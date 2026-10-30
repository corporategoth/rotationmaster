-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Survival Hunter in melee (dual-wield), levels 10–60, once Survival is the main tree
-- with 21 points (Strider Kick's tier); until then Survival levels with the ranged premade, as every
-- source advises. Wowhead's level-30 order: Mongoose Bite, Strider Kick, Raptor Strike,
-- Counterattack, with Explosive Trap on packs. Out of melee it shoots (own Serpent Sting, Arcane,
-- Aimed, Auto Shot). Aspect of the Beast and Hunter's Mark (Expose Prey needs it) are reminders.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
-- Talent trees in the Forever talent window's order (assumed classic: 1 Beast Mastery, 2 Marksmanship, 3 Survival; verify in game).
-- Level 10 first (no talent config below it), then the points (an empty tree is a clean no-match),
-- then the primary tree, which settles hybrids.
local function tree(n,points)return{type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 {type='TALENT_TREE_POINTS',tree=n,operator='GREATERTHANOREQUALS',value=points},{type='PRIMARY_TALENT_TREE',tree=n}}}end
local function stop(id,conditions,attack)return{id=id,type='stop',suppress_attack=not attack,conditions=conditions or{}}end
local elite=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.hunter.survival',revision=7,
 blocks={['forever.hunter.boundaries']=4,['forever.hunter.survival-pull']=3,['forever.hunter.range-shots']=1,['forever.hunter.melee-aoe']=1,
  ['forever.hunter.pet-care']=2,['forever.hunter.burst']=1},
 applicability={families={'forever'},actionContext='player',class='HUNTER'},
 tags={'survival','melee','leveling','wowhead'},
 sources={
  {url='https://www.wowhead.com/forever/guide/classes/hunter/survival/level-30-dps-overview',title='Wowhead: Forever level 30 Survival Hunter',reviewedAt='2026-10-23',revision='2026-10-11'},
  {url='https://www.wowhead.com/forever/guide/classes/hunter/survival/dps-abilities',title='Wowhead: Forever Survival Hunter abilities',reviewedAt='2026-10-23',revision='2026-10-08'},
  {url='https://www.icy-veins.com/wow-forever/survival-hunter-melee-dps-pve-guide',title='Icy Veins: Forever Survival Hunter PvE',reviewedAt='2026-10-23',revision='2026-10-05',notes='Traps on packs; Survival plays ranged until talented.'},
  {url='https://worldofwarcraft.blizzard.com/en-us/news/24301515',title='Blizzard: Forever class deep dive, Hunter and Druid',reviewedAt='2026-10-23',revision='2026-09-30',notes='Aspect of the Beast, Strider Kick, Expose Prey; no priority.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/hunter.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks and cooldowns only.'},
 },
 body={priority=20,switch=tree(3,21),
  cooldowns={
   BuiltinConditions.spell('sv-aspect-beast',13161,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='BUFF',unit='player',spell=13161,anyrank=true,ownbuff=true}))),
   BuiltinConditions.spell('sv-mark',1130,BuiltinConditions.all(BuiltinConditions.combat(),{type='ATTACKABLE',unit='target'},BuiltinConditions.negate({type='DEBUFF',unit='target',spell=1130,anyrank=true}))),
   BuiltinConditions.block('sv-burst','forever.hunter.burst','sv-'),
   BuiltinConditions.spell('sv-deterrence',19263,BuiltinConditions.all(BuiltinConditions.combat(),{type='THREAT',unit='target',threat=3})),
   BuiltinConditions.block('sv-pet-care','forever.hunter.pet-care','sv-'),
  },
  rotation={
   BuiltinConditions.block('sv-boundaries','forever.hunter.boundaries','sv-'),
   BuiltinConditions.block('sv-pull','forever.hunter.survival-pull','sv-'),
   {id='sv-range',type='branch',conditions={type='BEYOND_MELEE',unit='target'},onFalse={},onTrue={
    BuiltinConditions.block('sv-range-shots','forever.hunter.range-shots','sv-range-'),stop('sv-range-stop')}},
   BuiltinConditions.block('sv-aoe','forever.hunter.melee-aoe','sv-'),
   BuiltinConditions.spell('sv-mongoose-bite',1495),
   BuiltinConditions.spell('sv-strider-kick',1317257),
   BuiltinConditions.spell('sv-raptor-strike',2973,BuiltinConditions.negate({type='SPELL_ACTIVE',spell=2973})),
   BuiltinConditions.spell('sv-counterattack',19306),
   {id='sv-immolation-trap',type='spell',action=13795,ranked=false,disabled=true,conditions=elite},
   stop('sv-done',nil,true),
  },
 },
}))
