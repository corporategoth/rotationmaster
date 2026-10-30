-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Warlock before a specialization (levels 1-9, or later with none chosen): the
-- class catch-all, lowest priority, so every specialization premade beats it from level 10. Corruption to
-- pull, Drain Life below half health, Corruption kept up, Shadow Bolt. Reminders: the Voidwalker solo (the
-- Imp in a group or before level 8) and a Healthstone between pulls. No guide covers these levels; this is
-- the level 1-9 kit arranged like the TBC solo branch. Shared parts: mop/blocks.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local corrupted={type='DEBUFF',unit='target',spell=172,anyrank=true,owndebuff=true}
local petless=BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate({type='PET'}))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.warlock.unspecialized',revision=7,
 blocks={['mop.warlock.boundaries']=4},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='WARLOCK'},
 tags={'dps','caster','ranged','leveling'},
 sources={{url='https://www.icy-veins.com/mists-of-pandaria-classic/affliction-warlock-leveling',title='Icy Veins: Affliction Warlock leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-06-10'},
 {url='https://wago.tools/db2/SpellLevels?build=5.5.4.70531',title='wago.tools: MoP Classic 5.5.4 SpellLevels (level 1-9 kit)',reviewedAt='2026-10-23',revision='5.5.4.70531'}},
 body={priority=1,
 cooldowns={
  BuiltinConditions.spell('warlock-start-voidwalker',697,BuiltinConditions.all(petless,BuiltinConditions.negate({type='GROUP'}))),
  BuiltinConditions.spell('warlock-start-imp',688,BuiltinConditions.all(petless,BuiltinConditions.any({type='GROUP'},BuiltinConditions.negate({type='SPELL_KNOWN',spell=697})))),
  BuiltinConditions.spell('warlock-start-healthstone',6201,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),{type='CARRYING',item={5512},operator='LESSTHAN',value=1})),
 },
 rotation={
 block('mop.warlock.boundaries','warlock-'),
 {id='warlock-start-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('warlock-start-pull-corruption',172,BuiltinConditions.negate(corrupted)),
  BuiltinConditions.spell('warlock-start-pull-shadow-bolt',686),
  {id='warlock-start-pull-stop',type='stop',suppress_attack=true,conditions={}},
 }},
 BuiltinConditions.spell('warlock-start-drain-life',689,{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5}),
 BuiltinConditions.spell('warlock-start-corruption',172,BuiltinConditions.negate(corrupted)),
 BuiltinConditions.spell('warlock-start-shadow-bolt',686),
 }},
}))
