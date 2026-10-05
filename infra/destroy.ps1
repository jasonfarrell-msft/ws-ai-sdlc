[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroup,

    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z]{2,5}01$')]
    [string] $EnvironmentName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ConfirmEnvironment
)

. (Join-Path $PSScriptRoot 'lib/Common.ps1')

if ($ConfirmEnvironment -cne $EnvironmentName) {
    throw '-ConfirmEnvironment must exactly match -EnvironmentName.'
}

Assert-Command -Name az
Select-AzureSubscription
Resolve-ResourceLocation -ResourceGroup $ResourceGroup

$stackName = "azstk$EnvironmentName"
az stack group show `
    --subscription $script:SubscriptionId `
    --resource-group $ResourceGroup `
    --name $stackName `
    --output none

$deploymentRoleName = "Support Desk Container App Deployer $EnvironmentName"
$identityName = "id-gha-ca-$EnvironmentName"
$identityId = az identity list `
    --subscription $script:SubscriptionId `
    --resource-group $ResourceGroup `
    --query "[?name=='$identityName'].id | [0]" `
    --output tsv

if (-not [string]::IsNullOrWhiteSpace($identityId)) {
    $principalId = az identity show `
        --subscription $script:SubscriptionId `
        --resource-group $ResourceGroup `
        --name $identityName `
        --query principalId `
        --output tsv
    $assignmentIds = @(
        az role assignment list `
            --subscription $script:SubscriptionId `
            --assignee-object-id $principalId `
            --role $deploymentRoleName `
            --scope "/subscriptions/$($script:SubscriptionId)/resourceGroups/$ResourceGroup" `
            --query '[].id' `
            --output tsv
    )
    foreach ($assignmentId in $assignmentIds) {
        if (-not [string]::IsNullOrWhiteSpace($assignmentId)) {
            az role assignment delete `
                --subscription $script:SubscriptionId `
                --ids $assignmentId
        }
    }
}

az stack group delete `
    --subscription $script:SubscriptionId `
    --resource-group $ResourceGroup `
    --name $stackName `
    --action-on-unmanage deleteAll `
    --yes

if (-not [string]::IsNullOrWhiteSpace($identityId)) {
    az identity delete `
        --subscription $script:SubscriptionId `
        --resource-group $ResourceGroup `
        --name $identityName
}

Write-Host "Deleted generated environment $EnvironmentName from $ResourceGroup. Resource group preserved."
