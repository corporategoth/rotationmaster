-- Zero means the selected-hand timer estimate elapsed, not that a swing will fire.
-- Default/generated-current requires actual generated source. authored-copy is pre-integration only.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local mode=arg[1]or'generated-current';assert(mode=='authored-copy'or mode=='generated-current','explicit source mode required')
local function read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local oldLine='        return Functions.values.compare(value.operator,speed-math.max(evalStart-lastSwing,0),value.value)'
local newLine='        return Functions.values.compare(value.operator,math.max(speed-math.max(evalStart-lastSwing,0),0),value.value)'
local function replaceOne(text,from,to)local i,j=assert(text:find(from,1,true));assert(not text:find(from,j+1,true));return text:sub(1,i-1)..to..text:sub(j+1)end
local function evaluator()
 local text=read('Conditions/weapon.lua');local first=assert(text:find('addon:RegisterCondition("SWING_TIME_REMAIN", {',1,true));local section=text:sub(first);local signature='    evaluate = function(value, cache, evalStart)';local _,start=assert(section:find(signature,1,true));assert(not section:find(signature,start+1,true));local ending=assert(section:find('    end,\n    print = function',start+1,true));local body=section:sub(start+1,ending+3);assert(body:sub(1,1)=='\n'and body:sub(-5)=='\n    ');return body
end
local authored=evaluator()
-- The producer is the handler up to the registration below it (a comment now sits between them).
local producer;do
 local text=read('main.lua');local from=assert(text:find('local function handle_combat_log(_',1,true));local to=assert(text:find('\naddon.COMBAT_LOG_EVENT_UNFILTERED',from,true))
 producer=assert(text:sub(from,to-1):gsub('\n%-%-[^\n]*',''):match('^(.-\nend)%s*$'))
end
local function fixture()
 local f=F.new();local a,e=f.addon,f.env;local s={now=100,main=2,off=3,calls={}};a.damageHistory={}
 local function hit(name,...)s.calls[#s.calls+1]={name,...}end
 e.GetTime=function(...)assert(select('#',...)==0);hit('clock');return s.now end
 e.UnitAttackSpeed=function(...)assert(select('#',...)==1 and(...)=='player');hit('speed',...);if s.speedThrow then error('native speed failure')end;return s.main,s.off end
 e.UnitCastingInfo=function(...)assert(select('#',...)==1 and(...)=='player');hit('cast',...);return s.cast and'Cast in progress'or nil end
 e.UnitChannelInfo=function(...)assert(select('#',...)==1 and(...)=='player');hit('channel',...);return s.channel and'Channel in progress'or nil end
 e.geterrorhandler=function()return function()end end
 for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/common.lua','Conditions/weapon.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'})do f.load(path)end
 e.loadstring=function(code,name)local fn,why=loadstring(code,name);if fn then setfenv(fn,e)end;return fn,why end
 local catalog=assert(a:GetBuiltinConditionSource('SWING_TIME_REMAIN'));local current=a:CopySettingsData(catalog)
 if mode=='generated-current'then assert(current.evaluate==authored,'generated SWING_TIME_REMAIN catalog does not equal actual authored evaluator')else current.evaluate=authored end
 a:RegisterCondition('CURRENT_COPY',assert(a:CompileCustomCondition('CURRENT_COPY',current)))
 local archive=a:CopySettingsData(catalog);if archive.evaluate:find(newLine,1,true)then archive.evaluate=replaceOne(archive.evaluate,newLine,oldLine)end
 -- The archive is the current catalog source with the formula it had when the copy was saved. It used to be pinned by the hash of the
 -- whole source, which any unrelated edit of the catalog entry (a description, a binding) changed; the formula is what it stands for.
 assert(archive.evaluate:find(oldLine,1,true) and not archive.evaluate:find(newLine,1,true),'archived swing source does not carry the saved formula');a:RegisterCondition('RAW_ARCHIVE',assert(a:CompileCustomCondition('RAW_ARCHIVE',archive)))
 local factory=assert(loadstring('return function(addon,playerGUID) '..producer..';return handle_combat_log end','@actual-combat-log-producer'));setfenv(factory,e);local append=factory()(a,'Player-A')
 return f,a,s,append,catalog,current,archive
end
local function swing(append,event,offhand)
 if event=='SWING_DAMAGE'then append(nil,event,nil,'Player-A',nil,nil,nil,'Creature-A',nil,nil,nil,10,0,1,0,0,0,false,false,false,offhand)
 else append(nil,event,nil,'Player-A',nil,nil,nil,'Creature-A',nil,nil,nil,'DODGE',offhand)end
end
local function node(tag,offhand,operator,value)return{type=tag,offhand=offhand,operator=operator or'EQUALS',value=value or 0}end
local function count(s,name)local n=0;for _,v in ipairs(s.calls)do if v[1]==name then n=n+1 end end;return n end
local tags={'SWING_TIME_REMAIN','CURRENT_COPY'}
local function known(a,v,expected)
 assert(a:validateCondition(v,0));local r=a:evaluateConditionResult(v);local negated=a:evaluateConditionResult({type='NOT',value=v});assert(r.status==(expected and'match'or'no-match'),'wrong countdown comparison');assert(negated.status==(expected and'no-match'or'match'))
 local selected;local branch=a:EvaluateRotationSequence({rotation={{id='guard',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=403}},onFalse={{id='no',type='spell',action=403}}}}},function(n)return a:evaluateConditionResult(n)end,function(n)selected=n.id end);assert(branch.status=='complete'and selected==(expected and'yes'or'no'))
end
test('actual damage and missed swing producers preserve selected hand and finite timestamp',function()
 for _,event in ipairs({'SWING_DAMAGE','SWING_MISSED'})do for _,offhand in ipairs({false,true})do local _,a,s,append=fixture();s.now=100.25;swing(append,event,offhand);assert(a[offhand and'lastOffSwing'or'lastMainSwing']==100.25);assert(a[offhand and'lastMainSwing'or'lastOffSwing']==nil);assert(count(s,'clock')==(event=='SWING_DAMAGE'and 2 or 1))end end
end)
test('zero boundary comparisons stay nonnegative after either hand timer estimate expires',function()
 for _,event in ipairs({'SWING_DAMAGE','SWING_MISSED'})do for _,offhand in ipairs({false,true})do local _,a,s,append=fixture();swing(append,event,offhand);local speed=offhand and 3 or 2
  s.now=100+speed+.25;for _,tag in ipairs(tags)do known(a,node(tag,offhand,'EQUALS',0),true);known(a,node(tag,offhand,'LESSTHAN',0),false);known(a,node(tag,offhand,'GREATERTHANOREQUALS',0),true)end
  assert(a[offhand and'lastOffSwing'or'lastMainSwing']==100,'evaluation advanced recorded timestamp')
 end end
end)
test('all operators and positive thresholds preserve before exact after and negative elapsed countdowns',function()
 for _,event in ipairs({'SWING_DAMAGE','SWING_MISSED'})do for _,offhand in ipairs({false,true})do local _,a,s,append=fixture();swing(append,event,offhand);local speed=offhand and 3 or 2
  for _,age in ipairs({-.25,0,speed-.25,speed,speed+.25,speed+1.25})do s.now=100+age;local remaining=age<0 and speed or age>=speed and 0 or speed-age
   for _,operator in ipairs({'EQUALS','NOTEQUALS','LESSTHAN','LESSTHANOREQUALS','GREATERTHAN','GREATERTHANOREQUALS','DIVISIBLE'})do for _,threshold in ipairs({0,.25,1,2})do if operator~='DIVISIBLE'or threshold~=0 then
    local expected=a.Functions.values.compare(operator,remaining,threshold);for _,tag in ipairs(tags)do known(a,node(tag,offhand,operator,threshold),expected)end
   end end end
  end
 end end
end)
test('no history casting and channeling retain full selected hand speed fallback and laziness',function()
 for _,offhand in ipairs({false,true})do for _,state in ipairs({'no-history','cast','channel'})do local _,a,s=fixture();local speed=offhand and 3 or 2;s.now=110
  if state~='no-history'then a[offhand and'lastOffSwing'or'lastMainSwing']=100;s[state]=true end
  for _,tag in ipairs(tags)do known(a,node(tag,offhand,'EQUALS',speed),true)end
  if state=='no-history'then assert(count(s,'cast')==0 and count(s,'channel')==0)elseif state=='cast'then assert(count(s,'cast')>0 and count(s,'channel')==0)else assert(count(s,'cast')>0 and count(s,'channel')>0)end
 end end
end)
test('direct current callbacks share unchanged native caches receiver arity and never add a clock query',function()
 local _,a,s,append=fixture();swing(append,'SWING_DAMAGE',false);s.now=103;s.calls={};local cache={}
 for _,tag in ipairs(tags)do assert(a.conditionDefinitions[tag].evaluate(node(tag,false,'EQUALS',0),cache,s.now)==true)end
 assert(count(s,'speed')==1 and count(s,'cast')==1 and count(s,'channel')==1 and count(s,'clock')==0)
 for _,call in ipairs(s.calls)do assert(call[2]=='player'and call[3]==nil)end
end)
test('native speed readiness and requested hand failure behavior remain unchanged',function()
 for _,tag in ipairs(tags)do local f,a,s=fixture();s.speedThrow=true;assert(a:evaluateConditionResult({type='NOT',value=node(tag,false)}).status=='unavailable');s.speedThrow=false;s.off=nil;assert(a:evaluateConditionResult({type='NOT',value=node(tag,true)}).status=='match','no off-hand weapon is a reading: the check is false, true under NOT');local opaque={};s.off=opaque;f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end;assert(a:evaluateConditionResult({type='NOT',value=node(tag,true)}).status=='unavailable');assert(#a.Diagnostics:GetReports()==0)end
end)
test('archived raw source retains negative overdue behavior without mutating stored source',function()
 local _,a,s,append,catalog,current,archive=fixture();local before=a:CopySettingsData(archive);swing(append,'SWING_MISSED',false);s.now=102.25;known(a,node('RAW_ARCHIVE',false,'LESSTHAN',0),true);known(a,node('RAW_ARCHIVE',false,'EQUALS',0),false);assert(a:SettingsDataEqual(archive,before));assert(current.evaluate==authored)
 if mode=='generated-current'then assert(catalog.evaluate==authored)else assert(catalog.evaluate==archive.evaluate,'authored-copy requires explicit archived checked-in catalog')end
end)
-- swingSpeed changed on purpose (an absent off-hand weapon reads false, 994be32a); the other helpers are unchanged.
test('native helper and capture source identities remain exact for current and historical copies',function()
 local _,a=fixture();for name,hash in pairs({enchantObservation='5abf63f3',numericObservation='02dee6a9',swingSpeed='5af56bab',color='63742be5',helpers='e831a1db'})do local id='builtin:Conditions/weapon.lua:'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/weapon.lua'](name))end
end)
print('Source mode: '..mode..(mode=='authored-copy'and' (exact authored evaluator over detached archived metadata; checked-in catalog untouched)'or' (checked-in catalog must equal actual authored evaluator)'))
finish()
