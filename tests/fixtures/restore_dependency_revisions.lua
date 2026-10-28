-- Exact managed-dependency foundation inverse; frozen HEAD61ad6ad.
local records = {
    ["Core/rotation_references.lua"] = [====[local _,addon=...
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
    -- Public option copying uses live pairs; a prior override can retain its
    -- private input maps. Their later lookups must remain callback-free too.
    if not proofPlain(observed) or not proofPlain(stamp)
        or not proofPlain(proofRawget(observed,'itemsets'))
        or not proofPlain(proofRawget(observed,'conditions'))
        or not proofPlain(proofRawget(observed,'effects')) then return end
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

-- BEGIN PRIVATE VALIDATION CPU HANDOFF
do
 local bind=addon.BindCPUValidationScopeDiagnostic
 if type(bind)=='function' then bind(addon,'references',ownedValidationStamp,function() return observe,sameEntries,sameItemsets,proofGlobals end) end
end
-- END PRIVATE VALIDATION CPU HANDOFF
]====],
    ["Core/conditions.lua"] = [====[local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- Registry and tree services are independent of options rendering.
local printArray, printSingle, validateArray, validateSingle, usefulArray, usefulSingle

local conditions = {}
addon.conditionDefinitions = conditions
local special = {}
addon.conditionSpecials = special
local quarantined = setmetatable({}, {__mode="k"})
special["DELETE"] = { desc = DELETE, icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Controls\\trash.tga", fields = { } }
special["AND"] = { desc = L["AND"], icon = addon.Artwork.logic["AND"], fields = { value = "condition[]" } }
special["OR"] = { desc = L["OR"], icon = addon.Artwork.logic["OR"], fields = { value = "condition[]" } }
special["NOT"] = { desc = L["NOT"], icon = addon.Artwork.logic["NOT"], fields = { value = "condition" } }

-- Inputs here are normalized, readable data. Client adapters own secret-value access.
local function outcome(status, reason, path)
    return {status=status, reason=reason, path=path}
end

local function callCondition(definition, stage, value, cache, start, path, context)
    if quarantined[definition] then return false end
    local function run()
        if stage == "valid" then return definition.valid(addon.currentSpec, value) end
        return definition.evaluate(value, cache, start)
    end
    if not addon.Diagnostics then return true, run() end
    local ok, result, reason = addon.Diagnostics:Call({module="conditions", operation=stage,
        conditionPath=path, conditionTag=value.type, stepId=context and context.stepId,
        rotationId=addon.currentRotation, customCode=definition.customCode == true}, run)
    if not ok then quarantined[definition] = true end
    return ok, result, reason
end

local function evaluate(value, cache, start, state, depth, path)
    state.count = state.count + 1
    if depth > 64 or state.count > 4096 then
        return outcome("unavailable", "condition-limit", path)
    end
    if value == nil then return outcome("match") end
    if type(value) ~= "table" then return outcome("unavailable", "invalid-condition", path) end
    if state.active[value] then return outcome("unavailable", "condition-cycle", path) end
    if value.disabled ~= nil and type(value.disabled) ~= "boolean" then
        return outcome("unavailable", "invalid-disabled-flag", path)
    end
    if value.disabled then return outcome("match") end
    if value.type == nil then
        if next(value) == nil then return outcome("match") end
        return outcome("unavailable", "missing-condition-type", path)
    end
    if type(value.type) ~= "string" then return outcome("unavailable", "invalid-condition-type", path) end
    state.active[value] = true
    local result
    if value.type == "AND" or value.type == "OR" then
        local children = value.value
        if children == nil then children = {} end
        if type(children) ~= "table" then
            result = outcome("unavailable", "invalid-condition-list", path)
        else
            local count, largest = 0, 0
            for key in pairs(children) do
                if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
                    result = outcome("unavailable", "invalid-condition-list", path)
                    break
                end
                count = count + 1
                if count > 4096 - state.count then
                    result = outcome("unavailable", "condition-limit", path)
                    break
                end
                if key > largest then largest = key end
            end
            if not result and count ~= largest then result = outcome("unavailable", "sparse-condition-list", path) end
            if not result then
                local matched = value.type == "AND"
                for index = 1, count do
                    local child = evaluate(children[index], cache, start, state, depth+1, path..".value["..index.."]")
                    if child.status == "unavailable" then result = child; break end
                    if value.type == "AND" and child.status == "no-match" then matched = false end
                    if value.type == "OR" and child.status == "match" then matched = true end
                end
                result = result or outcome(matched and "match" or "no-match")
            end
        end
    elseif value.type == "NOT" then
        if type(value.value) ~= "table" then
            result = outcome("unavailable", "invalid-not-condition", path)
        else
            result = evaluate(value.value, cache, start, state, depth+1, path..".value")
            if result.status ~= "unavailable" then
                result = outcome(result.status == "match" and "no-match" or "match")
            end
        end
    else
        local definition = conditions[value.type]
        if not definition then
            result = outcome("unavailable", "unknown-condition", path)
        elseif definition.functionUnavailable then
            result = outcome("unavailable", "unavailable-function", path)
        elseif definition.disabled then
            result = outcome("unavailable", "disabled-condition", path)
        elseif type(definition.valid) ~= "function" or type(definition.evaluate) ~= "function" then
            result = outcome("unavailable", "incomplete-condition-definition", path)
        else
            local validOk, valid = callCondition(definition, "valid", value, cache, start, path, state.context)
            if not validOk then
                result = outcome("unavailable", "condition-callback-error", path)
            elseif not valid then
                result = outcome("unavailable", "invalid-condition-fields", path)
            else
                local evalOk, matched, reason = callCondition(definition, "evaluate", value, cache, start, path, state.context)
                if not evalOk then
                    result = outcome("unavailable", "condition-callback-error", path)
                -- Legacy predicates often return nil for false (e.g. UnitExists).
                -- Only explicit nil + reason declares unavailable observation data.
                elseif matched == nil and reason ~= nil then
                    result = outcome("unavailable", reason, path)
                else
                    result = outcome(matched and "match" or "no-match")
                end
            end
        end
    end
    state.active[value] = nil
    return result
end

-- Alternatives belong to translated predicate templates, never inferred from
-- rendered names. Only the first marker is the leaf's predicate; subsequent
-- markers are qualifiers and retain their positive wording under negation.
local printerSources=setmetatable({}, {__mode='k'})
function addon:RenderConditionPhrase(text,negated)
    if type(text)~='string' then return text end
    local first=true;local hasPrimary=text:find('{{!',1,true)~=nil
    local rendered,count=text:gsub('{{(.-)|(.-)}}',function(positive,negative)
        local primary=positive:sub(1,1)=='!';if primary then positive=positive:sub(2) end
        local predicate=not hasPrimary or primary
        local result=negated and first and predicate and negative or positive;if predicate then first=false end;return result
    end)
    if negated and count==0 then return string.format(L['not (%s)'],text) end
    return rendered
end
-- Transient summary authority is shared by native and compiled helper calls.
-- Values are detached before rendering and are never parsed as template syntax.
local summaryRecords=setmetatable({}, {__mode='k'})
local SUMMARY_LIMIT,SUMMARY_PARTS=64000,4096
local function summaryObject(record)
    local object={};summaryRecords[object]=record;return object
end
local function invalidSummary() return summaryObject({kind='invalid'}) end
local function summaryFallback()
    local key='Condition summary unavailable: invalid template or values.'
    local text=L[key];return type(text)=='string' and #text<=SUMMARY_LIMIT and text or key
end
local function summaryScalar(value)
    local kind=type(value)
    if kind=='string' then return #value<=SUMMARY_LIMIT and value or nil end
    if kind=='boolean' or kind=='number' and value==value and value~=math.huge and value~=-math.huge then return tostring(value) end
end
function addon:CreateConditionSummaryPredicate(positive,negative,primary)
    if type(positive)~='string' or #positive>SUMMARY_LIMIT or negative~=nil and (type(negative)~='string' or #negative>SUMMARY_LIMIT) or primary~=nil and type(primary)~='boolean' then return invalidSummary() end
    return summaryObject({kind='predicate',positive=positive,negative=negative,primary=primary==true})
end
function addon:CreateConditionSummaryPhrase(template,values)
    if type(template)~='string' or #template>SUMMARY_LIMIT or type(values)~='table' or getmetatable(values)~=nil then return invalidSummary() end
    local copied,count={},0
    for key,value in pairs(values) do
        count=count+1
        if count>SUMMARY_PARTS or type(key)~='string' or not key:match('^[A-Za-z_][A-Za-z_0-9]*$') then return invalidSummary() end
        local predicate=type(value)=='table' and summaryRecords[value]
        if predicate and predicate.kind=='predicate' then copied[key]=predicate
        else copied[key]=summaryScalar(value);if copied[key]==nil then return invalidSummary() end end
    end
    local parts,index={},1
    local function add(part) parts[#parts+1]=part;return #parts<=SUMMARY_PARTS end
    while index<=#template do
        local head=template:sub(index,index+3)
        if head=='{{{{' or head=='}}}}' then
            if not add(head:sub(1,2)) then return invalidSummary() end;index=index+4
        elseif template:sub(index,index+1)=='{{' then
            local closing=template:find('}}',index+2,true);if not closing then return invalidSummary() end
            local body=template:sub(index+2,closing-1)
            local positive,negative=body:match('^([^|{}]*)|([^|{}]*)$');if not positive then return invalidSummary() end
            local primary=positive:sub(1,1)=='!';if primary then positive=positive:sub(2) end
            if not add({kind='predicate',positive=positive,negative=negative,primary=primary}) then return invalidSummary() end
            index=closing+2
        elseif template:sub(index,index)=='{' then
            local closing=template:find('}',index+1,true);if not closing then return invalidSummary() end
            local name=template:sub(index+1,closing-1)
            if not name:match('^[A-Za-z_][A-Za-z_0-9]*$') or copied[name]==nil or not add(copied[name]) then return invalidSummary() end
            index=closing+1
        elseif template:sub(index,index)=='}' then return invalidSummary()
        else
            local nextBrace=template:find('[{}]',index) or #template+1
            if not add(template:sub(index,nextBrace-1)) then return invalidSummary() end;index=nextBrace
        end
    end
    return summaryObject({kind='phrase',parts=parts})
end
function addon:RenderConditionSummary(result,negated)
    if type(result)=='string' then return self:RenderConditionPhrase(result,negated) end
    local record=type(result)=='table' and summaryRecords[result]
    if not record or record.kind~='phrase' then return summaryFallback() end
    local primary=false
    for _,part in ipairs(record.parts) do if type(part)=='table' and part.negative~=nil and part.primary then primary=true;break end end
    local output,bytes,first,predicates={},0,true,0
    for _,part in ipairs(record.parts) do
        local text=part
        if type(part)=='table' then
            local eligible=not primary or part.primary
            text=part.positive
            if part.negative~=nil then
                predicates=predicates+1
                if negated and first and eligible then text=part.negative end
                if eligible then first=false end
            end
        end
        bytes=bytes+#text;if bytes>SUMMARY_LIMIT then return summaryFallback() end
        output[#output+1]=text
    end
    local text=table.concat(output)
    if negated and predicates==0 then
        local ok,wrapped=pcall(string.format,L['not (%s)'],text)
        if not ok then return summaryFallback() end;text=wrapped
    end
    if #text>SUMMARY_LIMIT then return summaryFallback() end
    return text
end
---@param text string
---@return string
local function trimOuter(text)
    if text:sub(1,1)~='(' or text:sub(-1)~=')' then return text end
    local depth=0
    for i=1,#text do
        local c=text:sub(i,i)
        if c=='(' then depth=depth+1 elseif c==')' then depth=depth-1 end
        if depth==0 and i<#text or depth<0 then return text end
    end
    return depth==0 and text:sub(2,-2) or text
end

printArray = function(operation, array, spec)
    if array == nil then
        return ""
    end

    local rv = "("
    local first = true

    for _, entry in pairs(array) do
        if entry ~= nil and entry.type ~= nil then
            if first then
                first = false
            else
                rv = rv .. " " .. operation .. " "
            end

            rv = rv .. printSingle(entry, spec)
        end
    end

    rv = rv .. ")"

    return rv
end

printSingle = function(value, spec, negated)
    if value == nil or value.type == nil or value.disabled then
        return ""
    end

    if value.type == "AND" or value.type == "OR" then
        local text=printArray(value.type, value.value, spec)
        return negated and L['NOT']..' '..text or text
    elseif value.type == "NOT" then
        return printSingle(value.value, spec, not negated)
    elseif conditions[value.type] ~= nil then
        if conditions[value.type].disabled or conditions[value.type].functionUnavailable then return string.format(L['Unavailable condition: %s'],conditions[value.type].description or value.type) end
        return conditions[value.type].print(spec, value, negated)
    else
        return L["<INVALID CONDITION>"]
    end
end

validateArray = function(_, array, spec)
    if array == nil then
        return true
    end

    for _, entry in pairs(array) do
        if entry ~= nil and entry.type ~= nil then
            local rv
            if entry.type == "AND" or entry.type == "OR" then
                rv = validateArray(entry.type, entry.value, spec)
            else
                rv = validateSingle(entry, spec)
            end
            if not rv then
                return false
            end
        end
    end

    return true
end

validateSingle = function(value, spec)
    if value == nil or value.type == nil or value.disabled then
        return true
    end

    if value.type == "AND" or value.type == "OR" then
        return validateArray(value.type, value.value, spec)
    elseif value.type == "NOT" then
        return validateSingle(value.value, spec)
    elseif conditions[value.type] ~= nil then
        if conditions[value.type].disabled or conditions[value.type].functionUnavailable then return false end
        return conditions[value.type].valid(spec, value)
    else
        return false
    end
end

usefulArray = function(_, array)
    if array == nil then
        return false
    end

    for _, entry in pairs(array) do
        if entry ~= nil and entry.type ~= nil then
            local rv
            if entry.type == "AND" or entry.type == "OR" then
                rv = usefulArray(entry.type, entry.value)
            else
                rv = usefulSingle(entry)
            end
            if rv then
                return true
            end
        end
    end

    return false
end

usefulSingle = function(value)
    if value == nil or value.type == nil then
        return false
    end

    if value.type == "AND" or value.type == "OR" then
        return usefulArray(value.type, value.value)
    elseif value.type == "NOT" then
        return usefulSingle(value.value)
    elseif conditions[value.type] ~= nil then
        return true
    else
        return false
    end
end

function addon:RefreshConditionConsumers()
    -- Built-in and saved definitions register before runtime initialization.
    if self.currentSpec==nil or type(self.autoswitchRotation)~='table' or not self.UpdateAutoSwitch then return end
    self:UpdateAutoSwitch()
    if self.currentRotation and self.GetRuntimeRotation then
        local pass=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator() and self:AcquireRotationRuntimePass(self.currentSpec)
        local body;if pass then body=pass:Get(self.currentRotation) else body=self:GetRuntimeRotation(self.currentSpec,self.currentRotation) end
        if not body then self:DisableRotation() end
    end
    self:SwitchRotation()
end

function addon:ResetConditionQuarantine(definition) quarantined[definition]=nil end

function addon:RegisterCondition(tag, array)
    local availabilityChanged=(conditions[tag] and conditions[tag].disabled==true or false)~=(array.disabled==true)
    if conditions[tag] and not conditions[tag].disabled and not conditions[tag].functionUnavailable and not conditions[tag].functionSuspended and conditions[tag].on_unregister then
        conditions[tag].on_unregister(tag)
    end
    if type(array.print)=='function' and not printerSources[array.print] then
        local raw=array.print
        local wrapped=function(spec,value,negated) return addon:RenderConditionSummary(raw(spec,value),negated) end
        printerSources[wrapped]=raw;array.print=wrapped
    end
    conditions[tag] = array
    self.conditionRegistryVersion=(self.conditionRegistryVersion or 0)+1
    quarantined[array] = nil
    if not array.disabled and not array.functionUnavailable and array.on_register then
        array.on_register(tag)
    end
    if availabilityChanged then self:RefreshConditionConsumers() end
end

function addon:UnregisterCondition(tag)
    local wasDisabled=conditions[tag] and conditions[tag].disabled==true
    if conditions[tag] and not conditions[tag].disabled and not conditions[tag].functionUnavailable and not conditions[tag].functionSuspended and conditions[tag].on_unregister then
        conditions[tag].on_unregister(tag)
    end
    if conditions[tag]~=nil then self.conditionRegistryVersion=(self.conditionRegistryVersion or 0)+1 end
    conditions[tag] = nil
    if wasDisabled then self:RefreshConditionConsumers() end
end

function addon:evaluateConditionResult(value, context)
    return evaluate(value, {}, GetTime(), {active={}, count=0, context=context}, 0, "condition")
end

function addon:evaluateCondition(value, context)
    return self:evaluateConditionResult(value, context).status == "match"
end

function addon:printCondition(value, spec)
    return trimOuter(printSingle(value, spec))
end

function addon:validateCondition(value, spec)
    return validateSingle(value, spec)
end

function addon:usefulCondition(value)
    return usefulSingle(value)
end
]====],
    ["Core/functions.lua"] = [====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local reserved={['and']=true,['break']=true,['do']=true,['else']=true,['elseif']=true,['end']=true,['false']=true,['for']=true,['function']=true,['if']=true,['in']=true,['local']=true,['nil']=true,['not']=true,['or']=true,['repeat']=true,['return']=true,['then']=true,['true']=true,['until']=true,['while']=true}
local function identifier(name)
    return type(name)=='string' and #name<=128 and name:match('^[A-Za-z_][A-Za-z_0-9]*$')~=nil and not reserved[name]
end
local function text(value,limit,required) return type(value)=='string' and #value<=limit and (not required or value:find('%S')~=nil) end
local function array(value,limit)
    if type(value)~='table' or getmetatable(value) or #value>limit then return false end
    local count=0;for index in pairs(value) do count=count+1;if type(index)~='number' or index%1~=0 or index<1 or index>#value then return false end end
    return count==#value
end
function addon:IsCustomFunctionIdentifier(id) return identifier(id) and id~='addon' and id~='L' end
local namespaceRoots={addon=true,L=true,_G=true,_ENV=true,math=true,string=true,table=true,coroutine=true,debug=true,io=true,os=true,package=true,bit=true,bit32=true,utf8=true}
local function identifierPath(path,maxSegments)
    if type(path)~='string' or #path>512 or path=='' or path:sub(1,1)=='.' or path:sub(-1)=='.' or path:find('..',1,true) then return nil end
    local parts={};for part in path:gmatch('[^.]+') do if not identifier(part) then return nil end;parts[#parts+1]=part end
    if #parts>(maxSegments or 8) then return nil end
    return parts
end
function addon:IsFunctionNamespace(namespace)
    if namespace=='' then return true end
    -- Leave room for the separator and a maximum-length callable name inside
    -- the same bounded 512-byte binding path.
    if type(namespace)~='string' or #namespace>383 then return false end
    local parts=identifierPath(namespace,7);return parts~=nil and not namespaceRoots[parts[1]]
end
function addon:FunctionNamespace(id,source)
    if type(source)=='table' and type(source.namespace)=='string' and source.namespace~='' and self:IsFunctionNamespace(source.namespace) then return source.namespace end
    local module=type(id)=='string' and id:match('^builtin:(.-):[^:]+$')
    if module then return module:gsub('%.lua$',''):gsub('[/\\]','.') end
    if type(id)=='string' and id:match('^builtin:') then return 'builtin' end
    return 'functions'
end
function addon:FunctionQualifiedName(id,source)
    return self:FunctionNamespace(id,source)..'.'..self:FunctionEditorName(id,source)
end
-- Registry IDs remain stable across name edits; a binding exposes this suggested
-- local name in a caller. Existing exports with descriptive names still load.
function addon:FunctionEditorName(id,source)
    local name=source and source.name
    if self:IsCustomFunctionIdentifier(name) then return name end
    name=type(name)=='string' and name:gsub('[^A-Za-z_0-9]','_'):gsub('^%d+','') or ''
    if name=='' then name=tostring(id or 'helper'):gsub('[^A-Za-z_0-9]','_'):gsub('^%d+','') end
    name=name:sub(1,128)
    if not self:IsCustomFunctionIdentifier(name) then name='helper_'..name:sub(1,121) end
    return name
end
function addon:NormalizeFunctionBindings(bindings,arguments)
    if bindings==nil then return {} end
    if type(bindings)~='table' or getmetatable(bindings) then return nil,'invalid-function-bindings' end
    local result,count={},0;local names={addon=true,L=true};for _,argument in ipairs(arguments or {}) do names[argument.name]=true end
    for alias,id in pairs(bindings) do
        count=count+1
        local parts=identifierPath(alias)
        if count>128 or not parts or names[parts[1]] or #parts>1 and namespaceRoots[parts[1]] or not text(id,512,true) then return nil,'invalid-function-bindings' end
        result[alias]=id
    end
    local occupied={};for alias,id in pairs(result) do occupied[alias]=id end
    if not names.functions and not result.functions then for alias,id in pairs(result) do if not alias:find('.',1,true) then
        local path='functions.'..alias;if occupied[path] and occupied[path]~=id then return nil,'invalid-function-bindings' end;occupied[path]=id
    end end end
    for alias in pairs(occupied) do
        local prefix='';for part in alias:gmatch('[^.]+') do
            if prefix~='' and occupied[prefix] then return nil,'invalid-function-bindings' end
            prefix=prefix=='' and part or prefix..'.'..part
        end
    end
    return result
end
function addon:FunctionBindingPrelude(bindings,parameters)
    local arguments={};for name in (parameters or ''):gmatch('[A-Za-z_][A-Za-z_0-9]*') do arguments[#arguments+1]={name=name} end
    local normalized,why=self:NormalizeFunctionBindings(bindings,arguments);if not normalized then return nil,why end
    bindings=normalized;local keys={};for alias in pairs(bindings) do keys[#keys+1]=alias end;table.sort(keys)
    local lines,created={},{}
    local function namespace(path)
        local prefix='';for part in path:gmatch('[^.]+') do
            local parent=prefix;prefix=prefix=='' and part or prefix..'.'..part
            if not created[prefix] then lines[#lines+1]=(parent=='' and 'local ' or '')..prefix..'={}';created[prefix]=true end
        end
    end
    for _,alias in ipairs(keys) do local parent=alias:match('^(.*)%.');if parent then namespace(parent) end end
    for _,alias in ipairs(keys) do lines[#lines+1]=(alias:find('.',1,true) and '' or 'local ')..alias..'=addon:RequireFunctionBinding('..string.format('%q',bindings[alias])..')' end
    local shadowed=bindings and bindings.functions
    for name in (parameters or ''):gmatch('[A-Za-z_][A-Za-z_0-9]*') do if name=='functions' then shadowed=true end end
    if not shadowed then
        namespace('functions');for _,alias in ipairs(keys) do if not alias:find('.',1,true) then lines[#lines+1]='functions.'..alias..'='..alias end end
    end
    return table.concat(lines,'\n')
end
function addon:NormalizeLuaSourceForEditor(code)
    code=(code or ''):gsub('^[ \t\r]*\n','')
    while code:match('^[ \t\r]*\n') do code=code:gsub('^[ \t\r]*\n','') end
    local syntax=self.LuaSyntax
    -- Use the existing Lua tokenizer/formatter so multiline literals retain
    -- their contents; stripping whitespace from every line would change them.
    if syntax and syntax.indentCode then code=syntax.decode(syntax.indentCode(syntax.encode(code),4)) end
    return code
end
function addon:CompileLuaCallbackBody(code,parameters,bindings,chunkName)
    if type(loadstring)~='function' then return nil,'compiler-unavailable' end
    -- A valid generated wrapper alone is insufficient: an unmatched `end` in
    -- the supplied body can escape into its return list and run at bind time.
    -- Check the body as an independent chunk first. Neither chunk is executed.
    local body,why=loadstring(code,chunkName);if not body then return nil,why end
    local prelude,problem=self:FunctionBindingPrelude(bindings,parameters);if not prelude then return nil,problem end
    return loadstring('return function(addon,L) return function('..parameters..')\n'..prelude..'\n'..code..'\nend end',chunkName)
end
function addon:ValidateCustomFunctionSource(id,source)
    if not self:IsCustomFunctionIdentifier(id) then return nil,'invalid-function-identifier' end
    if type(source)~='table' or getmetatable(source) or not text(source.description,4096,true) or not text(source.code,65536) or source.name~=nil and not text(source.name,256) or source.disabled~=nil and type(source.disabled)~='boolean' then return nil,'invalid-function-source' end
    if source.namespace~=nil and not self:IsFunctionNamespace(source.namespace) then return nil,'invalid-function-namespace' end
    local allowed={name=true,namespace=true,description=true,args=true,returns=true,code=true,bindings=true,disabled=true}
    for field in pairs(source) do if not allowed[field] then return nil,'unknown-function-field' end end
    if not array(source.args,32) or not array(source.returns,16) then return nil,'invalid-function-arguments' end
    local names={addon=true,L=true}
    for index,argument in ipairs(source.args) do
        if type(argument)~='table' or getmetatable(argument) or not identifier(argument.name) and not (argument.name=='...' and index==#source.args) or names[argument.name] or not text(argument.type,128,true) or not text(argument.description or '',2048) then return nil,'invalid-function-arguments' end
        names[argument.name]=true;for field in pairs(argument) do if field~='name' and field~='type' and field~='description' then return nil,'invalid-function-arguments' end end
    end
    for _,result in ipairs(source.returns) do
        if type(result)~='table' or getmetatable(result) or not text(result.type,128,true) or not text(result.description or '',2048) then return nil,'invalid-function-returns' end
        for field in pairs(result) do if field~='type' and field~='description' then return nil,'invalid-function-returns' end end
    end
    local bindings,why=self:NormalizeFunctionBindings(source.bindings,source.args);if not bindings then return nil,why end
    if source.disabled then return {bindings=bindings} end
    local params={};for _,argument in ipairs(source.args) do params[#params+1]=argument.name end
    local chunk,errorText=self:CompileLuaCallbackBody(source.code,table.concat(params,','),bindings,'@RotationMaster:function:'..id)
    if not chunk then return nil,errorText end
    return {bindings=bindings,chunk=chunk}
end
function addon:RegisterBuiltinFunction(id,source,getter,valueBinding)
    if type(id)~='string' or not id:match('^builtin:') or #id>512 or type(source)~='table' or type(getter)~='function' then return false end
    self.builtinFunctions=self.builtinFunctions or {};if self.builtinFunctions[id] then return false end
    self.builtinFunctions[id]={source=source,get=getter,valueBinding=valueBinding==true};return true
end
function addon:BuildFunctionRegistry(sources)
    if type(sources)~='table' or getmetatable(sources) then return nil,'invalid-function-registry' end
    local result={};local count=0
    for id,source in pairs(sources or {}) do
        count=count+1;if count>4096 then return nil,'function-limit' end
        local checked,why=self:ValidateCustomFunctionSource(id,source);local previous=self.functionRegistry and self.functionRegistry[id]
        local record={source=source,problem=why,bindings=checked and checked.bindings or {}};result[id]=record
        if checked and checked.chunk then
            if previous and previous.fn and self:SettingsDataEqual(previous.source,source) then record.fn=previous.fn
            else
                local ok,binder=pcall(checked.chunk)
                if ok and type(binder)=='function' then local bound,fn=pcall(binder,self,L);if bound and type(fn)=='function' then record.fn=fn else record.problem='function-compile-failed' end
                else record.problem='function-compile-failed' end
            end
        end
    end
    return result
end
function addon:InitializeFunctionRegistry()
    self.functionRegistry=self:BuildFunctionRegistry(self.db.global.custom_functions or {}) or {};self.functionRegistryVersion=(self.functionRegistryVersion or 0)+1
end
function addon:FunctionAvailable(id,registry,active,depth,memo)
    registry=registry or self.functionRegistry;if not registry then self:InitializeFunctionRegistry();registry=self.functionRegistry end
    if self.builtinFunctions and self.builtinFunctions[id] then return true end
    memo=memo or {};if memo[id] then return memo[id][1],memo[id][2] end
    depth=(depth or 0)+1;if depth>64 then return nil,'function-depth' end
    active=active or {};if active[id] then return nil,'function-cycle' end
    local record=registry[id];if not record then return nil,'missing-function' end
    if record.problem then return nil,record.problem end
    if record.source.disabled then return nil,'disabled-function' end
    if not record.fn then return nil,'function-compile-failed' end
    active[id]=true
    for _,dependency in pairs(record.bindings) do local ok,why=self:FunctionAvailable(dependency,registry,active,depth,memo);if not ok then active[id]=nil;memo[id]={false,why};return nil,why end end
    active[id]=nil;memo[id]={true};return true
end
function addon:AreFunctionBindingsAvailable(bindings,registry)
    for _,id in pairs(bindings or {}) do local ok,why=self:FunctionAvailable(id,registry);if not ok then return nil,why end end;return true
end
function addon:ResolveFunctionBinding(id)
    local ok,why=self:FunctionAvailable(id);if not ok then return nil,why end
    local builtin=self.builtinFunctions and self.builtinFunctions[id]
    if builtin then
        local read,value=pcall(builtin.get);if not read then return nil,'builtin-binding-unavailable' end
        if not builtin.valueBinding and type(value)~='function' then return nil,'builtin-function-unavailable' end
        return value
    end
    return self.functionRegistry[id].fn
end
function addon:RequireFunctionBinding(id)
    local value,why=self:ResolveFunctionBinding(id);if why then error('Rotation Master function unavailable: '..tostring(id)..' ('..why..')',2) end;return value
end
-- Release resources while the old helper graph is still usable. A later
-- refresh resumes suspended consumers only after the new graph is installed.
function addon:PrepareFunctionConsumerTransition(registry)
    local cleaned={}
    for id,definition in pairs(self.conditionDefinitions or {}) do
        if definition.functionBindings and not definition.disabled and not definition.functionUnavailable and not definition.functionSuspended and not self:AreFunctionBindingsAvailable(definition.functionBindings,registry) then
            local ok=true;if definition.on_unregister then ok=pcall(definition.on_unregister,id) end
            if not ok then
                for _,entry in ipairs(cleaned) do entry[2].functionSuspended=nil;if entry[2].on_register then pcall(entry[2].on_register,entry[1]) end end
                return nil,'function-consumer-cleanup-failed'
            end
            definition.functionSuspended=true;cleaned[#cleaned+1]={id,definition}
        end
    end
    return true
end
-- Staged imports defer runtime selection refresh until commit and retain every
-- resume attempt so rollback can release partially initialized hook resources.
function addon:RefreshFunctionConsumers(deferRefresh)
    local successful,attempted=true,{}
    for id,definition in pairs(self.conditionDefinitions or {}) do
        if definition.functionBindings then
            local ok,why=self:AreFunctionBindingsAvailable(definition.functionBindings)
            definition.functionUnavailable=not ok and why or nil
            if ok and definition.functionSuspended and not definition.disabled then
                attempted[#attempted+1]={id=id,definition=definition}
                local registered=true;if definition.on_register then registered=pcall(definition.on_register,id) end
                if registered then definition.functionSuspended=nil else successful=false;definition.functionUnavailable='function-consumer-registration-failed' end
            end
            if self.ResetConditionQuarantine then self:ResetConditionQuarantine(definition) end
        end
    end
    self.conditionRegistryVersion=(self.conditionRegistryVersion or 0)+1
    if not deferRefresh and self.RefreshConditionConsumers then self:RefreshConditionConsumers() end
    return successful,not successful and 'function-consumer-registration-failed' or nil,attempted
end
function addon:InstallCustomFunction(id,source,expected)
    if not self:IsCustomFunctionIdentifier(id) then return nil,'invalid-function-identifier' end
    local current=(self.db.global.custom_functions or {})[id]
    if not self:SettingsDataEqual(current,expected) then return nil,'function-changed' end
    local checked,why=self:ValidateCustomFunctionSource(id,source);if not checked then return nil,why end
    local sources=self:CopySettingsData(self.db.global.custom_functions or {});sources[id]=self:CopySettingsData(source)
    local registry,problem=self:BuildFunctionRegistry(sources);if not registry then return nil,problem end
    if not source.disabled then local available,reason=self:FunctionAvailable(id,registry);if not available then return nil,reason end end
    local prepared,prepareError=self:PrepareFunctionConsumerTransition(registry);if not prepared then return nil,prepareError end
    self.db.global.custom_functions=sources;self.functionRegistry=registry;self.functionRegistryVersion=(self.functionRegistryVersion or 0)+1;self:RefreshFunctionConsumers();return true
end
function addon:RemoveCustomFunction(id,expected)
    local current=(self.db.global.custom_functions or {})[id];if not current or not self:SettingsDataEqual(current,expected) then return nil,'function-changed' end
    local sources=self:CopySettingsData(self.db.global.custom_functions);sources[id]=nil;local registry,why=self:BuildFunctionRegistry(sources);if not registry then return nil,why end
    local prepared,prepareError=self:PrepareFunctionConsumerTransition(registry);if not prepared then return nil,prepareError end
    self.db.global.custom_functions=sources;self.functionRegistry=registry;self.functionRegistryVersion=(self.functionRegistryVersion or 0)+1;self:RefreshFunctionConsumers();return true
end
]====],
    ["Core/custom_authoring.lua"] = [====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local docs={
    evaluate={description=L['Decide whether this condition currently matches.'],args={{'value','table',L['The stored values for this condition.']},{'cache','table',L['Shared data for this evaluation cycle.']},{'evalStart','number',L['Evaluation start time, in seconds from GetTime().']}},returns={'boolean | nil',L['True matches; false or nil does not match.']}},
    valid={description=L['Check whether the stored condition values are complete and valid.'],args={{'spec','number',L['Rotation specialization scope.']},{'value','table',L['The stored values for this condition.']}},returns={'boolean',L['True when the condition can be evaluated.']}},
    print={description=L['Describe the condition in readable words.'],args={{'spec','number',L['Rotation specialization scope.']},{'value','table',L['The stored values for this condition.']}},returns={'string | RMConditionPhrase',L['A readable string, or a transient named phrase from Functions.presentation.phrase. Named values remain literal; typed predicates choose positive or negative wording. The legacy string format remains supported.']}},
    widget={description=L['Build the controls used to edit this condition.'],args={{'parent','RMConditionGroup',L['The condition field container supplied by the UI adapter.']},{'spec','number',L['Rotation specialization scope.']},{'value','table',L['The stored values for this condition.']}},returns={'nil',L['Add controls to the supplied container.']}},
    help={description=L['Build the help content for this condition.'],args={{'frame','RMConditionGroup',L['The help container supplied by the UI adapter.']}},returns={'nil',L['Add help content to the supplied container.']}},
    on_register={description=L['Initialize resources when the condition is registered.'],args={{'tag','string',L['The condition identifier.']}},returns={'nil',L['No return value is used.']}},
    on_unregister={description=L['Release resources when the condition is removed or replaced.'],args={{'tag','string',L['The condition identifier.']}},returns={'nil',L['No return value is used.']}},
}
local callbacks={}
for name,entry in pairs(docs) do local args={};for _,arg in ipairs(entry.args) do args[#args+1]=arg[1] end;callbacks[name]=table.concat(args,', ') end
addon.CustomConditionCallbacks=callbacks;addon.CustomConditionCallbackDocs=docs
function addon:CustomConditionDocumentation(name)
    local doc=docs[name];if not doc then return '' end
    local lines={doc.description,'|cffffcc55'..L['Arguments']..'|r'}
    for _,arg in ipairs(doc.args) do lines[#lines+1]='|cffffcc55'..arg[1]..'|r (|cff66ccff'..arg[2]..'|r): '..arg[3] end
    lines[#lines+1]='|cffffcc55'..L['Returns']..'|r |cff66ccff'..doc.returns[1]..'|r: '..doc.returns[2]
    return table.concat(lines,'\n')
end
local kinds={string=true,number=true,boolean=true,condition=true,['condition[]']=true}
function addon:FormatCustomFieldSchema(fields)
    local normalized,why=self:NormalizeCustomFieldSchema(fields,true);if not normalized then return nil,why end
    local function format(value)
        if type(value)=='string' then return value end
        local keys={};for key in pairs(value) do keys[#keys+1]=key end;table.sort(keys)
        local parts={};for _,key in ipairs(keys) do parts[#parts+1]=(type(key)=='string' and (key:match('^[%a_][%w_]*$') and key or '['..string.format('%q',key)..']')..' = ' or '')..format(value[key]) end
        return '{ '..table.concat(parts,', ')..' }'
    end
    return format(normalized)
end
function addon:ParseCustomFieldSchema(text)
    -- 512 nodes with valid 64-byte field names can exceed 32 KiB. Keep
    -- byte work bounded while allowing every newly supported graph to roundtrip.
    if type(text)~='string' or #text>65536 then return nil,'schema-limit' end
    local cursor,nodes=1,0
    local function skip() local _,last=text:find('^%s*',cursor);cursor=(last or cursor-1)+1 end
    local function token(pattern) skip();local first,last=text:find('^'..pattern,cursor);if first then local v=text:sub(first,last);cursor=last+1;return v end end
    local parse
    parse=function(depth)
        nodes=nodes+1;if depth>16 or nodes>512 then error('schema-limit',0) end
        if token('{') then
            local result,index={},1
            if token('}') then return result end
            repeat
                local start=cursor;local name=token('[%a_][%w_]*');local key
                if not name and token('%[') then
                    local quote=token('"') or token("'");if not quote then error('invalid-field-name',0) end
                    local pieces={};local closed=false
                    while cursor<=#text do
                        local ch=text:sub(cursor,cursor);cursor=cursor+1
                        if ch==quote then closed=true;break end
                        if ch=='\\' then ch=text:sub(cursor,cursor);cursor=cursor+1;if ch~=quote and ch~='\\' then error('invalid-field-name',0) end end
                        pieces[#pieces+1]=ch
                    end
                    if not closed or not token('%]') then error('invalid-field-name',0) end;name=table.concat(pieces)
                end
                if name and token('=') then key=name else cursor=start;key=index;index=index+1 end
                if result[key]~=nil then error('duplicate-field',0) end
                result[key]=parse(depth+1)
                if token('}') then return result end
                if not token(',') then error('expected-comma',0) end
            until false
        end
        local kind=token('[%a_][%w_]*%[%]') or token('[%a_][%w_]*')
        if not kinds[kind] then error('unknown-field-type',0) end;return kind
    end
    local ok,value=pcall(parse,0);if not ok then return nil,value end;skip();if cursor<=#text then return nil,'unexpected-schema-text' end
    return self:NormalizeCustomFieldSchema(value,true)
end
function addon:NormalizeCustomConditionParameters(parameters)
    if parameters==nil then return {} end
    if type(parameters)~='table' or getmetatable(parameters) then return nil,'invalid-callback-parameters' end
    local result={}
    for name,args in pairs(parameters) do
        if not callbacks[name] or type(args)~='table' or getmetatable(args) or #args>32 then return nil,'invalid-callback-parameters' end
        local count=0;for index in pairs(args) do count=count+1;if type(index)~='number' or index%1~=0 or index<1 or index>#args then return nil,'invalid-callback-parameters' end end
        if count~=#args then return nil,'invalid-callback-parameters' end
        for index,arg in ipairs(args) do if type(arg)~='string' or not arg:match('^[A-Za-z_][A-Za-z_0-9]*$') and not (arg=='...' and index==#args) then return nil,'invalid-callback-parameters' end end
        result[name]=self:CopySettingsData(args)
    end
    return result
end
function addon:NormalizeCustomConditionRequiredFields(required,fields)
    if type(required)~='table' or getmetatable(required) or #required>128 then return nil end
    local result,seen={},{};local count=0
    for index in pairs(required) do count=count+1;if type(index)~='number' or index%1~=0 or index<1 or index>#required then return nil end end
    if count~=#required then return nil end
    for _,name in ipairs(required) do if type(name)~='string' or fields[name]==nil or seen[name] then return nil end;seen[name]=true;result[#result+1]=name end
    return result
end
function addon:CustomConditionSignature(source,name)
    return 'function('..callbacks[name]..')'
end
function addon:CustomConditionParameterAliases(source,name)
    local aliases={};local doc=docs[name]
    for index,original in ipairs(source.parameters and source.parameters[name] or {}) do
        local canonical=doc and doc.args[index] and doc.args[index][1]
        if canonical and original~='...' and original~=canonical then aliases[original]=canonical end
    end
    return aliases
end
function addon:CompileCustomConditionCallback(key,name,code,bindings,parameters)
    local params=callbacks[name]
    if not params or type(code)~='string' then return nil,'invalid-callback' end
    local names,values={},{};for alias,canonical in pairs(self:CustomConditionParameterAliases({parameters=parameters},name)) do names[#names+1]=alias;values[#values+1]=canonical end
    -- Original packaged names stay compatible while the editor and new code
    -- always receive the complete public callback contract.
    local aliases=#names>0 and 'local '..table.concat(names,',')..'='..table.concat(values,',')..'\n' or ''
    return self:CompileLuaCallbackBody(aliases..code,params,bindings,'@RotationMaster:custom:'..tostring(key):sub(1,128)..':'..name)
end
function addon:ValidateCustomConditionSource(key,source,compatibility,allowUnavailable)
    if type(loadstring)~='function' then return nil,{field='compiler',reason='compiler-unavailable'} end
    if not self:IsCustomConditionIdentifier(key,compatibility) then return nil,{field='identifier',reason='invalid-identifier'} end
    if type(source)~='table' or type(source.description)~='string' or not source.description:find('%S') or not compatibility and #source.description>4096 or not self:IsCategoryIcon(source.icon) then return nil,{field='description',reason='incomplete-definition'} end
    if source.disabled~=nil and type(source.disabled)~='boolean' then return nil,{field='disabled',reason='invalid-disabled-flag'} end
    if not compatibility then for field in pairs(source) do if field~='description' and field~='icon' and field~='fields' and field~='disabled' and field~='fieldOrder' and field~='bindings' and field~='parameters' and field~='requiredFields' and not callbacks[field] then return nil,{field=field,reason='unknown-field'} end end end
    local fields,why=self:NormalizeCustomFieldSchema(source.fields,true);if not fields then return nil,{field='fields',reason=why} end
    if source.fieldOrder~=nil and not self:NormalizeCustomFieldOrder(source.fieldOrder,fields) then return nil,{field='fields',reason='invalid-field-order'} end
    local parameters,parameterError=self:NormalizeCustomConditionParameters(source.parameters);if not parameters then return nil,{field='parameters',reason=parameterError} end
    local bindings,unavailable
    if source.bindings~=nil then
        local arguments={{name='value'},{name='cache'},{name='evalStart'},{name='spec'},{name='parent'},{name='frame'},{name='tag'}}
        for _,aliases in pairs(parameters) do for _,name in ipairs(aliases) do arguments[#arguments+1]={name=name} end end
        local why;bindings,why=self:NormalizeFunctionBindings(source.bindings,arguments)
        if not bindings then return nil,{field='bindings',reason=why} end
        local available,problem=self:AreFunctionBindingsAvailable(bindings);if not available then if not allowUnavailable then return nil,{field='bindings',reason=problem} end;unavailable=problem end
    end
    local required;if source.requiredFields then required=self:NormalizeCustomConditionRequiredFields(source.requiredFields,fields);if not required then return nil,{field='requiredFields',reason='invalid-required-fields'} end end
    local compiled,total={},0
    for name in pairs(callbacks) do
        local code=source[name];if type(code)~='string' or not compatibility and #code>65536 then return nil,{callback=name,reason='code-limit'} end;total=total+#code;if not compatibility and total>262144 then return nil,{callback=name,reason='code-limit'} end
        local fn,errorText=self:CompileCustomConditionCallback(key,name,code,bindings,parameters)
        if not fn then return nil,{callback=name,reason='syntax-error',detail=errorText} end
        compiled[name]=fn
    end
    return {valid=true,compiled=compiled,fields=fields,bindings=bindings,parameters=parameters,requiredFields=required,unavailable=unavailable}
end
function addon:CompileCustomCondition(key,source,compatibility)
    if type(source)=='table' and source.disabled==true then
        if not self:IsCustomConditionIdentifier(key,true) then return nil,{field='identifier',reason='invalid-identifier'} end
        return {description=source.description or key,icon=source.icon,fields=self:NormalizeCustomFieldSchema(source.fields,true) or {},customCode=true,disabled=true}
    end
    local checked,why=self:ValidateCustomConditionSource(key,source,compatibility,true);if not checked then return nil,why end
    local definition={description=source.description,icon=source.icon,fields=checked.fields,customCode=true,functionBindings=checked.bindings,requiredFields=checked.requiredFields,functionUnavailable=checked.unavailable,functionSuspended=checked.unavailable~=nil}
    for name,chunk in pairs(checked.compiled) do
        local ok,binder=pcall(chunk);if not ok or type(binder)~='function' then return nil,{callback=name,reason='compile-failed'} end
        local bound,fn=pcall(binder,self,L);if not bound or type(fn)~='function' then return nil,{callback=name,reason='compile-failed'} end;definition[name]=fn
    end
    return definition
end
function addon:InstallCustomCondition(key,source,expected,expectedSource)
    local registry=self.conditionDefinitions or self.definitions;local previous=registry and registry[key]
    if previous~=expected or previous and not (self.db.global.custom_conditions or {})[key] then return false,{field='identifier',reason='definition-changed'} end
    local saved=(self.db.global.custom_conditions or {})[key]
    if saved~=nil and previous==nil and expectedSource==nil or expectedSource~=nil and not self:SettingsDataEqual(saved,expectedSource) then return false,{field='identifier',reason='definition-changed'} end
    local definition,why=self:CompileCustomCondition(key,source,expectedSource~=nil);if not definition then return false,why end
    local ok
    if self.Diagnostics then ok=self.Diagnostics:Call({module='custom_conditions',operation='register',conditionTag=key,customCode=true},self.RegisterCondition,self,key,definition)
    else ok=pcall(self.RegisterCondition,self,key,definition) end
    if not ok then
        if registry then registry[key]=previous end
        -- Trusted hooks can have arbitrary external effects. Restore registry
        -- and saved source; restoring the prior hook's setup is best effort.
        if previous and not previous.disabled and previous.on_register then pcall(previous.on_register,key) end
        return false,{field='registration',reason='registration-failed'}
    end
    self.db.global.custom_conditions=self.db.global.custom_conditions or {};self.db.global.custom_conditions[key]=self:CopySettingsData(source);return true
end
function addon:NewCustomConditionDraft(key,source)
    local d={key=key or '',value=self:CopySettingsData(source),undo={},redo={},bytes=0}
    d.baseline={key=d.key,value=self:CopySettingsData(d.value)}
    local function weight(v) if type(v)=='string' then return #v+24 elseif type(v)~='table' then return 16 end;local n=64;for k,c in pairs(v) do n=n+weight(k)+weight(c) end;return n end
    function d:Snapshot() return addon:CopySettingsData({key=self.key,value=self.value,context=self.context}) end
    function d:IsDirty() return not addon:SettingsDataEqual(self:Snapshot(),self.baseline) end
    function d:Change(change)
        local before=self:Snapshot();change(self)
        if addon:SettingsDataEqual(before,self:Snapshot()) then return false end
        self.undo[#self.undo+1]=before;self.redo={};self.bytes=0;for _,v in ipairs(self.undo) do self.bytes=self.bytes+weight(v) end
        while #self.undo>100 or self.bytes>4194304 do self.bytes=self.bytes-weight(table.remove(self.undo,1)) end;return true
    end
    function d:SetFunction(name,code) if not callbacks[name] then return false end;return self:Change(function(state) state.value[name]=code end) end
    function d:Travel(redo)
        local from=redo and self.redo or self.undo;local to=redo and self.undo or self.redo;if #from==0 then return false end
        to[#to+1]=self:Snapshot();local state=table.remove(from);self.key=state.key;self.value=state.value;self.context=state.context;return true
    end
    function d:Undo() return self:Travel(false) end
    function d:Redo() return self:Travel(true) end
    function d:MarkSaved() self.baseline=self:Snapshot();self.undo={};self.redo={};self.bytes=0 end
    return d
end
]====],
    ["Core/function_data.lua"] = [====[local _,addon=...
local MAX_ENTRIES,MAX_BYTES,MAX_DEPTH=128,1048576,64
-- Bound and reject hostile data before any recursive copy or source compilation.
local function portable(value)
    local active,nodes,bytes={},0,0
    local function visit(v,depth)
        nodes=nodes+1;if nodes>50000 or depth>MAX_DEPTH then return false end
        local kind=type(v)
        if kind=='string' then bytes=bytes+#v;return bytes<=MAX_BYTES
        elseif kind=='nil' or kind=='boolean' then return true
        elseif kind=='number' then return v==v and v~=math.huge and v~=-math.huge
        elseif kind~='table' or getmetatable(v) or active[v] then return false end
        active[v]=true
        for k,c in pairs(v) do if type(k)~='string' and type(k)~='number' or not visit(k,depth+1) or not visit(c,depth+1) then return false end end
        active[v]=nil;return true
    end
    return visit(value,0)
end
local function dense(value)
    if type(value)~='table' or #value>MAX_ENTRIES then return false end
    local n=0;for k in pairs(value) do n=n+1;if type(k)~='number' or k%1~=0 or k<1 or k>#value then return false end end
    return n==#value
end
local function fields(value,allowed)
    if type(value)~='table' then return false end
    for k in pairs(value) do if not allowed[k] then return false end end;return true
end
local function identity(id) return type(id)=='string' and #id>0 and #id<=512 and not id:find('%c') end
local function name(value) return value==nil or type(value)=='string' and #value<=256 end
local function builtin(id) return type(id)=='string' and id:sub(1,8)=='builtin:' end
local function keys(value) local r={};for k in pairs(value or {}) do r[#r+1]=k end;table.sort(r);return r end
local function canonical(value)
    if type(value)~='table' then return type(value)..':'..tostring(value) end
    local ordered={};for k in pairs(value) do ordered[#ordered+1]=k end
    table.sort(ordered,function(a,b) if type(a)==type(b) then return a<b end;return type(a)<type(b) end)
    local out={'{'};for _,k in ipairs(ordered) do local v=canonical(value[k]);local key=canonical(k);out[#out+1]=#key..':'..key..#v..':'..v end;out[#out+1]='}';return table.concat(out)
end
function addon:FunctionSourceHash(source)
    if not portable(source) then return nil end
    local hash=5381;local text=canonical(source);for i=1,#text do hash=(hash*33+text:byte(i))%4294967296 end
    return string.format('%08x',hash)
end
-- Explicit bindings are the only remappable helper reference. Ignore comments
-- and strings when detecting handwritten resolver calls, without executing Lua.
local function manualReference(code)
    local tokens,i={},1
    while i<=#code do
        local rest=code:sub(i);local prefix=rest:match('^%-%-%[(=*)%[')
        local long=rest:match('^%[(=*)%[')
        if prefix~=nil or long~=nil then
            local equal=prefix or long;local start=i+(prefix~=nil and 4 or 2)+#equal
            local first,last=code:find(']'..equal..']',start,true)
            if prefix==nil then
                local literal=code:sub(start,(first or #code+1)-1)
                tokens[#tokens+1]=(literal=='RequireFunctionBinding' or literal=='ResolveFunctionBinding') and 'resolver-string' or 'string'
            end
            i=last and last+1 or #code+1
        elseif rest:sub(1,2)=='--' then local last=code:find('\n',i+2,true);i=last or #code+1
        elseif rest:sub(1,1)=='"' or rest:sub(1,1)=="'" then
            local quote=rest:sub(1,1);local start=i;i=i+1
            while i<=#code do local ch=code:sub(i,i);i=i+1;if ch=='\\' then i=i+1 elseif ch==quote then break end end
            local literal=code:sub(start+1,i-2)
            if literal=='RequireFunctionBinding' or literal=='ResolveFunctionBinding' then tokens[#tokens+1]='resolver-string' else tokens[#tokens+1]='string' end
        else
            local word=rest:match('^[A-Za-z_][A-Za-z_0-9]*')
            if word then tokens[#tokens+1]=word;i=i+#word else local ch=rest:sub(1,1);if not ch:match('%s') then tokens[#tokens+1]=ch end;i=i+1 end
        end
    end
    local receivers={addon=true}
    for index,token in ipairs(tokens) do
        if tokens[index+1]=='=' and receivers[tokens[index+2]] then receivers[token]=true end
        -- Computed access on the RM namespace cannot provide a stable helper
        -- identity. Diagnose it instead of guessing what the Lua will resolve.
        if receivers[token] and tokens[index+1]=='[' or (token=='RequireFunctionBinding' or token=='ResolveFunctionBinding') and (tokens[index-1]==':' or tokens[index-1]=='.') or token=='resolver-string' and tokens[index-1]=='[' then return true end
    end
end
local function checkSource(self,kind,id,source)
    if type(source)~='table' then return nil,'invalid-bundle-source' end
    if kind=='function' then
        if type(source.code)=='string' and manualReference(source.code) then return nil,'explicit-function-binding-required' end
        return self:ValidateCustomFunctionSource(builtin(id) and 'IMPORTED_BUILTIN' or id,source)
    end
    if kind~='condition' then return nil,'invalid-bundle-kind' end
    for callback in pairs(self.CustomConditionCallbacks or {}) do if type(source[callback])=='string' and manualReference(source[callback]) then return nil,'explicit-function-binding-required' end end
    return self:ValidateCustomConditionSource(id,source,false,true)
end
local function lookup(self,id)
    local built=self.builtinFunctions and self.builtinFunctions[id]
    return built and built.source or (self.db.global.custom_functions or {})[id],built~=nil
end
local function requirementHashMatches(self,requirement,current,isBuiltin)
    if self:FunctionSourceHash(current)==requirement.hash then return true end
    if not isBuiltin then return false end
    -- A declared ownership move may change only its source namespace. Keep
    -- executable bodies, arguments, bindings and documentation in the hash.
    local builtinRecord=self.builtinFunctions and self.builtinFunctions[requirement.id]
    for _,namespace in ipairs(builtinRecord and builtinRecord.compatibilityNamespaces or {}) do
        local previous=self:CopySettingsData(current);previous.namespace=namespace
        if self:FunctionSourceHash(previous)==requirement.hash then return true end
    end
    -- Older packaged catalogs used the captured local alias as the display
    -- name and had no namespace metadata. Reconstruct only that exact shape;
    -- executable code, arguments, bindings and documentation remain hashed.
    local alias=requirement.id:match('^builtin:.*:([^:]+)$') or requirement.id:match('^builtin:([^:]+)$')
    if not alias then return false end
    local legacy=self:CopySettingsData(current);legacy.namespace=nil;legacy.name=alias
    return self:FunctionSourceHash(legacy)==requirement.hash
end
function addon:BuildFunctionBundle(kind,id,source,includeDependencies)
    if kind~='function' and kind~='condition' or not identity(id) then return nil,'invalid-bundle-root' end
    source=source or (kind=='function' and lookup(self,id) or (self.db.global.custom_conditions or {})[id])
    if not portable(source) then return nil,'bundle-data-limit' end
    local checked,why=checkSource(self,kind,id,source);if not checked then return nil,why end
    local bundle={format='RM-FunctionBundle',version=1,root={kind=kind,id=id,name=source.name or id,source=self:CopySettingsData(source)},dependencies={},requirements={}}
    local origins=self.db.global.function_import_origins or {};bundle.root.provenance=self:CopySettingsData(origins[kind..':'..id])
    local active,seen,count={}, {},0;if kind=='function' then active[id]=true end
    local function visit(dependency,depth)
        if depth>MAX_DEPTH then return nil,'function-depth' end
        if active[dependency] then return nil,'function-cycle' end;if seen[dependency] then return true end
        count=count+1;if count>MAX_ENTRIES then return nil,'bundle-entry-limit' end
        local dependencySource,isBuiltin=lookup(self,dependency);if not dependencySource then return nil,'missing-function:'..dependency end
        if not portable(dependencySource) then return nil,'bundle-data-limit' end
        active[dependency]=true
        if not isBuiltin then local valid,errorText=checkSource(self,'function',dependency,dependencySource);if not valid then return nil,errorText end end
        -- Built In closures own their internal dependencies; only their stable
        -- public binding and source version cross this transport boundary.
        if not isBuiltin then for _,alias in ipairs(keys(dependencySource.bindings)) do local ok,errorText=visit(dependencySource.bindings[alias],depth+1);if not ok then return nil,errorText end end end
        active[dependency]=nil;seen[dependency]=true
        bundle.requirements[#bundle.requirements+1]={id=dependency,name=dependencySource.name or dependency,hash=self:FunctionSourceHash(dependencySource),builtin=isBuiltin}
        if not isBuiltin and includeDependencies~=false then bundle.dependencies[#bundle.dependencies+1]={id=dependency,name=dependencySource.name or dependency,source=self:CopySettingsData(dependencySource),provenance=self:CopySettingsData(origins['function:'..dependency])} end
        return true
    end
    for _,alias in ipairs(keys(source.bindings)) do local ok,errorText=visit(source.bindings[alias],1);if not ok then return nil,errorText end end
    if not portable(bundle) then return nil,'bundle-data-limit' end;return bundle
end
local function normalize(self,value)
    if not portable(value) or type(value)~='table' then return nil,'bundle-data-limit' end
    if value.format=='RM-CustomCondition' and value.version==1 then
        value={format='RM-FunctionBundle',version=1,root={kind='condition',id=value.name,name=value.name,source=value.condition},dependencies={},requirements={}}
    elseif value.format=='RM-CustomFunction' and value.version==1 then
        value={format='RM-FunctionBundle',version=1,root={kind='function',id=value.id or value.name,name=value.name,source=value.source or value['function']},dependencies={},requirements={}}
    end
    if value.format~='RM-FunctionBundle' or value.version~=1 or not fields(value,{format=true,version=true,root=true,dependencies=true,requirements=true}) or not fields(value.root,{kind=true,id=true,name=true,source=true,provenance=true}) or not identity(value.root.id) or not name(value.root.name) or not dense(value.dependencies) or not dense(value.requirements) then return nil,'invalid-function-bundle' end
    local root=value.root;local checked,why=checkSource(self,root.kind,root.id,root.source);if not checked then return nil,why end
    local included,required={},{}
    if root.kind=='function' then included[root.id]=root end
    for _,record in ipairs(value.dependencies) do
        if not fields(record,{id=true,name=true,source=true,provenance=true}) or not identity(record.id) or builtin(record.id) or not name(record.name) or included[record.id] then return nil,'invalid-bundle-dependency' end
        local valid,errorText=checkSource(self,'function',record.id,record.source);if not valid then return nil,errorText end;included[record.id]=record
    end
    for _,record in ipairs(value.requirements) do
        if not fields(record,{id=true,name=true,hash=true,builtin=true}) or not identity(record.id) or not name(record.name) or type(record.hash)~='string' or not record.hash:match('^%x%x%x%x%x%x%x%x$') or type(record.builtin)~='boolean' or record.builtin~=builtin(record.id) or required[record.id] or root.kind=='function' and root.id==record.id then return nil,'invalid-bundle-requirement' end
        if included[record.id] and self:FunctionSourceHash(included[record.id].source)~=record.hash then return nil,'bundle-hash-mismatch' end;required[record.id]=record
    end
    local active,seen={},{};if root.kind=='function' then active[root.id]=true end
    local function visit(id,depth)
        if depth>MAX_DEPTH then return nil,'function-depth' end
        if active[id] then return nil,'function-cycle' end;if seen[id] then return true end
        if not included[id] and not required[id] then return nil,'missing-bundle-requirement:'..tostring(id) end
        active[id]=true
        local record=included[id]
        if record then for _,dependency in pairs(record.source.bindings or {}) do local ok,errorText=visit(dependency,depth+1);if not ok then return nil,errorText end end end
        active[id]=nil;seen[id]=true;return true
    end
    for _,id in pairs(root.source.bindings or {}) do local ok,errorText=visit(id,1);if not ok then return nil,errorText end end
    for _,record in ipairs(value.dependencies) do if not seen[record.id] then return nil,'unrelated-bundle-dependency' end end
    return self:CopySettingsData(value)
end
function addon:ParseFunctionBundleImport(text,codec)
    local decoded,why=codec:Decode(text);if not decoded then return nil,why end;return normalize(self,decoded.value)
end
local pending=setmetatable({},{__mode='k'})
local function effects(self,id)
    local functions,conditions=self.db.global.custom_functions or {},self.db.global.custom_conditions or {}
    local affected={[id]=true};local changed=true
    while changed do
        changed=false
        for key,source in pairs(functions) do
            if not affected[key] then for _,dependency in pairs(type(source)=='table' and type(source.bindings)=='table' and source.bindings or {}) do if affected[dependency] then affected[key]=true;changed=true;break end end end
        end
    end
    local result={};for key in pairs(affected) do if key~=id then result[#result+1]='function:'..key end end
    for key,source in pairs(conditions) do for _,dependency in pairs(type(source)=='table' and type(source.bindings)=='table' and source.bindings or {}) do if affected[dependency] then result[#result+1]='condition:'..key;break end end end
    table.sort(result);return result
end
function addon:PlanFunctionBundleImport(value,choices)
    local bundle,why=normalize(self,value);if not bundle then return nil,why end
    choices=choices or {};if type(choices)~='table' or not portable(choices) then return nil,'invalid-import-choices' end
    for id,choice in pairs(choices) do if type(id)~='string' or not fields(choice,{action=true,id=true,name=true}) or not name(choice.name) then return nil,'invalid-import-choice' end end
    local plan={bundle=bundle,rows={},requirements={},problems={},warnings={},valid=true,remap={}}
    local targets,baselines,chosenIDs={},{},{};local registry=self.conditionDefinitions or self.definitions or {}
    local function problem(id,reason) plan.valid=false;plan.problems[#plan.problems+1]={id=id,reason=reason} end
    local function row(record,kind)
        local choiceKey=kind..':'..record.id;chosenIDs[record.id]=true;chosenIDs[choiceKey]=true
        local choice=choices[choiceKey] or choices[record.id] or {};if not fields(choice,{action=true,id=true,name=true}) or not name(choice.name) then return nil,'invalid-import-choice' end
        local needsClone=builtin(record.id) and choice.id==nil
        local target=choice.id or (needsClone and ('IMPORTED_'..record.id:gsub('[^A-Za-z_0-9]','_')):sub(1,128) or record.id)
        if kind=='function' and not self:IsCustomFunctionIdentifier(target) or kind=='condition' and not self:IsCustomConditionIdentifier(target) then return nil,'invalid-import-destination' end
        local targetKey=kind..':'..target;if targets[targetKey] then return nil,'duplicate-import-destination' end;targets[targetKey]=true
        local existing;if kind=='function' then existing=(self.db.global.custom_functions or {})[target] else existing=(self.db.global.custom_conditions or {})[target] end
        local protected=kind=='function' and self.builtinFunctions and self.builtinFunctions[target] or kind=='condition' and registry[target] and not existing
        if protected then return nil,'builtin-import-destination' end
        local action=choice.action
        if needsClone then action='conflict' end
        if action==nil then action=existing and (self:SettingsDataEqual(existing,record.source) and 'reuse' or 'conflict') or 'create' end
        if action~='reuse' and action~='replace' and action~='rename' and action~='create' and action~='conflict' then return nil,'invalid-import-action' end
        if action=='rename' and target==record.id or (action=='rename' or action=='create') and existing or (action=='reuse' or action=='replace') and not existing then return nil,'invalid-import-action' end
        if action=='conflict' then problem(record.id,'dependency-conflict') end
        local entry={kind=kind,choiceKey=choiceKey,originalID=record.id,originalName=record.name or record.id,source=self:CopySettingsData(record.source),originalSource=self:CopySettingsData(record.source),provenance=self:CopySettingsData(record.provenance),destinationID=target,action=action,existing=self:CopySettingsData(existing),effects=kind=='function' and effects(self,target) or {}}
        if choice.name and kind=='function' then entry.source.name=choice.name end
        entry.destinationName=entry.source.name or target
        plan.rows[#plan.rows+1]=entry;if kind=='function' then plan.remap[record.id]=target end
        baselines[targetKey]={kind=kind,id=target,source=self:CopySettingsData(existing),definition=kind=='condition' and registry[target] or nil}
        return true
    end
    for _,record in ipairs(bundle.dependencies) do local ok,errorText=row(record,'function');if not ok then return nil,errorText end end
    local ok,errorText=row(bundle.root,bundle.root.kind);if not ok then return nil,errorText end
    for id in pairs(choices) do if not chosenIDs[id] then return nil,'unknown-import-choice' end end
    local included={};for _,record in ipairs(bundle.dependencies) do included[record.id]=true end
    for _,requirement in ipairs(bundle.requirements) do
        local current,isBuiltin=lookup(self,requirement.id);local status='included'
        if not included[requirement.id] then
            local available=self:FunctionAvailable(requirement.id)
            if not current then status='missing-function' elseif isBuiltin~=requirement.builtin or not requirementHashMatches(self,requirement,current,isBuiltin) then status='incompatible-function' elseif not available then status='unavailable-function' else status='available' end
            if status~='available' then problem(requirement.id,status) end
            baselines['requirement:'..requirement.id]={kind='requirement',id=requirement.id,source=self:CopySettingsData(current),builtin=isBuiltin}
        end
        local reviewed=self:CopySettingsData(requirement);reviewed.status=status;plan.requirements[#plan.requirements+1]=reviewed
    end
    local sources=self:CopySettingsData(self.db.global.custom_functions or {})
    for _,entry in ipairs(plan.rows) do
        for alias,id in pairs(entry.source.bindings or {}) do entry.source.bindings[alias]=plan.remap[id] or id end
        if entry.kind=='function' and entry.action~='reuse' and entry.action~='conflict' then sources[entry.destinationID]=self:CopySettingsData(entry.source) end
    end
    local staged,compileError=self:BuildFunctionRegistry(sources);if not staged then return nil,compileError end
    -- Availability stops at disabled records; structural validation must still
    -- follow their declarations to reject cycles created by reuse/remapping.
    local graphSeen,graphCount={},0
    local function structural(id,active,depth,seen)
        if not graphSeen[id] then
            graphSeen[id]=true;graphCount=graphCount+1
            if graphCount>MAX_ENTRIES+1 then return nil,'bundle-entry-limit' end
            local current,isBuiltin=lookup(self,id)
            baselines['graph:'..id]={kind=isBuiltin and 'requirement' or 'graph',id=id,source=self:CopySettingsData(current),builtin=isBuiltin}
        end
        if self.builtinFunctions and self.builtinFunctions[id] then return true end
        if depth>MAX_DEPTH then return nil,'function-depth' end
        if active[id] then return nil,'function-cycle' end
        if seen[id] then return true end
        local record=staged[id];if not record then return nil,'missing-function' end
        if record.problem then return nil,record.problem end
        active[id]=true
        for _,dependency in pairs(record.bindings) do local valid,reason=structural(dependency,active,depth+1,seen);if not valid then return nil,reason end end
        active[id]=nil;seen[id]=true;return true
    end
    for _,entry in ipairs(plan.rows) do
        local effective=entry.action=='reuse' and entry.existing or entry.source
        local references=entry.kind=='function' and {entry.destinationID} or effective.bindings or {}
        for _,id in pairs(references) do local valid,reason=structural(id,{},1,{});if not valid then problem(entry.originalID,reason) end end
        if entry.action~='reuse' and entry.action~='conflict' then
            local valid,sourceError=checkSource(self,entry.kind,entry.destinationID,entry.source);if not valid then return nil,sourceError end
        end
        local available,reason
        if entry.kind=='function' then available,reason=self:FunctionAvailable(entry.destinationID,staged) else available,reason=self:AreFunctionBindingsAvailable(effective.bindings,staged) end
        if not available then
            if reason=='disabled-function' or entry.source.disabled then plan.warnings[#plan.warnings+1]={id=entry.originalID,reason=reason} else problem(entry.originalID,reason) end
        end
    end
    pending[plan]={snapshot=self:CopySettingsData(plan),baselines=baselines,owner=self}
    return plan
end
function addon:ApplyFunctionBundleImport(plan)
    local saved=pending[plan];if not saved or saved.owner~=self or not self:SettingsDataEqual(plan,saved.snapshot) then return nil,'import-plan-changed' end
    if not plan.valid then return nil,'import-plan-unresolved' end
    local registry=self.conditionDefinitions or self.definitions or {}
    for _,baseline in pairs(saved.baselines) do
        local current,isBuiltin
        if baseline.kind=='condition' then current=(self.db.global.custom_conditions or {})[baseline.id];if registry[baseline.id]~=baseline.definition then return nil,'import-destination-changed' end
        elseif baseline.kind=='requirement' then current,isBuiltin=lookup(self,baseline.id);if isBuiltin~=baseline.builtin then return nil,'import-destination-changed' end
        else current=(self.db.global.custom_functions or {})[baseline.id];if self.builtinFunctions and self.builtinFunctions[baseline.id] then return nil,'import-destination-changed' end end
        if not self:SettingsDataEqual(current,baseline.source) then return nil,'import-destination-changed' end
    end
    -- Replan from immutable input against the complete current graph so unrelated
    -- edits are preserved and newly introduced cycles are checked before hooks.
    local choices={};for _,entry in ipairs(plan.rows) do choices[entry.choiceKey]={action=entry.action,id=entry.destinationID,name=entry.kind=='function' and entry.source.name or nil} end
    local fresh,why=self:PlanFunctionBundleImport(plan.bundle,choices);if not fresh or not fresh.valid then return nil,why or 'import-graph-changed' end
    local sources=self:CopySettingsData(self.db.global.custom_functions or {})
    for _,entry in ipairs(fresh.rows) do if entry.kind=='function' and entry.action~='reuse' then sources[entry.destinationID]=self:CopySettingsData(entry.source) end end
    local staged,errorText=self:BuildFunctionRegistry(sources);if not staged then return nil,errorText end
    local conditions={}
    for _,entry in ipairs(fresh.rows) do if entry.kind=='condition' and entry.action~='reuse' then local definition,reason=self:CompileCustomCondition(entry.destinationID,entry.source,false);if not definition then return nil,reason end;conditions[#conditions+1]={entry=entry,definition=definition} end end
    local oldSources,oldRegistry,oldVersion=self.db.global.custom_functions,self.functionRegistry,self.functionRegistryVersion
    local oldConditions,oldOrigins=self.db.global.custom_conditions,self.db.global.function_import_origins
    local oldConditionVersion=self.conditionRegistryVersion
    local oldDefinitions={};for id,definition in pairs(registry) do oldDefinitions[id]={definition=definition,suspended=definition.functionSuspended,unavailable=definition.functionUnavailable} end
    local replacing={};for _,record in ipairs(conditions) do replacing[record.entry.destinationID]=true end
    local function restoreConsumers()
        for id,record in pairs(oldDefinitions) do
            local definition=record.definition;local resume=definition.functionSuspended and not record.suspended
            definition.functionSuspended=record.suspended;definition.functionUnavailable=record.unavailable
            if resume and definition.on_register and not definition.disabled and not record.unavailable then pcall(definition.on_register,id) end
        end
    end
    local prepared,prepareError=self:PrepareFunctionConsumerTransition(staged);if not prepared then return nil,prepareError end
    -- A replaced condition's cleanup belongs to the former helper graph, even
    -- when both versions of that graph are available. Suppress duplicate cleanup
    -- in RegisterCondition and resume the old hook on rollback.
    for id in pairs(replacing) do
        local previous=registry[id]
        if previous and not previous.disabled and not previous.functionUnavailable and not previous.functionSuspended then
            previous.functionSuspended=true
            if previous.on_unregister and not pcall(previous.on_unregister,id) then restoreConsumers();return nil,'condition-cleanup-failed' end
        end
    end
    self.db.global.custom_functions=sources;self.functionRegistry=staged
    -- Isolate saved tables too: a failing trusted hook may write to these maps.
    self.db.global.custom_conditions=self:CopySettingsData(oldConditions or {})
    self.db.global.function_import_origins=self:CopySettingsData(oldOrigins or {})
    local resumedConsumers={};local failureReason='condition-registration-failed'
    local success=pcall(function()
        for _,record in ipairs(conditions) do
            local entry=record.entry;local definition,reason=self:CompileCustomCondition(entry.destinationID,entry.source,false);if not definition then error(type(reason)=='table' and reason.reason or reason,0) end
            self:RegisterCondition(entry.destinationID,definition)
        end
        -- Resuming an existing consumer is also trusted registration. Keep the
        -- entire bundle provisional until every affected hook has succeeded.
        local refreshed,reason,attempted=self:RefreshFunctionConsumers(true);resumedConsumers=attempted
        if not refreshed then failureReason=reason;error(reason,0) end
    end)
    if not success then
        -- Release partially registered resources while their staged bindings
        -- still exist, then restore the old graph before resuming old consumers.
        for index=#resumedConsumers,1,-1 do
            local resumed=resumedConsumers[index]
            if resumed.definition.on_unregister then pcall(resumed.definition.on_unregister,resumed.id) end
        end
        for _,record in ipairs(conditions) do
            local key=record.entry.destinationID;local current=registry[key]
            if current and current~=(oldDefinitions[key] and oldDefinitions[key].definition) and current.on_unregister and not current.disabled and not current.functionUnavailable then pcall(current.on_unregister,key) end
            registry[key]=oldDefinitions[key] and oldDefinitions[key].definition
        end
        self.db.global.custom_functions=oldSources;self.functionRegistry=oldRegistry;self.functionRegistryVersion=oldVersion;self.db.global.custom_conditions=oldConditions;self.db.global.function_import_origins=oldOrigins;self.conditionRegistryVersion=oldConditionVersion
        restoreConsumers();return nil,failureReason
    end
    local conditionSources=self:CopySettingsData(oldConditions or {});local origins=self:CopySettingsData(oldOrigins or {})
    for _,entry in ipairs(fresh.rows) do if entry.action~='reuse' then
        if entry.kind=='condition' then conditionSources[entry.destinationID]=self:CopySettingsData(entry.source) end
        origins[entry.kind..':'..entry.destinationID]={originalID=entry.originalID,originalName=entry.originalName,hash=self:FunctionSourceHash(entry.originalSource),importedHash=self:FunctionSourceHash(entry.source),provenance=self:CopySettingsData(entry.provenance)}
    end end
    self.db.global.custom_conditions=conditionSources;self.db.global.function_import_origins=origins;self.functionRegistryVersion=(oldVersion or 0)+1
    if self.RefreshConditionConsumers then self:RefreshConditionConsumers() end;pending[plan]=nil;return true
end
]====],
    ["UI/condition_source_pane.lua"] = [====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function clearNew(p) p.creatingCondition=nil;p.newConditionKey=nil;p.newConditionSource=nil end
function addon:InstallInlineConditionNavigation(p)
    if p.inlineNavigation then return end;p.inlineNavigation=true
    local leave,release,draw,layout=p.RequestLeave,p.Release,p.Draw,p.Layout
    function p:Layout()
        layout(self);local editor=self.inlineCondition
        if editor and not editor.closed and editor.OwnerValid() then editor:ResizeHeight(math.max(160,self.frame:GetHeight()-34)) end
    end
    function p:Draw()
        local editor=self.inlineCondition
        self.inlineResume=nil
        if editor and not editor.closed and editor.OwnerValid() and self.mode~='categories' and editor.inlineSelection==self.condition and editor.inlineNewSource==self.newConditionSource then
            self.inlineResume=editor:CaptureDraft()
        end
        return draw(self)
    end
    function p:RequestLeave(callback)
        local editor=self.inlineCondition
        if editor and not editor.closed and editor:IsDirty() then
            local profile,global=self.profile,self.global
            self:ConfirmPending(function()
                if self.active and self.profile==profile and self.global==global and editor:Apply() then callback() end
            end,function()
                if not self.active or self.profile~=profile or self.global~=global then return end
                editor:Close();self.inlineCondition=nil;self:DiscardSettingsDraft();clearNew(self);callback()
            end)
            return false
        end
        return leave(self,callback)
    end
    function p:Release() clearNew(self);self.inlineResume=nil;release(self);self.inlineCondition=nil end
end
function addon:OpenInlineCustomCondition(p,key,source)
    self:InstallInlineConditionNavigation(p)
    p:RequestLeave(function()
        if not p.active then return end
        p.creatingCondition=true;p.newConditionKey=key;p.newConditionSource=self:CopySettingsData(source or self.empty_condition);p.condition=nil;p.conditionSource='custom';p.category='ALL';p:Draw()
    end)
end
function addon:DuplicateInlineCustomCondition(p)
    self:InstallInlineConditionNavigation(p)
    p:RequestLeave(function()
        if not p.active then return end
        local key=p.condition;local source=self.db.global.custom_conditions[key] or self.GetBuiltinConditionSource and self:GetBuiltinConditionSource(key);if not source then return end
        p.creatingCondition=true;p.newConditionKey=key:sub(1,216)..'_'..self:uuid():gsub('-','_');p.newConditionSource=self:CopySettingsData(source);p.newConditionSource.description=string.format(L['Copy of %s'],source.description);p.condition=nil;p.conditionSource='custom';p.category='ALL';p:Draw()
    end)
end
function addon:BuildInlineCustomCondition(p,key,source,readOnly)
    self:InstallInlineConditionNavigation(p)
    local token=p.generation;local store=p:SettingsData();local profile=store.profile
    local isNew=p.creatingCondition==true
    if isNew then key=nil;source=p.newConditionSource or self.empty_condition end
    local preferences={hidden=self:SettingsContains(profile.disabled_conditions,key),switch=self:SettingsContains(profile.switch_conditions,key),category='DEFAULT'}
    for _,group in ipairs(profile.condition_groups or {}) do if self:SettingsContains(group.conditions,key) then preferences.category=group.id;break end end
    local function valid() return p:Valid(token) end
    local geometry=self:GetWorkbenchRosterGeometry(p.frame:GetWidth(),p.frame:GetHeight())
    local options={readOnly=readOnly,parent=p.frame,x=geometry.detailX,footer=p.frame,width=geometry.detailWidth,height=math.max(160,p.frame:GetHeight()-34),editor=p.inlineEditorCache,resume=p.inlineResume};p.inlineResume=nil
    options.initialize=function(model)
        if isNew and p.newConditionKey then model.key=p.newConditionKey;model.baseline.key=model.key;model.creationPending=true end
        model.context=self:CopySettingsData(preferences);model.baseline.context=self:CopySettingsData(preferences)
    end
    options.closeOwner=function(mouse)
        local shell=addon.configWindow
        if shell and shell.pane==p then if mouse then shell.rightDown=true end;shell:Hide() else p:RequestLeave(function() p:Release() end) end
    end
    options.dirty=function() return p:IsSettingsDraftDirty() end
    options.discard=function() if valid() then p:DiscardSettingsDraft();clearNew(p);p:Draw() end end
    options.fields=function(form,d)
        local context=d.model.context;local y=form.y
        local checkWidth=(form.width-148)/2
        local hidden=form:Check('hidden',L['Hidden'],context.hidden,function(value) d.model:Change(function(model) model.context.hidden=value end);d:UpdateActions() end);hidden:SetWidth(checkWidth);hidden:GetFontString():SetWidth(checkWidth-22)
        local switch=form:Check('switch',L['Switch Condition'],context.switch,function(value) d.model:Change(function(model) model.context.switch=value end);d:UpdateActions() end);switch:ClearAllPoints();switch:SetPoint('TOPLEFT',checkWidth+8,-y);switch:SetWidth(checkWidth);switch:GetFontString():SetWidth(checkWidth-22);form.y=form.y-28
        if key and not readOnly then self:SettingsTopDelete(form,function()
            self:ConfirmSettingsDeletion(p,L['Delete this custom condition? Existing rotations using it will become unavailable.'],function()
                local ok,why=self:DeleteSavedCustomCondition(key);if ok then clearNew(p);p.condition=nil end;return ok,why
            end)
        end) end
    end
    options.category=function(form,d)
        local context=d.model.context;local savedCategory=d.model.baseline.context.category
        local groups=store.profile.condition_groups or {};local destinations={{value='DEFAULT',text=L['Other'],icon=self:GetConditionCategoryIcon(nil)}};local current=L['Other'];local icon=self:GetConditionCategoryIcon(nil)
        for _,group in ipairs(groups) do destinations[#destinations+1]={value=group.id,text=group.name or group.id,icon=self:GetConditionCategoryIcon(group)};if group.id==savedCategory then current=group.name or group.id;icon=self:GetConditionCategoryIcon(group) end end
        local function visitCategory()
            p:RequestLeave(function() if p.active then p.mode='categories';p.categorySelection=savedCategory;p:Draw() end end)
        end
        local categoryY=form:Row(L['Category'],28);form.pool.labels[form.counts.labels]:SetWidth(168)
        local fieldWidth=(form.width-182)/2
        local category=form:Acquire('sourceCategory',function() return self:CreateWorkbenchButton(form.child,'',fieldWidth) end);form.fields.current_category=category;category:ClearAllPoints();category:SetPoint('TOPLEFT',174,-categoryY);category:SetText(current)
        -- Navigation must offer Discard even while a raw source field is invalid.
        self:SetUIScript(category,'OnClick',function() if valid() then visitCategory() end end)
        category.categoryIcon=category.categoryIcon or category:CreateTexture(nil,'ARTWORK');category.categoryIcon:SetPoint('LEFT',3,0);category.categoryIcon:SetSize(20,20);category.categoryIcon:SetTexture(icon);category:SetWidth(fieldWidth);self:AlignWorkbenchTextLeft(category,28)
        local moveLabel=form:Acquire('labels',function() return form.child:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall') end)
        form.fields.moveLabel=moveLabel;moveLabel:ClearAllPoints();moveLabel:SetPoint('TOPLEFT',174+fieldWidth+8,-categoryY);moveLabel:SetSize(38,24);moveLabel:SetText(L['Move']);moveLabel:SetJustifyH('LEFT');moveLabel:SetJustifyV('MIDDLE')
        local move=form:Choice('move_to',nil,context.category,destinations,function(value)
            if valid() then d.model:Change(function(model) model.context.category=value end);form:Draw();d:UpdateActions() end
        end)
        move:ClearAllPoints();move:SetPoint('TOPLEFT',174+fieldWidth+50,-categoryY);move:SetWidth(fieldWidth-42);form.y=form.y-30
    end
    options.updateActions=function(d)
        for _,field in ipairs({'hidden','switch'}) do self:SetWorkbenchUnsaved(d.form.fields[field],d.model.context[field]~=d.model.baseline.context[field]) end
        self:SetWorkbenchUnsaved(d.form.fields.move_to,d.model.context.category~=d.model.baseline.context.category)
    end
    options.save=function(identifier,value,expected,expectedSource)
        if not valid() then return false,{reason='definition-changed'} end
        if InCombatLockdown and InCombatLockdown() then return false,{reason=L['Leave combat before applying these settings.']} end
        -- Validate every owned settings baseline before registration. A trusted
        -- registration hook can fail; preferences are applied only after it succeeds.
        for scope,keys in pairs(p.transactionKeys) do for _,field in ipairs(keys) do
            if not self:SettingsDataEqual(self.db[scope] and self.db[scope][field],p.draftBaseline[scope][field]) then return false,{reason=L['Settings changed elsewhere. Cancel to reload them before applying.']} end
        end end
        local previous=self:CopySettingsData(self.db.global.custom_conditions[identifier]);local oldDefinition=self.conditionDefinitions[identifier]
        if oldDefinition~=expected or expectedSource and not self:SettingsDataEqual(previous,expectedSource) then return false,{reason='definition-changed'} end
        if readOnly and not self:SettingsDataEqual(source,value) then return false,{reason='readonly-builtin'} end
        local changed=not readOnly and not self:SettingsDataEqual(previous,value)
        if changed then local ok,why=self:InstallCustomCondition(identifier,value,expected,expectedSource);if not ok then return false,why end end
        local saved=self:CopySettingsData(self.db.global.custom_conditions[identifier])
        p.draft.global.custom_conditions[identifier]=saved;p.draftBaseline.global.custom_conditions=p.draftBaseline.global.custom_conditions or {};p.draftBaseline.global.custom_conditions[identifier]=self:CopySettingsData(saved)
        local context=p.inlineCondition.model.context;local draft=p.draft.profile
        local function membership(list,enabled)
            if self:SettingsContains(list,identifier)~=enabled then self:SettingsFlag(list,identifier,enabled) end
        end
        draft.disabled_conditions=draft.disabled_conditions or {};membership(draft.disabled_conditions,context.hidden)
        draft.switch_conditions=draft.switch_conditions or {};membership(draft.switch_conditions,context.switch)
        for _,group in ipairs(draft.condition_groups or {}) do group.conditions=group.conditions or {};membership(group.conditions,group.id==context.category) end
        if not p:SaveSettingsDraft() then
            -- This can occur if trusted registration code changes another owned
            -- namespace. Restore our source/registry rather than accepting half a save.
            if changed then
                local current=self.conditionDefinitions[identifier];if current and not current.disabled and current.on_unregister then pcall(current.on_unregister,identifier) end
                self.db.global.custom_conditions[identifier]=previous;self.conditionDefinitions[identifier]=oldDefinition;self.conditionRegistryVersion=(self.conditionRegistryVersion or 0)+1
                if oldDefinition and not oldDefinition.disabled and oldDefinition.on_register then pcall(oldDefinition.on_register,identifier) end
                if self.RefreshConditionConsumers then self:RefreshConditionConsumers() end
                p.draft.global.custom_conditions[identifier]=self:CopySettingsData(previous);p.draftBaseline.global.custom_conditions[identifier]=self:CopySettingsData(previous)
            end
            return false,{reason=L['Settings changed elsewhere. Cancel to reload them before applying.']}
        end
        return true
    end
    local d,owner=self:condition_edit_box(function(identifier)
        if not valid() then return end
        clearNew(p);p.condition=identifier;p.conditionSource=readOnly and 'builtin' or 'custom';p.category='ALL';p:Draw()
    end,key,source,valid,options)
    p.inlineCondition=d;p.inlineEditorCache=d
    d.inlineSelection=p.condition;d.inlineNewSource=p.newConditionSource
    p.cleanups[#p.cleanups+1]=function() self:CloseCustomConditionEditor(d,owner);if p.inlineCondition==d then p.inlineCondition=nil end end
    p.creationUsed=true;p.creationUsedForNew=false;p.y=1;p.scroll:Hide()
    -- The right pane owns its source actions; no duplicate page Apply row.
    return d
end
]====],
    ["UI/settings_collections.lua"] = [====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:SettingsEntries(values)
    local entries={};for id,value in pairs(values or {}) do if type(value)=='table' then entries[#entries+1]={value=id,text=type(value.name)=='string' and value.name or tostring(id)} end end
    table.sort(entries,function(a,b) if a.text==b.text then return tostring(a.value)<tostring(b.value) end;return a.text<b.text end);return entries
end
function addon:SettingsNonempty(text) if type(text)=='string' and text:find('%S') then return text end end
function addon:SettingsPositiveID(text) local n=tonumber(text);if n and n>0 and n==math.floor(n) then return n end end
function addon:SettingsFlag(list,value,enabled)
    for i=#list,1,-1 do if list[i]==value then table.remove(list,i) end end
    if enabled then list[#list+1]=value end
end
function addon:SettingsContains(list,value) for _,entry in ipairs(list or {}) do if entry==value then return true end end;return false end
function addon:SettingsOrderControls(p,prefix,list,i,changed)
    local function move(destination) local value=table.remove(list,i);table.insert(list,destination,value);changed();p:Draw() end
    p:Actions({{key=prefix..'top',text=L['Move to Top'],icon='chevron-double-down',enabled=i>1,action=function() move(1) end},
        {key=prefix..'up',text=L['Move Up'],icon='up',enabled=i>1,action=function() move(i-1) end},
        {key=prefix..'down',text=L['Move Down'],icon='down',enabled=i<#list,action=function() move(i+1) end},
        {key=prefix..'bottom',text=L['Move to Bottom'],icon='chevron-double-down',enabled=i<#list,action=function() move(#list) end},
        {key=prefix..'remove',text=L['Delete'],icon='trash',action=function() table.remove(list,i);changed();p:Draw() end}})
end
function addon:OpenNativeSettings(parent,key,cached)
    local builders={General=self.BuildGeneralSettings,Profiles=self.BuildProfileSettings,About=self.BuildAboutSettings,
        Announces=self.BuildAnnounceSettings,Effects=self.BuildEffectSettings,ItemSets=self.BuildItemSettings,Conditions=self.BuildConditionSettings,Functions=self.BuildFunctionSettings,Integrations=self.BuildIntegrationSettings}
    local build=builders[key];if not build then return end
    local p=cached or self:CreateSettingsForm(parent)
    local scopes={Integrations={profile={'lua_editor','lua_line_numbers'}},Effects={global={'effects'}},ItemSets={profile={'itemsets'},global={'itemsets'}},Announces={profile={'announces'}},Conditions={profile={'condition_groups','switch_conditions','other_conditions_order','disabled_conditions'},global={'custom_conditions'}},General={profile={'enable','poll','ignore_mana','ignore_range','effect','color','magnification','setpoint','xoffs','yoffs','loglevel','detailed_profiling','disable_autoswitch','live_config_update','spell_history','combat_history','damage_history','disable_buttons','rotation_view','preview_spells','preview_vertical','preview_locked','preview_opacity','preview_icon_size','preview_window','minimap'},char={'specs'}}}
    scopes.Functions={global={'custom_functions'}}
    p.settingsKey=key;p.historyEnabled=key=='ItemSets';p.transactionKeys=scopes[key];p:SetWidth(parent:GetWidth());p:SetHeight(parent:GetHeight());p:Open(function(form) build(self,form) end);return p
end

function addon:CollectionFooter(p,kind,values,current,duplicate,transfer,compare)
    local candidates={};for _,entry in ipairs(self:SettingsEntries(values)) do if entry.value~=current then candidates[#candidates+1]=entry end end
    p:SetRosterActions({{key='new_collection',text=L['New'],icon='plus',action=p.roster.options.new},duplicate,transfer,
        {key='compare',text=L['Compare'],icon='compare',enabled=values[current]~=nil and #candidates>0,action=function()
            p:ShowChoices(p.fields.compare,candidates,function(id) p.fields.compare:SetText(L['Compare']);if id~=current and values[id] and values[current] then if compare then compare(values[current],values[id]) else self:ShowCollectionComparison(p,kind,values[current],values[id]) end end end)
        end}})
end
function addon:SettingsTopDelete(p,action)
    local c=p:Acquire('rootDelete',function() return self:CreateWorkbenchIconButton(p.child,'trash',L['Delete']) end);c:ClearAllPoints();c:SetPoint('TOPRIGHT',0,-4);c.icon:SetVertexColor(1,.25,.25,1);c:Enable();p.fields.delete=c
    self:SetUIScript(c,'OnClick',p:Guard(action));return c
end

-- Deletion is a separate confirmed operation. Resolve existing edits first,
-- then rebuild and read saved data so Apply/Discard cannot leave stale drafts.
function addon:ConfirmSettingsDeletion(p,warning,remove)
    local profile,global,char=self.db.profile,self.db.global,self.db.char
    p:RequestLeave(function()
        if not p.active or self.db.profile~=profile or self.db.global~=global or self.db.char~=char then return end
        p:DiscardSettingsDraft();p:Draw()
        local stockUnrelated=p.settingsKey=='ItemSets'
        local function ownsKey(scope,key)return not (stockUnrelated and scope=='profile' and key=='stockTargets')end
        local expected={};for scope,keys in pairs(p.transactionKeys or {}) do expected[scope]={};for _,key in ipairs(keys) do if ownsKey(scope,key) then expected[scope][key]=self:CopySettingsData(self.db[scope] and self.db[scope][key]) end end end
        local conditionRevision,functionRevision=self.conditionRegistryVersion,self.functionRegistryVersion
        p:Confirm(warning..' '..L['This cannot be undone.'],function()
            if InCombatLockdown and InCombatLockdown() then p:Message(L['Leave combat before applying these settings.']);return end
            for scope,keys in pairs(p.transactionKeys or {}) do for _,key in ipairs(keys) do
                if ownsKey(scope,key) and not self:SettingsDataEqual(self.db[scope] and self.db[scope][key],expected[scope][key]) then p:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return end
            end end
            if self.conditionRegistryVersion~=conditionRevision or self.functionRegistryVersion~=functionRevision then p:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return end
            local called,ok,why=pcall(remove)
            if not called or not ok then p:Message(tostring(called and why or ok));return end
            p:DiscardSettingsDraft();p.emptyDismissed=true;p:Draw()
            if self.RemoveAllCurrentGlows then self:RemoveAllCurrentGlows() end
            if self.ButtonFetch then self:ButtonFetch() end
        end)
    end)
end
function addon:DeleteSavedCustomCondition(key)
    local source=(self.db.global.custom_conditions or {})[key]
    if not source then return false,'definition-changed' end
    -- Unregister can run trusted cleanup hooks. A failure must retain its saved
    -- source and registered definition, rather than leaving an orphaned runtime.
    local definition=self.conditionDefinitions and self.conditionDefinitions[key]
    local ok,why=pcall(self.UnregisterCondition,self,key)
    if not ok then if self.conditionDefinitions then self.conditionDefinitions[key]=definition end;return false,why end
    self.db.global.custom_conditions[key]=nil
    if self.RefreshConditionConsumers then self:RefreshConditionConsumers() end
    return true
end
]====],
    ["UI/settings_draft.lua"] = [====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function equal(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
    for key,value in pairs(a) do if not equal(value,b[key]) then return false end end;for key in pairs(b) do if a[key]==nil then return false end end;return true
end
function addon:SettingsDataEqual(a,b) return equal(a,b) end
function addon:CopySettingsData(value,seen)
    if type(value)~='table' then return value end;seen=seen or {};if seen[value] then return seen[value] end
    local copy={};seen[value]=copy;for key,child in pairs(value) do copy[key]=self:CopySettingsData(child,seen) end;return copy
end
function addon:InstallSettingsDraft(p)
    function p:CanAutoCreateCollection(scope,key)
        return not self.emptyDismissed and not (self.draftBaseline and self.draftBaseline[scope] and next(self.draftBaseline[scope][key] or {}))
    end
    function p:CreationState()
        return {effect=self.newEffect,announcement=self.newAnnounce,profileName=self.newProfileName,profileSource=self.profileSource,importProfile=self.importProfile,stockTarget=self.newStockTarget,itemSetName=self.newItemSetName,categoryName=self.newGroupName}
    end
    function p:IsCreationDirty()
        if not self.creationUsedForNew then return false end
        for _,record in ipairs(self.edits) do if record.dirty then return true end end
        return not equal(self:CreationState(),self.creationBaseline or {})
    end
    function p:DiscardSettingsDraft()
        if self.ClearSettingsHistory then self:ClearSettingsHistory() end
        self.draft=nil;self.draftBaseline=nil;self.draftEffects=nil;self.newEffect=nil;self.newAnnounce=nil;self.newProfileName=nil;self.importProfile=nil;self.profileSource=nil;self.newStockTarget=nil;self.newItemSetName=nil;self.newGroupName=nil;self.creating=false;self.creatingCategory=false;self.creationBaseline=nil;self.creationApply=nil;self.emptyDismissed=true
    end
    function p:ApplyCreation()
        if not self:FlushEdits() or not self.creationApply then return false end
        local apply=self.creationApply;apply()
        if self.creationUsedForNew then return false end
        if self.transactionKeys and not self:SaveSettingsDraft() then return false end
        self.creationBaseline=nil;self:Draw();return true
    end
    function p:SettingsData()
        if not self.transactionKeys then return addon.db end
        if not self.draft then
            if self.settingsKey=='ItemSets' then
                local keys={};for _,key in ipairs(self.transactionKeys.profile or {}) do if key~='stockTargets' then keys[#keys+1]=key end end
                self.stockEditable=addon.StockSettings.CheckProfile(addon.db.profile)==true
                if self.stockEditable then keys[#keys+1]='stockTargets' end;self.transactionKeys.profile=keys
            end
            self.draft={profile=addon:CopySettingsData(addon.StockSettings.DraftProfile(addon.db.profile)),global=addon:CopySettingsData(addon.db.global),char=addon:CopySettingsData(addon.db.char or {})};self.draftBaseline={};self.draftEffects={}
            for scope,keys in pairs(self.transactionKeys) do self.draftBaseline[scope]={};for _,key in ipairs(keys) do self.draftBaseline[scope][key]=addon:CopySettingsData(addon.db[scope] and addon.db[scope][key]) end end
        end
        return self.draft
    end
    function p:RunSettingsEffect(key,callback)
        if self.transactionKeys then self.draftEffects[key]=callback else callback() end
    end
    function p:IsSettingsDraftDirty()
        if not self.draft then return false end
        for _,record in ipairs(self.edits) do if record.dirty then return true end end
        for scope,keys in pairs(self.transactionKeys) do for _,key in ipairs(keys) do if not equal(self.draft[scope][key],self.draftBaseline[scope][key]) then return true end end end;return false
    end
    function p:SaveSettingsDraft()
        if not self.draft then return true end
        if not self:Valid(self.generation) then return false end
        local stockUnchanged=false
        for _,key in ipairs(self.transactionKeys.profile or {}) do if key=='stockTargets' then
            if not addon.StockTargets.Validate(self.draft.profile.stockTargets) then self:Message(L['Complete the stock target settings before applying.']);return false end
            stockUnchanged=equal(self.draft.profile.stockTargets,self.draftBaseline.profile.stockTargets)
            if not stockUnchanged and not addon.StockSettings.CheckProfile(addon.db.profile) then self:Message(L['Invalid stock targets; data preserved.']);return false end
        end end
        for scope,keys in pairs(self.transactionKeys) do for _,key in ipairs(keys) do
            if not (scope=='profile' and key=='stockTargets' and stockUnchanged) and not equal(addon.db[scope] and addon.db[scope][key],self.draftBaseline[scope][key]) then self:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return false end
        end end
        local ownsEffects=false;for _,key in ipairs(self.transactionKeys.global or {}) do if key=='effects' then ownsEffects=true end end
        if ownsEffects and self.draft.global.effects then
            local names={};for id,effect in pairs(self.draft.global.effects) do
                if not equal(effect,self.draftBaseline.global.effects and self.draftBaseline.global.effects[id]) and addon.IsValidEffectDefinition and not addon:IsValidEffectDefinition(effect) then self:Message(L['Complete the effect settings before applying.']);return false end
                if effect.name and names[effect.name] then self:Message(L['This name is already in use.']);return false end;if effect.name then names[effect.name]=true end
            end
        end
        if self.transactionKeys.profile then for _,key in ipairs(self.transactionKeys.profile) do if key=='announces' then
            for index,entry in ipairs(self.draft.profile.announces or {}) do if not equal(entry,(self.draftBaseline.profile.announces or {})[index]) and not addon:IsValidAnnouncement(entry) then self:Message(L['Choose an action and complete the announcement before applying.']);return false end end
        end end end
        if InCombatLockdown and InCombatLockdown() then self:Message(L['Leave combat before applying these settings.']);return false end
        for scope,keys in pairs(self.transactionKeys) do for _,key in ipairs(keys) do
            if not (scope=='profile' and key=='stockTargets' and stockUnchanged) and not equal(self.draft[scope][key],self.draftBaseline[scope][key]) then addon.db[scope][key]=addon:CopySettingsData(self.draft[scope][key]) end
        end end
        local effects=self.draftEffects;if self.ClearSettingsHistory then self:ClearSettingsHistory() end;self.draft=nil;self.draftBaseline=nil;self.draftEffects=nil
        for _,callback in pairs(effects) do callback() end
        if addon.RemoveAllCurrentGlows then addon:RemoveAllCurrentGlows() end
        if addon.ButtonFetch then addon:ButtonFetch() end
        return true
    end
    function p:DraftActions()
        if not self.transactionKeys or self.creationUsed then return end
        self:CreationActions(function() if self:SaveSettingsDraft() then self:Draw() end end,function() self:DiscardSettingsDraft();self:Draw() end,true)
        if self:IsSettingsDraftDirty() then self.fields.apply:Enable() else self.fields.apply:Disable() end;self.creationUsedForNew=false
    end
end
]====],
    ["UI/settings_effects.lua"] = [====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local types={{value='texture',text=L['Texture']},{value='pixel',text=L['Pixel']},{value='autocast',text=L['Auto Cast']},{value='blizzard',text=L['Glow']},{value='proc',text=L['Proc Glow']},{value='dazzle',text=L['Dazzle']},{value='animate',text=L['Animate']},{value='pulse',text=L['Pulse']},{value='rotate',text=L['Rotate']},{value='custom',text=L['Custom']}}
local schemas={proc={{'duration','Loop duration',1,.1,5,.05}},pixel={{'lines','Lines',8,1,20,1},{'frequency','Frequency',.25,-1.5,1.5,.05},{'length','Length',2,1,20,1},{'thickness','Thickness',2,1,5,1}},autocast={{'particles','Particles',4,1,4,1},{'frequency','Frequency',.125,-1.5,1.5,.05},{'scale','Scale',1,.25,5,.25}},blizzard={{'frequency','Frequency',.125,0,1.5,.05}},dazzle={{'frequency','Frequency',.25,.1,5,.05}},animate={{'frequency','Frequency',.25,.1,5,.05}},pulse={{'frequency','Frequency',.25,.1,5,.05}},custom={{'frequency','Frequency',.25,.1,5,.05}},rotate={{'frequency','Frequency',.25,.1,5,.05},{'steps','Steps',4,2,36,1}}}
local function defaults(effect)
    for _,entry in ipairs(schemas[effect.type] or {}) do local v=effect[entry[1]];if type(v)~='number' or v~=v or v<entry[4] or v>entry[5] then effect[entry[1]]=entry[3] end end
    if effect.type=='dazzle' or effect.type=='animate' or effect.type=='pulse' or effect.type=='custom' then effect.sequence=effect.sequence or {} end
end
local function validEffect(effect)
    if type(effect)~='table' or type(effect.name)~='string' or not effect.name:find('%S') then return false end
    local known=false;for _,entry in ipairs(types) do known=known or entry.value==effect.type end;if not known then return false end
    for _,entry in ipairs(schemas[effect.type] or {}) do local v=effect[entry[1]];if v~=nil and (type(v)~='number' or v~=v or v<entry[4] or v>entry[5]) then return false end end
    if effect.type=='proc' and effect.startAnim~=nil and type(effect.startAnim)~='boolean' then return false end
    if effect.texture~=nil and type(effect.texture)~='string' and type(effect.texture)~='number' then return false end
    if effect.sequence~=nil then
        if type(effect.sequence)~='table' or #effect.sequence>256 then return false end
        for _,entry in ipairs(effect.sequence) do
            if effect.type=='pulse' then if type(entry)~='number' or entry~=entry or entry<.1 or entry>2 then return false end
            elseif effect.type=='animate' then if type(entry)~='string' and type(entry)~='number' then return false end
            elseif effect.type=='dazzle' or effect.type=='custom' then
                local color=effect.type=='custom' and type(entry)=='table' and entry.color or entry
                if type(color)~='table' then return false end;for _,key in ipairs({'r','g','b','a'}) do if type(color[key])~='number' or color[key]~=color[key] or color[key]<0 or color[key]>1 then return false end end
                if effect.type=='custom' and ((type(entry.texture)~='string' and type(entry.texture)~='number') or type(entry.angle or 0)~='number' or (entry.angle or 0)~=(entry.angle or 0) or math.abs(entry.angle or 0)==math.huge or type(entry.magnification)~='number' or entry.magnification~=entry.magnification or entry.magnification<.1 or entry.magnification>2) then return false end
            end
        end
    end
    return true
end
function addon:IsValidEffectDefinition(value) return validEffect(value) end
function addon:BuildEffectSettings(p)
    local store=p:SettingsData()
    local effects=store.global.effects or {};local entries=self:SettingsEntries(effects)
    for _,entry in ipairs(entries) do local effect=effects[entry.value];entry.icon=effect.texture or self:ControlTexture('preview');entry.search=effect.type end
    if not effects[p.selection] and not p.creating then p.selection=entries[1] and entries[1].value end
    p:UseRoster(entries,p.selection,function(id) p.selection=id;p.creating=false;p:Draw() end,{newText=L['Add effect'],new=function() p.previousSelection=p.selection;p.selection=nil;p.creating=true;p.newEffect=nil;p.emptyDismissed=false;p:Draw() end});p:Heading(L['Effects'])
    local isNew=p.creating or not effects[p.selection] and p:CanAutoCreateCollection('global','effects')
    if isNew then p.newEffect=p.newEffect or {name='',type='pixel'} end
    local effect=isNew and p.newEffect or effects[p.selection]
    if effect then
        local id=isNew and 'draft' or p.selection
        local function refresh() if self.RemoveAllCurrentGlows then self:RemoveAllCurrentGlows() end;if p.preview and self.HideGlow then self:HideGlow(p.preview,'settings-effect') end;if p.preview and self.Glow then self:Glow(p.preview,'settings-effect',effect,{r=1,g=1,b=1,a=1},1,'CENTER',0,0) end end
        local y=p.y;local preview=p:Acquire('effectPreview',function() return CreateFrame('Frame',nil,p.child) end);preview:ClearAllPoints();preview:SetPoint('TOPLEFT',174,-y-8);preview:SetSize(40,40);p.preview=preview
        p.cleanups[#p.cleanups+1]=function() if self.HideGlow then self:HideGlow(preview,'settings-effect') end end
        p:Edit('name',L['Name'],effect.name or '',nil,function(text) effect.name=text;p:UpdateRosterEntry(id,{text=effect.name,search=effect.type,icon=effect.texture or self:ControlTexture('preview')}) end)
        p:Choice('type',L['Type'],effect.type,types,function(value)
            if value==effect.type then return end
            local candidate=self:CopySettingsData(effect);candidate.type=value;candidate.sequence=nil;defaults(candidate)
            -- A new sequence kind has different entry shapes. Stage its valid
            -- empty sequence before replacing the saved object or previewing.
            if isNew then p.newEffect=candidate else effects[id]=candidate end;effect=candidate;refresh();p:Draw()
        end)
        if effect.type=='texture' or effect.type=='dazzle' or effect.type=='pulse' or effect.type=='rotate' then p:Texture('texture',L['Texture'],effect.texture or '',function(value) effect.texture=tonumber(value) or value;refresh();p:UpdateRosterEntry(id,{text=effect.name,search=effect.type,icon=effect.texture or self:ControlTexture('preview')}) end,{preview=false}) end
        for _,entry in ipairs(schemas[effect.type] or {}) do local key=entry[1];p:Slider(key,L[entry[2]],effect[key] or entry[3],entry[4],entry[5],entry[6],function(value) effect[key]=value;refresh() end) end
        if effect.type=='proc' then
            p:Check('startAnim',L['Start burst'],effect.startAnim==true,function(value) effect.startAnim=value;refresh() end)
            if not self.GetProcGlowSupport or not self:GetProcGlowSupport() then p.fields.proc_support=p:Text(L['Proc Glow is unavailable on this client; Pixel glow will be used.']) end
        end
        if effect.type=='rotate' then p:Check('reverse',L['Reverse'],effect.reverse,function(value) effect.reverse=value;refresh() end) end
        if effect.type=='dazzle' or effect.type=='animate' or effect.type=='pulse' or effect.type=='custom' then
            p:Heading(L['Sequence'])
            do
                local sequence=effect.sequence or {}
                p:OrderedCollection('sequence_'..id,sequence,function() local label;for _,t in ipairs(types) do if t.value==effect.type then label=t.text end end;return label or L['Effect'] end,function(p,i,entry)
                    if effect.type=='pulse' then p:Slider('seq'..i,L['Magnification'],entry,.1,2,.1,function(v) sequence[i]=v;refresh() end)
                    elseif effect.type=='animate' then p:Texture('seq'..i,L['Texture'],entry,function(v) sequence[i]=tonumber(v) or v;refresh() end)
                    elseif effect.type=='dazzle' then p:Color('seq'..i,L['Color'],entry,function(v) sequence[i]=v;refresh() end)
                    else
                        p:Texture('seq'..i..'texture',L['Texture'],entry.texture or '',function(v) entry.texture=tonumber(v) or v;refresh() end)
                        p:Slider('seq'..i..'angle',L['Angle'],entry.angle or 0,0,359,1,function(v) entry.angle=v;refresh() end)
                        p:Slider('seq'..i..'mag',L['Magnification'],entry.magnification or 1,.1,2,.1,function(v) entry.magnification=v;refresh() end)
                        p:Color('seq'..i..'color',L['Color'],entry.color,function(v) entry.color=v;refresh() end)
                    end
                end,refresh,{prefix='seq',header=false,dragIcon=function(i) return effect.type=='animate' and sequence[i] or effect.type=='custom' and sequence[i].texture or effect.texture end,endPreview=function(ghost) if ghost.effectPreview and self.HideGlow then self:HideGlow(ghost.effectPreview,'settings-drag') end end,dragPreview=function(ghost,i)
                    ghost.effectPreview=ghost.effectPreview or CreateFrame('Frame',nil,ghost);ghost.effectPreview:ClearAllPoints();ghost.effectPreview:SetPoint('TOPLEFT',8,-8);ghost.effectPreview:SetSize(28,28);ghost.effectPreview:Show()
                    if self.HideGlow then self:HideGlow(ghost.effectPreview,'settings-drag') end
                    if self.Glow then local selected=self:CopySettingsData(effect);selected.sequence={self:CopySettingsData(sequence[i])};self:Glow(ghost.effectPreview,'settings-drag',selected,{r=1,g=1,b=1,a=1},1,'CENTER',0,0) end
                end,dragSummary=function(i) local e=sequence[i];return effect.type=='pulse' and L['Magnification']..': '..tostring(e) or effect.type=='animate' and L['Texture']..': '..tostring(e) or effect.type=='custom' and L['Texture']..': '..tostring(e.texture)..' / '..L['Magnification']..': '..tostring(e.magnification) or L['Color'] end})
                p:Button('sequence_add',L['Add step'],function()
                    effect.sequence=effect.sequence or {};local value=effect.type=='pulse' and 1 or effect.type=='animate' and '' or effect.type=='dazzle' and {r=1,g=1,b=1,a=1} or {texture='',angle=0,color={r=1,g=1,b=1,a=1},magnification=1}
                    effect.sequence[#effect.sequence+1]=value;refresh();p:Draw()
                end,'plus')
            end
        end
        local actionEntries={{key='duplicate',text=L['Duplicate'],icon='copy',action=function() local nextId=self:uuid();effects[nextId]=self:CopySettingsData(effect);effects[nextId].name=string.format(L['Copy of %s'],effect.name or id);p.selection=nextId;p:Draw() end},
            {key='transfer',text=L['Import/Export'],icon='transfer',action=function()
                local codec=self:NewRotationCodec();local text,why=codec:Encode(effect);if not text then p:Message(why);return end
                self:ShowSettingsTextTransfer(p,L['Effect'],text,function(input,settings)
                    local decoded,errorCode=codec:Decode(input);if not decoded or not validEffect(decoded.value) then return false,errorCode or L['Invalid effect.'] end
                    local value=self:CopySettingsData(decoded.value);local name=settings.mode=='new' and settings.name or effect.name
                    for other,record in pairs(effects) do if (settings.mode=='new' or other~=id) and record.name==name then return false,L['This name is already in use.'] end end;value.name=name
                    if settings.mode=='new' then local generated=self:uuid();store.global.effects=store.global.effects or {};store.global.effects[generated]=value;p.selection=generated;p.creating=false;p.newEffect=nil
                    elseif isNew then p.newEffect=value else effects[id]=value end;refresh();return true
                end,{canReplace=not isNew,selectedName=effect.name,fallbackName=L['Imported effect'],originalName=function(input) local decoded=codec:Decode(input);return decoded and type(decoded.value)=='table' and decoded.value.name end})
            end},
            {key='delete',text=L['Delete'],icon='trash',action=function()
                self:ConfirmSettingsDeletion(p,L['Delete this effect? Rotations using it will need another effect.'],function()
                    if not (self.db.global.effects or {})[id] then return false,'effect-changed' end
                    self.db.global.effects[id]=nil;return true
                end)
            end}}
        actionEntries[1].enabled=not isNew;self:CollectionFooter(p,'effect',effects,isNew and nil or id,actionEntries[1],actionEntries[2]);if not isNew then self:SettingsTopDelete(p,actionEntries[3].action) end
        refresh()
    end
    if isNew then
        p.fields.new_name=p.fields.name;p.fields.new_type=p.fields.type
        p:CreationActions(function()
            if not self:SettingsNonempty(p.newEffect.name) then p:Message(L['Enter a name first.']);return end
            if not validEffect(p.newEffect) then p:Message(L['Complete the effect settings before applying.']);return end
            for _,value in pairs(effects) do if value.name==p.newEffect.name then p:Message(L['This name is already in use.']);return end end
            local id=self:uuid();store.global.effects=store.global.effects or {};store.global.effects[id]=self:CopySettingsData(p.newEffect);defaults(store.global.effects[id]);p.selection=id;p.creating=false;p.newEffect=nil;p:Draw()
        end,function() p.creating=false;p.selection=p.previousSelection;p.newEffect=nil;p.emptyDismissed=true;p:Draw() end)
    elseif not effect then
        self:CollectionFooter(p,'effect',effects,nil,{key='duplicate',text=L['Duplicate'],icon='copy',enabled=false,action=function() end},{key='transfer',text=L['Import/Export'],icon='transfer',action=function()
            local codec=self:NewRotationCodec();self:ShowSettingsTextTransfer(p,L['Effect'],'',function(input,settings) local decoded,why=codec:Decode(input);if not decoded or not validEffect(decoded.value) then return false,why or L['Invalid effect.'] end;p.newEffect=decoded.value;p.newEffect.name=settings.name;p.creating=true;return true end,{fallbackName=L['Imported effect'],originalName=function(input) local decoded=codec:Decode(input);return decoded and type(decoded.value)=='table' and decoded.value.name end})
        end})
    end
end
]====],
    ["UI/settings_items.lua"] = [====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function itemValue(text)
    local value=text:match('^%s*(.-)%s*$');if value=='' then return end
    local number=tonumber(value);if number then if number<=0 or number%1~=0 then return end;return number end
    return value
end
function addon:BuildItemSettings(p)
    self:ItemSettingsSourceOptions(p,{})
    if p.itemSettingsSource=='stock' then return self:BuildStockSettings(p) end
    local store=p:SettingsData()
    local profileSets=store.profile.itemsets or {};local globalSets=store.global.itemsets or {};local merged={}
    for id,set in pairs(globalSets) do merged[id]=set end;for id,set in pairs(profileSets) do merged[id]=set end
    local entries=self:SettingsEntries(merged);for _,entry in ipairs(entries) do local value=(merged[entry.value].items or {})[1];local info=value and self:GetReferenceProvider('item').info(tonumber(value) or self:GetReferenceProvider('item').resolve(value));entry.icon=info and info.icon or 'Interface\\Icons\\INV_Misc_Bag_08' end;if not merged[p.selection] and not p.creating then p.selection=entries[1] and entries[1].value end
    p:UseRoster(entries,p.selection,function(id) p.selection=id;p.creating=false;p:Draw() end,self:ItemSettingsSourceOptions(p,{newText=L['Add item set'],new=function() p.previousSelection=p.selection;p.selection=nil;p.creating=true;p.emptyDismissed=false;p:Draw() end}));p:Heading(L['Item Sets']);if p.historyEnabled then p:HistoryActions() end
    local set=merged[p.selection]
    if set then
        local id=p.selection;local items=set.items or {}
        local function update()
            local first=(set.items or {})[1];local provider=self:GetReferenceProvider('item');local info=first and provider.info(tonumber(first) or provider.resolve(first));p:UpdateRosterEntry(id,{text=set.name,icon=info and info.icon or 'Interface\\Icons\\INV_Misc_Bag_08'})
            set.modified=true;p:RunSettingsEffect('items_'..id,function() if self.UpdateBoundButton then self:UpdateBoundButton(id) end;if self.UpdateItemSetButtons then self:UpdateItemSetButtons(id) end end)
        end
        p:Edit('name',L['Name'],set.name or '',function(text) return self:SettingsNonempty(text) end,function(text) set.name=text;update() end)
        p:InlineCheck('name','global',L['Global'],globalSets[id]~=nil,function(value)
            store.global.itemsets=store.global.itemsets or {};store.profile.itemsets=store.profile.itemsets or {}
            if value then store.global.itemsets[id]=set;store.profile.itemsets[id]=nil else store.profile.itemsets[id]=set;store.global.itemsets[id]=nil end;p:Draw()
        end,140)
        p:Section('items_'..id,L['Items in priority order'],function()
            p:OrderedCollection('items_'..id,items,function(i) return self:GetReferenceProvider('item').name(tonumber(items[i]) or self:GetReferenceProvider('item').resolve(items[i])) or L['Item data loading'] end,function(form,i,item,row)
                local field=form:Item('item'..i,nil,item,function(value) items[i]=value;update() end);field:ClearAllPoints();field:SetPoint('TOPLEFT',18,-2);field:SetSize(form.width-20,24);form.y=22
            end,update,{prefix='item',compact=true})
            p.newItem=p.newItem or '';local y=p.y;local newItem=p:Item('new_item',L['Item'],p.newItem,function(value) p.newItem=value end,true);newItem:SetWidth(math.max(60,p.width-334))
            local add=p:Button('add_item',L['Add item'],function() local value=itemValue(tostring(p.newItem));if not value then p:Message(L['Choose an item first.']);return end;set.items=set.items or {};set.items[#set.items+1]=value;p.newItem='';update();p:Draw() end,'plus');add:ClearAllPoints();add:SetPoint('TOPRIGHT',0,-y);add:SetWidth(104);p.y=p.y-28
        end)
        local bindings=self.db.char and self.db.char.bindings or {}
        local binding=p:Acquire('bindingPill',function() return self:CreateWorkbenchPill(p.child,'',180) end);binding:ClearAllPoints();binding:SetPoint('TOPRIGHT',-100,-4);binding:SetSize(200,18);p.fields.binding=binding;p.fields.bind=binding
        local function refreshBinding()
            local slots=bindings[id];local labels={};for _,slot in ipairs(slots or {}) do labels[#labels+1]=tostring(slot) end
            binding:SetText(#labels>0 and string.format(L['Slots %s · Unbind'],table.concat(labels,', ')) or L['Bind']);binding:SetSelected(#labels>0)
            if self.EndHighlightSlot then self:EndHighlightSlot() end;if slots and self.HighlightSlots then self:HighlightSlots(slots) end
        end
        self:SetUIScript(binding,'OnClick',p:Guard(function() if not p:FlushEdits() then return end
            if InCombatLockdown and InCombatLockdown() then p:Message(L['Leave combat before changing action bar bindings.']);return end
            if bindings[id] then if self.UnbindItemSet then if self:UnbindItemSet(id)==false then p:Message(L['Leave combat before changing action bar bindings.']);return end else bindings[id]=nil;if self.EndHighlightSlot then self:EndHighlightSlot() end end;refreshBinding();return end
            if p.transactionKeys and p:IsSettingsDraftDirty() then p:Message(L['Apply item-set changes before binding it to an action bar.']);return end
            local first;if self.FindFirstItemOfItemSet then first=self:FindFirstItemOfItemSet({},id,true) elseif self.FindFirstItemInItems then first=self:FindFirstItemInItems(items) end
            if not first or type(PickupItem)~='function' then p:Message(L['An item from this set must be available before binding.']);return end
            self.bindingItemSet=id;PickupItem(first)
        end))
        local token=p.generation;local callback=function(changedId) if p:Valid(token) and (changedId==nil or changedId==id) then refreshBinding() end end;self.itemSetCallback=callback;refreshBinding()
        p.cleanups[#p.cleanups+1]=function() if self.itemSetCallback==callback then self.itemSetCallback=nil end;if self.bindingItemSet==id then self.bindingItemSet=nil;if type(GetCursorInfo)=='function' and GetCursorInfo()=='item' and type(ClearCursor)=='function' then ClearCursor() end end;if self.EndHighlightSlot then self:EndHighlightSlot() end end
        local actionEntries={{key='duplicate',text=L['Duplicate'],icon='copy',action=function() local new=self:uuid();store.profile.itemsets=store.profile.itemsets or {};store.profile.itemsets[new]=self:CopySettingsData(set);store.profile.itemsets[new].name=string.format(L['Copy of %s'],set.name or id);p.selection=new;p:Draw() end},
            {key='transfer',text=L['Import/Export'],icon='transfer',action=function()
                local codec=self:NewRotationCodec();local text,why=codec:Encode({format='RM-ItemSet',version=1,name=set.name,items=items});if not text then p:Message(why);return end
                self:ShowSettingsTextTransfer(p,L['Item Set'],text,function(input,settings)
                    local candidate,errorText=self:ParseItemSetImport(input,codec);if not candidate then return false,errorText end
                    if settings.mode=='replace' then set.items=self:CopySettingsData(candidate.items);update()
                    else local generated=self:uuid();store.profile.itemsets=store.profile.itemsets or {};store.profile.itemsets[generated]={name=settings.name,items=self:CopySettingsData(candidate.items)};p.selection=generated;p.creating=false;p:RunSettingsEffect('items_'..generated,function() if self.UpdateItemSetButtons then self:UpdateItemSetButtons(generated) end end) end;return true
                end,{canReplace=true,selectedName=set.name,fallbackName=L['Imported item set'],originalName=function(input) local candidate=self:ParseItemSetImport(input,codec);return candidate and candidate.name end})
            end},
            {key='reset',text=L['Reset'],icon='undo',enabled=self.getDefaultItemset and self:getDefaultItemset(id)~=nil or false,action=function() local defaults=self:getDefaultItemset(id);if defaults then set.items=self:CopySettingsData(defaults);update();set.modified=false;p:Draw() end end},
            {key='delete',text=L['Delete'],icon='trash',action=function()
                self:ConfirmSettingsDeletion(p,L['Delete this item set and its binding? Rotations referencing it will need another item set.'],function()
                    local profile,global=self.db.profile.itemsets or {},self.db.global.itemsets or {};local current=profile[id] or global[id]
                    if not current then return false,'item-set-changed' end
                    if self.UnbindItemSet then if self:UnbindItemSet(id,self:CopySettingsData(current.items or {}))==false then return false,L['Leave combat before changing action bar bindings.'] end
                    elseif self.db.char and self.db.char.bindings then self.db.char.bindings[id]=nil end
                    profile[id]=nil;global[id]=nil;if self.UpdateItemSetButtons then self:UpdateItemSetButtons(id) end;return true
                end)
            end}}

        self:CollectionFooter(p,'itemset',merged,id,actionEntries[1],actionEntries[2]);self:SettingsTopDelete(p,actionEntries[4].action)
        local reset=p:Acquire('resetPill',function() return self:CreateWorkbenchPill(p.child,L['Reset'],62) end);reset:ClearAllPoints();reset:SetPoint('TOPRIGHT',-30,-4);reset:SetSize(62,18);reset:SetText(L['Reset']);p.fields.reset=reset;if actionEntries[3].enabled then reset:Enable() else reset:Disable() end;self:SetUIScript(reset,'OnClick',p:Guard(function() if p:FlushEdits() then actionEntries[3].action() end end))
    end
    if p.creating or not set then
    self:CollectionFooter(p,'itemset',merged,nil,{key='duplicate',text=L['Duplicate'],icon='copy',enabled=false,action=function() end},{key='transfer',text=L['Import/Export'],icon='transfer',action=function()
        local codec=self:NewRotationCodec();self:ShowSettingsTextTransfer(p,L['Item Set'],'',function(text,settings)
            local candidate,why=self:ParseItemSetImport(text,codec);if not candidate then return false,why end
            local id=self:uuid();store.profile.itemsets=store.profile.itemsets or {};store.profile.itemsets[id]={name=settings.name,items=self:CopySettingsData(candidate.items)};p.selection=id;p.creating=false;return true
        end,{fallbackName=L['Imported item set'],originalName=function(input) local candidate=self:ParseItemSetImport(input,codec);return candidate and candidate.name end})
    end})
    if not p.creating and not p:CanAutoCreateCollection('profile','itemsets') then return end
    p:Heading(L['Add item set']);p.newItemSetName=p.newItemSetName or '';p:Edit('new_name',L['Name'],p.newItemSetName,nil,function(text) p.newItemSetName=text end)
    p:CreationActions(function()
        if not self:SettingsNonempty(p.newItemSetName) then p:Message(L['Enter a name first.']);return end
        local id=self:uuid();store.profile.itemsets=store.profile.itemsets or {};store.profile.itemsets[id]={name=p.newItemSetName,items={}};p.selection=id;p.creating=false;p.newItemSetName='';p:Draw()
    end,function() p.creating=false;p.selection=p.previousSelection;p.emptyDismissed=true;p.newEffectName=nil;p.newItemSetName=nil;p:Draw() end)
    end
end
]====],
    ["Core/rotation_lifecycle.lua"] = [====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Also called after import overlays: AceDB emits Reset/Copy before the
-- importer publishes its final roots, so its event alone cannot authorize them.
function addon:RefreshRotationProfileStorage()
    local ok,why=self:InitializeScopedRotationStorage()
    self.rotationStorageError=not ok and why or nil
    if self.InitializeRotationLibrary then self:InitializeRotationLibrary() end
    if not ok and self.warn then self:warn(L['Rotation data requires recovery: %s'],why) end
    return ok,why
end

function addon:RotationProfileChanged()
    if (self.rotationProfileChangeDepth or 0)>0 then return self:RefreshRotationProfileStorage() end
    if self.DisableRotation then self:DisableRotation() end
    self.manualRotation=false;self.autoswitchRotation={};self.longtermCache={}
    self.configRotationSelection=nil
    local ok,why=self:RefreshRotationProfileStorage()
    if self.RefreshConfiguration then self:RefreshConfiguration() end
    if ok and self.db.profile.enable and self.EnableRotation then self:EnableRotation() end
    return ok,why
end

function addon:InstallRotationProfileLifecycle()
    local db=self.db
    local previous=self.rotationProfileLifecycleDB
    local previousOwner=self.rotationProfileLifecycleOwner
    if self.rotationProfileLifecycleInstalled and previous==db and previousOwner then return end
    -- Retire authority before removing callbacks. A callback already captured
    -- by a dispatch must not apply the old database's event to a new active DB.
    self.rotationProfileLifecycleDB=nil
    self.rotationProfileLifecycleOwner=nil
    if previous and previousOwner then
        for _,event in ipairs({'OnProfileChanged','OnProfileCopied','OnProfileReset'}) do
            previous.UnregisterCallback(previousOwner,event)
        end
    end
    -- The addon itself already owns the init reset seeder on this registry.
    -- Give lifecycle callbacks a distinct binding owner so both can coexist.
    local owner={}
    local function changed(...)
        if self.db~=db or self.rotationProfileLifecycleDB~=db or self.rotationProfileLifecycleOwner~=owner then return end
        return self:RotationProfileChanged(...)
    end
    for _,event in ipairs({'OnProfileChanged','OnProfileCopied','OnProfileReset'}) do
        db.RegisterCallback(owner,event,changed)
    end
    self.rotationProfileLifecycleDB=db
    self.rotationProfileLifecycleOwner=owner
    self.rotationProfileLifecycleInstalled=true
end
]====],
    ["UI/settings_profiles.lua"] = [====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function nonempty(text) if text:find('%S') and #text<=50 then return text end end
function addon:BuildProfileSettings(p)
    local db=self.db;local current=db:GetCurrentProfile();local names=db:GetProfiles();table.sort(names)
    local entries,values={},{};for _,name in ipairs(names) do entries[#entries+1]={value=name,text=name};values[name]=name==current and db.profile or db.profiles and db.profiles[name] or {} end
    if not values[p.selection] and not p.creating then p.selection=current end
    local function overlay(destination,incoming) for key,value in pairs(incoming) do if (key=='color' or key=='minimap' or key=='preview_window') and type(value)=='table' and type(destination[key])=='table' then for field,entry in pairs(value) do destination[key][field]=self:CopySettingsData(entry) end else destination[key]=self:CopySettingsData(value) end end end
    local function saved(name) return name==db:GetCurrentProfile() and db.profile or db.profiles[name] end
    local function stockOK(profile)
        if self.StockSettings.CheckProfile(profile) then return true end
        p:Message(L['Invalid stock targets; data preserved.']);return false
    end
    local function change(operation,name,after)
        if operation=='CopyProfile' and not stockOK(saved(name)) then return false end
        if self.DisableRotation then self:DisableRotation() end
        local depth=self.rotationProfileChangeDepth or 0;self.rotationProfileChangeDepth=depth+1
        local ok,why=pcall(function() if operation=='CopyProfile' and not stockOK(saved(name)) then error(L['Invalid stock targets; data preserved.'],0) end;db[operation](db,name);if after then after() end end)
        self.rotationProfileChangeDepth=depth
        if self.RotationProfileChanged then self:RotationProfileChanged()
        elseif self.EnableRotation then self:EnableRotation() end
        if not ok then p:Message(tostring(why));return false end
        p.profile=db.profile;p.selection=p.selectAfterProfileChange or db:GetCurrentProfile();p.selectAfterProfileChange=nil;p:Draw();if self.RefreshConfiguration then self:RefreshConfiguration() end;return true
    end
    p:UseRoster(entries,p.selection,function(name) p.selection=name;p.creating=false;p:Draw() end,{new=function() p.previousSelection=p.selection;p.creating=true;p.newProfileName='';p.profileSource=nil;p.importProfile=nil;p:Draw() end})
    local selected=not p.creating and values[p.selection] or nil;local selectedName=p.selection
    local compareValues={};for name,value in pairs(values) do compareValues[name]={name=name,profile=value} end
    self:CollectionFooter(p,'profile',compareValues,selected and selectedName or nil,
        {key='duplicate',text=L['Duplicate'],icon='copy',enabled=selected~=nil,action=function() if not stockOK(saved(selectedName)) then return end;p.previousSelection=p.selection;p.profileSource=selectedName;p.newProfileName=string.format(L['Copy of %s'],selectedName);p.creating=true;p:Draw() end},
        {key='transfer',text=L['Import/Export'],icon='transfer',action=function()
            local codec=self:NewRotationCodec();local text,why='',nil
            if selected then
                local portable=self:ProfileToPortable(selected);if not portable then p:Message(L['Invalid profile.']);return end
                text,why=codec:Encode({format='RM-Profile',version=1,name=selectedName,profile=portable});if not text then p:Message(why);return end
            end
            if selected and not stockOK(selected) then return end
            local baseline=selected and self:CopySettingsData(selected)
            self:ShowSettingsTextTransfer(p,L['Profiles'],text,function(input,settings)
                local decoded,errorText=codec:Decode(input);local wrapper=decoded and decoded.value;local candidate=type(wrapper)=='table' and self:ProfileFromPortable(wrapper.profile,{preserveLegacyBodies=true})
                if type(wrapper)~='table' or wrapper.format~='RM-Profile' or wrapper.version~=1 or type(candidate)~='table' then return false,errorText or L['Invalid profile.'] end
                local plan,migrationError=self:PlanRotationProfileMigration(candidate,candidate.rotationFallbackID or DEFAULT)
                if not plan then return false,migrationError end
                local migrated,why=self:ApplyRotationProfileMigration(plan);if not migrated or not self:ValidateProfileTransfer(candidate) then return false,why or L['Invalid profile.'] end
                if settings.mode=='replace' and selected then
                    local target=selectedName==db:GetCurrentProfile() and db.profile or db.profiles[selectedName]
                    if not stockOK(target) then return false,L['Invalid stock targets; data preserved.'] end
                    if target~=selected or not self:SettingsDataEqual(baseline,self:CopySettingsData(target)) then return false,L['The selected profile changed. Reopen the import window.'] end
                    if selectedName==db:GetCurrentProfile() then return change('ResetProfile',nil,function() overlay(db.profile,candidate) end) end
                    db.profiles[selectedName]=self:CopySettingsData(candidate);p.selection=selectedName;return true
                end
                for _,name in ipairs(db:GetProfiles()) do if name==settings.name then return false,L['This name is already in use.'] end end
                p.importProfile=candidate;p.profileSource=nil;p.newProfileName=settings.name;p.previousSelection=p.selection;p.creating=true;return true
            end,{canReplace=selected~=nil,selectedName=selectedName,fallbackName=L['Imported profile'],originalName=function(input) local decoded=codec:Decode(input);return decoded and type(decoded.value)=='table' and decoded.value.name end})
        end},function(left,right)
            local first,second=saved(left.name),saved(right.name)
            if not first or not second then p:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return end
            if stockOK(first) and stockOK(second) then self:ShowCollectionComparison(p,'profile',{name=left.name,profile=first},{name=right.name,profile=second}) end
        end)
    p:Heading(L['Profiles']);p:Text(L['Profile changes apply immediately. Rotations and settings belong to the active profile.'])
    if p.creating then
        p:Edit('new_name',L['New profile name'],p.newProfileName or '',nil,function(text) p.newProfileName=text end)
        p:CreationActions(function()
            local name=nonempty(p.newProfileName or '');if not name then p:Message(L['Enter a profile name first.']);return end
            for _,existing in ipairs(db:GetProfiles()) do if existing==name then p:Message(L['This name is already in use.']);return end end
            local source=p.profileSource;local imported=p.importProfile;local previous=db:GetCurrentProfile()
            if source and not stockOK(saved(source)) then return end;p.selectAfterProfileChange=name
            local ok=change('SetProfile',name,function() if source then if not stockOK(saved(source)) then db:SetProfile(previous);error(L['Invalid stock targets; data preserved.'],0) end;db:CopyProfile(source) elseif imported then overlay(db.profile,imported) end;db:SetProfile(previous);p.creating=false;p.importProfile=nil;p.profileSource=nil end)
            if ok then p.newProfileName=nil end
        end,function() p.creating=false;p.selection=p.previousSelection or current;p.profileSource=nil;p.importProfile=nil;p.newProfileName=nil;p:Draw() end);p.fields.new=p.fields.apply;return
    end
    if selected then
        p:Heading(selectedName)
        local active=p:Button('activate',selectedName==current and L['Active profile'] or L['Activate profile'],function() change('SetProfile',selectedName) end);if selectedName==current then active:Disable() end
        local rows,recovery=self:GetProfileRotationHeaders(selected)
        local summary={};for _,row in ipairs(rows or {}) do summary[#summary+1]=row.name end;table.sort(summary)
        p:Text(not rows and string.format(L['Rotation data requires recovery: %s'],recovery) or #summary>0 and table.concat(summary,'\n') or L['No rotations in this profile.'])
        local others={};for _,entry in ipairs(entries) do if entry.value~=current then others[#others+1]=entry end end
        -- Keep explicit copying into the active profile available, with its
        -- existing replacement confirmation and runtime lifecycle.
        local copy=p:Choice('copy',L['Copy from profile'],nil,others,function(name) p:Confirm(string.format(L['Replace the current profile with %s?'],name),function() change('CopyProfile',name) end) end);if #others==0 then copy:Disable() end
        local reset=p:Button('reset',L['Reset current profile'],function() p:Confirm(L['Reset this profile to its defaults? Custom rotations and settings in it will be replaced.'],function() change('ResetProfile') end) end);if selectedName~=current then reset:Disable() end
        local trash=self:SettingsTopDelete(p,function() p:Confirm(string.format(L['Delete profile %s? This cannot be undone.'],selectedName),function() db:DeleteProfile(selectedName);p.selection=current;p:Draw() end) end);if selectedName==current or selectedName=='Default' then trash:Disable() end
        -- Compatibility for existing direct current-profile callers; sidebar
        -- selection is inspection, activation is always explicit.
        p.fields.current=p.fields.activate
    end
end
function addon:BuildAboutSettings(p)
    local getter=C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local function meta(key) if type(getter)=='function' then local ok,value=pcall(getter,addon_name,key);if ok and type(value)=='string' and value~='' then return value end end end
    p:Heading(addon.pretty_name or L['Rotation Master']);p:Text(meta('Notes') or L['Browse, view and edit rotations.'])
    for _,entry in ipairs({{'Version','Version'},{'Author','Author'},{'X-License','License'},{'X-Credits','Credits'},{'X-Localizations','Localizations'}}) do
        local value=meta(entry[1]);if value then if value:find('@',1,true) then value=L['Development'] end;p:Text(L[entry[2]]..': '..value) end
    end
    p:Heading(L['Links'])
    for _,entry in ipairs({{'X-Website','Website'},{'X-Discord','Discord'},{'X-Email','Email'}}) do local value=meta(entry[1]);if value then
        local c=p:Edit(entry[1],L[entry[2]],value,nil,function() end)
        addon:SetUIScript(c,'OnEditFocusGained',p:Guard(function() c:SetCursorPosition(0);c:HighlightText(0,-1) end))
        addon:SetUIScript(c,'OnTextChanged',p:Guard(function(_,user) if user then c:SetText(value) end end))
    end end
    p:Heading(L['Commands']);p:Text('/rm config\n/rm errors\n/rm help')
end
]====],
    ["init.lua"] = [====[local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

local multiinsert, deepcopy = addon.Functions.collections.multiinsert, addon.Functions.collections.deepcopy

local CHAR_VERSION = 1
local PROFILE_VERSION = 2
local GLOBAL_VERSION = 1

local classKey = select(2, UnitClass("player"))

local combination_food = {}
local conjured_food = { 22895, 8076, 8075, 1487, 1114, 1113, 5349, }
local conjured_water = { 8079, 8078, 8077, 3772, 2136, 2288, 5350, }
local mana_potions = { 13444, 13443, 6149, 3827, 3385, 2455, }
local healing_potions = { 13446, 3928, 1710, 929, 858, 118, }
local bandages = { 14530, 14529, 8545, 8544, 6451, 6450, 3531, 3530, 2581, 1251, }
local purchased_water = { 8766, 1645, 1708, 1205, 1179, 159, }
local healthstones = {
    "Major Healthstone",
    "Greater Healthstone",
    "Healthstone",
    "Lesser Healthstone",
    "Minor Healthstone",
}

if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
    combination_food = { 113509, 80618, 80610, 65499, 43523, 43518, 65517, 65516, 65515, 65500 }
    multiinsert(mana_potions, { 152495, 127835, 109222, 76098, 57192, 33448, 40067, 31677, 22732, 28101 })
    multiinsert(healing_potions, { 169451, 152494, 127834, 152615, 109223, 57191, 39671, 22829, 28100 })
    multiinsert(bandages, { 158382, 158381, 133942, 133940, 111603, 72986, 72985, 53051, 53050, 53049, 34722, 34721, 21991, 21990 })
    multiinsert(healthstones, {
        "Legion Healthstone",
        "Fel Healthstone",
        "Demonic Healthstone",
        "Master Healthstone",
    })
else
    if (LE_EXPANSION_LEVEL_CURRENT >= 1) then
        combination_food = { 34062 }
        multiinsert(conjured_food, { 22019 })
        multiinsert(conjured_water, { 22018, 30703, })
        multiinsert(mana_potions, { 31677, 33093, 23823, 22832, 32948, 33935, 28101 })
        multiinsert(healing_potions, { 33092, 23822, 22829, 32947, 28100, 33934 })
        multiinsert(bandages, { 21991, 21990, 23684 })
        multiinsert(purchased_water, { 33042, 29395, 27860, 32453, 38430, 28399, 29454, 32455, 24007, 24006, 23161 })
        multiinsert(healthstones, {
            "Master Healthstone",
        })
    end
    if (LE_EXPANSION_LEVEL_CURRENT >= 2) then
        multiinsert(combination_food, { 43523, 43518 })
        multiinsert(mana_potions, { 33448, 40067, 31677, 43570 })
        multiinsert(healing_potions, { 33447, 39671, 43569 })
        multiinsert(bandages, { 38640, 34722, 38643, 34721 })
        multiinsert(purchased_water, { 42777 })
        multiinsert(healthstones, {
            "Fel Healthstone",
            "Demonic Healthstone",
        })
    end
end

local default_itemsets = {
    ["e8d1525c-0412-40c1-95a4-00da22bc169e"] = {
        name = "Combination Food",
        items = combination_food,
    },
    ["e626834f-60b1-413f-9c87-8ddeeb4374aa"] = {
        name = "Conjured Food",
        items = conjured_food,
    },
    ["3b10f7d6-abb2-430c-b153-7189eca75838"] = {
        name = "Conjured Water",
        items = conjured_water,
    },
    ["6079c534-5f69-430e-b1bd-b487a31dcdd3"] = {
        name = "Mana Potions",
        items = mana_potions,
    },
    ["9294d112-681b-43bc-ac62-5d6bec5c1f7d"] = {
        name = "Healing Potions",
        items = healing_potions,
    },
    ["e66d5cfe-a0f0-4276-aa00-40464eab30df"] = {
        name = "Bandages",
        items = bandages,
    },
    ["b1aca4a4-acdd-4885-b63b-b62cca7afdfe"] = {
        name = "Purchased Water",
        items = purchased_water,
    },
    ["fed2659d-cb7b-43e1-8f53-6dda0391b8c6"] = {
        name = "Healthstones",
        items = healthstones,
    },
}

local default_effects = {
    ["61b36ed1-fa31-4656-ad71-f3d50f193a85"] = {
        type = "texture",
        name = "Ping",
        texture = "Interface\\Cooldown\\ping4",
    },
    ["332c4db5-5134-411d-9af5-f47e12f5f4b8"] = {
        type = "texture",
        name = "Star",
        texture = "Interface\\Cooldown\\star4",
    },
    ["c58ddd8a-26f4-4709-8f82-5e25dc851507"] = {
        type = "texture",
        name = "Starburst",
        texture = "Interface\\Cooldown\\starburst",
    },
    ["102e4302-c7f5-4722-8004-583f95ce473d"] = {
        type = "blizzard",
        name = "Glow",
    },
    ["4d003e1d-cbb3-41c8-b1aa-50afe80561a6"] = {
        type = "pixel",
        name = "Pixel",
    },
    ["b8d33d53-62d7-4a08-a0fa-933d2cf8de9c"] = {
        type = "autocast",
        name = "Auto Cast",
    },
    ["d2ab8d6c-4346-42fd-bb1a-dc967feb32b7"] = {
        ["type"] = "animate",
        ["name"] = "Boom!",
        ["frequency"] = 0.25,
        ["sequence"] = {
            "Interface\\Cooldown\\star4", -- [1]
            "Interface\\Cooldown\\starburst", -- [2]
            "Interface\\Cooldown\\ping4", -- [3]
        },
    },
    ["cbd72b0b-e0f4-4f6e-bef4-459776a5d7a9"] = {
        ["type"] = "rotate",
        ["name"] = "Rotating Starburst",
        ["steps"] = 16,
        ["frequency"] = 0.1,
        ["texture"] = "Interface\\Cooldown\\star4",
    },
    ["ec8946a4-c3aa-4397-b129-a0c8d6fed479"] = {
        ["type"] = "pulse",
        ["name"] = "Pulse",
        ["texture"] = "Interface\\Cooldown\\ping4",
        ["sequence"] = {
            0.4, -- [1]
            0.6, -- [2]
            0.8, -- [3]
            1, -- [4]
            1.2, -- [5]
            1.4, -- [6]
        },
        ["frequency"] = 0.1,
    }
}

local default_condition_groups = {
    {
        id = "b3d7df2c-f257-4a2d-961e-66e49336d109",
        name = L["Combat"],
        conditions = {
            "CASTING", "CASTING_SPELL", "CASTING_REMAIN", "CAST_INTERRUPTABLE",
            "CHANNELING", "CHANNELING_SPELL", "CHANNELING_REMAIN", "CHANNEL_INTERRUPTABLE",
            "COMBAT", "STEALTHED", "INCONTROL", "LOC_TYPE", "LOC_BLOCKED",
            "RUNNER", "RESIST", "IMMUNE", "MOVING", "THREAT", "THREAT_COUNT",
            "ATTACKABLE", "ENEMY", "COMBAT_HISTORY", "COMBAT_HISTORY_TIME", "TIME_IN_COMBAT",
        }
    },
    {
        id = "b8136123-2bda-4230-a77a-89ea2aed3a1a",
        name = L["Character"],
        conditions = {
            "CLASS", "CLASS_GROUP", "CREATURE", "CLASSIFICATION", "LEVEL", "TALENT",
            "ROLE", "GROUP", "FORM", "PET", "PET_NAME",
            "HEALTH", "HEALTHPCT", "TT_HEALTH", "TT_HEALTHPCT",
            "MANA", "MANAPCT", "POWER", "POWERPCT", "POINT", "RUNE", "RUNE_COOLDOWN",
            "TOTEM", "TOTEM_SPELL", "TOTEM_REMAIN", "TOTEM_SPELL_REMAIN",
            "STAT", "ECS_STAT", "ECS_STAT_PCT"
        }
    },
    {
        id = "8034819e-26f5-4f4e-9153-d8cab5e65f31",
        name = L["Spells"],
        conditions = {
            "SPELL_KNOWN", "SPELL_AVAIL", "SPELL_RANGE", "SPELL_COOLDOWN", "SPELL_REMAIN",
            "SPELL_CHARGES", "SPELL_ACTIVE", "SPELL_HISTORY", "SPELL_HISTORY_TIME",
            "PETSPELL_AVAIL", "PETSPELL_RANGE", "PETSPELL_COOLDOWN", "PETSPELL_REMAIN",
            "PETSPELL_CHARGES", "PETSPELL_ACTIVE", "PETSPELL_HISTORY", "PETSPELL_HISTORY_TIME",
            "ANYSPELL_AVAIL", "ANYSPELL_RANGE", "ANYSPELL_COOLDOWN", "ANYSPELL_REMAIN",
            "ANYSPELL_CHARGES",
        }
    },
    {
        id = "fca4ff75-4085-458a-b5bf-27a6b52f2092",
        name = L["Items"],
        conditions = {
            "EQUIPPED", "CARRYING", "ITEM", "ITEM_RANGE", "ITEM_COOLDOWN", "GLYPH",
        }
    },
    {
        id = "e618608c-92ec-4ae9-9dde-40a397d7beb9",
        name = L["Buffs"],
        conditions = {
            "BUFF", "BUFF_REMAIN", "BUFF_STACKS", "STEALABLE",
            "DEBUFF", "DEBUFF_REMAIN", "DEBUFF_STACKS", "DISPELLABLE",
            "WEAPON", "WEAPON_REMAIN", "WEAPON_STACKS", "SWING_TIME", "SWING_TIME_REMAIN",
        }
    },
    {
        id = "fa10aaf8-bc71-480f-9062-c949fd7c74e9",
        name = L["Spatial"],
        conditions = {
            "ZONE", "OUTDOORS", "DISTANCE", "BEYOND_MELEE", "DISTANCE_COUNT", "PROXIMITY",
            "PROXIMITY_HEALTH", "PROXIMITY_HEALTH_COUNT", "PROXIMITY_HEALTHPCT", "PROXIMITY_HEALTHPCT_COUNT",
            "PROXIMITY_MANA", "PROXIMITY_MANA_COUNT", "PROXIMITY_MANAPCT", "PROXIMITY_MANAPCT_COUNT",
        }
    },
}

-- Order of other conditions
local default_other_conditions_order = {
    "DELETE", "AND", "OR", "NOT", "ISSAME",
}

-- Default switch conditions
local default_switch_conditions = {
    "DELETE", "AND", "OR", "NOT", "SELF_LEVEL", "PVP", "ZONEPVP", "ZONE", "INSTANCE", "OUTDOORS",
    "STEALTHED", "GROUP", "FORM", "CLASS", "CLASS_GROUP", "CREATURE", "CLASSIFICATION",
    "PET", "PET_NAME", "EQUIPPED", "DISTANCE_COUNT", "THREAT_COUNT", "ROLE", "GLYPH"
}

-- Default 'switch only' conditions
local default_disabled_conditions = {
    "SELF_LEVEL", "PVP", "ZONEPVP", "INSTANCE",
}

local function updateRotationData(rot_func, cond_func)
    if addon.InitializeScopedRotationStorage or addon.db.profile.rotationStore~=nil or not addon.db.profile.rotations then
        return
    end

    local function updateConditionData(cond,func,depth)
        depth=depth or 0
        if type(cond)~="table" or depth>64 then return end
        if cond.type=="NOT" and type(cond.value)=="table" then
            updateConditionData(cond.value,func,depth+1)
        elseif (cond.type=="AND" or cond.type=="OR") and type(cond.value)=="table" then
            for _,subcond in pairs(cond.value) do updateConditionData(subcond,func,depth+1) end
        else func(cond) end
    end
    for _,rotations in pairs(addon.db.profile.rotations) do
        for _,rotation in pairs(rotations) do
            local tree=addon.RotationData.IndexRotationSteps(rotation,{allowMissingIds=true})
            -- Malformed data is retained for inspection, never flattened or
            -- partially upgraded by a best-effort walk over unknown structure.
            if tree then for _,row in ipairs(tree.rows) do
                local step=row.step
                if rot_func and step.type~="branch" then rot_func(step,row.section=="cooldowns") end
                if cond_func and step.conditions then updateConditionData(step.conditions,cond_func) end
            end end
        end
    end
end

local function upgradeTexturesToEffects()
    if addon.db.global.textures ~= nil then
        addon.db.global.effects = addon.db.global.textures
        for _, ent in pairs(addon.db.global.effects) do
            ent["type"] = "texture"
        end
        addon.db.global.textures = nil
    end
    if addon.db.profile.overlay ~= nil then
        addon.db.profile.effect = addon.db.profile.overlay
        addon.db.profile.overlay = nil
    end
end

local function upgradeGlobalRotationstoPlayer()
    if addon.InitializeScopedRotationStorage or addon.db.profile.rotationStore~=nil then return end
    if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
        -- Upgrade from TBC -> Wrath
        if (LE_EXPANSION_LEVEL_CURRENT >= 2) and
            addon.db.profile.rotations ~= nil and addon.db.profile.rotations[0] ~= nil then
            local rot = addon.db.profile.rotations[0]
            addon.db.profile.rotations = {}
            addon.db.profile.rotations[1] = rot
        end
    end
end

local function upgradeItemsToItemSets()
    updateRotationData(function(rot)
        if rot.type == "item" and (type(rot.action) == "number" or (type(rot.action) == "string" and
                not string.match(rot.action, "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x"))) then
            rot.action = { rot.action }
        end
    end, function(cond)
        if cond.type == "EQUIPPED" or cond.type == "CARRYING" or
                cond.type == "ITEM" or cond.type == "ITEM_COOLDOWN" or
                cond.type == "ITEM_RANGE" then
            if type(cond.item) == "number" or (type(cond.item) == "string" and
                    not string.match(cond.item, "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x")) then
                cond.item = { cond.item }
            end
        end
    end)
end

local function cacheItems()
    updateRotationData(function(rot)
        if rot.type == "item" and rot.action ~= nil and type(rot.action) == "table" then
            for _,item in pairs(rot.action) do
                GetItemInfo(item)
            end
        end
    end, function(cond)
        if cond.type == "EQUIPPED" or cond.type == "CARRYING" or
                cond.type == "ITEM" or cond.type == "ITEM_COOLDOWN" or
                cond.type == "ITEM_RANGE" then
            if cond.item ~= nil and type(cond.item) == "table" then
                for _,item in pairs(cond.item) do
                    GetItemInfo(item)
                end
            end
        end
    end)

    if addon.db.global.itemsets then
        for _,itemset in pairs(addon.db.global.itemsets) do
            if itemset.items ~= nil then
                for _,item in pairs(itemset.items) do
                    GetItemInfo(item)
                end
            end
        end
    end
    if addon.db.profile.itemsets then
        for _,itemset in pairs(addon.db.profile.itemsets) do
            if itemset.items ~= nil then
                for _,item in pairs(itemset.items) do
                    GetItemInfo(item)
                end
            end
        end
    end
end

local function upgradeAddIDToAnnounce()
    for _,announce in pairs(addon.db.profile.announces) do
        if announce.id == nil then
            announce.id = addon:uuid()
        end
    end
end

local function upgradeLogLevel()
    if addon.db.profile.debug then
        if addon.db.profile.verbose then
            addon.db.profile.loglevel = 4
        else
            addon.db.profile.loglevel = 3
        end
    end
    addon.db.profile.debug = nil
    addon.db.profile.verbose = nil
end

local function upgradeEffectsToGUID()
    local global = addon.db.global
    local name2idx = {}
    if #global.effects > 0 then
        local new_effects = {}
        for _,effect in ipairs(global.effects) do
            local uuid = addon:uuid()
            for k, v in pairs(default_effects) do
                if effect.name == v.name then
                    uuid = k
                end
            end
            new_effects[uuid] = effect
        end
        global.effects = new_effects
    end
    for k,v in pairs(global.effects) do
        if v.name and #v.name > 0 then
            name2idx[v.name] = k
        end
    end
    if global.effects[addon.db.profile.effect] == nil then
        addon.db.profile.effect = name2idx[addon.db.profile.effect]
    end

    updateRotationData(function(rot, is_cooldown)
        if is_cooldown and rot.effect ~= nil and rot.effect ~= NONE and global.effects[rot.effect] == nil then
            rot.effect = name2idx[rot.effect]
        end
    end)

    if addon.db.global.version == nil or addon.db.global.version < 1 then
        StaticPopupDialogs["ROTATIONMASTER_RESET_EFFECTS"] = {
            text = addon.pretty_name,
            subText = L["Default effects have changed since the previous release, do you want to reset the effect list?"],
            button1 = YES,
            button2 = NO,
            OnAccept = function()
                addon.db.global.effects = deepcopy(default_effects)
            end,
            showAlert = 1,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1
        }
        StaticPopup_Show("ROTATIONMASTER_RESET_EFFECTS")
    end
end

local function upgradePetSpellToAnySpell()
    if addon.db.profile.version == nil or addon.db.profile.version < 1 then
        updateRotationData(function(rot)
            if rot.type ~= nil and rot.type == BOOKTYPE_PET then
                rot.type = "any"
            end
        end, function(cond)
            if cond.type == "PETSPELL_AVAIL" then
                cond.type = "ANYSPELL_AVAIL"
            elseif cond.type == "PETSPELL_RANGE" then
                cond.type = "ANYSPELL_RANGE"
            elseif cond.type == "PETSPELL_COOLDOWN" then
                cond.type = "ANYSPELL_COOLDOWN"
            elseif cond.type == "PETSPELL_REMAIN" then
                cond.type = "ANYSPELL_REMAIN"
            elseif cond.type == "PETSPELL_CHARGES" then
                cond.type = "ANYSPELL_CHARGES"
            end
        end)
    end
end

local function upgradeRuneTypes()
    updateRotationData(nil, function(cond)
        if cond.type == "RUNE" or cond.type == "RUNE_COOLDOWN" then
            if cond.rune == "BLOOD" then
                cond.rune = 1
            elseif cond.rune == "FROST" then
                cond.rune = 2
            elseif cond.rune == "UNHOLY" then
                cond.rune = 3
            elseif cond.rune == "DEATH" then
                cond.rune = 4
            end
        end
    end)
end

local function upgradeBindingSlots()
    -- Upgrade the exact store AceDB opened; folder casing is not persistence identity.
    local DB = addon.db.sv
    if DB.char then
        for _,char in pairs(DB.char) do
            if char.bindings then
                for id,val in pairs(char.bindings) do
                    if type(val) == "number" then
                        char.bindings[id] = { val }
                    end
                end
            end
        end
    end
end

function addon:getDefaultItemset(id)
    if default_itemsets[id] ~= nil then
        return default_itemsets[id].items
    end
end

local function moveProfileItems()
    if addon.InitializeScopedRotationStorage or addon.db.profile.rotationStore~=nil then
        -- Rotation ownership migration never chooses a different profile or
        -- consumes char archives. Keep the unrelated old settings migration
        -- narrow: only an empty active-profile destination may receive data.
        for _,kind in ipairs({'itemsets','announces'}) do
            local source=addon.db.char[kind]
            if source~=nil and (type(source)~='table' or getmetatable(source)~=nil or next(source)~=nil) then
                local destination=addon.db.profile[kind]
                local copied=addon.RotationData.CopyData(source)
                if type(copied)=='table' and (destination==nil or type(destination)=='table' and next(destination)==nil) then
                    addon.db.profile[kind]=copied;addon.db.char[kind]=nil
                elseif addon.warn then
                    addon:warn(L['Legacy character %s data conflicts with the active profile; character data preserved.'],kind)
                end
            end
        end
        return
    end
    if not addon.db.profile.version or addon.db.profile.version < 2 then
        local rotations = addon.db.char.rotations
        addon.db.char.rotations = nil
        local itemsets = addon.db.char.itemsets
        addon.db.char.itemsets = nil
        local announces = addon.db.char.announces
        addon.db.char.announces = nil

        local notempty = ((rotations and next(rotations) ~= nil) or
                          (itemsets and next(itemsets) ~= nil) or
                          (announces and next(announces) ~= nil))

        if addon.db:GetCurrentProfile() == DEFAULT then
            addon.db:SetProfile(classKey)
            local modified = ((addon.db.profile.rotations and next(addon.db.profile.rotations) ~= nil) or
                              (addon.db.profile.itemsets and next(addon.db.profile.itemsets) ~= nil) or
                              (addon.db.profile.announces and next(addon.db.profile.announces) ~= nil))

            if modified then
                if notempty then
                    addon.db:SetProfile(UnitName("player") .. " - " .. GetRealmName())
                    addon.db:CopyProfile(DEFAULT, true)
                end
            else
                addon.db:CopyProfile(DEFAULT, true)
            end
        end

        if rotations and next(rotations) ~= nil then
            addon.db.profile.rotations = rotations
        end

        if itemsets and next(itemsets) ~= nil then
            addon.db.profile.itemsets = itemsets
        end

        if announces and next(announces) ~= nil then
            addon.db.profile.announces = announces
        end
    end
end

function addon:augmentDefaults(defaults)
    defaults.char.version = CHAR_VERSION

    defaults.global.itemsets = deepcopy(default_itemsets)
    defaults.global.effects = deepcopy(default_effects)
    defaults.global.version = GLOBAL_VERSION

    defaults.profile.condition_groups = deepcopy(default_condition_groups)
    defaults.profile.switch_conditions = deepcopy(default_switch_conditions)
    defaults.profile.other_conditions_order = deepcopy(default_other_conditions_order)
    defaults.profile.disabled_conditions = deepcopy(default_disabled_conditions)
    defaults.profile.version = PROFILE_VERSION
end

-- Keep indexed AceDB defaults stable: extending them recursively fills numeric
-- holes in existing customized/reordered lists. Seed new predicates only when
-- a profile is created or explicitly reset; copying a profile keeps its lists.
function addon:InitializeTalentTreeConditions(_,db)
    local profile=db.profile
    local function append(list)
        for _,tag in ipairs({'TALENT_TREE_POINTS','PRIMARY_TALENT_TREE'}) do
            if not addon.Functions.values.isin(list,tag) then list[#list+1]=tag end
        end
    end
    append(profile.switch_conditions)
    for _,category in ipairs(profile.condition_groups) do
        if category.id=='b8136123-2bda-4230-a77a-89ea2aed3a1a' then append(category.conditions)
        elseif category.id=='8034819e-26f5-4f4e-9153-d8cab5e65f31' and not addon.Functions.values.isin(category.conditions,'SPELL_AUTOREPEAT') then
            category.conditions[#category.conditions+1]='SPELL_AUTOREPEAT'
        end
    end
end

function addon:init()
    self.db.RegisterCallback(self,'OnNewProfile','InitializeTalentTreeConditions')
    self.db.RegisterCallback(self,'OnProfileReset','InitializeTalentTreeConditions')
    moveProfileItems()

    for k,v in pairs(default_itemsets) do
        if addon.db.global.itemsets[k] ~= nil and not addon.db.global.itemsets[k].modified then
            addon.db.global.itemsets[k].items = deepcopy(v.items)
        end
    end

    upgradeTexturesToEffects()
    upgradeGlobalRotationstoPlayer()
    upgradeItemsToItemSets()
    cacheItems()
    upgradeAddIDToAnnounce()
    upgradeLogLevel()
    upgradeEffectsToGUID()
    upgradePetSpellToAnySpell()
    upgradeRuneTypes()
    upgradeBindingSlots()

    addon.db.char.version = CHAR_VERSION
    if addon.db.profile.rotationStore~=nil then addon.db.profile.version=3
    elseif not addon.InitializeScopedRotationStorage then addon.db.profile.version=PROFILE_VERSION end
    addon.db.global.version = GLOBAL_VERSION
end

]====],
    ["validate.lua"] = [====[local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

local function mark_for_remove(toremove, key)
    if type(key) ~= "number" or key < 1 then
        toremove.not_array = true
    end
    if not toremove.data then
        toremove.data = {}
    end
    table.insert(toremove.data, key)
end

local function apply_remove(toremove, tbl, fix)
    if fix and toremove.data then
        if toremove.not_array then
            for _, key in pairs(toremove.data) do
                tbl[key] = nil
            end
        else
            local offs = 0
            for idx=1,#toremove.data do
                table.remove(tbl, toremove.data[idx] - offs)
                offs = offs + 1
            end
        end
    end

    addon.Functions.collections.cleanArray(toremove)
end

local function validate_basic(prefix, data, template, fix, preserved)
    local toremove = {}
    for k,v in pairs(data) do
        if preserved and preserved[k] then
            -- Semantic source metadata has its own non-destructive validator.
        elseif template[k] == nil then
            addon:warn("Extra Field %s:%s", prefix, tostring(k))
            mark_for_remove(toremove, k)
        elseif type(v) ~= type(template[k]) then
            addon:warn("Incorrect type for %s:%s (was %s, expected %s)", prefix, tostring(k), type(v), type(template[k]))
            mark_for_remove(toremove, k)
        elseif type(v) == "table" then
            if addon.Functions.collections.tablelength(template[k]) > 0 and #template[k] == 0 then
                validate_basic(prefix .. ":" .. k, v, template[k], fix)
            end
        end
    end
    apply_remove(toremove, data, fix)
end

local function validate_itemset_items(prefix, name, items, fix)
    local toremove = {}
    for idx, item in pairs(items) do
        if type(item) ~= "string" and type(item) ~= "number" then
            addon:warn("Invalid item in itemset %s:%s", prefix, name)
            mark_for_remove(toremove, idx)
        end
    end
    apply_remove(toremove, items, fix)
end

local function is_uuid(uuid)
    return type(uuid) == "string" and uuid:match("(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)") ~= nil
end

function addon:validate_itemset(prefix, name, itemset, fix)
    if not is_uuid(name) then
        addon:warn("Invalid ID for itemset %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(itemset)
            return
        end
    end
    local template = {
        modified = false,
        name = "test",
        items = {}
    }
    validate_basic(prefix .. ":" .. name, itemset, template, fix)
    validate_itemset_items(prefix, name, itemset.items, fix)
end

function addon:validate_effect(prefix, name, effect, fix)
    if not is_uuid(name) then
        addon:warn("Invalid ID for effect %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(effect)
            return
        end
    end
    if not effect["type"] then
        addon:warn("No effect type for %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(effect)
        end
        return
    end

    local function get_effect_template(type)
        if type == "texture" then
            return {
                texture = "some_texture"
            }
        elseif type == "pixel" then
            return {
                lines = 8,
                frequency = 0.25,
                length = 2,
                thickness = 2
            }
        elseif type == "autocast" then
            return {
                particles = 4,
                frequency = 0.25,
                scale = 1.0
            }
        elseif type == "proc" then
            return {duration=1,startAnim=false}
        elseif type == "blizzard" then
            return {
                frequency = 0.125
            }
        elseif type == "dazzle" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "animate" then
            return {
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "pulse" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "custom" then
            return {
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "rotate" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                steps = 4,
                reverse = false
            }
        end
    end

    local template = get_effect_template(effect["type"])
    if not template then
        addon:warn(L["Unknown effect type for %s:%s (%s); record preserved."], prefix, name, tostring(effect.type))
        return
    end
    if template.texture~=nil and type(effect.texture)=="number" then template.texture=1 end
    template["type"] = "texture"
    template["name"] = "some name"
    validate_basic(prefix .. ":" .. name, effect, template, fix)

    if effect["sequence"] then
        local toremove = {}
        for idx, seq in pairs(effect["sequence"]) do
            if effect["type"] == "dazzle" then
                if type(seq) == "table" then
                    local template = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
                    validate_basic(prefix .. ":" .. name .. ":" .. idx, seq, template, fix)
                else
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "animate" then
                if type(seq) ~= "string" and type(seq) ~= "number" then
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "pulse" then
                if type(seq) ~= "number" then
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "custom" then
                if type(seq) == "table" then
                    local template = {
                        texture = type(seq.texture)=="number" and 1 or "some_texture",
                        angle = 0.0,
                        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
                        magnification = 0.0,
                    }
                    validate_basic(prefix .. ":" .. name .. ":" .. idx, seq, template, fix)
                else
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            end
        end
        apply_remove(toremove, effect["sequence"], fix)
    end
end

function addon:validate_announce(prefix, idx, announce, fix)
    if not announce["type"] then
        addon:warn("No announce type for %s:%s", prefix, idx)
        if fix then
            addon.Functions.collections.cleanArray(announce)
        end
        return
    end

    local template = {
        type = "spell",
        disabled = false,
        announce = "party",
        event = "SUCCEEDED",
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        name = "Announcement",
        value = "Some Announce",
        announce_sound = "Sound"
    }

    if announce["type"] == "spell" or announce["type"] == "petspell" or announce["type"] == "pet" then
        template["spell"] = 12345
        template["ranked"] = false
    elseif announce["type"] == "item" then
        template["item"] = {}
    else
        addon:warn("Invalid type for announce %s:%s", prefix, tostring(announce["id"]))
        if fix then
            addon.Functions.collections.cleanArray(announce)
            return
        end
    end

    validate_basic(prefix, announce, template, fix, announce.type=="item" and {item=true} or nil)

    if not announce["id"] or not is_uuid(announce["id"]) then
        addon:warn("Invalid ID for announce %s:%s", prefix, tostring(announce["id"]))
        if fix then
            addon.Functions.collections.cleanArray(announce)
            return
        end
    end

    if announce.type=="item" and not addon:IsValidAnnouncementItemReference(announce.item) then
        local message=fix and L["Invalid item reference for announce %s:%s; reference preserved; announcement disabled."]
            or L["Invalid item reference for announce %s:%s; explicit repair will preserve the reference and disable the announcement."]
        addon:warn(message, prefix, tostring(announce.id))
        if fix then announce.disabled=true end
    end
end

function addon:validate_condition_group(prefix, idx, group, fix)
    local template = {
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        name = "Some Group",
        conditions = {},
        icon = type(group.icon)=="number" and 1 or "Interface\\Icons\\INV_Misc_Book_09"
    }

    validate_basic(prefix .. ":" .. idx, group, template, fix)
    if group.icon~=nil and not (type(group.icon)=="string" and #group.icon>0 and #group.icon<=1024 or type(group.icon)=="number" and group.icon>0 and group.icon<math.huge and group.icon%1==0) then
        addon:warn("Invalid category icon %s:%s",prefix,tostring(idx));if fix then group.icon=nil end
    end
end

function addon:validate_custom_condition(prefix, name, custom_condition, fix)
    local semantic={fields=true,icon=true,disabled=true,fieldOrder=true,bindings=true,parameters=true,requiredFields=true}
    local template={disabled=false,fieldOrder={},bindings={},parameters={},requiredFields={}}
    for key,value in pairs(addon.empty_condition) do template[key]=value end
    validate_basic(prefix .. ":" .. name, custom_condition, template, fix, semantic)

    local function invalid(field,reason)
        local message=fix and L["Invalid custom condition %s:%s field %s (%s); source preserved; condition disabled."]
            or L["Invalid custom condition %s:%s field %s (%s); explicit repair will preserve source and disable the condition."]
        addon:warn(message, prefix, name, field, reason or "invalid-data")
        if fix then
            custom_condition.disabled=true
            local saved=addon.db and addon.db.global and addon.db.global.custom_conditions
            local definition=addon.conditionDefinitions and addon.conditionDefinitions[name]
            if type(saved)=="table" and saved[name]==custom_condition and definition and definition.customCode==true and definition.disabled~=true then
                -- Do not invoke lifecycle hooks or recompile user source from
                -- repair. Selection notices this registry version next pass.
                definition.disabled=true
                addon.conditionRegistryVersion=(addon.conditionRegistryVersion or 0)+1
            end
        end
    end
    -- Check data contracts only. Repair must not compile callback text, resolve
    -- currently unavailable helper bindings, or execute registration hooks.
    local fields,fieldReason=addon:NormalizeCustomFieldSchema(custom_condition.fields,true)
    if not fields then invalid("fields",fieldReason) end
    if not addon:IsCategoryIcon(custom_condition.icon) then invalid("icon","invalid-icon") end
    if custom_condition.disabled~=nil and type(custom_condition.disabled)~="boolean" then invalid("disabled","invalid-disabled-flag") end
    local parameters,parameterReason=addon:NormalizeCustomConditionParameters(custom_condition.parameters)
    if not parameters then invalid("parameters",parameterReason) end
    if custom_condition.bindings~=nil then
        local arguments={{name="value"},{name="cache"},{name="evalStart"},{name="spec"},{name="parent"},{name="frame"},{name="tag"}}
        for _,aliases in pairs(parameters or {}) do for _,alias in ipairs(aliases) do arguments[#arguments+1]={name=alias} end end
        local bindings,reason=addon:NormalizeFunctionBindings(custom_condition.bindings,arguments)
        if not bindings then invalid("bindings",reason) end
    end
    if custom_condition.requiredFields~=nil and not addon:NormalizeCustomConditionRequiredFields(custom_condition.requiredFields,fields or {}) then invalid("requiredFields","invalid-required-fields") end
    if custom_condition.fieldOrder~=nil and not addon:NormalizeCustomFieldOrder(custom_condition.fieldOrder,fields or {}) then invalid("fieldOrder","invalid-field-order") end
end

local function validate_rotation_condition(prefix, condition, fix)
    if addon.Functions.collections.tablelength(condition) == 0 then
        return
    end

    if type(condition["type"]) ~= "string" then
        addon:warn("Invalid type for %s", prefix)
        if fix then
            addon.Functions.collections.cleanArray(condition)
        end
        return
    end

    local full_id = prefix .. ":" .. condition["type"]
    local fields = addon.Functions.collections.deepcopy(select(4, addon:describeCondition(condition["type"])))
    -- The condition might not exist if you're not playing a class where it is active.
    if not fields then
        return
    end
    fields["type"] = "string"
    fields["disabled"] = "boolean"
    if condition.type=="AND" or condition.type=="OR" or condition.type=="NOT" then fields.name="string" end

    local function handle_array_field(cond, field)
        if type(cond) == "table" then
            for i=1,#field do
                if type(field[i]) == "table" then
                    local allfound = true
                    for j=1,#cond do
                        local subfound = handle_array_field(cond[j], field[i])
                        if not subfound then
                            allfound = false
                            break
                        end
                    end
                    if allfound then
                        return true
                    end
                end
            end
        else
            for i=1,#field do
                if type(field[i]) ~= "table" and type(cond) == field[i] then
                    return true
                end
            end
        end
        return false
    end

    local function handle_fields(cond, f, subtree)
        local keyremove = {}
        for key, data in pairs(cond) do
            local newsubtree = (subtree and (subtree .. ".") or "") .. key
            local field = f[key]
            if field == nil then
                addon:warn("Extra Field %s.%s", full_id, newsubtree)
                mark_for_remove(keyremove, key)
            elseif type(field) == "table" then
                -- The #field specifies this is an array, specifically.
                if #field > 0 then
                    local found = handle_array_field(data, field)
                    if not found then
                        addon:warn("Condition %s.%s has data of the wrong type (got %s)", full_id, newsubtree, type(data))
                        if fix then
                            mark_for_remove(keyremove, key)
                        end
                    end
                elseif type(data) == "table" then
                    handle_fields(data, field, newsubtree)
                else
                    addon:warn("Condition %s.%s has data of the wrong type (got %s)", full_id, newsubtree, type(data))
                    mark_for_remove(keyremove, key)
                end
            elseif field == "condition" then
                validate_rotation_condition(full_id, data, fix)
            elseif type(field) == "string" and type(data) == "table" then
                if addon.Functions.collections.tablelength(data) ~= #data then
                    addon:warn("Condition %s.%s provides a table where an array is required", full_id, subtree)
                    mark_for_remove(keyremove, key)
                elseif #data > 0 then
                    local basetype = field:match("^(.*)%[%]$")
                    if basetype == "condition" then
                        local toremove = {}
                        for i=1,#data do
                            if type(data[i]) == "table" then
                                validate_rotation_condition(full_id .. "[" .. i .. "]", data[i], fix)
                            else
                                addon:warn("Condition %s.%s[%d] has data of the wrong type (expected %s, got %s)", full_id, newsubtree, i, "table", type(data[i]))
                                mark_for_remove(toremove, i)
                            end
                        end
                        apply_remove(toremove, data, fix)
                    elseif basetype then
                        local toremove = {}
                        for i=1,#data do
                            if type(data[i]) ~= basetype then
                                addon:warn("Condition %s.%s[%d] has data of the wrong type (expected %s, got %s)", full_id, newsubtree, i, basetype, type(data[i]))
                                mark_for_remove(toremove, i)
                            end
                        end
                        apply_remove(toremove, data, fix)
                    else
                        addon:error("Unknown field type used in field spec for array on %s:%s", full_id, newsubtree)
                    end
                end
            elseif type(data) ~= field then
                addon:warn("Condition %s.%s has data of the wrong type (expected %s, got %s)", full_id, newsubtree, field, type(data))
                mark_for_remove(keyremove, key)
            end
        end
        apply_remove(keyremove, cond, fix)
    end

    handle_fields(condition, fields)
end

function addon:validate_rotation(prefix, id, rotation, fix)
    if type(rotation)=='table' and rotation.priority~=nil and not self.RotationData.GetRotationPriority(rotation.priority) then
        self:warn(L['Invalid switch priority for %s:%s; explicit repair resets it to zero.'],prefix,id)
        if fix then rotation.priority=nil end
    end
    -- The old template fixer knows only flat actions. Use the non-destructive
    -- schema for branch bodies; never strip their arms or future metadata.
    if type(rotation)=="table" and type(rotation.rotation)=="table" then
        for _,step in pairs(rotation.rotation) do
            if type(step)=="table" and step.type=="branch" then
                local settings=self.GetImportValidationOptions and self:GetImportValidationOptions() or {conditions=self.conditionDefinitions}
                local result=self.RotationData.ValidateBody(rotation,settings)
                for _,diagnostic in ipairs(result.diagnostics) do self:warn("%s:%s %s",prefix,id,diagnostic.code.." "..diagnostic.path) end
                return
            end
        end
    end
    if id ~= DEFAULT and not is_uuid(id) then
        addon:warn("Invalid ID for rotation %s:%s", prefix, id)
        if fix then
            addon.Functions.collections.cleanArray(rotation)
            return
        end
    end

    local template = {
        name = "Some Name",
        description = "Rotation description",
        metadata = {},
        tags = {},
        priority = 0,
        disabled = false,
        switch = {},
        cooldowns = {},
        rotation = {}
    }
    validate_basic(prefix .. ":" .. id, rotation, template, fix)

    if id ~= DEFAULT and not rotation["name"] then
        addon:warn("Unnamed non-default rotation %s:%s", prefix, id)
        if fix then
            addon.Functions.collections.cleanArray(rotation)
            return
        end
    end

    -- Normal actions and cooldown actions share the persisted appearance
    -- schema. These examples validate types; they never materialize defaults.
    local rotation_template = {
        use_name = false,
        name = "Some cool name",
        effect = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        type = "spell",
        ranked = false,
        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        magnification = 1.4,
        setpoint = "CENTER",
        xoffs = 0.0,
        yoffs = 0.0,
        announce = "None",
        announce_sound = "LoudSound",
        disabled = false,
        conditions = {},
    }
    local cooldown_template = addon.Functions.collections.deepcopy(rotation_template)

    local function augment_template_type(template, rot)
        if rot.type=="none" then template.suppress_attack=false end
        if rot.type=="spell" or rot.type=="pet" or rot.type=="any" or rot.type=="petspell" or rot.type=="anyspell" then
            template["action"] = 1234
        elseif rot["type"] == "item" then
            if type(rot["action"]) == "table" then
                template["action"] = {}
            else
                template["action"] = "61b36ed1-fa31-4656-ad71-f3d50f193a85"
            end
        end
    end

    if rotation["cooldowns"] then
        local toremove = {}
        for idx, rot in pairs(rotation["cooldowns"]) do
            local template = addon.Functions.collections.deepcopy(cooldown_template)
            augment_template_type(template, rot)
            validate_basic(prefix .. ":" .. id .. ":cooldown:" .. idx, rot, template, fix)
            if not is_uuid(rot["id"]) then
                addon:warn("Invalid ID for cooldown %s:%s:%d", prefix, id, idx)
                mark_for_remove(toremove, idx)
            end
            if rot["effect"] and not is_uuid(rot["effect"]) then
                addon:warn("Invalid effect ID for cooldown %s:%s:%d", prefix, id, idx)
                if fix then
                    rot["effect"] = nil
                end
            end
            if rot["type"] == "item" then
                if type(rot["action"]) == "table" then
                    validate_itemset_items(prefix .. ":" .. id .. ":cooldown", idx, rot["action"], fix)
                elseif type(rot["action"]) ~= "string" then
                    addon:warn("Invalid type for item action in cooldown %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                elseif not is_uuid(rot["action"]) then
                    addon:warn("Invalid itemset ID for cooldown %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                end
            end
            if rot["conditions"] then
                validate_rotation_condition( string.format("%s:%s:cooldowns:%d", prefix, id, idx),
                        rot["conditions"], fix)
            end
            if addon.Functions.collections.tablelength(rot) == 0 then
                mark_for_remove(toremove, idx)
            end
        end
        apply_remove(toremove, rotation["cooldowns"], fix)
    end

    if rotation["rotation"] then
        local toremove = {}
        for idx, rot in pairs(rotation["rotation"]) do
            local template = addon.Functions.collections.deepcopy(rotation_template)
            augment_template_type(template, rot)
            validate_basic(prefix .. ":" .. id .. ":rotation:" .. idx, rot, template, fix)
            if not is_uuid(rot["id"]) then
                addon:warn("Invalid ID for rotation step %s:%s:%d", prefix, id, idx)
                mark_for_remove(toremove, idx)
            end
            if rot.effect and not is_uuid(rot.effect) then
                addon:warn(L["Invalid effect ID for rotation step %s:%s:%d."], prefix, id, idx)
                if fix then rot.effect=nil end
            end
            if rot["type"] == "item" then
                if type(rot["action"]) == "table" then
                    validate_itemset_items(prefix .. ":" .. id .. ":rotation", idx, rot["action"], fix)
                elseif type(rot["action"]) ~= "string" then
                    addon:warn("Invalid type for item action in rotation %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                elseif not is_uuid(rot["action"]) then
                    addon:warn("Invalid itemset ID for rotation %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                end
            end
            if rot["conditions"] then
                validate_rotation_condition( string.format("%s:%s:rotation:%d", prefix, id, idx),
                        rot["conditions"], fix)
            end
            if addon.Functions.collections.tablelength(rot) == 0 then
                mark_for_remove(toremove, idx)
            end
        end
        apply_remove(toremove, rotation["rotation"], fix)
    end

    if rotation["switch"] then
        validate_rotation_condition( string.format("%s:%s:switch", prefix, id),
                rotation["switch"], fix)
    end
end

function addon:validate(template, fix)
    local DB = _G[self.savedVariableName or "RotationMasterDB"]

    local glob_template = addon.Functions.collections.deepcopy(template.global)
    glob_template.itemsets = {}
    glob_template.effects = {}
    validate_basic("global", DB.global, glob_template, fix)

    if DB.global.itemsets then
        local toremove = {}
        for name, itemset in pairs(DB.global.itemsets) do
            addon:validate_itemset("global", name, itemset, fix)
            if addon.Functions.collections.tablelength(itemset) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.itemsets, fix)
    end

    if DB.global.effects then
        local toremove = {}
        for name, effect in pairs(DB.global.effects) do
            addon:validate_effect("global", name, effect, fix)
            if addon.Functions.collections.tablelength(effect) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.effects, fix)
    end

    if DB.global.custom_conditions then
        local toremove = {}
        for name, custom_condition in pairs(DB.global.custom_conditions) do
            addon:validate_custom_condition("global", name, custom_condition, fix)
            if addon.Functions.collections.tablelength(custom_condition) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.custom_conditions, fix)
    end

    -- Offline characters can still own their v1 data until their explicit
    -- login migration. Recognize these roots without moving or inspecting them.
    local char_template=addon.Functions.collections.deepcopy(template.char)
    char_template.rotations={}
    char_template.itemsets={}
    char_template.announces={}
    for char, data in pairs(DB.char) do
        validate_basic("char:" .. char, data, char_template, fix)
        if data.bindings then
            local toremove = {}
            for id,buttons in pairs(data.bindings) do
                if not is_uuid(id) then
                    addon:warn("Binding for invalid itemset %s", id)
                    if fix then
                        mark_for_remove(toremove, id)
                    end
                end

                local i = 1
                while i <= #buttons do
                    if type(buttons[i]) ~= "number" then
                        addon:warn("Invalid button ID in button bindings %s:%s", char, id)
                        if fix then
                            table.remove(buttons, i)
                        else
                            i = i + 1
                        end
                    else
                        i = i + 1
                    end
                end
                if #buttons == 0 then
                    mark_for_remove(toremove, id)
                end
            end
            apply_remove(toremove, data.bindings, fix)
        end
    end

    -- These optional library-owned values are recognized schema, not defaults:
    -- their absence preserves LibDBIcon's own placement and interaction policy.
    local profile_template=addon.Functions.collections.deepcopy(template.profile)
    if type(profile_template.minimap)=="table" then
        profile_template.minimap=addon.Functions.collections.deepcopy(profile_template.minimap)
        profile_template.minimap.minimapPos=0
        profile_template.minimap.radius=0
        profile_template.minimap.lock=false
        profile_template.minimap.showInCompartment=false
    end
    for profile, data in pairs(DB.profiles) do
        -- Ownership archives must never be removed by the legacy shape repair.
        -- Their pure schema is validated independently, without guessing owners
        -- or mutating a future/invalid format that may need explicit recovery.
        validate_basic("profile:" .. profile, data, profile_template, fix,{stockTargets=true,rotationStore=true,rotationFallbackID=true,rotations=addon.InitializeScopedRotationStorage~=nil,rotationLibrary=addon.InitializeScopedRotationStorage~=nil})
        local stockTargets=rawget(data,'stockTargets')
        if stockTargets~=nil then
            local ok,why=addon.StockTargets.Validate(stockTargets)
            if not ok then addon:warn(L['Invalid stock targets in profile %s (%s); data preserved.'],profile,why) end
        end
        local fallback=data.rotationFallbackID
        if (data.rotationStore~=nil or fallback~=nil) and (type(fallback)~='string' or #fallback==0 or #fallback>128 or not fallback:find('%S') or fallback:find('[%z\1-\31\127]')) then
            addon:warn(L['Invalid rotation fallback configuration in profile %s; data preserved.'],profile)
        end
        if data.rotationStore~=nil then
            local ok,why=addon.RotationData.ValidateRotationStore(data.rotationStore)
            if not ok then addon:warn(L["Invalid rotation ownership data in profile %s (%s); record preserved."],profile,tostring(why)) end
        end
        if type(data.minimap)=="table" then
            for _,key in ipairs({"minimapPos","radius"}) do
                local value=data.minimap[key]
                if type(value)=="number" and (value~=value or value==math.huge or value==-math.huge) then
                    addon:warn(L["Non-finite minimap value in profile %s: %s."], profile, key)
                    if fix then data.minimap[key]=nil end
                end
            end
        end

        if data.itemsets then
            local toremove = {}
            for name, itemset in pairs(data.itemsets) do
                addon:validate_itemset("profile:" .. profile, name, itemset, fix)
                if addon.Functions.collections.tablelength(itemset) == 0 then
                    mark_for_remove(toremove, name)
                end
            end
            apply_remove(toremove, data.itemsets, fix)
        end

        if data.announces then
            local toremove = {}
            for idx, announce in pairs(data.announces) do
                addon:validate_announce("profile:" .. profile, idx, announce, fix)
                if addon.Functions.collections.tablelength(announce) == 0 then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.announces, fix)
        end

        if data.rotations and not addon.InitializeScopedRotationStorage then
            local specremove = {}
            for spec, rotations in pairs(data.rotations) do
                if type(spec) ~= "number" then
                    table.insert(specremove, spec)
                end
                local toremove = {}
                for id, rotation in pairs(rotations) do
                    addon:validate_rotation("profile:" .. profile .. ":" .. spec, id, rotation, fix)
                    if addon.Functions.collections.tablelength(rotation) == 0 then
                        mark_for_remove(toremove, id)
                    end
                end
                apply_remove(toremove, rotations, fix)
            end
            if fix then
                for _, key in pairs(specremove) do
                    data.rotations[key] = nil
                end
            end
        end

        if data.condition_groups then
            local toremove = {}
            for idx,group in pairs(data.condition_groups) do
                if type(idx) ~= "number" then
                    mark_for_remove(toremove, idx)
                end
                addon:validate_condition_group("profile:" .. profile, idx, group, fix)
                if addon.Functions.collections.tablelength(group) == 0 then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.condition_groups, fix)
        end

        local toremove = {}
        if data.switch_conditions then
            for idx,cond in pairs(data.switch_conditions) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.switch_conditions, fix)
        end

        if data.other_conditions_order then
            for idx,cond in pairs(data.other_conditions_order) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.other_conditions_order, fix)
        end

        if data.disabled_conditions then
            for idx,cond in pairs(data.disabled_conditions) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.disabled_conditions, fix)
        end
    end
end
]====],
    ["tests/fixtures/addon.lua"] = [====[-- Explicit external boundaries; production constants/utilities/help stay real.
local F = {}
function F.new(product, expansion, class)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.WOW_PROJECT_MAINLINE, env.WOW_PROJECT_CLASSIC = 1, 2
    env.WOW_PROJECT_BURNING_CRUSADE_CLASSIC,env.WOW_PROJECT_MISTS_CLASSIC=5,19
    env.WOW_PROJECT_WRATH_CLASSIC,env.WOW_PROJECT_CATACLYSM_CLASSIC,env.WOW_PROJECT_CAMELOT=11,14,18
    env.WOW_PROJECT_ID, env.LE_EXPANSION_LEVEL_CURRENT = product or 5, expansion or 1
    env.NORMAL_FONT_COLOR_CODE, env.DEFAULT, env.DELETE, env.NAME = '', 'Default', 'Delete', 'Name'
    env.PRIMARY, env.SECONDARY = 'Primary', 'Secondary'
    env.EDIT, env.COMBAT, env.HEALTH, env.MANA = 'Edit', 'Combat', 'Health', 'Mana'
    env.Enum = {PowerType = {Mana=0, Rage=1, Energy=3, Balance=26, Runes=5, SoulShards=7, Chi=12, ArcaneCharges=16, ComboPoints=4}}
    env.UnitClass = function() return class or 'Shaman', class or 'SHAMAN' end
    env.GetTime = function() return 100 end
    local addon = {help_funcs = {}, longtermCache = {}, unitsInRange = {}, currentSpec = 0,
                   db = {profile = {}, global = {}}, definitions = {}}
    local translations = {}
    local L = setmetatable({}, {
        __index = function(_, key) return translations[key] or key end,
        __newindex = function(_, key, value) translations[key] = value == true and key or value end,
    })
    local function widget(kind)
        local w = {kind=kind, children={}}
        function w:AddChild(child) assert(child); self.children[#self.children+1]=child end
        function w:SetText(text) self.text=text end
        function w:SetLayout(layout) self.layout=layout end
        function w:SetFullWidth(value) self.fullWidth=value end
        function w:SetFullHeight(value) self.fullHeight=value end
        function w:SetUserData(key,value) self[key]=value end
        function w:GetUserData(key) return self[key] end
        function w:SetLabel(value) self.label=value end
        function w:SetTitle(value) self.title=value end
        function w:SetValue(value) self.value=value end
        function w:SetIsPercent(value) self.isPercent=value end
        function w:SetSliderValues(minimum,maximum,step) self.sliderValues={minimum,maximum,step} end
        function w:SetDisabled(value) self.disabled=value end
        function w:SetStatusText(value) self.statusText=value end
        function w:SetCallback(event,callback) self.callbacks=self.callbacks or {};self.callbacks[event]=callback end
        function w:SetImage(value) self.image=value end
        function w:SetImageSize(width,height) self.imageWidth,self.imageHeight=width,height end
        function w:SetHeight(value) self.height=value end
        function w:SetWidth(value) self.width=value end
        function w:SetFont(...) self.font={...} end
        function w:SetFontObject(value) self.font=value end
        return w
    end
    local libraries = {
        ['AceLocale-3.0'] = {GetLocale=function() return L end, NewLocale=function() return L end},
        ['AceConsole-3.0'] = {}, ['LibCompress'] = {},
        ['LibClassicDurations'] = {},
        ['LibRangeCheck-3.0'] = {},
    }
    env.LibStub = function(name) return assert(libraries[name], 'Unexpected library '..name) end
    function addon:RegisterCondition(tag, definition) self.definitions[tag]=definition end
    local function load(path)
        local chunk=assert(loadfile(path)); setfenv(chunk, env); return chunk('rotationmaster',addon)
    end
    dofile('tests/fixtures/native_ui.lua')(env)
    load('globals.lua');load('Platform/client.lua');load('Platform/rotation_owner.lua');load('Platform/groups.lua');load('Platform/roster_class.lua');load('Platform/role.lua');load('Platform/mobinfo2.lua');load('Platform/casting.lua');load('Platform/unit_health.lua');load('Platform/unit_stat.lua');load('Platform/health_forecast.lua');load('Platform/unit_level.lua');load('Platform/unit_power.lua');load('Platform/player_movement.lua');load('Platform/unit_attackability.lua');load('Platform/unit_flags.lua');load('Platform/player_flags.lua');load('Platform/form.lua');load('Platform/points.lua');load('Platform/runes.lua');load('Platform/unit_identity.lua');load('Platform/unit_metadata.lua');load('Platform/creature_type.lua');load('Platform/unit_presence.lua');load('Platform/pet.lua');load('Platform/threat.lua');load('Platform/instance.lua');load('Platform/zone_pvp.lua');load('Platform/loss_of_control.lua');load('Platform/items.lua');load('Platform/glyphs.lua');load('Platform/specializations.lua')
    load('Locales/enUS.lua'); load('constants.lua');load('Data/artwork.lua');load('Functions/values.lua');load('Functions/presentation.lua');load('Functions/text.lua');load('Functions/collections.lua');load('Functions/cache.lua');load('Functions/trends.lua');load('Functions/forecast.lua'); load('utils.lua');load('Core/level_conditions.lua');load('Core/point_conditions.lua');load('Core/class_group_conditions.lua');load('Core/creature_conditions.lua');load('Core/health_forecast_conditions.lua');load('Core/threat_count_conditions.lua')
    load('UI/controls.lua');load('UI/condition_widgets.lua');load('UI/condition_observation.lua');load('UI/condition_icon.lua');load('UI/condition_position.lua');load('UI/condition_display.lua');load('UI/drag_presentation.lua');load('Core/unsaved_changes.lua');load('UI/unsaved.lua');load('Core/stock_targets.lua');load('UI/stock_profile_safety.lua');load('UI/settings_stock.lua');load('UI/settings_draft.lua');load('UI/collection_compare.lua');load('UI/draft_changes.lua');load('UI/draft_change_controls.lua');load('UI/window.lua');load('UI/selector.lua');load('UI/tag_picker.lua');load('UI/checkbox.lua');load('UI/condition_inputs.lua');load('UI/condition_layout.lua');load('UI/condition_table.lua');load('UI/condition_unit.lua');load('Core/item_conditions.lua');load('Core/rotation_references.lua');load('Help/common.lua'); load('Help/conditional.lua'); load('Core/presentation.lua');load('Core/condition_description.lua'); load('Core/spell_catalog.lua');load('Core/spell_search.lua');load('Core/reference_catalog.lua');load('Core/category_data.lua');load('Core/announcement_data.lua');load('Core/profile_data.lua');load('Core/collection_data.lua');load('Core/custom_condition_data.lua');load('Core/functions.lua');load('UI/spell_search.lua');load('UI/spell_icon.lua')
    return {env=env, addon=addon, load=load, widget=widget, translations=translations, libraries=libraries}
end
function F.text(widget)
    local parts={widget.text or ''}
    for _, child in ipairs(widget.children or {}) do parts[#parts+1]=F.text(child) end
    return table.concat(parts, '\n')
end
function F.suite()
    local failed,passed=0,0
    return function(name, body)
        local ok,err=pcall(body)
        if ok then passed=passed+1; print('PASS '..name)
        else failed=failed+1; print('FAIL '..name..': '..tostring(err)) end
    end, function() print(passed..' passed, '..failed..' failed'); os.exit(failed>0 and 1 or 0) end
end
return F
]====],
}

local patches = {
    ["Core/rotation_references.lua"] = {
        {
            old = [====[local _,addon=...
local observed,stamp
-- Trusted standard primitives at module load; changed live pointers disable reuse.
local proofPairs,proofRawget,proofRawequal,proofType,proofGetmetatable=pairs,rawget,rawequal,type,getmetatable
-- Lua5.1 accepts a stack level or function; the checker declares only levels.
]====],
            current = [====[local _,addon=...
local observed,stamp
local dependencyReader
local bindDependency=addon.BindRotationDependencyReader
if type(bindDependency)=='function' then
    bindDependency(addon,function(reader) if type(reader)=='function' then dependencyReader=reader end end)
    addon.BindRotationDependencyReader=nil
end
local dependencyIdentity=rawequal
local managed
-- Trusted standard primitives at module load; changed live pointers disable reuse.
local proofPairs,proofRawget,proofRawequal,proofType,proofGetmetatable=pairs,rawget,rawequal,type,getmetatable
-- Lua5.1 accepts a stack level or function; the checker declares only levels.
]====],
        },
        {
            old = [====[end
-- Observe identities without copying maps on the common unchanged path.
-- Normalized false markers keep malformed/NaN entries stable, as before.
local function observe(owner)
    local profile,global=owner.db.profile,owner.db.global
    local shared,personal=global.itemsets,profile.itemsets
    local conditions,effects=owner.conditionDefinitions,global.effects
]====],
            current = [====[end
-- Observe identities without copying maps on the common unchanged path.
-- Normalized false markers keep malformed/NaN entries stable, as before.
local function observeLegacy(owner)
    local profile,global=owner.db.profile,owner.db.global
    local shared,personal=global.itemsets,profile.itemsets
    local conditions,effects=owner.conditionDefinitions,global.effects
]====],
        },
        {
            old = [====[        effects=effectEntries,effectCount=effectCount}
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
]====],
            current = [====[        effects=effectEntries,effectCount=effectCount}
    stamp={}
end
-- Managed ownership does not require plain/default-free maps. AceDB may
-- materialize default metatables; contents change through explicit publication.
local function observe(owner)
    if not dependencyReader or not dependencyIdentity(owner,addon) then
        observeLegacy(owner);return observed,stamp
    end
    local epoch=dependencyReader(owner)
    local db=owner.db;local profile,global=db.profile,db.global
    local conditions,version=owner.conditionDefinitions,owner.conditionRegistryVersion or 0
    local shared,personal,effects=global.itemsets,profile.itemsets,global.effects
    if not managed or not dependencyIdentity(managed.epoch,epoch) or not dependencyIdentity(managed.db,db)
        or not dependencyIdentity(managed.profile,profile) or not dependencyIdentity(managed.global,global)
        or not dependencyIdentity(managed.conditions,conditions) or not dependencyIdentity(managed.shared,shared)
        or not dependencyIdentity(managed.personal,personal) or not dependencyIdentity(managed.effects,effects)
        or not dependencyIdentity(managed.version,version) then
        managed={epoch=epoch,db=db,profile=profile,global=global,conditions=conditions,
            shared=shared,personal=personal,effects=effects,version=version,stamp={}}
    end
    -- Public options copy actual source maps, never a retained private map.
    -- Capture this invocation's roots and generation before live iteration.
    return managed,managed.stamp
end
-- Internal authority checks need the current stamp, not detached public maps.
-- Keep checking every dependency at each call, including reentrant mutations.
function addon:GetRotationValidationStamp()
    local _,current=observe(self)
    return current
end
local ownedValidationStamp=addon.GetRotationValidationStamp
-- Even protected metatable metadata can disguise a callback. Only native
]====],
        },
        {
            old = [====[        and proofRawequal(proofRawget(proofEnvironment,'type'),proofType) and proofRawequal(proofRawget(proofEnvironment,'getmetatable'),proofGetmetatable)
        and proofRawequal(proofRawget(proofEnvironment,'getfenv'),proofGetfenv)
        and proofRawequal(proofGetfenv(ownedValidationStamp),proofEnvironment)
        and proofRawequal(proofGetfenv(observe),proofEnvironment) and proofRawequal(proofGetfenv(normalized),proofEnvironment)
        and proofRawequal(proofGetfenv(entries),proofEnvironment) and proofRawequal(proofGetfenv(sameEntries),proofEnvironment)
        and proofRawequal(proofGetfenv(validItemsets),proofEnvironment) and proofRawequal(proofGetfenv(sameItemsets),proofEnvironment)
        and proofRawequal(proofGetfenv(itemsetEntries),proofEnvironment)
]====],
            current = [====[        and proofRawequal(proofRawget(proofEnvironment,'type'),proofType) and proofRawequal(proofRawget(proofEnvironment,'getmetatable'),proofGetmetatable)
        and proofRawequal(proofRawget(proofEnvironment,'getfenv'),proofGetfenv)
        and proofRawequal(proofGetfenv(ownedValidationStamp),proofEnvironment)
        and proofRawequal(proofGetfenv(observe),proofEnvironment) and proofRawequal(proofGetfenv(observeLegacy),proofEnvironment) and proofRawequal(proofGetfenv(normalized),proofEnvironment)
        and proofRawequal(proofGetfenv(entries),proofEnvironment) and proofRawequal(proofGetfenv(sameEntries),proofEnvironment)
        and proofRawequal(proofGetfenv(validItemsets),proofEnvironment) and proofRawequal(proofGetfenv(sameItemsets),proofEnvironment)
        and proofRawequal(proofGetfenv(itemsetEntries),proofEnvironment)
]====],
        },
        {
            old = [====[        and proofRawequal(e,effects) and proofRawequal(v,version) and proofRawequal(l,state)
end
local function readValidationStamp(owner,method,entryMethod)
    local db,profile,global,conditions,shared,personal,effects,version,state
    -- A successful PRE proof closes the owned scan. POST checks raw layout
    -- again, without repeating globals that no permitted callback can change.
]====],
            current = [====[        and proofRawequal(e,effects) and proofRawequal(v,version) and proofRawequal(l,state)
end
local function readValidationStamp(owner,method,entryMethod)
    if dependencyReader and dependencyIdentity(owner,addon) then
        local value=method(owner);return value
    end
    local db,profile,global,conditions,shared,personal,effects,version,state
    -- A successful PRE proof closes the owned scan. POST checks raw layout
    -- again, without repeating globals that no permitted callback can change.
]====],
        },
        {
            old = [====[-- Dependency maps may carry AceDB defaults metatables. Observe their entries,
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
]====],
            current = [====[-- Dependency maps may carry AceDB defaults metatables. Observe their entries,
-- without copying/traversing definitions or writing into SavedVariables.
function addon:GetRotationValidationOptions()
    local snapshot,current=observe(self)
    -- Public maps remain fresh: consumers cannot poison private observations.
    local conditions=entries(snapshot.conditions)
    local itemsets
    if dependencyReader and dependencyIdentity(self,addon) then
        itemsets=itemsetEntries(snapshot.shared,snapshot.personal)
    else itemsets=entries(snapshot.itemsets) end
    local effects=entries(snapshot.effects)
    return {conditions=conditions,itemsets=itemsets,effects=effects},current
end

-- Legacy bodies have no envelope. Inspect their semantic condition edges too,
]====],
        },
    },
    ["Core/conditions.lua"] = {
        {
            old = [====[local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

]====],
            current = [====[local addon_name, addon = ...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

]====],
        },
        {
            old = [====[
local conditions = {}
addon.conditionDefinitions = conditions
local special = {}
addon.conditionSpecials = special
local quarantined = setmetatable({}, {__mode="k"})
]====],
            current = [====[
local conditions = {}
addon.conditionDefinitions = conditions
if invalidateDependencies then invalidateDependencies(addon,'condition',nil) end
local special = {}
addon.conditionSpecials = special
local quarantined = setmetatable({}, {__mode="k"})
]====],
        },
        {
            old = [====[    end
    conditions[tag] = array
    self.conditionRegistryVersion=(self.conditionRegistryVersion or 0)+1
    quarantined[array] = nil
    if not array.disabled and not array.functionUnavailable and array.on_register then
        array.on_register(tag)
]====],
            current = [====[    end
    conditions[tag] = array
    self.conditionRegistryVersion=(self.conditionRegistryVersion or 0)+1
    if invalidateDependencies then invalidateDependencies(addon,'condition',tag) end
    quarantined[array] = nil
    if not array.disabled and not array.functionUnavailable and array.on_register then
        array.on_register(tag)
]====],
        },
        {
            old = [====[    if conditions[tag] and not conditions[tag].disabled and not conditions[tag].functionUnavailable and not conditions[tag].functionSuspended and conditions[tag].on_unregister then
        conditions[tag].on_unregister(tag)
    end
    if conditions[tag]~=nil then self.conditionRegistryVersion=(self.conditionRegistryVersion or 0)+1 end
    conditions[tag] = nil
    if wasDisabled then self:RefreshConditionConsumers() end
end

]====],
            current = [====[    if conditions[tag] and not conditions[tag].disabled and not conditions[tag].functionUnavailable and not conditions[tag].functionSuspended and conditions[tag].on_unregister then
        conditions[tag].on_unregister(tag)
    end
    local removed=conditions[tag]~=nil
    if removed then self.conditionRegistryVersion=(self.conditionRegistryVersion or 0)+1 end
    conditions[tag] = nil
    if removed then if invalidateDependencies then invalidateDependencies(addon,'condition',tag) end end
    if wasDisabled then self:RefreshConditionConsumers() end
end

]====],
        },
    },
    ["Core/functions.lua"] = {
        {
            old = [====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local reserved={['and']=true,['break']=true,['do']=true,['else']=true,['elseif']=true,['end']=true,['false']=true,['for']=true,['function']=true,['if']=true,['in']=true,['local']=true,['nil']=true,['not']=true,['or']=true,['repeat']=true,['return']=true,['then']=true,['true']=true,['until']=true,['while']=true}
local function identifier(name)
]====],
            current = [====[local addon_name,addon=...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local reserved={['and']=true,['break']=true,['do']=true,['else']=true,['elseif']=true,['end']=true,['false']=true,['for']=true,['function']=true,['if']=true,['in']=true,['local']=true,['nil']=true,['not']=true,['or']=true,['repeat']=true,['return']=true,['then']=true,['true']=true,['until']=true,['while']=true}
local function identifier(name)
]====],
        },
        {
            old = [====[end
function addon:InitializeFunctionRegistry()
    self.functionRegistry=self:BuildFunctionRegistry(self.db.global.custom_functions or {}) or {};self.functionRegistryVersion=(self.functionRegistryVersion or 0)+1
end
function addon:FunctionAvailable(id,registry,active,depth,memo)
    registry=registry or self.functionRegistry;if not registry then self:InitializeFunctionRegistry();registry=self.functionRegistry end
]====],
            current = [====[end
function addon:InitializeFunctionRegistry()
    self.functionRegistry=self:BuildFunctionRegistry(self.db.global.custom_functions or {}) or {};self.functionRegistryVersion=(self.functionRegistryVersion or 0)+1
    if invalidateDependencies then invalidateDependencies(addon,'function',nil) end
end
function addon:FunctionAvailable(id,registry,active,depth,memo)
    registry=registry or self.functionRegistry;if not registry then self:InitializeFunctionRegistry();registry=self.functionRegistry end
]====],
        },
        {
            old = [====[        if definition.functionBindings and not definition.disabled and not definition.functionUnavailable and not definition.functionSuspended and not self:AreFunctionBindingsAvailable(definition.functionBindings,registry) then
            local ok=true;if definition.on_unregister then ok=pcall(definition.on_unregister,id) end
            if not ok then
                for _,entry in ipairs(cleaned) do entry[2].functionSuspended=nil;if entry[2].on_register then pcall(entry[2].on_register,entry[1]) end end
                return nil,'function-consumer-cleanup-failed'
            end
            definition.functionSuspended=true;cleaned[#cleaned+1]={id,definition}
        end
    end
    return true
]====],
            current = [====[        if definition.functionBindings and not definition.disabled and not definition.functionUnavailable and not definition.functionSuspended and not self:AreFunctionBindingsAvailable(definition.functionBindings,registry) then
            local ok=true;if definition.on_unregister then ok=pcall(definition.on_unregister,id) end
            if not ok then
                for _,entry in ipairs(cleaned) do entry[2].functionSuspended=nil;if invalidateDependencies then invalidateDependencies(addon,'condition',entry[1]) end;if entry[2].on_register then pcall(entry[2].on_register,entry[1]) end end
                return nil,'function-consumer-cleanup-failed'
            end
            definition.functionSuspended=true;if invalidateDependencies then invalidateDependencies(addon,'condition',id) end;cleaned[#cleaned+1]={id,definition}
        end
    end
    return true
]====],
        },
        {
            old = [====[    for id,definition in pairs(self.conditionDefinitions or {}) do
        if definition.functionBindings then
            local ok,why=self:AreFunctionBindingsAvailable(definition.functionBindings)
            definition.functionUnavailable=not ok and why or nil
            if ok and definition.functionSuspended and not definition.disabled then
                attempted[#attempted+1]={id=id,definition=definition}
                local registered=true;if definition.on_register then registered=pcall(definition.on_register,id) end
                if registered then definition.functionSuspended=nil else successful=false;definition.functionUnavailable='function-consumer-registration-failed' end
            end
            if self.ResetConditionQuarantine then self:ResetConditionQuarantine(definition) end
        end
    end
    self.conditionRegistryVersion=(self.conditionRegistryVersion or 0)+1
    if not deferRefresh and self.RefreshConditionConsumers then self:RefreshConditionConsumers() end
    return successful,not successful and 'function-consumer-registration-failed' or nil,attempted
end
]====],
            current = [====[    for id,definition in pairs(self.conditionDefinitions or {}) do
        if definition.functionBindings then
            local ok,why=self:AreFunctionBindingsAvailable(definition.functionBindings)
            local previousUnavailable=definition.functionUnavailable
            definition.functionUnavailable=not ok and why or nil
            if previousUnavailable~=definition.functionUnavailable then if invalidateDependencies then invalidateDependencies(addon,'condition',id) end end
            if ok and definition.functionSuspended and not definition.disabled then
                attempted[#attempted+1]={id=id,definition=definition}
                if invalidateDependencies then invalidateDependencies(addon,'condition',id) end
                local registered=true;if definition.on_register then registered=pcall(definition.on_register,id) end
                if registered then definition.functionSuspended=nil else successful=false;definition.functionUnavailable='function-consumer-registration-failed' end
                if invalidateDependencies then invalidateDependencies(addon,'condition',id) end
            end
            if self.ResetConditionQuarantine then self:ResetConditionQuarantine(definition) end
        end
    end
    self.conditionRegistryVersion=(self.conditionRegistryVersion or 0)+1
    if invalidateDependencies then invalidateDependencies(addon,'condition',nil) end
    if not deferRefresh and self.RefreshConditionConsumers then self:RefreshConditionConsumers() end
    return successful,not successful and 'function-consumer-registration-failed' or nil,attempted
end
]====],
        },
        {
            old = [====[    local registry,problem=self:BuildFunctionRegistry(sources);if not registry then return nil,problem end
    if not source.disabled then local available,reason=self:FunctionAvailable(id,registry);if not available then return nil,reason end end
    local prepared,prepareError=self:PrepareFunctionConsumerTransition(registry);if not prepared then return nil,prepareError end
    self.db.global.custom_functions=sources;self.functionRegistry=registry;self.functionRegistryVersion=(self.functionRegistryVersion or 0)+1;self:RefreshFunctionConsumers();return true
end
function addon:RemoveCustomFunction(id,expected)
    local current=(self.db.global.custom_functions or {})[id];if not current or not self:SettingsDataEqual(current,expected) then return nil,'function-changed' end
    local sources=self:CopySettingsData(self.db.global.custom_functions);sources[id]=nil;local registry,why=self:BuildFunctionRegistry(sources);if not registry then return nil,why end
    local prepared,prepareError=self:PrepareFunctionConsumerTransition(registry);if not prepared then return nil,prepareError end
    self.db.global.custom_functions=sources;self.functionRegistry=registry;self.functionRegistryVersion=(self.functionRegistryVersion or 0)+1;self:RefreshFunctionConsumers();return true
end
]====],
            current = [====[    local registry,problem=self:BuildFunctionRegistry(sources);if not registry then return nil,problem end
    if not source.disabled then local available,reason=self:FunctionAvailable(id,registry);if not available then return nil,reason end end
    local prepared,prepareError=self:PrepareFunctionConsumerTransition(registry);if not prepared then return nil,prepareError end
    self.db.global.custom_functions=sources;self.functionRegistry=registry;self.functionRegistryVersion=(self.functionRegistryVersion or 0)+1;if invalidateDependencies then invalidateDependencies(addon,'function',id) end;self:RefreshFunctionConsumers();return true
end
function addon:RemoveCustomFunction(id,expected)
    local current=(self.db.global.custom_functions or {})[id];if not current or not self:SettingsDataEqual(current,expected) then return nil,'function-changed' end
    local sources=self:CopySettingsData(self.db.global.custom_functions);sources[id]=nil;local registry,why=self:BuildFunctionRegistry(sources);if not registry then return nil,why end
    local prepared,prepareError=self:PrepareFunctionConsumerTransition(registry);if not prepared then return nil,prepareError end
    self.db.global.custom_functions=sources;self.functionRegistry=registry;self.functionRegistryVersion=(self.functionRegistryVersion or 0)+1;if invalidateDependencies then invalidateDependencies(addon,'function',id) end;self:RefreshFunctionConsumers();return true
end
]====],
        },
    },
    ["Core/custom_authoring.lua"] = {
        {
            old = [====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local docs={
    evaluate={description=L['Decide whether this condition currently matches.'],args={{'value','table',L['The stored values for this condition.']},{'cache','table',L['Shared data for this evaluation cycle.']},{'evalStart','number',L['Evaluation start time, in seconds from GetTime().']}},returns={'boolean | nil',L['True matches; false or nil does not match.']}},
]====],
            current = [====[local addon_name,addon=...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local docs={
    evaluate={description=L['Decide whether this condition currently matches.'],args={{'value','table',L['The stored values for this condition.']},{'cache','table',L['Shared data for this evaluation cycle.']},{'evalStart','number',L['Evaluation start time, in seconds from GetTime().']}},returns={'boolean | nil',L['True matches; false or nil does not match.']}},
]====],
        },
        {
            old = [====[    if self.Diagnostics then ok=self.Diagnostics:Call({module='custom_conditions',operation='register',conditionTag=key,customCode=true},self.RegisterCondition,self,key,definition)
    else ok=pcall(self.RegisterCondition,self,key,definition) end
    if not ok then
        if registry then registry[key]=previous end
        -- Trusted hooks can have arbitrary external effects. Restore registry
        -- and saved source; restoring the prior hook's setup is best effort.
        if previous and not previous.disabled and previous.on_register then pcall(previous.on_register,key) end
]====],
            current = [====[    if self.Diagnostics then ok=self.Diagnostics:Call({module='custom_conditions',operation='register',conditionTag=key,customCode=true},self.RegisterCondition,self,key,definition)
    else ok=pcall(self.RegisterCondition,self,key,definition) end
    if not ok then
        if registry then local changed=not rawequal(registry[key],previous);registry[key]=previous;if changed and invalidateDependencies then invalidateDependencies(addon,'condition',key) end end
        -- Trusted hooks can have arbitrary external effects. Restore registry
        -- and saved source; restoring the prior hook's setup is best effort.
        if previous and not previous.disabled and previous.on_register then pcall(previous.on_register,key) end
]====],
        },
    },
    ["Core/function_data.lua"] = {
        {
            old = [====[local _,addon=...
local MAX_ENTRIES,MAX_BYTES,MAX_DEPTH=128,1048576,64
-- Bound and reject hostile data before any recursive copy or source compilation.
local function portable(value)
]====],
            current = [====[local _,addon=...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end
local MAX_ENTRIES,MAX_BYTES,MAX_DEPTH=128,1048576,64
-- Bound and reject hostile data before any recursive copy or source compilation.
local function portable(value)
]====],
        },
        {
            old = [====[    local function restoreConsumers()
        for id,record in pairs(oldDefinitions) do
            local definition=record.definition;local resume=definition.functionSuspended and not record.suspended
            definition.functionSuspended=record.suspended;definition.functionUnavailable=record.unavailable
            if resume and definition.on_register and not definition.disabled and not record.unavailable then pcall(definition.on_register,id) end
        end
    end
]====],
            current = [====[    local function restoreConsumers()
        for id,record in pairs(oldDefinitions) do
            local definition=record.definition;local resume=definition.functionSuspended and not record.suspended
            local changed=definition.functionSuspended~=record.suspended or definition.functionUnavailable~=record.unavailable
            definition.functionSuspended=record.suspended;definition.functionUnavailable=record.unavailable
            if changed and invalidateDependencies then invalidateDependencies(addon,'condition',id) end
            if resume and definition.on_register and not definition.disabled and not record.unavailable then pcall(definition.on_register,id) end
        end
    end
]====],
        },
        {
            old = [====[        local previous=registry[id]
        if previous and not previous.disabled and not previous.functionUnavailable and not previous.functionSuspended then
            previous.functionSuspended=true
            if previous.on_unregister and not pcall(previous.on_unregister,id) then restoreConsumers();return nil,'condition-cleanup-failed' end
        end
    end
    self.db.global.custom_functions=sources;self.functionRegistry=staged
    -- Isolate saved tables too: a failing trusted hook may write to these maps.
    self.db.global.custom_conditions=self:CopySettingsData(oldConditions or {})
    self.db.global.function_import_origins=self:CopySettingsData(oldOrigins or {})
]====],
            current = [====[        local previous=registry[id]
        if previous and not previous.disabled and not previous.functionUnavailable and not previous.functionSuspended then
            previous.functionSuspended=true
            if invalidateDependencies then invalidateDependencies(addon,'condition',id) end
            if previous.on_unregister and not pcall(previous.on_unregister,id) then restoreConsumers();return nil,'condition-cleanup-failed' end
        end
    end
    self.db.global.custom_functions=sources;self.functionRegistry=staged
    if invalidateDependencies then invalidateDependencies(addon,'function',nil) end
    -- Isolate saved tables too: a failing trusted hook may write to these maps.
    self.db.global.custom_conditions=self:CopySettingsData(oldConditions or {})
    self.db.global.function_import_origins=self:CopySettingsData(oldOrigins or {})
]====],
        },
        {
            old = [====[            local key=record.entry.destinationID;local current=registry[key]
            if current and current~=(oldDefinitions[key] and oldDefinitions[key].definition) and current.on_unregister and not current.disabled and not current.functionUnavailable then pcall(current.on_unregister,key) end
            registry[key]=oldDefinitions[key] and oldDefinitions[key].definition
        end
        self.db.global.custom_functions=oldSources;self.functionRegistry=oldRegistry;self.functionRegistryVersion=oldVersion;self.db.global.custom_conditions=oldConditions;self.db.global.function_import_origins=oldOrigins;self.conditionRegistryVersion=oldConditionVersion
        restoreConsumers();return nil,failureReason
    end
    local conditionSources=self:CopySettingsData(oldConditions or {});local origins=self:CopySettingsData(oldOrigins or {})
]====],
            current = [====[            local key=record.entry.destinationID;local current=registry[key]
            if current and current~=(oldDefinitions[key] and oldDefinitions[key].definition) and current.on_unregister and not current.disabled and not current.functionUnavailable then pcall(current.on_unregister,key) end
            registry[key]=oldDefinitions[key] and oldDefinitions[key].definition
            if invalidateDependencies then invalidateDependencies(addon,'condition',key) end
        end
        self.db.global.custom_functions=oldSources;self.functionRegistry=oldRegistry;self.functionRegistryVersion=oldVersion;self.db.global.custom_conditions=oldConditions;self.db.global.function_import_origins=oldOrigins;self.conditionRegistryVersion=oldConditionVersion
        if invalidateDependencies then invalidateDependencies(addon,'all',nil) end
        restoreConsumers();return nil,failureReason
    end
    local conditionSources=self:CopySettingsData(oldConditions or {});local origins=self:CopySettingsData(oldOrigins or {})
]====],
        },
    },
    ["UI/condition_source_pane.lua"] = {
        {
            old = [====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function clearNew(p) p.creatingCondition=nil;p.newConditionKey=nil;p.newConditionSource=nil end
function addon:InstallInlineConditionNavigation(p)
]====],
            current = [====[local addon_name,addon=...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function clearNew(p) p.creatingCondition=nil;p.newConditionKey=nil;p.newConditionSource=nil end
function addon:InstallInlineConditionNavigation(p)
]====],
        },
        {
            old = [====[            if changed then
                local current=self.conditionDefinitions[identifier];if current and not current.disabled and current.on_unregister then pcall(current.on_unregister,identifier) end
                self.db.global.custom_conditions[identifier]=previous;self.conditionDefinitions[identifier]=oldDefinition;self.conditionRegistryVersion=(self.conditionRegistryVersion or 0)+1
                if oldDefinition and not oldDefinition.disabled and oldDefinition.on_register then pcall(oldDefinition.on_register,identifier) end
                if self.RefreshConditionConsumers then self:RefreshConditionConsumers() end
                p.draft.global.custom_conditions[identifier]=self:CopySettingsData(previous);p.draftBaseline.global.custom_conditions[identifier]=self:CopySettingsData(previous)
]====],
            current = [====[            if changed then
                local current=self.conditionDefinitions[identifier];if current and not current.disabled and current.on_unregister then pcall(current.on_unregister,identifier) end
                self.db.global.custom_conditions[identifier]=previous;self.conditionDefinitions[identifier]=oldDefinition;self.conditionRegistryVersion=(self.conditionRegistryVersion or 0)+1
                if invalidateDependencies then invalidateDependencies(addon,'condition',identifier) end
                if oldDefinition and not oldDefinition.disabled and oldDefinition.on_register then pcall(oldDefinition.on_register,identifier) end
                if self.RefreshConditionConsumers then self:RefreshConditionConsumers() end
                p.draft.global.custom_conditions[identifier]=self:CopySettingsData(previous);p.draftBaseline.global.custom_conditions[identifier]=self:CopySettingsData(previous)
]====],
        },
    },
    ["UI/settings_collections.lua"] = {
        {
            old = [====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:SettingsEntries(values)
    local entries={};for id,value in pairs(values or {}) do if type(value)=='table' then entries[#entries+1]={value=id,text=type(value.name)=='string' and value.name or tostring(id)} end end
]====],
            current = [====[local addon_name,addon=...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:SettingsEntries(values)
    local entries={};for id,value in pairs(values or {}) do if type(value)=='table' then entries[#entries+1]={value=id,text=type(value.name)=='string' and value.name or tostring(id)} end end
]====],
        },
        {
            old = [====[    -- source and registered definition, rather than leaving an orphaned runtime.
    local definition=self.conditionDefinitions and self.conditionDefinitions[key]
    local ok,why=pcall(self.UnregisterCondition,self,key)
    if not ok then if self.conditionDefinitions then self.conditionDefinitions[key]=definition end;return false,why end
    self.db.global.custom_conditions[key]=nil
    if self.RefreshConditionConsumers then self:RefreshConditionConsumers() end
    return true
]====],
            current = [====[    -- source and registered definition, rather than leaving an orphaned runtime.
    local definition=self.conditionDefinitions and self.conditionDefinitions[key]
    local ok,why=pcall(self.UnregisterCondition,self,key)
    if not ok then if self.conditionDefinitions then local changed=not rawequal(self.conditionDefinitions[key],definition);self.conditionDefinitions[key]=definition;if changed and invalidateDependencies then invalidateDependencies(addon,'condition',key) end end;return false,why end
    self.db.global.custom_conditions[key]=nil
    if self.RefreshConditionConsumers then self:RefreshConditionConsumers() end
    return true
]====],
        },
    },
    ["UI/settings_draft.lua"] = {
        {
            old = [====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function equal(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
]====],
            current = [====[local addon_name,addon=...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function equal(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
]====],
        },
        {
            old = [====[        end end end
        if InCombatLockdown and InCombatLockdown() then self:Message(L['Leave combat before applying these settings.']);return false end
        for scope,keys in pairs(self.transactionKeys) do for _,key in ipairs(keys) do
            if not (scope=='profile' and key=='stockTargets' and stockUnchanged) and not equal(self.draft[scope][key],self.draftBaseline[scope][key]) then addon.db[scope][key]=addon:CopySettingsData(self.draft[scope][key]) end
        end end
        local effects=self.draftEffects;if self.ClearSettingsHistory then self:ClearSettingsHistory() end;self.draft=nil;self.draftBaseline=nil;self.draftEffects=nil
        for _,callback in pairs(effects) do callback() end
]====],
            current = [====[        end end end
        if InCombatLockdown and InCombatLockdown() then self:Message(L['Leave combat before applying these settings.']);return false end
        for scope,keys in pairs(self.transactionKeys) do for _,key in ipairs(keys) do
            if not (scope=='profile' and key=='stockTargets' and stockUnchanged) and not equal(self.draft[scope][key],self.draftBaseline[scope][key]) then
                addon.db[scope][key]=addon:CopySettingsData(self.draft[scope][key])
                if key=='itemsets' and (scope=='profile' or scope=='global') then if invalidateDependencies then invalidateDependencies(addon,'itemset',nil) end
                elseif key=='effects' and scope=='global' then if invalidateDependencies then invalidateDependencies(addon,'effect',nil) end end
            end
        end end
        local effects=self.draftEffects;if self.ClearSettingsHistory then self:ClearSettingsHistory() end;self.draft=nil;self.draftBaseline=nil;self.draftEffects=nil
        for _,callback in pairs(effects) do callback() end
]====],
        },
    },
    ["UI/settings_effects.lua"] = {
        {
            old = [====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local types={{value='texture',text=L['Texture']},{value='pixel',text=L['Pixel']},{value='autocast',text=L['Auto Cast']},{value='blizzard',text=L['Glow']},{value='proc',text=L['Proc Glow']},{value='dazzle',text=L['Dazzle']},{value='animate',text=L['Animate']},{value='pulse',text=L['Pulse']},{value='rotate',text=L['Rotate']},{value='custom',text=L['Custom']}}
local schemas={proc={{'duration','Loop duration',1,.1,5,.05}},pixel={{'lines','Lines',8,1,20,1},{'frequency','Frequency',.25,-1.5,1.5,.05},{'length','Length',2,1,20,1},{'thickness','Thickness',2,1,5,1}},autocast={{'particles','Particles',4,1,4,1},{'frequency','Frequency',.125,-1.5,1.5,.05},{'scale','Scale',1,.25,5,.25}},blizzard={{'frequency','Frequency',.125,0,1.5,.05}},dazzle={{'frequency','Frequency',.25,.1,5,.05}},animate={{'frequency','Frequency',.25,.1,5,.05}},pulse={{'frequency','Frequency',.25,.1,5,.05}},custom={{'frequency','Frequency',.25,.1,5,.05}},rotate={{'frequency','Frequency',.25,.1,5,.05},{'steps','Steps',4,2,36,1}}}
]====],
            current = [====[local addon_name,addon=...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local types={{value='texture',text=L['Texture']},{value='pixel',text=L['Pixel']},{value='autocast',text=L['Auto Cast']},{value='blizzard',text=L['Glow']},{value='proc',text=L['Proc Glow']},{value='dazzle',text=L['Dazzle']},{value='animate',text=L['Animate']},{value='pulse',text=L['Pulse']},{value='rotate',text=L['Rotate']},{value='custom',text=L['Custom']}}
local schemas={proc={{'duration','Loop duration',1,.1,5,.05}},pixel={{'lines','Lines',8,1,20,1},{'frequency','Frequency',.25,-1.5,1.5,.05},{'length','Length',2,1,20,1},{'thickness','Thickness',2,1,5,1}},autocast={{'particles','Particles',4,1,4,1},{'frequency','Frequency',.125,-1.5,1.5,.05},{'scale','Scale',1,.25,5,.25}},blizzard={{'frequency','Frequency',.125,0,1.5,.05}},dazzle={{'frequency','Frequency',.25,.1,5,.05}},animate={{'frequency','Frequency',.25,.1,5,.05}},pulse={{'frequency','Frequency',.25,.1,5,.05}},custom={{'frequency','Frequency',.25,.1,5,.05}},rotate={{'frequency','Frequency',.25,.1,5,.05},{'steps','Steps',4,2,36,1}}}
]====],
        },
        {
            old = [====[            {key='delete',text=L['Delete'],icon='trash',action=function()
                self:ConfirmSettingsDeletion(p,L['Delete this effect? Rotations using it will need another effect.'],function()
                    if not (self.db.global.effects or {})[id] then return false,'effect-changed' end
                    self.db.global.effects[id]=nil;return true
                end)
            end}}
        actionEntries[1].enabled=not isNew;self:CollectionFooter(p,'effect',effects,isNew and nil or id,actionEntries[1],actionEntries[2]);if not isNew then self:SettingsTopDelete(p,actionEntries[3].action) end
]====],
            current = [====[            {key='delete',text=L['Delete'],icon='trash',action=function()
                self:ConfirmSettingsDeletion(p,L['Delete this effect? Rotations using it will need another effect.'],function()
                    if not (self.db.global.effects or {})[id] then return false,'effect-changed' end
                    self.db.global.effects[id]=nil;if invalidateDependencies then invalidateDependencies(addon,'effect',id) end;return true
                end)
            end}}
        actionEntries[1].enabled=not isNew;self:CollectionFooter(p,'effect',effects,isNew and nil or id,actionEntries[1],actionEntries[2]);if not isNew then self:SettingsTopDelete(p,actionEntries[3].action) end
]====],
        },
    },
    ["UI/settings_items.lua"] = {
        {
            old = [====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function itemValue(text)
    local value=text:match('^%s*(.-)%s*$');if value=='' then return end
]====],
            current = [====[local addon_name,addon=...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function itemValue(text)
    local value=text:match('^%s*(.-)%s*$');if value=='' then return end
]====],
        },
        {
            old = [====[                    if not current then return false,'item-set-changed' end
                    if self.UnbindItemSet then if self:UnbindItemSet(id,self:CopySettingsData(current.items or {}))==false then return false,L['Leave combat before changing action bar bindings.'] end
                    elseif self.db.char and self.db.char.bindings then self.db.char.bindings[id]=nil end
                    profile[id]=nil;global[id]=nil;if self.UpdateItemSetButtons then self:UpdateItemSetButtons(id) end;return true
                end)
            end}}

]====],
            current = [====[                    if not current then return false,'item-set-changed' end
                    if self.UnbindItemSet then if self:UnbindItemSet(id,self:CopySettingsData(current.items or {}))==false then return false,L['Leave combat before changing action bar bindings.'] end
                    elseif self.db.char and self.db.char.bindings then self.db.char.bindings[id]=nil end
                    profile[id]=nil;global[id]=nil;if invalidateDependencies then invalidateDependencies(addon,'itemset',id) end;if self.UpdateItemSetButtons then self:UpdateItemSetButtons(id) end;return true
                end)
            end}}

]====],
        },
    },
    ["Core/rotation_lifecycle.lua"] = {
        {
            old = [====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Also called after import overlays: AceDB emits Reset/Copy before the
-- importer publishes its final roots, so its event alone cannot authorize them.
function addon:RefreshRotationProfileStorage()
    local ok,why=self:InitializeScopedRotationStorage()
    self.rotationStorageError=not ok and why or nil
    if self.InitializeRotationLibrary then self:InitializeRotationLibrary() end
]====],
            current = [====[local addon_name,addon=...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Also called after import overlays: AceDB emits Reset/Copy before the
-- importer publishes its final roots, so its event alone cannot authorize them.
function addon:RefreshRotationProfileStorage()
    if invalidateDependencies then invalidateDependencies(addon,'all',nil) end
    local ok,why=self:InitializeScopedRotationStorage()
    self.rotationStorageError=not ok and why or nil
    if self.InitializeRotationLibrary then self:InitializeRotationLibrary() end
]====],
        },
    },
    ["UI/settings_profiles.lua"] = {
        {
            old = [====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function nonempty(text) if text:find('%S') and #text<=50 then return text end end
function addon:BuildProfileSettings(p)
]====],
            current = [====[local addon_name,addon=...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function nonempty(text) if text:find('%S') and #text<=50 then return text end end
function addon:BuildProfileSettings(p)
]====],
        },
        {
            old = [====[        local depth=self.rotationProfileChangeDepth or 0;self.rotationProfileChangeDepth=depth+1
        local ok,why=pcall(function() if operation=='CopyProfile' and not stockOK(saved(name)) then error(L['Invalid stock targets; data preserved.'],0) end;db[operation](db,name);if after then after() end end)
        self.rotationProfileChangeDepth=depth
        if self.RotationProfileChanged then self:RotationProfileChanged()
        elseif self.EnableRotation then self:EnableRotation() end
        if not ok then p:Message(tostring(why));return false end
]====],
            current = [====[        local depth=self.rotationProfileChangeDepth or 0;self.rotationProfileChangeDepth=depth+1
        local ok,why=pcall(function() if operation=='CopyProfile' and not stockOK(saved(name)) then error(L['Invalid stock targets; data preserved.'],0) end;db[operation](db,name);if after then after() end end)
        self.rotationProfileChangeDepth=depth
        if invalidateDependencies then invalidateDependencies(addon,'all',nil) end
        if self.RotationProfileChanged then self:RotationProfileChanged()
        elseif self.EnableRotation then self:EnableRotation() end
        if not ok then p:Message(tostring(why));return false end
]====],
        },
    },
    ["init.lua"] = {
        {
            old = [====[local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

]====],
            current = [====[local addon_name, addon = ...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

]====],
        },
        {
            old = [====[            button2 = NO,
            OnAccept = function()
                addon.db.global.effects = deepcopy(default_effects)
            end,
            showAlert = 1,
            timeout = 0,
]====],
            current = [====[            button2 = NO,
            OnAccept = function()
                addon.db.global.effects = deepcopy(default_effects)
                if invalidateDependencies then invalidateDependencies(addon,'effect',nil) end
            end,
            showAlert = 1,
            timeout = 0,
]====],
        },
        {
            old = [====[    if addon.db.profile.rotationStore~=nil then addon.db.profile.version=3
    elseif not addon.InitializeScopedRotationStorage then addon.db.profile.version=PROFILE_VERSION end
    addon.db.global.version = GLOBAL_VERSION
end

]====],
            current = [====[    if addon.db.profile.rotationStore~=nil then addon.db.profile.version=3
    elseif not addon.InitializeScopedRotationStorage then addon.db.profile.version=PROFILE_VERSION end
    addon.db.global.version = GLOBAL_VERSION
    if invalidateDependencies then invalidateDependencies(addon,'all',nil) end
end

]====],
        },
    },
    ["validate.lua"] = {
        {
            old = [====[local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

]====],
            current = [====[local addon_name, addon = ...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

]====],
        },
        {
            old = [====[        end
    end

    addon.Functions.collections.cleanArray(toremove)
end

]====],
            current = [====[        end
    end

    if fix and toremove.data and invalidateDependencies then invalidateDependencies(addon,'all',nil) end
    addon.Functions.collections.cleanArray(toremove)
end

]====],
        },
        {
            old = [====[        addon:warn("Invalid ID for itemset %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(itemset)
            return
        end
    end
]====],
            current = [====[        addon:warn("Invalid ID for itemset %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(itemset)
            if invalidateDependencies then invalidateDependencies(addon,'itemset',name) end
            return
        end
    end
]====],
        },
        {
            old = [====[        addon:warn("Invalid ID for effect %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(effect)
            return
        end
    end
]====],
            current = [====[        addon:warn("Invalid ID for effect %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(effect)
            if invalidateDependencies then invalidateDependencies(addon,'effect',name) end
            return
        end
    end
]====],
        },
        {
            old = [====[        addon:warn("No effect type for %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(effect)
        end
        return
    end
]====],
            current = [====[        addon:warn("No effect type for %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(effect)
            if invalidateDependencies then invalidateDependencies(addon,'effect',name) end
        end
        return
    end
]====],
        },
        {
            old = [====[                -- repair. Selection notices this registry version next pass.
                definition.disabled=true
                addon.conditionRegistryVersion=(addon.conditionRegistryVersion or 0)+1
            end
        end
    end
]====],
            current = [====[                -- repair. Selection notices this registry version next pass.
                definition.disabled=true
                addon.conditionRegistryVersion=(addon.conditionRegistryVersion or 0)+1
                if invalidateDependencies then invalidateDependencies(addon,'condition',name) end
            end
        end
    end
]====],
        },
        {
            old = [====[end

function addon:validate(template, fix)
    local DB = _G[self.savedVariableName or "RotationMasterDB"]

    local glob_template = addon.Functions.collections.deepcopy(template.global)
]====],
            current = [====[end

function addon:validate(template, fix)
    if fix then if invalidateDependencies then invalidateDependencies(addon,'all',nil) end end
    local DB = _G[self.savedVariableName or "RotationMasterDB"]

    local glob_template = addon.Functions.collections.deepcopy(template.global)
]====],
        },
        {
            old = [====[            apply_remove(toremove, data.disabled_conditions, fix)
        end
    end
end
]====],
            current = [====[            apply_remove(toremove, data.disabled_conditions, fix)
        end
    end
    if fix then if invalidateDependencies then invalidateDependencies(addon,'all',nil) end end
end
]====],
        },
    },
    ["tests/fixtures/addon.lua"] = {
        {
            old = [====[        local chunk=assert(loadfile(path)); setfenv(chunk, env); return chunk('rotationmaster',addon)
    end
    dofile('tests/fixtures/native_ui.lua')(env)
    load('globals.lua');load('Platform/client.lua');load('Platform/rotation_owner.lua');load('Platform/groups.lua');load('Platform/roster_class.lua');load('Platform/role.lua');load('Platform/mobinfo2.lua');load('Platform/casting.lua');load('Platform/unit_health.lua');load('Platform/unit_stat.lua');load('Platform/health_forecast.lua');load('Platform/unit_level.lua');load('Platform/unit_power.lua');load('Platform/player_movement.lua');load('Platform/unit_attackability.lua');load('Platform/unit_flags.lua');load('Platform/player_flags.lua');load('Platform/form.lua');load('Platform/points.lua');load('Platform/runes.lua');load('Platform/unit_identity.lua');load('Platform/unit_metadata.lua');load('Platform/creature_type.lua');load('Platform/unit_presence.lua');load('Platform/pet.lua');load('Platform/threat.lua');load('Platform/instance.lua');load('Platform/zone_pvp.lua');load('Platform/loss_of_control.lua');load('Platform/items.lua');load('Platform/glyphs.lua');load('Platform/specializations.lua')
    load('Locales/enUS.lua'); load('constants.lua');load('Data/artwork.lua');load('Functions/values.lua');load('Functions/presentation.lua');load('Functions/text.lua');load('Functions/collections.lua');load('Functions/cache.lua');load('Functions/trends.lua');load('Functions/forecast.lua'); load('utils.lua');load('Core/level_conditions.lua');load('Core/point_conditions.lua');load('Core/class_group_conditions.lua');load('Core/creature_conditions.lua');load('Core/health_forecast_conditions.lua');load('Core/threat_count_conditions.lua')
    load('UI/controls.lua');load('UI/condition_widgets.lua');load('UI/condition_observation.lua');load('UI/condition_icon.lua');load('UI/condition_position.lua');load('UI/condition_display.lua');load('UI/drag_presentation.lua');load('Core/unsaved_changes.lua');load('UI/unsaved.lua');load('Core/stock_targets.lua');load('UI/stock_profile_safety.lua');load('UI/settings_stock.lua');load('UI/settings_draft.lua');load('UI/collection_compare.lua');load('UI/draft_changes.lua');load('UI/draft_change_controls.lua');load('UI/window.lua');load('UI/selector.lua');load('UI/tag_picker.lua');load('UI/checkbox.lua');load('UI/condition_inputs.lua');load('UI/condition_layout.lua');load('UI/condition_table.lua');load('UI/condition_unit.lua');load('Core/item_conditions.lua');load('Core/rotation_references.lua');load('Help/common.lua'); load('Help/conditional.lua'); load('Core/presentation.lua');load('Core/condition_description.lua'); load('Core/spell_catalog.lua');load('Core/spell_search.lua');load('Core/reference_catalog.lua');load('Core/category_data.lua');load('Core/announcement_data.lua');load('Core/profile_data.lua');load('Core/collection_data.lua');load('Core/custom_condition_data.lua');load('Core/functions.lua');load('UI/spell_search.lua');load('UI/spell_icon.lua')
    return {env=env, addon=addon, load=load, widget=widget, translations=translations, libraries=libraries}
]====],
            current = [====[        local chunk=assert(loadfile(path)); setfenv(chunk, env); return chunk('rotationmaster',addon)
    end
    dofile('tests/fixtures/native_ui.lua')(env)
    load('globals.lua');load('Core/dependency_revisions.lua');load('Platform/client.lua');load('Platform/rotation_owner.lua');load('Platform/groups.lua');load('Platform/roster_class.lua');load('Platform/role.lua');load('Platform/mobinfo2.lua');load('Platform/casting.lua');load('Platform/unit_health.lua');load('Platform/unit_stat.lua');load('Platform/health_forecast.lua');load('Platform/unit_level.lua');load('Platform/unit_power.lua');load('Platform/player_movement.lua');load('Platform/unit_attackability.lua');load('Platform/unit_flags.lua');load('Platform/player_flags.lua');load('Platform/form.lua');load('Platform/points.lua');load('Platform/runes.lua');load('Platform/unit_identity.lua');load('Platform/unit_metadata.lua');load('Platform/creature_type.lua');load('Platform/unit_presence.lua');load('Platform/pet.lua');load('Platform/threat.lua');load('Platform/instance.lua');load('Platform/zone_pvp.lua');load('Platform/loss_of_control.lua');load('Platform/items.lua');load('Platform/glyphs.lua');load('Platform/specializations.lua')
    load('Locales/enUS.lua'); load('constants.lua');load('Data/artwork.lua');load('Functions/values.lua');load('Functions/presentation.lua');load('Functions/text.lua');load('Functions/collections.lua');load('Functions/cache.lua');load('Functions/trends.lua');load('Functions/forecast.lua'); load('utils.lua');load('Core/level_conditions.lua');load('Core/point_conditions.lua');load('Core/class_group_conditions.lua');load('Core/creature_conditions.lua');load('Core/health_forecast_conditions.lua');load('Core/threat_count_conditions.lua')
    load('UI/controls.lua');load('UI/condition_widgets.lua');load('UI/condition_observation.lua');load('UI/condition_icon.lua');load('UI/condition_position.lua');load('UI/condition_display.lua');load('UI/drag_presentation.lua');load('Core/unsaved_changes.lua');load('UI/unsaved.lua');load('Core/stock_targets.lua');load('UI/stock_profile_safety.lua');load('UI/settings_stock.lua');load('UI/settings_draft.lua');load('UI/collection_compare.lua');load('UI/draft_changes.lua');load('UI/draft_change_controls.lua');load('UI/window.lua');load('UI/selector.lua');load('UI/tag_picker.lua');load('UI/checkbox.lua');load('UI/condition_inputs.lua');load('UI/condition_layout.lua');load('UI/condition_table.lua');load('UI/condition_unit.lua');load('Core/item_conditions.lua');load('Core/rotation_references.lua');load('Help/common.lua'); load('Help/conditional.lua'); load('Core/presentation.lua');load('Core/condition_description.lua'); load('Core/spell_catalog.lua');load('Core/spell_search.lua');load('Core/reference_catalog.lua');load('Core/category_data.lua');load('Core/announcement_data.lua');load('Core/profile_data.lua');load('Core/collection_data.lua');load('Core/custom_condition_data.lua');load('Core/functions.lua');load('UI/spell_search.lua');load('UI/spell_icon.lua')
    return {env=env, addon=addon, load=load, widget=widget, translations=translations, libraries=libraries}
]====],
        },
    },
}

return function(text, path, baseline)
    if path == 'UI/settings_collections.lua' and not baseline then
        text = dofile('tests/fixtures/restore_questie_wiring.lua')(text, path)
    end

    local old = assert(records[path], 'unknown dependency-revision module')

    if baseline then
        assert(text == nil)
        return old
    end

    assert(type(text) == 'string')

    for _, patch in ipairs(patches[path]) do
        local first, last = text:find(patch.current, 1, true)
        assert(first, 'exact dependency-revision block missing: ' .. path)
        assert(not text:find(patch.current, last + 1, true), 'dependency-revision block repeated: ' .. path)
        text = text:sub(1, first - 1) .. patch.old .. text:sub(last + 1)
    end

    assert(text == old, 'module changed outside dependency revisions: ' .. path)
    return old
end
