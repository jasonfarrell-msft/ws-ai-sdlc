# Part 6: Coding Agent Delivery

## Section 1: Prepare Foundry Work for Assignment

### Goal

In this section, you prepare the first two Azure Boards Tasks that will be sent
to GitHub Copilot cloud agent:

- The existing Task that creates the Microsoft Foundry Bicep
- A new Task that adds Foundry infrastructure deployment to the existing
  GitHub Actions workflow when changes under `infra/` reach `main`

You add explicit implementation instructions to the Bicep Task so the coding
agent receives project-specific guidance rather than relying only on general
repository context. This demonstrates how a team can customize individual work
items when a change needs tighter boundaries.

Part 5 used one Task per User Story as a Sprint-planning guardrail. This section
deliberately adds one sibling Task because the deployment workflow is a
separately deliverable and independently verifiable artifact that depends on
the Bicep entry point.

This section changes Azure Boards only. It does not send either Task to the
coding agent or create a pull request.

### Prerequisites

Before continuing:

- Complete Part 5.
- Confirm that the Azure AI Foundry enablement User Story from Part 5 exists in
  Azure Boards.
- Confirm that the Story has an existing Task for creating the Foundry Bicep.
- Confirm that `az devops configure --list` shows the intended Azure DevOps
  organization and project.
- Open the repository in VS Code so the specialist can inspect the existing
  `infra/` and `.github/workflows/` conventions.

> [!NOTE]
> Microsoft now documents the service as **Microsoft Foundry**. The current
> Microsoft Foundry Bicep quickstart deploys a Foundry resource and project
> using `Microsoft.CognitiveServices/accounts` and
> `Microsoft.CognitiveServices/accounts/projects`. The Task instructions below
> require the coding agent to verify the latest generally available resource
> types and API versions at implementation time rather than relying on a
> version copied into this workshop. The existing Story can retain its earlier
> Azure AI Foundry title; new instructions use the current service name.

> [!IMPORTANT]
> The existing GitHub Actions identity has `Website Contributor` scoped to the
> Web App. That access cannot deploy Microsoft Foundry resources at resource
> group scope. The workflow Task must identify the exact additional
> least-privilege access required and stop for human approval. The coding agent
> must not grant or broaden its own Azure permissions.

### 1. Review the Foundry work items

Open the Foundry enablement User Story and its existing Bicep Task in Azure
Boards. Record their IDs:

```powershell
$FOUNDRY_STORY_ID = <foundry-story-id>
$FOUNDRY_BICEP_TASK_ID = <foundry-bicep-task-id>
```

Read both items before changing them:

```powershell
az boards work-item show `
  --id $FOUNDRY_STORY_ID `
  --detect false `
  --expand none `
  --output table

az boards work-item show `
  --id $FOUNDRY_BICEP_TASK_ID `
  --detect false `
  --expand none `
  --output table
```

Confirm that:

- The Task belongs to the expected Foundry enablement User Story.
- The Task has not already been completed.
- Another Task does not already cover infrastructure deployment from `main`.
- The existing `.github/workflows/deploy.yml` does not already deploy the
  Bicep entry point.

If a matching deployment Task already exists, update that Task rather than
creating a duplicate.

### 2. Define the Task customizations

Select `azure-boards-specialist` from the agent picker and submit the following
prompt. Replace both work item ID placeholders before submitting it.

```text
Prepare two Azure Boards Tasks for later assignment to GitHub Copilot cloud
agent. Follow the standards in your Azure Boards specialist profile.

Run az devops configure --list to establish the intended Azure DevOps
organization and project. Confirm the current identity, project, and Agile
process. Use one available Azure Boards integration or the Azure DevOps CLI
consistently for all Azure Boards write operations. Stop if it resolves to a
different organization or project. Never request or create a personal access
token or other credential.

Use these existing work items:
- Foundry enablement User Story: <foundry-story-id>
- Existing Foundry Bicep Task: <foundry-bicep-task-id>

First inspect the repository and read both work items from Azure Boards. Search
the Story's child Tasks for existing Bicep deployment workflow work. Do not
create a duplicate.

Propose an update to the existing Foundry Bicep Task. Preserve its approved
scope and acceptance criteria, then add a clearly labeled "Special
instructions for the coding agent" section with these requirements:

- Place every Bicep file and Bicep parameter file under the repository's
  infra/ directory.
- Extend the established resource-group deployment entry point at
  infra/main.bicep and its existing parameter file. Do not create a competing
  top-level deployment entry point.
- Use the deployment resource group's location for location-capable resources
  unless an approved requirement explicitly specifies another location. In
  Bicep, default location parameters to resourceGroup().location.
- Verify that the resource group's region supports the required Microsoft
  Foundry resource and model SKU. If it does not, stop and report the
  limitation rather than silently choosing another region.
- Implement the current Microsoft Foundry resource and project model. Before
  writing Bicep, verify the latest generally available resource types and API
  versions in the official Microsoft Foundry Bicep quickstart and Azure
  Resource Manager template reference. Do not use preview API versions when a
  GA version supports the requirement.
- Use the current Microsoft Foundry naming and architecture. Do not substitute
  legacy Azure AI Foundry hub-based or older Azure OpenAI deployment patterns.
- Use managed identity and least-privilege RBAC. Do not add API keys, client
  secrets, connection strings, or other stored credentials.
- Keep the change focused on this Task and include the validation commands and
  results in the pull request description.

Also propose one new Task under the same Foundry enablement User Story:

Title: Deploy Foundry infrastructure changes from main

The Task must require:
- Extend the existing .github/workflows/deploy.yml rather than creating a
  second workflow with an overlapping main and infra/** trigger.
- Preserve the existing main and infra/** trigger behavior and the
  workshop-deployment concurrency controls.
- Deploy infra/main.bicep with its established parameter file to the approved
  Azure resource group.
- Reuse infra/validate.ps1, or run an equivalent resource-group what-if against
  the same entry point, before deployment.
- Use the existing workshop-deployment GitHub environment because its
  federated credential is environment-scoped.
- Set job-level permissions to id-token: write and contents: read, then
  authenticate with azure/login using the existing AZURE_CLIENT_ID,
  AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID, and AZURE_RESOURCE_GROUP environment
  variables.
- Do not add a client secret, publishing profile, stored Azure credential, or
  another federated credential.
- Document the exact additional least-privilege Azure role assignments needed
  for the resource-group deployment and any approved Foundry RBAC assignments.
  Stop for human approval; do not create, invent, or broaden the workflow
  identity's access.
- Explicit failure when validation, authentication, or deployment fails.
- A completion condition and evidence that can be checked from the workflow
  file and a successful workflow run.
- A note that deploying Foundry resources and models can incur Azure charges;
  identify the resources and SKUs whose cost must be approved before the first
  deployment.

The new workflow Task depends on the Bicep Task because it needs the approved
entry point and parameters. Do not create additional Tasks, assign either Task,
send work to the coding agent, create a branch, or create a pull request.

Before writing anything:
1. Report the resolved organization, project, process, identity, Story, and
   existing Bicep Task.
2. Identify any existing deployment Task that should be reused.
3. Present the exact Bicep Task update and new workflow Task.
4. List assumptions, open questions, dependencies, and exact create, update,
   and link operations.
5. Ask for explicit approval.

After I approve:
1. Update only the approved Bicep Task fields.
2. Create or update only the approved workflow Task.
3. Set the workflow Task's iteration path to the same Sprint iteration as the
   Foundry enablement User Story.
4. Add a Parent link from the workflow Task to the Foundry enablement User
   Story.
5. Add a Predecessor/Successor link with the Bicep Task as the predecessor and
   the workflow Task as the successor.
6. Read the Story and both Tasks back from Azure Boards.
7. Report their IDs, titles, states, iteration paths, parent IDs, links, URLs,
   and verification
   results.

Stop and report the exact failure if an item cannot be updated, created,
linked, or verified. Do not create a replacement or report success-shaped
fallback output.
```

The specialist should stop after presenting the proposal. Confirm that the
Bicep instructions are explicit without prescribing unsupported implementation
details. Confirm that the workflow Task deploys only after changes under
`infra/` reach `main`.

Approve the exact update, create, and link operations only after resolving all
reported assumptions and open questions.

### 3. Review the prepared Tasks

After the approved changes are complete, replace the workflow Task placeholder
with the ID reported by the specialist:

```powershell
$FOUNDRY_WORKFLOW_TASK_ID = <foundry-workflow-task-id>
$WORK_ITEM_IDS = @(
  $FOUNDRY_STORY_ID,
  $FOUNDRY_BICEP_TASK_ID,
  $FOUNDRY_WORKFLOW_TASK_ID
)

foreach ($id in $WORK_ITEM_IDS) {
  az boards work-item show `
    --id $id `
    --detect false `
    --expand none `
    --fields System.Id,System.WorkItemType,System.Title,System.Parent,System.State,System.IterationPath,System.AssignedTo `
    --output table
}

foreach ($id in $WORK_ITEM_IDS) {
  az boards work-item show `
    --id $id `
    --detect false `
    --expand relations `
    --output json
}
```

Confirm that:

- Both Tasks have the Foundry enablement User Story as their parent.
- The workflow Task has the same Sprint iteration path as the Story and Bicep
  Task.
- The Bicep Task contains every approved special instruction.
- The workflow Task extends `.github/workflows/deploy.yml` without adding an
  overlapping workflow.
- The workflow Task requires OIDC and does not request a stored Azure
  credential.
- The Bicep Task is the predecessor of the workflow Task.
- Neither Task is assigned to the coding agent.
- No branch or pull request was created.

If a field or link is wrong, ask the specialist to correct only that item and
verify it again. Do not create a replacement.

### Foundry work ready for assignment

The Foundry enablement Story now contains a customized Bicep Task and one
deployment-workflow Task. Both remain in Azure Boards and are ready for the
assignment exercise in the next section of Part 6.

## Public documentation used for validation

- [Deploy a Foundry resource by using Bicep](https://learn.microsoft.com/azure/foundry/how-to/create-resource-template)
- [Integrate Copilot cloud agent with Azure Boards](https://docs.github.com/copilot/how-tos/copilot-integrations/integrate-cloud-agent-with-azure-boards)
- [Configure OpenID Connect in Azure](https://docs.github.com/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-azure)
- [GitHub Actions workflow syntax](https://docs.github.com/actions/reference/workflows-and-actions/workflow-syntax)
