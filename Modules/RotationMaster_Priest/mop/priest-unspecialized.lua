-- Mists of Pandaria Classic Priest before a specialization (levels 1-9, or a priest who has not chosen one yet):
-- the catch-all, lowest priority, so it applies only when none of Mind Flay, Penance or Holy Word: Chastise is
-- known. A friendly target gets Flash Heal when low or a Power Word: Shield; an enemy gets Shadow Word: Pain when
-- it will live, then Smite. Reminders: Inner Fire, and a shield on yourself when solo and hurt. RM policy built
-- from the 1-9 kit (Smite 1, Shadow Word: Pain 3, Power Word: Shield 5, Flash Heal 7, Inner Fire 9).
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function health(unit,op,n)return{type='HEALTHPCT',unit=unit,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.priest.unspecialized',revision=1,
 blocks={['mop.priest.upkeep']=1,['mop.priest.healer-boundaries']=1},
 nameKey='Default.MoP.Priest.Unspecialized.Name',descriptionKey='Default.MoP.Priest.Unspecialized.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='PRIEST',minLevel=1,maxLevel=90},
 tags={'dps','caster','leveling','icy-veins'},
 sources={{url='https://www.icy-veins.com/mists-of-pandaria-classic/shadow-priest-leveling',title='Icy Veins: Shadow Priest levelling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/discipline-priest-leveling',title='Icy Veins: Discipline Priest levelling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'}},
 body={priority=1,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
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
