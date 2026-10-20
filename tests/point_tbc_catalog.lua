-- Whole-catalog preservation and actual compiled value-binding identity.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local restore,oldBody,newBody=dofile('tests/fixtures/restore_point_tbc_transport.lua')
local h=assert(io.open('tests/point_tbc_transport.lua'));local text=h:read('*a');h:close()
local fixture=assert(loadstring(assert(text:match('^(.-)\ntest%('))..'\nreturn fixture','@point-catalog-fixture'))()
local oldHashes={
 ['Conditions/stats.lua']='f4cb3161da8fe05d04a1ea4700a557cdd24e6d5ee5bb9c376e6e261ccc77dcd7',
 ['Core/point_conditions.lua']='a73ccb7333af632938b66fc00738e6b5dc713aa29e0896a544f608c6f98774a9',
 ['Platform/points.lua']='cc118c323de118cf921263a043e42092c9ebe79671d22e1a4727905212c3df07',
}
test('all old catalog fields survive exactly after the one callback and four additive bindings',function()
 local _,a=fixture();local catalog=a:CopySettingsData(a.BuiltinSourceCatalog);local modules,bindings,conditions=0,0,0
 dofile('tests/fixtures/restore_swing_catalog.lua')(catalog)
 dofile('tests/fixtures/restore_distance_catalog.lua')(catalog)
 for _,m in pairs(catalog.modules)do modules=modules+1;for _ in pairs(m.bindings)do bindings=bindings+1 end end
 for _ in pairs(catalog.conditions)do conditions=conditions+1 end
 assert(modules==75 and bindings==238 and conditions==116,'unexpected catalog inventory change')
 local core=catalog.modules['Core/point_conditions.lua'].bindings;local platform=catalog.modules['Platform/points.lua'].bindings
 assert(core.GetConditionPointResourceV2.callName=='addon:GetConditionPointResourceV2')
 assert(platform.Platform_GetPlayerComboPointObservation.callName=='addon.Platform:GetPlayerComboPointObservation')
 assert(core.pointComboTypes.kind=='value'and core.pointComboValue.kind=='value')
 core.GetConditionPointResourceV2=nil;core.pointComboTypes=nil;core.pointComboValue=nil;platform.Platform_GetPlayerComboPointObservation=nil
 for path,hash in pairs(oldHashes)do catalog.modules[path].hash=hash end
 local point=catalog.conditions.POINT.callbacks.evaluate;assert(point.code==newBody);point.code=restore(point.code,'POINT',true)
 local _,oldLines=oldBody:gsub('\n','');local _,newLines=newBody:gsub('\n','');local shift=newLines-oldLines
 assert(shift==10,'unexpected approved evaluator line shift')
 for _,condition in pairs(catalog.conditions)do if condition.module=='Conditions/stats.lua'then
  for _,callback in pairs(condition.callbacks)do if callback.line>point.line then callback.line=callback.line-shift end end
 end end
 -- Compose the independently reviewed TIME readiness slice before the
 -- unchanged complete61ad catalog fingerprint; no other fields are masked.
 local timeInverse=dofile('tests/fixtures/restore_spell_history_time_readiness.lua')
 local timeHashes={['Conditions/spell.lua']='158b26ea9c0bd607f0a5e2f30a0da9fccb8d007189b42ddcca9c744038b9df15',['Conditions/petspell.lua']='beea507310073f5b476909714356af1c780c253a5f6c718da4cb46c963653987'}
 local moved=0
 for _,tag in ipairs({'SPELL_HISTORY_TIME','PETSPELL_HISTORY_TIME'})do
  local row=catalog.conditions[tag];local callback=row.callbacks.evaluate;local previous=timeInverse(callback.code,tag,true)
  local _,oldCount=previous:gsub('\n','');local _,newCount=callback.code:gsub('\n','');assert(newCount-oldCount==10)
  callback.code=previous;catalog.modules[row.module].hash=timeHashes[row.module]
  for _,condition in pairs(catalog.conditions)do if condition.module==row.module then for _,cb in pairs(condition.callbacks)do
   if cb.line>callback.line then cb.line=cb.line-10;moved=moved+1 end
  end end end
 end
 assert(moved==21,'unexpected TIME callback relocation count')
 assert(a:FunctionSourceHash(catalog)=='06307a3c','catalog changed beyond the exact POINT transport addition from61ad6ad')
end)
test('compiled public V2 retains actual Enum table identity rather than a serialized copy',function()
 for _,selector in ipairs({4,14})do local f,a=fixture(5,selector);local tableID='builtin:Core/point_conditions.lua:pointComboTypes';local valueID='builtin:Core/point_conditions.lua:pointComboValue'
  assert(a.builtinFunctions[tableID].valueBinding and a.builtinFunctions[valueID].valueBinding)
  local captured=a:ResolveFunctionBinding(tableID);assert(rawequal(captured,f.env.Enum.PowerType)and a:ResolveFunctionBinding(valueID)==selector)
  local id='builtin:Core/point_conditions.lua:GetConditionPointResourceV2';local record=a.builtinFunctions[id];local source=a:CopySettingsData(record.source)
  assert(source.bindings.pointComboTypes==tableID and source.bindings.pointComboValue==valueID)
  assert(source.bindings.playerClassCacheKey=='builtin:Core/point_conditions.lua:playerClassCacheKey')
  assert(a:InstallCustomFunction('V2_COPY',source));local copy=assert(a:ResolveFunctionBinding('V2_COPY'))
  local power,reason,transport=copy(a,'player',{});assert(power==selector and reason==nil and transport=='target-combo')
  f.env.Enum.PowerType={ComboPoints=selector};assert(select(3,copy(a,'player',{}))=='power','copied helper trusted a replacement table')
  f.env.Enum.PowerType=captured;assert(select(3,copy(a,'player',{}))=='target-combo')
  assert(a:SettingsDataEqual(source,a.builtinFunctions[id].source),'editable copy changed the published source')
 end
end)
test('new public observation copy keeps unknown failures and exact player target arguments',function()
 local f,a,s=fixture();local id='builtin:Platform/points.lua:Platform_GetPlayerComboPointObservation';local source=a:CopySettingsData(a.builtinFunctions[id].source)
 assert(a:InstallCustomFunction('COMBO_COPY',source));local copy=assert(a:ResolveFunctionBinding('COMBO_COPY'));s.calls={}
 assert(copy(a.Platform,4,'current')==5 and #s.calls==1 and s.calls[1][2]=='player'and s.calls[1][3]=='target')
 f.env.GetComboPoints=nil;local value,reason=copy(a.Platform,4,'current');assert(value==nil and reason=='missing-api'and #s.calls==1)
 f.env.GetComboPoints=function(...)assert(select('#',...)==2);return 0 end;assert(copy(a.Platform,4,'current')==0)
end)
finish()
