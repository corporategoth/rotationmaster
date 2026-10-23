-- Season of Discovery Rogue melee DPS, Zockify Phase 8 lean Envenom list (alternative premade).
-- Same switch and shared blocks as the recommended SoD premade (era/blocks.lua). Differs where
-- Zockify differs: no bleed upkeep at all (no Rupture, no Crimson Tempest) and no Expose Armor;
-- Poisoned Knife at four poison stacks; Slice and Dice when missing from two points (four with
-- Saber Slash); Envenom at five; builder by glove rune. Left manual: the Vanish and Cold Blood
-- burst, Shadowstep, Sprint and positioning.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function stacks(id,n)return{type='DEBUFF_STACKS',unit='target',spell=id,anyrank=true,owndebuff=true,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local unsliced=negate({type='BUFF',unit='player',spell=5171,anyrank=true,ownbuff=true})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.rogue.dps.zockify',revision=1,
 blocks={['era.rogue.boundaries']=1,['era.rogue.sod-opener']=1,['era.rogue.sod-upkeep']=1,['era.rogue.sod-builders']=1},
 nameKey='Default.SoD.Rogue.DPS.Zockify.Name',descriptionKey='Default.SoD.Rogue.DPS.Zockify.Description',
 applicability={families={'era'},actionContext='player',class='ROGUE',minLevel=1,maxLevel=60,rulesets={'season:2'}},
 tags={'dps','melee','endgame','season-of-discovery','zockify'},
 sources={{url='https://www.zockify.com/wowclassic/rogue/dps/',title='Zockify: SoD DPS Rogue (Phase 8)',reviewedAt='2026-10-23',revision='2025-04-07'}},
 body={priority=42,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('era.rogue.sod-upkeep','rogue-')},
 rotation={
 block('era.rogue.boundaries','rogue-'),
 {id='rogue-stealth',type='branch',conditions={type='STEALTHED'},onFalse={},onTrue={block('era.rogue.sod-opener','rogue-stealth-')}},
 spell('rogue-poisoned-knife',425012,all(points('LESSTHAN',5),any(stacks(458820,4),stacks(1214170,4),stacks(2818,4)))),
 spell('rogue-slice',5171,all(unsliced,negate(known(424785)),points('GREATERTHANOREQUALS',2))),
 spell('rogue-saber-slice',5171,all(unsliced,known(424785),points('GREATERTHANOREQUALS',4))),
 {id='rogue-finisher',type='branch',conditions=points('GREATERTHANOREQUALS',5),onFalse={},onTrue={
  spell('rogue-envenom',399963),
  spell('rogue-eviscerate',2098,negate(known(399963))),
  {id='rogue-pool',type='none',suppress_attack=false,conditions={}},
 }},
 block('era.rogue.sod-builders','rogue-'),
 }},
}))
