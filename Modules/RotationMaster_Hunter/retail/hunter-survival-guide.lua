-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Survival Hunter after SimulationCraft (reference; Icy Veins' openers
-- agree): Kill Command builds Tip of the Spear, which Takedown, Boomstick, Wildfire Bomb and Raptor
-- Strike spend. Pack Leader: Kill Command on Howl of the Pack Leader; Sentinel: Wildfire Bomb on
-- Sentinel's Mark and Moonlight Chakram. Three or more enemies: Boomstick and Wildfire Bomb first,
-- Raptor Swipe. Disabled: Tip of the Spear, charges and Focus are secret in Midnight combat.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local KILL,BOMB,TAKEDOWN,BOOM,RAPTOR,SWIPE,CHAKRAM=259489,259495,1250646,1261193,186270,1262293,1264949
local tip=buff(260286)
local howl=BuiltinConditions.any(buff(471878),buff(472324),buff(472325))
-- Kill Command just before a ready Takedown, without Twin Fangs and with no Tip of the Spear.
local beforeTakedown=BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(1272139)),BuiltinConditions.negate(tip),{type='SPELL_AVAIL',spell=TAKEDOWN})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.hunter.survival.guide',revision=7,
 blocks={['retail.hunter.boundaries']=3,['retail.hunter.utility']=2,['retail.hunter.mark']=1},
 applicability={families={'retail'},actionContext='player',class='HUNTER'},
 tags={'survival','melee','pet','reference','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/hunter_survival.simc',title='SimulationCraft default action list: Survival',reviewedAt='2026-10-23',revision='c5fea93f'},
  {url='https://www.icy-veins.com/wow/survival-hunter-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Survival Hunter rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12',notes='Openers only; they match SimulationCraft.'},
 },
 body={priority=10,disabled=true,specs={255},
  cooldowns={
   BuiltinConditions.block('svguide-utility','retail.hunter.utility','svguide-'),
   BuiltinConditions.spell('svguide-aspect-of-the-eagle',186289,BuiltinConditions.all(BuiltinConditions.combat(),{type='BEYOND_MELEE',unit='target'})),
  },
  rotation={
   BuiltinConditions.block('svguide-boundaries','retail.hunter.boundaries','svguide-'),
   BuiltinConditions.spell('svguide-call-pet',883,BuiltinConditions.negate({type='PET'})),
   {id='svguide-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
    BuiltinConditions.block('svguide-pull-mark','retail.hunter.mark','svguide-pull-'),BuiltinConditions.spell('svguide-pull-bomb',BOMB),BuiltinConditions.stop('svguide-pull-stop')}},
   {id='svguide-cleave',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    BuiltinConditions.spell('svguide-cleave-kill',KILL,BuiltinConditions.negate(tip)),
    BuiltinConditions.spell('svguide-cleave-boomstick',BOOM),
    BuiltinConditions.spell('svguide-cleave-bomb',BOMB),
    BuiltinConditions.spell('svguide-cleave-takedown',TAKEDOWN),
    BuiltinConditions.spell('svguide-cleave-swipe',SWIPE),
    BuiltinConditions.spell('svguide-cleave-raptor',RAPTOR),
    BuiltinConditions.spell('svguide-cleave-kill-filler',KILL),
    BuiltinConditions.stop('svguide-cleave-stop')}},
   {id='svguide-pack-leader',type='branch',conditions=BuiltinConditions.known(471876),
    onTrue={
     BuiltinConditions.spell('svguide-pl-howl',KILL,BuiltinConditions.all(howl,BuiltinConditions.any(BuiltinConditions.negate(tip),{type='BUFF_STACKS',unit='player',spell=260286,ownbuff=true,operator='LESSTHAN',value=2}))),
     BuiltinConditions.spell('svguide-pl-before-takedown',KILL,beforeTakedown),
     BuiltinConditions.spell('svguide-pl-takedown',TAKEDOWN,BuiltinConditions.any(tip,BuiltinConditions.known(1272139))),
     BuiltinConditions.spell('svguide-pl-bomb',BOMB,tip),
     BuiltinConditions.spell('svguide-pl-boomstick',BOOM,tip),
     BuiltinConditions.spell('svguide-pl-raptor',RAPTOR,BuiltinConditions.any(tip,BuiltinConditions.negate(BuiltinConditions.known(1259003)))),
     BuiltinConditions.spell('svguide-pl-kill',KILL),
     BuiltinConditions.spell('svguide-pl-takedown-filler',TAKEDOWN)},
    onFalse={
     BuiltinConditions.spell('svguide-sen-kill',KILL,BuiltinConditions.negate(tip)),
     BuiltinConditions.spell('svguide-sen-boomstick',BOOM),
     BuiltinConditions.spell('svguide-sen-bomb',BOMB,BuiltinConditions.any(buff(1253601),buff(1266960),{type='SPELL_CHARGES',spell=BOMB,operator='GREATERTHANOREQUALS',value=2})),
     BuiltinConditions.spell('svguide-sen-before-takedown',KILL,beforeTakedown),
     BuiltinConditions.spell('svguide-sen-takedown',TAKEDOWN),
     BuiltinConditions.spell('svguide-sen-chakram',CHAKRAM),
     BuiltinConditions.spell('svguide-sen-raptor',RAPTOR),
     BuiltinConditions.spell('svguide-sen-kill-filler',KILL),
     BuiltinConditions.spell('svguide-sen-bomb-filler',BOMB)}},
  },
 },
}))
