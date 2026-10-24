-- WoW Forever Fire Mage, levels 10–60, once Fire is the main tree with 11 points (Pyroblast's tier).
-- Warcraft Tavern's and Wowhead's Heating Up play with Icy Veins' extras: Pyroblast at three Heating
-- Up stacks, Fire Blast on cooldown, Scorch to keep your five Fire Vulnerability stacks on elites,
-- Frostfire Bolt (from 40) or Fireball. Ice Lance steps serve Fire/Frost hybrids. Scorch starts the
-- stacks only with Improved Scorch talented (trait node 105788). The Icy Veins leveling variant is
-- rm.forever.mage.fire.icyveins.
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
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function off(id,action,conditions)local step=spell(id,action,conditions);step.disabled=true;return step end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local elite=any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
local fingers=any({type='BUFF',unit='player',spell=400669},{type='BUFF',unit='player',spell=400670})
local frozen=any({type='DEBUFF',unit='target',spell=122,anyrank=true},{type='DEBUFF',unit='target',spell=12494})
local vulnerable={type='DEBUFF',unit='target',spell=22959,owndebuff=true}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.mage.fire',revision=6,
 blocks={['forever.mage.lance-batch']=1,['forever.mage.boundaries']=3,['forever.mage.fire-moving']=2,['forever.mage.fire-aoe']=1,['forever.mage.wand']=3,['forever.mage.upkeep']=2},
 nameKey='Default.Forever.Mage.Fire.Name',descriptionKey='Default.Forever.Mage.Fire.Description',
 applicability={families={'forever'},actionContext='player',class='MAGE'},
 tags={'fire','leveling','single-target','aoe','warcraft-tavern','wowhead'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/4dd64b4a212e946cdbf22219f7d7c42f2fe0e23d/engine/dbc/generated/trait_data.inc',title='SimulationCraft Forever trait data (1.60.1.70425): talent node IDs',reviewedAt='2026-10-23',revision='4dd64b4'},
  {url='https://www.warcrafttavern.com/forever/guides/fire-mage/',title='Warcraft Tavern: Forever Fire Mage',reviewedAt='2026-10-23'},
  {url='https://www.wowhead.com/forever/guide/classes/mage/fire/level-30-dps-overview',title='Wowhead: Forever level 30 Fire Mage',reviewedAt='2026-10-23',revision='2026-10-06'},
  {url='https://www.icy-veins.com/wow-forever/fire-mage-ranged-dps-pve-guide',title='Icy Veins: Forever Fire Mage PvE',reviewedAt='2026-10-23',revision='2026-10-16',notes='Pyroblast pull on bosses, Frostfire Bolt from 40, Fire AoE order.'},
  {url='https://www.warcrafttavern.com/forever/news/scrolls-totems-mage-shaman-deep-dive-for-wow-forever/',title='Blizzard Mage and Shaman deep dive (as published by Warcraft Tavern)',reviewedAt='2026-10-23',revision='2026-10-07',notes='Heating Up, Improved Scorch and Fire Power changes; no priority.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/mage.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks and auras only.'},
 },
 body={priority=30,switch=tree(2,11),
  cooldowns={
   block('fire-upkeep','forever.mage.upkeep','fire-'),
   spell('fire-combustion',11129,all(combat(),elite)),
   spell('fire-presence-of-mind',12043,all(combat(),elite)),
  },
  rotation={
   block('fire-lance-batch','forever.mage.lance-batch','fire-'),
   block('fire-boundaries','forever.mage.boundaries','fire-'),
   {id='fire-pull',type='branch',conditions=combat(),onTrue={},onFalse={
    spell('fire-pull-pyroblast',11366,elite),spell('fire-pull-frostfire',401502),spell('fire-pull-fireball',133),stop('fire-pull-stop')}},
   block('fire-moving','forever.mage.fire-moving','fire-'),
   spell('fire-hot-pyroblast',11366,{type='BUFF_STACKS',unit='player',spell=400625,operator='GREATERTHANOREQUALS',value=3}),
   spell('fire-ice-lance',1312002,any(fingers,frozen)),
   spell('fire-blast',2136),
   spell('fire-scorch-refresh',2948,all(elite,vulnerable,any({type='DEBUFF_STACKS',unit='target',spell=22959,owndebuff=true,operator='LESSTHAN',value=5},
    {type='DEBUFF_REMAIN',unit='target',spell=22959,owndebuff=true,operator='LESSTHAN',value=5}))),
   spell('fire-scorch-apply',2948,all({type='TALENT',layout='traits',node=105788,operator='GREATERTHANOREQUALS',value=1},elite,negate(vulnerable))),
   block('fire-aoe','forever.mage.fire-aoe','fire-'),
   off('fire-close-scorch',2948,{type='DISTANCE',unit='target',value=8}),
   spell('fire-frostfire',401502),
   spell('fire-fireball',133),
   block('fire-wand','forever.mage.wand','fire-'),
  },
 },
}))
