-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Warrior tank, levels 10–70, Icy Veins order (alternative tank variant).
-- Same switch as the Wowhead variant (Defensive Stance), lower priority. Differs where Icy Veins
-- differs: Shield Block whenever the target is hitting you, no single-target Thunder Clap or
-- Demoralizing Shout upkeep (Thunder Clap on packs, Demoralizing Shout for elite packs), and
-- Rend at the start of a fight until Shield Slam is learned.
-- Left manual: taunting, pre-pull rage, stance swaps and other utility.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function debuff(id,own)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=own or nil}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.warrior.protection.icyveins',revision=7,
 blocks={['tbc.warrior.boundaries']=4,['tbc.warrior.upkeep']=1,['tbc.warrior.prot-upkeep']=1,['tbc.warrior.prot-core']=1,['tbc.warrior.sunder']=1},
 applicability={families={'tbc'},actionContext='player',class='WARRIOR'},
 tags={'tank','melee','leveling','endgame','aoe','icy-veins'},
 sources={{url='https://www.icy-veins.com/tbc-classic/protection-warrior-tank-pve-rotation-cooldowns-abilities',title='Icy Veins: Protection Warrior tank rotation, cooldowns and abilities',reviewedAt='2026-10-23',revision='2026-01-12'},
 {url='https://www.icy-veins.com/tbc-classic/protection-warrior-leveling-guide',title='Icy Veins: Protection Warrior leveling',reviewedAt='2026-10-23',revision='2026-01-12'}},
 body={priority=25,disabled=true,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='FORM',form=71}}},
 cooldowns={block('tbc.warrior.upkeep','warrior-prot-'),block('tbc.warrior.prot-upkeep','warrior-prot-'),
  BuiltinConditions.spell('warrior-prot-shield-block',2565,BuiltinConditions.all({type='COMBAT',unit='player'},{type='WEAPON_TYPE',slot='offhand',kind='shield'},BuiltinConditions.negate({type='BUFF',unit='player',spell=2565,anyrank=true}),
   {type='ISSAME',unit='targettarget',otherunit='player'}))},
 rotation={
 block('tbc.warrior.boundaries','warrior-prot-'),
 {id='warrior-prot-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},onFalse={},onTrue={
  BuiltinConditions.spell('warrior-prot-aoe-thunder-clap',6343),
  BuiltinConditions.spell('warrior-prot-aoe-demoralizing-shout',1160,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.classified('worldboss'),BuiltinConditions.classified('elite')),BuiltinConditions.negate(BuiltinConditions.any(debuff(1160),debuff(99))))),
 }},
 block('tbc.warrior.prot-core','warrior-prot-'),
 block('tbc.warrior.sunder','warrior-prot-'),
 BuiltinConditions.spell('warrior-prot-rend',772,BuiltinConditions.all(BuiltinConditions.negate({type='SPELL_KNOWN',spell=23922}),BuiltinConditions.negate(debuff(772,true)))),
 }},
}))
