-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Warrior tank, levels 10–70, Wowhead/simulator order (the recommended tank variant).
-- Selected by Defensive Stance (read by spell, 71), ahead of the DPS premades by priority; a Battle or
-- Berserker Stance pull shows the DPS premade instead. Shield Slam > Revenge > Thunder Clap and
-- Demoralizing Shout kept up on elites and bosses > Devastate (or Sunder to five). Shield Block
-- is reminded against targets that can crush. Shared parts live in Defaults/blocks/warrior.lua.
-- Left manual: taunting, pre-pull rage, stance swaps, Spell Reflection, Intervene and other utility.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function debuff(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local demoralized=BuiltinConditions.any(debuff(1160),debuff(99))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.warrior.protection.wowhead',revision=6,
 blocks={['tbc.warrior.boundaries']=4,['tbc.warrior.upkeep']=1,['tbc.warrior.prot-upkeep']=1,['tbc.warrior.prot-core']=1,['tbc.warrior.sunder']=1},
 applicability={families={'tbc'},actionContext='player',class='WARRIOR'},
 tags={'tank','melee','leveling','endgame','aoe','wowhead'},
 sources={{url='https://www.wowhead.com/tbc/guide/classes/warrior/protection/tank-rotation-cooldowns-abilities-pve',title='Wowhead: TBC Protection Warrior tank rotation',reviewedAt='2026-10-23',revision='2026-02-23'},
 {url='https://www.wowhead.com/tbc/guide/classes/warrior/protection/leveling-tips',title='Wowhead: TBC Protection Warrior leveling',reviewedAt='2026-10-23',revision='2026-09-04'},
 },
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='FORM',form=71}}},
 cooldowns={block('tbc.warrior.upkeep','warrior-prot-'),block('tbc.warrior.prot-upkeep','warrior-prot-'),
  BuiltinConditions.spell('warrior-prot-shield-block',2565,BuiltinConditions.all({type='COMBAT',unit='player'},{type='WEAPON_TYPE',slot='offhand',kind='shield'},BuiltinConditions.negate({type='BUFF',unit='player',spell=2565,anyrank=true}),
   BuiltinConditions.any(BuiltinConditions.classified('worldboss'),{type='LEVEL',unit='target',relative=true,operator='GREATERTHANOREQUALS',value=3})))},
 rotation={
 block('tbc.warrior.boundaries','warrior-prot-'),
 {id='warrior-prot-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},onFalse={},onTrue={
  BuiltinConditions.spell('warrior-prot-aoe-thunder-clap',6343),
  BuiltinConditions.spell('warrior-prot-aoe-demoralizing-shout',1160,BuiltinConditions.negate(demoralized)),
 }},
 block('tbc.warrior.prot-core','warrior-prot-'),
 {id='warrior-prot-debuffs',type='branch',conditions=BuiltinConditions.any(BuiltinConditions.classified('worldboss'),BuiltinConditions.classified('elite')),onFalse={},onTrue={
  BuiltinConditions.spell('warrior-prot-demoralizing-shout',1160,BuiltinConditions.negate(demoralized)),
  BuiltinConditions.spell('warrior-prot-thunder-clap',6343,BuiltinConditions.negate(debuff(6343))),
 }},
 block('tbc.warrior.sunder','warrior-prot-'),
 }},
}))
