-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Blood Death Knight after SimulationCraft's Deathbringer list (reference):
-- Death and Decay kept up, Death's Caress for Bone Shield while runes are short, runic power spent on
-- Death Strike whenever it is affordable (runic power is secret on Retail, so its cap dump is gone).
-- Disabled: its buffs and debuffs are secret in Midnight combat.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local exterminate=BuiltinConditions.any(buff(441416),buff(447954))
local runeWeapon=buff(81256)
local lowBones=BuiltinConditions.any(BuiltinConditions.negate(buff(195181)),{type='BUFF_REMAIN',unit='player',spell=195181,ownbuff=true,operator='LESSTHAN',value=3},
 {type='BUFF_STACKS',unit='player',spell=195181,ownbuff=true,operator='LESSTHAN',value=6})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.deathknight.blood.simc',revision=7,
 blocks={['retail.deathknight.boundaries']=3,['retail.deathknight.utility']=2},
 applicability={families={'retail'},actionContext='player',class='DEATHKNIGHT'},
 tags={'blood','tank','reference','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/deathknight_blood.simc',title='SimulationCraft default action list: Blood (Deathbringer)',reviewedAt='2026-10-23',revision='c5fea93f'},
 },
 body={priority=5,disabled=true,specs={250},
  cooldowns={
   BuiltinConditions.block('bsimc-utility','retail.deathknight.utility','bsimc-'),
   BuiltinConditions.spell('bsimc-raise-dead',46585,BuiltinConditions.combat()),
   BuiltinConditions.spell('bsimc-dancing-rune-weapon',49028,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(exterminate),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=434765,owndebuff=true}))),
   BuiltinConditions.spell('bsimc-vampiric-blood',55233,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(buff(55233)))),
  },
  rotation={
   BuiltinConditions.block('bsimc-boundaries','retail.deathknight.boundaries','bsimc-'),
   {id='bsimc-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={BuiltinConditions.spell('bsimc-pull-caress',195292),BuiltinConditions.stop('bsimc-pull-stop')}},
   BuiltinConditions.spell('bsimc-death-and-decay',43265,BuiltinConditions.negate(buff(188290))),
   BuiltinConditions.spell('bsimc-reapers-mark',439843),
   BuiltinConditions.spell('bsimc-exterminate',195182,exterminate),
   {id='bsimc-bones',type='branch',conditions=lowBones,onFalse={},onTrue={
    BuiltinConditions.spell('bsimc-bones-caress',195292,{type='POINT',unit='player',operator='LESSTHAN',value=4}),
    BuiltinConditions.spell('bsimc-marrowrend',195182)}},
   BuiltinConditions.spell('bsimc-death-strike',49998),
   BuiltinConditions.spell('bsimc-blood-boil',50842),
   BuiltinConditions.spell('bsimc-consumption',1263824,BuiltinConditions.negate(runeWeapon)),
   BuiltinConditions.spell('bsimc-heart-strike',206930),
   BuiltinConditions.spell('bsimc-late-consumption',1263824),
  },
 },
}))
