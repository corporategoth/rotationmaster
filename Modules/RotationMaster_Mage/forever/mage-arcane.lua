-- WoW Forever Arcane Mage, levels 10–60, once Arcane is the main tree with 11 points and Arcane Blast
-- is known (a Frost Mage who took Missile Barrage first stays Frost). Written for the
-- current Arcane Blast (a 15 s stacking spell-power buff that other spells do not consume, with
-- Arcane Wrath to spend it), after Warcraft Tavern: Missiles on Barrage, Clearcasting on Arcane
-- Blast, Arcane Wrath at three stacks, Arcane Blast to four stacks on elites and two otherwise
-- (mana is secret on Forever, so while it is affordable), then Frostfire Bolt, Frostbolt or
-- Fireball to fish for Barrage. Without Arcane
-- Wrath (the older beta design) Fire Blast spends the stacks, as Icy Veins and Wowhead advise.
local _,addon=...
-- Talent trees in the Forever talent window's order (assumed classic: 1 Arcane, 2 Fire, 3 Frost; verify in game).
-- Level 10 first (no talent config below it), then the points (an empty tree is a clean no-match),
-- then the primary tree, which settles hybrids.
local function tree(n,points)return{type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 {type='TALENT_TREE_POINTS',tree=n,operator='GREATERTHANOREQUALS',value=points},{type='PRIMARY_TALENT_TREE',tree=n}}}end
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(...)local list={};for i,id in ipairs({...})do list[i]={type='SPELL_KNOWN',spell=id}end;return{type='OR',value=list}end
local function stacks(op,v)return{type='BUFF_STACKS',unit='player',spell=400573,operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local elite=any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
local charged={type='BUFF',unit='player',spell=400573}
local barrage=any({type='BUFF',unit='player',spell=400589},{type='BUFF',unit='player',spell=1326083})
local function below(n)return any(negate(charged),stacks('LESSTHAN',n))end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.mage.arcane',revision=6,
 blocks={['forever.mage.boundaries']=3,['forever.mage.frostbolt']=1,['forever.mage.wand']=3,['forever.mage.upkeep']=2},
 nameKey='Default.Forever.Mage.Arcane.Name',descriptionKey='Default.Forever.Mage.Arcane.Description',
 applicability={families={'forever'},actionContext='player',class='MAGE'},
 tags={'arcane','leveling','single-target','aoe','warcraft-tavern'},
 sources={
  {url='https://www.warcrafttavern.com/forever/guides/arcane-mage/',title='Warcraft Tavern: Forever Arcane Mage',reviewedAt='2026-10-23'},
  {url='https://www.wowhead.com/forever/guide/classes/mage/arcane/level-30-dps-overview',title='Wowhead: Forever level 30 Arcane Mage',reviewedAt='2026-10-23',revision='2026-10-06',notes='Two-stack cap on normal mobs; Fire Blast stack dump.'},
  {url='https://www.icy-veins.com/wow-forever/arcane-mage-ranged-dps-pve-guide',title='Icy Veins: Forever Arcane Mage PvE',reviewedAt='2026-10-23',revision='2026-10-16',notes='Solo Frostbolt pull; Fire Blast stack dump.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/mage.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Arcane Blast aura, Arcane Wrath and ranks only.'},
 },
 body={priority=20,
  switch=all(tree(1,11),known(400574,1239696,1239697,1239699,1239700)),
  cooldowns={
   block('arcane-upkeep','forever.mage.upkeep','arcane-'),
   spell('arcane-presence-of-mind',12043,all(combat(),elite)),
   spell('arcane-power',12042,all(combat(),elite)),
  },
  rotation={
   block('arcane-boundaries','forever.mage.boundaries','arcane-'),
   {id='arcane-pull',type='branch',conditions=combat(),onTrue={},onFalse={
    spell('arcane-pull-frostbolt',116,negate({type='GROUP'})),spell('arcane-pull-blast',400574),stop('arcane-pull-stop')}},
   {id='arcane-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    spell('arcane-moving-fire-blast',2136),stop('arcane-moving-stop')}},
   spell('arcane-missiles',5143,barrage),
   spell('arcane-clearcasting-blast',400574,{type='BUFF',unit='player',spell=12536}),
   {id='arcane-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    spell('arcane-explosion',1449),stop('arcane-aoe-stop')}},
   spell('arcane-wrath',1326079,stacks('GREATERTHANOREQUALS',3)),
   {id='arcane-big',type='branch',conditions=elite,
    onTrue={spell('arcane-blast-four',400574,below(4))},
    onFalse={spell('arcane-blast-two',400574,below(2))}},
   spell('arcane-dump-fire-blast',2136,all(negate(known(1326079,1326080,1326081,1326082)),charged)),
   spell('arcane-frostfire',401502),
   block('arcane-filler','forever.mage.frostbolt','arcane-'),
   block('arcane-wand','forever.mage.wand','arcane-'),
  },
 },
}))
