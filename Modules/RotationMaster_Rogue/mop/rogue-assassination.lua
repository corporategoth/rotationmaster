-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Assassination Rogue, levels 10-90 (the recommended variant): wowsims' Phase 5 APL, which
-- Hekili mirrors and Wowhead's Phase 5 page describes, with Icy Veins' levelling additions. Selected in the Assassination
-- specialization (259) from level 10 (RM stores MoP rotations per talent group). Stealth opens with Cheap Shot
-- solo, else Dispatch on Blindside or Mutilate. Four or more engaged enemies: Slice and Dice, Crimson Tempest at
-- seven, Rupture, Envenom, Fan of Knives. One target: Slice and Dice (Envenom keeps it from 60), Rupture when neither
-- bleed is up or at five points under 2 s, Envenom at five with Rupture lasting, the 4-point Envenom-buff rule without
-- Anticipation, Marked for Death, Dispatch below 35% or on Blindside (dagger in the main hand), Mutilate up to three points (four with
-- Anticipation or Shadow Blades). Eviscerate stands in for Envenom before 20. Shared parts: mop/blocks.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function energy(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function mine(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=n}end
local function buffRemain(id,op,n)return{type='BUFF_REMAIN',unit='player',spell=id,ownbuff=true,operator=op,value=n}end
local function lifetime(op,n)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=n}end
local function talent(n)return{type='TALENT',layout='grid',value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function target(op,n)return{type='HEALTHPCT',unit='target',operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local sliced=own(5171)
local boss={type='CLASSIFICATION',unit='target',value='worldboss'}
-- Envenom replaces Eviscerate at 20; both steps carry the same condition so the spender exists at every level.
local function spend(id,conditions)return spell(id..'-envenom',32645,conditions),spell(id..'-eviscerate',2098,conditions)end
local fourPoint=all(points('GREATERTHANOREQUALS',4),negate(talent(18)),negate(own(121471)),negate(own(121153)),
 any(negate(known(111240)),target('GREATERTHANOREQUALS',.35)),any(buffRemain(32645,'LESSTHANOREQUALS',1),negate(own(32645)),energy('GREATERTHANOREQUALS',50)))
local dying=all(points('GREATERTHANOREQUALS',2),lifetime('LESSTHAN',4))
local four1,four2=spend('rogue-assassination-four',fourPoint)
local dying1,dying2=spend('rogue-assassination-dying',dying)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.rogue.assassination',revision=8,
 blocks={['mop.rogue.boundaries']=3,['mop.rogue.assassination-opener']=3,['mop.rogue.out-of-combat']=3,['mop.rogue.solo']=2,['mop.rogue.upkeep']=1},
 nameKey='Default.MoP.Rogue.Assassination.Name',descriptionKey='Default.MoP.Rogue.Assassination.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='ROGUE'},
 tags={'assassination','dps','melee','leveling','endgame','wowsims','wowhead','icy-veins'},
 sources={{url='https://github.com/wowsims/mop/blob/ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9/ui/specs/rogue/assassination/apls/assassination.apl.json',title='wowsims/mop: Assassination Rogue APL',reviewedAt='2026-10-23',revision='ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9'},
 {url='https://www.wowhead.com/mop-classic/guide/classes/rogue/assassination/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Assassination Rogue rotation (MoP Classic, Phase 5)',reviewedAt='2026-10-23',revision='2026-06-29'},
 {url='https://github.com/Smufrik/Hekili/blob/0750b5dd98005481baf828cce26149b9abca875b/MistsOfPandaria/Priorities/RogueAssassination.simc',title='Hekili MoP fork: Assassination Rogue priority',reviewedAt='2026-10-23',revision='0750b5dd98005481baf828cce26149b9abca875b'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/assassination-rogue-leveling',title='Icy Veins: Assassination Rogue leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-09-23'}},
 body={priority=30,specs={259},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.rogue.upkeep','rogue-'),
  spell('rogue-assassination-vendetta',79140,all(combat(),any(sliced,mine(1943)),any(boss,lifetime('GREATERTHAN',20)))),
  spell('rogue-assassination-shadow-blades',121471,all(combat(),mine(79140))),
  spell('rogue-assassination-vanish',1856,all(combat(),negate({type='STEALTHED'}),mine(79140),points('LESSTHAN',5),energy('LESSTHAN',60),negate(own(121153)))),
  spell('rogue-assassination-preparation',14185,all(combat(),mine(79140),{type='SPELL_COOLDOWN',spell=1856,operator='GREATERTHAN',value=60})),
 },
 rotation={
 block('mop.rogue.boundaries','rogue-'),
 block('mop.rogue.assassination-opener','rogue-'),
 block('mop.rogue.out-of-combat','rogue-'),
 {id='rogue-assassination-aoe',type='branch',conditions=all(enemies('GREATERTHANOREQUALS',4),known(51723)),onFalse={},onTrue={
  spell('rogue-assassination-aoe-slice',5171,all(points('GREATERTHANOREQUALS',1),negate(sliced))),
  spell('rogue-assassination-crimson-tempest',121411,all(points('GREATERTHANOREQUALS',5),enemies('GREATERTHANOREQUALS',7),negate(mine(122233)))),
  spell('rogue-assassination-aoe-rupture',1943,all(points('GREATERTHANOREQUALS',2),negate(mine(1943)))),
  {id='rogue-assassination-aoe-spend',type='branch',conditions=any(points('GREATERTHANOREQUALS',5),all(points('GREATERTHANOREQUALS',2),buffRemain(5171,'LESSTHAN',3))),onFalse={},onTrue={
   spell('rogue-assassination-aoe-envenom',32645),spell('rogue-assassination-aoe-eviscerate',2098)}},
  spell('rogue-assassination-fan',51723),
  {id='rogue-assassination-aoe-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 spell('rogue-assassination-slice',5171,any(all(points('GREATERTHANOREQUALS',1),negate(sliced)),
  all({type='LEVEL',unit='player',operator='LESSTHAN',value=60},points('GREATERTHANOREQUALS',2),buffRemain(5171,'LESSTHAN',2)))),
 block('mop.rogue.solo','rogue-'),
 spell('rogue-assassination-rupture',1943,all(any(all(points('GREATERTHANOREQUALS',1),negate(mine(1943)),negate(mine(703))),
  all(mine(1943),remain(1943,'LESSTHAN',2),any(points('GREATERTHANOREQUALS',5),all(points('GREATERTHANOREQUALS',4),negate(talent(18)))))),
  any(boss,lifetime('GREATERTHAN',8)))),
 {id='rogue-assassination-finisher',type='branch',conditions=all(points('GREATERTHANOREQUALS',5),any(negate(known(1943)),remain(1943,'GREATERTHANOREQUALS',4))),onFalse={},onTrue={
  spell('rogue-assassination-envenom',32645),spell('rogue-assassination-eviscerate',2098)}},
 four1,four2,
 dying1,dying2,
 spell('rogue-assassination-marked-for-death',137619,all(points('LESSTHANOREQUALS',0),sliced,mine(1943))),
 spell('rogue-assassination-dispatch',111240,all({type='WEAPON_TYPE',slot='mainhand',subclass=15},any(target('LESSTHAN',.35),own(121153)),any(points('LESSTHANOREQUALS',4),talent(18)))),
 spell('rogue-assassination-mutilate',1329,any(points('LESSTHANOREQUALS',3),all(points('LESSTHANOREQUALS',4),any(talent(18),own(121471))))),
 spell('rogue-assassination-shuriken-toss',114014,{type='BEYOND_MELEE',unit='target'}),
 }},
}))
