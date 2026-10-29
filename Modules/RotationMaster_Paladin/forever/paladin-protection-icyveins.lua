-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Protection Paladin after Icy Veins, levels 10–60: a player-chosen alternative to
-- rm.forever.paladin.protection (same switch, lower priority, off by default). Consecration first
-- whenever it is affordable, on one target too; Judgement is held for taunts (no on-cooldown reminder), with Swift
-- Judgement to reset it; then Holy Strike and Exorcism on Undead and Demons.
local _,addon=...
-- Talent trees in the Forever talent window's order (assumed classic: 1 Holy, 2 Protection, 3 Retribution; verify in game).
-- Level 10 first (no talent config below it), then the points (an empty tree is a clean no-match),
-- then the primary tree, which settles hybrids.
local function tree(n,points)return{type='AND',value={{type='TALENT_TREE_POINTS',tree=n,operator='GREATERTHANOREQUALS',value=points},
 {type='PRIMARY_TALENT_TREE',tree=n}}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions,attack)return{id=id,type='stop',suppress_attack=not attack,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.paladin.protection.icyveins',revision=6,
 blocks={['forever.paladin.boundaries']=3,['forever.paladin.aura-blessing']=1,['forever.paladin.taunt']=2,['forever.paladin.tank-upkeep']=2},
 nameKey="Protection, Consecration first (Icy Veins)",descriptionKey="Icy Veins' tanking style, an alternative to the recommended Wowhead Protection premade, off by default: enable it and disable that one, or raise its priority. Consecration first whenever you can afford it, on one enemy too; Judgement is kept for taunts (no on-cooldown reminder), with Swift Judgement to reset it; then Holy Strike and Exorcism on Undead and Demons. Same tank reminders otherwise.",
 applicability={families={'forever'},actionContext='player',class='PALADIN'},
 tags={'protection','tank','group','leveling','aoe','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow-forever/protection-paladin-tank-pve-guide',title='Icy Veins: Forever Protection Paladin PvE',reviewedAt='2026-10-23',revision='2026-10-19'},
  {url='https://www.icy-veins.com/wow-forever/protection-paladin-leveling',title='Icy Veins: Forever Protection Paladin leveling',reviewedAt='2026-10-23',revision='2026-10-19'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/paladin.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks, cooldowns and GCDs only.'},
 },
-- 11 Protection points as the main tree first (readable, so a deep Protection paladin never waits
 -- on an aura read), then Righteous Fury, then Protection as the main tree at any depth, last so a
 -- tie (unavailable) cannot hide Righteous Fury.
 body={priority=35,disabled=true,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},any(tree(2,11),own(25780),tree(2,1))}},
  cooldowns={
   block('ivprot-tank-upkeep','forever.paladin.tank-upkeep','ivprot-'),
   block('ivprot-aura-blessing','forever.paladin.aura-blessing','ivprot-'),
  },
  rotation={
   block('ivprot-boundaries','forever.paladin.boundaries','ivprot-'),
   stop('ivprot-target',negate({type='ATTACKABLE',unit='target'}),true),
   spell('ivprot-consecration',26573),
   block('ivprot-taunt','forever.paladin.taunt','ivprot-'),
   spell('ivprot-holy-strike',679),
   spell('ivprot-exorcism',879,any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='DEMON'})),
  },
 },
}))
