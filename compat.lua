-- Compatibility shims for the options panel API that differs between clients: the Settings category API on modern
-- clients, InterfaceOptions on clients that predate it.
-- Loaded from RotationMaster.toc after the Platform adapters and before the libraries and constants. It owns only
-- these two wrappers; the launcher that calls them is UI/settings_setup.lua. It must not touch saved data.
local addon_name, addon = ...

-- Registers an options panel frame with the client's options UI.
-- @param frame table  The options panel frame; frame.parent, when set, makes it a subcategory.
--
-- Registers it as a Settings category (a subcategory when frame.parent is set), or with the legacy InterfaceOptions
-- list on clients without the Settings API. Modern clients identify Settings panels by category ID, so frame.name is
-- overwritten with it for native child panels to find the registered parent.
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

-- Opens the options panel for a frame.
-- @param frame table  The options panel frame; it is selected by the name RegisterOptionsCategory left on it.
function addon:OpenOptions(frame)
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(frame.name)
    else
        -- Legacy Interface Options needs a second call to select a child panel.
        InterfaceOptionsFrame_OpenToCategory(frame)
        InterfaceOptionsFrame_OpenToCategory(frame)
    end
end
