-- Inverse of the window layering change (docs/architecture/window-layering.md) for the modules whose complete
-- predecessor contents other suites pin: the opens go back to registering for Escape, the window asks for its own
-- click-raise again and the embedded editor's stand-alone panels are no longer laid out with the RM windows.
local patches = {
    ['Integrations/lua_workbench.lua'] = {
        {
            current = [=[    -- The embedded library's stand-alone panels hang from UIParent at DIALOG strata, which is below every RM
    -- window. Whenever one is opened, lay it out with the RM windows, above the editor it came from.
    for _,spec in ipairs({{engine.Inspector,'Show','panel'},{engine.DebugProbe,'ShowTerminal','terminal'},{engine.DebugProbe,'ShowSnapshot','snapshot'},{engine.DebugProbe,'BuildPanel','panel'}}) do
        local object,method,field=spec[1],spec[2],spec[3]
        local original=object and object[method]
        if type(original)=='function' then
            object[method]=function(self,...)
                local function after(...)
                    local panel=self[field]
                    if type(panel)=='table' and panel.IsShown and panel:IsShown() then rm:OpenPopup({frame=panel},frame,{escape=false}) end
                    return ...
                end
                return after(original(self,...))
            end
        end
    end
]=],
            old = '',
        },
    },
    ['UI/custom_condition_editor.lua'] = {
        {
            current = [=[frame:SetSize(960,740);frame:SetPoint('CENTER');frame:SetClampedToScreen(true);self:MakeWindowOpaque(frame)]=],
            old = [=[frame:SetSize(960,740);frame:SetPoint('CENTER');frame:SetToplevel(true);frame:SetClampedToScreen(true);self:MakeWindowOpaque(frame)]=],
        },
        {
            current = [=[self:ShowFooter(true);if not self.embedded then addon:OpenPopup(self) end end end]=],
            old = [=[self:ShowFooter(true);if not self.embedded then addon:RegisterWindowForEscape(self) end end end]=],
        },
        {
            current = [=[p.prompt.frame:SetParent(UIParent);addon:OpenPopup(p.prompt,d)]=],
            old = [=[p.prompt.frame:SetParent(UIParent);addon:RegisterWindowForEscape(p.prompt)]=],
        },
        {
            current = [=[d.cancel:SetText(L['Cancel']);addon:OpenPopup(d)]=],
            old = [=[d.cancel:SetText(L['Cancel']);addon:RegisterWindowForEscape(d)]=],
        },
    },
}

return function(text, path)
    for _, patch in ipairs(patches[path] or {}) do
        local first, last = text:find(patch.current, 1, true)
        assert(first and not text:find(patch.current, last + 1, true), 'missing or repeated window layering change')
        text = text:sub(1, first - 1) .. patch.old .. text:sub(last + 1)
    end

    return text
end
