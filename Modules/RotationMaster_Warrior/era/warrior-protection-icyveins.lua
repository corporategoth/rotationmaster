-- Classic Era Protection Warrior, Icy Veins "sunderless" Battle Shout tanking (alternative tank
-- premade; same switch, lower priority). For groups where four or more players (pets count) hear
-- the shout, from Phase 5's Battle Shout rank: Revenge, Shield Slam (Bloodthirst for Fury-Prot),
-- then Battle Shout as the threat filler instead of Sunder Armor; Demoralizing Shout kept up.
-- Same reminders as the recommended tank (era/blocks.lua). Switch back to Sunder when focusing one
-- target in a crowd.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function rage(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local shield={type='WEAPON_TYPE',slot='offhand',kind='shield'}
local tanked={type='ISSAME',unit='targettarget',otherunit='player'}
local unqueued=all(negate(queued(78)),negate(queued(845)))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.warrior.protection.icyveins',revision=5,
 blocks={['era.warrior.boundaries']=3,['era.warrior.upkeep']=1},
 nameKey='Default.Era.Warrior.Protection.IcyVeins.Name',descriptionKey='Default.Era.Warrior.Protection.IcyVeins.Description',
 applicability={families={'era'},actionContext='player',class='WARRIOR'},
 tags={'tank','melee','endgame','aoe','icy-veins'},
 sources={{url='https://www.icy-veins.com/wow-classic/warrior-tank-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Warrior tank rotation (Battle Shout tanking)',reviewedAt='2026-10-23',revision='2024-11-17'}},
 body={priority=25,disabled=true,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='FORM',form=71}}},
 cooldowns={block('era.warrior.upkeep','warrior-prot-iv-'),
  spell('warrior-prot-iv-shield-block',2565,all(combat(),shield,tanked,negate({type='CASTING',unit='target'}),negate({type='BUFF',unit='player',spell=2565}))),
  spell('warrior-prot-iv-bloodrage',2687,all(combat(),rage('LESSTHAN',60),{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.5})),
  spell('warrior-prot-iv-heroic-strike',78,all(combat(),unqueued,enemies('LESSTHAN',2),rage('GREATERTHANOREQUALS',50))),
  spell('warrior-prot-iv-cleave',845,all(combat(),unqueued,enemies('GREATERTHANOREQUALS',2),rage('GREATERTHANOREQUALS',50))),
 },
 rotation={
 block('era.warrior.boundaries','warrior-prot-iv-'),
 spell('warrior-prot-iv-demoralizing',1160,negate(any({type='DEBUFF',unit='target',spell=1160,anyrank=true},{type='DEBUFF',unit='target',spell=99,anyrank=true}))),
 spell('warrior-prot-iv-revenge',6572),
 spell('warrior-prot-iv-shield-slam',23922,shield),
 spell('warrior-prot-iv-bloodthirst',23881),
 spell('warrior-prot-iv-shout-filler',6673),
 }},
}))
