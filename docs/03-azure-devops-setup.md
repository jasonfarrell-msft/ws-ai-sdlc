# Part 3: Connect Azure Boards to GitHub

Run the commands in order in a PowerShell 7 terminal from your fork. This part
creates an Azure DevOps project, connects Azure Boards to your GitHub fork, and
configures the Azure DevOps CLI for later workshop parts.

## Prerequisites

- Complete [Part 1](01-azure-foundation.md) and use the personal fork created
  there.
- Have an Azure DevOps organization in the same Microsoft Entra tenant as your
  account. Your account must be a member of that tenant, not a guest.
- Have permission to create projects in the Azure DevOps organization.
- Have administrator access to your GitHub fork.
- Install [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell),
  [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), and
  [GitHub CLI](https://cli.github.com/).

> [!IMPORTANT]
> Sign in with Microsoft Entra ID. Do not create or use a personal access token
> (PAT) or other stored credential for this workshop.

## 1. Set the organization, project, and fork

Set your Azure DevOps organization URL and project name:

```powershell
$AZURE_DEVOPS_ORGANIZATION = "https://dev.azure.com/<organization-name>"
$AZURE_DEVOPS_PROJECT = "Support-Sim"
```

Replace `<organization-name>` with your Azure DevOps organization name. Keep
`Support-Sim` or choose a project name that is not already in use.

Get your personal fork and confirm it belongs to the workshop:

```powershell
gh auth login
$githubUser = gh api user --jq '.login'
$GITHUB_REPOSITORY = "$githubUser/ws-ai-sdlc"
gh api "repos/$GITHUB_REPOSITORY" `
  --jq '{name: .full_name, isFork: .fork, admin: .permissions.admin, parent: .parent.full_name}'
```

The output must show your fork, `isFork: true`, `admin: true`, and parent
`jasonfarrell-msft/ws-ai-sdlc`.

## 2. Install the Azure DevOps CLI extension

Install or update the extension:

```powershell
az extension add --name azure-devops --upgrade
```

## 3. Sign in and check organization access

Sign in with the Microsoft Entra account that has access to your Azure DevOps
organization:

```powershell
az login
```

## 4. Create the Azure DevOps project

Check whether the project name is already in use:

```powershell
az devops project list `
  --organization $AZURE_DEVOPS_ORGANIZATION `
  --output table
```

Create a private project using the Agile process:

```powershell
az devops project create `
  --name $AZURE_DEVOPS_PROJECT `
  --organization $AZURE_DEVOPS_ORGANIZATION `
  --process Agile `
  --visibility private `
  --source-control git `
  --output table
```

If the project already exists, use it only if you administer it; otherwise
change `$AZURE_DEVOPS_PROJECT` and run the command again. The project creates
an empty Azure Repos repository. Keep the workshop source in your GitHub fork.

## 5. Configure and verify the local CLI context

Set the organization and project defaults:

```powershell
az devops configure --defaults `
  "organization=$AZURE_DEVOPS_ORGANIZATION" `
  "project=$AZURE_DEVOPS_PROJECT"
```

Verify the defaults and project:

```powershell
az devops configure --list
az devops project show `
  --organization $AZURE_DEVOPS_ORGANIZATION `
  --project $AZURE_DEVOPS_PROJECT `
  --output table
```

These defaults are stored in your local Azure CLI configuration. Local tools
running as your user can use `az boards` and `az devops` with your signed-in
identity. Remote or hosted tools need their own approved authentication.

## 6. Connect the Azure Boards GitHub App

Open the Azure DevOps project:

```powershell
az devops project show `
  --organization $AZURE_DEVOPS_ORGANIZATION `
  --project $AZURE_DEVOPS_PROJECT `
  --open
```

In Azure DevOps:

1. Open **Project settings** > **GitHub connections** and select **Connect your
   GitHub account**.
2. Select the GitHub account that owns your fork. In **Add GitHub Repositories**,
   select only `$GITHUB_REPOSITORY`, then select **Save**.
3. On GitHub's **Install & Authorize Azure Boards** page, select the account
   that owns the fork. Set **Repository access** to **Only select repositories**
   and select only `$GITHUB_REPOSITORY`.
4. Select **Approve, Install, & Authorize** (or **Install & Authorize**).
   If GitHub shows **Request**, submit it and ask an organization owner to
   approve the Azure Boards app installation.
5. Return to Azure DevOps and confirm the connection lists your fork.

Do not grant the app access to every repository. A GitHub organization may
require an owner to approve the app; a personal fork does not require approval
from the upstream repository owner.

## 7. Verify Boards access

Create one task to verify that your account can write to the project:

```powershell
az boards work-item create `
  --type Task `
  --title "Verify Azure Boards CLI access" `
  --description "Confirm Azure Boards CLI access for the workshop project." `
  --output table
```

Keep the returned work item ID for reference. This connection links Azure
Boards to your GitHub fork; it does not move source code to Azure Repos or grant
GitHub access to your Azure subscription.
