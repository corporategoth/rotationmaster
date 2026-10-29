-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Rogue melee DPS, simulator "sweaty" Sword Specialization timing (alternative premade).
-- The recommended order (era/blocks.lua parts), but Sinister Strike waits for a fresh main-hand
-- swing so a Sword Specialization extra attack does not clip it: at least 2.0 seconds to the next
-- swing (tuned for a 2.6–2.8 speed sword; edit it in a clone), unless energy is near the cap or
-- the target is about to die. Eviscerate at five also waits for Slice and Dice, full energy or a
-- dying target. Left manual: Feint, Sprint, Blind, Sap and positioning.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function points(n)return{type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=n}end
local function lifetime(op,n)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local sliced={type='BUFF',unit='player',spell=5171,anyrank=true,ownbuff=true}
local capped={type='POWER',unit='player',operator='GREATERTHANOREQUALS',value=79}
local lasting=any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'},
 {type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.2})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.rogue.dps.simulator',revision=6,
 blocks={['era.rogue.boundaries']=3,['era.rogue.opener']=3,['era.rogue.upkeep']=2,['era.rogue.builders']=2,['era.rogue.expose-armor']=2},
 nameKey='Default.Era.Rogue.DPS.Simulator.Name',descriptionKey='Default.Era.Rogue.DPS.Simulator.Description',
 applicability={families={'era'},actionContext='player',class='ROGUE'},
 tags={'dps','melee','endgame'},
 sources={
 {url='https://www.warcrafttavern.com/wow-classic/guides/rogue-leveling-guide/',title='Warcraft Tavern: Classic Rogue leveling guide (Sword Specialization timing)',reviewedAt='2026-10-23'}},
 body={priority=3,disabled=true,
 cooldowns={block('era.rogue.upkeep','rogue-')},
 rotation={
 block('era.rogue.boundaries','rogue-'),
 {id='rogue-stealth',type='branch',conditions={type='STEALTHED'},onFalse={},onTrue={block('era.rogue.opener','rogue-stealth-')}},
 spell('rogue-riposte',14251),
 spell('rogue-slice',5171,all(points(1),negate(sliced),lasting)),
 block('era.rogue.expose-armor','rogue-'),
 spell('rogue-slice-refresh',5171,all(points(5),{type='BUFF_REMAIN',unit='player',spell=5171,anyrank=true,ownbuff=true,operator='LESSTHAN',value=3})),
 {id='rogue-finisher',type='branch',conditions=points(5),onFalse={},onTrue={
  spell('rogue-eviscerate',2098,any(sliced,capped,lifetime('LESSTHAN',6))),
  {id='rogue-pool',type='stop',suppress_attack=false,conditions={}},
 }},
 block('era.rogue.builders','rogue-'),
 spell('rogue-sinister',1752,any({type='SWING_TIME_REMAIN',offhand=false,operator='GREATERTHANOREQUALS',value=2},capped,lifetime('LESSTHAN',6))),
 }},
}))
