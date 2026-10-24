-- WoW Forever damage Priest after Mobalytics' DoT-and-wand leveling style, levels 1–60: a
-- player-chosen alternative to rm.forever.priest.dps (same switch, lower priority, off by default).
-- Before
-- Shadowform: Mind Blast and Holy Fire only on tough mobs (elite, or two levels above you), own
-- Shadow Word: Pain and Devouring Plague, then the wand; Shield and Renew on yourself between pulls.
-- From Shadowform (40): Mind Blast, Pain, Plague, Mind Flay. Health and mana are secret on Forever,
-- so the emergency heals and the mana and target-health checks are left out.
-- Spreading Pain across several mobs (tabbing) stays with the player.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function mine(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local shadowform={type='BUFF',unit='player',spell=15473}
local unshielded=negate({type='DEBUFF',unit='player',spell=6788})
local tough=any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},
 {type='CLASSIFICATION',unit='target',value='worldboss'},{type='LEVEL',unit='target',operator='GREATERTHANOREQUALS',value=2,relative=true})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.priest.dps.mobalytics',revision=4,
 blocks={['forever.priest.dps-boundaries']=1,['forever.priest.upkeep']=1,['forever.priest.dps-upkeep']=2,['forever.priest.wand']=1},
 nameKey='Default.Forever.Priest.DpsMobalytics.Name',descriptionKey='Default.Forever.Priest.DpsMobalytics.Description',
 applicability={families={'forever'},actionContext='player',class='PRIEST'},
 tags={'shadow','leveling','dot','wand','mobalytics'},
 sources={
  {url='https://mobalytics.gg/wow-forever/classes/priest-leveling-guide-1-60',title='Mobalytics: Forever Priest leveling 1–60',reviewedAt='2026-10-23',revision='2026-10-07'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/priest.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks and cooldowns only.'},
 },
 body={priority=5,disabled=true,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('dot-upkeep','forever.priest.upkeep','dot-'),
   block('dot-reminders','forever.priest.dps-upkeep','dot-'),
   spell('dot-prepull-shield',17,all(negate({type='COMBAT',unit='player'}),unshielded)),
   spell('dot-prepull-renew',139,all(negate({type='COMBAT',unit='player'}),negate(mine(139)))),
   spell('dot-cure-disease',528,{type='DISPELLABLE',unit='player',debufftype='Disease'}),
  },
  rotation={
   block('dot-boundaries','forever.priest.dps-boundaries','dot-'),
   spell('dot-shadowform',15473,negate(shadowform)),
   {id='dot-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell('dot-pull-holy-fire',14914,all(tough,negate(known(15473)))),
    spell('dot-pull-mind-blast',8092,tough),
    spell('dot-pull-pain',589,negate(own(589))),
    spell('dot-pull-smite',585,negate(known(589))),
    stop('dot-pull-stop')}},
   {id='dot-shadow',type='branch',conditions=shadowform,onFalse={},onTrue={
    spell('dot-shadow-blast',8092),
    spell('dot-shadow-pain',589,negate(own(589))),
    spell('dot-shadow-plague',2944,negate(own(2944))),
    spell('dot-shadow-flay',15407),
    stop('dot-shadow-stop')}},
   spell('dot-pain',589,negate(own(589))),
   spell('dot-plague',2944,negate(own(2944))),
   block('dot-wand','forever.priest.wand','dot-'),
   spell('dot-smite',585),
   stop('dot-done'),
  },
 },
}))
