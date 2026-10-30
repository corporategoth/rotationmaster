-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Priest before a specialization (levels 1-9, or a priest who has not chosen one yet):
-- the catch-all, lowest priority, so it applies only when no specialization switch
-- matches. A friendly target gets Flash Heal when low or a Power Word: Shield; an enemy gets Shadow Word: Pain when
-- it will live, then Smite. Reminders: Inner Fire, and a shield on yourself when solo and hurt. RM policy built
-- from the 1-9 kit (Smite 1, Shadow Word: Pain 3, Power Word: Shield 5, Flash Heal 7, Inner Fire 9).
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function health(unit,op,n)return{type='HEALTHPCT',unit=unit,operator=op,value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.priest.unspecialized',revision=5,
 blocks={['mop.priest.upkeep']=1,['mop.priest.healer-boundaries']=2},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='PRIEST'},
 tags={'dps','caster','leveling','icy-veins'},
 sources={{url='https://www.icy-veins.com/mists-of-pandaria-classic/shadow-priest-leveling',title='Icy Veins: Shadow Priest leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/discipline-priest-leveling',title='Icy Veins: Discipline Priest leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'}},
 body={priority=1,
 cooldowns={block('mop.priest.upkeep','priest-'),
  BuiltinConditions.spell('priest-starter-self-shield',17,BuiltinConditions.all({type='COMBAT',unit='player'},BuiltinConditions.negate({type='GROUP'}),health('player','LESSTHAN',.7),
   BuiltinConditions.negate({type='DEBUFF',unit='player',spell=6788}))),
 },
 rotation={
 block('mop.priest.healer-boundaries','priest-starter-'),
 {id='priest-starter-heal',type='branch',conditions=BuiltinConditions.all({type='FRIENDLY',unit='target'},BuiltinConditions.negate({type='DEAD',unit='target'})),onFalse={},onTrue={
  BuiltinConditions.spell('priest-starter-flash',2061,health('target','LESSTHAN',.6)),
  BuiltinConditions.spell('priest-starter-shield',17,BuiltinConditions.all(health('target','LESSTHAN',.8),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=6788}))),
  BuiltinConditions.stop('priest-starter-heal-stop'),
 }},
 BuiltinConditions.stop('priest-starter-no-enemy',BuiltinConditions.negate({type='ATTACKABLE',unit='target'})),
 BuiltinConditions.spell('priest-starter-pain',589,BuiltinConditions.all(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=589,owndebuff=true}),
  BuiltinConditions.any(health('target','GREATERTHANOREQUALS',.35),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=6}))),
 BuiltinConditions.spell('priest-starter-smite',585),
 BuiltinConditions.stop('priest-starter-end'),
 }},
}))
