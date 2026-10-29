-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Druid Feral after Warcraft Tavern's non-powershifting list: no shifting; Shred or Claw
-- to five combo points, then Rip on a target that lives, Tiger's Fury, Ferocious Bite. Bear as
-- recommended. Same switch as rm.era.druid.feral at a lower priority.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function form(id)return{type='FORM',form=id}end
local function ref(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local noFF=all(negate({type='DEBUFF',unit='target',spell=770,anyrank=true}),negate({type='DEBUFF',unit='target',spell=16857,anyrank=true}))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.druid.feral.warcrafttavern.casual',revision=6,
 blocks={['era.druid.boundaries']=4,['era.druid.upkeep']=1,['era.druid.feral-cooldowns']=2,['era.druid.stealth-opener']=2,
  ['era.druid.cat-builders']=1,['era.druid.bear']=2,['era.druid.bear-pull']=3,['era.druid.feral-humanoid']=2},
 nameKey="Feral (Warcraft Tavern, no powershifting)",descriptionKey="Warcraft Tavern's list without powershifting, an alternative to the recommended Feral premade, off by default: enable it and disable that one, or raise its priority. Build to five combo points with Shred (Claw from the front), then Rip on a target that will live, Tiger's Fury, Ferocious Bite; otherwise wait for energy. Bear and reminders as the recommended premade.",
 applicability={families={'era'},actionContext='player',class='DRUID'},
 tags={'leveling','endgame','feral','melee','tank','single-target','warcraft-tavern'},
 sources={
  {url='https://www.warcrafttavern.com/wow-classic/guides/pve-feral-druid-dps-rotations-cooldowns/',title='Warcraft Tavern: Classic Feral DPS rotations',reviewedAt='2026-10-23'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/pve-feral-druid-tank-rotations-cooldowns/',title='Warcraft Tavern: Classic Feral tank',reviewedAt='2026-10-23'},
 },
 body={priority=28,disabled=true,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=2}}},
  cooldowns={ref('era-feral-wtc-upkeep','era.druid.upkeep','era-feral-wtc-'),ref('era-feral-wtc-cooldowns','era.druid.feral-cooldowns','era-feral-wtc-')},
  rotation={
   ref('era-feral-wtc-boundaries','era.druid.boundaries','era-feral-wtc-'),
   {id='era-feral-wtc-cat',type='branch',conditions=form(768),onFalse={},onTrue={
    ref('era-feral-wtc-opening','era.druid.stealth-opener','era-feral-wtc-open-'),
    spell('era-feral-wtc-faerie-fire',16857,noFF),
    {id='era-feral-wtc-finisher',type='branch',conditions={type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=5},onFalse={},onTrue={
     spell('era-feral-wtc-finisher-rip',1079,all(negate({type='DEBUFF',unit='target',spell=1079,anyrank=true,owndebuff=true}),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=12})),
     spell('era-feral-wtc-finisher-tigers-fury',5217,negate({type='BUFF',unit='player',spell=5217,anyrank=true})),
     spell('era-feral-wtc-finisher-bite',22568)}},
    ref('era-feral-wtc-builders','era.druid.cat-builders','era-feral-wtc-build-'),
    {id='era-feral-wtc-wait',type='stop',conditions={}}}},
   {id='era-feral-wtc-bear',type='branch',conditions=any(form(5487),form(9634)),onFalse={},onTrue={ref('era-feral-wtc-bear-section','era.druid.bear','era-feral-wtc-bear-')}},
   ref('era-feral-wtc-humanoid','era.druid.feral-humanoid','era-feral-wtc-'),
  },
 },
}))
