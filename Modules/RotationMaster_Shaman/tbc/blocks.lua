-- Shared TBC Shaman blocks (Built In composition; authoring-time only).
-- Consumers: rm.tbc.shaman.enhancement.*, rm.tbc.shaman.elemental.* and
-- rm.tbc.shaman.restoration. A content change needs a revision bump, every
-- consumer's `blocks` pin and revision bumped, and ledger rows in
-- tests/fixtures/builtin_composition_ledger.lua. Policy and sources are the consumers'.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function solo()return negate({type='GROUP'})end
local function totem(slot)return{type='TOTEM',spell=slot}end -- 1 fire, 2 earth, 3 water, 4 air
local function enemies(n,yards)return{type='DISTANCE_COUNT',enemy=true,distance=yards,operator='GREATERTHANOREQUALS',value=n}end
local function boss()return all({type='GROUP'},{type='CLASSIFICATION',unit='target',value='worldboss'})end
local function shaman(id,steps,revision)assert(addon:RegisterDefaultBlock({id=id,revision=revision or 1,families={'tbc'},class='SHAMAN',steps=steps}))end
-- Casts, channels and Ghost Wolf halt advice and implicit Attack.
shaman('tbc.shaman.boundaries',{
 {id='casting',type='none',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
 {id='ghost-wolf',type='none',suppress_attack=true,conditions=own(2645)},
})
-- Every source interrupts with Earth Shock.
shaman('tbc.shaman.interrupt',{
 {id='interrupt',type='spell',action=8042,ranked=false,conditions=any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})},
})
-- Water Shield once learned, else Lightning Shield; either shield already up is respected.
shaman('tbc.shaman.shield',{
 {id='water-shield',type='spell',action=24398,ranked=false,conditions=all(negate(own(24398)),negate(own(324)))},
 {id='lightning-shield',type='spell',action=324,ranked=false,conditions=all(negate(known(24398)),negate(own(324)))},
})
-- Learned Windfury owns the main hand; any enchant already there is respected.
shaman('tbc.shaman.mainhand-imbue',{
 {id='windfury-weapon',type='spell',action=8232,ranked=false,conditions=negate({type='WEAPON',offhand=false})},
 {id='rockbiter-weapon',type='spell',action=8017,ranked=false,conditions=all(negate(known(8232)),negate({type='WEAPON',offhand=false}))},
})
shaman('tbc.shaman.bloodlust',{
 {id='bloodlust',type='spell',action=2825,ranked=false,conditions=all(combat(),boss())},
 {id='heroism',type='spell',action=32182,ranked=false,conditions=all(combat(),boss())},
})
-- Enhancement upkeep both Enhancement sources agree on; Windfury goes on an off-hand weapon too (read by
-- item type, so a shield never asks for it).
shaman('tbc.shaman.enhancement-upkeep',{
 {id='mainhand',type='block',block='tbc.shaman.mainhand-imbue'},
 {id='offhand-windfury',type='spell',action=8232,ranked=false,conditions=all({type='WEAPON_TYPE',slot='offhand',kind='weapon'},negate({type='WEAPON',offhand=true}))},
 {id='shield',type='block',block='tbc.shaman.shield'},
 {id='strength-of-earth',type='spell',action=8075,ranked=false,conditions=all(combat(),negate(totem(2)))},
 {id='mana-spring',type='spell',action=5675,ranked=false,conditions=all(combat(),{type='GROUP'},negate(totem(3)))},
 {id='healing-stream',type='spell',action=5394,ranked=false,conditions=all(combat(),solo(),negate(totem(3)),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=30})},
 {id='stoneclaw',type='spell',action=5730,ranked=false,conditions=all(combat(),solo(),enemies(2,8))},
 {id='earth-elemental',type='spell',action=2062,ranked=false,conditions=all(combat(),solo(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=0.35})},
 {id='lust',type='block',block='tbc.shaman.bloodlust'},
 {id='fire-elemental',type='spell',action=2894,ranked=false,disabled=true,conditions=all(combat(),boss())},
},2)
-- Enhancement opening both sources agree on: protect casts, pull with a ranged
-- Bolt, interrupt, then Fire Nova and Magma for packs.
shaman('tbc.shaman.enhancement-opening',{
 {id='boundaries',type='block',block='tbc.shaman.boundaries'},
 {id='pull',type='branch',conditions=negate(combat()),onFalse={},onTrue={
  {id='pull-bolt',type='spell',action=403,ranked=false,conditions=all({type='ATTACKABLE',unit='target'},negate({type='COMBAT',unit='target'}),{type='BEYOND_MELEE',unit='target'},negate({type='MOVING'}))},
  {id='pull-stop',type='none',conditions={}},
 }},
 {id='no-target',type='none',conditions=negate({type='ATTACKABLE',unit='target'})},
 {id='kick',type='block',block='tbc.shaman.interrupt'},
 {id='aoe-fire-nova',type='spell',action=1535,ranked=false,conditions=all(enemies(3,8),negate({type='TOTEM_SPELL',spell=1535}))},
 {id='aoe-magma',type='spell',action=8190,ranked=false,conditions=all(enemies(3,8),negate({type='TOTEM_SPELL',spell=1535}),negate({type='TOTEM_SPELL',spell=8190}))},
})
-- Elemental opening every Elemental source shares.
shaman('tbc.shaman.elemental-opening',{
 {id='boundaries',type='block',block='tbc.shaman.boundaries'},
 {id='no-target',type='none',conditions=negate({type='ATTACKABLE',unit='target'})},
 {id='kick',type='block',block='tbc.shaman.interrupt'},
})
-- Icy Veins and Wowhead AoE: Fire Nova and Magma only when close, Chain Lightning.
shaman('tbc.shaman.elemental-aoe',{
 {id='fire-nova',type='spell',action=1535,ranked=false,conditions=all(enemies(3,8),negate({type='TOTEM_SPELL',spell=1535}))},
 {id='chain-lightning',type='spell',action=421,ranked=false,conditions=enemies(3,20)},
 {id='magma',type='spell',action=8190,ranked=false,conditions=all(enemies(3,8),negate({type='TOTEM_SPELL',spell=1535}),negate({type='TOTEM_SPELL',spell=8190}))},
})
-- Caster totems (Icy Veins, Wowhead): Totem of Wrath or a long-fight Searing,
-- Wrath of Air, Mana Spring; Totemic Call refunds mana after the fight.
shaman('tbc.shaman.elemental-totems',{
 {id='totem-of-wrath',type='spell',action=30706,ranked=false,conditions=all(combat(),negate(totem(1)))},
 {id='searing',type='spell',action=3599,ranked=false,conditions=all(combat(),negate(known(30706)),negate(totem(1)),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=20})},
 {id='wrath-of-air',type='spell',action=3738,ranked=false,conditions=all(combat(),negate(totem(4)))},
 {id='mana-spring',type='spell',action=5675,ranked=false,conditions=all(combat(),negate(totem(3)),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=30})},
 {id='totemic-call',type='spell',action=36936,ranked=false,conditions=all(negate(combat()),negate({type='ATTACKABLE',unit='target'}),any(totem(1),totem(2),totem(3),totem(4)))},
})
