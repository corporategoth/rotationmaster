-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Retribution seal stacking (Wowhead Phase 8, simulator): keep both Seal of Command
-- and Seal of Martyrdom up (each recast below 1 s), Divine Storm at three Holy Power (or freely
-- without the set), Crusader Strike, Exorcism, Holy Wrath on Undead and Demons (anything with the
-- Purifying Power rune), Consecration, and
-- Judgement while both seals are up. Disabled by default (opt-in): it needs the Soul of the Sealbearer
-- rune or the six-piece set that makes seals linger, which RM cannot read.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function expiring(id)return BuiltinConditions.any(BuiltinConditions.negate(own(id)),{type='BUFF_REMAIN',unit='player',spell=id,anyrank=true,ownbuff=true,operator='LESSTHANOREQUALS',value=1})end
local undead=BuiltinConditions.any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='DEMON'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.paladin.retribution.stacking',revision=6,
 blocks={['sod.paladin.ret-upkeep']=2,['era.paladin.safety']=1,['era.paladin.melee-opening']=3},
 applicability={families={'era'},actionContext='player',class='PALADIN',rulesets={'season:2'}},
 tags={'endgame','raid','retribution','melee','single-target','season-of-discovery','wowhead'},
 sources={{url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/paladin/dps-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Paladin DPS rotation, seal stacking (Phase 8)',reviewedAt='2026-10-23',revision='2025-06-06'},
  },
 body={priority=103,disabled=true,switch=BuiltinConditions.all({type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=20},BuiltinConditions.known(20375),rune(407778),{type='PRIMARY_TALENT_TREE',tree=3}),
  cooldowns={BuiltinConditions.block('sstack-upkeep','sod.paladin.ret-upkeep','sstack-'),BuiltinConditions.block('sstack-safety','era.paladin.safety','sstack-')},
  rotation={
   BuiltinConditions.block('sstack-opening','era.paladin.melee-opening','sstack-'),
   BuiltinConditions.spell('sstack-command',20375,expiring(20375)),
   BuiltinConditions.spell('sstack-martyrdom',407798,expiring(407798)),
   {id='sstack-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell('sstack-pull-exorcism',415068),
    {id='sstack-pull-stop',type='stop',conditions={}},
   }},
   BuiltinConditions.spell('sstack-divine-storm',407778,BuiltinConditions.any(BuiltinConditions.negate({type='BUFF',unit='player',spell=1226461}),{type='BUFF_STACKS',unit='player',spell=1226461,operator='GREATERTHANOREQUALS',value=3})),
   BuiltinConditions.spell('sstack-crusader-strike',407676),
   BuiltinConditions.spell('sstack-exorcism',415068),
   BuiltinConditions.spell('sstack-holy-wrath',2812,BuiltinConditions.any(rune(429144),undead)),
   BuiltinConditions.spell('sstack-consecration',26573),
   BuiltinConditions.spell('sstack-judgement',20271,BuiltinConditions.all(own(407798),own(20375))),
  },
 },
}))
