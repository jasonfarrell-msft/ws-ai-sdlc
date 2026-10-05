# Azure deployment plan

**Status:** GitHub-hosted application/container validation passed; Azure configuration and what-if required

## Purpose

Deploy the Support Desk Simulator into a dedicated user-provided resource group
through a repeatable deployment stack. Host both frontend and backend in
separate Azure Container Apps, replacing Static Web Apps and managed Functions.

## Application

| Component | Technology | Azure target |
| --- | --- | --- |
| Frontend | React 19, TypeScript, Vite, nginx | Azure Container Apps |
| Backend | Python 3.11, FastAPI, Uvicorn | Azure Container Apps |

Uvicorn serves the existing FastAPI routes directly. nginx exposes the same-origin
`/api` route and verifies the backend HTTPS certificate and SNI/Host routing.

## Infrastructure

The Bicep deployment creates:

- A shared Azure Container Apps environment and two public HTTPS apps
- An ACR Basic registry with admin/anonymous access disabled
- System-assigned app identities with registry-scoped `AcrPull`
- A Log Analytics workspace with 30-day retention
- Workspace-based Application Insights
- The Application Insights connection string in the backend's environment;
  SDK request instrumentation remains a separate future enhancement
- An environment-specific custom deployment role for ACR source uploads,
  scheduled builds, run status/log access, and Container App updates

Container Apps provides managed HTTPS. Both apps have public endpoints as
requested; browser participants normally use the frontend API proxy. Private
networking is outside this non-production workshop baseline.

## Deployment flow

1. Compile Bicep and run a resource-group what-if.
2. Create or update the resource-group deployment stack.
3. Build the backend Linux/AMD64 image in ACR and update its app.
4. Build the frontend Linux/AMD64 nginx image in ACR and update its app.
5. Verify direct backend health, proxied `/api/health`, and the application root.

GitHub uses the same sequential update model and tags both images with the full
commit SHA. It authenticates using environment-scoped OIDC; no deployment token,
registry password, or client secret is stored. Updates are not atomic.

## Security and cost decisions

- The GitHub identity receives the environment-specific custom deployment role
  in the dedicated workshop resource group; each app's pull role is registry-scoped.
- The OIDC subject is limited to the `workshop-deployment` environment, whose
  branch policy allows only `main`.
- Pull request jobs have read-only repository access and no Azure OIDC
  permission.
- nginx route and response-header configuration is versioned with the
  frontend.
- Both apps use 0.5 vCPU / 1 GiB, with one minimum replica; the frontend can scale
  to two. The backend stays at one replica/worker because its data is process-local.
- Container compute, ACR storage/builds, and log ingestion can incur charges.
- Demo identity headers remain intentionally spoofable and are not production
  authentication.
- Process-local ticket state resets whenever the API container restarts
  and is not shared across instances.

## Validation checklist

- [x] FastAPI regression tests pass (8 tests on the existing local Python environment).
- [x] Frontend type checking and production build succeed on GitHub.
- [x] Both Docker images build and Compose smoke tests pass on GitHub.
- [x] Bicep compilation succeeds (three documented `BCP081` API type warnings remain).
- [x] PowerShell deployment scripts parse successfully.
- [ ] Resource-group ARM what-if succeeds in a target subscription.
- [x] GitHub Actions workflow syntax is valid.
- [x] Security and architecture review is complete.

The exact nginx configuration and entrypoint passed four integration smoke tests
against the local API with existing frontend assets. Missing and invalid
`BACKEND_URL` values are rejected. Compose configuration parses successfully.
These checks do not substitute for building both images from scratch.

Local full builds are blocked by the corporate npm feed returning 404 for
`yallist@3.1.1` and external Python package downloads failing TLS connections.
Local commands must honor the global corporate registry policy; Compose can
receive its non-secret registry URL through `NPM_CONFIG_REGISTRY`. GitHub-hosted
validation and Azure remote builds use public npm. The workflow gates Azure
deployment on frontend build and full Docker Compose integration tests.

GitHub Actions run
[37378291181](https://github.com/jasonfarrell-msft/ws-ai-sdlc/actions/runs/37378291181)
passed backend tests, the frontend production build, Bicep compilation, and both
container builds plus integration smoke tests. The deployment job stopped before
Azure sign-in because `AZURE_CLIENT_ID` is not configured in
`workshop-deployment`. Complete Parts 1 and 2 to provision the target and
configure the environment variables before attempting Azure deployment.
