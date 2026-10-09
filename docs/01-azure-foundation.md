# Deploy the Existing Application

## Goal

Deploy the existing Support Desk Simulator to one Azure App Service Web App and
confirm that its Blazor frontend and ASP.NET Core API work through one HTTPS
origin.

The deployment creates:

- One Linux App Service Plan on the Basic B1 tier
- One .NET 10 Web App with WebSockets enabled for Blazor Interactive Server
- One published ASP.NET Core application containing the UI and API
- Log Analytics and workspace-based Application Insights
- One Microsoft Foundry resource with the `support-sim-project` project
- One GPT-5.4-mini `GlobalStandard` model deployment

There are no containers, registries, JavaScript packages, Node.js tools, npm
manifests, or custom Azure roles.

> [!IMPORTANT]
> The application uses synthetic data and demo identities. Do not enter real
> customer, credential, personal, or confidential information.

## Architecture

| Component | Technology | Configuration |
| --- | --- | --- |
| Frontend | .NET 10 Blazor Web App | Interactive Server components |
| Backend | ASP.NET Core | Minimal API routes under `/api` |
| State | Singleton .NET service | Thread-safe process-local synthetic data |
| Hosting | Azure App Service | One Linux Web App on one Basic B1 plan |
| Monitoring | Log Analytics and Application Insights | 30-day workspace retention |
| AI foundation | Microsoft Foundry | `support-sim-project` and GPT-5.4-mini |
| Deployment | `dotnet publish` and ZIP deployment | Microsoft Entra authentication |

The UI and API run in one ASP.NET Core process. Blazor Interactive Server uses
the Microsoft-provided browser bootstrap asset included with ASP.NET Core. It
does not use npm or a JavaScript package pipeline.

The store resets when the application restarts. The plan uses one instance
because multiple instances would not share changes.

## Prerequisites

Run every command in this guide from a PowerShell 7 terminal. You need:

- Access to an Azure subscription
- Permission to create resources in a dedicated resource group
- Azure CLI 2.48.1 or newer with Bicep
- .NET 10 SDK
- Git and GitHub CLI

Install any missing prerequisites:

- [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)
- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)
- [Git](https://git-scm.com/downloads)
- [GitHub CLI](https://cli.github.com/)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)

Open a new PowerShell terminal, then install Bicep:

```powershell
az bicep install
```

## 1. Fork and clone the repository

```powershell
gh auth login
gh repo fork jasonfarrell-msft/ws-ai-sdlc `
  --clone `
  --default-branch-only
Set-Location ws-ai-sdlc
gh repo set-default origin

$GITHUB_REPOSITORY = gh repo view `
  --json nameWithOwner `
  --jq .nameWithOwner
```

Confirm that the repository is your fork:

```powershell
gh api "repos/$GITHUB_REPOSITORY" `
  --jq '{repository:.full_name,isFork:.fork,admin:.permissions.admin,upstream:.parent.full_name}'
```

`isFork` and `admin` must be `true`, and `upstream` must be
`jasonfarrell-msft/ws-ai-sdlc`.

## 2. Check the required tools

```powershell
git --version
gh --version
$PSVersionTable.PSVersion
dotnet --version
az version --query '"azure-cli"' --output tsv
az bicep version
```

`dotnet --version` must report `10.0.300` or a compatible later .NET 10 patch
selected by [`global.json`](../global.json).

No Node.js or npm check is required. The repository contains no npm packages and
does not contact an npm registry.

## 3. Restore, test, and run locally

```powershell
dotnet restore SupportDesk.slnx `
  --locked-mode

dotnet test SupportDesk.slnx `
  --configuration Release `
  --no-restore

dotnet run `
  --project ./src/SupportDesk.App/SupportDesk.App.csproj
```

Open the HTTPS URL printed by ASP.NET Core. Confirm the ticket and knowledge
workflows, then stop the local process with <kbd>Ctrl</kbd>+<kbd>C</kbd>.

## 4. Sign in and create the resource group

```powershell
az login
az account set --subscription '<subscription-id>'

$RESOURCE_GROUP = '<resource-group-name>'
$LOCATION = '<azure-region>'

az group create `
  --name $RESOURCE_GROUP `
  --location $LOCATION `
  --query '{name:name,location:location}' `
  --output table
```

Register the required resource providers:

```powershell
az provider register --namespace Microsoft.Web --wait
az provider register --namespace Microsoft.OperationalInsights --wait
az provider register --namespace Microsoft.Insights --wait
az provider register --namespace Microsoft.CognitiveServices --wait
```

## 5. Validate the infrastructure

```powershell
./infra/validate.ps1 `
  -ResourceGroup $RESOURCE_GROUP
```

The script compiles [`infra/main.bicep`](../infra/main.bicep) and runs an Azure
Resource Manager what-if without creating resources.

> [!WARNING]
> If the resource group contains an older workshop deployment using the same
> initials, the deployment stack replaces resources previously managed by that
> stack. Use a different resource group or initials if the older environment
> must remain available.

## 6. Deploy the application

```powershell
./infra/deploy.ps1 `
  -ResourceGroup $RESOURCE_GROUP
```

Enter 2-5 letters when prompted. The script lowercases the initials and appends
`01`; for example, `JRF` becomes `jrf01`. For non-interactive use:

```powershell
./infra/deploy.ps1 `
  -ResourceGroup $RESOURCE_GROUP `
  -Initials JRF
```

The script performs four visible stages:

1. Creates or updates the App Service deployment stack.
2. Publishes the .NET 10 application in Release configuration.
3. Waits for the new App Service SCM/Kudu hostname to resolve and accept HTTPS,
   then ZIP-deploys the published output to the Web App.
4. Verifies `/api/health` and the rendered Blazor application.

Rerunning the command with the same initials updates the same environment.
`-SkipCodeDeploy` provisions only infrastructure.

The first deployment can pause at stage 3 while Azure publishes the new SCM
DNS record. The script retries that readiness check for up to five minutes
before failing with the exact hostname, then retries transient Kudu deployment
failures up to three times. It does not enable App Service build automation
because `dotnet publish` has already produced a complete package.

## 7. Record and verify the deployment

The successful command prints:

```text
Infrastructure ready; application deployment verified.
Environment name:  <initials>01
Deployment stack: azstk<initials>01
Resource group:    <resource-group-name>
Application URL:   https://<web-app-name>.azurewebsites.net
App Service plan:  <app-service-plan-name>
Web App:           <web-app-name>
Foundry resource:  <foundry-resource-name>
Foundry project:   support-sim-project
Model deployment:  gpt-5.4-mini
```

Save the environment name, Web App name, Foundry resource, project, and model
deployment names. Parts 5 and 6 assume that the Microsoft Foundry resource,
project, and model deployment already exist; they do not add infrastructure
provisioning work to the Sprint.

The Foundry account uses a system-assigned managed identity, and local key
authentication is disabled on the account. GPT-5.4-mini model version
`2026-03-17` is deployed as `GlobalStandard` with capacity 50 in the resource
group's region (targeting 50,000 tokens per minute). Confirm that the model
deployment is available and quota is approved for that region before
deployment; ARM provisioning will fail if sufficient quota is unavailable.
Model usage can incur charges.
application does not call the model in this foundation deployment, so the Web
App identity is not granted Foundry access yet. A later application Task must
request only the runtime RBAC needed to call the model.

```powershell
$WEB_APP = '<web-app-name>'
$APPLICATION_URL = "https://$WEB_APP.azurewebsites.net"

Invoke-RestMethod -Uri "$APPLICATION_URL/api/health"

az webapp show `
  --resource-group $RESOURCE_GROUP `
  --name $WEB_APP `
  --query '{name:name,state:state,host:defaultHostName,httpsOnly:httpsOnly}' `
  --output table
```

The health response must be `{"status":"healthy"}`, the state must be `Running`,
and `httpsOnly` must be `true`.

## Deployment complete

The Blazor frontend and ASP.NET Core backend now run as one .NET App Service
application. The Microsoft Foundry resource, project, and GPT-5.4-mini model
are provisioned for later use; the application does not integrate with or call
the model yet.

## Public documentation used for validation

- [Deploy a Microsoft Foundry resource by using Bicep](https://learn.microsoft.com/azure/foundry/how-to/create-resource-template)
- [Microsoft Foundry account Bicep reference](https://learn.microsoft.com/azure/templates/microsoft.cognitiveservices/2026-07-01/accounts)
- [Microsoft Foundry project Bicep reference](https://learn.microsoft.com/azure/templates/microsoft.cognitiveservices/2026-07-01/accounts/projects)
- [Microsoft Foundry model deployment Bicep reference](https://learn.microsoft.com/azure/templates/microsoft.cognitiveservices/2026-07-01/accounts/deployments)
- [Foundry Models sold directly by Azure](https://learn.microsoft.com/azure/foundry/foundry-models/concepts/models-sold-directly-by-azure)
- [Region availability for Foundry Models sold by Azure](https://learn.microsoft.com/azure/foundry/foundry-models/concepts/models-sold-directly-by-azure-region-availability)
