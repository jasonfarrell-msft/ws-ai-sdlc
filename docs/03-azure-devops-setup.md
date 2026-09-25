# Connect Azure Boards to GitHub

## Goal

In this part, you create an Azure DevOps project and connect its Azure Boards
work items to your fork of the workshop repository.

You also establish a local Azure DevOps CLI context. Any local tool running as
your user that can invoke Azure CLI can then read or update the project with
your permissions.

By the end of this part, you will have:

- A private Azure DevOps project
- The Azure Boards GitHub App connected only to your fork
- Azure DevOps CLI defaults for your organization and project
- A work item that verifies your Boards access

The examples recommend `Support-Sim` as the project name. You may choose a
different name.

## Prerequisites

Before continuing:

- Complete Part 1 and use the personal fork created there.
- Have an Azure DevOps organization in the same Microsoft Entra tenant as your
  user account.
- Be a member, rather than a guest, in that tenant. Guest users require
  PAT-based Azure DevOps CLI authentication, which this workshop does not use.
- Have permission to create projects in that organization.
- Have administrator access to your GitHub fork.
- Use a PowerShell 7 terminal from the repository root.
- Install Azure CLI and GitHub CLI.

> [!IMPORTANT]
> This part uses your interactive Microsoft Entra sign-in. Do not create a
> personal access token (PAT), service principal secret, or other stored
> credential for this workshop.

## 1. Set the organization, project, and repository

Set your Azure DevOps organization URL. Keep the recommended project name, or
replace it with another name:

```powershell
$AZURE_DEVOPS_ORGANIZATION = 'https://dev.azure.com/<organization-name>'
$AZURE_DEVOPS_PROJECT = 'Support-Sim'
```

Get the name of your GitHub fork:

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

## 2. Install the Azure DevOps CLI extension

Install or update the Azure DevOps extension for Azure CLI:

```powershell
az extension add `
  --name azure-devops `
  --upgrade

az extension show `
  --name azure-devops `
  --query '{name:name,version:version}' `
  --output table
```

The extension supplies the `az devops` and `az boards` command groups.

## 3. Sign in as yourself

Sign in interactively with the Microsoft Entra account that has access to your
Azure DevOps organization:

```powershell
az login

az account show `
  --query '{tenantId:tenantId,user:user.name}' `
  --output table
```

If the browser cannot open, use device-code authentication:

```powershell
az login --use-device-code
```

If your account belongs to more than one tenant, sign in to the tenant that
contains the Azure DevOps organization:

```powershell
az login `
  --tenant '<tenant-id>'
```

Confirm that your signed-in identity can reach the organization:

```powershell
az devops project list `
  --organization $AZURE_DEVOPS_ORGANIZATION `
  --query 'value[].{name:name,visibility:visibility}' `
  --output table
```

The command may return no projects if the organization is empty, but it must
not return an authentication or authorization error.

> [!WARNING]
> Do not run `az devops login` for this workshop. That command stores a PAT for
> an organization. The Azure DevOps extension can use the interactive
> `az login` session instead.

## 4. Create the Azure DevOps project

Create a private project that uses the Agile work item process:

```powershell
az devops project create `
  --organization $AZURE_DEVOPS_ORGANIZATION `
  --name $AZURE_DEVOPS_PROJECT `
  --description 'Support Desk Simulator workshop project' `
  --process Agile `
  --source-control git `
  --visibility private `
  --query '{name:name,state:state,visibility:visibility}' `
  --output table
```

Project names must be unique within an Azure DevOps organization. If your
chosen name already exists, either use that project if you administer it or
change `$AZURE_DEVOPS_PROJECT` and run the command again.

The command creates an Azure Repos repository with the project. Leave it empty;
the workshop source remains in your GitHub fork.

## 5. Configure the local Azure DevOps context

Set the organization and project as defaults for later commands:

```powershell
az devops configure `
  --defaults `
  organization=$AZURE_DEVOPS_ORGANIZATION `
  project=$AZURE_DEVOPS_PROJECT

az devops configure `
  --list
```

Verify that the defaults resolve to the new project:

```powershell
az devops project show `
  --project $AZURE_DEVOPS_PROJECT `
  --query '{name:name,state:state,visibility:visibility}' `
  --output table
```

These defaults are stored in your local Azure CLI configuration. Local tools
running as the same operating-system user can invoke `az devops` and
`az boards` without receiving a copied password or PAT.

> [!NOTE]
> A remote or hosted agent cannot inherit this local sign-in. It needs its own
> approved authentication and authorization configuration.

## 6. Connect the Azure Boards GitHub App

Open the project in Azure DevOps:

```powershell
az devops project show `
  --project $AZURE_DEVOPS_PROJECT `
  --open
```

In the Azure DevOps browser window:

1. Select **Project settings**.
2. Select **GitHub connections**.
3. Select **Connect your GitHub account**.
4. Select the GitHub account that owns your fork and authenticate if prompted.
5. In **Add GitHub Repositories**, clear every repository except
   `$GITHUB_REPOSITORY`, then select **Save**.
6. On GitHub, select **Approve, Install, & Authorize** for the Azure Boards app.
7. Return to Azure DevOps and confirm that the connection lists your fork.

GitHub organizations may require an organization owner to approve the app
installation. A fork under your personal account does not require approval
from the upstream repository owner.

Grant the app access only to the workshop fork. Do not grant access to every
repository in your account.

The connection links Azure Boards to GitHub. It does not move the source code
to Azure Repos and does not grant GitHub access to your Azure subscription.

## 7. Verify Boards access from the CLI

Create a task that records completion of this setup:

```powershell
$WORK_ITEM_ID = az boards work-item create `
  --type Task `
  --title 'Connect Azure Boards to the workshop repository' `
  --description "Connected to $GITHUB_REPOSITORY" `
  --query id `
  --output tsv

az boards work-item show `
  --id $WORK_ITEM_ID `
  --fields System.Id,System.Title,System.State `
  --output table
```

The command must return the new work item without requiring another sign-in.
This verifies the identity, organization default, project default, and Boards
permissions that local tools will use.

## 8. Use work item links in GitHub

Include the Azure Boards work item ID in a commit message or pull request
description:

```text
AB#<work-item-id>
```

For the task created in the previous step, PowerShell can generate the link
text:

```powershell
"AB#$WORK_ITEM_ID"
```

After a referenced commit or pull request is pushed to the connected fork,
open the work item in Azure Boards and check its **Development** section. The
GitHub commit or pull request should appear there.

An `AB#<work-item-id>` reference in a pull request title or comment does not
create a work item link.

Use the same `AB#<work-item-id>` syntax in later workshop parts so code changes
remain traceable to their Azure Boards work.

## Azure Boards setup complete

Your Azure DevOps project is connected to your GitHub fork, and your local
Azure DevOps CLI context is ready. Local assistants and command-line tools can
use `az boards` commands with your signed-in identity and your configured
organization and project defaults.

To inspect the active context at any time, run:

```powershell
az account show `
  --query '{tenantId:tenantId,user:user.name}' `
  --output table

az devops configure `
  --list

az devops project show `
  --project $AZURE_DEVOPS_PROJECT `
  --query '{name:name,state:state,visibility:visibility}' `
  --output table
```
