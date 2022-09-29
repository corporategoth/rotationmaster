local addon_name, addon = ...

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

    addon.cleanArray(toremove)
end

local function validate_basic(prefix, data, template, fix)
    local toremove = {}
    for k,v in pairs(data) do
        if template[k] == nil then
            addon:warn("Extra Field %s:%s", prefix, tostring(k))
            mark_for_remove(toremove, k)
        elseif type(v) ~= type(template[k]) then
            addon:warn("Incorrect type for %s:%s (was %s, expected %s)", prefix, tostring(k), type(v), type(template[k]))
            mark_for_remove(toremove, k)
        elseif type(v) == "table" then
            if addon.tablelength(template[k]) > 0 then
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
    return uuid:match("(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)") ~= nil
end

function addon:validate_itemset(prefix, name, itemset, fix)
    if not is_uuid(name) then
        addon:warn("Invalid ID for itemset %s:%s", prefix, name)
        if fix then
            addon.cleanArray(effect)
            return
        end
    end
    local template = {
        modified = false,
        name = "test",
        items = {}
    }
    validate_basic(prefix, itemset, template, fix)
    validate_itemset_items(prefix, name, itemset.items, fix)
end

function addon:validate_effect(prefix, name, effect, fix)
    if not is_uuid(name) then
        addon:warn("Invalid ID for effect %s:%s", prefix, name)
        if fix then
            addon.cleanArray(effect)
            return
        end
    end
    if not effect["type"] then
        addon:warn("No effect type for %s:%s", prefix, name)
        if fix then
            addon.cleanArray(effect)
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
                if type(seq) ~= "string" then
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
                        texture = "some_texture",
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
            addon.cleanArray(announce)
        end
        return
    end

    local template = {
        type = "spell",
        disabled = false,
        announce = "party",
        event = "SUCCEEDED",
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        value = "Some Announce"
    }

    if announce["type"] == "spell" or announce["type"] == "petspell" then
        template["spell"] = 12345
        template["ranked"] = false
    elseif announce["type"] ~= "item" then
        addon:warn("Invalid type for announce %s:%s", prefix, tostring(announce["id"]))
        if fix then
            addon.cleanArray(announce)
            return
        end
    end

    validate_basic(prefix, announce, template, fix)

    if not announce["id"] or not is_uuid(announce["id"]) then
        addon:warn("Invalid ID for announce %s:%s", prefix, tostring(announce["id"]))
        if fix then
            addon.cleanArray(announce)
            return
        end
    end

    if announce["type"] == "item" and announce["item"] ~= nil then
        if type(announce["item"]) == "table" then
            validate_itemset_items(prefix, announce["id"], announce["item"], fix)
        elseif type(announce["item"]) ~= "string" then
            addon:warn("Invalid type for item set for announce %s:%s", prefix, tostring(announce["id"]))
            if fix then
                announce.item = nil
            end
        end
    end
end

function addon:validate_custom_condition(prefix, name, custom_condition, fix)
    validate_basic(prefix .. ":" .. name, custom_condition, addon.empty_condition, fix)

    local function validate_custom_field_spec(parent, spec)
        local toremove = {}
        for k,v in pairs(spec) do
            if type(v) == "string" then
                if not (v == "string" or v == "number" or v == "boolean") then
                    addon:warn("Invalid type in custom funcion type spec %s:%s", parent, k)
                    mark_for_remove(toremove, k)
                end
            elseif type(v) == "table" then
                validate_custom_field_spec(parent .. ":" .. k, v)
            else
                addon:warn("Invalid type in custom funcion type spec %s:%s", parent, k)
                mark_for_remove(toremove, k)
            end
        end
        apply_remove(toremove, spec, fix)
    end

    if custom_condition["fields"] then
        validate_custom_field_spec(prefix .. ":" .. name, custom_condition["fields"])
    end
end

local function validate_rotation_condition(prefix, condition, fix)
    if addon.tablelength(condition) == 0 then
        return
    end

    if type(condition["type"]) ~= "string" then
        addon:warn("Invalid type for %s", prefix)
        if fix then
            addon.cleanArray(condition)
        end
        return
    end

    local full_id = prefix .. ":" .. condition["type"]
    local fields = addon.deepcopy(select(4, addon:describeCondition(condition["type"])))
    -- The condition might not exist if you're not playing a class where it is active.
    if not fields then
        return
    end
    fields["type"] = "string"
    fields["disabled"] = "boolean"

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
                            table.insert(toremove, key)
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
                if addon.tablelength(data) ~= #data then
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
    if id ~= DEFAULT and not is_uuid(id) then
        addon:warn("Invalid ID for rotation %s:%s", prefix, id)
        if fix then
            addon.cleanArray(rotation)
            return
        end
    end

    local template = {
        name = "Some Name",
        disabled = false,
        switch = {},
        cooldowns = {},
        rotation = {}
    }
    validate_basic(prefix .. ":" .. id, rotation, template, fix)

    if id ~= DEFAULT and not rotation["name"] then
        addon:warn("Unnamed non-default rotation %s:%s", prefix, id)
        if fix then
            addon.cleanArray(rotation)
            return
        end
    end

    local rotation_template = {
        use_name = false,
        name = "Some cool name",
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        type = "spell",
        disabled = false,
        conditions = {},
    }

    local cooldown_template = {
        use_name = false,
        name = "Some cool name",
        effect = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        type = "spell",
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

    local function augment_template_type(template, rot)
        if rot["type"] == "spell" then
            template["action"] = 1234
            template["ranked"] = false
        elseif rot["type"] == "petspell" or template["type"] == "anyspell" then
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
            local template = addon.deepcopy(cooldown_template)
            augment_template_type(template, rot)
            validate_basic(prefix .. ":" .. id .. ":cooldown:" .. idx, rot, template, fix)
            if not is_uuid(rot["id"]) then
                addon:warn("Invalid ID for cooldown %s:%d:%d", prefix, id, idx)
                mark_for_remove(toremove, idx)
            end
            if rot["effect"] and not is_uuid(rot["effect"]) then
                addon:warn("Invalid effect ID for cooldown %s:%d:%d", prefix, id, idx)
                if fix then
                    rot["effect"] = nil
                end
            end
            if rot["type"] == "item" then
                if type(rot["action"]) == "table" then
                    validate_itemset_items(prefix .. ":" .. id .. ":cooldown", idx, rot["action"], fix)
                elseif type(rot["action"]) ~= "string" then
                    addon:warn("Invalid type for item action in cooldown %s:%d:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                elseif not is_uuid(rot["action"]) then
                    addon:warn("Invalid itemset ID for cooldown %s:%d:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                end
            end
            if rot["conditions"] then
                validate_rotation_condition( string.format("%s:%s:cooldowns:%d", prefix, id, idx),
                        rot["conditions"], fix)
            end
            if addon.tablelength(rot) == 0 then
                mark_for_remove(toremove, idx)
            end
        end
        apply_remove(toremove, rotation["cooldowns"], fix)
    end

    if rotation["rotation"] then
        local toremove = {}
        for idx, rot in pairs(rotation["rotation"]) do
            local template = addon.deepcopy(rotation_template)
            augment_template_type(template, rot)
            validate_basic(prefix .. ":" .. id .. ":rotation:" .. idx, rot, template, fix)
            if not is_uuid(rot["id"]) then
                addon:warn("Invalid ID for rotation step %s:%d:%d", prefix, id, idx)
                mark_for_remove(toremove, idx)
            end
            if rot["type"] == "item" then
                if type(rot["action"]) == "table" then
                    validate_itemset_items(prefix .. ":" .. id .. ":rotation", idx, rot["action"], fix)
                elseif type(rot["action"]) ~= "string" then
                    addon:warn("Invalid type for item action in rotation %s:%d:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                elseif not is_uuid(rot["action"]) then
                    addon:warn("Invalid itemset ID for rotation %s:%d:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                end
            end
            if rot["conditions"] then
                validate_rotation_condition( string.format("%s:%s:rotation:%d", prefix, id, idx),
                        rot["conditions"], fix)
            end
            if addon.tablelength(rot) == 0 then
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
    local DB = _G[addon_name .. "DB"]

    validate_basic("global", DB.global, template.global, fix)

    if DB.global.itemsets then
        local toremove = {}
        for name, itemset in pairs(DB.global.itemsets) do
            addon:validate_itemset("global", name, itemset, fix)
            if addon.tablelength(itemset) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.itemsets, fix)
    end

    if DB.global.effects then
        local toremove = {}
        for name, effect in pairs(DB.global.effects) do
            addon:validate_effect("global", name, effect, fix)
            if addon.tablelength(effect) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.effects, fix)
    end

    if DB.global.custom_conditions then
        local toremove = {}
        for name, custom_condition in pairs(DB.global.custom_conditions) do
            addon:validate_custom_condition("global", name, custom_condition, fix)
            if addon.tablelength(custom_condition) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.custom_conditions, fix)
    end

    for char, data in pairs(DB.char) do
        validate_basic("char:" .. char, data, template.char, fix)
    end

    for profile, data in pairs(DB.profiles) do
        validate_basic("profile:" .. profile, data, template.profile, fix)

        if data.itemsets then
            local toremove = {}
            for name, itemset in pairs(data.itemsets) do
                addon:validate_itemset("profile:" .. profile, name, itemset, fix)
                if addon.tablelength(itemset) == 0 then
                    mark_for_remove(toremove, name)
                end
            end
            apply_remove(toremove, data.itemsets, fix)
        end

        if data.announces then
            local toremove = {}
            for idx, announce in pairs(data.announces) do
                addon:validate_announce("profile:" .. profile, idx, announce, fix)
                if addon.tablelength(announce) == 0 then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.announces, fix)
        end

        if data.rotations then
            local specremove = {}
            for spec, rotations in pairs(data.rotations) do
                if type(spec) ~= "number" then
                    table.insert(specremove, spec)
                end
                local toremove = {}
                for id, rotation in pairs(rotations) do
                    addon:validate_rotation("profile:" .. profile .. ":" .. spec, id, rotation, fix)
                    if addon.tablelength(rotation) == 0 then
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
    end
end
