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
  `support-sim-project`, `gpt-5.4-mini`, and the deployed nonsecret runtime
  endpoint setting. The App Service identity has least-privilege model access.

> [!NOTE]
> Part 1 provisions the Foundry resource, model, runtime role assignment, and
> nonsecret endpoint setting. The deployment stack's `foundryEndpoint` output
> is the source of truth; do not hardcode an environment-specific account name.
> The GitHub Actions identity remains limited to deploying the Web App. Do not
> expand its Azure access or add Foundry provisioning to the workflow.

## 1. Choose Tasks and check their order

Review the approved Tasks and their parent Stories. Decide which Tasks to
send to the coding agent and which to keep with people. Keep each Task as a
separate handoff, and check for an existing linked PR or active agent session
before starting work to avoid duplicate implementations.

This walkthrough assumes Part 5 created Tasks in the order they should be
completed. Work through your Tasks in ascending Task ID order, reviewing and
merging each PR before starting the next. Check the recorded prerequisites
first; if they conflict with numerical order, follow the prerequisites.

In this example, Part 5 produced **three Tasks**; your backlog may have a
different number:

| Order | Implementation unit | When to start |
| --- | --- | --- |
| First | Backend contracts, current-ticket retrieval, and grounded answers | Start here. |
| Second | Foundry question interpretation and model adapter | After the first Task's PR is reviewed and merged. |
| Third | Accessible question input, answer/source, and fallback UI | After the second Task's PR is reviewed and merged. |

Use the Task IDs returned by Part 5 and include all Tasks selected for this
handoff. Both the adapter and UI in this example depend on the backend contract; the
sequential walkthrough also keeps review and integration simple. As with a
human team, prerequisite relationships determine what can start next;
numerical order is only a convenient walkthrough assumption.

## 2. Do the work: send each Task to Copilot

1. Start with the **lowest Task ID** in the verified order from Section 1.
   Open that **Task** in Azure Boards, not its parent Story or Feature.
   Check that its saved description includes the approved scope,
   completion evidence, safeguards, and dependencies.
2. Set **Assigned To** to the person responsible for the Task and set its
   state to **Active** (in progress). Save the Task.
3. Select the **Copilot** action in the Task details and choose **Create a
   pull request with Copilot**.
4. Under **GitHub repository**, select the connected repository where the
   implementation belongs. Verify the owner and repository name, especially
   if both a fork and its parent repository are connected.
5. Check the base branch. For this walkthrough, use **`main`**, the connected
   repository's default branch. Automatic Task closure requires merging into
   the repository's default branch.
6. In the model selector, choose **Auto** or a specific model available to your
   account for this handoff.
7. In **additional instructions**, paste the following, replacing
   `<TASK_ID>` with this Task's actual ID:

   ```text
   Include the following standalone line in the pull request description:
   Closed AB#<TASK_ID>
   Reference only this Task for automatic closure; do not close its parent Story.
   ```

   Do not expand the approved scope. A plain `AB#<TASK_ID>` reference links
   the work item but does not request a state change.
8. Select **Create**. Monitor the coding agent in GitHub's **Agents** tab.
   The linked PR remains in **draft** mode when the agent finishes; it still
   needs human review before merging.
9. Open the PR and verify that its description contains the standalone
   `Closed AB#<TASK_ID>` line with the correct ID. Add it if missing.

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

1. Review the current Task's PR against its scope and parent Story's
   criteria. Inspect the code and test evidence; a draft PR is evidence of
   work underway, not completion.
2. Request corrections in the PR when needed. Keep changes focused on that
   Task and verify that existing behavior and safe fallbacks are preserved.
3. Confirm the Task's completion requirements are met and the closure line
   names only that Task. Mark the draft PR **Ready for review**, complete the
   repository's required checks and human review, then merge into **`main`**.
4. Verify that Azure Boards changes the Task to **Closed**. In GitHub's
   **Actions** tab, open the merged commit's **Validate and deploy** run and
   confirm the **Deploy application** job succeeds, including any required
   environment approval. PR checks alone do not prove deployment. If closure
   or deployment fails, investigate before proceeding.
5. Open the next Task in the verified order and repeat Section 2, including
   assigning a person and setting the Task to **Active**. Confirm its base
   branch contains the merged prerequisite changes. Repeat the handoff,
   review, merge, closure, and deployment checks until **all selected Tasks
   are complete and all corresponding Actions deployments have succeeded**.

Merging the prerequisite makes its code available to dependent agents;
deployment is a separate concern. Each Task must retain its approved safe
deployment behavior. The UI can show unavailable-AI feedback before the model
adapter or runtime access is ready. A code merge or passing tests do not
establish live Foundry access.

## 4. Verify the combined result

- Confirm each PR is linked to the intended Task and stays within its scope.
- Confirm every selected Task is Closed and each corresponding post-merge
  Actions deployment succeeded. Automatic Task closure occurs on merge; it
  does not wait for deployment or prove that deployment succeeded.
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
