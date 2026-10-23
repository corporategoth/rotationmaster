# Packaged rotations

Definitions in this folder are addon data and read-only in game. They appear in the declared class’s list, including disabled and otherwise inapplicable definitions for that class. Explicit Universal definitions are shared. Enable preferences live in the profile's `rotationLibrary.preferences`. Clone creates an independent per-spec custom body in the existing SavedVariables rotation store; `rotationLibrary.origins` keeps its manifest, source revision, baseline and step origins. The default is never copied into that editable store automatically. Editing a clone cannot alter its source. Changing profiles rebinds preferences; no source pack overwrites saved rotations or the user's existing fallback.

Authoring requirements: version 1 envelope, stable pack ID/revision and step IDs, explicit edition/action context, localized name/description keys, provenance and independent condition tables. Packaged definitions declare a class or explicitly declare Universal applicability; specialization may be omitted. Unknown condition/schema/edition data remains visible but unavailable for execution. Roles and intent selectors currently remain reference-only until their context providers are implemented; do not silently treat them as universal. `rulesets` selects by season and game rules from the build context: any listed token that is active matches (`standard`, `hardcore`, `self-found`, `season:<id>`, `season:<seasonname>`, `mode:<id>`). Packs for a vehicle, possession, override bar or pet battle declare that `actionContext`; they are chosen only while that bar is up and may reference gear through the `SET_PIECES`, `EQUIPPED` and `WEAPON_IMBUE` conditions. Retail/Forever defaults remain reference-only under the current restricted-data policy.

Run `python3 tools/check`. Class scenario suites such as `tests/defaults_tbc_shaman.lua` load real predicates and the shipped packs and exercise switches, priorities, Stops and upkeep. The shared native roster/editor now shows packaged and custom definitions with the same read-only/editable card layout.

`tests/default_corpus.lua` automatically loads every direct `Defaults/` Lua entry in the TOC across five synthetic client families and thirteen class tokens. It checks source/review metadata, English name/description coverage, schema resolution on matching editions/classes, nested stable IDs, definition validation, visibility, read-only isolation, enable/disable and runtime exclusion at sampled level/spec/build/context boundaries. Invalid-manifest probes verify the guard rejects missing translations/sources, invalid dates and incomplete conditions/branches. It never evaluates combat conditions. This is an authoring/selection gate; it adds neither class coverage nor gameplay scenarios, and synthetic declarations do not certify live APIs or recommendation quality. Add pack-specific behavioral scenarios alongside new packs.

Default, clone and import validation share effective global/profile item-set references, with a nonnil profile entry taking precedence. Dependency additions/removals and registered schema changes refresh catalog validation without reload; unchanged lookups do not revalidate all packaged graphs. A structurally valid packaged source remains visible with diagnostics if a changed condition schema makes it invalid. Runtime eligibility keeps that source inert; custom saves still use strict current-schema validation. Extensions should change schemas through RegisterCondition/UnregisterCondition rather than silently mutating nested fields.

A shared leveling pack is appropriate when removing unavailable spells from its later-level priorities leaves the correct early priority order. A change in relative order due to talents or mechanics requires an explicit conditional branch or a distinct automatically selected pack; spell availability alone must not be assumed to prove equivalence.

## TBC Mage, Warlock and Priest premades

These replace the bracketed Mage, Warlock and Priest previews (removed with their tests; saved clones of them keep working). Each premade covers a role from level 1 (or its first talent point) to 70; variants of a role share a switch and the recommended one has the higher priority. Shared steps live in `Defaults/blocks/{mage,warlock,priest}.lua`.

| Premade | Switch, priority | Notes |
|---|---|---|
| `rm.tbc.mage.frost` | knows Fireball, 0 (catch-all, also unspecced) | Frostbolt; Frost Nova when attacked (not on world bosses); Cone of Cold / Blizzard / Arcane Explosion on packs; Ice Lance on frozen targets; wand finish |
| `rm.tbc.mage.fire.icyveins` (recommended) | level ≥ 10 and Fire primary, 20 | Pyroblast opener; Improved Scorch keeps five Fire Vulnerability stacks; Fireball; Fire Blast only while moving |
| `rm.tbc.mage.fire.wowhead` | same, 10 | Fireball opener; Fire Blast weaved whenever ready (Wowhead, wowsims) |
| `rm.tbc.mage.arcane` | level ≥ 10 and Arcane primary, 20 | Arcane Missiles before 64; then Arcane Blast under Arcane Power/Bloodlust, at 35%+ mana or to keep stacks, otherwise Frostbolt |
| `rm.tbc.warlock.dps.icyveins` (recommended) | knows Shadow Bolt, 10 | Every tree: procs, instants while moving, Seed/Hellfire/Shadowfury on packs, curse by situation, DoTs refreshed once under 1.5 s, Drain Life/Life Tap/wand solo, Incinerate or Shadow Bolt |
| `rm.tbc.warlock.dps.wowhead` | same, 5 | Drain-tanking solo (Drain Life filler, no wand); Immolate and Siphon Life kept for elites; group Immolate after Corruption and Siphon Life |
| `rm.tbc.priest.dps.icyveins` (recommended) | knows Smite, 10 | Shadowform; pull with Vampiric Touch / Mind Blast; DoTs before Mind Blast; Shadow Word: Death above 50% health; Mind Flay (Holy Fire/Smite for Holy/Discipline questers); wand |
| `rm.tbc.priest.dps.wowhead` | same, 5 | Mind Blast before DoT refreshes; Vampiric Embrace only on low health; no wand on a dying target |
| `rm.tbc.priest.healer.wowhead` (recommended) | in a group, level ≥ 10, Holy or Discipline primary, 30 | Advises on your friendly target: pre-pull Prayer of Mending and Renew; Shield below 35%; dispels; Prayer of Mending; group heals; Binding/Flash/Renew/Greater Heal by what is learned |
| `rm.tbc.priest.healer.icyveins` | same, 25 | Shield, dispels, Binding Heal, Renew, Flash Heal, Greater Heal, group heals, Prayer of Mending last |

The Warlock armor policy is unchanged in spirit and extended: Fel Armor over Demon Armor over Demon Skin; a learned better armor replaces an active Demon Skin; a Demon Armor you put up yourself is never replaced; an unready preferred armor never falls back to a lower one.


## TBC Warrior, Rogue and Hunter premades (levels 1–70)

These replace the bracketed Warrior, Rogue and Hunter previews (removed, with their tests; saved clones of them are independent copies and keep loading, running and auto-selecting, covered by `tests/builtin_removed_pack_clones.lua`). Each premade runs from its first level to 70 and adapts by spell known, never by level. Where the sources compared in the premade research disagree on the priority itself, each source family is its own premade with the same switch; the recommended one has the higher `priority` and auto-selects, the others are there to choose.

| Premade | Switch, priority | Differs from its sibling by |
|---|---|---|
| `rm.tbc.warrior.protection.wowhead` (Wowhead, wowsims) | Defensive Stance (`FORM` 2), 30 | Thunder Clap/Demoralizing Shout upkeep on elites; Shield Block against crush-capable targets |
| `rm.tbc.warrior.protection.icyveins` | Defensive Stance, 25 | no single-target debuff upkeep; Shield Block while the target attacks you; Rend before Shield Slam |
| `rm.tbc.warrior.dps.wowsims` (wowsims, Wowhead) | level ≥ 1 (catch-all), 10 | Execute after Bloodthirst/Mortal Strike/Whirlwind; Devastate/Sunder filler |
| `rm.tbc.warrior.dps.icyveins` | level ≥ 1, 5 | Execute first (Arms) or second (Fury); Hamstring only near the rage cap |
| `rm.tbc.rogue.dps.wowsims` (wowsims, Icy Veins) | level ≥ 1, 10 | two-point Slice and Dice; Rupture when it will last; near-death Eviscerate |
| `rm.tbc.rogue.dps.wowhead` | level ≥ 1, 5 | one-point Slice and Dice; Eviscerate only |
| `rm.tbc.hunter.ranged.wowsims` (wowsims, rotationtools, Icy Veins) | level ≥ 1, 10 | Arcane Shot fills a clipped Steady; solo Serpent Sting; Viper/Hawk hysteresis |
| `rm.tbc.hunter.ranged.wowhead` | level ≥ 1, 5 | Multi/Steady only; no Sting at 62+; no Viper |

Shared steps live in `Defaults/blocks/{warrior,rogue,hunter}.lua`. Every rotation starts with one cast/channel Stop and one no-target Stop; Warrior and Hunter pulls sit behind one out-of-combat Branch; the Rogue opener behind one stealth Branch; multi-target play is one Branch on `THREAT_COUNT` (enemies with nameplates that have you on their threat table: two for Warriors, three for Hunters' Multi-Shot) and an elite-or-second-enemy gate on Rogue cooldowns. `DISTANCE_COUNT` is not used: an enemy whose range LibRangeCheck cannot bound makes it unavailable, and an unavailable Branch halts the whole rotation. RM cannot count enemies around the target, so Hunter traps and Volley stay manual. `tests/defaults_tbc_{warrior,rogue,hunter}.lua` run each premade through the real predicates, catalog, sequence and publisher with modeled WoW observations; native gameplay acceptance remains open.

## TBC Shaman, Druid and Paladin premades

These replace the bounded Shaman, Druid and Paladin leveling previews. Each premade covers one role from level 1 (or the first talent point) to 70 and adapts by learned spell, talent tree and condition; there are no level brackets. A role gets one premade per source family only where the sources disagree on the priority itself (order of core abilities, filler, cooldown or totem policy); the research's recommendation carries the higher `priority`, so it is auto-selected, and players switch by disabling it or choosing the other. Variants of a role use the same switch and share composition blocks (`Defaults/blocks/{shaman,druid,paladin}.lua`) for everything their sources agree on.

| Class | Premade (priority) | Switch |
|---|---|---|
| Shaman | Enhancement, Icy Veins (10) / Wowhead & wowsims (5) | catch-all: every Shaman no other premade fits, including below 10, no points and ties |
| Shaman | Elemental, Icy Veins & wowsims (30) / Wowhead (21) / NextActionTBC (20) | primary tree 1 |
| Shaman | Restoration (30) | primary tree 3 |
| Druid | Balance (0) | catch-all |
| Druid | Feral cat and bear, Icy Veins, Warcraft Tavern & wowsims (30) / Wowhead (20) | primary tree 2; the form decides cat or bear |
| Druid | Restoration (30) | primary tree 3 |
| Paladin | Retribution, Wowhead & wowsims (2) / Icy Veins (1) | catch-all |
| Paladin | Retribution seal twisting (3, disabled by default) | Seal of Command and Blood or Martyr learned, primary tree 3 |
| Paladin | Protection, Wowhead & wowsims (20) / Icy Veins (19) | Righteous Fury up, or primary tree 2 |
| Paladin | Holy, Icy Veins & Wowhead (10) / Wowhead tank healing (9) | in a group and primary tree 1 |

Every rotation starts with Stops (casting or channelling, travel forms, no attackable target), then a pull or opener section that ends in a Stop when out of combat, then the priority. Independent upkeep (imbues, shields, totems, auras, blessings, forms, Mark, cooldowns) lives in `cooldowns`. Optional steps that need a macro or a raid decision (Fire Elemental, powershifting) ship `disabled` and can be enabled in a clone. A Branch or Stop whose condition is unavailable halts the whole priority, so enemy counts (`DISTANCE_COUNT`, unavailable whenever a nameplate's range is ambiguous) and time-to-die forecasts (`TT_HEALTH`) appear only on action steps. Druid forms are read from their auras, not the `FORM` slot index. Healer premades act on the current friendly target (or none) and leave choosing whom to heal, and downranking, to the player. `tests/defaults_tbc_{shaman,druid,paladin}.lua` run each premade through the real predicates, catalog, readiness and sequence executor with modeled native APIs (`tests/fixtures/tbc_hybrid_premades.lua`); native gameplay acceptance is pending. Sources, reviewed 2026-10-23, are recorded in each manifest; research notes are kept outside the addon.

## Built In composition

Packaged definitions can share named step blocks; this is authoring-time reuse only. `RegisterDefaultRotation` expands every reference once, at load, so the catalog, editor, runtime, export and Clone only ever see a fully expanded independent tree. A clone copies every included step, and neither later block edits nor clone edits reach the other. Users cannot see or author a block.

Put blocks in `Defaults/blocks/<topic>.lua`, listed in the TOC before every consumer:

```lua
assert(addon:RegisterDefaultBlock({id='shared.preserve-cast',revision=1,families={'era','tbc'},class='ROGUE', -- class optional
 steps={{id='cast',type='none',suppress_attack=true,conditions={type='CASTING',unit='player'}}},
 overrides={{families={'tbc'},steps={...}}}}))  -- optional whole-variant replacements by families and/or specs
```

A consumer pins every block it reaches, including nested ones, in `blocks`. It references a block as a step anywhere in `rotation`, `cooldowns`, a branch arm or another block:

```lua
id='rm.tbc.rogue.dps.wowsims',revision=1,blocks={['tbc.rogue.opening']=1,['tbc.rogue.upkeep']=1,['tbc.rogue.builders']=1},
rotation={{id='rogue-ref-opening',type='block',block='tbc.rogue.opening',prefix='rogue-'}, ...}
```

An expanded step ID is the reference's `prefix` (default `<reference id>.`) followed by the block step's ID. Prefixes compound through nested references, so IDs stay stable across reloads and differ per inclusion. Choose a prefix that keeps existing IDs when converting a shipped pack, since saved clones' step origins name them. `families` lists every edition the block was reviewed for. TBC may share Classic blocks only after reviewing changed talents and mechanics; shared spell names alone are insufficient. An override replaces the whole step list, and applies only when the consumer's whole edition/spec scope lies inside its selector; a partial match or a second matching override is rejected. Expansion also hard-rejects missing or undeclared blocks, unused or stale pins, cycles, duplicate block or expanded IDs, and incompatible editions or classes. Each rejection names the failing location.

A block content change needs a new block revision. Every consumer's pin must then change, or it fails to load. Bump the consumer's own revision too. Record both as new rows in `tests/fixtures/builtin_composition_ledger.lua`; `tests/builtin_composition.lua` fails when content or pins change without a revision bump. A block change therefore always reaches clones as a source revision with a source-side diff. `rm.tbc.rogue.starter.30-39` and `.40-49` share `Defaults/blocks/rogue.lua` and expand to their exact pre-composition trees.

## WoW Forever premades: Druid, Hunter, Mage, Paladin, Priest

`Defaults/forever/<class>-<role>.lua` (ids `rm.forever.<class>.<role>[.<source>]`) with shared blocks in `Defaults/blocks/forever-<class>.lua`, levels 1–60 (talent-gated roles from 10), `families={'forever'}`. Forever has one specialization ID per class and RM's talent conditions are unavailable on its traits layout, so every switch is a known-spell or own-aura proxy (for example Pyroblast for Fire, Strider Kick for Survival, Holy Shock plus a group for a Holy Paladin), talent spells are matched across all their rank IDs, and the catch-all premade of each class has the lowest priority. Player-chosen source variants share their recommended sibling's switch at a lower priority. RM classes Forever as `combatDataPolicy="restricted"`, so these packs are listed but never auto-selected (`restricted-or-unsupported-client`); they are written to be correct if that policy is relaxed and are exercised on a synthetic Forever context with `probe` policy by `tests/defaults_forever_<class>.lua` (shared model: `tests/fixtures/forever_premade_model.lua`). Branch and Stop conditions use observations that do not routinely go unavailable: enemy counts in branches are engaged enemies (`THREAT_COUNT`), player-centred `DISTANCE_COUNT` appears only inside single steps, target lifetime is approximated by target health, and combo points are read on the player as on Mainline-engine clients. Every guide behind them is a level-30 beta guide; spell IDs follow the research's Wowhead and SimulationCraft cross-check and still need in-game verification.

## Retail premades: Death Knight, Demon Hunter, Druid, Evoker, Hunter, Mage, Monk

`Defaults/retail/<class>-<spec>[-<source>].lua` (ids `rm.retail.<class>.<spec>[.<source>]`) with shared blocks in `Defaults/blocks/retail-<class>.lua`, `families={'retail'}`, levels 10–90 (8–90 for Death Knights and Demon Hunters). Retail stores rotations per specialization, so each premade declares `applicability.specs={<spec ID>}` and lands in that spec's slot; its switch is only the level floor. In Midnight combat most data an addon reads is secret (buffs, debuffs, cooldown times, primary resources, health, enemy casts), so the recommended premade for every damage and tank spec is **Blizzard Assisted** (bare id, priority 20): stop while casting or channelling, then one `assisted` step ("Blizzard's suggestion", `docs/assisted-combat.md`), plus independent highlights for what Assisted Combat never suggests — the cooldowns SimulationCraft's model marks as outside it or lists separately (Breath of Sindragosa, Metamorphosis, Celestial Alignment, Berserk, Trueshot, Takedown, Arcane Surge, Combustion, Zenith, Celestial Conduit…), tank mitigation and racials (in combat, decided by the readable cooldown flags), interrupts on an interruptible cast and defensives below a health threshold (both light only where those observations are readable). Guide lists (Icy Veins, Wowhead, SimulationCraft `default`) are reference premades shipped `disabled` (`.guide` priority 10, extra `.simc`/`.wowhead` sources 5): they read secret data and are kept for reading and cloning. Exceptions follow the research: Augmentation's Icy Veins Ebon Might list is the recommended premade (Ebon Might is a whitelisted aura) with Assisted as an enabled alternative; Brewmaster's Assisted premade adds Icy Veins' brews; Restoration Druid uses the Assisted step on an enemy and maintenance heals on a friend; Preservation and Mistweaver are reference-only. RM classes Retail as `combatDataPolicy="restricted"`, so these packs are listed but never auto-selected (`restricted-or-unsupported-client`); `tests/defaults_retail_<class>.lua` exercise them on a synthetic Retail context with `probe` policy and a modeled `C_AssistedCombat` (shared model: `tests/fixtures/retail_premade_model_a.lua`), including a Midnight-secrets scenario. Spell IDs follow the research and the SimulationCraft 12.1.5 spell dump and still need in-game verification.
