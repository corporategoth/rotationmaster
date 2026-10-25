-- Classic Era Druid Feral with Wowhead's geared raid bear: the recommended cat, but the bear Mauls
-- every swing and tab-Mauls packs, Swipes only with 60 rage to spare, uses no Demoralizing Roar and
-- no Enrage in combat. Same switch as rm.era.druid.feral at a lower priority.
local _,addon=...
local function any(...)return{type='OR',value={...}}end
local function form(id)return{type='FORM',form=id}end
local function ref(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.druid.feral.wowhead',revision=6,
 blocks={['era.druid.boundaries']=4,['era.druid.upkeep']=1,['era.druid.feral-cooldowns']=2,['era.druid.cat']=1,['era.druid.stealth-opener']=2,
  ['era.druid.cat-builders']=1,['era.druid.powershift']=2,['era.druid.bear-pull']=3,['era.druid.feral-humanoid']=2},
 nameKey='Default.Era.Druid.Feral.Wowhead.Name',descriptionKey='Default.Era.Druid.Feral.Wowhead.Description',
 applicability={families={'era'},actionContext='player',class='DRUID'},
 tags={'endgame','raid','feral','melee','tank','single-target','wowhead'},
 sources={
  {url='https://www.wowhead.com/classic/guide/classes/druid/feral/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Feral DPS rotation',reviewedAt='2026-10-23',revision='2023-11-21'},
  {url='https://www.wowhead.com/classic/guide/classes/druid/feral/tank-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Feral tank rotation',reviewedAt='2026-10-23',revision='2023-12-02'},
 },
 body={priority=27,disabled=true,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=2}}},
  cooldowns={ref('era-feral-wh-upkeep','era.druid.upkeep','era-feral-wh-'),ref('era-feral-wh-cooldowns','era.druid.feral-cooldowns','era-feral-wh-')},
  rotation={
   ref('era-feral-wh-boundaries','era.druid.boundaries','era-feral-wh-'),
   {id='era-feral-wh-cat',type='branch',conditions=form(768),onFalse={},onTrue={ref('era-feral-wh-cat-section','era.druid.cat','era-feral-wh-cat-')}},
   {id='era-feral-wh-bear',type='branch',conditions=any(form(5487),form(9634)),onFalse={},onTrue={
    ref('era-feral-wh-bear-pull','era.druid.bear-pull','era-feral-wh-bear-pull-'),
    {id='era-feral-wh-swipe',type='spell',action=779,ranked=false,conditions={type='POWER',unit='player',operator='GREATERTHANOREQUALS',value=60}},
    {id='era-feral-wh-faerie-fire',type='spell',action=16857,ranked=false,conditions={}},
    {id='era-feral-wh-bear-wait',type='stop',conditions={}}}},
   ref('era-feral-wh-humanoid','era.druid.feral-humanoid','era-feral-wh-'),
  },
 },
}))
