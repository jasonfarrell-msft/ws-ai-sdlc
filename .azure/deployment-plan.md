# Azure deployment plan

**Status:** App Service migration implemented; Azure what-if awaits an active target resource group

## Purpose

Deploy the Support Desk Simulator into a dedicated user-provided resource group
through a repeatable deployment stack. Host the React frontend and FastAPI API
in one code-based Linux Azure App Service Web App.

## Application

| Component | Technology | Azure target |
| --- | --- | --- |
| Frontend | React 19, TypeScript, Vite | Static assets served by FastAPI |
| Backend | Python 3.13, FastAPI, Uvicorn | Azure App Service |

The browser and API share one HTTPS origin. FastAPI returns the compiled SPA for
frontend routes and preserves structured 404 responses for missing API routes
and assets.

## Infrastructure

The Bicep deployment creates:

- One Basic B1 Linux App Service Plan with one instance
- One code-based Python 3.13 Web App with HTTPS-only ingress
- A system-assigned managed identity for future Azure service access
- A Log Analytics workspace with 30-day retention
- Workspace-based Application Insights
- App Service health checks against `/api/health`
- FTP publishing disabled and TLS 1.2 or newer required

There is no ACR, Container Apps environment, image-pull identity, registry
credential, deployment token, or custom Azure role.

## Deployment flow

1. Run `validate.ps1` to compile Bicep and execute a resource-group what-if.
2. Run `deploy.ps1` to create or update the resource-group deployment stack.
3. Build the React production assets with locked npm dependencies.
4. Package the FastAPI source, Python requirements, and frontend assets.
5. ZIP-deploy the package; App Service restores Python dependencies.
6. Verify `/api/health` and the application root.

GitHub uses the same package format. It authenticates with environment-scoped
OIDC and receives the built-in `Website Contributor` role only on the generated
Web App.

## Security and cost decisions

- One public HTTPS endpoint avoids CORS and public backend coordination.
- The Web App is HTTPS-only, FTP publishing is disabled, and no credentials are
  stored in source or GitHub.
- The GitHub OIDC subject is limited to the `workshop-deployment` environment,
  whose branch policy allows only `main`.
- Pull request jobs have read-only repository access and no Azure OIDC
  permission.
- One Basic B1 instance is sufficient for the process-local demo store and
  avoids implying high availability.
- App Service compute and log ingestion can incur charges.
- Demo identity headers remain intentionally spoofable and are not production
  authentication.
- Process-local ticket state resets whenever the application restarts.

## Validation checklist

- [x] FastAPI regression tests pass (8 tests on Python 3.13).
- [ ] A fresh local frontend install/build is blocked because the configured
  corporate npm mirror does not contain `yallist@3.1.1`; the unchanged frontend
  build previously passed on GitHub-hosted runners.
- [x] Combined same-origin application smoke tests pass (4 tests using the
  existing production assets).
- [x] Bicep compilation succeeds. The latest GA Microsoft.Web `2026-08-01`
  resources produce `BCP081` warnings because local Bicep types lag the live
  provider API.
- [x] PowerShell deployment scripts parse successfully.
- [ ] Resource-group ARM what-if is blocked while the selected target resource
  group is in Azure's deprovisioning state.
- [x] GitHub Actions workflow syntax is valid.
- [x] Security and architecture review is complete. The demo accepts the
  documented residual risk that App Service basic publishing policies remain at
  their platform defaults.
