local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:BuildIntegrationSettings(p)
    local profile=p:SettingsData().profile
    p:Heading(L['Lua editor'])
    local entries=self:ListLuaEditorProviders();local selected=profile.lua_editor or 'auto';local known=false
    for _,entry in ipairs(entries) do if entry.value==selected then known=true end end
    if not known then entries[#entries+1]={value=selected,text=selected..' ('..L['Unavailable']..')'} end
    p:Choice('lua_editor',L['Editor'],selected,entries,function(value) profile.lua_editor=value end)
    p:Check('lua_line_numbers',L['Show line numbers'],profile.lua_line_numbers~=false,function(value) profile.lua_line_numbers=value end)
    p:Text(L['Line-number visibility applies to every condition and function code editor.'])
    p:Text(L['Automatic uses an available editor integration, with built-in syntax highlighting as its fallback. Plain text disables highlighting. Apply changes the editor used the next time you open a custom condition.'])
    p:Heading(L['Questie'])
    p:Check('questie_enabled',L['Enable Questie integration'],profile.questie_enabled==true,function(value)
        profile.questie_enabled=value
        p:RunSettingsEffect('questie',function() self:SyncQuestieIntegration() end)
    end)
    local status=self.GetQuestieIntegrationStatus and self:GetQuestieIntegrationStatus() or {state='unavailable'}
    local states={disabled=L['Disabled'],missing=L['Not loaded.'],waiting=L['Waiting for Questie.'],
        incompatible=L['Questie API incompatible.'],available=L['Questie callback connection available.'],
        ['client-restricted']=L['Questie values are restricted by this client.'],
        error=L['Questie integration unavailable after an adapter error.'],unavailable=L['Questie adapter unavailable.']}
    p:Text(states[status.state] or L['Questie adapter unavailable.'])
    if status.version then
        p:Text(string.format(L['Questie version: %s (%s)'],status.version:gsub('|','||'),status.versionStatus=='source-tested' and L['source-tested'] or L['unverified']))
    end
    if status.family then
        p:Text(string.format(L['Client family: %s (%s)'],status.family,status.familyContract=='declared-unverified' and L['declared; unverified'] or L['unsupported']))
    end
    p:Text(L['Native acceptance: unverified. Coverage: recent update receipts only; no quest progress, completion or rotation selection.'])
    p:Text(L['Questie is optional and disabled by default. Apply saves this profile preference. No background polling is used.'])
    p:Button('questie_refresh',L['Refresh Questie status'],function() self:RefreshQuestieIntegration();p:Draw() end)
    p:Heading(L['Supported addons'])
    local inventoryStates={missing=L['Not loaded.'],loaded=L['Loaded; connection not confirmed.'],
        connected=L['Connected'],disabled=L['Disabled'],incompatible=L['Incompatible'],unknown=L['Unknown']}
    for _,entry in ipairs(self.ListIntegrationStatus and self:ListIntegrationStatus() or {}) do
        local label=entry.name
        if entry.version then label=string.format(L['%s (version %s)'],label,entry.version) end
        p:Text(string.format(L['%s: %s'],label,inventoryStates[entry.state] or L['Unknown']))
        if entry.detail then p:Text(entry.detail) end
    end
    p:Text(L['Supported addons are listed even when missing. Loaded addons are only marked connected when their integration is available.'])
end
