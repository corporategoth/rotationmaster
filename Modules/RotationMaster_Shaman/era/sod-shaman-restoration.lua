-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Restoration Shaman, levels 10–60 (primary tree 3). Icy Veins order on the
-- current friendly target: Riptide then Lesser Healing Wave below 40%, Cure Poison / Cure
-- Disease, Healing Rain when three nearby group members are below 85%, Chain Heal when two are
-- (at once on a Power Surge proc), Riptide on cooldown below 95% for Tidal Waves, Healing Wave
-- below 90%. On a hostile target it fights. Reminders: Water Shield (Lightning Shield before),
-- Earth Shield on your friendly target or yourself, Shamanistic Rage, Mana Tide, totems.
-- Shared parts: era/blocks.lua. Left manual: choosing whom to heal, Tremor and cleansing totems.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function totem(slot)return{type='TOTEM',spell=slot}end
local function target(op,v)return{type='HEALTHPCT',unit='target',operator=op,value=v}end
local function hurt(n)return{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=40,healthoperator='LESSTHAN',health=.85,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local friendly={type='FRIENDLY',unit='target'}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.shaman.restoration',revision=4,
 blocks={['era.shaman.manual']=3,['era.shaman.shield']=1,['era.shaman.cures']=1,['era.shaman.healer-damage']=2},
 nameKey="Restoration (SoD)",descriptionKey="Season of Discovery Restoration from level 10 (most points in Restoration); built from Icy Veins and Wowhead. On your friendly target: Riptide then Lesser Healing Wave below 40%, Cure Poison or Cure Disease, Healing Rain when three group members near you are below 85%, Chain Heal when two are (at once on a Power Surge proc), Riptide below 95% for Tidal Waves, Healing Wave below 90%. On an enemy it fights. Reminders: Water Shield (Lightning Shield before), Earth Shield on your friendly target or yourself, Shamanistic Rage, Mana Tide, Mana Spring and Strength of Earth. Choosing whom to heal and Tremor or cleansing totems stay with you.",
 applicability={families={'era'},actionContext='player',class='SHAMAN',rulesets={'season:2'}},
 tags={'healer','leveling','endgame','season-of-discovery','icy-veins','wowhead'},
 sources={{url='https://www.icy-veins.com/wow-classic/restoration-shaman-healer-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Restoration Shaman healer rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
 {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/shaman/healer-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Shaman healer rotation',reviewedAt='2026-10-23',revision='2024-09-26'}},
 body={priority=60,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=3}}},
 cooldowns={
  block('era.shaman.shield','sod-resto-'),
  spell('sod-resto-earth-shield',408514,all(friendly,negate({type='BUFF',unit='target',spell=408514,ownbuff=true}))),
  spell('sod-resto-earth-shield-self',408514,all(negate({type='GROUP'}),negate({type='BUFF',unit='player',spell=408514,ownbuff=true}))),
  spell('sod-resto-shamanistic-rage',425336,all(combat(),{type='MANAPCT',unit='player',operator='LESSTHANOREQUALS',value=.6})),
  spell('sod-resto-mana-tide',16190,all(combat(),{type='GROUP'},{type='MANAPCT',unit='player',operator='LESSTHAN',value=.6})),
  spell('sod-resto-mana-spring',5675,all(combat(),{type='GROUP'},negate(totem(3)))),
  spell('sod-resto-strength-of-earth',8075,all(combat(),{type='GROUP'},negate(totem(2)))),
 },
 rotation={
 block('era.shaman.manual','sod-resto-'),
 {id='sod-resto-heal',type='branch',conditions=friendly,onTrue={
  spell('sod-resto-emergency-riptide',408521,target('LESSTHAN',.4)),
  spell('sod-resto-lesser-wave',8004,target('LESSTHAN',.4)),
  block('era.shaman.cures','sod-resto-'),
  spell('sod-resto-healing-rain',415236,hurt(3)),
  spell('sod-resto-chain-heal',1064,any({type='BUFF',unit='player',spell=440285},{type='BUFF',unit='player',spell=468526},hurt(2))),
  spell('sod-resto-riptide',408521,target('LESSTHAN',.95)),
  spell('sod-resto-healing-wave',331,target('LESSTHAN',.9)),
  {id='sod-resto-heal-stop',type='stop',suppress_attack=true,conditions={}},
 },onFalse={block('era.shaman.healer-damage','sod-resto-')}},
 }},
}))
