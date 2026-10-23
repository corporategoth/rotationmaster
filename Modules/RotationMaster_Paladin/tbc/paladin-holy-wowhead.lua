-- Holy, Wowhead tank-healing: Holy Light on anyone missing a tenth of their health,
-- Flash of Light only for small deficits, Holy Shock while moving, Divine Favor and
-- Divine Illumination on cooldown. Same switch as the blended Holy premade, lower priority.
-- Shared blocks: Defaults/blocks/paladin.lua. Original priority data, no guide prose.
local _,addon=...
local function hurt(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.paladin.holy.wowhead',revision=1,
 blocks={['tbc.paladin.holy-upkeep']=1,['tbc.paladin.boundaries']=1,['tbc.paladin.holy-hostile']=1,['tbc.paladin.holy-emergency']=1},
 nameKey='Default.TBC.Paladin.Holy.Wowhead.Name',descriptionKey='Default.TBC.Paladin.Holy.Wowhead.Description',
 applicability={families={'tbc'},actionContext='player',class='PALADIN',minLevel=10,maxLevel=70},
 tags={'endgame','raid','holy','healer','tank-healing','wowhead'},
 sources={{url='https://www.wowhead.com/tbc/guide/classes/paladin/holy/healer-rotation-cooldowns-abilities-pve',title='Wowhead: Holy Paladin healing',reviewedAt='2026-10-23',revision='2026-02-10'}},
 body={priority=9,switch={type='AND',value={{type='GROUP'},{type='PRIMARY_TALENT_TREE',tree=1}}},
  cooldowns={{id='holy-wh-upkeep',type='block',block='tbc.paladin.holy-upkeep',prefix='holy-wh-'}},
  rotation={
   {id='holy-wh-boundaries',type='block',block='tbc.paladin.boundaries',prefix='holy-wh-'},
   {id='holy-wh-hostile',type='branch',conditions={type='ATTACKABLE',unit='target'},onTrue={
    {id='holy-wh-judge',type='block',block='tbc.paladin.holy-hostile',prefix='holy-wh-'},
   },onFalse={
    {id='holy-wh-emergency',type='block',block='tbc.paladin.holy-emergency',prefix='holy-wh-'},
    {id='holy-wh-light',type='spell',action=635,ranked=false,conditions=hurt(0.9)},
    {id='holy-wh-flash',type='spell',action=19750,ranked=false,conditions=hurt(0.97)},
    {id='holy-wh-stop',type='none',suppress_attack=true,conditions={}},
   }},
  },
 },
}))
