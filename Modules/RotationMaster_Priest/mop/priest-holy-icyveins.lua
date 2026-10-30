-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Holy Priest, Icy Veins order (a player-chosen variant, off by default). The chakra
-- picks the list. Chakra: Sanctuary: Holy Word: Sanctuary on three hurt allies, Renew, Circle of Healing, Prayer of
-- Mending, Prayer of Healing, then Binding Heal and Flash Heal only in emergencies. Otherwise (Serenity, or no
-- chakra yet): Renew, Holy Word: Serenity, Prayer of Mending, Greater Heal when low or at two Serendipity, Heal,
-- Binding Heal, Flash Heal when very low or on Surge of Light, Power Word: Shield last, and Flash Heal as the
-- filler before Heal is learned. Same switch, chakra fill, reminders and damage arm as the recommended Holy
-- premade (mop/blocks.lua).
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function health(unit,op,n)return{type='HEALTHPCT',unit=unit,operator=op,value=n}end
local function low(n)return health('target','LESSTHAN',n)end
local function hurt(n,below)return{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=40,healthoperator='LESSTHAN',health=below,operator='GREATERTHANOREQUALS',value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local friendly={type='FRIENDLY',unit='target'}
local group={type='GROUP'}
local unshielded=BuiltinConditions.negate({type='DEBUFF',unit='target',spell=6788})
local nochakra=BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.ownBuff(81208)),BuiltinConditions.negate(BuiltinConditions.ownBuff(81206)),BuiltinConditions.negate(BuiltinConditions.ownBuff(81209)))
local aoe=BuiltinConditions.all(group,hurt(3,.85))
local renew=BuiltinConditions.all(low(.95),BuiltinConditions.negate({type='BUFF',unit='target',spell=139,ownbuff=true}))
local binding=BuiltinConditions.all(health('player','LESSTHAN',.7),low(.7),BuiltinConditions.negate({type='ISSAME',unit='target',otherunit='player'}))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.priest.holy.icyveins',revision=7,
 blocks={['mop.priest.upkeep']=1,['mop.priest.healer-boundaries']=2,['mop.priest.healer-cooldowns']=1,['mop.priest.holy-damage']=2},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='PRIEST'},
 tags={'holy','healer','group','leveling','endgame','icy-veins'},
 sources={{url='https://www.icy-veins.com/mists-of-pandaria-classic/holy-priest-pve-rotation-cooldowns-abilities',title='Icy Veins: Holy Priest rotation (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/holy-priest-leveling',title='Icy Veins: Holy Priest leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'}},
 body={priority=20,disabled=true,specs={257},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.priest.upkeep','priest-'),block('mop.priest.healer-cooldowns','priest-'),
  BuiltinConditions.spell('priest-holy-iv-sanctuary-chakra',81206,BuiltinConditions.all(nochakra,{type='GROUP',raid=true})),
  BuiltinConditions.spell('priest-holy-iv-serenity-chakra',81208,BuiltinConditions.all(nochakra,group,BuiltinConditions.negate({type='GROUP',raid=true}))),
  BuiltinConditions.spell('priest-holy-iv-chastise-chakra',81209,BuiltinConditions.all(nochakra,BuiltinConditions.negate(group))),
  BuiltinConditions.spell('priest-holy-iv-guardian-spirit',47788,BuiltinConditions.all(BuiltinConditions.combat(),friendly,low(.25))),
  BuiltinConditions.spell('priest-holy-iv-divine-hymn',64843,BuiltinConditions.all(BuiltinConditions.combat(),hurt(5,.5))),
  BuiltinConditions.spell('priest-holy-iv-desperate-prayer',19236,health('player','LESSTHAN',.5)),
 },
 rotation={
 block('mop.priest.healer-boundaries','priest-holy-iv-'),
 {id='priest-holy-iv-heal',type='branch',conditions=BuiltinConditions.all(friendly,BuiltinConditions.negate({type='DEAD',unit='target'})),onTrue={
  {id='priest-holy-iv-mode',type='branch',conditions=BuiltinConditions.ownBuff(81206),onTrue={
   BuiltinConditions.spell('priest-holy-iv-sanctuary',88625,aoe),
   BuiltinConditions.spell('priest-holy-iv-raid-renew',139,renew),
   BuiltinConditions.spell('priest-holy-iv-circle',34861,aoe),
   BuiltinConditions.spell('priest-holy-iv-raid-mending',33076,BuiltinConditions.combat()),
   BuiltinConditions.spell('priest-holy-iv-prayer',596,aoe),
   BuiltinConditions.spell('priest-holy-iv-raid-binding',32546,binding),
   BuiltinConditions.spell('priest-holy-iv-raid-flash',2061,BuiltinConditions.any(BuiltinConditions.ownBuff(114255),low(.35))),
  },onFalse={
   BuiltinConditions.spell('priest-holy-iv-renew',139,renew),
   BuiltinConditions.spell('priest-holy-iv-serenity',88625,BuiltinConditions.all(BuiltinConditions.ownBuff(81208),low(.9))),
   BuiltinConditions.spell('priest-holy-iv-mending',33076,BuiltinConditions.combat()),
   BuiltinConditions.spell('priest-holy-iv-greater',2060,BuiltinConditions.any(low(.6),{type='BUFF_STACKS',unit='player',spell=63735,ownbuff=true,operator='GREATERTHANOREQUALS',value=2})),
   BuiltinConditions.spell('priest-holy-iv-heal-spell',2050,low(.9)),
   BuiltinConditions.spell('priest-holy-iv-binding',32546,binding),
   BuiltinConditions.spell('priest-holy-iv-flash',2061,BuiltinConditions.any(BuiltinConditions.ownBuff(114255),low(.35))),
   BuiltinConditions.spell('priest-holy-iv-shield',17,BuiltinConditions.all(low(.25),unshielded)),
   BuiltinConditions.spell('priest-holy-iv-flash-filler',2061,low(.9)),
  }},
  BuiltinConditions.stop('priest-holy-iv-heal-stop'),
 },onFalse={block('mop.priest.holy-damage','priest-holy-iv-dmg-')}},
 }},
}))
