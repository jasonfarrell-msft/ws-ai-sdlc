# Part 4: Backlog Planning

Create an Azure Boards specialist, then use it to prepare the product backlog.
The agent proposes changes; you approve them before it writes to Azure Boards.
This part creates no Tasks or Sprints.

## Before you start

Complete [Part 3](03-azure-devops-setup.md) and open your fork in VS Code.
Part 1 must have completed successfully: it provisions Microsoft Foundry,
`support-sim-project`, and `gpt-5.4-mini`. Application access to the model is
separate and may still need authorization.

## 1. Create the specialist

A custom agent is a saved set of instructions for Copilot. This one uses the
Azure Boards Agile hierarchy: **Epic > Feature > User Story > Task**.
Scrum does not require that hierarchy; it is how this workshop organizes work.

Create the profile folder:

```powershell
New-Item -ItemType Directory -Path .github/agents -Force
```

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
- Completed Part 1 confirms the existing Foundry resource, support-sim-project,
  and gpt-5.4-mini. Reuse its saved output or the user's existing confirmation;
  do not ask for resource names solely to draft backlog work. Documentation
  examples are not deployment evidence. If confirmation is absent, ask once
  for saved output or a resource group for a scoped, read-only check.
- If a foundation resource is missing, report the Part 1 prerequisite and stop.
  Do not create provisioning work. Endpoint configuration and managed-identity
  runtime permission are separate application dependencies, not proof of
  missing infrastructure. Keep external access checks separate from code/test
  completion; do not change Azure resources or RBAC while planning.

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
  acceptance criteria, constraints, and a path to User Stories.
- User Story: one parent Feature; "As a <user>, I want <capability>, so that
  <value>"; observable Given/When/Then criteria; relevant rules and dependencies.
  Keep it a small, independently valuable slice, not an implementation layer.
- Task: one parent Story, action-oriented title, bounded implementation scope,
  completion tied to existing Story criteria, automated test evidence, relevant
  security/privacy/reliability/accessibility constraints, dependencies with
  prerequisite Task IDs, and inspected repository areas likely to change.
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

The core Feature answers questions about one ticket. The optional Feature
answers questions across the queue; it stays outside the later coding exercise.

Submit this prompt to the specialist:

```text
Prepare the Support Desk Simulator product backlog using your profile.
Inspect the repository and Boards; reuse existing items without duplicates.
Verify CLI defaults, the authenticated Boards identity, project, and Agile
process. Present a proposal before any writes.

Use this hierarchy:
- Epic: Conversational Ticket Insights
- Core Feature: Constrained Ticket Status Q&A
  Read-only, single-turn status, assignee, priority, and product questions
  about one explicitly identified ticket. Answer from current caller-visible
  data and identify the source ticket.
- Optional Feature: Conversational Queue Insights
  Constrained counts by status, filtered lists, unassigned counts, product
  comparisons, and status summaries. Application logic performs calculations;
  empty results receive a clear response.

For both Features:
- Use synthetic data only. Preserve existing role and data-access boundaries.
- Keep requests stateless; no conversation history, ticket mutations,
  assignment, status changes, arbitrary queries, or automatic resolution.
- Application logic retrieves facts; the model must not invent them.
- Treat questions and ticket text as untrusted data, not instructions.
- Provide clear fallbacks for unsupported, ambiguous, malformed, unknown-ticket,
  and unavailable-AI cases. Do not log ticket content, questions, prompts, or
  model responses.
- Use only Part 1's existing Foundry resource, support-sim-project, and
  gpt-5.4-mini. No provisioning work. Record runtime connection, managed-identity
  least-privilege access, usage limits, and monitoring as dependencies where
  unresolved; do not invent thresholds. No keys or connection strings.

Propose 3-4 product-facing Stories for the core Feature and 2-3 for the optional
Feature. Derive measurable success indicators and observable acceptance
criteria from these requirements. Apply your profile's item-quality rules.
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
of existing items. If it matches your intent, reply:

```text
Approve the exact proposed operations.
```

After execution, use the returned links to spot-check the Epic, both Features,
and their Stories. Every Feature must have the Epic as its parent; every Story
must have one Feature parent. The agent's report must show read-back results,
not just successful create commands.

Keep the reported IDs for later parts. If execution stops, resolve the reported
problem and ask the agent to resume using the existing IDs, not replacements.
Continue to [Part 5: Backlog Task Preparation](05-sprint-planning.md).
