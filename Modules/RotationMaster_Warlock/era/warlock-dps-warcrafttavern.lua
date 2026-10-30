-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Warlock, Warcraft Tavern "drain tank" (alternative premade; same switch, lower
-- priority). The Imp, then the Succubus from level 20 (Dark Pact mana); solo: Immolate, Agony,
-- Corruption and Siphon Life, then Drain Life as the filler once its fourth rank is learned
-- (level 38; the wand before), Life Tap whenever health is nearly full, Dark Pact before the pet
-- is full; in raids every DoT the slots allow (Siphon Life on Shadow Vulnerability), Shadow Bolt.
-- Same boundaries, finishers, curse and safety reminders as the recommended premade
-- (era/blocks.lua). Left manual: fearing a second mob.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local raid={type='INSTANCE',value='raid'}
local summon=BuiltinConditions.all(BuiltinConditions.negate({type='PET'}),BuiltinConditions.negate({type='COMBAT',unit='player'}))
local blocks={['era.warlock.boundaries']=3,['era.warlock.procs']=1,['era.warlock.group-finish']=1,['era.warlock.dying']=2,['era.warlock.curse']=2,
 ['era.warlock.moving']=2,['era.warlock.aoe']=1,['era.warlock.filler']=2,['era.warlock.armor']=1,['era.warlock.safety']=1}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.warlock.dps.warcrafttavern',revision=6,blocks=blocks,
 applicability={families={'era'},actionContext='player',class='WARLOCK'},
 tags={'dps','ranged','caster','leveling','endgame','warcraft-tavern'},
 sources={{url='https://www.warcrafttavern.com/wow-classic/guides/warlock-leveling-guide/',title='Warcraft Tavern: Classic Warlock leveling guide',reviewedAt='2026-10-23'},
 {url='https://www.warcrafttavern.com/wow-classic/guides/pve-warlock-rotation/',title='Warcraft Tavern: Classic Warlock rotation',reviewedAt='2026-10-23'}},
 body={priority=5,disabled=true,
 cooldowns={block('era.warlock.armor','lock-wt-'),
  BuiltinConditions.spell('lock-wt-succubus',712,summon),
  BuiltinConditions.spell('lock-wt-imp',688,BuiltinConditions.all(summon,BuiltinConditions.negate(BuiltinConditions.known(712)))),
  block('era.warlock.safety','lock-wt-')},
 rotation={
 block('era.warlock.boundaries','lock-wt-'),
 block('era.warlock.procs','lock-wt-'),
 block('era.warlock.group-finish','lock-wt-'),
 block('era.warlock.dying','lock-wt-'),
 block('era.warlock.moving','lock-wt-'),
 block('era.warlock.aoe','lock-wt-'),
 block('era.warlock.curse','lock-wt-'),
 BuiltinConditions.spell('lock-wt-immolate',348,BuiltinConditions.negate(own(348))),
 BuiltinConditions.spell('lock-wt-siphon-life',18265,BuiltinConditions.all(BuiltinConditions.negate(own(18265)),BuiltinConditions.any(BuiltinConditions.negate(raid),{type='DEBUFF',unit='target',spell=17800,anyrank=true}))),
 BuiltinConditions.spell('lock-wt-corruption',172,BuiltinConditions.negate(own(172))),
 {id='lock-wt-solo',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
  BuiltinConditions.spell('lock-wt-dark-pact',18220,BuiltinConditions.all(mana('LESSTHAN',.8),{type='MANAPCT',unit='pet',operator='GREATERTHAN',value=.5})),
  BuiltinConditions.spell('lock-wt-life-tap',1454,BuiltinConditions.all(mana('LESSTHAN',.9),{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.9})),
  BuiltinConditions.spell('lock-wt-drain-life',689,BuiltinConditions.known(7651)),
  {id='lock-wt-wanding',type='stop',suppress_attack=true,conditions={type='SPELL_AUTOREPEAT',spell=5019,ranked=true}},
  BuiltinConditions.spell('lock-wt-wand',5019),
 }},
 block('era.warlock.filler','lock-wt-'),
 }},
}))
