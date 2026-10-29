-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Retribution, levels 1-60, and the default for any Paladin no other premade fits
-- (lowest priority). Icy Veins and Wowhead with Warcraft Tavern: Judgement of the Crusader once on
-- long fights, Seal of Command with a slow weapon else Righteousness, Exorcism and Holy Wrath on
-- Undead and Demons, Hammer of Wrath, Judgement on cooldown, Consecration with Vengeance or packs.
-- Adapts by learned spell (Exorcism 20, Consecration 20, Hammer of Wrath 44, Holy Wrath 50).
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.paladin.retribution',revision=5,
 blocks={['era.paladin.ret-upkeep']=2,['era.paladin.safety']=1,['era.paladin.melee-opening']=3,
  ['era.paladin.crusader-opener']=1,['era.paladin.seal']=2,['era.paladin.undead']=1},
 applicability={families={'era'},actionContext='player',class='PALADIN'},
 tags={'leveling','endgame','retribution','melee','single-target','icy-veins','wowhead','warcraft-tavern'},
 sources={{url='https://www.icy-veins.com/wow-classic/retribution-paladin-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Retribution Paladin rotation',reviewedAt='2026-10-23',revision='2024-11-18'},
  {url='https://www.icy-veins.com/wow-classic/retribution-paladin-leveling-talent-build-from-1-to-60',title='Icy Veins: Retribution Paladin leveling 1-60',reviewedAt='2026-10-23',revision='2026-07-18'},
  {url='https://www.icy-veins.com/wow-classic/classic-paladin-leveling-guide',title='Icy Veins: Classic Paladin leveling guide',reviewedAt='2026-10-23',revision='2024-11-18'},
  {url='https://www.icy-veins.com/wow-classic/hardcore-paladin-class-overview',title='Icy Veins: Hardcore Paladin overview',reviewedAt='2026-10-23',revision='2023-05-21',notes='Divine Shield and Forbearance safety reminders.'},
  {url='https://www.wowhead.com/classic/guide/classes/paladin/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Retribution Paladin rotation',reviewedAt='2026-10-23',revision='2025-03-20'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/pve-retribution-paladin-rotations-cooldowns/',title='Warcraft Tavern: Classic Retribution Paladin rotations',reviewedAt='2026-10-23'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/paladin-leveling-guide/',title='Warcraft Tavern: Classic Paladin leveling guide',reviewedAt='2026-10-23'}},
 body={priority=2,
  cooldowns={BuiltinConditions.block('ret-upkeep','era.paladin.ret-upkeep','ret-'),BuiltinConditions.block('ret-safety','era.paladin.safety','ret-')},
  rotation={
   BuiltinConditions.block('ret-opening','era.paladin.melee-opening','ret-'),
   BuiltinConditions.block('ret-crusader','era.paladin.crusader-opener','ret-'),
   BuiltinConditions.block('ret-seal','era.paladin.seal','ret-'),
   {id='ret-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell('ret-pull-judgement',20271),
    {id='ret-pull-stop',type='stop',conditions={}},
   }},
   BuiltinConditions.block('ret-undead','era.paladin.undead','ret-'),
   BuiltinConditions.spell('ret-hammer-of-wrath',24275,mana('GREATERTHANOREQUALS',0.2)),
   BuiltinConditions.spell('ret-judgement',20271,mana('GREATERTHANOREQUALS',0.15)),
   BuiltinConditions.spell('ret-consecration',26573,BuiltinConditions.all(mana('GREATERTHANOREQUALS',0.3),BuiltinConditions.any(own(20050),{type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=2}))),
  },
 },
}))
