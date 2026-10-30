# World-state and edition conditions

Nine Built In conditions read the state of the world around the player and the
mechanics that belong to one edition (`PLAYER_STATE`, `ENCOUNTER`,
`KEYSTONE_LEVEL`, `GROUP_COUNT`, `HERO_TALENT`, `SPELL_GLOW`, `PET_HAPPINESS`,
`STAGGER`, `ECLIPSE`), and four released conditions gained optional fields
(`INSTANCE`, `SWING_TIME`, `SWING_TIME_REMAIN`, `ITEM_COOLDOWN`). Each is
registered on every client; where an edition lacks the mechanic or the API,
`Core/condition_support.lua` declares it unavailable there (the editor says "X
is not available on this client (reason)", a rotation that uses it is
incomplete, and the website's condition browser draws its red X from the same
table). Per-condition secrecy classification and evidence:
[restricted-clients.md](restricted-clients.md). No condition does any work until
a rotation, switch or announcement evaluates it, and each reader runs at most
once per evaluation (one `getCached` entry shared by every condition that needs
the same fact).

Where one fact has several variants they are one condition with a choice, not
one condition each: the player states are the choices of `PLAYER_STATE`, the
group measures those of `GROUP_COUNT`, the two Eclipse measures those of
`ECLIPSE`. A released condition is never renamed or narrowed: new fields on it
are optional, and a condition saved without them evaluates as it always did.

## Player state (`Conditions/player_state.lua`, `Platform/world_state.lua`)

`PLAYER_STATE` has one field, `state`, chosen from a list. Stealth, being
outdoors and having control of your character are the older `STEALTHED`,
`OUTDOORS` and `INCONTROL` conditions, and `DEAD` ("Is Dead or Ghost") tests any
unit; none of them is repeated here.

| State | Matches while | API | Editions |
|---|---|---|---|
| `mounted` | you are on a mount | `IsMounted` | all |
| `swimming` | you are swimming, at the surface or under water | `IsSwimming` | all |
| `flying` | you are flying | `IsFlying` | all |
| `falling` | you are falling | `IsFalling` | all |
| `resting` | you are in a rested area (inn, capital) | `IsResting` | all |
| `dead` | you are dead and have not released your spirit | `UnitIsDead` | all |
| `ghost` | you have released your spirit | `UnitIsDeadOrGhost` and not `UnitIsDead` | all |

The legacy forms of these functions answer 1 or nil; nil means "no". A secret,
malformed or throwing answer is unavailable, also under NOT. `ghost` is derived
from the two death functions the generated client manifests already list, so it
adds no new global name; `UnitIsGhost`, `UnitOnTaxi` (on a flight path) and
`IsSubmerged` are not referenced anywhere yet and would need the manifests
regenerated (`tools/generate_client_api.py`, which reads Blizzard's UI source
for all five clients) before a state can use them.

## Encounter, instance and keystone

| Condition | Matches | API | Editions |
|---|---|---|---|
| `ENCOUNTER` | while the game reports a boss encounter in progress (no boss mod needed) | `C_InstanceEncounter.IsEncounterInProgress` (the deprecated global is a fallback) | all |
| `KEYSTONE_LEVEL` | compares the active Mythic+ keystone level (0 outside a run) | `C_ChallengeMode.IsChallengeModeActive`, `GetActiveKeystoneInfo` | Retail |

`INSTANCE` (`Conditions/misc.lua`) gained two optional fields next to its kind
(dungeon, raid, ...):

- `difficulty`: the difficulty ID of your instance, picked from a list the game
  names (`GetDifficultyInfo`); 0 is the open world;
- `instanceID`: one particular instance by its ID, which does not change with
  the game language the way a zone name does; the editor shows the instance you
  are in. Both come from `GetInstanceInfo`.

Every part given must match. With no kind chosen, a difficulty or an ID alone
decides; a condition with neither is the released condition and evaluates as it
did. `ENCOUNTER_START` and `ENCOUNTER_END` wake the idle gate.

`ENCOUNTER` has no encounter ID field. `ENCOUNTER_START` carries the encounter ID
and Blizzard's documentation marks it unannotated, but nobody has read it on a
live Midnight pull, so it stays out until the payload is verified (`/rm debug
timeline` records what an encounter hands an addon). Affix conditions are not
built: the affix IDs change every season and need a list the game offers.

## Group (`Conditions/group_state.lua`)

`GROUP_COUNT` compares one number about your party or raid, and **every count
includes you**:

| Measure | Counts | API | Editions |
|---|---|---|---|
| `size` | players in your group (1 alone) | `GetNumGroupMembers`, `IsInRaid` | all |
| `TANK`, `HEALER`, `DAMAGER` | members whose assigned role it is | `UnitGroupRolesAssigned` over `player`/`party1-4` or `raid1-40` | Retail, Forever, Mists |
| `dead` | members who are dead or ghosts | `UnitIsDeadOrGhost` over the same tokens | all |

Each measure except `size` can be compared as a count or, with the "As a
percent of the group" box, as a percent of the whole group (you included): more
than 50 percent dead while you are not (`PLAYER_STATE` dead, under NOT) is one
AND of two conditions. `Platform:GetGroupSnapshot(want)` reads only what the
measure needs, so a group size never asks for roles or deaths. A member whose
value cannot be read makes the count unavailable instead of understating it. The
party and raid tokens are read inside the platform adapter; they are not unit
choices in the condition editors.

Assigned roles stay unavailable on Classic Era and Burning Crusade
(`no-group-roles`). The generated manifests list `UnitGroupRolesAssigned` as a
native function there, which proves it exists and nothing else: whether a
player can assign a role on those clients is unverified. In a group, `/run
print(UnitGroupRolesAssigned("player"))` after setting a role answers it; the
gate relaxes only on a TANK, HEALER or DAMAGER answer.

## Retail systems

| Condition | Matches | API | Editions |
|---|---|---|---|
| `HERO_TALENT` | the chosen hero talent tree (subtree ID; blank matches any tree); the editor lists the trees of the rotation's specialization by the game's own names | `C_ClassTalents.GetActiveHeroTalentSpec`; names from `C_Traits.GetSubTreeInfo` | Retail |
| `SPELL_GLOW` | a spell shows the activation (proc) glow; the spell and its base and override IDs are all asked | `C_SpellActivationOverlay.IsSpellOverlayed` | all that have the API (the glow never shows where nothing procs, so it is false there) |

`ITEM_COOLDOWN` (`Conditions/item.lua`, `Core/item_conditions.lua`) gained an
optional `slot` (trinket 1 or 2, inventory slots 13 and 14): the cooldown left on
whatever is equipped there, so one rotation works for every trinket, read from
the equipped item the build context keeps and `Platform:GetItemCooldown`. With a
slot the item is ignored (and no longer required); an empty slot is false and a
trinket with no on-use effect is unavailable.

`SPELL_GLOW` takes a plain spell ID and returns a plain boolean, so it reads
in combat on Retail and Forever where an aura read for the same proc may be
secret. `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` and `_HIDE` wake the idle gate.

## Edition mechanics (`Conditions/edition_state.lua`, `Platform/edition_state.lua`)

| Condition | Matches | API | Editions |
|---|---|---|---|
| `PET_HAPPINESS` | Hunter pet is Unhappy, Content or Happy (false without a Hunter pet) | `GetPetHappiness` | Classic Era, Burning Crusade, Wrath |
| `STAGGER` | compares the Stagger pool, or its percent of maximum health | `UnitStagger`, `UnitHealthMax` | Mists, Retail, Forever |
| `ECLIPSE` | `direction`: the Eclipse bar heads toward a Solar or a Lunar Eclipse; `energy`: compares the bar, -100 (Lunar) to 100 (Solar) | `GetEclipseDirection`; `UnitPower("player", Enum.PowerType.Balance)` | Wrath through Mists |

`SWING_TIME` and `SWING_TIME_REMAIN` (`Conditions/weapon.lua`) gained an optional
`ranged` flag next to `offhand` (the two exclude each other): the Auto Shot or
wand interval from `UnitRangedDamage`, and the time until the next shot from the
last `RANGE_DAMAGE`/`RANGE_MISSED` of an auto-repeat spell in the combat log.
The interval reads wherever its value is readable; the remaining time needs the
combat log, so it is available on Era, Burning Crusade and Mists and declared
unavailable on Retail and Forever.

Eclipse follows Blizzard's own 5.5.4 Eclipse bar (`Blizzard_UnitFrame/Cata/
EclipseBarFrame.lua`: the Sun sits at the right end of the bar, the Moon at the
left, power from `Enum.PowerType.Balance`). Another class has no Eclipse bar,
so it is unavailable for it. The ranged timer is cleared when you leave
combat and is not reset by a cast or a target change; before the first shot of
a fight it reads the full weapon interval.

## Profiles

Existing profiles receive the new conditions once, under the profile flag
`worldConditionsSeeded` (`Conditions/world_seed.lua`): each joins its category
(Spatial, Combat, Character or Spells) and the conditions that choose a
rotation also join the Switch picker. A condition removed later stays removed;
new and reset profiles take the packaged defaults in `init.lua`. A development
profile seeded by an earlier draft loses the tags that were merged away
(`MOUNTED` and its siblings, `GROUP_SIZE`, `ECLIPSE_DIRECTION`, ...), and nothing
else.

## Not built

- Boss timeline conditions (`C_EncounterTimeline`): `/rm debug timeline
  [seconds|show|stop]` records what the client really hands an addon during an
  encounter (which fields are readable, event IDs, states, times remaining).
  The condition ("a boss ability is due in N seconds") follows the answer.
- Retail class resources that Blizzard does not flag never secret (Maelstrom,
  Insanity, Fury): `POWER` and `POWERPCT` already read them whenever
  `C_Secrets.GetPowerTypeSecrecy` allows. Soul Fragments (Devourer) are an aura
  count (`C_UnitAuras.GetPlayerAuraBySpellID`, spell IDs 1225789 and 1227702):
  `BUFF_STACKS` reads them wherever the aura is readable.
- Boss, arena and nameplate unit tokens in the unit picker: they change every
  unit-aware condition, its saved-value validity and every editor, so they are
  a project of their own. (Focus, and the resolved group units, are in
  [unit-types.md](unit-types.md).)
- A heal-target choice (RM never chooses a spell's target), the lowest-health
  ally on Retail (health is secret), War Mode, affixes, delve tier and level
  difference: low value, impossible, or no stable list. (Raid markers are in
  [raid-marks.md](raid-marks.md).)
