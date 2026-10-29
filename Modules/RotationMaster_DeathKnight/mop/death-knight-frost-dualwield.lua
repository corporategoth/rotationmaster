-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Frost Death Knight with two one-handed weapons (Masterfrost), levels
-- 55–90, after Icy Veins' rotation with simulator' masterfrost cap guards. Selected in the Frost
-- specialization (251) while the off hand holds a weapon (with a two-hander rm.mop.deathknight.frost
-- takes over). Killing Machine goes to Frost Strike, Howling Blast is the main rune spender,
-- Obliterate spends capped Unholy runes below 77 runic power.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rp(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function rune(kind,op,n)return{type='RUNE',rune=kind,operator=op,value=n}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.deathknight.frost.dualwield',revision=6,
 blocks={['mop.deathknight.boundaries']=3,['mop.deathknight.upkeep']=1,['mop.deathknight.frost-upkeep']=2,['mop.deathknight.frost-open']=2,
  ['mop.deathknight.frost-tail']=1,['mop.deathknight.survival']=1,['mop.deathknight.spread']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DEATHKNIGHT'},
 tags={'frost','single-target','aoe','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/frost-death-knight-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Frost Death Knight rotation (dual-wield)',reviewedAt='2026-10-23',revision='2025-09-23'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/frost-death-knight-leveling',title='Icy Veins: MoP Classic Frost Death Knight leveling',reviewedAt='2026-10-23',revision='2025-09-23'},

  {url='https://www.wowhead.com/mop-classic/guide/classes/death-knight/frost/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Frost Death Knight rotation',reviewedAt='2026-10-23',revision='2025-08-02',notes='Read from a Wayback snapshot; same order.'},
 },
 body={priority=30,specs={251},switch={type='WEAPON_TYPE',slot='offhand',kind='weapon'},
  cooldowns={
   BuiltinConditions.block('masterfrost-upkeep','mop.deathknight.frost-upkeep','masterfrost-'),
   BuiltinConditions.block('masterfrost-class','mop.deathknight.upkeep','masterfrost-'),
  },
  rotation={
   BuiltinConditions.block('masterfrost-boundaries','mop.deathknight.boundaries','masterfrost-'),
   BuiltinConditions.block('masterfrost-open','mop.deathknight.frost-open','masterfrost-'),
   BuiltinConditions.spell('masterfrost-strike-km',49143,BuiltinConditions.any(BuiltinConditions.buff(51124),rp('GREATERTHANOREQUALS',89))),
   BuiltinConditions.spell('masterfrost-howling-capped',49184,BuiltinConditions.any(rune(2,'EQUALS',2),rune(4,'EQUALS',2),BuiltinConditions.buff(59052))),
   BuiltinConditions.spell('masterfrost-obliterate-capped',49020,BuiltinConditions.all(rune(3,'EQUALS',2),rp('LESSTHANOREQUALS',76))),
   BuiltinConditions.spell('masterfrost-strike-cap',49143,rp('GREATERTHANOREQUALS',76)),
   BuiltinConditions.spell('masterfrost-obliterate',49020,BuiltinConditions.all(rune(3,'GREATERTHANOREQUALS',1),rp('LESSTHAN',77))),
   BuiltinConditions.spell('masterfrost-howling-blast',49184),
   BuiltinConditions.block('masterfrost-tail','mop.deathknight.frost-tail','masterfrost-'),
  },
 },
}))
