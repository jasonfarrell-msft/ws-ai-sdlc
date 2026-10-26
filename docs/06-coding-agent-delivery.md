# Part 6: Coding Agent Delivery

## Goal

Deliver the approved Azure Boards Tasks from Part 5 through GitHub Copilot,
then review, merge, and verify deployment and end-user behavior.

Part 5 is the source of truth for scope. Do not rewrite Task logic here.

## Before you start

- Complete [Part 5](05-sprint-planning.md) and keep the approved Story/Task IDs.
- Have a paid GitHub Copilot plan with coding agent enabled.
- Confirm Azure Boards integration from
  [Part 3](03-azure-devops-setup.md).
- Use the existing repo and deployment flow from Parts 1-2.

> [!NOTE]
> Do not change Sprint/iteration fields in this exercise.
> Do not expand scope into infrastructure, RBAC, or unrelated work.

## 1. Build the execution queue

1. Start from the selected Tasks created/approved in Part 5.
2. Process **one Task per handoff**.
3. Follow real prerequisites first. If Task IDs and dependencies conflict,
   dependencies win.
4. Before handoff, check the Task for an existing active implementation
   (linked PR or running agent session). Do not create duplicates.

## 2. Send one Task to Copilot

For the current unblocked Task:

1. Open the **Task** (not the parent Story/Feature).
2. Set **Assigned To** to a human owner and set State = **Active**.
3. Select **Copilot**, then **Create a pull request with Copilot**.
4. In **GitHub repository**, choose the correct connected repo.
5. Use base branch **`main`** (the default branch for this workshop repo).
6. In **additional instructions**, include this text and replace `<TASK_ID>`
   with the current Task ID:

   ```text
   Include this standalone line in the pull request description:
   Closed AB#<TASK_ID>
   Reference only this Task. Do not close the parent Story.
   ```

7. Create the handoff and monitor progress in GitHub **Agents**.
8. When the PR appears, verify it contains a standalone `Closed AB#<TASK_ID>` line.

> [!IMPORTANT]
> Handoff context includes work-item text fields and the last 50 comments, copied
> into PR context visible to repository readers. Use only synthetic/nonsecret data.

## 3. Review, merge, and verify deployment (before next dependent Task)

1. Review the PR against:
   - The Task scope from Part 5.
   - The parent Story acceptance criteria.
2. Keep the PR focused on that single Task.
3. A Copilot PR is draft by default. Complete required checks and human review,
   mark **Ready for review**, then merge to **`main`**.
4. Confirm both:
   - Task auto-closed in Azure Boards.
   - GitHub Actions post-merge run **Validate and deploy** succeeded, including
     **Deploy application**.

Task closure on merge is not proof of deployment. PR checks are not deployment.
If closure or deployment fails, resolve it before proceeding.

## 4. Repeat safely for remaining Tasks

- Do not start a dependent Task until prerequisite PRs are merged.
- For each next Task, repeat Sections 2-3.
- Finish all selected Tasks.

The handoff authorizes implementation only within approved Task scope. It does
not authorize Sprint edits, Story closure by Task reference, or scope expansion.

## 5. Verify the combined Story result

After all selected Tasks are merged and deployed:

- Confirm each Task is Closed and each corresponding deployment succeeded.
- Validate the combined behavior against approved Story criteria.
- Use **real browser evidence** for browser-dependent outcomes
  (state persistence, accessibility, keyboard flow, contrast, fallback behavior).
- Do not treat mocked/server-only tests as sufficient proof for browser behavior.

Use your team's normal completion process to move Stories to Done. Never close
the parent Story from a Task PR description.

## Next Steps

After completing this dark-mode exercise, continue with the
**Accessible Ticket Creation** Feature under the same Epic from Part 4.
Use [Part 5](05-sprint-planning.md) with the `tasking-specialist` to
prepare its Stories' Tasks, then repeat this Part 6 flow for delivery.
Treat it as new work; do not assume it is already tasked or implemented.
