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
if (-not $SkipCodeDeploy) {
    Assert-Command -Name npm
    Assert-Command -Name swa
    $pythonCommand = if (Get-Command python3.11 -ErrorAction SilentlyContinue) {
        'python3.11'
    }
    elseif (Get-Command python -ErrorAction SilentlyContinue) {
        'python'
    }
    else {
        throw "Required command 'python3.11' is not installed."
    }
    $pythonVersion = (& $pythonCommand -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")').Trim()
    if ($pythonVersion -ne '3.11') {
        throw "Python 3.11 is required to package the managed API. '$pythonCommand' reports Python $pythonVersion."
    }
    $swaVersionOutput = (swa --version).Trim()
    if ($swaVersionOutput -notmatch '(?<version>\d+\.\d+\.\d+)') {
        throw "Could not parse the Azure Static Web Apps CLI version from '$swaVersionOutput'."
    }
    if ([version]$Matches.version -lt [version]'2.0.10') {
        throw 'Azure Static Web Apps CLI 2.0.10 or newer is required.'
    }
}
Select-AzureSubscription
Resolve-ResourceLocation -ResourceGroup $ResourceGroup

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

Write-Host "Deploying environment $environmentName to $ResourceGroup."

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
        "environmentName=$environmentName" `
        "deploymentLabel=$Label" `
        "deployedBy=$deployedBy" `
        "createdAt=$createdAt" `
    --action-on-unmanage deleteAll `
    --deny-settings-mode None `
    --yes `
    --output none

$staticWebAppName = Get-StackOutput `
    -ResourceGroup $ResourceGroup `
    -StackName $stackName `
    -OutputName staticWebAppName
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

    for ($attempt = 1; $attempt -le 12; $attempt++) {
        try {
            if ($HealthEndpoint) {
                $response = Invoke-RestMethod -Uri $Uri -Method Get
                if ($response.status -ne 'healthy') {
                    throw "Health endpoint returned status '$($response.status)'."
                }
            }
            else {
                Invoke-WebRequest -Uri $Uri -Method Get -UseBasicParsing | Out-Null
            }
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

if (-not $SkipCodeDeploy) {
    $backendDirectory = Join-Path $script:ProjectRoot 'src/backend'
    $backendStageDirectory = Join-Path $script:InfraDirectory "backend-$environmentName"
    $frontendDirectory = Join-Path $script:ProjectRoot 'src/frontend'
    $previousDeploymentToken = $env:SWA_CLI_DEPLOYMENT_TOKEN
    $locationPushed = $false

    try {
        if (Test-Path $backendStageDirectory) {
            Remove-Item $backendStageDirectory -Recurse -Force
        }
        New-Item -ItemType Directory -Path $backendStageDirectory | Out-Null
        Copy-Item `
            -Path (Join-Path $backendDirectory 'app') `
            -Destination $backendStageDirectory `
            -Recurse
        foreach ($fileName in 'function_app.py', 'host.json', 'requirements.txt') {
            Copy-Item `
                -Path (Join-Path $backendDirectory $fileName) `
                -Destination $backendStageDirectory
        }
        & $pythonCommand -m pip install `
            --disable-pip-version-check `
            --target (Join-Path $backendStageDirectory '.python_packages/lib/site-packages') `
            --platform manylinux2014_x86_64 `
            --python-version 3.11 `
            --implementation cp `
            --only-binary=:all: `
            --requirement (Join-Path $backendDirectory 'requirements.txt')

        Push-Location $frontendDirectory
        $locationPushed = $true
        npm ci --replace-registry-host=never
        npm run build

        $env:SWA_CLI_DEPLOYMENT_TOKEN = az staticwebapp secrets list `
            --subscription $script:SubscriptionId `
            --resource-group $ResourceGroup `
            --name $staticWebAppName `
            --query properties.apiKey `
            --output tsv
        if ([string]::IsNullOrWhiteSpace($env:SWA_CLI_DEPLOYMENT_TOKEN)) {
            throw "Azure did not return a deployment token for '$staticWebAppName'."
        }

        swa deploy ./dist `
            --api-location $backendStageDirectory `
            --swa-config-location ./dist `
            --app-name $staticWebAppName `
            --env production
    }
    finally {
        if ($locationPushed) {
            Pop-Location
        }
        $env:SWA_CLI_DEPLOYMENT_TOKEN = $previousDeploymentToken
        if (Test-Path $backendStageDirectory) {
            Remove-Item $backendStageDirectory -Recurse -Force
        }
    }

    Test-ApplicationEndpoint -Uri "$applicationUrl/api/health" -HealthEndpoint
    Test-ApplicationEndpoint -Uri $applicationUrl
}

Write-Host @"

Deployment complete.
Environment name:  $environmentName
Deployment stack: $stackName
Resource group:    $ResourceGroup
Application URL:   $applicationUrl
Static Web App:    $staticWebAppName

To remove only this generated environment:
pwsh ./infra/destroy.ps1 -ResourceGroup '$ResourceGroup' -EnvironmentName '$environmentName' -ConfirmEnvironment '$environmentName'
"@
