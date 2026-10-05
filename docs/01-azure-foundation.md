# Deploy the Existing Application

## Goal

Deploy the existing Support Desk Simulator to Azure and confirm that its
frontend and API are accessible through one HTTPS origin. This creates the
starting point for the rest of the workshop.

The deployment creates:

- A React frontend served by nginx in Azure Container Apps
- A FastAPI/Uvicorn backend in a separate Azure Container App on Python 3.11
- An Azure Container Registry (ACR) for both images
- Same-origin API routing under `/api` through nginx
- Log Analytics and workspace-based Application Insights

> [!IMPORTANT]
> The application uses synthetic data and demo identities. Do not enter real
> customer, credential, personal, or confidential information.

## Architecture

| Component | Azure service | Configuration |
| --- | --- | --- |
| Frontend | Azure Container Apps | Vite assets served by nginx; public HTTPS; 1-2 replicas |
| Backend | Azure Container Apps | FastAPI/Uvicorn on Python 3.11; public HTTPS; one replica |
| Images | Azure Container Registry Basic | Remote Linux/AMD64 builds; managed identity pulls |
| Routing | nginx reverse proxy | Same-origin `/api`; backend HTTPS host and SNI |
| Monitoring | Log Analytics and Application Insights | Container console/system logs; 30-day workspace retention |
| Deployment role | Custom Azure role definition | Build images and update apps in the dedicated resource group |

The deployment also creates a custom Azure role named
`Support Desk Container App Deployer <environment-name>`. It grants the
permissions needed to upload build sources, schedule ACR builds, read build
status/logs, and update Container Apps. Part 2 assigns this role to a workflow
identity. Each app has a system-assigned identity with `AcrPull` on the registry;
the registry admin account and anonymous pulls are disabled.

Both apps share a Container Apps environment and use managed HTTPS ingress,
with HTTP forwarded to port 80 inside each container. Both endpoints are public;
the browser normally calls the frontend's `/api` proxy. This is a synthetic,
non-production workshop, not a private-network production architecture.

The backend runs one replica and one Uvicorn worker because its ticket store
is process-local. A restart or revision change resets it. The frontend can scale
to two replicas. Deployment updates the backend before the frontend, but the
two updates are **not atomic**; API changes must remain backward compatible.

Container Apps compute, ACR storage/builds, and Log Analytics ingestion can incur
charges. One minimum replica per app avoids cold starts but is not a free-tier
guarantee. Delete the environment when finished. Application Insights is
provisioned and its connection string is passed to the API; automatic request
telemetry requires SDK instrumentation that this baseline does not configure.

## Prerequisites

Use a PowerShell 7 terminal on Windows, macOS, or Linux. You need:

- Access to an Azure subscription
- Permission to create resources, custom role definitions, and role assignments
  in a dedicated resource group
- Azure CLI 2.48.1 or newer with Bicep
- Git and GitHub CLI
- PowerShell 7
- Python 3.11 and Node.js 22 or newer with npm for local development
- Docker with Compose for local container verification (optional for Azure builds)

Azure image builds run in ACR, so deployment does not require local Python,
Node.js, Docker, or the Static Web Apps CLI. Deployment uses Microsoft Entra
authentication, not a stored client secret or registry password.

### Install the tools

Skip any tool that you already have at the required version. Step 2 verifies
the result.

On Windows:

```powershell
winget install --exact --id Git.Git
winget install --exact --id GitHub.cli
winget install --exact --id Microsoft.PowerShell
winget install --exact --id Python.Python.3.11
winget install --exact --id OpenJS.NodeJS.LTS
winget install --exact --id Microsoft.AzureCLI
```

On macOS:

```powershell
brew install git gh python@3.11 node azure-cli
brew install --cask powershell
```

On Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y git curl software-properties-common
sudo snap install powershell --classic
sudo snap install gh
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt-get install -y python3.11 python3.11-venv
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

Open a new PowerShell 7 terminal so that the updated `PATH` applies, then add
Bicep and install or update the Container Apps extension on every platform:

```powershell
az bicep install
az extension add --name containerapp --upgrade
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
pwsh --version
node --version
npm --version
az version --query '"azure-cli"' --output tsv
az bicep version
az containerapp --help
```

The API Dockerfile selects Python 3.11 regardless of your local interpreter.
The frontend build stage uses Node.js 24. ACR builds both Linux/AMD64 images
from their Dockerfiles.

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

Use a resource group dedicated to the workshop. The deployment and validation
scripts use its location for the apps, registry, and monitoring resources.
Choose a region that supports Container Apps and check subscription quotas.

Register the resource providers if they are not already registered:

```powershell
az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.ContainerRegistry --wait
az provider register --namespace Microsoft.OperationalInsights --wait
az provider register --namespace Microsoft.Insights --wait
```

## 4. Validate the infrastructure

```powershell
pwsh ./infra/validate.ps1 `
  -ResourceGroup $RESOURCE_GROUP
```

The script compiles [`infra/main.bicep`](../infra/main.bicep) and runs an Azure
Resource Manager what-if without creating resources.

The current Bicep CLI may warn that the documented GA Container Apps API
`2026-07-01` has no local type definitions (`BCP081`). Compilation still
succeeds; ARM what-if remains necessary to validate resource properties and
regional availability.

Before Azure deployment, if Docker is available, verify both images locally:

```powershell
$env:NPM_CONFIG_REGISTRY = npm config get registry
docker compose up --build --detach --wait
python ./infra/test-containers.py
docker compose down
```

Use `python3` instead of `python` if that is your installed command. The smoke
test checks direct and proxied health, frontend headers, API errors, and a
synthetic ticket creation, assignment, and resolution. It does not use real
credentials or customer data.

Local npm installation follows the global corporate registry policy. The
environment variable passes that registry URL into the Docker build without
changing global npm configuration. Do not use it for tokens or credential-bearing
URLs. GitHub-hosted Actions and Azure remote builds use public npm. If a corporate
feed lacks a required package, have the feed administrator resolve it rather
than bypassing the local policy.

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
2. Provisions ACR, the Container Apps environment, both apps, monitoring,
   managed identities, and image-pull role assignments with Bicep.
3. Builds the backend Linux/AMD64 image in ACR with an environment/timestamp tag.
4. Updates the backend app to that image.
5. Builds the locked frontend dependencies and nginx image in ACR.
6. Updates the frontend app, whose runtime `BACKEND_URL` points at the API.
7. Checks the backend health, proxied `/api/health`, and application root.

The first infrastructure deployment uses a public bootstrap image so Azure can
create system-assigned identities before private image pulls. The script then
replaces it with application images. On reruns it preserves the existing image
references during infrastructure updates. `-SkipCodeDeploy` provisions only
infrastructure (or preserves existing code); a fresh environment using that
switch is not a running Support Desk application.

> [!WARNING]
> Rerunning against an existing Static Web Apps deployment stack replaces the
> old hosting resources. Review what-if first and allow a maintenance window;
> remove any old `Support Desk SWA Deployer <environment>` role assignments
> before updating the stack so Azure can delete the obsolete role definition.
> The old deployment token and Functions package are not reused. After the
> migration, rerun Part 2 with the Container Apps and registry names.

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
Infrastructure ready; application deployment verified.
Environment name:  <initials>01
Deployment stack: azstk<initials>01
Resource group:    <resource-group-name>
Application URL:   https://<frontend-host>.azurecontainerapps.io
Frontend App:     ca-web-<initials>01
Backend App:      ca-api-<initials>01
Container Registry: <registry-name>
```

Save the environment name, deployment stack, application URL, both app names,
and registry name. Part 2 uses those names to configure GitHub.

Open the application URL and confirm that the synthetic ticket queue and
knowledge library work. Then verify the API:

```powershell
Invoke-RestMethod -Uri '<application-url>/api/health'

az containerapp show `
  --resource-group $RESOURCE_GROUP `
  --name '<frontend-app-name>' `
  --query '{name:name,host:properties.configuration.ingress.fqdn}' `
  --output table
```

The health response must be `{"status":"healthy"}`.

## Deployment complete

The existing application is now deployed as two containerized services with
same-origin browser routing. The AI feature is intentionally not present yet.
