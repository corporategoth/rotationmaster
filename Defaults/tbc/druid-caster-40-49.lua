-- Separate bounded40–49 caster preview; earlier packs and saved copies stay unchanged.
-- All nonzero forms, Feral combat, talents, targeted support and resources stay manual.
-- Moonfire-first then learned stationary Starfire/Wrath is RM preview policy;
-- native learned/bar/readiness remains decisive, with no mana or damage simulation.
-- Own Moonfire uses existing native-attributable player-caster semantics.
-- This source identifies only humanoid index0, never guesses Bear/Aquatic by learned slot order.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(value)return{type='NOT',value=value}end
local function stop(id)return{id=id,type='none',suppress_attack=true,conditions={}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.druid.caster.starter.40-49',revision=1,
 nameKey='Default.TBC.Druid.Caster.Forty.Name',descriptionKey='Default.TBC.Druid.Caster.Forty.Description',
 applicability={families={'tbc'},actionContext='player',class='DRUID',minLevel=40,maxLevel=49},
 tags={'leveling','solo','starter','single-target','preview','caster'},
 sources={{url='https://www.icy-veins.com/tbc-classic/balance-druid-leveling-guide',title='Icy Veins: Balance Druid leveling',reviewedAt='2026-10-20',revision='2026-01-12'}},
 body={switch=all({type='SPELL_KNOWN',spell=5176},{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=40},{type='LEVEL',unit='player',operator='LESSTHAN',value=50}),cooldowns={},rotation={
  {id='druid-caster-forty-humanoid',type='branch',conditions={type='FORM',value=0},onFalse={stop('druid-caster-forty-manual-form')},onTrue={
   {id='druid-caster-forty-target',type='branch',conditions=all({type='ATTACKABLE',unit='target'},
    {type='OR',value={{type='COMBAT',unit='player'},negate({type='COMBAT',unit='target'})}}),onFalse={},onTrue={
    {id='druid-caster-forty-casting',type='none',suppress_attack=true,conditions={type='OR',value={{type='CASTING',unit='player'},{type='CHANNELING',unit='player'}}}},
    {id='druid-caster-forty-moonfire',type='spell',action=8921,ranked=false,conditions=negate({type='DEBUFF',unit='target',spell=8921,anyrank=true,owndebuff=true})},
    -- Explicit RM policy: maintain own Moonfire, prefer learned stationary Starfire,
    -- then independently ready Wrath. No talent/proximity/resource optimization.
    {id='druid-caster-forty-starfire-known',type='branch',conditions={type='SPELL_KNOWN',spell=2912},onFalse={},onTrue={
     {id='druid-caster-forty-starfire',type='spell',action=2912,ranked=false,conditions=negate({type='MOVING'})}}},
    {id='druid-caster-forty-wrath',type='spell',action=5176,ranked=false,conditions=negate({type='MOVING'})},
   }},stop('druid-caster-forty-caster-exhausted'),
  }},
 }},
}))
