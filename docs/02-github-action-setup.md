# Configure Automatic Deployment

## Goal

In this section, you connect the GitHub Actions workflows to the Azure resources
created in Part 1. After setup, a completed backend or frontend change merged
to `main` automatically deploys the changed component.

The setup uses GitHub OIDC and Azure managed identities. It does not create or
store an Azure client secret or App Service publishing credential.

## Prerequisites

Before continuing:

- Complete Part 1 and keep its recorded deployment values.
- Use a PowerShell 7 terminal.
- Use the personal fork created and cloned in Part 1.
- Have permission to create managed identities and role assignments at the
  two App Service resource scopes.
- Confirm the backend and frontend workflow files are on your fork's `main`
  branch.

## 1. Check the required access

Confirm that Azure CLI is signed in to the subscription used in Part 1:

```powershell
az account show `
  --query '{subscription:name,id:id,user:user.name}' `
  --output table
```

Confirm GitHub CLI is signed in and that the current repository is your fork:

```powershell
gh auth status
gh repo set-default origin

$GITHUB_REPOSITORY = gh repo view `
  --json nameWithOwner `
  --jq .nameWithOwner

gh api `
  "repos/$GITHUB_REPOSITORY" `
  --jq '{
    repository:.full_name,
    isFork:.fork,
    admin:.permissions.admin,
    upstream:.parent.full_name
  }'
```

The GitHub command must show `isFork: true`, `admin: true`, and upstream
`jasonfarrell-msft/ws-ai-sdlc`.

## 2. Enable workflows in your fork

GitHub disables Actions when a repository is first forked. This setting can
only be enabled from the GitHub website.

Open the Actions tab for your fork:

```powershell
Write-Host "https://github.com/$GITHUB_REPOSITORY/actions"
```

Open the printed URL, then select
**I understand my workflows, go ahead and enable them**.

Confirm that GitHub now reports registered workflows:

```powershell
gh api `
  "repos/$GITHUB_REPOSITORY/actions/workflows" `
  --jq '{
    registeredWorkflows:.total_count,
    workflows:[.workflows[] | {path,state}]
  }'
```

The `registeredWorkflows` value must be greater than zero, both workshop
workflow paths must appear, and neither workflow should report
`disabled_fork`. The setup script checks these conditions before creating
Azure identities or GitHub environments. If the count is zero or a workflow
reports `disabled_fork`, confirm that you enabled workflows. If a path is
missing, confirm that both workflow files are present on your fork's `main`
branch.

## 3. Set the Part 1 deployment values

Use the values printed by `infra/deploy.ps1`:

```powershell
$RESOURCE_GROUP = '<resource-group-name>'
$ENVIRONMENT_NAME = '<initials>01'
$AZURE_BACKEND_APP_SERVICE = '<backend-app-name>'
$AZURE_FRONTEND_APP_SERVICE = '<frontend-app-name>'
```

Use the complete environment name printed by the deployment script. It consists
of your lowercase initials followed by the fixed `01` suffix; for example,
initials `JRF` produce `jrf01`.

## 4. Configure Azure and GitHub access

Run the setup script from the repository root:

```powershell
pwsh ./infra/configure-github-actions.ps1 `
  -ResourceGroup $RESOURCE_GROUP `
  -EnvironmentName $ENVIRONMENT_NAME `
  -BackendAppService $AZURE_BACKEND_APP_SERVICE `
  -FrontendAppService $AZURE_FRONTEND_APP_SERVICE `
  -Repository $GITHUB_REPOSITORY
```

The script creates and configures:

| Item | Purpose |
| --- | --- |
| Backend deployment identity | Updates only the backend App Service |
| Frontend deployment identity | Updates only the frontend App Service |
| Two OIDC federated credentials | Let GitHub authenticate without stored secrets |
| `workshop-backend` environment | Supplies backend Azure resource variables |
| `workshop-frontend` environment | Supplies frontend Azure resource variables |
| `AZURE_BACKEND_URL` repository variable | Configures the frontend production build; derived from the backend App Service name |
| `main` environment branch policies | Prevent non-`main` deployment jobs from using either identity |

The script derives the backend URL as
`https://<backend-app-name>.azurewebsites.net`. It also verifies that the target
is your fork of the workshop repository, confirms that you enabled Actions for
the fork, configures its Actions permissions, and enables both workflows.

> [!WARNING]
> Maintainers testing this setup against the source repository can temporarily
> add `-SkipForkValidation` to the command. This testing-only override bypasses
> only the fork-parent check and must not be used for participant setup. Remove
> the parameter after source-repository testing is complete.

No manual deployment approval is configured. The path-filtered workflows deploy
automatically after a matching change reaches `main`.

The script is safe to run again with the same values if setup is interrupted.

## 5. Verify the configuration

Confirm the backend environment variables:

```powershell
gh variable list `
  --repo $GITHUB_REPOSITORY `
  --env workshop-backend
```

Expected names:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
AZURE_RESOURCE_GROUP
AZURE_BACKEND_APP_SERVICE
```

Confirm the frontend environment variables:

```powershell
gh variable list `
  --repo $GITHUB_REPOSITORY `
  --env workshop-frontend
```

Expected names:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
AZURE_RESOURCE_GROUP
AZURE_APP_SERVICE
```

Confirm the repository variable:

```powershell
gh variable list `
  --repo $GITHUB_REPOSITORY |
  Select-String '^AZURE_BACKEND_URL'
```

Each environment must return exactly one row.

Confirm that both workflows are active in your fork:

```powershell
gh workflow list `
  --repo $GITHUB_REPOSITORY `
  --all
```

## 6. Test the deployment loop

The workflows normally run automatically when matching files change on `main`.
For an initial access check, start each workflow manually from `main`:

```powershell
gh workflow run backend.yml `
  --repo $GITHUB_REPOSITORY `
  --ref main

gh workflow run frontend.yml `
  --repo $GITHUB_REPOSITORY `
  --ref main
```

List the runs:

```powershell
gh run list `
  --repo $GITHUB_REPOSITORY `
  --limit 10
```

Both runs should complete successfully without an approval step. The backend
workflow ZIP-deploys the Python application, and the frontend workflow builds
and ZIP-deploys the site. Each workflow verifies its deployed endpoint before
reporting success.

Azure role assignments can take several minutes to propagate. If either run
fails with an authorization error, wait two minutes, copy its run ID from the
list, and retry it:

```powershell
gh run rerun '<run-id>' `
  --repo $GITHUB_REPOSITORY
```

## Automatic deployment setup complete

The deployment loop is ready. Pull requests validate changes without Azure
access. After completed work is merged to `main`, backend and frontend changes
deploy to their respective App Services automatically.
