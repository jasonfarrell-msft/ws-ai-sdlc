# Part 4: Plan the Product Backlog

Use the Azure Boards specialist included in the repository to propose the
product backlog. Review and approve its proposal before it creates or updates
work items. This part creates no Tasks or Sprints.

## Before you start

- Complete [Part 3](03-azure-devops-setup.md) and open your fork in VS Code.
- This exercise introduces dark mode to the existing application. It requires
  no additional service. Do not change infrastructure for this exercise.

## 1. Open the Azure Boards specialist

Open
[`.github/agents/azure-boards-specialist.agent.md`](../.github/agents/azure-boards-specialist.agent.md)
in any text editor ([Visual Studio Code](https://code.visualstudio.com/) is
recommended) and review it. Select **azure-boards-specialist** in Copilot Chat.

## 2. Draft the product backlog

Submit this prompt to the azure-boards-specialist agent:

```text
Prepare the Support Desk Simulator product backlog using your profile.
Inspect the repository and Azure Boards. Verify the configured organization,
project, Agile process, and authenticated Boards identity. Reuse existing
matching items; do not create duplicates. Do not write anything until I approve
the exact proposal.

Propose this hierarchy:
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
- No application AI integration, provisioning, RBAC changes, secrets,
  new backend endpoints, database, or account-level preference service.
- No system-theme detection, automatic scheduling, cross-device or live
  cross-tab synchronization, custom palettes, or unrelated redesign.
- Do not modify or reparent existing AI backlog items to repurpose them.
  Leave unrelated work untouched and reuse only matching dark-mode items.

Propose the product-facing Stories needed to fulfill this Feature. Do not
assume a fixed Story count. Each Story must be a bounded, acceptable component
with observable acceptance criteria, not a CSS/component/storage implementation
layer. Switching themes and remembering a choice are candidate Story boundaries,
not a mandatory template.

Show how each Story covers Feature criteria and how all Stories together
fulfill the Feature without gaps or duplicate scope. Derive measurable success
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
and Feature-to-Story coverage. Confirm that the Stories cover accessible
switching, all existing views, saved preferences, and storage-unavailable
behavior. If the proposal matches your intent, reply:

```text
Approve the exact proposed operations.
```

After execution, use the returned links to verify that the Feature has the
Epic as its parent and each Story has one Feature parent. Confirm the specialist
read each item and link back, and that existing iteration values were not
changed. Keep the item IDs for Part 5. If execution stops, resolve the reported
problem and ask the specialist to resume with its recorded IDs; do not recreate
items.

Continue to [Part 5: Backlog Task Preparation](05-sprint-planning.md).
