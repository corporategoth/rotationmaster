local restoreCreature=dofile('tests/fixtures/restore_creature_type_repairs.lua')
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path) local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local catalog=read('Data/builtin_sources.lua')
local inverse,oldBodies,newBodies,oldBindings,oldHashes=dofile('tests/fixtures/restore_mobinfo2_repairs.lua')
local tags={'RUNNER','RESIST','IMMUNE'}
local function fixture(project,providerPresent)
 local f=F.new(project or 11,2,'SHAMAN');local a,e=f.addon,f.env;local opaque={};local s={exists=true,name='Audit Mob',level=20,data={lowHpAction=1,resists={fi=1,fiHits=2}},calls={}}
 e.canaccessvalue=function(v) return not rawequal(v,opaque) end
 local function query(key,...) assert(select('#',...)==(key=='provider' and 3 or 1));s.calls[#s.calls+1]={key,...};if s.throw==key then error('native mob failed') end end
 e.UnitExists=function(...) query('exists',...);return s.exists end;e.UnitName=function(...) query('name',...);return s.name,opaque end;e.UnitLevel=function(...) query('level',...);return s.level,opaque end
 e.MI2_GetMobData=providerPresent==false and nil or function(...) query('provider',...);return s.data,opaque end
 if providerPresent==false then e.MI2_GetMobData=nil elseif providerPresent=='noncallable' then e.MI2_GetMobData=1 end
 local h=io.open('Platform/mobinfo2.lua');if h then h:close();f.load('Platform/mobinfo2.lua') end
 for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/character.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
 local chunk=assert(loadstring(catalog,'@mobinfo2-process-catalog'));setfenv(chunk,e);chunk('rotationmaster',a);f.load('Core/builtin_sources.lua')
 e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
 s.calls={};return f,a,s,opaque
end
local function node(tag) return {type=tag,unit='target',school='fi',operator='GREATERTHAN',value=.25,partial=false} end
local function unknown(a,v)
 assert(a.conditionDefinitions[v.type].valid(0,v),'invalid MobInfo2 fixture')
 for _,guard in ipairs({v,{type='NOT',value=v},{type='AND',value={v}},{type='OR',value={{type='NOT',value=v}}}}) do local result=a:evaluateConditionResult(guard);assert(result.status=='unavailable' and result.reason~='condition-callback-error' and result.reason~='invalid-condition-fields',tostring(result.status)..':'..tostring(result.reason))
  local body={rotation={{id='guard',type='branch',conditions=guard,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}};assert(a:EvaluateRotationSequence(body,function(v) return a:evaluateConditionResult(v) end,function() error('unknown MobInfo2 selected branch') end).status=='unavailable')
 end
 assert(#a.Diagnostics:GetReports()==0,'optional provider fault quarantined the condition')
end
test('unavailable required native and provider facts never authorize NOT or branches and recover without quarantine',function()
 for _,tag in ipairs(tags) do for _,field in ipairs({'exists','name','level','provider'}) do for _,mode in ipairs({'missing','throw','opaque','malformed','nil'}) do
  local f,a,s,opaque=fixture();if mode=='missing' then f.env[({exists='UnitExists',name='UnitName',level='UnitLevel',provider='MI2_GetMobData'})[field]]=nil elseif mode=='throw' then s.throw=field elseif mode=='opaque' then if field=='provider' then s.data=opaque else s[field]=opaque end elseif mode=='malformed' then if field=='provider' then s.data=false else s[field]={} end elseif field~='provider' then s[field]=nil end
  if not (mode=='nil' and field=='provider') then unknown(a,node(tag)) end
 end end end
 for _,tag in ipairs(tags) do local _,a,s=fixture();s.throw='provider';unknown(a,node(tag));s.throw=nil;assert(a:evaluateConditionResult(node(tag)).status==(tag=='IMMUNE' and 'no-match' or 'match')) end
end)
test('known absent unrecorded nil and omitted school histories preserve deliberate false controls',function()
 for _,tag in ipairs(tags) do for _,mode in ipairs({'absent','no-record','empty-record','empty-school'}) do local _,a,s=fixture();if mode=='absent' then s.exists=false elseif mode=='no-record' then s.data=nil elseif mode=='empty-record' then s.data={} else s.data.resists={} end
  if tag~='RUNNER' or mode~='empty-school' then local v=node(tag);assert(a:evaluateConditionResult(v).status=='no-match' and a:evaluateConditionResult({type='NOT',value=v}).status=='match') end
 end end
end)
test('finite runner truthiness resistance sign ratios and complete partial immunity retain exact meanings',function()
 local _,a,s=fixture();for _,x in ipairs({0,-1,1.5,true,false,'','run'}) do s.data.lowHpAction=x;assert(a:evaluateConditionResult(node('RUNNER')).status==(x and 'match' or 'no-match')) end
 s.data.resists.fi=-1;s.data.resists.fiHits=0;assert(a:evaluateConditionResult(node('IMMUNE')).status=='match' and a:evaluateConditionResult(node('RESIST')).status=='no-match')
 s.data.resists.fiHits=2;assert(a:evaluateConditionResult(node('IMMUNE')).status=='no-match');local v=node('IMMUNE');v.partial=true;assert(a:evaluateConditionResult(v).status=='match')
 s.data.resists.fi=1;s.data.resists.fiHits=nil;assert(a:evaluateConditionResult(node('RESIST')).status=='match');s.data.resists.fiHits=-2;assert(a:evaluateConditionResult(node('RESIST')).status=='no-match')
 for _,tag in ipairs(tags) do local v=node(tag);s.data={lowHpAction=1,resists={fi=tag=='IMMUNE' and -1 or 1,fiHits=tag=='IMMUNE' and 0 or 2}};local selected;local body={rotation={{id='yes',type='branch',conditions=v,onTrue={{id='selected',type='spell',action=1}},onFalse={}}}};a:EvaluateRotationSequence(body,function(n) return a:evaluateConditionResult(n) end,function(n) selected=n.id;return true end);assert(selected=='selected') end
end)
test('malformed consumed history and nonfinite resistance arithmetic stay unknown without requiring unrelated fields',function()
 local _,a,s,opaque=fixture();for _,bad in ipairs({opaque,{},function() end,0/0,math.huge}) do s.data.lowHpAction=bad;unknown(a,node('RUNNER')) end
 s.data.lowHpAction=1;for _,bad in ipairs({0,0/0,math.huge,opaque,{},'2'}) do s.data.resists.fiHits=bad;unknown(a,node('RESIST')) end
 s.data.resists.fi=1e308;s.data.resists.fiHits=1e-308;unknown(a,node('RESIST'));s.data.resists.fi=opaque;unknown(a,node('IMMUNE'))
 s.data.resists.fi=-1;s.data.resists.fiHits=opaque;local v=node('IMMUNE');v.partial=true;assert(a:evaluateConditionResult(v).status=='match');v.partial=false;unknown(a,v)
end)
test('presence-only cache shares units across kinds while metadata provider and public helper clones stay fresh',function()
 local _,a,s=fixture();local cache={};for _,tag in ipairs(tags) do assert(a.conditionDefinitions[tag].evaluate(node(tag),cache)~=nil) end
 assert(#s.calls==10 and s.calls[1][1]=='exists');for i=2,10,3 do assert(s.calls[i][1]=='name' and s.calls[i+1][1]=='level' and s.calls[i+2][1]=='provider') end
 s.exists=nil;cache={};local value,why=a.conditionDefinitions.RUNNER.evaluate(node('RUNNER'),cache);assert(value==nil and why);s.exists=true;local again,reason=a.conditionDefinitions.RESIST.evaluate(node('RESIST'),cache);assert(again==nil and reason==why);assert(a.conditionDefinitions.RESIST.evaluate(node('RESIST'),{}))
end)
test('optional registration stays load-time truthiness while unsupported policies require no native queries',function()
 local f,a=fixture(11,false);for _,tag in ipairs(tags) do assert(a.conditionDefinitions[tag]==nil) end;f.env.MI2_GetMobData=function() return {} end;for _,tag in ipairs(tags) do assert(a.conditionDefinitions[tag]==nil) end
 local _,registered=fixture(11,'noncallable');for _,tag in ipairs(tags) do assert(registered.conditionDefinitions[tag]);unknown(registered,node(tag)) end
 for _,project in ipairs({999}) do local _,a,s=fixture(project);for _,tag in ipairs(tags) do unknown(a,node(tag)) end;assert(#s.calls==0) end
end)
test('actual current exported and public helper copies share presence authority with fresh provider facts',function()
 local _,a,s=fixture();for _,tag in ipairs(tags) do local source=assert(a:GetBuiltinConditionSource(tag));assert(source.evaluate==newBodies[tag],'MobInfo2 catalog pending');a:RegisterCondition('COPY_'..tag,assert(a:CompileCustomCondition('COPY_'..tag,source))) end
 local cache={};assert(a.conditionDefinitions.RUNNER.evaluate(node('RUNNER'),cache));s.data.lowHpAction=false;assert(a.conditionDefinitions.COPY_RUNNER.evaluate(node('COPY_RUNNER'),cache)==false and #s.calls==7)
 for _,tag in ipairs(tags) do s.exists=nil;unknown(a,node('COPY_'..tag));s.exists=true end
 local id='builtin:Platform/mobinfo2.lua:Platform_GetMobInfo2Observation';local record=assert(a.builtinFunctions[id],'MobInfo2 public catalog pending');assert(a:ResolveFunctionBinding(id)==a.Platform.GetMobInfo2Observation);assert(a:InstallCustomFunction('COPY_MOBINFO2',a:CopySettingsData(record.source)));local fn=a:ResolveFunctionBinding('COPY_MOBINFO2');assert(record.source.args[1].type=='RMPlatform')
 s.calls={};cache={};fn(a.Platform,'target','runner',nil,cache);a.Platform:GetMobInfo2Observation('target','resist','fi',cache);assert(#s.calls==7,'cloned helper lost actual private presence identity')
end)
test('archived raw bindings sources nil behavior and provider errors remain byte exact',function()
 for _,tag in ipairs(tags) do local _,a,s=fixture();local source=assert(a:GetBuiltinConditionSource(tag));source.evaluate=oldBodies[tag];source.bindings=a:CopySettingsData(oldBindings[tag]);assert(a:FunctionSourceHash(source)==oldHashes[tag]);local saved=a:CopySettingsData(source);local definition=assert(a:CompileCustomCondition('RAW_'..tag,source));a:RegisterCondition('RAW_'..tag,definition)
  s.exists=nil;assert(a:evaluateConditionResult({type='NOT',value=node('RAW_'..tag)}).status=='match');s.exists=true;s.throw='provider';local ok,why=pcall(definition.evaluate,node(tag),{});assert(not ok and tostring(why):find('native mob failed',1,true));assert(a:SettingsDataEqual(source,saved))
 end
end)
test('strict three-body inverse preserves whole character ROLE exports and every historic private identity',function()
 local _,a=fixture();assert(a:FunctionSourceHash(inverse(dofile('tests/fixtures/restore_glyph_presentation_repairs.lua')((restoreCreature(read('Conditions/character.lua'))))))=='ea9510de','change outside three MobInfo2 evaluators')
 for _,tag in ipairs(tags) do local source=assert(a:GetBuiltinConditionSource(tag));source.evaluate=inverse(source.evaluate,tag,true);source.bindings=a:CopySettingsData(oldBindings[tag]);assert(a:FunctionSourceHash(source)==oldHashes[tag]) end
 for name,hash in pairs({color='3f9fe631',character_class='f9f4e4b5',helpers='2e9a81e7',unit_class_num='33645816'}) do local id='builtin:Conditions/character.lua:'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/character.lua'](name)) end
 assert(not pcall(inverse,read('Conditions/character.lua')..read('Conditions/character.lua')));assert(not pcall(inverse,newBodies.RUNNER..' ','RUNNER',true))
end)
finish()
