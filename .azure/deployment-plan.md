# Azure deployment plan

**Status:** Validated

## Purpose

Deploy the Support Desk Simulator baseline into a dedicated resource group
created by the user. The deployment uses the resource group's location,
remains resource-group scoped, and creates a separately removable deployment
stack for each workshop environment.

## Application

| Component | Technology | Azure target |
| --- | --- | --- |
| Frontend | React 19, TypeScript, Vite | Linux App Service S1 |
| Backend | Python 3.13, FastAPI | Linux App Service S1 |

The application uses only synthetic, process-local data. It deliberately has no
AI feature, durable database, or production authentication.

## Infrastructure

The Bicep deployment creates:

- A shared Linux S1 App Service plan
- A Node.js App Service for the compiled SPA
- A Python App Service for the FastAPI backend
- A Log Analytics workspace and workspace-based Application Insights
- Diagnostic settings for both App Services

HTTPS is required, both App Services use TLS 1.2 or newer, FTP and SCM basic
authentication are disabled, and the API allows browser CORS requests only
from the generated frontend origin.

## Deployment flow

1. Validate Bicep and run a resource-group what-if.
2. Create a fresh deployment stack containing two Linux App Services.
3. ZIP-deploy the backend source to the Python App Service.
4. Build the Vite frontend using the backend URL.
5. ZIP-deploy the contents of `dist` to the Node.js App Service.
6. Verify `/api/health` and the frontend root.

Every run receives a cryptographically random identifier.

## Accepted workshop boundaries

- Demo identity headers are spoofable and are not authentication.
- Ticket state resets when the single backend replica restarts.
- The API is public because browsers call it directly.
- Azure Monitor ingestion and query endpoints remain public, with Azure RBAC
  still required for telemetry access; private networking is outside this
  non-production workshop scope.
- The topology is single-region and has no production SLA, RPO, or RTO.
- App Service S1 is retained from the approved safe infrastructure even though
  a static-hosting service could be cheaper.

## Validation checklist

- [x] Azure CLI is installed and authenticated to the target subscription.
- [x] Bicep compilation succeeds.
- [x] Resource-group ARM validation succeeds.
- [x] Resource-group what-if succeeds with 12 creates, 0 modifications, and 0
  deletions for a fresh validation identifier.
- [x] Scaffold conformance passes with no failures.
- [x] React type checking and production build succeed.
- [x] FastAPI tests pass.
- [x] Frontend production dependency audit reports no vulnerabilities.
- [x] FTP and SCM basic publishing authentication are disabled; frontend ZIP
  deployment uses Microsoft Entra authentication with Azure CLI 2.48.1 or newer.

## Role assignment verification

- **Status:** Verified
- **Identity:** Separate GitHub Actions deployment identities for the backend
  and frontend
- **Role:** `Website Contributor`
- **Scope:** Each generated App Service only
- **Result:** Each workflow can update only its corresponding App Service.

## Validation proof

Validated on 2026-09-22 before deployment approval:

| Command | Result |
| --- | --- |
| `pwsh ./infra/validate.ps1 -ResourceGroup <resource-group-name>` | PASS: CLI, authentication, Bicep build, and resource-group what-if |
| `scaffold-conformance.sh ... infra` | PASS: `{"passed":true,"failures":[]}` |
| `cd src/backend && .venv/bin/python -m pytest -q` | PASS: 8 tests; one upstream deprecation warning |
| `npm run build --prefix src/frontend` | PASS: TypeScript and Vite production build |
| `npm audit --prefix src/frontend --omit=dev` | PASS: 0 vulnerabilities |

The installed Bicep CLI emits non-blocking `BCP081` for the registered
`Microsoft.OperationalInsights/workspaces@2026-03-01` API because local type
metadata lags the service API. ARM validation and what-if both accept the
resource.
