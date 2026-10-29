-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Warlock, levels 1–60, every tree (the recommended vanilla premade; also Hardcore and
-- Self-Found). Wowhead's raid gates with every source's finish and Icy Veins' leveling: procs
-- first; Shadowburn and Searing Pain to finish a group target; a dying solo target gets Drain Soul
-- or a finisher, not DoTs; instants while moving; Hellfire or Rain of Fire on packs; one curse
-- (raid Curse of Shadow or Elements when nobody has it, Doom on long fights, else Agony);
-- Immolate when it pays (Destruction, raids, or with 40% mana), Corruption, Siphon Life (in
-- raids only on Shadow Vulnerability); solo Dark Pact, Life Tap, Drain Life when hurt, the wand;
-- Shadow Bolt. Shared parts: era/blocks.lua. Left manual: curse assignments (Recklessness,
-- Tongues), Fear, Banish, Soulstones and creating Healthstones.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local raid={type='INSTANCE',value='raid'}
local lasting=BuiltinConditions.any({type='GROUP'},{type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'},
 {type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.4})
local blocks={['era.warlock.boundaries']=3,['era.warlock.procs']=1,['era.warlock.group-finish']=1,['era.warlock.dying']=2,['era.warlock.curse']=2,
 ['era.warlock.moving']=2,['era.warlock.aoe']=1,['era.warlock.sustain']=3,['era.warlock.filler']=2,['era.warlock.armor']=1,['era.warlock.pets']=1,['era.warlock.safety']=1}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.warlock.dps',revision=5,blocks=blocks,
 applicability={families={'era'},actionContext='player',class='WARLOCK'},
 tags={'dps','ranged','caster','leveling','endgame','aoe','wowhead','icy-veins','warcraft-tavern'},
 sources={{url='https://www.wowhead.com/classic/guide/classes/warlock/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Warlock DPS abilities and rotation',reviewedAt='2026-10-23',revision='2025-03-20'},
 {url='https://www.wowhead.com/classic/guides/warlock-leveling-classic-wow',title='Wowhead: Classic Warlock leveling guide',reviewedAt='2026-10-23',revision='2024-11-18'},
 {url='https://www.icy-veins.com/wow-classic/warlock-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Warlock DPS rotation',reviewedAt='2026-10-23',revision='2024-11-18'},
 {url='https://www.icy-veins.com/wow-classic/classic-warlock-leveling-guide',title='Icy Veins: Classic Warlock leveling guide',reviewedAt='2026-10-23',revision='2024-11-18'},
 {url='https://www.icy-veins.com/wow-classic/hardcore-warlock-class-overview',title='Icy Veins: Hardcore Warlock overview (safety)',reviewedAt='2026-10-23',revision='2023-05-26'},
 {url='https://www.warcrafttavern.com/wow-classic/guides/pve-warlock-rotation/',title='Warcraft Tavern: Classic Warlock rotation (raid DoTs)',reviewedAt='2026-10-23'},
 },
 body={priority=10,
 cooldowns={block('era.warlock.armor','lock-'),block('era.warlock.pets','lock-'),block('era.warlock.safety','lock-')},
 rotation={
 block('era.warlock.boundaries','lock-'),
 block('era.warlock.procs','lock-'),
 block('era.warlock.group-finish','lock-'),
 block('era.warlock.dying','lock-'),
 block('era.warlock.moving','lock-'),
 block('era.warlock.aoe','lock-'),
 block('era.warlock.curse','lock-'),
 BuiltinConditions.spell('lock-immolate',348,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.negate(own(348)),{type='DEBUFF_REMAIN',unit='target',spell=348,anyrank=true,owndebuff=true,operator='LESSTHAN',value=1.5}),
  BuiltinConditions.any(BuiltinConditions.known(17962),raid,{type='MANAPCT',unit='player',operator='GREATERTHAN',value=.4}),lasting)),
 BuiltinConditions.spell('lock-corruption',172,BuiltinConditions.negate(own(172))),
 BuiltinConditions.spell('lock-siphon-life',18265,BuiltinConditions.all(BuiltinConditions.negate(own(18265)),BuiltinConditions.any(BuiltinConditions.negate(raid),{type='DEBUFF',unit='target',spell=17800,anyrank=true}))),
 block('era.warlock.sustain','lock-'),
 block('era.warlock.filler','lock-'),
 }},
}))
