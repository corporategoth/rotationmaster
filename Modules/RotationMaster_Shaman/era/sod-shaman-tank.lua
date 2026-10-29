-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Shaman tank (Way of Earth), levels 30–60: chosen when the Way of Earth rune
-- (passive: a tank with Rockbiter and a shield) is engraved. Icy Veins and
-- Wowhead order with simulator' details: Flame Shock to pull; Earth Shock taunts a target that is
-- not on you and interrupts; on two engaged enemies Molten Blast, Flame Shock, Chain Lightning at
-- five Maelstrom stacks or on Power Surge, Fire Nova at five stacks, Magma; Flame Shock kept up;
-- Lava Burst on Power Surge or while Flame Shock lasts; Stormstrike; Earth Shock; Lightning Bolt
-- at five stacks; Molten Blast; Frost Shock. Reminders: Rockbiter, Lightning Shield, Spirit of
-- the Alpha on yourself, Feral Spirit, Shamanistic Rage, totems. Shared parts: era/blocks.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function totem(slot)return{type='TOTEM',spell=slot}end
local function maelstrom(n)return{type='BUFF_STACKS',unit='player',spell=408505,operator='GREATERTHANOREQUALS',value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function imbue(ids)local list={};for _,id in ipairs(ids)do list[#list+1]={type='WEAPON_IMBUE',enchant=id}end;return{type='OR',value=list}end
local rockbiter=imbue({29,6,1,503,1663,683,1664,7568,504})
local flamed={type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true}
local surge={type='BUFF',unit='player',spell=440285}
local group=BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.shaman.tank',revision=6,
 blocks={['era.shaman.manual']=3,['era.shaman.interrupt']=1},
 applicability={families={'era'},actionContext='player',class='SHAMAN',rulesets={'season:2'}},
 tags={'tank','melee','endgame','aoe','season-of-discovery','icy-veins','wowhead','warcraft-tavern'},
 sources={{url='https://www.icy-veins.com/wow-classic/enhancement-shaman-tank-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Enhancement Shaman tank rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
 {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/shaman/tank-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Shaman tank rotation',reviewedAt='2026-10-23',revision='2025-04-07'},

 {url='https://www.warcrafttavern.com/wow-classic/guides/sod-shaman-tank/',title='Warcraft Tavern: SoD Shaman tank (Phase 4)',reviewedAt='2026-10-23'}},
 -- Way of Earth: 408531 is the rune's first taught spell (simulator/exporter), 408680 the same name on Wowhead.
 body={priority=70,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=30},BuiltinConditions.any({type='RUNE_ENGRAVED',spell=408531},{type='RUNE_ENGRAVED',spell=408680})}},
 cooldowns={
  BuiltinConditions.spell('sod-tank-rockbiter',8017,BuiltinConditions.negate(rockbiter)),
  BuiltinConditions.spell('sod-tank-lightning-shield',324,BuiltinConditions.negate({type='BUFF',unit='player',spell=324,anyrank=true})),
  BuiltinConditions.spell('sod-tank-spirit-of-the-alpha',408696,BuiltinConditions.negate({type='BUFF',unit='player',spell=408696,ownbuff=true})),
  BuiltinConditions.spell('sod-tank-feral-spirit',440580,BuiltinConditions.combat()),
  BuiltinConditions.spell('sod-tank-shamanistic-rage',425336,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any({type='MANAPCT',unit='player',operator='LESSTHANOREQUALS',value=.65},{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5}))),
  BuiltinConditions.spell('sod-tank-searing-totem',3599,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(totem(1)),{type='THREAT_COUNT',threat=1,operator='LESSTHAN',value=2})),
  BuiltinConditions.spell('sod-tank-magma-totem',8190,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(totem(1)),{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2})),
  BuiltinConditions.spell('sod-tank-strength-of-earth',8075,BuiltinConditions.all(group,BuiltinConditions.negate(totem(2)))),
  BuiltinConditions.spell('sod-tank-grace-of-air',8835,BuiltinConditions.all(group,BuiltinConditions.negate(totem(4)))),
  BuiltinConditions.spell('sod-tank-mana-spring',5675,BuiltinConditions.all(group,BuiltinConditions.negate(totem(3)))),
 },
 rotation={
 block('era.shaman.manual','sod-tank-'),
 {id='sod-tank-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('sod-tank-pull-flame-shock',8050,BuiltinConditions.all({type='ATTACKABLE',unit='target'},BuiltinConditions.negate({type='COMBAT',unit='target'}))),
  {id='sod-tank-pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 {id='sod-tank-no-target',type='stop',suppress_attack=true,conditions=BuiltinConditions.negate({type='ATTACKABLE',unit='target'})},
 BuiltinConditions.spell('sod-tank-taunt',8042,BuiltinConditions.all(BuiltinConditions.negate({type='ISSAME',unit='targettarget',otherunit='player'}),BuiltinConditions.negate({type='BEYOND_MELEE',unit='target'}))),
 block('era.shaman.interrupt','sod-tank-'),
 {id='sod-tank-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},onFalse={},onTrue={
  BuiltinConditions.spell('sod-tank-aoe-molten-blast',425339),
  BuiltinConditions.spell('sod-tank-aoe-flame-shock',8050,BuiltinConditions.negate(flamed)),
  BuiltinConditions.spell('sod-tank-aoe-chain-lightning',421,BuiltinConditions.any(maelstrom(5),surge)),
  BuiltinConditions.spell('sod-tank-aoe-fire-nova',408341,maelstrom(5)),
 }},
 BuiltinConditions.spell('sod-tank-flame-shock',8050,BuiltinConditions.negate(flamed)),
 BuiltinConditions.spell('sod-tank-lava-burst',408490,BuiltinConditions.any(surge,{type='DEBUFF_REMAIN',unit='target',spell=8050,anyrank=true,owndebuff=true,operator='GREATERTHANOREQUALS',value=4})),
 BuiltinConditions.spell('sod-tank-stormstrike',17364),
 BuiltinConditions.spell('sod-tank-earth-shock',8042),
 BuiltinConditions.spell('sod-tank-maelstrom-bolt',403,maelstrom(5)),
 BuiltinConditions.spell('sod-tank-molten-blast',425339),
 BuiltinConditions.spell('sod-tank-frost-shock',8056,flamed),
 }},
}))
