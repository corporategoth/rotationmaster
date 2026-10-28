-- Strict test-only inverse of exactly FORM print and widget metadata repairs.
local old = {
    print = '\n'
        .. [=[
        local form
        if value.value ~= nil then
            if value.value == 0 then
                form = L["humanoid"]
            elseif character_class == "SHAMAN" then
                form = select(1, GetSpellInfo("Ghost Wolf"))
            else
                form = GetSpellInfo(select(4, GetShapeshiftFormInfo(value.value)))
            end
        end
        return string.format(L["you {{!are|are not}} in %s form"], Functions.presentation.nullable(form, L["<form>"]))
    ]=],
    widget = '\n'
        .. [=[
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local forms = {}
        local formsOrder = {}

        forms["0"] = L["humanoid"]
        table.insert(formsOrder, "0")
        if character_class == "SHAMAN" then
            forms["1"] = select(1, GetSpellInfo("Ghost Wolf"))
            table.insert(formsOrder, tostring("1"))
        else
            for i=1,GetNumShapeshiftForms() do
                local spellid = select(4, GetShapeshiftFormInfo(i))
                if spellid == nil then
                    break
                end
                forms[tostring(i)] = GetSpellInfo(spellid)
                table.insert(formsOrder, tostring(i))
            end
        end

        local formIcon = addon:CreateConditionIcon()
        local function set_form_icon()
            if value.value ~= nil then
                if value.value == 0 then
                    formIcon:SetImage("Interface\\Icons\\inv_misc_head_human_02")
                else
                    if character_class == "SHAMAN" then
                        if value.value == 1 then
                            formIcon:SetImage(GetSpellTexture("Ghost Wolf"))
                        end
                    else
                        formIcon:SetImage(GetShapeshiftFormInfo(value.value))
                    end
                end
            else
                formIcon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
            end
        end

        formIcon:SetWidth(44)
        formIcon:SetHeight(44)
        formIcon:SetImageSize(36, 36)
        set_form_icon()
        parent:AddChild(formIcon)

        local form = addon:CreateConditionDropdown()
        form:SetLabel(L["Form"])
        form:SetCallback("OnValueChanged", function(_, _, v)
            value.value = tonumber(v)
            form:SetValue(v)
            set_form_icon()
            top:SetStatusText(funcs:print(root, spec))
        end)
        form.configure = function()
            form:SetList(forms, formsOrder)
            if (value.value) then
                form:SetValue(tostring(value.value))
            end
        end
        parent:AddChild(form)
    ]=],
}

local repaired = {
    print = '\n'
        .. [=[
        local form
        if value.value ~= nil then
            if value.value == 0 then
                form = L["humanoid"]
            elseif character_class == "SHAMAN" then
                local info = addon.Platform:GetSpellInfo("Ghost Wolf")
                form = info and info.name
            else
                local info = addon.Platform:GetSpellInfo(select(4, GetShapeshiftFormInfo(value.value)))
                form = info and info.name
            end
        end
        return string.format(L["you {{!are|are not}} in %s form"], Functions.presentation.nullable(form, L["<form>"]))
    ]=],
    widget = '\n'
        .. [=[
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local forms = {}
        local formsOrder = {}

        forms["0"] = L["humanoid"]
        table.insert(formsOrder, "0")
        if character_class == "SHAMAN" then
            local info = addon.Platform:GetSpellInfo("Ghost Wolf")
            forms["1"] = info and info.name or L["<form>"]
            table.insert(formsOrder, tostring("1"))
        else
            for i=1,GetNumShapeshiftForms() do
                local spellid = select(4, GetShapeshiftFormInfo(i))
                if spellid == nil then
                    break
                end
                local info = addon.Platform:GetSpellInfo(spellid)
                forms[tostring(i)] = info and info.name or L["<form>"]
                table.insert(formsOrder, tostring(i))
            end
        end

        local formIcon = addon:CreateConditionIcon()
        local function set_form_icon()
            if value.value ~= nil then
                if value.value == 0 then
                    formIcon:SetImage("Interface\\Icons\\inv_misc_head_human_02")
                else
                    if character_class == "SHAMAN" then
                        if value.value == 1 then
                            local info = addon.Platform:GetSpellInfo("Ghost Wolf")
                            formIcon:SetImage(info and info.iconID or "Interface\\Icons\\INV_Misc_QuestionMark")
                        end
                    else
                        formIcon:SetImage(GetShapeshiftFormInfo(value.value))
                    end
                end
            else
                formIcon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
            end
        end

        formIcon:SetWidth(44)
        formIcon:SetHeight(44)
        formIcon:SetImageSize(36, 36)
        set_form_icon()
        parent:AddChild(formIcon)

        local form = addon:CreateConditionDropdown()
        form:SetLabel(L["Form"])
        form:SetCallback("OnValueChanged", function(_, _, v)
            value.value = tonumber(v)
            form:SetValue(v)
            set_form_icon()
            top:SetStatusText(funcs:print(root, spec))
        end)
        form.configure = function()
            form:SetList(forms, formsOrder)
            if (value.value) then
                form:SetValue(tostring(value.value))
            end
        end
        parent:AddChild(form)
    ]=],
}

local signatures = { print = 'print = function(_, value)', widget = 'widget = function(parent, spec, value)' }

local function inverse(text, callback)
    assert(type(text) == 'string', 'form metadata inverse needs text')

    if callback ~= nil then
        assert(repaired[callback] and text == repaired[callback], 'unexpected FORM callback body')
        return old[callback]
    end

    for _, name in ipairs({ 'print', 'widget' }) do
        local from = signatures[name] .. repaired[name] .. 'end,'
        local to = signatures[name] .. old[name] .. 'end,'
        local first, last = text:find(from, 1, true)
        assert(first and not text:find(from, last + 1, true), 'unexpected FORM metadata callback count: ' .. name)
        text = text:sub(1, first - 1) .. to .. text:sub(last + 1)
    end

    return text
end

return inverse, old, repaired
