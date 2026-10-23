-- Trusted offline source registration/export only; never loaded by the addon/Web.
-- Primary typed JSON is deterministic. Actual codec fixture bytes need not be.
local M={}
local arrays=setmetatable({},{__mode='k'})
local function array(v)arrays[v]=true;return v end
local function sorted(v)local t={};for k in pairs(v)do t[#t+1]=k end;table.sort(t,function(a,b)if type(a)==type(b)then return a<b end;return type(a)=='number'end);return t end
local function quote(s)return '"'..s:gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',c:byte())end)..'"'end
local function json(v)
 local t=type(v);if t=='string'then return quote(v)elseif t=='boolean'then return tostring(v)elseif t=='number'then assert(v==v and v<math.huge and v>-math.huge);return string.format('%.17g',v)end
 assert(t=='table'and getmetatable(v)==nil);local out={}
 if arrays[v]then for _,x in ipairs(v)do out[#out+1]=json(x)end;return '['..table.concat(out,',')..']'end
 for _,k in ipairs(sorted(v))do assert(type(k)=='string');out[#out+1]=quote(k)..':'..json(v[k])end;return '{'..table.concat(out,',')..'}'
end
local function numberBits(n)
 local sign=n<0 or n==0 and 1/n<0;n=math.abs(n);local exponent,mantissa=0,0
 if n~=0 then local m,e=math.frexp(n);if e<=-1022 then mantissa=n/2^-1074 else exponent=e+1022;mantissa=(m*2-1)*2^52 end end
 return string.format('%08x%08x',(sign and 2147483648 or 0)+exponent*1048576+math.floor(mantissa/4294967296),mantissa%4294967296)
end
local function typed(v)
 local t=type(v)
 if t=='nil'then return{type='nil'}elseif t=='string'then return{type='bytes',hex=(v:gsub('.',function(c)return string.format('%02x',c:byte())end))}
 elseif t=='boolean'then return{type='boolean',value=v}elseif t=='number'then return{type='number',bits=numberBits(v)}end
 assert(t=='table'and not getmetatable(v));local entries=array({});for _,k in ipairs(sorted(v))do entries[#entries+1]=array({typed(k),typed(v[k])})end;return{type='table',entries=entries}
end
local function safePath(path)
 return type(path)=='string'and path:match('^[A-Za-z0-9_./%-]+$')and path:sub(1,1)~='/'and not path:find('//',1,true)and not ('/'..path..'/'):find('/../',1,true)and not ('/'..path..'/'):find('/./',1,true)
end
local function sha(path)
 assert(safePath(path),'unsafe fixed source path');local p=assert(io.popen('sha256sum '..path,'r'));local s=assert(p:read('*l'));assert(p:close());local hash=s:match('^([0-9a-f]+) ');assert(hash and #hash==64);return hash
end
local modules={'globals.lua','Libs/LibStub/LibStub.lua','Libs/AceLocale-3.0/AceLocale-3.0.lua','Locales/enUS.lua',
 'Data/plain.lua','Data/rotation_revision.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua','Core/imports.lua'}
function M.build()
 local a,env={RotationData={},Platform={}},{ }
 -- Only configured enUS selection is supplied to AceLocale. No game locale,
 -- player fact, metadata/provider or recommendation callback is observed.
 for _,k in ipairs({'assert','error','getmetatable','setmetatable','rawget','rawset','rawequal','type','pairs','ipairs','next','tonumber','tostring','unpack','select','pcall','xpcall','math','string','table','getfenv','setfenv'})do env[k]=_G[k]end
 env._G=env;env.GAME_LOCALE='enUS';env.GetLocale=function()return'enUS'end
 env.geterrorhandler=function()return function()error('missing source translation',0)end end
 setmetatable(env,{__index=function(_,key)if key=='NORMAL_FONT_COLOR_CODE'or key=='LibStub'then return nil end;error('unsupported offline module global '..tostring(key),0)end})
 local function load(path,scope)local f=assert(loadfile(path));setfenv(f,scope or env);f('rotationmaster',a)end
 for _,path in ipairs(modules)do load(path)end
 local data,locale=a.RotationData,env.LibStub('AceLocale-3.0'):GetLocale('rotationmaster')
 local generation={};a.db={profile={rotations={}},global={}}
 a.GetRotationValidationOptions=function()return{},generation end;a.GetRotationValidationStamp=function()return generation end
 local paths,seenPaths={},{}
 for line in io.lines('RotationMaster.toc')do local path=line:gsub('\r',''):match('^%s*(Defaults/.-%.lua)%s*$');if path then assert(safePath(path)and not seenPaths[path],'unsafe/duplicate default source');seenPaths[path]=true;paths[#paths+1]=path end end
 assert(#paths>0 and #paths<=256,'bundled record limit')
 local captured,current,seen={},nil,{};local register=a.RegisterDefaultRotation
 a.RegisterDefaultRotation=function(self,value)
  local ok,why=register(self,value);assert(ok,why);assert(not seen[value.id],'duplicate pack id');seen[value.id]=true
  local scope=value.applicability;assert(scope.class or scope.universal==true,'explicit declared class/universal required')
  for _,key in ipairs({'nameKey','descriptionKey'})do assert(not value[key]:find('[\128-\255]'),'ASCII symbolic display key required');local display=rawget(locale,value[key]);assert(type(display)=='string'and #display>0 and #display<=262144,'missing/oversized enUS display')end
  -- Built In composition: the catalog carries the expanded tree registration consumes.
  captured[#captured+1]={path=current,value=assert(a:ExpandDefaultRotation(value))};return ok
 end
 -- Reviewed pack constructors can build data through the production registrar.
 -- Imported source is never accepted and pack globals cannot query native APIs.
 local packEnv=setmetatable({assert=assert,ipairs=ipairs,pairs=pairs,type=type},{__index=function(_,key)error('unsupported pack global '..tostring(key),0)end})
 -- Shared block sources register no pack; they are hashed inputs like every pack source.
 a.loadAllDefaults=true -- the catalog covers every edition
 for _,path in ipairs(paths)do current=path;local count=#captured;load(path,packEnv);assert(#captured==count+(path:match('^Defaults/blocks/')and 0 or 1),'exactly one pack per source required')end
 assert(a:InitializeRotationLibrary())
 local output={format='RotationMasterBundledDefaults',version=1,scope='declared-data-only',displayLocale='enUS',nativeAvailability='unverified',sourceFiles={},packs=array({})}
 local inputs={'RotationMaster.toc','tools/export_web_defaults.lua','Data/codec.lua','tests/fixtures/codec.lua','Libs/AceSerializer-3.0/AceSerializer-3.0.lua','Libs/LibCompress/LibCompress.lua'}
 for _,path in ipairs(modules)do inputs[#inputs+1]=path end;for _,path in ipairs(paths)do inputs[#inputs+1]=path end
 for _,path in ipairs(inputs)do output.sourceFiles[path]=sha(path)end
 table.sort(captured,function(x,y)return x.value.id<y.value.id end)
 for _,record in ipairs(captured)do
  local original=record.value;local normalized=assert(a:GetDefaultRotation(original.id)).envelope
  local exported=assert(a:GetRotationExportData(0,'RM-BUILTIN:'..original.id))
  local function same(x,y)if type(x)~=type(y)then return false end;if type(x)~='table'then return x==y end;for k,v in pairs(x)do if not same(v,y[k])then return false end end;for k in pairs(y)do if x[k]==nil then return false end end;return true end
  assert(same(original,normalized)and same(normalized,exported),'source/export normalization changed manifest')
  assert(data.CheckPortable(exported));assert(data.IndexRotationSteps(exported.body));assert(data.ValidateEnvelope(exported).valid)
  output.packs[#output.packs+1]={id=original.id,sourcePath=record.path,sourceSHA=output.sourceFiles[record.path],
   display={nameKey=original.nameKey,descriptionKey=original.descriptionKey,name=rawget(locale,original.nameKey),description=rawget(locale,original.descriptionKey)},envelope=typed(exported)}
  record.value=exported
 end
 local encoded=json(output);assert(#encoded+1<=8388608,'catalog text limit');return output,captured
end
function M.fixtures()
 assert(jit,'actual wire fixtures require LuaJIT/bit')
 local _,captured=M.build();local data,deps=dofile('tests/fixtures/codec.lua')();local codec=assert(data.NewCodec(deps));local records=array({})
 for _,record in ipairs(captured)do local wire=assert(codec:Encode(record.value));local decoded=assert(codec:Decode(wire));assert(decoded.kind=='envelope');assert(json(typed(decoded.value))==json(typed(record.value)),'codec roundtrip differs')
  records[#records+1]={id=record.value.id,sourcePath=record.path,sourceSHA=sha(record.path),wire=wire,expected=typed(record.value)}
 end
 return{format='RotationMasterBundledDefaultWireFixtures',version=1,records=records}
end
M.json=json
if arg and arg[0]=='tools/export_web_defaults.lua'then print(json(arg[1]=='--fixtures'and M.fixtures()or M.build()))end
return M
