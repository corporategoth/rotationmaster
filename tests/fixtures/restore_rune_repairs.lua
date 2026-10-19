-- Strict test-only inverse for exactly the two approved rune evaluators.
local original={}
local repaired={}
original['RUNE']=[=[        evaluate = function(value, cache)
            local count = 0
            for i=1,6 do
                if Functions.cache.getCached(cache, GetRuneType, i) == value.rune then
                    if select(3, Functions.cache.getCached(cache, GetRuneCooldown, i)) then count = count + 1 end
                end
            end
            return Functions.values.compare(value.operator, count, value.value)
        end,]=]
repaired['RUNE']=[=[        evaluate = function(value, cache)
            local count = 0
            for i=1,6 do
                local runeType,reason=Functions.cache.getCached(cache, addon.Platform.GetRuneTypeObservation, addon.Platform, i)
                if runeType==nil then return nil,reason end
                if runeType == value.rune then
                    local observation,why=Functions.cache.getCached(cache, addon.Platform.GetRuneCooldownObservation, addon.Platform, i)
                    if observation==nil then return nil,why end
                    if observation.ready==nil then return nil,observation.readyReason end
                    if observation.ready then count = count + 1 end
                end
            end
            return Functions.values.compare(value.operator, count, value.value)
        end,]=]
original['RUNE_COOLDOWN']=[=[        evaluate = function(value, cache)
            local now = GetTime()
            local lowest_remain
            for i=1,6 do
                if Functions.cache.getCached(cache, GetRuneType, i) == value.rune then
                    local start, duration = Functions.cache.getCached(cache, GetRuneCooldown, i)
                    local remain = math.max(addon.Functions.values.round(duration - (now - start), 3), 0)
                    if lowest_remain == nil or remain < lowest_remain then
                        lowest_remain = remain
                    end
                end
            end
            return Functions.values.compare(value.operator, lowest_remain, value.value)
        end,]=]
repaired['RUNE_COOLDOWN']=[=[        evaluate = function(value, cache)
            local now,timeReason=addon.Platform:GetRuneEvaluationTime()
            local lowest_remain
            for i=1,6 do
                local runeType,reason=Functions.cache.getCached(cache, addon.Platform.GetRuneTypeObservation, addon.Platform, i)
                if runeType==nil then return nil,reason end
                if runeType == value.rune then
                    if now==nil then return nil,timeReason end
                    local observation,why=Functions.cache.getCached(cache, addon.Platform.GetRuneCooldownObservation, addon.Platform, i)
                    if observation==nil then return nil,why end
                    if observation.start==nil then return nil,observation.startReason end
                    if observation.duration==nil then return nil,observation.durationReason end
                    local remain = observation.duration - (now - observation.start)
                    if remain~=remain or remain>=math.huge or remain<=-math.huge then return nil,'invalid-rune-time' end
                    remain = addon.Functions.values.round(remain, 3)
                    if type(remain)~='number' or remain~=remain or remain>=math.huge or remain<=-math.huge then return nil,'invalid-rune-time' end
                    remain = math.max(remain, 0)
                    if lowest_remain == nil or remain < lowest_remain then
                        lowest_remain = remain
                    end
                end
            end
            if lowest_remain==nil then return false end
            return Functions.values.compare(value.operator, lowest_remain, value.value)
        end,]=]
return function(text,tag)
    if tag then
        assert(original[tag],'invalid rune repair tag')
        local before=assert(repaired[tag]:match('^        evaluate = function%([^\n]*%)(.*)end,$'))
        local after=assert(original[tag]:match('^        evaluate = function%([^\n]*%)(.*)end,$'))
        assert(text==before,'unexpected repaired rune callback bytes: '..tag)
        return after
    end
    for _,name in ipairs({'RUNE','RUNE_COOLDOWN'}) do
        local body=repaired[name]
        local first=assert(text:find(body,1,true),'exact repaired rune missing: '..name)
        assert(not text:find(body,first+1,true),'multiple repaired rune bodies: '..name)
        text=text:sub(1,first-1)..original[name]..text:sub(first+#body)
    end
    return text
end
