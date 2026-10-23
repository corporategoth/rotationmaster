-- Retribution seal twisting (Wowhead, Icy Veins and wowsims agree): open with Judgement of
-- the Crusader, then every swing prepare Seal of Command (rank 1) early and replace it with
-- Seal of Blood or the Martyr in the last 0.4 s, Crusader Strike as the anchor, judge only
-- Blood or Martyr, fillers last; below 12% mana roll Blood without twisting.
-- Disabled by default (opt-in): it needs a swing timer and practice. Same tree as the
-- other Retribution premades with Seal of Command and Blood or Martyr learned.
-- Shared blocks: Defaults/blocks/paladin.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function swing(op,v)return{type='SWING_TIME_REMAIN',offhand=false,operator=op,value=v}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function blood()return any(own(31892),own(348700))end
local function anySeal()local out={};for i,id in ipairs({21084,20375,31892,348700,31801,348704,21082,20166,20165,20164})do out[i]=own(id)end;return{type='OR',value=out}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.paladin.retribution.twist',revision=3,
 blocks={['tbc.paladin.ret-upkeep']=2,['tbc.paladin.melee-opening']=1,['tbc.paladin.boundaries']=1},
 nameKey='Default.TBC.Paladin.Retribution.Twist.Name',descriptionKey='Default.TBC.Paladin.Retribution.Twist.Description',
 applicability={families={'tbc'},actionContext='player',class='PALADIN',minLevel=64,maxLevel=70},
 tags={'endgame','raid','retribution','melee','single-target','seal-twisting','wowhead','icy-veins','wowsims'},
 sources={{url='https://www.wowhead.com/tbc/guide/classes/paladin/retribution/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Retribution Paladin DPS rotation',reviewedAt='2026-10-23',revision='2026-02-10'},
  {url='https://www.icy-veins.com/tbc-classic/retribution-paladin-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Retribution Paladin rotation (twisting)',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://github.com/wowsims/tbc/blob/3301fca59306a747e521274c36e073e69acc7b77/sim/paladin/retribution/rotation.go',title='wowsims/tbc Retribution twist rotation',reviewedAt='2026-10-23',revision='3301fca59306a747e521274c36e073e69acc7b77'}},
 body={priority=3,disabled=true,switch=all(known(20375),any(known(31892),known(348700)),{type='PRIMARY_TALENT_TREE',tree=3}),
  cooldowns={{id='twist-upkeep',type='block',block='tbc.paladin.ret-upkeep',prefix='twist-'}},
  rotation={
   {id='twist-opening',type='block',block='tbc.paladin.melee-opening',prefix='twist-'},
   {id='twist-low-mana',type='branch',conditions=all(mana('LESSTHAN',0.12),negate(own(20375))),onFalse={},onTrue={
    {id='twist-low-blood',type='spell',action=31892,ranked=false,conditions=negate(blood())},
    {id='twist-low-martyr',type='spell',action=348700,ranked=false,conditions=negate(blood())},
    {id='twist-low-strike',type='spell',action=35395,ranked=false,conditions={}},
    {id='twist-low-stop',type='none',conditions={}},
   }},
   {id='twist-opener',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    {id='twist-opener-judgement',type='spell',action=20271,ranked=false,conditions=own(21082)},
    {id='twist-opener-crusader',type='spell',action=21082,ranked=false,conditions=all(negate({type='DEBUFF',unit='target',spell=21183,anyrank=true}),negate(own(21082)))},
    {id='twist-opener-command',type='spell',action=20375,ranked=true,conditions=negate(own(20375))},
    {id='twist-opener-stop',type='none',conditions={}},
   }},
   {id='twist-finish-blood',type='spell',action=31892,ranked=false,conditions=all(own(20375),swing('LESSTHANOREQUALS',0.4))},
   {id='twist-finish-martyr',type='spell',action=348700,ranked=false,conditions=all(own(20375),swing('LESSTHANOREQUALS',0.4))},
   {id='twist-hold',type='none',conditions=own(20375)},
   {id='twist-crusader-strike',type='spell',action=35395,ranked=false,conditions=any(blood(),swing('GREATERTHANOREQUALS',1.5))},
   {id='twist-prepare',type='branch',conditions=all(swing('GREATERTHANOREQUALS',1.6),any(negate(known(35395)),{type='SPELL_COOLDOWN',spell=35395,operator='GREATERTHANOREQUALS',value=1.5})),onFalse={},onTrue={
    {id='twist-judge-blood',type='spell',action=20271,ranked=false,conditions=blood()},
    {id='twist-command',type='spell',action=20375,ranked=true,conditions={}},
   }},
   {id='twist-seal',type='branch',conditions=anySeal(),onTrue={},onFalse={
    {id='twist-seal-blood',type='spell',action=31892,ranked=false,conditions={}},
    {id='twist-seal-martyr',type='spell',action=348700,ranked=false,conditions={}},
   }},
   {id='twist-exorcism',type='spell',action=879,ranked=false,conditions=all(any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='DEMON'}),mana('GREATERTHANOREQUALS',0.4))},
   {id='twist-consecration',type='spell',action=26573,ranked=false,conditions=all(mana('GREATERTHANOREQUALS',0.6),negate({type='BEYOND_MELEE',unit='target'}))},
  },
 },
}))
