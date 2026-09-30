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

function Invoke-ZipDeploy {
    param(
        [Parameter(Mandatory)]
        [string] $ResourceGroup,

        [Parameter(Mandatory)]
        [string] $AppName,

        [Parameter(Mandatory)]
        [string] $ZipPath
    )

    $priorDeploymentIds = @()
    for ($attempt = 1; $attempt -le 4; $attempt++) {
        try {
            $priorDeploymentIds = @(
                az webapp log deployment list `
                    --subscription $script:SubscriptionId `
                    --resource-group $ResourceGroup `
                    --name $AppName `
                    --query '[].id' `
                    --output tsv |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            )
            break
        }
        catch {
            if ($attempt -eq 4) {
                throw "Unable to read the existing App Service deployment state for '$AppName' after 4 attempts: $($_.Exception.Message)"
            }
            Start-Sleep -Seconds 15
        }
    }

    $previousNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
    try {
        $PSNativeCommandUseErrorActionPreference = $false
        az webapp deploy `
            --subscription $script:SubscriptionId `
            --resource-group $ResourceGroup `
            --name $AppName `
            --src-path $ZipPath `
            --type zip `
            --clean true `
            --restart true `
            --output none
        $deploymentExitCode = $LASTEXITCODE
    }
    finally {
        $PSNativeCommandUseErrorActionPreference = $previousNativeErrorPreference
    }

    if ($deploymentExitCode -eq 0) {
        return
    }

    $deploymentError = "az webapp deploy exited with code $deploymentExitCode."
    Write-Warning "Azure CLI did not confirm deployment for '$AppName'. Polling the App Service deployment log."

    $deadline = [DateTime]::UtcNow.AddSeconds(600)
    $lastStatusError = $null

    while ([DateTime]::UtcNow -lt $deadline) {
        try {
            $deploymentId = az webapp log deployment list `
                --subscription $script:SubscriptionId `
                --resource-group $ResourceGroup `
                --name $AppName `
                --query 'sort_by([?start_time != `null`], &start_time)[-1].id' `
                --output tsv

            if ([string]::IsNullOrWhiteSpace($deploymentId) -or $priorDeploymentIds -contains $deploymentId) {
                Start-Sleep -Seconds 15
                continue
            }

            $messages = az webapp log deployment show `
                --subscription $script:SubscriptionId `
                --resource-group $ResourceGroup `
                --name $AppName `
                --deployment-id $deploymentId `
                --query '[].message' `
                --output tsv
            $lastStatusError = $null

            if ($messages -match '(?i)Deployment failed') {
                throw "ZIP deployment failed for '$AppName'. App Service deployment log reported failure."
            }
            if ($messages -match '(?i)Deployment successful') {
                Write-Host "App Service deployment log confirmed successful deployment for '$AppName'."
                return
            }
        }
        catch {
            if ($_.Exception.Message -like 'ZIP deployment failed*') {
                throw
            }
            $lastStatusError = $_.Exception.Message
        }

        Start-Sleep -Seconds 15
    }

    $statusDetail = if ($lastStatusError) {
        " Last deployment-log error: $lastStatusError"
    }
    else {
        ''
    }
    throw "Azure CLI deployment for '$AppName' failed and App Service did not report a terminal deployment result within 600 seconds. Initial error: $deploymentError$statusDetail"
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
