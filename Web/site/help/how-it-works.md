# How recommendations work

Rotation Master answers one question over and over: *what is the best thing to press right now?* Understanding how it answers makes everything else easy.

## The short version

```diagram
Every polling interval (0.15 s by default):

  Which rotation is active?  (switch conditions
                              or your manual choice)
             │
             ▼
  Walk the ordered actions from the top:
     card's conditions match?  ── no ──► next card
             │ yes
     action actually usable?   ── no ──► next card
             │ yes
             ▼
     HIGHLIGHT this one, stop looking
  (nothing qualified? → implicit Attack, if it applies)

  Separately, every cooldown card is checked on its own
  and highlights whenever its own conditions match.
```

## Priority order

The ordered actions in a rotation are a **priority list**, not a script. RM does not remember where it was last time; it starts from the top on every check. The first card that qualifies wins, and only **one** main recommendation is shown at a time.

So put the most important things first. A rarely-ready, high-value ability near the top costs nothing when it is not ready: RM simply moves on to the next card.

## What RM checks for you

You do not need conditions for the basics. Every action automatically requires:

- a spell you have **learned**, or an item you are **carrying** (or wearing, for items with a Use effect),
- enough **resources** (mana, rage, energy and so on) to use it,
- the action being **ready** (off cooldown),
- the target being **in range**.

Conditions are for everything else: buffs and debuffs, health, the number of enemies nearby, whether you are moving, and so on. A condition can also test *another* action, such as "only if that other spell is on cooldown".

> **Note:** The highlight appears on action bar buttons, so the action must be on one of your bars to be highlighted there. The optional preview window shows the icons even if they are not.

## The implicit Attack

When no ordered action qualifies, RM can still suggest your weapon **Attack** as a final fallback. It does this only when you are in melee combat with a living hostile target and auto-attack is not already running. It uses the normal rotation highlight and, like everything else, never presses a button.

A [Stop card](/help/stop-and-branch#stop) can switch this off for casters who should not be meleeing.

## Cooldowns are separate

[Cooldown cards](/help/cooldowns) are not part of the priority list. Each one is checked on its own and can highlight at the same time as the main recommendation and as other cooldowns. Use them for reminders: a defensive ability when your health is low, a potion, a missing buff.

## Unknown is not "no"

Sometimes the game does not give RM the information a condition needs: an unreadable aura, a unit that does not exist, data the client restricts. RM treats that as **unavailable**, not as false. An unavailable condition does not match, and putting it inside **Not** does not turn it into a match. This keeps RM from recommending something because it could not see the reason not to.

## Updating efficiently

RM re-checks every **Polling Interval** (0.15 seconds by default). Out of combat, with no target or focus, it skips checks when nothing it watches has changed, and still re-checks at least every **Idle Re-check Interval** (1 second by default) for time-based conditions. Both are in [General](/help/general#timing).
