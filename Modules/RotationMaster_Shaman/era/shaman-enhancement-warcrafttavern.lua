-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Enhancement Shaman, Warcraft Tavern order (alternative premade; same catch-all
-- switch at a lower priority). Totems as the recommended premade (era/blocks.lua), then
-- Stormstrike, Flame Shock before any direct shock, Earth Shock while your threat is low and Frost
-- Shock in a group once it is high; Chain Lightning with Magma on packs. Windfury Weapon from the
-- moment it is learned (Rockbiter before). Left manual: dispels, purges and cleansing totems.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local ranged=BuiltinConditions.all({type='BEYOND_MELEE',unit='target'},BuiltinConditions.negate({type='MOVING'}))
local threatening=BuiltinConditions.all({type='GROUP'},{type='THREAT',unit='target',threat=2})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.shaman.enhancement.warcrafttavern',revision=6,
 blocks={['era.shaman.manual']=3,['era.shaman.interrupt']=1,['era.shaman.shield']=1,['era.shaman.self-heal']=1,['era.shaman.melee-totems']=1},
 applicability={families={'era'},actionContext='player',class='SHAMAN'},
 tags={'dps','melee','leveling','endgame','aoe','warcraft-tavern'},
 sources={{url='https://www.warcrafttavern.com/wow-classic/guides/pve-enhancement-shaman/',title='Warcraft Tavern: Classic PvE Enhancement Shaman',reviewedAt='2026-10-23'},
 {url='https://www.warcrafttavern.com/wow-classic/guides/shaman-leveling-guide/',title='Warcraft Tavern: Classic Shaman leveling guide',reviewedAt='2026-10-23'}},
 body={priority=5,disabled=true,
 cooldowns={
  BuiltinConditions.spell('enh-wt-windfury-weapon',8232,BuiltinConditions.negate({type='WEAPON'})),
  BuiltinConditions.spell('enh-wt-rockbiter-weapon',8017,BuiltinConditions.all(BuiltinConditions.negate({type='WEAPON'}),BuiltinConditions.negate(BuiltinConditions.known(8232)))),
  block('era.shaman.shield','enh-wt-'),
  block('era.shaman.melee-totems','enh-wt-'),
  block('era.shaman.self-heal','enh-wt-'),
 },
 rotation={
 block('era.shaman.manual','enh-wt-'),
 {id='enh-wt-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('enh-wt-pull-bolt',403,BuiltinConditions.all({type='ATTACKABLE',unit='target'},BuiltinConditions.negate({type='COMBAT',unit='target'}),ranged)),
  {id='enh-wt-pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 {id='enh-wt-no-target',type='stop',suppress_attack=true,conditions=BuiltinConditions.negate({type='ATTACKABLE',unit='target'})},
 block('era.shaman.interrupt','enh-wt-'),
 {id='enh-wt-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  BuiltinConditions.spell('enh-wt-aoe-magma',8190,BuiltinConditions.negate({type='TOTEM',spell=1})),
  BuiltinConditions.spell('enh-wt-aoe-chain-lightning',421),
 }},
 BuiltinConditions.spell('enh-wt-stormstrike',17364),
 BuiltinConditions.spell('enh-wt-flame-shock',8050,BuiltinConditions.negate({type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true})),
 BuiltinConditions.spell('enh-wt-frost-shock',8056,threatening),
 BuiltinConditions.spell('enh-wt-earth-shock',8042,BuiltinConditions.negate(threatening)),
 BuiltinConditions.spell('enh-wt-ranged-bolt',403,ranged),
 }},
}))
