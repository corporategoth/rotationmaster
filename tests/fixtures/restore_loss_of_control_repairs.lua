-- Strict test-only inverse of exactly2LOC evaluators and the numeric school schema.
local original={
    LOC_TYPE=[=[    evaluate = function(value, cache)
        for i=1,Functions.cache.getCached(cache, C_LossOfControl.GetNumEvents) do
            local loc_type, _, _, _, _, remain = Functions.cache.getCached(cache, C_LossOfControl.GetEventInfo, i)
            if addon.loc_equivalent[loc_type] then
                loc_type = addon.loc_equivalent[loc_type]
            end
            if loc_type == value.loc_type then
                return Functions.values.compare(value.operator, remain, value.value)
            end
        end
        return false
    end,]=],
    LOC_BLOCKED=[=[    evaluate = function(value, cache)
        for i=1,Functions.cache.getCached(cache, C_LossOfControl.GetNumEvents) do
            local _, _, _, _, _, remain, _, school = Functions.cache.getCached(cache, C_LossOfControl.GetEventInfo, i)
            if bit.band(school, bit.lshift(1, value.school-1)) then
                return Functions.values.compare(value.operator, remain, value.value)
            end
        end
        return false
    end,]=],
}
local repaired={
    LOC_TYPE=[=[    evaluate = function(value, cache)
        local count,reason=Functions.cache.getCached(cache, addon.Platform.GetLossOfControlCount, addon.Platform)
        if count==nil then return nil,reason end
        for i=1,count do
            local record,why=Functions.cache.getCached(cache, addon.Platform.GetLossOfControlEvent, addon.Platform, i, "type")
            if not record then return nil,why end
            local loc_type = record.locType
            if addon.loc_equivalent[loc_type] then
                loc_type = addon.loc_equivalent[loc_type]
            end
            if loc_type == value.loc_type then
                if record.timeRemaining==nil then return nil,record.timeRemainingReason end
                return Functions.values.compare(value.operator, record.timeRemaining, value.value)
            end
        end
        return false
    end,]=],
    LOC_BLOCKED=[=[    evaluate = function(value, cache)
        local count,reason=Functions.cache.getCached(cache, addon.Platform.GetLossOfControlCount, addon.Platform)
        if count==nil then return nil,reason end
        for i=1,count do
            local record,why=Functions.cache.getCached(cache, addon.Platform.GetLossOfControlEvent, addon.Platform, i, "school")
            if not record then return nil,why end
            if not addon.Platform:CanReadValue(bit) then return nil,"restricted-value" end
            if type(bit)~="table" then return nil,"missing-api" end
            local shiftOk,selectedBit=pcall(function() return bit.lshift(1, value.school-1) end)
            if not shiftOk then return nil,"api-error" end
            if not addon.Platform:CanReadValue(selectedBit) then return nil,"restricted-value" end
            if canaccessvalue and not canaccessvalue(selectedBit) then return nil,"restricted-value" end
            if type(selectedBit)~="number" or selectedBit~=selectedBit or selectedBit==math.huge or selectedBit==-math.huge or selectedBit%1~=0 then return nil,"invalid-api-result" end
            local bandOk,blocked=pcall(function() return bit.band(record.lockoutSchool, selectedBit) end)
            if not bandOk then return nil,"api-error" end
            if not addon.Platform:CanReadValue(blocked) then return nil,"restricted-value" end
            if canaccessvalue and not canaccessvalue(blocked) then return nil,"restricted-value" end
            if type(blocked)~="number" or blocked~=blocked or blocked==math.huge or blocked==-math.huge or blocked%1~=0 then return nil,"invalid-api-result" end
            if blocked~=0 then
                if record.timeRemaining==nil then return nil,record.timeRemainingReason end
                return Functions.values.compare(value.operator, record.timeRemaining, value.value)
            end
        end
        return false
    end,]=],
}
local function body(text) return assert(text:match('^    evaluate = function%([^\n]*%)(.*)end,$')) end
local originalBodies={LOC_TYPE=body(original.LOC_TYPE),LOC_BLOCKED=body(original.LOC_BLOCKED)}
return function(text,tag)
    if tag then
        assert(tag=='LOC_TYPE' or tag=='LOC_BLOCKED','invalid LOC inverse tag')
        assert(text==body(repaired[tag]),'unexpected LOC replacement body')
        return originalBodies[tag]
    end
    for _,name in ipairs({'LOC_TYPE','LOC_BLOCKED'}) do
        local first=assert(text:find(repaired[name],1,true),'exact repaired '..name..' missing')
        assert(not text:find(repaired[name],first+1,true),'multiple LOC replacement bodies')
        text=text:sub(1,first-1)..original[name]..text:sub(first+#repaired[name])
    end
    local newFields='    fields = { operator = "string", value = "number", school = "number" },'
    local oldFields='    fields = { operator = "string", value = "number", school = "string" },'
    local first=assert(text:find(newFields,1,true),'numeric school schema missing')
    assert(not text:find(newFields,first+1,true),'multiple school schema replacements')
    return text:sub(1,first-1)..oldFields..text:sub(first+#newFields)
end,originalBodies
