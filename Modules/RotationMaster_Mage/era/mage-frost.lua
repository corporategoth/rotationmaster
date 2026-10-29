-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Mage Frost, levels 1–60, and the Mage default (lowest priority): Frost and Arcane
-- builds play Frostbolt, as every Era source has them do. Fireball until Frostbolt (level 4);
-- Frost Nova when a mob reaches you; Arcane Missiles in melee with Improved Arcane Missiles;
-- Cone of Cold, Arcane Explosion and Blizzard when three or more enemies are engaged; Fire Blast
-- and the wand finish ordinary mobs. Blink, kiting, Polymorph and Ice Block stay with the player.
-- Optional (disabled): the Shatter Flamestrike and rank-1 Frostbolt to stack Winter's Chill.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function near(n)return{type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=n}end
local function talent(tree,index,v)return{type='TALENT',layout='tree',tree=tree,talent=index,operator='GREATERTHANOREQUALS',value=v or 1}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id)return{id=id,type='stop',suppress_attack=true,conditions={}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local P='mage-frost-'
local onMe={type='THREAT',unit='target',threat=3}
local frozen={type='DEBUFF',unit='target',spell=122,anyrank=true}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.mage.frost',revision=5,
 blocks={['era.mage.boundaries']=3,['era.mage.frostbolt']=1,['era.mage.moving']=2,['era.mage.nova']=1,['era.mage.execute']=2,
  ['era.mage.wand-finish']=2,['era.mage.armor']=1,['era.mage.upkeep']=1},
 nameKey='Default.Era.Mage.Frost.Name',descriptionKey='Default.Era.Mage.Frost.Description',
 applicability={families={'era'},actionContext='player',class='MAGE'},
 tags={'frost','arcane','leveling','raid','single-target','aoe'},
 sources={
  {url='https://www.icy-veins.com/wow-classic/mage-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Mage DPS rotation',reviewedAt='2026-10-23',revision='2024-11-17'},
  {url='https://www.icy-veins.com/wow-classic/single-target-frost-mage-leveling-talent-build-from-1-to-60',title='Icy Veins: single-target Frost Mage leveling',reviewedAt='2026-10-23',revision='2026-07-18'},
  {url='https://www.icy-veins.com/wow-classic/arcane-mage-leveling-talent-build-from-1-to-60',title='Icy Veins: Arcane Mage leveling',reviewedAt='2026-10-23',revision='2026-07-18'},
  {url='https://www.wowhead.com/classic/guide/classes/mage/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Mage DPS rotation',reviewedAt='2026-10-23',revision='2025-03-20'},
  {url='https://www.wowhead.com/classic/guide/classes/mage/frost/leveling-tips',title='Wowhead: Classic Frost Mage leveling',reviewedAt='2026-10-23',revision='2024-11-18'},
  {url='https://www.wowhead.com/classic/guide/classes/mage/arcane/leveling-tips',title='Wowhead: Classic Arcane Mage leveling',reviewedAt='2026-10-23',revision='2024-11-20'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/pve-frost-mage-rotations-cooldowns/',title='Warcraft Tavern: Classic Frost Mage PvE',reviewedAt='2026-10-23'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/pve-arcane-mage-rotations-cooldowns/',title='Warcraft Tavern: Classic Arcane Mage PvE',reviewedAt='2026-10-23'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/mage-leveling-guide/',title='Warcraft Tavern: Classic Mage leveling',reviewedAt='2026-10-23'},
  {url='https://github.com/kaminaris/MaxDps-Mage/tree/886c8e27f48e38e0f9b8c22cf56b5e625dfce3f0/Specialization/Classic',title='MaxDps-Mage Classic Frost and Arcane modules',reviewedAt='2026-10-23',revision='886c8e2'},

 },
 body={
  priority=1,
  cooldowns={block(P..'armor','era.mage.armor',P),block(P..'upkeep','era.mage.upkeep',P)},
  rotation={
   block(P..'boundaries','era.mage.boundaries',P),
   {id=P..'pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    block(P..'pull-filler','era.mage.frostbolt',P..'pull-'),stop(P..'pull-stop')}},
   block(P..'moving','era.mage.moving',P),
   block(P..'nova','era.mage.nova',P),
   -- Arcane leveling: channel Missiles once an enemy reaches you (Improved Arcane Missiles stops pushback).
   spell(P..'arcane-missiles',5143,all(talent(1,3,3),near(1),onMe)),
   {id=P..'aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    spell(P..'aoe-cone',120,near(2)),
    spell(P..'aoe-explosion',1449,near(3)),
    {id=P..'aoe-shatter-flamestrike',type='spell',action=2120,ranked=false,disabled=true,conditions=all(frozen,talent(3,13))},
    spell(P..'aoe-blizzard',10)}},
   block(P..'execute','era.mage.execute',P),
   -- Optional raid opener: rank-1 Frostbolt stacks Winter's Chill cheaply to five.
   {id=P..'winters-chill',type='spell',action=116,ranked=true,disabled=true,conditions=all(talent(3,16),
    negate({type='DEBUFF_STACKS',unit='target',spell=12579,operator='GREATERTHANOREQUALS',value=5}))},
   block(P..'filler','era.mage.frostbolt',P),
   block(P..'finish','era.mage.wand-finish',P),
  },
 },
}))
