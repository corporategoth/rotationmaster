-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Shaman catch-all, levels 1-9 or any Shaman without a specialization (lowest priority;
-- every specialization premade outranks it once a specialization is chosen). RM policy built from the 1-9 kit in the
-- Enhancement-leveling shape (Wowhead): Lightning Bolt to pull from range, Healing Surge when low and solo,
-- Primal Strike, Earth Shock, Lightning Bolt while out of melee. Lightning Shield is kept up. Shared parts:
-- mop/blocks.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local ranged={type='BEYOND_MELEE',unit='target'}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.shaman.unspecialized',revision=6,
 blocks={['mop.shaman.manual-target']=2,['mop.shaman.lightning-shield']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='SHAMAN'},
 tags={'dps','melee','leveling','wowhead'},
 sources={{url='https://www.wowhead.com/mop-classic/guide/classes/shaman/enhancement/dps-leveling-talent-builds-tips',title='Wowhead: Enhancement Shaman leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2026-06-29'}},
 body={priority=1,
 cooldowns={block('mop.shaman.lightning-shield','shaman-new-')},
 rotation={
 block('mop.shaman.manual-target','shaman-new-'),
 {id='shaman-new-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
  BuiltinConditions.spell('shaman-new-pull-bolt',403,ranged),
  {id='shaman-new-pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 BuiltinConditions.spell('shaman-new-surge',8004,BuiltinConditions.all({type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.35},BuiltinConditions.negate({type='GROUP'}))),
 BuiltinConditions.spell('shaman-new-primal-strike',73899),
 BuiltinConditions.spell('shaman-new-earth-shock',8042),
 BuiltinConditions.spell('shaman-new-bolt',403,ranged),
 }},
}))
