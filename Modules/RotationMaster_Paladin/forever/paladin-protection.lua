-- WoW Forever Protection Paladin, levels 10–60: any Paladin with Protection as the main talent tree,
-- or who has Righteous Fury on to tank. Wowhead's level-30 orders: taunt with a Seal of
-- Fury Judgement (Swift Judgement to reset it) when the target turns away; on two or more enemies
-- Consecration first, then Exorcism on Undead and Demons and Holy Strike; on one, Exorcism, Holy
-- Strike, then Consecration (mana is secret on Forever, so it no longer waits for mana to spare).
-- Judgement on cooldown is a reminder (off the GCD).
-- The Icy Veins Consecration-first variant is rm.forever.paladin.protection.icyveins.
local _,addon=...
-- Talent trees in the Forever talent window's order (assumed classic: 1 Holy, 2 Protection, 3 Retribution; verify in game).
-- Level 10 first (no talent config below it), then the points (an empty tree is a clean no-match),
-- then the primary tree, which settles hybrids.
local function tree(n,points)return{type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 {type='TALENT_TREE_POINTS',tree=n,operator='GREATERTHANOREQUALS',value=points},{type='PRIMARY_TALENT_TREE',tree=n}}}end
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions,attack)return{id=id,type='none',suppress_attack=not attack,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local evil=any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='DEMON'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.paladin.protection',revision=3,
 blocks={['forever.paladin.boundaries']=1,['forever.paladin.aura-blessing']=1,['forever.paladin.taunt']=2,['forever.paladin.tank-upkeep']=2},
 nameKey='Default.Forever.Paladin.Protection.Name',descriptionKey='Default.Forever.Paladin.Protection.Description',
 applicability={families={'forever'},actionContext='player',class='PALADIN',minLevel=10,maxLevel=60},
 tags={'protection','tank','group','leveling','aoe','wowhead'},
 sources={
  {url='https://www.wowhead.com/forever/guide/classes/paladin/protection/level-30-tank-overview',title='Wowhead: Forever level 30 Protection Paladin',reviewedAt='2026-10-23',revision='2026-10-06'},
  {url='https://www.icy-veins.com/wow-forever/protection-paladin-leveling',title='Icy Veins: Forever Protection Paladin leveling',reviewedAt='2026-10-23',revision='2026-10-19',notes='Swift Judgement to recover a taunt.'},
  {url='https://worldofwarcraft.com/en-us/news/24302099',title='Blizzard: Forever class deep dive, Paladin',reviewedAt='2026-10-23',revision='2026-10-15',notes='Seal of Fury taunt, Templar\'s Bulwark, Holy Shield; no priority.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/paladin.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks, cooldowns and GCDs only.'},
 },
-- 11 Protection points as the main tree first (readable, so a deep Protection paladin never waits
 -- on an aura read), then Righteous Fury, then Protection as the main tree at any depth, last so a
 -- tie (unavailable) cannot hide Righteous Fury.
 body={priority=40,switch=any(tree(2,11),own(25780),tree(2,1)),
  cooldowns={
   block('prot-tank-upkeep','forever.paladin.tank-upkeep','prot-'),
   block('prot-aura-blessing','forever.paladin.aura-blessing','prot-'),
   spell('prot-judgement',20271,all({type='COMBAT',unit='player'},{type='ATTACKABLE',unit='target'},own(1311649))),
  },
  rotation={
   block('prot-boundaries','forever.paladin.boundaries','prot-'),
   stop('prot-target',negate({type='ATTACKABLE',unit='target'}),true),
   block('prot-taunt','forever.paladin.taunt','prot-'),
   {id='prot-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},
    onTrue={
     spell('prot-aoe-consecration',26573),
     spell('prot-aoe-exorcism',879,evil),
     spell('prot-aoe-holy-wrath',2812,evil),
     spell('prot-aoe-holy-strike',679)},
    onFalse={
     spell('prot-exorcism',879,evil),
     spell('prot-holy-strike',679),
     spell('prot-consecration',26573)}},
  },
 },
}))
