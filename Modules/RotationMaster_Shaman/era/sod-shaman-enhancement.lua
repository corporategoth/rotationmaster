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
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function maelstrom(n)return{type='BUFF_STACKS',unit='player',spell=408505,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function optional(step)step.disabled=true;return step end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function imbue(ids,offhand)local list={};for _,id in ipairs(ids)do list[#list+1]={type='WEAPON_IMBUE',enchant=id,offhand=offhand}end;return{type='OR',value=list}end
local windfury={283,284,525,1669,7569}
local big=any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})
local ranged=all({type='BEYOND_MELEE',unit='target'},negate({type='MOVING'}))
local flamed={type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true}
-- An off-hand weapon (by item type, so a shield never asks for an imbue) without its enchant.
local dual=all({type='WEAPON_TYPE',slot='offhand',kind='weapon'},negate({type='WEAPON',offhand=true}))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.shaman.enhancement',revision=6,
 blocks={['era.shaman.manual']=3,['era.shaman.interrupt']=1,['era.shaman.shield']=1,['era.shaman.melee-totems']=1},
 nameKey="Enhancement (SoD)",descriptionKey="Season of Discovery, levels 1–60 with runes as you engrave them, dual wield or two-hander, and every SoD Shaman no other premade fits; built from simulator Phase 6, Icy Veins and Wowhead. Flame Shock pulls; Earth Shock interrupts. On three or more enemies: Magma, Fire Nova from a fire totem, Chain Lightning at four Maelstrom stacks, Flame Shock. Then Lava Burst at five Maelstrom stacks, Stormstrike, Lava Lash, Lightning Bolt at five stacks, Flame Shock when it will run, Earth Shock, Molten Blast, Lightning Bolt from range. Reminders: Windfury Weapon (Rockbiter before), Flametongue on an off-hand weapon with Lava Lash (else Windfury; never on a shield; an Icy Veins Windfury-both line is listed off), Water or Lightning Shield, Spirit of the Alpha, Feral Spirit, Shamanistic Rage below 65% mana, totems, Ancestral Guidance. Totemic Projection, dispels and purges stay with you.",
 applicability={families={'era'},actionContext='player',class='SHAMAN',rulesets={'season:2'}},
 tags={'dps','melee','leveling','endgame','aoe','season-of-discovery','icy-veins','wowhead'},
 sources={
 {url='https://www.icy-veins.com/wow-classic/enhancement-shaman-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Enhancement Shaman DPS rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
 {url='https://www.icy-veins.com/wow-classic/enhancement-shaman-dps-season-of-discovery-leveling',title='Icy Veins: SoD Enhancement Shaman leveling',reviewedAt='2026-10-23',revision='2026-07-18'},
 {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/shaman/enhancement/dps-talent-builds-runes',title='Wowhead: SoD Enhancement Shaman talents and runes',reviewedAt='2026-10-23',revision='2025-02-15'}},
 body={priority=40,
 cooldowns={
  spell('sod-enh-windfury-weapon',8232,negate(imbue(windfury))),
  spell('sod-enh-rockbiter-weapon',8017,all(negate({type='WEAPON'}),negate(known(8232)))),
  spell('sod-enh-offhand-flametongue',8024,all(dual,rune(408507))),
  spell('sod-enh-offhand-windfury',8232,all(dual,negate(rune(408507)))),
  optional(spell('sod-enh-offhand-windfury-icyveins',8232,dual)),
  block('era.shaman.shield','sod-enh-'),
  spell('sod-enh-spirit-of-the-alpha',408696,all(negate(buff(443320)),negate({type='BUFF',unit='player',spell=408696,ownbuff=true}))),
  spell('sod-enh-feral-spirit',440580,combat()),
  spell('sod-enh-shamanistic-rage',425336,all(combat(),{type='MANAPCT',unit='player',operator='LESSTHANOREQUALS',value=.65})),
  block('era.shaman.melee-totems','sod-enh-'),
  spell('sod-enh-ancestral-guidance',409324,all(combat(),{type='GROUP'})),
 },
 rotation={
 block('era.shaman.manual','sod-enh-'),
 {id='sod-enh-pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('sod-enh-pull-flame-shock',8050,all({type='ATTACKABLE',unit='target'},negate({type='COMBAT',unit='target'}))),
  spell('sod-enh-pull-bolt',403,all({type='ATTACKABLE',unit='target'},negate({type='COMBAT',unit='target'}),ranged)),
  {id='sod-enh-pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 {id='sod-enh-no-target',type='stop',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
 block('era.shaman.interrupt','sod-enh-'),
 {id='sod-enh-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  spell('sod-enh-aoe-magma',8190,negate({type='TOTEM',spell=1})),
  spell('sod-enh-aoe-fire-nova',408341,{type='TOTEM',spell=1}),
  spell('sod-enh-aoe-chain-lightning',421,maelstrom(4)),
  spell('sod-enh-aoe-flame-shock',8050,negate(flamed)),
 }},
 spell('sod-enh-lava-burst',408490,maelstrom(5)),
 spell('sod-enh-stormstrike',17364),
 spell('sod-enh-lava-lash',408507),
 spell('sod-enh-maelstrom-bolt',403,maelstrom(5)),
 spell('sod-enh-flame-shock',8050,all(negate(flamed),any(big,{type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.5}))),
 spell('sod-enh-earth-shock',8042),
 spell('sod-enh-molten-blast',425339),
 spell('sod-enh-ranged-bolt',403,ranged),
 }},
}))
