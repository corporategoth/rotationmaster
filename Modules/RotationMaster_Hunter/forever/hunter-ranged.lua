-- WoW Forever ranged Hunter (Beast Mastery, Marksmanship, and Survival before Strider Kick),
-- levels 1–60; the Hunter catch-all (lowest priority). Wowhead's level-30 Hawk cycle: Hunter's Mark,
-- own Serpent Sting, Summon Hawk, Summon Hawk, Arcane Shot on their shared cooldown, Aimed Shot
-- (Multi-Shot on two or more enemies, as they share a cooldown). Sniper Shot while Rapid Killing
-- lasts or on elites; Explosive Trap and Volley on packs. Uses no mana reading: Forever is
-- reported to hide the player's mana in combat. Pet commands stay with the player.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function enemies(n)return{type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=n}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local elite=any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
local arcaneTurn=all({type='SPELL_HISTORY_TIME',spell=1293241,operator='LESSTHAN',value=7},
 negate({type='SPELL_HISTORY_TIME',spell=3044,operator='LESSTHAN',value=17}))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.hunter.ranged',revision=1,
 blocks={['forever.hunter.boundaries']=1,['forever.hunter.deadzone']=1,['forever.hunter.pull']=1,['forever.hunter.moving']=1,
  ['forever.hunter.aspects-ranged']=1,['forever.hunter.pet-care']=1,['forever.hunter.burst']=1},
 nameKey='Default.Forever.Hunter.Ranged.Name',descriptionKey='Default.Forever.Hunter.Ranged.Description',
 applicability={families={'forever'},actionContext='player',class='HUNTER',minLevel=1,maxLevel=60},
 tags={'beast-mastery','marksmanship','ranged','leveling','single-target','aoe','wowhead'},
 sources={
  {url='https://www.wowhead.com/forever/guide/classes/hunter/beast-mastery/level-30-dps-overview',title='Wowhead: Forever level 30 Beast Mastery Hunter',reviewedAt='2026-10-23',revision='2026-10-11'},
  {url='https://www.wowhead.com/forever/guide/classes/hunter/marksmanship/level-30-dps-overview',title='Wowhead: Forever level 30 Marksmanship Hunter',reviewedAt='2026-10-23',revision='2026-10-11'},
  {url='https://www.icy-veins.com/wow-forever/beast-mastery-hunter-ranged-dps-pve-guide',title='Icy Veins: Forever Beast Mastery Hunter PvE',reviewedAt='2026-10-23',revision='2026-10-17',notes='Explosive Trap, Volley and elite-only cooldowns.'},
  {url='https://www.icy-veins.com/wow-forever/marksmanship-hunter-leveling',title='Icy Veins: Forever Marksmanship Hunter leveling',reviewedAt='2026-10-23',revision='2026-10-17',notes='Sniper Shot under Rapid Killing.'},
  {url='https://worldofwarcraft.blizzard.com/en-us/news/24301515',title='Blizzard: Forever class deep dive, Hunter and Druid',reviewedAt='2026-10-23',revision='2026-09-30',notes='Shared cooldowns and talents; no priority.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/hunter.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks and cooldown categories only.'},
 },
 body={priority=10,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('ranged-aspects','forever.hunter.aspects-ranged','ranged-'),
   spell('ranged-trueshot-aura',1299346,negate({type='BUFF',unit='player',spell=1299346,anyrank=true})),
   block('ranged-pet-care','forever.hunter.pet-care','ranged-'),
   block('ranged-burst','forever.hunter.burst','ranged-'),
   spell('ranged-intimidation',19577,all(combat(),{type='ISSAME',unit='targettarget',otherunit='player'})),
   {id='ranged-feign-death',type='spell',action=5384,ranked=false,disabled=true,conditions=all(combat(),{type='GROUP'},{type='ISSAME',unit='targettarget',otherunit='player'})},
  },
  rotation={
   stop('ranged-target',negate({type='ATTACKABLE',unit='target'})),
   block('ranged-boundaries','forever.hunter.boundaries','ranged-'),
   block('ranged-deadzone','forever.hunter.deadzone','ranged-'),
   block('ranged-pull','forever.hunter.pull','ranged-'),
   -- Optional (off): solo, hold shots until the pet has the mob's attention.
   {id='ranged-pet-threat',type='none',suppress_attack=true,disabled=true,conditions=all({type='PET'},negate({type='GROUP'}),
    negate({type='ISSAME',unit='targettarget',otherunit='pet'}),{type='TIME_IN_COMBAT',operator='LESSTHAN',value=2})},
   block('ranged-moving','forever.hunter.moving','ranged-'),
   spell('ranged-auto-shot',75,negate({type='SPELL_AUTOREPEAT',spell=75,ranked=true})),
   spell('ranged-mark',1130,all(negate({type='DEBUFF',unit='target',spell=1130,anyrank=true}),any(elite,{type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.5}))),
   {id='ranged-aoe',type='branch',conditions=engaged(2),onFalse={},onTrue={
    spell('ranged-explosive-trap',13813,enemies(3)),
    spell('ranged-aoe-hawk',1293241,negate(arcaneTurn)),
    spell('ranged-multi-shot',2643),
    spell('ranged-volley',1510,engaged(5))}},
   spell('ranged-serpent-sting',1978,all(negate({type='DEBUFF',unit='target',spell=1978,anyrank=true,owndebuff=true}),
    negate({type='DEBUFF',unit='target',spell=3043,anyrank=true,owndebuff=true}),{type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.3})),
   spell('ranged-hawk',1293241,negate(arcaneTurn)),
   spell('ranged-arcane-shot',3044,any(negate({type='SPELL_KNOWN',spell=1293241}),arcaneTurn)),
   spell('ranged-sniper-shot',1310687,any({type='BUFF',unit='player',spell=415407},elite)),
   spell('ranged-aimed-shot',19434),
   stop('ranged-done'),
  },
 },
}))
