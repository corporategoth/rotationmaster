-- Classic Era Protection after Wowhead's tanking guide (Askalon) with Icy Veins: Righteous Fury
-- selects it at any level and in any tree. Seal of Righteousness (Wisdom when mana runs low),
-- Holy Shield up, Consecration and Holy Wrath on packs, Judgement of the Crusader then Judgement
-- on a single target, Exorcism on Undead and Demons. Taunting and Blessing of Kings spam stay yours.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local undead=any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='DEMON'})
local function noSeal()local out={};for i,id in ipairs({20154,21084,20375,21082,20166,20165,20164})do out[i]=own(id)end;return negate({type='OR',value=out})end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.paladin.protection',revision=1,
 blocks={['era.paladin.tank-upkeep']=1,['era.paladin.melee-opening']=1,['era.paladin.boundaries']=1},
 nameKey='Default.Era.Paladin.Protection.Name',descriptionKey='Default.Era.Paladin.Protection.Description',
 applicability={families={'era'},actionContext='player',class='PALADIN',minLevel=1,maxLevel=60},
 tags={'leveling','endgame','protection','tank','single-target','aoe','wowhead','icy-veins'},
 sources={{url='https://www.wowhead.com/classic/guide/lights-bulwark-protection-paladin-tanking',title='Wowhead: Protection Paladin tanking guide (Askalon)',reviewedAt='2026-10-23',revision='2024-11-21'},
  {url='https://www.icy-veins.com/wow-classic/protection-paladin-tank-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Protection Paladin rotation',reviewedAt='2026-10-23',revision='2024-11-18'},
  {url='https://www.icy-veins.com/wow-classic/protection-paladin-leveling-talent-build-from-1-to-60',title='Icy Veins: Protection Paladin leveling 1-60',reviewedAt='2026-10-23',revision='2026-07-18'}},
 body={priority=20,switch=any(own(25780),{type='PRIMARY_TALENT_TREE',tree=2}),
  cooldowns={block('prot-upkeep','era.paladin.tank-upkeep','prot-')},
  rotation={
   block('prot-opening','era.paladin.melee-opening','prot-'),
   {id='prot-seal',type='branch',conditions=noSeal(),onFalse={},onTrue={
    spell('prot-seal-wisdom',20166,mana('LESSTHAN',0.4)),
    spell('prot-seal-righteousness',20154),
   }},
   {id='prot-pull',type='branch',conditions=negate({type='COMBAT',unit='player'}),onFalse={},onTrue={
    spell('prot-pull-holy-shield',20925,negate(own(20925))),
    spell('prot-pull-judgement',20271),
    {id='prot-pull-stop',type='none',conditions={}},
   }},
   spell('prot-holy-shield',20925,negate(own(20925))),
   {id='prot-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},onTrue={
    spell('prot-aoe-consecration',26573,mana('GREATERTHANOREQUALS',0.2)),
    spell('prot-aoe-holy-wrath',2812,undead),
   },onFalse={
    spell('prot-crusader-judgement',20271,own(21082)),
    spell('prot-crusader-seal',21082,all(negate({type='DEBUFF',unit='target',spell=21183,anyrank=true}),{type='SPELL_AVAIL',spell=20271})),
    spell('prot-judgement',20271),
    spell('prot-consecration',26573,mana('GREATERTHANOREQUALS',0.5)),
   }},
   spell('prot-exorcism',879,undead),
  },
 },
}))
