# Metrics: adherence, delay and output

How closely the player follows a rotation's advice, how long they take to act on it, what they cast instead, and what a fight
produced. This is separate from the TBC cast-receipt diagnostic in [analytics-replay.md](analytics-replay.md), which stays a
30-second, volatile, evidence-grade capture; the metrics are lightweight totals that run for as long as the player leaves them on.

## Switches and cost

Three profile switches, all **off** by default (General > Metrics): `metrics_adherence`, `metrics_effectiveness` and `metrics_prediction`.
`addon:ApplyMetricsSettings()` makes the registrations match them and is called from `enable()`, `disable()` (which forces
everything off), the settings effect and every profile change. With both off no frame, event, message handler or timer exists;
the first switch turned on creates one frame.

| Switch | Registers | Reads |
| --- | --- | --- |
| adherence | `UNIT_SPELLCAST_SENT` for `player` only, `PLAYER_REGEN_DISABLED/ENABLED`, the `ROTATIONMASTER_SPELL_UPDATE` message the glow already sends | the spell id of the player's own cast, when it is readable (`CanReadValue`) |
| effectiveness | `COMBAT_LOG_EVENT_UNFILTERED` (plus the combat events) | damage and healing of events whose source is the player: one string comparison for every other event |
| prediction | the combat events and the `ROTATIONMASTER_SPELL_UPDATE` message | nothing from the game: it compares the forecast ([forecast](forecast.md)) with the highlights that follow |

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
* **Prediction accuracy**: per rotation and predicted slot (2 to 5), how many forecasts were checked, how many were right and how sure they said they were; see [forecast](forecast.md).
* **Fights**: a fight of at least 8 seconds with at least one cast is filed, with its duration, damage, healing, casts and
  followed casts, in a ring of the last 40 per rotation. The report compares output in fights that followed the advice less than
  60 percent, 60 to 85 and 85 or more of casts, each tier shown only with three or more fights.

Saved in `RotationMasterDB.global.metrics` (`version`, `order`, `rotations`), bounded: 24 rotations (the least recently added
is dropped), 64 advised spells each, 40 fights each. Nothing identifies a character, a realm, a target or a guild.

## Reading and exporting (`UI/metrics_report.lua`)

Metrics is a top-level tab, between General and Conditions. It holds the three recording switches (adherence, damage and healing, prediction accuracy) and the report, drawn in the pane with a scroll bar for the page; nothing opens a separate window except the export's text.

* **Metrics report** covers a period you choose with a row of buttons across the top of the pane: **Last fight**, **This session**
  (the fights since the addon loaded: logging in or reloading the interface), **This instance** (the instance or, in the open
  world, the zone you are in now), a **timed** period and **All time**. **Reset** sits in the same row (the button reads Confirm
  for four seconds after the first press, and the second press does it). The timed period's button reads "Last N minutes, hours
  or days": a slider sets N and three buttons set the unit (minutes up to 180, hours up to 72, days up to 30). The periods are
  made of the last 300 fights, each kept in full with its time, its
  place (the key of the instance or zone, from `GetInstanceInfo` or `GetRealZoneText`) and, where the client announces it, the
  encounter (`ENCOUNTER_START`). Forecast accuracy is only kept for all time. It opens on the last fight.
  A window of graphs with a tab for each rotation (up to five, most fights first): a gauge for how closely the
  advice was followed (green from 85 percent, yellow from 60, red below), a bar of where the casts went (followed, out of order,
  outside the rotation, no advice), a chart of how long it took to act on the advice, damage per second by how closely the advice
  was followed, the most common deviations (what was cast instead, with spell icons) and, when tracked, how often each forecast was
  right against how sure it said it was. Drawn from pooled textures, so reopening it allocates nothing new.
* **Compare with** (a button under the period buttons that steps through the choices) sets the rotation shown beside something
  else: nothing, the previous fight (for Last fight), the period before (for a timed period, the same length just before it),
  this session, this instance, another instance (a second button chooses which of the instances fought in), a timed period of its
  own (with its own slider and units), all time, or another rotation over the same period (a second button chooses which). The
  comparison table lists how closely the advice was followed, the time to act, damage and healing per second and the share of
  casts outside the rotation or out of order, each as shown, compared and change; a change under two percent is gray, an
  improvement green, a worsening red. The controls fill the pane's width and the page is redrawn when the pane is resized; they
  wrap onto more rows when the pane is too narrow for the least width of a button.
* **Export for the website**, under the graphs, exports the period shown and opens the selectable text window (Ctrl-A, Ctrl-C). With
  **Add instructions for a language model** ticked, plain-English instructions that define each field and ask where the player
  deviates, whether the deviations look deliberate, and where the rotation should change come first, and the same JSON follows. The JSON with `format="rm-metrics"` and `version=1`: per rotation `id`, `name`, `fights`, `seconds`, `casts`,
  `followed`, `followedPercent`, `meanDelay`, `delayHistogram`, `dps`, `hps`, `outOfOrder`, `outside`, `unadvised`, `superseded`,
  `spells[] { spell, name, followed, meanDelay, superseded, replacedBy[] { spell, name, count } }`, `outsideSpells[]`, `byAdherence[]`,
  `predictionAccuracy[] { slot, checked, hitPercent, meanConfidencePercent }` and `fightList[]`; plus `client { family, interface }`. Keys are sorted, so the same data encodes the same way. The website
  imports this to attach adherence and output to a rotation page; it never leaves the game by itself.

## Tests

`tests/metrics.lua` (the bookkeeping, caps and JSON), `tests/metrics_events.lua` (nothing exists while off, the registrations
each switch makes, matching a cast with its advice, the combat log and the restricted clients). No real client has run this:
`UNIT_SPELLCAST_SENT` carrying the spell id as its fourth argument and the combat log payload positions are from the documented
events, and the Retail and Forever cast id is read only when `CanReadValue` allows it.
