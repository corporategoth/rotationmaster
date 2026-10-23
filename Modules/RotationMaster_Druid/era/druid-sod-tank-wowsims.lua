-- Season of Discovery Druid bear tank, wowsims P7 "cat weave": off by default (expert, needs Savage
-- Roar from gear as well as Lacerate). Leaves Bear for Cat to keep Rake and Savage Roar up, then
-- returns to Dire Bear and plays the tank list. Same switch as rm.sod.druid.tank at a lower priority.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function cp(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function ref(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function spell(id,action,conditions,ranked)return{id=id,type='spell',action=action,ranked=ranked or false,conditions=conditions or {}}end
local rake={type='DEBUFF',unit='target',spell=1822,anyrank=true,owndebuff=true}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.druid.tank.wowsims',revision=1,
 blocks={['era.druid.boundaries']=1,['era.druid.upkeep']=1,['sod.druid.maul']=1,['sod.druid.tank-cooldowns']=1,['sod.druid.bear']=1,['sod.druid.tank-humanoid']=1},
 nameKey='Default.SoD.Druid.Tank.Wowsims.Name',descriptionKey='Default.SoD.Druid.Tank.Wowsims.Description',
 applicability={families={'era'},actionContext='player',class='DRUID',minLevel=1,maxLevel=60,rulesets={'season:2'}},
 tags={'season-of-discovery','endgame','feral','tank','melee','single-target','wowsims'},
 sources={
  {url='https://github.com/wowsims/sod/blob/0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e/ui/feral_tank_druid/apls/catweave_rake.apl.json',title='wowsims/sod Feral tank cat-weave APL (Phase 7)',reviewedAt='2026-10-23',revision='0e3f6ef'},
 },
 body={priority=139,disabled=true,switch={type='SPELL_KNOWN',spell=414644},
  cooldowns={ref('sod-tank-ws-upkeep','era.druid.upkeep','sod-tank-ws-'),ref('sod-tank-ws-maul','sod.druid.maul','sod-tank-ws-'),ref('sod-tank-ws-cooldowns','sod.druid.tank-cooldowns','sod-tank-ws-')},
  rotation={
   ref('sod-tank-ws-boundaries','era.druid.boundaries','sod-tank-ws-'),
   {id='sod-tank-ws-cat',type='branch',conditions=own(768),onFalse={},onTrue={
    {id='sod-tank-ws-cat-no-target',type='none',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
    spell('sod-tank-ws-savage-roar',407988,all(negate(own(407988)),cp('GREATERTHANOREQUALS',2))),
    spell('sod-tank-ws-tigers-fury',417045,negate(rake),true),
    spell('sod-tank-ws-mangle',407993,all(known(407988),negate(own(407988)),cp('LESSTHAN',2)),true),
    spell('sod-tank-ws-rake',1822,negate(rake)),
    spell('sod-tank-ws-cat-dire-bear-form',9634),
    spell('sod-tank-ws-cat-bear-form',5487),
    {id='sod-tank-ws-cat-wait',type='none',conditions={}}}},
   {id='sod-tank-ws-bear',type='branch',conditions=any(own(5487),own(9634)),onFalse={},onTrue={
    spell('sod-tank-ws-cat-form',768,all(known(407988),{type='ATTACKABLE',unit='target'},negate(rake))),
    ref('sod-tank-ws-bear-section','sod.druid.bear','sod-tank-ws-bear-')}},
   ref('sod-tank-ws-humanoid','sod.druid.tank-humanoid','sod-tank-ws-'),
  },
 },
}))
