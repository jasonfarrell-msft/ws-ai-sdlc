# Configure Automatic Deployment

## Goal

Connect the fork's GitHub Actions workflow to the Static Web App created in
Part 1. Pull requests validate without Azure access. A change merged to `main`
atomically deploys the frontend and managed API.

The setup uses GitHub OIDC and one Azure user-assigned managed identity. It
stores no Azure client secret or Static Web Apps deployment token in GitHub.

## Prerequisites

- Complete Part 1 and retain its deployment output.
- Use the personal fork created in Part 1.
- Use a PowerShell 7 terminal with authenticated Azure and GitHub CLIs.
- Have permission to create a managed identity and role assignment at the
  Static Web App resource scope. Part 1 also requires permission to create the
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
$AZURE_STATIC_WEB_APP = '<static-web-app-name>'
```

## 4. Configure Azure and GitHub

```powershell
pwsh ./infra/configure-github-actions.ps1 `
  -ResourceGroup $RESOURCE_GROUP `
  -EnvironmentName $ENVIRONMENT_NAME `
  -StaticWebApp $AZURE_STATIC_WEB_APP `
  -Repository $GITHUB_REPOSITORY
```

The script creates:

| Item | Purpose |
| --- | --- |
| User-assigned managed identity | Gives GitHub a secretless Azure identity |
| Environment-scoped OIDC credential | Trusts only `workshop-deployment` in this fork |
| Custom deployment role assignment | Allows only app read and deployment-token retrieval on the generated Static Web App |
| `workshop-deployment` environment | Holds non-secret Azure resource identifiers |
| `main` branch policy | Prevents other branches from using the deployment identity |

The workflow signs in with OIDC, retrieves the Azure-generated deployment token
at run time, masks it, and passes it directly to the pinned Static Web Apps
deployment action. The token is never stored in the repository or a GitHub
secret.

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
AZURE_STATIC_WEB_APP
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

The workflow runs backend tests, the frontend build, and Bicep compilation
before requesting an OIDC token. It then deploys both application components
and verifies the application root and `/api/health`.

Azure role assignments can take several minutes to propagate. If the first run
fails with authorization denied, wait two minutes and rerun that run:

```powershell
gh run rerun '<run-id>' `
  --repo $GITHUB_REPOSITORY
```

## Automatic deployment setup complete

Pull requests now validate without Azure access. Merges to `main` deploy the
frontend and API together through the fork's dedicated identity.
