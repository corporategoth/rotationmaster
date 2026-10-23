-- TBC Rogue melee DPS, levels 1–70, Wowhead order (alternative variant).
-- Same switch and shared blocks as the wowsims variant (Defaults/blocks/rogue.lua). Differs where
-- Wowhead differs: Slice and Dice from one combo point, and every five-point finisher is
-- Eviscerate (Rupture and the near-death Eviscerate are not used).
-- Left manual: Expose Armor, Kidney Shot, Feint, Vanish, Sprint, Thistle Tea and positioning.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function points(n)return{type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.rogue.dps.wowhead',revision=3,
 blocks={['tbc.rogue.opening']=2,['tbc.rogue.upkeep']=2,['tbc.rogue.builders']=3},
 nameKey='Default.TBC.Rogue.DPS.Wowhead.Name',descriptionKey='Default.TBC.Rogue.DPS.Wowhead.Description',
 applicability={families={'tbc'},actionContext='player',class='ROGUE',minLevel=1,maxLevel=70},
 tags={'dps','melee','leveling','endgame','wowhead'},
 sources={{url='https://www.wowhead.com/tbc/guide/classes/rogue/dps-rotation-cooldowns-abilities-pve',title='Wowhead: TBC Rogue DPS rotation, cooldowns and abilities',reviewedAt='2026-10-23',revision='2026-02-10'},
 {url='https://www.wowhead.com/tbc/guide/classes/rogue/leveling-tips',title='Wowhead: TBC Rogue leveling',reviewedAt='2026-10-23',revision='2026-09-04'},
 {url='https://www.wowhead.com/tbc/guide/classes/rogue/subtlety/leveling-tips',title='Wowhead: TBC Subtlety Rogue leveling (Cheap Shot opener)',reviewedAt='2026-10-23',revision='2025-12-26'},
 {url='https://warcrafttavern.com/tbc/guides/pve-subtlety-rogue-rotation-cooldowns-abilities/',title='Warcraft Tavern: Subtlety Rogue PvE rotation (stealth openers)',reviewedAt='2026-10-23'}},
 body={priority=5,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('tbc.rogue.upkeep','rogue-')},
 rotation={
 block('tbc.rogue.opening','rogue-'),
 spell('rogue-slice',5171,all(points(1),any(negate({type='BUFF',unit='player',spell=5171,anyrank=true,ownbuff=true}),
  {type='BUFF_REMAIN',unit='player',spell=5171,anyrank=true,ownbuff=true,operator='LESSTHAN',value=2}))),
 {id='rogue-finisher',type='branch',conditions=points(5),onFalse={},onTrue={
  spell('rogue-eviscerate',2098),
  {id='rogue-pool',type='none',suppress_attack=false,conditions={}},
 }},
 block('tbc.rogue.builders','rogue-'),
 }},
}))
