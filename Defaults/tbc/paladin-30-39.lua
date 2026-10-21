-- Bounded generic Paladin30–39 preview; not a complete Ret build or optimality claim.
-- Aura/seal upkeep, talents, twisting, support and resources remain manual.
-- Only affirmative native own Righteousness authorizes Judgement; nil owner does not.
-- Readiness and mappings govern learned actions; levels grant no spells or ranks.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function missing(id)return{type='NOT',value={type='BUFF',unit='player',spell=id,anyrank=true}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.paladin.starter.30-39',revision=1,
 nameKey='Default.TBC.Paladin.Thirty.Name',descriptionKey='Default.TBC.Paladin.Thirty.Description',
 applicability={families={'tbc'},actionContext='player',class='PALADIN',minLevel=30,maxLevel=39},
 tags={'leveling','solo','starter','single-target','preview'},
 sources={{url='https://www.icy-veins.com/tbc-classic/paladin-leveling-guide',title='Icy Veins: Paladin leveling',reviewedAt='2026-10-20',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/retribution-paladin-leveling-guide',title='Icy Veins: Retribution Paladin leveling (context; no automatic talent or seal choice)',reviewedAt='2026-10-20',revision='2026-01-12'},
  {url='https://nether.wowhead.com/tbc/tooltip/spell/20165?dataEnv=5&locale=0',title='TBC client-description mirror: Seal of Light identity; not native learning proof',reviewedAt='2026-10-20'},
  {url='https://nether.wowhead.com/tbc/tooltip/spell/20166?dataEnv=5&locale=0',title='TBC client-description mirror: Seal of Wisdom identity; not native learning proof',reviewedAt='2026-10-20'}},
 body={switch=all({type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=30},{type='LEVEL',unit='player',operator='LESSTHAN',value=40}),
 cooldowns={},rotation={{id='paladin-thirty-combat',type='branch',conditions=all({type='COMBAT',unit='player'},{type='ATTACKABLE',unit='target'}),onFalse={},onTrue={
  {id='paladin-thirty-casting',type='none',suppress_attack=true,conditions={type='OR',value={{type='CASTING',unit='player'},{type='CHANNELING',unit='player'}}}},
  -- Conflicting manual seals also block transient overlapping observations.
  {id='paladin-thirty-righteous-judgement',type='spell',action=20271,ranked=false,
   conditions=all({type='BUFF',unit='player',spell=21084,anyrank=true,ownbuff=true},missing(21082),missing(20375),missing(20164),missing(20165),missing(20166))},
 }}}},
}))
