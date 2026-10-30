-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Outlaw Rogue, Icy Veins, SimulationCraft and Wowhead: the optimal reference,
-- disabled by default because Roll the Bones buffs, Opportunity stacks and energy are hidden in
-- Midnight combat. From stealth Ambush. One combo point short of full: Between the Eyes, Killing
-- Spree, Coup de Grace, Dispatch. Otherwise build: Ambush with Audacity, Pistol Shot at six
-- Opportunity stacks (three when low on combo points), Ambush (Hidden Opportunity), Sinister
-- Strike. Reminders: Roll the Bones with no roll up, Adrenaline Rush at two or fewer combo points,
-- Blade Flurry kept up on two or more enemies, Blade Rush, Preparation when Adrenaline Rush,
-- Between the Eyes and Blade Rush are all cooling. Keep It Rolling stays manual.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function points(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function opportunity(n)return{type='BUFF_STACKS',unit='player',spell=195627,ownbuff=true,operator='GREATERTHANOREQUALS',value=n}end
local function cooling(id)return BuiltinConditions.negate({type='SPELL_AVAIL',spell=id})end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=BuiltinConditions.all(BuiltinConditions.combat(),{type='ATTACKABLE',unit='target'})
local rolled=BuiltinConditions.any(BuiltinConditions.ownBuff(193356),BuiltinConditions.ownBuff(199600),BuiltinConditions.ownBuff(193358),BuiltinConditions.ownBuff(193357),BuiltinConditions.ownBuff(199603),BuiltinConditions.ownBuff(193359))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.rogue.outlaw.icyveins',revision=6,
 blocks={['retail.rogue.boundaries']=2,['retail.rogue.upkeep']=2},
 applicability={families={'retail'},actionContext='player',class='ROGUE'},
 tags={'outlaw','melee','reference','single-target','aoe','icy-veins','simulationcraft','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow/outlaw-rogue-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Outlaw Rogue rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/rogue_outlaw.simc',title='SimulationCraft: Outlaw Rogue default list',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
  {url='https://www.wowhead.com/guide/classes/rogue/outlaw/rotation-cooldowns-pve-dps',title='Wowhead: Outlaw Rogue rotation (Season 1)',reviewedAt='2026-10-23',revision='2026-04-23'},
 },
 body={priority=5,disabled=true,specs={260},
  cooldowns={
   block('retail.rogue.upkeep','outlawiv-'),
   BuiltinConditions.spell('outlawiv-roll-the-bones',1214909,BuiltinConditions.all(fight,BuiltinConditions.negate(rolled))),
   BuiltinConditions.spell('outlawiv-adrenaline-rush',13750,BuiltinConditions.all(fight,points('LESSTHANOREQUALS',2))),
   BuiltinConditions.spell('outlawiv-blade-flurry',13877,BuiltinConditions.all(fight,{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},
    BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.ownBuff(13877)),{type='BUFF_REMAIN',unit='player',spell=13877,ownbuff=true,operator='LESSTHAN',value=2}))),
   BuiltinConditions.spell('outlawiv-blade-rush',271877,fight),
   BuiltinConditions.spell('outlawiv-preparation',1277933,BuiltinConditions.all(fight,cooling(13750),cooling(315341),cooling(271877))),
  },
  rotation={
   block('retail.rogue.boundaries','outlawiv-'),
   {id='outlawiv-stealthed',type='branch',conditions={type='STEALTHED'},onFalse={},onTrue={
    BuiltinConditions.spell('outlawiv-stealthed-ambush',8676),
    {id='outlawiv-stealthed-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   {id='outlawiv-finish',type='branch',conditions=points('LESSTHANOREQUALS',-1),onFalse={
    BuiltinConditions.spell('outlawiv-audacity',8676,BuiltinConditions.ownBuff(386270)),
    BuiltinConditions.spell('outlawiv-pistol-shot',185763,BuiltinConditions.any(opportunity(6),BuiltinConditions.all(opportunity(3),points('LESSTHANOREQUALS',3)))),
    BuiltinConditions.spell('outlawiv-ambush',8676),
    BuiltinConditions.spell('outlawiv-sinister-strike',193315),
   },onTrue={
    BuiltinConditions.spell('outlawiv-between-the-eyes',315341),
    BuiltinConditions.spell('outlawiv-killing-spree',51690),
    BuiltinConditions.spell('outlawiv-coup-de-grace',441776),
    BuiltinConditions.spell('outlawiv-dispatch',2098),
   }},
  },
 },
}))
