-- Classic Era Rogue melee DPS, levels 1–60, Warcraft Tavern order (alternative premade).
-- Same switch and shared blocks as the recommended premade (era/blocks.lua). Differs where
-- Warcraft Tavern differs: every finisher waits for five points (Relentless Strikes), Slice and
-- Dice only once its second rank is learned (level 42), always Eviscerate otherwise; no
-- near-death Eviscerate and no Expose Armor (Sunder covers it).
-- Left manual: Feint, Sprint, Blind, Sap and positioning.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.rogue.dps.warcrafttavern',revision=5,
 blocks={['era.rogue.boundaries']=3,['era.rogue.opener']=3,['era.rogue.upkeep']=2,['era.rogue.builders']=2},
 nameKey='Default.Era.Rogue.DPS.WarcraftTavern.Name',descriptionKey='Default.Era.Rogue.DPS.WarcraftTavern.Description',
 applicability={families={'era'},actionContext='player',class='ROGUE'},
 tags={'dps','melee','leveling','endgame','warcraft-tavern'},
 sources={{url='https://www.warcrafttavern.com/wow-classic/guides/pve-combat-rogue/',title='Warcraft Tavern: Classic PvE Combat Rogue',reviewedAt='2026-10-23'},
 {url='https://www.warcrafttavern.com/wow-classic/guides/pve-assassination-rogue/',title='Warcraft Tavern: Classic PvE Assassination Rogue',reviewedAt='2026-10-23'},
 {url='https://www.warcrafttavern.com/wow-classic/guides/rogue-leveling-guide/',title='Warcraft Tavern: Classic Rogue leveling guide',reviewedAt='2026-10-23'}},
 body={priority=5,disabled=true,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('era.rogue.upkeep','rogue-')},
 rotation={
 block('era.rogue.boundaries','rogue-'),
 {id='rogue-stealth',type='branch',conditions={type='STEALTHED'},onFalse={},onTrue={block('era.rogue.opener','rogue-stealth-')}},
 spell('rogue-riposte',14251),
 {id='rogue-finisher',type='branch',conditions={type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=5},onFalse={},onTrue={
  spell('rogue-slice',5171,all({type='SPELL_KNOWN',spell=6774},any(negate({type='BUFF',unit='player',spell=5171,anyrank=true,ownbuff=true}),
   {type='BUFF_REMAIN',unit='player',spell=5171,anyrank=true,ownbuff=true,operator='LESSTHAN',value=3}))),
  spell('rogue-eviscerate',2098),
  {id='rogue-pool',type='stop',suppress_attack=false,conditions={}},
 }},
 block('era.rogue.builders','rogue-'),
 spell('rogue-sinister',1752),
 }},
}))
