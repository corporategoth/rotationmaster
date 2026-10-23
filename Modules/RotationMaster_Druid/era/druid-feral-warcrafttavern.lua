-- Classic Era Druid Feral after Warcraft Tavern's powershifting guide: Rip first at five combo points
-- whenever it is missing (raids too), then Ferocious Bite from four combo points under 63 energy,
-- Shred, powershift. Bear as recommended. Same switch as rm.era.druid.feral at a lower priority.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function cp(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function ref(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local noFF=all(negate({type='DEBUFF',unit='target',spell=770,anyrank=true}),negate({type='DEBUFF',unit='target',spell=16857,anyrank=true}))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.druid.feral.warcrafttavern',revision=1,
 blocks={['era.druid.boundaries']=1,['era.druid.upkeep']=1,['era.druid.feral-cooldowns']=1,['era.druid.stealth-opener']=1,
  ['era.druid.cat-builders']=1,['era.druid.powershift']=1,['era.druid.bear']=1,['era.druid.bear-pull']=1,['era.druid.feral-humanoid']=1},
 nameKey='Default.Era.Druid.Feral.WarcraftTavern.Name',descriptionKey='Default.Era.Druid.Feral.WarcraftTavern.Description',
 applicability={families={'era'},actionContext='player',class='DRUID',minLevel=10,maxLevel=60},
 tags={'endgame','raid','feral','melee','tank','single-target','warcraft-tavern'},
 sources={
  {url='https://www.warcrafttavern.com/wow-classic/guides/feral-druid-dps-powershifting-rotation/',title='Warcraft Tavern: Feral Druid powershifting',reviewedAt='2026-10-23'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/pve-feral-druid-tank-rotations-cooldowns/',title='Warcraft Tavern: Classic Feral tank',reviewedAt='2026-10-23'},
 },
 body={priority=29,switch={type='PRIMARY_TALENT_TREE',tree=2},
  cooldowns={ref('era-feral-wt-upkeep','era.druid.upkeep','era-feral-wt-'),ref('era-feral-wt-cooldowns','era.druid.feral-cooldowns','era-feral-wt-')},
  rotation={
   ref('era-feral-wt-boundaries','era.druid.boundaries','era-feral-wt-'),
   {id='era-feral-wt-cat',type='branch',conditions=own(768),onFalse={},onTrue={
    ref('era-feral-wt-opening','era.druid.stealth-opener','era-feral-wt-open-'),
    spell('era-feral-wt-faerie-fire',16857,noFF),
    spell('era-feral-wt-clearcasting-shred',5221,all(own(16870),negate({type='ISSAME',unit='targettarget',otherunit='player'}))),
    spell('era-feral-wt-rip',1079,all(cp('GREATERTHANOREQUALS',5),negate({type='DEBUFF',unit='target',spell=1079,anyrank=true,owndebuff=true}))),
    spell('era-feral-wt-bite',22568,all(cp('GREATERTHANOREQUALS',4),{type='POWER',unit='player',operator='LESSTHAN',value=63})),
    ref('era-feral-wt-builders','era.druid.cat-builders','era-feral-wt-build-'),
    ref('era-feral-wt-powershift','era.druid.powershift','era-feral-wt-shift-')}},
   {id='era-feral-wt-bear',type='branch',conditions=any(own(5487),own(9634)),onFalse={},onTrue={ref('era-feral-wt-bear-section','era.druid.bear','era-feral-wt-bear-')}},
   ref('era-feral-wt-humanoid','era.druid.feral-humanoid','era-feral-wt-'),
  },
 },
}))
