local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local inverse,oldBody,newBody=dofile('tests/fixtures/restore_combat_history_time_repairs.lua')
local function read(path) local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local catalogText=read('Data/builtin_sources.lua')
local producerText=assert(read('main.lua'):match('addon%.UNIT_COMBAT = wrapCombatEvent%((function.-\nend)%)'))
local function fixture(project,expose)
 local f=F.new(project or 11,2,'SHAMAN');local a,e=f.addon,f.env;local s={now=100,clockCalls=0}
 e.GetTime=function(...) assert(select('#',...)==0);s.clockCalls=s.clockCalls+1;return s.now end
 -- Test-only deterministic iteration for a selected history; the production
 -- callback retains its ordinary pairs traversal and no chronology guarantee.
 e.pairs=function(t) if rawequal(t,s.orderedHistory) then return ipairs(t) end;return pairs(t) end
 for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
 local captured
 if expose then
  -- Return the actual private map from this test loader only. Ordinary addon
  -- alias rebinding cannot mutate the Built In's private comparison leaf.
  local chunk=assert(loadstring(read('Conditions/combat.lua')..'\nreturn Functions\n','@Conditions/combat.lua'));setfenv(chunk,e);captured=chunk('rotationmaster',a)
 else f.load('Conditions/combat.lua') end
 local chunk=assert(loadstring(catalogText,'@combat-history-catalog-snapshot'));setfenv(chunk,e);chunk('rotationmaster',a);f.load('Core/builtin_sources.lua')
 e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
 local getProducer=assert(loadstring('return '..producerText,'@actual-unit-combat-producer'));setfenv(getProducer,e)
 a.combatHistory={target={{time=90,action='WOUND'}}};return f,a,s,getProducer(),captured
end
local function node(op,value,tag) return {type=tag or 'COMBAT_HISTORY_TIME',unit='target',action='WOUND',operator=op or 'GREATERTHAN',value=value or 0} end
local function branch(a,v)
 local selected;local body={rotation={{id='gate',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
 local result=a:EvaluateRotationSequence(body,function(c) return a:evaluateConditionResult(c) end,function(action) selected=action.id;return true end);return result,selected
end
local function unknown(a,v)
 assert(a.conditionDefinitions[v.type].valid(0,v),'unknown fixture must pass unchanged validation')
 for _,c in ipairs({v,{type='NOT',value=v},{type='AND',value={v}},{type='OR',value={{type='NOT',value=v}}}}) do local r=a:evaluateConditionResult(c);assert(r.status=='unavailable' and r.reason~='condition-callback-error' and r.reason~='invalid-condition-fields','unknown history became '..r.status..':'..tostring(r.reason)) end
 for _,c in ipairs({v,{type='NOT',value=v}}) do local r,selected=branch(a,c);assert(r.status=='unavailable' and selected==nil) end
 assert(#a.Diagnostics:GetReports()==0,'numeric availability relied on error quarantine')
end
local function known(a,v,match)
 assert(a.conditionDefinitions[v.type].valid(0,v));assert(a:evaluateConditionResult(v).status==(match and 'match' or 'no-match'))
 local r,selected=branch(a,v);assert(r.status=='complete' and selected==(match and 'yes' or 'no'))
end

test('actual event producer timestamps remain nonactionable when their consumed clock is nonfinite',function()
 for _,bad in ipairs({0/0,math.huge,-math.huge}) do local _,a,s,append=fixture();a.combatHistory={};s.now=bad;append(a,'UNIT_COMBAT','target','WOUND',nil,10,1);assert(s.clockCalls==1 and a.combatHistory.target[1].action=='WOUND');s.now=100;unknown(a,node()) end
end)
test('required recorded and supplied numeric domains reject missing malformed and restricted facts without reports',function()
 for _,which in ipairs({'row','clock'}) do for _,bad in ipairs({false,true,'90',{},0/0,math.huge,-math.huge,'nil','opaque'}) do
  local f,a,s=fixture();local opaque=setmetatable({},{__sub=function() error('unreadable time used') end});local value=bad;if bad=='nil' then value=nil elseif bad=='opaque' then value=opaque end
  f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
  if which=='row' then a.combatHistory.target[1].time=value else s.now=value end;unknown(a,node())
 end end
end)
test('finite subtraction overflow and an explicitly unreadable derived elapsed stay unknown',function()
 for _,pair in ipairs({{-1e308,1e308},{1e308,-1e308}}) do local _,a,s=fixture();a.combatHistory.target[1].time=pair[1];s.now=pair[2];unknown(a,node()) end
 local f,a=fixture();f.env.canaccessvalue=function(value) return value~=10 end;unknown(a,node())
end)
test('finite signed fractional zero and negative elapsed preserve operators and configured threshold scope',function()
 local _,a,s=fixture()
 for _,case in ipairs({{'EQUALS',10,true},{'NOTEQUALS',10,false},{'LESSTHAN',5,false},{'LESSTHANOREQUALS',10,true},{'GREATERTHAN',0,true},{'GREATERTHANOREQUALS',10,true},{'DIVISIBLE',5,true}}) do known(a,node(case[1],case[2]),case[3]) end
 for _,case in ipairs({{100.5,100,'LESSTHAN',0},{-3,-2,'EQUALS',1},{0,0,'EQUALS',0},{1e308,1e308,'EQUALS',0}}) do a.combatHistory.target[1].time=case[1];s.now=case[2];known(a,node(case[3],case[4]),true) end
 a.combatHistory.target[1].time=90;s.now=100;local unbounded=node('LESSTHAN',math.huge);assert(a.conditionDefinitions.COMBAT_HISTORY_TIME.valid(0,unbounded) and a:evaluateConditionResult(unbounded).status=='match','configured threshold scope changed')
end)
test('absent and empty history skip numeric requirements and successful rows preserve later-row laziness',function()
 local f,a,s=fixture();local evaluate=a.conditionDefinitions.COMBAT_HISTORY_TIME.evaluate;local opaque={};f.env.canaccessvalue=function(v) assert(not rawequal(v,opaque),'empty history consumed time');return true end
 a.combatHistory.target=nil;assert(evaluate(node(),nil,opaque)==false);a.combatHistory.target={};assert(evaluate(node(),nil,opaque)==false)
 s.now=0/0;known(a,node(),false);a.combatHistory.target=nil;known(a,node(),false)
 a.combatHistory.target={{time=90,action='WOUND'},setmetatable({action='WOUND'},{__index=function(_,key) if key=='time' then error('later time consumed') end end})};s.orderedHistory=a.combatHistory.target;assert(evaluate(node(),{},100)==true)
 a.combatHistory.target={{time=0/0,action='HEAL'}};s.now=100;unknown(a,node())
end)
test('callee operator timestamp and threshold getter ordering retain finite old behavior and thrown identity',function()
 for _,case in ipairs({'operator-time','callee-time','callee-operator','threshold-after-time','threshold-rebinds-callee','threshold-throws','timestamp-throws'}) do
  local _,a,_,_,captured=fixture(nil,true);local evaluate=a.conditionDefinitions.COMBAT_HISTORY_TIME.evaluate;local trace={};local marker={};local v=node();local map=captured.values;local original=map.compare
  map.compare=function(...) trace[#trace+1]='compare';return original(...) end
  local poison=function() trace[#trace+1]='poison';return false end
  a.combatHistory.target={setmetatable({action='WOUND'},{__index=function(_,key) if key=='time' then trace[#trace+1]='time';if case=='operator-time' then v.operator='LESSTHAN' elseif case=='callee-time' then map.compare=poison elseif case=='threshold-after-time' then v.value=20 elseif case=='timestamp-throws' then error(marker) end;return 90 end end})}
  if case=='callee-operator' then v.operator=nil;setmetatable(v,{__index=function(_,key) if key=='operator' then trace[#trace+1]='operator';map.compare=poison;return 'GREATERTHAN' end end}) end
  if case=='threshold-rebinds-callee' or case=='threshold-throws' then v.value=nil;setmetatable(v,{__index=function(_,key) if key=='value' then trace[#trace+1]='threshold';if case=='threshold-throws' then error(marker) end;map.compare=poison;return 0 end end}) end
  local ok,result=pcall(evaluate,v,{},100)
  if case=='threshold-throws' or case=='timestamp-throws' then assert(not ok and result==marker) else assert(ok and result==(case~='threshold-after-time')) end
  local expected=case=='callee-operator' and 'operator,time,compare' or case=='threshold-rebinds-callee' and 'time,threshold,compare' or case=='threshold-throws' and 'time,threshold' or case=='timestamp-throws' and 'time' or 'time,compare'
  assert(table.concat(trace,',')==expected,'expression order changed in '..case)
 end
end)
test('direct callbacks add no clock policy or cache query and still observe live history after failures',function()
 for _,project in ipairs({1,2,5,11,14,18,19,999}) do local f,a=fixture(project);local evaluate=a.conditionDefinitions.COMBAT_HISTORY_TIME.evaluate
  f.env.GetTime=function() error('new clock query') end;a.Platform.GetClientInfo=function() error('new policy query') end
  local retained={};local cache=setmetatable({retained=retained},{__index=function() error('cache read') end,__newindex=function() error('cache write') end})
  a.combatHistory.target[1].time=0/0;local r,why=evaluate(node(),cache,100);assert(r==nil and type(why)=='string');a.combatHistory.target[1].time=90;assert(evaluate(node(),cache,100)==true);a.combatHistory.target[1].time=110;assert(evaluate(node(),cache,100)==false);assert(cache.retained==retained)
 end
 local _,a,s,append=fixture();a.combatHistory={};s.now=90;append(a,'UNIT_COMBAT','target','WOUND',nil,10,1);assert(s.clockCalls==1);s.now=100;known(a,node(),true)
 local before=s.clockCalls;assert(a:evaluateConditionResult(node()).status=='match' and s.clockCalls==before+1)
end)
test('current generated copy repairs observations and retains complete unrelated export metadata',function()
 local _,a=fixture();local source=assert(a:GetBuiltinConditionSource('COMBAT_HISTORY_TIME'));assert(source.evaluate==newBody,'COMBAT_HISTORY_TIME catalog pending');local before=a:CopySettingsData(source)
 a:RegisterCondition('COPY_HISTORY_TIME',assert(a:CompileCustomCondition('COPY_HISTORY_TIME',source)));a.combatHistory.target[1].time=0/0;unknown(a,node(nil,nil,'COPY_HISTORY_TIME'));a.combatHistory.target[1].time=90;known(a,node(nil,nil,'COPY_HISTORY_TIME'),true)
 local restored=a:CopySettingsData(source);restored.evaluate=inverse(restored.evaluate,true);assert(a:FunctionSourceHash(restored)=='ee45fbef','unrelated export metadata/parameters/bindings changed');assert(a:SettingsDataEqual(source,before),'editable source rewritten')
end)
test('archived raw saved callback keeps original arithmetic and stored source unchanged',function()
 local _,a,s=fixture();local raw=assert(a:GetBuiltinConditionSource('COMBAT_HISTORY_TIME'));raw.evaluate=oldBody;assert(a:FunctionSourceHash(raw)=='ee45fbef','raw complete source changed');local stored=a:CopySettingsData(raw);a.db.global.custom_conditions={RAW_HISTORY=raw};a:RegisterCondition('RAW_HISTORY_TIME',assert(a:CompileCustomCondition('RAW_HISTORY_TIME',raw)))
 a.combatHistory.target[1].time=0/0;assert(a:evaluateConditionResult(node(nil,nil,'RAW_HISTORY_TIME')).status=='no-match');assert(a:evaluateConditionResult({type='NOT',value=node(nil,nil,'RAW_HISTORY_TIME')}).status=='match')
 a.combatHistory.target[1].time=-1e308;s.now=1e308;known(a,node(nil,nil,'RAW_HISTORY_TIME'),true)
 assert(a:SettingsDataEqual(raw,stored) and a.db.global.custom_conditions.RAW_HISTORY==raw,'saved source rewritten')
end)
test('only the exact callback changes whole combat and preserves private source/getter identities',function()
 local _,a=fixture();a:InitializeFunctionRegistry();local text=read('Conditions/combat.lua');assert(a:FunctionSourceHash(inverse(text))=='250de3b3','combat changed beyond COMBAT_HISTORY_TIME from0db0ca6')
 assert(inverse(newBody,true)==oldBody and not pcall(inverse,oldBody,true) and not pcall(inverse,newBody..' ',true) and not pcall(inverse,text..text))
 for name,hash in pairs({character_class='d17cf4c1',color='dbda383d',helpers='9e28e933'}) do local id='builtin:Conditions/combat.lua:'..name;assert(a:FunctionSourceHash(assert(a.builtinFunctions[id]).source)==hash and rawequal(a:ResolveFunctionBinding(id),a.builtinSourceModules['Conditions/combat.lua'](name)),'private identity changed '..name) end
end)
test('ordinary history lookup count and action severity short circuits remain unchanged',function()
 local _,a=fixture();local evaluate=a.conditionDefinitions.COMBAT_HISTORY_TIME.evaluate;local rows={{time=90,action='WOUND'}};local reads=0
 a.combatHistory=setmetatable({},{__index=function(_,key) assert(key=='target');reads=reads+1;return rows end});assert(evaluate(node(),{},100)==true and reads==2)
 reads=0;a.combatHistory=setmetatable({},{__index=function() reads=reads+1;return nil end});assert(evaluate(node(),nil,nil)==false and reads==1)
 a.combatHistory={target={setmetatable({time=90},{__index=function(_,key) if key=='action' then error('comparison false consumed action') end end})}};assert(evaluate(node('LESSTHAN',0),{},100)==false)
 a.combatHistory.target={setmetatable({time=90,action='WOUND'},{__index=function(_,key) if key=='severity' then error('plain action consumed severity') end end})};assert(evaluate(node(),{},100)==true)
end)
test('unreadable and malformed visited rows return availability before arithmetic',function()
 for _,bad in ipairs({false,1,'entry'}) do local _,a=fixture();a.combatHistory.target={bad};unknown(a,node()) end
 local f,a=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;a.combatHistory.target={opaque};unknown(a,node())
end)
finish()
