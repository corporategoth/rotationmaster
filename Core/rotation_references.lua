local _,addon=...
local observed,stamp
-- Trusted standard primitives at module load; changed live pointers disable reuse.
local proofPairs,proofRawget,proofRawequal,proofType,proofGetmetatable=pairs,rawget,rawequal,type,getmetatable
-- Lua5.1 accepts a stack level or function; the checker declares only levels.
---@type fun(f: number|function): table
local proofGetfenv=getfenv
local proofEnvironment=proofType(proofGetfenv)=='function' and proofGetfenv(1) or nil
local function normalized(value)
    return type(value)=='table' and value or false
end
local function entries(value)
    local result,count={},0
    if type(value)=='table' then
        for key,item in pairs(value) do result[key]=normalized(item);count=count+1 end
    end
    return result,count
end
local function sameEntries(value,previous,expected)
    local count=0
    if type(value)=='table' then
        for key,item in pairs(value) do
            if not rawequal(type(item)=='table' and item or false,previous[key]) then return false end
            count=count+1
        end
    end
    return count==expected
end
local function validItemsets(shared,personal)
    return (shared==nil or type(shared)=='table') and (personal==nil or type(personal)=='table')
end
local function sameItemsets(shared,personal,previous,expected)
    if not validItemsets(shared,personal) then return expected==0 end
    local count=0
    if shared then
        for key,item in pairs(shared) do
            -- Only actual personal entries shadow shared entries. A missing-key
            -- lookup could materialize an AceDB default and mutate the source.
            if not personal or rawget(personal,key)==nil then
                if not rawequal(type(item)=='table' and item or false,previous[key]) then return false end
                count=count+1
            end
        end
    end
    if personal then
        for key,item in pairs(personal) do
            if not rawequal(type(item)=='table' and item or false,previous[key]) then return false end
            count=count+1
        end
    end
    return count==expected
end
local function itemsetEntries(shared,personal)
    if not validItemsets(shared,personal) then return {},0 end
    local result,count=entries(shared)
    if personal then
        for key,item in pairs(personal) do
            if result[key]==nil then count=count+1 end
            result[key]=normalized(item)
        end
    end
    return result,count
end
-- Observe identities without copying maps on the common unchanged path.
-- Normalized false markers keep malformed/NaN entries stable, as before.
local function observe(owner)
    local profile,global=owner.db.profile,owner.db.global
    local shared,personal=global.itemsets,profile.itemsets
    local conditions,effects=owner.conditionDefinitions,global.effects
    local version=owner.conditionRegistryVersion or 0
    if observed and observed.profile==profile and observed.global==global and observed.version==version
        and sameItemsets(shared,personal,observed.itemsets,observed.itemsetCount)
        and sameEntries(conditions,observed.conditions,observed.conditionCount)
        and sameEntries(effects,observed.effects,observed.effectCount) then return end
    local itemsets,itemsetCount=itemsetEntries(shared,personal)
    local conditionEntries,conditionCount=entries(conditions)
    local effectEntries,effectCount=entries(effects)
    observed={profile=profile,global=global,version=version,
        itemsets=itemsets,itemsetCount=itemsetCount,
        conditions=conditionEntries,conditionCount=conditionCount,
        effects=effectEntries,effectCount=effectCount}
    stamp={}
end
-- Internal authority checks need the current stamp, not detached public maps.
-- Keep checking every dependency at each call, including reentrant mutations.
function addon:GetRotationValidationStamp()
    observe(self)
    return stamp
end
local ownedValidationStamp=addon.GetRotationValidationStamp
-- Even protected metatable metadata can disguise a callback. Only native
-- primitives stored directly in the owned environment can certify this path.
local function proofGlobals()
    return proofType(proofEnvironment)=='table' and proofRawequal(proofRawget(proofEnvironment,'pairs'),proofPairs)
        and proofRawequal(proofRawget(proofEnvironment,'rawget'),proofRawget) and proofRawequal(proofRawget(proofEnvironment,'rawequal'),proofRawequal)
        and proofRawequal(proofRawget(proofEnvironment,'type'),proofType) and proofRawequal(proofRawget(proofEnvironment,'getmetatable'),proofGetmetatable)
        and proofRawequal(proofRawget(proofEnvironment,'getfenv'),proofGetfenv)
        and proofRawequal(proofGetfenv(ownedValidationStamp),proofEnvironment)
        and proofRawequal(proofGetfenv(observe),proofEnvironment) and proofRawequal(proofGetfenv(normalized),proofEnvironment)
        and proofRawequal(proofGetfenv(entries),proofEnvironment) and proofRawequal(proofGetfenv(sameEntries),proofEnvironment)
        and proofRawequal(proofGetfenv(validItemsets),proofEnvironment) and proofRawequal(proofGetfenv(sameItemsets),proofEnvironment)
        and proofRawequal(proofGetfenv(itemsetEntries),proofEnvironment)
end
local function proofPlain(value)
    return proofType(value)=='table' and proofGetmetatable(value)==nil
end
-- Only raw-present, callback-free layouts can join adjacent observations.
-- AceAddon owners and AceDB db objects may have metatables: every accessed
-- slot is raw-present, and neither object participates in equality/tostring.
local function validationLayout(owner,method)
    if proofType(owner)~='table'
        or method~=ownedValidationStamp or proofRawget(owner,'GetRotationValidationStamp')~=ownedValidationStamp then return end
    local db=proofRawget(owner,'db');if proofType(db)~='table' then return end
    local profile,global=proofRawget(db,'profile'),proofRawget(db,'global')
    if not proofPlain(profile) or not proofPlain(global) then return end
    local conditions,version=proofRawget(owner,'conditionDefinitions'),proofRawget(owner,'conditionRegistryVersion')
    local shared,personal=proofRawget(global,'itemsets'),proofRawget(profile,'itemsets')
    local effects,state=proofRawget(global,'effects'),proofRawget(profile,'rotationLibrary')
    if not proofPlain(conditions) or proofType(version)~='number' or not proofPlain(shared)
        or not proofPlain(personal) or not proofPlain(effects) or not proofPlain(state) then return end
    return db,profile,global,conditions,shared,personal,effects,version,state
end
local function sameValidationLayout(owner,method,db,profile,global,conditions,shared,personal,effects,version,state)
    local d,p,g,c,s,i,e,v,l=validationLayout(owner,method)
    return d~=nil and proofRawequal(d,db) and proofRawequal(p,profile) and proofRawequal(g,global)
        and proofRawequal(c,conditions) and proofRawequal(s,shared) and proofRawequal(i,personal)
        and proofRawequal(e,effects) and proofRawequal(v,version) and proofRawequal(l,state)
end
local function readValidationStamp(owner,method,entryMethod)
    local db,profile,global,conditions,shared,personal,effects,version,state
    -- A successful PRE proof closes the owned scan. POST checks raw layout
    -- again, without repeating globals that no permitted callback can change.
    if entryMethod==ownedValidationStamp and proofGlobals() then db,profile,global,conditions,shared,personal,effects,version,state=validationLayout(owner,method) end
    local value=method(owner)
    if db then return value,db,profile,global,conditions,shared,personal,effects,version,state end
    return value
end
-- Trusted private module handoff, retired by its consumer. This does not
-- authenticate a hostile replacement of the complete loader/binder itself.
function addon:BindRotationValidationReader(bind)
    if type(bind)~='function' then return nil,'invalid-validation-reader-binder' end
    bind(readValidationStamp,sameValidationLayout,proofRawget,proofRawequal,proofType,proofGetmetatable)
    return true
end
-- Dependency maps may carry AceDB defaults metatables. Observe their entries,
-- without copying/traversing definitions or writing into SavedVariables.
function addon:GetRotationValidationOptions()
    observe(self)
    -- Public maps remain fresh: consumers cannot poison private observations.
    local conditions=entries(observed.conditions)
    local itemsets=entries(observed.itemsets)
    local effects=entries(observed.effects)
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
