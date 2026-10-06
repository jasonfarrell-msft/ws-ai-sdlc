[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroup,

    [ValidatePattern('^[a-zA-Z0-9-]{1,32}$')]
    [string] $Label = 'aisdlc',

    [ValidatePattern('^[A-Za-z]{2,5}$')]
    [string] $Initials,

    [switch] $SkipCodeDeploy
)

. (Join-Path $PSScriptRoot 'lib/Common.ps1')

Assert-Command -Name az
Assert-AzureCliVersion
Select-AzureSubscription
Resolve-ResourceLocation -ResourceGroup $ResourceGroup

if (-not $SkipCodeDeploy) {
    Assert-Command -Name npm
}

$resolvedInitials = $Initials
while ([string]::IsNullOrWhiteSpace($resolvedInitials)) {
    $entry = (Read-Host 'Enter your initials (2-5 letters)').Trim()
    if ($entry -match '^[A-Za-z]{2,5}$') {
        $resolvedInitials = $entry
    }
    else {
        Write-Warning 'Initials must contain 2-5 letters only.'
    }
}

$environmentName = "$($resolvedInitials.ToLowerInvariant())01"
$stackName = "azstk$environmentName"
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

$templateFile = Join-Path $script:InfraDirectory 'main.bicep'
$parametersFile = Join-Path $script:InfraDirectory 'main.parameters.json'

Write-Host "1/4 Provisioning App Service environment '$environmentName'."
az stack group create `
    --subscription $script:SubscriptionId `
    --resource-group $ResourceGroup `
    --name $stackName `
    --template-file $templateFile `
    --parameters $parametersFile `
    --parameters `
        "location=$script:ResourceLocation" `
        "environmentName=$environmentName" `
        "deploymentLabel=$Label" `
        "deployedBy=$deployedBy" `
        "createdAt=$createdAt" `
    --action-on-unmanage deleteAll `
    --deny-settings-mode None `
    --yes `
    --output none

$webAppName = Get-StackOutput `
    -ResourceGroup $ResourceGroup `
    -StackName $stackName `
    -OutputName webAppName
$appServicePlanName = Get-StackOutput `
    -ResourceGroup $ResourceGroup `
    -StackName $stackName `
    -OutputName appServicePlanName
$applicationUrl = Get-StackOutput `
    -ResourceGroup $ResourceGroup `
    -StackName $stackName `
    -OutputName applicationUrl

function Test-ApplicationEndpoint {
    param(
        [Parameter(Mandatory)]
        [uri] $Uri,

        [switch] $HealthEndpoint
    )

    for ($attempt = 1; $attempt -le 18; $attempt++) {
        try {
            if ($HealthEndpoint) {
                $response = Invoke-RestMethod -Uri $Uri -Method Get
                if ($response.status -ne 'healthy') {
                    throw "Health endpoint returned status '$($response.status)'."
                }
            }
            else {
                $response = Invoke-WebRequest -Uri $Uri -Method Get -UseBasicParsing
                if ($response.Content -notmatch 'Support Desk Simulator') {
                    throw 'Application root did not contain the expected title.'
                }
            }
            return
        }
        catch {
            if ($attempt -eq 18) {
                throw
            }
            Start-Sleep -Seconds 10
        }
    }
}

if (-not $SkipCodeDeploy) {
    $backendDirectory = Join-Path $script:ProjectRoot 'src/backend'
    $frontendDirectory = Join-Path $script:ProjectRoot 'src/frontend'
    $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) "support-desk-$([guid]::NewGuid().ToString('N'))"
    $stagingDirectory = Join-Path $temporaryRoot 'package'
    $packagePath = Join-Path $temporaryRoot 'support-desk.zip'

    try {
        Write-Host '2/4 Building the React application.'
        npm --prefix $frontendDirectory ci
        npm --prefix $frontendDirectory run build

        Write-Host '3/4 Creating and deploying the application package.'
        New-Item -ItemType Directory -Path $stagingDirectory | Out-Null
        Copy-Item -Path (Join-Path $backendDirectory 'app') -Destination $stagingDirectory -Recurse
        Copy-Item -Path (Join-Path $backendDirectory 'requirements.txt') -Destination $stagingDirectory
        $staticDirectory = Join-Path $stagingDirectory 'app/static'
        New-Item -ItemType Directory -Path $staticDirectory | Out-Null
        Copy-Item -Path (Join-Path $frontendDirectory 'dist/*') -Destination $staticDirectory -Recurse
        Compress-Archive -Path (Join-Path $stagingDirectory '*') -DestinationPath $packagePath

        az webapp deploy `
            --subscription $script:SubscriptionId `
            --resource-group $ResourceGroup `
            --name $webAppName `
            --src-path $packagePath `
            --type zip `
            --clean true `
            --restart true `
            --track-status true `
            --output none

        Write-Host '4/4 Verifying the deployed application.'
        Test-ApplicationEndpoint -Uri "$applicationUrl/api/health" -HealthEndpoint
        Test-ApplicationEndpoint -Uri $applicationUrl
    }
    finally {
        if (Test-Path -LiteralPath $temporaryRoot) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
    }
}

Write-Host @"

Infrastructure ready$(if ($SkipCodeDeploy) { ' (application package was not deployed)' } else { '; application deployment verified' }).
Environment name:  $environmentName
Deployment stack: $stackName
Resource group:    $ResourceGroup
Application URL:   $applicationUrl
App Service plan:  $appServicePlanName
Web App:           $webAppName

To remove only this generated environment:
./infra/destroy.ps1 -ResourceGroup '$ResourceGroup' -EnvironmentName '$environmentName' -ConfirmEnvironment '$environmentName'
"@
