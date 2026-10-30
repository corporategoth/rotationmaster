-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Blood Death Knight (tank), levels 55–90, after Icy Veins' rotation and
-- leveling pages with simulator' readable guards: Death Strike below 50% health, to restore a missing
-- Blood Shield (from 80) and before all four Frost and Unholy runes cap; Rune Strike at 90 runic
-- power; diseases by Outbreak, refreshed by Blood Boil; Soul Reaper under 35%; Heart Strike on two
-- Blood runes; Crimson Scourge; Death Strike as the main filler. Bone Shield, presence and
-- defensive cooldowns by health are reminders. The health-reactive variant is .blood.simulator.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function disease(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,v)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=v}end
local function rp(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function rune(kind,op,n)return{type='RUNE',rune=kind,operator=op,value=n}end
local FEVER,PLAGUE=55095,55078
local both=BuiltinConditions.all(disease(FEVER),disease(PLAGUE))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.deathknight.blood',revision=6,
 blocks={['mop.deathknight.boundaries']=3,['mop.deathknight.upkeep']=1,['mop.deathknight.blood-upkeep']=2,['mop.deathknight.blood-pull']=2,['mop.deathknight.spread']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DEATHKNIGHT'},
 tags={'blood','tank','leveling','single-target','aoe','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/blood-death-knight-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Blood Death Knight rotation',reviewedAt='2026-10-23',revision='2025-09-23'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/blood-death-knight-leveling',title='Icy Veins: MoP Classic Blood Death Knight leveling',reviewedAt='2026-10-23',revision='2025-09-23'},

  {url='https://www.wowhead.com/mop-classic/guide/classes/death-knight/blood/tank-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Blood Death Knight rotation',reviewedAt='2026-10-23',revision='2025-08-02',notes='Read from a Wayback snapshot; Crimson Scourge split at 15 s.'},
 },
 body={priority=30,specs={250},
  cooldowns={
   BuiltinConditions.block('blood-upkeep','mop.deathknight.blood-upkeep','blood-'),
   BuiltinConditions.block('blood-class','mop.deathknight.upkeep','blood-'),
  },
  rotation={
   BuiltinConditions.block('blood-boundaries','mop.deathknight.boundaries','blood-'),
   BuiltinConditions.block('blood-pull','mop.deathknight.blood-pull','blood-'),
   BuiltinConditions.spell('blood-death-strike-low',49998,{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5}),
   BuiltinConditions.spell('blood-death-strike-shield',49998,BuiltinConditions.all({type='SELF_LEVEL',operator='GREATERTHANOREQUALS',value=80},BuiltinConditions.negate({type='BUFF',unit='player',spell=77535,ownbuff=true}))),
   BuiltinConditions.spell('blood-outbreak',77575,BuiltinConditions.any(BuiltinConditions.negate(disease(FEVER)),BuiltinConditions.negate(disease(PLAGUE)))),
   BuiltinConditions.spell('blood-icy-touch',45477,BuiltinConditions.negate(disease(FEVER))),
   BuiltinConditions.spell('blood-plague-strike',45462,BuiltinConditions.negate(disease(PLAGUE))),
   BuiltinConditions.spell('blood-boil-refresh',48721,BuiltinConditions.all({type='SELF_LEVEL',operator='GREATERTHANOREQUALS',value=68},both,BuiltinConditions.any(remain(FEVER,'LESSTHAN',5),remain(PLAGUE,'LESSTHAN',5)))),
   BuiltinConditions.spell('blood-death-strike-runes',49998,BuiltinConditions.all(rune(2,'EQUALS',2),rune(3,'EQUALS',2))),
   BuiltinConditions.spell('blood-rune-strike-cap',56815,rp('GREATERTHANOREQUALS',90)),
   BuiltinConditions.spell('blood-death-coil-cap',47541,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(56815)),rp('GREATERTHANOREQUALS',80))),
   {id='blood-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    BuiltinConditions.spell('blood-aoe-death-and-decay',43265),
    BuiltinConditions.block('blood-aoe-spread','mop.deathknight.spread','blood-aoe-'),
    BuiltinConditions.spell('blood-aoe-blood-boil',48721,BuiltinConditions.any(BuiltinConditions.buff(81141),rune(1,'GREATERTHANOREQUALS',1),rune(4,'GREATERTHANOREQUALS',1)))}},
   BuiltinConditions.spell('blood-soul-reaper',114866,{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.35}),
   BuiltinConditions.spell('blood-heart-strike-capped',55050,rune(1,'EQUALS',2)),
   BuiltinConditions.spell('blood-blood-strike-capped',45902,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(55050)),rune(1,'EQUALS',2))),
   BuiltinConditions.spell('blood-scourge-decay',43265,BuiltinConditions.all(BuiltinConditions.buff(81141),remain(FEVER,'GREATERTHAN',15),remain(PLAGUE,'GREATERTHAN',15))),
   BuiltinConditions.spell('blood-scourge-boil',48721,BuiltinConditions.buff(81141)),
   BuiltinConditions.spell('blood-blood-tap',45529,{type='BUFF_STACKS',unit='player',spell=114851,operator='GREATERTHANOREQUALS',value=11}),
   BuiltinConditions.spell('blood-death-strike',49998),
   BuiltinConditions.spell('blood-heart-strike',55050),
   BuiltinConditions.spell('blood-blood-strike',45902,BuiltinConditions.negate(BuiltinConditions.known(55050))),
   BuiltinConditions.spell('blood-rune-strike',56815),
   BuiltinConditions.spell('blood-horn-filler',57330),
  },
 },
}))
