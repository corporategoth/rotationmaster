-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Restoration Shaman, levels 10-90: Icy Veins' order with Wowhead's group block.
-- Selected in the Restoration specialization (264)
-- from level 10 (RM stores MoP rotations per talent group). Heals act on your friendly target (or none); RM cannot choose whom to heal. An
-- attackable target gets the damage filler (Flame Shock, Lava Burst, Elemental Blast, Lightning Bolt), any other
-- enemy target stops. Healing: Greater Healing Wave under Ancestral Swiftness, Healing Surge below 35%, Purify
-- Spirit on Magic or Curses, Unleash Elements then Healing Rain when three nearby allies are hurt, Riptide,
-- Chain Heal for group damage, Greater Healing Wave below 60%, Healing Wave below 90% (Healing Surge below 70%
-- before Healing Wave is learned). Reminders: shields, Earthliving, Earth Shield on your focus, Healing Stream,
-- Mana Tide, Healing Tide, Elemental Mastery / Ancestral Guidance, Spiritwalker's Grace. Ascendance and Spirit
-- Link Totem ship off (raid assignments). Shared parts: mop/blocks.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function hurt(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
local function around(health,n)return{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=40,healthoperator='LESSTHAN',health=health,operator='GREATERTHANOREQUALS',value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local someone=BuiltinConditions.any(hurt(.95),around(.9,1))
local heavy=around(.6,3)
local rain=BuiltinConditions.all({type='SPELL_AVAIL',spell=73920},around(.9,3))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.shaman.restoration',revision=6,
 blocks={['mop.shaman.manual']=3,['mop.shaman.group']=1,['mop.shaman.restoration-upkeep']=1,['mop.shaman.restoration-damage']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='SHAMAN'},
 tags={'restoration','healer','caster','leveling','endgame','icy-veins','wowhead'},
 sources={{url='https://www.icy-veins.com/mists-of-pandaria-classic/restoration-shaman-pve-rotation-cooldowns-abilities',title='Icy Veins: Restoration Shaman rotation (MoP Classic)',reviewedAt='2026-10-23',revision='2025-06-22'},
 {url='https://www.wowhead.com/mop-classic/guide/classes/shaman/restoration/healer-rotation-cooldowns-abilities-pve',title='Wowhead: Restoration Shaman healing (MoP Classic)',reviewedAt='2026-10-23',revision='2026-06-21'},
 {url='https://www.warcrafttavern.com/mop/guides/pve-restoration-shaman-rotation-cooldowns/',title='Warcraft Tavern: Restoration Shaman rotation (MoP)',reviewedAt='2026-10-23'}},
 body={priority=30,specs={264},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.shaman.restoration-upkeep','shaman-resto-'),
  BuiltinConditions.spell('shaman-resto-healing-stream',5394,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='TOTEM',spell=3}),someone)),
  BuiltinConditions.spell('shaman-resto-mana-tide',16190,BuiltinConditions.all(BuiltinConditions.combat(),{type='MANAPCT',unit='player',operator='LESSTHAN',value=.8})),
  BuiltinConditions.spell('shaman-resto-healing-tide',108280,BuiltinConditions.all(BuiltinConditions.combat(),around(.6,5))),
  BuiltinConditions.spell('shaman-resto-elemental-mastery',16166,BuiltinConditions.all(BuiltinConditions.combat(),heavy)),
  BuiltinConditions.spell('shaman-resto-ancestral-guidance',108281,BuiltinConditions.all(BuiltinConditions.combat(),heavy)),
  BuiltinConditions.spell('shaman-resto-ancestral-swiftness',16188,BuiltinConditions.all({type='FRIENDLY',unit='target'},hurt(.35))),
  BuiltinConditions.spell('shaman-resto-spiritwalkers-grace',79206,BuiltinConditions.all(BuiltinConditions.combat(),{type='MOVING'},someone)),
  {id='shaman-resto-ascendance',type='spell',action=114049,ranked=false,disabled=true,conditions=BuiltinConditions.all(BuiltinConditions.combat(),around(.5,5))},
  {id='shaman-resto-spirit-link',type='spell',action=98008,ranked=false,disabled=true,conditions=BuiltinConditions.all(BuiltinConditions.combat(),around(.4,3))},
  block('mop.shaman.group','shaman-resto-'),
 },
 rotation={
 block('mop.shaman.manual','shaman-resto-'),
 {id='shaman-resto-hostile',type='branch',conditions={type='ATTACKABLE',unit='target'},onFalse={},onTrue={
  block('mop.shaman.restoration-damage','shaman-resto-dps-'),
  {id='shaman-resto-dps-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 {id='shaman-resto-enemy',type='stop',suppress_attack=true,conditions={type='ENEMY',unit='target'}},
 BuiltinConditions.spell('shaman-resto-swift-wave',77472,BuiltinConditions.ownBuff(16188)),
 BuiltinConditions.spell('shaman-resto-surge',8004,hurt(.35)),
 BuiltinConditions.spell('shaman-resto-purify',77130,BuiltinConditions.any({type='DISPELLABLE',unit='target',debufftype='Magic'},{type='DISPELLABLE',unit='target',debufftype='Curse'})),
 BuiltinConditions.spell('shaman-resto-unleash',73680,rain),
 BuiltinConditions.spell('shaman-resto-healing-rain',73920,rain),
 BuiltinConditions.spell('shaman-resto-riptide',61295,BuiltinConditions.all(BuiltinConditions.negate({type='BUFF',unit='target',spell=61295,ownbuff=true}),BuiltinConditions.any(hurt(.95),{type='ISSAME',unit='target',otherunit='focus'}))),
 BuiltinConditions.spell('shaman-resto-chain-heal',1064,around(.85,3)),
 BuiltinConditions.spell('shaman-resto-greater-wave',77472,hurt(.6)),
 BuiltinConditions.spell('shaman-resto-wave',331,hurt(.9)),
 BuiltinConditions.spell('shaman-resto-early-surge',8004,BuiltinConditions.all(BuiltinConditions.negate({type='SPELL_KNOWN',spell=331}),hurt(.7))),
 {id='shaman-resto-heal-stop',type='stop',suppress_attack=true,conditions={}},
 }},
}))
