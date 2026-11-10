# Forecast: predicting the recommendations after the first

The preview window shows up to five upcoming recommendations (Preview Spells). Without the forecast the poll keeps walking the
rotation against the game *as it is now* and shows the next steps whose conditions match, so a spell the first one is about to
put on cooldown, spend mana on or apply a debuff for is judged as if it had not been cast. With the forecast on (Preview >
Forecast, off by default) the first recommendation is read exactly as before and each later one is predicted from the state
after the earlier ones were cast. It needs Preview Spells above one; it adds one rotation walk per extra slot (at most four).

## How a pass works (`Core/forecast.lua`)

`addon.Forecast:Run(rot, first, count)` is called by both evaluation engines (`main.lua`, standard and lean) after the walk has
stopped at the first recommendation. For each predicted slot it:

1. makes a fresh condition cache and a fresh readiness memo;
2. replaces a few `Platform` readers for the length of the call (below) with projections of the same reads;
3. runs the real executor (`addon:EvaluateRotationSequence`, so Branch and Stop behave as they do) with the real conditions
   (`addon:evaluateConditionWithCache`, the cache-taking form of `evaluateConditionResult`) and the real readiness
   (`addon:NewActionReadiness`), and takes the first step that matches and is ready;
4. applies that spell to the projected state (its cooldown, cost, charges, auras, damage and healing) and moves the projected
   time on by the longer of the spell's cast time and the global cooldown (an off-global-cooldown spell takes 0.05 seconds).

The readers are put back before `Run` returns, also when a condition raises an error; a failing forecast logs at verbose level and
returns no predictions, so it can cost the later icons but never the first recommendation. Nothing is written to a Blizzard
global: only RM's own `Platform` table is touched, and only inside the call.

**Time is not warped.** Every projected timestamp is moved back by the projected offset instead, so a condition that computes
`expiration - GetTime()` reads the remaining time at the projected moment. A cooldown that started at `s` is reported as starting
at `s - t`; a cast spell's cooldown starts at `now + (cast offset) - t`; an aura expiring at `e` expires at `e - t`, and is dropped
when that is in the past.

| Reader | Projection |
| --- | --- |
| `GetSpellCooldown`, `IsSpellReady` | shifted as above; a predicted spell with a base cooldown (`GetSpellBaseCooldown`) is on it from its cast. A hidden (secret) time is passed through unshifted. |
| `GetSpellCharges` | uses of the spell so far taken off the current charges |
| `GetItemCooldown` (and so `IsItemReady`) | an item a predicted step uses is on its cooldown from then, so a potion or trinket is not predicted twice; a cooldown already running is shifted like a spell's. The cooldown's length is the longest seen running (saved on the spell the item casts, `cooldown`), and, for an item never seen on cooldown, once for the window, at 5% of the confidence |
| `IsSpellUsable`, `GetUnitPowerObservation` | the player's power with predicted costs (`C_Spell.GetSpellPowerCost`) spent, what the predicted spells give (rage from Charge, focus from a builder) added, and regeneration added (mana from `GetManaRegen`, energy 10 per second); a spell short of power now is usable when regeneration covers it, and the reverse |
| `GetUnitFlagObservation` | the player is in combat once a predicted spell that starts it has been cast (one the game's spell tables aim at an enemy, or one known to do damage; no client has an API that says whether a spell is harmful), so a rotation's out-of-combat branch (a pull such as Charge, then Stop) does not end every later slot |
| `GetUnitPointPowerObservation`, `GetPlayerComboPointObservation` | the player's points of a resource (combo points, holy power, chi, soul shards, ...) with what the predicted spells do to them: a builder adds the points it gives, a finisher spends every point there is; never more than the maximum |
| `GetAuraByIndex` | the real list aged to the projected time, then the auras the predicted spells are known to apply, written as the unit's own auras |
| `GetUnitHealthObservation` | the target's health less the damage the predicted spells are known to do; the player's plus the healing they do to the player |

Everything else, including the target, range, the global state and every condition, is read as it is. A reader that cannot be read
is not guessed at, so on Retail and Forever (where most of these numbers are secret in combat) the pass degrades to the real
conditions seeing real, unshifted values and the confidence says so.

## What the forecast learns (`Platform/forecast_events.lua`)

While the switch is on, per spell, saved in `RotationMasterDB.global.forecast` (at most 160 spells): the aura a spell leaves on the
target or the player (the auras before the cast, on `UNIT_SPELLCAST_SENT`, against 0.35 seconds after `UNIT_SPELLCAST_SUCCEEDED`; settled
after three matching sightings or five empty looks, after which the spell is not scanned again), and the damage it does and the
healing it does to the player (a running average, from the combat log; not on Retail and Forever). Nothing is registered with the
switch off, and Preview > Forecast has a button to forget it all.

What a cast leaves is taken from, in this order:

1. what was seen of the spell on this client (above), once it has been watched;
2. the game's own spell tables (`Data/spell_effects_forever.lua`, `Data/spell_effects_retail.lua`, one per client family and loaded
   only on that one, parsed on first use by `Forecast:Effects`): the auras a class spell applies to the target or the player, directly
   or through the spell it triggers, and for how long (0 until removed). These are generated by `tools/generate_spell_effects.py`
   from the public DB2 tables (wago.tools: product `wowf` for Forever, `wow` for Retail) for the spells a class can learn plus every
   number in the family's Built In rotations; `--fetch` is the only thing that touches the network, the build and a hash of the rows
   are recorded in the file, and `tools/check --static` runs `--check` to prove nobody edited the rows. A spell that applies several
   auras (a buff and a debuff) applies each, and one that stacks (Sunder Armor, to five) adds a stack to the count already there, up to
   the most it stacks to, so a condition on the number of stacks reads what it will be. The same rows say how many points of a point
   resource a spell gives (a combo point from Sinister Strike) which spells are finishers (every point is spent) and which are aimed at an enemy (casting one starts combat, which is how a pull such as Charge puts the later slots in combat). The same rows
   carry the amount of a primary resource a spell gives (rage, focus, energy, runic power, ...), its costs (below) and its school. Where a
   spell is a hit and its aura is a separate spell of the same name (Rend, Corruption), the aura is linked by name when exactly one
   spell of that name and class applies one; where that is ambiguous (Retail's Rend has dozens) nothing is guessed. A spell the tables
   do not list falls through to the next source. A spell watched leaving no aura is never given one;
3. the rotation: a step that casts a spell only while that spell's own buff or debuff is missing or running out (a `BUFF`, `DEBUFF`,
   `BUFF_REMAIN` or `DEBUFF_REMAIN` test naming the spell, or a spell of the same name, on the step's conditions) is the upkeep step
   for it, so casting it is projected to apply that aura, on the unit the test names, for 30 seconds, at a 5% cost to the
   confidence.

Without these, an upkeep step such as Rend or Battle Shout would be predicted again straight after its own cast.

**Chances are guesses, and only the confidence pays for them.** The tables hold no per-cast chance (`SpellAuraOptions.ProcChance` is
the rate of a proc, not of the cast applying its own aura), so a chance is worked out two ways:

* *How often an aura follows a cast, seen here.* For a spell's first twenty casts every aura that is new or refreshed after the cast is
  counted (`seen[aura].n` over `casts`, at most six auras a spell). The one seen most is what the spell applies; an aura seen after
  only some casts is a proc. An aura seen after at least half the casts (counted over at least two) is projected, and costs
  `0.5 + 0.5 x chance` of the confidence (an aura seen after 7 casts in 10 costs 15%); one seen less often is not projected, since
  the likelier outcome is that it is not there. Records saved by an earlier version, which kept one aura and no count, are taken as
  certain.
* *Whether the cast lands.* Not on Retail: a spell the tables aim at an enemy (or known to do damage) has a chance to miss from the
  player's and the target's level (a level the game does not show is taken as three above), from the Classic-era table (physical 5,
  5.5, 6 and 8 percent, magical 4, 5, 6 and 17 at 0 to 3 levels above) with no hit rating taken off: no client manifest lists a way to
  read the player's hit, so a well-geared player is shown as surer of a miss than they are. Half of a miss changes what follows, so a
  chance of 8% costs 4% of the confidence. The spell's school decides which table (physical or not).

Costs are read live (`C_Spell.GetSpellPowerCost`) on every pass. Where the game hides them (in combat on a restricted client) the last
readable answer for that spell is used, because nothing that sets a cost (gear, talents, level, maximum mana, which is what a cost
given as a percentage is a share of) can change in combat, and every readable read replaces it. The rotation's spells are read
ahead of time, at most every five seconds and never in combat, so a spell first cast in combat already has an answer.

A spell whose cost was never readable falls back to the game's tables: its flat cost plus its percentage of the player's *base
mana*. The game does not say the base mana, so it is worked out from any live read of a spell whose table row has a percentage
(`(cost - flat) / percent`), saved with the level it was read at (`forecast.base`) and dropped when the level changes, so it follows a
level-up and is replaced by the next readable read; gear, talents and auras that change a cost are not in the table, which is why a cost
taken this way is an estimate and takes 3% off the confidence. A percentage cost whose base mana is not yet known is left out. A cost
that cannot be found at all costs confidence like any resource the pass does not project.

## Confidence

Slot confidence starts at 1 and each predicted step multiplies it by 0.9, by 0.9 again when it repeats the previous spell, by 0.95
for a spell with a cast time (it can be interrupted or moved away from), by 0.88 for a cost in a resource the pass does not
project, by 0.97 for a cost taken from the tables, by 0.95 for an aura assumed from the rotation and for an item whose cooldown has
not been seen, by `0.5 + 0.5 x chance` for an aura seen after only some casts, and by half the chance to miss. With prediction tracking on, the measured hit rate of that slot (over all rotations, once 20 predictions have been
checked) is averaged with it. The preview icon fades with it (opacity 0.4 to 1) unless Preview > Forecast > "Fade predictions that are
less certain" is off; the first icon never fades. Each predicted icon also says, over its middle, how many seconds after the
first spell it would be cast ("+3.5s"), and, at its foot, the confidence as a percentage. The fade, the percentage and the seconds are three options (Preview > Forecast: "Fade
predictions that are less certain", "Show how sure each prediction is", "Show the seconds until each prediction is cast"), each on by default.
When nothing is ready after a cast the projection moves forward a second at a time, up to ten seconds, to the next step that is,
so the queue is filled even while everything cools down; each second waited costs 3% of the confidence. The preview icons draw no
cooldown dial. A later slot is never shown surer than the one before it, since it only comes true if that one did. The pass judges
readiness by the preview's own options (`NewActionReadiness(now, 'preview')`), so a preview that ignores range or mana projects the same
way it advises. With the preview's Ignore Moving on, while the player moves and nothing can be advised (the rotation's own moving
conditions stop it), the preview shows what would be advised standing still, as upcoming slots that light nothing: the projection reads
no movement (`Wait(rot, count, true)`). While a cast is under way the first slot's time counts from the cast's remaining seconds when the game lets them be read, so the
"+Ns" figures count down as the cast goes on; the times of a wait (nothing ready) are aged by the poll in between.

## Measuring it (`Analytics/metrics.lua`)

"Track how accurate the predictions were" (`metrics_prediction`) records the first forecast made for each advised spell, ahead of
time, and compares it with the highlights that follow: the next new highlight against the forecast's first prediction, the one
after against its second, and so on. Per rotation and slot it keeps the number checked, the hits and the sum of the confidences,
so the report shows the hit rate beside how sure the forecast said it was. Only fights count; a cleared highlight is not a
highlight. See [metrics](metrics.md).

## Tests

`tests/forecast.lua` (each projected reader with numbers, items, gains, estimated costs, chances and misses, the pass loop, confidence, restoration), `tests/forecast_events.lua`
(learning and its limits), `tests/forecast_engine.lua` (the real executor, conditions and preview window on both engines),
`tests/metrics.lua` (prediction accuracy). No real client has run this; the projections follow the documented return shapes of
the readers, `GetSpellBaseCooldown` returning milliseconds and the global cooldown flag, `C_Spell.GetSpellPowerCost`, and
`GetManaRegen`.
