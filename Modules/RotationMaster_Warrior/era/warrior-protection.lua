-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Protection Warrior tank, levels 10–60 (the recommended vanilla tank; chosen whenever
-- you are in Defensive Stance, so Fury-Prot and two-hander tanks are covered). Icy Veins and
-- MaxDps order: on four or more engaged enemies Demoralizing Shout and Battle Shout for threat;
-- Revenge; Shield Slam; Bloodthirst (Fury-Prot); Sunder Armor to five; Demoralizing Shout on
-- elites; Sunder Armor as the threat filler; Rend before Shield Slam or Bloodthirst is learned.
-- Reminders: Battle Shout, Shield Block while the target hits you, Bloodrage, Heroic Strike and
-- Cleave from 50 rage, Shield Bash, Last Stand. Shared parts: era/blocks.lua. Left manual: the
-- Battle Stance swap for Execute (the DPS premade takes over), Challenging Shout; Taunt, Shield
-- Wall and Death Wish are listed off.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function rage(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function optional(step)step.disabled=true;return step end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local big=any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})
local shield={type='WEAPON_TYPE',slot='offhand',kind='shield'}
local tanked={type='ISSAME',unit='targettarget',otherunit='player'}
local unqueued=all(negate(queued(78)),negate(queued(845)))
local demoralized=any({type='DEBUFF',unit='target',spell=1160,anyrank=true},{type='DEBUFF',unit='target',spell=99,anyrank=true})
local stacked=all({type='DEBUFF',unit='target',spell=7386,anyrank=true},{type='DEBUFF_STACKS',unit='target',spell=7386,anyrank=true,operator='GREATERTHANOREQUALS',value=5})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.warrior.protection',revision=5,
 blocks={['era.warrior.boundaries']=3,['era.warrior.upkeep']=1},
 nameKey='Default.Era.Warrior.Protection.Name',descriptionKey='Default.Era.Warrior.Protection.Description',
 applicability={families={'era'},actionContext='player',class='WARRIOR'},
 tags={'tank','melee','leveling','endgame','aoe','icy-veins','maxdps'},
 sources={{url='https://www.icy-veins.com/wow-classic/warrior-tank-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Warrior tank rotation',reviewedAt='2026-10-23',revision='2024-11-17'},
 {url='https://www.icy-veins.com/wow-classic/protection-warrior-leveling-guide-1-60',title='Icy Veins: Classic Protection Warrior leveling 1-60',reviewedAt='2026-10-23',revision='2026-07-18'},
 {url='https://github.com/kaminaris/MaxDps-Warrior/blob/c3bf773f3709514aae9aad8647cd6a4ae7fc8756/Specialization/Classic/Protection.lua',title='MaxDps-Warrior: Classic Protection',reviewedAt='2026-10-23',revision='c3bf773f3709514aae9aad8647cd6a4ae7fc8756'}},
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='FORM',form=71}}},
 cooldowns={block('era.warrior.upkeep','warrior-prot-'),
  spell('warrior-prot-shield-block',2565,all(combat(),shield,tanked,negate({type='CASTING',unit='target'}),negate({type='BUFF',unit='player',spell=2565}))),
  spell('warrior-prot-bloodrage',2687,all(combat(),rage('LESSTHAN',60),{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.5})),
  spell('warrior-prot-heroic-strike',78,all(combat(),unqueued,enemies('LESSTHAN',2),rage('GREATERTHANOREQUALS',50))),
  spell('warrior-prot-cleave',845,all(combat(),unqueued,enemies('GREATERTHANOREQUALS',2),rage('GREATERTHANOREQUALS',50))),
  spell('warrior-prot-last-stand',12975,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.3})),
  optional(spell('warrior-prot-shield-wall',871,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.2}))),
  optional(spell('warrior-prot-taunt',355,all(combat(),{type='GROUP'},negate(tanked)))),
  optional(spell('warrior-prot-death-wish',12328,all(combat(),{type='TIME_IN_COMBAT',operator='LESSTHAN',value=5}))),
 },
 rotation={
 block('era.warrior.boundaries','warrior-prot-'),
 {id='warrior-prot-pack',type='branch',conditions=enemies('GREATERTHANOREQUALS',4),onFalse={},onTrue={
  spell('warrior-prot-pack-demoralizing',1160,negate(demoralized)),
  spell('warrior-prot-pack-battle-shout',6673),
 }},
 spell('warrior-prot-revenge',6572),
 spell('warrior-prot-shield-slam',23922,shield),
 spell('warrior-prot-bloodthirst',23881),
 spell('warrior-prot-sunder',7386,negate(stacked)),
 spell('warrior-prot-demoralizing',1160,all(big,negate(demoralized))),
 spell('warrior-prot-sunder-filler',7386),
 spell('warrior-prot-rend',772,all(negate(known(23922)),negate(known(23881)),negate({type='DEBUFF',unit='target',spell=772,anyrank=true,owndebuff=true}))),
 }},
}))
