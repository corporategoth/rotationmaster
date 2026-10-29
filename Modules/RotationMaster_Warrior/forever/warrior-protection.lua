-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Protection Warrior tank, levels 10–60, Icy Veins order (the recommended tank).
-- Chosen whenever you are in Defensive Stance: Forever's Protection levels in it (Vanguard),
-- and RM cannot read Forever talents. Charge to pull (usable in Defensive Stance once Vanguard
-- is taken); Victory Rush; on packs Thunder Clap on cooldown, Demoralizing Shout, Shield Slam,
-- Revenge and Rend; Shield Slam; Revenge; Demoralizing Shout; Rend; Sunder Armor (five on
-- elites); Thunder Clap on dangerous single targets. Shield Block while you hold the target,
-- Heroic Strike when both strikes are recovering, Cleave on packs. Rage, health and the target's
-- mana are secret on Forever, so the rage thresholds, the caster checks and Last Stand are left
-- out. Shared parts: Defaults/blocks/forever-warrior.lua.
-- Left manual: swapping to Battle Stance to Charge before Vanguard, taunting other enemies,
-- tab-targeting untouched enemies; Taunt, Shield Wall, Concussion Blow and Disarm are listed off.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function debuff(id,own)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=own or nil}end
local function sunders(n)return{type='DEBUFF_STACKS',unit='target',spell=7386,anyrank=true,operator='GREATERTHANOREQUALS',value=n}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function big()return BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})end
local tanked={type='THREAT',unit='target',threat=3}
local unqueued=BuiltinConditions.all(BuiltinConditions.negate(queued(78)),BuiltinConditions.negate(queued(845)))
local function rend()return BuiltinConditions.spell('warrior-prot-rend',772,BuiltinConditions.negate(debuff(772,true)))end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.warrior.protection',revision=6,
 blocks={['forever.warrior.boundaries']=3,['forever.warrior.upkeep']=2},
 applicability={families={'forever'},actionContext='player',class='WARRIOR'},
 tags={'tank','melee','leveling','endgame','aoe','icy-veins','method'},
 sources={{url='https://www.icy-veins.com/wow-forever/protection-warrior-tank-pve-guide',title='Icy Veins: Forever Protection Warrior tank PvE guide',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.icy-veins.com/wow-forever/protection-warrior-leveling',title='Icy Veins: Forever Protection Warrior leveling',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.method.gg/wow-forever/wow-forever-warrior-leveling-guide-and-talents',title='Method: Forever Warrior leveling guide and talents',reviewedAt='2026-10-23',revision='2026-10-09'},
 {url='https://worldofwarcraft.blizzard.com/en-us/news/24301514',title='Blizzard: Forever class deep dives, Priest and Warrior',reviewedAt='2026-10-23',revision='2026-09-30'}},
 body={priority=25,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='FORM',value=2}}},
 cooldowns={block('forever.warrior.upkeep','warrior-prot-'),
  BuiltinConditions.spell('warrior-prot-shield-block',2565,BuiltinConditions.all(BuiltinConditions.combat(),tanked,BuiltinConditions.negate({type='BUFF',unit='player',spell=2565}))),
  BuiltinConditions.spell('warrior-prot-heroic-strike',78,BuiltinConditions.all(BuiltinConditions.combat(),unqueued,enemies('LESSTHAN',2),BuiltinConditions.negate({type='SPELL_AVAIL',spell=23922}),BuiltinConditions.negate({type='SPELL_AVAIL',spell=6572}))),
  BuiltinConditions.spell('warrior-prot-cleave',845,BuiltinConditions.all(BuiltinConditions.combat(),unqueued,enemies('GREATERTHANOREQUALS',2))),
  {id='warrior-prot-taunt',type='spell',action=355,ranked=false,disabled=true,conditions=BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},BuiltinConditions.negate(tanked))},
  {id='warrior-prot-shield-wall',type='spell',action=871,ranked=false,disabled=true,conditions=BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(big(),enemies('GREATERTHANOREQUALS',3)))}},
 rotation={
 block('forever.warrior.boundaries','warrior-prot-'),
 BuiltinConditions.spell('warrior-prot-victory-rush',402927),
 {id='warrior-prot-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={
  BuiltinConditions.spell('warrior-prot-aoe-thunder-clap',6343),
  BuiltinConditions.spell('warrior-prot-aoe-demoralizing-shout',1160,BuiltinConditions.negate(debuff(1160))),
  BuiltinConditions.spell('warrior-prot-aoe-shield-slam',23922),
  BuiltinConditions.spell('warrior-prot-aoe-revenge',6572),
  BuiltinConditions.spell('warrior-prot-aoe-rend',772,BuiltinConditions.negate(debuff(772,true))),
 }},
 BuiltinConditions.spell('warrior-prot-shield-slam',23922),
 BuiltinConditions.spell('warrior-prot-revenge',6572),
 BuiltinConditions.spell('warrior-prot-demoralizing-shout',1160,BuiltinConditions.negate(debuff(1160))),
 rend(),
 BuiltinConditions.spell('warrior-prot-sunder',7386,BuiltinConditions.any(BuiltinConditions.all(big(),BuiltinConditions.negate(sunders(5))),BuiltinConditions.negate(sunders(2)))),
 BuiltinConditions.spell('warrior-prot-thunder-clap',6343,BuiltinConditions.all(big(),BuiltinConditions.negate(debuff(6343)))),
 {id='warrior-prot-concussion-blow',type='spell',action=12809,ranked=false,disabled=true,conditions={}},
 {id='warrior-prot-disarm',type='spell',action=676,ranked=false,disabled=true,conditions=big()},
 }},
}))
