# Configure Automatic Deployment

## Goal

Connect the fork's GitHub Actions workflow to the Container Apps and registry created in
Part 1. Pull requests validate without Azure access. A change merged to `main`
builds and deploys separate frontend and backend images.

The setup uses GitHub OIDC and one Azure user-assigned managed identity. It
stores no Azure client secret, registry password, or deployment token in GitHub.

## Prerequisites

- Complete Part 1 and retain its deployment output.
- Use the personal fork created in Part 1.
- Use a PowerShell 7 terminal with authenticated Azure and GitHub CLIs.
- Have permission to create a managed identity and role assignment in the
  dedicated workshop resource group. Part 1 also requires permission to create the
  environment-specific custom role definition in the resource group.
- Ensure [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml) is on
  the fork's `main` branch.

## 1. Confirm access

```powershell
az account show `
  --query '{subscription:name,id:id,user:user.name}' `
  --output table

gh auth status
gh repo set-default origin

$GITHUB_REPOSITORY = gh repo view `
  --json nameWithOwner `
  --jq .nameWithOwner
```

Confirm that the repository is your fork:

```powershell
gh api "repos/$GITHUB_REPOSITORY" `
  --jq '{repository:.full_name,isFork:.fork,admin:.permissions.admin,upstream:.parent.full_name}'
```

## 2. Enable workflows in the fork

GitHub disables Actions when a repository is first forked. Open the Actions
page and select **I understand my workflows, go ahead and enable them**:

```powershell
Write-Host "https://github.com/$GITHUB_REPOSITORY/actions"
```

Confirm that the workflow is registered and not `disabled_fork`:

```powershell
gh api "repos/$GITHUB_REPOSITORY/actions/workflows" `
  --jq '.workflows[] | {path,state}'
```

## 3. Set the Part 1 values

```powershell
$RESOURCE_GROUP = '<resource-group-name>'
$ENVIRONMENT_NAME = '<initials>01'
$AZURE_CONTAINER_REGISTRY = '<container-registry-name>'
$AZURE_FRONTEND_APP = 'ca-web-<initials>01'
$AZURE_BACKEND_APP = 'ca-api-<initials>01'
```

## 4. Configure Azure and GitHub

```powershell
pwsh ./infra/configure-github-actions.ps1 `
  -ResourceGroup $RESOURCE_GROUP `
  -EnvironmentName $ENVIRONMENT_NAME `
  -ContainerRegistry $AZURE_CONTAINER_REGISTRY `
  -FrontendApp $AZURE_FRONTEND_APP `
  -BackendApp $AZURE_BACKEND_APP `
  -Repository $GITHUB_REPOSITORY
```

The script creates:

| Item | Purpose |
| --- | --- |
| User-assigned managed identity | Gives GitHub a secretless Azure identity |
| Environment-scoped OIDC credential | Trusts only `workshop-deployment` in this fork |
| Custom deployment role assignment | Allows ACR source uploads/builds/status/log access and Container App updates in the dedicated resource group |
| `workshop-deployment` environment | Holds non-secret Azure resource identifiers |
| `main` branch policy | Prevents other branches from using the deployment identity |

The workflow signs in with OIDC and submits both Linux/AMD64 builds to ACR.
It tags both images with the full Git commit SHA, then updates the backend app
followed by the frontend app. Each app pulls images through its system-assigned
identity with `AcrPull` on ACR; admin credentials are disabled.

The app updates are not atomic. Keep API changes compatible with the previous
frontend while a release is in progress. The fixed deployment concurrency group
prevents overlapping releases, but a failed frontend update can leave the
backend on a newer revision. Repair the failure and rerun the workflow.

> [!IMPORTANT]
> If you previously configured Static Web Apps hosting, rerun this setup with
> the new resource names. The new Container Apps identity replaces the old
> deployment target. Remove obsolete `AZURE_STATIC_WEB_APP` environment
> variables and any old `id-gha-swa-<environment>` identity/role assignment after
> confirming it is no longer used. Neither is required by the new workflow.

> [!WARNING]
> Maintainers testing the source repository can temporarily add
> `-SkipForkValidation`. Participants must not use that override.

The script is idempotent and can be rerun with the same values.

## 5. Verify the configuration

```powershell
gh variable list `
  --repo $GITHUB_REPOSITORY `
  --env workshop-deployment
```

Expected variable names:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
AZURE_RESOURCE_GROUP
AZURE_CONTAINER_REGISTRY
AZURE_FRONTEND_APP
AZURE_BACKEND_APP
```

Confirm that the workflow is active:

```powershell
gh workflow list `
  --repo $GITHUB_REPOSITORY `
  --all
```

## 6. Test the deployment loop

```powershell
gh workflow run deploy.yml `
  --repo $GITHUB_REPOSITORY `
  --ref main

gh run list `
  --repo $GITHUB_REPOSITORY `
  --limit 5
```

The workflow runs backend tests, the frontend build, Bicep compilation, and
Docker Compose integration smoke tests before requesting an OIDC token.
It then builds and deploys both application components
and verifies direct backend health, the application root, and proxied `/api/health`.
The runner explicitly installs Bicep and the Container Apps CLI extension;
GitHub-hosted builds use public npm rather than local corporate registry settings.

Azure role assignments can take several minutes to propagate. If the first run
fails with authorization denied, wait two minutes and rerun that run:

```powershell
gh run rerun '<run-id>' `
  --repo $GITHUB_REPOSITORY
```

## Automatic deployment setup complete

Pull requests now validate without Azure access. Merges to `main` deploy the
frontend and API images through the fork's dedicated identity. Container
compute, image builds/storage, and log ingestion may incur Azure charges.
