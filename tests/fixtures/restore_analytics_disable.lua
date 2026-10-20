-- Strict cold lifecycle inverse; historical CPU snapshots stay byte-identical.
local block=" if type(self.ClearCastCaptureForDisable)=='function' then self:ClearCastCaptureForDisable() end\n"
local function hash(s)local h=0;for i=1,#s do h=(h*33+s:byte(i))%4294967296 end;return string.format('%08x',h)end
return function(text,path)
 assert(path=='Diagnostics/cpu.lua','unknown cast shutdown inverse path')
 assert(type(text)=='string'and#text==55206 and hash(text)=='5eeec9b5','unrelated cast shutdown module change')
 local a,b=text:find(block,1,true);assert(a,'cast shutdown block changed')
 assert(not text:find(block,b+1,true),'duplicate cast shutdown block')
 local old=text:sub(1,a-1)..text:sub(b+1)
 assert(#old==55109 and hash(old)=='785d8fa6','cast shutdown predecessor mismatch')
 return old
end
