# Support Desk Simulator

A deployable baseline support application for software-delivery workshops. The
frontend is React 19, TypeScript, and Vite; the API is Python 3.13 and FastAPI.
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
  restricted CORS, and secure response headers

The baseline intentionally has **no AI functionality**. Future workshop part
files under `docs/` will define the epic and the **AI Grounded Response
Assistant** feature. Those workshop files are not created or changed here.

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

Workshop part files added separately under `docs/` define the backlog and guide
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
docs/         Reserved for workshop part files supplied separately
```

## Local development

Prerequisites are PowerShell 7, Python 3.13, and Node.js 22 or newer.

Start the API:

```powershell
Set-Location src/backend
$systemPython = if ($IsWindows) { 'python' } else { 'python3.13' }
& $systemPython -m venv .venv
$venvPython = if ($IsWindows) {
  '.\.venv\Scripts\python.exe'
} else {
  './.venv/bin/python'
}
& $venvPython -m pip install -r requirements-dev.txt
$env:FRONTEND_ORIGIN = 'http://localhost:5173'
& $venvPython -m uvicorn app.main:app --host 127.0.0.1 --port 5050 --no-access-log
```

In another terminal, start Vite:

```powershell
Set-Location src/frontend
npm ci
npm run dev
```

Open `http://localhost:5173`. Vite proxies `/api` to
`http://localhost:5050`. For a separately hosted API, set
`VITE_API_BASE_URL` when building the frontend.

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

The intended split deployment is:

- **Backend:** FastAPI runs on a Python 3.13 Linux App Service.
- **Frontend:** the Vite production assets are built with the backend's public
  URL in `VITE_API_BASE_URL` and served by a Node.js 24 Linux App Service.
- **Compute:** both applications share one Linux S1 App Service plan.
- **Observability:** Log Analytics, workspace-based Application Insights, and
  diagnostic settings collect platform telemetry.

Set `FRONTEND_ORIGIN` on the backend to the frontend's exact HTTPS origin. The
deployment scripts set it from the generated App Service URL.

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

The deployment prints the frontend and backend URLs.

By default, each deployment creates a shared App Service plan, separate
frontend and backend web apps, Log Analytics, Application Insights, and
diagnostic settings. FTP and SCM basic publishing authentication are disabled,
and no application secrets are stored.

## GitHub Actions deployments

Two path-filtered workflows independently validate and deploy application
changes:

- [`.github/workflows/backend.yml`](.github/workflows/backend.yml) tests
  FastAPI changes, ZIP-deploys the backend to App Service, and checks
  `/api/health`.
- [`.github/workflows/frontend.yml`](.github/workflows/frontend.yml) checks the
  React production build, rebuilds it with the deployed backend URL, ZIP
  deploys it to App Service, and checks the website response.

Pull requests run validation only. Pushes to `main` deploy the changed
application, and either workflow can be run manually from `main`. Validation
runs cancel obsolete work for the same branch. Azure deployment jobs use a
fixed component-specific concurrency group and never cancel an in-progress
deployment, preventing two runs from racing to update the same resource.

Workshop participants fork this repository and configure the workflows in
their own fork. This keeps each participant's GitHub OIDC trust, variables, and
Azure deployment target isolated from the source repository and other
participants.

### Configure the deployment environments

Use separate deployment identities and GitHub environments so each workflow can
modify only its own Azure resources.

Create `workshop-backend` with:

| Environment variable | Value |
| --- | --- |
| `AZURE_CLIENT_ID` | Client ID of the backend deployment identity |
| `AZURE_TENANT_ID` | Microsoft Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Subscription containing the deployment |
| `AZURE_RESOURCE_GROUP` | Existing resource group containing the application |
| `AZURE_BACKEND_APP_SERVICE` | Backend App Service resource name |

Create `workshop-frontend` with:

| Environment variable | Value |
| --- | --- |
| `AZURE_CLIENT_ID` | Client ID of the frontend deployment identity |
| `AZURE_TENANT_ID` | Microsoft Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Subscription containing the deployment |
| `AZURE_RESOURCE_GROUP` | Existing resource group containing the application |
| `AZURE_APP_SERVICE` | Frontend App Service resource name |

Add `AZURE_BACKEND_URL` as a repository variable containing the backend HTTPS
origin without a trailing slash. It is public configuration used by the
unprivileged frontend packaging job.

Use dedicated user-assigned managed identities for GitHub. Add an
environment-scoped federated credential to each deployment identity with:

- Issuer: `https://token.actions.githubusercontent.com`
- Audience: `api://AzureADTokenExchange`
- Backend subject:
  `repo:<fork-owner>/ws-ai-sdlc:environment:workshop-backend`
- Frontend subject:
  `repo:<fork-owner>/ws-ai-sdlc:environment:workshop-frontend`

Under **Deployment branches and tags**, choose **Selected branches and tags**
and add only `main` for both environments. The workflows also enforce
`refs/heads/main` before any deployment job can start. No manual approval is
required: merging a backend or frontend change to `main` completes the loop by
deploying that component automatically.

No GitHub secret or Azure client secret is required. At the narrowest applicable
resource scopes, grant the identities:

| Role | Scope | Used by |
| --- | --- | --- |
| `Website Contributor` | Backend identity, backend App Service | Deploy the backend ZIP |
| `Website Contributor` | Frontend identity, App Service | Deploy the frontend ZIP |

The workflows pin every action to a full commit SHA and grant `id-token: write`
only to deployment jobs. Frontend dependencies are installed and production
assets are packaged in a separate job that cannot request an OIDC token.

Part 2, [`docs/02-github-action-setup.md`](docs/02-github-action-setup.md), uses
`infra/configure-github-actions.ps1` to create the identities, federated
credentials, role assignments, environments, and variables in the
participant's verified fork. The script also enables both workflows in that
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
- CORS permits only `FRONTEND_ORIGIN`; credentials are not enabled.
- Responses set no-sniff, frame, referrer, permissions, and no-store headers.
- Uvicorn access logging is disabled in App Service. Application code never
  logs ticket subjects or descriptions.
- Azure Monitor ingestion and query endpoints are public, but telemetry access
  still requires Azure RBAC. Private endpoints and network isolation are outside
  this non-production workshop baseline.
- No secrets are required or stored. Never enter real personal, customer,
  credential, or confidential information into this simulator.
