-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Shadow Priest, Icy Veins and SimulationCraft's default list: the optimal
-- reference, disabled by default because its DoT, Madness and Voidform timings are hidden in
-- Midnight combat. Vampiric Touch before the pull. Tentacle Slam to apply Vampiric Touch, both DoTs
-- refreshed in the last 30%, Shadow Word: Madness when it is ending or in Voidform, Void Blast during
-- Madness, Tentacle Slam at two charges, Void Torrent, Mind Blast, Tentacle Slam, Mind Flay: Insanity
-- during Madness, Void Volley; moving: Death and Pain; Mind Flay, clipped for a ready Mind Blast (the
-- channel is read by spell, so Void Torrent and other channels run out). Insanity and health are
-- secret on Retail, so the Insanity-cap Madness, the Shadow Word: Death execute and Desperate Prayer
-- are left to you. Reminders: Halo, Voidform with both DoTs up, Power Infusion in Voidform.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function dot(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function dotRemain(id,v)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator='LESSTHAN',value=v}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=BuiltinConditions.all(BuiltinConditions.combat(),{type='ATTACKABLE',unit='target'})
local madness=dot(335467)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.priest.shadow.icyveins',revision=8,
 blocks={['retail.priest.upkeep']=2},
 applicability={families={'retail'},actionContext='player',class='PRIEST'},
 tags={'shadow','ranged','reference','single-target','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/shadow-priest-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Shadow Priest rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/priest_shadow.simc',title='SimulationCraft: Shadow Priest default list',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
 },
 body={priority=5,disabled=true,specs={258},
  cooldowns={
   block('retail.priest.upkeep','shadowiv-'),
   BuiltinConditions.spell('shadowiv-shadowform',232698,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate(BuiltinConditions.ownBuff(232698)),BuiltinConditions.negate(BuiltinConditions.ownBuff(194249)))),
   BuiltinConditions.spell('shadowiv-halo',120644,fight),
   BuiltinConditions.spell('shadowiv-voidform',228260,BuiltinConditions.all(fight,dot(34914),dot(589))),
   BuiltinConditions.spell('shadowiv-power-infusion',10060,BuiltinConditions.all(fight,BuiltinConditions.ownBuff(194249))),
  },
  rotation={
   {id='shadowiv-casting',type='stop',suppress_attack=true,conditions=BuiltinConditions.any({type='CASTING',unit='player'},BuiltinConditions.all({type='CHANNELING',unit='player'},
    BuiltinConditions.negate(BuiltinConditions.all(BuiltinConditions.any({type='CHANNELING_SPELL',unit='player',spell=15407},{type='CHANNELING_SPELL',unit='player',spell=391403}),{type='SPELL_AVAIL',spell=8092}))),
    BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))},
   {id='shadowiv-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
    BuiltinConditions.spell('shadowiv-pull-vampiric-touch',34914,BuiltinConditions.negate(dot(34914))),
    {id='shadowiv-pull-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   BuiltinConditions.spell('shadowiv-tentacle-touch',1227280,BuiltinConditions.negate(dot(34914))),
   BuiltinConditions.spell('shadowiv-vampiric-touch',34914,BuiltinConditions.any(BuiltinConditions.negate(dot(34914)),dotRemain(34914,6.3))),
   BuiltinConditions.spell('shadowiv-shadow-word-pain',589,BuiltinConditions.any(BuiltinConditions.negate(dot(589)),dotRemain(589,4.8))),
   BuiltinConditions.spell('shadowiv-madness',335467,BuiltinConditions.any(BuiltinConditions.negate(madness),dotRemain(335467,1.5),BuiltinConditions.ownBuff(194249))),
   BuiltinConditions.spell('shadowiv-void-blast',450983,madness),
   BuiltinConditions.spell('shadowiv-tentacle-capped',1227280,{type='SPELL_CHARGES',spell=1227280,operator='GREATERTHANOREQUALS',value=2}),
   BuiltinConditions.spell('shadowiv-void-torrent',263165),
   BuiltinConditions.spell('shadowiv-mind-blast',8092),
   BuiltinConditions.spell('shadowiv-tentacle-slam',1227280),
   BuiltinConditions.spell('shadowiv-mind-flay-insanity',391403,madness),
   BuiltinConditions.spell('shadowiv-void-volley',1242173),
   {id='shadowiv-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    BuiltinConditions.spell('shadowiv-moving-death',32379),
    BuiltinConditions.spell('shadowiv-moving-pain',589),
   }},
   BuiltinConditions.spell('shadowiv-mind-flay',15407),
  },
 },
}))
