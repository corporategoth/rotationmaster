-- Strict inverse of the post-AceDB cache diagnostic initialization only.
local block=[=[    -- BEGIN CACHE DIAGNOSTIC INITIALIZATION
    if type(self.InitializeCacheDiagnosticMode)=="function" then
        self:InitializeCacheDiagnosticMode(self.db.global)
    end
    -- END CACHE DIAGNOSTIC INITIALIZATION
]=]
return function(text)
 assert(type(text)=='string','cache initialization inverse needs main source')
 local first,last=text:find(block,1,true)
 assert(first and not text:find(block,last+1,true),'missing or duplicate cache initialization')
 local old=text:sub(1,first-1)..text:sub(last+1)
 local hash=5381;for i=1,#old do hash=(hash*33+old:byte(i))%4294967296 end
 assert(#old==66250 and string.format('%08x',hash)=='9c155686','unexpected main source outside cache initialization')
 return old
end
