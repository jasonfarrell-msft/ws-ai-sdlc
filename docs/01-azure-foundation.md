# Part 1: Deploy the Support Desk Simulator

Run the commands in order in a PowerShell 7 terminal. This part creates an
Azure App Service, monitoring resources, and a Microsoft Foundry resource with
the model deployment prepared for later workshop parts. The application does
not call the model yet.

> [!IMPORTANT]
> The application uses synthetic data and demo identities. Do not enter real
> customer, credential, personal, or confidential information.

## Prerequisites

Install:

- [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)
- [Azure CLI 2.48.1 or later](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)
- [Git](https://git-scm.com/downloads)
- [GitHub CLI](https://cli.github.com/)

You also need an Azure subscription where you can create a resource group,
register resource providers, create resources, and assign roles. The deployment
creates a GPT-5.4-mini `GlobalStandard` deployment with capacity 50
(50,000 tokens per minute). Before continuing, confirm [regional
availability](https://learn.microsoft.com/azure/foundry/foundry-models/concepts/models-sold-directly-by-azure-region-availability)
and [quota](https://learn.microsoft.com/azure/foundry/openai/quotas-limits) for
your chosen region. Azure resource and model usage can incur charges.

## 1. Sign in and fork the repository

Sign in to GitHub and fork the workshop repository:

```powershell
gh auth login
gh repo fork jasonfarrell-msft/ws-ai-sdlc --clone
Set-Location ws-ai-sdlc
```

Sign in to Azure and select the subscription you will use:

```powershell
az login
az account list --output table
$subscriptionId = "<your-subscription-id>"
az account set --subscription $subscriptionId
az account show --output table
```

## 2. Check tools and run the application locally

Confirm the installed versions. `dotnet --version` must report `10.0.300`, as
selected by [`global.json`](../global.json).

```powershell
az version --query '"azure-cli"' --output tsv
az bicep install
az bicep version
dotnet --version
dotnet dev-certs https --trust
git --version
gh --version
```

Restore, test, and run the application:

```powershell
dotnet restore SupportDesk.slnx --locked-mode
dotnet test SupportDesk.slnx --configuration Release --no-restore
dotnet run --project src/SupportDesk.App/SupportDesk.App.csproj --launch-profile https
```

Open `https://localhost:7241` and confirm the ticket and knowledge pages load.
Stop the application with <kbd>Ctrl</kbd>+<kbd>C</kbd>.

## 3. Create a resource group

Choose a region with the required GPT-5.4-mini quota. Use a new, dedicated
resource group for this workshop:

```powershell
$resourceGroup = "rg-support-desk-demo"
$location = "eastus2"
$initials = "JRF"

az group create `
  --name $resourceGroup `
  --location $location `
  --output table
```

## 4. Validate the infrastructure

This compiles the Bicep template and shows the planned Azure changes without
creating them:

```powershell
./infra/validate.ps1 -ResourceGroup $resourceGroup
```

Review the result before deploying. Use a different resource group or initials
if you need to preserve an existing workshop deployment.

## 5. Deploy

Deploy the infrastructure, publish the application, and verify the live site:

```powershell
./infra/deploy.ps1 -ResourceGroup $resourceGroup -Initials $initials
```

The script creates the deployment stack, publishes the application, ZIP-deploys
it to App Service, and checks the health endpoint, rendered page, and Blazor
connection. The first deployment can take several minutes while Azure creates
the resources and registers the App Service deployment endpoint.

## 6. Verify and save the outputs

The script prints the application URL, resource names, and Foundry endpoint.
Check the health response and Web App configuration:

```powershell
$environmentName = "$($initials.ToLowerInvariant())01"
$stackName = "azstk$environmentName"
$webAppName = az stack group show `
  --resource-group $resourceGroup `
  --name $stackName `
  --query "outputs.webAppName.value" `
  --output tsv
$applicationUrl = az stack group show `
  --resource-group $resourceGroup `
  --name $stackName `
  --query "outputs.applicationUrl.value" `
  --output tsv

Invoke-RestMethod "$applicationUrl/api/health"
az webapp show `
  --resource-group $resourceGroup `
  --name $webAppName `
  --query "{state:state,httpsOnly:httpsOnly}" `
  --output table
```

The health response must be `{"status":"healthy"}`; the Web App state must be
`Running` and `httpsOnly` must be `true`. Keep the resource group and deployment
outputs for Parts 2-6. The Foundry endpoint is a nonsecret resource identifier;
do not hardcode it in source code.
