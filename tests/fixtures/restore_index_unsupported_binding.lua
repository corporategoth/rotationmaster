-- Strict inverse of the once-bound unsupported execution reader from b135a21.
local old='    bind(read,retire,indexStatus)'
local current=[=[    local reader=read
    if indexType(indexStringMethods)~="table" then
        reader=function(body,profile,namespace,db) retire();return false end
    end
    bind(reader,retire,indexStatus)]=]
return function(text)
 assert(type(text)=='string','unsupported-reader inverse needs source')
 local first,last=text:find(current,1,true)
 assert(first and not text:find(current,last+1,true),'missing or duplicate unsupported-reader binding')
 local restored=text:sub(1,first-1)..old..text:sub(last+1)
 local hash=0;for i=1,#restored do hash=(hash*33+restored:byte(i))%4294967296 end
 assert(#restored==13523 and string.format('%08x',hash)=='1ff5be45','unrelated unsupported-reader source delta')
 return restored
end
