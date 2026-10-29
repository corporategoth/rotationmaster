-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Warrior melee DPS, levels 1–60: two-hander, dual wield, Gladiator and
-- leveling (the SoD catch-all outside Defensive Stance). simulator/sod Phase 6 with Wowhead Phase
-- 7/8: Charge; Victory Rush; Intercept; Whirlwind (Thunder Clap before it) on two engaged enemies;
-- Slam at three Slammin' stacks (Phase 8 four-piece); Rend kept up; Slam on Blood Surge (on
-- cooldown with the Precise Timing rune);
-- Bloodthirst; Mortal Strike; Shield Slam; Overpower; then by build: Quick Strike for two-handers
-- (the engraved glove rune), or Whirlwind, Raging Blow and Devastate (Sunder before it) for dual
-- wield; Execute with 30 rage or Sudden Death; Hamstring near the rage cap. Reminders: Battle and
-- Commanding Shout, Heroic Strike from 50 rage (always while Consumed by Rage enrages you), Cleave,
-- Bloodrage, Rampage, Death Wish, Recklessness, Sweeping Strikes, interrupts. Shared parts:
-- era/blocks.lua. Left manual: stance dancing; Berserker Rage and the Taste for Blood Battle
-- Stance dip are listed off.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function rage(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function target(op,v)return{type='HEALTHPCT',unit='target',operator=op,value=v}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
local function cooling(id,n)return BuiltinConditions.all(BuiltinConditions.known(id),{type='SPELL_COOLDOWN',spell=id,operator='GREATERTHAN',value=n})end
local function optional(step)step.disabled=true;return step end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local boss={type='CLASSIFICATION',unit='target',value='worldboss'}
local big=BuiltinConditions.any(boss,{type='CLASSIFICATION',unit='target',value='elite'})
local strike=BuiltinConditions.any(BuiltinConditions.known(12294),BuiltinConditions.known(23881))
local unqueued=BuiltinConditions.all(BuiltinConditions.negate(queued(78)),BuiltinConditions.negate(queued(845)))
local immune=BuiltinConditions.any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='MECHANICAL'},{type='CREATURE',unit='target',value='ELEMENTAL'})
local enraged=BuiltinConditions.any(buff(12880),buff(425415),buff(427066),buff(29131),buff(18499))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.warrior.dps',revision=6,
 blocks={['era.warrior.boundaries']=3,['era.warrior.upkeep']=1,['era.warrior.aoe-strikes']=1},
 applicability={families={'era'},actionContext='player',class='WARRIOR',rulesets={'season:2'}},
 tags={'dps','melee','leveling','endgame','aoe','season-of-discovery','wowhead'},
 sources={
 {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/warrior/dps-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Warrior DPS rotation (Phase 7/8)',reviewedAt='2026-10-23',revision='2025-04-12'},
 {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/warrior/dps-talent-builds-runes',title='Wowhead: SoD Warrior DPS talents and runes (Phase 8)',reviewedAt='2026-10-23',revision='2025-04-08'}},
 body={priority=50,
 cooldowns={block('era.warrior.upkeep','sod-dps-'),
  BuiltinConditions.spell('sod-dps-commanding-shout',403215,BuiltinConditions.negate(buff(403215))),
  BuiltinConditions.spell('sod-dps-heroic-strike',78,BuiltinConditions.all(BuiltinConditions.combat(),unqueued,enemies('LESSTHAN',2),BuiltinConditions.any(rage('GREATERTHANOREQUALS',50),BuiltinConditions.all(strike,buff(425415))))),
  BuiltinConditions.spell('sod-dps-cleave',845,BuiltinConditions.all(BuiltinConditions.combat(),unqueued,enemies('GREATERTHANOREQUALS',2),rage('GREATERTHANOREQUALS',50))),
  BuiltinConditions.spell('sod-dps-bloodrage',2687,BuiltinConditions.all(BuiltinConditions.combat(),{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.4})),
  BuiltinConditions.spell('sod-dps-rampage',426940,BuiltinConditions.all(BuiltinConditions.combat(),big)),
  BuiltinConditions.spell('sod-dps-death-wish',12328,BuiltinConditions.combat()),
  BuiltinConditions.spell('sod-dps-recklessness',1719,BuiltinConditions.all(BuiltinConditions.combat(),boss,BuiltinConditions.any(buff(12328),BuiltinConditions.lifetime('LESSTHANOREQUALS',25)))),
  BuiltinConditions.spell('sod-dps-sweeping-strikes',12292,BuiltinConditions.all(BuiltinConditions.combat(),enemies('GREATERTHANOREQUALS',2))),
  optional(BuiltinConditions.spell('sod-dps-berserker-rage',18499,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(rune(402911),rune(426940)),BuiltinConditions.negate(enraged)))),
  optional(BuiltinConditions.spell('sod-dps-battle-stance-dip',2457,BuiltinConditions.all(BuiltinConditions.combat(),buff(426969),BuiltinConditions.negate({type='FORM',form=2457}),rage('LESSTHANOREQUALS',25)))),
 },
 rotation={
 block('era.warrior.boundaries','sod-dps-'),
 BuiltinConditions.spell('sod-dps-victory-rush',402927),
 BuiltinConditions.spell('sod-dps-intercept',20252,{type='BEYOND_MELEE',unit='target'}),
 {id='sod-dps-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={block('era.warrior.aoe-strikes','sod-dps-')}},
 BuiltinConditions.spell('sod-dps-slammin',1464,{type='BUFF_STACKS',unit='player',spell=1234005,operator='GREATERTHANOREQUALS',value=3}),
 BuiltinConditions.spell('sod-dps-rend',772,BuiltinConditions.all(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=772,anyrank=true,owndebuff=true}),BuiltinConditions.any(big,target('GREATERTHAN',.3)),BuiltinConditions.negate(immune))),
 BuiltinConditions.spell('sod-dps-blood-surge-slam',1464,BuiltinConditions.any(buff(413399),rune(402922))),
 BuiltinConditions.spell('sod-dps-bloodthirst',23881),
 BuiltinConditions.spell('sod-dps-mortal-strike',12294),
 BuiltinConditions.spell('sod-dps-shield-slam',23922,{type='WEAPON_TYPE',slot='offhand',kind='shield'}),
 BuiltinConditions.spell('sod-dps-overpower',7384),
 {id='sod-dps-two-hand',type='branch',conditions=rune(429765),onTrue={
  BuiltinConditions.spell('sod-dps-quick-strike',429765,BuiltinConditions.any(rage('GREATERTHANOREQUALS',30),cooling(23881,1.5),cooling(12294,1.5))),
 },onFalse={
  BuiltinConditions.spell('sod-dps-whirlwind',1680),
  BuiltinConditions.spell('sod-dps-raging-blow',402911),
  BuiltinConditions.spell('sod-dps-devastate',403196),
  BuiltinConditions.spell('sod-dps-sunder',7386,BuiltinConditions.all(BuiltinConditions.negate(rune(403195)),target('GREATERTHANOREQUALS',.6),BuiltinConditions.any(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=7386,anyrank=true}),
   {type='DEBUFF_STACKS',unit='target',spell=7386,anyrank=true,operator='LESSTHAN',value=5}))),
 }},
 BuiltinConditions.spell('sod-dps-execute',5308,BuiltinConditions.any(buff(440114),BuiltinConditions.all(target('LESSTHAN',.2),rage('GREATERTHANOREQUALS',30)))),
 BuiltinConditions.spell('sod-dps-hamstring',1715,BuiltinConditions.all(rage('GREATERTHANOREQUALS',80),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(23881)),cooling(23881,0)),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(1680)),cooling(1680,0)))),
 }},
}))
