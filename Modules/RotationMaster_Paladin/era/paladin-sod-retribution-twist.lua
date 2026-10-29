-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Retribution seal twisting (Wowhead Phase 8, simulator): Seal of Martyrdom and Seal
-- of Command swapped in the last 0.4 s before each swing, nothing on the global cooldown in the 1.9 s
-- before it, Judgement while both seals linger, then one filler per swing: Divine Storm at three Holy
-- Power, Crusader Strike, Exorcism. Disabled by default (opt-in): needs a slow two-hander, a swing
-- timer and practice.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function swing(op,v)return{type='SWING_TIME_REMAIN',offhand=false,operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.paladin.retribution.twist',revision=6,
 blocks={['sod.paladin.ret-upkeep']=2,['era.paladin.safety']=1,['era.paladin.melee-opening']=3,['sod.paladin.seal']=2},
 nameKey="Retribution, seal twisting (SoD)",descriptionKey="Off by default; enable it if you twist with a slow two-hander. Swaps between Seal of Martyrdom and Seal of Command in the last 0.4 seconds before each swing, suggests nothing on the global cooldown in the 1.9 seconds before it, judges while both seals linger, and uses one filler per swing: Divine Storm at three Holy Power, Crusader Strike, Exorcism. Needs a swing timer and practice.",
 applicability={families={'era'},actionContext='player',class='PALADIN',rulesets={'season:2'}},
 tags={'endgame','raid','retribution','melee','single-target','seal-twisting','season-of-discovery','wowhead'},
 sources={{url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/paladin/dps-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Paladin DPS rotation, seal twisting (Phase 8)',reviewedAt='2026-10-23',revision='2025-06-06'},
  },
 body={priority=104,disabled=true,switch=all({type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=20},known(20375),rune(407778),{type='PRIMARY_TALENT_TREE',tree=3}),
  cooldowns={block('stwist-upkeep','sod.paladin.ret-upkeep','stwist-'),block('stwist-safety','era.paladin.safety','stwist-')},
  rotation={
   block('stwist-opening','era.paladin.melee-opening','stwist-'),
   block('stwist-seal','sod.paladin.seal','stwist-'),
   {id='stwist-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell('stwist-pull-exorcism',415068),
    {id='stwist-pull-stop',type='stop',conditions={}},
   }},
   spell('stwist-to-command',20375,all(own(407798),negate(own(20375)),swing('LESSTHANOREQUALS',0.4))),
   spell('stwist-to-martyrdom',407798,all(own(20375),negate(own(407798)),swing('LESSTHANOREQUALS',0.4))),
   {id='stwist-danger',type='stop',conditions=swing('LESSTHANOREQUALS',1.9)},
   spell('stwist-judgement',20271,all(own(407798),own(20375))),
   spell('stwist-divine-storm',407778,{type='BUFF_STACKS',unit='player',spell=1226461,operator='GREATERTHANOREQUALS',value=3}),
   spell('stwist-crusader-strike',407676),
   spell('stwist-exorcism',415068),
  },
 },
}))
