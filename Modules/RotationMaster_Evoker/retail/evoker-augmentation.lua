-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Augmentation Evoker after Icy Veins (recommended; SimulationCraft agrees):
-- Ebon Might refreshed under 4 s and on cooldown unless Breath of Eons is ready, Prescience, Fire
-- Breath, Upheaval, Eruption in Ebon Might or on two Essence Bursts, Azure Strike, Living Flame
-- (Chrono Flame). Ebon Might is one of the few auras Blizzard keeps readable in Midnight combat, so
-- its upkeep runs there; steps on other buffs are skipped while those are hidden. Breath of Eons,
-- Deep Breath (both aimed), Tip the Scales and Time Skip are highlights beside it.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function ready(id)return{type='SPELL_AVAIL',spell=id}end
local ebon={type='BUFF',unit='player',spell=395296,ownbuff=true}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.evoker.augmentation',revision=7,
 blocks={['retail.evoker.boundaries']=3,['retail.evoker.utility']=2},
 applicability={families={'retail'},actionContext='player',class='EVOKER'},
 tags={'augmentation','ranged','support','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/augmentation-evoker-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Augmentation Evoker rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/evoker_augmentation.simc',title='SimulationCraft default action list: Augmentation',reviewedAt='2026-10-23',revision='c5fea93f',notes='Same order; Ebon Might refreshed in its pandemic window.'},
  {url='https://warcraft.wiki.gg/wiki/Patch_12.0.0/Planned_API_changes',title='Warcraft Wiki: Patch 12.0.0 API changes (aura whitelist)',reviewedAt='2026-10-23',notes='Ebon Might is a never-secret aura.'},
 },
 body={priority=20,specs={1473},
  cooldowns={
   BuiltinConditions.block('aug-utility','retail.evoker.utility','aug-'),
   BuiltinConditions.spell('aug-breath-of-eons',403631,BuiltinConditions.combat()),
   BuiltinConditions.spell('aug-deep-breath',357210,BuiltinConditions.combat()),
   BuiltinConditions.spell('aug-tip-the-scales',370553,BuiltinConditions.all(BuiltinConditions.combat(),ready(357208))),
   BuiltinConditions.spell('aug-time-skip',404977,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(ready(357208)),BuiltinConditions.negate(ready(396286)))),
  },
  rotation={
   BuiltinConditions.block('aug-boundaries','retail.evoker.boundaries','aug-'),
   {id='aug-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
    BuiltinConditions.spell('aug-pull-blistering-scales',360827,BuiltinConditions.all({type='GROUP'},{type='FRIENDLY',unit='target'},BuiltinConditions.negate({type='BUFF',unit='target',spell=360827,ownbuff=true}))),
    BuiltinConditions.spell('aug-pull-living-flame',361469,{type='ATTACKABLE',unit='target'}),
    BuiltinConditions.stop('aug-pull-stop')}},
   BuiltinConditions.spell('aug-ebon-might-expiring',395152,BuiltinConditions.any(BuiltinConditions.negate(ebon),{type='BUFF_REMAIN',unit='player',spell=395296,ownbuff=true,operator='LESSTHAN',value=4})),
   BuiltinConditions.spell('aug-ebon-might',395152,BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(403631)),BuiltinConditions.negate(ready(403631)))),
   BuiltinConditions.spell('aug-prescience',409311),
   BuiltinConditions.spell('aug-fire-breath',357208),
   BuiltinConditions.spell('aug-upheaval',396286),
   BuiltinConditions.spell('aug-eruption',395160,BuiltinConditions.any(ebon,{type='BUFF_STACKS',unit='player',spell=392268,ownbuff=true,operator='GREATERTHANOREQUALS',value=2})),
   BuiltinConditions.spell('aug-azure-strike',362969),
   BuiltinConditions.spell('aug-living-flame',361469),
  },
 },
}))
