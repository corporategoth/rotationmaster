-- WoW Forever Survival Hunter, two-hander in-and-out weave (Wowhead's alternative), levels 10–60:
-- a player-chosen alternative to rm.forever.hunter.survival (same switch, lower priority; RM cannot
-- tell a two-hander). In melee: Mongoose Bite and Raptor Strike; with Raptor Strike far from ready,
-- Strider Kick and step out. Out of melee: shoot until Raptor Strike is nearly ready, then go back
-- in. RM follows the range you choose; it cannot tell you to move.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions,attack)return{id=id,type='none',suppress_attack=not attack,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function raptor(op,v)return{type='SPELL_COOLDOWN',spell=2973,operator=op,value=v}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.hunter.survival.weave',revision=1,
 blocks={['forever.hunter.boundaries']=1,['forever.hunter.survival-pull']=1,['forever.hunter.range-shots']=1,['forever.hunter.melee-aoe']=1,
  ['forever.hunter.pet-care']=1,['forever.hunter.burst']=1},
 nameKey='Default.Forever.Hunter.SurvivalWeave.Name',descriptionKey='Default.Forever.Hunter.SurvivalWeave.Description',
 applicability={families={'forever'},actionContext='player',class='HUNTER',minLevel=10,maxLevel=60},
 tags={'survival','melee','two-hander','weave','wowhead'},
 sources={
  {url='https://www.wowhead.com/forever/guide/classes/hunter/survival/level-30-dps-overview',title='Wowhead: Forever level 30 Survival Hunter (two-hand weave)',reviewedAt='2026-10-23',revision='2026-10-11'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/hunter.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks and cooldowns only.'},
 },
 body={priority=15,switch={type='SPELL_KNOWN',spell=1317257},
  cooldowns={
   spell('weave-aspect-beast',13161,all(combat(),negate({type='BUFF',unit='player',spell=13161,anyrank=true,ownbuff=true}))),
   spell('weave-mark',1130,all(combat(),{type='ATTACKABLE',unit='target'},negate({type='DEBUFF',unit='target',spell=1130,anyrank=true}))),
   block('weave-burst','forever.hunter.burst','weave-'),
   block('weave-pet-care','forever.hunter.pet-care','weave-'),
  },
  rotation={
   stop('weave-target',negate({type='ATTACKABLE',unit='target'})),
   block('weave-boundaries','forever.hunter.boundaries','weave-'),
   block('weave-pull','forever.hunter.survival-pull','weave-'),
   {id='weave-range',type='branch',conditions={type='BEYOND_MELEE',unit='target'},onFalse={},onTrue={
    stop('weave-return',raptor('LESSTHAN',1),true),
    block('weave-range-shots','forever.hunter.range-shots','weave-range-'),stop('weave-range-stop')}},
   block('weave-aoe','forever.hunter.melee-aoe','weave-'),
   spell('weave-mongoose-bite',1495),
   spell('weave-raptor-strike',2973,negate({type='SPELL_ACTIVE',spell=2973})),
   -- Mongoose Bite was not usable above; with Raptor Strike far off, kick and step out.
   {id='weave-exit',type='branch',conditions=raptor('GREATERTHAN',2.5),onFalse={},onTrue={
    spell('weave-strider-kick',1317257),stop('weave-exit-stop',nil,true)}},
   spell('weave-counterattack',19306),
   stop('weave-done',nil,true),
  },
 },
}))
