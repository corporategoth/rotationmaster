# Switch conditions and auto-switching

You can have many rotations: one for solo play, one for groups, one for each form or stance, one for AoE. RM can choose between them by itself.

## Switch conditions

Each rotation can have a **switch condition**, shown just below the editor header. It is an ordinary [condition tree](/help/conditions), but it answers a different question: *should this rotation be the active one?*

Only some condition types make sense for that, so the switch condition editor offers the ones marked as **Switch Condition** on the [Conditions](/help/conditions#managing-conditions) tab, such as level, group, form, class, zone, instance, PvP state, pet, nearby enemy count and threat. You can change which types are offered there.

## How RM picks a rotation

When automatic switching is on, RM goes through your enabled rotations in order and picks the first one whose switch condition matches:

1. Your **custom** rotations first. A higher **Switch priority** (set in Metadata, from -100000 to 100000; blank means 0) is tried earlier. Equal priorities are ordered by name, then by a stable identifier, so the choice never depends on chance.
2. Then **Built In** rotations, in the same way, but only if you do not have a usable **fallback rotation** of your own. A Built In rotation never displaces your saved fallback.
3. If nothing matches, the **fallback rotation** is used. It has no switch condition of its own.

Disabled rotations, rotations with invalid conditions and Built In rotations that do not apply to your class or level are skipped.

```diagram
 custom rotations, highest priority first ── match? ──► use it
          │ none
          ▼
 your fallback rotation is usable? ── yes ──► use it
          │ no
          ▼
 Built In rotations for your class/level ── match? ──► use it
```

## When RM re-checks

- Every **Auto-Switch Re-check Interval** (about once a second by default), in and out of combat, so conditions that change on their own (enemies nearby, threat, moving, health) take effect.
- **Immediately** when your target, focus or pet changes.

Set the interval on the [General](/help/general#timing) tab. Setting it to **0** turns automatic switching off.

## Choosing a rotation yourself

You can always pick a rotation by hand, from the minimap icon's right-click menu or with:

```text
/rm set My Rotation Name
```

A manually chosen rotation **holds**: automatic switching stays out of the way until you choose automatic selection again, with the minimap menu or:

```text
/rm set auto
```

RM remembers a manual choice for that character, specialization and action context. `/rm current` tells you which rotation is active.

> **Tip:** If two rotations have the same name, `/rm set` cannot tell them apart; pick the right one in the rotation browser, or rename one.

## Troubleshooting switching

- *"No rotation is active as there is none suitable to automatically switch to."* No rotation matched and there is no usable fallback. Give one rotation no switch condition, or fix the fallback.
- A rotation never gets picked: check that it is enabled, that its switch condition is valid (no red warning), and whether a custom rotation with a higher priority also matches.
- Switching seems slow: lower the re-check interval, or remember that target, focus and pet changes are already immediate.
