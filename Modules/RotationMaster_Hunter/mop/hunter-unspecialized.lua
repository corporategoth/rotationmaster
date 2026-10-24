-- Mists of Pandaria Classic Hunter before a specialization: levels 1–9, and any Hunter with no
-- specialization chosen (Warcraft Tavern's leveling list). The lowest priority, so the Beast
-- Mastery, Marksmanship and Survival premades take over as soon as a specialization is
-- chosen. Hunter's Mark and Arcane Shot to pull; Serpent Sting, Multi-Shot on three or more,
-- Arcane Shot, Steady Shot, Auto Shot.
local _,addon=...
local function negate(c)return{type='NOT',value=c}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local idle=negate({type='SPELL_AUTOREPEAT',spell=75,ranked=true})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.hunter.unspecialized',revision=3,
 blocks={['mop.hunter.boundaries']=2,['mop.hunter.mark']=1,['mop.hunter.pet']=1,['mop.hunter.aspect']=1,['mop.hunter.serpent']=1},
 nameKey='Default.MoP.Hunter.Unspecialized.Name',descriptionKey='Default.MoP.Hunter.Unspecialized.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='HUNTER'},
 tags={'leveling','single-target'},
 sources={
  {url='https://www.warcrafttavern.com/mop/guides/hunter-leveling-guide/',title='Warcraft Tavern: MoP Hunter leveling guide',reviewedAt='2026-10-23'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/beast-mastery-hunter-leveling',title='Icy Veins: MoP Classic Beast Mastery Hunter leveling',reviewedAt='2026-10-23',revision='2026-05-29',notes='The specialization rotation from level 10.'},
 },
 body={priority=1,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('hunter-pet','mop.hunter.pet','hunter-'),
   block('hunter-aspect','mop.hunter.aspect','hunter-'),
  },
  rotation={
   block('hunter-boundaries','mop.hunter.boundaries','hunter-'),
   {id='hunter-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    block('hunter-pull-mark','mop.hunter.mark','hunter-pull-'),
    spell('hunter-pull-arcane',3044),
    {id='hunter-pull-auto-shot',type='spell',action=75,ranked=true,conditions=idle},
    stop('hunter-pull-stop')}},
   block('hunter-serpent','mop.hunter.serpent','hunter-'),
   spell('hunter-multi-shot',2643,{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3}),
   spell('hunter-arcane',3044),
   spell('hunter-steady',56641),
   {id='hunter-auto-shot',type='spell',action=75,ranked=true,conditions=idle},
   stop('hunter-wait'),
  },
 },
}))
