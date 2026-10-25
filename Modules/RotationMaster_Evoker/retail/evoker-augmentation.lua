-- Retail (Midnight 12.x) Augmentation Evoker after Icy Veins (recommended; SimulationCraft agrees):
-- Ebon Might refreshed under 4 s and on cooldown unless Breath of Eons is ready, Prescience, Fire
-- Breath, Upheaval, Eruption in Ebon Might or on two Essence Bursts, Azure Strike, Living Flame
-- (Chrono Flame). Ebon Might is one of the few auras Blizzard keeps readable in Midnight combat, so
-- its upkeep runs there; steps on other buffs are skipped while those are hidden. Breath of Eons,
-- Deep Breath (both aimed), Tip the Scales and Time Skip are highlights beside it.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function ready(id)return{type='SPELL_AVAIL',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local ebon={type='BUFF',unit='player',spell=395296,ownbuff=true}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.evoker.augmentation',revision=6,
 blocks={['retail.evoker.boundaries']=3,['retail.evoker.utility']=2},
 nameKey='Default.Retail.Evoker.Augmentation.Name',descriptionKey='Default.Retail.Evoker.Augmentation.Description',
 applicability={families={'retail'},actionContext='player',class='EVOKER'},
 tags={'augmentation','ranged','support','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/augmentation-evoker-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Augmentation Evoker rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/evoker_augmentation.simc',title='SimulationCraft default action list: Augmentation',reviewedAt='2026-10-23',revision='c5fea93f',notes='Same order; Ebon Might refreshed in its pandemic window.'},
  {url='https://warcraft.wiki.gg/wiki/Patch_12.0.0/Planned_API_changes',title='Warcraft Wiki: Patch 12.0.0 API changes (aura whitelist)',reviewedAt='2026-10-23',notes='Ebon Might is a never-secret aura.'},
 },
 body={priority=20,specs={1473},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('aug-utility','retail.evoker.utility','aug-'),
   spell('aug-breath-of-eons',403631,combat()),
   spell('aug-deep-breath',357210,combat()),
   spell('aug-tip-the-scales',370553,all(combat(),ready(357208))),
   spell('aug-time-skip',404977,all(combat(),negate(ready(357208)),negate(ready(396286)))),
  },
  rotation={
   block('aug-boundaries','retail.evoker.boundaries','aug-'),
   {id='aug-pull',type='branch',conditions=combat(),onTrue={},onFalse={
    spell('aug-pull-blistering-scales',360827,all({type='GROUP'},{type='FRIENDLY',unit='target'},negate({type='BUFF',unit='target',spell=360827,ownbuff=true}))),
    spell('aug-pull-living-flame',361469,{type='ATTACKABLE',unit='target'}),
    stop('aug-pull-stop')}},
   spell('aug-ebon-might-expiring',395152,any(negate(ebon),{type='BUFF_REMAIN',unit='player',spell=395296,ownbuff=true,operator='LESSTHAN',value=4})),
   spell('aug-ebon-might',395152,any(negate(known(403631)),negate(ready(403631)))),
   spell('aug-prescience',409311),
   spell('aug-fire-breath',357208),
   spell('aug-upheaval',396286),
   spell('aug-eruption',395160,any(ebon,{type='BUFF_STACKS',unit='player',spell=392268,ownbuff=true,operator='GREATERTHANOREQUALS',value=2})),
   spell('aug-azure-strike',362969),
   spell('aug-living-flame',361469),
  },
 },
}))
