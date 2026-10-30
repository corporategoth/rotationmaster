-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Warrior tank, levels 10–60 (chosen in Defensive Stance). Wowhead Phase 8
-- order: Charge; on two engaged enemies Thunder Clap, Shockwave, Shield Slam, Revenge, Whirlwind
-- and Devastate; Shield Slam whenever Defender's Resolve is missing or ending; Revenge; Shield
-- Slam; Shockwave; Execute; Whirlwind at five Gladiator's Cunning stacks; Devastate (Sunder
-- before it); Demoralizing Shout and Thunder Clap on elites; Rend before Shield Slam. Reminders:
-- Battle and Commanding Shout, Shield Block, Heroic Strike from 50 rage, Cleave from 55,
-- Bloodrage, Rampage, Last Stand, interrupts. Shared parts: era/blocks.lua. Left manual: the
-- Gladiator swap for Execute (the DPS premade takes over); Taunt, Shield Wall, Death Wish,
-- Recklessness and Retaliation are listed off.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
-- The Devastate rune's first taught spell is 403195 (simulator/exporter); 403196 is the ability.
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function rage(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
local function optional(step)step.disabled=true;return step end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local big=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})
local tanked={type='ISSAME',unit='targettarget',otherunit='player'}
local unqueued=BuiltinConditions.all(BuiltinConditions.negate(queued(78)),BuiltinConditions.negate(queued(845)))
-- Defender's Resolve: 460171 per simulator and Wowhead's text, 462230 per Wowhead's link (verify).
local function resolve(id)return BuiltinConditions.any(BuiltinConditions.negate(buff(id)),{type='BUFF_REMAIN',unit='player',spell=id,operator='LESSTHAN',value=2})end
local shield={type='WEAPON_TYPE',slot='offhand',kind='shield'}
local stacked=BuiltinConditions.all({type='DEBUFF',unit='target',spell=7386,anyrank=true},{type='DEBUFF_STACKS',unit='target',spell=7386,anyrank=true,operator='GREATERTHANOREQUALS',value=5})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.warrior.tank',revision=6,
 blocks={['era.warrior.boundaries']=3,['era.warrior.upkeep']=1},
 applicability={families={'era'},actionContext='player',class='WARRIOR',rulesets={'season:2'}},
 tags={'tank','melee','leveling','endgame','aoe','season-of-discovery','wowhead'},
 sources={{url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/warrior/tank-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Protection Warrior tank rotation (Phase 8)',reviewedAt='2026-10-23',revision='2025-04-09'},
 },
 body={priority=70,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='FORM',form=71}}},
 cooldowns={block('era.warrior.upkeep','sod-tank-'),
  BuiltinConditions.spell('sod-tank-commanding-shout',403215,BuiltinConditions.negate(buff(403215))),
  BuiltinConditions.spell('sod-tank-shield-block',2565,BuiltinConditions.all(BuiltinConditions.combat(),shield,tanked,BuiltinConditions.negate({type='BUFF',unit='player',spell=2565}))),
  BuiltinConditions.spell('sod-tank-heroic-strike',78,BuiltinConditions.all(BuiltinConditions.combat(),unqueued,enemies('LESSTHAN',2),rage('GREATERTHANOREQUALS',50))),
  BuiltinConditions.spell('sod-tank-cleave',845,BuiltinConditions.all(BuiltinConditions.combat(),unqueued,enemies('GREATERTHANOREQUALS',2),rage('GREATERTHANOREQUALS',55))),
  BuiltinConditions.spell('sod-tank-bloodrage',2687,BuiltinConditions.all(BuiltinConditions.combat(),{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.5})),
  BuiltinConditions.spell('sod-tank-rampage',426940,BuiltinConditions.combat()),
  BuiltinConditions.spell('sod-tank-last-stand',12975,BuiltinConditions.all(BuiltinConditions.combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.3})),
  optional(BuiltinConditions.spell('sod-tank-shield-wall',871,BuiltinConditions.all(BuiltinConditions.combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.2}))),
  optional(BuiltinConditions.spell('sod-tank-taunt',355,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},BuiltinConditions.negate(tanked)))),
  optional(BuiltinConditions.spell('sod-tank-death-wish',12328,BuiltinConditions.all(BuiltinConditions.combat(),{type='TIME_IN_COMBAT',operator='LESSTHAN',value=10}))),
  optional(BuiltinConditions.spell('sod-tank-recklessness',1719,BuiltinConditions.all(BuiltinConditions.combat(),{type='CLASSIFICATION',unit='target',value='worldboss'}))),
  optional(BuiltinConditions.spell('sod-tank-retaliation',20230,BuiltinConditions.all(BuiltinConditions.combat(),{type='CLASSIFICATION',unit='target',value='worldboss'},{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2}))),
 },
 rotation={
 block('era.warrior.boundaries','sod-tank-'),
 {id='sod-tank-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={
  BuiltinConditions.spell('sod-tank-aoe-thunder-clap',6343),
  BuiltinConditions.spell('sod-tank-aoe-shockwave',440488),
  BuiltinConditions.spell('sod-tank-aoe-shield-slam',23922,shield),
  BuiltinConditions.spell('sod-tank-aoe-revenge',6572),
  BuiltinConditions.spell('sod-tank-aoe-whirlwind',1680),
  BuiltinConditions.spell('sod-tank-aoe-devastate',403196),
  BuiltinConditions.spell('sod-tank-aoe-sunder',7386,BuiltinConditions.negate(rune(403195))),
 }},
 BuiltinConditions.spell('sod-tank-resolve-shield-slam',23922,BuiltinConditions.all(shield,resolve(460171),resolve(462230))),
 BuiltinConditions.spell('sod-tank-revenge',6572),
 BuiltinConditions.spell('sod-tank-shield-slam',23922,shield),
 BuiltinConditions.spell('sod-tank-shockwave',440488),
 BuiltinConditions.spell('sod-tank-execute',5308),
 BuiltinConditions.spell('sod-tank-cunning-whirlwind',1680,{type='BUFF_STACKS',unit='player',spell=1234067,operator='GREATERTHANOREQUALS',value=5}),
 BuiltinConditions.spell('sod-tank-devastate',403196),
 BuiltinConditions.spell('sod-tank-sunder',7386,BuiltinConditions.all(BuiltinConditions.negate(rune(403195)),BuiltinConditions.negate(stacked))),
 BuiltinConditions.spell('sod-tank-demoralizing',1160,BuiltinConditions.all(big,BuiltinConditions.negate(BuiltinConditions.any({type='DEBUFF',unit='target',spell=1160,anyrank=true},{type='DEBUFF',unit='target',spell=99,anyrank=true})))),
 BuiltinConditions.spell('sod-tank-thunder-clap',6343,BuiltinConditions.all(big,BuiltinConditions.negate({type='DEBUFF',unit='target',spell=6343,anyrank=true}))),
 BuiltinConditions.spell('sod-tank-rend',772,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(23922)),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=772,anyrank=true,owndebuff=true}))),
 BuiltinConditions.spell('sod-tank-sunder-filler',7386,BuiltinConditions.negate(rune(403195))),
 }},
}))
