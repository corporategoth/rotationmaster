-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Enhancement Shaman, levels 1–60 (the recommended vanilla premade and the catch-all
-- for every Shaman with no points, a tie or a hybrid leveling build; also Hardcore and Self-Found).
-- Icy Veins order with simulator' gates: Lightning Bolt pull from range; Earth Shock interrupts; in
-- raids Stormstrike and Frost Shock only (debuff slots); Fire Nova and Magma totems on packs;
-- Stormstrike; Earth Shock into its debuff or to finish; Flame Shock when it will run; Earth
-- Shock with half mana; Lightning Bolt while out of reach. Rockbiter solo, Windfury in dungeons.
-- Shared parts: era/blocks.lua. Left manual: dispels, purges, Tremor and cleansing totems; the
-- Hardcore safety totems, totem twisting and racials are listed off.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function optional(step)step.disabled=true;return step end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function imbue(ids)local list={};for _,id in ipairs(ids)do list[#list+1]={type='WEAPON_IMBUE',enchant=id}end;return{type='OR',value=list}end
local rockbiter=imbue({29,6,1,503,1663,683,1664,7568,504})
local dungeon=BuiltinConditions.any({type='INSTANCE',value='party'},{type='INSTANCE',value='raid'})
local big=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})
local ranged=BuiltinConditions.all({type='BEYOND_MELEE',unit='target'},BuiltinConditions.negate({type='MOVING'}))
local near={type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=2}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.shaman.enhancement',revision=5,
 blocks={['era.shaman.manual']=3,['era.shaman.interrupt']=1,['era.shaman.shield']=1,['era.shaman.self-heal']=1,['era.shaman.melee-totems']=1},
 applicability={families={'era'},actionContext='player',class='SHAMAN'},
 tags={'dps','melee','leveling','endgame','aoe','icy-veins','wowhead'},
 sources={{url='https://www.icy-veins.com/wow-classic/enhancement-shaman-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Enhancement Shaman DPS rotation',reviewedAt='2026-10-23',revision='2024-11-17'},
 {url='https://www.icy-veins.com/wow-classic/enhancement-shaman-leveling-guide-1-60',title='Icy Veins: Classic Enhancement Shaman leveling 1-60',reviewedAt='2026-10-23',revision='2026-07-18'},
 {url='https://www.icy-veins.com/wow-classic/hardcore-shaman-class-overview',title='Icy Veins: Hardcore Shaman overview (safety totems)',reviewedAt='2026-10-23',revision='2023-05-19'},
 {url='https://www.wowhead.com/classic/guide/classes/shaman/enhancement/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Enhancement Shaman DPS rotation',reviewedAt='2026-10-23',revision='2023-12-02'},
 {url='https://www.wowhead.com/classic/guide/classes/shaman/enhancement/leveling-tips',title='Wowhead: Classic Enhancement Shaman leveling tips',reviewedAt='2026-10-23',revision='2024-11-20'},
 },
 body={priority=10,
 cooldowns={
  BuiltinConditions.spell('enh-windfury-weapon',8232,BuiltinConditions.all(dungeon,BuiltinConditions.any(BuiltinConditions.negate({type='WEAPON'}),rockbiter))),
  BuiltinConditions.spell('enh-rockbiter-weapon',8017,BuiltinConditions.all(BuiltinConditions.negate({type='WEAPON'}),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(8232)),BuiltinConditions.negate(dungeon)))),
  block('era.shaman.shield','enh-'),
  block('era.shaman.melee-totems','enh-'),
  block('era.shaman.self-heal','enh-'),
  optional(BuiltinConditions.spell('enh-stoneclaw',5730,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='GROUP'}),near))),
  optional(BuiltinConditions.spell('enh-earthbind',2484,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='GROUP'}),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5}))),
  optional(BuiltinConditions.spell('enh-twist-windfury',8512,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},{type='SPELL_HISTORY_TIME',spell=8512,operator='GREATERTHANOREQUALS',value=8.5}))),
  optional(BuiltinConditions.spell('enh-twist-grace',8835,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},{type='TOTEM_SPELL',spell=8512}))),
  optional(BuiltinConditions.spell('enh-blood-fury',20572,BuiltinConditions.all(BuiltinConditions.combat(),big))),
  optional(BuiltinConditions.spell('enh-berserking',26297,BuiltinConditions.all(BuiltinConditions.combat(),big))),
 },
 rotation={
 block('era.shaman.manual','enh-'),
 {id='enh-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('enh-pull-bolt',403,BuiltinConditions.all({type='ATTACKABLE',unit='target'},BuiltinConditions.negate({type='COMBAT',unit='target'}),ranged)),
  {id='enh-pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 {id='enh-no-target',type='stop',suppress_attack=true,conditions=BuiltinConditions.negate({type='ATTACKABLE',unit='target'})},
 block('era.shaman.interrupt','enh-'),
 {id='enh-raid',type='branch',conditions={type='INSTANCE',value='raid'},onFalse={},onTrue={
  BuiltinConditions.spell('enh-raid-stormstrike',17364),
  BuiltinConditions.spell('enh-raid-frost-shock',8056),
  {id='enh-raid-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 {id='enh-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  BuiltinConditions.spell('enh-aoe-fire-nova',1535,BuiltinConditions.negate({type='TOTEM_SPELL',spell=1535})),
  BuiltinConditions.spell('enh-aoe-magma',8190,BuiltinConditions.all(BuiltinConditions.negate({type='TOTEM_SPELL',spell=8190}),BuiltinConditions.negate({type='TOTEM_SPELL',spell=1535}))),
 }},
 BuiltinConditions.spell('enh-stormstrike',17364),
 BuiltinConditions.spell('enh-stormstrike-shock',8042,{type='DEBUFF',unit='target',spell=17364,owndebuff=true}),
 BuiltinConditions.spell('enh-finishing-shock',8042,BuiltinConditions.lifetime('LESSTHAN',2)),
 BuiltinConditions.spell('enh-flame-shock',8050,BuiltinConditions.all(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true}),BuiltinConditions.any(big,{type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.5}))),
 BuiltinConditions.spell('enh-earth-shock',8042,{type='MANAPCT',unit='player',operator='GREATERTHANOREQUALS',value=.5}),
 BuiltinConditions.spell('enh-ranged-bolt',403,ranged),
 }},
}))
