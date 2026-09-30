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
    --action-on-unmanage deleteAll `
    --deny-settings-mode None `
    --yes `
    --output none

function Test-HttpEndpoint {
    param(
        [Parameter(Mandatory)]
        [uri] $Uri
    )

    for ($attempt = 1; $attempt -le 12; $attempt++) {
        try {
            Invoke-WebRequest -Uri $Uri -Method Get -UseBasicParsing | Out-Null
            return
        }
        catch {
            if ($attempt -eq 12) {
                throw
            }
            Start-Sleep -Seconds 10
        }
    }
}

$backendAppName = Get-StackOutput -ResourceGroup $ResourceGroup -StackName $stackName -OutputName backendAppName
$frontendAppName = Get-StackOutput -ResourceGroup $ResourceGroup -StackName $stackName -OutputName frontendAppName
$backendUrl = Get-StackOutput -ResourceGroup $ResourceGroup -StackName $stackName -OutputName backendUrl
$frontendUrl = Get-StackOutput -ResourceGroup $ResourceGroup -StackName $stackName -OutputName frontendUrl

if (-not $SkipCodeDeploy) {
    $backendDirectory = Join-Path $script:ProjectRoot 'src/backend'
    $backendStageDirectory = Join-Path $script:InfraDirectory "backend-$runIdentifier"
    $backendZipPath = Join-Path $script:InfraDirectory "backend-$runIdentifier.zip"
    $frontendDirectory = Join-Path $script:ProjectRoot 'src/frontend'
    $frontendDistDirectory = Join-Path $frontendDirectory 'dist'
    $frontendZipPath = Join-Path $script:InfraDirectory "frontend-$runIdentifier.zip"
    $previousApiBaseUrl = $env:VITE_API_BASE_URL
    $locationPushed = $false

    try {
        $backendStageAppDirectory = Join-Path $backendStageDirectory 'app'
        New-Item -ItemType Directory -Path $backendStageAppDirectory | Out-Null
        Copy-Item `
            -Path (Join-Path $backendDirectory 'app/*.py') `
            -Destination $backendStageAppDirectory
        Copy-Item `
            -Path (Join-Path $backendDirectory 'requirements.txt') `
            -Destination $backendStageDirectory
        Get-ChildItem -Path $backendStageDirectory -Force |
            Compress-Archive -DestinationPath $backendZipPath

        az webapp deploy `
            --subscription $script:SubscriptionId `
            --resource-group $ResourceGroup `
            --name $backendAppName `
            --src-path $backendZipPath `
            --type zip `
            --clean true `
            --restart true `
            --output none

        Push-Location $frontendDirectory
        $locationPushed = $true
        npm ci --replace-registry-host=never
        $env:VITE_API_BASE_URL = $backendUrl
        npm run build
        Pop-Location
        $locationPushed = $false

        Get-ChildItem -Path $frontendDistDirectory -Force |
            Compress-Archive -DestinationPath $frontendZipPath

        az webapp deploy `
            --subscription $script:SubscriptionId `
            --resource-group $ResourceGroup `
            --name $frontendAppName `
            --src-path $frontendZipPath `
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
        foreach ($zipPath in $backendZipPath, $frontendZipPath) {
            if (Test-Path $zipPath) {
                Remove-Item $zipPath -Force
            }
        }
        if (Test-Path $backendStageDirectory) {
            Remove-Item $backendStageDirectory -Recurse -Force
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
Backend App:      $backendAppName

To remove only this generated environment:
pwsh ./infra/destroy.ps1 -ResourceGroup '$ResourceGroup' -EnvironmentName '$runIdentifier' -ConfirmEnvironment '$runIdentifier'
"@
