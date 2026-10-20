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
- A system-assigned App Service identity with the `Cognitive Services OpenAI User`
  role on the Foundry account
- The `StatusAssigneeInterpreter__Endpoint` Web App setting containing the
  generated Foundry project endpoint

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

## 1. Fork and clone the repository

From the directory where you want the repository cloned, run:

```powershell
gh repo fork jasonfarrell-msft/ws-ai-sdlc --clone
Set-Location ws-ai-sdlc
```

## 2. Check the required tools

`dotnet --version` must report `10.0.300` or a compatible later .NET 10 patch
selected by [`global.json`](../global.json).

No Node.js or npm check is required. The repository contains no npm packages and
does not contact an npm registry.

## 3. Restore, test, and run locally

Open the HTTPS URL printed by ASP.NET Core. Confirm the ticket and knowledge
workflows, then stop the local process with <kbd>Ctrl</kbd>+<kbd>C</kbd>.

## 4. Sign in and create the resource group

Register the required resource providers:

## 5. Validate the infrastructure

The script compiles [`infra/main.bicep`](../infra/main.bicep) and runs an Azure
Resource Manager what-if without creating resources.

> [!WARNING]
> If the resource group contains an older workshop deployment using the same
> initials, the deployment stack replaces resources previously managed by that
> stack. Use a different resource group or initials if the older environment
> must remain available.

## 6. Deploy the application

Enter 2-5 letters when prompted. The script lowercases the initials and appends
`01`; for example, `JRF` becomes `jrf01`. For non-interactive use:

The script performs four visible stages:

1. Creates or updates the App Service deployment stack.
2. Publishes the .NET 10 application in Release configuration.
3. Waits for the new App Service SCM/Kudu hostname to resolve and accept HTTPS,
   then ZIP-deploys the published output to the Web App.
4. Verifies `/api/health` and the rendered Blazor application.

Rerunning the command with the same initials updates the same environment.
`-SkipCodeDeploy` provisions only infrastructure.

The GPT-5.4-mini deployment belongs to the Foundry account, not the project.
The template provisions the account, then its model deployment, then its
project. The project's explicit dependency on the model deployment controls
operation order only; both resources remain children of the account. This
prevents their writes from running concurrently and causing an account-level
`RequestConflict`.

If Azure still reports another operation in progress, inspect the deployment
operations and the account's Activity Log for an overlapping external operation.
Allow that operation to finish before rerunning the same command with the same
initials. Do not delete the environment just to retry a partially completed
deployment.

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
Foundry endpoint:  https://<foundry-resource-name>.services.ai.azure.com/api/projects/support-sim-project/
```

The deployment stack retains these outputs for later handoffs. The endpoint is
also applied to the Web App as the nonsecret
`StatusAssigneeInterpreter__Endpoint` setting; do not copy it into source code,
GitHub secrets, or a task description as a hardcoded account name. Retrieve it
again at any time with:

```powershell
az stack group show `
  --resource-group $RESOURCE_GROUP `
  --name "azstk$($environmentName)" `
  --query 'outputs.{foundryEndpoint:foundryEndpoint.value,foundryResource:foundryResourceName.value,foundryProject:foundryProjectName.value,model:foundryModelDeploymentName.value}' `
  --output table
```

Parts 5 and 6 use these existing outputs and do not add infrastructure
provisioning work to the Sprint.

The App Service has a system-assigned managed identity. Part 1 grants that
identity the least-privilege `Cognitive Services OpenAI User` role scoped to the
Foundry account; the role assignment is part of the same Bicep deployment.
Local key authentication is disabled on the account. GPT-5.4-mini model version
`2026-03-17` is deployed as `GlobalStandard` with capacity 50 in the resource
group's region (targeting 50,000 tokens per minute). Confirm that the model
deployment is available and quota is approved for that region before
deployment; ARM provisioning will fail if sufficient quota is unavailable.
Model usage can incur charges.
The current application does not call the model yet. The endpoint setting and
role are provisioned for the later application integration.

The health response must be `{"status":"healthy"}`, the state must be `Running`,
and `httpsOnly` must be `true`.

## Deployment complete

The Blazor frontend and ASP.NET Core backend now run as one .NET App Service
application. The Microsoft Foundry resource, project, model deployment, runtime
RBAC, and nonsecret endpoint setting are provisioned together.

## Public documentation used for validation

- [Deploy a Microsoft Foundry resource by using Bicep](https://learn.microsoft.com/azure/foundry/how-to/create-resource-template)
- [Microsoft Foundry account Bicep reference](https://learn.microsoft.com/azure/templates/microsoft.cognitiveservices/2026-07-01/accounts)
- [Microsoft Foundry project Bicep reference](https://learn.microsoft.com/azure/templates/microsoft.cognitiveservices/2026-07-01/accounts/projects)
- [Microsoft Foundry model deployment Bicep reference](https://learn.microsoft.com/azure/templates/microsoft.cognitiveservices/2026-07-01/accounts/deployments)
- [Foundry Models sold directly by Azure](https://learn.microsoft.com/azure/foundry/foundry-models/concepts/models-sold-directly-by-azure)
- [Region availability for Foundry Models sold by Azure](https://learn.microsoft.com/azure/foundry/foundry-models/concepts/models-sold-directly-by-azure-region-availability)
