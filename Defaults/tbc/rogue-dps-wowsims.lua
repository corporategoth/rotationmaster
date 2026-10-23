-- TBC Rogue melee DPS, levels 1–70, wowsims order (the recommended variant; Icy Veins agrees).
-- One premade for every spec: the builder follows what is known (Mutilate, Hemorrhage, Backstab,
-- Sinister Strike). Slice and Dice from two points and refreshed in its last two seconds; a
-- two-point Eviscerate on a target about to die; at five points Rupture when it is missing, Blade
-- Flurry is not cleaving and the target will outlive it, else Eviscerate; no builder at five.
-- The Wowhead variant spends every five points on Eviscerate instead. Shared parts:
-- Defaults/blocks/rogue.lua. Left manual: Expose Armor (a raid assignment), Kidney Shot, Feint,
-- Vanish, Sprint, Thistle Tea and positioning.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function points(n)return{type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=n}end
local function lifetime(op,n)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.rogue.dps.wowsims',revision=1,
 blocks={['tbc.rogue.opening']=1,['tbc.rogue.upkeep']=1,['tbc.rogue.builders']=1},
 nameKey='Default.TBC.Rogue.DPS.Wowsims.Name',descriptionKey='Default.TBC.Rogue.DPS.Wowsims.Description',
 applicability={families={'tbc'},actionContext='player',class='ROGUE',minLevel=1,maxLevel=70},
 tags={'dps','melee','leveling','endgame','wowsims','icy-veins'},
 sources={{url='https://github.com/wowsims/tbc/blob/3301fca59306a747e521274c36e073e69acc7b77/sim/rogue/rotation.go',title='wowsims/tbc: Rogue rotation',reviewedAt='2026-10-23',revision='3301fca59306a747e521274c36e073e69acc7b77'},
 {url='https://www.icy-veins.com/tbc-classic/rogue-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: TBC Rogue DPS rotation, cooldowns and abilities',reviewedAt='2026-10-23',revision='2026-01-12'},
 {url='https://www.icy-veins.com/tbc-classic/combat-rogue-leveling-guide',title='Icy Veins: Combat Rogue leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
 {url='https://warcrafttavern.com/tbc/guides/pve-subtlety-rogue-rotation-cooldowns-abilities/',title='Warcraft Tavern: Subtlety Rogue PvE rotation (stealth openers)',reviewedAt='2026-10-23'}},
 body={priority=10,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('tbc.rogue.upkeep','rogue-')},
 rotation={
 block('tbc.rogue.opening','rogue-'),
 spell('rogue-slice',5171,all(points(2),any(negate({type='BUFF',unit='player',spell=5171,anyrank=true,ownbuff=true}),
  {type='BUFF_REMAIN',unit='player',spell=5171,anyrank=true,ownbuff=true,operator='LESSTHAN',value=2}))),
 spell('rogue-kill-shot',2098,all(points(2),lifetime('LESSTHAN',4))),
 {id='rogue-finisher',type='branch',conditions=points(5),onFalse={},onTrue={
  spell('rogue-rupture',1943,all(negate({type='DEBUFF',unit='target',spell=1943,anyrank=true,owndebuff=true}),
   negate({type='BUFF',unit='player',spell=13877,anyrank=true,ownbuff=true}),lifetime('GREATERTHAN',16))),
  spell('rogue-eviscerate',2098),
  {id='rogue-pool',type='none',suppress_attack=false,conditions={}},
 }},
 block('tbc.rogue.builders','rogue-'),
 }},
}))
