-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Druid Feral, cat and bear, from level 10 when Feral is the primary talent tree. After
-- Icy Veins, Wowhead, Warcraft Tavern and simulator: the form decides cat or bear. Cat keeps Faerie
-- Fire (Feral) up, spends Clearcasting on Shred, finishes from four combo points (Rip outside raids,
-- Ferocious Bite under 63 energy), Rakes outside raids, Shreds from behind and Claws from the front,
-- and powershifts with Furor 5/5. Bear Mauls every swing, Swipes packs and spare rage.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.druid.feral',revision=5,
 blocks={['era.druid.boundaries']=4,['era.druid.upkeep']=1,['era.druid.feral-cooldowns']=2,['era.druid.cat']=1,['era.druid.stealth-opener']=2,
  ['era.druid.cat-builders']=1,['era.druid.powershift']=2,['era.druid.bear']=2,['era.druid.bear-pull']=3,['era.druid.feral-humanoid']=2},
 applicability={families={'era'},actionContext='player',class='DRUID'},
 tags={'leveling','endgame','feral','melee','tank','single-target','aoe','icy-veins','wowhead','warcraft-tavern'},
 sources={
  {url='https://www.icy-veins.com/wow-classic/feral-druid-melee-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Feral Druid DPS rotation',reviewedAt='2026-10-23',revision='2024-11-17'},
  {url='https://www.icy-veins.com/wow-classic/feral-druid-tank-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Feral Druid tank rotation',reviewedAt='2026-10-23',revision='2024-11-17'},
  {url='https://www.icy-veins.com/wow-classic/feral-druid-leveling-talent-build-from-1-to-60',title='Icy Veins: Feral Druid leveling',reviewedAt='2026-10-23',revision='2026-07-18'},
  {url='https://www.wowhead.com/classic/guide/classes/druid/feral/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Feral DPS rotation',reviewedAt='2026-10-23',revision='2023-11-21'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/pve-feral-druid-tank-rotations-cooldowns/',title='Warcraft Tavern: Classic Feral tank',reviewedAt='2026-10-23'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/druid-leveling-guide/',title='Warcraft Tavern: Druid leveling',reviewedAt='2026-10-23'},

 },
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=2}}},
  cooldowns={BuiltinConditions.block('era-feral-upkeep','era.druid.upkeep','era-feral-'),BuiltinConditions.block('era-feral-cooldowns','era.druid.feral-cooldowns','era-feral-')},
  rotation={
   BuiltinConditions.block('era-feral-boundaries','era.druid.boundaries','era-feral-'),
   {id='era-feral-cat',type='branch',conditions=BuiltinConditions.form(768),onFalse={},onTrue={BuiltinConditions.block('era-feral-cat-section','era.druid.cat','era-feral-cat-')}},
   {id='era-feral-bear',type='branch',conditions=BuiltinConditions.any(BuiltinConditions.form(5487),BuiltinConditions.form(9634)),onFalse={},onTrue={BuiltinConditions.block('era-feral-bear-section','era.druid.bear','era-feral-bear-')}},
   BuiltinConditions.block('era-feral-humanoid','era.druid.feral-humanoid','era-feral-'),
  },
 },
}))
