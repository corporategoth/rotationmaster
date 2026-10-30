-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Retribution seal twisting (Wowhead Phase 8, simulator): Seal of Martyrdom and Seal
-- of Command swapped in the last 0.4 s before each swing, nothing on the global cooldown in the 1.9 s
-- before it, Judgement while both seals linger, then one filler per swing: Divine Storm at three Holy
-- Power, Crusader Strike, Exorcism. Disabled by default (opt-in): needs a slow two-hander, a swing
-- timer and practice.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function swing(op,v)return{type='SWING_TIME_REMAIN',offhand=false,operator=op,value=v}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.paladin.retribution.twist',revision=6,
 blocks={['sod.paladin.ret-upkeep']=2,['era.paladin.safety']=1,['era.paladin.melee-opening']=3,['sod.paladin.seal']=2},
 applicability={families={'era'},actionContext='player',class='PALADIN',rulesets={'season:2'}},
 tags={'endgame','raid','retribution','melee','single-target','seal-twisting','season-of-discovery','wowhead'},
 sources={{url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/paladin/dps-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Paladin DPS rotation, seal twisting (Phase 8)',reviewedAt='2026-10-23',revision='2025-06-06'},
  },
 body={priority=104,disabled=true,switch=BuiltinConditions.all({type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=20},BuiltinConditions.known(20375),rune(407778),{type='PRIMARY_TALENT_TREE',tree=3}),
  cooldowns={BuiltinConditions.block('stwist-upkeep','sod.paladin.ret-upkeep','stwist-'),BuiltinConditions.block('stwist-safety','era.paladin.safety','stwist-')},
  rotation={
   BuiltinConditions.block('stwist-opening','era.paladin.melee-opening','stwist-'),
   BuiltinConditions.block('stwist-seal','sod.paladin.seal','stwist-'),
   {id='stwist-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell('stwist-pull-exorcism',415068),
    {id='stwist-pull-stop',type='stop',conditions={}},
   }},
   BuiltinConditions.spell('stwist-to-command',20375,BuiltinConditions.all(own(407798),BuiltinConditions.negate(own(20375)),swing('LESSTHANOREQUALS',0.4))),
   BuiltinConditions.spell('stwist-to-martyrdom',407798,BuiltinConditions.all(own(20375),BuiltinConditions.negate(own(407798)),swing('LESSTHANOREQUALS',0.4))),
   {id='stwist-danger',type='stop',conditions=swing('LESSTHANOREQUALS',1.9)},
   BuiltinConditions.spell('stwist-judgement',20271,BuiltinConditions.all(own(407798),own(20375))),
   BuiltinConditions.spell('stwist-divine-storm',407778,{type='BUFF_STACKS',unit='player',spell=1226461,operator='GREATERTHANOREQUALS',value=3}),
   BuiltinConditions.spell('stwist-crusader-strike',407676),
   BuiltinConditions.spell('stwist-exorcism',415068),
  },
 },
}))
