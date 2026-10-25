-- Retribution, Wowhead with wowsims: a judgement opener chosen by mana (Wisdom when
-- low, else the Crusader), the best seal you know, Crusader Strike, Judgement only of a
-- seal worth judging (Command only on a stunned target), Exorcism on Undead and Demons,
-- Consecration only for packs. Hammer of Wrath is left out: Wowhead keeps it for fleeing
-- targets, wowsims never casts it, and RUNNER needs the MobInfo2 addon.
-- Catch-all Paladin premade (lowest priority): every level, no talents, ties.
-- Shared blocks: Defaults/blocks/paladin.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function debuff(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function anySeal()local out={};for i,id in ipairs({21084,20375,31892,348700,31801,348704,21082,20166,20165,20164})do out[i]=own(id)end;return{type='OR',value=out}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.paladin.retribution.wowhead',revision=6,
 blocks={['tbc.paladin.ret-upkeep']=2,['tbc.paladin.melee-opening']=2,['tbc.paladin.boundaries']=2},
 nameKey='Default.TBC.Paladin.Retribution.Wowhead.Name',descriptionKey='Default.TBC.Paladin.Retribution.Wowhead.Description',
 applicability={families={'tbc'},actionContext='player',class='PALADIN'},
 tags={'leveling','endgame','retribution','melee','single-target','aoe','wowhead','wowsims'},
 sources={{url='https://www.wowhead.com/tbc/guide/classes/paladin/retribution/leveling-tips',title='Wowhead: Retribution Paladin leveling',reviewedAt='2026-10-23',revision='2026-09-04'},
  {url='https://www.wowhead.com/tbc/guide/classes/paladin/retribution/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Retribution Paladin DPS rotation',reviewedAt='2026-10-23',revision='2026-02-10'},
  {url='https://github.com/wowsims/tbc/blob/3301fca59306a747e521274c36e073e69acc7b77/sim/paladin/retribution/rotation.go',title='wowsims/tbc Retribution rotation',reviewedAt='2026-10-23',revision='3301fca59306a747e521274c36e073e69acc7b77',notes='Exorcism and Consecration mana gates; no Hammer of Wrath.'}},
 body={priority=2,
  cooldowns={{id='ret-wh-upkeep',type='block',block='tbc.paladin.ret-upkeep',prefix='ret-wh-'}},
  rotation={
   {id='ret-wh-opening',type='block',block='tbc.paladin.melee-opening',prefix='ret-wh-'},
   {id='ret-wh-opener',type='branch',conditions=all(negate(debuff(21183)),negate(debuff(20186)),negate({type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=10})),onFalse={},onTrue={
    {id='ret-wh-opener-judgement',type='spell',action=20271,ranked=false,conditions=any(own(21082),own(20166))},
    {id='ret-wh-opener-wisdom',type='spell',action=20166,ranked=false,conditions=all(mana('LESSTHAN',0.6),negate(any(own(21082),own(20166))))},
    {id='ret-wh-opener-crusader',type='spell',action=21082,ranked=false,conditions=negate(any(own(21082),own(20166)))},
   }},
   {id='ret-wh-seal',type='branch',conditions=anySeal(),onTrue={},onFalse={
    {id='ret-wh-seal-blood',type='spell',action=31892,ranked=false,conditions={}},
    {id='ret-wh-seal-martyr',type='spell',action=348700,ranked=false,conditions={}},
    {id='ret-wh-seal-command',type='spell',action=20375,ranked=false,conditions={}},
    {id='ret-wh-seal-righteousness',type='spell',action=21084,ranked=false,conditions={}},
   }},
   {id='ret-wh-crusader-strike',type='spell',action=35395,ranked=false,conditions={}},
   {id='ret-wh-judgement',type='spell',action=20271,ranked=false,conditions=all(mana('GREATERTHANOREQUALS',0.3),
    any(own(21084),own(31892),own(348700),all(own(20375),any(debuff(853),debuff(20066)))))},
   {id='ret-wh-exorcism',type='spell',action=879,ranked=false,conditions=all(any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='DEMON'}),mana('GREATERTHANOREQUALS',0.4))},
   {id='ret-wh-consecration',type='spell',action=26573,ranked=false,conditions=all({type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=3},mana('GREATERTHANOREQUALS',0.5))},
  },
 },
}))
