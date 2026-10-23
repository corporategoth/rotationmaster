-- Protection, Wowhead with wowsims: a pre-pull of Holy Shield, Avenger's Shield and
-- Judgement; against a crushing target (world boss, or three or more levels above you)
-- Holy Shield comes first; otherwise Consecration, Exorcism on Undead and Demons,
-- Judgement, Holy Shield, then Avenger's Shield except on crushing targets. Seal of
-- Wisdom on packs when mana runs short, else Righteousness. Avenging Wrath on pull.
-- Selected by the Protection tree or by Righteous Fury (any spec that is tanking).
-- Shared blocks: Defaults/blocks/paladin.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function undead()return any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='DEMON'})end
local function crushing()return any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='LEVEL',unit='target',operator='GREATERTHANOREQUALS',value=3,relative=true})end
local function anySeal()local out={};for i,id in ipairs({21084,20375,31892,348700,31801,348704,21082,20166,20165,20164})do out[i]=own(id)end;return{type='OR',value=out}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.paladin.protection.wowhead',revision=1,
 blocks={['tbc.paladin.tank-upkeep']=1,['tbc.paladin.melee-opening']=1,['tbc.paladin.boundaries']=1},
 nameKey='Default.TBC.Paladin.Protection.Wowhead.Name',descriptionKey='Default.TBC.Paladin.Protection.Wowhead.Description',
 applicability={families={'tbc'},actionContext='player',class='PALADIN',minLevel=1,maxLevel=70},
 tags={'leveling','endgame','protection','tank','single-target','aoe','wowhead','wowsims'},
 sources={{url='https://www.wowhead.com/tbc/guide/classes/paladin/tank-rotation-cooldowns-abilities-pve',title='Wowhead: Protection Paladin tank rotation',reviewedAt='2026-10-23',revision='2026-02-10'},
  {url='https://www.wowhead.com/tbc/guide/classes/paladin/protection/leveling-tips',title='Wowhead: Protection Paladin leveling',reviewedAt='2026-10-23',revision='2026-09-04'},
  {url='https://github.com/wowsims/tbc/blob/3301fca59306a747e521274c36e073e69acc7b77/sim/paladin/protection/rotation.go',title='wowsims/tbc Protection rotation',reviewedAt='2026-10-23',revision='3301fca59306a747e521274c36e073e69acc7b77'}},
 body={priority=20,switch=any(own(25780),{type='PRIMARY_TALENT_TREE',tree=2}),
  cooldowns={
   {id='prot-wh-upkeep',type='block',block='tbc.paladin.tank-upkeep',prefix='prot-wh-'},
   {id='prot-wh-avenging-wrath',type='spell',action=31884,ranked=false,conditions=all({type='COMBAT',unit='player'},negate({type='DEBUFF',unit='player',spell=25771}))},
  },
  rotation={
   {id='prot-wh-opening',type='block',block='tbc.paladin.melee-opening',prefix='prot-wh-'},
   {id='prot-wh-seal',type='branch',conditions=negate(anySeal()),onFalse={},onTrue={
    {id='prot-wh-seal-wisdom',type='spell',action=20166,ranked=false,conditions=all({type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=3},mana('LESSTHAN',0.5))},
    {id='prot-wh-seal-righteousness',type='spell',action=21084,ranked=false,conditions={}},
   }},
   {id='prot-wh-pull',type='branch',conditions=negate({type='COMBAT',unit='player'}),onFalse={},onTrue={
    {id='prot-wh-pull-holy-shield',type='spell',action=20925,ranked=false,conditions=negate(own(20925))},
    {id='prot-wh-pull-avengers-shield',type='spell',action=31935,ranked=false,conditions={}},
    {id='prot-wh-pull-judgement',type='spell',action=20271,ranked=false,conditions={}},
    {id='prot-wh-pull-stop',type='none',conditions={}},
   }},
   {id='prot-wh-crushing',type='branch',conditions=crushing(),onFalse={},onTrue={
    {id='prot-wh-crush-holy-shield',type='spell',action=20925,ranked=false,conditions=negate(own(20925))},
   }},
   {id='prot-wh-consecration',type='spell',action=26573,ranked=false,conditions=negate({type='BEYOND_MELEE',unit='target'})},
   {id='prot-wh-exorcism',type='spell',action=879,ranked=false,conditions=all(undead(),mana('GREATERTHANOREQUALS',0.4))},
   {id='prot-wh-judgement',type='spell',action=20271,ranked=false,conditions={}},
   {id='prot-wh-holy-shield',type='spell',action=20925,ranked=false,conditions=negate(own(20925))},
   {id='prot-wh-holy-wrath',type='spell',action=2812,ranked=false,conditions=all(undead(),{type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=3})},
   {id='prot-wh-avengers-shield',type='spell',action=31935,ranked=false,conditions=negate(crushing())},
   {id='prot-wh-hammer',type='spell',action=24275,ranked=false,conditions=mana('GREATERTHANOREQUALS',0.4)},
  },
 },
}))
