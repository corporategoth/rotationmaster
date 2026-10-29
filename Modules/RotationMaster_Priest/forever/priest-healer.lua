-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever healing Priest (Discipline and Holy) in a group, levels 10–60: selected without
-- Shadowform when Discipline or Holy is the main talent tree. Heals your current friendly target (RM suggests the spell; you pick the target):
-- shield, Prayer of Mending and Renew before the pull; dispels; Prayer of Mending, Holy Nova on Holy
-- Purpose, Penance, Renew when missing, Heal (Lesser Heal before it). Spare time on an enemy: DoTs,
-- Smite, wand. Health and mana are secret on Forever, so the target you pick is the only signal of
-- who needs healing; emergency heals, Prayer of Healing, Binding Heal, Greater and Flash Heal,
-- Desperate Prayer and Dark Sacrifice are the player's call.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
-- Talent trees in the Forever talent window's order (assumed classic: 1 Discipline, 2 Holy, 3 Shadow; verify in game).
-- Level 10 first (no talent config below it), then the points (an empty tree is a clean no-match),
-- then the primary tree, which settles hybrids.
local function tree(n,points)return{type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 {type='TALENT_TREE_POINTS',tree=n,operator='GREATERTHANOREQUALS',value=points},{type='PRIMARY_TALENT_TREE',tree=n}}}end
local function known(...)local list={};for i,id in ipairs({...})do list[i]={type='SPELL_KNOWN',spell=id}end;return{type='OR',value=list}end
local function dot(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local renewed={type='BUFF',unit='target',spell=139,anyrank=true,ownbuff=true}
local unshielded=BuiltinConditions.negate({type='DEBUFF',unit='target',spell=6788})
local friendly={type='FRIENDLY',unit='target'}
local function dispel(kind)return{type='DISPELLABLE',unit='target',debufftype=kind}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.priest.healer',revision=7,
 blocks={['forever.priest.boundaries']=3,['forever.priest.upkeep']=1,['forever.priest.wand']=2},
 applicability={families={'forever'},actionContext='player',class='PRIEST'},
 tags={'discipline','holy','healer','group','icy-veins','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow-forever/discipline-priest-healer-pve-guide',title='Icy Veins: Forever Discipline Priest PvE',reviewedAt='2026-10-23',revision='2026-10-16'},
  {url='https://www.icy-veins.com/wow-forever/holy-priest-healer-pve-guide',title='Icy Veins: Forever Holy Priest PvE',reviewedAt='2026-10-23',revision='2026-10-16'},
  {url='https://www.wowhead.com/forever/guide/classes/priest/holy/level-30-healer-overview',title='Wowhead: Forever level 30 Holy Priest',reviewedAt='2026-10-23',revision='2026-10-06',notes='Binding Heal, Prayer of Healing; dungeon shield.'},
  {url='https://www.wowhead.com/forever/guide/classes/priest/discipline/level-30-healer-overview',title='Wowhead: Forever level 30 Discipline Priest',reviewedAt='2026-10-23',revision='2026-10-06'},
  {url='https://worldofwarcraft.com/en-us/news/24301514',title='Blizzard: Forever class deep dive, Priest and Warrior',reviewedAt='2026-10-23',revision='2026-09-30',notes='Rage from damage ignores absorbs, so tanks are shielded; no priority.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/priest.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks, Holy Purpose proc.'},
 },
 body={priority=20,
  switch=BuiltinConditions.all({type='GROUP'},BuiltinConditions.negate(known(15473)),BuiltinConditions.any(tree(1,1),tree(2,1))),
  cooldowns={
   BuiltinConditions.block('heal-upkeep','forever.priest.upkeep','heal-'),
   BuiltinConditions.spell('heal-power-infusion',10060,BuiltinConditions.all({type='COMBAT',unit='player'},friendly,BuiltinConditions.negate({type='ISSAME',unit='target',otherunit='player'}))),
   BuiltinConditions.spell('heal-inner-focus',14751,{type='COMBAT',unit='player'}),
   BuiltinConditions.spell('heal-divine-grace',1277370,BuiltinConditions.all(friendly,{type='DEBUFF',unit='target',spell=6788})),
   BuiltinConditions.spell('heal-contingency-plan',1277462,BuiltinConditions.all({type='COMBAT',unit='player'},friendly)),
  },
  rotation={
   BuiltinConditions.block('heal-boundaries','forever.priest.boundaries','heal-'),
   {id='heal-hostile',type='branch',conditions={type='ATTACKABLE',unit='target'},onFalse={},onTrue={
    BuiltinConditions.spell('heal-pain',589,BuiltinConditions.negate(dot(589))),
    BuiltinConditions.spell('heal-holy-fire',14914,BuiltinConditions.negate(dot(14914))),
    BuiltinConditions.spell('heal-enemy-penance',402174),
    BuiltinConditions.spell('heal-smite',585),
    BuiltinConditions.block('heal-wand','forever.priest.wand','heal-'),
    BuiltinConditions.stop('heal-hostile-stop')}},
   BuiltinConditions.stop('heal-target',BuiltinConditions.negate(BuiltinConditions.all(friendly,BuiltinConditions.negate({type='DEAD',unit='target'})))),
   {id='heal-prepull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell('heal-prepull-shield',17,unshielded),
    BuiltinConditions.spell('heal-prepull-mending',401859),
    BuiltinConditions.spell('heal-prepull-renew',139,BuiltinConditions.negate(renewed)),
    BuiltinConditions.stop('heal-prepull-stop')}},
   BuiltinConditions.spell('heal-dispel-magic',527,dispel('Magic')),
   BuiltinConditions.spell('heal-abolish-disease',552,dispel('Disease')),
   BuiltinConditions.spell('heal-cure-disease',528,BuiltinConditions.all(BuiltinConditions.negate(known(552)),dispel('Disease'))),
   BuiltinConditions.spell('heal-mending',401859),
   BuiltinConditions.spell('heal-holy-nova',15237,{type='BUFF',unit='player',spell=1284536}),
   BuiltinConditions.spell('heal-penance',402174),
   BuiltinConditions.spell('heal-renew',139,BuiltinConditions.negate(renewed)),
   BuiltinConditions.spell('heal-heal',2054),
   BuiltinConditions.spell('heal-lesser',2050,BuiltinConditions.negate(known(2054))),
   BuiltinConditions.stop('heal-done'),
  },
 },
}))
