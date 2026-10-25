-- Enhancement, Icy Veins order: Stormstrike, Earth Shock on its debuff, Flame Shock
-- only on a target that lives (NextActionTBC's 12 s gate), Earth Shock on cooldown.
-- Catch-all Shaman premade (lowest priority): every level, no talents, ties.
-- Shared opening/upkeep: Defaults/blocks/shaman.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function totem(slot)return{type='TOTEM',spell=slot}end
local function ttd(op,s)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=s}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.shaman.enhancement.icyveins',revision=6,
 blocks={['tbc.shaman.enhancement-upkeep']=2,['tbc.shaman.mainhand-imbue']=1,['tbc.shaman.shield']=1,['tbc.shaman.bloodlust']=1,
  ['tbc.shaman.enhancement-opening']=3,['tbc.shaman.boundaries']=3,['tbc.shaman.interrupt']=1},
 nameKey='Default.TBC.Shaman.Enhancement.IcyVeins.Name',descriptionKey='Default.TBC.Shaman.Enhancement.IcyVeins.Description',
 applicability={families={'tbc'},actionContext='player',class='SHAMAN'},
 tags={'leveling','endgame','enhancement','melee','single-target','aoe','icy-veins'},
 sources={{url='https://www.icy-veins.com/tbc-classic/enhancement-shaman-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Enhancement Shaman rotation',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/enhancement-shaman-leveling-guide',title='Icy Veins: Enhancement Shaman leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.curseforge.com/wow/addons/next-action',title='NextActionTBC 1.30.1 Enhancement priority',reviewedAt='2026-10-23',revision='1.30.1',notes='Flame Shock 12-second time-to-die gate only.'}},
 body={priority=10,
  cooldowns={
   {id='enh-icy-upkeep',type='block',block='tbc.shaman.enhancement-upkeep',prefix='enh-icy-'},
   {id='enh-icy-windfury-totem',type='spell',action=8512,ranked=false,conditions=all(combat(),{type='GROUP'},negate(totem(4)))},
   {id='enh-icy-grace-of-air',type='spell',action=8835,ranked=false,conditions=all(combat(),negate({type='GROUP'}),negate(totem(4)))},
   {id='enh-icy-searing',type='spell',action=3599,ranked=false,conditions=all(combat(),negate(totem(1)),ttd('GREATERTHANOREQUALS',20))},
   {id='enh-icy-shamanistic-rage',type='spell',action=30823,ranked=false,conditions=combat()},
  },
  rotation={
   {id='enh-icy-opening',type='block',block='tbc.shaman.enhancement-opening',prefix='enh-icy-'},
   {id='enh-icy-stormstrike',type='spell',action=17364,ranked=false,conditions={}},
   {id='enh-icy-shock-debuff',type='spell',action=8042,ranked=false,conditions={type='DEBUFF',unit='target',spell=17364}},
   {id='enh-icy-flame-shock',type='spell',action=8050,ranked=false,conditions=all(negate({type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true}),negate(ttd('LESSTHAN',12)))},
   {id='enh-icy-earth-shock',type='spell',action=8042,ranked=false,conditions={}},
   {id='enh-icy-ranged-bolt',type='spell',action=403,ranked=false,conditions=all({type='BEYOND_MELEE',unit='target'},negate({type='MOVING'}))},
  },
 },
}))
