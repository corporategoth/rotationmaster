-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Shadow Priest, Warcraft Tavern order (a player-chosen variant, off by default):
-- Devouring Plague at three Shadow Orbs, Shadow Word: Death below 20%, Mind Blast, Vampiric Touch, Shadow Word:
-- Pain, Mind Spike on Surge of Darkness, the tier-6 talent, Mind Flay. No Mind Flay: Insanity priority and no
-- Mind Blast gate on Devouring Plague. Same switch, boundaries, pull, movement, packs and reminders as the
-- recommended Shadow premade (mop/blocks.lua).
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function dot(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator='LESSTHAN',value=n}end
local function lives(n)return BuiltinConditions.any({type='HEALTHPCT',unit='target',operator='GREATERTHANOREQUALS',value=.35},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=n})end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function far(n)return BuiltinConditions.negate({type='DISTANCE',unit='target',value=n})end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.priest.shadow.warcrafttavern',revision=7,
 blocks={['mop.priest.upkeep']=1,['mop.priest.shadow-shell']=5,['mop.priest.shadow-cooldowns']=2},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='PRIEST'},
 tags={'shadow','dps','caster','leveling','endgame','warcraft-tavern'},
 sources={{url='https://www.warcrafttavern.com/mop/guides/pve-shadow-priest-rotations-cooldowns/',title='Warcraft Tavern: Shadow Priest rotation (MoP Classic)',reviewedAt='2026-10-23'}},
 body={priority=20,disabled=true,specs={258},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.priest.upkeep','priest-'),block('mop.priest.shadow-cooldowns','priest-')},
 rotation={
 block('mop.priest.shadow-shell','priest-'),
 BuiltinConditions.spell('priest-tavern-plague',2944,{type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=3}),
 BuiltinConditions.spell('priest-tavern-death',32379,{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2}),
 BuiltinConditions.spell('priest-tavern-blast',8092),
 BuiltinConditions.spell('priest-tavern-touch',34914,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.negate(dot(34914)),remain(34914,4.5)),lives(8))),
 BuiltinConditions.spell('priest-tavern-pain',589,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.negate(dot(589)),remain(589,3)),lives(6))),
 BuiltinConditions.spell('priest-tavern-surge',73510,BuiltinConditions.ownBuff(87160)),
 BuiltinConditions.spell('priest-tavern-halo',120517,BuiltinConditions.all(far(15),{type='DISTANCE',unit='target',value=30})),
 BuiltinConditions.spell('priest-tavern-cascade',121135,far(10)),
 BuiltinConditions.spell('priest-tavern-divine-star',110744,{type='DISTANCE',unit='target',value=24}),
 BuiltinConditions.spell('priest-tavern-flay',15407),
 {id='priest-tavern-end',type='stop',suppress_attack=true,conditions={}},
 }},
}))
