-- Bounded combat-only continuation; the separate1–19 pack is unchanged.
-- Rend maintenance stops here. Overpower/dodge response, stance choices, pulls,
-- reactive utility and resource/queue planning remain manual. Execute-before-HS
-- is RM preview policy; actual learned/bar/native readiness still permits actions.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local priorities={
 {id='warrior-continuation-execute',type='spell',action=5308,ranked=false,
  conditions={type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2}},
}
-- Exact ranks in this bounded corpus; no generic queued-family inference.
for _,id in ipairs({78,284,285,1608})do
 priorities[#priorities+1]={id='warrior-continuation-known-hs-'..id,type='branch',conditions={type='SPELL_KNOWN',spell=id},onFalse={},onTrue={
  {id='warrior-continuation-pending-hs-'..id,type='none',suppress_attack=false,conditions={type='SPELL_ACTIVE',spell=id,ranked=true}}}}
end
priorities[#priorities+1]={id='warrior-continuation-heroic-strike',type='spell',action=78,ranked=false,conditions={}}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.warrior.starter.20-29',revision=1,
 nameKey='Default.TBC.Warrior.Continuation.Name',descriptionKey='Default.TBC.Warrior.Continuation.Description',
 applicability={families={'tbc'},actionContext='player',class='WARRIOR',minLevel=20,maxLevel=29},
 tags={'leveling','solo','starter','single-target','preview'},
 sources={{url='https://www.icy-veins.com/tbc-classic/arms-warrior-leveling-guide',title='Icy Veins: Arms Warrior leveling',reviewedAt='2026-10-20',revision='2026-01-12'}},
 body={switch=all({type='SPELL_KNOWN',spell=78},{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=20},{type='LEVEL',unit='player',operator='LESSTHAN',value=30}),
 cooldowns={{id='warrior-continuation-battle-shout',type='spell',action=6673,ranked=false,
  conditions=negate({type='BUFF',unit='player',spell=6673,anyrank=true})}},
 rotation={{id='warrior-continuation-target',type='branch',conditions=all({type='COMBAT',unit='player'},{type='ATTACKABLE',unit='target'}),onFalse={},onTrue=priorities}},
 },
}))
