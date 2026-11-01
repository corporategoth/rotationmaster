-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Optional use of the installed WowLua syntax engine on an RM-owned editor.
local _, addon = ...

function addon:IsWowLuaIntegrationAvailable()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if type(loaded) ~= 'function' then return false end
    local ok, value = pcall(loaded, 'WowLua')
    local syntax = type(_G.WowLua) == 'table' and _G.WowLua.indent
    return ok and value == true and type(syntax) == 'table'
        and type(syntax.enable) == 'function' and type(syntax.disable) == 'function'
        and type(syntax.decode) == 'function' and type(syntax.colorCodeEditbox) == 'function'
end

local discover = addon.DiscoverLuaEditorIntegrations
function addon:DiscoverLuaEditorIntegrations()
    if discover then discover(self) end
    if not self.RegisterLuaEditorProvider or not self:IsWowLuaIntegrationAvailable() then return end
    self:RegisterLuaEditorProvider('WowLua', function(parent, changed, valid)
        if not self:IsWowLuaIntegrationAvailable() then return nil end
        local control = self:CreateWorkbenchLuaEditor(parent, changed, valid, 'plain')
        local syntax = _G.WowLua.indent
        local colors = {}
        for token, color in pairs(syntax.defaultColorTable or {}) do
            colors[token] = type(color) == 'string' and color:gsub('^|c00', '|cff') or color
        end
        local ok, err = pcall(syntax.enable, control.edit, colors, 4)
        if not ok then
            pcall(syntax.disable, control.edit)
            control:Release()
            error(err)
        end
        control.syntax, control.syntaxColors = syntax, colors

        -- WowLua normally waits until typing stops for 0.2 seconds. Queue one recolor for the next frame instead,
        -- outside the native text-change callback, and suppress synthetic change notifications during repaint.
        local pending, painting = false, false
        control.edit:HookScript('OnTextChanged', function()
            if not painting and not control.released then pending = true end
        end)
        control.edit:HookScript('OnUpdate', function()
            if not pending or control.released or painting then return end
            pending, painting = false, true
            local previousSetting = control.setting
            control.setting = true
            local colored, why = pcall(syntax.colorCodeEditbox, control.edit)
            control.setting, painting = previousSetting, false
            if not colored then error(why) end
        end)
        return control
    end)
end
