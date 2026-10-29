-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Fire Warlock, Icy Veins order (alternative premade; same switch, lower
-- priority). Differs where Icy Veins and Warcraft Tavern differ: Conflagrate on cooldown (not only
-- for Backdraft); Chaos Bolt on cooldown even below 35%; the damage curse only while moving (in a
-- group Recklessness when nobody has it). Shared parts: era/blocks.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local big=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})
local curses={980,603,1490,17862,704,1714,702,18223}
local cursed={type='OR',value={}};for i,id in ipairs(curses)do cursed.value[i]=own(id)end
local summon=BuiltinConditions.all(BuiltinConditions.negate({type='PET'}),BuiltinConditions.negate(BuiltinConditions.combat()))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.warlock.fire.icyveins',revision=6,
 blocks={['era.warlock.boundaries']=3,['era.warlock.armor']=1,['era.warlock.safety']=1},
 applicability={families={'era'},actionContext='player',class='WARLOCK',rulesets={'season:2'}},
 tags={'dps','ranged','caster','endgame','aoe','season-of-discovery','icy-veins','warcraft-tavern'},
 sources={{url='https://www.icy-veins.com/wow-classic/destruction-warlock-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Destruction Warlock DPS rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
 {url='https://www.warcrafttavern.com/wow-classic-sod/guides/destruction-warlock-dps/',title='Warcraft Tavern: SoD Destruction Warlock DPS (Phase 4)',reviewedAt='2026-10-23'}},
 body={priority=65,disabled=true,switch=BuiltinConditions.any(rune(403629),rune(412758)),
 cooldowns={block('era.warlock.armor','sod-fire-iv-'),
  BuiltinConditions.spell('sod-fire-iv-imp',688,summon),
  block('era.warlock.safety','sod-fire-iv-')},
 rotation={
 block('era.warlock.boundaries','sod-fire-iv-'),
 BuiltinConditions.spell('sod-fire-iv-finish-shadowburn',17877,BuiltinConditions.lifetime('LESSTHAN',1.5)),
 {id='sod-fire-iv-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  BuiltinConditions.spell('sod-fire-iv-moving-shadowburn',17877,{type='CARRYING',item={6265},operator='GREATERTHANOREQUALS',value=2}),
  BuiltinConditions.spell('sod-fire-iv-moving-doom',603,BuiltinConditions.all(BuiltinConditions.negate(cursed),big,BuiltinConditions.lifetime('GREATERTHAN',60))),
  BuiltinConditions.spell('sod-fire-iv-moving-agony',980,BuiltinConditions.negate(cursed)),
  BuiltinConditions.spell('sod-fire-iv-moving-lake-of-fire',460692),
  {id='sod-fire-iv-moving-stop',type='stop',suppress_attack=true,conditions={}},
 }},
 {id='sod-fire-iv-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  BuiltinConditions.spell('sod-fire-iv-aoe-incinerate',412758,BuiltinConditions.negate(buff(412758))),
  BuiltinConditions.spell('sod-fire-iv-aoe-lake-of-fire',460692),
  BuiltinConditions.spell('sod-fire-iv-aoe-hellfire',1949,BuiltinConditions.all({type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=3},{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.5})),
 }},
 BuiltinConditions.spell('sod-fire-iv-recklessness',704,BuiltinConditions.all({type='GROUP'},BuiltinConditions.negate(cursed),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=704,anyrank=true}))),
 BuiltinConditions.spell('sod-fire-iv-immolate',348,BuiltinConditions.negate(own(348))),
 BuiltinConditions.spell('sod-fire-iv-conflagrate',17962,own(348)),
 BuiltinConditions.spell('sod-fire-iv-chaos-bolt',403629),
 BuiltinConditions.spell('sod-fire-iv-incinerate-buff',412758,BuiltinConditions.negate(buff(412758))),
 BuiltinConditions.spell('sod-fire-iv-execute-soul-fire',6353,BuiltinConditions.all({type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.35},buff(440873))),
 BuiltinConditions.spell('sod-fire-iv-soul-fire-proc',6353,buff(457643)),
 BuiltinConditions.spell('sod-fire-iv-incinerate',412758),
 BuiltinConditions.spell('sod-fire-iv-bolt',686,BuiltinConditions.negate(rune(412758))),
 BuiltinConditions.spell('sod-fire-iv-tap',1454,{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.4}),
 }},
}))
