local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- Registry and tree services are independent of options rendering.
local printArray, printSingle, validateArray, validateSingle, usefulArray, usefulSingle

local conditions = {}
addon.conditionDefinitions = conditions
local special = {}
addon.conditionSpecials = special
local quarantined = setmetatable({}, {__mode="k"})
special["DELETE"] = { desc = DELETE, icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Controls\\trash.tga", fields = { } }
special["AND"] = { desc = L["AND"], icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\logic", fields = { value = "condition[]" } }
special["OR"] = { desc = L["OR"], icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\logic", fields = { value = "condition[]" } }
special["NOT"] = { desc = L["NOT"], icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\logic", fields = { value = "condition" } }

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
    if self.currentRotation and self.GetRuntimeRotation and not self:GetRuntimeRotation(self.currentSpec,self.currentRotation) then self:DisableRotation() end
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
        local wrapped=function(spec,value,negated) return addon:RenderConditionPhrase(raw(spec,value),negated) end
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
