# Azure deployment plan

**Status:** .NET 10 Blazor App Service migration implemented; Azure what-if requires an active target resource group

## Purpose

Deploy the Support Desk Simulator through a repeatable deployment stack. Host
the Blazor frontend and ASP.NET Core API in one code-based Linux Azure App
Service Web App.

## Application

| Component | Technology | Azure target |
| --- | --- | --- |
| Frontend | .NET 10 Blazor Web App, Interactive Server | Azure App Service |
| Backend | ASP.NET Core Minimal APIs and singleton service | Same Web App |
| Tests | MSTest and ASP.NET Core test host | GitHub-hosted runner |

The browser and API share one HTTPS origin. There is no JavaScript source,
Node.js toolchain, npm manifest, npm dependency, Python runtime, or frontend
package build. The Microsoft-provided Blazor bootstrap is supplied by the
ASP.NET Core shared framework.

## Infrastructure

The Bicep deployment creates:

- One Basic B1 Linux App Service Plan with one instance
- One code-based .NET 10 Web App with HTTPS-only ingress and WebSockets
- A system-assigned managed identity for future Azure service access
- A Log Analytics workspace with 30-day retention
- Workspace-based Application Insights
- One Microsoft Foundry resource with the `support-sim-project` project
- One GPT-5.4-mini `GlobalStandard` model deployment with capacity 50
  (targeting 50,000 tokens per minute, subject to available quota)
- App Service health checks against `/api/health`
- FTP publishing disabled and TLS 1.2 or newer required

## Deployment flow

1. `validate.ps1` compiles Bicep and runs a resource-group what-if.
2. `deploy.ps1` creates or updates the deployment stack.
3. `dotnet publish` builds the complete UI and API.
4. PowerShell creates one ZIP from the publish directory.
5. The deployment waits for the newly created SCM hostname and HTTPS endpoint
   to become reachable.
6. Azure CLI deploys the compiled output to App Service with bounded retries
   for transient Kudu initialization failures.
7. The script verifies `/api/health` and the rendered Blazor application.

GitHub uses the same publish/package model. It authenticates with
environment-scoped OIDC and receives the built-in `Website Contributor` role
only on the generated Web App.

## Security and cost decisions

- One public HTTPS endpoint avoids CORS and public backend coordination.
- WebSockets support Blazor Interactive Server.
- The Web App is HTTPS-only, FTP publishing is disabled, and no deployment
  credential is stored in source or GitHub.
- The GitHub OIDC subject is limited to the `workshop-deployment` environment
  and `main` branch policy.
- Pull request jobs receive no Azure OIDC permission.
- One Basic B1 instance matches the process-local demo store.
- The Foundry resource disables local key authentication. Its model deployment
  is provisioned for later use and is not called by the application.
- Foundry model usage can incur charges. Confirm regional availability and
  quota for the resource group's region before provisioning.
- App Service compute and log ingestion can incur charges.
- Demo identities are intentionally spoofable and are not authentication.

## Validation checklist

- [x] .NET solution restores from committed NuGet lock files.
- [x] C# and Razor source formatting is enforced.
- [x] .NET Release build succeeds.
- [x] Thirteen MSTest unit and hosted integration tests pass.
- [x] Published application health, rendered UI, and Blazor negotiation pass.
- [x] Bicep compilation succeeds; target-resource-group what-if remains a
  pre-deployment step.
- [x] PowerShell scripts parse successfully.
- [x] Workflow YAML parses successfully.
- [x] Repository scan confirms no JavaScript, TypeScript, npm, Node.js, or
  Python source/tooling remains.
- [x] Security and architecture review is complete. The user accepted the
  documented synthetic demo-identity risk.
