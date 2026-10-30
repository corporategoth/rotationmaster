# Unit types

Every unit-aware condition names its unit by a choice in the editor. The choice
is saved as a plain string and is either a token the game understands or a
*group unit type*, which has no token of its own and is resolved when the
condition is evaluated.

## Tokens the game understands

`player`, `pet`, `target`, `mouseover`, `pettarget`, `targettarget`,
`mouseovertarget`, and `focus` and `focustarget` wherever the client has a focus
target. The focus tokens used to be hidden on Classic Era by a 2021 check of
`WOW_PROJECT_ID`. `Platform:IsFocusUnitSupported()` replaces it with a probe of
the client itself: the focus system registers `PLAYER_FOCUS_CHANGED` (asked of
`C_EventUtils.IsEventValid`, the same catalog `main.lua` uses for optional
events) and defines `FocusUnit` and the `FocusFrame`; any one of the three
answers yes. A client that cannot be probed keeps the old answer for its family
(everything but Era). `constants.lua` builds `addon.units` from it once at load.
Whether the focus target works on Era in the real game is unverified here; the
in-game check is `/focus` then `/run print(UnitExists("focus"))`.

## Group unit types

| Type | Resolves to | API | Editions |
|---|---|---|---|
| `maintank` | the raid's Main Tank | the `role` field of `GetRaidRosterInfo` (`"MAINTANK"`) | all; raids only, a party has none |
| `mainassist` | the raid's Main Assist | the same field (`"MAINASSIST"`) | all; raids only |
| `assignedtank` | the first member whose assigned role is Tank | `UnitGroupRolesAssigned` | Retail, Forever, Wrath through Mists (not Classic Era or Burning Crusade: `no-group-roles`) |
| `assignedhealer` | the first member whose assigned role is Healer | `UnitGroupRolesAssigned` | as above |
| `groupleader` | the party or raid leader | `UnitIsGroupLeader` | all |
| `skull` `cross` `square` `moon` `triangle` `diamond` `circle` `star` | the unit that carries that raid mark now | `GetRaidTargetIndex` over the tokens the client can reach (the mark table) | clients that have `GetRaidTargetIndex`; see [raid-marks.md](raid-marks.md) |
| `anymark` | the highest-priority marked unit: skull first, then cross, square, moon, triangle, diamond, circle, star | as above | as above |

`Platform:ResolveGroupUnit(kind)` (`Platform/group_units.lua`) walks `party1-4`
and `player`, or `raid1-40`, and answers a token (`raid7`, `party2`, `player`).
`addon:ResolveConditionUnits(value, cache)` (`Core/group_unit_resolution.lua`)
hands the condition a copy of its value whose `unit` (and `otherunit`, for
`ISSAME`) is that token, once per kind per evaluation, in both evaluation routes
and for switch conditions; every other condition field and every other condition
is untouched. Nobody holding the assignment, a member the game will not read,
or a missing API is *unavailable* with its reason (`no-assigned-unit`,
`restricted-value`, `missing-api`), also under NOT, and a rotation that uses a
type the client cannot resolve is incomplete (`Core/condition_support.lua`). A
type is offered in the unit picker only where the client can resolve it.

The roster role is spelled in capitals (`MAINTANK`, `MAINASSIST`) and is compared
case-insensitively. Not yet confirmed in game; a mismatch makes the two types
resolve to nobody (`no-assigned-unit`), never to a wrong unit.

`GetPartyAssignment("MAINTANK", unit)` answers the same question as the roster
role but is not in the generated client manifests (`tools/generate_client_api.py`
needs Blizzard's UI source for all five clients), so the roster field is read
instead. On Retail and Forever the conditions you can put on a group member are
the ones the game does not hide (alive or dead, in a range band, aura presence
where readable, existence); health, power and most auras are secret there.

## Not built

Boss, arena, party-member and raid-member tokens as unit choices, nameplate
tokens, heal-target selection, lowest-health ally on Retail (health is secret),
the reading "any marked unit satisfies" (the engine hands a condition one resolved
token; `anymark` is the highest-priority marked unit, and `MARKED` / `MARK_COUNT`
cover the rest), and any integration with another addon's assignments (no
stable public API).
