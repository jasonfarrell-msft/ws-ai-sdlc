# Part 4: Plan the Product Backlog

Describe the change you want to add to the application. The Azure Boards
specialist proposes the breakdown, reusing suitable Epics and Features,
creating missing items, and adding or refining Stories where needed.
Review and approve its proposal before it creates or updates work items.
This part creates no Tasks or Sprints.

## Before you start

- Complete [Part 3](03-azure-devops-setup.md) and open your fork in VS Code.
- This exercise plans dark mode and a second accessibility Feature under one
  Epic. Neither requires an additional service. Do not change infrastructure.
  Only dark mode continues into the implementation exercise in Parts 5-6.

## 1. Open the Azure Boards specialist

Open
[`.github/agents/azure-boards-specialist.agent.md`](../.github/agents/azure-boards-specialist.agent.md)
in any text editor ([Visual Studio Code](https://code.visualstudio.com/) is
recommended) and review it. Select **azure-boards-specialist** in Copilot Chat.

## 2. Draft the product backlog

Provide the feature, its value, and the behavior you expect. The specialist's
profile already defines the hierarchy, decomposition rules, approval process,
and verification steps; you do not need to repeat them in each request.

Submit this feature brief to the azure-boards-specialist agent:

```text
Umbrella outcome: A comfortable, accessible support-desk experience.

Feature: Accessible Dark Mode
I want to add light/dark theme switching to the Support Desk Simulator.

Value:
Let users choose a comfortable appearance while continuing their existing
support workflows without interruption.

Expectations:
- A labeled, keyboard-operable toggle exposes the selected theme to assistive
  technology. Switching needs no reload and preserves filters, selected
  tickets, and draft input across views.
- Both themes cover the whole application, including navigation, ticket
  queue/detail, creation, knowledge library, demo banner, and empty,
  validation, notification, and error states. Preserve responsive layouts,
  visible focus, and recognizable hover, selected, disabled, status, and
  priority states; do not rely on color alone.
- Meet WCAG AA contrast: 4.5:1 for normal text, 3:1 for large text and required
  control boundaries and state/focus indicators.
- Default to light when no valid preference exists. Remember only the theme
  in the same browser across reloads and visits, isolated from other users.
  If saving is unavailable, switching still works for the interactive session
  with accessible, non-blocking feedback that the choice cannot be saved.
- Preserve existing workflows, role/data boundaries, and API behavior.
  Keep scope to switching and remembering light/dark: no automatic switching,
  synchronization, custom palettes, account settings, redesign, or extra services.
```

## 3. Review and approve the proposal

Check the hierarchy, Story scope, measurable criteria, reuse of existing items,
and Feature-to-Story coverage. Confirm that the Stories cover accessible
switching, all existing views, saved preferences, and storage-unavailable
behavior. If the proposal matches your intent, reply:

```text
Approve the exact proposed operations.
```

After execution, use the returned links to verify that each affected Feature
has one Epic parent and each Story has one Feature parent. Confirm the specialist
read each item and link back, and that existing iteration values were not
changed. Keep the returned Epic ID for the next request and the dark-mode
Feature and Story IDs for Part 5. If execution stops, resolve the reported
problem and ask the specialist to resume with its recorded IDs; do not recreate
items.

## 4. Add a second Feature under the same Epic

After the first proposal is approved and verified, describe another capability
that contributes to the same outcome. Replace `<EPIC_ID>` below with the actual
Epic ID returned by the first run; do not create a second Epic.

The baseline already has form labels, validation messages, and status feedback.
The specialist should inspect them and identify unmet expectations rather than
assume they are missing. Keep accessibility work distinct from the theme
contrast, toggle, and persistence work already covered by dark mode.

```text
Under existing Epic AB#<EPIC_ID>:

Feature: Accessible Ticket Creation
I want requesters using a keyboard or screen reader to create a support ticket
and recover from input errors independently.

Value:
Make the requester workflow usable without a mouse or visual-only feedback,
reducing barriers to asking for support.

Expectations:
- Open, complete, submit, and cancel ticket creation using only the keyboard,
  with logical focus order, visible focus, and no keyboard traps.
- Give every field an accessible name and expose required-field instructions
  and invalid states to assistive technology.
- On invalid submission, preserve entered values, make errors discoverable
  through focus and screen-reader feedback, and associate each error with its
  field so the requester can correct it and resubmit.
- Communicate successful creation or submission failure accessibly without
  requiring the requester to find a visual-only notification.
- Build on existing accessibility behavior. Preserve ticket validation,
  role/data boundaries, API behavior, and both supported theme appearances.
  No dark-mode scope changes, application-wide accessibility audit, new
  services, or redesign.
```

Review and approve this proposal separately using Section 3's approval step.
Verify that the second Feature has the same Epic parent, its Stories describe
unmet requester needs, and the dark-mode backlog remains unchanged. If these
expectations are already satisfied, have the specialist report that evidence
instead of inventing implementation work.

Keep this second Feature in the product backlog. Parts 5-6 continue with only
the dark-mode Feature and its Stories so the walkthrough stays time-boxed.

Continue to [Part 5: Backlog Task Preparation](05-sprint-planning.md).
