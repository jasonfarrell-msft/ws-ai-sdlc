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

$validationEnvironmentName = 'val01'
$whatIfJson = az deployment group what-if `
    --subscription $script:SubscriptionId `
    --resource-group $ResourceGroup `
    --template-file $templateFile `
    --parameters $parametersFile `
    --parameters `
        "location=$script:ResourceLocation" `
        "environmentName=$validationEnvironmentName" `
        'deploymentLabel=validation' `
    --exclude-change-types Ignore NoChange `
    --no-pretty-print `
    --output json

if (-not $whatIfJson) {
    throw 'Azure Resource Manager returned no what-if result.'
}

$whatIf = $whatIfJson | ConvertFrom-Json -Depth 100
if ($whatIf.status -ne 'Succeeded') {
    throw "Azure Resource Manager what-if did not succeed. Status: $($whatIf.status)."
}

$changes = @($whatIf.changes | Where-Object { $null -ne $_ })

if ($changes.Count -eq 0) {
    Write-Host 'Infrastructure validation passed. Azure reports no planned changes.'
    return
}

$changeSummary = $changes |
    Group-Object -Property changeType |
    Sort-Object -Property Name |
    ForEach-Object { "$($_.Name): $($_.Count)" }

Write-Host "Infrastructure validation passed. Planned changes: $($changeSummary -join ', ')."
