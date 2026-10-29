-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Guardian Druid after Icy Veins and Wowhead (optimal reference): Thrash and
-- Mangle on cooldown, Red Moon on a single target or Moonfire when missing, Moonfire on Galactic
-- Guardian, Swipe. Ironfur and the defensives are reminders whenever they are ready in combat. Rage and
-- health are secret on Retail, so the 80-rage Maul and Raze dump is left to you. Disabled: debuffs and
-- procs are secret in Midnight combat.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.druid.guardian.guide',revision=6,
 blocks={['retail.druid.boundaries']=3,['retail.druid.utility']=2},
 applicability={families={'retail'},actionContext='player',class='DRUID'},
 tags={'guardian','tank','reference','icy-veins','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow/guardian-druid-pve-tank-rotation-cooldowns-abilities',title='Icy Veins: Guardian Druid rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://www.wowhead.com/guide/classes/druid/guardian/rotation-cooldowns-pve-tank',title='Wowhead: Guardian Druid rotation (Midnight Season 1)',reviewedAt='2026-10-23',revision='2026-03-07',notes='Read from a Wayback snapshot.'},
 },
 body={priority=10,disabled=true,specs={104},
  cooldowns={
   BuiltinConditions.block('gguide-utility','retail.druid.utility','gguide-'),
   BuiltinConditions.spell('gguide-bear-form',5487,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate(buff(5487)),BuiltinConditions.negate(buff(102558)))),
   BuiltinConditions.spell('gguide-skull-bash',106839,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
   BuiltinConditions.spell('gguide-ironfur',192081,BuiltinConditions.combat()),
   BuiltinConditions.spell('gguide-frenzied-regeneration',22842,BuiltinConditions.combat()),
   BuiltinConditions.spell('gguide-survival-instincts',61336,BuiltinConditions.combat()),
   BuiltinConditions.spell('gguide-berserk',50334,BuiltinConditions.combat()),
   BuiltinConditions.spell('gguide-incarnation',102558,BuiltinConditions.combat()),
   BuiltinConditions.spell('gguide-lunar-beam',204066,BuiltinConditions.combat()),
   BuiltinConditions.spell('gguide-convoke',391528,BuiltinConditions.combat()),
   BuiltinConditions.spell('gguide-heart-of-the-wild',1261867,BuiltinConditions.combat()),
  },
  rotation={
   BuiltinConditions.block('gguide-boundaries','retail.druid.boundaries','gguide-'),
   BuiltinConditions.spell('gguide-thrash',77758),
   BuiltinConditions.spell('gguide-mangle',33917),
   BuiltinConditions.spell('gguide-red-moon',1252871,BuiltinConditions.negate({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2})),
   BuiltinConditions.spell('gguide-moonfire',8921,BuiltinConditions.negate({type='DEBUFF',unit='target',spell=164812,owndebuff=true})),
   BuiltinConditions.spell('gguide-galactic-moonfire',8921,buff(213708)),
   BuiltinConditions.spell('gguide-swipe',213771),
  },
 },
}))
