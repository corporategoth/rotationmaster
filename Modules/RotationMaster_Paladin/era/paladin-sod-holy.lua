-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Holy (Icy Veins and Warcraft Tavern, Phase 4: no later healing guide exists):
-- chosen in a group by an engraved Beacon of Light, Divine Light or Sacred Shield, or by the Holy tree
-- without Crusader Strike. Heals act on your friendly target: Cleanse, Holy Shock while moving or for
-- a target below 30%, Divine Light (else Holy Light) below 60%, Flash of Light below 90%. Beacon and
-- Sacred Shield are reminders for the target that lacks them. Choosing whom to heal stays with you.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function hurt(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.paladin.holy',revision=6,
 blocks={['sod.paladin.holy-upkeep']=2,['era.paladin.boundaries']=2,['era.paladin.cleanse']=1,['sod.paladin.holy-hostile']=3},
 nameKey="Holy (SoD)",descriptionKey="Season of Discovery healing in a group, chosen by an engraved Beacon of Light, Divine Light or Sacred Shield, or the Holy tree without Crusader Strike. Acts on your friendly target: Cleanse, Holy Shock while moving or below 30%, Divine Light (Holy Light when mana is under half) below 60%, Flash of Light below 90%. With an enemy in melee range it only keeps a seal up. Reminders: Beacon of Light and Sacred Shield on the target that lacks them, Concentration or Devotion Aura, Blessing of Wisdom, Divine Favor and Lay on Hands for a target that is very low. The guides behind it are from Phase 4; choosing whom to heal stays with you.",
 applicability={families={'era'},actionContext='player',class='PALADIN',rulesets={'season:2'}},
 tags={'leveling','endgame','holy','healer','dungeon','raid','season-of-discovery','icy-veins','warcraft-tavern'},
 sources={{url='https://www.icy-veins.com/wow-classic/holy-paladin-healer-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Holy Paladin rotation (Phase 4)',reviewedAt='2026-10-23',revision='2024-07-09'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/season-of-discovery-sod-paladin-healer-build/',title='Warcraft Tavern: SoD Paladin healer guide (Phase 4)',reviewedAt='2026-10-23'}},
 body={priority=110,switch=all({type='GROUP'},any(rune(407613),rune(458856),rune(412019),all(negate(rune(407676)),{type='PRIMARY_TALENT_TREE',tree=1}))),
  cooldowns={block('sholy-upkeep','sod.paladin.holy-upkeep','sholy-')},
  rotation={
   block('sholy-boundaries','era.paladin.boundaries','sholy-'),
   {id='sholy-friend',type='branch',conditions=all({type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'})),onFalse={},onTrue={
    block('sholy-cleanse','era.paladin.cleanse','sholy-'),
    spell('sholy-shock',20473,any(all({type='MOVING'},hurt(0.9)),hurt(0.3))),
    spell('sholy-divine-light',458856,all(hurt(0.6),mana('GREATERTHANOREQUALS',0.5))),
    spell('sholy-holy-light',635,hurt(0.6)),
    spell('sholy-flash',19750,hurt(0.9)),
    {id='sholy-friend-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   block('sholy-hostile','sod.paladin.holy-hostile','sholy-'),
  },
 },
}))
