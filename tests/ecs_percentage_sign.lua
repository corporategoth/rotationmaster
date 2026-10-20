local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local inverse,old,repaired=dofile('tests/fixtures/restore_ecs_percentage_sign.lua')
local function read(path) local file=assert(io.open(path));local text=file:read('*a');file:close();return text end
local function fixture(output)
 local f=F.new();local a,e=f.addon,f.env;a.delayed_condition={};local s={output=output or '-50%',calls=0,imports=0}
 -- ECS5.5.2/c48ccf8 Data.GetStatInfo('SpellHasteBonus') dispatches its
 -- SpellDamage provider, whose Constants table applies debuffs1714=-50,
 --11719=-60. Unchanged installed/upstream provider execution independently
 -- proves -50%, -60%, and -0.25%; no local install/network is needed here.
 local data={GetStatInfo=function(...)
  assert(select('#',...)==1 and select(1,...)=='SpellHasteBonus','provider dot API or refName changed');s.calls=s.calls+1;return s.output
 end}
 e.ECSLoader={ImportModule=function(self,name) assert(self==e.ECSLoader and name=='Data');s.imports=s.imports+1;return data end}
 e.ExtendedCharacterStats={profile={refName='RootHeader',text='Stats',spell={refName='SpellHeader',text='Spell',hasteBonus={refName='SpellHasteBonus',text='Haste Bonus'}}}}
 for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/common.lua','Conditions/ext_stats.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
 for tag,definition in pairs(a.delayed_condition.ExtendedCharacterStats) do a:RegisterCondition(tag,definition) end
 e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
 s.calls=0;return f,a,s
end
local function node(tag,operator,threshold) return {type=tag or 'ECS_STAT_PCT',stat='SpellHasteBonus',operator=operator or 'LESSTHAN',value=threshold or 0} end
local function assertKnown(a,v,want)
 assert(a.conditionDefinitions[v.type].valid(0,v),'ECS percentage fixture invalid')
 assert(a:evaluateConditionResult(v).status==(want and 'match' or 'no-match'),'signed provider percentage miscompared')
 assert(a:evaluateConditionResult({type='NOT',value=v}).status==(want and 'no-match' or 'match'))
 for _,kind in ipairs({'AND','OR'}) do assert(a:evaluateConditionResult({type=kind,value={v}}).status==(want and 'match' or 'no-match')) end
 local selected;local body={rotation={{id='guard',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
 local result=a:EvaluateRotationSequence(body,function(n) return a:evaluateConditionResult(n) end,function(n) selected=n.id;return true end)
 assert(result.status=='complete' and selected==(want and 'yes' or 'no'),'signed percentage selected wrong branch')
end

test('real provider signed integer and fractional percentages remain usable through NOT groups and branches',function()
 for _,output in ipairs({'-50%','-60%','-0.25%'}) do local _,a=fixture(output);assertKnown(a,node(),true) end
end)
test('signed percentages preserve all existing operators and fractional threshold scale',function()
 local _,a=fixture('-50%');local definition=a.conditionDefinitions.ECS_STAT_PCT
 for _,case in ipairs({{'LESSTHAN',.25,true},{'LESSTHANOREQUALS',.25,true},{'GREATERTHAN',.25,false},{'GREATERTHANOREQUALS',.25,false},{'EQUALS',.25,false},{'NOTEQUALS',.25,true},{'DIVISIBLE',.25,true},{'DIVISIBLE',.3,false}}) do
  local v=node(nil,case[1],case[2]);assert(definition.valid(0,v));assert(definition.evaluate(v,{})==case[3],case[1])
 end
end)
test('zero positive fractions and historical numeric prefix suffix acceptance are unchanged',function()
 for _,case in ipairs({{'0%',false},{'25.5%',false},{'25.5% extra',false},{'25.5rest',false},{'25.',false},{'-0.25% extra',true},{'-0.25rest',true},{'-25.',true}}) do local _,a=fixture(case[1]);assertKnown(a,node(),case[2]) end
end)
test('same pass retains exact provider query identity and a fresh pass recovers changed signed values',function()
 local _,a,s=fixture('-0.25%');local v=node();local definition=a.conditionDefinitions.ECS_STAT_PCT;local cache={}
 assert(definition.evaluate(v,cache)==true and definition.evaluate(v,cache)==true and s.calls==1 and s.imports==1)
 s.output='25.5%';assert(definition.evaluate(v,cache)==true and s.calls==1);assert(definition.evaluate(v,{})==false and s.calls==2)
 s.output='-60%';assert(definition.evaluate(v,{})==true and s.calls==3)
end)
test('percentage schema summaries and nonnegative configured threshold remain unchanged',function()
 local _,a,s=fixture();local definition=a.conditionDefinitions.ECS_STAT_PCT;local v=node();assert(definition.valid(0,v));v.value=-.25;assert(not definition.valid(0,v));v.value=0
 assert(definition.fields.stat=='string' and definition.fields.operator=='string' and definition.fields.value=='number')
 local before=a:CopySettingsData(v);local summary=a:printCondition(v,0);assert(summary:find('Haste Bonus',1,true) and summary:find('0%',1,true) and s.calls==0 and a:SettingsDataEqual(before,v))
end)
test('previous plus and whitespace parsing are not silently broadened',function()
 for _,output in ipairs({'+25%',' -25%','word25%'}) do local _,a=fixture(output);local definition=a.conditionDefinitions.ECS_STAT_PCT
  assert(not pcall(definition.evaluate,node(),{}),'unrelated parsing acceptance broadened')
 end
end)
test('one exact evaluator inverse preserves complete source and all private bindings',function()
 local _,a=fixture();assert(a:FunctionSourceHash(inverse(read('Conditions/ext_stats.lua')))=='4992ce44','unrelated ECS source changed')
 assert(inverse(repaired,true)==old and not pcall(inverse,old,true) and not pcall(inverse,repaired..' ',true) and not pcall(inverse,read('Conditions/ext_stats.lua')..read('Conditions/ext_stats.lua')))
 local source=assert(a:GetBuiltinConditionSource('ECS_STAT_PCT'));if source.evaluate==repaired then source.evaluate=inverse(source.evaluate,true) else assert(source.evaluate==old) end
 assert(a:FunctionSourceHash(source)=='cded9a5d','ECS export metadata parameters or bindings changed')
 for name,hash in pairs({color='bcd5d295',ecs_state='f87297b5',helpers='8c6f9acb'}) do local id='builtin:Conditions/ext_stats.lua:'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and rawequal(a:ResolveFunctionBinding(id),a.builtinSourceModules['Conditions/ext_stats.lua'](name))) end
end)
test('archived raw source retains unsigned parsing without rewriting its stored source',function()
 local _,a=fixture();local source=a:GetBuiltinConditionSource('ECS_STAT_PCT');source.evaluate=old;assert(a:FunctionSourceHash(source)=='cded9a5d');local before=a:CopySettingsData(source);a.db.global.custom_conditions={RAW_ECS=source}
 local raw=assert(a:CompileCustomCondition('RAW_ECS',source));a:RegisterCondition('RAW_ECS',raw);local v=node('RAW_ECS');assert(raw.valid(0,v) and not pcall(raw.evaluate,v,{}));assert(a:evaluateConditionResult(v).status=='unavailable')
 assert(a:SettingsDataEqual(before,source) and a.db.global.custom_conditions.RAW_ECS==source)
end)
test('actual current editable copy shares signed observation cache and preserves the complete source export',function()
 local _,a,s=fixture('-0.25%');local source=a:GetBuiltinConditionSource('ECS_STAT_PCT');assert(source.evaluate==repaired,'ECS percentage catalog pending');local before=a:CopySettingsData(source)
 local copy=assert(a:CompileCustomCondition('COPY_ECS',source));a:RegisterCondition('COPY_ECS',copy);local v=node('COPY_ECS');assertKnown(a,v,true)
 s.calls=0;local cache={};assert(copy.evaluate(v,cache)==true and a.conditionDefinitions.ECS_STAT_PCT.evaluate(node(),cache)==true and s.calls==1)
 assert(a:SettingsDataEqual(before,source))
end)
finish()
