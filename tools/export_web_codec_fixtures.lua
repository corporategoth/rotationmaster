-- Golden oracle only: run from repository root with actual LuaJIT/bit.
-- Bundled vendors stay unchanged and are not shipped inside the Web codec.
-- Output is a snapshot: Lua table/compressor ordering need not be byte-stable across runs.
local bit=require('bit')
local data,deps,calls,lib,serializer=dofile('tests/fixtures/codec.lua')()
local codec=assert(data.NewCodec(deps))
local function quote(s)
 return '"'..s:gsub('[%z\1-\31\\"]',function(c) return string.format('\\u%04x',c:byte()) end)..'"'
end
local function hex(s) return (s:gsub('.',function(c) return string.format('%02x',c:byte()) end)) end
local function numberBits(n)
 local negative=n<0 or n==0 and 1/n<0;n=math.abs(n)
 local exponent,mantissa=0,0
 if n~=0 then
  local m,e=math.frexp(n)
  if e<=-1022 then mantissa=n/2^-1074
  else exponent=e+1022;mantissa=(m*2-1)*2^52 end
 end
 local high=(negative and 2147483648 or 0)+exponent*1048576+math.floor(mantissa/4294967296)
 return string.format('%08x%08x',high,mantissa%4294967296)
end
local function tree(v)
 local t=type(v)
 if t=='string' then return '{"type":"bytes","hex":'..quote(hex(v))..'}' end
 if t=='number' then return '{"type":"number","bits":'..quote(numberBits(v))..'}' end
 if t=='boolean' then return '{"type":"boolean","value":'..tostring(v)..'}' end
 assert(t=='table');local keys={};for k in pairs(v) do keys[#keys+1]=k end
 table.sort(keys,function(a,b) if type(a)~=type(b) then return type(a)=='number' end return a<b end)
 local entries={};for _,k in ipairs(keys) do entries[#entries+1]='['..tree(k)..','..tree(v[k])..']' end
 return '{"type":"table","entries":['..table.concat(entries,',')..']}'
end
local goldens,probes={},{}
local function golden(id,text)
 local d,why=codec:Decode(text);assert(d,id..':'..tostring(why))
 goldens[#goldens+1]='{"id":'..quote(id)..',"text":'..quote(text)..',"kind":'..quote(d.kind)..',"expected":'..tree(d.value)..'}'
end
for _,v in ipairs(dofile('tests/fixtures/legacy_rotation_exports.lua')) do golden('original90083-'..tostring(v.codec or v.name or #goldens+1),v.text) end
local value={name='Protocol 雪',rotation={},cooldowns={},disabled=false,[1]='numeric',['1']='string',
 ['__proto__']='inert',constructor='inert',bytes=string.char(0,30,31,32,94,126,127,128,255),
 source='error("MUST NEVER EXECUTE")',zero=0,fraction=0.125}
for i=1,30 do value.rotation[i]={id='step-'..i,type='spell',action=403,conditions={type='AND',value={{type='NOT',value={type='BUFF',unit='player',spell='Lightning Shield'}},{type='COMBAT',value=false}}}} end
local raw=serializer:Serialize(value)
for _,mode in ipairs({'Store','CompressLZW','CompressHuffman'}) do
 local stream=assert(lib[mode](lib,raw));local tag=stream:byte(1)
 assert(tag==({Store=1,CompressLZW=2,CompressHuffman=3})[mode],mode..' fell back')
 golden(mode..'-bytes-map',assert(data.EncodeBase64(stream)))
end
local C=dofile('tests/fixtures/default_corpus.lua');local f,packs=C.load(5,2,'SHAMAN')
for _,v in ipairs(packs) do if v.id:find('shaman',1,true) then golden('current-reviewed-'..v.id,assert(codec:Encode(v)));break end end
local function probe(id,raw)
 local text=assert(data.EncodeBase64(string.char(1)..raw));local v,why=codec:Decode(text)
 probes[#probes+1]='{"id":'..quote(id)..',"text":'..quote(text)..',"rawHex":'..quote(hex(raw))..',"accepted":'..tostring(v~=nil)..(v and ',"expected":'..tree(v.value) or ',"reason":'..quote(why))..'}'
end
for _,n in ipairs({'','+1','01','1e2','0x10','0x1p2','nan','inf','-0','1.2.3','.5','1.','+0x10','-0x10','0XFF','0x1.8','0x1p-1074','1E+2','NaN','NAN','+nan','-nan','INF','Infinity','infinity','+inf','1.#INF','-1.#INF','0x.p2','0x1p','0x100000000000008p-4','0x1fffffffffffffp-1075'}) do probe('number-'..n,'^1^T^Sk^N'..n..'^t^^') end
for _,s in ipairs({'~a','~','~?','~@','~{','~|','~}','~~','~z'}) do probe('escape-'..s,'^1^T^Sk^S'..s..'^t^^') end
probe('ignored-token-data','^1extension^Tfuture^Sk^Bignored^tignored^^trailing')
probe('duplicate-key-last-wins','^1^T^Sk^N1^Sk^N2^t^^')
probe('nil-value','^1^T^Sk^Z^t^^')
probe('negative-numeric-key','^1^T^N-1^Sv^t^^')
probe('zero-numeric-key','^1^T^N0^Sv^t^^')
probe('float-mac-inf-mantissa','^1^T^Sk^F1.#INF^f0^t^^')
probe('float-mac-inf-exponent','^1^T^Sk^F1^f1.#INF^t^^')
probe('float-normal','^1^T^Sk^F3^f-1^t^^')
probe('float-subnormal-intermediate','^1^T^Sk^F4503599627370496^f-1126^t^^')
probe('float-nonfinite','^1^T^Sk^F1^f1024^t^^')
local h=assert(lib:CompressHuffman(raw));local truncations={}
for n=1,math.min(8,#h-5) do
 local v,why=codec:Decode(assert(data.EncodeBase64(h:sub(1,#h-n))))
 truncations[#truncations+1]='{"bytesRemoved":'..n..',"text":'..quote(assert(data.EncodeBase64(h:sub(1,#h-n))))..',"accepted":'..tostring(v~=nil)..(v and ',"expected":'..tree(v.value) or ',"reason":'..quote(why))..'}'
end
local generated={}
if arg and arg[1]=='--differential' then
 local seed=1977
 local function rand(n) seed=(seed*48271)%2147483647;return seed%n end
 local function emit(id,v)
  local text=assert(codec:Encode(v));local decoded=assert(codec:Decode(text))
  generated[#generated+1]='{"id":'..quote(id)..',"text":'..quote(text)..',"expected":'..tree(decoded.value)..'}'
 end
 for i=1,64 do
  local v={['__proto__']='inert',index=i,[1]=false,['1']=0,rows={}}
  for j=1,rand(12)+1 do
   local chars={};for _=1,rand(40) do chars[#chars+1]=string.char(rand(256)) end
   v.rows[j]={id='node-'..j,text=table.concat(chars),number=(rand(200000)-100000)/2^rand(20),enabled=rand(2)==0,nested={}}
  end
  emit('generated-'..i,v)
 end
 for _,n in ipairs({0,-0.0,1e-5,1e-4,1e16,1e17,1/3,2^-1074,2^-1022,1.7976931348623157e308}) do emit('float-'..string.format('%.17g',n),{n=n}) end
end
local compressedProbes={}
local function compressed(id,stream)
 local text=assert(data.EncodeBase64(stream));local d,why=codec:Decode(text)
 compressedProbes[#compressedProbes+1]='{"id":'..quote(id)..',"text":'..quote(text)..',"accepted":'..tostring(d~=nil)..(d and ',"expected":'..tree(d.value) or ',"reason":'..quote(why))..'}'
end
compressed('lzw-expansion-over',assert(lib:CompressLZW(string.rep('a',1048577))))
for _,value in ipairs({'a','aa','aaaa',string.rep('a',200),string.rep(string.char(0,255,128),100),string.rep('abababa',100)}) do
 local v={text=value};local rawValue=serializer:Serialize(v)
 compressed('lzw-special-'..#compressedProbes,assert(lib:CompressLZW(rawValue)))
 compressed('huffman-special-'..#compressedProbes,assert(lib:CompressHuffman(rawValue)))
end
local mutations={}
if arg and arg[1]=='--adversarial' then
 local sourceRaw=serializer:Serialize({text=string.rep('abc',80),zero=0,enabled=false,rotation={{id='a',type='none'}}})
 local function mutation(id,stream)
  local text=assert(data.EncodeBase64(stream));local d,why=codec:Decode(text)
  mutations[#mutations+1]='{"id":'..quote(id)..',"text":'..quote(text)..',"accepted":'..tostring(d~=nil)..(d and ',"expected":'..tree(d.value) or ',"reason":'..quote(why))..'}'
 end
 for _,mode in ipairs({'Store','CompressLZW','CompressHuffman'}) do
  local stream=assert(lib[mode](lib,sourceRaw))
  for index=1,math.min(96,#stream) do
   local at=1+(index*37)%#stream
   local byte=bit.bxor(stream:byte(at),2^(index%8))
   mutation(mode..'-flip-'..index,stream:sub(1,at-1)..string.char(byte)..stream:sub(at+1))
  end
  for n=1,math.min(24,#stream) do mutation(mode..'-truncate-'..n,stream:sub(1,#stream-n)) end
 end
end
io.write('{"baseline":"2c2a97962b01a6c08607e33c2b280e222a891205","runtime":',quote(jit.version),',"mutations":['..table.concat(mutations,',')..'],"generated":['..table.concat(generated,',')..'],"compressedProbes":['..table.concat(compressedProbes,',')..'],"goldens":[',table.concat(goldens,','),'],"probes":[',table.concat(probes,','),'],"huffmanTruncations":[',table.concat(truncations,','),']}\n')
