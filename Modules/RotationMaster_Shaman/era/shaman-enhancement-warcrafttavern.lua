-- Classic Era Enhancement Shaman, Warcraft Tavern order (alternative premade; same catch-all
-- switch at a lower priority). Totems as the recommended premade (era/blocks.lua), then
-- Stormstrike, Flame Shock before any direct shock, Earth Shock while your threat is low and Frost
-- Shock in a group once it is high; Chain Lightning with Magma on packs. Windfury Weapon from the
-- moment it is learned (Rockbiter before). Left manual: dispels, purges and cleansing totems.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local ranged=all({type='BEYOND_MELEE',unit='target'},negate({type='MOVING'}))
local threatening=all({type='GROUP'},{type='THREAT',unit='target',threat=2})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.shaman.enhancement.warcrafttavern',revision=2,
 blocks={['era.shaman.manual']=1,['era.shaman.interrupt']=1,['era.shaman.shield']=1,['era.shaman.self-heal']=1,['era.shaman.melee-totems']=1},
 nameKey='Default.Era.Shaman.Enhancement.WarcraftTavern.Name',descriptionKey='Default.Era.Shaman.Enhancement.WarcraftTavern.Description',
 applicability={families={'era'},actionContext='player',class='SHAMAN',minLevel=1,maxLevel=60},
 tags={'dps','melee','leveling','endgame','aoe','warcraft-tavern'},
 sources={{url='https://www.warcrafttavern.com/wow-classic/guides/pve-enhancement-shaman/',title='Warcraft Tavern: Classic PvE Enhancement Shaman',reviewedAt='2026-10-23'},
 {url='https://www.warcrafttavern.com/wow-classic/guides/shaman-leveling-guide/',title='Warcraft Tavern: Classic Shaman leveling guide',reviewedAt='2026-10-23'}},
 body={priority=5,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={
  spell('enh-wt-windfury-weapon',8232,negate({type='WEAPON'})),
  spell('enh-wt-rockbiter-weapon',8017,all(negate({type='WEAPON'}),negate(known(8232)))),
  block('era.shaman.shield','enh-wt-'),
  block('era.shaman.melee-totems','enh-wt-'),
  block('era.shaman.self-heal','enh-wt-'),
 },
 rotation={
 block('era.shaman.manual','enh-wt-'),
 {id='enh-wt-pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('enh-wt-pull-bolt',403,all({type='ATTACKABLE',unit='target'},negate({type='COMBAT',unit='target'}),ranged)),
  {id='enh-wt-pull-stop',type='none',suppress_attack=false,conditions={}},
 }},
 {id='enh-wt-no-target',type='none',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
 block('era.shaman.interrupt','enh-wt-'),
 {id='enh-wt-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  spell('enh-wt-aoe-magma',8190,negate({type='TOTEM',spell=1})),
  spell('enh-wt-aoe-chain-lightning',421),
 }},
 spell('enh-wt-stormstrike',17364),
 spell('enh-wt-flame-shock',8050,negate({type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true})),
 spell('enh-wt-frost-shock',8056,threatening),
 spell('enh-wt-earth-shock',8042,negate(threatening)),
 spell('enh-wt-ranged-bolt',403,ranged),
 }},
}))
