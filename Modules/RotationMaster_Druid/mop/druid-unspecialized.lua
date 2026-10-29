-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Druid before a specialization (levels 1–9, or a druid who has not chosen
-- one): the catch-all, lowest priority. No source writes a 1–9 list, so this is RM policy built from
-- the kit (Warcraft Tavern: Wrath and Moonfire first): Cat Form Rake/Bite/Mangle, Bear Form
-- Mangle/Maul, otherwise Moonfire and Wrath with a solo Rejuvenation when hurt.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function cp(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function swing(id,conditions)return{id=id,type='stop',conditions=conditions or{}}end
local lives=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'},
 {type='HEALTHPCT',unit='target',operator='GREATERTHANOREQUALS',value=.3},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=6})
local moving={type='MOVING'}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.druid.unspecialized',revision=6,
 blocks={['mop.druid.melee-boundaries']=2},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DRUID'},
 tags={'leveling','single-target','warcraft-tavern'},
 sources={
  {url='https://www.warcrafttavern.com/mop/guides/druid-leveling-guide/',title='Warcraft Tavern: MoP Classic Druid leveling',reviewedAt='2026-10-23',notes='Only names Wrath and Moonfire for the first levels; the form arms are RM policy.'},
 },
 body={priority=0,
  cooldowns={},
  rotation={
   BuiltinConditions.block('none-boundaries','mop.druid.melee-boundaries','none-'),
   {id='none-cat',type='branch',conditions={type='FORM',form=768},onFalse={},onTrue={
    BuiltinConditions.spell('none-cat-rake',1822,BuiltinConditions.all(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=1822,owndebuff=true}),lives)),
    BuiltinConditions.spell('none-cat-bite',22568,BuiltinConditions.any(cp('GREATERTHANOREQUALS',5),BuiltinConditions.all(cp('GREATERTHANOREQUALS',2),{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.3}))),
    BuiltinConditions.spell('none-cat-mangle',33917),
    swing('none-cat-stop')}},
   {id='none-bear',type='branch',conditions={type='FORM',form=5487},onFalse={},onTrue={
    BuiltinConditions.spell('none-bear-mangle',33917),
    BuiltinConditions.spell('none-bear-maul',6807,{type='POWER',unit='player',operator='GREATERTHANOREQUALS',value=30}),
    swing('none-bear-stop')}},
   {id='none-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell('none-pull-moonfire',8921,moving),BuiltinConditions.spell('none-pull-wrath',5176),BuiltinConditions.stop('none-pull-stop')}},
   BuiltinConditions.spell('none-rejuvenation',774,BuiltinConditions.all({type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5},
    BuiltinConditions.negate({type='BUFF',unit='player',spell=774,ownbuff=true}),BuiltinConditions.negate({type='GROUP'}))),
   BuiltinConditions.spell('none-moonfire',8921,BuiltinConditions.all(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=8921,owndebuff=true}),lives)),
   BuiltinConditions.spell('none-wrath',5176,BuiltinConditions.negate(moving)),
   BuiltinConditions.spell('none-moonfire-moving',8921,moving),
  },
 },
}))
