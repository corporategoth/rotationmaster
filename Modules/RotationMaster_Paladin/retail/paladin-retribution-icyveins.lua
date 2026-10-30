-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Retribution Paladin, Icy Veins and SimulationCraft's default list: the optimal
-- reference, disabled by default because its buffs, charges and enemy count are hidden in
-- Midnight combat. Hammer of Light; a free (Divine Purpose) spender; at 5 Holy Power with Wake of
-- Ashes cooling, the spender (SimulationCraft's finishers at holy_power=5 before Wake); Wake of
-- Ashes and Divine Toll; Blade of Justice on Art of War; Hammer of Wrath before it caps; then the
-- spender at 3+ Holy Power (Divine Storm on two or more enemies or with Empyrean Power), Hammer of
-- Wrath, Blade of Justice, Judgment and the builders. Avenging Wrath and Execution Sentence (with
-- Wake of Ashes ready) are reminders. Holy Power is never secret for the player in Midnight.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function holyPower(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=BuiltinConditions.all(BuiltinConditions.combat(),{type='ATTACKABLE',unit='target'})
local spread=BuiltinConditions.any({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},BuiltinConditions.ownBuff(326733))
-- Holy Power is read first so a hidden Empyrean Power cannot mask a readable answer.
local storm=BuiltinConditions.any(BuiltinConditions.all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},holyPower('GREATERTHANOREQUALS',3)),BuiltinConditions.ownBuff(326733))
local capped=BuiltinConditions.all(holyPower('GREATERTHANOREQUALS',5),BuiltinConditions.negate({type='SPELL_AVAIL',spell=255937}))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.paladin.retribution.icyveins',revision=7,
 blocks={['retail.paladin.boundaries']=2,['retail.paladin.upkeep']=2},
 applicability={families={'retail'},actionContext='player',class='PALADIN'},
 tags={'retribution','melee','reference','single-target','aoe','icy-veins','simulationcraft','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow/retribution-paladin-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Retribution Paladin rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/paladin_retribution.simc',title='SimulationCraft: Retribution Paladin default list',reviewedAt='2026-10-23',revision='c5fea93fb77d',notes='Finishers at holy_power=5 while Wake of Ashes is cooling, before Wake.'},
  {url='https://www.wowhead.com/guide/classes/paladin/retribution/rotation-cooldowns-pve-dps',title='Wowhead: Retribution Paladin rotation',reviewedAt='2026-10-23',revision='2026-04-21',notes='Matches the Icy Veins order; Hammer of Wrath above Blade of Justice for Herald of the Sun.'},
 },
 body={priority=5,disabled=true,specs={70},
  cooldowns={
   block('retail.paladin.upkeep','retiv-'),
   BuiltinConditions.spell('retiv-avenging-wrath',31884,fight),
   BuiltinConditions.spell('retiv-execution-sentence',343527,BuiltinConditions.all(fight,{type='SPELL_COOLDOWN',spell=255937,operator='LESSTHAN',value=1.5})),
   BuiltinConditions.spell('retiv-divine-protection',403876,BuiltinConditions.combat()),
  },
  rotation={
   block('retail.paladin.boundaries','retiv-'),
   BuiltinConditions.spell('retiv-hammer-of-light',427453),
   BuiltinConditions.spell('retiv-free-storm',53385,BuiltinConditions.all(BuiltinConditions.ownBuff(223819),spread)),
   BuiltinConditions.spell('retiv-free-verdict',383328,BuiltinConditions.ownBuff(223819)),
   BuiltinConditions.spell('retiv-capped-storm',53385,BuiltinConditions.all(capped,spread)),
   BuiltinConditions.spell('retiv-capped-verdict',383328,capped),
   BuiltinConditions.spell('retiv-capped-templars-verdict',85256,capped),
   BuiltinConditions.spell('retiv-wake-of-ashes',255937),
   BuiltinConditions.spell('retiv-divine-toll',375576),
   BuiltinConditions.spell('retiv-art-of-war',184575,BuiltinConditions.ownBuff(406086)),
   BuiltinConditions.spell('retiv-hammer-of-wrath-capped',24275,{type='SPELL_CHARGES',spell=24275,operator='GREATERTHANOREQUALS',value=2}),
   BuiltinConditions.spell('retiv-divine-storm',53385,storm),
   BuiltinConditions.spell('retiv-final-verdict',383328,holyPower('GREATERTHANOREQUALS',3)),
   BuiltinConditions.spell('retiv-templars-verdict',85256,holyPower('GREATERTHANOREQUALS',3)),
   BuiltinConditions.spell('retiv-hammer-of-wrath',24275),
   BuiltinConditions.spell('retiv-blade-of-justice',184575),
   BuiltinConditions.spell('retiv-judgment',20271),
   BuiltinConditions.spell('retiv-templar-strike',407480),
   BuiltinConditions.spell('retiv-templar-slash',406647),
   BuiltinConditions.spell('retiv-crusader-strike',35395),
  },
 },
}))
