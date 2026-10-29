-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Devourer Demon Hunter after Icy Veins' Annihilator list (optimal reference).
-- Outside Void Metamorphosis: Consume on Soulburst, Reap, Soul Immolation, Voidblade and The Hunt
-- once Void Metamorphosis is ready, Void Metamorphosis, Hungering Slash, Void Ray once affordable,
-- Consume. Inside: Devour on Soulburst, Void Ray (Void-Scarred melee actives next), Collapsing
-- Star, Cull, Devour, Soul Immolation. RM cannot count Soul Fragments, so Reap and Cull go on
-- cooldown and charges; Fury is secret on Retail, so Void Ray waits only for its cost. Disabled: buffs
-- are secret in Midnight combat.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local soulburst=buff(1297433)
local metaReady={type='BUFF_STACKS',unit='player',spell=1225789,ownbuff=true,operator='GREATERTHANOREQUALS',value=50}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.demonhunter.devourer.guide',revision=6,
 blocks={['retail.demonhunter.boundaries']=3,['retail.demonhunter.utility']=2},
 applicability={families={'retail'},actionContext='player',class='DEMONHUNTER'},
 tags={'devourer','ranged','reference','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow/devourer-demon-hunter-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Devourer Demon Hunter rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12',notes='Annihilator list; Void-Scarred actives follow Void Ray inside Void Metamorphosis.'},
 },
 body={priority=10,disabled=true,specs={1480},
  cooldowns={BuiltinConditions.block('dguide-utility','retail.demonhunter.utility','dguide-')},
  rotation={
   BuiltinConditions.block('dguide-boundaries','retail.demonhunter.boundaries','dguide-'),
   {id='dguide-meta',type='branch',conditions=buff(1217607),
    onTrue={
     BuiltinConditions.spell('dguide-meta-soulburst',1217610,soulburst),
     BuiltinConditions.spell('dguide-meta-void-ray',473728),
     BuiltinConditions.spell('dguide-meta-reapers-toll',1245470),
     BuiltinConditions.spell('dguide-meta-pierce-the-veil',1245483),
     BuiltinConditions.spell('dguide-meta-predators-wake',1259431),
     BuiltinConditions.spell('dguide-meta-collapsing-star',1221150),
     BuiltinConditions.spell('dguide-meta-cull',1245453),
     BuiltinConditions.spell('dguide-meta-devour',1217610),
     BuiltinConditions.spell('dguide-meta-soul-immolation',1241937)},
    onFalse={
     BuiltinConditions.spell('dguide-soulburst',473662,soulburst),
     BuiltinConditions.spell('dguide-reap',1226019),
     BuiltinConditions.spell('dguide-soul-immolation',1241937,BuiltinConditions.negate(buff(1241937))),
     BuiltinConditions.spell('dguide-voidblade',1245412,metaReady),
     BuiltinConditions.spell('dguide-the-hunt',1246167,metaReady),
     BuiltinConditions.spell('dguide-void-metamorphosis',1217605),
     BuiltinConditions.spell('dguide-hungering-slash',1239123),
     BuiltinConditions.spell('dguide-void-ray',473728),
     BuiltinConditions.spell('dguide-consume',473662)}},
  },
 },
}))
