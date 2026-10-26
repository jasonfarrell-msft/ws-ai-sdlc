# Part 5: Prepare Backlog Tasks

Turn selected User Stories into Tasks that a coding agent can implement and
deploy separately. This part prepares and verifies the backlog; it does not
configure a Sprint, deploy the application, or create a working feature.

## Before you start

- Complete [Part 4](04-backlog-planning.md). Keep the Azure Boards specialist
  selected in Copilot Chat.
- Keep the approved Feature and Story IDs from Part 4.
- Dark mode uses the existing application and deployment workflow. Foundry
  resources and application model access are not dependencies of this feature.

## 1. Prepare the Task proposal

Ask the **azure-boards-specialist** to draft Tasks for the existing Stories.
Submit this prompt in Copilot Chat:

```text
Prepare backlog Tasks for the Support Desk Simulator using your profile.
Do not write to Azure Boards until I approve the exact proposal.

Verify CLI defaults, the configured organization and project, Agile process,
and authenticated Boards identity. Inspect the repository, the existing
Accessible Dark Mode Feature, its child Stories, and matching Tasks across
the project. Read each Story's acceptance criteria from its description or
dedicated field. Reuse matching items, including unparented Tasks from
interrupted runs. Inspect existing Blazor components, theme variables,
hardcoded colors, and relevant tests. Do not inspect or change Foundry
resources, runtime endpoints, or Azure RBAC.

Select the existing product-facing Stories needed for the complete dark-mode
demo: accessible switching across existing views, preservation of in-progress
work, saved preferences restored after reload, invalid stored values, and
storage-unavailable feedback. Explain how their current criteria cover the
demo. Reuse Stories unchanged. If scope is missing or unclear, identify the
Story and missing scope, then stop Task drafting for it and return to Part 4
for separately approved refinement. Do not invent criteria, add Stories, or
change existing criteria. Leave unrelated Stories and AI backlog items untouched.

Draft only the Tasks needed for distinct, coding-agent-sized units of
implementation and deployment. Do not force a fixed Task count. Assess theme
styling, accessible controls, and browser-preference persistence as candidate
units; explain combinations or omissions. Reuse existing Blazor and CSS
patterns, including theme variables and hardcoded colors that need theme-aware
equivalents. Keep light mode intact. No backend/API or agent/prompt unit is
needed merely to fill a template.

Define ownership of shared theme state, theme application, and preference
read/write contracts. Account for Blazor Interactive Server prerendering and
browser interop availability. Keep each browser's theme isolated; do not put
a mutable preference in a singleton shared across users. Prefer existing .NET
and browser capabilities. If persistence needs a small first-party JavaScript
module, include its ownership and tests in the appropriate Task; no Node.js,
npm, or frontend package pipeline is required.

Each Task must have one existing parent Story and include:
- Action-oriented title, bounded scope, and repository areas likely to change.
- Tangible deployable result, interface ownership, integration points, and
  safe behavior while related work is incomplete.
- Completion evidence tied to the parent's existing criteria.
- Automated tests for success, fallback/error, and compatibility behavior,
  without Azure access or secrets. Check theme selection and preference logic.
- Browser evidence for persistence, keyboard operation, contrast, responsive
  layouts, and representative UI states in both themes where relevant.
- Relevant security, privacy, reliability, and accessibility requirements.
- Actual prerequisite Task IDs and execution order.

Give every behavior a clear owner. Include relevant safeguards, tests, and
documentation in each Task. Keep scopes non-overlapping; do not create routine
substep Tasks, a catch-all safeguards Task, or artificial dependencies.
Use explicit contracts and test doubles where useful. Do not defer deployment
until Story completion. Server-side tests and mocked storage alone do not
prove actual browser behavior.

Preserve these constraints in every Task:
- Theme changes must not reload the application, reset filters or selection,
  discard draft input, change ticket data, or alter existing role boundaries.
- Preserve light-mode behavior and theme coverage across all views and their
  interactive, validation, empty, notification, and error states.
- Maintain the parent's keyboard, assistive-technology, and contrast criteria.
- Store only a validated light/dark preference locally in the browser; no
  ticket content, demo identity, credentials, or account-level settings.
- Missing or invalid preferences use light mode. When storage is unavailable,
  retain interactive-session switching and show accessible, non-blocking
  feedback that saving failed. Do not silently claim persistence.
- No AI integration, new API endpoints, database, provisioning, RBAC changes,
  secrets, or unrelated redesign. Do not add system-theme detection or sync.

Present the verified scope and identity, Feature, selected Stories, and Task
drafts in parent-to-child order. Explain the demo outcome, exclusions, and
Task boundaries. Map each Task to its parent's existing criteria and verify
that the Tasks collectively fulfill each selected Story. Show styling,
control, and preference ownership and how each Task can be deployed safely.
State shared constraints once and make inheritance explicit. List assumptions,
open questions, dependencies, and execution order separately.

Identify existing Tasks to reuse. Specify exact create, field-update, and
Parent-link operations. Propose new Task creation in execution order, with
prerequisites first; independent Tasks may be ordered either way. Reused Tasks
may have older IDs, so actual prerequisites take precedence over numeric order.
Keep each approved Story parent even when creation order crosses Stories.
Record prerequisite IDs in Task descriptions; do not add dependency links.
Each Task must have exactly one selected Story parent. Do not repeat entire
Story descriptions in the proposal.

Do not change Story criteria, estimates, capacity, policy, or Definition of
Done. Do not inspect or configure iterations, Sprint dates, or settings; do not
assign iteration paths. Read current iteration fields to verify they remain
unchanged and new Tasks use the default root backlog path.

Ask one explicit approval question. After approval, create or update only the
approved Tasks and Parent links. Replace draft prerequisite labels with actual
Task IDs. Use your duplicate-prevention, ID-recording, read-back, and
failure/resume rules. Read every affected item back and report ID, title, type,
state, parent, current iteration, URL, dependencies, and verification. Stop
on a real failure or uncertain create; do not retry uncertain creates or
create replacements.
```

## 2. Review and approve

Check that the selected Stories cover the demo and each Task has a bounded
scope, deployable result, completion evidence, tests, and actual dependencies.
Confirm that styling, controls, and browser-preference work are accounted for,
and that completing the Tasks would fulfill each selected Story. Browser
checks must be visible, not assumed satisfied by server-side tests or doubles.

If the proposal is correct, reply:

```text
Approve the exact proposed operations.
```

The specialist creates or updates only the approved Tasks and links. This
approval does not assign Tasks to a Sprint or iteration.

## 3. Verify the backlog

Use the returned links to check that:

- Each Task has the approved scope and exactly one selected Story parent.
- Descriptions include completion evidence and actual prerequisite Task IDs.
- New Tasks were created in the approved order. If reused IDs do not follow
  execution order, the reported handoff sequence respects prerequisites.
- Each Task has a deployable result and safe behavior while related work is
  incomplete. A Task deployment does not mean its Story is complete.
- Existing iteration values are unchanged; new Tasks use the default root
  backlog path.
- Unselected Stories were not changed, and no provisioning work was added.

The specialist must read all affected items back. Harmless HTML whitespace or
entity normalization is acceptable; missing content or incorrect links are
not. If work stops after a real failure, retain the reported IDs and request
a resume only after resolving the blocker. Do not rerun creation or replace
partial items.

Keep the selected Story and Task IDs and execution order for
[Part 6: Coding Agent Delivery](06-coding-agent-delivery.md). Implementation,
deployment, and actual browser behavior still need verification before the
demo is complete.
