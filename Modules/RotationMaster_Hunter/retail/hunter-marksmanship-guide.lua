-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Marksmanship Hunter after SimulationCraft and Icy Veins (optimal
-- reference): Explosive Shot, Volley and Trueshot on cooldown, Precise Shots spent before the next
-- Aimed Shot, Aimed Shot in Trueshot or before it caps. Dark Ranger: Black Arrow on Precise Shots and
-- Wailing Arrow; Sentinel: Moonlight Chakram before its window ends. Three or more enemies with Trick
-- Shots: Multi-Shot to apply it, then Rapid Fire and Aimed Shot while it lasts (Focus is secret on
-- Retail, so the 70-Focus Multi-Shot dump is left out). Disabled: procs and charges are secret in
-- Midnight combat.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local AIMED,RAPID,TRUESHOT,EXPLOSIVE,VOLLEY,KILLSHOT,MULTI,ARCANE,STEADY,BLACK,WAILING,CHAKRAM=19434,257044,288613,212431,260243,53351,257620,185358,56641,466930,392060,1264949
local precise=buff(260242)
local trueshot=buff(TRUESHOT)
local trick=buff(257622)
local aimedCap={type='SPELL_CHARGES',spell=AIMED,operator='GREATERTHANOREQUALS',value=2}
local hydra=BuiltinConditions.all(precise,engaged(2),BuiltinConditions.known(470945))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.hunter.marksmanship.guide',revision=8,
 blocks={['retail.hunter.boundaries']=3,['retail.hunter.utility']=2,['retail.hunter.mark']=1},
 applicability={families={'retail'},actionContext='player',class='HUNTER'},
 tags={'marksmanship','ranged','reference','simulationcraft','icy-veins'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/hunter_marksmanship.simc',title='SimulationCraft default action list: Marksmanship',reviewedAt='2026-10-23',revision='c5fea93f'},
  {url='https://www.icy-veins.com/wow/marksmanship-hunter-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Marksmanship Hunter rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-14'},
 },
 body={priority=10,disabled=true,specs={254},
  cooldowns={BuiltinConditions.block('mmguide-utility','retail.hunter.utility','mmguide-')},
  rotation={
   BuiltinConditions.block('mmguide-boundaries','retail.hunter.boundaries','mmguide-'),
   BuiltinConditions.spell('mmguide-call-pet',883,BuiltinConditions.all(BuiltinConditions.known(1223323),BuiltinConditions.negate({type='PET'}))),
   {id='mmguide-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
    BuiltinConditions.block('mmguide-pull-mark','retail.hunter.mark','mmguide-pull-'),BuiltinConditions.spell('mmguide-pull-aimed',AIMED),BuiltinConditions.stop('mmguide-pull-stop')}},
   {id='mmguide-aoe',type='branch',conditions=BuiltinConditions.all(BuiltinConditions.known(257621),engaged(3)),onFalse={},onTrue={
    BuiltinConditions.spell('mmguide-aoe-explosive',EXPLOSIVE),BuiltinConditions.spell('mmguide-aoe-volley',VOLLEY),
    BuiltinConditions.spell('mmguide-aoe-black-arrow',BLACK,precise),
    BuiltinConditions.spell('mmguide-aoe-trick',MULTI,BuiltinConditions.negate(trick)),
    BuiltinConditions.spell('mmguide-aoe-trueshot',TRUESHOT),
    BuiltinConditions.spell('mmguide-aoe-rapid',RAPID,trick),BuiltinConditions.spell('mmguide-aoe-aimed',AIMED,trick),
    BuiltinConditions.spell('mmguide-aoe-steady',STEADY),BuiltinConditions.stop('mmguide-aoe-stop')}},
   {id='mmguide-dark-ranger',type='branch',conditions=BuiltinConditions.known(BLACK),
    onTrue={
     BuiltinConditions.spell('mmguide-dr-black-arrow',BLACK,precise),
     BuiltinConditions.spell('mmguide-dr-explosive',EXPLOSIVE,BuiltinConditions.negate(buff(194594))),
     BuiltinConditions.spell('mmguide-dr-volley',VOLLEY),
     BuiltinConditions.spell('mmguide-dr-aimed-window',AIMED,BuiltinConditions.any(BuiltinConditions.all(trueshot,BuiltinConditions.negate(precise),{type='SPELL_AVAIL',spell=BLACK}),aimedCap)),
     BuiltinConditions.spell('mmguide-dr-trueshot',TRUESHOT),
     BuiltinConditions.spell('mmguide-dr-rapid',RAPID),
     BuiltinConditions.spell('mmguide-dr-wailing',WAILING),
     BuiltinConditions.spell('mmguide-dr-multi',MULTI,hydra),
     BuiltinConditions.spell('mmguide-dr-arcane',ARCANE,precise),
     BuiltinConditions.spell('mmguide-dr-aimed',AIMED),
     BuiltinConditions.spell('mmguide-dr-black-arrow-filler',BLACK),
     BuiltinConditions.spell('mmguide-dr-steady',STEADY)},
    onFalse={
     BuiltinConditions.spell('mmguide-sen-explosive',EXPLOSIVE),
     BuiltinConditions.spell('mmguide-sen-volley',VOLLEY),
     BuiltinConditions.spell('mmguide-sen-trueshot',TRUESHOT),
     BuiltinConditions.spell('mmguide-sen-chakram-ending',CHAKRAM,{type='BUFF_REMAIN',unit='player',spell=1264946,ownbuff=true,operator='LESSTHAN',value=5}),
     BuiltinConditions.spell('mmguide-sen-aimed-window',AIMED,BuiltinConditions.all(trueshot,BuiltinConditions.negate(precise))),
     BuiltinConditions.spell('mmguide-sen-rapid',RAPID,BuiltinConditions.any(BuiltinConditions.negate(precise),trueshot)),
     BuiltinConditions.spell('mmguide-sen-kill-shot',KILLSHOT,precise),
     BuiltinConditions.spell('mmguide-sen-multi',MULTI,hydra),
     BuiltinConditions.spell('mmguide-sen-arcane',ARCANE,precise),
     BuiltinConditions.spell('mmguide-sen-aimed',AIMED),
     BuiltinConditions.spell('mmguide-sen-chakram',CHAKRAM),
     BuiltinConditions.spell('mmguide-sen-steady',STEADY)}},
  },
 },
}))
