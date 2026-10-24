-- Season of Discovery Rogue melee DPS, levels 1–60 (the recommended SoD premade and the SoD
-- catch-all). wowsims/sod Phase 6 presets with Icy Veins and Zockify Phase 8: on three engaged
-- enemies Blunderbuss, Crimson Tempest and Fan of Knives first; Ambush on a Cutthroat proc; Saber
-- Slash stacks kept; Poisoned Knife at four poison stacks; Slice and Dice from two points,
-- refreshed from four in its last two seconds (not with Cut to the Chase, whose finishers refresh
-- it); Expose Armor duty; with the Carnage rune a bleed (Crimson Tempest, else Rupture, none with
-- Saber Slash); Envenom (Eviscerate before it is engraved) at five; builder by glove rune. Runes
-- are read as engraved, passive ones too (Vanish for Master of Subtlety). Shared parts: era/blocks.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function lifetime(op,n)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=n}end
local function owned(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function stacks(id,n)return{type='DEBUFF_STACKS',unit='target',spell=id,anyrank=true,owndebuff=true,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local sliced={type='BUFF',unit='player',spell=5171,anyrank=true,ownbuff=true}
local big=any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})
local lasting=any(big,{type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.35})
-- Four of your Occult Poison I/II or Deadly Poison stacks on the target.
local poisoned=any(stacks(458820,4),stacks(1214170,4),stacks(2818,4))
-- Passive runes: Carnage (bleeds pay), Cut to the Chase (finishers refresh Slice and Dice).
local carnage,chase=rune(432276),rune(432271)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.rogue.dps',revision=5,
 blocks={['era.rogue.boundaries']=3,['era.rogue.sod-opener']=4,['era.rogue.sod-upkeep']=3,['era.rogue.sod-builders']=3,['era.rogue.expose-armor']=2},
 nameKey='Default.SoD.Rogue.DPS.Name',descriptionKey='Default.SoD.Rogue.DPS.Description',
 applicability={families={'era'},actionContext='player',class='ROGUE',rulesets={'season:2'}},
 tags={'dps','melee','leveling','endgame','aoe','season-of-discovery','wowsims','icy-veins','zockify'},
 sources={{url='https://github.com/wowsims/sod/tree/0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e/ui/rogue/apls',title='wowsims/sod: Rogue Phase 6 APLs (Mutilate, Saber, Backstab)',reviewedAt='2026-10-23',revision='0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e'},
 {url='https://www.icy-veins.com/wow-classic/assassination-rogue-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Assassination Rogue DPS rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
 {url='https://www.icy-veins.com/wow-classic/subtlety-rogue-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Subtlety Rogue DPS rotation (area damage)',reviewedAt='2026-10-23',revision='2025-04-08'},
 {url='https://www.icy-veins.com/wow-classic/assassination-rogue-dps-season-of-discovery-leveling',title='Icy Veins: SoD Assassination Rogue leveling',reviewedAt='2026-10-23',revision='2025-04-08'},
 {url='https://www.zockify.com/wowclassic/rogue/dps/',title='Zockify: SoD DPS Rogue (Phase 8)',reviewedAt='2026-10-23',revision='2025-04-07'}},
 body={priority=50,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('era.rogue.sod-upkeep','rogue-')},
 rotation={
 block('era.rogue.boundaries','rogue-'),
 {id='rogue-stealth',type='branch',conditions={type='STEALTHED'},onFalse={},onTrue={block('era.rogue.sod-opener','rogue-stealth-')}},
 {id='rogue-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  spell('rogue-aoe-blunderbuss',436564),
  spell('rogue-aoe-crimson-tempest',412096,all(points('GREATERTHANOREQUALS',3),negate(owned(436611)))),
  spell('rogue-aoe-fan-of-knives',409240),
 }},
 spell('rogue-cutthroat-ambush',8676,all({type='WEAPON_TYPE',slot='mainhand',subclass=15},{type='BUFF',unit='player',spell=462707})),
 spell('rogue-saber-upkeep',424785,all(points('LESSTHAN',4),any(negate(stacks(424785,3)),
  {type='DEBUFF_REMAIN',unit='target',spell=424785,owndebuff=true,operator='LESSTHAN',value=2}))),
 spell('rogue-poisoned-knife',425012,all(points('LESSTHAN',5),{type='POWER',unit='player',operator='LESSTHANOREQUALS',value=80},poisoned)),
 spell('rogue-slice',5171,all(points('GREATERTHANOREQUALS',2),negate(sliced),lasting)),
 block('era.rogue.expose-armor','rogue-'),
 spell('rogue-slice-refresh',5171,all(points('GREATERTHANOREQUALS',4),negate(chase),{type='BUFF_REMAIN',unit='player',spell=5171,anyrank=true,ownbuff=true,operator='LESSTHAN',value=2})),
 spell('rogue-crimson-tempest',412096,all(carnage,points('GREATERTHANOREQUALS',4),negate(owned(436611)),lasting)),
 spell('rogue-rupture',1943,all(carnage,points('GREATERTHANOREQUALS',3),negate(rune(412096)),negate(rune(424785)),negate(owned(1943)),lasting)),
 spell('rogue-kill-envenom',399963,all(points('GREATERTHANOREQUALS',3),lifetime('LESSTHAN',4))),
 spell('rogue-kill-eviscerate',2098,all(points('GREATERTHANOREQUALS',3),negate(rune(399963)),lifetime('LESSTHAN',4))),
 {id='rogue-finisher',type='branch',conditions=points('GREATERTHANOREQUALS',5),onFalse={},onTrue={
  spell('rogue-envenom',399963),
  spell('rogue-eviscerate',2098,negate(rune(399963))),
  {id='rogue-pool',type='stop',suppress_attack=false,conditions={}},
 }},
 block('era.rogue.sod-builders','rogue-'),
 }},
}))
