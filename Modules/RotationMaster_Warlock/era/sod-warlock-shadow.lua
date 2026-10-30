-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Shadow Warlock, levels 1–60: Affliction and Felguard builds, and every SoD
-- Warlock no other premade fits (the SoD catch-all). simulator/sod Phase 6 order with Wowhead and
-- Icy Veins: Nightfall procs; Shadowburn or Drain Soul to finish; a dying solo target gets Drain
-- Soul, not DoTs; instants while moving; Lake of Fire and Hellfire on packs; a curse (group
-- Recklessness when nobody has it, else Agony); Unstable Affliction, Master Channeler Drain Life,
-- Shadowflame (Immolate before it), Corruption, Haunt, Siphon Life (with the Invocation rune each is
-- refreshed under 6 s); Drain Soul below 20% with the Soul Siphon rune; solo sustain and the wand;
-- Shadow Bolt. Reminders: Fel Armor,
-- the pet (a Felguard once engraved), Life Tap for a thirsty pet, Amplify Curse and the safety
-- ones. Shared parts: era/blocks.lua. Left manual: curse assignments and Shadow Bolt Volley packs.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function remain(id,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,anyrank=true,owndebuff=true,operator='LESSTHAN',value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local lasting=BuiltinConditions.any({type='GROUP'},{type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'},
 {type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.4})
local curses={980,603,1490,17862,704,1714,702,18223}
local cursed={type='OR',value={}};for i,id in ipairs(curses)do cursed.value[i]=own(id)end
-- Passive runes: Invocation (a refresh under 6 s deals the DoT's remaining damage at once), Soul
-- Siphon (Drain Soul ticks three times faster and drains far more below 20%).
local invocation,soulSiphon=rune(426243),rune(403511)
local function invoke(id)return BuiltinConditions.all(invocation,remain(id,6))end
local blocks={['era.warlock.boundaries']=3,['era.warlock.procs']=1,['era.warlock.dying']=2,['era.warlock.curse']=2,['era.warlock.moving']=2,['era.warlock.aoe']=1,
 ['era.warlock.sustain']=3,['era.warlock.filler']=2,['era.warlock.armor']=1,['era.warlock.pets']=1,['era.warlock.safety']=1}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.warlock.shadow',revision=6,blocks=blocks,
 applicability={families={'era'},actionContext='player',class='WARLOCK',rulesets={'season:2'}},
 tags={'dps','ranged','caster','leveling','endgame','aoe','season-of-discovery','wowhead','icy-veins'},
 sources={
 {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/warlock/dps-talent-builds-runes',title='Wowhead: SoD Warlock DPS talents and runes (Phase 6)',reviewedAt='2026-10-23',revision='2025-01-13'},
 {url='https://www.icy-veins.com/wow-classic/affliction-warlock-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Affliction Warlock DPS rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
 {url='https://www.icy-veins.com/wow-classic/affliction-warlock-dps-season-of-discovery-leveling',title='Icy Veins: SoD Affliction Warlock leveling',reviewedAt='2026-10-23',revision='2025-04-08'}},
 body={priority=60,
 cooldowns={block('era.warlock.armor','sod-shadow-'),block('era.warlock.pets','sod-shadow-'),
  BuiltinConditions.spell('sod-shadow-pet-life-tap',1454,BuiltinConditions.all(BuiltinConditions.combat(),{type='PET'},{type='MANAPCT',unit='pet',operator='LESSTHAN',value=.3},{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.6})),
  block('era.warlock.safety','sod-shadow-')},
 rotation={
 block('era.warlock.boundaries','sod-shadow-'),
 block('era.warlock.procs','sod-shadow-'),
 BuiltinConditions.spell('sod-shadow-finish-shadowburn',17877,BuiltinConditions.all({type='GROUP'},BuiltinConditions.lifetime('LESSTHAN',1.5))),
 BuiltinConditions.spell('sod-shadow-finish-drain-soul',1120,BuiltinConditions.all({type='GROUP'},BuiltinConditions.lifetime('LESSTHAN',3.5))),
 block('era.warlock.dying','sod-shadow-'),
 block('era.warlock.moving','sod-shadow-'),
 block('era.warlock.aoe','sod-shadow-'),
 {id='sod-shadow-group-curse',type='branch',conditions=BuiltinConditions.all({type='GROUP'},BuiltinConditions.negate(cursed)),onFalse={},onTrue={
  BuiltinConditions.spell('sod-shadow-recklessness',704,BuiltinConditions.negate({type='DEBUFF',unit='target',spell=704,anyrank=true})),
 }},
 block('era.warlock.curse','sod-shadow-'),
 BuiltinConditions.spell('sod-shadow-unstable-affliction',427717,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.negate(own(427717)),remain(427717,1.5),invoke(427717)),lasting)),
 BuiltinConditions.spell('sod-shadow-master-channeler',403677,BuiltinConditions.all(BuiltinConditions.negate(own(403677)),lasting)),
 BuiltinConditions.spell('sod-shadow-shadowflame',426320,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.negate(own(426320)),remain(426320,1.5),invoke(426320)),lasting)),
 BuiltinConditions.spell('sod-shadow-immolate',348,BuiltinConditions.all(BuiltinConditions.negate(rune(426320)),BuiltinConditions.negate(own(348)),{type='MANAPCT',unit='player',operator='GREATERTHAN',value=.4},lasting)),
 BuiltinConditions.spell('sod-shadow-corruption',172,BuiltinConditions.any(BuiltinConditions.negate(own(172)),invoke(172))),
 BuiltinConditions.spell('sod-shadow-haunt',403501),
 BuiltinConditions.spell('sod-shadow-siphon-life',18265,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.negate(own(18265)),invoke(18265)),lasting)),
 BuiltinConditions.spell('sod-shadow-execute-drain-soul',1120,BuiltinConditions.all(soulSiphon,{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2})),
 block('era.warlock.sustain','sod-shadow-'),
 BuiltinConditions.spell('sod-shadow-low-mana-tap',1454,{type='MANAPCT',unit='player',operator='LESSTHAN',value=.1}),
 block('era.warlock.filler','sod-shadow-'),
 }},
}))
