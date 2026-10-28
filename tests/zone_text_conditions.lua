-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local inverse,old,repaired=dofile('tests/fixtures/restore_zone_text_repairs.lua')
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function fixture()
 local f=F.new();local a,e=f.addon,f.env;local s={zone='Orgrimmar',subzone='Valley of Strength',trace={},tail={}}
 local function query(kind,...)assert(select('#',...)==0,'zone query gained native arguments');s.trace[#s.trace+1]=kind;if s.throws==kind then error(s.marker or 'selected zone failure')end;return s[kind],s.tail end
 e.GetZoneText=function(...)return query('zone',...)end;e.GetSubZoneText=function(...)return query('subzone',...)end
 for _,path in ipairs({'Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/common.lua','Conditions/spatial.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'})do f.load(path)end
 e.loadstring=function(code,name)local fn,why=loadstring(code,name);if fn then setfenv(fn,e)end;return fn,why end
 return f,a,s
end
local function node(subzone,text,tag)return{type=tag or'ZONE',value=text or'Orgrimmar',subzone=subzone}end
local function unknown(a,v,reason)
 assert(a:validateCondition(v,0),'invalid unavailable fixture')
 for _,n in ipairs({v,{type='NOT',value=v},{type='AND',value={v}},{type='OR',value={{type='NOT',value=v}}}})do local r=a:evaluateConditionResult(n);assert(r.status=='unavailable','required zone text became '..r.status);if reason then assert(r.reason==reason,r.reason)end end
 for _,guard in ipairs({v,{type='NOT',value=v}})do local selected;local r=a:EvaluateRotationSequence({rotation={{id='guard',type='branch',conditions=guard,onTrue={{id='yes',type='spell',action=403}},onFalse={{id='no',type='spell',action=403}}}}},function(n)return a:evaluateConditionResult(n)end,function(n)selected=n.id end);assert(r.status=='unavailable'and not selected,'unknown zone selected a branch')end
end
local function known(a,v,match)
 assert(a:validateCondition(v,0));assert(a:evaluateConditionResult(v).status==(match and'match'or'no-match'));assert(a:evaluateConditionResult({type='NOT',value=v}).status==(match and'no-match'or'match'))
end
test('required main and selected subzone nil remain unknown through real engine logical and branch paths',function()
 for _,subzone in ipairs({false,true})do local _,a,s=fixture();s[subzone and'subzone'or'zone']=nil;unknown(a,node(subzone),'zone-text-unavailable');for _,call in ipairs(s.trace)do assert(call==(subzone and'subzone'or'zone'),'unavailable selected subzone fell through to main zone')end end
end)
test('readable empty and localized native text stay known without nonempty or locale conversion rules',function()
 for _,subzone in ipairs({false,true})do for _,text in ipairs({'','Orgrimmar','Vallée de la Force','暴风城'})do local _,a,s=fixture();s[subzone and'subzone'or'zone']=text;known(a,node(subzone,text),true);known(a,node(subzone,text..' different'),false);for _,call in ipairs(s.trace)do assert(call==(subzone and'subzone'or'zone'))end end end
end)
test('missing selected API does not require or fall back to the other zone query',function()
 for _,subzone in ipairs({false,true})do local f,a,s=fixture();f.env[subzone and'GetSubZoneText'or'GetZoneText']=nil;unknown(a,node(subzone),'missing-api');assert(#s.trace==0)end
end)
test('protected selected failure returns unavailable without quarantining later recovery',function()
 for _,subzone in ipairs({false,true})do local _,a,s=fixture();s.throws=subzone and'subzone'or'zone';unknown(a,node(subzone),'api-error');s.throws=nil;known(a,node(subzone,subzone and'Valley of Strength'or'Orgrimmar'),true)end
end)
test('restricted and malformed consumed text are unavailable while unused opaque tails are ignored',function()
 for _,subzone in ipairs({false,true})do local f,a,s=fixture();local key=subzone and'subzone'or'zone';local opaque={};s[key]=opaque;f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end;unknown(a,node(subzone),'restricted-value')
  for _,v in ipairs({false,0,1,{},function()end})do s[key]=v;unknown(a,node(subzone),'zone-text-unavailable')end
  s[key]='';s.tail=opaque;known(a,node(subzone,''),true)
 end
end)
test('original actual native function keys share snapshots complete nil tuples and separate modes',function()
 local f,a,s=fixture();local fn=a.conditionDefinitions.ZONE.evaluate;local cache={};local get=a.Functions.cache.getCached
 local first,tail=get(cache,f.env.GetZoneText);assert(first=='Orgrimmar'and tail==s.tail and #s.trace==1);assert(fn(node(false),cache)==true and fn(node(nil),cache)==true and #s.trace==1)
 assert(fn(node(true,'Valley of Strength'),cache)==true and #s.trace==2)
 cache={};s.subzone=nil;local value,reason=fn(node(true),cache);assert(value==nil and reason=='zone-text-unavailable');local before=#s.trace;s.subzone='Orgrimmar';value,reason=fn(node(true),cache);assert(value==nil and reason=='zone-text-unavailable'and #s.trace==before)
 local native,unused=get(cache,f.env.GetSubZoneText);assert(native==nil and unused==s.tail and #s.trace==before,'native full nil tuple lost');assert(fn(node(true),{})==true and #s.trace==before+1)
 local calls=#s.trace;fn(node(false));fn(node(false));assert(#s.trace==calls+2,'nil cache stopped reading native text')
end)
test('live native replacement partitions the same cache and no client or unrelated metadata policy is added',function()
 local f,a,s=fixture();local fn=a.conditionDefinitions.ZONE.evaluate;local cache={};assert(fn(node(false),cache)==true)
 f.env.GetZoneText=function(...)assert(select('#',...)==0);return 'Replacement' end;assert(fn(node(false,'Replacement'),cache)==true)
 a.Platform.GetClientInfo=function()error('zone text added a client policy query')end;f.env.WOW_PROJECT_ID=999;assert(fn(node(false,'Replacement'),{})==true)
end)
test('private helper source identities of the Spatial module stay exact',function()
 local _,a=fixture()
 for alias,hash in pairs({RangeCheck='272f05e0',booleanRead='3b3ceeb2',finite='9e1e3ece',color='158ebd8f',helpers='9485f785',rcf='a7ab75e4',protectedRead='cc49d134'})do local id='builtin:Conditions/spatial.lua:'..alias;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and rawequal(a:ResolveFunctionBinding(id),a.builtinSourceModules['Conditions/spatial.lua'](alias)),'private identity changed '..alias)end
end)
test('actual current compiled source guards selected facts and whole saved raw source retains its historic fallback',function()
 for _,subzone in ipairs({false,true})do local _,a,s=fixture();local source=a:GetBuiltinConditionSource('ZONE');local before=a:CopySettingsData(source);a:RegisterCondition('COPY',assert(a:CompileCustomCondition('COPY',source)));s[subzone and'subzone'or'zone']=nil;unknown(a,node(subzone,nil,'COPY'),'zone-text-unavailable')
  local raw=a:CopySettingsData(source);raw.evaluate=old;local frozen=a:CopySettingsData(raw);a.db.global.custom_conditions={SAVED=raw};a:RegisterCondition('SAVED',assert(a:CompileCustomCondition('SAVED',raw)));known(a,node(subzone,nil,'SAVED'),subzone)
  assert(a:SettingsDataEqual(raw,frozen)and a:SettingsDataEqual(source,before)and a.db.global.custom_conditions.SAVED==raw)
 end
end)
finish()
