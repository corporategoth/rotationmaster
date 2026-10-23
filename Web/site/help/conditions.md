# Conditions

Conditions decide *when*: when a card in a rotation may be used, when a cooldown reminder shows, when a rotation is switched to, when a branch takes its True arm, and when an announcement is sent. They all use the same condition editor.

## The condition editor

Click the condition text on any card to open it. A condition is a tree of cards:

```diagram
All of
 ├─ In Combat                (player)
 ├─ Debuff Present  — Unless (target, Corruption, mine)
 └─ Any of
     ├─ Health Percentage    (target) < 20%
     └─ Have Item Equipped   (Some Trinket)
```

reads as: *in combat, and the target does not have my Corruption, and either the target is below 20% health or I have the trinket equipped.*

### Building the tree

- **Add condition** and **Add group** append to the end when clicked, or insert where you drop them when dragged.
- Click a card's condition type to search for a type or browse by category. Choosing the same type again keeps its fields.
- Click a card's summary to edit its fields. Many conditions take a **unit**: player, target, focus, pet and so on.
- The chevron switches a card between name only and summary; the double chevron closes the fields.

### Groups

| Control | Meaning |
|---|---|
| **All** (AND) | Every child must match. An empty All group always matches. |
| **Any** (OR) | At least one child must match. An empty Any group never matches. |
| **If / Unless** | Unless negates a card or group ("not"). |
| **Enabled / Disabled** | A disabled card keeps its settings but is skipped. |

Ctrl-click or Shift-click to select several cards, then group them with All or Any. **Split group** removes a group's wrapper and keeps its children. Click a group's name to rename it; the branch icon folds its children away. Undo and Redo work on the whole tree until you Apply.

### Live status

While you edit, RM can show whether each condition is **currently satisfied**, refreshed every **Live Status Update Frequency** seconds ([General](/help/general#timing)). Cards that cannot be evaluated for your current specialization are marked as such.

## When the game cannot answer

Some information is not always available: an aura the client will not identify, a unit that does not exist, data a game edition restricts. RM calls this **unavailable**. An unavailable condition does not match, and wrapping it in **Unless** / **Not** does not make it match either. This deliberately errs on the side of not recommending.

## Buff and debuff ranks

Buff and debuff conditions match the exact spell you picked. Tick **Match all ranks** to also match other ranks of the same spell (by its localized name). Use exact IDs when two different spells share a name.

## Managing conditions

The **Conditions** tab controls which condition types appear where, and holds your custom conditions.

- The list can be narrowed to **All**, **Built In** or **Custom** types, and filtered by **Switch**, **Other** or a named category. Search finds a type by name or identifier.
- **Switch Condition** — offer this type in [switch conditions](/help/switching).
- **Announcement** — offer this type in [announcement](/help/announcements) conditions.
- **Hidden** — remove the type from the *Other* picker category. Explicit category and Switch membership still work, and existing uses are not affected.
- **Move To** — choose a named category (or Other) and use the Apply beside it to stage the move; the page's Apply saves it.
- The arrows and dragging in the sidebar set the order within a category.

### Categories

**Manage categories** (below the list) lets you add, rename, reorder and delete categories. Built-in categories cannot be renamed or deleted. Deleting a category moves its conditions to *Other*; nothing is lost. You can export a category's list of condition identifiers to share it.

See [Condition types](/help/conditions-reference) for every built-in type and its default category.

## Custom conditions

If no built-in type does what you need, you can write your own in Lua.

> **Warning:** Custom conditions are Lua code that runs inside your game. Only write or import code you understand and trust.

Choose **Add** on the Conditions tab, or select an existing custom condition. Its editor has:

- an **identifier** (stable once saved), a **description** (the name shown in pickers) and an **icon**,
- a **category** and the same Switch / Announcement / Hidden options as built-in types,
- **Fields**: the values the condition stores, edited graphically or as text, for example

  ```lua
  { spell = { string, number }, unit = string, checks = condition[] }
  ```

  Supported field types are `string`, `number`, `boolean`, `condition` and `condition[]`; named tables are records and ordered tables are alternatives. Fields can be marked **Required**.
- the Lua **callbacks**, each on its own tab:

| Callback | Arguments | Purpose |
|---|---|---|
| **Evaluate** | `value, cache, evalStart` | Return true when the condition matches right now. |
| **Validate** | `spec, value` | Return true when the stored values are complete and valid. |
| **Summary** | `spec, value` | Return readable text describing the condition. |
| **Fields UI** | `parent, spec, value` | Add controls for editing the condition. |
| **Help** | `frame` | Add help content shown from the condition's **?** icon. |
| **On register** / **On unregister** | `tag` | Set up or release resources. |

`addon` and `L` are available in every callback. Each callback lists its arguments and return values above the code. Helper functions from the [Functions](/help/functions) tab can be used by recording them as dependencies.

**Check syntax** compiles the code without running it. **Apply** validates the whole definition and only then registers and saves it; if registration fails, the previous version stays in place and the error is listed in `/rm errors`. Each callback can be up to 64 KiB (256 KiB in total).

Importing a custom condition asks you to confirm that you trust it, and opens it as a draft: nothing is registered until you Apply. Export bundles can include the custom functions a condition depends on; see [Importing, exporting and sharing](/help/sharing).
