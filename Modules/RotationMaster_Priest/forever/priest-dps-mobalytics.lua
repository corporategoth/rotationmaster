-- WoW Forever damage Priest after Mobalytics' DoT-and-wand leveling style, levels 1–60: a
-- player-chosen alternative to rm.forever.priest.dps (same switch, lower priority). Before
-- Shadowform: Mind Blast and Holy Fire only on tough mobs (elite, or two levels above you), own
-- Shadow Word: Pain and Devouring Plague on a target that will live, then the wand; Shield and
-- Renew on yourself between pulls. From Shadowform (40): Mind Blast, Pain, Plague, Mind Flay.
-- Spreading Pain across several mobs (tabbing) stays with the player.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function mine(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function health(unit,op,v)return{type='HEALTHPCT',unit=unit,operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function off(id,action,conditions)local step=spell(id,action,conditions);step.disabled=true;return step end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local shadowform={type='BUFF',unit='player',spell=15473}
local solo=negate({type='GROUP'})
local unshielded=negate({type='DEBUFF',unit='player',spell=6788})
local tough=any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},
 {type='CLASSIFICATION',unit='target',value='worldboss'},{type='LEVEL',unit='target',operator='GREATERTHANOREQUALS',value=2,relative=true})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.priest.dps.mobalytics',revision=1,
 blocks={['forever.priest.boundaries']=1,['forever.priest.upkeep']=1,['forever.priest.dps-upkeep']=1,['forever.priest.wand']=1},
 nameKey='Default.Forever.Priest.DpsMobalytics.Name',descriptionKey='Default.Forever.Priest.DpsMobalytics.Description',
 applicability={families={'forever'},actionContext='player',class='PRIEST',minLevel=1,maxLevel=60},
 tags={'shadow','leveling','dot','wand','mobalytics'},
 sources={
  {url='https://mobalytics.gg/wow-forever/classes/priest-leveling-guide-1-60',title='Mobalytics: Forever Priest leveling 1–60',reviewedAt='2026-10-23',revision='2026-10-07'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/priest.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks and cooldowns only.'},
 },
 body={priority=5,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('dot-upkeep','forever.priest.upkeep','dot-'),
   block('dot-reminders','forever.priest.dps-upkeep','dot-'),
   spell('dot-prepull-shield',17,all(negate({type='COMBAT',unit='player'}),unshielded,{type='MANAPCT',unit='player',operator='GREATERTHAN',value=.5})),
   spell('dot-prepull-renew',139,all(negate({type='COMBAT',unit='player'}),negate(mine(139)),{type='MANAPCT',unit='player',operator='GREATERTHAN',value=.5})),
   spell('dot-cure-disease',528,{type='DISPELLABLE',unit='player',debufftype='Disease'}),
  },
  rotation={
   block('dot-boundaries','forever.priest.boundaries','dot-'),
   stop('dot-target',negate({type='ATTACKABLE',unit='target'})),
   spell('dot-shadowform',15473,negate(shadowform)),
   {id='dot-emergency',type='branch',conditions=all(solo,health('player','LESSTHAN',.35)),onFalse={},onTrue={
    spell('dot-emergency-shield',17,unshielded),
    spell('dot-emergency-renew',139,negate(mine(139))),
    off('dot-emergency-scream',8122),
    {id='dot-emergency-heal',type='branch',conditions=negate(shadowform),onFalse={},onTrue={
     spell('dot-heal',2054),spell('dot-lesser-heal',2050)}},
    stop('dot-emergency-stop')}},
   {id='dot-pull',type='branch',conditions=negate({type='COMBAT',unit='player'}),onFalse={},onTrue={
    spell('dot-pull-holy-fire',14914,all(tough,negate(known(15473)))),
    spell('dot-pull-mind-blast',8092,tough),
    spell('dot-pull-pain',589,negate(own(589))),
    spell('dot-pull-smite',585,negate(known(589))),
    stop('dot-pull-stop')}},
   {id='dot-shadow',type='branch',conditions=shadowform,onFalse={},onTrue={
    spell('dot-shadow-blast',8092),
    spell('dot-shadow-pain',589,negate(own(589))),
    spell('dot-shadow-plague',2944,all(negate(own(2944)),health('target','GREATERTHAN',.5))),
    spell('dot-shadow-flay',15407),
    stop('dot-shadow-stop')}},
   spell('dot-pain',589,negate(own(589))),
   spell('dot-plague',2944,all(negate(own(2944)),health('target','GREATERTHAN',.5))),
   block('dot-wand','forever.priest.wand','dot-'),
   spell('dot-smite',585),
   stop('dot-done'),
  },
 },
}))
