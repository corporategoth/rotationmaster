-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Enhancement Shaman, levels 1–60, dual wield and two-hander (the SoD
-- catch-all). simulator/sod Phase 6 order with Icy Veins' five-stack Maelstrom test: Flame Shock to
-- pull; Earth Shock interrupts; on three engaged enemies Magma, Fire Nova from a fire totem,
-- Chain Lightning at four Maelstrom stacks and Flame Shock; Lava Burst at five stacks; Stormstrike;
-- Lava Lash; Lightning Bolt at five stacks; Flame Shock when it will run; Earth Shock; Molten
-- Blast; Lightning Bolt from range. Reminders: Windfury on the main hand (Rockbiter before),
-- Flametongue on the off hand with Lava Lash (else Windfury), a shield, Spirit of the Alpha,
-- Feral Spirit, Shamanistic Rage, totems, Ancestral Guidance. Shared parts: era/blocks.lua.
-- Left manual: Totemic Projection, dispels and purges.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function maelstrom(n)return{type='BUFF_STACKS',unit='player',spell=408505,operator='GREATERTHANOREQUALS',value=n}end
local function optional(step)step.disabled=true;return step end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function imbue(ids,offhand)local list={};for _,id in ipairs(ids)do list[#list+1]={type='WEAPON_IMBUE',enchant=id,offhand=offhand}end;return{type='OR',value=list}end
local windfury={283,284,525,1669,7569}
local big=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})
local ranged=BuiltinConditions.all({type='BEYOND_MELEE',unit='target'},BuiltinConditions.negate({type='MOVING'}))
local flamed={type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true}
-- An off-hand weapon (by item type, so a shield never asks for an imbue) without its enchant.
local dual=BuiltinConditions.all({type='WEAPON_TYPE',slot='offhand',kind='weapon'},BuiltinConditions.negate({type='WEAPON',offhand=true}))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.shaman.enhancement',revision=6,
 blocks={['era.shaman.manual']=3,['era.shaman.interrupt']=1,['era.shaman.shield']=1,['era.shaman.melee-totems']=1},
 applicability={families={'era'},actionContext='player',class='SHAMAN',rulesets={'season:2'}},
 tags={'dps','melee','leveling','endgame','aoe','season-of-discovery','icy-veins','wowhead'},
 sources={
 {url='https://www.icy-veins.com/wow-classic/enhancement-shaman-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Enhancement Shaman DPS rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
 {url='https://www.icy-veins.com/wow-classic/enhancement-shaman-dps-season-of-discovery-leveling',title='Icy Veins: SoD Enhancement Shaman leveling',reviewedAt='2026-10-23',revision='2026-07-18'},
 {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/shaman/enhancement/dps-talent-builds-runes',title='Wowhead: SoD Enhancement Shaman talents and runes',reviewedAt='2026-10-23',revision='2025-02-15'}},
 body={priority=40,
 cooldowns={
  BuiltinConditions.spell('sod-enh-windfury-weapon',8232,BuiltinConditions.negate(imbue(windfury))),
  BuiltinConditions.spell('sod-enh-rockbiter-weapon',8017,BuiltinConditions.all(BuiltinConditions.negate({type='WEAPON'}),BuiltinConditions.negate(BuiltinConditions.known(8232)))),
  BuiltinConditions.spell('sod-enh-offhand-flametongue',8024,BuiltinConditions.all(dual,rune(408507))),
  BuiltinConditions.spell('sod-enh-offhand-windfury',8232,BuiltinConditions.all(dual,BuiltinConditions.negate(rune(408507)))),
  optional(BuiltinConditions.spell('sod-enh-offhand-windfury-icyveins',8232,dual)),
  block('era.shaman.shield','sod-enh-'),
  BuiltinConditions.spell('sod-enh-spirit-of-the-alpha',408696,BuiltinConditions.all(BuiltinConditions.negate(buff(443320)),BuiltinConditions.negate({type='BUFF',unit='player',spell=408696,ownbuff=true}))),
  BuiltinConditions.spell('sod-enh-feral-spirit',440580,BuiltinConditions.combat()),
  BuiltinConditions.spell('sod-enh-shamanistic-rage',425336,BuiltinConditions.all(BuiltinConditions.combat(),{type='MANAPCT',unit='player',operator='LESSTHANOREQUALS',value=.65})),
  block('era.shaman.melee-totems','sod-enh-'),
  BuiltinConditions.spell('sod-enh-ancestral-guidance',409324,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'})),
 },
 rotation={
 block('era.shaman.manual','sod-enh-'),
 {id='sod-enh-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('sod-enh-pull-flame-shock',8050,BuiltinConditions.all({type='ATTACKABLE',unit='target'},BuiltinConditions.negate({type='COMBAT',unit='target'}))),
  BuiltinConditions.spell('sod-enh-pull-bolt',403,BuiltinConditions.all({type='ATTACKABLE',unit='target'},BuiltinConditions.negate({type='COMBAT',unit='target'}),ranged)),
  {id='sod-enh-pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 {id='sod-enh-no-target',type='stop',suppress_attack=true,conditions=BuiltinConditions.negate({type='ATTACKABLE',unit='target'})},
 block('era.shaman.interrupt','sod-enh-'),
 {id='sod-enh-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  BuiltinConditions.spell('sod-enh-aoe-magma',8190,BuiltinConditions.negate({type='TOTEM',spell=1})),
  BuiltinConditions.spell('sod-enh-aoe-fire-nova',408341,{type='TOTEM',spell=1}),
  BuiltinConditions.spell('sod-enh-aoe-chain-lightning',421,maelstrom(4)),
  BuiltinConditions.spell('sod-enh-aoe-flame-shock',8050,BuiltinConditions.negate(flamed)),
 }},
 BuiltinConditions.spell('sod-enh-lava-burst',408490,maelstrom(5)),
 BuiltinConditions.spell('sod-enh-stormstrike',17364),
 BuiltinConditions.spell('sod-enh-lava-lash',408507),
 BuiltinConditions.spell('sod-enh-maelstrom-bolt',403,maelstrom(5)),
 BuiltinConditions.spell('sod-enh-flame-shock',8050,BuiltinConditions.all(BuiltinConditions.negate(flamed),BuiltinConditions.any(big,{type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.5}))),
 BuiltinConditions.spell('sod-enh-earth-shock',8042),
 BuiltinConditions.spell('sod-enh-molten-blast',425339),
 BuiltinConditions.spell('sod-enh-ranged-bolt',403,ranged),
 }},
}))
