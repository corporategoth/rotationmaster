-- Mists of Pandaria Classic Druid before a specialization (levels 1–9, or a druid who has not chosen
-- one): the catch-all, lowest priority. No source writes a 1–9 list, so this is RM policy built from
-- the kit (Warcraft Tavern: Wrath and Moonfire first): Cat Form Rake/Bite/Mangle, Bear Form
-- Mangle/Maul, otherwise Moonfire and Wrath with a solo Rejuvenation when hurt.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function cp(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function swing(id,conditions)return{id=id,type='none',conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local lives=any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'},
 {type='HEALTHPCT',unit='target',operator='GREATERTHANOREQUALS',value=.3},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=6})
local moving={type='MOVING'}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.druid.unspecialized',revision=4,
 blocks={['mop.druid.melee-boundaries']=1},
 nameKey='Default.MoP.Druid.Unspecialized.Name',descriptionKey='Default.MoP.Druid.Unspecialized.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DRUID'},
 tags={'leveling','single-target','warcraft-tavern'},
 sources={
  {url='https://www.warcrafttavern.com/mop/guides/druid-leveling-guide/',title='Warcraft Tavern: MoP Classic Druid leveling',reviewedAt='2026-10-23',notes='Only names Wrath and Moonfire for the first levels; the form arms are RM policy.'},
 },
 body={priority=0,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={},
  rotation={
   block('none-boundaries','mop.druid.melee-boundaries','none-'),
   {id='none-cat',type='branch',conditions={type='FORM',form=768},onFalse={},onTrue={
    spell('none-cat-rake',1822,all(negate({type='DEBUFF',unit='target',spell=1822,owndebuff=true}),lives)),
    spell('none-cat-bite',22568,any(cp('GREATERTHANOREQUALS',5),all(cp('GREATERTHANOREQUALS',2),{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.3}))),
    spell('none-cat-mangle',33917),
    swing('none-cat-stop')}},
   {id='none-bear',type='branch',conditions={type='FORM',form=5487},onFalse={},onTrue={
    spell('none-bear-mangle',33917),
    spell('none-bear-maul',6807,{type='POWER',unit='player',operator='GREATERTHANOREQUALS',value=30}),
    swing('none-bear-stop')}},
   {id='none-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell('none-pull-moonfire',8921,moving),spell('none-pull-wrath',5176),stop('none-pull-stop')}},
   spell('none-rejuvenation',774,all({type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5},
    negate({type='BUFF',unit='player',spell=774,ownbuff=true}),negate({type='GROUP'}))),
   spell('none-moonfire',8921,all(negate({type='DEBUFF',unit='target',spell=8921,owndebuff=true}),lives)),
   spell('none-wrath',5176,negate(moving)),
   spell('none-moonfire-moving',8921,moving),
  },
 },
}))
