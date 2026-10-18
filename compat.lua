local addon_name, addon = ...

-- Modern clients identify Settings panels by category ID. Keep frame.name in
-- sync so child panels and AceConfigDialog can find the registered parent.
function addon:RegisterOptionsCategory(frame)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category
        if frame.parent then
            category = Settings.RegisterCanvasLayoutSubcategory(Settings.GetCategory(frame.parent), frame, frame.name)
        else
            category = Settings.RegisterCanvasLayoutCategory(frame, frame.name)
            Settings.RegisterAddOnCategory(category)
        end
        frame.name = category.ID
    else
        InterfaceOptions_AddCategory(frame)
    end
end

function addon:OpenOptions(frame)
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(frame.name)
    else
        -- Legacy Interface Options needs a second call to select a child panel.
        InterfaceOptionsFrame_OpenToCategory(frame)
        InterfaceOptionsFrame_OpenToCategory(frame)
    end
end
