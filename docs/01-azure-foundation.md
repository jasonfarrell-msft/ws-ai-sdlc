# Deploy the Existing Application

## Goal

Deploy the existing Support Desk Simulator to one Azure App Service Web App and
confirm that the frontend and API work through one HTTPS origin. This creates
the starting point for the rest of the workshop.

The deployment creates:

- One Linux App Service Plan on the Basic B1 tier
- One Python 3.13 Web App
- The React production build served by FastAPI
- Same-origin API routes under `/api`
- Log Analytics and workspace-based Application Insights

The application is deployed as source and static files in one ZIP package.
There are no containers, registries, registry credentials, or custom Azure
roles.

> [!IMPORTANT]
> The application uses synthetic data and demo identities. Do not enter real
> customer, credential, personal, or confidential information.

## Architecture

| Component | Azure service | Configuration |
| --- | --- | --- |
| Application | Azure App Service | One Linux Web App on one Basic B1 plan |
| Frontend | FastAPI static-file routes | Compiled React assets with SPA fallback |
| Backend | FastAPI/Uvicorn | Python 3.13; one process; `/api` routes |
| Monitoring | Log Analytics and Application Insights | 30-day workspace retention |
| Deployment | App Service ZIP deployment | Microsoft Entra authentication; no stored deployment secret |

App Service terminates HTTPS and forwards requests to Uvicorn. FastAPI serves
both the API and the compiled frontend, so the browser uses one hostname and no
CORS policy or backend URL configuration is required.

The backend uses process-local synthetic storage. Restarts and deployments reset
ticket changes. The Basic plan uses one instance because multiple instances
would not share this state. App Service and Log Analytics can incur charges;
delete the environment when the workshop is complete.

## Prerequisites

Run every command in this guide from a PowerShell 7 terminal. You need:

- Access to an Azure subscription
- Permission to create resources in a dedicated resource group
- Azure CLI 2.48.1 or newer with Bicep
- Git and GitHub CLI
- Node.js 24 and npm

Python is not required for deployment. App Service installs the backend
requirements during ZIP deployment. Local npm commands honor the configured
global registry policy.

### Prepare the tools

Install any missing prerequisites:

- [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)
- [Git](https://git-scm.com/downloads)
- [GitHub CLI](https://cli.github.com/)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Node.js 24](https://nodejs.org/)

Open a new PowerShell terminal after installation, then install Bicep:

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
az version --query '"azure-cli"' --output tsv
az bicep version
node --version
npm --version
npm config get registry
```

The registry printed by npm must match your organization's local package policy.
Do not replace it with a public registry to bypass that policy.

## 3. Sign in and create the resource group

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

Use a resource group dedicated to the workshop. The deployment uses its location
for the Web App and monitoring resources.

Register the required resource providers:

```powershell
az provider register --namespace Microsoft.Web --wait
az provider register --namespace Microsoft.OperationalInsights --wait
az provider register --namespace Microsoft.Insights --wait
```

## 4. Validate the infrastructure

```powershell
./infra/validate.ps1 `
  -ResourceGroup $RESOURCE_GROUP
```

The script compiles [`infra/main.bicep`](../infra/main.bicep) and runs an Azure
Resource Manager what-if without creating resources.

> [!WARNING]
> If the resource group contains an older workshop deployment using the same
> initials, the deployment stack replaces its Container Apps and registry with
> App Service. The synthetic application has no persistent data, but this is a
> platform migration and causes a maintenance window. Use a new resource group
> or different initials if the older environment must remain available.

## 5. Deploy the application

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
2. Installs locked frontend dependencies and builds the React application.
3. Packages the backend source, requirements, and frontend assets into one ZIP
   and deploys it to the Web App.
4. Verifies `/api/health` and the application root.

Rerunning the command with the same initials updates the same environment.
`-SkipCodeDeploy` provisions only infrastructure and does not deploy a working
application package.

If infrastructure succeeds but application deployment fails, fix the reported
build or deployment error and rerun the same command. Successful infrastructure
is preserved.

## 6. Record and verify the deployment

The successful command prints:

```text
Infrastructure ready; application deployment verified.
Environment name:  <initials>01
Deployment stack: azstk<initials>01
Resource group:    <resource-group-name>
Application URL:   https://<web-app-name>.azurewebsites.net
App Service plan:  <app-service-plan-name>
Web App:           <web-app-name>
```

Save the environment name and Web App name. Part 2 uses them to configure
automatic deployment.

Open the application URL and confirm that the synthetic ticket queue and
knowledge library work. Then verify Azure and the API:

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

The health response must be `{"status":"healthy"}`, the Web App state must be
`Running`, and `httpsOnly` must be `true`.

## Cleanup

Remove only the generated workshop environment while preserving the resource
group:

```powershell
./infra/destroy.ps1 `
  -ResourceGroup $RESOURCE_GROUP `
  -EnvironmentName '<initials>01' `
  -ConfirmEnvironment '<initials>01'
```

## Deployment complete

The existing frontend and API now run as one code-based App Service application.
The AI feature is intentionally not present yet.
