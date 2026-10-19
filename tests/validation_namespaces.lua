local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local restore=dofile('tests/fixtures/restore_validation_qualifiers.lua')
local sites={};local uuid='61b36ed1-fa31-4656-ad71-f3d50f193a85'
local function pack(...) return {n=select('#',...),...} end
-- Poison only validation callers: source-bound legacy consumers elsewhere keep
-- their real behavior. Canonical spies delegate to actual collection functions.
local function instrument(f)
 local a=f.addon
 for _,name in ipairs({'cleanArray','tablelength','deepcopy'}) do
  local old,leaf=a[name],a.Functions.collections[name]
  a[name]=function(...)
   local info=debug.getinfo(2,'S');assert(not info or info.source~='@validate.lua','LEGACY_VALIDATION_ALIAS_'..name)
   return old(...)
  end
  a.Functions.collections[name]=function(...)
   local info=debug.getinfo(2,'Sl');if info and info.source=='@validate.lua' then sites[info.currentline]=name end
   return leaf(...)
  end
 end
 return f
end
local function fixture()
 local f=instrument(F.new());local a=f.addon
 for _,path in ipairs({'Core/custom_authoring.lua','Core/custom_condition_services.lua','Core/schema_authoring.lua','Core/conditions.lua','Core/condition_catalog.lua','UI/condition_entrypoints.lua','validate.lua'}) do f.load(path) end
 local warnings={};a.warn=function(_,message,...) warnings[#warnings+1]=string.format(message,...) end
 return f,a,warnings
end
local function actualSuite(path,want)
 local wrapped={};for k,v in pairs(F) do wrapped[k]=v end
 wrapped.new=function(...) return instrument(F.new(...)) end
 local count=0;wrapped.suite=function() return function(name,body) local ok,why=pcall(body);assert(ok,path..': '..name..': '..tostring(why));count=count+1 end,function() end end
 local env=setmetatable({dofile=function(file) if file=='tests/fixtures/addon.lua' then return wrapped end;return dofile(file) end},{__index=_G})
 local chunk=assert(loadfile(path));setfenv(chunk,env);chunk();assert(count==want,'actual fixture suite did not finish')
end
test('actual schema repair preserves semantic metadata with validation aliases poisoned',function() actualSuite('tests/schema_repair.lua',19) end)
test('actual legacy union branch label priority and metadata repairs use canonical leaves',function() actualSuite('tests/legacy_regressions.lua',12) end)
test('invalid early exits clear original records and retain their metatable',function()
 local _,a=fixture();local mt={};local v=setmetatable({name='Keep table identity',items={1}},mt);a:validate_itemset('fixture','bad',v,true);assert(next(v)==nil and getmetatable(v)==mt)
 for _,entry in ipairs({{'bad',{type='texture',texture='x'}},{uuid,{name='Missing type'}}}) do local v=entry[2];a:validate_effect('fixture',entry[1],v,true);assert(next(v)==nil) end
 for _,v in ipairs({{id=uuid},{id=uuid,type='unknown'},{type='spell',spell=1}}) do a:validate_announce('fixture',1,v,true);assert(next(v)==nil) end
 for _,entry in ipairs({{'bad',{name='bad',rotation={}}},{uuid,{rotation={}}}}) do local v=entry[2];a:validate_rotation('fixture',entry[1],v,true);assert(next(v)==nil) end
 local cond={unexpected=true};local body={name='Valid',rotation={},cooldowns={},switch=cond};a:validate_rotation('fixture',uuid,body,true);assert(body.switch==cond and next(cond)==nil)
end)
test('full saved-variable repair removes empty roots in place without leaking shallow template expansion',function()
 local f,a=fixture();local mt={};local nested={sentinel=true};local globalTemplate=setmetatable({custom_conditions={},custom_functions={},function_import_origins={},nested=nested},mt)
 local template={global=globalTemplate,char={bindings={}},profile={itemsets={},announces={},rotations={},condition_groups={},minimap={hide=false}}}
 local items={bad={items={1}}};local effects={bad={type='texture',texture='x'}};local pitems={bad={items={2}}};local announces={{}};local rotations={[0]={bad={name='bad',rotation={}}}};local groups={{extra=1}};local minimap={hide=false,minimapPos=12}
 local db={global={itemsets=items,effects=effects,custom_conditions={},nested=nested},char={Player={bindings={}}},profiles={Fixture={itemsets=pitems,announces=announces,rotations=rotations,condition_groups=groups,minimap=minimap}}};a.savedVariableName='NamespaceProbeDB';f.env.NamespaceProbeDB=db
 local snapshot=a:CopySettingsData(db);a:validate(template,false);assert(a:SettingsDataEqual(db,snapshot),'read-only validation changed data')
 a:validate(template,true);assert(next(items)==nil and next(effects)==nil and next(pitems)==nil and next(announces)==nil and next(rotations[0])==nil and next(groups)==nil)
 assert(db.global.itemsets==items and db.profiles.Fixture.itemsets==pitems and db.profiles.Fixture.announces==announces and db.profiles.Fixture.rotations==rotations and db.profiles.Fixture.condition_groups==groups,'repair replaced a persisted collection')
 assert(db.profiles.Fixture.minimap==minimap and minimap.minimapPos==12 and db.global.nested==nested and template.global.nested==nested and getmetatable(template.global)==mt)
 assert(template.profile.minimap.minimapPos==nil,'optional template expansion escaped private shallow copy')
end)
test('real condition schema copies stay shallow and preserve select argument tuple and live replacements',function()
 local _,a=fixture();local nested={x='number'};local schema=setmetatable({group=nested,removed='number'},{});local except={'removed'};local invert=false
 local describe=a.describeCondition
 function a:describeCondition(tag) if tag=='NAMESPACE_SCHEMA' then return nil,nil,nil,schema,except,invert end;return describe(self,tag) end
 local leaf=a.Functions.collections.deepcopy;local observed=0
 a.Functions.collections.deepcopy=function(...)
  local args=pack(...);local input=args[1];local result=leaf(...)
  if input==schema then
   observed=observed+1;assert(args.n==3 and args[2]==except and args[3]==invert,'select expansion/identity changed')
   assert(result~=schema and getmetatable(result)==nil and result.removed==nil,'copy changed shallow/filter semantics')
   assert(except==nil and invert and result.group==nil or except~=nil and result.group==nested,'copy changed nested identity/filtering')
  end
  return result
 end
 local group={x=1};local condition={type='NAMESPACE_SCHEMA',group=group,removed=7};local body={name='Valid',rotation={},cooldowns={},switch=condition}
 assert(pack(a:validate_rotation('fixture',uuid,body,true)).n==0);assert(observed==1 and condition.group==group and condition.removed==nil and schema.group==nested and schema.type==nil)
 except={'group'};invert=true;condition.group={x=2};condition.removed=9;a:validate_rotation('fixture',uuid,body,true);assert(observed==2 and condition.group.x==2 and condition.removed==nil,'live schema options were captured')
 except=nil;invert=true;condition.group={x=3};a:validate_rotation('fixture',uuid,body,true);assert(observed==3 and condition.group==nil,'explicit nil except slot was lost')
 local calls,missing=0,0;a.Functions.collections.deepcopy=function(...)
  local args=pack(...);if args[1]==schema then calls=calls+1;assert(args.n==3 and args[2]==nil and args[3]==true,'live replacement lost nil tuple slot')
  elseif args[1]==nil then missing=missing+1;assert(args.n==0,'unknown description gained arguments') end
  return leaf(...)
 end
 condition.group={x=4};a:validate_rotation('fixture',uuid,body,true);assert(calls==1 and condition.group==nil,'canonical replacement was captured')
 body.switch={type='MISSING_CONDITION',future={value=true}};a:validate_rotation('fixture',uuid,body,true);assert(body.switch.future.value and missing==1,'nil schema no longer passes through')
end)
test('canonical cleanup count and copy failures retain warning mutation and return order',function()
 for _,name in ipairs({'cleanArray','tablelength','deepcopy'}) do
  local _,a,warnings=fixture();local marker={};local condition={type='UNKNOWN'};local body={name='Valid',rotation={},cooldowns={},switch=condition,extra=true}
  local leaf=a.Functions.collections[name];local calls=0
  a.Functions.collections[name]=function(...)
   local input=(...)
   if name~='tablelength' or input==condition then calls=calls+1;error(marker) end
   return leaf(...)
  end
  local id=name=='cleanArray' and 'bad' or uuid
  local ok,why=pcall(a.validate_rotation,a,'fixture',id,body,true);assert(not ok and why==marker and calls==1,'canonical error was swallowed/replaced')
  assert(#warnings==1 and body.switch==condition and condition.type=='UNKNOWN','warning or prior source mutations changed')
  if name=='cleanArray' then assert(body.extra==true and warnings[1]:find('Invalid ID',1,true),'cleanup error moved after mutation')
  else assert(body.extra==nil and warnings[1]:find('Extra Field',1,true),'copy/count error moved before shape repair') end
 end
end)
test('strict inverse restores full7111658 source and helper aliases getters catalog stay unchanged',function()
 local f=F.new();local a=f.addon;f.load('Core/function_data.lua');local function hash(text) return a:FunctionSourceHash(text) end
 local h=assert(io.open('validate.lua'));local text=h:read('*a');h:close();local old=restore(text,hash)
 assert(hash(old)=='25c084e8');assert(not pcall(restore,old,hash) and not pcall(restore,text..text,hash),'inverse accepted absent/duplicate qualifications')
 assert(not pcall(restore,text..'\n-- unrelated change\n',hash),'inverse accepted unrelated changes')
 f.load('Data/builtin_sources.lua');f.load('Core/builtin_sources.lua');assert(not a.BuiltinSourceCatalog.modules['validate.lua'])
 for _,name in ipairs({'cleanArray','tablelength','deepcopy'}) do
  local fn=a.Functions.collections[name];assert(a[name]==fn and debug.getinfo(fn,'S').source=='@Functions/collections.lua','helper ownership/alias changed')
  assert(a:ResolveFunctionBinding('builtin:Functions/collections.lua:'..name)==fn and a.builtinSourceModules['Functions/collections.lua'](name)==fn,'public helper getter changed')
 end
end)
test('actual schema legacy and boundary fixtures exercise every one of the30 consumer sites',function()
 local expected={cleanArray={30,72,89,96,211,235,245,320,449,470},tablelength={45,313,389,544,584,609,620,631,714,725,741,761},deepcopy={326,494,512,554,600,640,679,681}}
 local count=0;for name,lines in pairs(expected) do for _,line in ipairs(lines) do assert(sites[line]==name,'unexercised canonical validation site '..line);count=count+1 end end
 assert(count==30)
end)
finish()
