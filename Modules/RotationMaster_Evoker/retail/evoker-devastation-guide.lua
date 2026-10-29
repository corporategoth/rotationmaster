-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Devastation Evoker after SimulationCraft and Icy Veins (optimal
-- reference), one list per hero tree (Mass Disintegrate known = Scalecommander, else Flameshaper):
-- empowers on cooldown, Disintegrate to spend (Mass Disintegrate stacks first), Pyre on five or more,
-- Unbound Flame, Living Flame on Burnout with Leaping Flames, Azure Sweep, Living Flame, Azure Strike
-- on the move. Disabled: procs, cooldowns and target debuffs are secret in Midnight combat, and RM
-- cannot pick an empower rank (Icy Veins: rank 1 on one target).
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local burstRoom={type='BUFF_STACKS',unit='player',spell=359618,ownbuff=true,operator='LESSTHAN',value=2}
local flames=BuiltinConditions.all(buff(375802),buff(370901))
local sweep=buff(1265871)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.evoker.devastation.guide',revision=7,
 blocks={['retail.evoker.boundaries']=3,['retail.evoker.utility']=2},
 applicability={families={'retail'},actionContext='player',class='EVOKER'},
 tags={'devastation','ranged','reference','simulationcraft','icy-veins'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/evoker_devastation.simc',title='SimulationCraft default action list: Devastation',reviewedAt='2026-10-23',revision='c5fea93f'},
  {url='https://www.icy-veins.com/wow/devastation-evoker-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Devastation Evoker rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12',notes='Empowers at rank 1 on a single target; Azure Strike while moving.'},
 },
 body={priority=10,disabled=true,specs={1467},
  cooldowns={
   BuiltinConditions.block('dguide-utility','retail.evoker.utility','dguide-'),
   BuiltinConditions.spell('dguide-dragonrage',375087,BuiltinConditions.combat()),
   BuiltinConditions.spell('dguide-tip-the-scales',370553,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(buff(375087),{type='SPELL_AVAIL',spell=357208}))),
   BuiltinConditions.spell('dguide-deep-breath',357210,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.known(436335))),
  },
  rotation={
   BuiltinConditions.block('dguide-boundaries','retail.evoker.boundaries','dguide-'),
   {id='dguide-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={BuiltinConditions.spell('dguide-pull-living-flame',361469),BuiltinConditions.stop('dguide-pull-stop')}},
   {id='dguide-tree',type='branch',conditions=BuiltinConditions.known(436335),
    onTrue={
     BuiltinConditions.spell('dguide-sc-eternity-surge',359073),
     BuiltinConditions.spell('dguide-sc-fire-breath',357208),
     BuiltinConditions.spell('dguide-sc-deep-breath',357210,engaged(2)),
     BuiltinConditions.spell('dguide-sc-mass-disintegrate',356995,buff(436336)),
     BuiltinConditions.spell('dguide-sc-pyre',357211,engaged(5)),
     BuiltinConditions.spell('dguide-sc-disintegrate',356995),
     BuiltinConditions.spell('dguide-sc-flames',361469,flames),
     BuiltinConditions.spell('dguide-sc-unbound-flame',1292321,burstRoom),
     BuiltinConditions.spell('dguide-sc-azure-sweep',362969,sweep)},
    onFalse={
     BuiltinConditions.spell('dguide-fs-eternity-surge',359073),
     BuiltinConditions.spell('dguide-fs-fire-breath',357208,BuiltinConditions.any(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=357209,owndebuff=true}),{type='DEBUFF_REMAIN',unit='target',spell=357209,owndebuff=true,operator='LESSTHAN',value=4})),
     BuiltinConditions.spell('dguide-fs-pyre',357211,engaged(5)),
     BuiltinConditions.spell('dguide-fs-disintegrate',356995),
     BuiltinConditions.spell('dguide-fs-deep-breath',357210,engaged(4)),
     BuiltinConditions.spell('dguide-fs-unbound-flame',1292321),
     BuiltinConditions.spell('dguide-fs-flames',361469,flames),
     BuiltinConditions.spell('dguide-fs-azure-sweep',362969,sweep)}},
   BuiltinConditions.spell('dguide-moving-azure-strike',362969,{type='MOVING'}),
   BuiltinConditions.spell('dguide-living-flame',361469),
   BuiltinConditions.spell('dguide-azure-strike',362969),
  },
 },
}))
