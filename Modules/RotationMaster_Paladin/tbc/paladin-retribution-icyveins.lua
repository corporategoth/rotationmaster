-- Retribution, Icy Veins: Judgement of the Crusader once per target, Righteousness (or
-- Command with a slow two-hander, Blood or Martyr once known), Crusader Strike, Hammer of
-- Wrath and Judgement on cooldown, Consecration on two or more enemies with mana to
-- spare, Exorcism on Undead and Demons, offensive Holy Shock for Holy levelers.
-- Same catch-all switch as the Wowhead variant, lower priority.
-- Shared blocks: Defaults/blocks/paladin.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function anySeal()local out={};for i,id in ipairs({21084,20375,31892,348700,31801,348704,21082,20166,20165,20164})do out[i]=own(id)end;return{type='OR',value=out}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.paladin.retribution.icyveins',revision=7,
 blocks={['tbc.paladin.ret-upkeep']=2,['tbc.paladin.melee-opening']=2,['tbc.paladin.boundaries']=2},
 nameKey='Default.TBC.Paladin.Retribution.IcyVeins.Name',descriptionKey='Default.TBC.Paladin.Retribution.IcyVeins.Description',
 applicability={families={'tbc'},actionContext='player',class='PALADIN'},
 tags={'leveling','endgame','retribution','melee','single-target','aoe','icy-veins'},
 sources={{url='https://www.icy-veins.com/tbc-classic/retribution-paladin-leveling-guide',title='Icy Veins: Retribution Paladin leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/paladin-leveling-guide',title='Icy Veins: Paladin leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/retribution-paladin-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Retribution Paladin rotation',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/holy-paladin-leveling-guide',title='Icy Veins: Holy Paladin leveling',reviewedAt='2026-10-23',revision='2026-01-12',notes='Offensive Holy Shock only.'}},
 body={priority=1,disabled=true,
  cooldowns={{id='ret-icy-upkeep',type='block',block='tbc.paladin.ret-upkeep',prefix='ret-icy-'}},
  rotation={
   {id='ret-icy-opening',type='block',block='tbc.paladin.melee-opening',prefix='ret-icy-'},
   {id='ret-icy-opener',type='branch',conditions=all(negate({type='DEBUFF',unit='target',spell=21183,anyrank=true}),negate({type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=10})),onFalse={},onTrue={
    {id='ret-icy-opener-judgement',type='spell',action=20271,ranked=false,conditions=own(21082)},
    {id='ret-icy-opener-crusader',type='spell',action=21082,ranked=false,conditions=negate(own(21082))},
   }},
   {id='ret-icy-seal',type='branch',conditions=anySeal(),onTrue={},onFalse={
    {id='ret-icy-seal-blood',type='spell',action=31892,ranked=false,conditions={}},
    {id='ret-icy-seal-martyr',type='spell',action=348700,ranked=false,conditions={}},
    {id='ret-icy-seal-command',type='spell',action=20375,ranked=false,conditions={type='SWING_TIME',offhand=false,operator='GREATERTHANOREQUALS',value=3.5}},
    {id='ret-icy-seal-righteousness',type='spell',action=21084,ranked=false,conditions={}},
   }},
   {id='ret-icy-crusader-strike',type='spell',action=35395,ranked=false,conditions={}},
   {id='ret-icy-hammer',type='spell',action=24275,ranked=false,conditions={}},
   {id='ret-icy-judgement',type='spell',action=20271,ranked=false,conditions={}},
   {id='ret-icy-consecration',type='spell',action=26573,ranked=false,conditions=all({type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=2},mana('GREATERTHANOREQUALS',0.5))},
   {id='ret-icy-exorcism',type='spell',action=879,ranked=false,conditions={type='OR',value={{type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='DEMON'}}}},
   {id='ret-icy-holy-shock',type='spell',action=20473,ranked=false,conditions=mana('GREATERTHANOREQUALS',0.5)},
  },
 },
}))
