-- Classic Era Retribution, levels 1-60, and the default for any Paladin no other premade fits
-- (lowest priority). Icy Veins and Wowhead with Warcraft Tavern: Judgement of the Crusader once on
-- long fights, Seal of Command with a slow weapon else Righteousness, Exorcism and Holy Wrath on
-- Undead and Demons, Hammer of Wrath, Judgement on cooldown, Consecration with Vengeance or packs.
-- Adapts by learned spell (Exorcism 20, Consecration 20, Hammer of Wrath 44, Holy Wrath 50).
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
 format='RotationMaster',schemaVersion=1,id='rm.era.paladin.retribution',revision=4,
 blocks={['era.paladin.ret-upkeep']=2,['era.paladin.safety']=1,['era.paladin.melee-opening']=3,
  ['era.paladin.crusader-opener']=1,['era.paladin.seal']=2,['era.paladin.undead']=1},
 nameKey='Default.Era.Paladin.Retribution.Name',descriptionKey='Default.Era.Paladin.Retribution.Description',
 applicability={families={'era'},actionContext='player',class='PALADIN'},
 tags={'leveling','endgame','retribution','melee','single-target','icy-veins','wowhead','warcraft-tavern'},
 sources={{url='https://www.icy-veins.com/wow-classic/retribution-paladin-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Retribution Paladin rotation',reviewedAt='2026-10-23',revision='2024-11-18'},
  {url='https://www.icy-veins.com/wow-classic/retribution-paladin-leveling-talent-build-from-1-to-60',title='Icy Veins: Retribution Paladin leveling 1-60',reviewedAt='2026-10-23',revision='2026-07-18'},
  {url='https://www.icy-veins.com/wow-classic/classic-paladin-leveling-guide',title='Icy Veins: Classic Paladin leveling guide',reviewedAt='2026-10-23',revision='2024-11-18'},
  {url='https://www.icy-veins.com/wow-classic/hardcore-paladin-class-overview',title='Icy Veins: Hardcore Paladin overview',reviewedAt='2026-10-23',revision='2023-05-21',notes='Divine Shield and Forbearance safety reminders.'},
  {url='https://www.wowhead.com/classic/guide/classes/paladin/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Retribution Paladin rotation',reviewedAt='2026-10-23',revision='2025-03-20'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/pve-retribution-paladin-rotations-cooldowns/',title='Warcraft Tavern: Classic Retribution Paladin rotations',reviewedAt='2026-10-23'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/paladin-leveling-guide/',title='Warcraft Tavern: Classic Paladin leveling guide',reviewedAt='2026-10-23'}},
 body={priority=2,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={block('ret-upkeep','era.paladin.ret-upkeep','ret-'),block('ret-safety','era.paladin.safety','ret-')},
  rotation={
   block('ret-opening','era.paladin.melee-opening','ret-'),
   block('ret-crusader','era.paladin.crusader-opener','ret-'),
   block('ret-seal','era.paladin.seal','ret-'),
   {id='ret-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell('ret-pull-judgement',20271),
    {id='ret-pull-stop',type='stop',conditions={}},
   }},
   block('ret-undead','era.paladin.undead','ret-'),
   spell('ret-hammer-of-wrath',24275,mana('GREATERTHANOREQUALS',0.2)),
   spell('ret-judgement',20271,mana('GREATERTHANOREQUALS',0.15)),
   spell('ret-consecration',26573,all(mana('GREATERTHANOREQUALS',0.3),any(own(20050),{type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=2}))),
  },
 },
}))
