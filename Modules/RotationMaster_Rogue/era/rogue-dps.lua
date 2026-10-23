-- Classic Era Rogue melee DPS, levels 1–60, every spec (the recommended vanilla premade; also
-- Hardcore and Self-Found). wowsims/classic order with Icy Veins and Wowhead: Slice and Dice from
-- one point when missing on a target worth it, refreshed at five in its last three seconds;
-- Improved Expose Armor duty in groups when nobody Sunders; a two-point Eviscerate on a dying
-- target; Eviscerate at five and no builder past five. The builder follows what is known:
-- Ghostly Strike and Hemorrhage outside raids, Backstab when not faced, else Sinister Strike.
-- Shared parts: era/blocks.lua. Left manual: Feint, Sprint, Blind, Sap and positioning; Vanish,
-- Gouge, Preparation, Kidney Shot and racials are listed off.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function points(n)return{type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=n}end
local function lifetime(op,n)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local sliced={type='BUFF',unit='player',spell=5171,anyrank=true,ownbuff=true}
-- A target worth a Slice: an elite or boss, or one above a fifth of its health.
local lasting=any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'},
 {type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.2})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.rogue.dps',revision=1,
 blocks={['era.rogue.boundaries']=1,['era.rogue.opener']=1,['era.rogue.upkeep']=1,['era.rogue.builders']=1,['era.rogue.expose-armor']=1},
 nameKey='Default.Era.Rogue.DPS.Name',descriptionKey='Default.Era.Rogue.DPS.Description',
 applicability={families={'era'},actionContext='player',class='ROGUE',minLevel=1,maxLevel=60},
 tags={'dps','melee','leveling','endgame','wowsims','icy-veins','wowhead'},
 sources={{url='https://github.com/wowsims/classic/tree/7779ebbf79dc7f1341e6ab939b28a3402c9a730a/ui/rogue',title='wowsims/classic: Rogue APLs and presets',reviewedAt='2026-10-23',revision='7779ebbf79dc7f1341e6ab939b28a3402c9a730a'},
 {url='https://www.icy-veins.com/wow-classic/rogue-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Rogue DPS rotation, cooldowns and abilities',reviewedAt='2026-10-23',revision='2024-11-17'},
 {url='https://www.icy-veins.com/wow-classic/classic-rogue-leveling-guide',title='Icy Veins: Classic Rogue leveling guide',reviewedAt='2026-10-23',revision='2024-11-16'},
 {url='https://www.icy-veins.com/wow-classic/sword-rogue-leveling-talent-build-from-1-to-60',title='Icy Veins: Classic Sword Rogue leveling 1-60',reviewedAt='2026-10-23',revision='2026-07-18'},
 {url='https://www.icy-veins.com/wow-classic/subtlety-rogue-leveling-talent-build-from-1-to-60',title='Icy Veins: Classic Subtlety Rogue leveling 1-60',reviewedAt='2026-10-23',revision='2026-07-18'},
 {url='https://www.wowhead.com/classic/guide/classes/rogue/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Rogue DPS rotation, cooldowns and abilities',reviewedAt='2026-10-23',revision='2025-03-20'}},
 body={priority=10,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('era.rogue.upkeep','rogue-')},
 rotation={
 block('era.rogue.boundaries','rogue-'),
 {id='rogue-stealth',type='branch',conditions={type='STEALTHED'},onFalse={},onTrue={block('era.rogue.opener','rogue-stealth-')}},
 spell('rogue-riposte',14251),
 spell('rogue-slice',5171,all(points(1),negate(sliced),lasting)),
 block('era.rogue.expose-armor','rogue-'),
 spell('rogue-slice-refresh',5171,all(points(5),{type='BUFF_REMAIN',unit='player',spell=5171,anyrank=true,ownbuff=true,operator='LESSTHAN',value=3})),
 spell('rogue-kill-shot',2098,all(points(2),lifetime('LESSTHAN',4))),
 {id='rogue-finisher',type='branch',conditions=points(5),onFalse={},onTrue={
  spell('rogue-eviscerate',2098),
  {id='rogue-pool',type='none',suppress_attack=false,conditions={}},
 }},
 {id='rogue-kidney-shot',type='spell',action=408,ranked=false,disabled=true,conditions=all(negate({type='GROUP'}),points(3),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.4})},
 block('era.rogue.builders','rogue-'),
 spell('rogue-sinister',1752),
 }},
}))
