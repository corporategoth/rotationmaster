-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Holy after Wowhead's Phase 4 healing guide: Holy Light is the main heal (Divine
-- Light when mana allows) for moderate and heavy damage, then Cleanse, Holy Shock for light damage or
-- while moving, Flash of Light for light damage. Same switch as the recommended SoD Holy premade,
-- lower priority, shipped disabled.
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
 format='RotationMaster',schemaVersion=1,id='rm.sod.paladin.holy.wowhead',revision=7,
 blocks={['sod.paladin.holy-upkeep']=2,['era.paladin.boundaries']=2,['era.paladin.cleanse']=1,['sod.paladin.holy-hostile']=3},
 nameKey='Default.SoD.Paladin.Holy.Wowhead.Name',descriptionKey='Default.SoD.Paladin.Holy.Wowhead.Description',
 applicability={families={'era'},actionContext='player',class='PALADIN',rulesets={'season:2'}},
 tags={'endgame','holy','healer','dungeon','raid','season-of-discovery','wowhead'},
 sources={{url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/paladin/healer-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Paladin healer rotation (Phase 4)',reviewedAt='2026-10-23',revision='2024-07-12'}},
 body={priority=109,disabled=true,switch=all({type='GROUP'},any(rune(407613),rune(458856),rune(412019),all(negate(rune(407676)),{type='PRIMARY_TALENT_TREE',tree=1}))),
  cooldowns={block('sholywh-upkeep','sod.paladin.holy-upkeep','sholywh-')},
  rotation={
   block('sholywh-boundaries','era.paladin.boundaries','sholywh-'),
   {id='sholywh-friend',type='branch',conditions=all({type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'})),onFalse={},onTrue={
    spell('sholywh-divine-light',458856,all(hurt(0.75),mana('GREATERTHANOREQUALS',0.5))),
    spell('sholywh-holy-light',635,hurt(0.75)),
    block('sholywh-cleanse','era.paladin.cleanse','sholywh-'),
    spell('sholywh-shock',20473,any(all({type='MOVING'},hurt(0.95)),hurt(0.9))),
    spell('sholywh-flash',19750,hurt(0.95)),
    {id='sholywh-friend-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   block('sholywh-hostile','sod.paladin.holy-hostile','sholywh-'),
  },
 },
}))
