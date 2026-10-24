-- Season of Discovery Retribution after Icy Veins' Phase 4 list (Warcraft Tavern agrees): Judgement
-- of the Crusader once on targets that live 20 s, Seal of Martyrdom, Exorcism, Crusader Strike,
-- Divine Storm and Judgement on cooldown, Consecration with mana or three enemies, Hammer of Wrath.
-- Same switch as the recommended SoD Retribution premade, lower priority, shipped disabled.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.paladin.retribution.icyveins',revision=5,
 blocks={['sod.paladin.ret-upkeep']=2,['era.paladin.safety']=1,['era.paladin.melee-opening']=3,['sod.paladin.seal']=2},
 nameKey='Default.SoD.Paladin.Retribution.IcyVeins.Name',descriptionKey='Default.SoD.Paladin.Retribution.IcyVeins.Description',
 applicability={families={'era'},actionContext='player',class='PALADIN',rulesets={'season:2'}},
 tags={'leveling','retribution','melee','single-target','season-of-discovery','icy-veins','warcraft-tavern'},
 sources={{url='https://www.icy-veins.com/wow-classic/retribution-paladin-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Retribution Paladin rotation (Phase 4)',reviewedAt='2026-10-23',revision='2024-07-07'},
  {url='https://www.icy-veins.com/wow-classic/retribution-paladin-dps-season-of-discovery-leveling',title='Icy Veins: SoD Retribution Paladin leveling (Phase 4)',reviewedAt='2026-10-23',revision='2024-07-02'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/season-of-discovery-sod-paladin-dps-build-guide/',title='Warcraft Tavern: SoD Paladin DPS guide (Phase 4)',reviewedAt='2026-10-23'}},
 body={priority=101,disabled=true,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={block('sretiv-upkeep','sod.paladin.ret-upkeep','sretiv-'),block('sretiv-safety','era.paladin.safety','sretiv-')},
  rotation={
   block('sretiv-opening','era.paladin.melee-opening','sretiv-'),
   spell('sretiv-crusader-judgement',20271,own(21082)),
   spell('sretiv-crusader-seal',21082,all(negate({type='DEBUFF',unit='target',spell=21183,anyrank=true}),negate({type='GROUP',raid=true}),{type='SPELL_AVAIL',spell=20271},
    any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='worldboss'},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=20}))),
   block('sretiv-seal','sod.paladin.seal','sretiv-'),
   {id='sretiv-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell('sretiv-pull-exorcism',415068),
    spell('sretiv-pull-judgement',20271),
    {id='sretiv-pull-stop',type='stop',conditions={}},
   }},
   spell('sretiv-exorcism',415068),
   spell('sretiv-crusader-strike',407676),
   spell('sretiv-divine-storm',407778),
   spell('sretiv-judgement',20271,mana('GREATERTHANOREQUALS',0.15)),
   spell('sretiv-consecration',26573,any(mana('GREATERTHANOREQUALS',0.5),{type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=3})),
   spell('sretiv-hammer-of-wrath',24275),
  },
 },
}))
