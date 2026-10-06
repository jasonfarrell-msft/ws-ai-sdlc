# Configure Automatic Deployment

## Goal

Connect the fork's GitHub Actions workflow to the App Service Web App created in
Part 1. Pull requests validate without Azure access. A change merged to `main`
builds one application package and deploys it to the Web App.

The setup uses GitHub OIDC and one Azure user-assigned managed identity. It
stores no Azure client secret or App Service publishing credential in GitHub.

## Prerequisites

- Complete Part 1 and retain its deployment output.
- Use the personal fork created in Part 1.
- Use a PowerShell 7 terminal with authenticated Azure and GitHub CLIs.
- Have permission to create a managed identity and assign a built-in role.
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
$AZURE_WEB_APP = '<web-app-name>'
```

## 4. Configure Azure and GitHub

```powershell
./infra/configure-github-actions.ps1 `
  -ResourceGroup $RESOURCE_GROUP `
  -EnvironmentName $ENVIRONMENT_NAME `
  -WebApp $AZURE_WEB_APP `
  -Repository $GITHUB_REPOSITORY
```

The script creates:

| Item | Purpose |
| --- | --- |
| User-assigned managed identity | Gives GitHub a secretless Azure identity |
| Environment-scoped OIDC credential | Trusts only `workshop-deployment` in this fork |
| Built-in `Website Contributor` assignment | Deploys only to the generated Web App |
| `workshop-deployment` environment | Holds non-secret Azure resource identifiers |
| `main` branch policy | Prevents other branches from using the deployment identity |

The built-in role is scoped to the Web App, not the resource group. The script
also removes obsolete Container Apps environment variables if they exist.

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
AZURE_WEB_APP
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

The workflow:

1. Runs the backend regression tests.
2. Type-checks and builds the frontend.
3. Compiles the Bicep infrastructure.
4. Runs the combined frontend/API smoke tests.
5. Builds one ZIP deployment package.
6. Signs in to Azure through OIDC.
7. Deploys the package to App Service.
8. Verifies the health endpoint and application root.

Azure role assignments can take several minutes to propagate. If the first run
fails with authorization denied, wait two minutes and rerun that run:

```powershell
gh run rerun '<run-id>' `
  --repo $GITHUB_REPOSITORY
```

## Automatic deployment setup complete

Pull requests now validate without Azure access. Merges to `main` deploy the
frontend and API together as one App Service package.
