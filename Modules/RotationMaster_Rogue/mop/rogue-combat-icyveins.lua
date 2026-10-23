-- Mists of Pandaria Classic Combat Rogue, Sinister Strike builder (Icy Veins, Warcraft Tavern, Method, wowtbc.gg; off by
-- default): how Combat played before the Siege of Orgrimmar patch raised Sinister Strike to 50 energy on 2026-06-02,
-- superseded for Phase 5. Slice and Dice, Revealing Strike kept up, five-point Rupture on a long single fight and
-- Eviscerate, Sinister Strike as the builder; same reminders and pack play as the recommended Combat premade. Same switch
-- (Blade Flurry known), lower priority. Shared parts: mop/blocks.lua.
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
local function lifetime(op,n)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local boss={type='CLASSIFICATION',unit='target',value='worldboss'}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.rogue.combat.icyveins',revision=1,
 blocks={['mop.rogue.boundaries']=1,['mop.rogue.combat-opener']=1,['mop.rogue.out-of-combat']=1,['mop.rogue.combat-aoe']=1,['mop.rogue.solo']=1,['mop.rogue.upkeep']=1,['mop.rogue.combat-upkeep']=1},
 nameKey='Default.MoP.Rogue.Combat.IcyVeins.Name',descriptionKey='Default.MoP.Rogue.Combat.IcyVeins.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='ROGUE',minLevel=10,maxLevel=90},
 tags={'combat','dps','melee','leveling','endgame','icy-veins','warcraft-tavern','method','wowtbc'},
 sources={{url='https://www.icy-veins.com/mists-of-pandaria-classic/combat-rogue-pve-rotation-cooldowns-abilities',title='Icy Veins: Combat Rogue rotation (MoP Classic)',reviewedAt='2026-10-23',revision='2025-09-23'},
 {url='https://www.warcrafttavern.com/mop/guides/pve-combat-rogue-dps-rotations-cooldowns/',title='Warcraft Tavern: Combat Rogue rotation (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://www.method.gg/mop-classic/combat-rogue-class-guide-mop-classic',title='Method: Combat Rogue guide (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://wowtbc.gg/mop/class-guides/combat-rogue/',title='wowtbc.gg: Combat Rogue (MoP Classic)',reviewedAt='2026-10-23'}},
 body={priority=20,disabled=true,switch=known(13877),
 cooldowns={block('mop.rogue.upkeep','rogue-'),block('mop.rogue.combat-upkeep','rogue-')},
 rotation={
 block('mop.rogue.boundaries','rogue-'),
 block('mop.rogue.combat-opener','rogue-'),
 block('mop.rogue.out-of-combat','rogue-'),
 block('mop.rogue.combat-aoe','rogue-'),
 spell('rogue-combat-iv-slice',5171,all(points('GREATERTHANOREQUALS',2),negate(own(5171)))),
 block('mop.rogue.solo','rogue-'),
 spell('rogue-combat-iv-revealing-strike',84617,negate(mine(84617))),
 {id='rogue-combat-iv-finisher',type='branch',conditions=points('GREATERTHANOREQUALS',5),onFalse={},onTrue={
  spell('rogue-combat-iv-finisher-slice',5171,buffRemain(5171,'LESSTHANOREQUALS',2)),
  spell('rogue-combat-iv-rupture',1943,all(any(negate(mine(1943)),remain(1943,'LESSTHANOREQUALS',2)),negate(own(13877)),any(boss,lifetime('GREATERTHAN',26)))),
  spell('rogue-combat-iv-eviscerate',2098),
  {id='rogue-combat-iv-pool',type='none',suppress_attack=false,conditions={}},
 }},
 spell('rogue-combat-iv-dying',2098,all(points('GREATERTHANOREQUALS',2),lifetime('LESSTHAN',4))),
 spell('rogue-combat-iv-sinister',1752),
 spell('rogue-combat-iv-shuriken-toss',114014,{type='BEYOND_MELEE',unit='target'}),
 }},
}))
