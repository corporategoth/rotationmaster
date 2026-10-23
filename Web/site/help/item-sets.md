# Item sets

An **item set** is an ordered list of alternatives, such as the different mana potions or bandages you might be carrying. It lets one action, one cooldown or one action bar button stand for "the best one of these I have".

## How RM chooses an item

RM looks down the list from the top and uses the **first item you are carrying** (or wearing, where the action asks for equipped items). Priority comes only from the order you choose, not from item level.

```diagram
Item set "Healing potions"
 1. Super Healing Potion   ← not in bags, skipped
 2. Major Healing Potion   ← in bags: this is the one
 3. Superior Healing Potion
```

Choosing an item this way does not mean it can be used right now: the action still has to be ready, off cooldown and in range like any other.

> **Note:** RM does **not** count your items or restock them. An item set simply says which item to use first; how many you carry is up to you.

If RM cannot read your bags or an item's details yet (for example right after logging in), it waits rather than skipping ahead to a lower item on the list.

## Editing a set

- **Name** — used in the list and when you pick the set in a rotation or condition. New sets are saved empty when you first Apply the name; then add items and Apply again.
- **Global** — when ticked, the set is shared by every profile and character. Otherwise it belongs to the current profile. A profile set wins if both exist with the same identity.
- **Items** — search for an item by name, or drag it from your bags or action bar into the empty field, then choose **Add item** (or drag **Add item** into a gap to insert it). Edit a row to replace that item; use its red trash can to remove it.
- **Order** — use the arrows on the left, or drag a row into a gap. **Ctrl**-drag moves that row and everything after it.
- **Reset** — for sets that ship with the addon, restores the original list.
- **Undo / Redo** cover additions, removals, replacements and reordering until you Apply or Discard.

The list's icon is the first item in the list, not necessarily the one being used.

## Using a set

- In a rotation or cooldown, choose the **Item** action type, then pick the set by name. Or choose **Custom** to make a list that belongs only to that card.
- Conditions about items can use a set too.
- [Announcements](/help/announcements) can watch for any item in a set being used.

Editing a named set changes it everywhere it is used, including on your other characters if it is global.

## Binding a set to your action bar

You can put an item set on an action bar slot. RM keeps that slot filled with the first available item of the set as your bags change, so one button always uses the right potion.

- Out of combat, Apply any pending edits first.
- Drag the set (its row in the list, or the **Bind** pill) onto any action bar slot. If the slot is occupied, its previous action is put on your cursor.
- Or click **Bind**, then click an empty slot.
- The pill shows the slot numbers the set is bound to. Click it to unbind; RM removes the set's items from those slots.

Binding is an immediate action-bar change. It is not part of the draft and Undo does not reverse it.

## Macros

On some game editions you can also trigger a set from a macro with `/click`. The button name is `RM_`, then the set's name with spaces and symbols removed, then `_` and a unit:

```text
/click [@mouseover,nodead,help] RM_Bandages_mouseover
```

Other unit endings are `player`, `pet`, `target`, `focus`, `pettarget`, `targettarget`, `focustarget` and `mouseovertarget`. These buttons do not get RM's readiness checks, and some clients restrict them.

## Deleting

The red trash at the top right permanently deletes the selected set after confirmation. Rotations or conditions that used it will then need another set. Bound action bar slots are cleaned up.
