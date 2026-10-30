-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Subtlety Rogue, Icy Veins and SimulationCraft's default list: the optimal
-- reference, disabled by default because Shadow Dance, Darkest Night and energy are hidden in
-- Midnight combat. Stealthed before the pull: Shadowstrike. One combo point short of full:
-- Eviscerate with Darkest Night, Secret Technique in Shadow Dance, Coup de Grace, Black Powder on
-- three or more enemies, Eviscerate. Otherwise build: Shadowstrike, Shuriken Storm on two or
-- more, Gloomblade or Backstab. Reminders: Goremaw's Bite in Shadow Dance, Shadow Blades with
-- Shadow Dance ready, Shadow Dance at two or fewer (or six or more) combo points with Secret
-- Technique ready or Shadow Blades up, Vanish out of stealth at two or fewer combo points.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function points(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function enemies(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=BuiltinConditions.all(BuiltinConditions.combat(),{type='ATTACKABLE',unit='target'})
local dance=BuiltinConditions.ownBuff(185422)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.rogue.subtlety.icyveins',revision=6,
 blocks={['retail.rogue.boundaries']=2,['retail.rogue.upkeep']=2},
 applicability={families={'retail'},actionContext='player',class='ROGUE'},
 tags={'subtlety','melee','reference','single-target','aoe','icy-veins','simulationcraft','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow/subtlety-rogue-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Subtlety Rogue rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/rogue_subtlety.simc',title='SimulationCraft: Subtlety Rogue default list',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
  {url='https://www.wowhead.com/guide/classes/rogue/subtlety/rotation-cooldowns-pve-dps',title='Wowhead: Subtlety Rogue rotation (Season 2)',reviewedAt='2026-10-23',revision='2026-08-22'},
 },
 body={priority=5,disabled=true,specs={261},
  cooldowns={
   block('retail.rogue.upkeep','subiv-'),
   BuiltinConditions.spell('subiv-goremaws-bite',426591,BuiltinConditions.all(fight,dance)),
   BuiltinConditions.spell('subiv-shadow-blades',121471,BuiltinConditions.all(fight,{type='SPELL_AVAIL',spell=185313})),
   BuiltinConditions.spell('subiv-shadow-dance',185313,BuiltinConditions.all(fight,BuiltinConditions.negate(dance),BuiltinConditions.any(points('LESSTHANOREQUALS',2),points('GREATERTHANOREQUALS',6)),BuiltinConditions.any({type='SPELL_AVAIL',spell=280719},BuiltinConditions.ownBuff(121471)))),
   BuiltinConditions.spell('subiv-vanish',1856,BuiltinConditions.all(fight,BuiltinConditions.negate({type='STEALTHED'}),points('LESSTHANOREQUALS',2))),
  },
  rotation={
   block('retail.rogue.boundaries','subiv-'),
   {id='subiv-opener',type='branch',conditions=BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),{type='STEALTHED'}),onFalse={},onTrue={
    BuiltinConditions.spell('subiv-opener-shadowstrike',185438),
    {id='subiv-opener-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   {id='subiv-finish',type='branch',conditions=points('LESSTHANOREQUALS',-1),onFalse={
    BuiltinConditions.spell('subiv-shadowstrike',185438),
    BuiltinConditions.spell('subiv-shuriken-storm',197835,enemies(2)),
    BuiltinConditions.spell('subiv-gloomblade',200758),
    BuiltinConditions.spell('subiv-backstab',53),
   },onTrue={
    BuiltinConditions.spell('subiv-darkest-night',196819,BuiltinConditions.ownBuff(457280)),
    BuiltinConditions.spell('subiv-secret-technique',280719,dance),
    BuiltinConditions.spell('subiv-coup-de-grace',441776),
    BuiltinConditions.spell('subiv-black-powder',319175,enemies(3)),
    BuiltinConditions.spell('subiv-eviscerate',196819),
   }},
  },
 },
}))
