-- Classic Era Restoration Shaman, levels 10–60 (primary tree 3). Icy Veins order on the current
-- friendly target: Healing Wave under Nature's Swiftness, Nature's Swiftness below 30%, Lesser
-- Healing Wave below 40%, Cure Poison / Cure Disease, Chain Heal when three nearby group members
-- are below 85%, Healing Wave below 90%. On a hostile target it fights (leveling): Earth Shock
-- interrupt, Chain Lightning on packs, Flame Shock, Lightning Bolt from range, melee. Reminders:
-- Lightning Shield and Rockbiter solo, Mana Tide in a group, Mana Spring, Strength of Earth and
-- Searing. Shared parts: era/blocks.lua. Left manual: choosing whom to heal, downranking, Tremor
-- and cleansing totems; keeping Healing Way on the tank is listed off (no focus unit on Era).
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function totem(slot)return{type='TOTEM',spell=slot}end
local function target(op,v)return{type='HEALTHPCT',unit='target',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local solo=negate({type='GROUP'})
local big=any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.shaman.restoration',revision=4,
 blocks={['era.shaman.manual']=3,['era.shaman.cures']=1,['era.shaman.healer-damage']=2},
 nameKey='Default.Era.Shaman.Restoration.Name',descriptionKey='Default.Era.Shaman.Restoration.Description',
 applicability={families={'era'},actionContext='player',class='SHAMAN'},
 tags={'healer','leveling','endgame','icy-veins','wowhead'},
 sources={{url='https://www.icy-veins.com/wow-classic/restoration-shaman-healer-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Restoration Shaman healer rotation',reviewedAt='2026-10-23',revision='2024-11-17'},
 {url='https://www.icy-veins.com/wow-classic/restoration-shaman-leveling-guide-1-60',title='Icy Veins: Classic Restoration Shaman leveling 1-60',reviewedAt='2026-10-23',revision='2026-07-18'},
 {url='https://www.wowhead.com/classic/guide/classes/shaman/healer-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Shaman healer rotation and downranking',reviewedAt='2026-10-23',revision='2025-03-20'}},
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=3}}},
 cooldowns={
  spell('resto-lightning-shield',324,all(solo,negate({type='BUFF',unit='player',spell=324,anyrank=true}))),
  spell('resto-rockbiter-weapon',8017,all(solo,negate({type='WEAPON'}))),
  spell('resto-mana-tide',16190,all(combat(),{type='GROUP'},{type='MANAPCT',unit='player',operator='LESSTHAN',value=.6})),
  spell('resto-mana-spring',5675,all(combat(),{type='GROUP'},negate(totem(3)))),
  spell('resto-strength-of-earth',8075,all(combat(),{type='GROUP'},negate(totem(2)))),
  spell('resto-searing-totem',3599,all(combat(),negate(totem(1)),{type='ATTACKABLE',unit='target'},any({type='GROUP'},big))),
 },
 rotation={
 block('era.shaman.manual','resto-'),
 {id='resto-heal',type='branch',conditions={type='FRIENDLY',unit='target'},onTrue={
  spell('resto-swift-wave',331,{type='BUFF',unit='player',spell=16188}),
  spell('resto-natures-swiftness',16188,target('LESSTHAN',.3)),
  spell('resto-lesser-wave',8004,target('LESSTHAN',.4)),
  block('era.shaman.cures','resto-'),
  {id='resto-healing-way',type='spell',action=331,ranked=false,disabled=true,conditions=all(target('LESSTHAN',1),
   any(negate({type='BUFF',unit='target',spell=29203}),{type='BUFF_STACKS',unit='target',spell=29203,operator='LESSTHAN',value=3}))},
  spell('resto-chain-heal',1064,{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=40,healthoperator='LESSTHAN',health=.85,operator='GREATERTHANOREQUALS',value=3}),
  spell('resto-healing-wave',331,target('LESSTHAN',.9)),
  {id='resto-heal-stop',type='stop',suppress_attack=true,conditions={}},
 },onFalse={block('era.shaman.healer-damage','resto-')}},
 }},
}))
