-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Holy Paladin after Wowhead's level-30 guide, levels 10–60: a player-chosen
-- alternative to rm.forever.paladin.holy (same switch, lower priority, off by default). Holy Shock
-- as a routine heal on cooldown, then Flash of Light (health is secret on Forever, so Holy Light
-- for big deficits is the player's call); on an enemy, keep your
-- Judgement of Light up by swapping to Seal of Light, judging, and swapping back to Righteousness,
-- then Holy Strike, Exorcism on Undead and Demons, Holy Shock and Consecration.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
-- Talent trees in the Forever talent window's order (assumed classic: 1 Holy, 2 Protection, 3 Retribution; verify in game).
-- Level 10 first (no talent config below it), then the points (an empty tree is a clean no-match),
-- then the primary tree, which settles hybrids.
local function tree(n,points)return{type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 {type='TALENT_TREE_POINTS',tree=n,operator='GREATERTHANOREQUALS',value=points},{type='PRIMARY_TALENT_TREE',tree=n}}}end
local function own(id,unit)return{type='BUFF',unit=unit or'player',spell=id,anyrank=true,ownbuff=true}end
local function stop(id,conditions,attack)return{id=id,type='stop',suppress_attack=not attack,conditions=conditions or{}}end
local judged={type='DEBUFF',unit='target',spell=20185,anyrank=true,owndebuff=true}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.paladin.holy.wowhead',revision=6,
 blocks={['forever.paladin.boundaries']=3,['forever.paladin.aura-blessing']=1,['forever.paladin.dispel']=1,['forever.paladin.healer-upkeep']=2},
 applicability={families={'forever'},actionContext='player',class='PALADIN'},
 tags={'holy','healer','group','wowhead'},
 sources={
  {url='https://www.wowhead.com/forever/guide/classes/paladin/holy/level-30-healer-overview',title='Wowhead: Forever level 30 Holy Paladin',reviewedAt='2026-10-23',revision='2026-10-06'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/paladin.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks and debuffs only.'},
 },
 body={priority=15,disabled=true,switch=BuiltinConditions.all({type='GROUP'},tree(1,21),BuiltinConditions.negate(own(25780))),
  cooldowns={
   BuiltinConditions.block('whholy-healer-upkeep','forever.paladin.healer-upkeep','whholy-'),
   BuiltinConditions.block('whholy-aura-blessing','forever.paladin.aura-blessing','whholy-'),
  },
  rotation={
   BuiltinConditions.block('whholy-boundaries','forever.paladin.boundaries','whholy-'),
   {id='whholy-friendly',type='branch',conditions=BuiltinConditions.all({type='FRIENDLY',unit='target'},BuiltinConditions.negate({type='DEAD',unit='target'})),onFalse={},onTrue={
    BuiltinConditions.spell('whholy-shock',1311606),
    BuiltinConditions.block('whholy-dispel','forever.paladin.dispel','whholy-'),
    BuiltinConditions.spell('whholy-flash',19750),
    stop('whholy-healed')}},
   {id='whholy-hostile',type='branch',conditions={type='ATTACKABLE',unit='target'},onFalse={},onTrue={
    BuiltinConditions.spell('whholy-swap-light',20165,BuiltinConditions.all(BuiltinConditions.negate(own(20165)),BuiltinConditions.negate(judged))),
    BuiltinConditions.spell('whholy-judgement',20271,BuiltinConditions.any(BuiltinConditions.all(own(20165),BuiltinConditions.negate(judged)),own(20154))),
    BuiltinConditions.spell('whholy-swap-righteousness',20154,BuiltinConditions.all(own(20165),judged)),
    BuiltinConditions.spell('whholy-strike',679),
    BuiltinConditions.spell('whholy-exorcism',879,BuiltinConditions.any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='DEMON'})),
    BuiltinConditions.spell('whholy-enemy-shock',1311606),
    BuiltinConditions.spell('whholy-consecration',26573),
    stop('whholy-hostile-done',nil,true)}},
   stop('whholy-done'),
  },
 },
}))
