-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Holy Priest, levels 10-90 (the recommended variant): Warcraft Tavern's and Icy Veins'
-- order with Hekili's thresholds. Selected in the Holy specialization (257). A friendly
-- target is healed: Holy Word: Serenity in Chakra: Serenity; Power Word: Shield only when the target is about to
-- die; Flash Heal on Surge of Light; Prayer of Mending; Flash Heal when very low; Binding Heal; with three hurt
-- allies in a group Circle of Healing, Holy Word: Sanctuary (in Chakra: Sanctuary; you place it), the tier-6
-- talent and Prayer of Healing; Renew; Greater Heal when low or at two Serendipity; Heal. An empty chakra is filled
-- by group size (Sanctuary in a raid, Serenity in a party, Chastise solo) and never swapped. An enemy target runs
-- the damage arm (mop/blocks.lua). Choosing whom to heal, Lightwell and Void Shift stay with you. The Icy Veins
-- variant puts emergency heals last.
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
local aoe=hurt(3,.85)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.priest.holy',revision=7,
 blocks={['mop.priest.upkeep']=1,['mop.priest.healer-boundaries']=2,['mop.priest.healer-cooldowns']=1,['mop.priest.holy-damage']=2},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='PRIEST'},
 tags={'holy','healer','group','leveling','endgame','warcraft-tavern','icy-veins','hekili'},
 sources={{url='https://www.warcrafttavern.com/mop/guides/pve-holy-priest-rotations-cooldowns/',title='Warcraft Tavern: Holy Priest rotation (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/holy-priest-pve-rotation-cooldowns-abilities',title='Icy Veins: Holy Priest rotation (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/holy-priest-leveling',title='Icy Veins: Holy Priest leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'},
 {url='https://www.method.gg/mop-classic/holy-priest-class-guide-mop-classic',title='Method: Holy Priest guide (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://wowtbc.gg/mop/class-guides/holy-priest/',title='wowtbc.gg: Holy Priest (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://github.com/Smufrik/Hekili/blob/0750b5dd98005481baf828cce26149b9abca875b/MistsOfPandaria/Priorities/PriestHoly.simc',title='Hekili (MoP fork): Holy Priest priority',reviewedAt='2026-10-23',revision='0750b5dd98005481baf828cce26149b9abca875b'}},
 body={priority=30,specs={257},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.priest.upkeep','priest-'),block('mop.priest.healer-cooldowns','priest-'),
  BuiltinConditions.spell('priest-holy-sanctuary-chakra',81206,BuiltinConditions.all(nochakra,{type='GROUP',raid=true})),
  BuiltinConditions.spell('priest-holy-serenity-chakra',81208,BuiltinConditions.all(nochakra,group,BuiltinConditions.negate({type='GROUP',raid=true}))),
  BuiltinConditions.spell('priest-holy-chastise-chakra',81209,BuiltinConditions.all(nochakra,BuiltinConditions.negate(group))),
  BuiltinConditions.spell('priest-holy-guardian-spirit',47788,BuiltinConditions.all(BuiltinConditions.combat(),friendly,low(.25))),
  BuiltinConditions.spell('priest-holy-divine-hymn',64843,BuiltinConditions.all(BuiltinConditions.combat(),hurt(5,.5))),
  BuiltinConditions.spell('priest-holy-desperate-prayer',19236,health('player','LESSTHAN',.5)),
 },
 rotation={
 block('mop.priest.healer-boundaries','priest-holy-'),
 {id='priest-holy-heal',type='branch',conditions=BuiltinConditions.all(friendly,BuiltinConditions.negate({type='DEAD',unit='target'})),onTrue={
  BuiltinConditions.spell('priest-holy-serenity',88625,BuiltinConditions.all(BuiltinConditions.ownBuff(81208),low(.9))),
  BuiltinConditions.spell('priest-holy-shield',17,BuiltinConditions.all(low(.25),unshielded)),
  BuiltinConditions.spell('priest-holy-surge',2061,BuiltinConditions.ownBuff(114255)),
  BuiltinConditions.spell('priest-holy-mending',33076,BuiltinConditions.combat()),
  BuiltinConditions.spell('priest-holy-flash',2061,low(.35)),
  BuiltinConditions.spell('priest-holy-binding',32546,BuiltinConditions.all(health('player','LESSTHAN',.7),low(.7),BuiltinConditions.negate({type='ISSAME',unit='target',otherunit='player'}))),
  {id='priest-holy-group',type='branch',conditions=group,onFalse={},onTrue={
   BuiltinConditions.spell('priest-holy-circle',34861,aoe),
   BuiltinConditions.spell('priest-holy-sanctuary',88625,BuiltinConditions.all(BuiltinConditions.ownBuff(81206),aoe)),
   BuiltinConditions.spell('priest-holy-halo',120517,aoe),
   BuiltinConditions.spell('priest-holy-cascade',121135,aoe),
   BuiltinConditions.spell('priest-holy-divine-star',110744,aoe),
   BuiltinConditions.spell('priest-holy-prayer',596,aoe),
   {id='priest-holy-nova',type='spell',action=132157,ranked=false,disabled=true,conditions=BuiltinConditions.all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},{type='MANAPCT',unit='player',operator='GREATERTHAN',value=.4})},
  }},
  BuiltinConditions.spell('priest-holy-renew',139,BuiltinConditions.all(low(.95),BuiltinConditions.negate({type='BUFF',unit='target',spell=139,ownbuff=true}))),
  BuiltinConditions.spell('priest-holy-greater',2060,BuiltinConditions.any(low(.6),{type='BUFF_STACKS',unit='player',spell=63735,ownbuff=true,operator='GREATERTHANOREQUALS',value=2})),
  BuiltinConditions.spell('priest-holy-heal-spell',2050,low(.9)),
  BuiltinConditions.stop('priest-holy-heal-stop'),
 },onFalse={block('mop.priest.holy-damage','priest-holy-dmg-')}},
 }},
}))
