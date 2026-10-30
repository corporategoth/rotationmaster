-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Enhancement Shaman, Stormbringer (SimulationCraft's single_sb and aoe lists,
-- Icy Veins, Wowhead): the optimal reference, disabled by default because Flame Shock, Crash
-- Lightning, Lashing Flames and cooldown timings are hidden in Midnight combat (Maelstrom Weapon
-- itself stays readable). Three or more engaged enemies: Crash Lightning to keep its buff,
-- Tempest at 10 Maelstrom Weapon, Chain Lightning at 9+, Crash Lightning, Lava Lash, Sundering.
-- Then: Primordial Storm at 9+, Voltaic Blaze or Flame Shock when Flame Shock is missing,
-- Sundering, Crash Lightning to keep its buff, Lava Lash to apply Lashing Flames, Windstrike,
-- Tempest or Lightning Bolt at 10 (8+ with Voltaic Blaze or Crash Lightning about ready),
-- Stormstrike at two charges, Lava Lash, Stormstrike, Voltaic Blaze, Crash Lightning, Lightning
-- Bolt at 5+, Flame Shock. Reminders: Doom Winds, Ascendance, Feral Spirit.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function mw(n)return{type='BUFF_STACKS',unit='player',spell=344179,ownbuff=true,operator='GREATERTHANOREQUALS',value=n}end
local function soon(id)return{type='SPELL_COOLDOWN',spell=id,operator='LESSTHAN',value=1.5}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=BuiltinConditions.all(BuiltinConditions.combat(),{type='ATTACKABLE',unit='target'})
local shocked={type='DEBUFF',unit='target',spell=188389,owndebuff=true}
local nearly=BuiltinConditions.all(mw(8),BuiltinConditions.any(soon(470057),soon(187874)))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.shaman.enhancement.stormbringer',revision=6,
 blocks={['retail.shaman.boundaries']=2,['retail.shaman.upkeep']=2,['retail.shaman.lightning-shield']=1},
 applicability={families={'retail'},actionContext='player',class='SHAMAN'},
 tags={'enhancement','melee','reference','stormbringer','single-target','aoe','icy-veins','simulationcraft','wowhead'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/shaman_enhancement.simc',title='SimulationCraft: Enhancement Shaman default list (single_sb, aoe)',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
  {url='https://www.icy-veins.com/wow/enhancement-shaman-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Enhancement Shaman rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://www.wowhead.com/guide/classes/shaman/enhancement/rotation-cooldowns-pve-dps',title='Wowhead: Enhancement Shaman rotation',reviewedAt='2026-10-23',revision='2026-08-12'},
 },
 body={priority=5,disabled=true,specs={263},
  cooldowns={
   block('retail.shaman.upkeep','enhsb-'),
   block('retail.shaman.lightning-shield','enhsb-'),
   BuiltinConditions.spell('enhsb-doom-winds',384352,fight),
   BuiltinConditions.spell('enhsb-ascendance',114051,BuiltinConditions.all(fight,BuiltinConditions.negate(BuiltinConditions.ownBuff(466772)))),
   BuiltinConditions.spell('enhsb-feral-spirit',51533,fight),
  },
  rotation={
   block('retail.shaman.boundaries','enhsb-'),
   {id='enhsb-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    BuiltinConditions.spell('enhsb-aoe-crash-buff',187874,BuiltinConditions.negate(BuiltinConditions.ownBuff(187878))),
    BuiltinConditions.spell('enhsb-aoe-tempest',452201,mw(10)),
    BuiltinConditions.spell('enhsb-aoe-chain-lightning',188443,mw(9)),
    BuiltinConditions.spell('enhsb-aoe-crash-lightning',187874),
    BuiltinConditions.spell('enhsb-aoe-lava-lash',60103),
    BuiltinConditions.spell('enhsb-aoe-sundering',197214),
   }},
   BuiltinConditions.spell('enhsb-primordial-storm',1218090,mw(9)),
   BuiltinConditions.spell('enhsb-voltaic-opener',470057,BuiltinConditions.negate(shocked)),
   BuiltinConditions.spell('enhsb-flame-shock-missing',470411,BuiltinConditions.negate(shocked)),
   BuiltinConditions.spell('enhsb-sundering',197214),
   BuiltinConditions.spell('enhsb-crash-buff',187874,BuiltinConditions.negate(BuiltinConditions.ownBuff(187878))),
   BuiltinConditions.spell('enhsb-lashing-flames',60103,BuiltinConditions.negate({type='DEBUFF',unit='target',spell=334168,owndebuff=true})),
   BuiltinConditions.spell('enhsb-windstrike',115356),
   BuiltinConditions.spell('enhsb-tempest-full',452201,mw(10)),
   BuiltinConditions.spell('enhsb-bolt-full',188196,mw(10)),
   BuiltinConditions.spell('enhsb-tempest-early',452201,nearly),
   BuiltinConditions.spell('enhsb-bolt-early',188196,nearly),
   BuiltinConditions.spell('enhsb-stormstrike-capped',17364,{type='SPELL_CHARGES',spell=17364,operator='GREATERTHANOREQUALS',value=2}),
   BuiltinConditions.spell('enhsb-lava-lash',60103),
   BuiltinConditions.spell('enhsb-stormstrike',17364),
   BuiltinConditions.spell('enhsb-voltaic-blaze',470057),
   BuiltinConditions.spell('enhsb-crash-lightning',187874),
   BuiltinConditions.spell('enhsb-bolt',188196,mw(5)),
   BuiltinConditions.spell('enhsb-flame-shock',470411),
  },
 },
}))
