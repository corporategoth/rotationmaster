-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever damage Priest, levels 1–60, and the Priest catch-all (lowest priority): Shadow, and
-- every Priest's solo play (Smite, Holy and Discipline levelers too). Icy Veins' and Wowhead's
-- order with Mobalytics' level-40 Shadowform play: Shield and Mind Blast (Holy Fire for Holy and
-- Discipline) to pull, Mind Blast, own Shadow Word: Pain and Devouring Plague, then the wand while
-- leveling solo, Mind Flay in Shadowform or a group. Discipline adds Holy Fire into Penance. Health
-- and mana are secret on Forever, so the execute window, the solo emergency heals and the mana
-- rules for Mind Blast, Plague, Holy Nova and solo Mind Flay are left out.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function known(...)local list={};for i,id in ipairs({...})do list[i]={type='SPELL_KNOWN',spell=id}end;return{type='OR',value=list}end
local shadowform={type='BUFF',unit='player',spell=15473}
local solo=BuiltinConditions.negate({type='GROUP'})
local unshielded=BuiltinConditions.negate({type='DEBUFF',unit='player',spell=6788})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.priest.dps',revision=6,
 blocks={['forever.priest.dps-boundaries']=2,['forever.priest.upkeep']=1,['forever.priest.dps-upkeep']=2,['forever.priest.wand']=2},
 applicability={families={'forever'},actionContext='player',class='PRIEST'},
 tags={'shadow','leveling','single-target','icy-veins','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow-forever/shadow-priest-leveling',title='Icy Veins: Forever Shadow Priest leveling',reviewedAt='2026-10-23',revision='2026-10-17'},
  {url='https://www.icy-veins.com/wow-forever/shadow-priest-ranged-dps-pve-guide',title='Icy Veins: Forever Shadow Priest PvE',reviewedAt='2026-10-23',revision='2026-10-17'},
  {url='https://www.wowhead.com/forever/guide/classes/priest/shadow/level-30-dps-overview',title='Wowhead: Forever level 30 Shadow Priest',reviewedAt='2026-10-23',revision='2026-10-13'},
  {url='https://www.icy-veins.com/wow-forever/discipline-priest-leveling',title='Icy Veins: Forever Discipline Priest leveling',reviewedAt='2026-10-23',revision='2026-10-16',notes='Holy Fire into Penance.'},
  {url='https://www.icy-veins.com/wow-forever/holy-priest-leveling',title='Icy Veins: Forever Holy Priest leveling',reviewedAt='2026-10-23',revision='2026-10-16',notes='Holy Nova on Searing Light procs.'},
  {url='https://mobalytics.gg/wow-forever/classes/priest-leveling-guide-1-60',title='Mobalytics: Forever Priest leveling 1–60',reviewedAt='2026-10-23',revision='2026-10-07',notes='Shadowform (40+) Mind Blast and Mind Flay play only.'},
  {url='https://worldofwarcraft.com/en-us/news/24301514',title='Blizzard: Forever class deep dive, Priest and Warrior',reviewedAt='2026-10-23',revision='2026-09-30',notes='Shadowform rework, baseline spells; no priority.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/priest.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks and cooldowns only.'},
 },
 body={priority=10,
  cooldowns={
   BuiltinConditions.block('dps-upkeep','forever.priest.upkeep','dps-'),
   BuiltinConditions.block('dps-reminders','forever.priest.dps-upkeep','dps-'),
  },
  rotation={
   BuiltinConditions.block('dps-boundaries','forever.priest.dps-boundaries','dps-'),
   BuiltinConditions.spell('dps-shadowform',15473,BuiltinConditions.negate(shadowform)),
   {id='dps-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell('dps-pull-shield',17,BuiltinConditions.all(solo,unshielded)),
    BuiltinConditions.spell('dps-pull-holy-fire',14914,BuiltinConditions.negate(known(15473))),
    BuiltinConditions.spell('dps-pull-mind-blast',8092),
    BuiltinConditions.spell('dps-pull-smite',585),
    BuiltinConditions.stop('dps-pull-stop')}},
   {id='dps-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    BuiltinConditions.spell('dps-moving-pain',589,BuiltinConditions.negate(own(589))),
    BuiltinConditions.spell('dps-moving-plague',2944,BuiltinConditions.negate(own(2944))),
    BuiltinConditions.stop('dps-moving-stop')}},
   BuiltinConditions.spell('dps-holy-fire',14914,BuiltinConditions.all(known(402174,1240720,1240721,1316995),BuiltinConditions.negate(own(14914)))),
   BuiltinConditions.spell('dps-penance',402174,BuiltinConditions.any(own(14914),BuiltinConditions.negate(known(14914)))),
   BuiltinConditions.spell('dps-mind-blast',8092),
   BuiltinConditions.spell('dps-pain',589,BuiltinConditions.negate(own(589))),
   BuiltinConditions.spell('dps-plague',2944,BuiltinConditions.negate(own(2944))),
   {id='dps-shadow',type='branch',conditions=shadowform,onFalse={},onTrue={BuiltinConditions.spell('dps-shadow-flay',15407),BuiltinConditions.stop('dps-shadow-stop')}},
   {id='dps-solo',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
    BuiltinConditions.spell('dps-holy-nova',15237,BuiltinConditions.all({type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=3},
     {type='BUFF',unit='player',spell=1284536})),
    BuiltinConditions.block('dps-solo-wand','forever.priest.wand','dps-solo-'),
    BuiltinConditions.spell('dps-solo-smite',585),
    BuiltinConditions.stop('dps-solo-stop')}},
   BuiltinConditions.spell('dps-flay',15407),
   BuiltinConditions.spell('dps-smite',585),
   BuiltinConditions.block('dps-wand','forever.priest.wand','dps-'),
   BuiltinConditions.stop('dps-done'),
  },
 },
}))
