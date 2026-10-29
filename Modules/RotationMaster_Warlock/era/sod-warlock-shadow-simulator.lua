-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Shadow Warlock, simulator Phase 6 "Drain Soul filler" (alternative premade;
-- same switch, lower priority). For a Soul Siphon build: Drain Soul is the filler at every health
-- and is not protected as a channel, so the next step shows as soon as it is due (clip the channel
-- for it); any other channel (Hellfire, Health Funnel, a channelled Drain Life) is protected. DoTs
-- are refreshed early: Unstable Affliction and Shadowflame with 7.5 seconds left, Agony and
-- Corruption with 6; Haunt; Shadow Bolt only on a Shadow Trance proc; Siphon Life; Life Tap below
-- 10% mana. Same reminders as the recommended SoD Shadow premade (era/blocks.lua).
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function due(id,n)return BuiltinConditions.any(BuiltinConditions.negate(own(id)),{type='DEBUFF_REMAIN',unit='target',spell=id,anyrank=true,owndebuff=true,operator='LESSTHAN',value=n})end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local curses={980,603,1490,17862,704,1714,702,18223}
local others={type='OR',value={}};for i,id in ipairs(curses)do if id~=980 then others.value[#others.value+1]=own(id)end end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.warlock.shadow.simulator',revision=6,
 blocks={['era.warlock.armor']=1,['era.warlock.pets']=1,['era.warlock.safety']=1},
 applicability={families={'era'},actionContext='player',class='WARLOCK',rulesets={'season:2'}},
 tags={'dps','ranged','caster','endgame','season-of-discovery'},
 sources={},
 body={priority=55,disabled=true,
 cooldowns={block('era.warlock.armor','sod-ws-'),block('era.warlock.pets','sod-ws-'),
  BuiltinConditions.spell('sod-ws-pet-life-tap',1454,BuiltinConditions.all(BuiltinConditions.combat(),{type='PET'},{type='MANAPCT',unit='pet',operator='LESSTHAN',value=.3},{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.6})),
  block('era.warlock.safety','sod-ws-')},
 rotation={
 BuiltinConditions.stop('sod-ws-cast',BuiltinConditions.any({type='CASTING',unit='player'},BuiltinConditions.all({type='CHANNELING',unit='player'},BuiltinConditions.negate({type='CHANNELING_SPELL',unit='player',spell=1120})),
  BuiltinConditions.negate(BuiltinConditions.all({type='ATTACKABLE',unit='target'},BuiltinConditions.any(BuiltinConditions.combat(),BuiltinConditions.negate({type='COMBAT',unit='target'}),{type='GROUP'}))))),
 BuiltinConditions.spell('sod-ws-unstable-affliction',427717,due(427717,7.5)),
 BuiltinConditions.spell('sod-ws-drain-life',403677,BuiltinConditions.negate(own(403677))),
 BuiltinConditions.spell('sod-ws-shadowflame',426320,due(426320,7.5)),
 BuiltinConditions.spell('sod-ws-agony',980,BuiltinConditions.all(BuiltinConditions.negate(others),due(980,6))),
 BuiltinConditions.spell('sod-ws-corruption',172,due(172,6)),
 BuiltinConditions.spell('sod-ws-haunt',403501),
 BuiltinConditions.spell('sod-ws-shadow-trance',686,{type='BUFF',unit='player',spell=17941}),
 BuiltinConditions.spell('sod-ws-siphon-life',18265,BuiltinConditions.negate(own(18265))),
 BuiltinConditions.spell('sod-ws-tap',1454,{type='MANAPCT',unit='player',operator='LESSTHAN',value=.1}),
 BuiltinConditions.stop('sod-ws-draining',{type='CHANNELING',unit='player'}),
 BuiltinConditions.spell('sod-ws-drain-soul',1120),
 BuiltinConditions.spell('sod-ws-bolt',686),
 }},
}))
