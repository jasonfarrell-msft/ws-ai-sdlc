# Part 6: Coding Agent Delivery

## Goal

Send approved Tasks from Azure Boards to GitHub Copilot coding agent, then
review the resulting pull requests in the connected GitHub repository.
Use the scope, acceptance criteria, tests, and safeguards already recorded
in each Task; there is no separate instruction-update exercise.

> [!NOTE]
> **This exercise does not assign Tasks to a Sprint.** Leave their iteration
> paths unchanged. In normal delivery planning, the team may place work in a
> Sprint and decide task by task whether an AI coding agent, a person, or a
> person working with an agent is the best fit. Dependency order matters for
> all of them: dependent work needs its prerequisite changes, regardless of
> who implements it.

## Prerequisites

- Complete [Part 5](05-sprint-planning.md). Keep the selected Story and Task
  IDs, and confirm every Task has its intended Story as its parent.
- Have a paid GitHub Copilot plan and access to the connected GitHub
  repository, with Copilot coding agent enabled.
- Complete the Azure Boards GitHub integration from
  [Part 3](03-azure-devops-setup.md), including any required application
  permission approval.
- Reuse the saved Part 1 confirmation for the existing Foundry resource,
  `support-sim-project`, and `gpt-5.4-mini`. Runtime endpoint and
  managed-identity access may still be separate dependencies.

> [!NOTE]
> The GitHub Actions identity remains limited to deploying the Web App. Do not
> expand its Azure access or add Foundry provisioning to the workflow.

## 1. Choose Tasks and check their order

Review the approved Tasks and their parent Stories. Decide which Tasks to
send to the coding agent and which to keep with people. Keep each Task as a
separate handoff, and check for an existing linked PR or active agent session
before starting work to avoid duplicate implementations.

Use the prerequisite Task IDs in the descriptions to determine the order,
not the order of items in the backlog. For the status/assignee decomposition,
the expected sequence is:

| Order | Implementation unit | When to start |
| --- | --- | --- |
| First | Backend contracts, current-ticket retrieval, and grounded answers | Start with this prerequisite Task. |
| Next | Foundry question interpretation and model adapter | After the backend contract is merged into the selected base branch. |
| Next | Accessible question input, answer/source, and fallback UI | After the backend contract is merged into the selected base branch. |

The adapter and UI can proceed in parallel once their shared prerequisite is
available; neither needs to wait for the other. Coordinate overlapping file
changes and resolve conflicts during review. Follow the actual approved Task
dependencies if your decomposition differs.

## 2. Send the prerequisite Task to Copilot

1. Open the prerequisite **Task** in Azure Boards, not its parent Story or
   Feature. Check that its saved description includes the approved scope,
   completion evidence, safeguards, and dependencies.
2. Select the **Copilot** action in the Task details and choose **Create a
   pull request with Copilot**.
3. Under **GitHub repository**, select the connected repository where the
   implementation belongs. Verify the owner and repository name, especially
   if both a fork and its parent repository are connected.
4. Check the base branch. It must be the intended target for this Task's
   changes.
5. Additional instructions are optional. Do not repeat the Task description
   or use this field to expand the approved scope.
6. Select **Create**. Copilot starts processing the work item and creates a
   linked draft pull request in GitHub.
7. Open the linked PR to follow the agent's progress and inspect its changes.

This action delegates the Task to Copilot; it does not require selecting a
GitHub bot in Azure Boards' **Assigned To** field or changing its Sprint.
If the action is missing, check the integration prerequisites rather than
creating a duplicate Task.

> [!IMPORTANT]
> The handoff copies work-item text fields and the last 50 comments into
> context stored in the PR, visible to people with repository access. Check
> that this content is appropriate to share. Never include secrets or real
> customer ticket data.

## 3. Review and merge before starting dependent work

1. Review the prerequisite Task's PR against its scope and parent Story's
   criteria. Inspect the code and test evidence; a draft PR is evidence of
   work underway, not completion.
2. Request corrections in the PR when needed. Keep changes focused on that
   Task and verify that existing behavior and safe fallbacks are preserved.
3. Complete the repository's required checks and human review, then merge
   the approved PR into the intended base branch.
4. Open each dependent Task in Azure Boards and repeat Section 2. Confirm
   that its selected base branch now contains the prerequisite changes.
   For this demo, the model adapter and UI can now be handed off separately.
5. Review and merge each resulting PR using the same process.

Merging the prerequisite makes its code available to dependent agents;
deployment is a separate concern. Each Task must retain its approved safe
deployment behavior. The UI can show unavailable-AI feedback before the model
adapter or runtime access is ready. A code merge or passing tests do not
establish live Foundry access.

## 4. Verify the combined result

- Confirm each PR is linked to the intended Task and stays within its scope.
- Verify the combined status/assignee interaction, exact source ticket ID,
  and clear fallbacks against the selected Stories' existing criteria.
- Keep code/test evidence separate from live runtime evidence. Endpoint
  configuration and least-privilege managed-identity access must be confirmed
  by the responsible owner before live AI use; the coding agent must not
  provision Foundry or change Azure RBAC to remove those blockers.
- Leave iteration paths unchanged. Use the team's existing completion
  process; a PR, merge, or deployment alone does not make a Story Done.

## Public documentation used for validation

- [Deploy a Foundry resource by using Bicep](https://learn.microsoft.com/azure/foundry/how-to/create-resource-template)
- [Integrate Copilot cloud agent with Azure Boards](https://docs.github.com/copilot/how-tos/copilot-integrations/integrate-cloud-agent-with-azure-boards)
- [Configure OpenID Connect in Azure](https://docs.github.com/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-azure)
- [GitHub Actions workflow syntax](https://docs.github.com/actions/reference/workflows-and-actions/workflow-syntax)
