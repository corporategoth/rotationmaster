-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Beast Mastery Hunter after SimulationCraft and Icy Veins (optimal
-- reference): Barbed Shot pooled around Bestial Wrath, Kill Command banked for it, Cobra Shot on
-- Cobra Fang, and Beast Cleave started with Wild Thrash on three or more enemies (two with Beast
-- Cleave talented). Dark Ranger adds Black Arrow in Withering Fire and Wailing Arrow as it ends.
-- Focus is secret on Retail, so Pack Leader's low-Focus Barbed Shot comes after Cobra Shot (when Cobra
-- Shot is unaffordable). Disabled: charges, cooldowns and procs are secret in Midnight combat.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local BARBED,WRATH,KILL,COBRA,THRASH,BLACK,WAILING=217200,19574,34026,193455,1264359,466930,392060
-- Barbed Shot about to reach two charges; Bestial Wrath within a global cooldown.
local capping=BuiltinConditions.any({type='SPELL_CHARGES',spell=BARBED,operator='GREATERTHANOREQUALS',value=2},
 BuiltinConditions.all({type='SPELL_CHARGES',spell=BARBED,operator='GREATERTHANOREQUALS',value=1},{type='SPELL_REMAIN',spell=BARBED,operator='LESSTHAN',value=2}))
local wrathSoon={type='SPELL_COOLDOWN',spell=WRATH,operator='LESSTHAN',value=1.5}
local cleave=buff(268877)
local withering=buff(466991)
-- Kill Command on Howl of the Pack Leader or Nature's Ally, or freely while Bestial Wrath is far off.
local kill=BuiltinConditions.any(buff(471878),buff(472324),buff(472325),buff(1276720),{type='SPELL_COOLDOWN',spell=WRATH,operator='GREATERTHAN',value=5})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.hunter.beastmastery.guide',revision=8,
 blocks={['retail.hunter.boundaries']=3,['retail.hunter.utility']=2,['retail.hunter.mark']=1},
 applicability={families={'retail'},actionContext='player',class='HUNTER'},
 tags={'beast-mastery','ranged','pet','reference','simulationcraft','icy-veins'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/hunter_beast_mastery.simc',title='SimulationCraft default action list: Beast Mastery',reviewedAt='2026-10-23',revision='c5fea93f'},
  {url='https://www.icy-veins.com/wow/beast-mastery-hunter-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Beast Mastery Hunter rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
 },
 body={priority=10,disabled=true,specs={253},
  cooldowns={BuiltinConditions.block('bmguide-utility','retail.hunter.utility','bmguide-'),BuiltinConditions.spell('bmguide-bloodshed',321530,BuiltinConditions.combat())},
  rotation={
   BuiltinConditions.block('bmguide-boundaries','retail.hunter.boundaries','bmguide-'),
   BuiltinConditions.spell('bmguide-call-pet',883,BuiltinConditions.negate({type='PET'})),
   {id='bmguide-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={BuiltinConditions.block('bmguide-pull-mark','retail.hunter.mark','bmguide-pull-'),BuiltinConditions.stop('bmguide-pull-stop')}},
   {id='bmguide-cleave',type='branch',conditions=BuiltinConditions.any(engaged(3),BuiltinConditions.all(BuiltinConditions.known(115939),engaged(2))),onFalse={},onTrue={
    BuiltinConditions.spell('bmguide-cleave-wild-thrash',THRASH,BuiltinConditions.negate(cleave)),
    BuiltinConditions.spell('bmguide-cleave-barbed',BARBED,capping),
    BuiltinConditions.spell('bmguide-cleave-wrath',WRATH),
    BuiltinConditions.spell('bmguide-cleave-black-arrow',BLACK),
    BuiltinConditions.spell('bmguide-cleave-wailing',WAILING),
    {id='bmguide-cleave-up',type='branch',conditions=cleave,onFalse={},onTrue={
     BuiltinConditions.spell('bmguide-cleave-kill',KILL),BuiltinConditions.spell('bmguide-cleave-up-barbed',BARBED),BuiltinConditions.spell('bmguide-cleave-cobra',COBRA)}}}},
   {id='bmguide-dark-ranger',type='branch',conditions=BuiltinConditions.known(BLACK),
    onTrue={
     BuiltinConditions.spell('bmguide-dr-barbed',BARBED,wrathSoon),
     BuiltinConditions.spell('bmguide-dr-wrath',WRATH),
     BuiltinConditions.spell('bmguide-dr-withering-arrow',BLACK,withering),
     BuiltinConditions.spell('bmguide-dr-kill',KILL,kill),
     BuiltinConditions.spell('bmguide-dr-wailing',WAILING,BuiltinConditions.all(withering,{type='BUFF_REMAIN',unit='player',spell=466991,ownbuff=true,operator='LESSTHAN',value=2})),
     BuiltinConditions.spell('bmguide-dr-fang',COBRA,buff(1299389)),
     BuiltinConditions.spell('bmguide-dr-wrath-cobra',COBRA,BuiltinConditions.all(buff(WRATH),{type='SPELL_CHARGES',spell=BARBED,operator='LESSTHAN',value=1})),
     BuiltinConditions.spell('bmguide-dr-black-arrow',BLACK),
     BuiltinConditions.spell('bmguide-dr-barbed-filler',BARBED),
     BuiltinConditions.spell('bmguide-dr-cobra',COBRA)},
    onFalse={
     BuiltinConditions.spell('bmguide-pl-barbed',BARBED,BuiltinConditions.any(wrathSoon,capping)),
     BuiltinConditions.spell('bmguide-pl-wrath',WRATH),
     BuiltinConditions.spell('bmguide-pl-wild-thrash',THRASH,engaged(2)),
     BuiltinConditions.spell('bmguide-pl-kill',KILL,kill),
     BuiltinConditions.spell('bmguide-pl-fang',COBRA,buff(1299389)),
     BuiltinConditions.spell('bmguide-pl-cobra',COBRA,BuiltinConditions.negate(wrathSoon)),
     BuiltinConditions.spell('bmguide-pl-barbed-focus',BARBED)}},
  },
 },
}))
