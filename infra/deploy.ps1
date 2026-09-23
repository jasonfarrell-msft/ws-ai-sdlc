[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroup,

    [ValidatePattern('^[a-zA-Z0-9-]{1,32}$')]
    [string] $Label = 'aisdlc',

    [switch] $SkipCodeDeploy
)

. (Join-Path $PSScriptRoot 'lib/Common.ps1')

$placeholderImage = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
$backendRepository = 'support-desk-api'

Assert-Command -Name az
Assert-AzureCliVersion
if (-not $SkipCodeDeploy) {
    Assert-Command -Name npm
}
Select-AzureSubscription
Resolve-ResourceLocation -ResourceGroup $ResourceGroup

$runIdentifier = New-RunIdentifier
$stackName = "azstk$runIdentifier"
$createdAt = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')

try {
    $deployedBy = az ad signed-in-user show --query displayName --output tsv
}
catch {
    $deployedBy = az account show --query user.name --output tsv
}
if ([string]::IsNullOrWhiteSpace($deployedBy)) {
    $deployedBy = az account show --query user.name --output tsv
}

Write-Host "Deploying fresh run $runIdentifier to $ResourceGroup in $script:ResourceLocation."

$templateFile = Join-Path $script:InfraDirectory 'main.bicep'
$parametersFile = Join-Path $script:InfraDirectory 'main.parameters.json'

function Invoke-StackDeployment {
    param(
        [Parameter(Mandatory)]
        [string] $Image,

        [Parameter(Mandatory)]
        [bool] $ExternalIngress,

        [Parameter(Mandatory)]
        [bool] $EnableDiagnostics
    )

    az stack group create `
        --subscription $script:SubscriptionId `
        --resource-group $ResourceGroup `
        --name $stackName `
        --template-file $templateFile `
        --parameters $parametersFile `
        --parameters `
            "location=$script:ResourceLocation" `
            "environmentName=$runIdentifier" `
            "deploymentLabel=$Label" `
            "deployedBy=$deployedBy" `
            "createdAt=$createdAt" `
            "containerImage=$Image" `
            "externalIngressEnabled=$($ExternalIngress.ToString().ToLowerInvariant())" `
            "enableDiagnostics=$($EnableDiagnostics.ToString().ToLowerInvariant())" `
        --action-on-unmanage deleteAll `
        --deny-settings-mode None `
        --yes `
        --output none
}

function Test-HttpEndpoint {
    param(
        [Parameter(Mandatory)]
        [uri] $Uri
    )

    for ($attempt = 1; $attempt -le 8; $attempt++) {
        try {
            Invoke-WebRequest -Uri $Uri -Method Get -UseBasicParsing | Out-Null
            return
        }
        catch {
            if ($attempt -eq 8) {
                throw
            }
            Start-Sleep -Seconds 10
        }
    }
}

Invoke-StackDeployment `
    -Image $placeholderImage `
    -ExternalIngress $false `
    -EnableDiagnostics $false

$registryName = Get-StackOutput -ResourceGroup $ResourceGroup -StackName $stackName -OutputName registryName
$registryServer = Get-StackOutput -ResourceGroup $ResourceGroup -StackName $stackName -OutputName registryLoginServer
$containerAppName = Get-StackOutput -ResourceGroup $ResourceGroup -StackName $stackName -OutputName containerAppName
$frontendAppName = Get-StackOutput -ResourceGroup $ResourceGroup -StackName $stackName -OutputName frontendAppName
$backendUrl = Get-StackOutput -ResourceGroup $ResourceGroup -StackName $stackName -OutputName backendUrl
$frontendUrl = Get-StackOutput -ResourceGroup $ResourceGroup -StackName $stackName -OutputName frontendUrl

if (-not $SkipCodeDeploy) {
    $dockerfile = Join-Path $script:ProjectRoot 'src/backend/Dockerfile'
    $backendDirectory = Join-Path $script:ProjectRoot 'src/backend'

    az acr build `
        --subscription $script:SubscriptionId `
        --registry $registryName `
        --image "${backendRepository}:$runIdentifier" `
        --file $dockerfile `
        $backendDirectory `
        --output none

    $imageDigest = az acr repository show `
        --subscription $script:SubscriptionId `
        --name $registryName `
        --image "${backendRepository}:$runIdentifier" `
        --query digest `
        --output tsv
    if ([string]::IsNullOrWhiteSpace($imageDigest)) {
        throw 'ACR did not return a digest for the backend image.'
    }
    $backendImage = "${registryServer}/${backendRepository}@${imageDigest}"

    $deployed = $false
    $delay = 10
    for ($attempt = 1; $attempt -le 6; $attempt++) {
        Write-Host "Applying backend image (attempt $attempt of 6)."
        try {
            Invoke-StackDeployment `
                -Image $backendImage `
                -ExternalIngress $true `
                -EnableDiagnostics $true
            $deployed = $true
            break
        }
        catch {
            if ($attempt -eq 6) {
                break
            }
            Write-Host "Waiting $delay seconds for AcrPull role propagation."
            Start-Sleep -Seconds $delay
            $delay *= 2
        }
    }
    if (-not $deployed) {
        throw 'The backend image could not be applied after AcrPull propagation retries.'
    }

    $frontendDirectory = Join-Path $script:ProjectRoot 'src/frontend'
    $distDirectory = Join-Path $frontendDirectory 'dist'
    $zipPath = Join-Path $script:InfraDirectory "frontend-$runIdentifier.zip"
    $previousApiBaseUrl = $env:VITE_API_BASE_URL
    $locationPushed = $false

    try {
        Push-Location $frontendDirectory
        $locationPushed = $true
        npm ci --replace-registry-host=never
        $env:VITE_API_BASE_URL = $backendUrl
        npm run build
        Pop-Location
        $locationPushed = $false

        if (Test-Path $zipPath) {
            Remove-Item $zipPath -Force
        }
        Get-ChildItem -Path $distDirectory -Force |
            Compress-Archive -DestinationPath $zipPath

        az webapp deploy `
            --subscription $script:SubscriptionId `
            --resource-group $ResourceGroup `
            --name $frontendAppName `
            --src-path $zipPath `
            --type zip `
            --clean true `
            --restart true `
            --output none
    }
    finally {
        if ($locationPushed) {
            Pop-Location
        }
        $env:VITE_API_BASE_URL = $previousApiBaseUrl
        if (Test-Path $zipPath) {
            Remove-Item $zipPath -Force
        }
    }

    Test-HttpEndpoint -Uri "$backendUrl/api/health"
    Test-HttpEndpoint -Uri $frontendUrl
}

Write-Host @"

Deployment complete.
Run identifier:  $runIdentifier
Deployment stack: $stackName
Resource group:   $ResourceGroup
Location:         $script:ResourceLocation
Frontend URL:     $frontendUrl
Backend URL:      $backendUrl
Frontend App:     $frontendAppName
Container App:    $containerAppName
Registry:         $registryName

To remove only this generated environment:
pwsh ./infra/destroy.ps1 -ResourceGroup '$ResourceGroup' -EnvironmentName '$runIdentifier' -ConfirmEnvironment '$runIdentifier'
"@
