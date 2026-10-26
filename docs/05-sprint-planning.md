# Part 5: Backlog Task Preparation

Turn a small selection of existing User Stories into Tasks a coding agent can
implement and deploy separately. Each Task must deliver a tangible change,
not merely a routine substep. The outcome of this exercise is a reviewed
backlog, not a configured Sprint, a deployment, or a working application.

The Feature defines the complete experience; Stories define bounded,
acceptable components of it. Tasks are the units of implementation and
deployment. A Story is complete when all necessary work and its acceptance
criteria are satisfied, not when its implementation is first deployed.
Do not hold all Task deployments until the Story is complete.

## Before you start

Complete [Part 4](04-backlog-planning.md) and keep its specialist selected in
VS Code. If you already had the specialist, update its profile to match Part 4,
especially the identity, read-back, and interrupted-run rules.

Dark mode needs no application AI service, Foundry model access, or
infrastructure changes.
Use the existing application and deployment workflow. Foundry resources from
Part 1 are not dependencies of this feature.

## 1. Draft the Tasks

The demo should switch between light and dark themes using an accessible
control, preserve in-progress work across existing views, and restore the
saved choice after a reload. It must also handle invalid preferences and
unavailable browser storage safely. Select the existing Stories that cover
this complete Feature, rather than assuming particular titles or a fixed count.

For this walkthrough, create new Tasks in the order they should be
implemented: prerequisites first, then dependent work. Part 6 uses ascending
Task IDs as a convenient handoff order and reviews and merges each PR before
starting the next. There is no fixed Task count; two Tasks are an example,
not a requirement. Reused Tasks may have older IDs, so recorded prerequisites
always take precedence over numerical order. Do not recreate Tasks or invent
dependencies just to obtain a numerical sequence.

Submit this prompt:

```text
Prepare backlog Tasks for the Support Desk Simulator using your specialist
profile. Do not write to Boards until I approve the exact proposal.

Discovery:
- Verify CLI defaults, authenticated Boards identity, project, and Agile process.
- Inspect the repository, the existing Accessible Dark Mode Feature,
  all its child Stories, and matching Tasks across the project. Reuse matching
  items, including unparented Tasks from interrupted runs.
- Read each Story's actual acceptance criteria, whether in its description or
  dedicated field. Inspect the existing Blazor components, theme variables,
  hardcoded colors, and relevant tests. Preserve existing demo role and
  data-access rules, workflows, and API contracts.
- No Foundry model access or new infrastructure is required. Do not inspect
  or change Foundry resources, runtime endpoints, or Azure RBAC.

Selection:
- Select the existing product-facing Stories needed for the complete dark-mode
  demo, including accessible switching, all existing views, saved preferences,
  invalid stored values, and storage-unavailable feedback.
  Explain how their existing criteria cover the selected demo outcome.
- Reuse selected Stories unchanged. If scope is unclear or too large, identify
  the Story for refinement; do not draft Tasks for it until resolved. If required
  theme, accessibility, or persistence behavior is absent from the existing
  criteria, name the affected Story and missing scope and return to Part 4 for
  separately approved
  refinement. Do not invent criteria or silently add a new Story here.
- Leave unrelated Stories and any existing AI backlog items untouched.

Task decomposition:
- Create only the Tasks needed for distinct, coding-agent-sized, tangible units
  of implementation and deployment. No fixed count. A Task need not deliver
  the whole Story; completing all its Tasks must satisfy that Story's criteria.
- Assess theme styling, accessible controls, and browser-preference persistence
  as candidate implementation units, not a mandatory three-Task template.
  Reuse the existing Blazor and CSS patterns, including theme variables and
  hardcoded colors that need theme-aware equivalents. Keep light mode intact.
  No backend/API or agent/prompt unit is needed merely to fill a template.
- Define ownership of the shared theme state, theme application, and preference
  read/write contract. Account for Blazor Interactive Server prerendering and
  browser interop availability. Keep each browser's theme isolated; do not put
  a mutable preference in a singleton shared across users.
- Prefer existing .NET and browser capabilities. If persistence needs a small
  first-party JavaScript module, include its ownership and tests in the
  appropriate Task; no Node.js, npm, or frontend package pipeline is required.
- State the tangible result deployed by each Task and how it preserves current
  behavior while related work is incomplete. Define the necessary interfaces,
  integration points, and prerequisite Tasks. Use existing compatibility or
  gating conventions where needed; do not assume unfinished capabilities are
  exposed or defer all deployments until Story completion.
- Give each behavior a clear owner. Include relevant fallback handling,
  security checks, tests, and directly related documentation within its unit;
  do not hide all safeguards in a catch-all Task or create routine substep Tasks.
- Use explicit contracts and test doubles where appropriate so independent
  units can be developed and checked without Azure access. Record actual
  integration dependencies, not artificial sequencing of otherwise independent
  work. Keep scopes non-overlapping.

Each Task draft must include:
- Action-oriented title and existing parent Story ID.
- Bounded implementation scope and inspected repository areas likely to change.
- Tangible deployable result, interface ownership, and safe behavior when
  related Tasks are not yet deployed.
- Verifiable completion tied to the parent's existing acceptance criteria.
- Required automated test evidence for that unit, including relevant success,
  fallback/error, and compatibility cases without Azure access or secrets.
  Use automated checks for theme selection and preference behavior, and
  browser evidence for actual persistence, keyboard operation, contrast,
  responsive layouts, and representative UI states in both themes.
- Relevant security, privacy, reliability, and accessibility constraints.
- Dependencies/blockers, including prerequisite Tasks and execution order.

Preserve these constraints in every written Task:
- Theme changes must not reload the application, reset filters or selection,
  discard draft input, change ticket data, or alter existing role boundaries.
- Preserve existing light-mode behavior and theme coverage across all views
  and their interactive, validation, empty, notification, and error states.
- Maintain the parent's keyboard, assistive-technology, and contrast criteria.
- Store only a validated light/dark preference locally in the browser; no
  ticket content, demo identity, credentials, or account-level settings.
- Missing or invalid preferences use light mode. When storage is unavailable,
  retain interactive-session switching and show accessible, non-blocking
  feedback that saving failed. Do not silently claim persistence.
- No AI integration, new API endpoints, database, provisioning, RBAC changes,
  secrets, or unrelated redesign. Do not add system-theme detection or sync.

Proposal:
Report verified scope/identity and Feature once. Show selected Stories and
Task drafts in parent-to-child order; state the demo outcome and briefly
explain selection, exclusions, and each Task split. Show shared constraints
once, with inheritance explicit. Do not repeat entire Story descriptions.
Show which existing Story criteria each Task contributes to and check that the
Tasks collectively fulfill each selected Story. Make styling, control, and
preference ownership visible and explain how each Task can be deployed;
neither Task completion nor deployment alone means the whole Story is complete.
List assumptions, open questions, dependencies, and execution order separately.
Specify a creation order for new Tasks that follows the proposed execution
order across all selected Stories, with prerequisites before dependent Tasks.
Independent Tasks may be placed in either order for the sequential walkthrough;
do not add artificial dependencies between them.
Identify existing Tasks to reuse and specify exact create, field-update, and
Parent-link operations; record prerequisite IDs in descriptions without
additional dependency links. No new Stories or changes to existing Story
criteria, estimates, capacity, policy, or Definition of Done.
Ask one explicit approval question; do not ask again about confirmed facts or
repository conventions.

Execution after approval:
Use your profile's duplicate prevention, ID recording, read-back normalization,
and failure/resume rules. Create/update only approved Tasks and Parent links.
Each Task must have exactly one selected Story parent. Replace draft
prerequisite labels with actual Task IDs in descriptions.
Create new Tasks in the approved creation order, preserving each Task's
approved Story parent even when the sequence crosses Stories. Reuse existing
Tasks without recreating them to change ID order; report any case where the
recorded prerequisites require a different handoff order from ascending IDs.
Do not inspect/configure project/team iterations, Sprint dates, or settings;
do not assign iteration paths. Reading current work-item iteration fields is
required to verify unchanged values and default root placement for new Tasks.
Report ID, title, type, state, parent, current iteration, URL, dependencies, and
verification for every affected item. Stop on a real failure; no replacements.
```

## 2. Approve the proposal

Check that the selected Stories deliver the demo outcome and every Task has a
clear scope, tangible deployable result, completion condition, tests, and
dependencies. Check that styling, controls, and browser-preference responsibilities
are accounted for without forcing a fixed number of Tasks, and that completing
the Tasks would fulfill each selected Story. Deployment is per Task, not held
until Story completion. Browser checks must be visible, not assumed satisfied by
server-side tests or test doubles.

If the proposal is correct, reply:

```text
Approve the exact proposed operations.
```

The agent creates or updates only those Tasks and links. No Sprint or iteration
assignment is part of this approval.

## 3. Check the result

Use the returned links to spot-check the selected Stories and Tasks:

- Each Task has the correct Story parent and approved scope.
- Descriptions include completion evidence and actual prerequisite Task IDs.
- New Tasks were created in the approved execution order. If reused IDs do
  not follow that order, the reported handoff sequence follows prerequisites.
- Each Task identifies its deployable change and safe integration with work
  that may not yet be deployed; Story completion is not a deployment gate.
- Existing iteration values are unchanged; new Tasks use the root backlog path.
- Unselected Stories are untouched and no provisioning work was added.

The agent must read all affected items back. Harmless HTML whitespace or entity
normalization is not an error; missing content or an incorrect link is.
If it stops after a real failure, retain the reported IDs and request a resume
only after resolving the blocker. Do not rerun creation or replace partial items.

Keep the selected Story/Task IDs and execution order for
[Part 6: Coding Agent Delivery](06-coding-agent-delivery.md). Implementation,
deployment, and actual browser behavior still need verification before the
demo is complete.
