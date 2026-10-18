local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- Registry and tree services are independent of options rendering.
local printArray, printSingle, validateArray, validateSingle, usefulArray, usefulSingle

local conditions = {}
addon.conditionDefinitions = conditions
local special = {}
addon.conditionSpecials = special
local quarantined = setmetatable({}, {__mode="k"})
special["DELETE"] = { desc = DELETE, icon = "Interface\\Icons\\Trade_Engineering", fields = { } }
special["AND"] = { desc = L["AND"], icon = "Interface\\Icons\\Spell_ChargePositive", fields = { value = "condition[]" } }
special["OR"] = { desc = L["OR"], icon = "Interface\\Icons\\Spell_ChargeNegative", fields = { value = "condition[]" } }
special["NOT"] = { desc = L["NOT"], icon = "Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent", fields = { value = "condition" } }

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

            if entry.type == "AND" or entry.type == "OR" then
                rv = rv .. printArray(entry.type, entry.value, spec)
            else
                rv = rv .. printSingle(entry, spec)
            end
        end
    end

    rv = rv .. ")"

    return rv
end

printSingle = function(value, spec)
    if value == nil or value.type == nil or value.disabled then
        return ""
    end

    if value.type == "AND" or value.type == "OR" then
        return  printArray(value.type, value.value, spec)
    elseif value.type == "NOT" then
        return "NOT " .. printSingle(value.value, spec)
    elseif conditions[value.type] ~= nil then
        return conditions[value.type].print(spec, value)
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

function addon:RegisterCondition(tag, array)
    if conditions[tag] and conditions[tag].on_unregister then
        conditions[tag].on_unregister(tag)
    end
    conditions[tag] = array
    self.conditionRegistryVersion=(self.conditionRegistryVersion or 0)+1
    quarantined[array] = nil
    if array.on_register then
        array.on_register(tag)
    end
end

function addon:UnregisterCondition(tag)
    if conditions[tag] and conditions[tag].on_unregister then
        conditions[tag].on_unregister(tag)
    end
    if conditions[tag]~=nil then self.conditionRegistryVersion=(self.conditionRegistryVersion or 0)+1 end
    conditions[tag] = nil
end

function addon:evaluateConditionResult(value, context)
    return evaluate(value, {}, GetTime(), {active={}, count=0, context=context}, 0, "condition")
end

function addon:evaluateCondition(value, context)
    return self:evaluateConditionResult(value, context).status == "match"
end

function addon:printCondition(value, spec)
    return printSingle(value, spec)
end

function addon:validateCondition(value, spec)
    return validateSingle(value, spec)
end

function addon:usefulCondition(value)
    return usefulSingle(value)
end
