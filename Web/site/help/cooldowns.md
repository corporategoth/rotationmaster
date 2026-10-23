# Cooldowns

**Cooldowns** are reminders that live beside the priority list rather than in it. Use them for things that can be used at any moment but are not part of your normal sequence: a long offensive cooldown, a defensive ability when your health drops, a health or mana potion, a missing buff.

## How they differ from ordered actions

| | Ordered actions | Cooldowns |
|---|---|---|
| Order matters | Yes: the first match wins | No |
| How many highlight at once | One | Any number, including none or all |
| Affected by Stop and Branch | Yes | No, they are always checked |
| Highlight style | The profile default | The profile default, or their own |

Like actions, a cooldown highlights only when its own conditions match *and* the action is learned or carried, affordable, ready and in range.

## Adding and arranging

Open a rotation on the [Rotations](/help/rotations) tab and switch to **Cooldowns**. The cards are in a grid.

- **Add cooldown** creates a new reminder; drag it into a gap to place it somewhere specific.
- Cooldowns have no Up/Down arrows, because their position means nothing. You can still drag them to tidy up.
- Each card's heading can collapse it to one row. **Expand all** and **Collapse all** work on every card.

## Highlight settings

Click a cooldown's action to open its fields. Besides the action itself (Spell, Pet Spell, Any Spell or Item; there is no Stop), a cooldown has its own highlight settings:

- **Effect** — any style from the [Effects](/help/effects) tab.
- **Magnification** — size relative to the action icon.
- **Color** — opens a colour picker with a live preview, or type RGBA values between 0 and 1.
- **Position** — the arrow pad moves the highlight (hold **Shift** for 10 pixels); **Center** resets it.
- **Sound** — play a sound from the shared media library; **Play** previews it.

Leave a setting blank, or choose **Default**, to use the profile's setting from [General](/help/general#highlight-style). The icon at the front of the card previews the effect live.

## Conditions

Click the condition text to choose when the reminder applies, exactly as for ordered actions. See [Conditions](/help/conditions).

```diagram
Cooldown: Healing Potion    if my health < 35%
Cooldown: Evocation         if mana < 20% and not moving
Cooldown: Arcane Intellect  if I lack Arcane Intellect
```
