-- Private current-graph reuse; public APIs retain fresh dispatch.
local make=dofile('tests/fixtures/rotation_execution.lua')
local pass,fail=0,0
local function test(name,fn)local ok,why=pcall(fn);if ok then pass=pass+1;print('PASS '..name)else fail=fail+1;print('FAIL '..name..': '..tostring(why))end end
local function count(fn,callback)
 local calls=0;local hook,mask,step=debug.gethook();local compiling=jit and jit.status();if jit then jit.off();jit.flush()end
 debug.sethook(function(event)if event=='call'and debug.getinfo(2,'f').func==fn then calls=calls+1 end end,'c')
 local ok,value=pcall(callback);if hook then debug.sethook(hook,mask,step)else debug.sethook()end;if compiling then jit.on()end;assert(ok,value);return calls,value
end
local function equal(a,b)
 assert(type(a)==type(b));if type(a)~='table'then assert(a==b,tostring(a)..' / '..tostring(b));return end
 for k,v in pairs(a)do equal(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,'extra field '..tostring(k))end
end
local function action(id,spell)return {id=id,type='spell',action=spell or 403,conditions={}}end
local function installBranch(c)
 local a=c.a;local record,token=a:GetRotationRecordSnapshot(0,a.currentRotation);assert(record,token)
 record.body.rotation={{id='branch',type='branch',mode='true',onTrue={action('head')},onFalse={}},action('tail',324)};record.body.cooldowns={}
 local reference=assert(a:ResolveRotationReference(0,a.currentRotation));assert(a:CommitRotationDraft(reference,token,record,'class'));c.tick();assert(a.currentSpell==403)
 return assert(a:AcquireRotationRuntimePass(0):Get(a.currentRotation))
end
for _,target in ipairs({false,true})do
 test('FEATURE warm main privately reuses index while checking current graph target='..tostring(target),function()
  local c=make({target=target});local calls=count(c.a.RotationData.IndexRotationSteps,function()for i=1,3 do c.tick()end end)
  assert(calls==0,'warm public index calls='..calls..'; current baseline expected3, proposed private path requires0')
 end)
end
test('real main frozen/current normalized advice query and ordered output trace agree',function()
 for _,target in ipairs({false,true})do local old,new=make({target=target},true),make({target=target});old.reset(true);new.reset(true);for i=1,5 do old.tick();new.tick()end;local om,ol=old.snapshot();local nm,nl=new.snapshot();equal(om,nm);equal(ol,nl);assert(old.a.currentSpell==new.a.currentSpell)end
end)
test('public sequence and public index stay fresh including bad callback precedence',function()
 local c=make({target=true});local a=c.a;local body={rotation={action('step')}}
 local calls=count(a.RotationData.IndexRotationSteps,function()for i=1,2 do assert(a:EvaluateRotationSequence(body,function()return {status='match'}end,function()return false end).status=='selected')end end);assert(calls==2)
 calls=count(a.RotationData.CheckPortable,function()for i=1,2 do assert(a.RotationData.IndexRotationSteps(body))end end);assert(calls==2)
 body.rotation[1].id='bad id';local r=a:EvaluateRotationSequence(body,nil,nil);assert(r.status=='unavailable'and r.diagnostic.code=='invalid-step-id')
end)
test('public index live portable false/error overrides retain exact1arg and reason identity',function()
 local c=make({target=true});local a=c.a;local body={rotation={action('step')}};local original=a.RotationData.CheckPortable;local marker={};local calls=0
 a.RotationData.CheckPortable=function(...)assert(select('#',...)==1 and (...)==body);calls=calls+1;return false,marker end
 local r=a:EvaluateRotationSequence(body,function()end,function()end);assert(r.status=='unavailable'and r.diagnostic==marker and calls==1)
 a.RotationData.CheckPortable=function()error(marker)end;local ok,why=pcall(a.EvaluateRotationSequence,a,body,function()end,function()end);assert(not ok and why==marker);a.RotationData.CheckPortable=original
end)
for _,kind in ipairs({'id','mode','unselected-arm','metatable','opaque'})do
 test('actual main callback changes runtime graph and next invocation refuses '..kind,function()
  for _,old in ipairs({true,false})do local c=make({target=true},old);local a=c.a;local body=installBranch(c);local original=a.GetSpellIds;local changed=false
   a.GetSpellIds=function(self,step,...)
    if step.id=='head'and not changed then changed=true
     if kind=='id'then step.id='tail'elseif kind=='mode'then body.rotation[1].mode='future'elseif kind=='unselected-arm'then body.rotation[1].onFalse[1]={id='broken',type='branch',onTrue={}}elseif kind=='metatable'then setmetatable(step,{})else step.unused=function()end end
    end
    return original(self,step,...)
   end
   c.tick();assert(changed and a.currentSpell==403,'first callback behavior changed')
   c.tick();assert(a.currentSpell==nil,'changed runtime graph reused stale index for '..kind);assert(not a.adviceErrorReport and #a.Diagnostics:GetReports()==0)
  end
 end)
end
for _,kind in ipairs({'CopyData','CheckPortable'})do
 test('cold/warm transient '..kind..' path escape cannot poison later metadata',function()
  for _,old in ipairs({true,false})do local c=make({target=true},old);local a=c.a;installBranch(c);local data=a.RotationData;local copy,portable=data.CopyData,data.CheckPortable
   a.NewActionReadiness=function()return function(_,id)return id~=403 end end
   local original=a.GetSpellIds;local round=0;local paths,objects={},{}
   a.GetSpellIds=function(self,step,...)
    if step.id=='head'then round=round+1;local thisRound=round
     if kind=='CopyData'then data.CopyData=function(path)
      if type(path)=='table'and path[1]=='rotation'and path[2]==2 then paths[#paths+1]=path[1];objects[#objects+1]=path;if thisRound==1 then path[1]='poison'end;data.CopyData=copy end
      return copy(path)
     end
     else data.CheckPortable=function(path)
      if type(path)=='table'and path[1]=='rotation'and path[2]==2 then paths[#paths+1]=path[1];objects[#objects+1]=path;if thisRound==1 then path[1]='poison'end;data.CheckPortable=portable;return true end
      return portable(path)
     end end
    end
    return original(self,step,...)
   end
   c.tick();c.tick();assert(round==2 and #paths==2 and paths[1]=='rotation'and paths[2]=='rotation','path poison escaped: '..table.concat(paths,','));assert(objects[1]~=objects[2],'path object reused across invocations');assert(data.CopyData==copy and data.CheckPortable==portable)
  end
 end)
end
-- Small source-owner fixture for dispatch/environment counterexamples. The
-- native standard slots are direct, matching WoW; inherited slots take fallback.
local restore=dofile('tests/fixtures/restore_rotation_execution_index.lua')
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function unit(old,setup)
 local e={};for k,v in pairs(_G)do e[k]=v end;e._G=e
 local a={db={profile={}}}
 local function load(path)local text=read(path);if old then if path=='Data/rotation_tree.lua'then text=dofile('tests/fixtures/restore_index_unsupported_binding.lua')(text)end;if path=='main.lua'then text=dofile('tests/fixtures/restore_cache_mode_initialization.lua')(text)end;text=restore(dofile('tests/fixtures/restore_rotation_execution_diagnostics.lua')(text,path),path)end;local fn=assert(loadstring(text,'@'..path));setfenv(fn,e);fn('rotationmaster',a)end
 load('Data/plain.lua');if setup then setup('plain',a,e)end
 load('Data/rotation_tree.lua');if setup then setup('tree',a,e)end
 load('Core/rotation_sequence.lua');if setup then setup('sequence',a,e)end
 local before,run;if a.BindRotationSequenceReader then a:BindRotationSequenceReader(function(b,r)before,run=b,r end)end
 local function invoke(owner,body,evaluate,visit)
  local proof=before and before(owner);local method=owner.EvaluateRotationSequence
  if run then return run(owner,proof,method,body,evaluate,visit)end
  return method(owner,body,evaluate,visit)
 end
 return a,e,invoke,run,before
end
local function selected()return {status='match'}end
local function visit()return false end
test('source-owner handoffs reject stale lexical namespaces',function()
 for _,at in ipairs({'plain','tree'})do
  local a,e,invoke=unit(false,function(phase,owner)
   if phase==at then local fresh={};for k,v in pairs(owner.RotationData)do fresh[k]=v end;owner.RotationData=fresh end
  end)
  local b={rotation={action('x')}};local fn=a.RotationData.IndexRotationSteps
  assert(count(fn,function()for i=1,2 do assert(invoke(a,b,selected,visit).status=='selected')end end)==2,'stale '..at..' namespace certified')
 end
end)
test('whole raw graph changes trigger exact portable/tree fallback including unused data',function()
 local changes={
  function(b)b.rotation[1].extra=false end,
  function(b)b.rotation[1].conditions=nil end,
  function(b)b.rotation[1].conditions={}end,
  function(b)b.rotation[1].conditions=b end,
  function(b)setmetatable(b.rotation[1],{__metatable=false})end,
  function(b)b.cooldowns={{id='x',type='spell'}}end,
  function(b)b.rotation[2]=action('x')end,
  function(b)b.rotation[1].unused=0/0 end,
  function(b)b.rotation[1].unused=function()end end,
  function(b)b.rotation[1].conditions={alias=b.rotation[1]}end,
 }
 for _,change in ipairs(changes)do
  local a,e,invoke=unit();local b={rotation={action('x')},cooldowns={}};assert(invoke(a,b,selected,visit).status=='selected');change(b)
  local actual;assert(count(a.RotationData.IndexRotationSteps,function()actual=invoke(a,b,selected,visit)end)==1,'changed graph skipped index')
  local expected=a:EvaluateRotationSequence(b,selected,visit);equal(actual,expected)
 end
end)
test('raw-only global and library qualification adds no inherited getter reads',function()
 for _,slot in ipairs({'type','pairs','ipairs','getmetatable','getfenv','table','math'})do
  local a,e,invoke=unit();local b={rotation={action('x')}};invoke(a,b,selected,visit)
  local original=e[slot];local reads=0;e[slot]=nil;setmetatable(e,{__index=function(_,key)if key==slot then reads=reads+1;return original end;return _G[key]end,__metatable={__index=_G}})
  local actual=invoke(a,b,selected,visit);local got=reads;reads=0;local expected=a:EvaluateRotationSequence(b,selected,visit)
  equal(actual,expected);assert(got==reads,slot..' proof invoked getter: '..got..' / '..reads)
  rawset(e,slot,original);assert(count(a.RotationData.IndexRotationSteps,function()invoke(a,b,selected,visit);invoke(a,b,selected,visit)end)==1,'restoration did not regain ownership')
 end
 for _,pair in ipairs({{'math','max'},{'math','huge'},{'table','sort'}})do
  local a,e,invoke=unit();local b={rotation={action('x')}};invoke(a,b,selected,visit)
  local library=e[pair[1]];local member=pair[2];local reads=0;local fresh={};for k,v in pairs(library)do if k~=member then fresh[k]=v end end
  setmetatable(fresh,{__index=function(_,k)reads=reads+1;return library[k]end});e[pair[1]]=fresh
  local actual=invoke(a,b,selected,visit);local got=reads;reads=0;local expected=a:EvaluateRotationSequence(b,selected,visit);equal(actual,expected);assert(got==reads)
 end
end)
test('public shared worker retains dynamic function environments without getfenv capability',function()
 for _,mode in ipairs({'index','type','rows','nested'})do
  local results={}
  for _,old in ipairs({true,false})do
   local a,e=unit(old);local b={rotation={{id='stop',type='none',conditions={}}}}
   local fn=a.EvaluateRotationSequence;local events={};local second={};for k,v in pairs(e)do second[k]=v end
   second.type=function(v)events[#events+1]='second-type';return type(v)end
   second.ipairs=function(v)events[#events+1]='second-ipairs';return ipairs(v)end
   if mode=='index'then local index=a.RotationData.IndexRotationSteps;a.RotationData.IndexRotationSteps=function(...)local result=index(...);setfenv(fn,second);return result end
   elseif mode=='type'then e.type=function(v)events[#events+1]='first-type';setfenv(fn,second);return type(v)end
   elseif mode=='rows'then e.ipairs=function(list)events[#events+1]='first-ipairs';local iter,state,key=ipairs(list);return function(s,k)local n,v=iter(s,k);setfenv(fn,second);return n,v end,state,key end
   end
   -- Missing probe capability must never become a public API dependency.
   e.getfenv=nil;second.getfenv=nil
   local result=fn(a,b,function()if mode=='nested'then setfenv(fn,second)end;return {status='match'}end,visit)
   results[#results+1]={result=result,events=events}
  end
  equal(results[1],results[2])
 end
end)
test('live public method overrides preserve one lookup receiver and exact three arguments',function()
 local a,e,invoke=unit();local b={rotation={action('x')}};invoke(a,b,selected,visit);local original=a.EvaluateRotationSequence;local calls=0
 local override=setmetatable({},{__call=function(_,...)calls=calls+1;assert(select('#',...)==4);local self,body,ev,vi=...;assert(self==a and body==b and ev==selected and vi==visit);return {status='custom'}end})
 a.EvaluateRotationSequence=override;assert(invoke(a,b,selected,visit).status=='custom'and calls==1)
 a.EvaluateRotationSequence=nil;local reads=0;setmetatable(a,{__index=function(_,key)if key=='EvaluateRotationSequence'then reads=reads+1;rawset(a,key,original);return original end end})
 assert(count(a.RotationData.IndexRotationSteps,function()invoke(a,b,selected,visit)end)==1 and reads==1,'getter-installed method falsely owned')
 assert(count(a.RotationData.IndexRotationSteps,function()invoke(a,b,selected,visit);invoke(a,b,selected,visit)end)==1)
end)
test('private row metadata never escapes through live worker iterator',function()
 local a,e,invoke=unit();local b={rotation={action('x')}};invoke(a,b,selected,visit)
 local original=e.ipairs;local leaked={};e.ipairs=function(list)
  if type(list[1])=='table'and list[1].step then leaked[#leaked+1]=list;assert(list[1].ordinal==1 and list[1].section=='rotation'and list[1].index==1 and list[1].depth==0 and list[1].unreachable==false);list[1].path[1]='poison';list[1].extra='escaped' end
  return original(list)
 end
 -- A live override disables private reuse, as required; restoring it cannot
 -- expose the canonical rows from an earlier invocation either.
 invoke(a,b,selected,visit);e.ipairs=original
 assert(invoke(a,b,selected,visit).status=='selected');assert(#leaked==1 and b.rotation[1].extra==nil)
end)
test('private execution retains live type and iterator overrides installed within callback',function()
 for _,slot in ipairs({'type','ipairs'})do
  local observations={}
  for _,old in ipairs({true,false})do
   local a,e,invoke=unit(old);local b={rotation={{id='branch',type='branch',conditions={},onTrue={action('x')},onFalse={}}}}
   local native=e[slot];local hits=0;local marker={};local ok,why=pcall(invoke,a,b,function()
    local observation={status='match'}
    e[slot]=function(value,...)if slot=='type'and value==observation or slot=='ipairs'and value==b.rotation[1].onTrue then hits=hits+1;error(marker)end;return native(value,...)end;return observation
   end,visit)
   e[slot]=native;observations[#observations+1]={ok=ok,hit=hits,marker=why==marker}
  end
  equal(observations[1],observations[2]);assert(not observations[2].ok and observations[2].hit==1 and observations[2].marker)
 end
end)
test('non-table private receiver proof falls back without rawget error',function()
 local a,e,invoke,run,before=unit();local marker={};local calls=0
 assert(before(nil)==nil and before(false)==nil)
 local function method(...)calls=calls+1;assert(select('#',...)==4);assert((...)==false);return marker,nil,false end
 local x,y,z=run(false,nil,method,{},selected,visit);assert(x==marker and y==nil and z==false and calls==1)
end)
test('profile and body changes retire one-entry proof; nested calls cannot poison outer metadata',function()
 local a,e,invoke=unit();local b={rotation={action('x')}};local c={rotation={action('y')}}
 assert(count(a.RotationData.IndexRotationSteps,function()invoke(a,b,selected,visit);invoke(a,b,selected,visit)end)==1)
 local profile=a.db.profile;a.db.profile={}
 assert(count(a.RotationData.IndexRotationSteps,function()invoke(a,b,selected,visit);invoke(a,b,selected,visit)end)==1)
 a.db.profile=profile
 assert(count(a.RotationData.IndexRotationSteps,function()invoke(a,b,selected,visit);invoke(a,c,selected,visit);invoke(a,b,selected,visit)end)==3)
 local nested=false;local paths={}
 local result=invoke(a,b,selected,function(step,ordinal,path)
  paths[#paths+1]=path;if not nested then nested=true;invoke(a,c,selected,function(_,_,inner)assert(inner~=path);inner[1]='poison';return false end)end
  assert(path[1]=='rotation');return false
 end)
 assert(result.status=='selected'and nested);invoke(a,b,selected,function(_,_,path)assert(path~=paths[1]and path[1]=='rotation');return false end)
end)
test('trusted string anchor rejects protected views and live method changes without invoking getter',function()
 local a,e,invoke=unit();local b={rotation={action('x')}};invoke(a,b,selected,visit)
 local mt=getmetatable('');local methods=rawget(mt,'__index');local protection=rawget(mt,'__metatable');local reads=0
 local fake={__index=methods};local changed=setmetatable({},{__index=function(_,key)reads=reads+1;return methods[key]end})
 local ok,why=pcall(function()
  rawset(mt,'__index',changed);rawset(mt,'__metatable',fake)
  local actual=invoke(a,b,selected,visit);local got=reads;reads=0;local expected=a:EvaluateRotationSequence(b,selected,visit)
  equal(actual,expected);assert(got==reads,'anchor proof chased forged string view')
 end)
 rawset(mt,'__index',methods);rawset(mt,'__metatable',protection);assert(ok,why)
 assert(count(a.RotationData.IndexRotationSteps,function()invoke(a,b,selected,visit);invoke(a,b,selected,visit)end)==1)
end)
test('many valid and malformed graphs retain exact result diagnostics and callback histories',function()
 local function execute(old,body)
  local a,e,invoke=unit(old);local trace={}
  local ok,result=pcall(invoke,a,body,function(condition,context)
   trace[#trace+1]={guard=condition and condition.type,path=context.stepPath,id=context.stepId}
   return {status=condition and condition.status or 'no-match'}
  end,function(step,ordinal,path)trace[#trace+1]={id=step.id,ordinal=ordinal,path=path};return step.action~=324 end)
  return {ok=ok,result=result,trace=trace}
 end
 for i=1,120 do
  local left={action('left',i%3==0 and 324 or 403)};local right={action('right')}
  local b={rotation={{id='b',type='branch',mode=({'evaluate','true','false'})[i%3+1],conditions={type='gate',status=({'match','no-match','unavailable'})[i%3+1]},onTrue=left,onFalse=right},action('tail')},cooldowns={}}
  if i%4==0 then left[1].disabled=true end
  if i%5==0 then right[1].id='left'end
  if i%7==0 then b.rotation[1].onFalse=nil end
  if i%11==0 then b.extra=function()end end
  if i%13==0 then b.rotation[1].future=false end
  equal(execute(true,b),execute(false,b))
 end
end)
test('db replacement with shared profile retires private index authority',function()
 local a,e,invoke=unit();local b={rotation={action('x')}};invoke(a,b,selected,visit)
 a.db={profile=a.db.profile}
 assert(count(a.RotationData.IndexRotationSteps,function()invoke(a,b,selected,visit);invoke(a,b,selected,visit)end)==1,'db container replacement retained previous entry')
end)
test('rebound binder environment cannot replace original-owned execution environment',function()
 local marker={};local a,e,invoke=unit(false,function(phase,owner)
  if phase=='sequence'then setfenv(owner.BindRotationSequenceReader,{type=function()error(marker)end,ipairs=function()error(marker)end})end
 end)
 assert(invoke(a,{rotation={action('x')}},selected,visit).status=='selected')
end)
print(pass..' passed, '..fail..' failed');os.exit(fail>0 and 1 or 0)
