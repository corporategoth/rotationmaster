local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local required={'family','class','spec','actionContext','level','build','combatDataPolicy'}
local function same(left,right)
 for _,key in ipairs(required) do local a,b=left[key],right[key];assert(a==b or type(a)=='number' and type(b)=='number' and a~=a and b~=b,'different '..key) end
end
local function fixture(before,beforeBind)
 local f=F.new(5,1,'SHAMAN');local a,e=f.addon,f.env
 local s={class='SHAMAN',level=11,build='20202',vehicle=false,battle=false,calls={}}
 local function hit(name) s.calls[name]=(s.calls[name] or 0)+1 end
 e.UnitClass=function(...) assert(select('#',...)==1 and (...)=='player');hit('class');if s.onClass then s.onClass() end;return 'Ignored',s.class end
 e.UnitLevel=function(...) assert(select('#',...)==1 and (...)=='player');hit('level');if s.onLevel then s.onLevel() end;return s.level end
 e.UnitHasVehicleUI=function(...) assert(select('#',...)==1 and (...)=='player');hit('vehicle');return s.vehicle end
 e.UnitInVehicle=function() hit('vehicleFallback');return s.fallback end
 e.C_PetBattles={IsInBattle=function(...) assert(select('#',...)==0);hit('battle');return s.battle end}
 e.GetBuildInfo=function(...) assert(select('#',...)==0);hit('build');if s.onBuild then s.onBuild() end;return 'Fixture',s.build,'Date',20504 end
 e.GetLocale=function() hit('locale');return 'enUS' end;e.GetClassicExpansionLevel=function() hit('expansion');return 1 end
 e.C_Seasons={GetActiveSeason=function() hit('season');return 3 end}
 e.C_GameRules={GetCurrentGameModeRecordID=function() hit('mode');return 4 end,IsHardcoreActive=function() hit('hardcore');return false end,IsSelfFoundAllowed=function() hit('selfFound');return true end}
 local data,envelope,validation=dofile('tests/fixtures/rotation_data.lua')();a.RotationData=data;a.conditionDefinitions=validation.conditions
 if before then before(a,e,s) end
 for _,path in ipairs({'Data/catalog.lua','Data/diff.lua','Data/rotation_store.lua','Core/rotation_library.lua'}) do f.load(path) end
 if beforeBind then beforeBind(a,e,s) end
 local reader;assert(a:BindRotationLibraryReader(function(value) reader=value end))
 return f,a,s,reader,envelope
end
local function context(reader,spec) assert(type(reader.Context)=='function','private context reader missing');return reader:Context(spec) end
local function reset(s) s.calls={} end
local function metadata(s,n)
 for _,key in ipairs({'locale','expansion','season','mode','hardcore','selfFound'}) do assert((s.calls[key] or 0)==n,'unconsumed native '..key..' count '..tostring(s.calls[key])) end
end
test('actual private library Read List Eligible omit unused native metadata while public context remains complete',function()
 local _,a,s,r,envelope=fixture();local pack=envelope();assert(a:RegisterDefaultRotation(pack) and a:InitializeRotationLibrary());reset(s)
 local view;assert(r:Read(0,pack.id,function(value) view=value;return true end));assert(r:List(0,function() return true end));assert(r:Eligible(view,0,false))
 metadata(s,0);for _,key in ipairs({'class','level','vehicle','battle','build'}) do assert(s.calls[key]==3,'dynamic '..key..' check count changed') end
 reset(s);local value=a:GetRotationContext(0);metadata(s,1)
 assert(value.locale=='enUS' and value.projectId==5 and value.classicExpansionLevel==1 and value.seasonId==3 and value.gameModeId==4 and value.hardcore==false and value.selfFoundAllowed==true and value.runtimeVerified==false and value.version=='Fixture' and value.interface==20504 and value.build==20202)
end)
test('owned projection matches current public required fields across family precedence and native value domains',function()
 local f,a,s,r=fixture();local e=f.env
 for _,project in ipairs({1,2,5,11,14,18,19,999}) do e.WOW_PROJECT_ID=project;s.build='20202';local public=a:GetRotationContext(9);reset(s);same(public,context(r,9));metadata(s,0) end
 e.WOW_PROJECT_CAMELOT=9;e.WOW_PROJECT_MAINLINE=9;e.WOW_PROJECT_ID=9;assert(context(r,0).family=='forever')
 local opaque={};e.canaccessvalue=function(value) return not rawequal(value,opaque) end
 for _,field in ipairs({'class','level','build','vehicle','battle'}) do
  local previous=s[field]
  for _,entry in ipairs({{}, {value=false},{value=0},{value='12'},{value=0/0},{value=math.huge},{value=opaque}}) do s[field]=entry.value;same(a:GetRotationContext(3),context(r,3)) end
  s[field]=previous
 end
 s.vehicle=nil;s.fallback=true;same(a:GetRotationContext(3),context(r,3));assert(context(r,3).actionContext=='vehicle')
 e.GetBuildInfo=nil;same(a:GetRotationContext(3),context(r,3));e.GetBuildInfo=function() error('missing build') end;same(a:GetRotationContext(3),context(r,3))
 for _,provider in ipairs({false,true,7,{}}) do e.C_PetBattles=provider;local public,value=pcall(a.GetRotationContext,a,3);local private,other=pcall(context,r,3);assert(public==private,'malformed petbattle namespace changed failure behavior');if public then same(value,other) end end
end)
test('both guarded method lookups dispatch the captured member exactly once including inherited and callable overrides',function()
 local _,a,s,r=fixture();local p=a.Platform;local original=p.GetClientInfo;local reads=0
 p.GetClientInfo=nil;setmetatable(p,{__index=function(_,key) if key=='GetClientInfo' then reads=reads+1;if reads==1 then return original end;error('second client lookup') end end})
 assert(context(r,4).class=='SHAMAN' and reads==1);metadata(s,0)
 local shared={family='tbc',combatDataPolicy='probe',build='7'};reads=0
 setmetatable(p,{__index=function(_,key) if key=='GetClientInfo' then reads=reads+1;assert(reads==1);return setmetatable({},{__call=function(_,...) assert(select('#',...)==1 and (...)==p);return shared,'ignored' end}) end end})
 assert(context(r,5)==shared and shared.spec==5 and shared.build==7 and reads==1)
 p.GetClientInfo=original;setmetatable(p,nil);local actual=a.GetRotationContext;a.GetRotationContext=nil;reads=0
 setmetatable(a,{__index=function(_,key) if key=='GetRotationContext' then reads=reads+1;assert(reads==1);return actual end end})
 reset(s);assert(context(r,6).spec==6 and reads==1);metadata(s,0);reads=0
 setmetatable(a,{__index=function(_,key) if key=='GetRotationContext' then reads=reads+1;assert(reads==1);return function(...) assert(select('#',...)==2 and select(1,...)==a and select(2,...)==6);return shared,'ignored' end end end})
 shared.spec=77;assert(context(r,6)==shared and shared.spec==77 and reads==1)
 setmetatable(a,nil);a.GetRotationContext=actual;reset(s);assert(context(r,6).spec==6);metadata(s,0)
end)
test('before binding client override remains full dispatch and restoration reenables the owned path',function()
 local original,shared,calls
 local _,a,s,r=fixture(function(a)
  original=a.Platform.GetClientInfo;shared={family='tbc',combatDataPolicy='probe',build='22'};calls=0
  a.Platform.GetClientInfo=function(...) assert(select('#',...)==1 and (...)==a.Platform);calls=calls+1;return shared end
 end)
 assert(context(r,2)==shared and shared.class=='SHAMAN' and shared.level==11 and shared.spec==2 and shared.build==22 and calls==1)
 a.Platform.GetClientInfo=original;reset(s);assert(context(r,2)~=shared);metadata(s,0)
 a.Platform.GetClientInfo=function(self) assert(self==a.Platform);return original(self) end;reset(s);context(r,2);metadata(s,1);a.Platform.GetClientInfo=original
 local previous=a.GetRotationContext;local supplied={class='MAGE',spec=71};a.GetRotationContext=function(...) assert(select('#',...)==2 and select(1,...)==a and select(2,...)==2);return supplied end
 assert(context(r,2)==supplied and supplied.spec==71);a.GetRotationContext=previous
 local called=0;local _,b,_,reader=fixture(nil,function(owner) owner.GetRotationContext=function(...) assert(select('#',...)==2 and (...)==owner);called=called+1;return supplied end end)
 assert(context(reader,2)==supplied and supplied.spec==71 and called==1 and b~=a,'context override before reader binding lost authority')
end)
test('private dispatch notices context member replacement during a native read without refreshing the current observation',function()
 local _,a,s,r=fixture();local original=a.GetRotationContext;local supplied={class='MAGE',spec=91};local calls=0
 s.onClass=function() a.GetRotationContext=function(...) assert(select('#',...)==2 and (...)==a);calls=calls+1;return supplied end end
 assert(context(r,3).class=='SHAMAN' and calls==0);assert(context(r,3)==supplied and supplied.spec==91 and calls==1)
 s.onClass=nil;a.GetRotationContext=original;reset(s);assert(context(r,3).class=='SHAMAN');metadata(s,0)
 a.GetRotationContext=function(self,spec) return original(self,spec) end;reset(s);context(r,3);metadata(s,1)
end)
test('private construction keeps live Platform readability after native calls and numeric build conversion order',function()
 for _,stage in ipairs({'onClass','onLevel'}) do
  local function run(private)
   local _,a,s,r=fixture();local old=a.Platform;local replacement=setmetatable({},{__index=old})
   replacement.CanReadValue=function(self,value) assert(self==replacement);return value~=(stage=='onClass' and s.class or s.level) end
   s[stage]=function() a.Platform=replacement end
   local value=private and context(r,3) or a:GetRotationContext(3)
   assert(value[stage=='onClass' and 'class' or 'level']==nil,'readability captured old platform');return value
  end
  same(run(false),run(true))
 end
 local _,a,s,r=fixture();local p=a.Platform;local writes={};local backing={family='tbc',combatDataPolicy='probe',build='3'}
 local shared=setmetatable({},{__index=backing,__newindex=function(_,key,value) writes[#writes+1]=key;backing[key]=value end})
 p.GetClientInfo=function() return shared end;s.onLevel=function() backing.build='27' end
 assert(context(r,4)==shared and backing.build==27 and table.concat(writes,',')=='class,level,build,spec,actionContext','assignment or conversion order changed')
end)
test('context override spec mutation stays at each original library caller and errors retain exact authority',function()
 local _,a,_,r,envelope=fixture();local pack=envelope();assert(a:RegisterDefaultRotation(pack) and a:InitializeRotationLibrary())
 local shared={family='tbc',class='SHAMAN',level=11,actionContext='player',combatDataPolicy='probe',spec=77};a.GetRotationContext=function() return shared end
 assert(context(r,0)==shared and shared.spec==77);local view
 assert(r:Read(0,pack.id,function(value) view=value;return true end) and shared.spec==0);shared.spec=77
 assert(r:List(0,function() return true end) and shared.spec==0);shared.spec=77
 assert(r:Eligible(view,0,false) and shared.spec==0)
 local marker={};a.GetRotationContext=function() error(marker) end;local ok,why=pcall(context,r,1);assert(not ok and why==marker)
 local _,b,_,reader=fixture();b.Platform.GetClientInfo=function() error(marker) end;ok,why=pcall(context,reader,1);assert(not ok and why==marker)
 for _,bad in ipairs({false,'wrong',17}) do b.Platform.GetClientInfo=bad;assert(not pcall(context,reader,1)) end
end)
local function runtime()
 local h=assert(io.open('tests/rotation_scope_runtime.lua'));local text=h:read('*a');h:close();local prefix=assert(text:match('^(.-)\nlocal function gate'))
 local e,a,events,body,reference,save,load=assert(loadstring(prefix..'\nreturn fixture','@client-context-actual-main'))()()
 local original,ownedReader
 for i=1,20 do local name,value=debug.getupvalue(a.GetRotationOwnerContext,i);if not name then break end
  if name=='libraryReader' then ownedReader=value;for j=1,10 do local key,entry=debug.getupvalue(value.OwnsContext,j);if not key then break end;if key=='ownedRotationContext' then original=entry end end end
 end
 assert(type(original)=='function');a.GetRotationContext=original;load('Platform/rotation_owner.lua')
 local s={class='SHAMAN',level=11,vehicle=false,build='20202',locale=0,classes=0,levels=0}
 e.UnitClass=function() s.classes=s.classes+1;return 'Ignored',s.class end;e.UnitLevel=function() s.levels=s.levels+1;return s.level end;e.UnitHasVehicleUI=function() return s.vehicle end
 e.GetBuildInfo=function() return 'Fixture',s.build,'Date',20504 end;e.GetLocale=function() s.locale=s.locale+1;return 'enUS' end
 return e,a,s,events,body,reference,save,ownedReader
end
test('actual plain-custom main path keeps all fresh checks while all private sites omit metadata',function()
 local _,a,s,events=runtime();a:EvaluateNextActionInternal();assert(a.currentSpell==403 and #events>0 and s.classes>s.levels and s.levels>0)
 assert(s.locale==0,'one private context route still queried unused locale')
end)
test('actual bound custom-only scope retains public fallback when private context proof is missing',function()
 for _,missing in ipairs({'method','reader'}) do
  local _,a,s,events,_,_,_,reader=runtime()
  if missing=='method' then reader.Context=nil else
   for i=1,20 do local name=debug.getupvalue(a.GetRotationOwnerContext,i);if not name then break end;if name=='libraryReader' then debug.setupvalue(a.GetRotationOwnerContext,i,nil);break end end
  end
  a:EvaluateNextActionInternal();assert(a.currentSpell==403 and #events>0 and s.locale>0,'missing proof bypassed full public context or broke custom-only evaluation')
 end
end)
test('actual staged main advice rejects reentrant class level vehicle build and policy changes',function()
 for _,kind in ipairs({'class','level','vehicle','build','policy'}) do
  local e,a,s,events,body,_,save=runtime();local changed=false
  a:RegisterCondition('CONTEXT_NATIVE_MUTATION',{fields={},valid=function() return true end,evaluate=function()
   changed=true;if kind=='class' then s.class='MAGE' elseif kind=='level' then s.level=12 elseif kind=='vehicle' then s.vehicle=true elseif kind=='build' then s.build='20203' else e.WOW_PROJECT_ID=e.WOW_PROJECT_MAINLINE end;return true
  end,print=function() return '' end,widget=function() end,help=function() end})
  body.rotation[1].conditions={type='CONTEXT_NATIVE_MUTATION'};save(body);a:EvaluateNextActionInternal()
  assert(changed and #events==0,'reentrant '..kind..' change published stale advice')
 end
end)
test('strict complete source inverse permits only private additions and the five authorized context expressions',function()
 local inverse=dofile('tests/fixtures/restore_rotation_client_context.lua');local f=F.new();f.load('Core/function_data.lua');local function hash(text) return f.addon:FunctionSourceHash(text) end
 for path,want in pairs({['Platform/client.lua']='6cb90db0',['Core/rotation_library.lua']='a636cfd7',['Core/rotation_scope.lua']='5daa21f1'}) do
  local h=assert(io.open(path));local text=h:read('*a');h:close();if path~='Platform/client.lua' then text=dofile('tests/fixtures/restore_rotation_validation_adjacent.lua')(text,path,hash) end;local old=inverse(text,path,hash);assert(hash(old)==want)
  assert(not pcall(inverse,old,path,hash) and not pcall(inverse,text..text,path,hash) and not pcall(inverse,text..'\n-- unrelated edit\n',path,hash))
 end
end)
finish()
