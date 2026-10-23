-- WoW Forever damage Priest, levels 1–60, and the Priest catch-all (lowest priority): Shadow, and
-- every Priest's solo play (Smite, Holy and Discipline levelers too). Icy Veins' and Wowhead's
-- order with Mobalytics' level-40 Shadowform play: Shield and Mind Blast (Holy Fire for Holy and
-- Discipline) to pull, own Shadow Word: Pain and Devouring Plague, Mind Blast while it is worth it,
-- Shadow Word: Death to execute, then the wand while leveling solo, Mind Flay in Shadowform or a
-- group. Discipline adds Holy Fire into Penance. A solo emergency branch shields and heals.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function known(...)local list={};for i,id in ipairs({...})do list[i]={type='SPELL_KNOWN',spell=id}end;return{type='OR',value=list}end
local function health(unit,op,v)return{type='HEALTHPCT',unit=unit,operator=op,value=v}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local shadowform={type='BUFF',unit='player',spell=15473}
local solo=negate({type='GROUP'})
local unshielded=negate({type='DEBUFF',unit='player',spell=6788})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.priest.dps',revision=2,
 blocks={['forever.priest.boundaries']=1,['forever.priest.upkeep']=1,['forever.priest.dps-upkeep']=1,['forever.priest.wand']=1},
 nameKey='Default.Forever.Priest.Dps.Name',descriptionKey='Default.Forever.Priest.Dps.Description',
 applicability={families={'forever'},actionContext='player',class='PRIEST',minLevel=1,maxLevel=60},
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
 body={priority=10,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('dps-upkeep','forever.priest.upkeep','dps-'),
   block('dps-reminders','forever.priest.dps-upkeep','dps-'),
  },
  rotation={
   block('dps-boundaries','forever.priest.boundaries','dps-'),
   stop('dps-target',negate({type='ATTACKABLE',unit='target'})),
   spell('dps-shadowform',15473,negate(shadowform)),
   {id='dps-emergency',type='branch',conditions=all(solo,health('player','LESSTHAN',.35)),onFalse={},onTrue={
    spell('dps-emergency-shield',17,unshielded),
    spell('dps-desperate-prayer',13908),
    {id='dps-emergency-heal',type='branch',conditions=shadowform,onTrue={},onFalse={
     spell('dps-flash-heal',2061),spell('dps-heal',2054),spell('dps-lesser-heal',2050)}},
    stop('dps-emergency-stop')}},
   {id='dps-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell('dps-pull-shield',17,all(solo,unshielded)),
    spell('dps-pull-holy-fire',14914,negate(known(15473))),
    spell('dps-pull-mind-blast',8092),
    spell('dps-pull-smite',585),
    stop('dps-pull-stop')}},
   {id='dps-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    spell('dps-moving-pain',589,negate(own(589))),
    spell('dps-moving-plague',2944,negate(own(2944))),
    spell('dps-moving-death',1309595,health('target','LESSTHAN',.2)),
    stop('dps-moving-stop')}},
   {id='dps-execute',type='branch',conditions=health('target','LESSTHAN',.2),onFalse={},onTrue={
    spell('dps-death',1309595,health('player','GREATERTHAN',.3)),
    {id='dps-finish',type='branch',conditions=all(solo,negate(shadowform)),onFalse={},onTrue={
     block('dps-finish-wand','forever.priest.wand','dps-finish-'),stop('dps-finish-stop')}}}},
   spell('dps-holy-fire',14914,all(known(402174,1240720,1240721,1316995),negate(own(14914)))),
   spell('dps-penance',402174,any(own(14914),negate(known(14914)))),
   spell('dps-mind-blast',8092,any(shadowform,{type='GROUP'},health('target','GREATERTHAN',.5))),
   spell('dps-pain',589,negate(own(589))),
   spell('dps-plague',2944,all(negate(own(2944)),health('target','GREATERTHAN',.4),any(shadowform,mana('GREATERTHANOREQUALS',.4)))),
   {id='dps-shadow',type='branch',conditions=shadowform,onFalse={},onTrue={spell('dps-shadow-flay',15407),stop('dps-shadow-stop')}},
   {id='dps-solo',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
    spell('dps-holy-nova',15237,all({type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=3},
     any({type='BUFF',unit='player',spell=1284536},mana('GREATERTHAN',.6)))),
    spell('dps-solo-flay',15407,mana('GREATERTHAN',.6)),
    block('dps-solo-wand','forever.priest.wand','dps-solo-'),
    spell('dps-solo-smite',585),
    stop('dps-solo-stop')}},
   spell('dps-flay',15407),
   spell('dps-smite',585),
   block('dps-wand','forever.priest.wand','dps-'),
   stop('dps-done'),
  },
 },
}))
