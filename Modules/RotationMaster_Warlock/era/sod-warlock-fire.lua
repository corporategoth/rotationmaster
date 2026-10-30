-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Fire Warlock, levels 1–60 (Chaos Bolt or Incinerate engraved).
-- simulator/sod Phase 6 and Wowhead Phase 6: Shadowburn and Searing Pain to finish; instants while
-- moving; Incinerate's buff, Lake of Fire and Hellfire on packs; a curse (group Recklessness when
-- nobody has it, Doom on long fights, else Agony); Conflagrate only to keep Backdraft; Immolate
-- kept up; Incinerate's buff kept up; below 35% Soul Fire under Decimation instead of Chaos Bolt;
-- Soul Fire! procs; Chaos Bolt; solo Master Channeler Drain Life and Life Tap; Incinerate filler
-- (Shadow Bolt before it). Reminders: Fel Armor, the Imp, Amplify Curse and the safety ones.
-- Shared parts: era/blocks.lua. Left manual: curse assignments, consumables.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local big=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})
local lasting=BuiltinConditions.any({type='GROUP'},big,{type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.4})
local execute={type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.35}
local curses={980,603,1490,17862,704,1714,702,18223}
local cursed={type='OR',value={}};for i,id in ipairs(curses)do cursed.value[i]=own(id)end
local incinerated=BuiltinConditions.all(buff(412758),{type='BUFF_REMAIN',unit='player',spell=412758,operator='GREATERTHANOREQUALS',value=1.8})
local summon=BuiltinConditions.all(BuiltinConditions.negate({type='PET'}),BuiltinConditions.negate(BuiltinConditions.combat()))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.warlock.fire',revision=6,
 blocks={['era.warlock.boundaries']=3,['era.warlock.armor']=1,['era.warlock.safety']=1},
 applicability={families={'era'},actionContext='player',class='WARLOCK',rulesets={'season:2'}},
 tags={'dps','ranged','caster','leveling','endgame','aoe','season-of-discovery','wowhead'},
 sources={
 {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/warlock/dps-talent-builds-runes',title='Wowhead: SoD Warlock DPS talents and runes (Phase 6)',reviewedAt='2026-10-23',revision='2025-01-13'},
 {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/warlock/dps-leveling-tips',title='Wowhead: SoD Warlock DPS leveling tips',reviewedAt='2026-10-23',revision='2025-01-26'}},
 body={priority=70,switch=BuiltinConditions.any(rune(403629),rune(412758)),
 cooldowns={block('era.warlock.armor','sod-fire-'),
  BuiltinConditions.spell('sod-fire-imp',688,summon),
  block('era.warlock.safety','sod-fire-')},
 rotation={
 block('era.warlock.boundaries','sod-fire-'),
 BuiltinConditions.spell('sod-fire-finish-shadowburn',17877,BuiltinConditions.lifetime('LESSTHAN',1.5)),
 BuiltinConditions.spell('sod-fire-finish-searing-pain',5676,BuiltinConditions.lifetime('LESSTHAN',2.5)),
 {id='sod-fire-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  BuiltinConditions.spell('sod-fire-moving-shadowburn',17877,{type='CARRYING',item={6265},operator='GREATERTHANOREQUALS',value=2}),
  BuiltinConditions.spell('sod-fire-moving-conflagrate',17962,own(348)),
  BuiltinConditions.spell('sod-fire-moving-agony',980,BuiltinConditions.negate(cursed)),
  BuiltinConditions.spell('sod-fire-moving-lake-of-fire',460692),
  BuiltinConditions.spell('sod-fire-moving-tap',1454,BuiltinConditions.all(mana('LESSTHAN',.9),{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.5})),
  {id='sod-fire-moving-stop',type='stop',suppress_attack=true,conditions={}},
 }},
 {id='sod-fire-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  BuiltinConditions.spell('sod-fire-aoe-incinerate',412758,BuiltinConditions.negate(buff(412758))),
  BuiltinConditions.spell('sod-fire-aoe-lake-of-fire',460692),
  BuiltinConditions.spell('sod-fire-aoe-hellfire',1949,BuiltinConditions.all({type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=3},{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.5})),
 }},
 {id='sod-fire-curse',type='branch',conditions=cursed,onTrue={},onFalse={
  BuiltinConditions.spell('sod-fire-recklessness',704,BuiltinConditions.all({type='GROUP'},BuiltinConditions.negate({type='DEBUFF',unit='target',spell=704,anyrank=true}))),
  BuiltinConditions.spell('sod-fire-doom',603,BuiltinConditions.all({type='GROUP'},big,BuiltinConditions.lifetime('GREATERTHAN',60))),
  BuiltinConditions.spell('sod-fire-agony',980,lasting),
 }},
 BuiltinConditions.spell('sod-fire-conflagrate',17962,BuiltinConditions.all(own(348),BuiltinConditions.negate(buff(427714)))),
 BuiltinConditions.spell('sod-fire-immolate',348,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.negate(own(348)),{type='DEBUFF_REMAIN',unit='target',spell=348,anyrank=true,owndebuff=true,operator='LESSTHAN',value=2}),lasting)),
 BuiltinConditions.spell('sod-fire-incinerate-buff',412758,BuiltinConditions.negate(incinerated)),
 {id='sod-fire-execute',type='branch',conditions=execute,onFalse={},onTrue={
  BuiltinConditions.spell('sod-fire-execute-soul-fire',6353,buff(440873)),
 }},
 BuiltinConditions.spell('sod-fire-soul-fire-proc',6353,buff(457643)),
 BuiltinConditions.spell('sod-fire-chaos-bolt',403629,BuiltinConditions.negate(execute)),
 BuiltinConditions.spell('sod-fire-shadow-trance',686,buff(17941)),
 {id='sod-fire-solo',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
  BuiltinConditions.spell('sod-fire-drain-life',403677,BuiltinConditions.negate(own(403677))),
  BuiltinConditions.spell('sod-fire-solo-tap',1454,BuiltinConditions.all(mana('LESSTHAN',.5),{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.7})),
 }},
 BuiltinConditions.spell('sod-fire-tap',1454,mana('LESSTHAN',.1)),
 BuiltinConditions.spell('sod-fire-incinerate',412758),
 BuiltinConditions.spell('sod-fire-bolt',686,BuiltinConditions.negate(rune(412758))),
 }},
}))
