local function read(p)local h=assert(io.open(p));local s=h:read('*a');h:close();return s end
local baseline={};local inverse=dofile('tests/fixtures/restore_parser_string_operations.lua')
local restorePreview=dofile('tests/fixtures/restore_cpu_preview_context.lua')
local originalPreviewInverse=restorePreview;local restoreScopes=dofile('tests/fixtures/restore_cpu_validation_scopes.lua')
restorePreview=function(text)return originalPreviewInverse(restoreScopes(text,'Diagnostics/cpu.lua'))end
for _,p in ipairs({'Data/plain.lua','Data/rotation_tree.lua','Diagnostics/cpu.lua'})do local source=read(p);if p=='Diagnostics/cpu.lua' then source=restorePreview(source) end;baseline[p]=inverse(source,p) end
-- Use the canonical actual-main setup without its unrelated frozen-index tail.
-- This feature's own exact inverse supplies the92c8fe8 reference Data owners.
local fixture=read('tests/fixtures/rotation_execution.lua');local start=assert(fixture:find("local restore=dofile('tests/fixtures/restore_rotation_execution_index.lua')",1,true))
fixture=fixture:sub(1,start-1)..'return function(options)return factory(options or {})end\n'
local make=assert(loadstring(fixture,'@parser-current-main-fixture'))();local passed,failed=0,0
local function test(name,fn)local ok,why=pcall(fn);if ok then passed=passed+1;print('PASS '..name)else failed=failed+1;print('FAIL '..name..': '..tostring(why))end end
local function copy(t)local r={};for k,v in pairs(t)do r[k]=v end;return r end
local function same(a,b)assert(type(a)==type(b));if type(a)~='table'then assert(a==b,tostring(a)..'/'..tostring(b));return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function pack(...)return{n=select('#',...),...}end
local function withSource(enabled,fn)
 local loader=loadfile;if not enabled then loadfile=function(p)if baseline[p]then return assert(loadstring(baseline[p],'@'..p))end;return loader(p)end end
 local r=pack(pcall(fn));loadfile=loader;assert(r[1],r[2]);return unpack(r,2,r.n)
end
local function current(options,enabled)return withSource(enabled,function()return make(options)end)end
local function calls(fn,run)
 local n=0;local hook,mask,step=debug.gethook();local active=jit and jit.status();if jit then jit.off()end
 debug.sethook(function(event)if event=='call'and debug.getinfo(2,'f').func==fn then n=n+1 end end,'c')
 local ok,why=pcall(run);if hook then debug.sethook(hook,mask,step)else debug.sethook()end;if active then jit.on()end;assert(ok,why);return n
end
local realMeta=getmetatable('');local oldProtection=rawget(realMeta,'__metatable')
local function masked(fn)
 rawset(realMeta,'__metatable','opaque native string descriptor')
 local ok,why=pcall(fn);rawset(realMeta,'__metatable',oldProtection);assert(ok,why)
end
for _,target in ipairs({false,true})do test('actual Shaman opaque native string descriptor target='..tostring(target),function()
 masked(function()
  local before,after=current({target=target},false),current({target=target},true)
  before.reset(true);after.reset(true)
  local old=calls(before.a.RotationData.IndexRotationSteps,function()for i=1,3 do before.tick()end end)
  local new=calls(after.a.RotationData.IndexRotationSteps,function()for i=1,3 do after.tick()end end)
  assert(old==3 and new==0,'warm calls '..old..'/'..new)
  local on,ot=before.snapshot();local nn,nt=after.snapshot();same(on,nn);same(ot,nt);assert(before.a.currentSpell==after.a.currentSpell)
 end)
end)end
local function unit(enabled)
 local e=copy(_G);e._G=e;local a={db={profile={}}}
 withSource(enabled,function()for _,p in ipairs({'Data/plain.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua'})do local f=assert(loadfile(p));setfenv(f,e);f('rotationmaster',a)end end)
 local before,run;a:BindRotationSequenceReader(function(b,r)before,run=b,r end)
 local function invoke(body,ev,visit)return run(a,before(a),a.EvaluateRotationSequence,body,ev or function()return{status='match'}end,visit or function()return false end)end
 return a,e,invoke
end
local function body()return{rotation={{id='valid:id-1.x',type='spell',action=403,conditions={}}},cooldowns={}}end
test('normal identifiers and malformed long/Unicode/control names retain decisions',function()
 local old=unit(false);local new=unit(true)
 for _,id in ipairs({'valid','A:b-c_d.9','',':bad','bad id','a\nb','界',string.rep('x',128),string.rep('x',129)})do local b=body();b.rotation[1].id=id;local x,y=pack(old.RotationData.IndexRotationSteps(b)),pack(new.RotationData.IndexRotationSteps(b));same(x,y)end
end)
test('portable error paths preserve80byte truncation exact code severity and tuple',function()
 local old=unit(false);local new=unit(true)
 for _,key in ipairs({'simple',string.rep('x',100),string.rep('界',40)})do local b={[key]={bad=function()end}};same(pack(old.RotationData.CheckPortable(b)),pack(new.RotationData.CheckPortable(b)))end
end)
test('public APIs always build fresh and public override receiver arity errors stay live',function()
 local a,e,invoke=unit(true);local b=body();invoke(b);assert(calls(a.RotationData.IndexRotationSteps,function()for i=1,2 do a:EvaluateRotationSequence(b,function()return{status='match'}end,function()return false end)end end)==2)
 local fn=a.RotationData.CheckPortable;local marker={};local n=0
 a.RotationData.CheckPortable=function(...)assert(select('#',...)==1 and (...)==b);n=n+1;return false,marker end
 local result=invoke(b);assert(result.diagnostic==marker and n==1)
 a.RotationData.CheckPortable=function()error(marker)end;local ok,why=pcall(invoke,b);assert(not ok and why==marker);a.RotationData.CheckPortable=fn
end)
test('raw whole graph detects unused fields and equal-content replacement',function()
 local a,_,invoke=unit(true);local b=body();invoke(b);assert(calls(a.RotationData.IndexRotationSteps,function()invoke(b)end)==0)
 b.unused={x=1};assert(calls(a.RotationData.IndexRotationSteps,function()invoke(b)end)==1)
 b.unused={x=1};assert(calls(a.RotationData.IndexRotationSteps,function()invoke(b)end)==1)
 b.rotation[1].id='bad id';assert(invoke(b).status=='unavailable')
end)
test('changed public helper environment retains fresh fallback',function()
 local a,e,invoke=unit(true);local b=body();invoke(b);local fn=a.RotationData.IndexRotationSteps;local alt=copy(e);local reads=0;alt.type=function(v)reads=reads+1;return type(v)end;setfenv(fn,alt)
 assert(calls(fn,function()invoke(b)end)==1 and reads>0)
 setfenv(fn,e);assert(calls(fn,function()invoke(b);invoke(b)end)==1)
end)
test('inherited globals preserve exact fresh getter counts without speculative proof reads',function()
 for _,key in ipairs({'type','pairs','ipairs','table','math','getmetatable','getfenv'})do
  local a,e,invoke=unit(true);local b=body();invoke(b);local native=e[key];local reads=0;e[key]=nil;setmetatable(e,{__index=function(_,k)if k==key then reads=reads+1;return native end;return _G[k]end,__metatable={__index=_G}})
  local r=invoke(b);local actual=reads;reads=0;local fresh=a:EvaluateRotationSequence(b,function()return{status='match'}end,function()return false end);same(r,fresh);assert(reads==actual,key..' added getter')
 end
end)
test('StringMT monkeypatch is intentionally no longer a parser override',function()
 local a,_,invoke=unit(true);local b=body();invoke(b);local methods=rawget(realMeta,'__index');local match=rawget(methods,'match');rawset(methods,'match',function()return nil end)
 local ok,why=pcall(function()assert(a.RotationData.IndexRotationSteps(b));assert(calls(a.RotationData.IndexRotationSteps,function()assert(invoke(b).status=='selected')end)==0)end)
 rawset(methods,'match',match);assert(ok,why)
end)
test('1000generated mixed portable values retain exact decisions and diagnostics',function()
 local old=unit(false);local new=unit(true);local seed=19
 local function random(n)seed=(seed*48271)%2147483647;return seed%n+1 end
 local function value(depth)
  local kind=random(depth>3 and 7 or 10)
  if kind==1 then return false elseif kind==2 then return 'text'..random(300) elseif kind==3 then return random(500)/7 elseif kind==4 then return math.huge elseif kind==5 then return function()end elseif kind==6 then return nil elseif kind==7 then return true end
  local result={};for i=1,random(4)do result[random(2)==1 and i or 'field'..random(12)]=value(depth+1)end;return result
 end
 for i=1,1000 do local v=value(0);same(pack(old.RotationData.CheckPortable(v)),pack(new.RotationData.CheckPortable(v)))end
end)
test('200nested trees retain all index rows paths and failures',function()
 local old=unit(false);local new=unit(true)
 for i=1,200 do
  local b=body();b.rotation[2]={id='branch'..i,type='branch',mode=i%3==0 and 'true' or 'evaluate',onTrue={{id='yes'..i,type='spell',action=403}},onFalse={{id='no'..i,type='spell',action=8042}}}
  if i%5==0 then b.rotation[2].onFalse[1].id=b.rotation[1].id end
  if i%7==0 then b.rotation[2].mode='future' end
  if i%11==0 then b.rotation[1].id='bad id' end
  same(pack(old.RotationData.IndexRotationSteps(b)),pack(new.RotationData.IndexRotationSteps(b)))
 end
end)
test('missing malformed and inherited captured operations decline without late adoption',function()
 for _,member in ipairs({'match','sub'})do for _,mode in ipairs({'missing-library','malformed-library','missing-member','malformed-member','inherited-member'})do
  local e=copy(_G);e._G=e;local a={db={profile={}}};local getters=0;local library=copy(string)
  if mode=='missing-library'then e.string=nil elseif mode=='malformed-library'then e.string=false
  else e.string=library;if mode=='malformed-member'then library[member]=false else library[member]=nil end
   if mode=='inherited-member'then setmetatable(library,{__index=function()getters=getters+1;error('inherited parser member')end})end
  end
  for _,path in ipairs({'Data/plain.lua','Data/rotation_tree.lua'})do local f=assert(loadfile(path));setfenv(f,e);f('rotationmaster',a)end
  local reader,status;a:BindRotationExecutionIndexReader(function(r,_,p)reader,status=r,p end)
  assert(getters==0,'captured inherited string member')
  local observation=status(a.RotationData);local portable=observation.portable;local index=observation.index
  if member=='sub'or mode=='missing-library'or mode=='malformed-library'then assert(portable.reason=='parser-sub-unavailable'and portable.parserSub==false)else assert(index.reason=='parser-match-unavailable'and index.parserMatch==false)end
  assert(reader(body(),a.db.profile,a.RotationData,a.db)==false,'unavailable parser authorized index reuse')
  e.string=string;local nextStatus=status(a.RotationData)
  assert(nextStatus.portable.parserSub==portable.parserSub and nextStatus.index.parserMatch==index.parserMatch,'captured parser adopted late library repair')
  assert(a.RotationData.CheckPortable(1)==true,'unused sub capability prevented scalar validation')
  if member=='match'or mode=='missing-library'or mode=='malformed-library'then assert(not pcall(a.RotationData.IndexRotationSteps,body()),'absent consumed match invented result')else assert(not pcall(a.RotationData.CheckPortable,{bad=function()end}),'absent consumed sub invented result')end
 end end
end)
test('captured parser capability ignores later library and native metatable changes',function()
 local a,e=unit(true);e.string={match=function()error('late match')end,sub=function()error('late sub')end}
 assert(a.RotationData.IndexRotationSteps(body()));local ok,why=a.RotationData.CheckPortable({long={bad=function()end}});assert(not ok and why.path=='$.long.bad')
end)
local cpuSource=read('tests/cpu.lua');local cpuPrefix=assert(cpuSource:match('^(.-)\ntest%('));local cpuFixture=assert(loadstring(cpuPrefix..'\nreturn fixture','@parser-current-cpu-fixture'))()
test('actual CPU report shows fixed captured parser capabilities with source-free bounded fields',function()
 for _,missing in ipairs({false,true})do
  local f,a,state=cpuFixture();local e=f.env
  for _,key in ipairs({'type','pairs','ipairs','getfenv','getmetatable','rawget','rawequal','next','math','table'})do e[key]=_G[key]end
  if missing then e.string=copy(string);e.string.match=nil else e.string=string end
  f.load('Data/plain.lua');f.load('Data/rotation_tree.lua')
  local status;a:BindRotationExecutionIndexReader(function(_,_,p)status=p end)
  assert(a:BindCPUExecutionIndexDiagnostic(function()local value=status(a.RotationData);value.main={reason='ready'};value.sequence={reason='ready'};return value end)==nil)
  assert(a:StartCPUProfile());state:complete();local text=a:GetCPUProfileReport()
  assert(text:find('; parser-match='..(missing and '0' or '1')..'; parser-sub=1',1,true),'missing captured parser report')
  assert(not text:find('string-index=',1,true)and not text:find('string-global=',1,true),'obsolete native string proof report')
  assert(not text:find('function:',1,true)and not text:find('SECRET_SOURCE_TEXT',1,true)and #text<16000)
  local n=#state.native;a:GetCPUProfileReport();assert(#state.native==n,'report read recollected source capability')
 end
end)
test('complete three-file inverse rejects altered original duplicate and unknown input',function()
 for _,path in ipairs({'Data/plain.lua','Data/rotation_tree.lua','Diagnostics/cpu.lua'})do
  local source=read(path);if path=='Diagnostics/cpu.lua' then source=restorePreview(source) end;assert(inverse(source,path)==baseline[path]);assert(not pcall(inverse,baseline[path],path));assert(not pcall(inverse,source..source,path));assert(not pcall(inverse,source..'\n-- unrelated change\n',path))
 end
 assert(not pcall(inverse,read('main.lua'),'main.lua'))
end)
print(passed..' passed, '..failed..' failed');if failed>0 then os.exit(1)end
