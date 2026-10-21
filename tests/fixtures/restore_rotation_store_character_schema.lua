-- Strict additive inverse: immutable character-bucket allowlist only.
local function hash(s)local n=5381;for i=1,#s do n=(n*33+s:byte(i))%4294967296 end;return string.format('%08x',n)end
return function(text,path)
 if path~='Data/rotation_store.lua'then return text end
 assert(#text==41033 and hash(text)=='fa04f55b','unrelated character-schema source')
 local declaration='local characterBucketFields={class=true,specs=true}\n'
 local a,b=assert(text:find(declaration,1,true));assert(not text:find(declaration,b+1,true),'duplicate character-schema declaration');text=text:sub(1,a-1)..text:sub(b+1)
 local old='fields(bucket,characterBucketFields)';local replacement='fields(bucket,{class=true,specs=true})';local count=0
 text=text:gsub('fields%(bucket,characterBucketFields%)',function()count=count+1;return replacement end);assert(count==3,'character-schema occurrence mismatch')
 assert(#text==40987 and hash(text)=='9d678565','character-schema predecessor mismatch')
 return text
end
