-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Unholy Death Knight after Icy Veins and Wowhead (optimal reference): ghoul
-- up; Festering Scythe to keep its plague haste; Soul Reaper with Reaping; Putrefy in Dark
-- Transformation; Death Coil (Epidemic on four or more) on Sudden Doom or Forbidden Knowledge;
-- Festering Strike with no Lesser Ghoul charges, Scourge Strike with them; Death Coil. Target health
-- and runic power are secret on Retail, so the execute window and the San'layn runic power spend are
-- left out. Disabled: procs and plagues are secret in Midnight combat.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function debuff(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local ghouls=buff(1254252)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.deathknight.unholy.guide',revision=6,
 blocks={['retail.deathknight.boundaries']=3,['retail.deathknight.utility']=2},
 applicability={families={'retail'},actionContext='player',class='DEATHKNIGHT'},
 tags={'unholy','melee','pet','reference','icy-veins','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow/unholy-death-knight-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Unholy Death Knight rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://www.wowhead.com/guide/classes/death-knight/unholy/rotation-cooldowns-pve-dps',title='Wowhead: Unholy Death Knight rotation (Midnight Season 2)',reviewedAt='2026-10-23',revision='2026-09-05',notes='Read from a Wayback snapshot.'},
 },
 body={priority=10,disabled=true,specs={252},
  cooldowns={
   BuiltinConditions.block('uguide-utility','retail.deathknight.utility','uguide-'),
   BuiltinConditions.spell('uguide-army-of-the-dead',42650,BuiltinConditions.combat()),
   BuiltinConditions.spell('uguide-dark-transformation',1233448,BuiltinConditions.combat()),
   BuiltinConditions.spell('uguide-outbreak',77575,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(debuff(191587)),BuiltinConditions.negate(debuff(1240996)))),
  },
  rotation={
   BuiltinConditions.block('uguide-boundaries','retail.deathknight.boundaries','uguide-'),
   BuiltinConditions.spell('uguide-raise-dead',46584,BuiltinConditions.negate({type='PET'})),
   BuiltinConditions.spell('uguide-festering-scythe',85948,BuiltinConditions.all(buff(458123),BuiltinConditions.any(BuiltinConditions.negate(debuff(1241077)),{type='DEBUFF_REMAIN',unit='target',spell=1241077,owndebuff=true,operator='LESSTHAN',value=5}))),
   BuiltinConditions.spell('uguide-soul-reaper',343294,buff(1242654)),
   BuiltinConditions.spell('uguide-putrefy',1247378,{type='BUFF',unit='pet',spell=1233448}),
   {id='uguide-spend',type='branch',conditions=BuiltinConditions.any(buff(81340),buff(1242223)),onFalse={},onTrue={
    BuiltinConditions.spell('uguide-spend-epidemic',207317,{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=4}),
    BuiltinConditions.spell('uguide-spend-death-coil',47541)}},
   BuiltinConditions.spell('uguide-festering-strike',85948,BuiltinConditions.negate(ghouls)),
   BuiltinConditions.spell('uguide-scourge-strike',55090,ghouls),
   BuiltinConditions.spell('uguide-death-coil',47541),
  },
 },
}))
