-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Priest before a specialization (levels 1-9, or a priest who has not chosen one yet):
-- the catch-all, lowest priority, so it applies only when no specialization switch
-- matches. A friendly target gets Flash Heal when low or a Power Word: Shield; an enemy gets Shadow Word: Pain when
-- it will live, then Smite. Reminders: Inner Fire, and a shield on yourself when solo and hurt. RM policy built
-- from the 1-9 kit (Smite 1, Shadow Word: Pain 3, Power Word: Shield 5, Flash Heal 7, Inner Fire 9).
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function health(unit,op,n)return{type='HEALTHPCT',unit=unit,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.priest.unspecialized',revision=5,
 blocks={['mop.priest.upkeep']=1,['mop.priest.healer-boundaries']=2},
 nameKey="Unspecialized",descriptionKey="For levels 1 to 9, or any priest who has not chosen a specialization yet. On an enemy: Shadow Word: Pain when it will live long enough, then Smite. On a friend: Flash Heal when they are low, otherwise Power Word: Shield. Reminders: Inner Fire, and a shield on yourself when you are solo and hurt. Choosing a specialization at 10 switches to its own premade.",
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='PRIEST'},
 tags={'dps','caster','leveling','icy-veins'},
 sources={{url='https://www.icy-veins.com/mists-of-pandaria-classic/shadow-priest-leveling',title='Icy Veins: Shadow Priest leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/discipline-priest-leveling',title='Icy Veins: Discipline Priest leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'}},
 body={priority=1,
 cooldowns={block('mop.priest.upkeep','priest-'),
  spell('priest-starter-self-shield',17,all({type='COMBAT',unit='player'},negate({type='GROUP'}),health('player','LESSTHAN',.7),
   negate({type='DEBUFF',unit='player',spell=6788}))),
 },
 rotation={
 block('mop.priest.healer-boundaries','priest-starter-'),
 {id='priest-starter-heal',type='branch',conditions=all({type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'})),onFalse={},onTrue={
  spell('priest-starter-flash',2061,health('target','LESSTHAN',.6)),
  spell('priest-starter-shield',17,all(health('target','LESSTHAN',.8),negate({type='DEBUFF',unit='target',spell=6788}))),
  stop('priest-starter-heal-stop'),
 }},
 stop('priest-starter-no-enemy',negate({type='ATTACKABLE',unit='target'})),
 spell('priest-starter-pain',589,all(negate({type='DEBUFF',unit='target',spell=589,owndebuff=true}),
  any(health('target','GREATERTHANOREQUALS',.35),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=6}))),
 spell('priest-starter-smite',585),
 stop('priest-starter-end'),
 }},
}))
