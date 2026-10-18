local _,addon=...
local platform=addon.Platform
local function identifier(item)
    if not platform:CanReadValue(item) then return nil,"restricted-value" end
    if type(item)=="number" and item>0 and item<math.huge and item%1==0 then return true end
    if type(item)=="string" and #item>0 and #item<=1024 then return true end
    return nil,"invalid-item"
end
local function normalize(name,id)
    if not platform:CanReadValue(name) or not platform:CanReadValue(id) then return nil,"restricted-value" end
    if name==nil and id==nil then return nil,"item-spell-unavailable" end
    if type(name)~="string" or name=="" or type(id)~="number" or id<=0 or id>=math.huge or id%1~=0 then return nil,"invalid-api-result" end
    return {name=name,spellID=id}
end
function platform:GetItemUseSpell(item)
    local valid,reason=identifier(item)
    if not valid then return nil,reason end
    local fn=C_Item and C_Item.GetItemSpell or GetItemSpell
    if type(fn)~="function" then return nil,"missing-api" end
    local ok,name,id=pcall(fn,item)
    if not ok then return nil,"api-error" end
    return normalize(name,id)
end

function platform:GetItemID(item)
    local valid,reason=identifier(item)
    if not valid then return nil,reason end
    if type(item)=="number" then return item end
    local fn=C_Item and C_Item.GetItemInfoInstant
    if type(fn)~='function' then fn=GetItemInfoInstant end
    if type(fn)~="function" then return nil,"missing-api" end
    local ok,id=pcall(fn,item)
    if not ok then return nil,"api-error" end
    if not self:CanReadValue(id) then return nil,"restricted-value" end
    if id==nil then return nil,"item-data-unavailable" end
    if type(id)~="number" or id<=0 or id>=math.huge or id%1~=0 then return nil,"invalid-api-result" end
    return id
end

local function finite(value)
    return type(value)=="number" and value==value and value>=0 and value<math.huge
end
-- Display metadata does not need a minimum-level observation. Keep the
-- gameplay metadata contract separate so a readable name/icon is still usable
-- in editors, while readiness never guesses a missing required level.
function platform:GetItemDisplayInfo(item)
    local id,reason=self:GetItemID(item);if not id then return nil,reason end
    local fn=C_Item and C_Item.GetItemInfo
    if type(fn)~='function' then fn=GetItemInfo end
    if type(fn)~='function' then return nil,'missing-api' end
    local ok,name,link,_,_,_,_,_,_,_,icon=pcall(fn,id)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(name) or not self:CanReadValue(link) or not self:CanReadValue(icon) then return nil,'restricted-value' end
    if link~=nil and (type(link)~='string' or link=='')
        or icon~=nil and not (type(icon)=='string' and icon~='' or finite(icon) and icon%1==0) then return nil,'invalid-api-result' end
    if name==nil then return nil,'item-data-unavailable' end
    if type(name)~='string' or name=='' then return nil,'invalid-api-result' end
    return {itemID=id,name=name,link=link,iconID=icon}
end
function platform:GetItemCooldown(item)
    local id,reason=self:GetItemID(item)
    if not id then return nil,reason end
    local fn=C_Item and C_Item.GetItemCooldown
    if type(fn)~='function' then fn=C_Container and C_Container.GetItemCooldown end
    if type(fn)~='function' then fn=GetItemCooldown end
    if type(fn)~='function' then return nil,'missing-api' end
    local ok,start,duration,enabled=pcall(fn,id)
    if not ok then return nil,'api-error' end
    for _,value in pairs({start=start,duration=duration,enabled=enabled}) do
        if not self:CanReadValue(value) then return nil,'restricted-value' end
    end
    if not finite(start) or not finite(duration) then return nil,'invalid-api-result' end
    -- Current C_Item uses bool; container/older global versions use 0/1. A
    -- deprecated global may itself alias C_Item, so validate both tuple forms.
    if enabled==1 then enabled=true elseif enabled==0 then enabled=false end
    if type(enabled)~='boolean' then return nil,'invalid-api-result' end
    return {startTime=start,duration=duration,isEnabled=enabled}
end
local function query(fn,...)
    if type(fn)~="function" then return nil,"missing-api" end
    local ok,value=pcall(fn,...)
    if not ok then return nil,"api-error" end
    if not platform:CanReadValue(value) then return nil,"restricted-value" end
    return value
end

function platform:GetItemMetadata(item)
    local id,reason=self:GetItemID(item);if not id then return nil,reason end
    local fn=C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(fn)~='function' then return nil,'missing-api' end
    local ok,name,link,_,_,level,_,_,_,_,icon=pcall(fn,id)
    if not ok then return nil,'api-error' end
    for _,value in pairs({name=name,link=link,level=level,icon=icon}) do
        if not self:CanReadValue(value) then return nil,'restricted-value' end
    end
    if name==nil then return nil,'item-data-unavailable' end
    if type(name)~='string' or name=='' or not finite(level) or level%1~=0
        or link~=nil and (type(link)~='string' or link=='')
        or icon~=nil and not (type(icon)=='string' or finite(icon) and icon%1==0) then return nil,'invalid-api-result' end
    return {name=name,link=link,minimumLevel=level,iconID=icon}
end
function platform:GetItemCount(item)
    local id,reason=self:GetItemID(item);if not id then return nil,reason end
    local value,why=query(C_Item and C_Item.GetItemCount or GetItemCount,id,false,false)
    if why then return nil,why end
    if not finite(value) or value%1~=0 then return nil,'invalid-api-result' end
    return value
end
function platform:IsItemEquipped(item)
    local id,reason=self:GetItemID(item);if not id then return nil,reason end
    local value,why=query(C_Item and C_Item.IsEquippedItem or IsEquippedItem,id)
    if why then return nil,why end
    if type(value)~='boolean' then return nil,'invalid-api-result' end
    return value
end
function platform:IsItemLevelAllowed(item)
    local metadata,reason=self:GetItemMetadata(item);if not metadata then return nil,reason end
    local level,why=query(UnitLevel,'player');if why then return nil,why end
    if not finite(level) or level%1~=0 then return nil,'invalid-api-result' end
    return level>=metadata.minimumLevel
end

function platform:IsItemReady(item,now)
    local id,reason=self:GetItemID(item)
    if not id then return nil,reason end
    if not self:CanReadValue(now) or not finite(now) then return nil,"invalid-time" end
    local count,why=self:GetItemCount(id)
    if why then return nil,why end
    if count==0 then return false end
    local fn=C_Item and C_Item.IsUsableItem or IsUsableItem
    if type(fn)~="function" then return nil,"missing-api" end
    local ok,usable,power=pcall(fn,id)
    if not ok then return nil,"api-error" end
    if not self:CanReadValue(usable) or not self:CanReadValue(power) then return nil,"restricted-value" end
    if type(usable)~="boolean" or type(power)~="boolean" then return nil,"invalid-api-result" end
    if not usable or power then return false end
    local cooldown,cooldownReason=self:GetItemCooldown(id)
    if not cooldown then return nil,cooldownReason end
    if not cooldown.isEnabled then return false end
    return cooldown.startTime+cooldown.duration<=now
end

function platform:GetItemRangeState(item,unit)
    local valid,reason=identifier(item)
    if not valid then return nil,reason end
    if not self:CanReadValue(unit) or type(unit)~="string" or unit=="" then return nil,"invalid-unit" end
    local shape=C_Item and C_Item.ItemHasRange or ItemHasRange
    if type(shape)=="function" then
        local hasRange,why=query(shape,item)
        if why then return nil,why end
        if type(hasRange)~="boolean" then return nil,"invalid-api-result" end
        if not hasRange then return {applicable=false} end
    end
    local native=C_Item and C_Item.IsItemInRange
    local inRange,why=query(native or IsItemInRange,item,unit)
    if why then return nil,why end
    if not native then
        if inRange==1 then inRange=true elseif inRange==0 then inRange=false end
    end
    if type(inRange)~="boolean" then return nil,"invalid-range-check" end
    return {applicable=true,inRange=inRange}
end
