-- Strict exact callback/module inverse; actual baseline4df0568.
local old="\n        if type(UnitExists)~=\"function\" then return nil,\"missing-api\" end\n        local ok,exists=pcall(UnitExists,value.unit)\n        if not ok then return nil,\"api-error\" end\n        if not addon.Platform:CanReadValue(exists) then return nil,\"restricted-value\" end\n        if exists==nil or exists==false then return false end\n        if exists~=true and exists~=1 then return nil,\"invalid-api-result\" end\n        return addon.Platform:IsBeyondMeleeRange(value.unit)\n    "
local repaired="\n        if type(UnitExists)~=\"function\" then return nil,\"missing-api\" end\n        local ok,exists=pcall(UnitExists,value.unit)\n        if not ok then return nil,\"api-error\" end\n        if not addon.Platform:CanReadValue(exists) then return nil,\"restricted-value\" end\n        if exists==nil then return nil,'unit-data-unavailable' end\n        if exists==false then return false end\n        if exists~=true and exists~=1 then return nil,\"invalid-api-result\" end\n        return addon.Platform:IsBeyondMeleeRange(value.unit)\n    "
local function inverse(text,callback)
 assert(type(text)=='string','source text required')
 if callback then assert(text==repaired,'unexpected complete BEYOND_MELEE evaluator');return old end
 local from='evaluate=function(value)'..repaired..'end,'
 local to='evaluate=function(value)'..old..'end,'
 local a,b=text:find(from,1,true);assert(a and not text:find(from,b+1,true),'missing or duplicate complete evaluator')
 text=text:sub(1,a-1)..to..text:sub(b+1)
 local h=5381;for i=1,#text do h=(h*33+text:byte(i))%4294967296 end
 assert(#text==2171 and string.format('%08x',h)=='a20f894d','unrelated complete range source delta')
 return text
end
return inverse,old,repaired
