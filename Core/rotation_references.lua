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

-- Legacy bodies have no envelope. Inspect their semantic condition edges too,
-- so a disabled definition cannot be bypassed by a later priority action.
function addon:HasDisabledRotationDependency(body)
    local definitions=self.conditionDefinitions or {}
    local hasDisabled=false
    for _,definition in pairs(definitions) do if type(definition)=='table' and definition.disabled then hasDisabled=true;break end end
    if not hasDisabled then return false end
    local tree=self.RotationData.IndexRotationSteps(body,{allowMissingIds=true})
    if not tree then return true end
    local count=0
    local condition,declared
    declared=function(value,schema,depth)
        if value==nil then return false end
        if depth>64 then return true end
        if schema=='condition' then return condition(value,depth+1) end
        if schema=='condition[]' then
            if type(value)~='table' then return true end
            for _,child in ipairs(value) do if condition(child,depth+1) then return true end end
        elseif type(schema)=='table' and type(value)=='table' then
            if schema[1]~=nil then
                -- Union schemas may contain object/list alternatives. Inspect
                -- only alternatives that declare nested conditions.
                for _,alternative in ipairs(schema) do if declared(value,alternative,depth+1) then return true end end
            else
                for key,kind in pairs(schema) do if declared(value[key],kind,depth+1) then return true end end
            end
        end
        return false
    end
    condition=function(value,depth)
        if value==nil then return false end
        count=count+1;if count>4096 or depth>64 or type(value)~='table' then return true end
        if value.type=='AND' or value.type=='OR' then return declared(value.value,'condition[]',depth+1) end
        if value.type=='NOT' then return condition(value.value,depth+1) end
        local definition=definitions[value.type]
        if type(definition)=='table' then
            if definition.disabled then return true end
            for key,kind in pairs(definition.fields or {}) do if declared(value[key],kind,depth+1) then return true end end
        end
        return false
    end
    if condition(body.switch,0) then return true end
    for _,row in ipairs(tree.rows) do if condition(row.step.conditions,0) then return true end end
    return false
end
