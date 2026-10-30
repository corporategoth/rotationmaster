-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Warlock, Icy Veins order (alternative premade; same switch, lower priority). Built
-- for 16-debuff realms: in raids only the curse and Corruption, then Shadow Bolt (no Immolate and
-- no Siphon Life even when slots allow). Leveling and five-man play as the recommended premade
-- (era/blocks.lua parts): Immolate with mana, Agony, Corruption, Siphon Life, the wand.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local outside=BuiltinConditions.negate({type='INSTANCE',value='raid'})
local lasting=BuiltinConditions.any({type='GROUP'},{type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'},
 {type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.4})
local blocks={['era.warlock.boundaries']=3,['era.warlock.procs']=1,['era.warlock.group-finish']=1,['era.warlock.dying']=2,['era.warlock.curse']=2,
 ['era.warlock.moving']=2,['era.warlock.aoe']=1,['era.warlock.sustain']=3,['era.warlock.filler']=2,['era.warlock.armor']=1,['era.warlock.pets']=1,['era.warlock.safety']=1}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.warlock.dps.icyveins',revision=6,blocks=blocks,
 applicability={families={'era'},actionContext='player',class='WARLOCK'},
 tags={'dps','ranged','caster','leveling','endgame','icy-veins'},
 sources={{url='https://www.icy-veins.com/wow-classic/warlock-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Warlock DPS rotation',reviewedAt='2026-10-23',revision='2024-11-18'},
 {url='https://www.icy-veins.com/wow-classic/classic-warlock-leveling-guide',title='Icy Veins: Classic Warlock leveling guide',reviewedAt='2026-10-23',revision='2024-11-18'},
 {url='https://www.icy-veins.com/wow-classic/warlock-dps-pve-spec-builds-talents',title='Icy Veins: Classic Warlock DPS talents (16-debuff limit)',reviewedAt='2026-10-23',revision='2026-07-18'}},
 body={priority=3,disabled=true,
 cooldowns={block('era.warlock.armor','lock-'),block('era.warlock.pets','lock-'),block('era.warlock.safety','lock-')},
 rotation={
 block('era.warlock.boundaries','lock-'),
 block('era.warlock.procs','lock-'),
 block('era.warlock.group-finish','lock-'),
 block('era.warlock.dying','lock-'),
 block('era.warlock.moving','lock-'),
 block('era.warlock.aoe','lock-'),
 block('era.warlock.curse','lock-'),
 BuiltinConditions.spell('lock-immolate',348,BuiltinConditions.all(outside,BuiltinConditions.any(BuiltinConditions.negate(own(348)),{type='DEBUFF_REMAIN',unit='target',spell=348,anyrank=true,owndebuff=true,operator='LESSTHAN',value=1.5}),
  BuiltinConditions.any(BuiltinConditions.known(17962),{type='MANAPCT',unit='player',operator='GREATERTHAN',value=.4}),lasting)),
 BuiltinConditions.spell('lock-corruption',172,BuiltinConditions.negate(own(172))),
 BuiltinConditions.spell('lock-siphon-life',18265,BuiltinConditions.all(outside,BuiltinConditions.negate(own(18265)))),
 block('era.warlock.sustain','lock-'),
 block('era.warlock.filler','lock-'),
 }},
}))
