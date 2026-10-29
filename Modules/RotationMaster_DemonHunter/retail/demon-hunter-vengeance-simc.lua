-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Vengeance Demon Hunter after SimulationCraft (reference). Aldrachi Reaver:
-- Sigil of Flame and Immolation Aura first, Metamorphosis, the Reaver's Glaive cycle, Fiery Brand,
-- Sigil of Spite, Spirit Bomb on packs, Soul Carver in Fiery Demise, then Fracture, Soul Cleave,
-- Felblade, Fel Devastation. Annihilator: spend a ready Voidfall with Spirit Bomb or Soul Cleave,
-- build it with Fracture. RM cannot count Soul Fragments, so fragment targets become enemy counts;
-- Fury is secret on Retail, so its Fury thresholds are left out. Disabled: secret in Midnight combat.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local demise={type='DEBUFF',unit='target',spell=212818,owndebuff=true}
local charged={type='SPELL_CHARGES',spell=263642,operator='GREATERTHANOREQUALS',value=2}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.demonhunter.vengeance.simc',revision=6,
 blocks={['retail.demonhunter.boundaries']=3,['retail.demonhunter.utility']=2},
 applicability={families={'retail'},actionContext='player',class='DEMONHUNTER'},
 tags={'vengeance','tank','reference','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/demonhunter_vengeance.simc',title='SimulationCraft default action list: Vengeance',reviewedAt='2026-10-23',revision='c5fea93f'},
 },
 body={priority=5,disabled=true,specs={581},
  cooldowns={
   BuiltinConditions.block('vsimc-utility','retail.demonhunter.utility','vsimc-'),
   BuiltinConditions.spell('vsimc-demon-spikes',203720,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(buff(203819)))),
  },
  rotation={
   BuiltinConditions.block('vsimc-boundaries','retail.demonhunter.boundaries','vsimc-'),
   {id='vsimc-aldrachi',type='branch',conditions=BuiltinConditions.known(442294),
    onTrue={
     BuiltinConditions.spell('vsimc-sigil-of-flame',204596),
     BuiltinConditions.spell('vsimc-immolation-aura',258920),
     BuiltinConditions.spell('vsimc-metamorphosis',187827,BuiltinConditions.any(buff(1270476),BuiltinConditions.negate(buff(187827)))),
     BuiltinConditions.spell('vsimc-reavers-glaive',204157,BuiltinConditions.any(buff(444686),buff(444764))),
     BuiltinConditions.spell('vsimc-rending-fracture',263642,buff(442442)),
     BuiltinConditions.spell('vsimc-flurry-soul-cleave',228477,buff(442435)),
     BuiltinConditions.spell('vsimc-glaive-felblade',232893,BuiltinConditions.any(buff(442442),buff(442435))),
     BuiltinConditions.spell('vsimc-fiery-brand',204021,BuiltinConditions.any({type='SPELL_CHARGES',spell=204021,operator='GREATERTHANOREQUALS',value=2},BuiltinConditions.negate(demise))),
     BuiltinConditions.spell('vsimc-sigil-of-spite',390163),
     BuiltinConditions.spell('vsimc-spirit-bomb',247454,engaged(3)),
     BuiltinConditions.spell('vsimc-soul-carver',207407,demise),
     BuiltinConditions.spell('vsimc-fracture',263642),
     BuiltinConditions.spell('vsimc-soul-cleave',228477),
     BuiltinConditions.spell('vsimc-felblade',232893),
     BuiltinConditions.spell('vsimc-fel-devastation',212084)},
    onFalse={
     {id='vsimc-voidfall',type='branch',conditions=buff(1256302),onFalse={},onTrue={
      BuiltinConditions.spell('vsimc-voidfall-spirit-bomb',247454,engaged(3)),
      BuiltinConditions.spell('vsimc-voidfall-soul-cleave',228477)}},
     BuiltinConditions.spell('vsimc-build-fracture',263642,{type='BUFF_STACKS',unit='player',spell=1256301,ownbuff=true,operator='GREATERTHANOREQUALS',value=2}),
     BuiltinConditions.spell('vsimc-metamorphosis-entry',187827,BuiltinConditions.negate(buff(187827))),
     BuiltinConditions.spell('vsimc-ann-spirit-bomb',247454,engaged(3)),
     BuiltinConditions.spell('vsimc-ann-sigil-of-spite',390163),
     BuiltinConditions.spell('vsimc-capped-fracture',263642,charged),
     BuiltinConditions.spell('vsimc-ann-immolation-aura',258920),
     BuiltinConditions.spell('vsimc-ann-sigil-of-flame',204596),
     BuiltinConditions.spell('vsimc-ann-fracture',263642),
     BuiltinConditions.spell('vsimc-ann-soul-cleave',228477),
     BuiltinConditions.spell('vsimc-ann-felblade',232893),
     BuiltinConditions.spell('vsimc-ann-throw-glaive',204157)}},
  },
 },
}))
