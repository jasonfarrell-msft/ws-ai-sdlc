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
    [string] $BackendAppService,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $FrontendAppService,

    [switch] $SkipForkValidation
)

. (Join-Path $PSScriptRoot 'lib/Common.ps1')

$backendEnvironment = 'workshop-backend'
$frontendEnvironment = 'workshop-frontend'
$sourceRepository = 'jasonfarrell-msft/ws-ai-sdlc'
$backendUrl = "https://$BackendAppService.azurewebsites.net"

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

$registeredWorkflowCount = 0
if (-not [int]::TryParse(
        [string]$workflowInventory.total_count,
        [ref]$registeredWorkflowCount
    )) {
    throw "GitHub CLI could not determine the workflow count for '$Repository'. Confirm GitHub CLI authentication and repository access."
}

$workshopWorkflowPaths = @(
    '.github/workflows/backend.yml'
    '.github/workflows/frontend.yml'
)
$workshopWorkflows = @(
    $workflowInventory.workflows |
        Where-Object { $_.path -in $workshopWorkflowPaths }
)
$disabledForkWorkflows = @(
    $workshopWorkflows |
        Where-Object { $_.state -eq 'disabled_fork' }
)

if ($registeredWorkflowCount -eq 0 -or $disabledForkWorkflows.Count -gt 0) {
    throw "GitHub Actions is not enabled for '$Repository'. Open https://github.com/$Repository/actions, enable workflows for the fork, and rerun this script."
}
if ($workshopWorkflows.Count -ne $workshopWorkflowPaths.Count) {
    throw "The backend and frontend workflows are not both registered in '$Repository'. Confirm that both workflow files are present on the default branch."
}

Select-AzureSubscription
Resolve-ResourceLocation -ResourceGroup $ResourceGroup

$tenantId = az account show --query tenantId --output tsv
if ([string]::IsNullOrWhiteSpace($tenantId)) {
    throw 'Azure CLI did not return a tenant ID.'
}

$backendWorkflowState = ''
$frontendWorkflowState = ''
for ($attempt = 1; $attempt -le 5; $attempt++) {
    try {
        gh workflow enable backend.yml --repo $Repository
        gh workflow enable frontend.yml --repo $Repository
    }
    catch {
        if ($attempt -eq 5) {
            throw "Could not enable workflows in '$Repository'."
        }
    }

    $backendWorkflowState = gh workflow list `
        --repo $Repository `
        --all `
        --json path,state `
        --jq '.[] | select(.path == ".github/workflows/backend.yml") | .state'
    $frontendWorkflowState = gh workflow list `
        --repo $Repository `
        --all `
        --json path,state `
        --jq '.[] | select(.path == ".github/workflows/frontend.yml") | .state'
    if ($backendWorkflowState -eq 'active' -and $frontendWorkflowState -eq 'active') {
        break
    }
    if ($attempt -lt 5) {
        Write-Host 'Waiting for GitHub to register workflows in the fork.'
        Start-Sleep -Seconds 5
    }
}
if ($backendWorkflowState -ne 'active') {
    throw "The backend workflow is not active in '$Repository'."
}
if ($frontendWorkflowState -ne 'active') {
    throw "The frontend workflow is not active in '$Repository'."
}

$backendIdentity = "id-gha-be-$EnvironmentName"
$frontendIdentity = "id-gha-fe-$EnvironmentName"

function Ensure-Identity {
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    try {
        $existingId = az identity show `
            --subscription $script:SubscriptionId `
            --resource-group $ResourceGroup `
            --name $Name `
            --query id `
            --output tsv 2>$null
    }
    catch {
        $existingId = ''
    }
    if ([string]::IsNullOrWhiteSpace($existingId)) {
        az identity create `
            --subscription $script:SubscriptionId `
            --resource-group $ResourceGroup `
            --name $Name `
            --location $script:ResourceLocation `
            --output none
    }
}

function Ensure-FederatedCredential {
    param(
        [Parameter(Mandatory)]
        [string] $IdentityName,

        [Parameter(Mandatory)]
        [string] $CredentialName,

        [Parameter(Mandatory)]
        [string] $GitHubEnvironment
    )

    $expectedSubject = "${oidcSubjectPrefix}:environment:${GitHubEnvironment}"
    try {
        $existingSubject = az identity federated-credential show `
            --subscription $script:SubscriptionId `
            --resource-group $ResourceGroup `
            --identity-name $IdentityName `
            --name $CredentialName `
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
            --identity-name $IdentityName `
            --name $CredentialName `
            --issuer 'https://token.actions.githubusercontent.com' `
            --subject $expectedSubject `
            --audiences 'api://AzureADTokenExchange' `
            --output none
    }
    elseif ($existingSubject -ne $expectedSubject) {
        az identity federated-credential update `
            --subscription $script:SubscriptionId `
            --resource-group $ResourceGroup `
            --identity-name $IdentityName `
            --name $CredentialName `
            --issuer 'https://token.actions.githubusercontent.com' `
            --subject $expectedSubject `
            --audiences 'api://AzureADTokenExchange' `
            --output none
    }
}

function Ensure-RoleAssignment {
    param(
        [Parameter(Mandatory)]
        [string] $PrincipalId,

        [Parameter(Mandatory)]
        [string] $RoleName,

        [Parameter(Mandatory)]
        [string] $Scope
    )

    $assignmentCount = az role assignment list `
        --subscription $script:SubscriptionId `
        --assignee-object-id $PrincipalId `
        --role $RoleName `
        --scope $Scope `
        --query 'length(@)' `
        --output tsv

    if ($assignmentCount -eq '0') {
        for ($attempt = 1; $attempt -le 6; $attempt++) {
            try {
                az role assignment create `
                    --subscription $script:SubscriptionId `
                    --assignee-object-id $PrincipalId `
                    --assignee-principal-type ServicePrincipal `
                    --role $RoleName `
                    --scope $Scope `
                    --output none
                return
            }
            catch {
                if ($attempt -eq 6) {
                    throw "Could not assign role '$RoleName' at scope '$Scope'."
                }
                Write-Host 'Waiting for managed identity propagation before retrying role assignment.'
                Start-Sleep -Seconds 10
            }
        }
    }
}

function Set-GitHubEnvironment {
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    $body = @{
        wait_timer = 0
        reviewers = @()
        deployment_branch_policy = @{
            protected_branches = $false
            custom_branch_policies = $true
        }
    } | ConvertTo-Json -Depth 4 -Compress

    $body | gh api `
        --method PUT `
        -H 'Accept: application/vnd.github+json' `
        "repos/$Repository/environments/$Name" `
        --input - | Out-Null

    $stalePolicyIds = @(gh api `
        "repos/$Repository/environments/$Name/deployment-branch-policies" `
        --paginate `
        --jq '.branch_policies[] | select(.name != "main" or .type != "branch") | .id')
    foreach ($policyId in $stalePolicyIds) {
        if (-not [string]::IsNullOrWhiteSpace($policyId)) {
            gh api `
                --method DELETE `
                "repos/$Repository/environments/$Name/deployment-branch-policies/$policyId" | Out-Null
        }
    }

    $mainPolicyId = gh api `
        "repos/$Repository/environments/$Name/deployment-branch-policies" `
        --jq '.branch_policies[] | select(.name == "main" and .type == "branch") | .id'
    if ([string]::IsNullOrWhiteSpace($mainPolicyId)) {
        gh api `
            --method POST `
            -H 'Accept: application/vnd.github+json' `
            "repos/$Repository/environments/$Name/deployment-branch-policies" `
            -f name=main `
            -f type=branch | Out-Null
    }
}

function Set-EnvironmentVariable {
    param(
        [Parameter(Mandatory)]
        [string] $Environment,

        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $Value
    )

    gh variable set $Name `
        --repo $Repository `
        --env $Environment `
        --body $Value
}

Ensure-Identity -Name $backendIdentity
Ensure-Identity -Name $frontendIdentity

$backendClientId = az identity show `
    --subscription $script:SubscriptionId `
    --resource-group $ResourceGroup `
    --name $backendIdentity `
    --query clientId `
    --output tsv
$backendPrincipalId = az identity show `
    --subscription $script:SubscriptionId `
    --resource-group $ResourceGroup `
    --name $backendIdentity `
    --query principalId `
    --output tsv
$frontendClientId = az identity show `
    --subscription $script:SubscriptionId `
    --resource-group $ResourceGroup `
    --name $frontendIdentity `
    --query clientId `
    --output tsv
$frontendPrincipalId = az identity show `
    --subscription $script:SubscriptionId `
    --resource-group $ResourceGroup `
    --name $frontendIdentity `
    --query principalId `
    --output tsv

Ensure-FederatedCredential `
    -IdentityName $backendIdentity `
    -CredentialName 'github-workshop-backend' `
    -GitHubEnvironment $backendEnvironment
Ensure-FederatedCredential `
    -IdentityName $frontendIdentity `
    -CredentialName 'github-workshop-frontend' `
    -GitHubEnvironment $frontendEnvironment

$backendAppServiceId = az webapp show `
    --subscription $script:SubscriptionId `
    --resource-group $ResourceGroup `
    --name $BackendAppService `
    --query id `
    --output tsv
$frontendAppServiceId = az webapp show `
    --subscription $script:SubscriptionId `
    --resource-group $ResourceGroup `
    --name $FrontendAppService `
    --query id `
    --output tsv

Ensure-RoleAssignment `
    -PrincipalId $backendPrincipalId `
    -RoleName 'Website Contributor' `
    -Scope $backendAppServiceId
Ensure-RoleAssignment `
    -PrincipalId $frontendPrincipalId `
    -RoleName 'Website Contributor' `
    -Scope $frontendAppServiceId

Set-GitHubEnvironment -Name $backendEnvironment
Set-GitHubEnvironment -Name $frontendEnvironment

Set-EnvironmentVariable -Environment $backendEnvironment -Name AZURE_CLIENT_ID -Value $backendClientId
Set-EnvironmentVariable -Environment $backendEnvironment -Name AZURE_TENANT_ID -Value $tenantId
Set-EnvironmentVariable -Environment $backendEnvironment -Name AZURE_SUBSCRIPTION_ID -Value $script:SubscriptionId
Set-EnvironmentVariable -Environment $backendEnvironment -Name AZURE_RESOURCE_GROUP -Value $ResourceGroup
Set-EnvironmentVariable -Environment $backendEnvironment -Name AZURE_BACKEND_APP_SERVICE -Value $BackendAppService

Set-EnvironmentVariable -Environment $frontendEnvironment -Name AZURE_CLIENT_ID -Value $frontendClientId
Set-EnvironmentVariable -Environment $frontendEnvironment -Name AZURE_TENANT_ID -Value $tenantId
Set-EnvironmentVariable -Environment $frontendEnvironment -Name AZURE_SUBSCRIPTION_ID -Value $script:SubscriptionId
Set-EnvironmentVariable -Environment $frontendEnvironment -Name AZURE_RESOURCE_GROUP -Value $ResourceGroup
Set-EnvironmentVariable -Environment $frontendEnvironment -Name AZURE_APP_SERVICE -Value $FrontendAppService

gh variable set AZURE_BACKEND_URL `
    --repo $Repository `
    --body $backendUrl

Write-Host @"

GitHub Actions access configured.
Repository:           $Repository
Backend environment:  $backendEnvironment
Frontend environment: $frontendEnvironment
Backend identity:     $backendIdentity
Frontend identity:    $frontendIdentity

Pushes to main now deploy changed backend or frontend files automatically.
"@
