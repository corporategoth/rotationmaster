-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Arcane Mage, levels 10–60, once Arcane is the main tree with 11 points and Arcane Blast
-- is known (a Frost Mage who took Missile Barrage first stays Frost). Written for the
-- current Arcane Blast (a 15 s stacking spell-power buff that other spells do not consume, with
-- Arcane Wrath to spend it), after Warcraft Tavern: Missiles on Barrage, Clearcasting on Arcane
-- Blast, Arcane Wrath at three stacks, Arcane Blast to four stacks on elites and two otherwise
-- (mana is secret on Forever, so while it is affordable), then Frostfire Bolt, Frostbolt or
-- Fireball to fish for Barrage. Without Arcane
-- Wrath (the older beta design) Fire Blast spends the stacks, as Icy Veins and Wowhead advise.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
-- Talent trees in the Forever talent window's order (assumed classic: 1 Arcane, 2 Fire, 3 Frost; verify in game).
-- Level 10 first (no talent config below it), then the points (an empty tree is a clean no-match),
-- then the primary tree, which settles hybrids.
local function tree(n,points)return{type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 {type='TALENT_TREE_POINTS',tree=n,operator='GREATERTHANOREQUALS',value=points},{type='PRIMARY_TALENT_TREE',tree=n}}}end
local function known(...)local list={};for i,id in ipairs({...})do list[i]={type='SPELL_KNOWN',spell=id}end;return{type='OR',value=list}end
local function stacks(op,v)return{type='BUFF_STACKS',unit='player',spell=400573,operator=op,value=v}end
local elite=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
local charged={type='BUFF',unit='player',spell=400573}
local barrage=BuiltinConditions.any({type='BUFF',unit='player',spell=400589},{type='BUFF',unit='player',spell=1326083})
local function below(n)return BuiltinConditions.any(BuiltinConditions.negate(charged),stacks('LESSTHAN',n))end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.mage.arcane',revision=7,
 blocks={['forever.mage.boundaries']=3,['forever.mage.frostbolt']=1,['forever.mage.wand']=3,['forever.mage.upkeep']=2},
 applicability={families={'forever'},actionContext='player',class='MAGE'},
 tags={'arcane','leveling','single-target','aoe','warcraft-tavern'},
 sources={
  {url='https://www.warcrafttavern.com/forever/guides/arcane-mage/',title='Warcraft Tavern: Forever Arcane Mage',reviewedAt='2026-10-23'},
  {url='https://www.wowhead.com/forever/guide/classes/mage/arcane/level-30-dps-overview',title='Wowhead: Forever level 30 Arcane Mage',reviewedAt='2026-10-23',revision='2026-10-06',notes='Two-stack cap on normal mobs; Fire Blast stack dump.'},
  {url='https://www.icy-veins.com/wow-forever/arcane-mage-ranged-dps-pve-guide',title='Icy Veins: Forever Arcane Mage PvE',reviewedAt='2026-10-23',revision='2026-10-16',notes='Solo Frostbolt pull; Fire Blast stack dump.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/mage.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Arcane Blast aura, Arcane Wrath and ranks only.'},
 },
 body={priority=20,
  switch=BuiltinConditions.all(tree(1,11),known(400574,1239696,1239697,1239699,1239700)),
  cooldowns={
   BuiltinConditions.block('arcane-upkeep','forever.mage.upkeep','arcane-'),
   BuiltinConditions.spell('arcane-presence-of-mind',12043,BuiltinConditions.all(BuiltinConditions.combat(),elite)),
   BuiltinConditions.spell('arcane-power',12042,BuiltinConditions.all(BuiltinConditions.combat(),elite)),
  },
  rotation={
   BuiltinConditions.block('arcane-boundaries','forever.mage.boundaries','arcane-'),
   {id='arcane-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
    BuiltinConditions.spell('arcane-pull-frostbolt',116,BuiltinConditions.negate({type='GROUP'})),BuiltinConditions.spell('arcane-pull-blast',400574),BuiltinConditions.stop('arcane-pull-stop')}},
   {id='arcane-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    BuiltinConditions.spell('arcane-moving-fire-blast',2136),BuiltinConditions.stop('arcane-moving-stop')}},
   BuiltinConditions.spell('arcane-missiles',5143,barrage),
   BuiltinConditions.spell('arcane-clearcasting-blast',400574,{type='BUFF',unit='player',spell=12536}),
   {id='arcane-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    BuiltinConditions.spell('arcane-explosion',1449),BuiltinConditions.stop('arcane-aoe-stop')}},
   BuiltinConditions.spell('arcane-wrath',1326079,stacks('GREATERTHANOREQUALS',3)),
   {id='arcane-big',type='branch',conditions=elite,
    onTrue={BuiltinConditions.spell('arcane-blast-four',400574,below(4))},
    onFalse={BuiltinConditions.spell('arcane-blast-two',400574,below(2))}},
   BuiltinConditions.spell('arcane-dump-fire-blast',2136,BuiltinConditions.all(BuiltinConditions.negate(known(1326079,1326080,1326081,1326082)),charged)),
   BuiltinConditions.spell('arcane-frostfire',401502),
   BuiltinConditions.block('arcane-filler','forever.mage.frostbolt','arcane-'),
   BuiltinConditions.block('arcane-wand','forever.mage.wand','arcane-'),
  },
 },
}))
