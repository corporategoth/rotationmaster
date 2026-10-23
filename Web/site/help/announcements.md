# Announcements

The **Announces** tab sends a message, emote or sound when you cast a spell or use an item, or when a macro asks it to. Announcements are separate from your rotation: they never cast anything, and they work whichever rotation is active.

## Triggers

Each announcement has one trigger:

| Trigger | Watches for |
|---|---|
| **Spell** | One of your spells. Untick the exact-rank option to include every rank you know. |
| **Pet Spell** | A spell from your pet's spellbook. |
| **Item** | Use of any item in an [item set](/help/item-sets), or in a custom list. |
| **Via Script/Macro** | Nothing automatic: it runs when a macro or script calls it by its **Identifier**. |

For Spell, Pet Spell and Item, choose which **event** triggers it:

| Event | Meaning |
|---|---|
| Started | The cast or channel began (it may still fail). |
| Stopped | The cast or channel stopped, successfully or not. |
| Succeeded | The game reported a successful cast. For a channel, this can be when it begins. |
| Interrupted | The cast was interrupted, including cancelling it yourself. |
| Failed | The cast failed. |
| Delayed | The cast was pushed back. |

## Outputs

An announcement has one or more **output** cards, all fired by the same trigger. Each output has its own destination, conditions and on/off pill. Add, duplicate, reorder or delete outputs like any other cards.

Destinations:

| Destination | Where it goes |
|---|---|
| **Raid or Party** | Raid chat in a raid, party chat in a party, your own chat frame when solo. |
| **Party** | Party chat (your party, even inside a raid). Nothing when solo. |
| **Raid Warning** | Raid warning when allowed; otherwise raid, party or local chat. |
| **Emote** | A named emote such as `/cheer`, optionally at the spell's recipient. |
| **Local** | Your own chat frame. Nobody else sees it. |
| **Audible** | Plays a sound locally (no chat). Choose a sound and press **Play** to preview. |
| **Say**, **Yell**, **Whisper**, a joined **channel** | Only for Via Script/Macro announcements, and still subject to the game's chat restrictions. |

### Message text

For chat destinations, write the message. These substitutions are filled in when available:

| Placeholder | Becomes |
|---|---|
| `{{spell}}` | A link to the spell. |
| `{{item}}` | A link to the item. |
| `{{target}}` | Who the cast was aimed at (recorded for that exact cast). It is never simply your current target. |
| `{{event}}` | The event name, or *Via Script/Macro*. |

Example: `Casting {{spell}} on {{target}}!`

## Conditions

Each output can have a condition tree, built with the normal [condition editor](/help/conditions). For automatic triggers it is checked after a matching cast; only a match lets that output speak. The **In Group** condition can check the **Spell recipient**, the unit the cast was aimed at.

Which condition types are offered here is set with the **Announcement** option on the [Conditions](/help/conditions#managing-conditions) tab.

## From a macro

A Via Script/Macro announcement runs when you call it with its Identifier:

```text
/run RM_Announce('FOO', 'mouseover')
```

The second argument is the unit used for `{{target}}`, whispers and conditions; if you leave it out, RM never guesses your current target instead. An optional third argument gives a spell (by ID or name) for `{{spell}}`. If something the message needs is missing, that output is skipped. (The older spelling `RM_Annouce` also works.)

## Saving and sharing

Edits stay in a draft until **Apply**. **New**, **Duplicate**, **Import/Export** and **Compare** are below the list; duplicating a Via Script/Macro announcement gives it a different identifier. The red trash deletes the selected announcement after confirmation.

> **Note:** Cast-triggered announcements depend on the game edition providing cast information; see [Game editions](/help/editions).
