# World-state and edition conditions

Twenty Built In conditions read the state of the world around the player and
the mechanics that belong to one edition. Each is registered on every client;
where an edition lacks the mechanic or the API, `Core/condition_support.lua`
declares it unavailable there (the editor says "X is not available on this
client (reason)", a rotation that uses it is incomplete, and the website's
condition browser draws its red X from the same table). Per-condition secrecy
classification and evidence: [restricted-clients.md](restricted-clients.md).
No condition does any work until a rotation, switch or announcement evaluates
it, and each reader runs at most once per evaluation (one `getCached` entry
shared by every condition that needs the same fact).

## Player state (`Conditions/player_state.lua`, `Platform/world_state.lua`)

| Condition | Matches while | API | Editions |
|---|---|---|---|
| `MOUNTED` | you are on a mount | `IsMounted` | all |
| `SWIMMING` | you are swimming, at the surface or under water | `IsSwimming` | all |
| `FALLING` | you are falling | `IsFalling` | all |
| `FLYING` | you are flying | `IsFlying` | all |
| `RESTING` | you are in a rested area (inn, capital) | `IsResting` | all |

The legacy forms of these functions answer 1 or nil; nil means "no". A secret,
malformed or throwing answer is unavailable, also under NOT.

## Encounter and instance (`Conditions/encounter_state.lua`)

| Condition | Matches | API | Editions |
|---|---|---|---|
| `ENCOUNTER` | while the game reports a boss encounter in progress (no boss mod needed) | `C_InstanceEncounter.IsEncounterInProgress` (the deprecated global is a fallback) | all |
| `INSTANCE_DIFFICULTY` | the difficulty ID of your instance, picked from a list the game names (`GetDifficultyInfo`); 0 is the open world | `GetInstanceInfo` | all |
| `INSTANCE_ID` | one particular instance by its ID, which does not change with the game language the way a zone name does; the editor shows the instance you are in | `GetInstanceInfo` | all |
| `KEYSTONE_LEVEL` | compares the active Mythic+ keystone level (0 outside a run) | `C_ChallengeMode.IsChallengeModeActive`, `GetActiveKeystoneInfo` | Retail |

`ENCOUNTER_START` and `ENCOUNTER_END` wake the idle gate. Affix conditions are
not built: the affix IDs change every season and need a list the game offers.

## Group (`Conditions/group_state.lua`)

| Condition | Compares | API | Editions |
|---|---|---|---|
| `GROUP_SIZE` | players in your party or raid, counting you (1 alone) | `GetNumGroupMembers`, `IsInRaid` | all |
| `GROUP_ROLE_COUNT` | members holding an assigned role (Tank, Healer, DPS), you included | `UnitGroupRolesAssigned` over `player`/`party1-4` or `raid1-40` | Retail, Forever, Mists |
| `GROUP_DEAD_COUNT` | other members who are dead or ghosts (never you) | `UnitIsDeadOrGhost` over the same tokens | all |

One `Platform:GetGroupSnapshot()` pass answers all three. A member whose value
cannot be read makes the count unavailable instead of understating it. The
party and raid tokens are read inside the platform adapter; they are not new
unit choices in the condition editors.

## Retail systems

| Condition | Matches | API | Editions |
|---|---|---|---|
| `HERO_TALENT` | the chosen hero talent tree (subtree ID; blank matches any tree); the editor lists the trees of the rotation's specialization by the game's own names | `C_ClassTalents.GetActiveHeroTalentSpec`; names from `C_Traits.GetSubTreeInfo` | Retail |
| `SPELL_GLOW` | a spell shows the activation (proc) glow; the spell and its base and override IDs are all asked | `C_SpellActivationOverlay.IsSpellOverlayed` | all that have the API (the glow never shows where nothing procs, so it is false there) |
| `TRINKET_COOLDOWN` | compares the cooldown left on the item in trinket slot 13 or 14, whatever it is | equipped item from the build context, `Platform:GetItemCooldown` | all |

`SPELL_GLOW` takes a plain spell ID and returns a plain boolean, so it reads
in combat on Retail and Forever where an aura read for the same proc may be
secret. `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` and `_HIDE` wake the idle gate.

## Edition mechanics (`Conditions/edition_state.lua`, `Platform/edition_state.lua`)

| Condition | Matches | API | Editions |
|---|---|---|---|
| `PET_HAPPINESS` | Hunter pet is Unhappy, Content or Happy (false without a Hunter pet) | `GetPetHappiness` | Classic Era, Burning Crusade, Wrath |
| `STAGGER` | compares the Stagger pool, or its percent of maximum health | `UnitStagger`, `UnitHealthMax` | Mists, Retail, Forever |
| `ECLIPSE_DIRECTION` | the Eclipse bar heads toward a Solar or a Lunar Eclipse | `GetEclipseDirection` | Wrath through Mists |
| `ECLIPSE_ENERGY` | compares the Eclipse bar, -100 (Lunar) to 100 (Solar) | `UnitPower("player", Enum.PowerType.Balance)` | Wrath through Mists |
| `RANGED_SWING_REMAIN` | compares the time until the next Auto Shot or wand shot | `UnitRangedDamage` speed; the last `RANGE_DAMAGE`/`RANGE_MISSED` of an auto-repeat spell from the combat log | Era, Burning Crusade, Mists (the combat log is hidden on Retail and Forever) |

Eclipse follows Blizzard's own 5.5.4 Eclipse bar (`Blizzard_UnitFrame/Cata/
EclipseBarFrame.lua`: the Sun sits at the right end of the bar, the Moon at the
left, power from `Enum.PowerType.Balance`). Another class has no Eclipse bar,
so those two are unavailable for it. The ranged timer is cleared when you leave
combat and is not reset by a cast or a target change; before the first shot of
a fight it reads the full weapon interval.

## Profiles

Existing profiles receive the new conditions once, under the profile flag
`worldConditionsSeeded` (`Conditions/world_seed.lua`): each joins its category
(Spatial, Combat, Character, Spells, Items or Buffs) and the conditions that
choose a rotation also join the Switch picker. A condition removed later stays
removed; new and reset profiles take the packaged defaults in `init.lua`.

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
- Boss, arena and party unit tokens in the unit picker: they change every
  unit-aware condition, its saved-value validity and every editor, so they are
  a project of their own.
- War Mode, affixes, delve tier, raid markers and level difference: low value
  or no stable list.
