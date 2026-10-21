-- Bounded40–49 Frost single-target preview; the original1–29 pack stays unchanged.
-- Keep manual armor choices. Learning a preferred armor does not justify replacing
-- an existing armor, or falling back when the preferred family is not ready.
-- Next-action advice retains the original Mage cast/channel publication behavior.
-- Talents, frozen-target combos, kiting, emergency defenses and resources stay manual.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(value)return{type='NOT',value=value}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function missing(id)return negate({type='BUFF',unit='player',spell=id,anyrank=true})end
-- OR does not turn an unavailable observation into a match. This guards the
-- armor decision when learning for any member of the armor family is unknown.
local function readableLearning(id)return{type='OR',value={known(id),negate(known(id))}}end
local function armor(...)return all(missing(168),missing(7302),missing(6117),
 readableLearning(168),readableLearning(7302),readableLearning(6117),...)end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.mage.starter.40-49',revision=1,
 nameKey='Default.TBC.Mage.Forties.Name',descriptionKey='Default.TBC.Mage.Forties.Description',
 applicability={families={'tbc'},actionContext='player',class='MAGE',minLevel=40,maxLevel=49},
 tags={'leveling','solo','starter','frost','single-target','preview'},
 sources={{url='https://www.icy-veins.com/tbc-classic/frost-single-target-mage-leveling-guide',
  title='Icy Veins: Frost single-target Mage leveling',reviewedAt='2026-10-20',revision='2026-01-12'}},
 body={
  switch=all(known(116),{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=40},
   {type='LEVEL',unit='player',operator='LESSTHAN',value=50}),
  rotation={{id='mage-forties-target',type='branch',conditions=all({type='ATTACKABLE',unit='target'},
   negate({type='MOVING'}),{type='OR',value={{type='COMBAT',unit='player'},negate({type='COMBAT',unit='target'})}}),
   onFalse={},onTrue={{id='mage-forties-frost',type='spell',action=116,ranked=false,conditions={}}}}},
  cooldowns={
   {id='mage-forties-intellect',type='spell',action=1459,ranked=false,conditions=missing(1459)},
   {id='mage-forties-mage-armor',type='spell',action=6117,ranked=false,conditions=armor(known(6117))},
   {id='mage-forties-ice-armor',type='spell',action=7302,ranked=false,conditions=armor(negate(known(6117)),known(7302))},
   {id='mage-forties-frost-armor',type='spell',action=168,ranked=false,conditions=armor(negate(known(6117)),negate(known(7302)),known(168))},
  },
 },
}))
