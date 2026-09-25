# Configure Automatic Deployment

## Goal

In this section, you connect the GitHub Actions workflows to the Azure resources
created in Part 1. After setup, a completed backend or frontend change merged
to `main` automatically deploys the changed component.

The setup uses GitHub OIDC and Azure managed identities. It does not create or
store an Azure client secret, registry password, or App Service publishing
credential.

## Prerequisites

Before continuing:

- Complete Part 1 and keep its recorded deployment values.
- Use a PowerShell 7 terminal.
- Use the personal fork created and cloned in Part 1.
- Have permission to create managed identities and role assignments at the
  three Azure resource scopes.
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

gh repo view `
  $GITHUB_REPOSITORY `
  --json nameWithOwner,isFork,viewerCanAdminister,parent `
  --jq '{
    repository:.nameWithOwner,
    isFork:.isFork,
    admin:.viewerCanAdminister,
    upstream:.parent.nameWithOwner
  }'
```

The GitHub command must show `isFork: true`, `admin: true`, and upstream
`jasonfarrell-msft/ws-ai-sdlc`.

## 2. Set the Section 1 deployment values

Use the values printed by `infra/deploy.ps1`:

```powershell
$RESOURCE_GROUP = '<resource-group-name>'
$RUN_IDENTIFIER = '<18-character-run-identifier>'
$AZURE_CONTAINER_REGISTRY = '<registry-name>'
$AZURE_CONTAINER_APP = '<container-app-name>'
$AZURE_APP_SERVICE = '<frontend-app-name>'
$AZURE_BACKEND_URL = 'https://<backend-app>.<environment>.azurecontainerapps.io'
```

The backend URL must use HTTPS and must not end with `/`.

## 3. Configure Azure and GitHub access

Run the setup script from the repository root:

```powershell
pwsh ./infra/configure-github-actions.ps1 `
  -ResourceGroup $RESOURCE_GROUP `
  -EnvironmentName $RUN_IDENTIFIER `
  -ContainerRegistry $AZURE_CONTAINER_REGISTRY `
  -ContainerApp $AZURE_CONTAINER_APP `
  -AppService $AZURE_APP_SERVICE `
  -BackendUrl $AZURE_BACKEND_URL `
  -Repository $GITHUB_REPOSITORY
```

The script creates and configures:

| Item | Purpose |
| --- | --- |
| Backend deployment identity | Builds in ACR and updates only the Container App |
| Frontend deployment identity | Updates only the App Service |
| Two OIDC federated credentials | Let GitHub authenticate without stored secrets |
| `workshop-backend` environment | Supplies backend Azure resource variables |
| `workshop-frontend` environment | Supplies frontend Azure resource variables |
| `AZURE_BACKEND_URL` repository variable | Configures the frontend production build |
| `main` environment branch policies | Prevent non-`main` deployment jobs from using either identity |

The script also verifies that the target is your fork of the workshop
repository, enables GitHub Actions for the fork, and enables both workflows.

No manual deployment approval is configured. The path-filtered workflows deploy
automatically after a matching change reaches `main`.

The script is safe to run again with the same values if setup is interrupted.

## 4. Verify the configuration

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
AZURE_CONTAINER_REGISTRY
AZURE_CONTAINER_APP
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

Confirm that both environments allow only `main`:

```powershell
foreach ($environmentName in 'workshop-backend', 'workshop-frontend') {
  gh api `
    "repos/$GITHUB_REPOSITORY/environments/$environmentName/deployment-branch-policies" `
    --jq '.branch_policies[] | {name:name,type:type}'
}
```

Each environment must return one branch policy with name `main` and type
`branch`.

Confirm that both workflows are active in your fork:

```powershell
gh workflow list `
  --repo $GITHUB_REPOSITORY `
  --all
```

## 5. Test the deployment loop

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
workflow builds and deploys a digest-pinned image, and the frontend workflow
builds and ZIP deploys the site. Each workflow verifies its deployed endpoint
before reporting success.

Azure role assignments can take several minutes to propagate. If either run
fails with an authorization error, wait two minutes, copy its run ID from the
list, and retry it:

```powershell
gh run rerun '<run-id>' `
  --repo $GITHUB_REPOSITORY
```

## Automatic deployment setup complete

The deployment loop is ready. Pull requests validate changes without Azure
access. After completed work is merged to `main`, backend changes deploy to the
Container App and frontend changes deploy to App Service automatically.
