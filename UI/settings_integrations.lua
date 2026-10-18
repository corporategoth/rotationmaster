local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:BuildIntegrationSettings(p)
    local profile=p:SettingsData().profile
    p:Heading(L['Lua editor'])
    local entries=self:ListLuaEditorProviders();local selected=profile.lua_editor or 'auto';local known=false
    for _,entry in ipairs(entries) do if entry.value==selected then known=true end end
    if not known then entries[#entries+1]={value=selected,text=selected..' ('..L['Unavailable']..')'} end
    p:Choice('lua_editor',L['Editor'],selected,entries,function(value) profile.lua_editor=value end)
    p:Text(L['Automatic uses an available editor integration, with built-in syntax highlighting as its fallback. Plain text disables highlighting. Apply changes the editor used the next time you open a custom condition.'])
    p:Heading(L['Optional addons'])
    local loaded=C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    for _,entry in ipairs({{'!!!LuaWorkbench','LuaWorkbench'},{'WowLua','WowLua'}}) do
        local ok,present=false,false;if type(loaded)=='function' then ok,present=pcall(loaded,entry[1]) end
        p:Text(entry[2]..': '..(ok and present and L['Loaded; editor integration not connected.'] or L['Not loaded.']))
    end
    p:Text(L['These addons are optional. Only connected editor providers appear in the Editor menu. Choosing an unavailable or failing editor falls back to the built-in editor.'])
end
