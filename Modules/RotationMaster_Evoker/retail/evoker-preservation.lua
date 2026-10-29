-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Preservation Evoker (reference only, off by default). Ally health, Echo,
-- Reversion, Essence Burst and every cooldown are secret in Midnight combat, RM cannot choose a heal
-- target, and Blizzard ships no Assisted Combat rotation for healers, so this keeps only what the
-- Icy Veins guide asks for outside the healing itself: Blessing of the Bronze and Source of Magic out
-- of combat (utility block), and a damage filler when your target is an enemy (Fire Breath,
-- Disintegrate, Living Flame, Azure Strike on the move).
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.evoker.preservation',revision=6,
 blocks={['retail.evoker.heal-boundaries']=2,['retail.evoker.utility']=2},
 applicability={families={'retail'},actionContext='player',class='EVOKER'},
 tags={'preservation','healer','reference','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow/preservation-evoker-pve-healing-rotation-cooldowns-abilities',title='Icy Veins: Preservation Evoker healing rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12',notes='Healing order kept as reference text only; Disintegrate when nobody needs healing.'},
 },
 body={priority=10,disabled=true,specs={1468},
  cooldowns={BuiltinConditions.block('pres-utility','retail.evoker.utility','pres-')},
  rotation={
   BuiltinConditions.block('pres-boundaries','retail.evoker.heal-boundaries','pres-'),
   BuiltinConditions.spell('pres-moving-azure-strike',362969,{type='MOVING'}),
   BuiltinConditions.spell('pres-fire-breath',357208),
   BuiltinConditions.spell('pres-disintegrate',356995),
   BuiltinConditions.spell('pres-living-flame',361469),
   BuiltinConditions.spell('pres-azure-strike',362969),
  },
 },
}))
