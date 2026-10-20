# Part 4: Plan the Product Backlog

Use the Azure Boards specialist included in the repository to propose the
product backlog. Review and approve its proposal before it creates or updates
work items. This part creates no Tasks or Sprints.

## Before you start

- Complete [Part 3](03-azure-devops-setup.md) and open your fork in VS Code.
- Confirm that Part 1 created Microsoft Foundry, `support-sim-project`, and
  `gpt-5.4-mini`. If a resource is missing, stop and resolve Part 1; do not add
  provisioning work to the backlog.

## 1. Open the Azure Boards specialist

Open
[`.github/agents/azure-boards-specialist.agent.md`](../.github/agents/azure-boards-specialist.agent.md) in any text editor ([Visual Studio Code](https://code.visualstudio.com/)
is recommended) and review it.

## 2. Draft the product backlog

Submit this prompt to the azure-boards-specialist agent:

```text
Prepare the Support Desk Simulator product backlog using your profile.
Inspect the repository and Azure Boards. Verify the configured organization,
project, Agile process, and authenticated Boards identity. Reuse existing
matching items; do not create duplicates. Do not write anything until I approve
the exact proposal.

Propose this hierarchy:
- Epic: Conversational Ticket Insights
- Core Feature: Constrained Ticket Status Q&A
- Optional Feature: Conversational Queue Insights

The core Feature answers read-only, single-turn questions about the status,
assignee, priority, or product of one explicitly identified ticket. The
complete experience includes an accessible interaction in the existing
application, a grounded answer, its source ticket, and a clear fallback.

The optional Feature answers constrained questions across the queue, such as
counts by status, filtered lists, unassigned counts, product comparisons, and
status summaries. Application logic calculates the results; empty results
receive a clear response. Keep this Feature outside the later coding exercise.

Use only synthetic data and preserve existing caller roles and data-access
rules. Keep requests stateless. Do not add conversation history, ticket
mutations, arbitrary queries, automatic resolution, or hosted-agent
provisioning. Application logic retrieves facts; the model must not invent
them. Treat questions and ticket text as untrusted input. Provide clear
fallbacks for unsupported, ambiguous, malformed, unknown-ticket, and
unavailable-AI cases. Do not log ticket content, questions, prompts, or model
responses.

Use only the existing Part 1 Foundry resource, support-sim-project, and
gpt-5.4-mini. Do not add provisioning work or change Azure resources or RBAC.
Record unresolved runtime endpoint, managed-identity access, usage limits, and
monitoring as dependencies; do not invent thresholds, keys, or connection
strings.

Propose the product-facing Stories needed to fulfill each Feature. Do not
assume a fixed Story count. Each Story must be a bounded, acceptable component
with observable acceptance criteria. For the core Feature, make the
application interaction, grounded answer, source, and fallback requirements
explicit and covered. Do not treat an API-only capability as an application
interaction or prescribe a particular hosted-agent architecture.

Show how each Story covers Feature criteria and how all Stories together
fulfill each Feature without gaps or duplicate scope. Derive measurable success
indicators from these requirements. Do not invent requirements or rewrite
existing approved criteria. No Tasks, implementation designs, estimates,
assignments, or Sprint setup.

List existing items to reuse and the exact create, field-update, and Parent-link
operations. Keep assumptions, open questions, dependencies, and execution
order brief. Ask for one explicit approval. After approval, perform only the
approved operations, read each item and link back for verification, leave
iteration values unchanged, and report IDs and URLs using your profile's
verification rules.
```

## 3. Review and approve the proposal

Check the hierarchy, Story scope, measurable criteria, reuse of existing items,
and Feature-to-Story coverage. Confirm that the core Stories include the
accessible application interaction, grounded answer, source, and fallbacks.
If the proposal matches your intent, reply:

```text
Approve the exact proposed operations.
```

After execution, use the returned links to verify that each Feature has the
Epic as its parent and each Story has one Feature parent. Confirm the specialist
read each item and link back, and that existing iteration values were not
changed. Keep the item IDs for Part 5. If execution stops, resolve the reported
problem and ask the specialist to resume with its recorded IDs; do not recreate
items.

Continue to [Part 5: Backlog Task Preparation](05-sprint-planning.md).
