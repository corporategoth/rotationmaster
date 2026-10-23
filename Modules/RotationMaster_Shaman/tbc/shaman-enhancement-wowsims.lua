-- Enhancement, Wowhead and wowsims level-70 model: Stormstrike, Fire Nova weave,
-- Flame Shock whenever it is down, Earth Shock as the main shock, Windfury /
-- Grace of Air totem twist. Same catch-all switch as the Icy Veins variant, lower priority.
-- Shared opening/upkeep: Defaults/blocks/shaman.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function windfuryWithin(s)return{type='SPELL_HISTORY_TIME',spell=8512,operator='LESSTHAN',value=s}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.shaman.enhancement.wowsims',revision=2,
 blocks={['tbc.shaman.enhancement-upkeep']=2,['tbc.shaman.mainhand-imbue']=1,['tbc.shaman.shield']=1,['tbc.shaman.bloodlust']=1,
  ['tbc.shaman.enhancement-opening']=1,['tbc.shaman.boundaries']=1,['tbc.shaman.interrupt']=1},
 nameKey='Default.TBC.Shaman.Enhancement.Wowsims.Name',descriptionKey='Default.TBC.Shaman.Enhancement.Wowsims.Description',
 applicability={families={'tbc'},actionContext='player',class='SHAMAN',minLevel=1,maxLevel=70},
 tags={'endgame','raid','enhancement','melee','single-target','aoe','wowhead','wowsims'},
 sources={{url='https://www.wowhead.com/tbc/guide/classes/shaman/enhancement/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Enhancement Shaman DPS rotation',reviewedAt='2026-10-23',revision='2026-02-17'},
  {url='https://github.com/wowsims/tbc/blob/3301fca59306a747e521274c36e073e69acc7b77/sim/shaman/enhancement/rotation.go',title='wowsims/tbc Enhancement rotation',reviewedAt='2026-10-23',revision='3301fca59306a747e521274c36e073e69acc7b77'}},
 body={priority=5,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   {id='enh-sim-upkeep',type='block',block='tbc.shaman.enhancement-upkeep',prefix='enh-sim-'},
   {id='enh-sim-windfury-totem',type='spell',action=8512,ranked=false,conditions=all(combat(),negate({type='TOTEM_SPELL',spell=8512}),negate(windfuryWithin(8.5)))},
   {id='enh-sim-grace-of-air',type='spell',action=8835,ranked=false,conditions=all(combat(),{type='TOTEM_SPELL',spell=8512},negate(windfuryWithin(1)))},
   {id='enh-sim-searing',type='spell',action=3599,ranked=false,conditions=all(combat(),negate({type='TOTEM',spell=1}))},
   {id='enh-sim-shamanistic-rage',type='spell',action=30823,ranked=false,conditions=all(combat(),{type='MANAPCT',unit='player',operator='LESSTHAN',value=0.4})},
  },
  rotation={
   {id='enh-sim-opening',type='block',block='tbc.shaman.enhancement-opening',prefix='enh-sim-'},
   {id='enh-sim-stormstrike',type='spell',action=17364,ranked=false,conditions={}},
   {id='enh-sim-fire-nova',type='spell',action=1535,ranked=false,conditions=negate({type='TOTEM_SPELL',spell=1535})},
   {id='enh-sim-flame-shock',type='spell',action=8050,ranked=false,conditions=negate({type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true})},
   {id='enh-sim-earth-shock',type='spell',action=8042,ranked=false,conditions={}},
   {id='enh-sim-ranged-bolt',type='spell',action=403,ranked=false,conditions=all({type='BEYOND_MELEE',unit='target'},negate({type='MOVING'}))},
  },
 },
}))
