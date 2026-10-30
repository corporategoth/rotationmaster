-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Warrior melee DPS, Wowhead Phase 7/8 Battle Forecaster stance dance
-- (alternative premade; same catch-all switch, lower priority). Needs Soul of the Battle
-- Forecaster (shoulder) or the Tier 1 six-piece, which Rotation Master cannot see: the stance
-- swaps keep the forecast buffs up (verify the buff logic in game), Heroic Strike almost always,
-- then Bloodthirst, Blood Surge Slam, Whirlwind, Raging Blow and Hamstring; no Rend and no
-- Overpower. Same boundaries and reminders as the recommended SoD premade (era/blocks.lua).
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function rage(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
local function forecast(id)return BuiltinConditions.any(BuiltinConditions.negate(buff(id)),{type='BUFF_REMAIN',unit='player',spell=id,operator='LESSTHAN',value=3})end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local unqueued=BuiltinConditions.all(BuiltinConditions.negate(queued(78)),BuiltinConditions.negate(queued(845)))
local berserker={type='FORM',form=2458}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.warrior.dps.wowhead',revision=6,
 blocks={['era.warrior.boundaries']=3,['era.warrior.upkeep']=1},
 applicability={families={'era'},actionContext='player',class='WARRIOR',rulesets={'season:2'}},
 tags={'dps','melee','endgame','season-of-discovery','wowhead'},
 sources={{url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/warrior/dps-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Warrior DPS rotation (Battle Forecaster, Phase 7/8)',reviewedAt='2026-10-23',revision='2025-04-12'}},
 body={priority=45,disabled=true,
 cooldowns={block('era.warrior.upkeep','sod-fc-'),
  BuiltinConditions.spell('sod-fc-berserker-stance',2458,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(berserker),BuiltinConditions.negate({type='FORM',form=71}),forecast(457816))),
  BuiltinConditions.spell('sod-fc-battle-stance',2457,BuiltinConditions.all(BuiltinConditions.combat(),berserker,forecast(457817))),
  BuiltinConditions.spell('sod-fc-heroic-strike',78,BuiltinConditions.all(BuiltinConditions.combat(),unqueued,enemies('LESSTHAN',2),rage('GREATERTHANOREQUALS',20))),
  BuiltinConditions.spell('sod-fc-cleave',845,BuiltinConditions.all(BuiltinConditions.combat(),unqueued,enemies('GREATERTHANOREQUALS',2),rage('GREATERTHANOREQUALS',30))),
  BuiltinConditions.spell('sod-fc-bloodrage',2687,BuiltinConditions.all(BuiltinConditions.combat(),{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.4})),
  BuiltinConditions.spell('sod-fc-death-wish',12328,BuiltinConditions.combat()),
 },
 rotation={
 block('era.warrior.boundaries','sod-fc-'),
 BuiltinConditions.spell('sod-fc-bloodthirst',23881),
 BuiltinConditions.spell('sod-fc-blood-surge-slam',1464,buff(413399)),
 BuiltinConditions.spell('sod-fc-whirlwind',1680),
 BuiltinConditions.spell('sod-fc-raging-blow',402911),
 BuiltinConditions.spell('sod-fc-hamstring',1715,rage('GREATERTHANOREQUALS',60)),
 }},
}))
