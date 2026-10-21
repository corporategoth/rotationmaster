-- Separate bounded40–49 preview; the earlier packs and saved copies stay unchanged.
-- Generic inherited ranged subset, not a complete BM build or optimal DPS policy.
-- Levels grant no spells: actual learned families, mappings and readiness govern ranks.
-- Pets, melee, ammunition, shot timing, positioning and resources remain manual.
-- Preserve deliberate Cheetah/Monkey and native-attributable own Scorpid.
-- A nil aura caster is not inferred to be the player under the existing contract.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(value)return{type='NOT',value=value}end
local function standing()return negate({type='MOVING'})end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.hunter.starter.40-49',revision=1,
 nameKey='Default.TBC.Hunter.Forty.Name',descriptionKey='Default.TBC.Hunter.Forty.Description',
 applicability={families={'tbc'},actionContext='player',class='HUNTER',minLevel=40,maxLevel=49},
 tags={'leveling','solo','starter','single-target','preview'},
 sources={{url='https://bnetcmsus-a.akamaihd.net/cms/template_resource/LO0VQ46XB1281555957773363.pdf',title='Blizzard: World of Warcraft manual (Hunter pp84–85; inherited Auto Shot/aspect context, not TBC training)',reviewedAt='2026-10-21',revision='2004'},
 {url='https://www.icy-veins.com/tbc-classic/beast-mastery-hunter-leveling-guide',title='Icy Veins: Beast Mastery Hunter leveling',reviewedAt='2026-10-21',revision='2026-01-12'}},
 body={switch=all({type='SPELL_KNOWN',spell=75},{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=40},{type='LEVEL',unit='player',operator='LESSTHAN',value=50}),
 cooldowns={{id='hunter-forty-hawk',type='spell',action=13165,ranked=false,
  conditions=all(negate({type='BUFF',unit='player',spell=13165,anyrank=true}),negate({type='BUFF',unit='player',spell=13163,anyrank=true}),negate({type='BUFF',unit='player',spell=5118,anyrank=true}))}},
 rotation={{id='hunter-forty-target',type='branch',conditions=all({type='ATTACKABLE',unit='target'},
  {type='OR',value={{type='COMBAT',unit='player'},negate({type='COMBAT',unit='target'})}}),onFalse={},onTrue={
  {id='hunter-forty-casting',type='none',suppress_attack=true,conditions={type='OR',value={{type='CASTING',unit='player'},{type='CHANNELING',unit='player'}}}},
  {id='hunter-forty-repeat',type='branch',conditions={type='SPELL_AUTOREPEAT',spell=75,ranked=true},onTrue={},onFalse={
   {id='hunter-forty-start-auto',type='spell',action=75,ranked=true,conditions=standing()}}},
  {id='hunter-forty-sting',type='spell',action=1978,ranked=false,conditions=all(negate({type='DEBUFF',unit='target',spell=1978,anyrank=true,owndebuff=true}),negate({type='DEBUFF',unit='target',spell=3043,anyrank=true,owndebuff=true}))},
  {id='hunter-forty-arcane',type='spell',action=3044,ranked=false,conditions={}},
  {id='hunter-forty-exhausted',type='none',suppress_attack=true,conditions={}},
 }}},
 },
}))
