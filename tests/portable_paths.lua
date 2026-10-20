local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local inverse,old,repaired=dofile('tests/fixtures/restore_portable_paths.lua')
local function read(path) local h=assert(io.open(path));local text=h:read('*a');h:close();return text end
local source=dofile('tests/fixtures/restore_rotation_execution_index.lua')(dofile('tests/fixtures/restore_rotation_execution_diagnostics.lua')(read('Data/plain.lua'),'Data/plain.lua'),'Data/plain.lua')
local function fixture()
 local f=F.new();f.load('Data/plain.lua');local a=f.addon
 local previous=source
 if previous:find(repaired,1,true) then previous=inverse(previous) else assert(previous:find(old,1,true),'unknown portable baseline') end
 local reference={};local chunk=assert(loadstring(previous,'@frozen-portable-before'));setfenv(chunk,f.env);chunk('rotationmaster',reference)
 return f,a.RotationData,reference.RotationData
end
local function pack(...) return {n=select('#',...),...} end
local function sameResult(current,previous,value)
 local one,two=pack(current.CheckPortable(value)),pack(previous.CheckPortable(value))
 assert(one.n==two.n and one[1]==two[1],'portable return tuple changed')
 if one[2] then for _,key in ipairs({'code','path','severity'}) do assert(one[2][key]==two[2][key],key..' changed: '..tostring(one[2][key])..' / '..tostring(two[2][key])) end end
 return one
end
local function formatted(fn,value)
 local calls=0;local hook,mask,count=debug.gethook();local compiling=jit and jit.status()
 if jit then jit.off();jit.flush() end
 debug.sethook(function(event) if event=='call' then local info=debug.getinfo(2,'f');if info.func==string.sub then calls=calls+1 end end end,'c')
 local ok,result=pcall(fn,value)
 if hook then debug.sethook(hook,mask,count) else debug.sethook() end
 if compiling then jit.on() end
 assert(ok,result);assert(result==true);return calls
end
test('successful validation does not format diagnostic paths for every field',function()
 local _,data,previous=fixture();local value={}
 for i=1,40 do value['field_'..i]={name='Spell '..i,amount=i,enabled=i%2==0} end
 local baseline=formatted(previous.CheckPortable,value);assert(baseline>=120,'frozen path work not reproduced')
 assert(formatted(data.CheckPortable,value)==0,'successful validation still formats error paths')
end)
test('valid scalars nested tables and shared aliases retain exact success tuples and copies',function()
 local _,data,previous=fixture()
 for _,value in ipairs({false,true,0,-1,1.25,'',{}, {a={b={1,false,'text'}}}}) do assert(sameResult(data,previous,value)[1]) end
 assert(sameResult(data,previous,nil)[1]);local shared={value=7};local value={a=shared,b=shared}
 assert(sameResult(data,previous,value)[1]);local copy=assert(data.CopyData(value));assert(copy.a==copy.b and copy.a~=shared and copy.a.value==7)
end)
test('malformed values keys metatables cycles and long names keep exact diagnostic paths',function()
 local _,data,previous=fixture();local cycle={};cycle.next=cycle
 local values={0/0,math.huge,-math.huge,function() end,coroutine.create(function() end),setmetatable({},{__index={}}),cycle,{[false]=1},{[0]=1},{[1.5]=1},{bad=function() end}}
 local key=string.rep('a',100);values[#values+1]={[key]={bad=function() end}}
 values[#values+1]={[string.rep('界',40)]={bad=math.huge}}
 values[#values+1]={a={bad=function() end},z=math.huge}
 for _,value in ipairs(values) do assert(sameResult(data,previous,value)[1]==false) end
 local result=sameResult(data,previous,{[key]={bad=function() end}});assert(result[2].path=='$.'..key:sub(1,80)..'.bad')
end)
test('depth node string and byte limits preserve parent versus child error locations',function()
 local _,data,previous=fixture();local root={};local leaf=root;for i=1,66 do leaf.next={};leaf=leaf.next end
 assert(sameResult(data,previous,root)[2].code=='data-depth-limit')
 assert(sameResult(data,previous,{[string.rep('k',262145)]=1})[2].path=='$')
 assert(sameResult(data,previous,{nested=string.rep('v',262145)})[2].path=='$.nested')
 local wide={};for i=1,10001 do wide[i]=true end;assert(sameResult(data,previous,wide)[2].code=='data-node-limit')
 local bytes={};for i=1,5 do bytes[i]=string.rep('x',220000) end;assert(sameResult(data,previous,bytes)[2].code=='data-byte-limit')
 local shared={text=string.rep('x',220000)};local aliases={shared,shared,shared,shared,shared};assert(sameResult(data,previous,aliases)[2].code=='data-byte-limit','shared aliases stopped being revisited')
end)
test('bounded generated mixed data keeps exact frozen validation decisions and paths',function()
 local _,data,previous=fixture();local seed=17
 local function random(n) seed=(seed*48271)%2147483647;return seed%n+1 end
 local function value(depth)
  local choice=random(depth>3 and 8 or 12)
  if choice==1 then return false elseif choice==2 then return true elseif choice==3 then return random(100)-50 elseif choice==4 then return 'text'..random(100) elseif choice==5 then return math.huge elseif choice==6 then return function() end elseif choice==7 then return nil elseif choice==8 then return 0/0 end
  local result={};for i=1,random(4) do local key=random(2)==1 and i or 'key'..random(20);result[key]=value(depth+1) end;return result
 end
 for _=1,2000 do sameResult(data,previous,value(0)) end
end)
test('strict inverse protects all other portable and copy source bytes',function()
 local f=fixture();f.load('Core/function_data.lua');local function hash(text) return f.addon:FunctionSourceHash(text) end
 assert(hash(inverse(source,hash))=='12133044')
 assert(not pcall(inverse,old,hash) and not pcall(inverse,source..source,hash) and not pcall(inverse,source..'\n-- extra change\n',hash))
end)
finish()
