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

az stack group delete `
    --subscription $script:SubscriptionId `
    --resource-group $ResourceGroup `
    --name $stackName `
    --action-on-unmanage deleteAll `
    --yes

Write-Host "Deleted generated environment $EnvironmentName from $ResourceGroup. Resource group preserved."
