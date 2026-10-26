# Part 5: Sprint Planning and Tasking

Use a tasking specialist to turn selected work into implementation-ready Tasks.
The Azure Boards specialist from Part 4 owns product scope and Story refinement;
the tasking specialist owns the implementation breakdown.

This is the tasking portion of Sprint Planning, after the team selects work.
It does not choose a Sprint Goal, estimate capacity, configure a Sprint, or
assign iteration paths. Leave existing iteration values unchanged.

## Before you start

- Complete [Part 4](04-backlog-planning.md) and keep the verified Feature and
  Story IDs.
- Decide the scope: selected User Stories, or every Story under one Feature.
  For this walkthrough, target the **Accessible Dark Mode Feature**. Leave
  Accessible Ticket Creation and other Features in the product backlog.
- Use the existing application and deployment workflow; dark mode needs no
  additional services.

## 1. Open the tasking specialist

Review
[`.github/agents/tasking-specialist.agent.md`](../.github/agents/tasking-specialist.agent.md)
and select **tasking-specialist** in Copilot Chat. If it does not appear,
reload VS Code.

This agent assumes an AI coding agent will implement each Task end to end.
It prefers a cohesive Task for a Story's remaining implementation, including
all relevant layers, tests, safeguards, and documentation. It does not create
separate Tasks for routine human-sized activities such as styling, coding,
testing, or documentation.

Broader Tasks do not mean broader Stories or unlimited agent capacity.
The specialist splits work only for a concrete dependency, independent
deployment, risk boundary, or reviewability reason. Every Task still has
exactly one Story parent. Keeping related work together reduces repeated
handoffs and discovery, but does not guarantee a particular token saving.

## 2. Request the Tasks

Replace `<FEATURE_ID>` with the actual dark-mode Feature ID from Part 4:

```text
Prepare implementation Tasks for every User Story under Feature AB#<FEATURE_ID>.
An AI coding agent will handle each Task end to end.
```

If the team has already selected individual Stories instead, use their actual
IDs rather than the Feature-wide request:

```text
Prepare implementation Tasks for User Stories AB#<STORY_ID_1> and AB#<STORY_ID_2>.
An AI coding agent will handle each Task end to end.
```

Adjust the list to match the selected Stories; there is no required count.
Use one request or the other, not both for the same work.

The specialist reads the approved criteria, repository, and existing Tasks,
then proposes the breakdown. Feature input accounts for every child Story,
not a smaller agent-selected subset. Completed or already-covered work is
reported with evidence rather than recreated. Unclear or missing Story scope
goes back to the Boards specialist for separately approved refinement.

## 3. Review and approve

Check that the proposal:

- Covers every targeted Story and maps its criteria to existing work or
  proposed Tasks, with any blocked work explicit.
- Uses cohesive, end-to-end scopes suitable for coding-agent delivery, with
  a reason for each split and no arbitrary layer-based or routine substep Tasks.
- Gives every Task one correct Story parent, a deployable result, completion
  evidence, safeguards, relevant tests, and related documentation.
- Preserves existing behavior and defines actual prerequisites and safe
  integration with work that is not yet deployed.
- Shows exact proposed writes and reused items without changing Story
  criteria, assigning iterations, or modifying unrelated work.

Browser-dependent acceptance needs browser evidence; server-side tests and
mocks alone do not establish persistence or accessibility.

If the proposal is correct, reply:

```text
Approve the exact proposed operations.
```

The specialist creates or updates only the approved Tasks and Parent links.
This approval does not authorize Story refinement, Sprint assignment, coding,
or starting a coding agent.

## 4. Verify and hand off

Use the returned links to check the Task scopes, Story parents, criteria
coverage, and actual prerequisite IDs. Confirm unchanged iteration values and
default root backlog placement for new Tasks. The specialist must report
read-back verification, not just successful write commands.

For the sequential walkthrough in Part 6, new Tasks are created in execution
order with prerequisites first. Existing IDs may not follow that order; use
recorded prerequisites rather than recreating items to obtain numerical order.
Each Task must be safely deployable; deployment does not wait for the whole
Story, and a Task deployment does not automatically make its Story Done.

If execution fails, retain the reported IDs. Resolve the blocker and request a
resume using those items; do not rerun creation or replace partial items.

Keep the selected Story and Task IDs and verified handoff order for
[Part 6: Coding Agent Delivery](06-coding-agent-delivery.md).
