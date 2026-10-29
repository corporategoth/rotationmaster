-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Protection Warrior, Icy Veins "sunderless" Battle Shout tanking (alternative tank
-- premade; same switch, lower priority). For groups where four or more players (pets count) hear
-- the shout, from Phase 5's Battle Shout rank: Revenge, Shield Slam (Bloodthirst for Fury-Prot),
-- then Battle Shout as the threat filler instead of Sunder Armor; Demoralizing Shout kept up.
-- Same reminders as the recommended tank (era/blocks.lua). Switch back to Sunder when focusing one
-- target in a crowd.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rage(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local shield={type='WEAPON_TYPE',slot='offhand',kind='shield'}
local tanked={type='ISSAME',unit='targettarget',otherunit='player'}
local unqueued=BuiltinConditions.all(BuiltinConditions.negate(queued(78)),BuiltinConditions.negate(queued(845)))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.warrior.protection.icyveins',revision=6,
 blocks={['era.warrior.boundaries']=3,['era.warrior.upkeep']=1},
 applicability={families={'era'},actionContext='player',class='WARRIOR'},
 tags={'tank','melee','endgame','aoe','icy-veins'},
 sources={{url='https://www.icy-veins.com/wow-classic/warrior-tank-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Warrior tank rotation (Battle Shout tanking)',reviewedAt='2026-10-23',revision='2024-11-17'}},
 body={priority=25,disabled=true,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='FORM',form=71}}},
 cooldowns={block('era.warrior.upkeep','warrior-prot-iv-'),
  BuiltinConditions.spell('warrior-prot-iv-shield-block',2565,BuiltinConditions.all(BuiltinConditions.combat(),shield,tanked,BuiltinConditions.negate({type='CASTING',unit='target'}),BuiltinConditions.negate({type='BUFF',unit='player',spell=2565}))),
  BuiltinConditions.spell('warrior-prot-iv-bloodrage',2687,BuiltinConditions.all(BuiltinConditions.combat(),rage('LESSTHAN',60),{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.5})),
  BuiltinConditions.spell('warrior-prot-iv-heroic-strike',78,BuiltinConditions.all(BuiltinConditions.combat(),unqueued,enemies('LESSTHAN',2),rage('GREATERTHANOREQUALS',50))),
  BuiltinConditions.spell('warrior-prot-iv-cleave',845,BuiltinConditions.all(BuiltinConditions.combat(),unqueued,enemies('GREATERTHANOREQUALS',2),rage('GREATERTHANOREQUALS',50))),
 },
 rotation={
 block('era.warrior.boundaries','warrior-prot-iv-'),
 BuiltinConditions.spell('warrior-prot-iv-demoralizing',1160,BuiltinConditions.negate(BuiltinConditions.any({type='DEBUFF',unit='target',spell=1160,anyrank=true},{type='DEBUFF',unit='target',spell=99,anyrank=true}))),
 BuiltinConditions.spell('warrior-prot-iv-revenge',6572),
 BuiltinConditions.spell('warrior-prot-iv-shield-slam',23922,shield),
 BuiltinConditions.spell('warrior-prot-iv-bloodthirst',23881),
 BuiltinConditions.spell('warrior-prot-iv-shout-filler',6673),
 }},
}))
