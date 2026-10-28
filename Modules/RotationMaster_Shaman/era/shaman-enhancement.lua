-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Enhancement Shaman, levels 1–60 (the recommended vanilla premade and the catch-all
-- for every Shaman with no points, a tie or a hybrid leveling build; also Hardcore and Self-Found).
-- Icy Veins order with wowsims' gates: Lightning Bolt pull from range; Earth Shock interrupts; in
-- raids Stormstrike and Frost Shock only (debuff slots); Fire Nova and Magma totems on packs;
-- Stormstrike; Earth Shock into its debuff or to finish; Flame Shock when it will run; Earth
-- Shock with half mana; Lightning Bolt while out of reach. Rockbiter solo, Windfury in dungeons.
-- Shared parts: era/blocks.lua. Left manual: dispels, purges, Tremor and cleansing totems; the
-- Hardcore safety totems, totem twisting and racials are listed off.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function lifetime(op,n)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function optional(step)step.disabled=true;return step end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function imbue(ids)local list={};for _,id in ipairs(ids)do list[#list+1]={type='WEAPON_IMBUE',enchant=id}end;return{type='OR',value=list}end
local rockbiter=imbue({29,6,1,503,1663,683,1664,7568,504})
local dungeon=any({type='INSTANCE',value='party'},{type='INSTANCE',value='raid'})
local big=any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})
local ranged=all({type='BEYOND_MELEE',unit='target'},negate({type='MOVING'}))
local near={type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=2}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.shaman.enhancement',revision=5,
 blocks={['era.shaman.manual']=3,['era.shaman.interrupt']=1,['era.shaman.shield']=1,['era.shaman.self-heal']=1,['era.shaman.melee-totems']=1},
 nameKey='Default.Era.Shaman.Enhancement.Name',descriptionKey='Default.Era.Shaman.Enhancement.Description',
 applicability={families={'era'},actionContext='player',class='SHAMAN'},
 tags={'dps','melee','leveling','endgame','aoe','icy-veins','wowhead','wowsims'},
 sources={{url='https://www.icy-veins.com/wow-classic/enhancement-shaman-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Enhancement Shaman DPS rotation',reviewedAt='2026-10-23',revision='2024-11-17'},
 {url='https://www.icy-veins.com/wow-classic/enhancement-shaman-leveling-guide-1-60',title='Icy Veins: Classic Enhancement Shaman leveling 1-60',reviewedAt='2026-10-23',revision='2026-07-18'},
 {url='https://www.icy-veins.com/wow-classic/hardcore-shaman-class-overview',title='Icy Veins: Hardcore Shaman overview (safety totems)',reviewedAt='2026-10-23',revision='2023-05-19'},
 {url='https://www.wowhead.com/classic/guide/classes/shaman/enhancement/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Enhancement Shaman DPS rotation',reviewedAt='2026-10-23',revision='2023-12-02'},
 {url='https://www.wowhead.com/classic/guide/classes/shaman/enhancement/leveling-tips',title='Wowhead: Classic Enhancement Shaman leveling tips',reviewedAt='2026-10-23',revision='2024-11-20'},
 {url='https://github.com/wowsims/classic/blob/7779ebbf79dc7f1341e6ab939b28a3402c9a730a/ui/enhancement_shaman/apls/default.apl.json',title='wowsims/classic: Enhancement Shaman default APL',reviewedAt='2026-10-23',revision='7779ebbf79dc7f1341e6ab939b28a3402c9a730a'}},
 body={priority=10,
 cooldowns={
  spell('enh-windfury-weapon',8232,all(dungeon,any(negate({type='WEAPON'}),rockbiter))),
  spell('enh-rockbiter-weapon',8017,all(negate({type='WEAPON'}),any(negate(known(8232)),negate(dungeon)))),
  block('era.shaman.shield','enh-'),
  block('era.shaman.melee-totems','enh-'),
  block('era.shaman.self-heal','enh-'),
  optional(spell('enh-stoneclaw',5730,all(combat(),negate({type='GROUP'}),near))),
  optional(spell('enh-earthbind',2484,all(combat(),negate({type='GROUP'}),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5}))),
  optional(spell('enh-twist-windfury',8512,all(combat(),{type='GROUP'},{type='SPELL_HISTORY_TIME',spell=8512,operator='GREATERTHANOREQUALS',value=8.5}))),
  optional(spell('enh-twist-grace',8835,all(combat(),{type='GROUP'},{type='TOTEM_SPELL',spell=8512}))),
  optional(spell('enh-blood-fury',20572,all(combat(),big))),
  optional(spell('enh-berserking',26297,all(combat(),big))),
 },
 rotation={
 block('era.shaman.manual','enh-'),
 {id='enh-pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('enh-pull-bolt',403,all({type='ATTACKABLE',unit='target'},negate({type='COMBAT',unit='target'}),ranged)),
  {id='enh-pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 {id='enh-no-target',type='stop',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
 block('era.shaman.interrupt','enh-'),
 {id='enh-raid',type='branch',conditions={type='INSTANCE',value='raid'},onFalse={},onTrue={
  spell('enh-raid-stormstrike',17364),
  spell('enh-raid-frost-shock',8056),
  {id='enh-raid-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 {id='enh-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  spell('enh-aoe-fire-nova',1535,negate({type='TOTEM_SPELL',spell=1535})),
  spell('enh-aoe-magma',8190,all(negate({type='TOTEM_SPELL',spell=8190}),negate({type='TOTEM_SPELL',spell=1535}))),
 }},
 spell('enh-stormstrike',17364),
 spell('enh-stormstrike-shock',8042,{type='DEBUFF',unit='target',spell=17364,owndebuff=true}),
 spell('enh-finishing-shock',8042,lifetime('LESSTHAN',2)),
 spell('enh-flame-shock',8050,all(negate({type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true}),any(big,{type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.5}))),
 spell('enh-earth-shock',8042,{type='MANAPCT',unit='player',operator='GREATERTHANOREQUALS',value=.5}),
 spell('enh-ranged-bolt',403,ranged),
 }},
}))
