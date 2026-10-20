# Part 5: Prepare Backlog Tasks

Turn selected User Stories into Tasks that a coding agent can implement and
deploy separately. This part prepares and verifies the backlog; it does not
configure a Sprint, deploy the application, or create a working feature.

## Before you start

- Complete [Part 4](04-backlog-planning.md). Keep the Azure Boards specialist
  selected in Copilot Chat.
- Confirm that Part 1 created Foundry, `support-sim-project`, and
  `gpt-5.4-mini`. Do not redeploy or add provisioning work here.
- Keep the approved Feature and Story IDs from Part 4.

## 1. Prepare the Task proposal

Ask the **azure-boards-specialist** to draft Tasks for the existing Stories.
Submit this prompt in Copilot Chat:

```text
Prepare backlog Tasks for the Support Desk Simulator using your profile.
Do not write to Azure Boards until I approve the exact proposal.

Verify CLI defaults, the configured organization and project, Agile process,
and authenticated Boards identity. Inspect the repository, the existing
Constrained Ticket Status Q&A Feature, its child Stories, and matching Tasks
across the project. Read each Story's acceptance criteria from its description
or dedicated field. Reuse matching items, including unparented Tasks from
interrupted runs. Reuse Part 1's confirmation for the existing Foundry
resources. Record unresolved runtime endpoint or managed-identity access as
external demo blockers, not code work.

Select the smallest set of existing product-facing Stories needed to demo a
status or assignee question about one synthetic ticket, with its source and a
clear fallback in an accessible interaction in the existing application.
Follow the repository's existing demo read-access and visibility rules. Keep
each request to one explicit ticket and do not add conversation history.
Explain how the Stories' current criteria cover the demo; source attribution
already required by an answer Story does not require selecting another Story.
Reuse Stories unchanged. If scope is missing or unclear, identify the Story
and missing scope, then stop Task drafting for it and return to Part 4 for
separately approved refinement. Do not invent criteria, add Stories, or change
existing criteria. Leave other Stories and Conversational Queue Insights
untouched.

Draft only the Tasks needed for distinct, coding-agent-sized units of
implementation and deployment. Do not force a fixed Task count. Assess backend,
frontend, and agent/prompt work as candidate units; explain combinations or
omissions. Consider backend contracts, current-ticket retrieval, caller access
checks, and grounded answers; frontend ticket/question input, answer/source,
and fallback presentation; and agent/prompt artifacts, constrained
interpretation, model adapter, validated outputs, and automated behavior
evaluations when required. These are candidates, not a template. Agent/prompt
work does not authorize hosted-agent provisioning or assume a Foundry
architecture.

Each Task must have one existing parent Story and include:
- Action-oriented title, bounded scope, and repository areas likely to change.
- Tangible deployable result, interface ownership, integration points, and
  safe behavior while related work is incomplete.
- Completion evidence tied to the parent's existing criteria.
- Automated tests for success, fallback/error, and compatibility behavior,
  without live model calls or secrets.
- Relevant security, privacy, reliability, and accessibility requirements.
- Actual prerequisite Task IDs and execution order.

Give every behavior a clear owner. Include relevant safeguards, tests, and
documentation in each Task. Keep scopes non-overlapping; do not create routine
substep Tasks, a catch-all safeguards Task, or artificial dependencies.
Use explicit contracts and test doubles where useful. Do not defer deployment
until Story completion.

Preserve these constraints in every Task:
- Read-only and stateless; use current caller-visible synthetic data.
- Application logic retrieves facts; the model cannot invent them.
- Treat questions and ticket text as untrusted input, never instructions.
- Unsupported, ambiguous, malformed, unknown or invisible ticket, and
  unavailable-AI cases get clear, non-fabricated fallbacks without hidden data.
- Do not log ticket content, questions, prompts, or model responses.
- Preserve existing roles and data boundaries. Do not add ticket actions or
  arbitrary queries. Production runtime access uses managed identity and
  least-privilege RBAC. Do not commit secrets, keys, credentials, or connection
  strings.
- Use only existing Part 1 resources when required by the parent Story. Do not
  provision or reconfigure Foundry, enable infrastructure, or change Azure
  resources or RBAC. Keep runtime endpoint and managed-identity access blockers
  separate from code and test completion.

Present the verified scope and identity, Feature, selected Stories, and Task
drafts in parent-to-child order. Explain the demo outcome, exclusions, and
Task boundaries. Map each Task to its parent's existing criteria and verify
that the Tasks collectively fulfill each selected Story. Show backend,
frontend, and agent/prompt ownership and how each Task can be deployed safely.
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
Confirm that backend, frontend, and agent/prompt work are accounted for, and
that completing the Tasks would fulfill each selected Story.

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
[Part 6: Coding Agent Delivery](06-coding-agent-delivery.md). Code and tests do
not verify live runtime endpoint or managed-identity access.
