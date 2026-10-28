-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Elemental, Wowhead: Chain Lightning on cooldown with Bolts between at 70 (with
-- Elemental Mastery or Clearcasting while leveling), Flame Shock only while moving,
-- Earth Shock only to finish a target that dies before a cast lands.
-- Shared blocks: Defaults/blocks/shaman.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.shaman.elemental.wowhead',revision=5,
 blocks={['tbc.shaman.shield']=1,['tbc.shaman.mainhand-imbue']=1,['tbc.shaman.elemental-totems']=1,['tbc.shaman.bloodlust']=1,
  ['tbc.shaman.elemental-opening']=2,['tbc.shaman.boundaries']=3,['tbc.shaman.interrupt']=1,['tbc.shaman.elemental-aoe']=1},
 nameKey='Default.TBC.Shaman.Elemental.Wowhead.Name',descriptionKey='Default.TBC.Shaman.Elemental.Wowhead.Description',
 applicability={families={'tbc'},actionContext='player',class='SHAMAN'},
 tags={'leveling','endgame','elemental','caster','single-target','aoe','wowhead'},
 sources={{url='https://www.wowhead.com/tbc/guide/classes/shaman/elemental/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Elemental Shaman DPS rotation',reviewedAt='2026-10-23',revision='2026-02-07'},
  {url='https://www.wowhead.com/tbc/guide/classes/shaman/elemental/leveling-tips',title='Wowhead: Elemental Shaman leveling',reviewedAt='2026-10-23',revision='2026-03-02'}},
 body={priority=21,disabled=true,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=1}}},
  cooldowns={
   {id='ele-wh-shield',type='block',block='tbc.shaman.shield',prefix='ele-wh-'},
   {id='ele-wh-imbue',type='block',block='tbc.shaman.mainhand-imbue',prefix='ele-wh-'},
   {id='ele-wh-totems',type='block',block='tbc.shaman.elemental-totems',prefix='ele-wh-'},
   {id='ele-wh-elemental-mastery',type='spell',action=16166,ranked=false,conditions=all({type='ATTACKABLE',unit='target'},{type='SPELL_AVAIL',spell=421})},
   {id='ele-wh-lust',type='block',block='tbc.shaman.bloodlust',prefix='ele-wh-'},
   {id='ele-wh-fire-elemental',type='spell',action=2894,ranked=false,disabled=true,conditions=all({type='COMBAT',unit='player'},{type='CLASSIFICATION',unit='target',value='worldboss'})},
  },
  rotation={
   {id='ele-wh-opening',type='block',block='tbc.shaman.elemental-opening',prefix='ele-wh-'},
   {id='ele-wh-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    {id='ele-wh-moving-flame-shock',type='spell',action=8050,ranked=false,conditions=negate({type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true})},
    {id='ele-wh-moving-stop',type='stop',conditions={}},
   }},
   {id='ele-wh-finish',type='spell',action=8042,ranked=false,conditions={type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=2.5}},
   {id='ele-wh-aoe',type='block',block='tbc.shaman.elemental-aoe',prefix='ele-wh-'},
   {id='ele-wh-chain',type='spell',action=421,ranked=false,conditions=any({type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=70},own(16166),own(16246))},
   {id='ele-wh-bolt',type='spell',action=403,ranked=false,conditions={}},
  },
 },
}))
