-- WoW Forever ranged Hunter, mana-saving (Mobalytics; also the form of Icy Veins' advice that RM
-- can express without reading mana), levels 1–60: a player-chosen alternative to
-- rm.forever.hunter.ranged (same switch, lower priority, off by default). Keeps one Hawk up, Aimed
-- Shot (Multi-Shot on packs), and no Arcane Shot once Summon Hawk is known; its second Hawk on a
-- healthy target is left out, as target health is secret on Forever.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.hunter.ranged.mobalytics',revision=4,
 blocks={['forever.hunter.boundaries']=3,['forever.hunter.deadzone']=2,['forever.hunter.pull']=2,['forever.hunter.moving']=1,
  ['forever.hunter.aspects-ranged']=1,['forever.hunter.pet-care']=2,['forever.hunter.burst']=1},
 nameKey='Default.Forever.Hunter.RangedMobalytics.Name',descriptionKey='Default.Forever.Hunter.RangedMobalytics.Description',
 applicability={families={'forever'},actionContext='player',class='HUNTER'},
 tags={'beast-mastery','marksmanship','ranged','leveling','mana-saving','mobalytics'},
 sources={
  {url='https://mobalytics.gg/wow-forever/classes/hunter-leveling-guide',title='Mobalytics: Forever Hunter leveling 1–30',reviewedAt='2026-10-23',revision='2026-10-18'},
  {url='https://mobalytics.gg/wow-forever/classes/marksmanship-hunter-guide',title='Mobalytics: Forever Marksmanship Hunter',reviewedAt='2026-10-23',revision='2026-10-18'},
  {url='https://www.icy-veins.com/wow-forever/beast-mastery-hunter-leveling',title='Icy Veins: Forever Beast Mastery Hunter leveling',reviewedAt='2026-10-23',revision='2026-10-17',notes='Arcane Shot only when mana-capped, which RM cannot read in Forever combat.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/hunter.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks and cooldown categories only.'},
 },
 body={priority=5,disabled=true,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('saver-aspects','forever.hunter.aspects-ranged','saver-'),
   spell('saver-trueshot-aura',1299346,negate({type='BUFF',unit='player',spell=1299346,anyrank=true})),
   block('saver-pet-care','forever.hunter.pet-care','saver-'),
   block('saver-burst','forever.hunter.burst','saver-'),
   spell('saver-intimidation',19577,all({type='COMBAT',unit='player'},{type='THREAT',unit='target',threat=3})),
  },
  rotation={
   block('saver-boundaries','forever.hunter.boundaries','saver-'),
   block('saver-deadzone','forever.hunter.deadzone','saver-'),
   block('saver-pull','forever.hunter.pull','saver-'),
   block('saver-moving','forever.hunter.moving','saver-'),
   spell('saver-auto-shot',75,negate({type='SPELL_AUTOREPEAT',spell=75,ranked=true})),
   spell('saver-serpent-sting',1978,all(negate({type='DEBUFF',unit='target',spell=1978,anyrank=true,owndebuff=true}),
    negate({type='DEBUFF',unit='target',spell=3043,anyrank=true,owndebuff=true}))),
   {id='saver-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},onFalse={},onTrue={
    spell('saver-multi-shot',2643)}},
   -- First Hawk: none summoned in the last 18 s (its lifetime).
   spell('saver-first-hawk',1293241,negate({type='SPELL_HISTORY_TIME',spell=1293241,operator='LESSTHAN',value=18})),
   spell('saver-aimed-shot',19434),
   spell('saver-arcane-shot',3044,negate({type='SPELL_KNOWN',spell=1293241})),
   spell('saver-sniper-shot',1310687,{type='BUFF',unit='player',spell=415407}),
   stop('saver-done'),
  },
 },
}))
