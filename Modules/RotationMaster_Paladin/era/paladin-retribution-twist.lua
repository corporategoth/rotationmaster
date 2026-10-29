-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Retribution seal twisting (Warcraft Tavern, simulator): keep Seal of Righteousness up,
-- swap to rank-1 Seal of Command in the last 0.4 s before a swing and back again, Judgement whenever
-- it is ready, Consecration with Vengeance, Hammer of Wrath, Exorcism on Undead and Demons.
-- Disabled by default (opt-in): it needs a swing timer, practice and a lot of mana.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function swing(op,v)return{type='SWING_TIME_REMAIN',offhand=false,operator=op,value=v}end
local function righteousness()return{type='OR',value={own(20154),own(21084)}}end
local function sealed()local out={};for i,id in ipairs({20154,21084,20375,21082,20166,20165,20164})do out[i]=own(id)end;return{type='OR',value=out}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.paladin.retribution.twist',revision=5,
 blocks={['era.paladin.ret-upkeep']=2,['era.paladin.safety']=1,['era.paladin.melee-opening']=3,['era.paladin.undead']=1},
 applicability={families={'era'},actionContext='player',class='PALADIN'},
 tags={'endgame','raid','retribution','melee','single-target','seal-twisting','warcraft-tavern'},
 sources={{url='https://www.warcrafttavern.com/wow-classic/guides/pve-retribution-paladin-rotations-cooldowns/',title='Warcraft Tavern: Classic Retribution Paladin rotations (seal twisting)',reviewedAt='2026-10-23'},
  },
 body={priority=3,disabled=true,switch=BuiltinConditions.all({type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=20},{type='SPELL_KNOWN',spell=20375},{type='PRIMARY_TALENT_TREE',tree=3}),
  cooldowns={BuiltinConditions.block('twist-upkeep','era.paladin.ret-upkeep','twist-'),BuiltinConditions.block('twist-safety','era.paladin.safety','twist-')},
  rotation={
   BuiltinConditions.block('twist-opening','era.paladin.melee-opening','twist-'),
   {id='twist-seal',type='branch',conditions=sealed(),onTrue={},onFalse={BuiltinConditions.spell('twist-seal-righteousness',20154)}},
   {id='twist-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell('twist-pull-judgement',20271),
    {id='twist-pull-stop',type='stop',conditions={}},
   }},
   {id='twist-to-command',type='spell',action=20375,ranked=true,conditions=BuiltinConditions.all(righteousness(),swing('LESSTHANOREQUALS',0.4))},
   BuiltinConditions.spell('twist-to-righteousness',20154,BuiltinConditions.all(own(20375),swing('LESSTHANOREQUALS',0.4))),
   BuiltinConditions.spell('twist-judgement',20271),
   BuiltinConditions.block('twist-undead','era.paladin.undead','twist-'),
   BuiltinConditions.spell('twist-hammer-of-wrath',24275,mana('GREATERTHANOREQUALS',0.2)),
   BuiltinConditions.spell('twist-consecration',26573,BuiltinConditions.all(own(20050),mana('GREATERTHANOREQUALS',0.3))),
  },
 },
}))
