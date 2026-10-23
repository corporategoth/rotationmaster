# Runtime condition evaluation

AND evaluates children in authored order and stops at the first no-match. OR stops at the first match. NOT evaluates its one child and inverts only a known match/no-match. An encountered unavailable result stops its group and remains unavailable through NOT.

A decisive prefix skips later children entirely: their validation/evaluation callbacks, native queries, errors, unknown condition tags, cycles and depth are not visited. Consequently NOT(AND(false, unavailable)) matches, while NOT(OR(true, unavailable)) does not match. If unavailable is reached first, neither expression may treat it as false. This deliberate runtime policy differs from the earlier engine, which kept evaluating all normal siblings to discover later unavailable values.

Each reached AND/OR still checks its complete immediate child list for valid numeric keys, density and width before executing any child. Nested structure is checked when reached. Existing depth/node budgets apply to reached traversal. Empty AND matches; empty OR does not. Disabled nodes retain their existing match behavior. Saved-body/schema validation is separate and still inspects the saved tree; runtime skipping does not repair or validate an invalid definition.

Reached callback errors retain existing diagnostics, quarantine and path behavior. Each top-level condition retains its own fresh cache/timestamp, shared by its reached descendants. There is no cross-poll result cache or new shared observation registry. The normal polling cadence, event handlers and volatile readiness checks are unchanged.

At the step boundary an unavailable condition makes the rotation unusable for that poll, never false. An action step (spell, pet, any, item or Blizzard's suggestion), an evaluated Branch and a Stop all end the walk with status `unavailable`: lower steps are not recommended and implicit Attack is suppressed; recommendations already made above it in the same poll (preview) are kept. An action step used to skip on unavailable and fall through to lower steps; it now stops like a Branch or Stop. A cooldown whose condition is unavailable is not shown, and the rotation continues. A switch condition that is unavailable does not select its rotation. Nothing is persisted: the next poll reads every condition afresh. The standard executor (`Core/rotation_sequence.lua`, a visitor may return `"unavailable"`) and the lean engine (`leanWalk`) agree; `tests/unavailable_steps.lua` covers both on the prepared and ordinary condition routes. `addon:evaluateCondition` and the runtime session's `EvaluateBool` return a second result, true when the tree was unavailable.


Unit death and friendliness
--------------------------

`DEAD` (Is Dead or Ghost) and `FRIENDLY` (Is Friendly) accept a Unit selector and are initially included in Switch conditions. Existing `GROUP` also accepts a unit; no second group predicate is introduced. A Via Macro announcement can use Announcement target on each leaf. For example: `DEAD AND (FRIENDLY OR GROUP)` tests the exact supplied unit before whispering a resurrection attempt. This does not prove that the spell cast succeeded, that the target can be resurrected, or that native chat was delivered.

Death uses `UnitIsDeadOrGhost(unit)`; friendliness uses `UnitIsFriend("player", unit)`. NOT Hostile is broader than explicit friendliness. Missing, restricted, failed or malformed observations remain unavailable, including under NOT. Observations use the existing evaluation cache and expire each pass; no background work or cross-poll unit cache is added. A cold one-time profile migration seeds the two Switch choices, then preserves user removals and ordering across profile switches, copies and reloads. Reset seeds them again.

Artwork: two new original transparent raster icons, exported through the existing 64/128-pixel pipeline. All previous 128 source icons and 256 runtime textures remain byte-identical. Native rendering and macro delivery still require client acceptance.
