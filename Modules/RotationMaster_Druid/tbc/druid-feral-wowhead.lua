-- Feral cat and bear, Wowhead: Rip whenever it is down at four or more combo points,
-- Ferocious Bite only on a target about to die (no bite-weaving), Mangle kept up, Shred;
-- bear spends free GCDs on Lacerate (static threat) before Swipe; Innervate for a cat's mana.
-- Shared blocks: Defaults/blocks/druid.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function energy(op,v)return{type='POWER',unit='player',operator=op,value=v}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.druid.feral.wowhead',revision=1,
 blocks={['tbc.druid.boundaries']=1,['tbc.druid.upkeep']=1,['tbc.druid.feral-cooldowns']=1,['tbc.druid.cat-opening']=1,
  ['tbc.druid.cat-builders']=1,['tbc.druid.bear-core']=1,['tbc.druid.feral-humanoid']=1},
 nameKey='Default.TBC.Druid.Feral.Wowhead.Name',descriptionKey='Default.TBC.Druid.Feral.Wowhead.Description',
 applicability={families={'tbc'},actionContext='player',class='DRUID',minLevel=10,maxLevel=70},
 tags={'leveling','endgame','feral','melee','tank','single-target','aoe','wowhead'},
 sources={{url='https://www.wowhead.com/tbc/guide/classes/druid/feral/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Feral Druid DPS rotation',reviewedAt='2026-10-23',revision='2026-02-10'},
  {url='https://www.wowhead.com/tbc/guide/classes/druid/feral/tank-rotation-cooldowns-abilities-pve',title='Wowhead: Feral Druid tank rotation',reviewedAt='2026-10-23',revision='2024-05-18'},
  {url='https://www.wowhead.com/tbc/guide/feral-druid-dps-leveling-guide-burning-crusade-classic',title='Wowhead: Feral Druid leveling',reviewedAt='2026-10-23',revision='2026-01-30'}},
 body={priority=20,switch={type='PRIMARY_TALENT_TREE',tree=2},
  cooldowns={
   {id='feral-wh-upkeep',type='block',block='tbc.druid.upkeep',prefix='feral-wh-'},
   {id='feral-wh-cooldowns',type='block',block='tbc.druid.feral-cooldowns',prefix='feral-wh-'},
   {id='feral-wh-innervate',type='spell',action=29166,ranked=false,conditions=all({type='COMBAT',unit='player'},{type='MANAPCT',unit='player',operator='LESSTHAN',value=0.3})},
  },
  rotation={
   {id='feral-wh-boundaries',type='block',block='tbc.druid.boundaries',prefix='feral-wh-'},
   {id='feral-wh-cat',type='branch',conditions=own(768),onFalse={},onTrue={
    {id='feral-wh-cat-opening',type='block',block='tbc.druid.cat-opening',prefix='feral-wh-cat-'},
    {id='feral-wh-finisher',type='branch',conditions={type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=4},onFalse={},onTrue={
     {id='feral-wh-rip',type='spell',action=1079,ranked=false,conditions=negate({type='DEBUFF',unit='target',spell=1079,anyrank=true,owndebuff=true})},
     {id='feral-wh-bite',type='spell',action=22568,ranked=false,conditions={type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=10}},
    }},
    {id='feral-wh-builders',type='block',block='tbc.druid.cat-builders',prefix='feral-wh-'},
    {id='feral-wh-powershift',type='spell',action=768,ranked=false,disabled=true,conditions=all({type='GROUP'},energy('LESSTHANOREQUALS',22),negate(own(16870)),{type='MANAPCT',unit='player',operator='GREATERTHANOREQUALS',value=0.1})},
    {id='feral-wh-wait',type='none',conditions={}},
   }},
   {id='feral-wh-bear',type='branch',conditions=any(own(5487),own(9634)),onFalse={},onTrue={
    {id='feral-wh-bear-core',type='block',block='tbc.druid.bear-core',prefix='feral-wh-bear-'},
    {id='feral-wh-lacerate',type='spell',action=33745,ranked=false,conditions={}},
    {id='feral-wh-swipe',type='spell',action=779,ranked=false,conditions={}},
    {id='feral-wh-bear-wait',type='none',conditions={}},
   }},
   {id='feral-wh-humanoid',type='block',block='tbc.druid.feral-humanoid',prefix='feral-wh-'},
  },
 },
}))
