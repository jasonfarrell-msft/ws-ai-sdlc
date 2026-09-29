# Deploy the Existing Application

## Goal

In this section, you deploy the existing Support Desk Simulator to Azure and
confirm that it is accessible. This creates the starting point for the rest of
the workshop.

You do not change the application code or add the AI feature in this section.

By the end of Section 1, you will have:

- A React frontend running on Azure App Service
- A FastAPI backend running on Azure Container Apps
- An Azure Container Registry with admin and anonymous access disabled
- Managed identity access for the Container App to pull its image
- Log Analytics and Application Insights for platform telemetry
- Frontend and backend URLs that you have verified

## Architecture

The deployment creates a fresh, isolated deployment stack inside a dedicated
resource group that you create. Every regional component uses that resource
group's location.

| Component | Azure service | Configuration |
| --- | --- | --- |
| Frontend | Linux App Service | S1 plan |
| Backend | Azure Container Apps | One always-ready replica |
| Container images | Azure Container Registry | Basic tier |
| Image authentication | User-assigned managed identity | Registry-scoped `AcrPull` |
| Monitoring | Log Analytics and Application Insights | 30-day workspace retention |

Each run uses a new random identifier. This prevents naming collisions and
keeps one workshop deployment separate from another.

> [!IMPORTANT]
> The application uses synthetic data and demo identities. Do not enter real
> customer, credential, personal, or confidential information.

## Prerequisites

Complete these steps from a PowerShell 7 terminal on Windows, macOS, or Linux.

You need:

- Access to an Azure subscription
- `Contributor` on the target subscription so you can create the dedicated
  resource group and its application resources
- `Role Based Access Control Administrator` on the target subscription, or on
  the dedicated workshop resource group after it is created, so the deployment
  can grant the managed identity registry-scoped `AcrPull`
- Azure CLI 2.48.1 or newer
- The Azure CLI Bicep component
- Git
- GitHub CLI
- A GitHub account that can create a personal fork
- PowerShell 7
- Node.js 22 or newer and npm 10.9 or newer

The deployment uses Microsoft Entra authentication. It does not require an ACR
admin password or App Service publishing credentials.

## 1. Fork and clone the repository

Sign in to GitHub CLI:

```powershell
gh auth login
gh auth status
```

Create a personal fork and clone it:

```powershell
gh repo fork jasonfarrell-msft/ws-ai-sdlc `
  --clone `
  --default-branch-only
Set-Location ws-ai-sdlc
```

GitHub CLI configures your fork as `origin` and the workshop source repository
as `upstream`.

Make your fork the default repository for GitHub CLI and record its
`owner/repository` value:

```powershell
gh repo set-default origin

$GITHUB_REPOSITORY = gh repo view `
  --json nameWithOwner `
  --jq .nameWithOwner
Write-Host $GITHUB_REPOSITORY
```

Confirm the repository is your fork and both remotes are present:

```powershell
gh repo view `
  $GITHUB_REPOSITORY `
  --json nameWithOwner,isFork,parent `
  --jq '{
    repository:.nameWithOwner,
    isFork:.isFork,
    upstream:.parent.nameWithOwner
  }'

git remote -v
```

Confirm that `isFork` is `true`, `upstream` is
`jasonfarrell-msft/ws-ai-sdlc`, `origin` points to your fork, and `upstream`
points to the workshop source repository.

If you already created and cloned the fork, do not run the fork command again.
Change to the existing `ws-ai-sdlc` directory and continue with
`gh repo set-default origin`.

## 2. Check the required tools

Run:

```powershell
git --version
gh --version
pwsh --version
az version --query '"azure-cli"' --output tsv
az bicep version
node --version
npm --version
```

Confirm that:

- Git is installed.
- GitHub CLI is installed.
- PowerShell is version 7 or newer.
- Azure CLI is version 2.48.1 or newer.
- Node.js is version 22 or newer.
- npm is version 10.9 or newer.
- The Azure CLI Bicep component is installed.
- Every command completes without a "command not found" error.

## 3. Sign in to Azure

Sign in:

```powershell
az login
```

If necessary, select the subscription that contains your lab resource group:

```powershell
az account set `
  --subscription '<subscription-id>'
```

Confirm the active subscription:

```powershell
az account show `
  --query '{name:name,id:id,user:user.name}' `
  --output table
```

## 4. Create the target resource group

Choose a name and Azure region for a dedicated workshop resource group:

```powershell
$RESOURCE_GROUP = '<resource-group-name>'
$LOCATION = '<azure-region>'
```

Create the resource group:

```powershell
az group create `
  --name $RESOURCE_GROUP `
  --location $LOCATION `
  --query '{name:name,location:location}' `
  --output table
```

The command returns the resource group's name and location. The deployment
scripts read this location directly and use it for every regional component.
Confirm that the returned location matches `$LOCATION`. You do not provide a
separate location parameter to the deployment scripts.

> [!NOTE]
> Use a new resource group dedicated to this workshop. The deployment creates
> a separate deployment stack inside it, which keeps the workshop resources
> isolated and simplifies cleanup.

## 5. Validate the infrastructure

From the repository root, run:

```powershell
pwsh ./infra/validate.ps1 `
  -ResourceGroup $RESOURCE_GROUP
```

The validation script:

1. Selects the target Azure subscription.
2. Reads the location from the target resource group.
3. Compiles [`infra/main.bicep`](../infra/main.bicep).
4. Asks Azure Resource Manager to evaluate the deployment and summarize the
   proposed changes without applying them.
5. Creates no resources.

Confirm that the command prints:

```text
Bicep compilation passed.
Infrastructure validation passed. Planned changes: Create: <count>.
```

The exact count can change as the workshop infrastructure evolves. A new
workshop resource group should report only planned creates. The validation is
not an emptiness check; it confirms that the template compiles and that Azure
Resource Manager can evaluate the deployment in the selected subscription,
resource group, and region.

You may see a non-blocking `BCP081` warning for the Log Analytics API version.
Azure validation accepts this registered API version.

## 6. Deploy the starting application

Run:

```powershell
pwsh ./infra/deploy.ps1 `
  -ResourceGroup $RESOURCE_GROUP
```

The deployment usually takes 10-20 minutes. The script:

1. Generates a unique 18-character run identifier.
2. Creates an isolated Azure deployment stack.
3. Provisions the App Service, Container Apps, ACR, managed identity, and
   monitoring resources.
4. Builds the FastAPI container image in ACR.
5. Resolves the image digest and deploys the digest-pinned image.
6. Builds the React frontend with the generated backend URL.
7. Deploys the frontend to App Service using Microsoft Entra authentication.
8. Checks the frontend and backend endpoints.

Do not close the terminal while the script is running.

### If deployment stops before completion

The infrastructure may already exist if the script fails during the image
build, frontend build, or endpoint checks. Before running `deploy.ps1` again,
list the deployment stacks:

```powershell
az stack group list `
  --resource-group $RESOURCE_GROUP `
  --query '[].{name:name,state:provisioningState}' `
  --output table
```

Find the new stack whose name starts with `azstk`. The run identifier is the
18-character value after that prefix. Record the stack name and state for
troubleshooting, then rerun the deployment.

## 7. Record the deployment output

When deployment succeeds, the script prints values similar to:

```text
Deployment complete.
Run identifier:  <18-character-identifier>
Deployment stack: azstk<18-character-identifier>
Resource group:   <resource-group-name>
Location:         <resource-group-location>
Frontend URL:     https://<app-name>.azurewebsites.net
Backend URL:      https://<app-name>.<environment>.azurecontainerapps.io
Frontend App:     <frontend-app-name>
Container App:    <container-app-name>
Registry:         <registry-name>
```

Save the following values for later workshop sections:

| Value | Your deployment |
| --- | --- |
| Run identifier | |
| Deployment stack | |
| Frontend URL | |
| Backend URL | |
| Frontend App | |
| Container App | |
| Registry | |

## 8. Verify the deployed application

Open the frontend URL printed by the deployment script.

Confirm that:

- The page title is **Support Desk Simulator**.
- The synthetic ticket queue is visible.
- You can switch between the requester and support-agent demo roles.
- The knowledge library opens.

> [!NOTE]
> This Section 1 deployment uses its own generated App Service URL. It is
> separate from the facilitator's pre-existing workshop URL.

Next, append `/api/health` to the backend URL or run:

```powershell
Invoke-RestMethod -Uri '<backend-url>/api/health'
```

Expected response:

```json
{"status":"healthy"}
```

Finally, confirm that Azure reports both application resources as healthy:

```powershell
az webapp show `
  --resource-group $RESOURCE_GROUP `
  --name '<frontend-app-name>' `
  --query '{state:state,httpsOnly:httpsOnly}' `
  --output table

az containerapp show `
  --resource-group $RESOURCE_GROUP `
  --name '<container-app-name>' `
  --query '{state:properties.provisioningState,fqdn:properties.configuration.ingress.fqdn}' `
  --output table
```

The App Service state should be `Running`, `httpsOnly` should be `true`, and
the Container App provisioning state should be `Succeeded`.

## Deployment complete

Your existing Support Desk application is now deployed and accessible in
Azure. Keep the frontend URL, backend URL, and run identifier available for the
remaining workshop sections.

The AI feature is intentionally not present yet. A later section will extend
this working starting point.

Keep the dedicated resource group until you complete the workshop. When you no
longer need the environment or its saved deployment values, delete the group
and all workshop resources inside it:

```powershell
az group delete `
  --name $RESOURCE_GROUP `
  --yes
```
