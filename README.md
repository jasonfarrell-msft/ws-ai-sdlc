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
  backend/    FastAPI app, tests, requirements, and production Dockerfile
  frontend/   React 19 + TypeScript + Vite application
infra/        Bicep plus validate, deploy, and targeted-destroy scripts
docs/         Reserved for workshop part files supplied separately
```

## Local development

Prerequisites are Python 3.13 and Node.js 22 or newer.

Start the API:

```bash
cd src/backend
python3.13 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
FRONTEND_ORIGIN=http://localhost:5173 \
  uvicorn app.main:app --host 127.0.0.1 --port 5050 --no-access-log
```

In another terminal, start Vite:

```bash
cd src/frontend
npm ci
npm run dev
```

Open `http://localhost:5173`. Vite proxies `/api` to
`http://localhost:5050`. For a separately hosted API, set
`VITE_API_BASE_URL` when building the frontend.

## Tests and validation

```bash
cd src/backend
python -m pytest -q

cd ../frontend
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

## Backend container

Build from the repository root:

```bash
docker build -f src/backend/Dockerfile -t support-desk-api src/backend
docker run --rm -p 8080:8080 \
  -e FRONTEND_ORIGIN=http://localhost:5173 \
  support-desk-api
curl http://localhost:8080/api/health
```

The production image runs as a non-root user, disables access logs, listens on
`0.0.0.0:8080`, and has an OCI health check for `/api/health`.

## Azure architecture

The intended split deployment is:

- **Backend:** one FastAPI replica runs in Azure Container Apps Consumption and
  exposes port 8080 over HTTPS.
- **Frontend:** the Vite production assets are built with the backend's public
  URL in `VITE_API_BASE_URL` and served by a Linux S1 App Service.
- **Images:** Azure Container Registry Basic stores the backend image; a
  registry-scoped managed identity provides `AcrPull`.
- **Observability:** Log Analytics, workspace-based Application Insights, and
  diagnostic settings collect platform telemetry.

Set `FRONTEND_ORIGIN` on the backend to the frontend's exact HTTPS origin. The
deployment scripts set it from the generated App Service URL.

Validate the deployment without creating resources:

```bash
./infra/validate.sh \
  --resource-group '<resource-group-name>'
```

Create and deploy a fresh workshop environment:

```bash
./infra/deploy.sh \
  --resource-group '<resource-group-name>'
```

The deployment prints the frontend and backend URLs plus a targeted
`infra/destroy.sh` command. That command removes only the generated deployment
stack; it does not delete the shared resource group.

By default, each deployment creates an App Service plan and frontend app, a
Container Apps environment and backend app, ACR, the least-privilege image-pull
identity, Log Analytics, Application Insights, and diagnostic settings. ACR
admin and anonymous access remain disabled, images are deployed by digest, and
no application secrets are stored.

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
- Uvicorn access logging is disabled in the container. Application code never
  logs ticket subjects or descriptions.
- Azure Monitor ingestion and query endpoints are public, but telemetry access
  still requires Azure RBAC. Private endpoints and network isolation are outside
  this non-production workshop baseline.
- No secrets are required or stored. Never enter real personal, customer,
  credential, or confidential information into this simulator.
