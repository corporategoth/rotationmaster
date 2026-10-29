-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Druid Feral cat: chosen when Savage Roar is engraved, or Feral is the primary
-- tree with no other legs rune. After Wowhead's SoD decision tree with simulator P5 and Icy Veins:
-- Faerie Fire (Feral), Savage Roar, Swipe (Cat) on four or more, the Mangle debuff, Clearcasting on
-- Shred, Rip at five combo points while Savage Roar lasts, Rake, Shred from behind, powershift.
-- Tiger's Fury and Berserk are reminders. In Bear Form it plays the SoD tank section.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function spell(id,action,conditions,ranked)return{id=id,type='spell',action=action,ranked=ranked or false,conditions=conditions or {}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.druid.feral',revision=6,
 blocks={['era.druid.boundaries']=4,['era.druid.upkeep']=1,['sod.druid.maul']=2,['sod.druid.cat']=2,['era.druid.stealth-opener']=2,
  ['era.druid.cat-builders']=1,['era.druid.powershift']=2,['sod.druid.bear']=2,['era.druid.feral-humanoid']=2},
 applicability={families={'era'},actionContext='player',class='DRUID',rulesets={'season:2'}},
 tags={'season-of-discovery','leveling','endgame','feral','melee','single-target','aoe','wowhead','icy-veins'},
 sources={
  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/druid/feral/dps-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Feral Druid DPS rotation',reviewedAt='2026-10-23',revision='2025-04-07'},

  {url='https://www.icy-veins.com/wow-classic/feral-druid-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Feral Druid DPS rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
 },
 body={priority=130,switch=BuiltinConditions.any(rune(407988),BuiltinConditions.all(BuiltinConditions.negate(rune(409824)),BuiltinConditions.negate(rune(417157)),{type='PRIMARY_TALENT_TREE',tree=2})),
  cooldowns={
   BuiltinConditions.block('sod-feral-upkeep','era.druid.upkeep','sod-feral-'),
   spell('sod-feral-tigers-fury',417045,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.form(768),{type='POWER',unit='player',operator='LESSTHANOREQUALS',value=60}),true),
   spell('sod-feral-berserk',417141,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.ownBuff(417045))),
   BuiltinConditions.block('sod-feral-maul','sod.druid.maul','sod-feral-'),
   spell('sod-feral-innervate',29166,BuiltinConditions.all(BuiltinConditions.combat(),{type='MANAPCT',unit='player',operator='LESSTHAN',value=.3})),
  },
  rotation={
   BuiltinConditions.block('sod-feral-boundaries','era.druid.boundaries','sod-feral-'),
   {id='sod-feral-cat',type='branch',conditions=BuiltinConditions.form(768),onFalse={},onTrue={BuiltinConditions.block('sod-feral-cat-section','sod.druid.cat','sod-feral-cat-')}},
   {id='sod-feral-bear',type='branch',conditions=BuiltinConditions.any(BuiltinConditions.form(5487),BuiltinConditions.form(9634)),onFalse={},onTrue={BuiltinConditions.block('sod-feral-bear-section','sod.druid.bear','sod-feral-bear-')}},
   BuiltinConditions.block('sod-feral-humanoid','era.druid.feral-humanoid','sod-feral-'),
  },
 },
}))
