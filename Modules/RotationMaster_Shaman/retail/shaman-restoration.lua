-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Restoration Shaman, Icy Veins. Blizzard's Assisted Combat does not cover
-- healers, health is hidden in Midnight combat and RM picks a spell, not a target, so this orders
-- your healing tools by readiness on whatever you target and leaves triage to you. Friendly
-- target: Healing Stream Totem, Unleash Life, Healing Rain and Chain Heal in a group, Surging
-- Totem, Riptide, Healing Wave. Enemy: Flame Shock when missing, Lava Burst, Lightning Bolt.
-- Reminders: Water Shield, Earth Shield on a friendly target and Skyfury between pulls; Nature's
-- Swiftness in combat; Healing Tide and Spirit Link in grouped combat; Wind Shear; Astral Shift.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local friend=BuiltinConditions.all({type='LEVEL',unit='target',operator='GREATERTHAN',value=0},{type='FRIENDLY',unit='target'},BuiltinConditions.negate({type='DEAD',unit='target'}))
local grouped=BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.shaman.restoration',revision=6,
 blocks={['retail.shaman.upkeep']=2},
 applicability={families={'retail'},actionContext='player',class='SHAMAN'},
 tags={'restoration','healer','reference','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow/restoration-shaman-pve-healing-rotation-cooldowns-abilities',title='Icy Veins: Restoration Shaman healing rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
 },
 body={priority=10,specs={264},
  cooldowns={
   block('retail.shaman.upkeep','resto-'),
   BuiltinConditions.spell('resto-water-shield',52127,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate({type='BUFF',unit='player',spell=52127,ownbuff=true}))),
   BuiltinConditions.spell('resto-earth-shield',974,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),friend,BuiltinConditions.negate({type='BUFF',unit='target',spell=974,ownbuff=true}))),
   BuiltinConditions.spell('resto-natures-swiftness',378081,BuiltinConditions.combat()),
   BuiltinConditions.spell('resto-healing-tide',108280,grouped),
   BuiltinConditions.spell('resto-spirit-link',98008,grouped),
  },
  rotation={
   {id='resto-casting',type='stop',suppress_attack=true,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
   {id='resto-friendly',type='branch',conditions=friend,onFalse={},onTrue={
    BuiltinConditions.spell('resto-healing-stream',5394),
    BuiltinConditions.spell('resto-unleash-life',73685),
    BuiltinConditions.spell('resto-healing-rain',73920,{type='GROUP'}),
    BuiltinConditions.spell('resto-surging-totem',444995),
    BuiltinConditions.spell('resto-riptide',61295),
    BuiltinConditions.spell('resto-chain-heal',1064,{type='GROUP'}),
    BuiltinConditions.spell('resto-healing-wave',77472),
    {id='resto-friendly-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   {id='resto-no-target',type='stop',suppress_attack=true,conditions=BuiltinConditions.negate({type='ATTACKABLE',unit='target'})},
   BuiltinConditions.spell('resto-flame-shock',470411,BuiltinConditions.negate({type='DEBUFF',unit='target',spell=188389,owndebuff=true})),
   BuiltinConditions.spell('resto-lava-burst',51505),
   BuiltinConditions.spell('resto-lightning-bolt',188196),
  },
 },
}))
