-- Season of Discovery Shockadin (wowsims Phase 8): a Holy-tree damage build. Seal of Martyrdom (else
-- Righteousness) judged as it runs out, Holy Shock to keep Sunlight up or at three Holy Power,
-- Exorcism, Crusader Strike. Disabled by default: nothing readable tells it apart from a Holy healer,
-- so enable it yourself.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function sealRemain(id)return{type='BUFF_REMAIN',unit='player',spell=id,anyrank=true,ownbuff=true,operator='LESSTHANOREQUALS',value=1.5}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.paladin.shockadin',revision=1,
 blocks={['sod.paladin.ret-upkeep']=1,['era.paladin.safety']=1,['era.paladin.melee-opening']=1,['era.paladin.boundaries']=1,['sod.paladin.seal']=1},
 nameKey='Default.SoD.Paladin.Shockadin.Name',descriptionKey='Default.SoD.Paladin.Shockadin.Description',
 applicability={families={'era'},actionContext='player',class='PALADIN',minLevel=40,maxLevel=60,rulesets={'season:2'}},
 tags={'endgame','raid','holy','melee','single-target','season-of-discovery','wowsims'},
 sources={{url='https://github.com/wowsims/sod/tree/0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e/ui/retribution_paladin',title='wowsims/sod Phase 8 Shockadin APLs',reviewedAt='2026-10-23',revision='0e3f6ef'}},
 body={priority=100,disabled=true,switch={type='PRIMARY_TALENT_TREE',tree=1},
  cooldowns={block('shock-upkeep','sod.paladin.ret-upkeep','shock-'),block('shock-safety','era.paladin.safety','shock-')},
  rotation={
   block('shock-opening','era.paladin.melee-opening','shock-'),
   spell('shock-judgement',20271,any(sealRemain(407798),sealRemain(20154))),
   block('shock-seal','sod.paladin.seal','shock-'),
   {id='shock-pull',type='branch',conditions=negate({type='COMBAT',unit='player'}),onFalse={},onTrue={
    spell('shock-pull-holy-shock',20473),
    {id='shock-pull-stop',type='none',conditions={}},
   }},
   spell('shock-sunlight',20473,any(negate({type='BUFF',unit='player',spell=1239543}),{type='BUFF_REMAIN',unit='player',spell=1239543,operator='LESSTHANOREQUALS',value=1.5})),
   spell('shock-exorcism',415068),
   spell('shock-holy-power',20473,{type='BUFF_STACKS',unit='player',spell=1226461,operator='GREATERTHANOREQUALS',value=3}),
   spell('shock-crusader-strike',407676),
  },
 },
}))
