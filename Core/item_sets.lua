local _,addon=...
local platform=addon.Platform

local function list(items)
    if type(items)~='table' or not addon:IsConditionItemReference(items) then return nil,'invalid-item-reference' end
    return items
end
local function read(cache,method,...)
    return addon.Functions.cache.getCached(cache,method,platform,...)
end
-- First-defined identity is useful for previews even without ownership. Do not
-- store failed name resolution in a long-lived cache: item metadata loads later.
function addon:FindFirstItemInItems(items)
    local entries,reason=list(items);if not entries then return nil,reason end
    if entries[1]~=nil then return platform:GetItemID(entries[1]) end
end
function addon:FindFirstItemInItemSet(id)
    local entries,reason=self:GetConditionItemList(id);if not entries then return nil,reason end
    return self:FindFirstItemInItems(entries)
end
function addon:FindItemInItems(items,item)
    local entries,reason=list(items);if not entries then return nil,reason end
    local wanted,why=platform:GetItemID(item);if not wanted then return nil,why end
    local unavailable
    for _,entry in ipairs(entries) do
        local candidate,problem=platform:GetItemID(entry)
        if candidate==wanted then return wanted end
        unavailable=unavailable or problem
    end
    return nil,unavailable
end
function addon:FindItemInItemSet(id,item)
    local entries,reason=self:GetConditionItemList(id);if not entries then return nil,reason end
    return self:FindItemInItems(entries,item)
end
function addon:FindFirstItemOfItems(cache,items,equipped)
    local entries,reason=list(items);if not entries then return nil,reason end
    cache=cache or {};local counts
    for _,entry in ipairs(entries) do
        local candidate,why=read(cache,platform.GetItemID,entry);if not candidate then return nil,why end
        if equipped then
            local worn,problem=read(cache,platform.IsItemEquipped,candidate)
            if worn==nil then return nil,problem end
            if worn then return candidate end
        end
        if not counts then
            local problem;counts,problem=read(cache,platform.GetBagItemCounts)
            if not counts then return nil,problem end
        end
        if counts[candidate] then return candidate end
    end
end
function addon:FindFirstItemOfItemSet(cache,id,equipped)
    local entries,reason=self:GetConditionItemList(id);if not entries then return nil,reason end
    return self:FindFirstItemOfItems(cache,entries,equipped)
end
