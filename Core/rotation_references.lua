local _,addon=...
local observed,stamp
local function entries(value)
    local result={}
    if type(value)=='table' then for key,item in pairs(value) do result[key]=type(item)=='table' and item or false end end
    return result
end
local function same(left,right)
    for key,value in pairs(left) do if not rawequal(value,right[key]) then return false end end
    for key,value in pairs(right) do if not rawequal(value,left[key]) then return false end end
    return true
end
-- Dependency maps may carry AceDB defaults metatables. Observe their entries,
-- without copying/traversing definitions or writing into SavedVariables.
function addon:GetRotationValidationOptions()
    local profile,global=self.db.profile,self.db.global
    local personal=profile.itemsets;local itemsets={}
    if (personal==nil or type(personal)=='table') and (global.itemsets==nil or type(global.itemsets)=='table') then
        itemsets=entries(global.itemsets)
        if personal then for key,value in pairs(personal) do itemsets[key]=type(value)=='table' and value or false end end
    end
    -- Invalid entries are unavailable markers, including NaN. Comparing raw NaN
    -- entries would change the stamp forever and recurse while rebuilding clones.
    local conditions=entries(self.conditionDefinitions)
    local effects=entries(global.effects)
    local version=self.conditionRegistryVersion or 0
    if not observed or observed.profile~=profile or observed.global~=global or observed.version~=version
        or not same(observed.itemsets,itemsets) or not same(observed.conditions,conditions) or not same(observed.effects,effects) then
        observed={profile=profile,global=global,version=version,itemsets=entries(itemsets),conditions=entries(conditions),effects=entries(effects)}
        stamp={}
    end
    -- Maps (including empty fallbacks) are fresh and cannot poison observations.
    return {conditions=conditions,itemsets=itemsets,effects=effects},stamp
end
