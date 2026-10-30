-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Mistweaver Monk, Icy Veins reference: Blizzard ships no Assisted Combat
-- list for healers, and ally health, Renewing Mist charges, Mana Tea stacks and procs are secret in
-- Midnight combat, so healing advice is impossible. On a hostile target it suggests the
-- fistweaving filler (Rising Sun Kick, Blackout Kick, Tiger Palm); otherwise nothing. Disabled.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.monk.mistweaver',revision=6,
 blocks={['retail.monk.heal-boundaries']=2,['retail.monk.utility']=2},
 applicability={families={'retail'},actionContext='player',class='MONK'},
 tags={'mistweaver','healer','reference','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow/mistweaver-monk-pve-healing-rotation-cooldowns-abilities',title='Icy Veins: Mistweaver Monk rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12',notes='Damage filler between heals; the healing priorities need ally health, which is secret.'},
 },
 body={priority=10,disabled=true,specs={270},
  cooldowns={BuiltinConditions.block('mw-utility','retail.monk.utility','mw-')},
  rotation={
   BuiltinConditions.block('mw-boundaries','retail.monk.heal-boundaries','mw-'),
   BuiltinConditions.spell('mw-rising-sun-kick',107428),
   BuiltinConditions.spell('mw-blackout-kick',100784),
   BuiltinConditions.spell('mw-tiger-palm',100780),
  },
 },
}))
