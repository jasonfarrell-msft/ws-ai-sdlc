# Deploy the Existing Application

## Goal

Deploy the existing Support Desk Simulator to Azure and confirm that its
frontend and API are accessible through one HTTPS origin. This creates the
starting point for the rest of the workshop.

The deployment creates:

- A React frontend on Azure Static Web Apps
- A FastAPI application hosted by managed Azure Functions on Python 3.11
- Same-origin API routing under `/api`
- Log Analytics and workspace-based Application Insights

> [!IMPORTANT]
> The application uses synthetic data and demo identities. Do not enter real
> customer, credential, personal, or confidential information.

## Architecture

| Component | Azure service | Configuration |
| --- | --- | --- |
| Frontend | Azure Static Web Apps | Vite static production build |
| Backend | Static Web Apps managed Functions | Python 3.11 and FastAPI ASGI |
| Routing | Static Web Apps reverse proxy | Fixed same-origin `/api` route |
| Monitoring | Log Analytics and Application Insights | 30-day workspace retention |
| Deployment role | Custom Azure role definition | Least-privilege token retrieval |

The deployment also creates a custom Azure role named
`Support Desk SWA Deployer <environment-name>`. It grants only the permissions
needed to read the Static Web App and retrieve its deployment token. Part 2
assigns this role to a workflow identity, so no deployment token or client
secret is ever stored.

The workshop uses the Free plan and disables staging environments. Static Web
Apps supplies managed HTTPS. The deployment script uploads the frontend and API
together, so users never receive a frontend that points at a different backend
revision.

## Prerequisites

Use a PowerShell 7 terminal on Windows, macOS, or Linux. You need:

- Access to an Azure subscription
- Permission to create resources in a dedicated resource group
- Azure CLI 2.48.1 or newer with Bicep
- Git and GitHub CLI
- PowerShell 7
- Python 3.11
- Node.js 22 or newer and npm
- Azure Static Web Apps CLI 2.0.10 or newer

The deployment uses Microsoft Entra authentication. It stores no Azure client
secret or Static Web Apps deployment token.

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
pwsh --version
node --version
npm --version
swa --version
az version --query '"azure-cli"' --output tsv
az bicep version
```

`deploy.ps1` packages the API with `python3.11` when that command exists and
otherwise falls back to `python`, so check whichever one you have:

```powershell
python3.11 --version
python --version
```

`deploy.ps1` calls `swa` directly, so install or update the Static Web Apps CLI
globally if the command is missing or older than 2.0.10:

```powershell
npm install --global @azure/static-web-apps-cli@latest
swa --version
```

The interpreter that `deploy.ps1` selects must report 3.11 exactly. Static Web
Apps managed functions do not support Python 3.12 or later, and `deploy.ps1`
stops if it finds another version.

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

Use a resource group dedicated to the workshop. The monitoring resources use
the resource group location. The Static Web App uses `eastus2` by default
because Static Web Apps supports a defined set of deployment regions; change
`staticWebAppLocation` in
[`infra/main.parameters.json`](../infra/main.parameters.json) if needed.

## 4. Validate the infrastructure

```powershell
pwsh ./infra/validate.ps1 `
  -ResourceGroup $RESOURCE_GROUP
```

The script compiles [`infra/main.bicep`](../infra/main.bicep) and runs an Azure
Resource Manager what-if without creating resources.

## 5. Deploy the application

```powershell
pwsh ./infra/deploy.ps1 `
  -ResourceGroup $RESOURCE_GROUP
```

Enter 2-5 letters when prompted. The script lowercases the initials and appends
`01`; for example, `JRF` becomes `jrf01`. For non-interactive use:

```powershell
pwsh ./infra/deploy.ps1 `
  -ResourceGroup $RESOURCE_GROUP `
  -Initials JRF
```

The script:

1. Creates or updates an isolated Azure deployment stack.
2. Provisions Static Web Apps and monitoring resources with Bicep.
3. Packages Python 3.11-compatible Linux API dependencies.
4. Installs the locked frontend dependencies and builds the Vite application.
5. Retrieves the generated Static Web Apps deployment token into process
   memory.
6. Atomically uploads the frontend and managed Python API.
7. Restores the previous token value and removes the temporary API package.
8. Checks `/api/health` and then the application root.

Step 3 downloads Linux `manylinux` wheels for Python 3.11 rather than wheels for
your own operating system, because `swa deploy` uploads the API exactly as
packaged and never installs dependencies in Azure.

Rerunning the command with the same initials updates the same environment.

If provisioning succeeds but code deployment fails, fix the reported problem
and rerun the same command. To remove the environment instead:

```powershell
pwsh ./infra/destroy.ps1 `
  -ResourceGroup $RESOURCE_GROUP `
  -EnvironmentName '<initials>01' `
  -ConfirmEnvironment '<initials>01'
```

`destroy.ps1` removes the deployment role assignment before it deletes the
stack, then deletes the workflow identity that Part 2 created. Run it from this
part even if you completed Part 2.

## 6. Record and verify the deployment

The successful command prints:

```text
Deployment complete.
Environment name:  <initials>01
Deployment stack: azstk<initials>01
Resource group:    <resource-group-name>
Application URL:   https://<generated-host>.azurestaticapps.net
Static Web App:    <resource-name>
```

Save the environment name, deployment stack, application URL, and Static Web
App resource name.

Open the application URL and confirm that the synthetic ticket queue and
knowledge library work. Then verify the API:

```powershell
Invoke-RestMethod -Uri '<application-url>/api/health'

az staticwebapp show `
  --resource-group $RESOURCE_GROUP `
  --name '<static-web-app-name>' `
  --query '{name:name,host:defaultHostname,sku:sku.name}' `
  --output table
```

The health response must be `{"status":"healthy"}`.

## Deployment complete

The existing application is now deployed through one standard, repeatable
Static Web Apps deployment. The AI feature is intentionally not present yet.
