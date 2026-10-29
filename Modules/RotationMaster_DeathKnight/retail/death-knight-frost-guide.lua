-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Frost Death Knight after Icy Veins and SimulationCraft (optimal reference):
-- Obliterate on two Killing Machines (or one with runes to spare), Frost Strike into five Razorice
-- with Shattering Blade, Howling Blast on Rime, Obliterate on Killing Machine, Frost Strike,
-- Obliterate (runic power is secret on Retail, so there is no cap check). Three or more enemies:
-- Frostscythe and Glacial Advance take their places. Disabled: procs and debuffs are secret in
-- Midnight combat.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local pillar=buff(51271)
local km=buff(51124)
local strong=BuiltinConditions.any({type='BUFF_STACKS',unit='player',spell=51124,ownbuff=true,operator='GREATERTHANOREQUALS',value=2},BuiltinConditions.all(km,{type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=3}))
local shatter=BuiltinConditions.all({type='DEBUFF_STACKS',unit='target',spell=51714,owndebuff=true,operator='GREATERTHANOREQUALS',value=5},BuiltinConditions.known(207057))
-- One priority, written for a builder (Obliterate or Frostscythe) and a spender (Frost Strike or Glacial Advance).
local function priority(p,builder,spender)return{
 BuiltinConditions.spell(p..'strong',builder,strong),BuiltinConditions.spell(p..'shatter',spender,shatter),BuiltinConditions.spell(p..'rime',49184,buff(59052)),
 BuiltinConditions.spell(p..'killing-machine',builder,km),BuiltinConditions.spell(p..'spend',spender),BuiltinConditions.spell(p..'build',builder)}end
local aoe=priority('fguide-aoe-',207230,194913)
aoe[#aoe+1]=BuiltinConditions.spell('fguide-aoe-obliterate',49020);aoe[#aoe+1]=BuiltinConditions.spell('fguide-aoe-frost-strike',49143)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.deathknight.frost.guide',revision=6,
 blocks={['retail.deathknight.boundaries']=3,['retail.deathknight.utility']=2},
 applicability={families={'retail'},actionContext='player',class='DEATHKNIGHT'},
 tags={'frost','melee','reference','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/frost-death-knight-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Frost Death Knight rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/deathknight_frost.simc',title='SimulationCraft default action list: Frost',reviewedAt='2026-10-23',revision='c5fea93f'},
 },
 body={priority=10,disabled=true,specs={251},
  cooldowns={
   BuiltinConditions.block('fguide-utility','retail.deathknight.utility','fguide-'),
   BuiltinConditions.spell('fguide-remorseless-winter',196770,BuiltinConditions.combat()),
   BuiltinConditions.spell('fguide-pillar-of-frost',51271,BuiltinConditions.combat()),
   BuiltinConditions.spell('fguide-breath-of-sindragosa',152279,pillar),
   BuiltinConditions.spell('fguide-reapers-mark',439843,BuiltinConditions.combat()),
   BuiltinConditions.spell('fguide-frostwyrms-fury',279302,pillar),
   BuiltinConditions.spell('fguide-raise-dead',46585,BuiltinConditions.combat()),
   BuiltinConditions.spell('fguide-empower-rune-weapon',47568,BuiltinConditions.all(BuiltinConditions.combat(),{type='SPELL_CHARGES',spell=47568,operator='GREATERTHANOREQUALS',value=2})),
  },
  rotation={
   BuiltinConditions.block('fguide-boundaries','retail.deathknight.boundaries','fguide-'),
   {id='fguide-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},
    onTrue=aoe,onFalse=priority('fguide-st-',49020,49143)},
   BuiltinConditions.spell('fguide-ranged-howling-blast',49184,{type='BEYOND_MELEE',unit='target'}),
  },
 },
}))
