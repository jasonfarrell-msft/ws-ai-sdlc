# Support Desk Simulator

A deployable baseline support application for software-delivery workshops. The
application is a .NET 10 ASP.NET Core Blazor Web App using Interactive Server
rendering with a same-process ASP.NET Core API.

The repository contains no JavaScript or TypeScript source, Node.js tooling, npm
manifests, or npm dependencies. Interactive Server uses the Microsoft-provided
Blazor browser bootstrap asset from the ASP.NET Core shared framework; it is
published by the .NET SDK and is not downloaded from npm.

> **Demo only:** Every ticket, article, person, and product in this repository is
> synthetic. The identity selector is not real authentication.

## Included baseline

- A synthetic ticket queue with status, priority, product, and text filters
- Ticket detail and append-only activity history
- A requester workflow for creating validated tickets
- A support-agent workflow for assigning a ticket and changing status
- A searchable, read-only, versioned knowledge library
- Accessible keyboard focus, semantic controls, responsive layouts, and explicit
  empty states
- Deterministically seeded, thread-safe, process-local storage
- Same-origin JSON API routes under `/api`
- Health checks, structured API errors, request limits, role authorization, and
  security response headers

The baseline intentionally has **no AI functionality**. The workshop files
under [docs/](docs/) guide participants through planning the AI Grounded
Response Assistant.

## Architecture

```text
Browser
   |
   | HTTPS + Blazor Interactive Server circuit
   v
Azure App Service
   └── ASP.NET Core (.NET 10)
       ├── Blazor components
       ├── Minimal API endpoints under /api
       └── Singleton synthetic support store
```

One code-based Linux Web App hosts the frontend and backend. There is no
container, registry, frontend build service, cross-origin API, or custom Azure
role.

The process-local store intentionally resets after an application restart or
deployment. The App Service plan uses one instance because multiple instances
would not share ticket changes.

## Project layout

```text
src/SupportDesk.App/
  Api/            ASP.NET Core API route mapping
  Components/     Blazor UI, pages, and layouts
  Domain/         Tickets, articles, identities, and request models
  Services/       Thread-safe support store
  wwwroot/        Application CSS
tests/SupportDesk.App.Tests/
                  MSTest unit and hosted integration tests
infra/            Bicep and PowerShell deployment scripts
docs/             Workshop setup and backlog-planning guides
SupportDesk.slnx  .NET solution
```

## Prerequisites

- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)
- [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [GitHub CLI](https://cli.github.com/)

Node.js and npm are neither required nor used.

## Local development

Restore and run the application:

```powershell
dotnet restore SupportDesk.slnx --locked-mode
dotnet run `
  --project ./src/SupportDesk.App/SupportDesk.App.csproj
```

Open the HTTPS URL printed by ASP.NET Core. The UI and API share the same
origin. Verify the health endpoint:

```powershell
Invoke-RestMethod -Uri 'https://localhost:<port>/api/health'
```

## Tests and validation

```powershell
dotnet format SupportDesk.slnx `
  --verify-no-changes `
  --no-restore

dotnet build SupportDesk.slnx `
  --configuration Release `
  --no-restore

dotnet test SupportDesk.slnx `
  --configuration Release `
  --no-build

dotnet publish ./src/SupportDesk.App/SupportDesk.App.csproj `
  --configuration Release `
  --no-build `
  --output ./artifacts/publish
```

The tests cover health, security headers, identity validation, filtering,
ticket creation, assignment, status changes, activity history, knowledge search,
the rendered Blazor application, and the structured API error contract.

## API

| Method | Route | Access |
| --- | --- | --- |
| `GET` | `/api/health` | Public |
| `GET` / `POST` | `/api/tickets` | Both roles / requester |
| `GET` | `/api/tickets/{id}` | Both roles |
| `POST` | `/api/tickets/{id}/assign` | Support agent |
| `PATCH` | `/api/tickets/{id}/status` | Support agent |
| `GET` | `/api/tickets/{id}/history` | Both roles |
| `GET` | `/api/articles` | Both roles |
| `GET` | `/api/articles/{id}` | Both roles |

API calls use the synthetic `x-demo-user` and `x-demo-role` headers. These
headers are deliberately easy to forge and must never be treated as a real
authentication mechanism.

## Azure deployment

Validate the infrastructure:

```powershell
./infra/validate.ps1 `
  -ResourceGroup '<resource-group-name>'
```

Provision App Service, publish the .NET application, ZIP-deploy it, and verify
the application:

```powershell
./infra/deploy.ps1 `
  -ResourceGroup '<resource-group-name>'
```

The deployment creates:

- One Basic B1 Linux App Service Plan
- One .NET 10 Web App with HTTPS-only access and WebSockets enabled
- Log Analytics and workspace-based Application Insights
- A system-assigned managed identity for future Azure service access

GitHub Actions uses OIDC and the built-in `Website Contributor` role scoped to
the Web App. It restores from committed NuGet lock files, builds, tests,
publishes, ZIP-deploys, and verifies the same .NET application. No publishing
profile, client secret, JavaScript package, or npm registry is used.

See [Part 1](docs/01-azure-foundation.md) and
[Part 2](docs/02-github-action-setup.md) for the complete workshop setup.

## Security boundaries

- Demo identities are examples only; use a real identity provider and
  server-validated tokens in a production system.
- Input models validate required values, lengths, enum values, and request size.
- HTTPS, TLS 1.2 or newer, HSTS, security headers, and disabled FTP are
  configured.
- GitHub deployment uses environment-scoped OIDC rather than stored Azure
  credentials.
- The App Service endpoint and Azure Monitor ingestion endpoints are public for
  this workshop. Private networking is outside this baseline.
- Never enter real personal, customer, credential, or confidential information.
