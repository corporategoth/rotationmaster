-- Original bounded ranged preview; pets, melee, ammunition and positioning remain manual.
-- Source evidence and explicit preview policy are maintained in Defaults/README.md.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(value)return{type='NOT',value=value}end
local function standing()return negate({type='MOVING'})end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.hunter.starter',revision=1,
 nameKey='Default.TBC.Hunter.Starter.Name',descriptionKey='Default.TBC.Hunter.Starter.Description',
 applicability={families={'tbc'},actionContext='player',class='HUNTER',minLevel=1,maxLevel=19},
 tags={'leveling','solo','starter','single-target','preview'},
 sources={{url='https://www.icy-veins.com/tbc-classic/beast-mastery-hunter-leveling-guide',title='Icy Veins: Beast Mastery Hunter leveling',reviewedAt='2026-10-20',revision='2026-01-12'}},
 body={switch=all({type='SPELL_KNOWN',spell=75},{type='LEVEL',unit='player',operator='LESSTHAN',value=20}),
 cooldowns={{id='hunter-starter-hawk',type='spell',action=13165,ranked=false,
  conditions=all(negate({type='BUFF',unit='player',spell=13165,anyrank=true}),negate({type='BUFF',unit='player',spell=13163,anyrank=true}))}},
 rotation={{id='hunter-starter-target',type='branch',conditions=all({type='ATTACKABLE',unit='target'},
  {type='OR',value={{type='COMBAT',unit='player'},negate({type='COMBAT',unit='target'})}}),onFalse={},onTrue={
  {id='hunter-starter-casting',type='none',suppress_attack=true,conditions={type='OR',value={{type='CASTING',unit='player'},{type='CHANNELING',unit='player'}}}},
  {id='hunter-starter-repeat',type='branch',conditions={type='SPELL_AUTOREPEAT',spell=75,ranked=true},onTrue={},onFalse={
   {id='hunter-starter-start-auto',type='spell',action=75,ranked=true,conditions=standing()}}},
  {id='hunter-starter-sting',type='spell',action=1978,ranked=false,conditions=negate({type='DEBUFF',unit='target',spell=1978,anyrank=true,owndebuff=true})},
  {id='hunter-starter-arcane',type='spell',action=3044,ranked=false,conditions={}},
  {id='hunter-starter-exhausted',type='none',suppress_attack=true,conditions={}},
 }}},
 },
}))
