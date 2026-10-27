-- Import/export dialog for one custom (Lua) condition, opened from the native custom condition editor. It encodes the
-- condition as an RM-CustomCondition text, lets the player paste one back, and hands a parsed import to the editor
-- only after an explicit "this contains Lua code" confirmation; it never saves or runs the imported code itself.
-- Conditions that carry function bindings are routed to the dependency-bundle review in
-- UI/function_bundle_transfer.lua instead. Loaded from the UI/ block of RotationMaster.toc, after
-- settings_transfer.lua.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Opens the transfer dialog for condition `key` over its editor `parent`; `update` is the editor's refresh callback.
-- Returns the dialog widget, or nil and a reason when the parent is not a native custom editor. While it is open the
-- parent editor is hidden, and it is shown again on close only if the editor is still resumable.
function addon:ShowCustomConditionTransfer(parent, update, key, condition)
    if not parent or parent.nativeCustomEditor ~= true then
        return nil, L['Native custom condition editor required.']
    end

    local owner = parent.rmConditionOwner
    if not owner then return end

    if parent.nativeCustomEditor and self.ShowConditionFunctionBundleTransfer and condition.bindings and next(
        condition.bindings
    ) then
        return self:ShowConditionFunctionBundleTransfer(parent, update, key, condition)
    end

    local codec = self:NewRotationCodec()

    local text, why = codec:Encode({
        format = 'RM-CustomCondition',
        version = 1,
        name = key or '',
        condition = condition,
    })

    if not text then return nil, why end
    local p = parent.rmCustomTransferForm

    if p then
        p:Release()
    else
        local host = CreateFrame('Frame', nil, UIParent)
        host:SetSize(1, 1)
        host:Hide()
        p = self:CreateSettingsForm(host)
        parent.rmCustomTransferForm = p
    end

    p:Open(function() end)
    parent:SetCallback('OnClose', function() end)

    if parent.HideForChild then
        parent:HideForChild()
    else
        parent:Hide()
    end

    -- True while the parent editor and its owner window are still the ones this dialog was opened over.
    local function valid()
        return addon:CanResumeCustomConditionDialog(parent, owner)
    end

    local dialog

    local options = {
        canReplace = key ~= nil and self.db.global.custom_conditions[key] ~= nil,
        selectedName = key,
        fallbackName = L['IMPORTED_CONDITION'],
        valid = valid,
        originalName = function(input)
            local parsed = self:ParseCustomConditionImport(input, codec)
            return parsed and parsed.name
        end,
        review = {
            kind = 'customcondition',
            parse = function(input)
                local parsed, why = self:ParseCustomConditionImport(input, codec)

                if not parsed then
                    if self.ParseFunctionBundleImport and self:ParseFunctionBundleImport(input, codec) then
                        return nil, L['This is a dependency bundle. Import opens the bundle review.']
                    end

                    return nil, why
                end

                local record = self:CopySettingsData(parsed.condition)
                record.name = parsed.name
                return record
            end,
            current = function()
                local record = self:CopySettingsData(condition)
                record.name = key
                return record
            end,
            problems = function(record, dialog)
                local list = {}
                local destination = dialog.mode == 'replace' and key or dialog.name:GetText()

                if not self:IsCustomConditionIdentifier(destination, dialog.mode == 'replace') then
                    list[#list + 1] = L['Use letters, numbers and underscores for the condition identifier.']
                elseif dialog.mode == 'new' and self:describeCondition(destination) ~= nil then
                    list[#list + 1] = L['That condition identifier already exists.']
                end

                return list
            end,
            notes = function()
                return {
                    L['This import contains Lua code. Only continue if you trust its author. Import opens the code for review; saving the condition can execute it.'],
                }
            end,
        },
        onClose = function()
            if dialog then
                owner.widgets[dialog] = nil
                dialog.rmConditionOwner = nil
            end

            if p.active then p:Release() end
            if valid() then parent:Show() end
        end,
    }

    dialog = self:ShowSettingsTextTransfer(
        p,
        L['Import/Export Condition'],
        text,
        function(input, settings)
            local parsed, errorText = self:ParseCustomConditionImport(input, codec)

            if not parsed then
                if parent.nativeCustomEditor and self.ShowConditionFunctionBundleTransfer then
                    local bundle = self:ParseFunctionBundleImport(input, codec)

                    if bundle and bundle.root.kind == 'condition' then
                        dialog.frame:Hide()
                        self:ShowConditionFunctionBundleTransfer(parent, update, key, condition, input)
                        return false, L['Review the dependency bundle before applying it.']
                    end
                end

                return false, errorText
            end

            local destination = settings.mode == 'replace' and key or settings.name

            if not self:IsCustomConditionIdentifier(destination, settings.mode == 'replace') then
                return false, L['Use letters, numbers and underscores for the condition identifier.']
            end

            if settings.mode == 'new' and self:describeCondition(destination) ~= nil then
                return false, L['That condition identifier already exists.']
            end

            local serial = dialog.serial

            p:Confirm(
                L['This import contains Lua code. Only continue if you trust its author. Import opens the code for review; saving the condition can execute it.'],
                function()
                    if not valid() or dialog.serial ~= serial or dialog.input:GetText() ~= input then return end
                    self:LayoutCustomConditionEditor(parent, update, destination, parsed.condition)
                    dialog.frame:Hide()
                end
            )

            p.prompt.frame:SetParent(UIParent)
            self:OpenPopup(p.prompt, p)
            return false, L['Confirm the Lua import, then review it before saving.']
        end,
        options
    )

    -- Lets the owner window's dismissal path hide this dialog like any other registered widget.
    function dialog:Hide()
        self.frame:Hide()
    end

    dialog.rmConditionOwner = owner
    owner.widgets[dialog] = true
    return dialog
end
