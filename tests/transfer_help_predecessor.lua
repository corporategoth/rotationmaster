-- Exact whole-file inverse of this bounded Help slice; rejects any other source.
local function hash(s)local n=5381;for i=1,#s do n=(n*33+s:byte(i))%4294967296 end;return n end
local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
do
local s=read('UI/settings_transfer.lua')
assert(#s==14228 and hash(s)==3054127884,'current source changed: UI/settings_transfer.lua')
s=s:sub(1,14154)..([[!]]):sub(2)..s:sub(14215)
s=s:sub(1,6500)..([[!]]):sub(2)..s:sub(6543)
s=s:sub(1,6108)..([[!]]):sub(2)..s:sub(6114)
s=s:sub(1,235)..([[!]]):sub(2)..s:sub(3551)
assert(#s==10806 and hash(s)==1773681860,'predecessor changed: UI/settings_transfer.lua')
print('PASS exact whole-file predecessor UI/settings_transfer.lua')
end
do
local s=read('UI/settings_profiles.lua')
assert(#s==11740 and hash(s)==2703702999,'current source changed: UI/settings_profiles.lua')
s=s:sub(1,5930)..([[!]]):sub(2)..s:sub(6616)
assert(#s==11055 and hash(s)==1700879846,'predecessor changed: UI/settings_profiles.lua')
print('PASS exact whole-file predecessor UI/settings_profiles.lua')
end
do
local s=read('UI/transfer.lua')
assert(#s==9566 and hash(s)==3590293502,'current source changed: UI/transfer.lua')
s=s:sub(1,4559)..([[!]]):sub(2)..s:sub(4963)
s=s:sub(1,2114)..([[!]]):sub(2)..s:sub(2701)
s=s:sub(1,2041)..([[!]]):sub(2)..s:sub(2114)
assert(#s==8505 and hash(s)==3763098304,'predecessor changed: UI/transfer.lua')
print('PASS exact whole-file predecessor UI/transfer.lua')
end
do
local s=read('UI/function_bundle_transfer.lua')
assert(#s==16439 and hash(s)==2749059124,'current source changed: UI/function_bundle_transfer.lua')
s=s:sub(1,14992)..([[!]]):sub(2)..s:sub(15570)
s=s:sub(1,14948)..([[!]]):sub(2)..s:sub(14992)
s=s:sub(1,4904)..([[!;]]):sub(2)..s:sub(5204)
s=s:sub(1,3900)..([[!]]):sub(2)..s:sub(4520)
assert(#s==14902 and hash(s)==4281164234,'predecessor changed: UI/function_bundle_transfer.lua')
print('PASS exact whole-file predecessor UI/function_bundle_transfer.lua')
end
