-- Original caster-only preview; form choice, Feral combat, targeted support and resources stay manual.
-- This source identifies only humanoid index0, never guesses Bear/Aquatic by learned slot order.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(value)return{type='NOT',value=value}end
local function stop(id)return{id=id,type='none',suppress_attack=true,conditions={}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.druid.caster.starter',revision=1,
 nameKey='Default.TBC.Druid.Caster.Starter.Name',descriptionKey='Default.TBC.Druid.Caster.Starter.Description',
 applicability={families={'tbc'},actionContext='player',class='DRUID',minLevel=1,maxLevel=19},
 tags={'leveling','solo','starter','single-target','preview','caster'},
 sources={{url='https://www.icy-veins.com/tbc-classic/balance-druid-leveling-guide',title='Icy Veins: Balance Druid leveling',reviewedAt='2026-10-20',revision='2026-01-12'}},
 body={switch=all({type='SPELL_KNOWN',spell=5176},{type='LEVEL',unit='player',operator='LESSTHAN',value=20}),cooldowns={},rotation={
  {id='druid-caster-starter-humanoid',type='branch',conditions={type='FORM',value=0},onFalse={stop('druid-caster-starter-manual-form')},onTrue={
   {id='druid-caster-starter-target',type='branch',conditions=all({type='ATTACKABLE',unit='target'},
    {type='OR',value={{type='COMBAT',unit='player'},negate({type='COMBAT',unit='target'})}}),onFalse={},onTrue={
    {id='druid-caster-starter-casting',type='none',suppress_attack=true,conditions={type='OR',value={{type='CASTING',unit='player'},{type='CHANNELING',unit='player'}}}},
    {id='druid-caster-starter-moonfire',type='spell',action=8921,ranked=false,conditions=negate({type='DEBUFF',unit='target',spell=8921,anyrank=true,owndebuff=true})},
    {id='druid-caster-starter-wrath',type='spell',action=5176,ranked=false,conditions=negate({type='MOVING'})},
   }},stop('druid-caster-starter-caster-exhausted'),
  }},
 }},
}))
