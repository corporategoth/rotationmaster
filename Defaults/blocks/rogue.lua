-- Shared TBC Rogue melee blocks (Built In composition; authoring-time only).
-- Consumers: rm.tbc.rogue.starter.30-39 and .40-49. A content change here needs a
-- revision bump, every consumer's `blocks` pin and revision bumped, and both
-- recorded in tests/fixtures/builtin_composition_ledger.lua.
-- Policy and evidence are the consumers': see their headers and Defaults/README.md.
local _,addon=...
local function negate(c)return{type='NOT',value=c}end
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
-- Manual stealth, casts and channels halt lower advice and implicit Attack.
assert(addon:RegisterDefaultBlock({
 id='tbc.rogue.preserve-manual',revision=1,families={'tbc'},class='ROGUE',steps={
 {id='preserve-stealth',type='none',suppress_attack=true,conditions={type='STEALTHED'}},
 {id='preserve-cast',type='none',suppress_attack=true,conditions={type='CASTING',unit='player'}},
 {id='preserve-channel',type='none',suppress_attack=true,conditions={type='CHANNELING',unit='player'}},
}}))
-- Two-point own Slice upkeep, five-point Eviscerate, otherwise Sinister Strike.
assert(addon:RegisterDefaultBlock({
 id='tbc.rogue.melee-priority',revision=1,families={'tbc'},class='ROGUE',steps={
 {id='upkeep-points',type='branch',conditions=points('GREATERTHANOREQUALS',2),onFalse={},onTrue={
  {id='upkeep-known',type='branch',conditions={type='SPELL_KNOWN',spell=5171},onFalse={},onTrue={
   {id='upkeep-missing',type='branch',conditions=negate({type='BUFF',unit='player',spell=5171,anyrank=true,ownbuff=true}),onFalse={},onTrue={
    {id='slice',type='spell',action=5171,ranked=false,conditions={}},
   }},
  }},
 }},
 {id='finisher-points',type='branch',conditions=points('GREATERTHANOREQUALS',5),onTrue={
  {id='eviscerate',type='spell',action=2098,ranked=false,conditions={}},
 },onFalse={
  {id='sinister',type='spell',action=1752,ranked=false,conditions={}},
 }},
}}))
