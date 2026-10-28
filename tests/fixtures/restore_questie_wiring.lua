-- Invert only reviewed Questie startup/profile wiring before historical proofs.
local paths = {
    ["main.lua"] = {
        {
            old = [====[        lua_line_numbers = true,
]====],
            new = [====[        lua_line_numbers = true,
        questie_enabled = false,
]====],
        },
        {
            old = [====[function addon:OnInitializeInternal()
]====],
            new = [====[-- One optional-provider lifetime, independent of the rotation event owner.
-- Settings only publish saved preferences through SyncQuestieIntegration.
local questieService,questieEvents,questieEnabled
function addon:InitializeQuestieIntegration()
    if questieService then return end
    local factory=self.Integrations and self.Integrations.NewQuestie
    if type(factory)~='function' then return end
    questieService=factory()
    self:SyncQuestieIntegration()
end
function addon:SyncQuestieIntegration()
    if not questieService then return false end
    local enabled=self.db and self.db.profile and self.db.profile.questie_enabled==true or false
    if enabled==questieEnabled then return true end
    questieEnabled=enabled
    if enabled then
        if not questieEvents then
            questieEvents=CreateFrame('Frame')
            questieEvents:SetScript('OnEvent',function(_,event,name)
                if event=='ADDON_LOADED' and name=='Questie' and questieEnabled then questieService:Refresh() end
            end)
        end
        questieEvents:RegisterEvent('ADDON_LOADED')
    elseif questieEvents then questieEvents:UnregisterEvent('ADDON_LOADED') end
    questieService:SetEnabled(enabled)
    return true
end
function addon:GetQuestieIntegrationStatus()
    if questieService then return questieService:GetStatus() end
    return {state='unavailable',reason='adapter-unavailable',nativeAcceptance='unverified'}
end
function addon:RefreshQuestieIntegration()
    if questieService and questieEnabled then return questieService:Refresh() end
    return self:GetQuestieIntegrationStatus()
end

function addon:OnInitializeInternal()
]====],
        },
        {
            old = [====[    --self:SetupOptions()
]====],
            new = [====[    self:InitializeQuestieIntegration()

    --self:SetupOptions()
]====],
        },
    },
    ["Core/rotation_lifecycle.lua"] = {
        {
            old = [====[function addon:RefreshRotationProfileStorage()
]====],
            new = [====[function addon:RefreshRotationProfileStorage()
    if self.SyncQuestieIntegration then self:SyncQuestieIntegration() end
]====],
        },
    },
    ["UI/settings_collections.lua"] = {
        {
            old = [====[    local build=builders[key];if not build then return end
    local p=cached or self:CreateSettingsForm(parent)
    local scopes={Integrations={profile={'lua_editor','lua_line_numbers'}},Effects={global={'effects'}},ItemSets={profile={'itemsets'},global={'itemsets'}},Announces={profile={'announces'}},Conditions={profile={'condition_groups','switch_conditions','other_conditions_order','disabled_conditions'},global={'custom_conditions'}},General={profile={'enable','poll','ignore_mana','ignore_range','effect','color','magnification','setpoint','xoffs','yoffs','loglevel','detailed_profiling','disable_autoswitch','live_config_update','spell_history','combat_history','damage_history','disable_buttons','rotation_view','preview_spells','preview_vertical','preview_locked','preview_opacity','preview_icon_size','preview_window','minimap'},char={'specs'}}}
    scopes.Functions={global={'custom_functions'}}
    p.settingsKey=key;p.historyEnabled=key=='ItemSets';p.transactionKeys=scopes[key];p:SetWidth(parent:GetWidth());p:SetHeight(parent:GetHeight());p:Open(function(form) build(self,form) end);return p
]====],
            new = [====[    local build=builders[key];if not build then return end
    local p=cached or self:CreateSettingsForm(parent)
    local scopes={Integrations={profile={'lua_editor','lua_line_numbers','questie_enabled'}},Effects={global={'effects'}},ItemSets={profile={'itemsets'},global={'itemsets'}},Announces={profile={'announces'}},Conditions={profile={'condition_groups','switch_conditions','other_conditions_order','disabled_conditions'},global={'custom_conditions'}},General={profile={'enable','poll','ignore_mana','ignore_range','effect','color','magnification','setpoint','xoffs','yoffs','loglevel','detailed_profiling','disable_autoswitch','live_config_update','spell_history','combat_history','damage_history','disable_buttons','rotation_view','preview_spells','preview_vertical','preview_locked','preview_opacity','preview_icon_size','preview_window','minimap'},char={'specs'}}}
    scopes.Functions={global={'custom_functions'}}
    p.settingsKey=key;p.historyEnabled=key=='ItemSets';p.transactionKeys=scopes[key];p:SetWidth(parent:GetWidth());p:SetHeight(parent:GetHeight());p:Open(function(form) build(self,form) end);return p
]====],
        },
    },
}

return function(text, path)
    if path == 'UI/settings_collections.lua' and text:find('lua_editor_disabled', 1, true) then
        text = dofile('tests/fixtures/restore_integration_settings.lua')(path, text)
    end

    local rows = assert(paths[path], 'unknown Questie wiring inverse path')

    for _, row in ipairs(rows) do
        local a, b = text:find(row.new, 1, true)
        assert(a, 'Questie wiring block changed: ' .. path)
        assert(not text:find(row.new, b + 1, true), 'duplicate Questie wiring block')
        text = text:sub(1, a - 1) .. row.old .. text:sub(b + 1)
    end

    return text
end
