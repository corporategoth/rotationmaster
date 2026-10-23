# Rotations and the editor

A **rotation** is what RM follows to choose a recommendation. Each one has:

- a list of **ordered actions** (the priority list),
- a set of independent **cooldowns**,
- an optional **switch condition** that says when RM should pick this rotation automatically,
- a name and optional **metadata**: a description, tags, author details and a switch priority.

Open `/rm config`; the **Rotations** tab is the first one.

## The roster

The list on the left shows the rotations available to your character.

- **Built In** rotations come with the addon and are shown in blue. They are read-only: you can enable or disable them and inspect every card and condition, but to change one, choose **Duplicate**. The copy is independent, and remembers which Built In rotation it came from so you can compare them later.
- **Custom** rotations are yours.

Use the search box to find a rotation by name, description, tags, author details or source; the tag filter and the All / Built In / Custom filter narrow the list further. Filters never discard what you are editing.

Below the roster are **New rotation**, **Duplicate**, **Import/Export** and **Compare rotations**.

### Who a rotation belongs to

Rotations belong to the active [profile](/help/profiles). Inside it, a new rotation belongs to your **Class** (shared by all your characters of that class) unless you change it to **This character** in Metadata. Built In rotations appear only for the class they declare, or for every class if they are universal.

Older rotations saved before RM recorded an owner are kept in an archive. **Recover unassigned rotations** lets you inspect them and adopt one for your class or your character.

## The editor header

- **Name** — click to rename.
- **Metadata** — opens a form with a longer **description**, **tags**, **switch priority** and optional **Author**, **Realm**, **Email**, **Website** and **Version**. Choose **Use changes** to put them in the draft; the rotation's **Apply** saves them. RM never fills in contact details by itself.
- **Enabled / Disabled** — a disabled rotation is never selected.
- **Delete** — permanently deletes a custom rotation after confirmation. Built In rotations and the fallback rotation cannot be deleted.
- **Undo / Redo / Apply / Discard** — see [drafts](/help/workbench#drafts-apply-and-discard).

### Tags

Tags are your own labels, such as `AOE`, `PvP`, `Raid` or `Leveling`. Type them comma-separated; put a tag containing a comma in double quotes. Up to 64 tags of up to 64 characters each. Tags help you search and filter; they never change what RM recommends.

## Switch condition

Just below the header is the rotation's **switch condition**. Click its text to edit the condition tree; click the heading to hide or show the summary. See [Switch conditions and auto-switching](/help/switching).

## Rotation and Cooldowns

Two tabs under the switch condition choose what you are editing:

- **Rotation** — the ordered priority list. Order matters: RM uses the first card that qualifies.
- **Cooldowns** — independent reminders in a grid. Order does not matter. See [Cooldowns](/help/cooldowns).

## Views: Diagram and List

- **Diagram** draws the rotation as connected cards, with branches side by side. Scroll the mouse wheel to zoom (25% to 200%), drag empty space to pan, and click the percentage or middle-click to go back to 100%.
- **List** shows the cards stacked, with branch arms boxed (False before True) and normal scrollbars.

The view you start in is set in [General](/help/general#rotation-view). Dragging cards works in both views.

## Action cards

Choose **Add action** to append a card, or drag the **Add action** button into a gap to insert it there.

Each card has:

- a **name** — click to rename. Clear a custom name to go back to the action's own name.
- an **action** — click the action text to open its fields.
- **conditions** — click the condition text to say when this card may be used. See [Conditions](/help/conditions).
- an **Enabled / Disabled** pill — a disabled card keeps its settings but is skipped.

The chevron switches a card between showing its summary and its name only; the double chevron closes open fields. **Expand all** and **Collapse all** do this for every card.

### Action types

| Type | Use it for |
|---|---|
| **Spell** | A spell from your spellbook. Type its name, or drag it from your spellbook or action bar into the field. |
| **Pet Spell** | A spell from your pet's spellbook. |
| **Any Spell** | A spell chosen from all spells, not only your current spellbook. |
| **Item** | An item with a Use effect, from an [item set](/help/item-sets) or a custom list made just for this card. |
| **Stop** | Ends the priority list here. See [Stop and Branch cards](/help/stop-and-branch#stop). |

On editions with spell ranks, **Use this exact spell rank** restricts the card to the rank you picked; otherwise any rank you know counts.

Remember that RM already checks that the action is learned or carried, affordable, ready and in range; see [How recommendations work](/help/how-it-works#what-rm-checks-for-you). Hover a spell's icon for its tooltip; Shift-click the action to link the spell in chat.

### Branches

**Add branch** inserts a decision point with a True arm and a False arm. See [Stop and Branch cards](/help/stop-and-branch#branch).

## Moving and copying cards

- Drag a card into a highlighted gap. Hold **Ctrl** as you start dragging to carry the card and every card after it.
- Dragging a card into a branch arm carries the rest of its sequence with it, including nested branches.
- **Up / Down** move one card (and its own branch, if it is one).
- **Duplicate** copies a card; the red trash can deletes it (Undo brings it back while the draft is open).

## Saving and validation

**Apply** checks the whole rotation, including branch arms that cannot currently be reached, and never runs custom condition code to do it. Cards that are incomplete or invalid get a red border and stay editable. If a rotation cannot run, a warning above the switch condition says why; click it for details.

A rotation can hold up to 2,000 steps, with branches nested up to 16 deep.

## Comparing rotations

**Compare rotations** shows two rotations side by side, including name, tag and priority changes. It is read-only: nothing is merged. It is especially useful for checking what changed between your copy and the Built In rotation it came from.
