-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Vengeance Demon Hunter after Wowhead's order and Icy Veins' hero-tree goals
-- (optimal reference): Aldrachi Reaver's Glaive cycle, Fracture at full charges, Spirit Bomb on
-- packs, Immolation Aura, Sigil of Flame, Soul Cleave, Fel Devastation, Fracture, Felblade, Throw
-- Glaive. RM cannot count Soul Fragments, so Spirit Bomb waits for three enemies and Soul Cleave
-- fills single target; Fury is secret on Retail, so spenders wait only for their cost and builders
-- do not avoid capping. Disabled: secret in Midnight combat.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function off(id,action,conditions)local step=BuiltinConditions.spell(id,action,conditions);step.disabled=true;return step end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.demonhunter.vengeance.guide',revision=6,
 blocks={['retail.demonhunter.boundaries']=3,['retail.demonhunter.utility']=2},
 applicability={families={'retail'},actionContext='player',class='DEMONHUNTER'},
 tags={'vengeance','tank','reference','wowhead','icy-veins'},
 sources={
  {url='https://www.wowhead.com/guide/classes/demon-hunter/vengeance/rotation-cooldowns-pve-tank',title='Wowhead: Vengeance Demon Hunter rotation (Midnight Season 1)',reviewedAt='2026-10-23',revision='2026-02-24',notes='Read from a Wayback snapshot; Season 1 data. Spirit Bomb at 6 souls.'},
  {url='https://www.icy-veins.com/wow/vengeance-demon-hunter-pve-tank-rotation-cooldowns-abilities',title='Icy Veins: Vengeance Demon Hunter rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12',notes='Hero-tree goals: Fracture before Soul Cleave (Aldrachi), Fracture on cooldown and Voidfall spending (Annihilator).'},
 },
 body={priority=10,disabled=true,specs={581},
  cooldowns={
   BuiltinConditions.block('vguide-utility','retail.demonhunter.utility','vguide-'),
   BuiltinConditions.spell('vguide-demon-spikes',203720,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(buff(203819)))),
   BuiltinConditions.spell('vguide-metamorphosis',187827,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(buff(187827)))),
   BuiltinConditions.spell('vguide-fiery-brand',204021,BuiltinConditions.combat()),
   off('vguide-infernal-strike',189110,{type='SPELL_CHARGES',spell=189110,operator='GREATERTHANOREQUALS',value=2}),
   BuiltinConditions.spell('vguide-sigil-of-spite',390163,BuiltinConditions.combat()),
   BuiltinConditions.spell('vguide-soul-carver',207407,BuiltinConditions.combat()),
  },
  rotation={
   BuiltinConditions.block('vguide-boundaries','retail.demonhunter.boundaries','vguide-'),
   {id='vguide-aldrachi',type='branch',conditions=BuiltinConditions.known(442294),onFalse={},onTrue={
    BuiltinConditions.spell('vguide-reavers-glaive',204157,BuiltinConditions.all(BuiltinConditions.any(buff(444686),buff(444764)),BuiltinConditions.negate(buff(442442)),BuiltinConditions.negate(buff(442435)))),
    BuiltinConditions.spell('vguide-rending-fracture',263642,buff(442442)),
    BuiltinConditions.spell('vguide-flurry-soul-cleave',228477,buff(442435))}},
   BuiltinConditions.spell('vguide-fracture-charges',263642,{type='SPELL_CHARGES',spell=263642,operator='GREATERTHANOREQUALS',value=2}),
   BuiltinConditions.spell('vguide-spirit-bomb',247454,engaged(3)),
   BuiltinConditions.spell('vguide-immolation-aura',258920),
   BuiltinConditions.spell('vguide-sigil-of-flame',204596),
   BuiltinConditions.spell('vguide-single-soul-cleave',228477,BuiltinConditions.negate(engaged(3))),
   BuiltinConditions.spell('vguide-fel-devastation',212084),
   BuiltinConditions.spell('vguide-soul-cleave',228477),
   BuiltinConditions.spell('vguide-fracture',263642),
   BuiltinConditions.spell('vguide-felblade',232893),
   BuiltinConditions.spell('vguide-throw-glaive',204157),
  },
 },
}))
