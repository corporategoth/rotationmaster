# Blizzard Assisted Combat

In Retail Midnight (12.x) most combat data is a secret value while you are in
combat: your own buffs, the target's debuffs, cooldown times, most primary
resources and every unit's health. A hand-written priority that reads them
stops working once the pull starts. Blizzard's own Assisted Combat pick (the
one-button assistant and the action bar highlight) can still be read, so it is
the one source of in-combat rotation advice an addon has left. MaxDps now
takes its main recommendation from it.

Rotation Master reads it in two ways.

- **Step: Blizzard's suggestion** (action type `assisted`, rotation list only,
  no `action` field). When its conditions match, the step recommends whatever
  spell Assisted Combat suggests at that moment. It highlights that spell's
  button, shows in the preview window and is held to the same requirements as
  a spell step: known, usable, ready and in range. If nothing is suggested,
  the spell is on none of your bars, or it is not ready, the step is skipped
  and lower steps are tried.
- **Condition: Assisted Combat Suggestion** (`ASSISTED_SUGGESTION`, in the
  Spells category). With a spell chosen, it is true when that spell is the
  suggestion; an override and its base spell count as the same spell. With no
  spell chosen, it is true whenever anything is suggested.

A Retail premade can then take this shape: stop while casting, then
upkeep, interrupts, defensives and cooldowns that Assisted Combat leaves out
as independent highlights, then one "Blizzard's suggestion" step in the
rotation.

## API contract

From Blizzard's generated API documentation in the Gethe/wow-ui-source mirror,
`Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua`:

| Function | Returns |
|---|---|
| `C_AssistedCombat.GetNextCastSpell(checkForVisibleButton=false)` | `spellID` or nil |
| `C_AssistedCombat.GetRotationSpells()` | array of spell IDs, never nil |
| `C_AssistedCombat.GetActionSpell()` | the one-button action's spell ID, or nil |
| `C_AssistedCombat.IsAvailable()` | `isAvailable`, `failureReason` |
| event `ASSISTED_COMBAT_ACTION_SPELL_CAST` | synchronous |

- `live` e7aa82019dc298e0351c7159d60c2a9b916b9b67 (12.1.5.70529, 2026-10-22).
  `GetNextCastSpell` carries `SecretArguments = "AllowedWhenUntainted"`. The
  return value is not marked secret. `Blizzard_ActionBar/Mainline/AssistedCombatManager.lua`
  polls `GetNextCastSpell(true)` from an OnUpdate at the
  `assistedCombatIconUpdateRate` CVar and compares the result with each
  button's spell ID.
- `forever` ca8368f2f2380cbe696854f7f2646387c278a61b (1.60.1.70532): the same
  file, byte for byte (sha256 a627eaac…).
- `classic` 45eb466d (5.5.4), `classic_era` 8165d4cd (1.15.9) and
  `classic_anniversary` 2cfec7c0 (2.5.6) declare the same four functions
  without the secret-argument note (sha256 edf6dfd6…) but ship no
  AssistedCombatManager. A Classic-family client may therefore expose the
  namespace while `IsAvailable()` returns false.

`Platform/assisted_combat.lua` wraps these. Each function is feature-detected
and protected. It returns a value and a reason: nil plus `missing-api`,
`api-error`, `restricted-value`, `assisted-unavailable` or
`invalid-api-result` when nothing usable could be read, and false when the
game has no suggestion. The step reads `GetNextCastSpell(false)`, so a suggestion counts
even when it is not on a visible button. It then tries the spell, its base
spell (`C_Spell.GetBaseSpell`) and its current override
(`C_Spell.GetOverrideSpell`) against the action bars.

## Behaviour and cost

- The condition is unavailable, not false, when the API is missing, the value
  cannot be read or Assisted Combat is unavailable for this character or spec.
  That holds under NOT too. "Nothing suggested" is a real false.
- On TBC, Era and other clients without the namespace, the step is skipped and
  the condition is unavailable (`missing-api`). Neither raises an error.
- Rotations that do not use the step do no extra work per poll. The lean
  engine reaches the assisted branch only for a step that has no `action`.
  The bench's call counts and allocation for the default fixture are
  unchanged.
- The suggestion is read fresh on every evaluation and never cached between
  polls.
- `ROTATIONMASTER_SPELL_UPDATE` messages and WeakAuras events report the
  step's type as `assisted` and the resolved spell ID.
- The legacy validator, `Data/validation.lua`, the website's `schema/rotation.mjs`
  (now in the separate `wow/rotationmaster-web` repository),
  export/import and clone all accept the step. An `assisted` step that carries
  an `action`, or one in the cooldown list, is reported unsupported
  (`unexpected-assisted-action`, `assisted-in-optional-list`).

## Retail limits

- **Readiness in combat.** The step is held to the same readiness check as a
  spell step. On Retail and Forever, `C_Spell.GetSpellCooldown` is
  `SecretWhenCooldownsRestricted`. In combat, encounters, challenge modes and
  PvP matches it hides `startTime`, `duration` and `modRate`. Its
  `isEnabled`, `isActive` and `isOnGCD` flags are documented `NeverSecret`
  (`SpellSharedDocumentation.lua`, identical on `live` e7aa82019d and
  `forever` ca8368f2f2). When only the times are hidden,
  `Platform:IsSpellReady` decides from the flags, with the meaning the times
  give it:
  - a held cooldown (`isEnabled` false) is not ready;
  - an inactive one is ready;
  - an active one is ready only while it is the global cooldown.

  Blizzard says `isOnGCD` can be trusted only at `SPELL_UPDATE_COOLDOWN`, so
  RM counts "on the GCD" only while the global cooldown is actually running.
  If `isOnGCD` is missing, RM decides only when no GCD is running. Flags that
  cannot be read leave the spell unavailable, never ready. So spell steps,
  this one included, and Spell Available now work in combat.

  One case may still differ from the times. A spell whose own cooldown ends
  inside the current GCD shows as not ready if the client reports it as on its
  own cooldown, until the client reports the GCD instead. With readable times
  (TBC, Era, Retail out of combat) nothing changes. Those clients make the
  same decisions with the same calls, and they never read the flags.
- **Conditions that need a time stay unavailable in combat.** Spell
  Cooldown (`SPELL_COOLDOWN`, a remaining-seconds comparison), Spell Recharge
  Time (`SPELL_REMAIN`) and Spell Charges (`SPELL_CHARGES`) need numbers that
  are secret: `SpellChargeInfo` leaves only `maxCharges` and `isActive`
  readable. A flag never stands in for a number. In particular, an inactive
  recharge is not read as full charges, and an inactive cooldown is not read
  as zero seconds, because that would answer only one side of a comparison.
  The pet and any-spell variants behave the same way.
- `C_Spell.IsSpellUsable`, `IsSpellInRange` and `SpellHasRange` carry no secret
  annotation on either branch, so RM reads them as usual. If one were secret
  after all, the spell would be unavailable.
- **Class resources (Points) in combat.** `UnitPower` and `GetComboPoints`
  are `SecretWhenUnitPowerRestricted`: secret "for power types not explicitly
  flagged as being never secret, unless the subject unit does not have a power
  of this type". `UnitPowerMax` is `SecretWhenUnitPowerMaxRestricted`: secret
  only for units that are not player-controlled, with per-type flags taking
  priority (`UnitDocumentation.lua`, `SecretPredicatesDocumentation.lua`,
  identical on `live` e7aa82019d and `forever` ca8368f2f2). The documentation
  does not list the flagged types. That flag is client data, and
  `C_Secrets.GetPowerTypeSecrecy` reads it. Blizzard named the player's
  secondary resources it stopped making secret during the 12.0.0 beta (compiled
  on warcraft.wiki.gg, Patch 12.0.0/Planned API changes): Combo Points, Runes,
  Soul Shards, Holy Power, Chi, Arcane Charges and Essence. Primary resources
  stay secret. Under the `restricted` policy, Points (`POINT`) reads only those
  types, matched by `Enum.PowerType` name. Every value still goes through
  `CanReadValue`, so a secret one makes Points unavailable instead of
  returning a number. Retail maps Paladin to Holy Power and Evoker to Essence.
  The other classes keep the shared map: Death Knight Runes, Warlock Soul
  Shards, Monk Chi, Mage Arcane Charges, everyone else Combo Points. TBC keeps
  that map, its transport and its calls unchanged. Era and progression select
  per expansion and specialization instead (see
  [Era and progression Points](architecture/condition-modernization-audit.md#era-and-progression-point-resources)).
  Copies saved from an older Points source still use the old
  `GetConditionPointResource` and stay unavailable on these clients.
- **Needs in-game confirmation:** that the cooldown flags really are readable
  in combat, how `isOnGCD` behaves when polled (and whether it is nil), and
  that usability and range stay readable. For Points: that
  `C_Secrets.GetPowerTypeSecrecy` reports the seven types as never secret on
  Retail and on Forever (Blizzard's list was for Midnight). Also that
  `UnitPower("player", Enum.PowerType.Runes)` counts ready runes.
- The condition and step have not been tested on a live Retail client. The
  tests use a modelled `C_AssistedCombat` built from the documentation.
  `tests/retail_combat_readiness.lua` models the secret cooldown times the
  same way.
- The condition reuses the Spell Available icon until original artwork exists
  (`tests/condition_icons.lua` lists it as pending).
- Packaged rotations still never auto-select on Retail or Forever, because
  `combatDataPolicy` is `restricted` there. Retail premades are a separate task.
