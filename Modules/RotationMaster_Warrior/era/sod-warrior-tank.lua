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
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
-- The Devastate rune's first taught spell is 403195 (wowsims/exporter); 403196 is the ability.
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function rage(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function optional(step)step.disabled=true;return step end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local big=any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})
local tanked={type='ISSAME',unit='targettarget',otherunit='player'}
local unqueued=all(negate(queued(78)),negate(queued(845)))
-- Defender's Resolve: 460171 per wowsims and Wowhead's text, 462230 per Wowhead's link (verify).
local function resolve(id)return any(negate(buff(id)),{type='BUFF_REMAIN',unit='player',spell=id,operator='LESSTHAN',value=2})end
local shield={type='WEAPON_TYPE',slot='offhand',kind='shield'}
local stacked=all({type='DEBUFF',unit='target',spell=7386,anyrank=true},{type='DEBUFF_STACKS',unit='target',spell=7386,anyrank=true,operator='GREATERTHANOREQUALS',value=5})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.warrior.tank',revision=6,
 blocks={['era.warrior.boundaries']=3,['era.warrior.upkeep']=1},
 nameKey='Default.SoD.Warrior.Tank.Name',descriptionKey='Default.SoD.Warrior.Tank.Description',
 applicability={families={'era'},actionContext='player',class='WARRIOR',rulesets={'season:2'}},
 tags={'tank','melee','leveling','endgame','aoe','season-of-discovery','wowhead','wowsims'},
 sources={{url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/warrior/tank-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Protection Warrior tank rotation (Phase 8)',reviewedAt='2026-10-23',revision='2025-04-09'},
 {url='https://github.com/wowsims/sod/blob/0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e/ui/tank_warrior/apls/phase_4.apl.json',title='wowsims/sod: Warrior tank Phase 4 APL',reviewedAt='2026-10-23',revision='0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e'}},
 body={priority=70,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='FORM',form=71}}},
 cooldowns={block('era.warrior.upkeep','sod-tank-'),
  spell('sod-tank-commanding-shout',403215,negate(buff(403215))),
  spell('sod-tank-shield-block',2565,all(combat(),shield,tanked,negate({type='BUFF',unit='player',spell=2565}))),
  spell('sod-tank-heroic-strike',78,all(combat(),unqueued,enemies('LESSTHAN',2),rage('GREATERTHANOREQUALS',50))),
  spell('sod-tank-cleave',845,all(combat(),unqueued,enemies('GREATERTHANOREQUALS',2),rage('GREATERTHANOREQUALS',55))),
  spell('sod-tank-bloodrage',2687,all(combat(),{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.5})),
  spell('sod-tank-rampage',426940,combat()),
  spell('sod-tank-last-stand',12975,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.3})),
  optional(spell('sod-tank-shield-wall',871,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.2}))),
  optional(spell('sod-tank-taunt',355,all(combat(),{type='GROUP'},negate(tanked)))),
  optional(spell('sod-tank-death-wish',12328,all(combat(),{type='TIME_IN_COMBAT',operator='LESSTHAN',value=10}))),
  optional(spell('sod-tank-recklessness',1719,all(combat(),{type='CLASSIFICATION',unit='target',value='worldboss'}))),
  optional(spell('sod-tank-retaliation',20230,all(combat(),{type='CLASSIFICATION',unit='target',value='worldboss'},{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2}))),
 },
 rotation={
 block('era.warrior.boundaries','sod-tank-'),
 {id='sod-tank-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={
  spell('sod-tank-aoe-thunder-clap',6343),
  spell('sod-tank-aoe-shockwave',440488),
  spell('sod-tank-aoe-shield-slam',23922,shield),
  spell('sod-tank-aoe-revenge',6572),
  spell('sod-tank-aoe-whirlwind',1680),
  spell('sod-tank-aoe-devastate',403196),
  spell('sod-tank-aoe-sunder',7386,negate(rune(403195))),
 }},
 spell('sod-tank-resolve-shield-slam',23922,all(shield,resolve(460171),resolve(462230))),
 spell('sod-tank-revenge',6572),
 spell('sod-tank-shield-slam',23922,shield),
 spell('sod-tank-shockwave',440488),
 spell('sod-tank-execute',5308),
 spell('sod-tank-cunning-whirlwind',1680,{type='BUFF_STACKS',unit='player',spell=1234067,operator='GREATERTHANOREQUALS',value=5}),
 spell('sod-tank-devastate',403196),
 spell('sod-tank-sunder',7386,all(negate(rune(403195)),negate(stacked))),
 spell('sod-tank-demoralizing',1160,all(big,negate(any({type='DEBUFF',unit='target',spell=1160,anyrank=true},{type='DEBUFF',unit='target',spell=99,anyrank=true})))),
 spell('sod-tank-thunder-clap',6343,all(big,negate({type='DEBUFF',unit='target',spell=6343,anyrank=true}))),
 spell('sod-tank-rend',772,all(negate(known(23922)),negate({type='DEBUFF',unit='target',spell=772,anyrank=true,owndebuff=true}))),
 spell('sod-tank-sunder-filler',7386,negate(rune(403195))),
 }},
}))
