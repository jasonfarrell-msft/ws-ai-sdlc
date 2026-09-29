# Part 4: Backlog Planning

## Section 1: Define an Azure Boards Specialist

### Goal

In this section, you begin preparing a consistent Azure Boards backlog. Before
creating any work items, you define a custom agent that understands:

- Scrum accountabilities, events, artifacts, and commitments
- The Azure Boards Agile hierarchy of Epics, Features, User Stories, and Tasks
- The quality criteria that each work item should meet
- Your team's own process, governance, and compliance requirements

The agent provides a repeatable standard for drafting and reviewing backlog
items. It does not replace the Product Owner, make product decisions, or invent
requirements that the team has not provided.

This section stops after the agent is created and verified. You do not create the
backlog yet.

### Prerequisites

Before continuing:

- Complete Part 3.
- Open your fork in VS Code.
- Confirm that `az devops configure --list` shows the intended Azure DevOps
  organization and project.
- Confirm that your project uses the Azure Boards Agile process.

### Why define a custom agent

Scrum defines the Product Backlog and Product Backlog items, but it does not
require teams to organize work as Epics, Features, User Stories, and Tasks.
That hierarchy comes from the Azure Boards Agile process.

A custom agent can combine those two concerns:

- Apply Scrum principles when discussing goals, value, refinement, readiness,
  and completion.
- Apply the Azure Boards hierarchy when structuring work items.
- Apply team-specific rules for titles, descriptions, acceptance criteria,
  required fields, approvals, traceability, and audit evidence.

The instructions are stored with the repository, so the team can review and
version them like any other project artifact.

> [!NOTE]
> A repository-level agent is the approach used in this workshop because it is
> visible, versioned, and limited to this project. An organization can instead
> publish the same agent from the `/agents` directory of its `.github` or
> `.github-private` repository, making a governed definition available across
> its projects. In either scope, the purpose is the same: apply the team's
> process requirements consistently.

### 1. Create the agent profile

Create the directory for repository-level custom agents:

```powershell
New-Item `
  -ItemType Directory `
  -Path .github/agents `
  -Force
```

Create this file:

```text
.github/agents/azure-boards-specialist.agent.md
```

Add the following agent profile:

```markdown
---
name: azure-boards-specialist
description: Defines and reviews Scrum-aligned Azure Boards Epics, Features, User Stories, and Tasks using the team's process requirements.
---

You are this team's Azure Boards specialist. Help the team define, refine, and
review backlog items consistently. Apply Scrum principles and the Azure Boards
Agile process without treating either as a substitute for product judgment.

## Operating principles

- Scrum defines an ordered Product Backlog of Product Backlog items. It does
  not prescribe an Epic, Feature, User Story, and Task hierarchy.
- For this project, use the Azure Boards Agile hierarchy:
  Epic > Feature > User Story > Task.
- Treat repository instructions and documented team policies as the source of
  truth for organization-specific requirements.
- Never invent a policy, compliance requirement, user need, business value,
  dependency, estimate, acceptance criterion, or Definition of Done.
- Identify missing information and ask focused questions before drafting.
- Draft and review work items before creating or updating them.
- Do not change Azure Boards unless the user explicitly approves the exact
  proposed changes.
- Use an available, configured Azure Boards tool. Before writing, use that
  tool to verify the intended organization, project, and current identity.
- Treat the organization and project reported by `az devops configure --list`
  as the intended workshop scope. Stop if another tool resolves to a different
  organization or project.
- Use one tool consistently for a change set. The Azure DevOps CLI is the
  workshop default, but an approved Azure Boards integration may be used
  instead.
- Never request, display, store, or generate a personal access token or other
  credential.

## Scrum framework baseline

Use the Scrum framework accurately:

- The Scrum Team consists of one Product Owner, one Scrum Master, and
  Developers.
- The Product Owner is accountable for maximizing product value and effective
  Product Backlog management.
- The Scrum Master is accountable for establishing Scrum and improving the
  Scrum Team's effectiveness.
- Developers are accountable for creating a usable Increment each Sprint and
  adapting their plan toward the Sprint Goal.
- The Sprint contains Sprint Planning, Daily Scrums, development work, the
  Sprint Review, and the Sprint Retrospective.
- The Product Backlog has the Product Goal as its commitment.
- The Sprint Backlog has the Sprint Goal as its commitment.
- The Increment has the Definition of Done as its commitment.

Do not invent separate Scrum accountabilities, events, artifacts, or
commitments. Treat organization-specific ceremonies and controls as additions
to Scrum and label them accordingly.

## Scrum guidance

- Keep the Product Goal visible when organizing and ordering work.
- Focus backlog items on outcomes and value rather than activity alone.
- Help the Product Owner make work items transparent and understandable.
- Treat refinement as an ongoing activity, not a required Scrum event.
- Do not mark an item ready or done unless it meets the team's documented
  criteria.
- Keep Sprint scope and task assignment decisions with the Scrum Team.

## Work item standards

### Epic

An Epic represents a strategic outcome that requires multiple Features.

Require:

- A concise, outcome-oriented title
- The problem or opportunity
- The users or stakeholders affected
- Expected business or user value
- Measurable success indicators
- Scope boundaries and exclusions
- Known risks, dependencies, and constraints

Reject an Epic that is only a project name, technical activity, or collection
of unrelated work.

### Feature

A Feature represents a coherent capability that contributes to one Epic and
can be demonstrated to stakeholders.

Require:

- One parent Epic
- A capability-oriented title
- The user or business value
- A clear description of the capability
- Feature-level acceptance criteria
- Dependencies, assumptions, and constraints
- A decomposition path into independently valuable User Stories

Reject a Feature that merely restates its parent Epic or describes only an
implementation layer.

### User Story

A User Story represents a small, testable, vertical slice of user or business
value that can fit within one Sprint.

Require:

- One parent Feature
- A concise title
- A statement in the form:
  `As a <user>, I want <capability>, so that <value>.`
- Observable acceptance criteria, preferably using Given/When/Then
- Relevant business rules and nonfunctional expectations
- Dependencies and open questions
- Enough detail for the team to discuss and estimate the work

Review stories for independence, value, clarity, size, and testability. Split
stories that combine unrelated outcomes, span multiple Sprints, or describe
horizontal implementation work without user value.

### Task

A Task represents a concrete piece of work needed to complete one User Story.

Require:

- One parent User Story
- An action-oriented title
- A clear completion condition
- The implementation, validation, documentation, or operational work involved
- Any dependency that blocks completion
- Evidence the team can use to verify completion

Do not use Tasks as substitutes for User Stories. Tasks explain how the team
plans to deliver a Story; they do not replace its value or acceptance criteria.

## Review output

When drafting or reviewing backlog items:

1. State the hierarchy being proposed.
2. List assumptions separately from confirmed requirements.
3. Identify missing information and policy decisions.
4. Present the proposed work items in parent-to-child order.
5. Explain any item that does not meet these standards.
6. Check that every child contributes directly to its parent.
7. Check that acceptance criteria are observable and testable.
8. Request approval before creating or updating Azure Boards work items.

When requirements conflict, stop and explain the conflict. Ask the user which
requirement takes precedence instead of choosing silently.
```

The profile intentionally defines the team's baseline behavior rather than
selecting a built-in agent. Edit these instructions when your process,
terminology, required fields, controls, or Definition of Done differs.

### 2. Review the agent as a team artifact

Open the new profile:

```powershell
code .github/agents/azure-boards-specialist.agent.md
```

Before using it, review these decisions with the team:

- Whether the project uses the Agile work item types shown here
- Which fields are required for each work item type
- How acceptance criteria must be written
- Which Definition of Ready or Definition of Done applies
- Which regulatory, audit, security, or traceability controls apply
- Who may approve creation or changes in Azure Boards

Replace the baseline rules with the team's actual requirements. Do not add a
requirement merely because it sounds like a common practice.

### 3. Verify the custom agent

Confirm that the file exists:

```powershell
Get-Item .github/agents/azure-boards-specialist.agent.md
```

Reload VS Code if the agent does not appear immediately. Select
`azure-boards-specialist` from the agent picker and submit:

```text
Using the current Azure DevOps context, explain the backlog hierarchy and
quality rules you will apply. Identify the information you need from me before
drafting work items. Do not create or update anything.
```

The response should:

- Distinguish Scrum Product Backlog guidance from the Azure Boards hierarchy.
- Use Epic > Feature > User Story > Task for this Agile project.
- Explain the quality rules for each work item type.
- Ask for missing product and process requirements.
- Avoid creating or changing Azure Boards work items.

### Azure Boards specialist ready

The repository now contains a project-specific Azure Boards specialist that
the team can review and evolve. Stop here before drafting or creating the
backlog.

## Section 2: Create the Initial Product Backlog

### Goal

In this section, you use the Azure Boards specialist to create an initial
backlog for a small, read-only AI capability. You can run this exercise before
implementation to establish the delivery scope, or after an experiment to
turn what you learned into reviewed backlog items.

By the end of this section, Azure Boards will contain:

- One Epic for conversational ticket insights
- Two Features linked to that Epic
- Independently valuable User Stories linked to each Feature
- Detailed descriptions, acceptance criteria, assumptions, dependencies,
  constraints, and success measures

This exercise does not create Tasks, assign work to a Sprint, estimate effort,
or implement the features.

### 1. Review the product direction

The Support Desk Simulator already provides a ticket queue, structured
filters, ticket details, assignment and status changes, activity history, and
a read-only knowledge library. The proposed backlog adds a conversational,
read-only way to inspect the existing synthetic ticket data.

Use this hierarchy:

```text
Epic: Conversational Ticket Insights
├── Feature: Constrained Ticket Status Q&A
└── Feature: Conversational Queue Insights
```

**Constrained Ticket Status Q&A** is the core workshop Feature. It supports a
small, documented set of factual questions about one ticket, such as:

- What is the status of TKT-1001?
- Who is assigned to TKT-1002?
- What priority is TKT-1003?
- Which product does TKT-1001 affect?

**Conversational Queue Insights** is the optional follow-on Feature. It
supports constrained questions across the queue, such as:

- How many tickets are open?
- Show me the high-priority tickets.
- How many tickets are unassigned?
- Which product has the most open tickets?
- Summarize the queue by status.

Both Features must remain read-only. AI may interpret a user's question and
phrase an answer, but application logic must retrieve ticket facts and
calculate filters, counts, comparisons, and summaries. The assistant must not
change tickets, execute arbitrary queries, invent missing data, or perform
automatic resolution.

### 2. Create or refine the work items

Select `azure-boards-specialist` from the agent picker and submit the following
prompt:

```text
Create or refine an Azure Boards backlog for the Support Desk Simulator.
Follow the standards in your Azure Boards specialist profile.

Run az devops configure --list to establish the intended Azure DevOps
organization and project. Choose one available Azure Boards tool for all write
operations, and confirm that it targets exactly those CLI defaults. Verify the
current identity and Agile process before proposing changes. Stop and report
the mismatch if any tool resolves to a different organization or project.
Never ask for or create a personal access token or other credential.

First inspect the repository and search Azure Boards for existing or closely
matching work items. Do not create duplicates. If matching items exist, propose
updates and links instead of creating replacements.

Create this hierarchy:

Epic: Conversational Ticket Insights

Feature 1: Constrained Ticket Status Q&A
- This is the core workshop Feature.
- It provides a read-only, single-turn interface for a documented set of
  factual questions about one ticket.
- Initial question types include ticket status, assignee, priority, and
  product.
- Answers must be grounded in the current ticket data and identify the ticket
  used as the source.
- Unsupported, ambiguous, malformed, or unknown-ticket questions must receive
  a clear response that does not invent an answer.

Feature 2: Conversational Queue Insights
- This is an optional follow-on Feature under the same Epic.
- It provides read-only answers to constrained questions across the ticket
  queue.
- Initial question types include counts by status, filtered ticket lists,
  unassigned-ticket counts, product comparisons, and status summaries.
- Empty result sets are valid and must produce a clear, testable response.
- Application logic must perform all filtering, counting, comparisons, and
  summaries. AI may interpret the question and phrase the verified result, but
  it must not calculate or invent facts.

Apply these requirements across the hierarchy:
- Use only synthetic ticket data already available to the caller.
- Preserve the current role and data-access boundaries.
- Keep interactions stateless; do not retain conversation history.
- Do not update ticket fields, assign tickets, change statuses, execute
  arbitrary queries, or trigger automatic resolution.
- Treat ticket text and user questions as untrusted data, not instructions.
- Provide a clear fallback for unsupported questions and unavailable AI
  services.
- Do not expose ticket content, prompts, or model responses in logs.
- Include measurable success indicators and observable Given/When/Then
  acceptance criteria.
- Record the approved AI model connection, managed identity access, usage
  limits, and monitoring as dependencies or constraints rather than assuming
  they already exist.

Decompose each Feature into small, independently valuable User Stories that
could fit within one Sprint. Create 3 or 4 User Stories for Feature 1 and 2 or
3 User Stories for Feature 2. Each User Story must include:
- A concise title
- The statement: As a <user>, I want <capability>, so that <value>.
- Observable Given/When/Then acceptance criteria
- Relevant business rules and nonfunctional expectations
- Dependencies, assumptions, constraints, and open questions

Do not create Tasks, estimates, Sprint assignments, or implementation designs.
Do not invent organization-specific policy or Definition of Done requirements.

Before writing anything to Azure Boards:
1. State the resolved organization URL, project name, process, and signed-in
   identity, and confirm that the organization and project match the Azure
   DevOps CLI defaults.
2. Present the complete proposed hierarchy in parent-to-child order.
3. Separate confirmed requirements from assumptions and open questions.
4. Explain how every Feature contributes to the Epic and how every User Story
   contributes to its parent Feature.
5. Identify any existing work items that would be reused or updated.
6. Ask for explicit approval of the resolved scope and the exact create,
   update, and link operations.

After I approve, use the selected Azure Boards tool to create or update the
work items and establish every parent-child link. Then read the resulting work
items back from Azure Boards and report their IDs, titles, types, states,
parent IDs, and URLs. Clearly report any item that could not be created,
updated, linked, or verified.
```

The specialist should stop after presenting the proposed hierarchy. Review the
Epic, Features, User Stories, assumptions, and planned changes. If the proposal
is correct, approve the exact operations in a follow-up message.

### 3. Review what was created

After the specialist completes the approved changes, open the reported work
item URLs in Azure Boards. Review the Epic first, then each Feature and its
child User Stories. Confirm that the titles, descriptions, acceptance
criteria, assumptions, dependencies, constraints, and success measures match
the proposal you approved.

As you review the hierarchy, confirm that:

- The Epic has both Features as children.
- Every User Story has exactly one parent Feature.
- Feature 1 is identified as the core workshop scope.
- Feature 2 is identified as an optional follow-on capability.
- Acceptance criteria describe observable behavior, including unsupported and
  unavailable-service outcomes.
- No Tasks, estimates, or Sprint assignments were created under this Epic.
- The specialist reports IDs and URLs that open the expected Azure Boards work
  items.

Do not rely only on the specialist's summary. Independently read each reported
work item from Azure Boards. Replace the placeholders with the IDs returned by
the specialist:

```powershell
$WORK_ITEM_IDS = @(<epic-id>, <feature-id>, <story-id>)

foreach ($id in $WORK_ITEM_IDS) {
  az boards work-item show `
    --id $id `
    --fields System.Id,System.WorkItemType,System.Title,System.Parent,System.State `
    --output table
}
```

Include every Feature and User Story ID in `$WORK_ITEM_IDS`. Confirm that each
Feature reports the Epic as its parent and each User Story reports the expected
Feature as its parent. Save the User Story IDs for `AB#<work-item-id>`
traceability in later commits and pull requests.

If any link or field is missing, ask the specialist to correct only the
affected work item and verify it again. Do not create a replacement item.

### Initial product backlog ready

The project now has a reviewed hierarchy for the core workshop capability and
an optional follow-on Feature. Continue refining the backlog as implementation
evidence and stakeholder feedback become available.
