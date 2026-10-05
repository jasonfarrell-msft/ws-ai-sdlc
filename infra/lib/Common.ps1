$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$script:InfraDirectory = Split-Path -Parent $PSScriptRoot
$script:ProjectRoot = Split-Path -Parent $script:InfraDirectory
$script:SubscriptionId = ''
$script:ResourceLocation = ''

function Assert-Command {
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' is not installed."
    }
}

function Assert-AzureCliVersion {
    $currentVersion = az version --query '"azure-cli"' --output tsv
    if ([version]$currentVersion -lt [version]'2.48.1') {
        throw 'Azure CLI 2.48.1 or newer is required.'
    }
}

function Select-AzureSubscription {
    try {
        $script:SubscriptionId = az account show --query id --output tsv
    }
    catch {
        throw "Azure CLI is not signed in. Run 'az login' and select a subscription."
    }

    if ([string]::IsNullOrWhiteSpace($script:SubscriptionId)) {
        throw 'Azure CLI did not return an active subscription.'
    }
}

function Resolve-ResourceLocation {
    param(
        [Parameter(Mandatory)]
        [string] $ResourceGroup
    )

    try {
        $script:ResourceLocation = az group show `
            --subscription $script:SubscriptionId `
            --name $ResourceGroup `
            --query location `
            --output tsv
    }
    catch {
        throw "Resource group '$ResourceGroup' does not exist in the active subscription."
    }

    if ([string]::IsNullOrWhiteSpace($script:ResourceLocation)) {
        throw "Azure did not return a location for resource group '$ResourceGroup'."
    }
    $script:ResourceLocation = $script:ResourceLocation.ToLowerInvariant()
}

function Get-StackOutput {
    param(
        [Parameter(Mandatory)]
        [string] $ResourceGroup,

        [Parameter(Mandatory)]
        [string] $StackName,

        [Parameter(Mandatory)]
        [string] $OutputName
    )

    $value = az stack group show `
        --subscription $script:SubscriptionId `
        --resource-group $ResourceGroup `
        --name $StackName `
        --query "outputs.$OutputName.value" `
        --output tsv

    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Stack '$StackName' did not return output '$OutputName'."
    }
    return $value
}
