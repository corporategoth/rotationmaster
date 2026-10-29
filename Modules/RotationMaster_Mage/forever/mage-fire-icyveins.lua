-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Fire Mage after Icy Veins' leveling build (no Improved Scorch), levels 10–60: a
-- player-chosen alternative to rm.forever.mage.fire (same switch, lower priority, off by default).
-- Pyroblast opens; Fire Blast spends Wake of Fire; Scorch as the mob closes (target health is secret
-- on Forever, so its low-target finishers are left out);
-- Frostfire Bolt from 40, else Fireball. No Heating Up or Scorch-stack steps.
local _,addon=...
-- Talent trees in the Forever talent window's order (assumed classic: 1 Arcane, 2 Fire, 3 Frost; verify in game).
-- Level 10 first (no talent config below it), then the points (an empty tree is a clean no-match),
-- then the primary tree, which settles hybrids.
local function tree(n,points)return{type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 {type='TALENT_TREE_POINTS',tree=n,operator='GREATERTHANOREQUALS',value=points},{type='PRIMARY_TALENT_TREE',tree=n}}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.mage.fire.icyveins',revision=7,
 blocks={['forever.mage.boundaries']=3,['forever.mage.fire-moving']=2,['forever.mage.fire-aoe']=1,['forever.mage.wand']=3,['forever.mage.upkeep']=2},
 nameKey="Fire leveling (Icy Veins)",descriptionKey="Icy Veins' Fire leveling build without Improved Scorch, an alternative to the recommended Fire premade, off by default: enable it and disable that one, or raise its priority. Pulls with Pyroblast, uses Fire Blast to spend Wake of Fire, Scorch as the mob closes (target health is hidden on Forever, so its low-target finishers are yours), then Frostfire Bolt (from 40) or Fireball. Same AoE, movement, wand and reminders as the Fire premade, without Combustion and Presence of Mind.",
 applicability={families={'forever'},actionContext='player',class='MAGE'},
 tags={'fire','leveling','single-target','aoe','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow-forever/fire-mage-leveling',title='Icy Veins: Forever Fire Mage leveling',reviewedAt='2026-10-23',revision='2026-10-16'},
  {url='https://www.icy-veins.com/wow-forever/fire-mage-ranged-dps-pve-guide',title='Icy Veins: Forever Fire Mage PvE',reviewedAt='2026-10-23',revision='2026-10-16'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/mage.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks and auras only.'},
 },
 body={priority=25,disabled=true,switch=tree(2,11),
  cooldowns={block('ivfire-upkeep','forever.mage.upkeep','ivfire-')},
  rotation={
   block('ivfire-boundaries','forever.mage.boundaries','ivfire-'),
   {id='ivfire-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell('ivfire-pull-pyroblast',11366),spell('ivfire-pull-fireball',133),stop('ivfire-pull-stop')}},
   block('ivfire-moving','forever.mage.fire-moving','ivfire-'),
   spell('ivfire-fire-blast',2136,{type='BUFF',unit='player',spell=1312934}),
   block('ivfire-aoe','forever.mage.fire-aoe','ivfire-'),
   spell('ivfire-scorch',2948,{type='DISTANCE',unit='target',value=8}),
   spell('ivfire-frostfire',401502),
   spell('ivfire-fireball',133),
   block('ivfire-wand','forever.mage.wand','ivfire-'),
  },
 },
}))
