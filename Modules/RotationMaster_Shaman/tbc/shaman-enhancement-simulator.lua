-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Enhancement, Wowhead and simulator level-70 model: Stormstrike, Fire Nova weave,
-- Flame Shock whenever it is down, Earth Shock as the main shock, Windfury /
-- Grace of Air totem twist. Same catch-all switch as the Icy Veins variant, lower priority.
-- Shared opening/upkeep: Defaults/blocks/shaman.lua. Original priority data, no guide prose.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function windfuryWithin(s)return{type='SPELL_HISTORY_TIME',spell=8512,operator='LESSTHAN',value=s}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.shaman.enhancement.simulator',revision=7,
 blocks={['tbc.shaman.enhancement-upkeep']=2,['tbc.shaman.mainhand-imbue']=1,['tbc.shaman.shield']=1,['tbc.shaman.bloodlust']=1,
  ['tbc.shaman.enhancement-opening']=3,['tbc.shaman.boundaries']=3,['tbc.shaman.interrupt']=1},
 applicability={families={'tbc'},actionContext='player',class='SHAMAN'},
 tags={'endgame','raid','enhancement','melee','single-target','aoe','wowhead'},
 sources={{url='https://www.wowhead.com/tbc/guide/classes/shaman/enhancement/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Enhancement Shaman DPS rotation',reviewedAt='2026-10-23',revision='2026-02-17'},
  },
 body={priority=5,disabled=true,
  cooldowns={
   {id='enh-sim-upkeep',type='block',block='tbc.shaman.enhancement-upkeep',prefix='enh-sim-'},
   {id='enh-sim-windfury-totem',type='spell',action=8512,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='TOTEM_SPELL',spell=8512}),BuiltinConditions.negate(windfuryWithin(8.5)))},
   {id='enh-sim-grace-of-air',type='spell',action=8835,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.combat(),{type='TOTEM_SPELL',spell=8512},BuiltinConditions.negate(windfuryWithin(1)))},
   {id='enh-sim-searing',type='spell',action=3599,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='TOTEM',spell=1}))},
   {id='enh-sim-shamanistic-rage',type='spell',action=30823,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.combat(),{type='MANAPCT',unit='player',operator='LESSTHAN',value=0.4})},
  },
  rotation={
   {id='enh-sim-opening',type='block',block='tbc.shaman.enhancement-opening',prefix='enh-sim-'},
   {id='enh-sim-stormstrike',type='spell',action=17364,ranked=false,conditions={}},
   {id='enh-sim-fire-nova',type='spell',action=1535,ranked=false,conditions=BuiltinConditions.negate({type='TOTEM_SPELL',spell=1535})},
   {id='enh-sim-flame-shock',type='spell',action=8050,ranked=false,conditions=BuiltinConditions.negate({type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true})},
   {id='enh-sim-earth-shock',type='spell',action=8042,ranked=false,conditions={}},
   {id='enh-sim-ranged-bolt',type='spell',action=403,ranked=false,conditions=BuiltinConditions.all({type='BEYOND_MELEE',unit='target'},BuiltinConditions.negate({type='MOVING'}))},
  },
 },
}))
