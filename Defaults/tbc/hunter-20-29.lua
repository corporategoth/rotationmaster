-- Separate bounded20–29 preview; the original1–19 pack and copies stay unchanged.
-- Pets, melee, ammunition, shot timing, positioning and resources remain manual.
-- Preserve deliberate Cheetah/Monkey and native-attributable own Scorpid.
-- A nil aura caster is not inferred to be the player under the existing contract.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(value)return{type='NOT',value=value}end
local function standing()return negate({type='MOVING'})end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.hunter.starter.20-29',revision=1,
 nameKey='Default.TBC.Hunter.Continuation.Name',descriptionKey='Default.TBC.Hunter.Continuation.Description',
 applicability={families={'tbc'},actionContext='player',class='HUNTER',minLevel=20,maxLevel=29},
 tags={'leveling','solo','starter','single-target','preview'},
 sources={{url='https://www.icy-veins.com/tbc-classic/beast-mastery-hunter-leveling-guide',title='Icy Veins: Beast Mastery Hunter leveling',reviewedAt='2026-10-20',revision='2026-01-12'}},
 body={switch=all({type='SPELL_KNOWN',spell=75},{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=20},{type='LEVEL',unit='player',operator='LESSTHAN',value=30}),
 cooldowns={{id='hunter-continuation-hawk',type='spell',action=13165,ranked=false,
  conditions=all(negate({type='BUFF',unit='player',spell=13165,anyrank=true}),negate({type='BUFF',unit='player',spell=13163,anyrank=true}),negate({type='BUFF',unit='player',spell=5118,anyrank=true}))}},
 rotation={{id='hunter-continuation-target',type='branch',conditions=all({type='ATTACKABLE',unit='target'},
  {type='OR',value={{type='COMBAT',unit='player'},negate({type='COMBAT',unit='target'})}}),onFalse={},onTrue={
  {id='hunter-continuation-casting',type='none',suppress_attack=true,conditions={type='OR',value={{type='CASTING',unit='player'},{type='CHANNELING',unit='player'}}}},
  {id='hunter-continuation-repeat',type='branch',conditions={type='SPELL_AUTOREPEAT',spell=75,ranked=true},onTrue={},onFalse={
   {id='hunter-continuation-start-auto',type='spell',action=75,ranked=true,conditions=standing()}}},
  {id='hunter-continuation-sting',type='spell',action=1978,ranked=false,conditions=all(negate({type='DEBUFF',unit='target',spell=1978,anyrank=true,owndebuff=true}),negate({type='DEBUFF',unit='target',spell=3043,anyrank=true,owndebuff=true}))},
  {id='hunter-continuation-arcane',type='spell',action=3044,ranked=false,conditions={}},
  {id='hunter-continuation-exhausted',type='none',suppress_attack=true,conditions={}},
 }}},
 },
}))
