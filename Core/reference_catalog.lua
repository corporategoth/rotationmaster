local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local items={}
local function id(value) local n=tonumber(value);if n and n>0 and n<math.huge and n%1==0 then return n end end
local function plain(value) return type(value)=='string' and value:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','') or value end
local function inventory()
    local result={};for key,count in pairs(addon.bagContents or {}) do if id(key) and type(count)=='number' and count>0 then result[id(key)]=true end end
    if type(GetInventoryItemID)=='function' then for slot=1,19 do local ok,value=pcall(GetInventoryItemID,'player',slot);if ok and addon.Platform:CanReadValue(value) and id(value) then result[value]=true end end end
    return result
end
local function itemInfo(value)
    local key=id(value);if not key then return end
    local getter=C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(getter)=='function' then
        local ok,name,link,_,_,_,_,_,_,_,icon=pcall(getter,key)
        if ok and type(name)=='string' and addon.Platform:CanReadValue(name) then items[key]={id=key,name=name,display=name,icon=icon,link=link} end
    end
    return items[key]
end
local function indexedItems()
    local result={};local ok,loader=pcall(LibStub,'AceGUI-3.0-ItemLoader',true)
    if ok and loader then for key,value in pairs(loader.itemList or {}) do if id(key) and type(value)=='table' and type(value.name)=='string' then result[id(key)]={id=id(key),name=value.name,display=value.name,icon=value.icon,link=value.link} end end end
    for key in pairs(addon.bagContents or {}) do itemInfo(key) end
    for key,value in pairs(items) do result[key]=value end
    return result
end
local function itemResolve(input,settings)
    settings=settings or {};local text=plain(tostring(input or ''));local key=id(text) or id(text:match('|Hitem:(%d+)')) or id(text:match('^item:(%d+)'))
    if not key then
        local getter=C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
        if type(getter)=='function' then local ok,value=pcall(getter,input);if ok and addon.Platform:CanReadValue(value) then key=id(value) end end
    end
    if not key then for item,record in pairs(indexedItems()) do if record.name:lower()==text:lower() then key=item;break end end end
    if key and settings.inventory and not inventory()[key] then return nil,'item-not-in-inventory' end
    if key then itemInfo(key);return key end
end
local function itemSearch(input,settings)
    settings=settings or {};local limit=settings.limit or 30;if type(limit)~='number' or limit<1 or limit>100 or limit%1~=0 then return nil,'invalid-search-options' end
    local query=plain(tostring(input or '')):lower();if #query>256 then return nil,'invalid-search-query' end
    local exact=id(query) or id(query:match('|Hitem:(%d+)'));if exact then itemInfo(exact) end
    local owned=settings.inventory and inventory();local matches={}
    for key,record in pairs(indexedItems()) do if (not owned or owned[key]) and (exact and exact==key or not exact and record.name:lower():find(query,1,true)) then matches[#matches+1]=record end end
    table.sort(matches,function(a,b) if a.name==b.name then return a.id<b.id end;return a.name:lower()<b.name:lower() end)
    local result={};for i=1,math.min(limit,#matches) do local row=matches[i];result[i]={id=row.id,name=row.name,display=row.name,icon=row.icon,link=row.link} end
    return result,{coverage='indexed-metadata',more=#matches>limit}
end
function addon:GetReferenceProvider(kind)
    if kind=='Item_EditBox' or kind=='Inventory_EditBox' or kind=='item' then
        return {kind='item',index=itemInfo,info=itemInfo,resolve=itemResolve,search=itemSearch,
            name=function(value) local record=itemInfo(value);return record and record.name end,
            missing=L['Item data loading'],inventory=kind=='Inventory_EditBox'}
    end
    local catalog=self.SpellCatalog
    return {kind='spell',index=function(value) return catalog:UpdateSpell(value) end,resolve=function(value,options) return catalog:ResolveSelection(value,options) end,
        name=function(value,norank) return catalog:SpellName(value,norank) end,search=function(value,options) return catalog:Search(value,options) end,
        info=function(value) local info=self.Platform:GetSpellInfo(value);return info and {id=value,name=info.name,display=info.name,icon=info.iconID} end,missing=L['Unknown spell']}
end
