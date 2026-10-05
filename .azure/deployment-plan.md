# Azure deployment plan

**Status:** Implementation validated locally; Azure what-if required

## Purpose

Deploy the Support Desk Simulator into a dedicated user-provided resource group
through a repeatable deployment stack. Replace the two App Service ZIP
deployments with one atomic Azure Static Web Apps deployment.

## Application

| Component | Technology | Azure target |
| --- | --- | --- |
| Frontend | React 19, TypeScript, Vite | Azure Static Web Apps Free |
| Backend | Python 3.11, FastAPI | Managed Azure Functions API |

The managed API uses the Azure Functions ASGI adapter, preserving the existing
FastAPI routes and tests. Static Web Apps exposes it through the fixed
same-origin `/api` route.

## Infrastructure

The Bicep deployment creates:

- An Azure Static Web App with staging environments disabled
- A Log Analytics workspace with 30-day retention
- Workspace-based Application Insights
- Static Web Apps application settings that connect the managed API to
  Application Insights
- An environment-specific custom deployment role with only resource-group
  read, Static Web App read, and deployment-token retrieval actions

Static Web Apps provides managed HTTPS. The workshop intentionally uses a
public endpoint because browser participants access it directly. Private
networking is outside this non-production workshop baseline.

## Deployment flow

1. Compile Bicep and run a resource-group what-if.
2. Create or update the resource-group deployment stack.
3. Vendor Python 3.11-compatible Linux dependencies into a temporary API
   package.
4. Build the Vite frontend.
5. Retrieve the generated deployment token into process memory.
6. Upload the frontend and managed API as one deployment.
7. Clear the token, remove the temporary package, and verify the application
   root and `/api/health`.

GitHub follows the same atomic upload model. It authenticates to Azure through
an environment-scoped OIDC credential, retrieves and masks the deployment token
at run time, and never stores an Azure client secret or deployment token.

## Security and cost decisions

- The GitHub identity receives the environment-specific custom deployment role
  only on the generated Static Web App.
- The OIDC subject is limited to the `workshop-deployment` environment, whose
  branch policy allows only `main`.
- Pull request jobs have read-only repository access and no Azure OIDC
  permission.
- Static Web Apps route and response-header configuration is versioned with the
  frontend.
- The Free plan is appropriate for this synthetic workshop and removes the
  always-on S1 App Service cost.
- Demo identity headers remain intentionally spoofable and are not production
  authentication.
- Process-local ticket state resets whenever the managed API instance restarts
  and is not shared across instances.

## Validation checklist

- [x] Python 3.11-compatible Linux dependency staging succeeds.
- [x] FastAPI and Functions adapter tests pass.
- [ ] React type checking and production build succeed.
- [ ] Static Web Apps configuration is copied to `dist`.
- [x] Bicep compilation succeeds.
- [x] PowerShell deployment scripts parse successfully.
- [ ] Resource-group ARM what-if succeeds in a target subscription.
- [x] GitHub Actions workflow syntax is valid.
- [x] Security and architecture review is complete.

The local npm package-feed proxy returned 404 for existing locked frontend
packages, so the unchanged frontend source could not be rebuilt in this
environment. The GitHub workflow retains the locked `npm ci` build as a
required deployment prerequisite.
