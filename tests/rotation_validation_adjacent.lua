-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local file=assert(io.open('tests/rotation_scope_runtime.lua'));local source=file:read('*a');file:close()
local runtimeFixture=assert(loadstring(assert(source:match('^(.-)\nlocal function gate'))..'\nreturn fixture','@adjacent-stamp-real-runtime'))()
local function nativeGlobals(e)
 -- WoW's actual global environment stores these native primitives directly.
 for _,name in ipairs({'pairs','rawget','rawequal','type','getmetatable','getfenv'}) do e[name]=_G[name] end
end
-- Preserve the scanner compatibility contract. Managed publication is
-- exercised separately by dependency_revisions.lua against actual AceDB.
local function withoutManagedDependencies(callback)
 local previous=loadfile
 _G.loadfile=function(path)if path=='Core/dependency_revisions.lua' then return function()end end;return previous(path)end
 local result={pcall(callback)};_G.loadfile=previous;assert(result[1],result[2])
 return unpack(result,2,8)
end
local function fixture()
 local e,a,events,body,reference,save,load=withoutManagedDependencies(runtimeFixture);nativeGlobals(e);return e,a,events,body,reference,save,load
end
local function private(a)
 for i=1,100 do local name,value=debug.getupvalue(a.GetRotationOwnerContext,i);if not name then break end;if name=='libraryReader' then return value end end
 error('private library reader absent')
end
local function calls(fn,run,separate)
 local count,other=0,0;local previous,mask,step=debug.gethook();local compiling=jit and jit.status()
 if jit then jit.off();jit.flush() end
 debug.sethook(function(event) if event=='call' and debug.getinfo(2,'f').func==fn then
  if separate and debug.getinfo(3,'f').func==separate then other=other+1 else count=count+1 end
 end end,'c')
 local ok,result,why=pcall(run)
 if previous then debug.sethook(previous,mask,step) else debug.sethook() end;if compiling then jit.on() end
 assert(ok,result);return count,result,why,other
end
local function current(a,pass,wanted,reason)
 local n,ok,why=calls(a.GetRotationValidationStamp,function() return pass:IsCurrent() end)
 assert(n==wanted,'stamp scans '..n..' expected '..wanted)
 if reason then assert(not ok and why==reason,tostring(ok)..'/'..tostring(why)) else assert(ok,why) end
end
test('actual unchanged scoped boundary scans once and each later boundary remains fresh',function()
 local _,a=fixture();local p=assert(a:AcquireRotationRuntimePass(0));current(a,p,1);current(a,p,1)
 a.db.global.effects.new={};local ok,why=p:IsCurrent();assert(not ok and why=='rotation-library-changed')
end)
test('metatable and absent raw dependency paths retain both scans without defaults',function()
 for _,kind in ipairs({'map','conditions','effects-meta','global','profile','state','version','effect','initializer'}) do
  local _,a=fixture();if kind=='map' then setmetatable(a.db.profile.itemsets,{__index=function() error('materialized default') end}) elseif kind=='conditions' then setmetatable(a.conditionDefinitions,{}) elseif kind=='effects-meta' then setmetatable(a.db.global.effects,{}) elseif kind=='global' then setmetatable(a.db.global,{}) elseif kind=='profile' then setmetatable(a.db.profile,{}) elseif kind=='state' then setmetatable(a.db.profile.rotationLibrary,{}) elseif kind=='version' then a.conditionRegistryVersion=nil elseif kind=='effect' then a.db.global.effects=nil else local original=a.InitializeRotationLibrary;a.InitializeRotationLibrary=function(self,...) return original(self,...) end end
  local p=assert(a:AcquireRotationRuntimePass(0));current(a,p,2)
 end
end)
test('late inherited library state mutation is detected by the second scan',function()
 local _,a=fixture();local p=assert(a:AcquireRotationRuntimePass(0));local profile=a.db.profile;local state=profile.rotationLibrary;profile.rotationLibrary=nil
 setmetatable(profile,{__index=function(_,key) if key=='rotationLibrary' then a.db.global.effects.late={};return state end end})
 current(a,p,2,'rotation-dependencies-changed')
end)
test('public method overrides keep exact receiver calls and second-result authority',function()
 local _,a=fixture();local p=assert(a:AcquireRotationRuntimePass(0));local original=a.GetRotationValidationStamp;local count=0
 a.GetRotationValidationStamp=function(self,...) assert(self==a and select('#',...)==0);count=count+1;if count==1 then return original(self) end;return {} end
 local ok,why=p:IsCurrent();assert(not ok and why=='rotation-dependencies-changed' and count==2)
 a.GetRotationValidationStamp=original;current(a,p,1)
end)
test('inherited original method cannot certify its lookup side effects',function()
 local _,a=fixture();local p=assert(a:AcquireRotationRuntimePass(0));local original=a.GetRotationValidationStamp;local count=0;a.GetRotationValidationStamp=nil
 setmetatable(a,{__index=function(_,key) if key=='GetRotationValidationStamp' then count=count+1;return original end end})
 local scans,ok=calls(original,function() return p:IsCurrent() end);assert(ok and scans==2 and count==2)
end)
test('private Generation overrides cannot forge proof or hide late dependency changes',function()
 local _,a=fixture();local p=assert(a:AcquireRotationRuntimePass(0));local reader=private(a);local original=reader.Generation
 reader.Generation=function(self,...) assert(self==reader and select('#',...)==0);local generation,why,stamp=original(self);a.db.global.effects.late={};return generation,why,stamp,true end
 current(a,p,2,'rotation-dependencies-changed')
 reader.Generation=original;assert(a:InitializeRotationLibrary());p=assert(a:AcquireRotationRuntimePass(0));current(a,p,1)
end)
test('retained public stamp metatables take the original two-scan path',function()
 local _,a=fixture();local p=assert(a:AcquireRotationRuntimePass(0));local stamp=a:GetRotationValidationStamp();setmetatable(stamp,{__eq=function() return true end});current(a,p,2)
end)
test('live primitive pointer changes preserve fallback scans and mutation detection',function()
 for _,name in ipairs({'pairs','rawget','rawequal','type','getmetatable','getfenv'}) do
  local env,a=fixture();local p=assert(a:AcquireRotationRuntimePass(0));local original=env[name];env[name]=function(...) return original(...) end
  current(a,p,2);env[name]=original;current(a,p,1)
 end
end)
test('raw map edits retain independent library authority checks',function()
 for _,kind in ipairs({'effect','condition','itemset','version'}) do
  local _,a=fixture();local p=assert(a:AcquireRotationRuntimePass(0))
  if kind=='effect' then a.db.global.effects.x={} elseif kind=='condition' then a.conditionDefinitions.CUSTOM={} elseif kind=='itemset' then a.db.profile.itemsets.x={} elseif kind=='version' then a.conditionRegistryVersion=a.conditionRegistryVersion+1 else a.db.profile=a.RotationData.CopyData(a.db.profile) end
  local ok,why=p:IsCurrent();assert(not ok,kind..' edit retained authority');assert(type(why)=='string')
 end
end)
test('public option maps remain detached and runtime staged mutation still blocks output',function()
 local _,a,events,body,_,save=fixture();local one,stamp=a:GetRotationValidationOptions();local two,nextStamp=a:GetRotationValidationOptions();assert(one~=two and one.conditions~=two.conditions and stamp==nextStamp)
 one.conditions.INJECTED={};assert(a:GetRotationValidationOptions().conditions.INJECTED==nil)
 local changed=false;a:RegisterCondition('ADJACENT_MUTATION',{description='Mutation',fields={},valid=function() return true end,evaluate=function() if not changed then changed=true;a.db.global.effects.changed={} end;return true end,print=function() return 'Mutation' end,widget=function() end,help=function() end})
 body.rotation[1].conditions={type='ADJACENT_MUTATION'};save(body);a:EvaluateNextActionInternal();assert(changed and #events==0)
end)

test('inherited lookup that installs the original method still takes fallback',function()
 local _,a=fixture();local p=assert(a:AcquireRotationRuntimePass(0));local original=a.GetRotationValidationStamp;a.GetRotationValidationStamp=nil
 setmetatable(a,{__index=function(_,key) if key=='GetRotationValidationStamp' then a.GetRotationValidationStamp=original;setmetatable(a,nil);return original end end})
 local scans,ok=calls(original,function() return p:IsCurrent() end);assert(ok and scans==2);current(a,p,1)
end)
test('callable stamp and controlled errors retain actual dispatch semantics',function()
 local _,a=fixture();local p=assert(a:AcquireRotationRuntimePass(0));local original=a.GetRotationValidationStamp;local count=0
 a.GetRotationValidationStamp=setmetatable({},{__call=function(_,...) assert(select('#',...)==1 and (...)==a);count=count+1;return original(a) end})
 assert(p:IsCurrent());assert(count==2)
 local failure={};a.GetRotationValidationStamp=function() error(failure) end;local ok,why=pcall(p.IsCurrent,p);assert(not ok and why==failure)
 a.GetRotationValidationStamp=original;a.db.global.effects.new={};a.InitializeRotationLibrary=function() error(failure) end;ok,why=pcall(p.IsCurrent,p);assert(not ok and why==failure)
end)
test('changed live pairs can mutate an already-scanned map and the second scan rejects it',function()
 local env,a=fixture();local p=assert(a:AcquireRotationRuntimePass(0));local original=env.pairs;local fired=false
 env.pairs=function(value) if value==a.db.global.effects and not fired then fired=true;a.conditionDefinitions.LATE={fields={}} end;return original(value) end
 current(a,p,2,'rotation-dependencies-changed');assert(fired)
end)
local function libraryFixture(before)
 local f=withoutManagedDependencies(F.new);nativeGlobals(f.env);local a=f.addon;local data,envelope,validation=dofile('tests/fixtures/rotation_data.lua')();a.RotationData=data;a.conditionDefinitions=validation.conditions
 a.db.profile.itemsets={};a.db.global.itemsets={};a.db.global.effects={};a.conditionRegistryVersion=1
 for _,path in ipairs({'Data/catalog.lua','Data/diff.lua','Data/rotation_store.lua'}) do f.load(path) end
 if before then before(a,f.env) end
 f.load('Core/rotation_library.lua');assert(a:RegisterDefaultRotation(envelope()));assert(a:InitializeRotationLibrary())
 local reader,checker;assert(a:BindRotationLibraryReader(function(r,c) reader,checker=r,c end));return a,reader,checker
end
test('definition-owned private proof only certifies unchanged initialized generations',function()
 local a,r,checker=libraryFixture();assert(type(checker)=='function','definition-owned Generation checker missing')
 local generation,why,stamp,proof=r:Generation();assert(generation and why==nil and stamp==a:GetRotationValidationStamp() and proof==true)
 a.db.global.effects.new={};local nextGeneration,_,checked,certified=r:Generation();assert(nextGeneration~=generation and checked==nil and not certified,'initializer call issued reuse proof')
 assert(a.BindRotationValidationReader==nil,'one-time validation handoff not retired')
end)
test('pre-library stamp overrides and missing handoff cannot certify selected coverage',function()
 for _,kind in ipairs({'override','missing','primitive'}) do
  local original,restore
  local a,r=libraryFixture(function(a,e)
   original=a.GetRotationValidationStamp
   if kind=='override' then a.GetRotationValidationStamp=function(self) return original(self) end elseif kind=='missing' then a.BindRotationValidationReader=nil else restore=e.rawget;e.rawget=function(...) return restore(...) end end
  end)
  local generation,why,stamp,proof=r:Generation();assert(generation and why==nil and not proof and stamp==nil,kind..' certified')
  if kind=='override' then a.GetRotationValidationStamp=original;local _,_,checked,certified=r:Generation();assert(checked and certified) end
 end
end)
test('private generation metatable comparison path cannot issue reuse proof',function()
 local a,r=libraryFixture();local generation=r:Generation();setmetatable(generation,{__eq=function() return true end})
 local value,why,stamp,proof=r:Generation();assert(value==generation and why==nil and stamp==nil and not proof)
end)


test('wrapper that drops the second handoff argument retains the second stamp scan',function()
 local _,a,_,_,_,_,load=fixture();local r=private(a)
 a.BindRotationLibraryReader=function(self,bind) assert(self==a);bind(r);return true end
 load('Core/rotation_scope.lua');assert(a:BindRotationProfile());local p=assert(a:AcquireRotationRuntimePass(0));current(a,p,2)
end)
test('Generation and stamp callback errors preserve their original error object',function()
 local _,a=fixture();local p=assert(a:AcquireRotationRuntimePass(0));local reader=private(a);local failure={}
 reader.Generation=function() error(failure) end;local ok,why=pcall(p.IsCurrent,p);assert(not ok and why==failure)
end)


test('public stamp equality callback cannot turn a late map mutation into reusable authority',function()
 local _,a=fixture();local p=assert(a:AcquireRotationRuntimePass(0));local first=a:GetRotationValidationStamp();local comparisons=0
 local meta={__eq=function() comparisons=comparisons+1;a.db.global.effects.late={};return true end};setmetatable(first,meta)
 a.db.global.effects.before={};setmetatable(a:GetRotationValidationStamp(),meta)
 current(a,p,2,'rotation-dependencies-changed');assert(comparisons>0)
end)




test('retained generation metatables cannot reuse the adjacent stamp',function()
 local _,a=fixture();local p=assert(a:AcquireRotationRuntimePass(0));local generation=private(a):Generation();setmetatable(generation,{__eq=function() return true end});current(a,p,2)
end)
test('proof dispatch cost stays bounded when unchanged registry maps grow',function()
 local function measure(size)
  local _,a=fixture();a.conditionDefinitions={};for i=1,size do a.conditionDefinitions['CUSTOM_'..i]={fields={}} end
  local p=assert(a:AcquireRotationRuntimePass(0));local total=0;local previous,mask,step=debug.gethook();local compiling=jit and jit.status()
  if jit then jit.off();jit.flush() end
  debug.sethook(function(event) if event=='call' then local info=debug.getinfo(2,'S');if info.what=='Lua' and info.source:match('^@Core/rotation_') then total=total+1 end end end,'c')
  local ok,why=pcall(function() for _=1,10 do assert(p:IsCurrent()) end end)
  if previous then debug.sethook(previous,mask,step) else debug.sethook() end;if compiling then jit.on() end;assert(ok,why);return total
 end
 assert(measure(256)==measure(1),'proof added per-entry Lua dispatch')
end)


test('bundled real AceAddon owner metadata does not disable the raw-present fast path',function()
 local e,a,_,_,_,_,load=fixture();load('Libs/AceAddon-3.0/AceAddon-3.0.lua');assert(e.LibStub('AceAddon-3.0'):NewAddon(a,'AdjacentProofFixture')==a)
 assert(type(getmetatable(a).__tostring)=='function','actual bundled AceAddon owner metatable absent')
 local p=assert(a:AcquireRotationRuntimePass(0));local meta=getmetatable(a);local equalities=0
 meta.__eq=function() equalities=equalities+1;error('owner equality callback') end
 meta.__index=function(_,key) error('unexpected owner lookup '..key) end
 current(a,p,1);assert(equalities==0)
 local version=a.conditionRegistryVersion;a.conditionRegistryVersion=nil;local lookups=0
 meta.__index=function(_,key) assert(key=='conditionRegistryVersion');lookups=lookups+1;return version end
 current(a,p,2);assert(lookups>0 and equalities==0)
end)


test('only raw globals qualify while inherited lookup and missing capability fall back',function()
 local e,a=fixture();local p=assert(a:AcquireRotationRuntimePass(0));current(a,p,1)
 for _,name in ipairs({'pairs','rawget','rawequal','type','getmetatable','getfenv'}) do e[name]=nil end
 setmetatable(e,{__index=_G});current(a,p,2)
 setmetatable(e,{__index=setmetatable({},{__index=_G})});current(a,p,2)
 for _,name in ipairs({'pairs','rawget','rawequal','type','getmetatable','getfenv'}) do e[name]=_G[name] end
 local primitives={pairs=true,rawget=true,rawequal=true,type=true,getmetatable=true,getfenv=true}
 setmetatable(e,{__index=function(_,key) assert(not primitives[key],'unproven global '..key);return _G[key] end});current(a,p,1)
 e.getfenv=false;current(a,p,2)
 e.pairs=false;assert(not pcall(p.IsCurrent,p),'raw malformed global did not retain native failure')
end)
test('missing getfenv at module load disables the private proof without changing reads',function()
 local a,r=libraryFixture(function(a,e)
  e.getfenv=false;local chunk=assert(loadfile('Core/rotation_references.lua'));setfenv(chunk,e);chunk('rotationmaster',a)
 end)
 local generation,why,stamp,proof=r:Generation();assert(generation and why==nil and stamp==nil and not proof)
end)
test('changed owned function environments require the original second observation',function()
 local e,a=fixture();local p=assert(a:AcquireRotationRuntimePass(0));local fn=a.GetRotationValidationStamp;local alternate=setmetatable({},{__index=e})
 setfenv(fn,alternate);current(a,p,2);setfenv(fn,e);current(a,p,1)
 local observe;for i=1,10 do local name,value=debug.getupvalue(fn,i);if name=='observe' then observe=value;break end end;assert(observe)
 setfenv(observe,alternate);current(a,p,2);setfenv(observe,e);current(a,p,1)
end)




test('initializer extra returns cannot impersonate the private unchanged-branch witness',function()
 for _,success in ipairs({true,1,'ready'}) do
  local _,a=fixture();local p=assert(a:AcquireRotationRuntimePass(0));local stale=a:GetRotationValidationStamp();local count=0
  a.db.global.effects.changed={};a.InitializeRotationLibrary=function(self,...) assert(self==a and select('#',...)==0);count=count+1;return success,nil,stale,true end
  local ok,why=p:IsCurrent();assert(not ok and why=='rotation-dependencies-changed' and count==1,'initializer forged reuse proof')
 end
 local a,r=libraryFixture();local stale=a:GetRotationValidationStamp();local reason={};local count=0;a.db.global.effects.changed={}
 a.InitializeRotationLibrary=function(self,...) assert(self==a and select('#',...)==0);count=count+1;return false,reason,stale,true end
 local generation,why,checked,proof=r:Generation();assert(generation==nil and why==reason and checked==nil and proof==nil and count==1)
 local failure={};count=0;a.InitializeRotationLibrary=function() count=count+1;error(failure) end
 local ok,why=pcall(r.Generation,r);assert(not ok and why==failure and count==1)
end)


test('eligible adjacent reads run exactly one complete environment proof',function()
 -- The frozen predecessor this once compared against (eight helper environment checks, no context proof) is retired with the
 -- byte-exact inverses; the current counts are the contract.
 local _,_,a=pcall(fixture);assert(a)
 local p=assert(a:AcquireRotationRuntimePass(0));local contextProof
 for i=1,100 do local name,value=debug.getupvalue(a:GetScopedRotationCoordinator().RuntimePass,i);if not name then break end;if name=='libraryContextProof'then contextProof=value end end;assert(type(contextProof)=='function')
 local count,currentOK,why,contextChecks=calls(getfenv,function()return p:IsCurrent()end,contextProof);assert(currentOK,why)
 assert(count==9,'current helper environment checks '..count..' expected9 (wrapper plus legacy scanner in one PRE proof)')
 assert(contextChecks==4,'context producer/projection environment proof count changed')
 current(a,p,1)
end)

finish()
