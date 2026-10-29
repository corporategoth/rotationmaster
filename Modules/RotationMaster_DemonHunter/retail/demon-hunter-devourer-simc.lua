-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Devourer Demon Hunter after SimulationCraft's Annihilator list (reference):
-- Void Metamorphosis as soon as it is ready, Voidblade only with Devourer's Bite on up to three
-- enemies; outside it Consume on Soulburst, Reap, Void Ray, Soul Immolation on packs, Consume;
-- inside it Devour on Soulburst against one target, The Hunt and Voidblade with Devourer's Bite,
-- Void Ray on packs, Collapsing Star, Cull, Void Ray, Soul Immolation, Devour. Disabled: secret in
-- Midnight combat.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local soulburst=buff(1297433)
local bite=BuiltinConditions.known(1240201)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.demonhunter.devourer.simc',revision=6,
 blocks={['retail.demonhunter.boundaries']=3,['retail.demonhunter.utility']=2},
 applicability={families={'retail'},actionContext='player',class='DEMONHUNTER'},
 tags={'devourer','ranged','reference','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/demonhunter_devourer.simc',title='SimulationCraft default action list: Devourer (Annihilator)',reviewedAt='2026-10-23',revision='c5fea93f'},
 },
 body={priority=5,disabled=true,specs={1480},
  cooldowns={BuiltinConditions.block('dsimc-utility','retail.demonhunter.utility','dsimc-')},
  rotation={
   BuiltinConditions.block('dsimc-boundaries','retail.demonhunter.boundaries','dsimc-'),
   {id='dsimc-meta',type='branch',conditions=buff(1217607),
    onTrue={
     BuiltinConditions.spell('dsimc-meta-soulburst',1217610,BuiltinConditions.all(soulburst,BuiltinConditions.negate(engaged(2)))),
     BuiltinConditions.spell('dsimc-meta-the-hunt',1246167,bite),
     BuiltinConditions.spell('dsimc-meta-voidblade',1245412,bite),
     BuiltinConditions.spell('dsimc-meta-void-ray-aoe',473728,engaged(2)),
     BuiltinConditions.spell('dsimc-meta-collapsing-star',1221150),
     BuiltinConditions.spell('dsimc-meta-cull',1245453),
     BuiltinConditions.spell('dsimc-meta-void-ray',473728),
     BuiltinConditions.spell('dsimc-meta-soul-immolation',1241937,BuiltinConditions.negate(buff(1241937))),
     BuiltinConditions.spell('dsimc-meta-devour',1217610)},
    onFalse={
     BuiltinConditions.spell('dsimc-voidblade',1245412,BuiltinConditions.all(bite,BuiltinConditions.negate(engaged(4)),{type='BUFF_STACKS',unit='player',spell=1225789,ownbuff=true,operator='GREATERTHANOREQUALS',value=50})),
     BuiltinConditions.spell('dsimc-void-metamorphosis',1217605),
     BuiltinConditions.spell('dsimc-soulburst',473662,soulburst),
     BuiltinConditions.spell('dsimc-reap',1226019),
     BuiltinConditions.spell('dsimc-void-ray',473728),
     BuiltinConditions.spell('dsimc-soul-immolation',1241937,engaged(2)),
     BuiltinConditions.spell('dsimc-consume',473662)}},
  },
 },
}))
