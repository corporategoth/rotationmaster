-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Havoc Demon Hunter after Icy Veins, SimulationCraft and Wowhead (optimal
-- reference): Aldrachi Reaver's Glaive and Rending Strike, Fel-Scarred Metamorphosis spending,
-- Essence Break windows, Eye Beam, Blade Dance, Immolation Aura, Chaos Strike, Felblade, Throw
-- Glaive (Fury is secret on Retail, so Felblade does not wait for room). Disabled: procs,
-- Metamorphosis and Essence Break are secret in Midnight combat.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local aldrachi=BuiltinConditions.known(442294)
local glaive=BuiltinConditions.any(buff(444686),buff(444764))
local scarredMeta=BuiltinConditions.all(BuiltinConditions.negate(aldrachi),buff(162264))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.demonhunter.havoc.guide',revision=6,
 blocks={['retail.demonhunter.boundaries']=3,['retail.demonhunter.utility']=2},
 applicability={families={'retail'},actionContext='player',class='DEMONHUNTER'},
 tags={'havoc','melee','reference','icy-veins','simulationcraft','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow/havoc-demon-hunter-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Havoc Demon Hunter rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/demonhunter_havoc.simc',title='SimulationCraft default action list: Havoc',reviewedAt='2026-10-23',revision='c5fea93f'},
  {url='https://www.wowhead.com/guide/classes/demon-hunter/havoc/rotation-cooldowns-pve-dps',title='Wowhead: Havoc Demon Hunter rotation (Midnight Season 2)',reviewedAt='2026-10-23',revision='2026-08-17',notes='Read from a Wayback snapshot.'},
 },
 body={priority=10,disabled=true,specs={577},
  cooldowns={
   BuiltinConditions.block('hguide-utility','retail.demonhunter.utility','hguide-'),
   BuiltinConditions.spell('hguide-metamorphosis',191427,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='SPELL_AVAIL',spell=198013}),BuiltinConditions.negate({type='SPELL_AVAIL',spell=188499}))),
   BuiltinConditions.spell('hguide-the-hunt',370965,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.all(aldrachi,BuiltinConditions.negate(glaive)),BuiltinConditions.all(BuiltinConditions.negate(aldrachi),{type='SPELL_COOLDOWN',spell=198013,operator='LESSTHAN',value=10})))),
   BuiltinConditions.spell('hguide-vengeful-retreat',198793,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.known(388108),BuiltinConditions.known(206476)))),
  },
  rotation={
   BuiltinConditions.block('hguide-boundaries','retail.demonhunter.boundaries','hguide-'),
   BuiltinConditions.spell('hguide-reavers-glaive',185123,BuiltinConditions.all(aldrachi,glaive,BuiltinConditions.negate(buff(442442)),BuiltinConditions.negate(buff(442435)))),
   BuiltinConditions.spell('hguide-rending-strike',162794,BuiltinConditions.all(aldrachi,buff(442442))),
   BuiltinConditions.spell('hguide-surge-essence-break',258860,scarredMeta),
   {id='hguide-window',type='branch',conditions=BuiltinConditions.any({type='DEBUFF',unit='target',spell=320338,owndebuff=true},scarredMeta),onFalse={},onTrue={
    BuiltinConditions.spell('hguide-window-blade-dance',188499),
    BuiltinConditions.spell('hguide-window-chaos-strike',162794)}},
   BuiltinConditions.spell('hguide-immolation-charges',258920,{type='SPELL_CHARGES',spell=258920,operator='GREATERTHANOREQUALS',value=2}),
   BuiltinConditions.spell('hguide-eye-beam',198013),
   BuiltinConditions.spell('hguide-inertia-felblade',232893,BuiltinConditions.all(BuiltinConditions.known(427640),BuiltinConditions.negate(buff(427641)))),
   BuiltinConditions.spell('hguide-essence-break',258860,{type='SPELL_COOLDOWN',spell=198013,operator='GREATERTHAN',value=4}),
   BuiltinConditions.spell('hguide-blade-dance',188499),
   BuiltinConditions.spell('hguide-immolation-cleave',258920,engaged(2)),
   BuiltinConditions.spell('hguide-chaos-strike',162794),
   BuiltinConditions.spell('hguide-felblade',232893),
   BuiltinConditions.spell('hguide-immolation-aura',258920),
   BuiltinConditions.spell('hguide-throw-glaive',185123),
   BuiltinConditions.spell('hguide-fel-rush',195072),
  },
 },
}))
