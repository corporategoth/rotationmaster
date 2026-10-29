-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Elemental, Icy Veins shape with simulator' adaptive mana model: Lightning Bolt filler,
-- Chain Lightning with Elemental Mastery, on Clearcasting with mana to spare, or on
-- cooldown when mana is in surplus; Flame Shock only while moving. Below Chain
-- Lightning (32) a target in melee is left to auto-attack (Icy Veins leveling).
-- Shared blocks: Defaults/blocks/shaman.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.shaman.elemental.icyveins',revision=4,
 blocks={['tbc.shaman.shield']=1,['tbc.shaman.mainhand-imbue']=1,['tbc.shaman.elemental-totems']=1,['tbc.shaman.bloodlust']=1,
  ['tbc.shaman.elemental-opening']=2,['tbc.shaman.boundaries']=3,['tbc.shaman.interrupt']=1,['tbc.shaman.elemental-aoe']=1},
 nameKey='Default.TBC.Shaman.Elemental.IcyVeins.Name',descriptionKey='Default.TBC.Shaman.Elemental.IcyVeins.Description',
 applicability={families={'tbc'},actionContext='player',class='SHAMAN'},
 tags={'leveling','endgame','elemental','caster','single-target','aoe','icy-veins'},
 sources={{url='https://www.icy-veins.com/tbc-classic/elemental-shaman-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Elemental Shaman rotation',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/elemental-shaman-leveling-guide',title='Icy Veins: Elemental Shaman leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  },
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=1}}},
  cooldowns={
   {id='ele-icy-shield',type='block',block='tbc.shaman.shield',prefix='ele-icy-'},
   {id='ele-icy-imbue',type='block',block='tbc.shaman.mainhand-imbue',prefix='ele-icy-'},
   {id='ele-icy-totems',type='block',block='tbc.shaman.elemental-totems',prefix='ele-icy-'},
   {id='ele-icy-elemental-mastery',type='spell',action=16166,ranked=false,conditions=all({type='COMBAT',unit='player'},{type='SPELL_AVAIL',spell=421})},
   {id='ele-icy-lust',type='block',block='tbc.shaman.bloodlust',prefix='ele-icy-'},
   {id='ele-icy-fire-elemental',type='spell',action=2894,ranked=false,disabled=true,conditions=all({type='COMBAT',unit='player'},{type='CLASSIFICATION',unit='target',value='worldboss'})},
  },
  rotation={
   {id='ele-icy-opening',type='block',block='tbc.shaman.elemental-opening',prefix='ele-icy-'},
   {id='ele-icy-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    {id='ele-icy-moving-flame-shock',type='spell',action=8050,ranked=false,conditions=negate({type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true})},
    {id='ele-icy-moving-stop',type='stop',conditions={}},
   }},
   {id='ele-icy-aoe',type='block',block='tbc.shaman.elemental-aoe',prefix='ele-icy-'},
   {id='ele-icy-mastery-chain',type='spell',action=421,ranked=false,conditions=own(16166)},
   {id='ele-icy-chain',type='spell',action=421,ranked=false,conditions=any(all(own(16246),mana('GREATERTHANOREQUALS',0.4)),mana('GREATERTHANOREQUALS',0.8))},
   {id='ele-icy-bolt',type='spell',action=403,ranked=false,conditions=any({type='SPELL_KNOWN',spell=421},{type='BEYOND_MELEE',unit='target'})},
  },
 },
}))
