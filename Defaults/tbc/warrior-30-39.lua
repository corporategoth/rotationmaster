-- Separate bounded30–39 combat preview; earlier sources and saved copies stay unchanged.
-- Generic inherited melee subset, not a complete Arms build or optimal DPS claim.
-- Preserve manual casts/channels, including Slam; native learning/readiness govern ranks.
-- Rend maintenance stops here. Overpower/dodge response, stance choices, pulls,
-- reactive utility and resource/queue planning remain manual. Execute-before-HS
-- is RM preview policy; actual learned/bar/native readiness still permits actions.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local priorities={
 {id='warrior-thirty-execute',type='spell',action=5308,ranked=false,
  conditions={type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2}},
}
-- Exact ranks in this bounded corpus; no generic queued-family inference.
for _,id in ipairs({78,284,285,1608,11564})do
 priorities[#priorities+1]={id='warrior-thirty-known-hs-'..id,type='branch',conditions={type='SPELL_KNOWN',spell=id},onFalse={},onTrue={
  {id='warrior-thirty-pending-hs-'..id,type='none',suppress_attack=false,conditions={type='SPELL_ACTIVE',spell=id,ranked=true}}}}
end
priorities[#priorities+1]={id='warrior-thirty-heroic-strike',type='spell',action=78,ranked=false,conditions={}}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.warrior.starter.30-39',revision=1,
 nameKey='Default.TBC.Warrior.Thirty.Name',descriptionKey='Default.TBC.Warrior.Thirty.Description',
 applicability={families={'tbc'},actionContext='player',class='WARRIOR',minLevel=30,maxLevel=39},
 tags={'leveling','solo','starter','single-target','preview'},
 sources={{url='https://raw.githubusercontent.com/Gethe/wow-ui-source/2cfec7c00f0f24762d5ca35a4beb1e93c0cde328/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua',title='Blizzard Spell API declarations: identifier-specific current/queued state',reviewedAt='2026-10-20',revision='2cfec7c00f0f24762d5ca35a4beb1e93c0cde328',notes='Supports exact identifier queries, not equivalence of highest learned and lower queued ranks.'},
 {url='https://nether.wowhead.com/tbc/tooltip/spell/11564?dataEnv=5&locale=0',title='TBC client-description mirror: Heroic Strike11564',reviewedAt='2026-10-20',notes='Nominal level32/Next Melee scenario identity, not Blizzard-hosted primary training or actual learned state.'},
 {url='https://nether.wowhead.com/tbc/tooltip/spell/20658?dataEnv=5&locale=0',title='TBC client-description mirror: Execute20658',reviewedAt='2026-10-20',notes='Strict below20% tooltip; nominal level32 is not training or stance automation.'},
 {url='https://nether.wowhead.com/tbc/tooltip/spell/11549?dataEnv=5&locale=0',title='TBC client-description mirror: Battle Shout11549',reviewedAt='2026-10-20',notes='Nominal level32 scenario identity; current native learning and readiness govern advice.'},
 {url='https://www.icy-veins.com/tbc-classic/arms-warrior-leveling-guide',title='Icy Veins: Arms Warrior leveling',reviewedAt='2026-10-20',revision='2026-01-12'}},
 body={switch=all({type='SPELL_KNOWN',spell=78},{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=30},{type='LEVEL',unit='player',operator='LESSTHAN',value=40}),
 cooldowns={{id='warrior-thirty-battle-shout',type='spell',action=6673,ranked=false,
  conditions=all(negate({type='CASTING',unit='player'}),negate({type='CHANNELING',unit='player'}),negate({type='BUFF',unit='player',spell=6673,anyrank=true}))}},
 rotation={
 {id='warrior-thirty-preserve-cast',type='none',suppress_attack=true,conditions={type='CASTING',unit='player'}},
 {id='warrior-thirty-preserve-channel',type='none',suppress_attack=true,conditions={type='CHANNELING',unit='player'}},
 {id='warrior-thirty-target',type='branch',conditions=all({type='COMBAT',unit='player'},{type='ATTACKABLE',unit='target'}),onFalse={},onTrue=priorities}},
 },
}))
