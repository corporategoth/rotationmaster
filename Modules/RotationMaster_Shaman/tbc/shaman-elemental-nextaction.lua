-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Elemental, NextActionTBC: keep Flame Shock up, Chain Lightning only against two or
-- more enemies with mana to spare, Lightning Bolt otherwise; Lightning Shield upkeep.
-- Totems are not part of this source's priority and stay manual here.
-- Shared blocks: Defaults/blocks/shaman.lua. Original priority data, no addon code copied.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function flame()return{type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.shaman.elemental.nextaction',revision=5,
 blocks={['tbc.shaman.mainhand-imbue']=1,['tbc.shaman.bloodlust']=1,['tbc.shaman.elemental-opening']=2,['tbc.shaman.boundaries']=3,['tbc.shaman.interrupt']=1},
 nameKey='Default.TBC.Shaman.Elemental.NextAction.Name',descriptionKey='Default.TBC.Shaman.Elemental.NextAction.Description',
 applicability={families={'tbc'},actionContext='player',class='SHAMAN'},
 tags={'leveling','endgame','elemental','caster','single-target','dot','nextaction'},
 sources={{url='https://www.curseforge.com/wow/addons/next-action',title='NextActionTBC 1.30.1 Elemental priority',reviewedAt='2026-10-23',revision='1.30.1'}},
 body={priority=20,disabled=true,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=1}}},
  cooldowns={
   {id='ele-na-lightning-shield',type='spell',action=324,ranked=false,conditions=all(negate(own(324)),negate(own(24398)))},
   {id='ele-na-imbue',type='block',block='tbc.shaman.mainhand-imbue',prefix='ele-na-'},
   {id='ele-na-elemental-mastery',type='spell',action=16166,ranked=false,conditions={type='COMBAT',unit='player'}},
   {id='ele-na-lust',type='block',block='tbc.shaman.bloodlust',prefix='ele-na-'},
  },
  rotation={
   {id='ele-na-opening',type='block',block='tbc.shaman.elemental-opening',prefix='ele-na-'},
   {id='ele-na-flame-shock',type='spell',action=8050,ranked=false,conditions=any(negate(flame()),{type='DEBUFF_REMAIN',unit='target',spell=8050,anyrank=true,owndebuff=true,operator='LESSTHAN',value=2})},
   {id='ele-na-moving',type='stop',conditions={type='MOVING'}},
   {id='ele-na-chain',type='spell',action=421,ranked=false,conditions=all({type='MANAPCT',unit='player',operator='GREATERTHANOREQUALS',value=0.3},{type='DISTANCE_COUNT',enemy=true,distance=20,operator='GREATERTHANOREQUALS',value=2})},
   {id='ele-na-bolt',type='spell',action=403,ranked=false,conditions={}},
  },
 },
}))
