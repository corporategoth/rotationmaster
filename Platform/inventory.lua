local _,addon=...
local platform=addon.Platform
local function finite(value) return type(value)=='number' and value==value and value>=0 and value<math.huge end
local function query(fn,...)
    local ok,value=pcall(fn,...)
    if not ok then return nil,'api-error' end
    if not platform:CanReadValue(value) then return nil,'restricted-value' end
    return value
end
-- A detached bag-only snapshot. GetItemCount can also include worn items;
-- bank slots are deliberately excluded from the Have Item In Bags predicate.
function platform:GetBagItemCounts()
    local last=NUM_TOTAL_EQUIPPED_BAG_SLOTS
    if not self:CanReadValue(last) then return nil,'restricted-value' end
    local totalProvided=last~=nil
    if last==nil then last=NUM_BAG_SLOTS end
    if not self:CanReadValue(last) then return nil,'restricted-value' end
    if not finite(last) or last>16 or last%1~=0 then return nil,'missing-bag-layout' end
    local bags={};for bag=0,last do bags[#bags+1]=bag end
    local family=self:GetClientInfo().family
    if not totalProvided and (family=='retail' or family=='forever') then
        local reagent=Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
        if not self:CanReadValue(reagent) then return nil,'restricted-value' end
        if reagent~=nil then
            if not finite(reagent) or reagent>16 or reagent%1~=0 then return nil,'invalid-bag-layout' end
            if reagent>last then bags[#bags+1]=reagent end
        end
    end
    local slots=C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local native=C_Container and C_Container.GetContainerItemInfo
    local info=type(native)=='function' and native or GetContainerItemInfo
    if type(slots)~='function' or type(info)~='function' then return nil,'missing-api' end
    local result={}
    for _,bag in ipairs(bags) do
        local size,reason=query(slots,bag);if reason then return nil,reason end
        if not finite(size) or size>256 or size%1~=0 then return nil,'invalid-api-result' end
        for slot=1,size do
            local ok,id,count,link,present
            if type(native)=='function' then
                local record;ok,record=pcall(info,bag,slot)
                if not ok then return nil,'api-error' end
                if not self:CanReadValue(record) then return nil,'restricted-value' end
                if record~=nil then
                    present=true
                    if type(record)~='table' then return nil,'invalid-api-result' end
                    id,count=record.itemID,record.stackCount
                end
            else
                local icon,locked,quality,readable,lootable,filtered,noValue
                ok,icon,count,locked,quality,readable,lootable,link,filtered,noValue,id=pcall(info,bag,slot)
                if not ok then return nil,'api-error' end
                if not self:CanReadValue(icon) or not self:CanReadValue(link) or not self:CanReadValue(id) or not self:CanReadValue(count) then return nil,'restricted-value' end
                present=icon~=nil or link~=nil or id~=nil or count~=nil
                if id==nil and link~=nil then id,reason=self:GetItemID(link);if not id then return nil,reason end end
            end
            if not self:CanReadValue(id) or not self:CanReadValue(count) then return nil,'restricted-value' end
            if present then
                if not finite(id) or id<=0 or id%1~=0 or not finite(count) or count<1 or count%1~=0 then return nil,'invalid-api-result' end
                result[id]=(result[id] or 0)+count
                if not finite(result[id]) then return nil,'invalid-api-result' end
            end
        end
    end
    return result
end
