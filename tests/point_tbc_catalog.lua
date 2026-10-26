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
