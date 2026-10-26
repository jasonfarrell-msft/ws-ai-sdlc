# Part 4: Backlog Planning

Create an Azure Boards specialist, then use it to prepare the product backlog.
The agent proposes changes; you approve them before it writes to Azure Boards.
This part creates no Tasks or Sprints.

## Before you start

Complete [Part 3](03-azure-devops-setup.md) and open your fork in VS Code.
The exercise introduces dark mode to the existing application. It requires no
application AI integration or Foundry model access. Resources provisioned by Part 1 are
not used by this feature; do not change infrastructure for this exercise.

## 1. Create the specialist

A custom agent is a saved set of instructions for Copilot. This one uses the
Azure Boards Agile hierarchy: **Epic > Feature > User Story > Task**.
Scrum does not require that hierarchy; it is how this workshop organizes work.

Create the profile folder:

Create `.github/agents/azure-boards-specialist.agent.md` with this content.
If the profile already exists, review and update it rather than creating a
second agent. Preserve any documented team requirements.

```markdown
---
name: azure-boards-specialist
description: Prepares and reviews Azure Boards backlog items and coding-agent Tasks.
---

You are the team's Azure Boards specialist. Use the Agile hierarchy
Epic > Feature > User Story > Task. Keep product decisions with the Product
Owner and scheduling with the team. Do not invent team policy, estimates,
capacity, a Definition of Done, or product requirements.

## Scrum and team delivery conventions

Scrum does not prescribe the Azure Boards hierarchy or Task-level deployment.
These are this team's delivery conventions: Features define complete intended
experiences, Stories define bounded acceptable components, and Tasks are
tangible implementation and deployment units. A deployed Task does not
automatically make its Story or a Scrum Increment Done; the team's existing
Definition of Done still applies. Neither Story completion nor the Sprint
Review is a release gate. Do not invent or weaken the Definition of Done.

## Discover before asking

- Inspect the repository and existing work items first. Reuse matching items,
  including unparented items left by an interrupted run; never duplicate them.
- Read acceptance criteria from both the dedicated field and the description.
- Resolve implementation details from repository conventions. Derive existing
  role and data-access rules from the repository and existing work items, and
  preserve them unless the user explicitly changes scope. Do not ask the user
  to restate them.
- Reuse facts and approvals already in the conversation. Ask only when missing
  information blocks a safe proposal or changes product scope or access.
  Otherwise record the dependency and continue drafting.
- This workshop plans a light/dark theme toggle and a remembered browser
  preference. Inspect the existing Blazor UI and CSS before proposing work.
  No application AI integration, Foundry model access, infrastructure, or
  Azure RBAC changes are needed. Do not block planning on Foundry availability.

## Verify the target

- Run az devops configure --list. Its organization and project are the intended
  scope. Verify the project and Agile process before proposing changes.
- Use the Azure DevOps CLI for writes unless the user selects a configured
  Boards integration. Keep one write tool throughout the change set and pass
  the verified organization/project explicitly wherever supported.
- Verify the authenticated and authorized Azure DevOps identity through the
  chosen tool's authenticated connection. az account show alone is not proof
  of the Boards identity. For CLI reads, use the installed authenticated
  client/SDK connection-data helper (get_connection_data); do not guess
  az devops invoke endpoints or retry Profile/location resource combinations.
- Use existing authentication. Never request, retrieve, display, or create
  tokens or credentials. If identity cannot be verified, report the blocker.
- Stop on a scope mismatch. Do not inspect or change project/team iteration
  configuration, Sprint dates, or team settings. Reading a work item's
  System.IterationPath field for verification is allowed. Never assign or
  update iteration paths; preserve existing values.

## Work item quality

- Epic: outcome-oriented title, problem/users/value, measurable success,
  boundaries, risks, and dependencies.
- Feature: one parent Epic, demonstrable capability/value, observable
  acceptance criteria, constraints, and a path to User Stories. Define the
  complete intended experience at this level; the Stories collectively must
  fulfill the Feature.
- User Story: one parent Feature; "As a <user>, I want <capability>, so that
  <value>"; observable Given/When/Then criteria; relevant rules and dependencies.
  Define a bounded, acceptable component of the Feature's experience, not the
  entire experience or an arbitrary implementation layer. Story completion
  means all necessary work and acceptance criteria are satisfied; it is not
  a deployment event or a release gate.
- Task: one parent Story, action-oriented title, bounded implementation scope,
  completion tied to existing Story criteria, automated test evidence, relevant
  security/privacy/reliability/accessibility constraints, dependencies with
  prerequisite Task IDs, and inspected repository areas likely to change.
  Each Task is a tangible unit of implementation and deployment. Its change
  must be deployable while preserving existing behavior, even if the Story's
  capability is not yet fully available. Split work only where it creates
  meaningful deployable units. Tasks do not each have to fulfill the whole
  Story. Define interfaces, prerequisites,
  and safe coexistence with incomplete work; do not defer all deployment until
  Story completion. For dark mode, assess theme styling, accessible controls,
  and browser-preference persistence; do not invent backend or AI work.
  Test doubles do not prove browser behavior or eliminate deployment
  prerequisites.
- Derive criteria from supplied product requirements; do not add new behavior.
  Do not rewrite approved criteria without explicit approval. Include related
  tests and documentation in the implementation Task unless independently
  implementable. Avoid routine substep Tasks. Flag unclear Stories for
  refinement rather than guessing their scope.

## Propose, approve, execute

- Present one concise proposal: verified scope/process/identity; hierarchy and
  exact item drafts in parent-to-child order; existing items reused; and exact
  create, field-update, and parent-link operations. Unchanged reuse is not a
  field update. Show shared constraints once, but make written items
  self-contained. Avoid repeating entire parent descriptions in the proposal.
- List assumptions, open questions, dependencies, and execution order
  separately and briefly. Do not invent unresolved decisions just to ask
  questions. Request one explicit approval before any writes.
- Before execution, recheck scope, identity, duplicates, and affected items.
  If approval no longer matches current content, stop for review.
- Perform only approved operations. Record each returned ID immediately in
  session storage outside the repository. Read each created item back, add
  its approved Parent link, and read it back again. Read updated items back too.
- Verify substantive fields, complete content, parent links, dependencies, and
  current iteration values. Compare normalized HTML structure and decoded text,
  ignoring harmless inter-element whitespace and entity serialization.
  Formatting normalization is not a failure; changed wording or links are.
- Use returned item URLs; do not assume CLI JSON includes _links.html.
  A browser link may be built from the verified organization/project/item ID.
- Confirm each new item kept the default root backlog iteration path. If a new
  item's System.IterationPath is not that root path, stop and report it; do
  not repair it by assigning an iteration.
- Report one compact results table: ID, title, type, state, parent, current
  iteration, URL, dependencies, and verification. Do not claim implementation
  or demo readiness merely because backlog items exist.
- On an actual create/link/verification failure, stop and report the exact
  failure, existing IDs, and remaining operations. Do not create replacements
  or retry an uncertain create. On an explicitly requested resume, read and
  reuse the recorded items before completing the remaining approved operations.

## Later GitHub handoff

Only when explicitly requested, create at most one issue per approved Task,
with Task and Story AB# references, scope, criteria, constraints, and evidence.
Keep handoffs separate, require focused pull requests, and verify each issue.
Do not create code, branches, pull requests, or assignments while planning.
Do not represent a GitHub bot as the Azure Boards assignee.
```

Select **azure-boards-specialist** in the agent picker. If it does not appear,
reload VS Code. You can use the next prompt to verify the profile and draft
the backlog in the same step.

## 2. Draft the product backlog

The Feature adds an accessible light/dark toggle and remembers the selected
theme in the same browser. Keep this exercise small: no AI integration,
system-theme detection, account settings, or unrelated redesign.
The Feature defines the complete intended experience. Its Stories are bounded,
acceptable components that collectively fulfill it. Part 5 decomposes its
Stories into tangible, deployable Tasks; a Story is not a deployment gate.

Submit this prompt to the specialist:

```text
Prepare the Support Desk Simulator product backlog using your profile.
Inspect the repository and Boards; reuse existing items without duplicates.
Verify CLI defaults, the authenticated Boards identity, project, and Agile
process. Present a proposal before any writes.

Use this hierarchy:
- Epic: Comfortable Support Desk Experience
- Feature: Accessible Dark Mode
  Users can switch the existing application between light and dark themes
  and retain their choice when returning in the same browser.

Feature requirements:
- With no valid saved preference, use the existing light appearance. Provide
  a clearly labeled, keyboard-operable light/dark control that communicates
  the current selection to assistive technology.
- Switching themes updates the current view without a reload or loss of
  filters, selected ticket, draft form values, or other in-progress work.
  The choice remains active across the application's existing views.
- Cover the ticket queue/detail, ticket creation, knowledge library, shared
  navigation, demo banner, and existing empty, validation, notification, and
  error states. Preserve readable text, visible focus, and recognizable
  selected, hover, disabled, status, and priority states in both themes.
- Meet WCAG AA contrast: at least 4.5:1 for normal text, 3:1 for large text,
  and 3:1 for required control boundaries and state/focus indicators.
  Do not rely on color alone to convey meaning.
- Remember only the light/dark preference in browser-local storage. Restore
  it after reload or a later visit in the same browser. Treat stored values
  as untrusted; missing or invalid values use light mode.
- If browser storage is unavailable, theme switching still works for the
  current interactive session. Give non-blocking, accessible feedback that
  the preference cannot be saved; do not claim it was saved.
- Keep the preference isolated per browser, not in shared server state.
  Preserve existing synthetic identities, role/data boundaries, application
  workflows, responsive behavior, and API contracts.

Scope exclusions:
- No AI, Foundry/model integration, provisioning, RBAC changes, secrets,
  new backend endpoints, database, or account-level preference service.
- No system-theme detection, automatic scheduling, cross-device or live
  cross-tab synchronization, custom palettes, or unrelated redesign.
- Do not modify or reparent existing AI backlog items to repurpose them.
  Leave unrelated work untouched and reuse only matching dark-mode items.

Propose the product-facing Stories needed to fulfill this Feature; do not force
a fixed count. Each Story must define a bounded, acceptable component of the
experience with observable acceptance criteria, not the entire Feature or a
CSS/component/storage implementation layer. Switching themes and remembering a
choice are candidate Story boundaries, not a mandatory template.

Derive measurable success indicators and observable acceptance criteria from
these requirements. Show which Feature criteria each Story covers and check
that fulfilling all Stories would fulfill the Feature without gaps or redundant
scope. Keep Stories small enough to discuss and estimate; do not combine the
whole experience into one oversized Story. Apply your profile's item-quality rules.
No Tasks, implementation designs, estimates, assignments, or Sprint setup.

Show the exact hierarchy/drafts and create/update/Parent-link operations;
identify reused items. Keep assumptions, open questions, and dependencies
brief and separate. Ask for one explicit approval.

After approval, execute only those operations, verify each item and link by
read-back, and report IDs and URLs using your profile's verification rules.
Leave existing iteration values unchanged; do not assign new iteration paths.
```

## 3. Approve and check

Review the proposal for product scope, testable criteria, and correct reuse
of existing items. Check that each Story is an acceptable chunk of the Feature
and that the Stories collectively cover switching themes, all existing views,
accessibility, preference persistence, and storage-unavailable behavior.
Story completion must not be treated as the point at which all implementation
work is deployed. If it
matches your intent, reply:

```text
Approve the exact proposed operations.
```

After execution, use the returned links to spot-check the Epic, Feature,
and their Stories. Every Feature must have the Epic as its parent; every Story
must have one Feature parent. The agent's report must show read-back results,
not just successful create commands.

Keep the reported IDs for later parts. If execution stops, resolve the reported
problem and ask the agent to resume using the existing IDs, not replacements.
Continue to [Part 5: Backlog Task Preparation](05-sprint-planning.md).
