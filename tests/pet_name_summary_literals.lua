local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local key='you {{!have|do not have}} a pet named {name}'
local name='Scout {{!blue|red}} 50% {name}'
local old='\n        return string.format(L["you {{!have|do not have}} a pet named %s"], Functions.presentation.nullable(value.value, L["<name>"]))\n    '
local function fixture()
 local f=F.new();local a,e=f.addon,f.env;local state={exists=true,name=name,calls=0}
 e.UnitExists=function(unit)assert(unit=='pet');state.calls=state.calls+1;return state.exists end
 e.GetUnitName=function(unit)assert(unit=='pet');state.calls=state.calls+1;return state.name end
 for _,path in ipairs({'Platform/pet.lua','Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/combat.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'})do f.load(path)end
 e.loadstring=function(code,label)local fn,why=loadstring(code,label);if fn then setfenv(fn,e)end;return fn,why end
 return f,a,state
end
local function node(tag,value)return{type=tag or 'PET_NAME',value=value}end
local function renders(a,v,positive,negative)
 assert(a:printCondition(v,0)==positive,'positive differs: '..a:printCondition(v,0):sub(1,160))
 assert(a:printCondition({type='NOT',value=v},0)==negative,'negative differs: '..a:printCondition({type='NOT',value=v},0):sub(1,160))
 assert(a:printCondition({type='NOT',value={type='NOT',value=v}},0)==positive)
end
local function archived(a)
 local source=a:GetBuiltinConditionSource('PET_NAME');source.print=old;source.bindings['PetSummary.phrase']=nil
 return source
end
local function register(a,id,source)a:RegisterCondition(id,assert(a:CompileCustomCondition(id,source)))end
test('accepted configured names remain opaque through positive NOT and double NOT summaries',function()
 local _,a=fixture()
 for _,value in ipairs({name,'{{yes|no}} {{!one|two}}','{name} 100% %s','|cff123456{{!Hot|Cold}}|r','|Hspell:1|h[{{!A|B}}]|h','Scout',''})do
  local v=node(nil,value);assert(a:validateCondition(v,0));local before=a:CopySettingsData(v)
  renders(a,v,'you have a pet named '..value,'you do not have a pet named '..value);assert(a:SettingsDataEqual(v,before))
 end
end)
test('named whole translations can put literal names before the actual predicate',function()
 local f,a=fixture();f.translations[key]='Pet {name}: you {{!have|do not have}} it :: 50%'
 renders(a,node(nil,name),'Pet '..name..': you have it :: 50%','Pet '..name..': you do not have it :: 50%')
end)
test('ordinary and nil placeholder wording stays equal to complete archived callbacks',function()
 local _,a=fixture();register(a,'ARCHIVED_PET_NAME',archived(a))
 for _,value in ipairs({'Scout','','Wolf (*)',123})do
  for _,negated in ipairs({false,true})do local v,c=node(nil,value),node('ARCHIVED_PET_NAME',value);if negated then v={type='NOT',value=v};c={type='NOT',value=c}end
   assert(a:printCondition(v,0)==a:printCondition(c,0))
  end
 end
 local placeholder=a.Functions.presentation.nullable(nil,'<name>');renders(a,node(), 'you have a pet named '..placeholder,'you do not have a pet named '..placeholder)
end)
test('current generated editable copies preserve opaque values and selected helper identity',function()
 local f,a=fixture();local source=a:GetBuiltinConditionSource('PET_NAME');local before=a:CopySettingsData(source)
 assert(source.bindings['PetSummary.phrase']=='builtin:Functions/presentation.lua:phrase'and not source.bindings.PetSummary)
 register(a,'COPY_PET_NAME',source);renders(a,node('COPY_PET_NAME',name),'you have a pet named '..name,'you do not have a pet named '..name)
 f.translations[key]='{name} :: {{!present|absent}}';renders(a,node('COPY_PET_NAME',name),name..' :: present',name..' :: absent')
 assert(a:SettingsDataEqual(source,before))
end)
test('raw archived exports preserve byte identity and historical literal parsing',function()
 local f,a=fixture();local source=archived(a);assert(a:FunctionSourceHash(source)=='e882267e');local before=a:CopySettingsData(source)
 a.db.global.custom_conditions={ARCHIVED_PET_NAME=source};register(a,'ARCHIVED_PET_NAME',source)
 f.translations['you {{!have|do not have}} a pet named %s']='Pet %s: you {{!have|do not have}} it'
 renders(a,node('ARCHIVED_PET_NAME',name),'Pet Scout blue 50% {name}: you have it','Pet Scout red 50% {name}: you have it')
 assert(a:SettingsDataEqual(source,before)and a.db.global.custom_conditions.ARCHIVED_PET_NAME==source)
end)
test('summary construction makes no native calls or saved-data writes',function()
 local _,a,s=fixture();local before=a:CopySettingsData(a.db);local v=node(nil,name);local data=a:CopySettingsData(v)
 renders(a,v,'you have a pet named '..name,'you do not have a pet named '..name)
 assert(s.calls==0 and a:SettingsDataEqual(v,data)and a:SettingsDataEqual(a.db,before))
end)
test('native readiness exact name comparison and actual engine branch dispatch stay unchanged',function()
 local _,a,s=fixture();register(a,'COPY_PET_NAME',a:GetBuiltinConditionSource('PET_NAME'))
 for _,tag in ipairs({'PET_NAME','COPY_PET_NAME'})do local v=node(tag,name)
  for _,case in ipairs({{true,name,'match','yes'},{true,'Other','no-match','no'},{false,name,'no-match','no'},{true,false,'unavailable'}})do
   s.exists=case[1];s.name=case[2]or nil;assert(a:evaluateConditionResult(v).status==case[3]);local selected
   local body={rotation={{id='gate',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
   local result=a:EvaluateRotationSequence(body,function(value)return a:evaluateConditionResult(value)end,function(value)selected=value.id;return true end)
   if case[3]=='unavailable'then assert(result.status=='unavailable'and selected==nil and a:evaluateConditionResult({type='NOT',value=v}).status=='unavailable')else assert(selected==case[4])end
  end
 end
end)
test('oversized accepted names retain engine truth and the established bounded summary fallback',function()
 local _,a,s=fixture();local value=string.rep('x',64000);local v=node(nil,value);s.name=value;assert(a:validateCondition(v,0)and a:evaluateConditionResult(v).status=='match')
 renders(a,v,'Condition summary unavailable: invalid template or values.','Condition summary unavailable: invalid template or values.')
end)
finish()
