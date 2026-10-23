-- Separate bounded40–49 continuation; both earlier sources and saved copies stay unchanged.
-- Generic inherited melee subset, not a complete Combat build or optimal DPS claim.
-- No newly guessed ranks or training: learned families/mappings/readiness remain authoritative.
-- This reuses the inherited priorities and existing TBC current-target POINT13 transport.
-- No new talent/poison/opening/lifetime policy or fixed resource threshold.
-- Own Slice uses existing native-attributable player-caster semantics;
-- readable nil caster is not invented as own, restricted attribution is unavailable.
-- Two-point Slice upkeep and five-point Eviscerate/no builder overflow are RM preview policy.
-- Stealth/openers, reactive utility, positioning, poisons, pulls and resource planning remain manual.
-- The manual-state Stops and melee priority are shared blocks (Defaults/blocks/rogue.lua);
-- registration expands them to the identical step IDs and tree shipped before composition.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.rogue.starter.40-49',revision=1,blocks={['tbc.rogue.preserve-manual']=1,['tbc.rogue.melee-priority']=1},
 nameKey='Default.TBC.Rogue.Forty.Name',descriptionKey='Default.TBC.Rogue.Forty.Description',
 applicability={families={'tbc'},actionContext='player',class='ROGUE',minLevel=40,maxLevel=49},
 tags={'leveling','solo','starter','single-target','preview'},
 sources={{url='https://raw.githubusercontent.com/Gethe/wow-ui-source/7c477d17fdb12d00b7deb3eb21bce1f02ce89fbf/Interface/FrameXML/ComboFrame.lua',title='Blizzard TBC ComboFrame client source: current player/target combo transport',reviewedAt='2026-10-20',revision='7c477d17fdb12d00b7deb3eb21bce1f02ce89fbf',notes='Supports inherited current-target combo query, not spell training, priority or complete talent build.'},
 {url='https://www.icy-veins.com/tbc-classic/combat-rogue-leveling-guide',title='Icy Veins: Combat Rogue leveling',reviewedAt='2026-10-20',revision='2026-01-12'}},
 body={switch=all({type='SPELL_KNOWN',spell=1752},{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=40},{type='LEVEL',unit='player',operator='LESSTHAN',value=50}),cooldowns={},rotation={
 {id='rogue-forty-manual',type='block',block='tbc.rogue.preserve-manual',prefix='rogue-forty-'},
 {id='rogue-forty-target',type='branch',conditions=all({type='COMBAT',unit='player'},{type='ATTACKABLE',unit='target'},negate({type='BEYOND_MELEE',unit='target'})),onFalse={},onTrue={
  {id='rogue-forty-melee',type='block',block='tbc.rogue.melee-priority',prefix='rogue-forty-'},
 }}},},
}))
