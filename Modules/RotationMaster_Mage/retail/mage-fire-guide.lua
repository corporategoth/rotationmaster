-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Fire Mage after SimulationCraft, Icy Veins and Wowhead (optimal reference):
-- Combustion as a Fire hard cast finishes; Fire Blast while hard-casting to turn Heating Up into Hot Streak;
-- Pyroblast (Flamestrike on four or more) on Hyperthermia, Meteor, then Hot Streak, Fire Blast on
-- Heating Up inside Combustion, Pyroclasm, Scorch on Heat Shimmer or on the move, Fire Blast on
-- Heating Up, Frostfire Bolt or Fireball. Disabled: Hot Streak, Heating Up, Pyroclasm and Fire Blast
-- charges are secret in Midnight combat.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local heating,combustion=buff(48107),buff(190319)
-- A Fire hard cast in progress (Fireball, Frostfire Bolt, Pyroblast, Flamestrike), read by spell, so a
-- mount, Hearthstone or Polymorph cast is not one.
local hardcast={type='OR',value={{type='CASTING_SPELL',unit='player',spell=133},{type='CASTING_SPELL',unit='player',spell=431044},
 {type='CASTING_SPELL',unit='player',spell=11366},{type='CASTING_SPELL',unit='player',spell=2120}}}
-- One priority, written for a spender: Pyroblast on one to three enemies, Flamestrike on four or more.
local function priority(p,spender)return{
 BuiltinConditions.spell(p..'hyperthermia',spender,buff(383874)),
 BuiltinConditions.spell(p..'meteor',153561),
 BuiltinConditions.spell(p..'hot-streak',spender,buff(48108)),
 BuiltinConditions.spell(p..'combustion-fire-blast',108853,BuiltinConditions.all(heating,combustion)),
 BuiltinConditions.spell(p..'pyroclasm',spender,buff(269651)),
 BuiltinConditions.spell(p..'heat-shimmer',2948,buff(458964)),
 BuiltinConditions.spell(p..'moving-scorch',2948,{type='MOVING'}),
 BuiltinConditions.spell(p..'fire-blast',108853,heating)}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.mage.fire.guide',revision=8,
 blocks={['retail.mage.boundaries']=3,['retail.mage.utility']=2},
 applicability={families={'retail'},actionContext='player',class='MAGE'},
 tags={'fire','caster','reference','icy-veins','wowhead','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/fire-mage-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Fire Mage rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://www.wowhead.com/guide/classes/mage/fire/rotation-cooldowns-pve-dps',title='Wowhead: Fire Mage rotation (Midnight Season 2)',reviewedAt='2026-10-23',revision='2026-08-16',notes='Read from a Wayback snapshot of 2026-09-17.'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/mage_fire.simc',title='SimulationCraft default action list: Fire',reviewedAt='2026-10-23',revision='c5fea93f'},
 },
 body={priority=10,disabled=true,specs={63},
  cooldowns={
   BuiltinConditions.block('fguide-utility','retail.mage.utility','fguide-'),
   BuiltinConditions.spell('fguide-barrier',235313,BuiltinConditions.combat()),
   BuiltinConditions.spell('fguide-combustion',190319,BuiltinConditions.all(BuiltinConditions.combat(),hardcast,{type='CASTING_REMAIN',unit='player',operator='LESSTHAN',value=1})),
  },
  rotation={
   BuiltinConditions.spell('fguide-casting-fire-blast',108853,BuiltinConditions.all(hardcast,heating)),
   BuiltinConditions.block('fguide-boundaries','retail.mage.boundaries','fguide-'),
   {id='fguide-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={BuiltinConditions.spell('fguide-pull-pyroblast',11366),BuiltinConditions.stop('fguide-pull-stop')}},
   {id='fguide-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=4},
    onTrue=priority('fguide-aoe-',2120),onFalse=priority('fguide-st-',11366)},
   BuiltinConditions.spell('fguide-frostfire-bolt',431044),
   BuiltinConditions.spell('fguide-fireball',133),
  },
 },
}))
