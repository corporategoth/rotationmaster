# Conditions on restricted clients (Retail and Forever)

Retail (Midnight, 12.x) and Forever (Interface 16001) run Rotation Master
under the **restricted** combat data policy (`Platform/client.lua`). While
`C_Secrets.HasSecretRestrictions()` is true, many APIs hand addons *secret
values*: they can be shown or passed back to Blizzard APIs, but comparing them,
doing arithmetic on them or using them as table keys raises an error in
addon code. Rotations and switch conditions need comparisons, so a condition
can only use data that is readable when it runs.

Each Built In condition is classified by the sources its reader uses:

- **Never secret** (N): no secret annotation on the API or field. The
  condition always reads.
- **Conditionally secret** (C): secret per unit, per spell, per field, or while
  restrictions apply (combat, encounters, challenge modes, PvP, restricted
  maps). The condition runs; every value passes `CanReadValue` (both
  `issecretvalue` and `canaccessvalue`) before it is compared, and a secret
  value this poll makes the condition **unavailable**: a Branch or Stop
  pauses that poll, an action step is skipped, and NOT of unavailable stays
  unavailable.
- **Always secret or removed** (A): the source never yields a comparable value
  for addons on that client. The condition is declared unsupported in
  `Core/condition_support.lua`, so a rotation that uses it is incomplete, with
  "X is not available on this client (reason)." in the editor and the Built In
  list.

## Sources

- Blizzard's generated API documentation, read as data:
  Gethe/wow-ui-source `Interface/AddOns/Blizzard_APIDocumentationGenerated`,
  `live` 15881d522c44cd106d3d8660106ec9f9d2f44167 (12.1.5.70575) and `forever`
  ca8368f2f2380cbe696854f7f2646387c278a61b (1.60.1.70532). Every annotation
  used below is identical on both branches (`SecretPredicatesDocumentation.lua`
  is byte-identical); the only differences in the APIs listed are
  `UnitAttackSpeed` (Forever adds a ranged speed return) and the weapon
  enchant reader (Forever documents `C_Item.GetWeaponEnchantInfo`; the global
  RM reads is undocumented on both).
- Annotations the documentation actually uses (function, field or event
  level): `SecretReturns`, `SecretWhen<Predicate>` (each predicate is
  explained in `SecretPredicatesDocumentation.lua`), field-level `NeverSecret`
  and `ConditionalSecret`, `SecretPayloads` on events, `HasRestrictions`, and
  the system-level `Environment = "SecureOnly"`. `SecretArguments` only says
  whether a secret may be passed in; RM passes plain values.
- In-game evidence from the user's Retail client, 2026-10-23, with
  `C_Secrets.HasSecretRestrictions()` true throughout:
  - `UnitHealth` and `UnitHealthMax` secret for `player` and `target` in
    combat, and for a hostile `target` out of combat; `UnitHealthPercent`
    secret for `player` and `target` in and out of combat. Comparing errored
    ("attempt to compare ... a secret number value, while execution tainted").
  - `C_Spell.GetSpellCooldown(61304)` (the global cooldown): `startTime` and
    `isEnabled` readable in combat.
  - `select(9, UnitCastingInfo("target"))` (cast spell ID): readable in combat.
  - Curve outputs (`C_CurveUtil`) stay secret; a secret value passed to a
    widget (`SetAlpha`, `StatusBar:SetValue`) makes the widget's getter secret.
- Not verified in game yet: everything else in the table. The throwaway probe
  addon `RMSecretProbe` (kept outside the repository, see the task report)
  prints `issecretvalue` per field for these APIs and units.

### Predicates in brief

| Predicate | Secret when |
|---|---|
| `SecretReturns` | whenever restrictions are in effect (no further condition given) |
| `SecretWhenUnitIdentityRestricted` | the unit is not player-controlled and not in your party/raid (any link of a compound token) |
| `SecretWhenUnitNameIdentityRestricted` | as identity, except a player in PvP |
| `SecretWhenUnitComparisonRestricted` | compound tokens always; otherwise only on addon-restricted maps |
| `SecretWhenUnitSpellCastRestricted` | the unit is not the player or pet; per-spell never/always flags win |
| `SecretWhenUnitAuraRestricted` | combat, encounter, challenge mode or PvP restrictions; per-spell flags win |
| `SecretWhenCooldownsRestricted` | combat, encounter, challenge mode or PvP restrictions; per-spell flags win |
| `SecretWhenTotemSlotSecret` | combat, encounter, challenge mode or PvP restrictions; per-totem flags win |
| `SecretWhenUnitStatsRestricted` | "when access to unit stats would generally produce secret values" (`C_Secrets.ShouldUnitStatsBeSecret`) |
| `SecretWhenUnitThreatStateRestricted` | depends on the token pair; player/pet/ally against a nameplate, boss or target is "generally not secret" |
| `SecretWhenUnitPowerRestricted` | any power type not flagged never secret (`C_Secrets.GetPowerTypeSecrecy`), unless the unit lacks that power |
| `SecretWhenUnitPowerMaxRestricted` | the unit is not player-controlled; per-type flags win |
| `SecretWhenUnitHealthMaxRestricted` | the unit is not player-controlled |
| `SecretWhenLossOfControlInfoRestricted` | the subject is not the active player (only the `...ByUnit` reader) |

## What is unsupported, and why

| Reason | Conditions | Evidence |
|---|---|---|
| `secret-health` (while `HasSecretRestrictions()` is true) | HEALTH, HEALTHPCT, TT_HEALTH, TT_HEALTHPCT, PROXIMITY_HEALTH, PROXIMITY_HEALTH_COUNT, PROXIMITY_HEALTHPCT, PROXIMITY_HEALTHPCT_COUNT | `UnitHealth` `SecretReturns`; `UnitHealthMax` `SecretWhenUnitHealthMaxRestricted`; in game, secret for player and target in and out of combat |
| `secret-power` (while restrictions apply and the type is not flagged never secret) | MANA, MANAPCT, PROXIMITY_MANA, PROXIMITY_MANA_COUNT, PROXIMITY_MANAPCT, PROXIMITY_MANAPCT_COUNT (Mana); POWER, POWERPCT (when no primary bar type is flagged never secret) | `UnitPower` `SecretWhenUnitPowerRestricted`; the flag is client data read live from `C_Secrets.GetPowerTypeSecrecy` (`Enum.SecrecyLevel.NeverSecret` = 0). Without that API, the secondary resources Blizzard named never secret (Platform/points.lua) are the only readable types |
| `combat-log-unavailable` | SWING_TIME_REMAIN, TT_HEALTH, TT_HEALTHPCT | `COMBAT_LOG_EVENT_UNFILTERED` is `HasRestrictions`, and its payload is read only through `C_CombatLogSecure.GetCurrentEventInfo`, a `SecureOnly` system; Blizzard's own combat log (`Blizzard_CombatLogProcessor`) reads it there, on both branches |

A restricted client whose `HasSecretRestrictions()` reports false (or whose
answer cannot be read, which counts as restricted) is checked live: health and
power then read normally. The answer is read at validation; validation
results are cached by the validation stamp.

## Where the game hides a supported condition

A condition marked C works, but is unavailable while the game hides its data.
`Core/condition_restrictions.lua` lists, per condition, the situations its
predicate names. The editor shows them as a note under the condition's fields
and as the hover tip in the condition picker:

| Note | Predicate | Conditions |
|---|---|---|
| In combat, boss encounters, Mythic+ and PvP matches | `SecretWhenUnitAuraRestricted`, `SecretWhenCooldownsRestricted`, `SecretWhenTotemSlotSecret` | BUFF, BUFF_REMAIN, BUFF_STACKS, DEBUFF, DEBUFF_REMAIN, DEBUFF_STACKS, DISPELLABLE, STEALABLE, SPELL_COOLDOWN, SPELL_CHARGES, SPELL_REMAIN, the ANYSPELL_ and PETSPELL_ cooldown, charges and remaining forms, TOTEM, TOTEM_REMAIN, TOTEM_SPELL, TOTEM_SPELL_REMAIN |
| In combat | `SecretWhenUnitStatsRestricted` (secret in combat per Hekili Forever's probes) | STAT, SWING_TIME |
| For units that are not you, your pet or in your group | `SecretWhenUnitIdentityRestricted`, `SecretWhenUnitNameIdentityRestricted` | CLASS, CREATURE, PVP, IMMUNE, RESIST, RUNNER |
| For anyone but you and your pet | `SecretWhenUnitSpellCastRestricted` | CASTING_SPELL, CASTING_REMAIN, CASTING_PROGRESS, CAST_INTERRUPTABLE and the CHANNELING twins |
| In dungeons and raids | `SecretWhenUnitComparisonRestricted` (restricted maps); `UnitPosition` is nil there | ISSAME, PROXIMITY |

A unit-bound note is left out when the condition's unit is you, your pet or a
group unit type. For a condition saved with a spell ID, `C_Secrets`
`GetSpellAuraSecrecy`, `GetSpellCooldownSecrecy` or `GetSpellCastSecrecy`
refines the note: `NeverSecret` (0) removes it, `AlwaysSecret` (1) replaces it
with "the game always hides this for the chosen spell", and an unreadable or
contextual (2) level keeps it. The situations are Blizzard's
`Enum.AddOnRestrictionType` (Combat, Encounter, ChallengeMode, PvPMatch, Map),
readable live through `C_RestrictedActions.IsAddOnRestrictionActive` and
`ADDON_RESTRICTION_STATE_CHANGED`; RM does not read the live state, since a
hidden value already makes the condition unavailable at that poll.

An empty aura list is not always proof of absence. Glowing Bars (Forever)
records that in combat the game can hand back an empty list of the player's
auras rather than secret entries. So while `C_Secrets.ShouldAurasBeSecret()` is
true (or unreadable), an aura condition on `player` whose scan finds no aura at
all is unavailable (`auras-hidden`) instead of false
(`Platform:AreAurasHidden`, `Core/aura_conditions.lua`). A list with readable
entries, other units, and clients without the API are unchanged. This is
unverified in game on RM's side.

## What still answers while the game hides a value

These sources stay readable on Retail and Forever, so RM uses them where the direct read is secret. `/rm debug secrets`
(`Diagnostics/secrets.lua`) reports what each one reads in game and which conditions were unavailable how often.

| Fallback | Source | Used by | Limits |
|---|---|---|---|
| Movement events | `PLAYER_STARTED_MOVING` / `PLAYER_STOPPED_MOVING`, last readable `GetUnitSpeed` (`Platform/player_movement.lua`) | MOVING, Ignore Moving | the speed while moving is the last readable one, marked `estimated` |
| Cooldown Manager | buff viewer items' `auraInstanceID` presence (`Platform/cooldown_viewer.lua`; Hekili Forever measured it) | BUFF/DEBUFF presence on `player` and `target` for a spell saved by ID | only auras tracked in Blizzard's Cooldown Manager; presence only; a "down" on the target counts for your own debuff only |
| Remembered values (opt-in, `remember_hidden`) | last readable aura (`Platform/auras.lua`) and cooldown (`Platform/spells.lua`), restarted by your own `UNIT_SPELLCAST_SUCCEEDED` (`Platform/memory.lua`) | BUFF, BUFF_REMAIN, BUFF_STACKS on `player`; SPELL_COOLDOWN and the conditions reading `GetSpellCooldown` | can be stale after a dispel or a reset; readiness keeps the never-secret cooldown flags only |
| Totem events | `PLAYER_TOTEM_UPDATE` after your cast, last readable `GetTotemInfo` (`Platform/totems.lua`) | the TOTEM conditions | needs the totem's duration from an earlier readable read |
| Interruptible events | `UNIT_SPELLCAST_INTERRUPTIBLE` / `NOT_INTERRUPTIBLE` (`Platform/casting.lua`) | CAST_INTERRUPTABLE, CHANNEL_INTERRUPTABLE | known only after a change during the cast |
| Spell range bracket | `C_Spell.GetSpellInfo` ranges and the in-range answers of the spells on your bars (`Platform/range.lua`) | DISTANCE, when LibRangeCheck gives no answer or an open-ended one | as fine as the ranges on your bars |
| Game swing timer | `PLAYER_SWING` (`Platform/swing_timer.lua`) | NEXT_SWING (Forever only) | none known |
| Usable answer | `C_Spell.IsSpellUsable` | SPELL_USABLE | none known |
| Display gates | `UnitHealthPercent` / `UnitPowerPercent` through a step curve into `SetAlpha` (`Platform/gates.lua`) | a step's "Shown by the game when", in the preview window and as a gated glow | display only: the rotation cannot branch on it |
| Health passthrough | `UnitHealth` / `UnitHealthMax` into a StatusBar | the preview's target health bar (`preview_target_health`) | display only |

## Per condition

Retail and Forever share every classification below unless the row says
otherwise. "Unavailable" means the condition reports unavailable for that
poll. Edition gates that are not about secrets (talent layout, Assisted
Combat, ranged slot, Season of Discovery runes) are listed in
`Core/condition_support.lua` and only noted here.

| Condition | APIs / fields | Retail | Forever | Source | When a value is secret |
|---|---|---|---|---|---|
| `ACTION_CONTEXT` | vehicle/override/possess/pet battle state (`UnitHasVehicleUI`, `C_PetBattles`) | N | N | no annotation | n/a |
| `ANYSPELL_AVAIL` | `C_Spell.GetSpellCooldown` flags `isEnabled`/`isActive`/`isOnGCD` | N (flags) | N (flags) | field `NeverSecret`; in game GCD readable | times are not needed; unreadable flags: unavailable |
| `ANYSPELL_CHARGES` | `C_Spell.GetSpellCharges` `currentCharges` | C (cooldowns restricted) | C | `SecretWhenCooldownsRestricted` | unavailable |
| `ANYSPELL_COOLDOWN` | `C_Spell.GetSpellCooldown` `startTime`/`duration` | C (cooldowns restricted, per spell) | C | `SecretWhenCooldownsRestricted`; GCD readable in game | unavailable |
| `ANYSPELL_RANGE` | `C_Spell.IsSpellInRange` | N | N | no annotation | n/a |
| `ANYSPELL_REMAIN` | `C_Spell.GetSpellCharges` times | C | C | `SecretWhenCooldownsRestricted` | unavailable |
| `ASSISTED_AVAILABLE` | `C_AssistedCombat.IsAvailable` | N | n/a (no API) | no annotation | unavailable |
| `ASSISTED_ROTATION_SPELL` | `C_AssistedCombat.GetRotationSpells` | N | n/a (no API) | no annotation | unavailable |
| `ASSISTED_SUGGESTION` | `C_AssistedCombat.GetNextCastSpell` | N | n/a (no API) | no annotation | unavailable |
| `ATTACKABLE` | `UnitCanAttack`, `UnitIsDead` | N | N | no annotation | n/a |
| `BEYOND_MELEE` | `C_Spell.IsSpellInRange(6603)`, LibRangeCheck | N | N | no annotation | n/a |
| `BOSSMOD_ENCOUNTER` | boss mod addon state | n/a (edition gate) | n/a (edition gate) | `bossmodFamilies` | n/a |
| `BOSSMOD_STAGE` | boss mod addon state | n/a (edition gate) | n/a (edition gate) | `bossmodFamilies` | n/a |
| `BOSSMOD_TIMER` | boss mod addon state | n/a (edition gate) | n/a (edition gate) | `bossmodFamilies` | n/a |
| `BOSS` | `UnitClassification`, `UnitIsBossMob` (Retail and Forever only; elsewhere World Boss and skull-level elites), `UnitLevel` | N | N | no annotation | n/a |
| `BUFF` | `C_UnitAuras.GetAuraDataByIndex` `name`/`spellId`/`sourceUnit` | C (auras restricted, per spell) | C | `SecretWhenUnitAuraRestricted`, `RequiresUnitAuraAccess` | unavailable |
| `BUFF_REMAIN` | aura `expirationTime` | C | C | `SecretWhenUnitAuraRestricted` | unavailable |
| `BUFF_STACKS` | aura `applications` | C | C | `SecretWhenUnitAuraRestricted` | unavailable |
| `CARRYING` | `C_Container.GetContainerNumSlots`/`GetContainerItemInfo` | N | N | no annotation | n/a |
| `CASTING` | `UnitExists`, `UnitCastingInfo` presence | C (presence still proven by a secret name) | C | `SecretWhenUnitSpellCastRestricted` | a secret name still means casting |
| `CASTING_PROGRESS` | `UnitCastingInfo` `startTimeMs`/`endTimeMs` | C (not player/pet, per spell) | C | `SecretWhenUnitSpellCastRestricted` | unavailable |
| `CASTING_REMAIN` | `UnitCastingInfo` `endTimeMs` | C | C | `SecretWhenUnitSpellCastRestricted` | unavailable |
| `CASTING_SPELL` | `UnitCastingInfo` `name`/`castingSpellID` | C | C | `SecretWhenUnitSpellCastRestricted`; spell ID readable in game | unavailable |
| `CAST_INTERRUPTABLE` | `UnitCastingInfo` `notInterruptible` | C | C | `SecretWhenUnitSpellCastRestricted` | unavailable |
| `CASTING_ANY` | `UnitCastingInfo` and `UnitChannelInfo` presence | C (presence still proven by a secret name) | C | `SecretWhenUnitSpellCastRestricted` | a secret name still means casting or channeling |
| `CHANNELING` | `UnitChannelInfo` presence | C (presence still proven by a secret name) | C | `SecretWhenUnitSpellCastRestricted` | a secret name still means channeling |
| `CHANNELING_PROGRESS` | `UnitChannelInfo` times | C | C | `SecretWhenUnitSpellCastRestricted` | unavailable |
| `CHANNELING_REMAIN` | `UnitChannelInfo` `endTimeMs` | C | C | `SecretWhenUnitSpellCastRestricted` | unavailable |
| `CHANNELING_SPELL` | `UnitChannelInfo` `name`/`spellID` | C | C | `SecretWhenUnitSpellCastRestricted` | unavailable |
| `CHANNEL_INTERRUPTABLE` | `UnitChannelInfo` `notInterruptible` | C | C | `SecretWhenUnitSpellCastRestricted` | unavailable |
| `CLASS` | `UnitClass` class file | C (identity: secret for an NPC outside your group) | C | `SecretWhenUnitIdentityRestricted` | unavailable |
| `CLASS_GROUP` | `IsInGroup`/`IsInRaid`, `UnitClass` of group members | C (group members are readable) | C | `SecretWhenUnitIdentityRestricted` | unavailable |
| `CLASSIFICATION` | `UnitClassification` | N | N | no annotation | n/a |
| `COMBAT` | `UnitAffectingCombat` | N | N | no annotation | n/a |
| `COMBAT_HISTORY` | `UNIT_COMBAT` event (`unitTarget`, `event`, `flagText`) | C (event recorded; each field checked) | C | event carries no annotation | an unreadable action is recorded as unknown: unavailable at that position |
| `COMBAT_HISTORY_TIME` | `UNIT_COMBAT` event, `GetTime` | C | C | event carries no annotation | as COMBAT_HISTORY |
| `CREATURE` | `UnitCreatureType` type ID | C (identity: effectively secret for an NPC) | C | `SecretWhenUnitIdentityRestricted` | unavailable |
| `DEAD` | `UnitIsDeadOrGhost` | N | N | no annotation | n/a |
| `DEBUFF` | `C_UnitAuras.GetAuraDataByIndex` | C (auras restricted, per spell) | C | `SecretWhenUnitAuraRestricted` | unavailable |
| `DEBUFF_REMAIN` | aura `expirationTime` | C | C | `SecretWhenUnitAuraRestricted` | unavailable |
| `DEBUFF_STACKS` | aura `applications` | C | C | `SecretWhenUnitAuraRestricted` | unavailable |
| `DISPELLABLE` | aura `dispelName` (dispellable filter) | C | C | `SecretWhenUnitAuraRestricted` | unavailable |
| `DISTANCE` | LibRangeCheck (item/interact/spell range) | N | N | no annotation on the range APIs | n/a |
| `DISTANCE_COUNT` | `NAME_PLATE_UNIT_ADDED/REMOVED` tokens, `UnitExists`, `UnitIsEnemy`, LibRangeCheck, `nameplateMaxDistance`; with In Combat, `UnitAffectingCombat` of each counted token | C (nameplate tokens; an NPC GUID is secret, so no GUID is read) | C | events carry no annotation; `UnitGUID` `SecretWhenUnitIdentityRestricted`; `UnitAffectingCombat` is `SecretArguments` only, its answer plain (still read through `CanReadValue`; unverified in game) | unavailable |
| `ECLIPSE` | `GetEclipseDirection` (direction), `UnitPower("player", Enum.PowerType.Balance)` (energy), `UnitClass` | n/a (edition gate) | n/a (edition gate) | `no-eclipse`: Wrath through Mists only | n/a |
| `ENCOUNTER` | `C_InstanceEncounter.IsEncounterInProgress` | N | N | no annotation; returns a non-nilable bool | n/a |
| `ELITE` | `UnitClassification` (Elite, Rare Elite or World Boss) | N | N | no annotation | n/a |
| `ENEMIES_TARGETING` | nameplate tokens `nameplate1`-`40`: `UnitExists`, `UnitCanAttack`, `UnitIsUnit("nameplateNtarget", "player")` | C (compound-token comparison is secret on restricted maps) | C | `SecretWhenUnitComparisonRestricted` | unavailable |
| `ENEMY` | `UnitIsEnemy` | N | N | no annotation | n/a |
| `EQUIPPED` | `C_Item.IsEquippedItem` | N | N | no annotation | n/a |
| `FORM` | `GetShapeshiftForm`, `GetShapeshiftFormInfo`/`GetShapeshiftFormID` | C (undocumented; checked) | C | not in the generated documentation | unavailable |
| `FRIENDLY` | `UnitIsFriend` | N | N | no annotation | n/a |
| `GLYPH` | glyph socket APIs | n/a (glyph layout gate) | n/a | `glyphLayout` | n/a |
| `GROUP` | `IsInGroup`, `IsInRaid` | N | N | undocumented, group state | n/a |
| `GROUP_COUNT` | `GetNumGroupMembers`, `IsInRaid`; `UnitGroupRolesAssigned` (a role) or `UnitIsDeadOrGhost` (dead) of `player` / `party1-4` / `raid1-40`; every count includes you | N (size, dead); C (roles: identity, a group member is readable) | N; C | no annotation on `UnitIsDeadOrGhost` or the group size; `SecretWhenUnitIdentityRestricted` on roles, which are not offered on Classic Era or Burning Crusade (`no-group-roles`: the function exists there, but nothing shows a role can be assigned) | an unreadable member makes the count unavailable |
| `HEALTH` | `UnitHealth` | A (`secret-health`) | A (`secret-health`) | `SecretReturns`; in game | unsupported |
| `HEALTHPCT` | `UnitHealth`, `UnitHealthMax` | A (`secret-health`) | A (`secret-health`) | `SecretReturns`, `SecretWhenUnitHealthMaxRestricted`; in game | unsupported |
| `HERO_TALENT` | `C_ClassTalents.GetActiveHeroTalentSpec` | N (Retail only: `retail-only`) | n/a (`retail-only`) | no annotation | n/a |
| `IMMUNE` | MobInfo2 data by `UnitName`, `UnitLevel` | C (name identity: secret for an NPC) | C | `SecretWhenUnitNameIdentityRestricted` | unavailable |
| `INCONTROL` | `HasFullControl` | N | N | no annotation | n/a |
| `INSTANCE` | `IsInInstance`; optional difficulty and instance ID from `GetInstanceInfo` `difficultyID` / `instanceID` | N | N | no annotation | a malformed value: unavailable |
| `ISSAME` | `UnitIsUnit` | C (compound tokens; restricted maps) | C | `SecretWhenUnitComparisonRestricted`, `RequiresComparableUnitTokens` | unavailable |
| `ITEM` | `C_Item.GetItemCount` | N | N | no annotation | n/a |
| `ITEM_COOLDOWN` | `C_Item.GetItemCooldown` / `C_Container.GetItemCooldown`; with a trinket slot, the equipped item from the build context (`GetInventoryItemID`) | N | N | no annotation | n/a (a slot with no use effect: unavailable) |
| `ITEM_RANGE` | `C_Item.IsItemInRange` | N | N | no annotation | n/a |
| `KEYSTONE_LEVEL` | `C_ChallengeMode.IsChallengeModeActive`, `GetActiveKeystoneInfo` | N (Retail only: `retail-only`) | n/a (`retail-only`) | no annotation | unavailable |
| `LEVEL` | `UnitLevel` | N | N | no annotation | n/a |
| `LOC_BLOCKED` | `C_LossOfControl.GetActiveLossOfControlData` `lockoutSchool` | N (player) | N | no annotation (only `...ByUnit` is restricted) | n/a |
| `LOC_TYPE` | `C_LossOfControl.GetActiveLossOfControlData` `locType`/`timeRemaining` | N (player) | N | no annotation | n/a |
| `MANA` | `UnitPower(unit, Mana)` | A unless Mana is flagged never secret (`secret-power`) | A unless flagged | `SecretWhenUnitPowerRestricted` | unsupported; if supported, unavailable |
| `MANAPCT` | `UnitPower`, `UnitPowerMax` (Mana) | A unless flagged (`secret-power`) | A unless flagged | `SecretWhenUnitPowerRestricted`, `SecretWhenUnitPowerMaxRestricted` | unsupported; if supported, unavailable |
| `UNIT_EXISTS` | `UnitExists` or group-unit resolution | N (marked-unit selectors disabled) | N (marked-unit selectors disabled) | unit presence | unavailable when the selected unit cannot be resolved |
| `RAID_ROLE` | `IsInRaid`, `UnitIsGroupLeader`, `UnitIsGroupAssistant` | N | N | group-role APIs | false outside a raid; unavailable when the role cannot be read |
| `MARKED` | `UnitExists`, `GetRaidTargetIndex(unit)` | A (`unsupported-client`) | A (`unsupported-client`) | Retail in-game test returned a secret marker | unavailable on these clients, also under NOT |
| `MARK_COUNT` | marker table and reachable unit observations | A (`unsupported-client`) | A (`unsupported-client`) | same marker restriction as MARKED | unavailable on these clients |
| `MOVING` | `GetUnitSpeed("player")`; when it is secret, `PLAYER_STARTED_MOVING` / `PLAYER_STOPPED_MOVING` and the last readable speed (`Platform/player_movement.lua`) | C (stats restricted; the events are not annotated) | C | `SecretWhenUnitStatsRestricted` on the speed only | answered from the events; unavailable only before the first event or readable speed |
| `NEXT_SWING` | `PLAYER_SWING(swingDuration, swingType)`, `GetTime` | n/a (no `C_SwingTimer`) | N (payload plain in combat per Hekili Forever's probes) | no annotation | n/a |
| `OUTDOORS` | `IsOutdoors` | N | N | no annotation | n/a |
| `PET` | `UnitExists("pet")` | N | N | no annotation | n/a |
| `PET_HAPPINESS` | `GetPetHappiness` | n/a (edition gate) | n/a (edition gate) | `no-pet-happiness`: Classic Era, Burning Crusade and Wrath only | n/a |
| `PET_NAME` | `GetUnitName("pet")` (`UnitName`) | C (your pet is player-controlled: readable) | C | `SecretWhenUnitNameIdentityRestricted` | unavailable |
| `PETSPELL_ACTIVE` | `C_Spell.IsCurrentSpell` | N | N | no annotation | n/a |
| `PETSPELL_AVAIL` | cooldown flags (pet bank) | N (flags) | N (flags) | field `NeverSecret` | unavailable |
| `PETSPELL_CHARGES` | `C_Spell.GetSpellCharges` | C | C | `SecretWhenCooldownsRestricted` | unavailable |
| `PETSPELL_COOLDOWN` | `C_Spell.GetSpellCooldown` times | C | C | `SecretWhenCooldownsRestricted` | unavailable |
| `PETSPELL_HISTORY` | `UNIT_SPELLCAST_SUCCEEDED` (pet) | C (event recorded; secret spell recorded as unknown) | C | `SecretWhenUnitSpellCastRestricted`: the pet is readable unless the spell is flagged | unavailable at that position |
| `PETSPELL_HISTORY_TIME` | `UNIT_SPELLCAST_SUCCEEDED` (pet), `GetTime` | C | C | as above | unavailable within the window |
| `PETSPELL_RANGE` | `C_Spell.IsSpellInRange` | N | N | no annotation | n/a |
| `PETSPELL_REMAIN` | `C_Spell.GetSpellCharges` times | C | C | `SecretWhenCooldownsRestricted` | unavailable |
| `PLAYER_STATE` | one of `IsMounted`, `IsSwimming`, `IsFlying`, `IsFalling`, `IsResting`, `UnitIsDead`, or `UnitIsDeadOrGhost` with `UnitIsDead` (ghost) | N | N | `SecretArguments` only; no secret return | n/a |
| `POINT` | `UnitPower`/`UnitPowerMax` of a secondary resource | N for the never-secret secondary resources | N | `SecretWhenUnitPowerRestricted`; Blizzard's never-secret list | unavailable for any other type |
| `POWER` | `UnitPowerType`, `UnitPower` | A when no primary type is flagged never secret (`secret-power`), else C | same | `SecretWhenUnitPowerRestricted` | unsupported; if supported, unavailable |
| `POWERPCT` | `UnitPowerType`, `UnitPower`, `UnitPowerMax` | as POWER | as POWER | `SecretWhenUnitPowerRestricted`, `SecretWhenUnitPowerMaxRestricted` | as POWER |
| `PRIMARY_TALENT_TREE` | talent tree APIs | n/a (talent layout gate) | n/a (talent layout gate) | `treeLayout` | n/a |
| `PROXIMITY` | `UnitPosition`, `UnitIsUnit`, group | N (positions are nil on restricted maps) | N | no annotation on `UnitPosition` | unavailable |
| `PROXIMITY_HEALTH` | + `UnitHealth`/`UnitHealthMax` | A (`secret-health`) | A | `SecretReturns` | unsupported |
| `PROXIMITY_HEALTH_COUNT` | + `UnitHealth`/`UnitHealthMax` | A (`secret-health`) | A | `SecretReturns` | unsupported |
| `PROXIMITY_HEALTHPCT` | + `UnitHealth`/`UnitHealthMax` | A (`secret-health`) | A | `SecretReturns` | unsupported |
| `PROXIMITY_HEALTHPCT_COUNT` | + `UnitHealth`/`UnitHealthMax` | A (`secret-health`) | A | `SecretReturns` | unsupported |
| `PROXIMITY_MANA` | + `UnitPower` (Mana) | A unless Mana is flagged never secret | A unless flagged | `SecretWhenUnitPowerRestricted` | unsupported |
| `PROXIMITY_MANA_COUNT` | + `UnitPower` (Mana) | A unless flagged | A unless flagged | `SecretWhenUnitPowerRestricted` | unsupported |
| `PROXIMITY_MANAPCT` | + `UnitPower`/`UnitPowerMax` (Mana) | A unless flagged | A unless flagged | `SecretWhenUnitPowerRestricted` | unsupported |
| `PROXIMITY_MANAPCT_COUNT` | + `UnitPower`/`UnitPowerMax` (Mana) | A unless flagged | A unless flagged | `SecretWhenUnitPowerRestricted` | unsupported |
| `PVP` | `UnitIsPVP` | C (identity) | C | `SecretWhenUnitIdentityRestricted` | unavailable |
| `RECENT_KILL` | `PARTY_KILL` event time, `GetTime` | N (the event fires; its GUIDs are not read) | N | `SecretWhenUnitIdentityRestricted` on the GUID payload only | n/a |
| `RESIST` | MobInfo2 data by `UnitName`, `UnitLevel` | C (name identity) | C | `SecretWhenUnitNameIdentityRestricted` | unavailable |
| `ROLE` | `C_SpecializationInfo.GetInspectSpecialization` / `GetTalentGroupRole` | C (identity; group members readable) | C | `SecretWhenUnitIdentityRestricted` | unavailable |
| `RUNE` | `GetRuneType`, `GetRuneCooldown` | N (`GetRuneType` is undocumented; missing API is reported as such) | N | no annotation on `GetRuneCooldown`; Runes are never secret | n/a |
| `RUNE_COOLDOWN` | `GetRuneCooldown` | N | N | no annotation | n/a |
| `RUNE_ENGRAVED` | `C_Engraving` | n/a (Season of Discovery only) | n/a | missing API | n/a |
| `RUNNER` | MobInfo2 data by `UnitName`, `UnitLevel` | C (name identity) | C | `SecretWhenUnitNameIdentityRestricted` | unavailable |
| `SELF_LEVEL` | `UnitLevel("player")` | N | N | no annotation | n/a |
| `SET_PIECES` | `GetInventoryItemID` | N | N | undocumented, inventory | n/a |
| `SPECIALIZATION` | `C_SpecializationInfo.GetSpecialization` | N | n/a for your own class (no specializations) | no annotation | n/a |
| `SPELL_ACTIVE` | `C_Spell.IsCurrentSpell` | N | N | no annotation | n/a |
| `SPELL_AUTOREPEAT` | `C_Spell.IsAutoRepeatSpell` | N | N | no annotation | n/a |
| `SPELL_AVAIL` | cooldown flags `isEnabled`/`isActive`/`isOnGCD` | N (flags) | N (flags) | field `NeverSecret`; in game | unreadable flags: unavailable |
| `SPELL_CHARGES` | `C_Spell.GetSpellCharges` `currentCharges` | C | C | `SecretWhenCooldownsRestricted` (`maxCharges`, `isActive` `NeverSecret`) | unavailable |
| `SPELL_COOLDOWN` | `C_Spell.GetSpellCooldown` times | C (per spell; the GCD is readable) | C | `SecretWhenCooldownsRestricted`; in game | unavailable |
| `SPELL_GLOW` | `C_SpellActivationOverlay.IsSpellOverlayed` (the spell and its base and override IDs) | N | N | `SecretArguments` only; the proc glow is plain even where the aura behind it is not | an unreadable relative leaves "not glowing" unproven: unavailable |
| `SPELL_USABLE` | `C_Spell.IsSpellUsable` (`usable`, `insufficientPower`) | N | N | no annotation; Hekili Forever reads it in combat for every spender | an unreadable answer: unavailable |
| `SPELL_HISTORY` | `UNIT_SPELLCAST_SUCCEEDED` (player) | C (event recorded; secret spell recorded as unknown) | C | `SecretWhenUnitSpellCastRestricted`: the player is readable unless the spell is flagged | unavailable at that position |
| `SPELL_HISTORY_TIME` | `UNIT_SPELLCAST_SUCCEEDED` (player), `GetTime` | C | C | as above | unavailable within the window |
| `SPELL_KNOWN` | `C_SpellBook.IsSpellKnown` | N | N | no annotation | n/a |
| `SPELL_RANGE` | `C_Spell.IsSpellInRange` | N | N | no annotation | n/a |
| `SPELL_REMAIN` | `C_Spell.GetSpellCharges` times | C | C | `SecretWhenCooldownsRestricted` | unavailable |
| `STAGGER` | `UnitStagger`, `UnitHealthMax` (percent form) | C (`ConditionalSecret`; maximum health is secret, so the percent form is unavailable) | C | field `ConditionalSecret`; `SecretWhenUnitHealthMaxRestricted` | unavailable |
| `STAT` | `UnitStat`, `UnitArmor` | C (stats restricted) | C | `SecretWhenUnitStatsRestricted` | unavailable |
| `STEALABLE` | aura `isStealable` | C | C | `SecretWhenUnitAuraRestricted` | unavailable |
| `STEALTHED` | `IsStealthed` | N | N | no annotation | n/a |
| `SWING_TIME` | `UnitAttackSpeed`; with Ranged, `UnitRangedDamage` | C (stats restricted) | C | `SecretWhenUnitStatsRestricted` on both | unavailable |
| `SWING_TIME_REMAIN` | swing timestamps from the combat log (Auto Shot and wand shots with Ranged, plus `UnitRangedDamage`) | A (`combat-log-unavailable`) | A | `SecureOnly` combat log | unsupported |
| `TALENT` | talent / trait APIs | N (layout gate) | N (layout gate) | no annotation | n/a |
| `TALENT_TREE_POINTS` | talent tree APIs | n/a (talent layout gate) | n/a (talent layout gate) | `treeLayout` | n/a |
| `THREAT` | `UnitIsEnemy`, `UnitThreatSituation("player", unit)` | C (generally readable against target or a nameplate) | C | `SecretWhenUnitThreatStateRestricted` | unavailable |
| `THREAT_COUNT` | nameplate tokens, `UnitThreatSituation` | C (nameplate tokens; no GUID read) | C | `SecretWhenUnitThreatStateRestricted`; `UnitGUID` identity-restricted | unavailable |
| `TIME_IN_COMBAT` | `PLAYER_REGEN_DISABLED` time, `GetTime` | N | N | no annotation | n/a |
| `TOTEM` | `GetTotemInfo` | C (totem slots restricted, per totem) | C | `SecretWhenTotemSlotSecret` | unavailable |
| `TOTEM_REMAIN` | `GetTotemInfo` times | C | C | `SecretWhenTotemSlotSecret` | unavailable |
| `TOTEM_SPELL` | `GetNumTotemSlots`, `GetTotemInfo` | C | C | `SecretWhenTotemSlotSecret` | unavailable |
| `TOTEM_SPELL_REMAIN` | `GetTotemInfo` times | C | C | `SecretWhenTotemSlotSecret` | unavailable |
| `TT_HEALTH` | `UnitHealth`, damage history from the combat log | A (`secret-health`, and `combat-log-unavailable`) | A | `SecretReturns`; `SecureOnly` combat log | unsupported |
| `TT_HEALTHPCT` | `UnitHealth`, `UnitHealthMax`, combat log | A (`secret-health`, and `combat-log-unavailable`) | A | as TT_HEALTH | unsupported |
| `WEAPON` | `GetWeaponEnchantInfo` | N | N | undocumented (Forever documents `C_Item.GetWeaponEnchantInfo` without annotation) | n/a |
| `WEAPON_IMBUE` | `GetWeaponEnchantInfo` enchant ID | N | N | as WEAPON | n/a |
| `WEAPON_REMAIN` | `GetWeaponEnchantInfo` expiration | N | N | as WEAPON | n/a |
| `WEAPON_STACKS` | `GetWeaponEnchantInfo` charges | N | N | as WEAPON | n/a |
| `WEAPON_TYPE` | equipped item class | N (no ranged slot on Retail) | N | edition gate | n/a |
| `ZONE` | `GetZoneText`, `GetSubZoneText` | N | N | no annotation | n/a |
| `ZONEPVP` | `C_PvP.GetZonePVPInfo` | N | N | no annotation | n/a |

## Unit types

| Unit type | APIs | Retail | Forever | Source | When a value is secret |
|---|---|---|---|---|---|
| `focus`, `focustarget` | probe: `C_EventUtils.IsEventValid("PLAYER_FOCUS_CHANGED")`, `FocusUnit`, `FocusFrame` | N | N | not read, only probed | n/a |
| `maintank`, `mainassist` | `GetRaidRosterInfo` role field over `raid1-40` (raids only) | N (group members) | N | undocumented, unannotated | an unreadable member: the unit is unavailable |
| `assignedtank`, `assignedhealer` | `UnitGroupRolesAssigned` over `player`/`party1-4`/`raid1-40` | C (identity; a group member is readable) | C | `SecretWhenUnitIdentityRestricted`; not Classic Era or Burning Crusade (`no-group-roles`) | an unreadable member: the unit is unavailable |
| `groupleader` | `UnitIsGroupLeader` over the same tokens | C (identity; a group member is readable) | C | `SecretWhenUnitIdentityRestricted` | an unreadable member: the unit is unavailable |
| `skull`, `cross`, `square`, `moon`, `triangle`, `diamond`, `circle`, `star`, `anymark` | marker table over reachable unit tokens | A (`unsupported-client`) | A (`unsupported-client`) | same marker restriction as MARKED | saved uses unavailable; omitted from unit selectors |

The Set Mark step calls `SetRaidTarget` directly when its conditions match. It does not check marker state or raid
permissions. Retail rejected the call as protected in game; RM skips it on Retail and Forever.

A condition on a resolved unit then reads what that condition always reads of a
unit token, so on Retail and Forever only the non-secret facts of a group member
are usable (docs/unit-types.md).

## Settings that read game data

| Setting | APIs | Retail | Forever | Source | When a value is secret |
|---|---|---|---|---|---|
| Ignore Mana (`ignore_mana`) | `C_Spell.IsSpellUsable` (`usable`, `noMana`) | N | N | no annotation | a hidden answer is never accepted: the spell is skipped, with or without the option (the General help says so on these clients) |
| Ignore Range (`ignore_range`) | none: the range read is skipped | n/a | n/a | n/a | nothing is read, so nothing can be secret; learned, usable, cooldown and conditions still apply |
| Ignore Moving (`ignore_moving`); off, a spell with a cast time is not ready while you move | `Platform:GetPlayerMovementObservation` (`GetUnitSpeed`, or the movement events when it is secret), `C_Spell.GetSpellInfo` `castTime` | N (events) | N (events) | the speed is `SecretWhenUnitStatsRestricted`; the events and `castTime` carry no annotation | unknown movement counts as not moving; an unreadable cast time lets the spell through |

The preview window can use its own copies of these three options (`preview_readiness`, `preview_ignore_mana`,
`preview_ignore_range`, `preview_ignore_moving`); both engines then judge each matching step under both sets of options in
one walk, so the bar glow and the preview can differ. With the option off, or the same values, it is one judgment.

`IsUsableSpell` answers `false, true` when only the resource is missing (the pair action bars color blue); the option
accepts that pair as well as a usable spell. Unverified in game on Retail and Forever.

## Event sources on restricted clients

`main.lua` registers, under the restricted policy, only the events whose
payloads reach addons, and their handlers check every field before it is
compared or used as a key (`wrapCombatEvent`'s restricted variant):

| Event | Annotation | Feeds | Unreadable field |
|---|---|---|---|
| `UNIT_SPELLCAST_SUCCEEDED` (player, pet; `RegisterUnitEvent`) | `SecretWhenUnitSpellCastRestricted` | SPELL_HISTORY, PETSPELL_HISTORY and their _TIME forms | a secret unit is dropped; a secret spell ID is recorded as `spell = false` (unknown) |
| `UNIT_COMBAT` | none | COMBAT_HISTORY, COMBAT_HISTORY_TIME | a secret unit is dropped; a secret action or flag text is recorded as `action = false`; a secret amount or school is not stored |
| `NAME_PLATE_UNIT_ADDED`, `NAME_PLATE_UNIT_REMOVED` | none | `addon.nameplateUnits` (token set) for THREAT_COUNT, DISTANCE_COUNT | a secret token is dropped |
| `COMBAT_LOG_EVENT_UNFILTERED` | `HasRestrictions`; payload only via `C_CombatLogSecure` (`SecureOnly`) | nothing: not registered | n/a |

The other spellcast events (`SENT`, `START`, `STOP`, channel, interrupt) feed
announcements only; announcements stay on the probe policy.

The GUID-keyed `addon.unitsInRange` snapshot and its per-poll refresh do not
run on restricted clients: `UnitGUID` of an NPC is secret there
(`SecretWhenUnitIdentityRestricted`), so it can be neither compared nor used
as a key. Restricted clients keep `addon.nameplateUnits` instead: the
nameplate tokens currently shown, seeded from `nameplate1`..`nameplate40` on
enable and kept by the nameplate events. Each token is read live when a
condition runs, so a vanished token reads absent and a reused one is simply the
unit now on that plate.

## Not built

- **Display-only highlights from secret values.** A secret value cannot be
  compared, but it visibly drives a frame: in game, a secret passed through a
  `C_CurveUtil` curve to `SetAlpha` made a fill appear and disappear at the
  threshold. That would give a highlight such as "target below 20% health"
  without RM reading the value, but it could never feed a rotation decision, and
  RM has none.
- **Encounter timeline (`C_EncounterTimeline`).** Blizzard's generated
  documentation marks an event's spell, icon and severity `SecretWhenEncounterEvent`
  and its ID, source and duration `NeverSecret`; `GetEventState` and
  `GetEventTimeRemaining` carry no annotation. A condition for "a boss ability
  is due in N seconds" depends on which of those a real encounter reveals, so
  there is none; `/rm debug timeline [seconds]` records what a real encounter hands an addon.
- **Per-spell static support.** `C_Secrets.GetSpellCooldownSecrecy`,
  `GetSpellAuraSecrecy` and `GetSpellCastSecrecy` return a spell's
  `Enum.SecrecyLevel`. RM reads them only for the editor note (above): a
  condition naming a spell flagged `AlwaysSecret` is still unavailable at every
  poll rather than declared unsupported for that saved value, and what those
  calls report in a real client is unconfirmed.
