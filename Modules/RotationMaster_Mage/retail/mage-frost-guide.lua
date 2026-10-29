-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Frost Mage after SimulationCraft and Icy Veins (optimal reference), one
-- order per hero tree. Frostfire (Frostfire Bolt known): Glacial Spike when ready, Comet Storm on one
-- or two enemies, Flurry on Brain Freeze, Ice Lance on two Fingers of Frost, Ray of Frost, Frozen
-- Orb, Blizzard on packs, Ice Lance on Thermal Void or twelve Freezing, Flurry, Cone of Cold or Ice
-- Nova on five. Spellslinger: Comet Storm first and Ice Lance from six Freezing. Ice Lance on the
-- move; Frostfire Bolt or Frostbolt filler. Disabled: procs, Freezing stacks and cooldowns are secret
-- in Midnight combat.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function freezing(v)return{type='DEBUFF_STACKS',unit='target',spell=1221389,owndebuff=true,operator='GREATERTHANOREQUALS',value=v}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local brainFreeze,fingers,thermal,spike=buff(190446),buff(44544),buff(1247730),buff(199844)
local twoFingers={type='BUFF_STACKS',unit='player',spell=44544,ownbuff=true,operator='GREATERTHANOREQUALS',value=2}
local frozenRain=BuiltinConditions.all(buff(270232),engaged(3))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.mage.frost.guide',revision=7,
 blocks={['retail.mage.boundaries']=3,['retail.mage.utility']=2},
 applicability={families={'retail'},actionContext='player',class='MAGE'},
 tags={'frost','caster','reference','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/frost-mage-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Frost Mage rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/mage_frost.simc',title='SimulationCraft default action list: Frost',reviewedAt='2026-10-23',revision='c5fea93f'},
 },
 body={priority=10,disabled=true,specs={64},
  cooldowns={
   BuiltinConditions.block('frguide-utility','retail.mage.utility','frguide-'),
   BuiltinConditions.spell('frguide-barrier',11426,BuiltinConditions.combat()),
   BuiltinConditions.spell('frguide-water-elemental',31687,BuiltinConditions.negate({type='PET'})),
  },
  rotation={
   BuiltinConditions.block('frguide-boundaries','retail.mage.boundaries','frguide-'),
   {id='frguide-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
    BuiltinConditions.spell('frguide-pull-frostfire',431044),BuiltinConditions.spell('frguide-pull-frostbolt',116),BuiltinConditions.stop('frguide-pull-stop')}},
   {id='frguide-frostfire',type='branch',conditions={type='SPELL_KNOWN',spell=431044},
    onTrue={
     BuiltinConditions.spell('frguide-ff-glacial-spike',199786,spike),
     BuiltinConditions.spell('frguide-ff-comet-storm',153595,BuiltinConditions.negate(engaged(3))),
     BuiltinConditions.spell('frguide-ff-brain-freeze',44614,BuiltinConditions.all(brainFreeze,BuiltinConditions.negate(thermal))),
     BuiltinConditions.spell('frguide-ff-two-fingers',30455,twoFingers),
     BuiltinConditions.spell('frguide-ff-ray-of-frost',205021),
     BuiltinConditions.spell('frguide-ff-frozen-orb',84714),
     BuiltinConditions.spell('frguide-ff-blizzard',190356,frozenRain),
     BuiltinConditions.spell('frguide-ff-thermal-void',30455,BuiltinConditions.all(fingers,thermal)),
     BuiltinConditions.spell('frguide-ff-shatter',30455,freezing(12)),
     BuiltinConditions.spell('frguide-ff-flurry',44614),
     BuiltinConditions.spell('frguide-ff-ice-nova',157997,engaged(5)),
     BuiltinConditions.spell('frguide-ff-cone-of-cold',120,engaged(5)),
     BuiltinConditions.spell('frguide-ff-moving-lance',30455,{type='MOVING'}),
     BuiltinConditions.spell('frguide-ff-glacial-spike-filler',199786),
     BuiltinConditions.spell('frguide-ff-frostfire-bolt',431044)},
    onFalse={
     BuiltinConditions.spell('frguide-ss-comet-storm',153595),
     BuiltinConditions.spell('frguide-ss-brain-freeze',44614,BuiltinConditions.all(brainFreeze,BuiltinConditions.negate(thermal))),
     BuiltinConditions.spell('frguide-ss-two-fingers',30455,twoFingers),
     BuiltinConditions.spell('frguide-ss-frozen-orb',84714),
     BuiltinConditions.spell('frguide-ss-glacial-spike',199786,spike),
     BuiltinConditions.spell('frguide-ss-blizzard',190356,frozenRain),
     BuiltinConditions.spell('frguide-ss-fingers',30455,fingers),
     BuiltinConditions.spell('frguide-ss-shatter',30455,freezing(6)),
     BuiltinConditions.spell('frguide-ss-ray-of-frost',205021),
     BuiltinConditions.spell('frguide-ss-flurry',44614),
     BuiltinConditions.spell('frguide-ss-ice-nova',157997,engaged(4)),
     BuiltinConditions.spell('frguide-ss-cone-of-cold',120,engaged(4)),
     BuiltinConditions.spell('frguide-ss-packs-blizzard',190356,engaged(7)),
     BuiltinConditions.spell('frguide-ss-moving-lance',30455,{type='MOVING'}),
     BuiltinConditions.spell('frguide-ss-glacial-spike-filler',199786),
     BuiltinConditions.spell('frguide-ss-frostbolt',116)}},
  },
 },
}))
