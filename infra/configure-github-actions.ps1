[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroup,

    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z]{2,5}01$')]
    [string] $EnvironmentName,

    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')]
    [string] $Repository,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $StaticWebApp,

    [switch] $SkipForkValidation
)

. (Join-Path $PSScriptRoot 'lib/Common.ps1')

$deploymentEnvironment = 'workshop-deployment'
$deploymentRoleName = "Support Desk SWA Deployer $EnvironmentName"
$sourceRepository = 'jasonfarrell-msft/ws-ai-sdlc'
$workflowPath = '.github/workflows/deploy.yml'

Assert-Command -Name az
Assert-Command -Name gh
Assert-AzureCliVersion

try {
    $isRepositoryAdmin = gh api "repos/$Repository" --jq '.permissions.admin'
}
catch {
    throw "GitHub CLI cannot access repository '$Repository'. Run 'gh auth login'."
}
if ($isRepositoryAdmin -ne 'true') {
    throw "Administrator access to '$Repository' is required."
}

$isWorkshopFork = gh api "repos/$Repository" `
    --jq ".fork and (.parent.full_name == `"$sourceRepository`")"
if ($isWorkshopFork -ne 'true') {
    if (-not $SkipForkValidation) {
        throw "'$Repository' must be a fork of '$sourceRepository'. For temporary testing against the source repository, rerun with -SkipForkValidation."
    }
    Write-Warning "Fork validation was skipped for '$Repository'. This testing-only override must not be used for participant setup."
}

try {
    $oidcConfigurationJson = gh api "repos/$Repository/actions/oidc/customization/sub"
    $oidcConfiguration = ($oidcConfigurationJson -join [Environment]::NewLine) |
        ConvertFrom-Json -Depth 10
}
catch {
    throw "GitHub CLI could not read the OIDC subject configuration for '$Repository'."
}
if ($oidcConfiguration.use_default -ne $true) {
    throw "Repository '$Repository' uses a custom OIDC subject template, which this workshop setup does not support."
}

$oidcSubjectPrefix = [string]$oidcConfiguration.sub_claim_prefix
if ([string]::IsNullOrWhiteSpace($oidcSubjectPrefix)) {
    $oidcSubjectPrefix = "repo:$Repository"
}
if (-not $oidcSubjectPrefix.StartsWith('repo:', [StringComparison]::Ordinal)) {
    throw "GitHub returned an unexpected OIDC subject prefix for '$Repository'."
}

gh api `
    --method PUT `
    "repos/$Repository/actions/permissions" `
    -F enabled=true `
    -f allowed_actions=all | Out-Null

try {
    $workflowInventoryJson = gh api "repos/$Repository/actions/workflows"
    $workflowInventory = ($workflowInventoryJson -join [Environment]::NewLine) |
        ConvertFrom-Json -Depth 10
}
catch {
    throw "GitHub CLI could not inspect workflows in '$Repository'."
}

$workflow = @(
    $workflowInventory.workflows |
        Where-Object { $_.path -eq $workflowPath }
)
if ($workflow.Count -ne 1) {
    throw "Workflow '$workflowPath' is not registered in '$Repository'. Confirm that the workflow file is present on the default branch."
}
if ($workflow[0].state -eq 'disabled_fork') {
    throw "GitHub Actions is not enabled for '$Repository'. Open https://github.com/$Repository/actions, enable workflows for the fork, and rerun this script."
}

Select-AzureSubscription
Resolve-ResourceLocation -ResourceGroup $ResourceGroup

$tenantId = az account show --query tenantId --output tsv
if ([string]::IsNullOrWhiteSpace($tenantId)) {
    throw 'Azure CLI did not return a tenant ID.'
}

for ($attempt = 1; $attempt -le 5; $attempt++) {
    try {
        gh workflow enable deploy.yml --repo $Repository
    }
    catch {
        if ($attempt -eq 5) {
            throw "Could not enable '$workflowPath' in '$Repository'."
        }
    }

    $workflowState = gh workflow list `
        --repo $Repository `
        --all `
        --json path,state `
        --jq ".[] | select(.path == `"$workflowPath`") | .state"
    if ($workflowState -eq 'active') {
        break
    }
    if ($attempt -lt 5) {
        Write-Host 'Waiting for GitHub to register the deployment workflow in the fork.'
        Start-Sleep -Seconds 5
    }
}
if ($workflowState -ne 'active') {
    throw "Workflow '$workflowPath' is not active in '$Repository'."
}

$identityName = "id-gha-swa-$EnvironmentName"

try {
    $identityId = az identity show `
        --subscription $script:SubscriptionId `
        --resource-group $ResourceGroup `
        --name $identityName `
        --query id `
        --output tsv 2>$null
}
catch {
    $identityId = ''
}
if ([string]::IsNullOrWhiteSpace($identityId)) {
    az identity create `
        --subscription $script:SubscriptionId `
        --resource-group $ResourceGroup `
        --name $identityName `
        --location $script:ResourceLocation `
        --output none
}

$expectedSubject = "${oidcSubjectPrefix}:environment:${deploymentEnvironment}"
$credentialName = 'github-workshop-deployment'
try {
    $existingSubject = az identity federated-credential show `
        --subscription $script:SubscriptionId `
        --resource-group $ResourceGroup `
        --identity-name $identityName `
        --name $credentialName `
        --query subject `
        --output tsv 2>$null
}
catch {
    $existingSubject = ''
}
if ([string]::IsNullOrWhiteSpace($existingSubject)) {
    az identity federated-credential create `
        --subscription $script:SubscriptionId `
        --resource-group $ResourceGroup `
        --identity-name $identityName `
        --name $credentialName `
        --issuer 'https://token.actions.githubusercontent.com' `
        --subject $expectedSubject `
        --audiences 'api://AzureADTokenExchange' `
        --output none
}
elseif ($existingSubject -ne $expectedSubject) {
    az identity federated-credential update `
        --subscription $script:SubscriptionId `
        --resource-group $ResourceGroup `
        --identity-name $identityName `
        --name $credentialName `
        --issuer 'https://token.actions.githubusercontent.com' `
        --subject $expectedSubject `
        --audiences 'api://AzureADTokenExchange' `
        --output none
}

$clientId = az identity show `
    --subscription $script:SubscriptionId `
    --resource-group $ResourceGroup `
    --name $identityName `
    --query clientId `
    --output tsv
$principalId = az identity show `
    --subscription $script:SubscriptionId `
    --resource-group $ResourceGroup `
    --name $identityName `
    --query principalId `
    --output tsv
$staticWebAppId = az staticwebapp show `
    --subscription $script:SubscriptionId `
    --resource-group $ResourceGroup `
    --name $StaticWebApp `
    --query id `
    --output tsv

$assignmentCount = az role assignment list `
    --subscription $script:SubscriptionId `
    --assignee-object-id $principalId `
    --role $deploymentRoleName `
    --scope $staticWebAppId `
    --query 'length(@)' `
    --output tsv
if ($assignmentCount -eq '0') {
    for ($attempt = 1; $attempt -le 6; $attempt++) {
        try {
            az role assignment create `
                --subscription $script:SubscriptionId `
                --assignee-object-id $principalId `
                --assignee-principal-type ServicePrincipal `
                --role $deploymentRoleName `
                --scope $staticWebAppId `
                --output none
            break
        }
        catch {
            if ($attempt -eq 6) {
                throw "Could not assign '$deploymentRoleName' at scope '$staticWebAppId'. Confirm that deploy.ps1 provisioned the matching custom role."
            }
            Write-Host 'Waiting for managed identity propagation before retrying role assignment.'
            Start-Sleep -Seconds 10
        }
    }
}

$environmentBody = @{
    wait_timer = 0
    reviewers = @()
    deployment_branch_policy = @{
        protected_branches = $false
        custom_branch_policies = $true
    }
} | ConvertTo-Json -Depth 4 -Compress

$environmentBody | gh api `
    --method PUT `
    -H 'Accept: application/vnd.github+json' `
    "repos/$Repository/environments/$deploymentEnvironment" `
    --input - | Out-Null

$stalePolicyIds = @(gh api `
    "repos/$Repository/environments/$deploymentEnvironment/deployment-branch-policies" `
    --paginate `
    --jq '.branch_policies[] | select(.name != "main" or .type != "branch") | .id')
foreach ($policyId in $stalePolicyIds) {
    if (-not [string]::IsNullOrWhiteSpace($policyId)) {
        gh api `
            --method DELETE `
            "repos/$Repository/environments/$deploymentEnvironment/deployment-branch-policies/$policyId" | Out-Null
    }
}

$mainPolicyId = gh api `
    "repos/$Repository/environments/$deploymentEnvironment/deployment-branch-policies" `
    --jq '.branch_policies[] | select(.name == "main" and .type == "branch") | .id'
if ([string]::IsNullOrWhiteSpace($mainPolicyId)) {
    gh api `
        --method POST `
        -H 'Accept: application/vnd.github+json' `
        "repos/$Repository/environments/$deploymentEnvironment/deployment-branch-policies" `
        -f name=main `
        -f type=branch | Out-Null
}

$environmentVariables = @{
    AZURE_CLIENT_ID = $clientId
    AZURE_TENANT_ID = $tenantId
    AZURE_SUBSCRIPTION_ID = $script:SubscriptionId
    AZURE_RESOURCE_GROUP = $ResourceGroup
    AZURE_STATIC_WEB_APP = $StaticWebApp
}
foreach ($variable in $environmentVariables.GetEnumerator()) {
    gh variable set $variable.Key `
        --repo $Repository `
        --env $deploymentEnvironment `
        --body $variable.Value
}

Write-Host @"

GitHub Actions access configured.
Repository:             $Repository
Deployment environment: $deploymentEnvironment
Deployment identity:    $identityName
Static Web App:          $StaticWebApp

Pushes to main now validate and atomically deploy the frontend and API.
"@
