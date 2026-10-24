-- WoW Forever Survival Hunter in melee (dual-wield), levels 10–60, once Survival is the main tree
-- with 21 points (Strider Kick's tier); until then Survival levels with the ranged premade, as every
-- source advises. Wowhead's level-30 order: Mongoose Bite, Strider Kick, Raptor Strike,
-- Counterattack, with Explosive Trap on packs. Out of melee it shoots (own Serpent Sting, Arcane,
-- Aimed, Auto Shot). Aspect of the Beast and Hunter's Mark (Expose Prey needs it) are reminders.
local _,addon=...
-- Talent trees in the Forever talent window's order (assumed classic: 1 Beast Mastery, 2 Marksmanship, 3 Survival; verify in game).
-- Level 10 first (no talent config below it), then the points (an empty tree is a clean no-match),
-- then the primary tree, which settles hybrids.
local function tree(n,points)return{type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 {type='TALENT_TREE_POINTS',tree=n,operator='GREATERTHANOREQUALS',value=points},{type='PRIMARY_TALENT_TREE',tree=n}}}end
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions,attack)return{id=id,type='none',suppress_attack=not attack,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local elite=any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.hunter.survival',revision=4,
 blocks={['forever.hunter.boundaries']=1,['forever.hunter.survival-pull']=2,['forever.hunter.range-shots']=1,['forever.hunter.melee-aoe']=1,
  ['forever.hunter.pet-care']=2,['forever.hunter.burst']=1},
 nameKey='Default.Forever.Hunter.Survival.Name',descriptionKey='Default.Forever.Hunter.Survival.Description',
 applicability={families={'forever'},actionContext='player',class='HUNTER',minLevel=10,maxLevel=60},
 tags={'survival','melee','leveling','wowhead'},
 sources={
  {url='https://www.wowhead.com/forever/guide/classes/hunter/survival/level-30-dps-overview',title='Wowhead: Forever level 30 Survival Hunter',reviewedAt='2026-10-23',revision='2026-10-11'},
  {url='https://www.wowhead.com/forever/guide/classes/hunter/survival/dps-abilities',title='Wowhead: Forever Survival Hunter abilities',reviewedAt='2026-10-23',revision='2026-10-08'},
  {url='https://www.icy-veins.com/wow-forever/survival-hunter-melee-dps-pve-guide',title='Icy Veins: Forever Survival Hunter PvE',reviewedAt='2026-10-23',revision='2026-10-05',notes='Traps on packs; Survival plays ranged until talented.'},
  {url='https://worldofwarcraft.blizzard.com/en-us/news/24301515',title='Blizzard: Forever class deep dive, Hunter and Druid',reviewedAt='2026-10-23',revision='2026-09-30',notes='Aspect of the Beast, Strider Kick, Expose Prey; no priority.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/hunter.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks and cooldowns only.'},
 },
 body={priority=20,switch=tree(3,21),
  cooldowns={
   spell('sv-aspect-beast',13161,all(combat(),negate({type='BUFF',unit='player',spell=13161,anyrank=true,ownbuff=true}))),
   spell('sv-mark',1130,all(combat(),{type='ATTACKABLE',unit='target'},negate({type='DEBUFF',unit='target',spell=1130,anyrank=true}))),
   block('sv-burst','forever.hunter.burst','sv-'),
   spell('sv-deterrence',19263,all(combat(),{type='THREAT',unit='target',threat=3})),
   block('sv-pet-care','forever.hunter.pet-care','sv-'),
  },
  rotation={
   stop('sv-target',negate({type='ATTACKABLE',unit='target'})),
   block('sv-boundaries','forever.hunter.boundaries','sv-'),
   block('sv-pull','forever.hunter.survival-pull','sv-'),
   {id='sv-range',type='branch',conditions={type='BEYOND_MELEE',unit='target'},onFalse={},onTrue={
    block('sv-range-shots','forever.hunter.range-shots','sv-range-'),stop('sv-range-stop')}},
   block('sv-aoe','forever.hunter.melee-aoe','sv-'),
   spell('sv-mongoose-bite',1495),
   spell('sv-strider-kick',1317257),
   spell('sv-raptor-strike',2973,negate({type='SPELL_ACTIVE',spell=2973})),
   spell('sv-counterattack',19306),
   {id='sv-immolation-trap',type='spell',action=13795,ranked=false,disabled=true,conditions=elite},
   stop('sv-done',nil,true),
  },
 },
}))
