-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Druid Feral after Warcraft Tavern's powershifting guide: Rip first at five combo points
-- whenever it is missing (raids too), then Ferocious Bite from four combo points under 63 energy,
-- Shred, powershift. Bear as recommended. Same switch as rm.era.druid.feral at a lower priority.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function cp(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local noFF=BuiltinConditions.all(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=770,anyrank=true}),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=16857,anyrank=true}))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.druid.feral.warcrafttavern',revision=6,
 blocks={['era.druid.boundaries']=4,['era.druid.upkeep']=1,['era.druid.feral-cooldowns']=2,['era.druid.stealth-opener']=2,
  ['era.druid.cat-builders']=1,['era.druid.powershift']=2,['era.druid.bear']=2,['era.druid.bear-pull']=3,['era.druid.feral-humanoid']=2},
 applicability={families={'era'},actionContext='player',class='DRUID'},
 tags={'endgame','raid','feral','melee','tank','single-target','warcraft-tavern'},
 sources={
  {url='https://www.warcrafttavern.com/wow-classic/guides/feral-druid-dps-powershifting-rotation/',title='Warcraft Tavern: Feral Druid powershifting',reviewedAt='2026-10-23'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/pve-feral-druid-tank-rotations-cooldowns/',title='Warcraft Tavern: Classic Feral tank',reviewedAt='2026-10-23'},
 },
 body={priority=29,disabled=true,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=2}}},
  cooldowns={BuiltinConditions.block('era-feral-wt-upkeep','era.druid.upkeep','era-feral-wt-'),BuiltinConditions.block('era-feral-wt-cooldowns','era.druid.feral-cooldowns','era-feral-wt-')},
  rotation={
   BuiltinConditions.block('era-feral-wt-boundaries','era.druid.boundaries','era-feral-wt-'),
   {id='era-feral-wt-cat',type='branch',conditions=BuiltinConditions.form(768),onFalse={},onTrue={
    BuiltinConditions.block('era-feral-wt-opening','era.druid.stealth-opener','era-feral-wt-open-'),
    BuiltinConditions.spell('era-feral-wt-faerie-fire',16857,noFF),
    BuiltinConditions.spell('era-feral-wt-clearcasting-shred',5221,BuiltinConditions.all(BuiltinConditions.ownBuff(16870),BuiltinConditions.negate({type='ISSAME',unit='targettarget',otherunit='player'}))),
    BuiltinConditions.spell('era-feral-wt-rip',1079,BuiltinConditions.all(cp('GREATERTHANOREQUALS',5),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=1079,anyrank=true,owndebuff=true}))),
    BuiltinConditions.spell('era-feral-wt-bite',22568,BuiltinConditions.all(cp('GREATERTHANOREQUALS',4),{type='POWER',unit='player',operator='LESSTHAN',value=63})),
    BuiltinConditions.block('era-feral-wt-builders','era.druid.cat-builders','era-feral-wt-build-'),
    BuiltinConditions.block('era-feral-wt-powershift','era.druid.powershift','era-feral-wt-shift-')}},
   {id='era-feral-wt-bear',type='branch',conditions=BuiltinConditions.any(BuiltinConditions.form(5487),BuiltinConditions.form(9634)),onFalse={},onTrue={BuiltinConditions.block('era-feral-wt-bear-section','era.druid.bear','era-feral-wt-bear-')}},
   BuiltinConditions.block('era-feral-wt-humanoid','era.druid.feral-humanoid','era-feral-wt-'),
  },
 },
}))
