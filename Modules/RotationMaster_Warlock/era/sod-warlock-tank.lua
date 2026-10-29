-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Warlock tank, levels 1–60 (Metamorphosis engraved). simulator/sod Phase 4 tank
-- order with Icy Veins, Wowhead and Warcraft Tavern: Shadow Cleave whenever Defender's Resolve is
-- missing or ending (even on one target); a Soul Fire! proc; Incinerate to keep its fire buff; on
-- three engaged enemies Shadow Cleave, Lake of Fire, Shadowflame and Hellfire; a curse (Agony,
-- else Recklessness when nobody has it); Shadowflame (Immolate before it); Master Channeler Drain
-- Life; Corruption; Siphon Life; Conflagrate for Backdraft; Soul Fire under Decimation below 35%;
-- Searing Pain as the threat filler. Reminders: Metamorphosis, Fel Armor, the pet, Immolation
-- Aura, Demonic Grace, Vengeance, Menace when the target is not on you, Demonic Howl on packs, Life
-- Tap for a thirsty pet. Shared parts: era/blocks.lua. Left manual: Infernal Armor.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function remain(id,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,anyrank=true,owndebuff=true,operator='LESSTHAN',value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local lasting=BuiltinConditions.any({type='GROUP'},{type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'},
 {type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.4})
local curses={980,603,1490,17862,704,1714,702,18223}
local cursed={type='OR',value={}};for i,id in ipairs(curses)do cursed.value[i]=own(id)end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.warlock.tank',revision=6,
 blocks={['era.warlock.boundaries']=3,['era.warlock.armor']=1,['era.warlock.pets']=1},
 applicability={families={'era'},actionContext='player',class='WARLOCK',rulesets={'season:2'}},
 tags={'tank','ranged','caster','endgame','aoe','season-of-discovery','icy-veins','wowhead','warcraft-tavern'},
 sources={
 {url='https://www.icy-veins.com/wow-classic/demonology-warlock-tank-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Demonology Warlock tank rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
 {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/warlock/tank-overview',title='Wowhead: SoD Warlock tank overview',reviewedAt='2026-10-23',revision='2025-01-26'},
 {url='https://www.warcrafttavern.com/wow-classic-sod/guides/warlock-tank/',title='Warcraft Tavern: SoD Warlock tank (Phase 4)',reviewedAt='2026-10-23'}},
 body={priority=80,switch=rune(403789),
 cooldowns={
  BuiltinConditions.spell('sod-tank-metamorphosis',403789,BuiltinConditions.negate(buff(403789))),
  block('era.warlock.armor','sod-tank-'),
  block('era.warlock.pets','sod-tank-'),
  BuiltinConditions.spell('sod-tank-immolation-aura',427726,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(buff(427726)))),
  BuiltinConditions.spell('sod-tank-demonic-grace',425463,BuiltinConditions.combat()),
  BuiltinConditions.spell('sod-tank-vengeance',426195,BuiltinConditions.all(BuiltinConditions.combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.4})),
  BuiltinConditions.spell('sod-tank-menace',403828,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},BuiltinConditions.negate({type='ISSAME',unit='targettarget',otherunit='player'}))),
  BuiltinConditions.spell('sod-tank-demonic-howl',412789,BuiltinConditions.all(BuiltinConditions.combat(),{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3})),
  BuiltinConditions.spell('sod-tank-amplify-curse',18288,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(own(980)))),
  BuiltinConditions.spell('sod-tank-pet-life-tap',1454,BuiltinConditions.all(BuiltinConditions.combat(),{type='PET'},{type='MANAPCT',unit='pet',operator='LESSTHAN',value=.3},{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.6})),
 },
 rotation={
 block('era.warlock.boundaries','sod-tank-'),
 BuiltinConditions.spell('sod-tank-shadow-cleave',403835,BuiltinConditions.any(BuiltinConditions.negate(buff(460200)),{type='BUFF_REMAIN',unit='player',spell=460200,operator='LESSTHAN',value=1.5})),
 BuiltinConditions.spell('sod-tank-soul-fire-proc',6353,buff(457643)),
 BuiltinConditions.spell('sod-tank-incinerate',412758,BuiltinConditions.any(BuiltinConditions.negate(buff(412758)),{type='BUFF_REMAIN',unit='player',spell=412758,operator='LESSTHAN',value=3})),
 {id='sod-tank-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  BuiltinConditions.spell('sod-tank-aoe-shadow-cleave',403835),
  BuiltinConditions.spell('sod-tank-aoe-lake-of-fire',460692),
  BuiltinConditions.spell('sod-tank-aoe-shadowflame',426320,BuiltinConditions.negate(own(426320))),
  BuiltinConditions.spell('sod-tank-aoe-hellfire',1949,{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.5}),
 }},
 {id='sod-tank-curse',type='branch',conditions=cursed,onTrue={},onFalse={
  BuiltinConditions.spell('sod-tank-agony',980,lasting),
  BuiltinConditions.spell('sod-tank-recklessness',704,BuiltinConditions.negate({type='DEBUFF',unit='target',spell=704,anyrank=true})),
 }},
 BuiltinConditions.spell('sod-tank-shadowflame',426320,BuiltinConditions.all(BuiltinConditions.negate(own(426320)),lasting)),
 BuiltinConditions.spell('sod-tank-drain-life',403677,BuiltinConditions.negate(own(403677))),
 BuiltinConditions.spell('sod-tank-immolate',348,BuiltinConditions.all(BuiltinConditions.negate(rune(426320)),BuiltinConditions.any(BuiltinConditions.negate(own(348)),remain(348,1.5)),lasting)),
 BuiltinConditions.spell('sod-tank-corruption',172,BuiltinConditions.all(BuiltinConditions.negate(own(172)),lasting)),
 BuiltinConditions.spell('sod-tank-siphon-life',18265,BuiltinConditions.all(BuiltinConditions.negate(own(18265)),lasting)),
 BuiltinConditions.spell('sod-tank-conflagrate',17962,BuiltinConditions.all(own(348),BuiltinConditions.negate(buff(427714)))),
 BuiltinConditions.spell('sod-tank-decimation-soul-fire',6353,BuiltinConditions.all({type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.35},buff(440873))),
 BuiltinConditions.spell('sod-tank-searing-pain',5676),
 BuiltinConditions.spell('sod-tank-life-tap',1454,{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.5}),
 }},
}))
