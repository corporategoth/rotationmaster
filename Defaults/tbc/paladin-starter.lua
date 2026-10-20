-- Original bounded priority data; provenance/manual limits are in Defaults/README.md.
-- Devotion default and no fixed mana reserve are RM preview policy.
-- Crusader Judgement, targeted blessings/heals, reactive utility and resources remain manual.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function missing(id,own)return{type='NOT',value={type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=own}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.paladin.starter',revision=1,
 nameKey='Default.TBC.Paladin.Starter.Name',descriptionKey='Default.TBC.Paladin.Starter.Description',
 applicability={families={'tbc'},actionContext='player',class='PALADIN',minLevel=1,maxLevel=19},
 tags={'leveling','solo','starter','single-target','preview'},
 sources={{url='https://www.icy-veins.com/tbc-classic/paladin-leveling-guide',title='Icy Veins: Paladin leveling',reviewedAt='2026-10-20',revision='2026-01-12'}},
 body={switch={type='LEVEL',unit='player',operator='LESSTHAN',value=20},cooldowns={
  -- Devotion is a conservative default, not a superior replacement for Retribution.
  {id='paladin-preview-devotion',type='spell',action=465,ranked=false,conditions=all(missing(465,true),missing(7294,true))},
  -- Leave manual Crusader/Judgement preparation intact.
  {id='paladin-preview-righteousness',type='spell',action=21084,ranked=false,conditions=all(missing(21084),missing(21082))},
 },rotation={{id='paladin-preview-combat',type='branch',conditions=all({type='COMBAT',unit='player'},{type='ATTACKABLE',unit='target'}),onFalse={},onTrue={
  {id='paladin-preview-righteous-judgement',type='spell',action=20271,ranked=false,conditions=all({type='BUFF',unit='player',spell=21084,anyrank=true},missing(21082))},
 }}}},
}))
