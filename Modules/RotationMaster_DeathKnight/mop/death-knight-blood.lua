-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Blood Death Knight (tank), levels 55–90, after Icy Veins' rotation and
-- leveling pages with simulator' readable guards: Death Strike below 50% health, to restore a missing
-- Blood Shield (from 80) and before all four Frost and Unholy runes cap; Rune Strike at 90 runic
-- power; diseases by Outbreak, refreshed by Blood Boil; Soul Reaper under 35%; Heart Strike on two
-- Blood runes; Crimson Scourge; Death Strike as the main filler. Bone Shield, presence and
-- defensive cooldowns by health are reminders. The health-reactive variant is .blood.simulator.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function disease(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,v)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=v}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function rp(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function rune(kind,op,n)return{type='RUNE',rune=kind,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local FEVER,PLAGUE=55095,55078
local both=all(disease(FEVER),disease(PLAGUE))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.deathknight.blood',revision=6,
 blocks={['mop.deathknight.boundaries']=3,['mop.deathknight.upkeep']=1,['mop.deathknight.blood-upkeep']=2,['mop.deathknight.blood-pull']=2,['mop.deathknight.spread']=1},
 nameKey='Default.MoP.DeathKnight.Blood.Name',descriptionKey='Default.MoP.DeathKnight.Blood.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DEATHKNIGHT'},
 tags={'blood','tank','leveling','single-target','aoe','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/blood-death-knight-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Blood Death Knight rotation',reviewedAt='2026-10-23',revision='2025-09-23'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/blood-death-knight-leveling',title='Icy Veins: MoP Classic Blood Death Knight leveling',reviewedAt='2026-10-23',revision='2025-09-23'},
  
  {url='https://www.wowhead.com/mop-classic/guide/classes/death-knight/blood/tank-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Blood Death Knight rotation',reviewedAt='2026-10-23',revision='2025-08-02',notes='Read from a Wayback snapshot; Crimson Scourge split at 15 s.'},
 },
 body={priority=30,specs={250},
  cooldowns={
   block('blood-upkeep','mop.deathknight.blood-upkeep','blood-'),
   block('blood-class','mop.deathknight.upkeep','blood-'),
  },
  rotation={
   block('blood-boundaries','mop.deathknight.boundaries','blood-'),
   block('blood-pull','mop.deathknight.blood-pull','blood-'),
   spell('blood-death-strike-low',49998,{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5}),
   spell('blood-death-strike-shield',49998,all({type='SELF_LEVEL',operator='GREATERTHANOREQUALS',value=80},negate({type='BUFF',unit='player',spell=77535,ownbuff=true}))),
   spell('blood-outbreak',77575,any(negate(disease(FEVER)),negate(disease(PLAGUE)))),
   spell('blood-icy-touch',45477,negate(disease(FEVER))),
   spell('blood-plague-strike',45462,negate(disease(PLAGUE))),
   spell('blood-boil-refresh',48721,all({type='SELF_LEVEL',operator='GREATERTHANOREQUALS',value=68},both,any(remain(FEVER,'LESSTHAN',5),remain(PLAGUE,'LESSTHAN',5)))),
   spell('blood-death-strike-runes',49998,all(rune(2,'EQUALS',2),rune(3,'EQUALS',2))),
   spell('blood-rune-strike-cap',56815,rp('GREATERTHANOREQUALS',90)),
   spell('blood-death-coil-cap',47541,all(negate(known(56815)),rp('GREATERTHANOREQUALS',80))),
   {id='blood-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    spell('blood-aoe-death-and-decay',43265),
    block('blood-aoe-spread','mop.deathknight.spread','blood-aoe-'),
    spell('blood-aoe-blood-boil',48721,any(buff(81141),rune(1,'GREATERTHANOREQUALS',1),rune(4,'GREATERTHANOREQUALS',1)))}},
   spell('blood-soul-reaper',114866,{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.35}),
   spell('blood-heart-strike-capped',55050,rune(1,'EQUALS',2)),
   spell('blood-blood-strike-capped',45902,all(negate(known(55050)),rune(1,'EQUALS',2))),
   spell('blood-scourge-decay',43265,all(buff(81141),remain(FEVER,'GREATERTHAN',15),remain(PLAGUE,'GREATERTHAN',15))),
   spell('blood-scourge-boil',48721,buff(81141)),
   spell('blood-blood-tap',45529,{type='BUFF_STACKS',unit='player',spell=114851,operator='GREATERTHANOREQUALS',value=11}),
   spell('blood-death-strike',49998),
   spell('blood-heart-strike',55050),
   spell('blood-blood-strike',45902,negate(known(55050))),
   spell('blood-rune-strike',56815),
   spell('blood-horn-filler',57330),
  },
 },
}))
