-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Shadow Priest, levels 10-90 (the recommended variant): simulator' order with the
-- guides' simplifications. Selected in the Shadow specialization (258) from level 10 (RM stores MoP rotations
-- per talent group, so the switch reads the specialization). Devouring Plague at three Shadow Orbs when Mind Blast is
-- ready or six seconds away; Mind Blast; Shadow Word: Death below 20%; Mind Flay under your Devouring Plague with
-- Solace and Insanity; Shadow Word: Pain and Vampiric Touch refreshed in their last tick on a target that lives;
-- Mind Spike on Surge of Darkness; the tier-6 talent at its range; Mind Flay. Shared parts (boundaries, pull,
-- movement, packs, reminders): mop/blocks.lua. The Warcraft Tavern variant has no Insanity priority.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function dot(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator='LESSTHAN',value=n}end
local function lives(n)return BuiltinConditions.any({type='HEALTHPCT',unit='target',operator='GREATERTHANOREQUALS',value=.35},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=n})end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function far(n)return BuiltinConditions.negate({type='DISTANCE',unit='target',value=n})end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.priest.shadow',revision=8,
 blocks={['mop.priest.upkeep']=1,['mop.priest.shadow-shell']=5,['mop.priest.shadow-cooldowns']=2},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='PRIEST'},
 tags={'shadow','dps','caster','leveling','endgame','icy-veins','method','wowtbc'},
 sources={
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/shadow-priest-pve-rotation-cooldowns-abilities',title='Icy Veins: Shadow Priest rotation (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/shadow-priest-leveling',title='Icy Veins: Shadow Priest leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'},
 {url='https://www.method.gg/mop-classic/shadow-priest-class-guide-mop-classic',title='Method: Shadow Priest guide (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://wowtbc.gg/mop/class-guides/shadow-priest/',title='wowtbc.gg: Shadow Priest (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://github.com/Smufrik/Hekili/blob/0750b5dd98005481baf828cce26149b9abca875b/MistsOfPandaria/Priorities/PriestShadow.simc',title='Hekili (MoP fork): Shadow Priest priority',reviewedAt='2026-10-23',revision='0750b5dd98005481baf828cce26149b9abca875b'}},
 body={priority=30,specs={258},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.priest.upkeep','priest-'),block('mop.priest.shadow-cooldowns','priest-')},
 rotation={
 block('mop.priest.shadow-shell','priest-'),
 BuiltinConditions.spell('priest-shadow-plague',2944,BuiltinConditions.all({type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=3},
  BuiltinConditions.any({type='SPELL_AVAIL',spell=8092},{type='SPELL_COOLDOWN',spell=8092,operator='GREATERTHANOREQUALS',value=6}))),
 BuiltinConditions.spell('priest-shadow-blast',8092),
 BuiltinConditions.spell('priest-shadow-death',32379,{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2}),
 BuiltinConditions.spell('priest-shadow-insanity',15407,BuiltinConditions.all({type='TALENT',layout='grid',value=9},dot(2944))),
 BuiltinConditions.spell('priest-shadow-pain',589,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.negate(dot(589)),remain(589,3)),lives(6))),
 BuiltinConditions.spell('priest-shadow-touch',34914,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.negate(dot(34914)),remain(34914,4.5)),lives(8))),
 BuiltinConditions.spell('priest-shadow-surge',73510,BuiltinConditions.ownBuff(87160)),
 BuiltinConditions.spell('priest-shadow-halo',120517,BuiltinConditions.all(far(15),{type='DISTANCE',unit='target',value=30})),
 BuiltinConditions.spell('priest-shadow-cascade',121135,far(10)),
 BuiltinConditions.spell('priest-shadow-divine-star',110744,{type='DISTANCE',unit='target',value=24}),
 {id='priest-shadow-sear',type='spell',action=48045,ranked=false,disabled=true,conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3}},
 BuiltinConditions.spell('priest-shadow-flay',15407),
 {id='priest-shadow-end',type='stop',suppress_attack=true,conditions={}},
 }},
}))
