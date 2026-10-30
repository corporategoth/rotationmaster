-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared TBC Shaman blocks (Built In composition; authoring-time only).
-- Consumers: rm.tbc.shaman.enhancement.*, rm.tbc.shaman.elemental.* and
-- rm.tbc.shaman.restoration. A content change needs a revision bump, every
-- consumer's `blocks` pin and revision bumped, and ledger rows in
-- tests/fixtures/builtin_composition_ledger.lua. Policy and sources are the consumers'.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function solo()return BuiltinConditions.negate({type='GROUP'})end
local function totem(slot)return{type='TOTEM',spell=slot}end -- 1 fire, 2 earth, 3 water, 4 air
local function enemies(n,yards)return{type='DISTANCE_COUNT',enemy=true,distance=yards,operator='GREATERTHANOREQUALS',value=n}end
local function boss()return BuiltinConditions.all({type='GROUP'},{type='CLASSIFICATION',unit='target',value='worldboss'})end
local function shaman(id,steps,revision)assert(addon:RegisterDefaultBlock({id=id,revision=revision or 1,families={'tbc'},class='SHAMAN',steps=steps}))end
-- Casts, channels and Ghost Wolf halt advice and implicit Attack.
shaman('tbc.shaman.boundaries',{
 {id='casting',type='stop',suppress_attack=true,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},own(2645))},
},3)
-- Every source interrupts with Earth Shock.
shaman('tbc.shaman.interrupt',{
 {id='interrupt',type='spell',action=8042,ranked=false,conditions=BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})},
})
-- Water Shield once learned, else Lightning Shield; either shield already up is respected.
shaman('tbc.shaman.shield',{
 {id='water-shield',type='spell',action=24398,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.negate(own(24398)),BuiltinConditions.negate(own(324)))},
 {id='lightning-shield',type='spell',action=324,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(24398)),BuiltinConditions.negate(own(324)))},
})
-- Learned Windfury owns the main hand; any enchant already there is respected.
shaman('tbc.shaman.mainhand-imbue',{
 {id='windfury-weapon',type='spell',action=8232,ranked=false,conditions=BuiltinConditions.negate({type='WEAPON',offhand=false})},
 {id='rockbiter-weapon',type='spell',action=8017,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(8232)),BuiltinConditions.negate({type='WEAPON',offhand=false}))},
})
shaman('tbc.shaman.bloodlust',{
 {id='bloodlust',type='spell',action=2825,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.combat(),boss())},
 {id='heroism',type='spell',action=32182,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.combat(),boss())},
})
-- Enhancement upkeep both Enhancement sources agree on; Windfury goes on an off-hand weapon too (read by
-- item type, so a shield never asks for it).
shaman('tbc.shaman.enhancement-upkeep',{
 {id='mainhand',type='block',block='tbc.shaman.mainhand-imbue'},
 {id='offhand-windfury',type='spell',action=8232,ranked=false,conditions=BuiltinConditions.all({type='WEAPON_TYPE',slot='offhand',kind='weapon'},BuiltinConditions.negate({type='WEAPON',offhand=true}))},
 {id='shield',type='block',block='tbc.shaman.shield'},
 {id='strength-of-earth',type='spell',action=8075,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(totem(2)))},
 {id='mana-spring',type='spell',action=5675,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},BuiltinConditions.negate(totem(3)))},
 {id='healing-stream',type='spell',action=5394,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.combat(),solo(),BuiltinConditions.negate(totem(3)),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=30})},
 {id='stoneclaw',type='spell',action=5730,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.combat(),solo(),enemies(2,8))},
 {id='earth-elemental',type='spell',action=2062,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.combat(),solo(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=0.35})},
 {id='lust',type='block',block='tbc.shaman.bloodlust'},
 {id='fire-elemental',type='spell',action=2894,ranked=false,disabled=true,conditions=BuiltinConditions.all(BuiltinConditions.combat(),boss())},
},2)
-- Enhancement opening both sources agree on: protect casts, pull with a ranged
-- Bolt, interrupt, then Fire Nova and Magma for packs.
shaman('tbc.shaman.enhancement-opening',{
 {id='boundaries',type='block',block='tbc.shaman.boundaries'},
 {id='pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  {id='pull-bolt',type='spell',action=403,ranked=false,conditions=BuiltinConditions.all({type='ATTACKABLE',unit='target'},BuiltinConditions.negate({type='COMBAT',unit='target'}),{type='BEYOND_MELEE',unit='target'},BuiltinConditions.negate({type='MOVING'}))},
  {id='pull-stop',type='stop',conditions={}},
 }},
 {id='no-target',type='stop',conditions=BuiltinConditions.negate({type='ATTACKABLE',unit='target'})},
 {id='kick',type='block',block='tbc.shaman.interrupt'},
 {id='aoe-fire-nova',type='spell',action=1535,ranked=false,conditions=BuiltinConditions.all(enemies(3,8),BuiltinConditions.negate({type='TOTEM_SPELL',spell=1535}))},
 {id='aoe-magma',type='spell',action=8190,ranked=false,conditions=BuiltinConditions.all(enemies(3,8),BuiltinConditions.negate({type='TOTEM_SPELL',spell=1535}),BuiltinConditions.negate({type='TOTEM_SPELL',spell=8190}))},
},3)
-- Elemental opening every Elemental source shares.
shaman('tbc.shaman.elemental-opening',{
 {id='boundaries',type='block',block='tbc.shaman.boundaries'},
 {id='no-target',type='stop',conditions=BuiltinConditions.negate({type='ATTACKABLE',unit='target'})},
 {id='kick',type='block',block='tbc.shaman.interrupt'},
},2)
-- Icy Veins and Wowhead AoE: Fire Nova and Magma only when close, Chain Lightning.
shaman('tbc.shaman.elemental-aoe',{
 {id='fire-nova',type='spell',action=1535,ranked=false,conditions=BuiltinConditions.all(enemies(3,8),BuiltinConditions.negate({type='TOTEM_SPELL',spell=1535}))},
 {id='chain-lightning',type='spell',action=421,ranked=false,conditions=enemies(3,20)},
 {id='magma',type='spell',action=8190,ranked=false,conditions=BuiltinConditions.all(enemies(3,8),BuiltinConditions.negate({type='TOTEM_SPELL',spell=1535}),BuiltinConditions.negate({type='TOTEM_SPELL',spell=8190}))},
})
-- Caster totems (Icy Veins, Wowhead): Totem of Wrath or a long-fight Searing,
-- Wrath of Air, Mana Spring; Totemic Call refunds mana after the fight.
shaman('tbc.shaman.elemental-totems',{
 {id='totem-of-wrath',type='spell',action=30706,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(totem(1)))},
 {id='searing',type='spell',action=3599,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(BuiltinConditions.known(30706)),BuiltinConditions.negate(totem(1)),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=20})},
 {id='wrath-of-air',type='spell',action=3738,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(totem(4)))},
 {id='mana-spring',type='spell',action=5675,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(totem(3)),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=30})},
 {id='totemic-call',type='spell',action=36936,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate({type='ATTACKABLE',unit='target'}),BuiltinConditions.any(totem(1),totem(2),totem(3),totem(4)))},
})
