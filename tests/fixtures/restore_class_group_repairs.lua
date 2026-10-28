-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Exact test-only inverse of the approved CLASS_GROUP evaluator.
local old = [=[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, IsInGroup) then
            return Functions.values.compare(value.operator, (character_class == value.class and 1 or 0), value.value)
        end

        local count = 0
        local prefix, size = "party", 4
        if value.raid and Functions.cache.getCached(cache, IsInRaid) then
            prefix, size = "raid", 40
        end
        if prefix == "party" and character_class == value.class then
            count = count + 1
        end
        for i=1,size do
            if select(2, Functions.cache.getCached(cache, UnitClass, prefix .. tostring(i))) == value.class then
                count = count + 1
            end
        end
        return Functions.values.compare(value.operator, count, value.value)
    end,]=]

local repaired = [=[    evaluate = function(value, cache)
        local count,reason=addon:GetClassGroupCount(cache,value.class,value.raid)
        if count==nil then return nil,reason end
        return Functions.values.compare(value.operator,count,value.value)
    end,]=]

return function(text, body)
    if body then
        local before = assert(repaired:match('^    evaluate = function%([^\n]*%)(.*)end,$'))
        local after = assert(old:match('^    evaluate = function%([^\n]*%)(.*)end,$'))
        assert(text == before, 'unexpected CLASS_GROUP evaluate bytes')
        return after
    end

    local first = assert(text:find(repaired, 1, true), 'exact CLASS_GROUP repair missing')
    assert(not text:find(repaired, first + 1, true), 'duplicate CLASS_GROUP repair')
    return text:sub(1, first - 1) .. old .. text:sub(first + #repaired)
end
