[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroup
)

. (Join-Path $PSScriptRoot 'lib/Common.ps1')

Assert-Command -Name az
Assert-AzureCliVersion
Select-AzureSubscription
Resolve-ResourceLocation -ResourceGroup $ResourceGroup

$templateFile = Join-Path $script:InfraDirectory 'main.bicep'
$parametersFile = Join-Path $script:InfraDirectory 'main.parameters.json'

az bicep build --file $templateFile --stdout | Out-Null
Write-Host 'Bicep compilation passed.'

$validationIdentifier = New-RunIdentifier
az deployment group what-if `
    --subscription $script:SubscriptionId `
    --resource-group $ResourceGroup `
    --template-file $templateFile `
    --parameters $parametersFile `
    --parameters `
        "location=$script:ResourceLocation" `
        "environmentName=$validationIdentifier" `
        'deploymentLabel=validation' `
    --no-pretty-print
