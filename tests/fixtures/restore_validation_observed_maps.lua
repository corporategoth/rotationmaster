-- Strict whole-module inverse of the private retained-map eligibility guard.
local addition=[==[    -- Public option copying uses live pairs; a prior override can retain its
    -- private input maps. Their later lookups must remain callback-free too.
    if not proofPlain(observed) or not proofPlain(stamp)
        or not proofPlain(proofRawget(observed,'itemsets'))
        or not proofPlain(proofRawget(observed,'conditions'))
        or not proofPlain(proofRawget(observed,'effects')) then return end
]==]
return function(text,path)
 if path~='Core/rotation_references.lua' then return text end
 local first,last=text:find(addition,1,true)
 assert(first and not text:find(addition,last+1,true),'missing or duplicate retained-map proof')
 local old=text:sub(1,first-1)..text:sub(last+1);local hash=5381
 for i=1,#old do hash=(hash*33+old:byte(i))%4294967296 end
 assert(#old==10959 and string.format('%08x',hash)=='fe39d6e6','unrelated retained-map source delta')
 return old
end
