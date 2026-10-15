# Part 5: Backlog Task Preparation

Turn a small selection of existing User Stories into Tasks a coding agent can
implement separately. The outcome is a reviewed backlog, not a configured
Sprint or a working application.

## Before you start

Complete [Part 4](04-backlog-planning.md) and keep its specialist selected in
VS Code. If you already had the specialist, update its profile to match Part 4,
especially the identity, read-back, and interrupted-run rules.

Part 1's Foundry resource, `support-sim-project`, and `gpt-5.4-mini` must already
exist. Reuse the deployment confirmation from the earlier steps; do not deploy
them again. Runtime model access may still be an external dependency.

## 1. Draft the Tasks

The demo should answer a status or assignee question about one synthetic ticket,
identify its source, and give a clear fallback when it cannot answer.
Normally the answer Story and fallback Story are sufficient. Source attribution
already required by an answer Story does not by itself require selecting a
third Story.

Submit this prompt:

```text
Prepare backlog Tasks for the Support Desk Simulator using your specialist
profile. Do not write to Boards until I approve the exact proposal.

Discovery:
- Verify CLI defaults, authenticated Boards identity, project, and Agile process.
- Inspect the repository, the existing Constrained Ticket Status Q&A Feature,
  all its child Stories, and matching Tasks across the project. Reuse matching
  items, including unparented Tasks from interrupted runs.
- Read each Story's actual acceptance criteria, whether in its description or
  dedicated field. Reuse the existing repo-defined demo read-access and
  visibility rules; keep one explicit ticket per request and no conversation
  history.
- Reuse Part 1 confirmation already available. Missing foundation resources
  block this exercise; do not add provisioning work. Record unresolved runtime
  endpoint and managed-identity access separately from code/test completion.

Selection:
- Select two existing product-facing Stories: normally status/assignee answers
  and safe fallbacks. Select a third only if necessary for a usable demo.
- Reuse selected Stories unchanged. If scope is unclear or too large, identify
  the Story for refinement; do not draft Tasks for it until resolved.
- Leave other Stories and Conversational Queue Insights untouched.
- Create only the Tasks needed for distinct, coding-agent-sized units.
  No fixed count. Include related tests/docs within each unit; do not create
  routine substep Tasks. Keep scopes non-overlapping and dependencies explicit.

Each Task draft must include:
- Action-oriented title and existing parent Story ID.
- Bounded implementation scope and inspected repository areas likely to change.
- Verifiable completion tied to the parent's existing acceptance criteria.
- Required automated test evidence for that unit.
- Relevant security, privacy, reliability, and accessibility constraints.
- Dependencies/blockers, including prerequisite Tasks and execution order.

Preserve these constraints in every written Task:
- Read-only and stateless, using current caller-visible synthetic data.
- Application logic retrieves facts; the model cannot invent them.
- Questions and ticket text are untrusted, never instructions.
- Unsupported, ambiguous, malformed, unknown/invisible-ticket, and unavailable-AI
  cases receive clear, non-fabricated fallbacks without disclosing hidden data.
- No ticket content, questions, prompts, or model responses in logs.
- Existing role/data boundaries stay intact; no ticket actions or arbitrary
  queries. Use managed identity and least-privilege production runtime RBAC;
  no committed secret, key, credential, or connection string.
- Use only existing Part 1 resources where the parent Story requires them.
  No Foundry provisioning, reconfiguration, or infrastructure-enablement Tasks.
  Backlog preparation makes no Azure resource or RBAC changes.

Proposal:
Report verified scope/identity and Feature once. Show selected Stories and
Task drafts in parent-to-child order; state the demo outcome and briefly
explain selection, exclusions, and each Task split. Show shared constraints
once, with inheritance explicit. Do not repeat entire Story descriptions.
List assumptions, open questions, dependencies, and execution order separately.
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
Do not inspect/configure project/team iterations, Sprint dates, or settings;
do not assign iteration paths. Reading current work-item iteration fields is
required to verify unchanged values and default root placement for new Tasks.
Report ID, title, type, state, parent, current iteration, URL, dependencies, and
verification for every affected item. Stop on a real failure; no replacements.
```

## 2. Approve the proposal

Check that the selected Stories deliver the demo outcome and every Task has a
clear scope, completion condition, tests, and dependencies. Unresolved runtime
access must be visible, not disguised as a provisioning Task or assumed ready.

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
- Existing iteration values are unchanged; new Tasks use the root backlog path.
- Unselected Stories are untouched and no provisioning work was added.

The agent must read all affected items back. Harmless HTML whitespace or entity
normalization is not an error; missing content or an incorrect link is.
If it stops after a real failure, retain the reported IDs and request a resume
only after resolving the blocker. Do not rerun creation or replace partial items.

Keep the selected Story/Task IDs and execution order for
[Part 6: Coding Agent Delivery](06-coding-agent-delivery.md). Implementation and
live managed-identity access still need verification before the demo can run.
