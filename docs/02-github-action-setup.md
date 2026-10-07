# Configure Automatic Deployment

## Goal

Connect the fork's GitHub Actions workflow to the App Service Web App created in
Part 1. Pull requests restore, format-check, build, test, publish, and smoke-test
the .NET application without Azure access. Merges to `main` deploy the same
published output.

The setup uses GitHub OIDC and one Azure user-assigned managed identity. It
stores no Azure client secret or App Service publishing credential.

The workflow uses only the .NET SDK and NuGet. It contains no Node.js, npm,
JavaScript package, Python, or frontend package-manager step.

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

Open the fork's Actions page and select
**I understand my workflows, go ahead and enable them**:

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

> [!WARNING]
> Maintainers testing the source repository can temporarily add
> `-SkipForkValidation`. Participants must not use that override.

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

1. Installs and selects the exact .NET 10.0.300 SDK declared by
   [`global.json`](../global.json).
2. Restores the committed NuGet lock files in locked mode.
3. Verifies C# and Razor formatting.
4. Builds and runs the MSTest suite.
5. Publishes and smoke-tests the complete Blazor/API application.
6. Compiles the Bicep infrastructure.
7. Signs in to Azure through OIDC.
8. ZIP-deploys the published .NET output to App Service.
9. Verifies the health endpoint and rendered application.

No workflow step contacts npm or a public npm registry.

The SDK version is part of the locked dependency graph. ASP.NET Core Web SDK
projects receive an implicit `Microsoft.AspNetCore.App.Internal.Assets`
reference from the installed targeting pack, so allowing the SDK to roll
forward can make locked restore fail even when no project package reference
changed. In both validation and deployment jobs, `setup-dotnet` reads the exact
version from the root `global.json`, and the workflow logs `dotnet --version`
before restore. Regenerate lock files only when intentionally changing the SDK,
and use that selected SDK for the regeneration.

If you created your fork before this parent-repository fix, sync the parent
repository's latest `main` into your fork before running the workflow again.
At minimum, copy the updated `global.json` and
`.github/workflows/deploy.yml` into your fork together; changing only one leaves
SDK installation and selection inconsistent. Keep the committed lock files
unchanged for SDK 10.0.300.

Azure role assignments can take several minutes to propagate. If the first run
fails with authorization denied, wait two minutes and rerun it:

```powershell
gh run rerun '<run-id>' `
  --repo $GITHUB_REPOSITORY
```

## Automatic deployment setup complete

Pull requests validate without Azure access. Merges to `main` deploy the Blazor
frontend and ASP.NET Core backend together as one .NET App Service package.
