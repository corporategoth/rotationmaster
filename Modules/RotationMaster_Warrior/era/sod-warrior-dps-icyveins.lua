-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Warrior melee DPS, Icy Veins order (alternative premade; same catch-all
-- switch, lowest priority). Icy Veins' Fury (Phase 6) and Arms (Phase 4) pages: Execute near the
-- top to dump rage below 20% or on a Sudden Death proc; Slam on Blood Surge; Bloodthirst or
-- Mortal Strike; Whirlwind; Overpower; Raging Blow; Quick Strike and Hamstring only above 60 rage
-- (pooling for Consumed by Rage); no Rend. Heroic Strike only above 80 rage. Same boundaries and
-- reminders as the recommended SoD premade (era/blocks.lua).
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function rage(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local unqueued=BuiltinConditions.all(BuiltinConditions.negate(queued(78)),BuiltinConditions.negate(queued(845)))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.warrior.dps.icyveins',revision=6,
 blocks={['era.warrior.boundaries']=3,['era.warrior.upkeep']=1},
 applicability={families={'era'},actionContext='player',class='WARRIOR',rulesets={'season:2'}},
 tags={'dps','melee','endgame','season-of-discovery','icy-veins'},
 sources={{url='https://www.icy-veins.com/wow-classic/fury-warrior-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Fury Warrior DPS rotation (Phase 6)',reviewedAt='2026-10-23',revision='2025-04-08'},
 {url='https://www.icy-veins.com/wow-classic/arms-warrior-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Arms Warrior DPS rotation (Phase 4)',reviewedAt='2026-10-23',revision='2025-04-08'}},
 body={priority=40,disabled=true,
 cooldowns={block('era.warrior.upkeep','sod-iv-'),
  BuiltinConditions.spell('sod-iv-heroic-strike',78,BuiltinConditions.all(BuiltinConditions.combat(),unqueued,enemies('LESSTHAN',2),rage('GREATERTHANOREQUALS',80))),
  BuiltinConditions.spell('sod-iv-cleave',845,BuiltinConditions.all(BuiltinConditions.combat(),unqueued,enemies('GREATERTHANOREQUALS',2),rage('GREATERTHANOREQUALS',60))),
  BuiltinConditions.spell('sod-iv-bloodrage',2687,BuiltinConditions.all(BuiltinConditions.combat(),{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.4})),
  BuiltinConditions.spell('sod-iv-death-wish',12328,BuiltinConditions.combat()),
  BuiltinConditions.spell('sod-iv-rampage',426940,BuiltinConditions.combat()),
  BuiltinConditions.spell('sod-iv-sweeping-strikes',12292,BuiltinConditions.all(BuiltinConditions.combat(),enemies('GREATERTHANOREQUALS',2))),
 },
 rotation={
 block('era.warrior.boundaries','sod-iv-'),
 BuiltinConditions.spell('sod-iv-execute',5308,BuiltinConditions.any(buff(440114),{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2})),
 BuiltinConditions.spell('sod-iv-blood-surge-slam',1464,buff(413399)),
 BuiltinConditions.spell('sod-iv-bloodthirst',23881),
 BuiltinConditions.spell('sod-iv-mortal-strike',12294),
 BuiltinConditions.spell('sod-iv-whirlwind',1680),
 BuiltinConditions.spell('sod-iv-overpower',7384),
 BuiltinConditions.spell('sod-iv-raging-blow',402911),
 BuiltinConditions.spell('sod-iv-quick-strike',429765,rage('GREATERTHANOREQUALS',60)),
 BuiltinConditions.spell('sod-iv-hamstring',1715,rage('GREATERTHANOREQUALS',60)),
 }},
}))
