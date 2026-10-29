-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Druid Balance, levels 1-60, and the default for every Druid no other premade fits
-- (no talent points, a tie, below level 10). After Wowhead (2025), Warcraft Tavern and simulator:
-- Moonfire and Insect Swarm on targets that live, Starfire filler (Wrath before it is learned),
-- Hurricane on packs, Faerie Fire in a group. In Cat or Bear Form it plays the Feral sections.
-- The Icy Veins Starfire-only list is rm.era.druid.balance.icyveins.
local _,addon=...
local function ref(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.druid.balance',revision=5,
 blocks={['era.druid.boundaries']=4,['era.druid.upkeep']=1,['era.druid.caster-cooldowns']=2,['era.druid.feral-cooldowns']=2,['era.druid.forms']=2,
  ['era.druid.cat']=1,['era.druid.stealth-opener']=2,['era.druid.cat-builders']=1,['era.druid.powershift']=2,['era.druid.bear']=2,['era.druid.bear-pull']=3,
  ['era.druid.caster']=2,['era.druid.caster-pull']=3},
 nameKey='Default.Era.Druid.Balance.Name',descriptionKey='Default.Era.Druid.Balance.Description',
 applicability={families={'era'},actionContext='player',class='DRUID'},
 tags={'leveling','endgame','balance','caster','single-target','aoe','wowhead','warcraft-tavern'},
 sources={
  {url='https://www.wowhead.com/classic/guide/classes/druid/balance/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Balance Druid rotation',reviewedAt='2026-10-23',revision='2025-03-20'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/balance-druid-pve-dps/',title='Warcraft Tavern: Classic Balance Druid',reviewedAt='2026-10-23'},
  {url='https://www.icy-veins.com/wow-classic/balance-druid-leveling-talent-build-from-1-to-60',title='Icy Veins: Balance Druid leveling',reviewedAt='2026-10-23',revision='2026-07-18'},

  {url='https://github.com/kaminaris/MaxDps-Druid/tree/0164267887c2efffb3068100a290c4513f961b7f/Specialization/Classic',title='MaxDps-Druid Classic modules',reviewedAt='2026-10-23',revision='0164267'},
 },
 body={priority=2,
  cooldowns={ref('era-balance-upkeep','era.druid.upkeep','era-balance-'),ref('era-balance-caster-cooldowns','era.druid.caster-cooldowns','era-balance-'),
   ref('era-balance-feral','era.druid.feral-cooldowns','era-balance-feral-')},
  rotation={
   ref('era-balance-boundaries','era.druid.boundaries','era-balance-'),
   ref('era-balance-forms','era.druid.forms','era-balance-'),
   ref('era-balance-caster','era.druid.caster','era-balance-'),
  },
 },
}))
