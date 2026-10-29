-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Protection after Wowhead's Phase 8 tank guide: chosen by Righteous Fury, an
-- engraved Hammer of the Righteous or Shield of Righteousness, or the Protection tree. Seal of
-- Martyrdom, Holy Shield first; one target: Hammer of the Righteous, Shield of Righteousness,
-- Exorcism, Avenger's Shield, Judgement, Divine Storm, Consecration; three or more engaged enemies:
-- Hammer of the Righteous, Avenger's Shield, Consecration, Shield of Righteousness, Exorcism.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.paladin.protection',revision=6,
 blocks={['sod.paladin.tank-upkeep']=2,['era.paladin.melee-opening']=3,['sod.paladin.seal']=2},
 applicability={families={'era'},actionContext='player',class='PALADIN',rulesets={'season:2'}},
 tags={'leveling','endgame','protection','tank','single-target','aoe','season-of-discovery','wowhead'},
 sources={{url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/paladin/tank-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Paladin tank rotation (Phase 8)',reviewedAt='2026-10-23',revision='2025-04-18'},
  {url='https://www.icy-veins.com/wow-classic/protection-paladin-tank-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Protection Paladin rotation (Phase 4)',reviewedAt='2026-10-23',revision='2024-07-05',notes='Hand of Reckoning on lost threat; Divine Storm if engraved.'}},
 body={priority=120,switch=BuiltinConditions.any(own(407627),own(25780),rune(407632),rune(440658),{type='PRIMARY_TALENT_TREE',tree=2}),
  cooldowns={BuiltinConditions.block('sprot-upkeep','sod.paladin.tank-upkeep','sprot-upkeep-')},
  rotation={
   BuiltinConditions.block('sprot-opening','era.paladin.melee-opening','sprot-'),
   BuiltinConditions.block('sprot-seal','sod.paladin.seal','sprot-'),
   {id='sprot-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell('sprot-pull-holy-shield',20925,BuiltinConditions.negate(own(20925))),
    BuiltinConditions.spell('sprot-pull-avengers-shield',407669),
    BuiltinConditions.spell('sprot-pull-exorcism',415068),
    {id='sprot-pull-stop',type='stop',conditions={}},
   }},
   BuiltinConditions.spell('sprot-holy-shield',20925,BuiltinConditions.negate(own(20925))),
   {id='sprot-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onTrue={
    BuiltinConditions.spell('sprot-aoe-hammer',407632),
    BuiltinConditions.spell('sprot-aoe-avengers-shield',407669),
    BuiltinConditions.spell('sprot-aoe-consecration',26573),
    BuiltinConditions.spell('sprot-aoe-shield',440658),
    BuiltinConditions.spell('sprot-aoe-exorcism',415068),
   },onFalse={
    BuiltinConditions.spell('sprot-hammer',407632),
    BuiltinConditions.spell('sprot-shield',440658),
    BuiltinConditions.spell('sprot-exorcism',415068),
    BuiltinConditions.spell('sprot-avengers-shield',407669),
    BuiltinConditions.spell('sprot-judgement',20271),
    BuiltinConditions.spell('sprot-divine-storm',407778),
    BuiltinConditions.spell('sprot-consecration',26573),
   }},
  },
 },
}))
