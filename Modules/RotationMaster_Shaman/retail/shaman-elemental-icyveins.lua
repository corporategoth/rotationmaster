-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Elemental Shaman, Icy Veins and SimulationCraft's default list: the optimal
-- reference, disabled by default because Flame Shock, Master of the Elements and Stormkeeper are
-- hidden in Midnight combat. Before the pull Stormkeeper and Lava Burst. Three or
-- more engaged enemies: Stormkeeper, Ancestral Swiftness, Flame Shock, Chain Lightning with
-- Stormkeeper, Elemental Blast, Earthquake, Lava Burst on Lava Surge, Tempest, Chain Lightning.
-- One or two: Stormkeeper, Ancestral Swiftness, Flame Shock and Voltaic Blaze in their last 30%
-- outside Master of the Elements, Lava Burst to start it, Tempest and Stormkeeper's Lightning Bolt
-- inside it, Elemental Blast or Earth Shock inside it, Voltaic Blaze, Tempest; moving Flame Shock
-- and Frost Shock; Elemental Blast or Earth Shock whenever affordable; Lightning Bolt. Maelstrom is
-- secret on Retail, so the spenders go at their cost instead of near full Maelstrom.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=BuiltinConditions.all(BuiltinConditions.combat(),{type='ATTACKABLE',unit='target'})
local motE=BuiltinConditions.ownBuff(260734)
local shocked={type='DEBUFF',unit='target',spell=188389,owndebuff=true}
local refresh=BuiltinConditions.any(BuiltinConditions.negate(shocked),{type='DEBUFF_REMAIN',unit='target',spell=188389,owndebuff=true,operator='LESSTHAN',value=5.4})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.shaman.elemental.icyveins',revision=7,
 blocks={['retail.shaman.boundaries']=2,['retail.shaman.upkeep']=2,['retail.shaman.lightning-shield']=1},
 applicability={families={'retail'},actionContext='player',class='SHAMAN'},
 tags={'elemental','ranged','reference','single-target','aoe','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/elemental-shaman-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Elemental Shaman rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/shaman_elemental.simc',title='SimulationCraft: Elemental Shaman default list',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
 },
 body={priority=5,disabled=true,specs={262},
  cooldowns={
   block('retail.shaman.upkeep','eleiv-'),
   block('retail.shaman.lightning-shield','eleiv-'),
   BuiltinConditions.spell('eleiv-ascendance',114050,BuiltinConditions.all(fight,BuiltinConditions.negate({type='SPELL_AVAIL',spell=191634}))),
   BuiltinConditions.spell('eleiv-fire-elemental',198067,fight),
   BuiltinConditions.spell('eleiv-storm-elemental',192249,fight),
   BuiltinConditions.spell('eleiv-spiritwalkers-grace',79206,BuiltinConditions.all(fight,{type='MOVING'})),
  },
  rotation={
   block('retail.shaman.boundaries','eleiv-'),
   {id='eleiv-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
    BuiltinConditions.spell('eleiv-pull-stormkeeper',191634),
    BuiltinConditions.spell('eleiv-pull-lava-burst',51505),
    {id='eleiv-pull-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   {id='eleiv-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    BuiltinConditions.spell('eleiv-aoe-stormkeeper',191634),
    BuiltinConditions.spell('eleiv-aoe-ancestral-swiftness',443454),
    BuiltinConditions.spell('eleiv-aoe-flame-shock',470411,BuiltinConditions.all(BuiltinConditions.negate(shocked),BuiltinConditions.negate(motE))),
    BuiltinConditions.spell('eleiv-aoe-stormkeeper-chain',188443,BuiltinConditions.ownBuff(191634)),
    BuiltinConditions.spell('eleiv-aoe-elemental-blast',117014),
    BuiltinConditions.spell('eleiv-aoe-earthquake',61882),
    BuiltinConditions.spell('eleiv-aoe-earthquake-targeted',462620),
    BuiltinConditions.spell('eleiv-aoe-lava-surge',51505,BuiltinConditions.ownBuff(77762)),
    BuiltinConditions.spell('eleiv-aoe-tempest',452201),
    BuiltinConditions.spell('eleiv-aoe-chain-lightning',188443),
   }},
   BuiltinConditions.spell('eleiv-stormkeeper',191634),
   BuiltinConditions.spell('eleiv-ancestral-swiftness',443454),
   BuiltinConditions.spell('eleiv-flame-shock',470411,BuiltinConditions.all(refresh,BuiltinConditions.negate(motE))),
   BuiltinConditions.spell('eleiv-voltaic-blaze-refresh',470057,BuiltinConditions.all(refresh,BuiltinConditions.negate(motE))),
   BuiltinConditions.spell('eleiv-lava-burst',51505,BuiltinConditions.all(BuiltinConditions.negate(motE),BuiltinConditions.any(BuiltinConditions.ownBuff(77762),{type='SPELL_CHARGES',spell=51505,operator='GREATERTHANOREQUALS',value=2}))),
   BuiltinConditions.spell('eleiv-tempest-mote',452201,motE),
   BuiltinConditions.spell('eleiv-stormkeeper-bolt',188196,BuiltinConditions.all(BuiltinConditions.ownBuff(191634),motE)),
   BuiltinConditions.spell('eleiv-elemental-blast',117014,motE),
   BuiltinConditions.spell('eleiv-earth-shock',8042,motE),
   BuiltinConditions.spell('eleiv-voltaic-blaze',470057),
   BuiltinConditions.spell('eleiv-tempest',452201),
   {id='eleiv-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    BuiltinConditions.spell('eleiv-moving-flame-shock',470411),
    BuiltinConditions.spell('eleiv-moving-frost-shock',196840),
   }},
   BuiltinConditions.spell('eleiv-elemental-blast-spend',117014),
   BuiltinConditions.spell('eleiv-earth-shock-spend',8042),
   BuiltinConditions.spell('eleiv-lightning-bolt',188196),
  },
 },
}))
