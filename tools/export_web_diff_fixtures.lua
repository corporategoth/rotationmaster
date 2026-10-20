-- Actual Lua data-layer oracle; run with LuaJIT for real codec wire records.
-- No native observations, custom source execution, or JS comparator dependency.
local data,envelope=dofile('tests/fixtures/rotation_data.lua')()
assert(loadfile('Data/diff.lua'))('rotationmaster',{RotationData=data})
local rows={};local passed=0
local codec
if arg[1]~='--controls' then local d,deps=dofile('tests/fixtures/codec.lua')();codec=assert(d.NewCodec(deps)) end
local function copy(v)return assert(data.CopyData(v))end
local function equal(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
local function find(r,kind,path)for _,c in ipairs(r.changes)do if c.kind==kind and(not path or c.path==path)then return c end end end
local function record(id,left,right,options,check,small)
 local oldLeft,oldRight=copy(left),copy(right)
 local result=data.DiffRotations(left,right,options);check(result)
 assert(equal(oldLeft,left),'left mutated');assert(equal(oldRight,right),'right mutated')
 passed=passed+1
 if codec and small~=false then
  local payload={id=id,left=left,right=right,result=result};if options then payload.options=options end
  local wire=assert(codec:Encode(payload));io.write('{"id":"'..id..'","wire":"'..wire..'"}\n')
 elseif codec then io.write('{"id":"'..id..'","summary":{"valid":'..tostring(result.valid)..',"complete":'..tostring(result.complete)..',"changes":'..#result.changes..',"diagnostic":"'..result.diagnostics[1].code..'"}}\n')
 else print('PASS '..id..' changes='..#result.changes..' complete='..tostring(result.complete))end
 return result
end
local a,b=envelope(),envelope()
b.body.revision=9
record('body-counter-is-nonsemantic',a,b,nil,function(r)assert(r.valid and r.complete and #r.changes==0)end)
a,b=envelope(),envelope();b.revision=2
record('envelope-source-version-observed',a,b,nil,function(r)assert(#r.changes==1 and find(r,'changed','$.revision'))end)
record('explicit-envelope-identity-ignore',a,b,{ignoreIdentity=true},function(r)assert(#r.changes==0)end)
a,b=envelope(),envelope();b.body.rotation[1].id='cloned'
record('renamed-id-without-lineage-is-add-remove',a,b,nil,function(r)assert(#r.changes==2 and find(r,'removed')and find(r,'added'))end)
record('explicit-origin-map-pairs-renamed-id',a,b,{rightOrigins={cloned='step-1'}},function(r)assert(#r.changes==0)end)
a,b=envelope(),envelope();b.body.rotation[1].ranked=true;b.body.rotation[1].disabled=true
record('authored-flags-remain-explicit',a,b,nil,function(r)assert(#r.changes==2 and find(r,'added','$.body.rotation[step-1].ranked')and find(r,'added','$.body.rotation[step-1].disabled'))end)
a,b=envelope(),envelope();b.body.rotation[1].conditions[1]=false;b.body.rotation[1].conditions['1']=true
record('numeric-and-byte-key-paths-distinct',a,b,nil,function(r)assert(#r.changes==2 and r.changes[1].segments[5].key==1 and r.changes[2].segments[5].key=='1')end)
a,b=envelope(),envelope();a.body.rotation={};b.body.rotation={}
for i=1,4 do a.body.rotation[i]={id='s'..i,type='spell',action=i}end
b.body.rotation={copy(a.body.rotation[2]),copy(a.body.rotation[3]),copy(a.body.rotation[4]),copy(a.body.rotation[1])}
record('LIS-rotation-is-one-move',a,b,nil,function(r)assert(#r.changes==1 and r.changes[1].kind=='moved'and r.changes[1].stepId=='s1')end)
a,b=envelope(),envelope();a.body.rotation={{id='branch',type='branch',mode='evaluate',conditions={},onTrue={{id='child',type='spell',action=403}},onFalse={}}};b=copy(a);b.body.rotation[1].onFalse=b.body.rotation[1].onTrue;b.body.rotation[1].onTrue={}
record('cross-arm-transfer-is-remove-add',a,b,nil,function(r)assert(#r.changes==2 and find(r,'removed')and find(r,'added')and not find(r,'moved'))end)
a,b=envelope(),envelope();b.body.rotation[1].conditions.onTrue={{value=4}}
record('arm-looking-custom-condition-field-is-ordinary',a,b,nil,function(r)assert(#r.changes==1 and find(r,'added','$.body.rotation[step-1].conditions.onTrue'))end)
a,b=envelope(),envelope();b.body.rotation[2]={id='two',type='spell',action=529}
record('origin-collision-refuses-all-output',a,b,{rightOrigins={['step-1']='same',two='same'}},function(r)assert(not r.valid and #r.changes==0 and r.diagnostics[1].code=='ambiguous-step-identity')end)
a,b=envelope(),envelope();b.body.cooldowns={{id='step-1',type='spell',action=529}}
record('duplicate-id-across-sections-refuses-all-output',a,b,nil,function(r)assert(not r.valid and #r.changes==0 and r.diagnostics[1].code=='ambiguous-step-identity')end)
a,b=envelope(),envelope();b.body.rotation=false
record('false-list-is-invalid-not-empty',a,b,nil,function(r)assert(not r.valid and #r.changes==0 and r.diagnostics[1].code=='invalid-priority-list')end)
a,b=envelope(),envelope();a['a.\000\255"']=1;b['a.\000\255"']=2
record('byte-key-quoting-retained-with-typed-segment',a,b,nil,function(r)assert(#r.changes==1 and r.changes[1].segments[1].key=='a.\000\255"')end)
a,b={},{body={}}
record('missing-body-versus-empty-body-is-observed',a,b,nil,function(r)assert(#r.changes==1 and r.changes[1].kind=='added'and r.changes[1].path=='$.body')end)
a,b=envelope(),envelope();a.body.rotation={};b.body.rotation={}
for i=1,501 do a.body.rotation[i]={id='s'..i,type='spell',action=1};b.body.rotation[i]={id='s'..i,type='spell',action=2}end
record('change-budget-explicit-incomplete',a,b,nil,function(r)assert(r.valid and not r.complete and #r.changes==500 and r.diagnostics[1].code=='diff-change-limit')end,false)
a,b=envelope(),envelope();local k=string.rep('k',4097);a[k]=1;b[k]=2
record('display-path-budget-explicit-incomplete',a,b,nil,function(r)assert(r.valid and not r.complete and #r.changes==0 and r.diagnostics[1].code=='diff-path-limit')end,false)
local r=data.DiffRotations({body={rotation={}}},{body={rotation={}}});r.changes[1]={kind='fake'};assert(#data.DiffRotations({body={rotation={}}},{body={rotation={}}}).changes==0);passed=passed+1
if not codec then print('PASS detached-result-control');print(passed..' passed, 0 failed')end
