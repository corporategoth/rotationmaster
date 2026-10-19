local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path) local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local catalog=read('Data/builtin_sources.lua')
local inverse,oldBodies,newBodies,oldBindings=dofile('tests/fixtures/restore_role_repairs.lua')
local function fixture(project,expansion,actualPolicy)
 local f=F.new(project or 11,expansion or 2,'SHAMAN');local a,e=f.addon,f.env;local s={exists=true,spec=77,role='HEALER',talent='HEALER',calls={}};local opaque={}
 local function call(key,...) assert(select('#',...)==1);s.calls[#s.calls+1]={key,arg=(...),arity=select('#',...)};if s.throw==key then error('native role failure') end end
 e.canaccessvalue=function(v) return not rawequal(v,opaque) end
 e.UnitExists=function(...) call('exists',...);return s.exists end
 e.UnitClass=function() return 'Shaman','SHAMAN',7 end;e.IsInRaid=function() return false end;e.IsInGroup=function() return false end
 e.C_SpecializationInfo={GetInspectSpecialization=function(...) call('modern',...);return s.spec end}
 e.GetInspectSpecialization=function(...) call('legacy',...);return s.spec end
 e.GetSpecializationInfoByID=function(...) call('metadata',...);return opaque,opaque,opaque,opaque,s.role,'SHAMAN' end
 e.GetTalentGroupRole=function(...) call('talent',...);return s.talent,opaque end
 local h=io.open('Platform/role.lua');if h then h:close();f.load('Platform/role.lua') end
 if not actualPolicy then local get=a.Platform.GetClientInfo;a.Platform.GetClientInfo=function(self) local info=get(self);info.combatDataPolicy='probe';return info end end
 for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/character.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
 local chunk=assert(loadstring(catalog,'@process-catalog-snapshot'));setfenv(chunk,e);chunk('rotationmaster',a);f.load('Core/builtin_sources.lua')
 e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
 s.calls={};return f,a,s,opaque
end
local function node(unit,tag) return {type=tag or 'ROLE',unit=unit or 'target',value='HEALER'} end
local function unknown(a,v)
 assert(a.conditionDefinitions[v.type].valid(0,v),'invalid ROLE fixture')
 for _,guard in ipairs({v,{type='NOT',value=v},{type='AND',value={v}},{type='OR',value={{type='NOT',value=v}}}}) do
  local r=a:evaluateConditionResult(guard);assert(r.status=='unavailable' and r.reason~='condition-callback-error' and r.reason~='invalid-condition-fields',tostring(r.status)..':'..tostring(r.reason))
  local body={rotation={{id='role',type='branch',conditions=guard,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
  assert(a:EvaluateRotationSequence(body,function(n) return a:evaluateConditionResult(n) end,function() error('unknown ROLE selected branch') end).status=='unavailable')
 end
 assert(#a.Diagnostics:GetReports()==0,'native observation failure quarantined ROLE')
end
local variants={{1,12,'inspect'},{11,2,'talent'}}
test('actual valid ROLE fixes inspect result5 and retains known mismatch absence and branch behavior',function()
 for _,shape in ipairs(variants) do local _,a,s=fixture(shape[1],shape[2]);local v=node();assert(a.conditionDefinitions.ROLE.valid(0,v));assert(a:evaluateConditionResult(v).status=='match','known HEALER did not match')
  assert(a:evaluateConditionResult({type='NOT',value=v}).status=='no-match')
  local matching;local yesBody={rotation={{id='role',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}};a:EvaluateRotationSequence(yesBody,function(n) return a:evaluateConditionResult(n) end,function(n) matching=n.id;return true end);assert(matching=='yes')
  s.role='FUTURE_ROLE';s.talent='NONE';assert(a:evaluateConditionResult(v).status=='no-match' and a:evaluateConditionResult({type='NOT',value=v}).status=='match')
  local selected;local body={rotation={{id='role',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}};a:EvaluateRotationSequence(body,function(n) return a:evaluateConditionResult(n) end,function(n) selected=n.id;return true end);assert(selected=='no')
  if shape[3]=='inspect' then s.exists=false;s.calls={};assert(a:evaluateConditionResult(v).status=='no-match' and #s.calls==1) end
 end
end)
test('missing failed nil empty malformed and restricted facts stay unknown under NOT groups and branches',function()
 for _,shape in ipairs(variants) do local fields=shape[3]=='inspect' and {'exists','spec','role'} or {'talent'}
  for _,field in ipairs(fields) do for _,mode in ipairs({'nil','throw','missing','restricted','',false,{}}) do
   local f,a,s,opaque=fixture(shape[1],shape[2]);if mode=='nil' then s[field]=nil elseif mode=='throw' then s.throw=field=='spec' and 'modern' or field=='role' and 'metadata' or field
   elseif mode=='missing' then if field=='exists' then f.env.UnitExists=nil elseif field=='spec' then f.env.C_SpecializationInfo=nil;f.env.GetInspectSpecialization=nil elseif field=='role' then f.env.GetSpecializationInfoByID=nil else f.env.GetTalentGroupRole=nil end
   elseif mode=='restricted' then s[field]=opaque else s[field]=mode end
   if not (field=='exists' and mode==false) then unknown(a,node()) end
  end end
 end
end)
test('canonical outer cache preserves nil tuples and isolates selected units receiver and currentSpec',function()
 for _,shape in ipairs(variants) do local _,a,s=fixture(shape[1],shape[2]);local inspect=shape[3]=='inspect';local key=inspect and 'role' or 'talent';local count=inspect and 3 or 1;local evaluate=a.conditionDefinitions.ROLE.evaluate;local cache={};s[key]=nil
  local v,why=evaluate(node(),cache);assert(v==nil and why);s[key]='HEALER';local again,reason=evaluate(node(),cache);assert(again==nil and why==reason and #s.calls==count)
  assert(evaluate(node(),{})==true and evaluate(node())==true and #s.calls==count*3)
  s.calls={};cache={};assert(evaluate(node(),cache));assert(evaluate(node(),cache));assert(#s.calls==count)
  if inspect then assert(evaluate(node('pet'),cache) and #s.calls==count*2)
  else a.currentSpec=2;assert(evaluate(node(),cache) and s.calls[2].arg==2);a.currentSpec=nil;assert(evaluate(node(),cache) and s.calls[3].arg==nil and s.calls[3].arity==1) end
  local method=inspect and a.Platform.GetInspectRoleObservation or a.Platform.GetTalentGroupRoleObservation;local other=setmetatable({},{__index=a.Platform});assert(a.Functions.cache.getCached(cache,method,other,inspect and 'target' or a.currentSpec)=='HEALER')
  if inspect then s.exists=false;s.calls={};cache={};assert(evaluate(node(),cache)==false);s.exists=true;assert(evaluate(node(),cache)==false and #s.calls==1);assert(evaluate(node(),{})==true) end
  assert(next(a.longtermCache)==nil)
 end
end)
test('registration branches unchanged while real non-probe policies deny without native calls and recover fresh',function()
 for _,shape in ipairs({{1,12,'inspect'},{18,12,'talent'},{11,2,'talent'},{14,3,'talent'},{19,4,'talent'},{5,1,false},{2,0,false},{999,12,'talent'}}) do local _,a,s=fixture(shape[1],shape[2],true);local definition=a.conditionDefinitions.ROLE
  if shape[3] then assert(definition.builtinSourceVariant==shape[3] and (definition.fields.unit~=nil)==(shape[3]=='inspect'));if shape[1]==1 or shape[1]==18 or shape[1]==999 then unknown(a,node());assert(#s.calls==0) else assert(a:evaluateConditionResult(node()).status=='match') end
  else assert(definition==nil) end
 end
 for _,shape in ipairs(variants) do local _,a,s=fixture(shape[1],shape[2]);s.throw=shape[3]=='inspect' and 'modern' or 'talent';unknown(a,node());s.throw=nil;assert(a:evaluateConditionResult(node()).status=='match') end
end)
test('current exported clones share actual normalized role snapshots and slot5 semantics',function()
 for _,shape in ipairs(variants) do local _,a,s=fixture(shape[1],shape[2]);local source=assert(a:GetBuiltinConditionSource('ROLE'));assert(source.evaluate==newBodies[shape[3]],'ROLE catalog pending');a:RegisterCondition('COPY_ROLE',assert(a:CompileCustomCondition('COPY_ROLE',source)))
  local cache={};assert(a.conditionDefinitions.ROLE.evaluate(node(),cache));assert(a.conditionDefinitions.COPY_ROLE.evaluate(node(nil,'COPY_ROLE'),cache));assert(#s.calls==(shape[3]=='inspect' and 3 or 1))
  s[shape[3]=='inspect' and 'role' or 'talent']=nil;unknown(a,node(nil,'COPY_ROLE'))
 end
end)
test('new public helper source clones preserve actual owned policy receiver and exact query tuples',function()
 for _,shape in ipairs(variants) do local _,a,s=fixture(shape[1],shape[2]);local name=shape[3]=='inspect' and 'Platform_GetInspectRoleObservation' or 'Platform_GetTalentGroupRoleObservation';local id='builtin:Platform/role.lua:'..name;local record=assert(a.builtinFunctions[id],'public ROLE helper catalog pending');local method=shape[3]=='inspect' and a.Platform.GetInspectRoleObservation or a.Platform.GetTalentGroupRoleObservation
  assert(a:ResolveFunctionBinding(id)==method and a.builtinSourceModules['Platform/role.lua'](name)==method);assert(record.source.args[1].type=='RMPlatform' and #record.source.description>0)
  assert(a:InstallCustomFunction('COPY_ROLE_HELPER',a:CopySettingsData(record.source)));local fn=assert(a:ResolveFunctionBinding('COPY_ROLE_HELPER'));assert(fn(a.Platform,shape[3]=='inspect' and 'target' or 2)=='HEALER')
  s[shape[3]=='inspect' and 'role' or 'talent']=nil;local result,why=fn(a.Platform,shape[3]=='inspect' and 'target' or 2);assert(result==nil and why)
 end
end)
test('archived raw source retains complete bindings global inspect slot6 and nil role mismatch without rewriting',function()
 for _,shape in ipairs(variants) do local _,a,s=fixture(shape[1],shape[2]);local source=assert(a:GetBuiltinConditionSource('ROLE'));source.evaluate=oldBodies[shape[3]];source.bindings=a:CopySettingsData(oldBindings[shape[3]]);local before=a:CopySettingsData(source)
  assert(a:FunctionSourceHash(source)==(shape[3]=='inspect' and '0e207da1' or '825b57b5'),'archived ROLE export changed');local d=assert(a:CompileCustomCondition('RAW_ROLE',source));a:RegisterCondition('RAW_ROLE',d)
  if shape[3]=='inspect' then assert(d.evaluate(node(),{})==false and s.calls[2][1]=='legacy','historical inspect slot6/global behavior changed') else s.talent=nil;assert(d.evaluate(node(),{})==false) end
  assert(a:evaluateConditionResult({type='NOT',value=node(nil,'RAW_ROLE')}).status=='match' and a:SettingsDataEqual(source,before))
 end
end)
test('strict inverse restores entire087a686 module both exports and four exact private source identities',function()
 local text=read('Conditions/character.lua');local _,a=fixture();assert(a:FunctionSourceHash(inverse(text))=='4df013ba','unexpected change outside two ROLE evaluates')
 for _,shape in ipairs(variants) do local _,owner=fixture(shape[1],shape[2]);local source=assert(owner:GetBuiltinConditionSource('ROLE'));source.evaluate=inverse(source.evaluate,shape[3],true);source.bindings=owner:CopySettingsData(oldBindings[shape[3]])
  assert(owner:FunctionSourceHash(source)==(shape[3]=='inspect' and '0e207da1' or '825b57b5'),'non-evaluate ROLE export changed')
 end
 for name,hash in pairs({color='3f9fe631',character_class='f9f4e4b5',helpers='2e9a81e7',unit_class_num='33645816'}) do local id='builtin:Conditions/character.lua:'..name;assert(a:FunctionSourceHash(assert(a.builtinFunctions[id]).source)==hash and a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/character.lua'](name)) end
 assert(not pcall(inverse,text..text));assert(not pcall(inverse,newBodies.inspect..' ','inspect',true))
end)
finish()
