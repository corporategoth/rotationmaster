-- Mists of Pandaria Classic Restoration Shaman, Hekili ladder variant (player-chosen, off by default, low
-- value). Same switch as the recommended premade (Restoration specialization). Keeps Riptide on the target, Healing Stream
-- and Healing Rain up whenever they are down (Rain is assumed down 10 s after you cast it), then heals by the
-- group's average health within 40 yd: Chain Heal below 80%, Healing Wave on a target below 70%, Greater
-- Healing Wave below 60%, Healing Surge below 40%; Healing Tide, Ancestral Guidance and Mana Tide by the same
-- ladder. An attackable target gets the damage filler plus Earth Shock. Shared parts: mop/blocks.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function hurt(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
local function group(v)return{type='PROXIMITY_HEALTHPCT',unit='player',operation='average',distance=40,operator='LESSTHAN',value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.shaman.restoration.hekili',revision=4,
 blocks={['mop.shaman.manual']=3,['mop.shaman.group']=1,['mop.shaman.restoration-upkeep']=1,['mop.shaman.restoration-damage']=1},
 nameKey='Default.MoP.Shaman.Restoration.Hekili.Name',descriptionKey='Default.MoP.Shaman.Restoration.Hekili.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='SHAMAN'},
 tags={'restoration','healer','caster','endgame','hekili'},
 sources={{url='https://github.com/Smufrik/Hekili/blob/0750b5dd98005481baf828cce26149b9abca875b/MistsOfPandaria/Priorities/ShamanRestoration.simc',title='Hekili (MoP fork): Restoration Shaman priority',reviewedAt='2026-10-23',revision='0750b5dd98005481baf828cce26149b9abca875b'}},
 body={priority=20,disabled=true,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='SPECIALIZATION',spec=264}}},
 cooldowns={block('mop.shaman.restoration-upkeep','shaman-resto-hk-'),
  spell('shaman-resto-hk-healing-stream',5394,all(combat(),negate({type='TOTEM',spell=3}))),
  spell('shaman-resto-hk-spiritwalkers-grace',79206,all(combat(),{type='MOVING'})),
  spell('shaman-resto-hk-ancestral-swiftness',16188,combat()),
  spell('shaman-resto-hk-healing-tide',108280,all(combat(),group(.25))),
  {id='shaman-resto-hk-ascendance',type='spell',action=114049,ranked=false,disabled=true,conditions=all(combat(),group(.25))},
  spell('shaman-resto-hk-ancestral-guidance',108281,all(combat(),group(.4))),
  spell('shaman-resto-hk-mana-tide',16190,all(combat(),{type='MANAPCT',unit='player',operator='LESSTHAN',value=.7})),
  block('mop.shaman.group','shaman-resto-hk-'),
 },
 rotation={
 block('mop.shaman.manual','shaman-resto-hk-'),
 {id='shaman-resto-hk-hostile',type='branch',conditions={type='ATTACKABLE',unit='target'},onFalse={},onTrue={
  block('mop.shaman.restoration-damage','shaman-resto-hk-dps-'),
  spell('shaman-resto-hk-earth-shock',8042),
  {id='shaman-resto-hk-dps-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 {id='shaman-resto-hk-enemy',type='stop',suppress_attack=true,conditions={type='ENEMY',unit='target'}},
 spell('shaman-resto-hk-earth-shield',974,negate({type='BUFF',unit='target',spell=974,ownbuff=true})),
 spell('shaman-resto-hk-riptide',61295,negate({type='BUFF',unit='target',spell=61295,ownbuff=true})),
 spell('shaman-resto-hk-healing-rain',73920,all(combat(),negate({type='SPELL_HISTORY_TIME',spell=73920,operator='LESSTHAN',value=10}))),
 spell('shaman-resto-hk-swift-wave',77472,own(16188)),
 spell('shaman-resto-hk-unleash',73680,combat()),
 spell('shaman-resto-hk-chain-heal',1064,group(.8)),
 spell('shaman-resto-hk-wave',331,hurt(.7)),
 spell('shaman-resto-hk-greater-wave',77472,hurt(.6)),
 spell('shaman-resto-hk-surge',8004,hurt(.4)),
 {id='shaman-resto-hk-heal-stop',type='stop',suppress_attack=true,conditions={}},
 }},
}))
