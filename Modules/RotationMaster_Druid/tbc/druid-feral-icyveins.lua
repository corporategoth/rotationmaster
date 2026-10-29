-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Feral cat and bear, Icy Veins with Warcraft Tavern and simulator: Rip from four combo
-- points on a target that lives, Ferocious Bite between Rips at moderate energy without
-- Clearcasting (bite-weave), Mangle kept up, Shred from behind (Mangle or Claw when the
-- target is on you); bear keeps Mangle, five Lacerates and Swipe as filler, Maul dumps rage.
-- Shared blocks: Defaults/blocks/druid.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function rip()return{type='DEBUFF',unit='target',spell=1079,anyrank=true,owndebuff=true}end
local function energy(op,v)return{type='POWER',unit='player',operator=op,value=v}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.druid.feral.icyveins',revision=5,
 blocks={['tbc.druid.boundaries']=4,['tbc.druid.upkeep']=1,['tbc.druid.feral-cooldowns']=2,['tbc.druid.cat-opening']=2,
  ['tbc.druid.cat-builders']=1,['tbc.druid.bear-core']=2,['tbc.druid.feral-humanoid']=2},
 nameKey='Default.TBC.Druid.Feral.IcyVeins.Name',descriptionKey='Default.TBC.Druid.Feral.IcyVeins.Description',
 applicability={families={'tbc'},actionContext='player',class='DRUID'},
 tags={'leveling','endgame','feral','melee','tank','single-target','aoe','icy-veins','warcraft-tavern'},
 sources={{url='https://www.icy-veins.com/tbc-classic/feral-druid-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Feral Druid DPS rotation',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/feral-druid-tank-pve-rotation-cooldowns-abilities',title='Icy Veins: Feral Druid tank rotation',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/feral-druid-leveling-guide',title='Icy Veins: Feral Druid leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.warcrafttavern.com/tbc/guides/pve-feral-druid-dps-rotation-abilities/',title='Warcraft Tavern: Feral DPS rotation',reviewedAt='2026-10-23'},
  {url='https://www.warcrafttavern.com/tbc/guides/pve-feral-druid-tank-rotation-abilities/',title='Warcraft Tavern: Feral tank rotation',reviewedAt='2026-10-23'},
  },
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=2}}},
  cooldowns={
   {id='feral-icy-upkeep',type='block',block='tbc.druid.upkeep',prefix='feral-icy-'},
   {id='feral-icy-cooldowns',type='block',block='tbc.druid.feral-cooldowns',prefix='feral-icy-'},
   {id='feral-icy-frenzied-regeneration',type='spell',action=22842,ranked=false,conditions=all(any({type='FORM',form=5487},{type='FORM',form=9634}),{type='COMBAT',unit='player'},{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=0.4})},
  },
  rotation={
   {id='feral-icy-boundaries',type='block',block='tbc.druid.boundaries',prefix='feral-icy-'},
   {id='feral-icy-cat',type='branch',conditions={type='FORM',form=768},onFalse={},onTrue={
    {id='feral-icy-cat-opening',type='block',block='tbc.druid.cat-opening',prefix='feral-icy-cat-'},
    {id='feral-icy-finisher',type='branch',conditions={type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=4},onFalse={},onTrue={
     {id='feral-icy-rip',type='spell',action=1079,ranked=false,conditions=all(negate(rip()),negate({type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=10}))},
     {id='feral-icy-bite',type='spell',action=22568,ranked=false,conditions=all(negate(own(16870)),energy('LESSTHAN',57))},
    }},
    {id='feral-icy-builders',type='block',block='tbc.druid.cat-builders',prefix='feral-icy-'},
    {id='feral-icy-powershift',type='spell',action=768,ranked=false,disabled=true,conditions=all({type='GROUP'},energy('LESSTHANOREQUALS',22),negate(own(16870)),{type='MANAPCT',unit='player',operator='GREATERTHANOREQUALS',value=0.1})},
    {id='feral-icy-wait',type='stop',conditions={}},
   }},
   {id='feral-icy-bear',type='branch',conditions=any({type='FORM',form=5487},{type='FORM',form=9634}),onFalse={},onTrue={
    {id='feral-icy-bear-core',type='block',block='tbc.druid.bear-core',prefix='feral-icy-bear-'},
    {id='feral-icy-lacerate',type='spell',action=33745,ranked=false,conditions=negate({type='DEBUFF_STACKS',unit='target',spell=33745,owndebuff=true,operator='GREATERTHANOREQUALS',value=5})},
    {id='feral-icy-swipe',type='spell',action=779,ranked=false,conditions={}},
    {id='feral-icy-bear-wait',type='stop',conditions={}},
   }},
   {id='feral-icy-humanoid',type='block',block='tbc.druid.feral-humanoid',prefix='feral-icy-'},
  },
 },
}))
