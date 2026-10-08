# Part 5: Sprint Planning and Coding Agent Handoff

## Goal

In this part, you turn the **Constrained Ticket Status Q&A** Feature from Part 4
into a small, ready-to-execute Sprint Backlog.

You use the Azure Boards specialist to select the smallest workshop set of User
Stories that can produce a usable Increment. For this exercise, that means two
User Stories, or three only when the third is necessary for the Sprint Goal.
You then create a limited number of Tasks, place the selected work in one
Sprint, and create matching GitHub issues for the implementation work that the
GitHub Copilot coding agent can perform. GitHub shows this agent as **Copilot**
in the issue assignee list.

By the end of this part, you will have:

- One Sprint Goal
- Two or three selected User Stories from the core Feature
- One implementation Task for each selected User Story
- No more than three new Tasks in total
- One GitHub issue for each implementation Task
- The first unblocked GitHub issue assigned to Copilot
- Verified traceability between the Feature, selected User Stories, Tasks, and
  GitHub issues
- A documented review and handoff sequence for Copilot pull requests

This exercise plans only one Sprint for the core Feature. It does not plan the
optional **Conversational Queue Insights** Feature, decompose every backlog
item, or create speculative Tasks for future Sprints.

## Prerequisites

Before continuing:

- Complete Part 4.
- Confirm that the **Constrained Ticket Status Q&A** Feature and its User
  Stories exist in Azure Boards.
- Confirm that `az devops configure --list` shows the intended Azure DevOps
  organization and project.
- Confirm that the Azure Boards GitHub App remains connected only to your fork.
- Confirm that GitHub CLI is authenticated to your fork:

```powershell
gh auth status
gh repo set-default origin
gh repo set-default --view
gh repo view --json nameWithOwner,isFork
```

- Confirm that your GitHub account and repository can use the GitHub Copilot
  coding agent. If the coding agent is unavailable, you can still create and review
  the Sprint Backlog, but stop before assigning the GitHub issues.

> [!IMPORTANT]
> An Azure Boards Task and a GitHub issue are different records. Azure Boards
> holds the Sprint plan and hierarchy. GitHub holds the implementation request
> assigned to the coding agent. Do not try to assign an Azure Boards Task to a
> GitHub bot identity. This workshop uses GitHub issues for the handoff so the
> request and resulting pull request remain reviewable in the repository.

## 1. Set the Sprint planning boundaries

Before asking an agent to create work items, agree on a small planning budget:

| Decision | Workshop value |
| --- | --- |
| Feature | Constrained Ticket Status Q&A |
| Selected User Stories | Two or three |
| Tasks per selected User Story | One |
| Maximum new Tasks | Three |
| GitHub issues per Task | One |
| Concurrent coding-agent assignments | One |

The one-Task-per-Story rule is deliberate. Each Task should include the code,
automated tests, and directly related documentation needed to satisfy its
parent User Story. Do not create separate Tasks for routine coding, unit tests,
formatting, documentation, pull request creation, or code review.

Create another Task only when the work:

- Has a different owner from the implementation work
- Can be completed and verified independently
- Is required for the User Story to meet its acceptance criteria

If a selected User Story cannot be described as one cohesive implementation
Task, return it to Product Backlog refinement instead of creating a large
collection of Tasks.

> [!NOTE]
> Scrum does not require Tasks or prescribe how many belong to a User Story.
> These limits are workshop guardrails that keep the Sprint Backlog
> understandable and reduce overlapping coding-agent pull requests.

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

The documented Azure Boards Sprint-planning flow does not provide a dedicated
Sprint Goal field. Choose a visible team-owned location for the goal, such as
the project wiki or a pinned dashboard item, and record that location as well.
You will replace the matching placeholders in the planning prompt.

Write a Sprint Goal that describes the outcome rather than the work:

```text
Enable support users to ask a documented set of read-only questions about one
synthetic ticket and receive a grounded answer or a clear fallback.
```

The Sprint Goal does not require every User Story under the Feature. Select only
the stories needed to demonstrate that outcome. Leave all other stories in the
Product Backlog.

## 3. Draft the Sprint Backlog and handoff

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
- Sprint Goal location: <project-wiki-page-or-dashboard-location>
- Sprint Goal: Enable support users to ask a documented set of read-only
  questions about one synthetic ticket and receive a grounded answer or a
  clear fallback.

Discovery:
First inspect the repository and Azure Boards. Find the existing Feature and
all of its child User Stories. Search for existing Sprints, Tasks, and GitHub
issues that already represent this work. Reuse or update matching records; do
not create duplicates. Verify that the approved Sprint exists, has the supplied
dates, and is selected for the intended team. Stop and report any mismatch
instead of creating another Sprint.

Sprint Backlog boundaries:
Propose the smallest coherent Sprint Backlog that can meet the Sprint Goal:
- Select two User Stories, or three only when the third is necessary for a
  usable Increment.
- Create exactly one cohesive implementation Task under each selected User
  Story.
- Create no more than three new Tasks in total.
- Include implementation, automated tests, and directly related documentation
  in each Task rather than creating separate routine Tasks.
- Leave unselected User Stories in the Product Backlog.
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

GitHub handoff:
For each proposed Azure Boards Task, also propose one matching GitHub issue for
the repository reported by gh repo view. Each issue must:
- Have a concise implementation-oriented title.
- Include the parent User Story's acceptance criteria and the Task's completion
  condition.
- Include AB#<task-id> and AB#<story-id> traceability placeholders in the issue
  description.
- State the expected automated tests and documentation updates.
- Tell the coding agent to inspect and follow repository instructions.
- State that committed NuGet lock files must be regenerated with
  dotnet restore --force-evaluate when package references change because CI
  restores with --locked-mode.
- Require a focused pull request and prohibit unrelated changes.
- Require the pull request description to reference both Azure Boards IDs.
- Avoid prescribing an implementation that repository inspection does not
  support.

Do not assign an Azure Boards Task to a GitHub bot identity. The GitHub issue,
not the Azure Boards Task, is the record assigned to the coding agent.
Plan to assign only the first unblocked GitHub issue. Leave dependent issues
unassigned until the preceding pull request is reviewed and merged.

Approval checkpoint:
Before writing anything:
1. Report the resolved Azure DevOps organization, project, process, identity,
   GitHub repository, intended team, and configured Sprint iteration.
2. Present the proposed Sprint Goal and selected User Stories.
3. Explain why each selected User Story is necessary and why each unselected
   User Story remains in the Product Backlog.
4. Present the exact Task and GitHub issue drafts in parent-to-child order.
5. List assumptions, open questions, dependencies, and the proposed execution
   order separately.
6. State the exact create, update, link, Sprint assignment, and coding-agent
   assignment operations.
7. Ask for explicit approval of those operations.

Approved execution:
After I approve:
1. Reuse the configured Sprint iteration and verify its dates and intended
   team. Do not create another iteration.
2. Create or update only the approved Tasks and parent-child links.
3. Assign the selected User Stories and Tasks to the Sprint iteration.
4. Create or update only the approved GitHub issues, substituting the actual
   Azure Boards IDs into each issue description before creation.
5. Use a supported GitHub Copilot coding-agent assignment operation to assign only the
   first unblocked issue. Do not treat a normal user assignment as equivalent.
6. Read every changed Azure Boards work item and GitHub issue back from its
   source.
7. Report the IDs, titles, types, states, parents, iteration paths, URLs,
   assignees, dependencies, and verification results.

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
Confirm that the approved Sprint Goal is recorded in the team-owned location
selected in Section 2. Keep that location visible to the team during the
Sprint.

Confirm that:

- The Sprint has the agreed name and dates.
- The agreed Sprint Goal is present in the selected team-owned location.
- The Sprint iteration is selected for the intended team.
- Only the selected **Constrained Ticket Status Q&A** User Stories are assigned
  to the Sprint.
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

## 5. Review the Coding Agent handoff

List the created GitHub issues:

```powershell
gh issue list `
  --state open `
  --limit 20 `
  --json number,title,assignees,url
```

Open each reported issue and confirm that it:

- Represents one Azure Boards Task
- References both its Task and parent User Story with `AB#<id>`
- Contains the acceptance criteria, completion condition, constraints, and
  expected test evidence
- States that package-reference changes must regenerate the committed NuGet
  lock files because CI uses locked restore
- Is narrow enough for one focused pull request
- Does not include secrets or real customer data
- Does not duplicate another issue

Only the first unblocked issue should be assigned to the GitHub Copilot coding
agent.
Keep later issues unassigned until their dependencies are satisfied. This
reduces conflicting pull requests and gives the team a review checkpoint
between changes.

To assign the approved issue in GitHub, open the issue, select **Assignees**,
and select **Copilot**. Then verify the assignee and URL:

```powershell
gh issue view <issue-number> `
  --json number,title,assignees,url
```

Confirm that GitHub starts a coding-agent session or opens its draft pull
request. Check the issue timeline for the Copilot assignment and the linked
draft pull request. Assigning a human teammate is not equivalent to assigning
Copilot.

When the coding agent opens a pull request:

1. Confirm that the pull request references the GitHub issue, Azure Boards
   Task, and parent User Story.
2. Review the proposed changes before allowing workflows to run. If GitHub
   displays **Approve and run workflows**, select it only after confirming that
   the changes are safe. Repository administrators can configure whether this
   approval is required for Copilot.
3. Review the code, tests, documentation, security boundaries, and completed
   workflow results.
4. Confirm that changes to `.github/workflows/`, `infra/`, `global.json`, or
   `Directory.Build.props` are required by the approved Task; reject unrelated
   changes to those files.
5. Request corrections in the same pull request when needed.
6. Merge only after the Task's completion condition and the User Story's
   acceptance criteria are satisfied.
7. Update the Task and User Story states in Azure Boards, then verify their
   links and states.
8. Assign the next unblocked GitHub issue to Copilot.

> [!WARNING]
> Merging to `main` triggers the deployment workflow configured in Part 2.
> Treat the merge as a deployment decision, not only a source-control action.
> Review Azure-impacting changes and expected cost before merging.

Do not assign every issue at once merely because the coding agent is available.
The Sprint Backlog is a plan owned by the Developers, and it should be adapted
as implementation and review evidence becomes available.

### Sprint Backlog ready

The Sprint now has a clear goal, a small set of selected User Stories, and a
bounded implementation plan. Each coding-agent issue maps to one Azure Boards
Task, and only the next unblocked issue is assigned. The team can now execute,
review, and adapt the Sprint without creating a large speculative task list.

## Public documentation used for validation

- [The Scrum Guide](https://scrumguides.org/scrum-guide.html)
- [Sprint and scrum best practices in Azure Boards](https://learn.microsoft.com/azure/devops/boards/sprints/best-practices-scrum)
- [Organize your backlog and map child work items](https://learn.microsoft.com/azure/devops/boards/backlogs/organize-backlog)
- [Link GitHub objects to Azure Boards work items](https://learn.microsoft.com/azure/devops/boards/github/link-to-from-github)
- [Start GitHub Copilot cloud agent sessions](https://docs.github.com/copilot/how-tos/use-copilot-agents/cloud-agent/start-copilot-sessions)
- [Configure GitHub Copilot cloud agent settings](https://docs.github.com/copilot/how-tos/use-copilot-agents/cloud-agent/configuring-agent-settings)
- [`gh repo set-default`](https://cli.github.com/manual/gh_repo_set-default)
- [`dotnet restore`](https://learn.microsoft.com/dotnet/core/tools/dotnet-restore)
