-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Enhancement Shaman, levels 1–60, Icy Veins order (the recommended Shaman
-- default, and every Shaman before a deep Elemental or Restoration talent).
-- Rank-1-style Lightning Bolt pull, Stormstrike on cooldown, a free Lightning Bolt at five
-- Maelstrom Weapon stacks, Fire Nova and Flame Shock on packs, Earth Shock into the Stormstrike
-- debuff, Flame Shock in groups, Earth Shock, then melee. Lightning Bolt fills the gap while the
-- target is out of melee range. Health, mana and time to die are secret or unavailable on
-- Forever, so self-heals, the low-mana casting pause (the Wowhead variant saves mana instead) and
-- the will-it-live checks are left out.
-- Left manual: totem placement presets (Call of the Elements), Frost Shock for threat, Purge,
-- Grounding/Tremor and other situational totems, Totemic Recall and Ghost Wolf.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function enemies(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function big()return BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})end
local function shocked()return{type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true}end
local stationary=BuiltinConditions.negate({type='MOVING'})
local ranged={type='BEYOND_MELEE',unit='target'}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.shaman.enhancement',revision=6,
 blocks={['forever.shaman.manual-target']=2,['forever.shaman.upkeep']=2,['forever.shaman.imbue']=1,['forever.shaman.group-totems']=1},
 applicability={families={'forever'},actionContext='player',class='SHAMAN'},
 tags={'dps','melee','leveling','endgame','aoe','icy-veins'},
 sources={{url='https://www.icy-veins.com/wow-forever/enhancement-shaman-melee-dps-pve-guide',title='Icy Veins: Forever Enhancement Shaman PvE guide',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.icy-veins.com/wow-forever/enhancement-shaman-leveling',title='Icy Veins: Forever Enhancement Shaman leveling',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://mobalytics.gg/wow-forever/classes/shaman-leveling-guide',title='Mobalytics: Forever Shaman leveling 1–30 (pre-30 imbue, Fire Nova, totems)',reviewedAt='2026-10-23',revision='2026-10-21'},
 {url='https://us.forums.blizzard.com/en/wow/t/2360696',title='Blizzard: WoW Forever beta development notes (Fire Nova, totems, Stormstrike)',reviewedAt='2026-10-23',revision='2026-10-16'}},
 body={priority=10,
 cooldowns={block('forever.shaman.upkeep','shaman-enh-'),block('forever.shaman.imbue','shaman-enh-'),block('forever.shaman.group-totems','shaman-enh-'),
  BuiltinConditions.spell('shaman-enh-magma-totem',8190,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='TOTEM',spell=1}),enemies(3))),
  BuiltinConditions.spell('shaman-enh-searing-totem',3599,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='TOTEM',spell=1}),BuiltinConditions.negate(BuiltinConditions.all(BuiltinConditions.known(8190),enemies(3))))),
  BuiltinConditions.spell('shaman-enh-rage-of-the-farseer',425336,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(big(),enemies(3)))),
  BuiltinConditions.spell('shaman-enh-stoneclaw-totem',5730,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='GROUP'}),enemies(2)))},
 rotation={
 block('forever.shaman.manual-target','shaman-enh-'),
 {id='shaman-enh-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('shaman-enh-pull-bolt',403,BuiltinConditions.all(ranged,stationary)),
  {id='shaman-enh-pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 BuiltinConditions.spell('shaman-enh-stormstrike',17364),
 BuiltinConditions.spell('shaman-enh-maelstrom-bolt',403,{type='BUFF_STACKS',unit='player',spell=408505,operator='GREATERTHANOREQUALS',value=5}),
 {id='shaman-enh-aoe',type='branch',conditions=enemies(3),onFalse={},onTrue={
  BuiltinConditions.spell('shaman-enh-fire-nova',408341,{type='TOTEM',spell=1}),
  BuiltinConditions.spell('shaman-enh-aoe-flame-shock',8050,BuiltinConditions.negate(shocked())),
 }},
 BuiltinConditions.spell('shaman-enh-stormstrike-shock',8042,{type='DEBUFF',unit='target',spell=17364,owndebuff=true}),
 BuiltinConditions.spell('shaman-enh-flame-shock',8050,BuiltinConditions.all({type='GROUP'},BuiltinConditions.negate(shocked()))),
 BuiltinConditions.spell('shaman-enh-earth-shock',8042),
 BuiltinConditions.spell('shaman-enh-bolt',403,BuiltinConditions.all(ranged,stationary)),
 }},
}))
