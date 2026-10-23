-- Client-data identities: CreatureType DB2, build2.5.4.44833, enUS/frFR/deDE/koKR.
-- Frozen primary/API and extraction provenance: external creaturetype-clientdata-provenance.json.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local identities={
 {"BEAST",1,"Beast","Bête","Wildtier","야수"},
 {"DRAGONKIN",2,"Dragonkin","Draconien","Drachkin","용족"},
 {"DEMON",3,"Demon","Démon","Dämon","악마"},
 {"ELEMENTAL",4,"Elemental","Elémentaire","Elementar","정령"},
 {"GIANT",5,"Giant","Géant","Riese","거인"},
 {"UNDEAD",6,"Undead","Mort-vivant","Untoter","언데드"},
 {"HUMANOID",7,"Humanoid","Humanoïde","Humanoid","인간형"},
 {"CRITTER",8,"Critter","Bestiole","Tier","동물"},
 {"MECHANICAL",9,"Mechanical","Mécanique","Mechanisch","기계"},
 {"OTHER",10,"Not specified","Non spécifié","Nicht spezifiziert","기타"},
 {"TOTEM",11,"Totem","Totem","Totem","토템"},
 {"NONCOMBAT_PET",12,"Non-combat Pet","Familier pacifique","Haustier","애완동물"},
 {"GAS_CLUUD",13,"Gas Cloud","Nuage de gaz","Gaswolke","가스"},
}
local function read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local function fixture(project)
 local f=F.new(project);local a,e=f.addon,f.env;local s={exists=true,id=1,name='Bête',calls={}}
 e.UnitExists=function(...)assert(select('#',...)==1);s.calls[#s.calls+1]={'exists',...};if s.throw=='exists'then error('existence failure')end;return s.exists end
 e.UnitCreatureType=function(...)assert(select('#',...)==1);s.calls[#s.calls+1]={'creature',...};if s.throw=='creature'then error('metadata failure')end;return s.name,s.id end
 for _,entry in ipairs({{'GetUnitCreatureTypeID','Platform/creature_type.lua',a.Platform},{'GetConditionCreatureTypeMatch','Core/creature_conditions.lua',a}})do
  if not entry[3][entry[1]]then local file=io.open(entry[2]);if file then file:close();f.load(entry[2])end end
 end
 for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/character.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'})do f.load(path)end
 e.loadstring=function(code,name)local fn,why=loadstring(code,name);if fn then setfenv(fn,e)end;return fn,why end
 s.calls={};return f,a,s
end
local function node(key,tag,unit)return{type=tag or'CREATURE',unit=unit or'target',value=key or'BEAST'}end
local function unavailable(a,v)
 assert(a.conditionDefinitions[v.type].valid(0,v),'invalid unavailable fixture')
 for _,value in ipairs({v,{type='NOT',value=v},{type='AND',value={v}},{type='OR',value={{type='NOT',value=v}}}})do local result=a:evaluateConditionResult(value);assert(result.status=='unavailable'and result.reason~='invalid-condition-fields','unknown creature fact became actionable')end
 local picked;local body={rotation={{id='guard',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
 local result=a:EvaluateRotationSequence(body,function(value)return a:evaluateConditionResult(value)end,function(value)picked=value.id;return true end);assert(not picked and result.status=='unavailable')
end
local function result(a,v,matched)
 assert(a.conditionDefinitions[v.type].valid(0,v),'invalid known fixture')
 assert(a:evaluateConditionResult(v).status==(matched and'match'or'no-match'),'wrong positive identity')
 assert(a:evaluateConditionResult({type='NOT',value=v}).status==(matched and'no-match'or'match'),'wrong negation')
 assert(a:evaluateConditionResult({type='AND',value={v}}).status==(matched and'match'or'no-match'))
 local picked;local body={rotation={{id='guard',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
 a:EvaluateRotationSequence(body,function(value)return a:evaluateConditionResult(value)end,function(value)picked=value.id;return true end);assert(picked==(matched and'yes'or'no'))
end
test('all13 creature concepts match real localized native IDs without changing captions',function()
 for _,project in ipairs({2,5,11,14,19})do local _,a,s=fixture(project);local captions=a:CopySettingsData(a.creatures)
  for _,row in ipairs(identities)do for locale=3,6 do s.id=row[2];s.name=row[locale];result(a,node(row[1]),true)end end
  assert(a:SettingsDataEqual(captions,a.creatures),'gameplay identity changed UI captions')
 end
end)
test('known different finite IDs absence and opaque unused names preserve exact matching semantics',function()
 local f,a,s=fixture();for _,id in ipairs({0,-1,.5,1.25,14,999999,1e308,-1e308})do s.id=id;result(a,node(),false)end
 local opaque={};f.env.issecretvalue=function(v)return rawequal(v,opaque)end;s.id=1;s.name=opaque;result(a,node(),true);s.name=nil;result(a,node(),true)
 s.exists=false;f.env.UnitCreatureType=nil;result(a,node(),false)
end)
test('required unknown ID and presence facts never authorize NOT groups or either branch',function()
 local f,a,s=fixture();for _,id in ipairs({false,'1',{},math.huge,-math.huge,0/0})do s.id=id;unavailable(a,node())end
 s.id=nil;unavailable(a,node());s.id=1;s.exists=nil;unavailable(a,node());s.exists=1;unavailable(a,node());s.exists=true
 local opaque={};f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end;s.id=opaque;unavailable(a,node());s.id=1
 s.throw='creature';unavailable(a,node());s.throw='exists';unavailable(a,node());s.throw=nil;result(a,node(),true)
 f.env.UnitCreatureType=nil;unavailable(a,node())
end)
test('service cache shares unit snapshots across selections and keeps absence nil reasons and new-pass recovery',function()
 local f,a,s=fixture();local longterm=a.longtermCache;local before=a:CopySettingsData(longterm);local cache={};assert(a:GetConditionCreatureTypeMatch('target','BEAST',cache)==true and #s.calls==2)
 s.id=2;assert(a:GetConditionCreatureTypeMatch('target','DRAGONKIN',cache)==false and #s.calls==2)
 assert(a:GetConditionCreatureTypeMatch('target','DRAGONKIN',{})==true and #s.calls==4)
 s.exists=false;cache={};assert(a:GetConditionCreatureTypeMatch('target','BEAST',cache)==false);local count=#s.calls;s.exists=true;assert(a:GetConditionCreatureTypeMatch('target','BEAST',cache)==false and #s.calls==count)
 s.id=nil;cache={};local v,why=a:GetConditionCreatureTypeMatch('target','BEAST',cache);assert(v==nil and type(why)=='string');count=#s.calls;s.id=1;local nextv,nextwhy=a:GetConditionCreatureTypeMatch('target','BEAST',cache);assert(nextv==nil and nextwhy==why and #s.calls==count)
 assert(a:GetConditionCreatureTypeMatch('target','BEAST',{})==true);count=#s.calls;a:GetConditionCreatureTypeMatch('target','BEAST');a:GetConditionCreatureTypeMatch('target','BEAST');assert(#s.calls==count+4 and a.longtermCache==longterm and a:SettingsDataEqual(before,longterm))
 local opaque={};f.env.issecretvalue=function(v)return rawequal(v,opaque)end;count=#s.calls
 for _,key in ipairs({'GAS_CLOUD','future',false,{},opaque})do assert(a:GetConditionCreatureTypeMatch('target',key,{})==nil)end
 assert(a:GetConditionCreatureTypeMatch(opaque,'BEAST',{})==nil and #s.calls==count)
end)
test('actual observer method receiver and unit identity partition cached observations',function()
 local _,a,s=fixture();local cache={};assert(a:GetConditionCreatureTypeMatch('target','BEAST',cache));s.id=2;assert(a:GetConditionCreatureTypeMatch('pet','DRAGONKIN',cache))
 local original=a.Platform;local replacement={};for key,value in pairs(original)do replacement[key]=value end;a.Platform=replacement;s.id=1;assert(a:GetConditionCreatureTypeMatch('pet','BEAST',cache))
 local method=replacement.GetUnitCreatureTypeID;local calls=0;replacement.GetUnitCreatureTypeID=function(self,unit,...)assert(self==replacement and unit=='pet'and select('#',...)==0);calls=calls+1;return 2 end
 assert(a:GetConditionCreatureTypeMatch('pet','DRAGONKIN',cache)==true and calls==1);replacement.GetUnitCreatureTypeID=method
 assert(a:GetConditionCreatureTypeMatch('pet','BEAST',cache)==true)
end)
test('probe policy and readonly string observer remain distinct from new numeric identity',function()
 for _,project in ipairs({999})do local _,a,s=fixture(project);unavailable(a,node());assert(#s.calls==0)end
 local _,a,s=fixture();assert(a.Platform:GetUnitMetadataObservation('target','creature')=='Bête');assert(a:GetConditionCreatureTypeMatch('target','BEAST',{})==true)
 s.name='Wildtier';assert(a.Platform:GetUnitMetadataObservation('target','creature')=='Wildtier');assert(a:GetConditionCreatureTypeMatch('target','BEAST',{})==true)
end)
test('strict one-body inverse preserves whole Character bytes and four actual private bindings',function()
 local restore=dofile('tests/fixtures/restore_creature_type_repairs.lua');local _,a=fixture();local current=read('Conditions/character.lua');local old=restore(current)
 assert(#old==36302 and a:FunctionSourceHash(old)=='abc41747');assert(not pcall(restore,current..'\n')and not pcall(restore,old))
 for name,hash in pairs({character_class='f9f4e4b5',color='3f9fe631',helpers='2e9a81e7',unit_class_num='33645816'})do local id='builtin:Conditions/character.lua:'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/character.lua'](name))end
end)
test('generated current and archived complete sources keep distinct identity behavior and exact raw export',function()
 local restore,oldBody,newBody,oldBindings,oldParameters=dofile('tests/fixtures/restore_creature_type_repairs.lua');local _,a,s=fixture();local current=assert(a:GetBuiltinConditionSource('CREATURE'))
 assert(current.evaluate==newBody,'catalog pending new CREATURE identity evaluator')
 a:RegisterCondition('COPY_CREATURE',assert(a:CompileCustomCondition('COPY_CREATURE',a:CopySettingsData(current))));result(a,node('BEAST','COPY_CREATURE'),true)
 local archived=a:CopySettingsData(current);archived.evaluate=restore(archived.evaluate,true);archived.bindings=a:CopySettingsData(oldBindings);archived.parameters.evaluate=a:CopySettingsData(oldParameters)
 assert(archived.evaluate==oldBody and a:FunctionSourceHash(archived)=='eb1ca8a7','complete archived CREATURE export changed')
 a:RegisterCondition('SAVED_RAW_CREATURE',assert(a:CompileCustomCondition('SAVED_RAW_CREATURE',archived)));result(a,node('BEAST','SAVED_RAW_CREATURE'),false)
 s.name='Beast';result(a,node('BEAST','SAVED_RAW_CREATURE'),true);s.name='Bête';s.id=nil;unavailable(a,node('BEAST','COPY_CREATURE'))
end)
test('actual public source clones resolve new mapper ownership and retain live numeric readiness',function()
 local f,a,s=fixture();local ids={observer='builtin:Platform/creature_type.lua:Platform_GetUnitCreatureTypeID',match='builtin:Core/creature_conditions.lua:GetConditionCreatureTypeMatch'}
 local observe=assert(a.builtinFunctions[ids.observer],'catalog pending public numeric observer');local matching=assert(a.builtinFunctions[ids.match],'catalog pending public creature matcher')
 assert(a:ResolveFunctionBinding(ids.observer)==a.Platform.GetUnitCreatureTypeID and observe.source.args[1].type=='RMPlatform')
 assert(matching.source.bindings.configuredID=='builtin:Core/creature_conditions.lua:configuredID'and matching.source.args[1].type=='RMAddon'and matching.source.args[3].name=='key')
 local getter=assert(a.builtinSourceModules['Core/creature_conditions.lua']);local mapping=assert(a:ResolveFunctionBinding(matching.source.bindings.configuredID));assert(mapping==getter('configuredID'))
 for _,row in ipairs(identities)do assert(mapping(row[1])==row[2])end;assert(mapping('GAS_CLOUD')==nil)
 assert(a:InstallCustomFunction('COPY_CREATURE_ID',a:CopySettingsData(observe.source)));local observer=a:ResolveFunctionBinding('COPY_CREATURE_ID')
 assert(a:InstallCustomFunction('COPY_CREATURE_MATCH',a:CopySettingsData(matching.source)));local match=a:ResolveFunctionBinding('COPY_CREATURE_MATCH')
 assert(observer(a.Platform,'target')==1 and match(a,'target','BEAST',{})==true)
 local opaque={};f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end;s.id=opaque;local v,why=observer(a.Platform,'target');assert(v==nil and why=='restricted-value');v,why=match(a,'target','BEAST',{});assert(v==nil and why=='restricted-value')
 s.id=1;assert(match(a,'target','BEAST',{})==true)
end)
finish()
