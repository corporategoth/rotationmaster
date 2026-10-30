-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Protection after Wowhead's tanking guide (Askalon) with Icy Veins: Righteous Fury
-- selects it at any level and in any tree. Seal of Righteousness (Wisdom when mana runs low),
-- Holy Shield up, Consecration and Holy Wrath on packs, Judgement of the Crusader then Judgement
-- on a single target, Exorcism on Undead and Demons. Taunting and Blessing of Kings spam stay yours.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local undead=BuiltinConditions.any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='DEMON'})
local function sealed()local out={};for i,id in ipairs({20154,21084,20375,21082,20166,20165,20164})do out[i]=own(id)end;return{type='OR',value=out}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.paladin.protection',revision=5,
 blocks={['era.paladin.tank-upkeep']=2,['era.paladin.melee-opening']=3},
 applicability={families={'era'},actionContext='player',class='PALADIN'},
 tags={'leveling','endgame','protection','tank','single-target','aoe','wowhead','icy-veins'},
 sources={{url='https://www.wowhead.com/classic/guide/lights-bulwark-protection-paladin-tanking',title='Wowhead: Protection Paladin tanking guide (Askalon)',reviewedAt='2026-10-23',revision='2024-11-21'},
  {url='https://www.icy-veins.com/wow-classic/protection-paladin-tank-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Protection Paladin rotation',reviewedAt='2026-10-23',revision='2024-11-18'},
  {url='https://www.icy-veins.com/wow-classic/protection-paladin-leveling-talent-build-from-1-to-60',title='Icy Veins: Protection Paladin leveling 1-60',reviewedAt='2026-10-23',revision='2026-07-18'}},
 body={priority=20,switch=BuiltinConditions.any(own(25780),{type='PRIMARY_TALENT_TREE',tree=2}),
  cooldowns={BuiltinConditions.block('prot-upkeep','era.paladin.tank-upkeep','prot-')},
  rotation={
   BuiltinConditions.block('prot-opening','era.paladin.melee-opening','prot-'),
   {id='prot-seal',type='branch',conditions=sealed(),onTrue={},onFalse={
    BuiltinConditions.spell('prot-seal-wisdom',20166,mana('LESSTHAN',0.4)),
    BuiltinConditions.spell('prot-seal-righteousness',20154),
   }},
   {id='prot-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell('prot-pull-holy-shield',20925,BuiltinConditions.negate(own(20925))),
    BuiltinConditions.spell('prot-pull-judgement',20271),
    {id='prot-pull-stop',type='stop',conditions={}},
   }},
   BuiltinConditions.spell('prot-holy-shield',20925,BuiltinConditions.negate(own(20925))),
   {id='prot-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},onTrue={
    BuiltinConditions.spell('prot-aoe-consecration',26573,mana('GREATERTHANOREQUALS',0.2)),
    BuiltinConditions.spell('prot-aoe-holy-wrath',2812,undead),
   },onFalse={
    BuiltinConditions.spell('prot-crusader-judgement',20271,own(21082)),
    BuiltinConditions.spell('prot-crusader-seal',21082,BuiltinConditions.all(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=21183,anyrank=true}),{type='SPELL_AVAIL',spell=20271})),
    BuiltinConditions.spell('prot-judgement',20271),
    BuiltinConditions.spell('prot-consecration',26573,mana('GREATERTHANOREQUALS',0.5)),
   }},
   BuiltinConditions.spell('prot-exorcism',879,undead),
  },
 },
}))
