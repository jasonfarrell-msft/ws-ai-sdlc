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
    Assert-Command -Name dotnet
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

function Wait-ScmEndpoint {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $HostName,

        [ValidateRange(30, 900)]
        [int] $TimeoutSeconds = 300
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $attempt = 0
    $lastError = 'The endpoint did not become reachable.'
    while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        $attempt++
        try {
            $dnsTask = [System.Net.Dns]::GetHostAddressesAsync($HostName)
            if (-not $dnsTask.Wait([TimeSpan]::FromSeconds(5)) -or $dnsTask.Result.Count -eq 0) {
                throw "DNS did not return an address for '$HostName'."
            }

            $tcpClient = [System.Net.Sockets.TcpClient]::new()
            try {
                $connectTask = $tcpClient.ConnectAsync($HostName, 443)
                if (-not $connectTask.Wait([TimeSpan]::FromSeconds(5)) -or -not $tcpClient.Connected) {
                    throw "HTTPS port 443 is not reachable for '$HostName'."
                }
            }
            finally {
                $tcpClient.Dispose()
            }

            Write-Host "App Service deployment endpoint '$HostName' is ready."
            return
        }
        catch {
            $lastError = $_.Exception.GetBaseException().Message
            $remainingSeconds = $TimeoutSeconds - [int]$stopwatch.Elapsed.TotalSeconds
            if ($remainingSeconds -le 0) {
                throw "App Service deployment endpoint '$HostName' was not ready within $TimeoutSeconds seconds. $lastError"
            }

            Write-Host "Waiting for App Service deployment endpoint '$HostName' (attempt $attempt)."
            Start-Sleep -Seconds ([Math]::Min(10, $remainingSeconds))
        }
    }

    throw "App Service deployment endpoint '$HostName' was not ready within $TimeoutSeconds seconds. $lastError"
}

if (-not $SkipCodeDeploy) {
    $projectFile = Join-Path $script:ProjectRoot 'src/SupportDesk.App/SupportDesk.App.csproj'
    $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) "support-desk-$([guid]::NewGuid().ToString('N'))"
    $publishDirectory = Join-Path $temporaryRoot 'publish'
    $packagePath = Join-Path $temporaryRoot 'support-desk.zip'

    try {
        Write-Host '2/4 Restoring and publishing the .NET application.'
        dotnet restore $projectFile `
            --locked-mode
        dotnet publish $projectFile `
            --configuration Release `
            --no-restore `
            --output $publishDirectory

        Write-Host '3/4 Creating and deploying the application package.'
        Compress-Archive -Path (Join-Path $publishDirectory '*') -DestinationPath $packagePath

        $scmHostName = "$webAppName.scm.azurewebsites.net"
        Wait-ScmEndpoint -HostName $scmHostName

        for ($deploymentAttempt = 1; $deploymentAttempt -le 3; $deploymentAttempt++) {
            try {
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
                break
            }
            catch {
                if ($deploymentAttempt -eq 3) {
                    throw
                }

                Write-Warning "App Service deployment attempt $deploymentAttempt failed. Retrying in 15 seconds."
                Start-Sleep -Seconds 15
            }
        }

        Write-Host '4/4 Verifying the deployed application.'
        Test-ApplicationEndpoint -Uri "$applicationUrl/api/health" -HealthEndpoint
        Test-ApplicationEndpoint -Uri $applicationUrl
        $negotiate = Invoke-RestMethod `
            -Uri "$applicationUrl/_blazor/negotiate?negotiateVersion=1" `
            -Method Post
        if ([string]::IsNullOrWhiteSpace($negotiate.connectionToken)) {
            throw 'Blazor Interactive Server negotiation did not return a connection token.'
        }
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
