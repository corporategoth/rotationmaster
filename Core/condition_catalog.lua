local _, addon = ...
local pairs = pairs

-- Live catalog/query/dispatch services, independent of options rendering.
-- Load after Core/conditions.lua; retain its original registry identities.
local conditions = addon.conditionDefinitions
local special = addon.conditionSpecials

function addon:findConditionGroup(value)
    if not value then
        return nil
    end

    local profile = addon.db.profile

    for _, v in pairs(profile.condition_groups) do
        if v.conditions then
            for _, cond in pairs(v.conditions) do
                if value == cond then
                    return v.id
                end
            end
        end
    end

    return "DEFAULT"
end

function addon:listConditions(group, nohide, store)
    store = store or addon.db
    local profile = store.profile
    local global = store.global

    local rv = {}

    if group == "SWITCH" or group == "ANNOUNCEMENT" then
        local selected = profile.switch_conditions
        if group == "ANNOUNCEMENT" then selected = profile.announcement_conditions end

        for _, cond in pairs(type(selected) == "table" and selected or {}) do
            if special[cond] then
                table.insert(rv, cond)
            elseif conditions[cond] then
                table.insert(rv, cond)
            end
        end

        for cond, _ in pairs(special) do
            if not addon.index(rv, cond) then
                table.insert(rv, cond)
            end
        end
    elseif group == "CUSTOM" then
        for key, _ in pairs(global.custom_conditions) do
            table.insert(rv, key)
        end
    else
        local skipped = {}

        for _, v in pairs(profile.condition_groups) do
            if v.conditions then
                if group == "DEFAULT" then
                    for _, cond in pairs(v.conditions) do
                        skipped[cond] = true
                    end
                elseif group == v.id or group == "ALL" then
                    for _, cond in pairs(v.conditions) do
                        if special[cond] then
                            table.insert(rv, cond)
                        elseif conditions[cond] then
                            table.insert(rv, cond)
                        end

                        skipped[cond] = true
                    end
                end
            end
        end

        if group == "DEFAULT" or group == "ALL" then
            for _, cond in pairs(profile.other_conditions_order) do
                if not (group == "ALL" and skipped[cond]) then
                    if special[cond] then
                        table.insert(rv, cond)
                    elseif conditions[cond] then
                        table.insert(rv, cond)
                    end

                    skipped[cond] = true
                end
            end

            for cond, _ in pairs(special) do
                if not skipped[cond] then
                    table.insert(rv, cond)
                end
            end

            for cond, _ in pairs(conditions) do
                if not skipped[cond] and (nohide or not addon.index(profile.disabled_conditions, cond)) then
                    table.insert(rv, cond)
                end
            end
        end
    end

    -- Pickers hide conditions that cannot work on this client. Saved trees
    -- that already use one still show it, marked unavailable, as incomplete.
    if not nohide and addon.GetConditionSupport then
        local kept = {}

        for _, cond in ipairs(rv) do
            if special[cond] or not addon:GetConditionSupport(cond, conditions[cond]) then kept[#kept + 1] = cond end
        end

        rv = kept
    end

    if group == "ALL" or group == "CUSTOM" then
        table.sort(rv, function(lhs, rhs)
            local ldesc, rdesc

            if special[lhs] then
                ldesc = special[lhs].desc
            else
                ldesc = conditions[lhs].description
            end

            if special[rhs] then
                rdesc = special[rhs].desc
            else
                rdesc = conditions[rhs].description
            end

            return ldesc < rdesc
        end)
    end

    return rv
end

function addon:describeCondition(type)
    if type ~= nil then
        if special[type] then
            return special[type].icon, special[type].desc, "", special[type].fields
        end

        if conditions[type] then
            return conditions[type].icon, conditions[type].description, conditions[type].help, conditions[type].fields
        end
    end
end

function addon:widgetCondition(parent, spec, value)
    if
        value ~= nil and value.type ~= nil and conditions[value.type] ~= nil and conditions[value.type].widget ~= nil
    then
        conditions[value.type].widget(parent, spec, value)
    end
end
