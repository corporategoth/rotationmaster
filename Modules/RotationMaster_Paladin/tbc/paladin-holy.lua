-- Holy, Icy Veins and Wowhead blended by damage taken (the research recommendation):
-- emergencies and cleansing first, Holy Shock while moving, Holy Light for heavy damage,
-- rank-5 Holy Light to keep Light's Grace up, Flash of Light for everything else.
-- Heals act on your friendly target (or none). Selected for the Holy tree in a group;
-- a soloing Holy paladin melees with a Retribution premade.
-- Shared blocks: Defaults/blocks/paladin.lua. Original priority data, no guide prose.
local _,addon=...
local function negate(c)return{type='NOT',value=c}end
local function hurt(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.paladin.holy',revision=2,
 blocks={['tbc.paladin.holy-upkeep']=2,['tbc.paladin.boundaries']=1,['tbc.paladin.holy-hostile']=1,['tbc.paladin.holy-emergency']=1},
 nameKey='Default.TBC.Paladin.Holy.Name',descriptionKey='Default.TBC.Paladin.Holy.Description',
 applicability={families={'tbc'},actionContext='player',class='PALADIN',minLevel=10,maxLevel=70},
 tags={'leveling','endgame','holy','healer','dungeon','icy-veins','wowhead'},
 sources={{url='https://www.icy-veins.com/tbc-classic/holy-paladin-healer-pve-rotation-cooldowns-abilities',title='Icy Veins: Holy Paladin rotation',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.wowhead.com/tbc/guide/classes/paladin/holy/healer-rotation-cooldowns-abilities-pve',title='Wowhead: Holy Paladin healing',reviewedAt='2026-10-23',revision='2026-02-10'}},
 body={priority=10,switch={type='AND',value={{type='GROUP'},{type='PRIMARY_TALENT_TREE',tree=1}}},
  cooldowns={{id='holy-upkeep',type='block',block='tbc.paladin.holy-upkeep',prefix='holy-'}},
  rotation={
   {id='holy-boundaries',type='block',block='tbc.paladin.boundaries',prefix='holy-'},
   {id='holy-hostile',type='branch',conditions={type='ATTACKABLE',unit='target'},onTrue={
    {id='holy-judge',type='block',block='tbc.paladin.holy-hostile',prefix='holy-'},
   },onFalse={
    {id='holy-emergency',type='block',block='tbc.paladin.holy-emergency',prefix='holy-'},
    {id='holy-light-heavy',type='spell',action=635,ranked=false,conditions=hurt(0.5)},
    {id='holy-light-grace',type='spell',action=1042,ranked=true,conditions={type='AND',value={negate({type='BUFF',unit='player',spell=31834,ownbuff=true}),hurt(0.8)}}},
    {id='holy-flash',type='spell',action=19750,ranked=false,conditions=hurt(0.9)},
    {id='holy-stop',type='none',suppress_attack=true,conditions={}},
   }},
  },
 },
}))
