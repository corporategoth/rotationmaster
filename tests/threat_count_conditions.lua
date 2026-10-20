local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite();local fixture=dofile('tests/fixtures/threat_count.lua')
local function node(op,count,tag) return {type=tag or 'THREAT_COUNT',threat=2,operator=op or 'GREATERTHAN',value=count or 0} end
local function unknown(a,v)
 assert(a.conditionDefinitions[v.type].valid(0,v),'unknown fixture must pass unchanged validator')
 for _,c in ipairs({v,{type='NOT',value=v},{type='AND',value={v}},{type='OR',value={{type='NOT',value=v}}}}) do local r=a:evaluateConditionResult(c);assert(r.status=='unavailable' and r.reason~='invalid-condition-fields','unknown count became '..r.status) end
 local body={rotation={{id='guard',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
 assert(a:EvaluateRotationSequence(body,function(c) return a:evaluateConditionResult(c) end,function() error('unavailable count selected a branch') end).status=='unavailable')
end
local function known(a,v,wanted)
 assert(a.conditionDefinitions[v.type].valid(0,v));assert(a:evaluateConditionResult(v).status==wanted)
 assert(a:evaluateConditionResult({type='NOT',value=v}).status==(wanted=='match' and 'no-match' or 'match'))
 local selected;local body={rotation={{id='guard',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
 local result=a:EvaluateRotationSequence(body,function(c) return a:evaluateConditionResult(c) end,function(action) selected=action.id;return true end)
 assert(result.status=='complete' and selected==(wanted=='match' and 'yes' or 'no'))
end
test('required unknown facts propagate through actual registered logical and branch execution',function()
 for _,key in ipairs({'exists','guid','enemy','threat'}) do for _,mode in ipairs({'nil','opaque','nan','throw','missing'}) do if key~='threat' or mode~='nil' then
  local f,a,s,o,_,update=fixture(true);local row=s.facts.nameplate1
  if mode=='nil' then row[key]=nil elseif mode=='opaque' then row[key]=o elseif mode=='nan' then row[key]=0/0 elseif mode=='throw' then row.throw=key else f.env[({exists='UnitExists',guid='UnitGUID',enemy='UnitIsEnemy',threat='UnitThreatSituation'})[key]]=nil end
  if key=='enemy' or key=='threat' then if mode~='throw' and mode~='missing' then update({},a.unitsInRange['Creature-old']) end end
  unknown(a,node());assert(#a.Diagnostics:GetReports()==0,'availability used an exception diagnostic')
 end end end
end)
test('actual producer stale absence and recycled identity are excluded without changing records',function()
 for _,case in ipairs({'absent','recycled'}) do local _,a,s,_,_,update=fixture(true);local record=a.unitsInRange['Creature-old']
  if case=='absent' then s.facts.nameplate1.exists=false else s.facts.nameplate1.guid='Creature-new' end;update({},record)
  assert(record.enemy and record.threat==3 and a.unitsInRange['Creature-new']==nil);known(a,node(),'no-match');known(a,{type='THREAT_COUNT',operator='EQUALS',value=0,threat=2},'match');assert(a.unitsInRange['Creature-old']==record)
 end
end)
test('known counts preserve operators optional nil and complete empty snapshot controls',function()
 for _,case in ipairs({{'EQUALS',1,true},{'NOTEQUALS',1,false},{'GREATERTHAN',0,true},{'LESSTHAN',2,true},{'GREATERTHANOREQUALS',1,true},{'LESSTHANOREQUALS',1,true},{'DIVISIBLE',1,true},{'DIVISIBLE',2,false}}) do local _,a=fixture(true);local v=node(case[1],case[2]);known(a,v,case[3] and 'match' or 'no-match') end
 for _,key in ipairs({'enemy','threat'}) do local _,a,s,_,_,update=fixture(true);if key=='enemy' then s.facts.nameplate1.enemy=false else s.facts.nameplate1.threat=nil end;update({},a.unitsInRange['Creature-old']);known(a,node(),'no-match') end
 local _,a=fixture(true);a.unitsInRange={};known(a,node('EQUALS',0),'match')
end)
test('current callbacks share only caller supplied observation tuples and recover next pass',function()
 local _,a,s=fixture(true);local evaluate=a.conditionDefinitions.THREAT_COUNT.evaluate;local cache={};s.facts.nameplate1.enemy=nil
 local r,why=evaluate(node(),cache);assert(r==nil and type(why)=='string');local calls=#s.calls;s.facts.nameplate1.enemy=true
 local again,issue=evaluate(node(),cache);assert(again==nil and issue==why and #s.calls==calls);assert(evaluate(node(),{})==true)
 s.calls={};cache={};assert(evaluate(node(),cache)==true and #s.calls==5);local v=node();v.threat=4;assert(evaluate(v,cache)==true and #s.calls==5);a.unitsInRange={};assert(evaluate(v,cache)==false and #s.calls==5)
end)
test('current compiled duplicate uses normalized observations and existing source factories',function()
 local _,a,s=fixture(true);local source=assert(a:GetBuiltinConditionSource('THREAT_COUNT'));local before=a:CopySettingsData(source);assert(source.parameters.evaluate[2]=='cache','catalog is pending current evaluator')
 a:RegisterCondition('COPY_THREAT_COUNT',assert(a:CompileCustomCondition('COPY_THREAT_COUNT',source)));s.facts.nameplate1.enemy=nil;unknown(a,node(nil,nil,'COPY_THREAT_COUNT'));s.facts.nameplate1.enemy=true;known(a,node(nil,nil,'COPY_THREAT_COUNT'),'match');assert(a:SettingsDataEqual(source,before),'editable source was rewritten')
end)
test('saved raw callbacks keep old stored-scalar behavior without rewriting their source',function()
 local _,a,s,_,_,update=fixture(true);local inverse=dofile('tests/fixtures/restore_threat_count_repairs.lua');local h=assert(io.open('Conditions/combat.lua'));local text=h:read('*a');h:close();local _,oldBody,_,bindings,parameters=inverse(text)
 local source=assert(a:GetBuiltinConditionSource('THREAT_COUNT'));source.evaluate=oldBody;source.bindings=a:CopySettingsData(bindings);source.parameters.evaluate=a:CopySettingsData(parameters);local before=a:CopySettingsData(source)
 a:RegisterCondition('RAW_THREAT_COUNT',assert(a:CompileCustomCondition('RAW_THREAT_COUNT',source)))
 s.facts.nameplate1.enemy=nil;update({},a.unitsInRange['Creature-old']);known(a,node(nil,nil,'RAW_THREAT_COUNT'),'no-match');assert(a:evaluateConditionResult({type='NOT',value=node(nil,nil,'RAW_THREAT_COUNT')}).status=='match')
 s.facts.nameplate1.enemy=true;s.facts.nameplate1.threat=3;update({},a.unitsInRange['Creature-old']);s.facts.nameplate1.exists=false;update({},a.unitsInRange['Creature-old']);known(a,node(nil,nil,'RAW_THREAT_COUNT'),'match');assert(a:SettingsDataEqual(source,before),'raw saved source rewritten')
end)
test('new public service clone resolves real observers cache authority and private captures',function()
 local _,a,s=fixture(true);a:InitializeFunctionRegistry();local id='builtin:Core/threat_count_conditions.lua:GetConditionThreatCount';local record=assert(a.builtinFunctions[id],'count helper catalog is pending')
 assert(a:ResolveFunctionBinding(id)==a.GetConditionThreatCount and a.builtinSourceModules['Core/threat_count_conditions.lua']('GetConditionThreatCount')==a.GetConditionThreatCount)
 assert(record.source.args[2].name=='minimum' and record.source.args[3].name=='cache' and #record.source.description>0)
 assert(a:InstallCustomFunction('COPY_THREAT_COUNT_SERVICE',a:CopySettingsData(record.source)));local fn=a:ResolveFunctionBinding('COPY_THREAT_COUNT_SERVICE');local cache={};assert(fn(a,1,cache)==1 and #s.calls==5);assert(fn(a,3,cache)==1 and #s.calls==5)
 s.facts.nameplate1.enemy=nil;local count,why=fn(a,1,{});assert(count==nil and type(why)=='string')
end)
test('one exact evaluator inverse retains whole combat old exports private identities and reused public bodies',function()
 local _,a=fixture(true);a:InitializeFunctionRegistry();local h=assert(io.open('Conditions/combat.lua'));local text=h:read('*a');h:close();local inverse=dofile('tests/fixtures/restore_threat_count_repairs.lua');local restored,oldBody,newBody,bindings,parameters=inverse(text)
 assert(a:FunctionSourceHash(restored)=='6c85f357','combat changed beyond THREAT_COUNT from frozen baseline')
 assert(not pcall(inverse,text..text),'ambiguous callback repair accepted');assert(not pcall(inverse,'changed'..newBody,true),'unexpected callback bytes accepted')
 local source=assert(a:GetBuiltinConditionSource('THREAT_COUNT'));assert(source.evaluate==newBody,'catalog is pending exact evaluator');source.evaluate=oldBody;source.bindings=a:CopySettingsData(bindings);source.parameters.evaluate=a:CopySettingsData(parameters);assert(a:FunctionSourceHash(source)=='7ca1d784','unrelated THREAT_COUNT export metadata changed')
 for name,hash in pairs({color='dbda383d',character_class='d17cf4c1',helpers='9e28e933'}) do local id='builtin:Conditions/combat.lua:'..name;assert(a:FunctionSourceHash(assert(a.builtinFunctions[id]).source)==hash);assert(a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/combat.lua'](name)) end
 for id,hash in pairs({['builtin:Platform/threat.lua:Platform_GetUnitThreatObservation']='3fd0293e',['builtin:Platform/health_forecast.lua:Platform_GetHealthForecastIdentityObservation']='26e0f56a'}) do assert(a:FunctionSourceHash(assert(a.builtinFunctions[id]).source)==hash,'reused public source changed') end
end)
test('malformed snapshots and unsupported empty observations stay unavailable without diagnostics',function()
 for _,bad in ipairs({false,1,'units'}) do local _,a=fixture(true);a.unitsInRange=bad;unknown(a,node());assert(#a.Diagnostics:GetReports()==0) end
 for _,project in ipairs({1,18,999}) do local _,a,s=fixture(true,project);a.unitsInRange={};unknown(a,node('EQUALS',0));assert(#s.calls==0) end
end)
finish()
