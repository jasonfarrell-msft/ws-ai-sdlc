# Section 1: Deploy the Existing Application

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

The deployment creates a fresh, isolated deployment stack inside an existing
resource group that you provide. Every regional component uses that resource
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
- `Owner`, or `Contributor` plus `Role Based Access Control Administrator`, on
  an existing resource group
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

## 4. Confirm the target resource group

Set the name of an existing resource group:

```powershell
$RESOURCE_GROUP = '<resource-group-name>'
```

Confirm that it exists in the active subscription:

```powershell
az group show `
  --name $RESOURCE_GROUP `
  --query '{name:name,location:location}' `
  --output table
```

Record the location returned by Azure. The scripts read this value directly
from the resource group and use it for every regional component. You do not
provide a separate location parameter.

> [!NOTE]
> The deployment creates a separate deployment stack inside this resource
> group. It does not replace other workshop environments in the group.

## 5. Validate the infrastructure

From the repository root, run:

```powershell
pwsh ./infra/validate.ps1 `
  -ResourceGroup $RESOURCE_GROUP
```

The validation script:

1. Selects the target Azure subscription.
2. Reads the location from the existing resource group.
3. Compiles [`infra/main.bicep`](../infra/main.bicep).
4. Runs an Azure resource-group what-if operation with a temporary random
   identifier.
5. Creates no resources.

Confirm that the command prints:

```text
Bicep compilation passed.
```

Review the JSON what-if output. A fresh run should contain `Create` values in
the `changes[].changeType` fields and newly generated resource names.

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
18-character value after that prefix. Use it with the cleanup command at the
end of this guide, then rerun the deployment.

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

## Section 1 complete

Your existing Support Desk application is now deployed and accessible in
Azure. Keep the frontend URL, backend URL, and run identifier available for the
remaining workshop sections.

The AI feature is intentionally not present yet. A later section will extend
this working starting point.

# Section 2: Configure Automatic Deployment

## Goal

In this section, you connect the GitHub Actions workflows to the Azure resources
created in Section 1. After setup, a completed backend or frontend change merged
to `main` automatically deploys the changed component.

The setup uses GitHub OIDC and Azure managed identities. It does not create or
store an Azure client secret, registry password, or App Service publishing
credential.

## Prerequisites

Before continuing:

- Complete Section 1 and keep its recorded deployment values.
- Use a PowerShell 7 terminal.
- Use the personal fork created and cloned in Section 1.
- Have permission to create managed identities and role assignments at the
  three Azure resource scopes.
- Confirm the backend and frontend workflow files are on your fork's `main`
  branch.

## 1. Check the required access

Confirm that Azure CLI is signed in to the subscription used in Section 1:

```powershell
az account show `
  --query '{subscription:name,id:id,user:user.name}' `
  --output table
```

Confirm GitHub CLI is signed in and that the current repository is your fork:

```powershell
gh auth status
gh repo set-default origin

$GITHUB_REPOSITORY = gh repo view `
  --json nameWithOwner `
  --jq .nameWithOwner

gh repo view `
  $GITHUB_REPOSITORY `
  --json nameWithOwner,isFork,viewerCanAdminister,parent `
  --jq '{
    repository:.nameWithOwner,
    isFork:.isFork,
    admin:.viewerCanAdminister,
    upstream:.parent.nameWithOwner
  }'
```

The GitHub command must show `isFork: true`, `admin: true`, and upstream
`jasonfarrell-msft/ws-ai-sdlc`.

## 2. Set the Section 1 deployment values

Use the values printed by `infra/deploy.ps1`:

```powershell
$RESOURCE_GROUP = '<resource-group-name>'
$RUN_IDENTIFIER = '<18-character-run-identifier>'
$AZURE_CONTAINER_REGISTRY = '<registry-name>'
$AZURE_CONTAINER_APP = '<container-app-name>'
$AZURE_APP_SERVICE = '<frontend-app-name>'
$AZURE_BACKEND_URL = 'https://<backend-app>.<environment>.azurecontainerapps.io'
```

The backend URL must use HTTPS and must not end with `/`.

## 3. Configure Azure and GitHub access

Run the setup script from the repository root:

```powershell
pwsh ./infra/configure-github-actions.ps1 `
  -ResourceGroup $RESOURCE_GROUP `
  -EnvironmentName $RUN_IDENTIFIER `
  -ContainerRegistry $AZURE_CONTAINER_REGISTRY `
  -ContainerApp $AZURE_CONTAINER_APP `
  -AppService $AZURE_APP_SERVICE `
  -BackendUrl $AZURE_BACKEND_URL `
  -Repository $GITHUB_REPOSITORY
```

The script creates and configures:

| Item | Purpose |
| --- | --- |
| Backend deployment identity | Builds in ACR and updates only the Container App |
| Frontend deployment identity | Updates only the App Service |
| Two OIDC federated credentials | Let GitHub authenticate without stored secrets |
| `workshop-backend` environment | Supplies backend Azure resource variables |
| `workshop-frontend` environment | Supplies frontend Azure resource variables |
| `AZURE_BACKEND_URL` repository variable | Configures the frontend production build |
| `main` environment branch policies | Prevent non-`main` deployment jobs from using either identity |

The script also verifies that the target is your fork of the workshop
repository, enables GitHub Actions for the fork, and enables both workflows.

No manual deployment approval is configured. The path-filtered workflows deploy
automatically after a matching change reaches `main`.

The script is safe to run again with the same values if setup is interrupted.

## 4. Verify the configuration

Confirm the backend environment variables:

```powershell
gh variable list `
  --repo $GITHUB_REPOSITORY `
  --env workshop-backend
```

Expected names:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
AZURE_RESOURCE_GROUP
AZURE_CONTAINER_REGISTRY
AZURE_CONTAINER_APP
```

Confirm the frontend environment variables:

```powershell
gh variable list `
  --repo $GITHUB_REPOSITORY `
  --env workshop-frontend
```

Expected names:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
AZURE_RESOURCE_GROUP
AZURE_APP_SERVICE
```

Confirm the repository variable:

```powershell
gh variable list `
  --repo $GITHUB_REPOSITORY |
  Select-String '^AZURE_BACKEND_URL'
```

Confirm that both environments allow only `main`:

```powershell
foreach ($environmentName in 'workshop-backend', 'workshop-frontend') {
  gh api `
    "repos/$GITHUB_REPOSITORY/environments/$environmentName/deployment-branch-policies" `
    --jq '.branch_policies[] | {name:name,type:type}'
}
```

Each environment must return one branch policy with name `main` and type
`branch`.

Confirm that both workflows are active in your fork:

```powershell
gh workflow list `
  --repo $GITHUB_REPOSITORY `
  --all
```

## 5. Test the deployment loop

The workflows normally run automatically when matching files change on `main`.
For an initial access check, start each workflow manually from `main`:

```powershell
gh workflow run backend.yml `
  --repo $GITHUB_REPOSITORY `
  --ref main

gh workflow run frontend.yml `
  --repo $GITHUB_REPOSITORY `
  --ref main
```

List the runs:

```powershell
gh run list `
  --repo $GITHUB_REPOSITORY `
  --limit 10
```

Both runs should complete successfully without an approval step. The backend
workflow builds and deploys a digest-pinned image, and the frontend workflow
builds and ZIP deploys the site. Each workflow verifies its deployed endpoint
before reporting success.

Azure role assignments can take several minutes to propagate. If either run
fails with an authorization error, wait two minutes, copy its run ID from the
list, and retry it:

```powershell
gh run rerun '<run-id>' `
  --repo $GITHUB_REPOSITORY
```

## Section 2 complete

The deployment loop is ready. Pull requests validate changes without Azure
access. After completed work is merged to `main`, backend changes deploy to the
Container App and frontend changes deploy to App Service automatically.

## Optional: remove your isolated environment

Cleanup is not part of Section 1 or Section 2. When you no longer need this
deployment, use the exact command printed by `deploy.ps1`:

```powershell
pwsh ./infra/destroy.ps1 `
  -ResourceGroup $RESOURCE_GROUP `
  -EnvironmentName $RUN_IDENTIFIER `
  -ConfirmEnvironment $RUN_IDENTIFIER
```

This deletes only the deployment stack associated with that run identifier. It
preserves the resource group and other workshop environments.

The two deployment identities were created outside the deployment stack. After
the stack is deleted, remove them:

```powershell
az identity delete `
  --resource-group $RESOURCE_GROUP `
  --name "id-gha-be-$RUN_IDENTIFIER"

az identity delete `
  --resource-group $RESOURCE_GROUP `
  --name "id-gha-fe-$RUN_IDENTIFIER"
```

After cleanup, update or remove the two GitHub environments and the
`AZURE_BACKEND_URL` repository variable in your fork so later workflow runs do
not reference deleted Azure resources.
