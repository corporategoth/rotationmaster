-- Classic Era Retribution seal twisting (Warcraft Tavern, wowsims): keep Seal of Righteousness up,
-- swap to rank-1 Seal of Command in the last 0.4 s before a swing and back again, Judgement whenever
-- it is ready, Consecration with Vengeance, Hammer of Wrath, Exorcism on Undead and Demons.
-- Disabled by default (opt-in): it needs a swing timer, practice and a lot of mana.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function swing(op,v)return{type='SWING_TIME_REMAIN',offhand=false,operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function righteousness()return{type='OR',value={own(20154),own(21084)}}end
local function sealed()local out={};for i,id in ipairs({20154,21084,20375,21082,20166,20165,20164})do out[i]=own(id)end;return{type='OR',value=out}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.paladin.retribution.twist',revision=2,
 blocks={['era.paladin.ret-upkeep']=2,['era.paladin.safety']=1,['era.paladin.melee-opening']=1,['era.paladin.boundaries']=1,['era.paladin.undead']=1},
 nameKey='Default.Era.Paladin.Retribution.Twist.Name',descriptionKey='Default.Era.Paladin.Retribution.Twist.Description',
 applicability={families={'era'},actionContext='player',class='PALADIN',minLevel=20,maxLevel=60},
 tags={'endgame','raid','retribution','melee','single-target','seal-twisting','warcraft-tavern','wowsims'},
 sources={{url='https://www.warcrafttavern.com/wow-classic/guides/pve-retribution-paladin-rotations-cooldowns/',title='Warcraft Tavern: Classic Retribution Paladin rotations (seal twisting)',reviewedAt='2026-10-23'},
  {url='https://github.com/wowsims/classic/tree/7779ebbf79dc7f1341e6ab939b28a3402c9a730a/ui/retribution_paladin',title='wowsims/classic basic Retribution APL',reviewedAt='2026-10-23',revision='7779ebb'}},
 body={priority=3,disabled=true,switch=all({type='SPELL_KNOWN',spell=20375},{type='PRIMARY_TALENT_TREE',tree=3}),
  cooldowns={block('twist-upkeep','era.paladin.ret-upkeep','twist-'),block('twist-safety','era.paladin.safety','twist-')},
  rotation={
   block('twist-opening','era.paladin.melee-opening','twist-'),
   {id='twist-seal',type='branch',conditions=sealed(),onTrue={},onFalse={spell('twist-seal-righteousness',20154)}},
   {id='twist-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell('twist-pull-judgement',20271),
    {id='twist-pull-stop',type='none',conditions={}},
   }},
   {id='twist-to-command',type='spell',action=20375,ranked=true,conditions=all(righteousness(),swing('LESSTHANOREQUALS',0.4))},
   spell('twist-to-righteousness',20154,all(own(20375),swing('LESSTHANOREQUALS',0.4))),
   spell('twist-judgement',20271),
   block('twist-undead','era.paladin.undead','twist-'),
   spell('twist-hammer-of-wrath',24275,mana('GREATERTHANOREQUALS',0.2)),
   spell('twist-consecration',26573,all(own(20050),mana('GREATERTHANOREQUALS',0.3))),
  },
 },
}))
