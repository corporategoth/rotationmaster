-- WoW Forever Fire Mage, levels 10–60, once Pyroblast (the 11-point Fire talent) is known.
-- Warcraft Tavern's and Wowhead's Heating Up play with Icy Veins' extras: Pyroblast at three Heating
-- Up stacks, Fire Blast on cooldown, Scorch to keep your five Fire Vulnerability stacks on elites,
-- Frostfire Bolt (from 40) or Fireball. Ice Lance steps serve Fire/Frost hybrids. RM cannot see
-- whether Improved Scorch is talented, so Scorch only refreshes stacks you already applied; the
-- step that starts them is off by default. The Icy Veins leveling variant is rm.forever.mage.fire.icyveins.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(...)local list={};for i,id in ipairs({...})do list[i]={type='SPELL_KNOWN',spell=id}end;return{type='OR',value=list}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function off(id,action,conditions)local step=spell(id,action,conditions);step.disabled=true;return step end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local elite=any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
local fingers=any({type='BUFF',unit='player',spell=400669},{type='BUFF',unit='player',spell=400670})
local frozen=any({type='DEBUFF',unit='target',spell=122,anyrank=true},{type='DEBUFF',unit='target',spell=12494})
local vulnerable={type='DEBUFF',unit='target',spell=22959,owndebuff=true}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.mage.fire',revision=1,
 blocks={['forever.mage.lance-batch']=1,['forever.mage.boundaries']=1,['forever.mage.fire-moving']=1,['forever.mage.fire-aoe']=1,['forever.mage.wand']=1,['forever.mage.upkeep']=1},
 nameKey='Default.Forever.Mage.Fire.Name',descriptionKey='Default.Forever.Mage.Fire.Description',
 applicability={families={'forever'},actionContext='player',class='MAGE',minLevel=10,maxLevel=60},
 tags={'fire','leveling','single-target','aoe','warcraft-tavern','wowhead'},
 sources={
  {url='https://www.warcrafttavern.com/forever/guides/fire-mage/',title='Warcraft Tavern: Forever Fire Mage',reviewedAt='2026-10-23'},
  {url='https://www.wowhead.com/forever/guide/classes/mage/fire/level-30-dps-overview',title='Wowhead: Forever level 30 Fire Mage',reviewedAt='2026-10-23',revision='2026-10-06'},
  {url='https://www.icy-veins.com/wow-forever/fire-mage-ranged-dps-pve-guide',title='Icy Veins: Forever Fire Mage PvE',reviewedAt='2026-10-23',revision='2026-10-16',notes='Pyroblast pull on bosses, Frostfire Bolt from 40, Fire AoE order.'},
  {url='https://www.warcrafttavern.com/forever/news/scrolls-totems-mage-shaman-deep-dive-for-wow-forever/',title='Blizzard Mage and Shaman deep dive (as published by Warcraft Tavern)',reviewedAt='2026-10-23',revision='2026-10-07',notes='Heating Up, Improved Scorch and Fire Power changes; no priority.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/mage.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks and auras only.'},
 },
 body={priority=30,switch=known(11366,12505,12522,12523,12524,12525,12526,18809),
  cooldowns={
   block('fire-upkeep','forever.mage.upkeep','fire-'),
   spell('fire-combustion',11129,all(combat(),elite)),
   spell('fire-presence-of-mind',12043,all(combat(),elite)),
  },
  rotation={
   block('fire-lance-batch','forever.mage.lance-batch','fire-'),
   block('fire-boundaries','forever.mage.boundaries','fire-'),
   {id='fire-pull',type='branch',conditions=negate(combat()),onFalse={},onTrue={
    spell('fire-pull-pyroblast',11366,elite),spell('fire-pull-frostfire',401502),spell('fire-pull-fireball',133),stop('fire-pull-stop')}},
   block('fire-moving','forever.mage.fire-moving','fire-'),
   spell('fire-hot-pyroblast',11366,{type='BUFF_STACKS',unit='player',spell=400625,operator='GREATERTHANOREQUALS',value=3}),
   spell('fire-ice-lance',1312002,any(fingers,frozen)),
   spell('fire-blast',2136),
   spell('fire-scorch-refresh',2948,all(elite,vulnerable,any({type='DEBUFF_STACKS',unit='target',spell=22959,owndebuff=true,operator='LESSTHAN',value=5},
    {type='DEBUFF_REMAIN',unit='target',spell=22959,owndebuff=true,operator='LESSTHAN',value=5}))),
   off('fire-scorch-apply',2948,all(elite,negate(vulnerable))),
   block('fire-aoe','forever.mage.fire-aoe','fire-'),
   off('fire-close-scorch',2948,{type='DISTANCE',unit='target',value=8}),
   spell('fire-frostfire',401502),
   spell('fire-fireball',133),
   block('fire-wand','forever.mage.wand','fire-'),
  },
 },
}))
