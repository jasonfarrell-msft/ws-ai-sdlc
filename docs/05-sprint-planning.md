# Part 5: Backlog Task Preparation

## Goal

In this part, you turn the **Constrained Ticket Status Q&A** Feature from Part 4
into a small, ready-to-execute set of Azure Boards backlog Tasks.

You use the Azure Boards specialist to select the smallest workshop set of
product-facing User Stories that can produce a usable Increment. For this
exercise, that means two User Stories, or three only when the third is necessary
for a usable demo. For each selected Story, you identify the distinct,
independently implementable units of work that can be handed to a GitHub Copilot
coding agent as separate Tasks. You then verify the work-item hierarchy and
leave it in the Product Backlog, ready for the team to schedule in a Sprint
later.

By the end of this part, you will have:

- Two or three selected User Stories from the core Feature
- The pre-provisioned Microsoft Foundry project and model are treated as
  environment prerequisites, not Sprint scope
- One or more implementation Tasks per selected User Story, as needed to
  describe agent-sized units of work
- Verified parent-child relationships in Azure Boards
- A reviewed execution order for the implementation Tasks

This exercise does not configure Azure Boards iterations or team settings,
create a Sprint, assign iteration paths, plan the optional
**Conversational Queue Insights** Feature, decompose every backlog item, assign
work to a coding agent, or create speculative Tasks for future Sprints.
Preparation for coding-agent assignment continues in Part 6.

## Prerequisites

Before continuing:

- Complete Part 4.
- Confirm that the **Constrained Ticket Status Q&A** Feature and its User
  Stories exist in Azure Boards.
- Confirm that `az devops configure --list` shows the intended Azure DevOps
  organization and project.

## 1. Set the backlog planning boundaries

Before asking an agent to create work items, agree on a small planning scope:

| Decision | Workshop value |
| --- | --- |
| Feature | Constrained Ticket Status Q&A |
| Selected User Stories | Two or three product-facing Stories |
| Tasks per selected User Story | As needed for independently implementable work units |
| Maximum new Tasks | No fixed limit; create only the Tasks needed to hand off the work clearly |

Each Task must describe one bounded unit of work that can be assigned to a
coding agent without combining unrelated implementation outcomes. Multiple
Tasks may belong to one Story when its work naturally divides into separate
agent-sized units. A Task may include the implementation, tests, and directly
related documentation needed for its own completion; separate Tasks are also
appropriate when those are independently implementable work units. Keep
dependencies and execution order explicit, and avoid overlapping scopes or
Tasks for routine substeps such as formatting.

Do not split work into arbitrary or overly small Tasks just to increase the
count. If a Story cannot be divided into clear, independently implementable
units without overlap or excessive coordination, keep its work in one cohesive
Task or return the Story to Product Backlog refinement if its scope cannot be
split into clear, independently implementable Tasks.

> [!NOTE]
> Scrum does not require Tasks or prescribe how many belong to a User Story.
> The limit on selected User Stories is a workshop guardrail. Task counts
> should reflect the distinct, agent-ready work without speculative
> decomposition.

## 2. Draft the backlog Tasks

Select only the product-facing work needed to demonstrate read-only questions
about one synthetic ticket with a grounded answer or clear fallback. Leave all
other stories in the Product Backlog.

Select `azure-boards-specialist` from the agent picker and submit the following
prompt.

```text
Prepare Azure Boards backlog Tasks for the Support Desk Simulator. Follow the
standards in your Azure Boards specialist profile.

Environment and authorization:
Run az devops configure --list to establish the intended Azure DevOps
organization and project. Confirm the current identity, project, and Agile
process. Choose one available Azure Boards integration or the Azure DevOps CLI,
and use that choice consistently for all Azure Boards write operations. Stop if
it resolves to a different organization or project. Never request or create a
personal access token or other credential.

Approved backlog scope:
- Feature: Constrained Ticket Status Q&A
- Create only the selected Stories and their implementation Tasks described
  below. Do not create or configure a Sprint.

Discovery:
First inspect the repository and Azure Boards. Find the existing Feature and
all of its child User Stories, and search for existing Tasks that already
represent this work. Reuse or update matching records; do not create
duplicates. Do not inspect or change project/team iterations or Sprint dates.
Do not assign iteration paths. Leave all work items in the Product Backlog
with their existing iteration values unchanged. Use the successful Part 1
deployment output as confirmation that the Microsoft Foundry resource,
support-sim-project project, and gpt-5.4-mini model deployment are provisioned.
Treat them as environment prerequisites, not backlog scope.

Backlog boundaries:
Propose the smallest coherent set of backlog work that can produce the
approved demo outcome when scheduled for a future Sprint:
- Select two existing product-facing User Stories, or three only when the
  third is necessary for a usable Increment.
- Create one or more implementation Tasks under each selected User Story,
  dividing the work into separate units when they can be implemented
  independently by a coding agent.
- Create only the Tasks needed to define the selected Stories as clear,
  agent-ready units; there is no fixed maximum number of Tasks.
- Give each Task a distinct, bounded scope, a verifiable completion condition,
  relevant automated test evidence, and explicit dependencies on other Tasks
  where applicable.
- Include directly related tests and documentation in the relevant Task when
  they are part of that unit; do not add arbitrary routine Tasks.
- Leave unselected User Stories in the Product Backlog.
- Do not create a Foundry provisioning User Story or Task. The Microsoft
  Foundry resource, project, and model deployment already exist from Part 1.
  Product-facing Tasks may use them only where their parent Story requires it;
  they must not provision or reconfigure these resources.
- Do not add the optional Conversational Queue Insights Feature to this
  backlog scope.
- Do not invent estimates, capacity, a Definition of Done, organization policy,
  or acceptance criteria.
- If a selected User Story is too large for a set of independently
  implementable Tasks, identify it for refinement and do not create Tasks for
  that Story until its scope is clear.

Task requirements:
Each proposed Task must include:
- An action-oriented title
- Its parent User Story ID
- A concise, bounded implementation scope suitable for a coding-agent handoff
- A completion condition tied to the parent's acceptance criteria
- Required automated test evidence for that unit of work
- Relevant security, privacy, reliability, and accessibility constraints
- Known dependencies and blockers, including prerequisite Tasks
- The repository areas likely to change, based on inspection

> [!IMPORTANT]
> Part 1 provisions the Microsoft Foundry resource, `support-sim-project`, and
> the GPT-5.4-mini model deployment. The application does not yet call the
> model. Do not create or select a Foundry infrastructure-enablement Story or
> Task in this backlog scope. If any foundation resource is missing, stop and
> report the Part 1 deployment prerequisite instead of adding provisioning to
> the backlog. Any application Task that calls Foundry must use managed
> identity and least-privilege RBAC; do not use API keys or connection strings.

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
   and the selected Feature.
2. Present the selected User Stories and the resulting demo outcome.
3. Explain why each selected User Story is necessary and why each unselected
   User Story remains in the Product Backlog.
4. Present the exact selected product-facing User Stories and Task drafts in
   parent-to-child order, identifying any existing items that will be reused.
   Explain why each Story has one Task or is divided into multiple distinct
   coding-agent-sized Tasks.
5. List assumptions, open questions, dependencies, and the proposed execution
   order separately.
6. State the exact create, update, and parent-link operations. Confirm that
   no iteration or Sprint configuration or assignment will be changed.
7. Ask for explicit approval of those operations.

Approved execution:
After I approve:
1. Create or update only the approved product-facing User Stories, Tasks, and
   parent-child links.
2. Leave iteration paths unchanged. Do not create or configure iterations,
   Sprint dates, or team iteration settings.
3. Read every changed Azure Boards work item back from Azure Boards.
4. Report the IDs, titles, types, states, parents, current iteration paths, URLs,
   dependencies, and verification results.

Stop and report the exact failure if an item cannot be created, linked, or
verified. Do not create a replacement or report success-shaped fallback output.
```

The specialist should stop after presenting the proposal. Check that the
proposal stays within the planning scope and that the selected stories can
produce a usable Increment when scheduled for a future Sprint. Approve the
exact operations only after resolving the reported assumptions and open
questions.

## 3. Review the backlog Tasks

After the approved changes are complete, review the Feature backlog in Azure
Boards. Open **Boards** > **Backlogs** and select the appropriate backlog level.

Confirm that:

- No iteration, Sprint dates, or team iteration settings were created or
  changed.
- Only the selected **Constrained Ticket Status Q&A** User Stories have
  implementation Tasks created or updated.
- The selected User Stories are product-facing; no Foundry infrastructure
  provisioning Story or Task was created.
- Each selected User Story has the necessary implementation Tasks, with
  distinct scopes that can be handed to a coding agent individually.
- No Task scopes overlap or split work into arbitrary routine substeps.
- Each Task has exactly one parent User Story.
- Every Task has a concrete completion condition and test evidence.
- Unselected Stories and the optional Feature remain outside this backlog
  scope.
- No estimate, capacity, policy, or Definition of Done was invented.

Set the IDs reported by the specialist, then verify the hierarchy independently:

```powershell
$WORK_ITEM_IDS = @(
  <feature-id>,
  <story-1-id>, <task-1-id>, <task-2-id>,
  <story-2-id>, <task-3-id>
  # Include every selected Story and each of its Tasks. A Story may have one
  # or more Tasks; include Story 3 and its Tasks only when selected.
)

foreach ($id in $WORK_ITEM_IDS) {
  az boards work-item show `
    --id $id `
    --detect false `
    --expand none `
    --fields System.Id,System.WorkItemType,System.Title,System.Parent,System.State `
    --output table
}
```

Include the Feature, every selected User Story, and every new Task in
`$WORK_ITEM_IDS`. Verify each Task's parent, scope, and dependencies so the
approved execution order is usable for individual coding-agent handoffs. Keep
all work in the Product Backlog; the team can configure its Sprint and assign
iteration paths later through its normal planning process.

If a field or link is wrong, ask the specialist to correct only that item and
verify it again. Do not create a replacement.

### Backlog ready for Sprint planning

The Project now has a clear Feature backlog with selected User Stories and
distinct implementation Tasks that can be handed to coding agents individually.
No iterations or Sprints were configured, and no iteration paths were changed.
The team can schedule these backlog items during its normal Sprint planning.
Continue to [Part 6](06-coding-agent-delivery.md) to prepare Tasks for coding
agent assignment.

## Public documentation used for validation

- [The Scrum Guide](https://scrumguides.org/scrum-guide.html)
- [Organize your backlog and map child work items](https://learn.microsoft.com/azure/devops/boards/backlogs/organize-backlog)
