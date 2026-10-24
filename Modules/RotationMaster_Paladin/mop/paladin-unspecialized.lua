-- Mists of Pandaria Classic Paladin before a specialization: levels 1–9, and any paladin who has
-- not chosen one. Lowest priority, so a
-- specialization premade wins as soon as one is chosen. Judgment to pull, Word of Glory and
-- Hammer of Justice when in danger, Crusader Strike, Judgment; the start of Icy Veins' leveling list.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function health(op,v)return{type='HEALTHPCT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.paladin.unspecialized',revision=3,
 blocks={['mop.paladin.damage-boundaries']=1,['mop.paladin.upkeep']=1,['mop.paladin.seal-truth']=2},
 nameKey='Default.MoP.Paladin.Unspecialized.Name',descriptionKey='Default.MoP.Paladin.Unspecialized.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='PALADIN'},
 tags={'leveling','single-target','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/retribution-paladin-leveling',title='Icy Veins: MoP Classic Retribution Paladin leveling',reviewedAt='2026-10-23',revision='2025-09-23',notes='Generators, then Word of Glory when in danger; no guide writes a list for levels 1-9.'},
 },
 body={priority=0,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('starter-seal','mop.paladin.seal-truth','starter-'),
   block('starter-upkeep','mop.paladin.upkeep','starter-'),
   spell('starter-flash-of-light',19750,all(negate(combat()),health('LESSTHAN',.7))),
  },
  rotation={
   block('starter-boundaries','mop.paladin.damage-boundaries','starter-'),
   {id='starter-pull',type='branch',conditions=all(negate(combat()),{type='BEYOND_MELEE',unit='target'}),onFalse={},onTrue={
    spell('starter-pull-judgment',20271),stop('starter-pull-stop')}},
   spell('starter-word-of-glory',85673,health('LESSTHAN',.4)),
   spell('starter-hammer-justice',853,all(negate({type='GROUP'}),health('LESSTHAN',.5))),
   spell('starter-crusader-strike',35395),
   spell('starter-judgment',20271),
  },
 },
}))
