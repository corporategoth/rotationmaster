-- Season of Discovery Protection after Wowhead's Phase 8 tank guide: chosen by Righteous Fury, an
-- engraved Hammer of the Righteous or Shield of Righteousness, or the Protection tree. Seal of
-- Martyrdom, Holy Shield first; one target: Hammer of the Righteous, Shield of Righteousness,
-- Exorcism, Avenger's Shield, Judgement, Divine Storm, Consecration; three or more engaged enemies:
-- Hammer of the Righteous, Avenger's Shield, Consecration, Shield of Righteousness, Exorcism.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.paladin.protection',revision=4,
 blocks={['sod.paladin.tank-upkeep']=2,['era.paladin.melee-opening']=2,['sod.paladin.seal']=2},
 nameKey='Default.SoD.Paladin.Protection.Name',descriptionKey='Default.SoD.Paladin.Protection.Description',
 applicability={families={'era'},actionContext='player',class='PALADIN',rulesets={'season:2'}},
 tags={'leveling','endgame','protection','tank','single-target','aoe','season-of-discovery','wowhead'},
 sources={{url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/paladin/tank-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Paladin tank rotation (Phase 8)',reviewedAt='2026-10-23',revision='2025-04-18'},
  {url='https://www.icy-veins.com/wow-classic/protection-paladin-tank-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Protection Paladin rotation (Phase 4)',reviewedAt='2026-10-23',revision='2024-07-05',notes='Hand of Reckoning on lost threat; Divine Storm if engraved.'}},
 body={priority=120,switch=any(own(407627),own(25780),rune(407632),rune(440658),{type='PRIMARY_TALENT_TREE',tree=2}),
  cooldowns={block('sprot-upkeep','sod.paladin.tank-upkeep','sprot-upkeep-')},
  rotation={
   block('sprot-opening','era.paladin.melee-opening','sprot-'),
   block('sprot-seal','sod.paladin.seal','sprot-'),
   {id='sprot-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell('sprot-pull-holy-shield',20925,negate(own(20925))),
    spell('sprot-pull-avengers-shield',407669),
    spell('sprot-pull-exorcism',415068),
    {id='sprot-pull-stop',type='none',conditions={}},
   }},
   spell('sprot-holy-shield',20925,negate(own(20925))),
   {id='sprot-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onTrue={
    spell('sprot-aoe-hammer',407632),
    spell('sprot-aoe-avengers-shield',407669),
    spell('sprot-aoe-consecration',26573),
    spell('sprot-aoe-shield',440658),
    spell('sprot-aoe-exorcism',415068),
   },onFalse={
    spell('sprot-hammer',407632),
    spell('sprot-shield',440658),
    spell('sprot-exorcism',415068),
    spell('sprot-avengers-shield',407669),
    spell('sprot-judgement',20271),
    spell('sprot-divine-storm',407778),
    spell('sprot-consecration',26573),
   }},
  },
 },
}))
