local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Public condition entry points accept native editors and compact refresh hosts.
function addon.LayoutConditionFrame(frame)
    if frame and type(frame.rmCompactRefresh) == 'function' then return frame.rmCompactRefresh() end
    return nil, L['Unsupported condition editor frame.']
end

function addon:EditCondition(index, spec, value, callback, targetValid)
    if type(self.ShowConditionEditor) == 'function' then
        return self:ShowConditionEditor(index, spec, value, callback, targetValid)
    end

    return nil, L['The native condition editor is unavailable.']
end
