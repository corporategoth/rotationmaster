-- Mists of Pandaria Classic Combat Rogue with Anticipation, Hekili MoP fork variant (off by default, low value): Revealing
-- Strike is the only builder (no Sinister Strike, even under Bloodlust). Builders run below five points, or with up to
-- four Anticipation charges while Revealing Strike is down: Fan of Knives at four engaged enemies, Marked for Death,
-- Revealing Strike. Finishers wait for Deep Insight, Shadow Blades coming back within 11 s, or four charges: Slice and
-- Dice, Rupture on one or two long-lived targets without Blade Flurry, Crimson Tempest at seven, Eviscerate. Slice and
-- Dice is refreshed early at 11 Bandit's Guile stacks. Selected only in the Combat specialization with Anticipation
-- talented; lower priority than the recommended Combat premade. Shared parts: mop/blocks.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function mine(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=n}end
local function buffRemain(id,op,n)return{type='BUFF_REMAIN',unit='player',spell=id,ownbuff=true,operator=op,value=n}end
local function stacks(id,op,n)return{type='BUFF_STACKS',unit='player',spell=id,ownbuff=true,operator=op,value=n}end
local function lifetime(op,n)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function energy(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local boss={type='CLASSIFICATION',unit='target',value='worldboss'}
local deep=own(84747)
local charges=function(op,n)return any(stacks(115189,op,n),negate(own(115189)))end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.rogue.combat.hekili',revision=6,
 blocks={['mop.rogue.boundaries']=3,['mop.rogue.combat-opener']=2,['mop.rogue.out-of-combat']=3,['mop.rogue.solo']=2,['mop.rogue.upkeep']=1,['mop.rogue.combat-upkeep']=1},
 nameKey='Default.MoP.Rogue.Combat.Hekili.Name',descriptionKey='Default.MoP.Rogue.Combat.Hekili.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='ROGUE'},
 tags={'combat','dps','melee','endgame','hekili'},
 sources={{url='https://github.com/Smufrik/Hekili/blob/0750b5dd98005481baf828cce26149b9abca875b/MistsOfPandaria/Priorities/RogueCombat.simc',title='Hekili MoP fork: Combat Rogue priority',reviewedAt='2026-10-23',revision='0750b5dd98005481baf828cce26149b9abca875b'}},
 body={priority=20,disabled=true,specs={260},switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='TALENT',layout='grid',value=18}}},
 cooldowns={block('mop.rogue.upkeep','rogue-'),block('mop.rogue.combat-upkeep','rogue-')},
 rotation={
 block('mop.rogue.boundaries','rogue-'),
 block('mop.rogue.combat-opener','rogue-'),
 block('mop.rogue.out-of-combat','rogue-'),
 spell('rogue-combat-hk-slice',5171,all(points('GREATERTHANOREQUALS',1),any(negate(own(5171)),buffRemain(5171,'LESSTHAN',2),
  all(points('GREATERTHANOREQUALS',4),stacks(84654,'GREATERTHANOREQUALS',11),buffRemain(5171,'LESSTHAN',15))))),
 block('mop.rogue.solo','rogue-'),
 {id='rogue-combat-hk-build',type='branch',conditions=any(points('LESSTHANOREQUALS',4),all(charges('LESSTHANOREQUALS',4),negate(mine(84617)))),onFalse={},onTrue={
  spell('rogue-combat-hk-fan',51723,enemies('GREATERTHANOREQUALS',4)),
  spell('rogue-combat-hk-marked-for-death',137619,points('LESSTHANOREQUALS',0)),
  spell('rogue-combat-hk-revealing-refresh',84617,any(negate(mine(84617)),remain(84617,'LESSTHANOREQUALS',3))),
  spell('rogue-combat-hk-revealing-strike',84617),
  {id='rogue-combat-hk-build-pool',type='stop',suppress_attack=false,conditions={}},
 }},
 {id='rogue-combat-hk-finish',type='branch',conditions=any(deep,stacks(115189,'GREATERTHANOREQUALS',4),all(known(121471),{type='SPELL_COOLDOWN',spell=121471,operator='LESSTHAN',value=11})),onFalse={},onTrue={
  spell('rogue-combat-hk-finisher-slice',5171,buffRemain(5171,'LESSTHANOREQUALS',2)),
  spell('rogue-combat-hk-rupture',1943,all(enemies('LESSTHANOREQUALS',2),any(negate(mine(1943)),remain(1943,'LESSTHANOREQUALS',2)),negate(own(13877)),any(boss,lifetime('GREATERTHANOREQUALS',26)))),
  spell('rogue-combat-hk-crimson-tempest',121411,enemies('GREATERTHANOREQUALS',7)),
  spell('rogue-combat-hk-eviscerate',2098),
  {id='rogue-combat-hk-pool',type='stop',suppress_attack=false,conditions={}},
 }},
 spell('rogue-combat-hk-revealing-filler',84617,any(energy('GREATERTHAN',60),negate(deep),buffRemain(84747,'LESSTHAN',2))),
 spell('rogue-combat-hk-shuriken-toss',114014,{type='BEYOND_MELEE',unit='target'}),
 }},
}))
