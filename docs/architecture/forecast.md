# Forecast: predicting the recommendations after the first

The preview window shows up to five upcoming recommendations (Preview Spells). Without the forecast the poll keeps walking the
rotation against the game *as it is now* and shows the next steps whose conditions match, so a spell the first one is about to
put on cooldown, spend mana on or apply a debuff for is judged as if it had not been cast. With the forecast on (General >
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
| `IsSpellUsable`, `GetUnitPowerObservation` | the player's power with predicted costs (`C_Spell.GetSpellPowerCost`) spent and regeneration added (mana from `GetManaRegen`, energy 10 per second); a spell short of power now is usable when regeneration covers it, and the reverse |
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
switch off, and General > Forecast has a button to forget it all.

## Confidence

Slot confidence starts at 1 and each predicted step multiplies it by 0.9, by 0.9 again when it repeats the previous spell, by 0.95
for a spell with a cast time (it can be interrupted or moved away from), and by 0.88 for a cost in a resource the pass does not
project. With prediction tracking on, the measured hit rate of that slot (over all rotations, once 20 predictions have been
checked) is averaged with it. The preview icon fades with it (opacity 0.4 to 1) unless General > Forecast > "Fade predictions that are
less certain" is off; the first icon never fades.

## Measuring it (`Analytics/metrics.lua`)

"Track how accurate the predictions were" (`metrics_prediction`) records the first forecast made for each advised spell, ahead of
time, and compares it with the highlights that follow: the next new highlight against the forecast's first prediction, the one
after against its second, and so on. Per rotation and slot it keeps the number checked, the hits and the sum of the confidences,
so the report shows the hit rate beside how sure the forecast said it was. Only fights count; a cleared highlight is not a
highlight. See [metrics](metrics.md).

## Tests

`tests/forecast.lua` (each projected reader with numbers, the pass loop, confidence, restoration), `tests/forecast_events.lua`
(learning and its limits), `tests/forecast_engine.lua` (the real executor, conditions and preview window on both engines),
`tests/metrics.lua` (prediction accuracy). No real client has run this; the projections follow the documented return shapes of
the readers, `GetSpellBaseCooldown` returning milliseconds and the global cooldown flag, `C_Spell.GetSpellPowerCost`, and
`GetManaRegen`.
