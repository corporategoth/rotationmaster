-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Protection Paladin, Wowhead: a reference, disabled by default. Judgment on
-- cooldown, Shield of the Righteous, Avenger's Shield, Divine Toll, Blessed Hammer or Hammer of the
-- Righteous, and Consecration only as the filler. Health is secret on Retail, so Word of Glory below
-- half health is left to you. Divine Toll only at 0 Holy Power, as Wowhead says (Holy Power
-- is never secret for the player in Midnight).
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.paladin.protection.wowhead',revision=7,
 blocks={['retail.paladin.boundaries']=2,['retail.paladin.upkeep']=2,['retail.paladin.prot-defensives']=2,['retail.paladin.prot-cooldowns']=1},
 applicability={families={'retail'},actionContext='player',class='PALADIN'},
 tags={'protection','tank','reference','single-target','aoe','wowhead'},
 sources={
  {url='https://www.wowhead.com/guide/classes/paladin/protection/rotation-cooldowns-pve-tank',title='Wowhead: Protection Paladin rotation (Season 2)',reviewedAt='2026-10-23',revision='2026-08-12',notes='Divine Toll at 0 Holy Power.'},
 },
 body={priority=4,disabled=true,specs={66},
  cooldowns={
   block('retail.paladin.upkeep','protwh-'),
   block('retail.paladin.prot-cooldowns','protwh-'),
   block('retail.paladin.prot-defensives','protwh-'),
  },
  rotation={
   block('retail.paladin.boundaries','protwh-'),
   BuiltinConditions.spell('protwh-judgment',275779),
   BuiltinConditions.spell('protwh-shield-of-the-righteous',53600),
   BuiltinConditions.spell('protwh-avengers-shield',31935),
   BuiltinConditions.spell('protwh-divine-toll',375576,{type='POINT',unit='player',operator='EQUALS',value=0}),
   BuiltinConditions.spell('protwh-blessed-hammer',204019),
   BuiltinConditions.spell('protwh-hammer-of-the-righteous',53595),
   BuiltinConditions.spell('protwh-consecration',26573),
  },
 },
}))
