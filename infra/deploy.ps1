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

$imageParameters = @()
foreach ($component in @(@{ Name = "ca-api-$environmentName"; Parameter = 'backendImage' },
                         @{ Name = "ca-web-$environmentName"; Parameter = 'frontendImage' })) {
    $currentImage = az containerapp list `
        --subscription $script:SubscriptionId `
        --resource-group $ResourceGroup `
        --query "[?name=='$($component.Name)'].properties.template.containers[0].image | [0]" `
        --output tsv
    if (-not [string]::IsNullOrWhiteSpace($currentImage)) {
        $imageParameters += "$($component.Parameter)=$currentImage"
    }
}

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
        @imageParameters `
    --action-on-unmanage deleteAll `
    --deny-settings-mode None `
    --yes `
    --output none

$registryName = Get-StackOutput `
    -ResourceGroup $ResourceGroup `
    -StackName $stackName `
    -OutputName containerRegistryName
$registryLoginServer = Get-StackOutput `
    -ResourceGroup $ResourceGroup `
    -StackName $stackName `
    -OutputName containerRegistryLoginServer
$backendAppName = Get-StackOutput `
    -ResourceGroup $ResourceGroup `
    -StackName $stackName `
    -OutputName backendAppName
$frontendAppName = Get-StackOutput `
    -ResourceGroup $ResourceGroup `
    -StackName $stackName `
    -OutputName frontendAppName
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
    $frontendDirectory = Join-Path $script:ProjectRoot 'src/frontend'
    $imageTag = "$environmentName-$([DateTime]::UtcNow.ToString('yyyyMMddHHmmss'))"

    Write-Host "Building the API image in Azure Container Registry '$registryName'."
    az acr build `
        --registry $registryName `
        --subscription $script:SubscriptionId `
        --image "support-desk-api:$imageTag" `
        --file (Join-Path $backendDirectory 'Dockerfile') `
        $backendDirectory `
        --platform linux/amd64 `
        --output none

    Write-Host "Updating the API Container App."
    az containerapp update `
        --subscription $script:SubscriptionId `
        --resource-group $ResourceGroup `
        --name $backendAppName `
        --image "$registryLoginServer/support-desk-api:$imageTag" `
        --output none

    Write-Host "Building the frontend image in Azure Container Registry '$registryName'."
    az acr build `
        --registry $registryName `
        --subscription $script:SubscriptionId `
        --image "support-desk-frontend:$imageTag" `
        --file (Join-Path $frontendDirectory 'Dockerfile') `
        $frontendDirectory `
        --platform linux/amd64 `
        --output none

    Write-Host "Updating the frontend Container App."
    az containerapp update `
        --subscription $script:SubscriptionId `
        --resource-group $ResourceGroup `
        --name $frontendAppName `
        --image "$registryLoginServer/support-desk-frontend:$imageTag" `
        --output none

    $backendUrl = Get-StackOutput `
        -ResourceGroup $ResourceGroup `
        -StackName $stackName `
        -OutputName backendUrl
    Test-ApplicationEndpoint -Uri "$backendUrl/api/health" -HealthEndpoint
    Test-ApplicationEndpoint -Uri "$applicationUrl/api/health" -HealthEndpoint
    Test-ApplicationEndpoint -Uri $applicationUrl
}

Write-Host @"

Infrastructure ready$(if ($SkipCodeDeploy) { ' (application images were not deployed)' } else { '; application deployment verified' }).
Environment name:  $environmentName
Deployment stack: $stackName
Resource group:    $ResourceGroup
Application URL:   $applicationUrl
Frontend App:       $frontendAppName
Backend App:        $backendAppName
Container Registry: $registryName

To remove only this generated environment:
pwsh ./infra/destroy.ps1 -ResourceGroup '$ResourceGroup' -EnvironmentName '$environmentName' -ConfirmEnvironment '$environmentName'
"@
