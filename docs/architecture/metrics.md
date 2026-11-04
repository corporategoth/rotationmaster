# Metrics: adherence, delay and output

How closely the player follows a rotation's advice, how long they take to act on it, what they cast instead, and what a fight
produced. This is separate from the TBC cast-receipt diagnostic in [analytics-replay.md](analytics-replay.md), which stays a
30-second, volatile, evidence-grade capture; the metrics are lightweight totals that run for as long as the player leaves them on.

## Switches and cost

Two profile switches, both **off** by default (General > Metrics): `metrics_adherence` and `metrics_effectiveness`.
`addon:ApplyMetricsSettings()` makes the registrations match them and is called from `enable()`, `disable()` (which forces
everything off), the settings effect and every profile change. With both off no frame, event, message handler or timer exists;
the first switch turned on creates one frame.

| Switch | Registers | Reads |
| --- | --- | --- |
| adherence | `UNIT_SPELLCAST_SENT` for `player` only, `PLAYER_REGEN_DISABLED/ENABLED`, the `ROTATIONMASTER_SPELL_UPDATE` message the glow already sends | the spell id of the player's own cast, when it is readable (`CanReadValue`) |
| effectiveness | `COMBAT_LOG_EVENT_UNFILTERED` (plus the combat events) | damage and healing of events whose source is the player: one string comparison for every other event |

Retail and Forever hide the combat log payload (`combatDataPolicy="restricted"`), so effectiveness registers nothing there and
`addon:GetMetricsState()` reports the combat log as unreadable; adherence works wherever the cast spell id is readable.
Nothing is allocated per event after the first record of a spell. The report and the exports are built when asked for.

## What is recorded (`Analytics/metrics.lua`)

Only during a fight (combat), under the rotation that was advising. A cast counts when the player presses it
(`UNIT_SPELLCAST_SENT`, so a cast-time spell counts at the press, not at the end).

* **Followed**: the cast is the spell being advised. The **delay** is the time since the advice appeared (or since the previous
  followed cast, because the same spell can stay advised). The global cooldown is part of it; it is not subtracted. Delays go into a
  six-bucket histogram (under 0.25, 0.5, 1, 2, 4 seconds, slower) and a mean.
* **Deviation**: another spell was advised. What replaced the advised spell is kept per advised spell (at most 8). The report
  splits deviations into **out of order** (the replacement is a spell the rotation also advises) and **outside** (it never
  advises it); the split is made when the report is built, once the rotation's whole advised set is known.
* **Unadvised**: nothing was advised.
* **Not acted on** (superseded): the advice changed before the player pressed it.
* **Fights**: a fight of at least 8 seconds with at least one cast is filed, with its duration, damage, healing, casts and
  followed casts, in a ring of the last 40 per rotation. The report compares output in fights that followed the advice less than
  60 percent, 60 to 85 and 85 or more of casts, each tier shown only with three or more fights.

Saved in `RotationMasterDB.global.metrics` (`version`, `order`, `rotations`), bounded: 24 rotations (the least recently added
is dropped), 64 advised spells each, 40 fights each. Nothing identifies a character, a realm, a target or a guild.

## Reading and exporting (`UI/metrics_report.lua`)

General > Metrics has four buttons, each opening the selectable text window (Ctrl-A, Ctrl-C):

* **Metrics report**: a readable summary per rotation.
* **Export for the website**: JSON with `format="rm-metrics"` and `version=1`: per rotation `id`, `name`, `fights`, `seconds`, `casts`,
  `followed`, `followedPercent`, `meanDelay`, `delayHistogram`, `dps`, `hps`, `outOfOrder`, `outside`, `unadvised`, `superseded`,
  `spells[] { spell, name, followed, meanDelay, superseded, replacedBy[] { spell, name, count } }`, `outsideSpells[]`, `byAdherence[]`
  and `fightList[]`; plus `client { family, interface }`. Keys are sorted, so the same data encodes the same way. The website
  imports this to attach adherence and output to a rotation page; it never leaves the game by itself.
* **Export for a language model**: the same JSON behind plain-English instructions that define each field and ask where the
  player deviates, whether the deviations look deliberate, and where the rotation should change. Both exports are data and stay in English.
* **Clear metrics**.

## Tests

`tests/metrics.lua` (the bookkeeping, caps and JSON), `tests/metrics_events.lua` (nothing exists while off, the registrations
each switch makes, matching a cast with its advice, the combat log and the restricted clients). No real client has run this:
`UNIT_SPELLCAST_SENT` carrying the spell id as its fourth argument and the combat log payload positions are from the documented
events, and the Retail and Forever cast id is read only when `CanReadValue` allows it.
