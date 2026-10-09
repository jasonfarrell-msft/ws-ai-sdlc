# Part 5: Sprint Planning

## Goal

In this part, you turn the **Constrained Ticket Status Q&A** Feature from Part 4
into a small, ready-to-execute Sprint Backlog.

You use the Azure Boards specialist to select the smallest workshop set of
product-facing User Stories that can produce a usable Increment. For this
exercise, that means two User Stories, or three only when the third is necessary
for a usable demo. You then create a limited number of Tasks, place the selected
work in one Sprint, and verify that the resulting Sprint Backlog is ready for
implementation.

By the end of this part, you will have:

- Two or three selected User Stories from the core Feature
- The pre-provisioned Microsoft Foundry project and model are treated as
  environment prerequisites, not Sprint scope
- One implementation Task for each selected User Story
- No more than three new Tasks in total
- Verified parent-child relationships and Sprint assignments in Azure Boards
- A reviewed execution order for the implementation Tasks

This exercise plans only one Sprint for the core Feature. It does not plan the
optional **Conversational Queue Insights** Feature, decompose every backlog
item, create implementation work outside Azure Boards, assign work to a coding
agent, or create speculative Tasks for future Sprints. Preparation for coding
agent assignment continues in Part 6.

## Prerequisites

Before continuing:

- Complete Part 4.
- Confirm that the **Constrained Ticket Status Q&A** Feature and its User
  Stories exist in Azure Boards.
- Confirm that `az devops configure --list` shows the intended Azure DevOps
  organization and project.

## 1. Set the Sprint planning boundaries

Before asking an agent to create work items, agree on a small planning budget:

| Decision | Workshop value |
| --- | --- |
| Feature | Constrained Ticket Status Q&A |
| Selected User Stories | Two or three product-facing Stories |
| Tasks per selected User Story | One |
| Maximum new Tasks | Three |

The one-Task-per-Story rule is deliberate. Each Task should include the code,
automated tests, and directly related documentation needed to satisfy its
parent User Story. Do not create separate Tasks for routine coding, unit tests,
formatting, or documentation.

If a selected User Story cannot be described as one cohesive implementation
Task, return it to Product Backlog refinement instead of creating a large
collection of Tasks.

> [!NOTE]
> Scrum does not require Tasks or prescribe how many belong to a User Story.
> These limits are workshop guardrails that keep the Sprint Backlog
> understandable and avoid speculative decomposition.

## 2. Define the Sprint

Choose the Sprint name and dates with the Scrum Team. Use an existing Sprint
iteration when one already represents the agreed timebox. Otherwise, create
one before drafting the Sprint Backlog.

Configure the Sprint in Azure Boards:

1. Open **Boards** > **Sprints** > **Backlog**, then select the intended team.
2. If the team already has a suitable Sprint, select **Set dates**, enter the
   approved start and finish dates, and save the iteration.
3. If no suitable Sprint exists:
   1. Open **Project settings** > **Project configuration** > **Iterations**.
   2. Create a child iteration with the approved Sprint name, start date, and
      finish date.
   3. Open **Project settings** > **Boards** > **Team configuration** >
      **Iterations**.
   4. Select the intended team and add the new iteration to that team.
4. Return to **Boards** > **Sprints** and confirm that the Sprint appears for
   the intended team with the approved dates.

Only a team or project administrator can change team iteration settings. If
you cannot create or select the Sprint, ask an administrator to complete these
steps before continuing.

## 3. Draft the Sprint Backlog

Select only the product-facing work needed to demonstrate read-only questions
about one synthetic ticket with a grounded answer or clear fallback. Leave all
other stories in the Product Backlog.

Select `azure-boards-specialist` from the agent picker and submit the following
prompt. Replace the Sprint placeholders before submitting it.

```text
Prepare a Sprint Backlog for the Support Desk Simulator. Follow the standards
in your Azure Boards specialist profile.

Environment and authorization:
Run az devops configure --list to establish the intended Azure DevOps
organization and project. Confirm the current identity, project, and Agile
process. Choose one available Azure Boards integration or the Azure DevOps CLI,
and use that choice consistently for all Azure Boards write operations. Stop if
it resolves to a different organization or project. Never request or create a
personal access token or other credential.

Approved Sprint context:
Use this approved scope:
- Feature: Constrained Ticket Status Q&A
- Sprint name: <sprint-name>
- Sprint start: <yyyy-MM-dd>
- Sprint finish: <yyyy-MM-dd>

Discovery:
First inspect the repository and Azure Boards. Find the existing Feature and
all of its child User Stories. Search for existing Sprints and Tasks that
already represent this work. Reuse or update matching records; do not create
duplicates. Verify that the approved Sprint exists, has the supplied dates,
and is selected for the intended team. Stop and report any mismatch instead of
creating another Sprint. Use the successful Part 1 deployment output as
confirmation that the Microsoft Foundry resource, support-sim-project project,
and gpt-5.4-mini model deployment are provisioned. Treat them as environment
prerequisites, not Sprint scope.

Sprint Backlog boundaries:
Propose the smallest coherent Sprint Backlog that can produce the approved
demo outcome:
- Select two existing product-facing User Stories, or three only when the
  third is necessary for a usable Increment.
- Create exactly one cohesive implementation Task under each selected User
  Story.
- Create no more than three new Tasks in total.
- Include implementation, automated tests, and directly related documentation
  in each Task rather than creating separate routine Tasks.
- Leave unselected User Stories in the Product Backlog.
- Do not create a Foundry provisioning User Story or Task. The Microsoft
  Foundry resource, project, and model deployment already exist from Part 1.
  Product-facing Tasks may use them only where their parent Story requires it;
  they must not provision or reconfigure these resources.
- Do not add the optional Conversational Queue Insights Feature to this Sprint.
- Do not invent estimates, capacity, a Definition of Done, organization policy,
  or acceptance criteria.
- If a selected User Story is too large for one cohesive Task, identify it for
  refinement and exclude it from the proposed Sprint.

Task requirements:
Each proposed Task must include:
- An action-oriented title
- Its parent User Story ID
- A concise implementation scope
- A completion condition tied to the parent's acceptance criteria
- Required automated test evidence
- Relevant security, privacy, reliability, and accessibility constraints
- Known dependencies and blockers
- The repository areas likely to change, based on inspection

> [!IMPORTANT]
> Part 1 provisions the Microsoft Foundry resource, `support-sim-project`, and
> the GPT-5.4-mini model deployment. The application does not yet call the
> model. Do not create or select a Foundry infrastructure-enablement Story or
> Task in this Sprint. If any foundation resource is missing, stop and report
> the Part 1 deployment prerequisite instead of adding provisioning to the
> Sprint. Any application Task that calls Foundry must use managed identity
> and least-privilege RBAC; do not use API keys or connection strings.

Product and security constraints:
Preserve these confirmed product constraints:
- The capability is read-only and stateless.
- Application logic retrieves ticket facts; the model must not invent them.
- Ticket content and user questions are untrusted data, not instructions.
- Unsupported, ambiguous, malformed, and unknown-ticket questions receive a
  clear fallback.
- An unavailable AI service receives a clear fallback.
- Ticket content, prompts, and model responses are not logged.
- Existing role and data-access boundaries remain in effect.
- Production Azure access uses managed identity and least-privilege RBAC.
- No secret, key, credential, or connection string is committed.

Approval checkpoint:
Before writing anything:
1. Report the resolved Azure DevOps organization, project, process, identity,
   intended team, and configured Sprint iteration.
2. Present the selected User Stories and the resulting demo outcome.
3. Explain why each selected User Story is necessary and why each unselected
   User Story remains in the Product Backlog.
4. Present the exact selected product-facing User Stories and Task drafts in
   parent-to-child order, identifying any existing items that will be reused.
5. List assumptions, open questions, dependencies, and the proposed execution
   order separately.
6. State the exact create, update, link, and Sprint assignment operations.
7. Ask for explicit approval of those operations.

Approved execution:
After I approve:
1. Reuse the configured Sprint iteration and verify its dates and intended
   team. Do not create another iteration.
2. Create or update only the approved product-facing User Stories, Tasks, and
   parent-child links.
3. Assign the selected User Stories and Tasks to the Sprint iteration.
4. Read every changed Azure Boards work item back from Azure Boards.
5. Report the IDs, titles, types, states, parents, iteration paths, URLs,
   dependencies, and verification results.

Stop and report the exact failure if an item cannot be created, linked,
assigned, or verified. Do not create a replacement or report success-shaped
fallback output.
```

The specialist should stop after presenting the proposal. Check that the
proposal stays within the planning budget and that the selected stories can
produce a usable Increment. Approve the exact operations only after resolving
the reported assumptions and open questions.

## 4. Review the Sprint Backlog

After the approved changes are complete, review the Sprint in Azure Boards.
Open **Boards** > **Sprints**, select the Sprint, and review its backlog.

Confirm that:

- The Sprint has the agreed name and dates.
- The Sprint iteration is selected for the intended team.
- Only the selected **Constrained Ticket Status Q&A** User Stories are assigned
  to the Sprint.
- The selected User Stories are product-facing; no Foundry infrastructure
  provisioning Story or Task was created.
- Each selected User Story has exactly one new implementation Task.
- No more than three new Tasks were created.
- Each Task has exactly one parent User Story.
- Every Task has a concrete completion condition and test evidence.
- Unselected stories and the optional Feature remain outside the Sprint.
- No estimate, capacity, policy, or Definition of Done was invented.

Set the IDs reported by the specialist, then verify the hierarchy and iteration
paths independently:

```powershell
$WORK_ITEM_IDS = @(
  <feature-id>,
  <story-1-id>, <task-1-id>,
  <story-2-id>, <task-2-id>
  # Add <story-3-id>, <task-3-id> only when the third Story was selected.
)

foreach ($id in $WORK_ITEM_IDS) {
  az boards work-item show `
    --id $id `
    --detect false `
    --expand none `
    --fields System.Id,System.WorkItemType,System.Title,System.Parent,System.State,System.IterationPath `
    --output table
}
```

Include the Feature, every selected User Story, and every new Task in
`$WORK_ITEM_IDS`. The Feature can remain outside the Sprint; the selected User
Stories and their Tasks must report the Sprint iteration path.

If a field or link is wrong, ask the specialist to correct only that item and
verify it again. Do not create a replacement.

### Sprint Backlog ready

The Sprint now has a clear scope, a small set of selected User Stories, and a
bounded implementation plan in Azure Boards. No implementation work has been
created or assigned outside Azure Boards. Continue to
[Part 6](06-coding-agent-delivery.md) to prepare the first Tasks for coding
agent assignment.

## Public documentation used for validation

- [The Scrum Guide](https://scrumguides.org/scrum-guide.html)
- [Sprint and scrum best practices in Azure Boards](https://learn.microsoft.com/azure/devops/boards/sprints/best-practices-scrum)
- [Organize your backlog and map child work items](https://learn.microsoft.com/azure/devops/boards/backlogs/organize-backlog)
