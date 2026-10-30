-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Shockadin (simulator Phase 8): a Holy-tree damage build. Seal of Martyrdom (else
-- Righteousness) judged as it runs out, Holy Shock to keep Sunlight up or at three Holy Power,
-- Exorcism, Crusader Strike. Disabled by default (opt-in); it applies with Holy as the main tree and
-- the Shock and Awe rune (passive, Holy Shock damage builds) engraved, which no Holy healer takes.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function sealRemain(id)return{type='BUFF_REMAIN',unit='player',spell=id,anyrank=true,ownbuff=true,operator='LESSTHANOREQUALS',value=1.5}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.paladin.shockadin',revision=6,
 blocks={['sod.paladin.ret-upkeep']=2,['era.paladin.safety']=1,['era.paladin.melee-opening']=3,['sod.paladin.seal']=2},
 applicability={families={'era'},actionContext='player',class='PALADIN',rulesets={'season:2'}},
 tags={'endgame','raid','holy','melee','single-target','season-of-discovery'},
 sources={},
 body={priority=100,disabled=true,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=40},{type='RUNE_ENGRAVED',spell=462834},{type='PRIMARY_TALENT_TREE',tree=1}}},
  cooldowns={BuiltinConditions.block('shock-upkeep','sod.paladin.ret-upkeep','shock-'),BuiltinConditions.block('shock-safety','era.paladin.safety','shock-')},
  rotation={
   BuiltinConditions.block('shock-opening','era.paladin.melee-opening','shock-'),
   BuiltinConditions.spell('shock-judgement',20271,BuiltinConditions.any(sealRemain(407798),sealRemain(20154))),
   BuiltinConditions.block('shock-seal','sod.paladin.seal','shock-'),
   {id='shock-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell('shock-pull-holy-shock',20473),
    {id='shock-pull-stop',type='stop',conditions={}},
   }},
   BuiltinConditions.spell('shock-sunlight',20473,BuiltinConditions.any(BuiltinConditions.negate({type='BUFF',unit='player',spell=1239543}),{type='BUFF_REMAIN',unit='player',spell=1239543,operator='LESSTHANOREQUALS',value=1.5})),
   BuiltinConditions.spell('shock-exorcism',415068),
   BuiltinConditions.spell('shock-holy-power',20473,{type='BUFF_STACKS',unit='player',spell=1226461,operator='GREATERTHANOREQUALS',value=3}),
   BuiltinConditions.spell('shock-crusader-strike',407676),
  },
 },
}))
