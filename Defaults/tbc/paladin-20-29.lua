-- Bounded Paladin20–29 upkeep/Righteousness-Judgement preview; not optimality proof.
-- Inherited ownbuff semantics: readable nil caster is not-own; restricted caster is unavailable.
-- Native own-aura attribution remains an acceptance requirement; no aura helper changes.
-- Devotion default and no fixed mana reserve are RM preview policy.
-- Crusader/Command/Justice Judgement, targeted support, reactive abilities and resources remain manual.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function missing(id,own)return{type='NOT',value={type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=own}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.paladin.starter.20-29',revision=1,
 nameKey='Default.TBC.Paladin.Continuation.Name',descriptionKey='Default.TBC.Paladin.Continuation.Description',
 applicability={families={'tbc'},actionContext='player',class='PALADIN',minLevel=20,maxLevel=29},
 tags={'leveling','solo','starter','single-target','preview'},
 sources={{url='https://www.icy-veins.com/tbc-classic/paladin-leveling-guide',title='Icy Veins: Paladin leveling',reviewedAt='2026-10-20',revision='2026-01-12'}},
 body={switch=all({type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=20},{type='LEVEL',unit='player',operator='LESSTHAN',value=30}),cooldowns={
  -- Devotion is a conservative default, not a superior replacement for Retribution.
  {id='paladin-preview-devotion',type='spell',action=465,ranked=false,conditions=all(missing(465,true),missing(7294,true),missing(19746,true),missing(19876,true))},
  -- Preserve recognized manual Crusader/Command/Justice choice; no seal/talent/weapon inference.
  {id='paladin-preview-righteousness',type='spell',action=21084,ranked=false,conditions=all(missing(21084),missing(21082),missing(20375),missing(20164))},
 },rotation={{id='paladin-preview-combat',type='branch',conditions=all({type='COMBAT',unit='player'},{type='ATTACKABLE',unit='target'}),onFalse={},onTrue={
  {id='paladin-preview-righteous-judgement',type='spell',action=20271,ranked=false,conditions=all({type='BUFF',unit='player',spell=21084,anyrank=true},missing(21082),missing(20375),missing(20164))},
 }}}},
}))
