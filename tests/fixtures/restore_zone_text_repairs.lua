-- Strict single-evaluator inverse; complete authored baselinefe3d3a0.
local old="\n        local zoneName = value.subzone and Functions.cache.getCached(cache, GetSubZoneText) or Functions.cache.getCached(cache, GetZoneText)\n        return value.value == zoneName\n    "
local repaired="\n        local method\n        if value.subzone then method=GetSubZoneText else method=GetZoneText end\n        if type(method)~='function' then return nil,'missing-api' end\n        local ok,zoneName=pcall(Functions.cache.getCached,cache,method)\n        if not ok then return nil,'api-error' end\n        if not addon.Platform:CanReadValue(zoneName) then return nil,'restricted-value' end\n        if type(zoneName)~='string' then return nil,'zone-text-unavailable' end\n        return value.value == zoneName\n    "
local function inverse(text,callback)
 assert(type(text)=='string','expected source text')
 if callback then assert(text==repaired,'unexpected complete ZONE evaluator');return old end
 local from='evaluate = function(value, cache)'..repaired..'end,'
 local to='evaluate = function(value, cache)'..old..'end,'
 local a,b=text:find(from,1,true);assert(a and not text:find(from,b+1,true),'missing or duplicate complete ZONE evaluator')
 text=text:sub(1,a-1)..to..text:sub(b+1)
 local h=5381;for i=1,#text do h=(h*33+text:byte(i))%4294967296 end
 assert(#text==24669 and string.format('%08x',h)=='2b643bde','unrelated complete spatial source delta')
 return text
end
return inverse,old,repaired
