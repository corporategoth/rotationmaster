-- Original bounded preview; provenance/manual responsibilities are in Defaults/README.md.
-- Rend through19 and no fixed rage reserve are RM preview policy, not optimality claims.
-- Reactive utility, stance changes, pulls and resource conservation remain manual.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local priorities={
 {id='warrior-preview-rend',type='spell',action=772,ranked=false,
  conditions=negate({type='DEBUFF',unit='target',spell=772,anyrank=true,owndebuff=true})},
}
-- Exact authored ranks in the bounded 1–19 corpus, not a new family resolver.
for _,id in ipairs({78,284,285})do
 priorities[#priorities+1]={id='warrior-preview-known-hs-'..id,type='branch',conditions={type='SPELL_KNOWN',spell=id},onFalse={},onTrue={
  {id='warrior-preview-pending-hs-'..id,type='none',suppress_attack=false,conditions={type='SPELL_ACTIVE',spell=id,ranked=true}}}}
end
priorities[#priorities+1]={id='warrior-preview-heroic-strike',type='spell',action=78,ranked=false,conditions={}}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.warrior.starter',revision=1,
 nameKey='Default.TBC.Warrior.Starter.Name',descriptionKey='Default.TBC.Warrior.Starter.Description',
 applicability={families={'tbc'},actionContext='player',class='WARRIOR',minLevel=1,maxLevel=19},
 tags={'leveling','solo','starter','single-target','preview'},
 sources={{url='https://www.icy-veins.com/tbc-classic/arms-warrior-leveling-guide',title='Icy Veins: Arms Warrior leveling',reviewedAt='2026-10-20',revision='2026-01-12'}},
 body={switch=all({type='SPELL_KNOWN',spell=78},{type='LEVEL',unit='player',operator='LESSTHAN',value=20}),
 cooldowns={{id='warrior-preview-battle-shout',type='spell',action=6673,ranked=false,
  conditions=negate({type='BUFF',unit='player',spell=6673,anyrank=true})}},
 rotation={{id='warrior-preview-target',type='branch',conditions=all({type='COMBAT',unit='player'},{type='ATTACKABLE',unit='target'}),onFalse={},onTrue=priorities}},
 },
}))
