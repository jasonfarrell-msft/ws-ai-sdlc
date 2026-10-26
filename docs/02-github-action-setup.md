# Part 2: Configure Automatic Deployment

Run the commands in order in a PowerShell 7 terminal from your fork. This part
connects GitHub Actions to the App Service created in Part 1. Pull requests run
validation; runs on `main` can deploy the application to Azure.

GitHub authenticates to Azure with OpenID Connect (OIDC) and a user-assigned
managed identity. The setup stores no Azure client secret or publishing
credential.

## Prerequisites

- Complete [Part 1](01-azure-foundation.md).
- Use the personal fork created in Part 1.
- Have administrator access to the fork.
- Have permission to create a managed identity and assign the `Website
  Contributor` role to the App Service.
- Install [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell),
  [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), and
  [GitHub CLI](https://cli.github.com/).

## 1. Sign in to GitHub and Azure

Sign in and confirm that GitHub CLI can access your fork:

```powershell
gh auth login
gh auth status
$githubUser = gh api user --jq '.login'
$repository = "$githubUser/ws-ai-sdlc"
gh repo set-default $repository
gh repo view $repository --json nameWithOwner,isFork,parent
```

`nameWithOwner` must be your fork, `isFork` must be `true`, and `parent` must be
`jasonfarrell-msft/ws-ai-sdlc`.

Sign in to the Azure subscription used in Part 1:

```powershell
az login
az account list --output table
$subscriptionId = "<your-subscription-id>"
az account set --subscription $subscriptionId
az account show --output table
```

## 2. Enable the workflow in your fork

Confirm that the latest `.github/workflows/deploy.yml` is on your fork's
`main` branch. If your fork is behind the workshop repository, open its GitHub
page and select **Sync fork** to update it.

Open the fork's Actions page:

```powershell
Start-Process "https://github.com/$repository/actions"
```

If GitHub displays **I understand my workflows, go ahead and enable them**,
select it. Confirm the `Validate and deploy` workflow is listed and enabled:

```powershell
gh workflow list --repo $repository --all
```

## 3. Set the Part 1 deployment values

Enter the same resource group and initials used in Part 1. The initials
determine the environment name (`JRF` becomes `jrf01`):

```powershell
$resourceGroup = "rg-support-desk-demo"
$initials = "JRF"
$environmentName = "$($initials.ToLowerInvariant())01"
$stackName = "azstk$environmentName"

$webAppName = az stack group show `
  --resource-group $resourceGroup `
  --name $stackName `
  --query "outputs.webAppName.value" `
  --output tsv

$webAppName
```

Replace the sample resource group and initials with the values from Part 1.
Confirm that `$webAppName` prints the Web App name before continuing.

## 4. Configure Azure and GitHub

Run the setup script:

```powershell
./infra/configure-github-actions.ps1 `
  -ResourceGroup $resourceGroup `
  -EnvironmentName $environmentName `
  -WebApp $webAppName `
  -Repository $repository
```

The script creates the managed identity, configures its OIDC credential and
App Service role, creates the `workshop-deployment` GitHub environment, limits
that environment to `main`, and sets the workflow's Azure variables.

## 5. Verify the configuration

Confirm the five variables are set in the GitHub environment:

```powershell
gh variable list `
  --repo $repository `
  --env workshop-deployment
```

The list must include:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
AZURE_RESOURCE_GROUP
AZURE_WEB_APP
```

## 6. Run and verify the deployment workflow

Start a manual run on `main`:

```powershell
gh workflow run deploy.yml --repo $repository --ref main
gh run list --repo $repository --workflow deploy.yml --limit 5
```

Open the new run from the fork's Actions page and confirm that the validation,
infrastructure, and deployment jobs succeed. The workflow builds and tests the
.NET application, then deploys it through OIDC and verifies the health endpoint,
rendered page, and Blazor connection.

Confirm the deployed application responds:

```powershell
$applicationUrl = "https://$webAppName.azurewebsites.net"
Invoke-RestMethod "$applicationUrl/api/health"
```

The response must be `{"status":"healthy"}`. Future pull requests run validation;
pushes to `main` that change workflow paths run validation and deploy.

If the deployment fails with authorization denied, wait two minutes for the
Azure role assignment to propagate, then run the workflow again. If GitHub
reports a missing workflow, sync the fork with the latest workshop `main` and
repeat steps 2-6.
