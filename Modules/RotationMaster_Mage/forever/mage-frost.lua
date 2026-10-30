-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Frost Mage, levels 1–60, and the Mage catch-all (lowest priority): every Mage before
-- a talent spell (levels 1–19) and Missile-Barrage-only builds level here. Icy Veins' Frost order
-- with Warcraft Tavern's Missile Barrage rule: Ice Lance on Fingers of Frost or a frozen target,
-- Cone of Cold at five Winter's Chill, Arcane Missiles on Barrage, Frostbolt. Instants first while
-- moving. AoE on three or more fighting you: Cone of Cold; Blizzard (Arcane Explosion with a mob on
-- you) from five. Warcraft Tavern's Flamestrike/Explosion AoE is in the AoE branch, off by default.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function off(id,action,conditions)local step=BuiltinConditions.spell(id,action,conditions);step.disabled=true;return step end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local fingers=BuiltinConditions.any({type='BUFF',unit='player',spell=400669},{type='BUFF',unit='player',spell=400670})
local frozen=BuiltinConditions.any({type='DEBUFF',unit='target',spell=122,anyrank=true},{type='DEBUFF',unit='target',spell=12494})
local barrage=BuiltinConditions.any({type='BUFF',unit='player',spell=400589},{type='BUFF',unit='player',spell=1326083})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.mage.frost',revision=6,
 blocks={['forever.mage.lance-batch']=1,['forever.mage.boundaries']=3,['forever.mage.frostbolt']=1,['forever.mage.wand']=3,['forever.mage.upkeep']=2},
 applicability={families={'forever'},actionContext='player',class='MAGE'},
 tags={'frost','leveling','single-target','aoe','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow-forever/frost-mage-ranged-dps-pve-guide',title='Icy Veins: Forever Frost Mage PvE',reviewedAt='2026-10-23',revision='2026-10-16'},
  {url='https://www.icy-veins.com/wow-forever/frost-mage-leveling',title='Icy Veins: Forever Frost Mage leveling',reviewedAt='2026-10-23',revision='2026-10-16'},
  {url='https://www.warcrafttavern.com/forever/guides/frost-mage/',title='Warcraft Tavern: Forever Frost Mage',reviewedAt='2026-10-23',notes='Missile Barrage on every proc; the optional Flamestrike/Explosion AoE.'},
  {url='https://www.wowhead.com/forever/guide/classes/mage/frost/level-30-dps-overview',title='Wowhead: Forever level 30 Frost Mage',reviewedAt='2026-10-23',revision='2026-10-09'},
  {url='https://www.warcrafttavern.com/forever/news/scrolls-totems-mage-shaman-deep-dive-for-wow-forever/',title='Blizzard Mage and Shaman deep dive (as published by Warcraft Tavern)',reviewedAt='2026-10-23',revision='2026-10-07',notes='Mechanics only (Winter\'s Chill, Fingers of Frost); no priority.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/mage.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks and auras only.'},
 },
 body={priority=10,
  cooldowns={
   BuiltinConditions.block('frost-upkeep','forever.mage.upkeep','frost-'),
   BuiltinConditions.spell('frost-cold-snap',12472,BuiltinConditions.all(BuiltinConditions.combat(),{type='SPELL_COOLDOWN',spell=122,operator='GREATERTHAN',value=2},{type='DISTANCE',unit='target',value=8})),
  },
  rotation={
   BuiltinConditions.block('frost-lance-batch','forever.mage.lance-batch','frost-'),
   BuiltinConditions.block('frost-boundaries','forever.mage.boundaries','frost-'),
   {id='frost-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
    BuiltinConditions.block('frost-pull-filler','forever.mage.frostbolt','frost-pull-'),BuiltinConditions.stop('frost-pull-stop')}},
   BuiltinConditions.spell('frost-fingers-lance',1312002,fingers),
   BuiltinConditions.spell('frost-frozen-lance',1312002,frozen),
   BuiltinConditions.spell('frost-chill-cone',120,BuiltinConditions.all({type='DEBUFF_STACKS',unit='target',spell=12579,owndebuff=true,operator='GREATERTHANOREQUALS',value=5},{type='DISTANCE',unit='target',value=10})),
   {id='frost-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    BuiltinConditions.spell('frost-moving-lance',1312002),BuiltinConditions.spell('frost-moving-fire-blast',2136),BuiltinConditions.stop('frost-moving-stop')}},
   BuiltinConditions.spell('frost-missiles',5143,barrage),
   {id='frost-aoe',type='branch',conditions=engaged(3),onFalse={},onTrue={
    off('frost-aoe-tavern-flamestrike',2120,BuiltinConditions.negate({type='DEBUFF',unit='target',spell=2120,anyrank=true,owndebuff=true})),
    off('frost-aoe-tavern-explosion',1449),
    BuiltinConditions.spell('frost-aoe-cone',120),
    {id='frost-aoe-five',type='branch',conditions=engaged(5),onFalse={},onTrue={
     {id='frost-aoe-close',type='branch',conditions={type='BEYOND_MELEE',unit='target'},
      onTrue={BuiltinConditions.spell('frost-aoe-blizzard',10)},onFalse={BuiltinConditions.spell('frost-aoe-explosion',1449)}}}}}},
   BuiltinConditions.block('frost-filler','forever.mage.frostbolt','frost-'),
   BuiltinConditions.block('frost-wand','forever.mage.wand','frost-'),
  },
 },
}))
