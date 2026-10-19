local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
 local f=F.new();local a=f.addon;a.conditionDefinitions={KNOWN={fields={}}};a.db.profile.itemsets={};a.db.global.itemsets={};a.db.global.effects={};f.load('Core/rotation_references.lua');return a
end
local function stamp(a) assert(type(a.GetRotationValidationStamp)=='function','nonallocating current stamp path missing');return a:GetRotationValidationStamp() end
local function changed(a,previous) local value=stamp(a);assert(value~=previous,'dependency mutation retained old stamp');return value end
test('public options retain fresh detached maps while unchanged stamp checks stay stable',function()
 local a=fixture();local item,effect={},{};a.db.global.itemsets.shared=item;a.db.global.effects.glow=effect
 local s=stamp(a);local first,one=a:GetRotationValidationOptions();local second,two=a:GetRotationValidationOptions();assert(one==s and two==s and first~=second and first.itemsets~=second.itemsets and first.effects~=second.effects and first.conditions~=second.conditions)
 assert(first.itemsets.shared==item and first.effects.glow==effect and first.conditions.KNOWN==a.conditionDefinitions.KNOWN)
 first.conditions.KNOWN=nil;first.itemsets.shared=false;first.effects.injected={};first.conditions.phantom={};assert(stamp(a)==s)
 local fresh,nextStamp=a:GetRotationValidationOptions();assert(nextStamp==s and fresh.conditions.KNOWN and fresh.itemsets.shared==item and fresh.effects.injected==nil)
end)
test('profile global and registry version identities still invalidate in-place observers',function()
 local a=fixture();local s=stamp(a);a.db.profile={itemsets={}};s=changed(a,s);a.db.global={effects={},itemsets={}};s=changed(a,s);a.conditionRegistryVersion=10;s=changed(a,s);assert(stamp(a)==s)
end)
test('condition effect additions replacements removals and malformed markers have exact stable semantics',function()
 for _,field in ipairs({'conditions','effects'}) do local a=fixture();local function map() return field=='conditions' and a.conditionDefinitions or a.db.global.effects end;local s=stamp(a)
  map().extra={};s=changed(a,s);map().extra={};s=changed(a,s);map().extra=0/0;s=changed(a,s);map().extra=0/0;assert(stamp(a)==s);map().extra=false;assert(stamp(a)==s);map().extra='bad';assert(stamp(a)==s);map().extra=nil;s=changed(a,s)
  local entries=map();if field=='conditions' then a.conditionDefinitions={} else a.db.global.effects={} end;if next(entries)==nil then assert(stamp(a)==s) else s=changed(a,s) end
 end
end)
test('itemset shadowing includes false markers and ignores changes hidden by personal entries',function()
 local a=fixture();local shared,personal={},{};a.db.global.itemsets={shared=shared,only={}};a.db.profile.itemsets={shared=personal};local s=stamp(a)
 assert(a:GetRotationValidationOptions().itemsets.shared==personal);a.db.global.itemsets.shared={};assert(stamp(a)==s,'hidden global replacement changed effective map')
 a.db.profile.itemsets.shared=false;s=changed(a,s);assert(a:GetRotationValidationOptions().itemsets.shared==false);a.db.global.itemsets.shared={};assert(stamp(a)==s)
 a.db.profile.itemsets.shared=nil;s=changed(a,s);assert(a:GetRotationValidationOptions().itemsets.shared==a.db.global.itemsets.shared);a.db.global.itemsets.only=nil;changed(a,s)
end)
test('malformed scope maps suppress all item references without unstable NaN observations',function()
 local a=fixture();a.db.global.itemsets={shared={}};local s=stamp(a);a.db.profile.itemsets=false;s=changed(a,s)
 for _,bad in ipairs({'bad',1,0/0}) do a.db.profile.itemsets=bad;assert(stamp(a)==s and next(a:GetRotationValidationOptions().itemsets)==nil) end
 a.db.profile.itemsets={personal={}};a.db.global.itemsets=false;assert(stamp(a)==s);a.db.global.itemsets=nil;s=changed(a,s);assert(a:GetRotationValidationOptions().itemsets.personal)
 a.conditionDefinitions=nil;a.db.global.effects=false;stamp(a);local opts=a:GetRotationValidationOptions();opts.conditions.phantom={};opts.effects.phantom={};assert(next(a:GetRotationValidationOptions().conditions)==nil and next(a:GetRotationValidationOptions().effects)==nil)
end)
test('same-count replacement and equivalent map swaps preserve exact top-level identity rules',function()
 local a=fixture();local item={items={1}};local effect={type='texture'};local definition=a.conditionDefinitions.KNOWN
 a.db.global.itemsets={shared=item};a.db.profile.itemsets={shared=false};a.db.global.effects={glow=effect};local s=stamp(a)
 a.db.global.itemsets.shared=false;assert(stamp(a)==s);a.db.global.itemsets.shared=nil;assert(stamp(a)==s,'hidden global removal changed personal marker')
 a.db.profile.itemsets={shared=false};a.db.global.itemsets={shared={}};a.db.global.effects={glow=effect};a.conditionDefinitions={KNOWN=definition};assert(stamp(a)==s,'equivalent map table replacement changed stamp')
 a.db.global.effects={other=effect};s=changed(a,s);a.db.global.effects.other.type='pixel';definition.fields.child='condition';assert(stamp(a)==s,'nested metadata began changing an identity-only stamp')
 a.db.profile.itemsets={renamed=false};s=changed(a,s);assert(a:GetRotationValidationOptions().itemsets.shared==a.db.global.itemsets.shared)
 a.db.global.itemsets=false;a.db.profile.itemsets=false;s=changed(a,s);a.db.global.itemsets={};a.db.profile.itemsets={};assert(stamp(a)==s,'malformed-to-empty equivalent map changed stamp')
end)
test('default-map metatables are observed without materializing missing shadow keys',function()
 local a=fixture();local indexes=0;local default=setmetatable({},{__index=function() indexes=indexes+1;return {} end});a.db.profile.itemsets=default;a.db.global.itemsets={shared={}};local s=stamp(a)
 for i=1,25 do assert(stamp(a)==s);local opts,nextStamp=a:GetRotationValidationOptions();assert(nextStamp==s and opts.itemsets.shared==a.db.global.itemsets.shared) end
 assert(indexes==0 and next(default)==nil,'stamp lookup materialized an AceDB-style default')
end)
test('unchanged identity scans keep Lua dispatch overhead independent of registry size',function()
 local a=fixture()
 local function measure(size)
  a.conditionDefinitions={};for i=1,size do local value={};if i%3==0 then value=false end;a.conditionDefinitions['CONDITION_'..i]=value end
  local expected=stamp(a);local calls=0
  local previous,mask,count=debug.gethook();local compiling=jit and jit.status()
  if jit then jit.off();jit.flush() end
  debug.sethook(function(event)
   if event=='call' then local info=debug.getinfo(2,'S');if info.what=='Lua' and not info.source:match('^@tests/') then calls=calls+1 end end
  end,'c')
  local ok,why=pcall(function() for _=1,20 do assert(rawequal(a:GetRotationValidationStamp(),expected)) end end)
  if previous then debug.sethook(previous,mask,count) else debug.sethook() end
  if compiling then jit.on() end
  assert(ok,why);return calls
 end
 local small,large=measure(1),measure(256)
 assert(large-small<=20,'unchanged registry size added '..(large-small)..' Lua calls to20 freshness checks')
end)
local function runtimeFixture()
 local h=assert(io.open('tests/rotation_scope_runtime.lua'));local source=h:read('*a');h:close();local prefix=assert(source:match('^(.-)\nlocal function gate'));return assert(loadstring(prefix..'\nreturn fixture','@validation-stamp-real-runtime'))()()
end
test('repeated real scoped ticks avoid rebuilding public maps for internal freshness checks',function()
 local _,a,events=runtimeFixture();for i=1,3 do a:EvaluateNextActionInternal() end
 local count=0;local options=a.GetRotationValidationOptions;a.GetRotationValidationOptions=function(self,...) count=count+1;return options(self,...) end
 for i=1,10 do a:EvaluateNextActionInternal() end
 assert(a.currentSpell==403 and #events>0,'real recommendation path did not run');assert(count<=20,'internal checks rebuilt public validation maps '..count..' times for10 stable ticks')
end)
test('raw dependency mutations during actual condition evaluation still retire staged recommendations',function()
 for _,kind in ipairs({'effects','itemsets','conditions','version'}) do local _,a,events,body,_,save=runtimeFixture();local mutate=false
  a:RegisterCondition('STAMP_MUTATION',{description='Dependency mutation',fields={},valid=function() return true end,evaluate=function()
   if not mutate then mutate=true;if kind=='effects' then a.db.global.effects.changed={} elseif kind=='itemsets' then a.db.global.itemsets.changed={} elseif kind=='conditions' then a.conditionDefinitions.NEW={fields={}} else a.conditionRegistryVersion=(a.conditionRegistryVersion or 0)+1 end end;return true end,
   print=function() return 'Dependency mutation' end,widget=function() end,help=function() end})
  body.rotation[1].conditions={type='STAMP_MUTATION'};save(body);a:EvaluateNextActionInternal();assert(mutate and #events==0,'reentrant '..kind..' mutation published stale advice')
 end
end)
finish()
