# Support Desk Simulator

A deployable baseline support application for software-delivery workshops. The
frontend is React 19, TypeScript, and Vite; the API is Python 3.11 and FastAPI.
It models a small support queue without connecting to real users, customer data,
ticketing systems, or AI services.

> **Demo only:** Every ticket, article, person, and product in this repository is
> synthetic. The identity selector sends plain HTTP headers and is not real
> authentication.

## Included baseline

- A synthetic ticket queue with status, priority, product, and text filters
- Ticket detail and append-only activity history
- A **Requester** workflow for creating validated tickets
- A **Support agent** workflow for assigning a ticket to self and changing status
- A searchable, read-only, versioned knowledge article library
- Accessible keyboard focus, semantic controls, responsive layouts, and explicit
  loading, error, and empty states
- Deterministically seeded, process-local storage
- Health checks, structured API errors, request limits, role authorization,
  same-origin API routing, and secure response headers

The baseline intentionally has **no AI functionality**. The workshop part
files under [docs/](docs/) define the epic and the **AI Grounded Response
Assistant** feature.

## What exists at the start of the workshop

Participants begin with a complete, deployable non-AI application rather than
an empty codebase. The default application already provides:

1. A requester-facing ticket submission workflow
2. A support-agent queue with search and structured filters
3. Ticket assignment, status changes, and append-only history
4. A versioned, read-only troubleshooting knowledge library
5. Deterministic synthetic tickets, articles, products, and identities
6. Backend tests, frontend type checking, production builds, health probes, and
   repeatable Azure deployment scripts

Workshop part files under [docs/](docs/) define the backlog and guide
participants through adding the AI Grounded Response Assistant. The starting
application does not contain a hidden, mocked, or disabled AI implementation.

## Synthetic data and demo identities

The API starts with three tickets (`TKT-1001` through `TKT-1003`) covering the
synthetic Analytics, Workspace, and Billing products, plus three knowledge
articles (`KB-101` through `KB-103`). Use either identity from the UI:

| Display name | Header user | Header role | Capabilities |
| --- | --- | --- | --- |
| Maya Chen | `maya.chen` | `requester` | View tickets/articles and create tickets |
| Jordan Lee | `jordan.lee` | `agent` | View tickets/articles, assign to self, change status |

The API requires matching `x-demo-user` and `x-demo-role` values for every route
except health. These headers are deliberately easy to forge and must never be
treated as an authentication mechanism.

## Project layout

```text
src/
  backend/    FastAPI app, tests, and Python requirements
  frontend/   React 19 + TypeScript + Vite application
infra/        Bicep plus validate, deploy, and targeted-destroy scripts
docs/         Workshop setup and backlog-planning guides
compose.yaml  Local frontend/backend container integration
```

## Local development

Prerequisites are PowerShell 7, Python 3.11, and Node.js 22 or newer.
[docs/01-azure-foundation.md](docs/01-azure-foundation.md) has
per-platform install commands for every tool.

Start the API:

```powershell
Set-Location src/backend
$systemPython = if ($IsWindows) { 'python' } else { 'python3.11' }
& $systemPython -m venv .venv
$venvPython = if ($IsWindows) {
  '.\.venv\Scripts\python.exe'
} else {
  './.venv/bin/python'
}
& $venvPython -m pip install -r requirements-dev.txt
& $venvPython -m uvicorn app.main:app --host 127.0.0.1 --port 5050 --no-access-log
```

In another terminal, start Vite:

```powershell
Set-Location src/frontend
npm ci
npm run dev
```

Open `http://localhost:5173`. Vite proxies `/api` to
`http://localhost:5050`. For a separately hosted API, set `VITE_API_BASE_URL` when building the
frontend. The Azure deployment leaves it unset so the browser uses nginx's
same-origin `/api` proxy.

To build and run the actual application images locally, use Docker with Compose
from the repository root. Stop the local Uvicorn server first if it is using
port 5050:

```powershell
$env:NPM_CONFIG_REGISTRY = npm config get registry
docker compose up --build --detach --wait
python ./infra/test-containers.py
```

Local npm commands use the corporate/global npm registry policy; do not override
it to bypass that policy. Compose passes the non-secret registry URL to the
frontend build. GitHub-hosted Actions and Azure remote builds use public npm.
Never place tokens or credential-bearing URLs in Docker build arguments.

Open `http://localhost:8080`. nginx forwards `/api` to the backend container;
the backend is also available directly at `http://localhost:5050`. Compose
binds both ports to loopback only. Use `python3` if that is your installed
command. The smoke test creates, assigns, and resolves a synthetic ticket; it requires no extra
Python packages.

Stop and remove the local containers when finished:

```powershell
docker compose down
```

## Tests and validation

```powershell
Set-Location src/backend
$venvPython = if ($IsWindows) {
  '.\.venv\Scripts\python.exe'
} else {
  './.venv/bin/python'
}
& $venvPython -m pytest -q

Set-Location ../frontend
npm run typecheck
npm run build
```

Backend tests cover health, happy paths, filtering, validation, body-size
limits, authorization, ticket history, missing resources, and knowledge
articles.

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

Ticket list query parameters are `status`, `priority`, `product`, and `search`.
Article list supports `search`. Errors use a stable shape:

```json
{
  "error": {
    "code": "validation_error",
    "message": "The request was not valid.",
    "details": []
  }
}
```

## Azure architecture

The application deploys as two Azure Container Apps in one shared environment:

- **Frontend:** nginx serves the Vite production assets over managed HTTPS.
- **Backend:** Uvicorn hosts the existing FastAPI application on Python 3.11
  behind a separate public HTTPS endpoint.
- **Routing:** frontend requests use the same-origin `/api` route. No deployed
  CORS policy or build-time backend URL is required.
- **Images:** ACR Basic builds and stores Linux/AMD64 images. Each app uses its
  system-assigned managed identity with `AcrPull`; registry admin access and
  anonymous pulls are disabled.
- **Observability:** Log Analytics collects container console/system logs.
  Workspace-based Application Insights is provisioned and its connection string
  is passed to the API, but SDK request instrumentation is not configured.
- **Scaling:** both apps use 0.5 vCPU and 1 GiB per replica. The frontend runs
  1-2 replicas; the process-local backend uses one replica and one worker.
- **Cost:** minimum replicas, registry storage/builds, and log ingestion may
  incur charges. This is not a Static Web Apps Free-plan deployment.

Both apps listen on port 80 within their containers. Container Apps terminates
public TLS; nginx uses HTTPS, the backend Host header, SNI, and certificate
verification when proxying to the Azure backend. Its runtime `BACKEND_URL` is
supplied by Bicep, not baked into the frontend bundle.

Validate the deployment against a dedicated workshop resource group without
creating application resources:

```powershell
pwsh ./infra/validate.ps1 `
  -ResourceGroup '<resource-group-name>'
```

Create and deploy a fresh workshop environment:

```powershell
pwsh ./infra/deploy.ps1 `
  -ResourceGroup '<resource-group-name>'
```

The deployment prints the application URL, both app names, and registry name.
Provisioning is repeatable through Bicep. ACR builds the backend and frontend
images, and the script updates each app separately, backend first. These
updates are not atomic: preserve backward API compatibility during rollout.
Reruns preserve existing image references while infrastructure is updated.
An initial bootstrap image is replaced after managed identities and pull roles
are ready; `-SkipCodeDeploy` does not deploy application images.

Migrating an existing deployment stack replaces the old Static Web Apps
resources; review what-if and plan a maintenance window first. Remove old SWA
deployment-role assignments before the stack update, then rerun Part 2 to
configure the new GitHub deployment identity and target.

## GitHub Actions deployments

[`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) tests the
FastAPI application, builds the React application, compiles Bicep, and deploys
separate frontend/backend images, and verifies their same-origin integration.

Pull requests run validation without Azure access. Pushes to `main` deploy the
whole application, and the workflow can also be run manually from `main`. A
fixed concurrency group never cancels an in-progress deployment, preventing
two releases from racing. Validation also builds and tests both containers
locally on the runner before Azure credentials are requested.

Workshop participants fork this repository and configure the workflows in
their own fork. This keeps each participant's GitHub OIDC trust, variables, and
Azure deployment target isolated from the source repository and other
participants.

### Configure the deployment environment

Create one `workshop-deployment` GitHub environment with:

| Environment variable | Value |
| --- | --- |
| `AZURE_CLIENT_ID` | Client ID of the deployment identity |
| `AZURE_TENANT_ID` | Microsoft Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Subscription containing the deployment |
| `AZURE_RESOURCE_GROUP` | Existing resource group containing the application |
| `AZURE_CONTAINER_REGISTRY` | ACR registry name |
| `AZURE_FRONTEND_APP` | Frontend Container App name |
| `AZURE_BACKEND_APP` | Backend Container App name |

Use a dedicated user-assigned managed identity for GitHub. Add an
environment-scoped federated credential to the deployment identity with:

- Issuer: `https://token.actions.githubusercontent.com`
- Audience: `api://AzureADTokenExchange`
- Subject: `<repository-oidc-subject-prefix>:environment:workshop-deployment`

The configuration script reads the subject prefix from GitHub so it supports
both legacy name-based subjects and immutable subjects containing owner and
repository IDs.

Under **Deployment branches and tags**, choose **Selected branches and tags**
and add only `main`. The workflow also enforces `refs/heads/main` before its
deployment job can start. No manual approval is required.

No GitHub secret or Azure client secret is required. Grant the identity at the
narrowest applicable scope:

| Role | Scope | Used by |
| --- | --- | --- |
| `Support Desk Container App Deployer <environment>` | Deployment identity, dedicated workshop resource group | Upload build sources, run ACR builds, read build status/logs, update apps |
| `AcrPull` | Each app's system-assigned identity, generated ACR | Pull private application images |

The workflows pin every action to a full commit SHA and grant `id-token: write`
only to the deployment job. No registry password or Static Web Apps deployment
token is used. Both images are tagged with the full Git commit SHA.

Part 2, [`docs/02-github-action-setup.md`](docs/02-github-action-setup.md), uses
[infra/configure-github-actions.ps1](infra/configure-github-actions.ps1) to create the identities, federated
credentials, role assignments, environments, and variables in the
participant's verified fork. The script also enables the workflow in that
fork after the participant completes GitHub's one-time Actions opt-in from the
fork's Actions tab.

## Ephemeral reset behavior

Tickets and history are held in a lock-protected, process-local store. Restarting
the API resets all changes and restores the deterministic seed data. Multiple
workers or replicas do not share changes. This is intentional for workshops and
must be replaced by a durable data store before any production use.

## Security boundaries

- Demo headers provide authorization examples only; use a real identity provider
  and server-validated tokens in a real system.
- Request models reject unknown fields, validate enums, trim text, cap field
  lengths, and reject bodies larger than 16 KB.
- The deployed frontend and API are same-origin, so no browser CORS exception
  is required.
- Responses set no-sniff, frame, referrer, permissions, and no-store headers.
- Application code never logs ticket subjects or descriptions.
- Azure Monitor ingestion and query endpoints are public, but telemetry access
  still requires Azure RBAC. Private endpoints and network isolation are outside
  this non-production workshop baseline.
- Both Container Apps have public HTTPS ingress for this workshop. Registry
  access is authenticated, and the frontend verifies upstream TLS certificates.
- Deployment uses Entra/OIDC and managed identity rather than stored passwords.
  The platform's Log Analytics integration obtains a workspace key within ARM;
  it is not checked into source or exported as a deployment output.
- Never enter real personal, customer,
  credential, or confidential information into this simulator.
