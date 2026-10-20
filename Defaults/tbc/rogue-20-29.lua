-- Separate bounded20–29 continuation; original1–19 pack/copies stay unchanged.
-- This reuses the inherited priorities and existing TBC current-target POINT13 transport.
-- No new talent/poison/opening/lifetime policy or fixed resource threshold.
-- Own Slice uses existing native-attributable player-caster semantics;
-- readable nil caster is not invented as own, restricted attribution is unavailable.
-- Two-point Slice upkeep and five-point Eviscerate/no builder overflow are RM preview policy.
-- Stealth/openers, reactive utility, positioning, poisons, pulls and resource planning remain manual.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.rogue.starter.20-29',revision=1,
 nameKey='Default.TBC.Rogue.Continuation.Name',descriptionKey='Default.TBC.Rogue.Continuation.Description',
 applicability={families={'tbc'},actionContext='player',class='ROGUE',minLevel=20,maxLevel=29},
 tags={'leveling','solo','starter','single-target','preview'},
 sources={{url='https://www.icy-veins.com/tbc-classic/combat-rogue-leveling-guide',title='Icy Veins: Combat Rogue leveling',reviewedAt='2026-10-20',revision='2026-01-12'}},
 body={switch=all({type='SPELL_KNOWN',spell=1752},{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=20},{type='LEVEL',unit='player',operator='LESSTHAN',value=30}),cooldowns={},rotation={
 {id='rogue-preview-preserve-stealth',type='none',suppress_attack=true,conditions={type='STEALTHED'}},
 {id='rogue-preview-preserve-cast',type='none',suppress_attack=true,conditions={type='CASTING',unit='player'}},
 {id='rogue-preview-preserve-channel',type='none',suppress_attack=true,conditions={type='CHANNELING',unit='player'}},
 {id='rogue-preview-target',type='branch',conditions=all({type='COMBAT',unit='player'},{type='ATTACKABLE',unit='target'},negate({type='BEYOND_MELEE',unit='target'})),onFalse={},onTrue={
  {id='rogue-preview-upkeep-points',type='branch',conditions=points('GREATERTHANOREQUALS',2),onFalse={},onTrue={
   {id='rogue-preview-upkeep-known',type='branch',conditions={type='SPELL_KNOWN',spell=5171},onFalse={},onTrue={
    {id='rogue-preview-upkeep-missing',type='branch',conditions=negate({type='BUFF',unit='player',spell=5171,anyrank=true,ownbuff=true}),onFalse={},onTrue={
     {id='rogue-preview-slice',type='spell',action=5171,ranked=false,conditions={}},
    }},
   }},
  }},
  {id='rogue-preview-finisher-points',type='branch',conditions=points('GREATERTHANOREQUALS',5),onTrue={
   {id='rogue-preview-eviscerate',type='spell',action=2098,ranked=false,conditions={}},
  },onFalse={
   {id='rogue-preview-sinister',type='spell',action=1752,ranked=false,conditions={}},
  }},
 }}},},
}))
