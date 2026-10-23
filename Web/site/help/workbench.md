# Using the settings window

Open the settings window with `/rm config` or by left-clicking the minimap icon. It is called the *workbench*, and every part of Rotation Master is configured here.

## Tabs

| Tab | What it is for |
|---|---|
| **Rotations** | Your rotations: the ordered actions, cooldowns and switch condition of each. See [Rotations and the editor](/help/rotations). |
| **General** | Timing, auto-switching, highlights, the preview window, history and diagnostics. See [General](/help/general). |
| **Conditions** | Condition categories, which conditions appear where, and your custom conditions. See [Conditions](/help/conditions). |
| **Functions** | Reusable Lua helpers for custom conditions. See [Functions](/help/functions). |
| **Effects** | Highlight styles. See [Effects](/help/effects). |
| **Item Sets** | Ordered lists of alternative items. See [Item sets](/help/item-sets). |
| **Announces** | Chat messages, emotes and sounds on casts. See [Announcements](/help/announcements). |
| **Profiles** | Separate sets of settings. See [Profiles](/help/profiles). |
| **Integrations** | Optional addons RM can work with. See [Integrations](/help/integrations). |

Most tabs have a searchable list on the left and the selected entry's details on the right. Built In entries are read-only; **Duplicate** gives you an editable copy.

## Drafts: Apply and Discard

Almost everything you change is kept in a **draft** until you choose **Apply**.

- **Apply** saves the draft.
- **Discard** throws the draft away and restores the saved version.
- **Undo** and **Redo** step through your recent edits in the draft.
- **View Changes** (where offered) compares the saved and unsaved versions.

If you try to leave a page with unsaved changes, RM asks whether to **Apply**, **Discard** or **Cancel** (stay where you are). Invalid fields are shown in red and must be fixed, or discarded, before you can apply.

Text fields commit their value to the draft when you press **Enter** or click elsewhere. **Escape** restores the field's last committed text.

> **Warning:** Drafts survive closing the window, but not a `/reload` or logging out. Apply before you reload.

A few things happen immediately instead of waiting for Apply, because they are actions rather than settings: activating a profile, confirming a profile copy or reset, binding an item set to your action bar, and diagnostic captures.

## Help and tips

- A gold **?** opens full help for its window, page or card.
- Hovering over a control shows a short tip. Spell and item fields keep the game's normal tooltips.
- Opening help never applies or discards anything.

## Scale and window controls

- **Scale** (the slider at the top left) resizes the whole workbench and its child windows, from 70% to 130%. Drag the slider or type a percentage and press Enter.
- Drag the title bar to move the window; drag the lower-right corner to resize it.
- Close the frontmost RM window with **X**, **Escape** or a right-click inside it.
- The language selector changes the workbench language. Project links open a copyable address.

## Lists, cards and dragging

Lists of things (actions, conditions, items, sequence steps, announcement outputs) work the same way everywhere:

- **Drag** a card into a highlighted gap to move it. Hold **Ctrl** when you start the drag to carry that card *and everything after it*.
- **Up / Down** arrows on the left move one card at a time.
- **Duplicate** copies a card; the red **trash can** deletes it.
- **Add** buttons append to the end when clicked, or insert where you drop them when dragged.
