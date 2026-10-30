-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever damage Priest after Mobalytics' DoT-and-wand leveling style, levels 1–60: a
-- player-chosen alternative to rm.forever.priest.dps (same switch, lower priority, off by default).
-- Before
-- Shadowform: Mind Blast and Holy Fire only on tough mobs (elite, or two levels above you), own
-- Shadow Word: Pain and Devouring Plague, then the wand; Shield and Renew on yourself between pulls.
-- From Shadowform (40): Mind Blast, Pain, Plague, Mind Flay. Health and mana are secret on Forever,
-- so the emergency heals and the mana and target-health checks are left out.
-- Spreading Pain across several mobs (tabbing) stays with the player.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function mine(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local shadowform={type='BUFF',unit='player',spell=15473}
local unshielded=BuiltinConditions.negate({type='DEBUFF',unit='player',spell=6788})
local tough=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},
 {type='CLASSIFICATION',unit='target',value='worldboss'},{type='LEVEL',unit='target',operator='GREATERTHANOREQUALS',value=2,relative=true})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.priest.dps.mobalytics',revision=6,
 blocks={['forever.priest.dps-boundaries']=2,['forever.priest.upkeep']=1,['forever.priest.dps-upkeep']=2,['forever.priest.wand']=2},
 applicability={families={'forever'},actionContext='player',class='PRIEST'},
 tags={'shadow','leveling','dot','wand','mobalytics'},
 sources={
  {url='https://mobalytics.gg/wow-forever/classes/priest-leveling-guide-1-60',title='Mobalytics: Forever Priest leveling 1–60',reviewedAt='2026-10-23',revision='2026-10-07'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/priest.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks and cooldowns only.'},
 },
 body={priority=5,disabled=true,
  cooldowns={
   BuiltinConditions.block('dot-upkeep','forever.priest.upkeep','dot-'),
   BuiltinConditions.block('dot-reminders','forever.priest.dps-upkeep','dot-'),
   BuiltinConditions.spell('dot-prepull-shield',17,BuiltinConditions.all(BuiltinConditions.negate({type='COMBAT',unit='player'}),unshielded)),
   BuiltinConditions.spell('dot-prepull-renew',139,BuiltinConditions.all(BuiltinConditions.negate({type='COMBAT',unit='player'}),BuiltinConditions.negate(mine(139)))),
   BuiltinConditions.spell('dot-cure-disease',528,{type='DISPELLABLE',unit='player',debufftype='Disease'}),
  },
  rotation={
   BuiltinConditions.block('dot-boundaries','forever.priest.dps-boundaries','dot-'),
   BuiltinConditions.spell('dot-shadowform',15473,BuiltinConditions.negate(shadowform)),
   {id='dot-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell('dot-pull-holy-fire',14914,BuiltinConditions.all(tough,BuiltinConditions.negate(BuiltinConditions.known(15473)))),
    BuiltinConditions.spell('dot-pull-mind-blast',8092,tough),
    BuiltinConditions.spell('dot-pull-pain',589,BuiltinConditions.negate(own(589))),
    BuiltinConditions.spell('dot-pull-smite',585,BuiltinConditions.negate(BuiltinConditions.known(589))),
    BuiltinConditions.stop('dot-pull-stop')}},
   {id='dot-shadow',type='branch',conditions=shadowform,onFalse={},onTrue={
    BuiltinConditions.spell('dot-shadow-blast',8092),
    BuiltinConditions.spell('dot-shadow-pain',589,BuiltinConditions.negate(own(589))),
    BuiltinConditions.spell('dot-shadow-plague',2944,BuiltinConditions.negate(own(2944))),
    BuiltinConditions.spell('dot-shadow-flay',15407),
    BuiltinConditions.stop('dot-shadow-stop')}},
   BuiltinConditions.spell('dot-pain',589,BuiltinConditions.negate(own(589))),
   BuiltinConditions.spell('dot-plague',2944,BuiltinConditions.negate(own(2944))),
   BuiltinConditions.block('dot-wand','forever.priest.wand','dot-'),
   BuiltinConditions.spell('dot-smite',585),
   BuiltinConditions.stop('dot-done'),
  },
 },
}))
