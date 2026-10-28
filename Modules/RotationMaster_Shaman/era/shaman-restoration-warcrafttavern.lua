-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Restoration Shaman, Warcraft Tavern order (alternative premade; same switch, lower
-- priority). Chain Heal is the rotation: Lesser Healing Wave when the target is about to die,
-- otherwise Chain Heal on anyone below 90% (rank 1 at least half the time is yours to pick).
-- Healing Wave is only for an assigned tank healer with Healing Way: listed off. Same cures,
-- damage arm and reminders as the recommended premade (era/blocks.lua).
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function target(op,v)return{type='HEALTHPCT',unit='target',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.shaman.restoration.warcrafttavern',revision=5,
 blocks={['era.shaman.manual']=3,['era.shaman.cures']=1,['era.shaman.healer-damage']=2},
 nameKey='Default.Era.Shaman.Restoration.WarcraftTavern.Name',descriptionKey='Default.Era.Shaman.Restoration.WarcraftTavern.Description',
 applicability={families={'era'},actionContext='player',class='SHAMAN'},
 tags={'healer','endgame','warcraft-tavern'},
 sources={{url='https://www.warcrafttavern.com/wow-classic/guides/pve-restoration-shaman/',title='Warcraft Tavern: Classic PvE Restoration Shaman',reviewedAt='2026-10-23'}},
 body={priority=21,disabled=true,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=3}}},
 cooldowns={
  spell('resto-wt-mana-tide',16190,all(combat(),{type='GROUP'},{type='MANAPCT',unit='player',operator='LESSTHAN',value=.6})),
  spell('resto-wt-mana-spring',5675,all(combat(),{type='GROUP'},negate({type='TOTEM',spell=3}))),
  spell('resto-wt-strength-of-earth',8075,all(combat(),{type='GROUP'},negate({type='TOTEM',spell=2}))),
 },
 rotation={
 block('era.shaman.manual','resto-wt-'),
 {id='resto-wt-heal',type='branch',conditions={type='FRIENDLY',unit='target'},onTrue={
  spell('resto-wt-lesser-wave',8004,target('LESSTHAN',.4)),
  block('era.shaman.cures','resto-wt-'),
  spell('resto-wt-chain-heal',1064,target('LESSTHAN',.9)),
  {id='resto-wt-tank-wave',type='spell',action=331,ranked=false,disabled=true,conditions=target('LESSTHAN',.9)},
  {id='resto-wt-heal-stop',type='stop',suppress_attack=true,conditions={}},
 },onFalse={block('era.shaman.healer-damage','resto-wt-')}},
 }},
}))
