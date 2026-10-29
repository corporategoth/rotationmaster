-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Destruction Warlock, levels 10-90: the guide consensus order (Warcraft Tavern,
-- Method, wowtbc.gg, Wowhead; Hekili's single-target list matches) with simulator' Backdraft and Immolate
-- refinements. Selected in the Destruction specialization (267)
-- from level 10 (RM stores MoP rotations per talent group). Pre-cast Incinerate. Moving without Kil'jaeden's
-- Cunning: Shadowburn, Conflagrate, Fel Flame. Shadowburn a target about to die. Three or more engaged
-- enemies: Rain of Fire on four, Fire and Brimstone on four with an ember (toggled off again with none),
-- Immolate, Conflagrate, Incinerate. Otherwise Immolate kept up (refreshed early in Dark Soul), Shadowburn
-- below 20% in Dark Soul or at 3.5 embers, Conflagrate at two charges, Chaos Bolt in Dark Soul or at 3.5
-- embers (not on a three-stack Backdraft), Conflagrate without Backdraft, Incinerate with it, Conflagrate,
-- Incinerate. Havoc is a reminder: it needs a second target. Shared parts: mop/blocks.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function dot(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=n}end
local function embers(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function talent(n)return{type='TALENT',layout='grid',value=n}end
local function stop(id)return{id=id,type='stop',suppress_attack=true,conditions={}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local soul=BuiltinConditions.ownBuff(113858)
local backdraft=BuiltinConditions.ownBuff(117828)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.warlock.destruction',revision=7,
 blocks={['mop.warlock.boundaries']=4,['mop.warlock.upkeep']=1,['mop.warlock.pet-felhunter']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='WARLOCK'},
 tags={'destruction','dps','caster','ranged','leveling','endgame','warcraft-tavern','method','wowtbc'},
 sources={{url='https://www.warcrafttavern.com/mop/guides/pve-destruction-warlock-rotations-cooldowns/',title='Warcraft Tavern: Destruction Warlock rotation (MoP)',reviewedAt='2026-10-23'},
 {url='https://www.method.gg/mop-classic/destruction-warlock-class-guide-mop-classic',title='Method: Destruction Warlock guide (MoP Classic)',reviewedAt='2026-10-23',revision='2025-07-23'},
 {url='https://wowtbc.gg/mop/class-guides/destruction-warlock/',title='wowtbc.gg: Destruction Warlock (MoP Classic)',reviewedAt='2026-10-23'},

 {url='https://github.com/Smufrik/Hekili/blob/0750b5dd98005481baf828cce26149b9abca875b/MistsOfPandaria/Priorities/WarlockDestruction.simc',title='Hekili (MoP fork): Destruction Warlock priority',reviewedAt='2026-10-23',revision='0750b5dd98005481baf828cce26149b9abca875b'}},
 body={priority=30,specs={267},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.warlock.upkeep','warlock-'),block('mop.warlock.pet-felhunter','warlock-'),
  BuiltinConditions.spell('warlock-destro-dark-soul',113858,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.negate(soul),{type='SPELL_CHARGES',spell=113858,operator='GREATERTHANOREQUALS',value=2}))),
  BuiltinConditions.spell('warlock-destro-grimoire-felhunter',111897,BuiltinConditions.combat()),
  BuiltinConditions.spell('warlock-destro-havoc',80240,BuiltinConditions.all(BuiltinConditions.combat(),enemies('GREATERTHANOREQUALS',2))),
  BuiltinConditions.spell('warlock-destro-flames-of-xoroth',120451,BuiltinConditions.all(BuiltinConditions.combat(),talent(15),BuiltinConditions.negate({type='BUFF',unit='player',spell=108503}),BuiltinConditions.negate({type='PET'}))),
  BuiltinConditions.spell('warlock-destro-ember-tap',114635,BuiltinConditions.all(BuiltinConditions.combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5})),
 },
 rotation={
 block('mop.warlock.boundaries','warlock-'),
 {id='warlock-destro-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('warlock-destro-pull-incinerate',29722),
  stop('warlock-destro-pull-stop'),
 }},
 {id='warlock-destro-moving',type='branch',conditions=BuiltinConditions.all({type='MOVING'},BuiltinConditions.negate(talent(17))),onFalse={},onTrue={
  BuiltinConditions.spell('warlock-destro-moving-shadowburn',17877),
  BuiltinConditions.spell('warlock-destro-moving-conflagrate',17962),
  BuiltinConditions.spell('warlock-destro-moving-fel-flame',77799),
  stop('warlock-destro-moving-stop'),
 }},
 BuiltinConditions.spell('warlock-destro-snipe',17877,{type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=3}),
 {id='warlock-destro-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',3),onFalse={},onTrue={
  BuiltinConditions.spell('warlock-destro-rain-of-fire',5740,BuiltinConditions.all(enemies('GREATERTHANOREQUALS',4),BuiltinConditions.negate({type='SPELL_HISTORY_TIME',spell=5740,operator='LESSTHAN',value=7}))),
  BuiltinConditions.spell('warlock-destro-brimstone-off',108683,BuiltinConditions.all(BuiltinConditions.ownBuff(108683),embers('LESSTHAN',1))),
  BuiltinConditions.spell('warlock-destro-brimstone',108683,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.ownBuff(108683)),enemies('GREATERTHANOREQUALS',4),embers('GREATERTHANOREQUALS',1))),
  BuiltinConditions.spell('warlock-destro-aoe-immolate',348,BuiltinConditions.negate(dot(348))),
  BuiltinConditions.spell('warlock-destro-aoe-conflagrate',17962),
  BuiltinConditions.spell('warlock-destro-aoe-incinerate',29722),
  stop('warlock-destro-aoe-stop'),
 }},
 BuiltinConditions.spell('warlock-destro-immolate',348,BuiltinConditions.any(BuiltinConditions.negate(dot(348)),remain(348,'LESSTHAN',3),BuiltinConditions.all(soul,remain(348,'LESSTHAN',7.5)))),
 BuiltinConditions.spell('warlock-destro-shadowburn',17877,BuiltinConditions.all({type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2},BuiltinConditions.any(soul,embers('GREATERTHANOREQUALS',3.5)))),
 BuiltinConditions.spell('warlock-destro-conflagrate-capped',17962,{type='SPELL_CHARGES',spell=17962,operator='GREATERTHANOREQUALS',value=2}),
 BuiltinConditions.spell('warlock-destro-chaos-bolt',116858,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.negate(backdraft),{type='BUFF_STACKS',unit='player',spell=117828,ownbuff=true,operator='LESSTHAN',value=3}),
  BuiltinConditions.any(soul,embers('GREATERTHANOREQUALS',3.5)))),
 BuiltinConditions.spell('warlock-destro-conflagrate-fresh',17962,BuiltinConditions.negate(backdraft)),
 BuiltinConditions.spell('warlock-destro-incinerate-backdraft',29722,backdraft),
 BuiltinConditions.spell('warlock-destro-conflagrate',17962),
 BuiltinConditions.spell('warlock-destro-incinerate',29722),
 }},
}))
