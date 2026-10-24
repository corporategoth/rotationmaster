-- Season of Discovery Rogue melee DPS, Icy Veins Phase 8 order (alternative premade).
-- Same switch and shared blocks as the recommended SoD premade (era/blocks.lua). Differs where
-- Icy Veins differs: Garrote opener in a group; Poisoned Knife only at five poison stacks; every
-- finisher at five points: Slice and Dice when missing or ending, Rupture kept up for Carnage (when engraved),
-- then Envenom; area damage is Blunderbuss or Fan of Knives on three. Instant Poison on both
-- weapons. Left manual: Sebacious Poison duty, Shadowstep, Sprint and positioning.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function stacks(id,n)return{type='DEBUFF_STACKS',unit='target',spell=id,anyrank=true,owndebuff=true,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local five={type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=5}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.rogue.dps.icyveins',revision=6,
 blocks={['era.rogue.boundaries']=3,['era.rogue.sod-opener']=4,['era.rogue.sod-upkeep']=3,['era.rogue.sod-builders']=3},
 nameKey='Default.SoD.Rogue.DPS.IcyVeins.Name',descriptionKey='Default.SoD.Rogue.DPS.IcyVeins.Description',
 applicability={families={'era'},actionContext='player',class='ROGUE',rulesets={'season:2'}},
 tags={'dps','melee','leveling','endgame','aoe','season-of-discovery','icy-veins'},
 sources={{url='https://www.icy-veins.com/wow-classic/assassination-rogue-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Assassination Rogue DPS rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
 {url='https://www.icy-veins.com/wow-classic/combat-rogue-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Combat Rogue DPS rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
 {url='https://www.icy-veins.com/wow-classic/subtlety-rogue-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Subtlety Rogue DPS rotation',reviewedAt='2026-10-23',revision='2025-04-08'}},
 body={priority=45,disabled=true,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('era.rogue.sod-upkeep','rogue-')},
 rotation={
 block('era.rogue.boundaries','rogue-'),
 {id='rogue-stealth',type='branch',conditions={type='STEALTHED'},onFalse={},onTrue={block('era.rogue.sod-opener','rogue-stealth-')}},
 {id='rogue-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  spell('rogue-aoe-blunderbuss',436564),
  spell('rogue-aoe-fan-of-knives',409240),
 }},
 spell('rogue-poisoned-knife',425012,all(negate(five),any(stacks(458820,5),stacks(1214170,5),stacks(2818,5)))),
 {id='rogue-finisher',type='branch',conditions=five,onFalse={},onTrue={
  spell('rogue-slice',5171,any(negate({type='BUFF',unit='player',spell=5171,anyrank=true,ownbuff=true}),
   {type='BUFF_REMAIN',unit='player',spell=5171,anyrank=true,ownbuff=true,operator='LESSTHAN',value=2})),
  spell('rogue-rupture',1943,all(rune(432276),negate({type='DEBUFF',unit='target',spell=1943,anyrank=true,owndebuff=true}))),
  spell('rogue-envenom',399963),
  spell('rogue-eviscerate',2098,negate(rune(399963))),
  {id='rogue-pool',type='stop',suppress_attack=false,conditions={}},
 }},
 block('era.rogue.sod-builders','rogue-'),
 }},
}))
