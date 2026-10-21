local outer=dofile('tests/fixtures/restore_final_composition.lua')
-- Exact integration stages for two independently reviewed revision slices.
local overlaps={
 ['tests/fixtures/addon.lua']={current=[=[-- Explicit external boundaries; production constants/utilities/help stay real.
local F = {}
function F.new(product, expansion, class)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.WOW_PROJECT_MAINLINE, env.WOW_PROJECT_CLASSIC = 1, 2
    env.WOW_PROJECT_BURNING_CRUSADE_CLASSIC,env.WOW_PROJECT_MISTS_CLASSIC=5,19
    env.WOW_PROJECT_WRATH_CLASSIC,env.WOW_PROJECT_CATACLYSM_CLASSIC,env.WOW_PROJECT_CAMELOT=11,14,18
    env.WOW_PROJECT_ID, env.LE_EXPANSION_LEVEL_CURRENT = product or 5, expansion or 1
    env.NORMAL_FONT_COLOR_CODE, env.DEFAULT, env.DELETE, env.NAME = '', 'Default', 'Delete', 'Name'
    env.PRIMARY, env.SECONDARY = 'Primary', 'Secondary'
    env.EDIT, env.COMBAT, env.HEALTH, env.MANA = 'Edit', 'Combat', 'Health', 'Mana'
    env.Enum = {PowerType = {Mana=0, Rage=1, Energy=3, Balance=26, Runes=5, SoulShards=7, Chi=12, ArcaneCharges=16, ComboPoints=4}}
    env.UnitClass = function() return class or 'Shaman', class or 'SHAMAN' end
    env.GetTime = function() return 100 end
    local addon = {help_funcs = {}, longtermCache = {}, unitsInRange = {}, currentSpec = 0,
                   db = {profile = {}, global = {}}, definitions = {}}
    local translations = {}
    local L = setmetatable({}, {
        __index = function(_, key) return translations[key] or key end,
        __newindex = function(_, key, value) translations[key] = value == true and key or value end,
    })
    local function widget(kind)
        local w = {kind=kind, children={}}
        function w:AddChild(child) assert(child); self.children[#self.children+1]=child end
        function w:SetText(text) self.text=text end
        function w:SetLayout(layout) self.layout=layout end
        function w:SetFullWidth(value) self.fullWidth=value end
        function w:SetFullHeight(value) self.fullHeight=value end
        function w:SetUserData(key,value) self[key]=value end
        function w:GetUserData(key) return self[key] end
        function w:SetLabel(value) self.label=value end
        function w:SetTitle(value) self.title=value end
        function w:SetValue(value) self.value=value end
        function w:SetIsPercent(value) self.isPercent=value end
        function w:SetSliderValues(minimum,maximum,step) self.sliderValues={minimum,maximum,step} end
        function w:SetDisabled(value) self.disabled=value end
        function w:SetStatusText(value) self.statusText=value end
        function w:SetCallback(event,callback) self.callbacks=self.callbacks or {};self.callbacks[event]=callback end
        function w:SetImage(value) self.image=value end
        function w:SetImageSize(width,height) self.imageWidth,self.imageHeight=width,height end
        function w:SetHeight(value) self.height=value end
        function w:SetWidth(value) self.width=value end
        function w:SetFont(...) self.font={...} end
        function w:SetFontObject(value) self.font=value end
        return w
    end
    local libraries = {
        ['AceLocale-3.0'] = {GetLocale=function() return L end, NewLocale=function() return L end},
        ['AceConsole-3.0'] = {}, ['LibCompress'] = {},
        ['LibClassicDurations'] = {},
        ['LibRangeCheck-3.0'] = {},
    }
    env.LibStub = function(name) return assert(libraries[name], 'Unexpected library '..name) end
    function addon:RegisterCondition(tag, definition) self.definitions[tag]=definition end
    local function load(path)
        local chunk=assert(loadfile(path)); setfenv(chunk, env)
        if path=='Data/plain.lua' then chunk('rotationmaster',addon);return load('Data/rotation_revision.lua') end
        return chunk('rotationmaster',addon)
    end
    dofile('tests/fixtures/native_ui.lua')(env)
    load('globals.lua');load('Core/dependency_revisions.lua');load('Platform/client.lua');load('Platform/rotation_owner.lua');load('Platform/groups.lua');load('Platform/roster_class.lua');load('Platform/role.lua');load('Platform/mobinfo2.lua');load('Platform/casting.lua');load('Platform/unit_health.lua');load('Platform/unit_stat.lua');load('Platform/health_forecast.lua');load('Platform/unit_level.lua');load('Platform/unit_power.lua');load('Platform/player_movement.lua');load('Platform/unit_attackability.lua');load('Platform/unit_flags.lua');load('Platform/player_flags.lua');load('Platform/form.lua');load('Platform/points.lua');load('Platform/runes.lua');load('Platform/unit_identity.lua');load('Platform/unit_metadata.lua');load('Platform/creature_type.lua');load('Platform/unit_presence.lua');load('Platform/pet.lua');load('Platform/threat.lua');load('Platform/instance.lua');load('Platform/zone_pvp.lua');load('Platform/loss_of_control.lua');load('Platform/items.lua');load('Platform/glyphs.lua');load('Platform/specializations.lua')
    load('Locales/enUS.lua'); load('constants.lua');load('Data/artwork.lua');load('Functions/values.lua');load('Functions/presentation.lua');load('Functions/text.lua');load('Functions/collections.lua');load('Functions/cache.lua');load('Functions/trends.lua');load('Functions/forecast.lua'); load('utils.lua');load('Core/level_conditions.lua');load('Core/point_conditions.lua');load('Core/class_group_conditions.lua');load('Core/creature_conditions.lua');load('Core/health_forecast_conditions.lua');load('Core/threat_count_conditions.lua')
    load('UI/controls.lua');load('UI/condition_widgets.lua');load('UI/condition_observation.lua');load('UI/condition_icon.lua');load('UI/condition_position.lua');load('UI/condition_display.lua');load('UI/drag_presentation.lua');load('Core/unsaved_changes.lua');load('UI/unsaved.lua');load('Core/stock_targets.lua');load('UI/stock_profile_safety.lua');load('UI/settings_stock.lua');load('UI/settings_draft.lua');load('UI/collection_compare.lua');load('UI/draft_changes.lua');load('UI/draft_change_controls.lua');load('UI/window.lua');load('UI/selector.lua');load('UI/tag_picker.lua');load('UI/checkbox.lua');load('UI/condition_inputs.lua');load('UI/condition_layout.lua');load('UI/condition_table.lua');load('UI/condition_unit.lua');load('Core/item_conditions.lua');load('Core/rotation_references.lua');load('Help/common.lua'); load('Help/conditional.lua'); load('Core/presentation.lua');load('Core/condition_description.lua'); load('Core/spell_catalog.lua');load('Core/spell_search.lua');load('Core/reference_catalog.lua');load('Core/category_data.lua');load('Core/announcement_data.lua');load('Core/profile_data.lua');load('Core/collection_data.lua');load('Core/custom_condition_data.lua');load('Core/functions.lua');load('UI/spell_search.lua');load('UI/spell_icon.lua')
    return {env=env, addon=addon, load=load, widget=widget, translations=translations, libraries=libraries}
end
function F.text(widget)
    local parts={widget.text or ''}
    for _, child in ipairs(widget.children or {}) do parts[#parts+1]=F.text(child) end
    return table.concat(parts, '\n')
end
function F.suite()
    local failed,passed=0,0
    return function(name, body)
        local ok,err=pcall(body)
        if ok then passed=passed+1; print('PASS '..name)
        else failed=failed+1; print('FAIL '..name..': '..tostring(err)) end
    end, function() print(passed..' passed, '..failed..' failed'); os.exit(failed>0 and 1 or 0) end
end
return F
]=],persistent=[=[-- Explicit external boundaries; production constants/utilities/help stay real.
local F = {}
function F.new(product, expansion, class)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.WOW_PROJECT_MAINLINE, env.WOW_PROJECT_CLASSIC = 1, 2
    env.WOW_PROJECT_BURNING_CRUSADE_CLASSIC,env.WOW_PROJECT_MISTS_CLASSIC=5,19
    env.WOW_PROJECT_WRATH_CLASSIC,env.WOW_PROJECT_CATACLYSM_CLASSIC,env.WOW_PROJECT_CAMELOT=11,14,18
    env.WOW_PROJECT_ID, env.LE_EXPANSION_LEVEL_CURRENT = product or 5, expansion or 1
    env.NORMAL_FONT_COLOR_CODE, env.DEFAULT, env.DELETE, env.NAME = '', 'Default', 'Delete', 'Name'
    env.PRIMARY, env.SECONDARY = 'Primary', 'Secondary'
    env.EDIT, env.COMBAT, env.HEALTH, env.MANA = 'Edit', 'Combat', 'Health', 'Mana'
    env.Enum = {PowerType = {Mana=0, Rage=1, Energy=3, Balance=26, Runes=5, SoulShards=7, Chi=12, ArcaneCharges=16, ComboPoints=4}}
    env.UnitClass = function() return class or 'Shaman', class or 'SHAMAN' end
    env.GetTime = function() return 100 end
    local addon = {help_funcs = {}, longtermCache = {}, unitsInRange = {}, currentSpec = 0,
                   db = {profile = {}, global = {}}, definitions = {}}
    local translations = {}
    local L = setmetatable({}, {
        __index = function(_, key) return translations[key] or key end,
        __newindex = function(_, key, value) translations[key] = value == true and key or value end,
    })
    local function widget(kind)
        local w = {kind=kind, children={}}
        function w:AddChild(child) assert(child); self.children[#self.children+1]=child end
        function w:SetText(text) self.text=text end
        function w:SetLayout(layout) self.layout=layout end
        function w:SetFullWidth(value) self.fullWidth=value end
        function w:SetFullHeight(value) self.fullHeight=value end
        function w:SetUserData(key,value) self[key]=value end
        function w:GetUserData(key) return self[key] end
        function w:SetLabel(value) self.label=value end
        function w:SetTitle(value) self.title=value end
        function w:SetValue(value) self.value=value end
        function w:SetIsPercent(value) self.isPercent=value end
        function w:SetSliderValues(minimum,maximum,step) self.sliderValues={minimum,maximum,step} end
        function w:SetDisabled(value) self.disabled=value end
        function w:SetStatusText(value) self.statusText=value end
        function w:SetCallback(event,callback) self.callbacks=self.callbacks or {};self.callbacks[event]=callback end
        function w:SetImage(value) self.image=value end
        function w:SetImageSize(width,height) self.imageWidth,self.imageHeight=width,height end
        function w:SetHeight(value) self.height=value end
        function w:SetWidth(value) self.width=value end
        function w:SetFont(...) self.font={...} end
        function w:SetFontObject(value) self.font=value end
        return w
    end
    local libraries = {
        ['AceLocale-3.0'] = {GetLocale=function() return L end, NewLocale=function() return L end},
        ['AceConsole-3.0'] = {}, ['LibCompress'] = {},
        ['LibClassicDurations'] = {},
        ['LibRangeCheck-3.0'] = {},
    }
    env.LibStub = function(name) return assert(libraries[name], 'Unexpected library '..name) end
    function addon:RegisterCondition(tag, definition) self.definitions[tag]=definition end
    local function load(path)
        local chunk=assert(loadfile(path)); setfenv(chunk, env)
        if path=='Data/plain.lua' then chunk('rotationmaster',addon);return load('Data/rotation_revision.lua') end
        return chunk('rotationmaster',addon)
    end
    dofile('tests/fixtures/native_ui.lua')(env)
    load('globals.lua');load('Platform/client.lua');load('Platform/rotation_owner.lua');load('Platform/groups.lua');load('Platform/roster_class.lua');load('Platform/role.lua');load('Platform/mobinfo2.lua');load('Platform/casting.lua');load('Platform/unit_health.lua');load('Platform/unit_stat.lua');load('Platform/health_forecast.lua');load('Platform/unit_level.lua');load('Platform/unit_power.lua');load('Platform/player_movement.lua');load('Platform/unit_attackability.lua');load('Platform/unit_flags.lua');load('Platform/player_flags.lua');load('Platform/form.lua');load('Platform/points.lua');load('Platform/runes.lua');load('Platform/unit_identity.lua');load('Platform/unit_metadata.lua');load('Platform/creature_type.lua');load('Platform/unit_presence.lua');load('Platform/pet.lua');load('Platform/threat.lua');load('Platform/instance.lua');load('Platform/zone_pvp.lua');load('Platform/loss_of_control.lua');load('Platform/items.lua');load('Platform/glyphs.lua');load('Platform/specializations.lua')
    load('Locales/enUS.lua'); load('constants.lua');load('Data/artwork.lua');load('Functions/values.lua');load('Functions/presentation.lua');load('Functions/text.lua');load('Functions/collections.lua');load('Functions/cache.lua');load('Functions/trends.lua');load('Functions/forecast.lua'); load('utils.lua');load('Core/level_conditions.lua');load('Core/point_conditions.lua');load('Core/class_group_conditions.lua');load('Core/creature_conditions.lua');load('Core/health_forecast_conditions.lua');load('Core/threat_count_conditions.lua')
    load('UI/controls.lua');load('UI/condition_widgets.lua');load('UI/condition_observation.lua');load('UI/condition_icon.lua');load('UI/condition_position.lua');load('UI/condition_display.lua');load('UI/drag_presentation.lua');load('Core/unsaved_changes.lua');load('UI/unsaved.lua');load('Core/stock_targets.lua');load('UI/stock_profile_safety.lua');load('UI/settings_stock.lua');load('UI/settings_draft.lua');load('UI/collection_compare.lua');load('UI/draft_changes.lua');load('UI/draft_change_controls.lua');load('UI/window.lua');load('UI/selector.lua');load('UI/tag_picker.lua');load('UI/checkbox.lua');load('UI/condition_inputs.lua');load('UI/condition_layout.lua');load('UI/condition_table.lua');load('UI/condition_unit.lua');load('Core/item_conditions.lua');load('Core/rotation_references.lua');load('Help/common.lua'); load('Help/conditional.lua'); load('Core/presentation.lua');load('Core/condition_description.lua'); load('Core/spell_catalog.lua');load('Core/spell_search.lua');load('Core/reference_catalog.lua');load('Core/category_data.lua');load('Core/announcement_data.lua');load('Core/profile_data.lua');load('Core/collection_data.lua');load('Core/custom_condition_data.lua');load('Core/functions.lua');load('UI/spell_search.lua');load('UI/spell_icon.lua')
    return {env=env, addon=addon, load=load, widget=widget, translations=translations, libraries=libraries}
end
function F.text(widget)
    local parts={widget.text or ''}
    for _, child in ipairs(widget.children or {}) do parts[#parts+1]=F.text(child) end
    return table.concat(parts, '\n')
end
function F.suite()
    local failed,passed=0,0
    return function(name, body)
        local ok,err=pcall(body)
        if ok then passed=passed+1; print('PASS '..name)
        else failed=failed+1; print('FAIL '..name..': '..tostring(err)) end
    end, function() print(passed..' passed, '..failed..' failed'); os.exit(failed>0 and 1 or 0) end
end
return F
]=],dependency=[=[-- Explicit external boundaries; production constants/utilities/help stay real.
local F = {}
function F.new(product, expansion, class)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.WOW_PROJECT_MAINLINE, env.WOW_PROJECT_CLASSIC = 1, 2
    env.WOW_PROJECT_BURNING_CRUSADE_CLASSIC,env.WOW_PROJECT_MISTS_CLASSIC=5,19
    env.WOW_PROJECT_WRATH_CLASSIC,env.WOW_PROJECT_CATACLYSM_CLASSIC,env.WOW_PROJECT_CAMELOT=11,14,18
    env.WOW_PROJECT_ID, env.LE_EXPANSION_LEVEL_CURRENT = product or 5, expansion or 1
    env.NORMAL_FONT_COLOR_CODE, env.DEFAULT, env.DELETE, env.NAME = '', 'Default', 'Delete', 'Name'
    env.PRIMARY, env.SECONDARY = 'Primary', 'Secondary'
    env.EDIT, env.COMBAT, env.HEALTH, env.MANA = 'Edit', 'Combat', 'Health', 'Mana'
    env.Enum = {PowerType = {Mana=0, Rage=1, Energy=3, Balance=26, Runes=5, SoulShards=7, Chi=12, ArcaneCharges=16, ComboPoints=4}}
    env.UnitClass = function() return class or 'Shaman', class or 'SHAMAN' end
    env.GetTime = function() return 100 end
    local addon = {help_funcs = {}, longtermCache = {}, unitsInRange = {}, currentSpec = 0,
                   db = {profile = {}, global = {}}, definitions = {}}
    local translations = {}
    local L = setmetatable({}, {
        __index = function(_, key) return translations[key] or key end,
        __newindex = function(_, key, value) translations[key] = value == true and key or value end,
    })
    local function widget(kind)
        local w = {kind=kind, children={}}
        function w:AddChild(child) assert(child); self.children[#self.children+1]=child end
        function w:SetText(text) self.text=text end
        function w:SetLayout(layout) self.layout=layout end
        function w:SetFullWidth(value) self.fullWidth=value end
        function w:SetFullHeight(value) self.fullHeight=value end
        function w:SetUserData(key,value) self[key]=value end
        function w:GetUserData(key) return self[key] end
        function w:SetLabel(value) self.label=value end
        function w:SetTitle(value) self.title=value end
        function w:SetValue(value) self.value=value end
        function w:SetIsPercent(value) self.isPercent=value end
        function w:SetSliderValues(minimum,maximum,step) self.sliderValues={minimum,maximum,step} end
        function w:SetDisabled(value) self.disabled=value end
        function w:SetStatusText(value) self.statusText=value end
        function w:SetCallback(event,callback) self.callbacks=self.callbacks or {};self.callbacks[event]=callback end
        function w:SetImage(value) self.image=value end
        function w:SetImageSize(width,height) self.imageWidth,self.imageHeight=width,height end
        function w:SetHeight(value) self.height=value end
        function w:SetWidth(value) self.width=value end
        function w:SetFont(...) self.font={...} end
        function w:SetFontObject(value) self.font=value end
        return w
    end
    local libraries = {
        ['AceLocale-3.0'] = {GetLocale=function() return L end, NewLocale=function() return L end},
        ['AceConsole-3.0'] = {}, ['LibCompress'] = {},
        ['LibClassicDurations'] = {},
        ['LibRangeCheck-3.0'] = {},
    }
    env.LibStub = function(name) return assert(libraries[name], 'Unexpected library '..name) end
    function addon:RegisterCondition(tag, definition) self.definitions[tag]=definition end
    local function load(path)
        local chunk=assert(loadfile(path)); setfenv(chunk, env); return chunk('rotationmaster',addon)
    end
    dofile('tests/fixtures/native_ui.lua')(env)
    load('globals.lua');load('Core/dependency_revisions.lua');load('Platform/client.lua');load('Platform/rotation_owner.lua');load('Platform/groups.lua');load('Platform/roster_class.lua');load('Platform/role.lua');load('Platform/mobinfo2.lua');load('Platform/casting.lua');load('Platform/unit_health.lua');load('Platform/unit_stat.lua');load('Platform/health_forecast.lua');load('Platform/unit_level.lua');load('Platform/unit_power.lua');load('Platform/player_movement.lua');load('Platform/unit_attackability.lua');load('Platform/unit_flags.lua');load('Platform/player_flags.lua');load('Platform/form.lua');load('Platform/points.lua');load('Platform/runes.lua');load('Platform/unit_identity.lua');load('Platform/unit_metadata.lua');load('Platform/creature_type.lua');load('Platform/unit_presence.lua');load('Platform/pet.lua');load('Platform/threat.lua');load('Platform/instance.lua');load('Platform/zone_pvp.lua');load('Platform/loss_of_control.lua');load('Platform/items.lua');load('Platform/glyphs.lua');load('Platform/specializations.lua')
    load('Locales/enUS.lua'); load('constants.lua');load('Data/artwork.lua');load('Functions/values.lua');load('Functions/presentation.lua');load('Functions/text.lua');load('Functions/collections.lua');load('Functions/cache.lua');load('Functions/trends.lua');load('Functions/forecast.lua'); load('utils.lua');load('Core/level_conditions.lua');load('Core/point_conditions.lua');load('Core/class_group_conditions.lua');load('Core/creature_conditions.lua');load('Core/health_forecast_conditions.lua');load('Core/threat_count_conditions.lua')
    load('UI/controls.lua');load('UI/condition_widgets.lua');load('UI/condition_observation.lua');load('UI/condition_icon.lua');load('UI/condition_position.lua');load('UI/condition_display.lua');load('UI/drag_presentation.lua');load('Core/unsaved_changes.lua');load('UI/unsaved.lua');load('Core/stock_targets.lua');load('UI/stock_profile_safety.lua');load('UI/settings_stock.lua');load('UI/settings_draft.lua');load('UI/collection_compare.lua');load('UI/draft_changes.lua');load('UI/draft_change_controls.lua');load('UI/window.lua');load('UI/selector.lua');load('UI/tag_picker.lua');load('UI/checkbox.lua');load('UI/condition_inputs.lua');load('UI/condition_layout.lua');load('UI/condition_table.lua');load('UI/condition_unit.lua');load('Core/item_conditions.lua');load('Core/rotation_references.lua');load('Help/common.lua'); load('Help/conditional.lua'); load('Core/presentation.lua');load('Core/condition_description.lua'); load('Core/spell_catalog.lua');load('Core/spell_search.lua');load('Core/reference_catalog.lua');load('Core/category_data.lua');load('Core/announcement_data.lua');load('Core/profile_data.lua');load('Core/collection_data.lua');load('Core/custom_condition_data.lua');load('Core/functions.lua');load('UI/spell_search.lua');load('UI/spell_icon.lua')
    return {env=env, addon=addon, load=load, widget=widget, translations=translations, libraries=libraries}
end
function F.text(widget)
    local parts={widget.text or ''}
    for _, child in ipairs(widget.children or {}) do parts[#parts+1]=F.text(child) end
    return table.concat(parts, '\n')
end
function F.suite()
    local failed,passed=0,0
    return function(name, body)
        local ok,err=pcall(body)
        if ok then passed=passed+1; print('PASS '..name)
        else failed=failed+1; print('FAIL '..name..': '..tostring(err)) end
    end, function() print(passed..' passed, '..failed..' failed'); os.exit(failed>0 and 1 or 0) end
end
return F
]=],baseline=[=[-- Explicit external boundaries; production constants/utilities/help stay real.
local F = {}
function F.new(product, expansion, class)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.WOW_PROJECT_MAINLINE, env.WOW_PROJECT_CLASSIC = 1, 2
    env.WOW_PROJECT_BURNING_CRUSADE_CLASSIC,env.WOW_PROJECT_MISTS_CLASSIC=5,19
    env.WOW_PROJECT_WRATH_CLASSIC,env.WOW_PROJECT_CATACLYSM_CLASSIC,env.WOW_PROJECT_CAMELOT=11,14,18
    env.WOW_PROJECT_ID, env.LE_EXPANSION_LEVEL_CURRENT = product or 5, expansion or 1
    env.NORMAL_FONT_COLOR_CODE, env.DEFAULT, env.DELETE, env.NAME = '', 'Default', 'Delete', 'Name'
    env.PRIMARY, env.SECONDARY = 'Primary', 'Secondary'
    env.EDIT, env.COMBAT, env.HEALTH, env.MANA = 'Edit', 'Combat', 'Health', 'Mana'
    env.Enum = {PowerType = {Mana=0, Rage=1, Energy=3, Balance=26, Runes=5, SoulShards=7, Chi=12, ArcaneCharges=16, ComboPoints=4}}
    env.UnitClass = function() return class or 'Shaman', class or 'SHAMAN' end
    env.GetTime = function() return 100 end
    local addon = {help_funcs = {}, longtermCache = {}, unitsInRange = {}, currentSpec = 0,
                   db = {profile = {}, global = {}}, definitions = {}}
    local translations = {}
    local L = setmetatable({}, {
        __index = function(_, key) return translations[key] or key end,
        __newindex = function(_, key, value) translations[key] = value == true and key or value end,
    })
    local function widget(kind)
        local w = {kind=kind, children={}}
        function w:AddChild(child) assert(child); self.children[#self.children+1]=child end
        function w:SetText(text) self.text=text end
        function w:SetLayout(layout) self.layout=layout end
        function w:SetFullWidth(value) self.fullWidth=value end
        function w:SetFullHeight(value) self.fullHeight=value end
        function w:SetUserData(key,value) self[key]=value end
        function w:GetUserData(key) return self[key] end
        function w:SetLabel(value) self.label=value end
        function w:SetTitle(value) self.title=value end
        function w:SetValue(value) self.value=value end
        function w:SetIsPercent(value) self.isPercent=value end
        function w:SetSliderValues(minimum,maximum,step) self.sliderValues={minimum,maximum,step} end
        function w:SetDisabled(value) self.disabled=value end
        function w:SetStatusText(value) self.statusText=value end
        function w:SetCallback(event,callback) self.callbacks=self.callbacks or {};self.callbacks[event]=callback end
        function w:SetImage(value) self.image=value end
        function w:SetImageSize(width,height) self.imageWidth,self.imageHeight=width,height end
        function w:SetHeight(value) self.height=value end
        function w:SetWidth(value) self.width=value end
        function w:SetFont(...) self.font={...} end
        function w:SetFontObject(value) self.font=value end
        return w
    end
    local libraries = {
        ['AceLocale-3.0'] = {GetLocale=function() return L end, NewLocale=function() return L end},
        ['AceConsole-3.0'] = {}, ['LibCompress'] = {},
        ['LibClassicDurations'] = {},
        ['LibRangeCheck-3.0'] = {},
    }
    env.LibStub = function(name) return assert(libraries[name], 'Unexpected library '..name) end
    function addon:RegisterCondition(tag, definition) self.definitions[tag]=definition end
    local function load(path)
        local chunk=assert(loadfile(path)); setfenv(chunk, env); return chunk('rotationmaster',addon)
    end
    dofile('tests/fixtures/native_ui.lua')(env)
    load('globals.lua');load('Platform/client.lua');load('Platform/rotation_owner.lua');load('Platform/groups.lua');load('Platform/roster_class.lua');load('Platform/role.lua');load('Platform/mobinfo2.lua');load('Platform/casting.lua');load('Platform/unit_health.lua');load('Platform/unit_stat.lua');load('Platform/health_forecast.lua');load('Platform/unit_level.lua');load('Platform/unit_power.lua');load('Platform/player_movement.lua');load('Platform/unit_attackability.lua');load('Platform/unit_flags.lua');load('Platform/player_flags.lua');load('Platform/form.lua');load('Platform/points.lua');load('Platform/runes.lua');load('Platform/unit_identity.lua');load('Platform/unit_metadata.lua');load('Platform/creature_type.lua');load('Platform/unit_presence.lua');load('Platform/pet.lua');load('Platform/threat.lua');load('Platform/instance.lua');load('Platform/zone_pvp.lua');load('Platform/loss_of_control.lua');load('Platform/items.lua');load('Platform/glyphs.lua');load('Platform/specializations.lua')
    load('Locales/enUS.lua'); load('constants.lua');load('Data/artwork.lua');load('Functions/values.lua');load('Functions/presentation.lua');load('Functions/text.lua');load('Functions/collections.lua');load('Functions/cache.lua');load('Functions/trends.lua');load('Functions/forecast.lua'); load('utils.lua');load('Core/level_conditions.lua');load('Core/point_conditions.lua');load('Core/class_group_conditions.lua');load('Core/creature_conditions.lua');load('Core/health_forecast_conditions.lua');load('Core/threat_count_conditions.lua')
    load('UI/controls.lua');load('UI/condition_widgets.lua');load('UI/condition_observation.lua');load('UI/condition_icon.lua');load('UI/condition_position.lua');load('UI/condition_display.lua');load('UI/drag_presentation.lua');load('Core/unsaved_changes.lua');load('UI/unsaved.lua');load('Core/stock_targets.lua');load('UI/stock_profile_safety.lua');load('UI/settings_stock.lua');load('UI/settings_draft.lua');load('UI/collection_compare.lua');load('UI/draft_changes.lua');load('UI/draft_change_controls.lua');load('UI/window.lua');load('UI/selector.lua');load('UI/tag_picker.lua');load('UI/checkbox.lua');load('UI/condition_inputs.lua');load('UI/condition_layout.lua');load('UI/condition_table.lua');load('UI/condition_unit.lua');load('Core/item_conditions.lua');load('Core/rotation_references.lua');load('Help/common.lua'); load('Help/conditional.lua'); load('Core/presentation.lua');load('Core/condition_description.lua'); load('Core/spell_catalog.lua');load('Core/spell_search.lua');load('Core/reference_catalog.lua');load('Core/category_data.lua');load('Core/announcement_data.lua');load('Core/profile_data.lua');load('Core/collection_data.lua');load('Core/custom_condition_data.lua');load('Core/functions.lua');load('UI/spell_search.lua');load('UI/spell_icon.lua')
    return {env=env, addon=addon, load=load, widget=widget, translations=translations, libraries=libraries}
end
function F.text(widget)
    local parts={widget.text or ''}
    for _, child in ipairs(widget.children or {}) do parts[#parts+1]=F.text(child) end
    return table.concat(parts, '\n')
end
function F.suite()
    local failed,passed=0,0
    return function(name, body)
        local ok,err=pcall(body)
        if ok then passed=passed+1; print('PASS '..name)
        else failed=failed+1; print('FAIL '..name..': '..tostring(err)) end
    end, function() print(passed..' passed, '..failed..' failed'); os.exit(failed>0 and 1 or 0) end
end
return F
]=]},
 ['validate.lua']={current=[=[local addon_name, addon = ...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

local function mark_for_remove(toremove, key)
    if type(key) ~= "number" or key < 1 then
        toremove.not_array = true
    end
    if not toremove.data then
        toremove.data = {}
    end
    table.insert(toremove.data, key)
end

local function apply_remove(toremove, tbl, fix)
    if fix and toremove.data then
        if toremove.not_array then
            for _, key in pairs(toremove.data) do
                tbl[key] = nil
            end
        else
            local offs = 0
            for idx=1,#toremove.data do
                table.remove(tbl, toremove.data[idx] - offs)
                offs = offs + 1
            end
        end
    end

    if fix and toremove.data and invalidateDependencies then invalidateDependencies(addon,'all',nil) end
    addon.Functions.collections.cleanArray(toremove)
end

local function validate_basic(prefix, data, template, fix, preserved)
    local toremove = {}
    for k,v in pairs(data) do
        if preserved and preserved[k] then
            -- Semantic source metadata has its own non-destructive validator.
        elseif template[k] == nil then
            addon:warn("Extra Field %s:%s", prefix, tostring(k))
            mark_for_remove(toremove, k)
        elseif type(v) ~= type(template[k]) then
            addon:warn("Incorrect type for %s:%s (was %s, expected %s)", prefix, tostring(k), type(v), type(template[k]))
            mark_for_remove(toremove, k)
        elseif type(v) == "table" then
            if addon.Functions.collections.tablelength(template[k]) > 0 and #template[k] == 0 then
                validate_basic(prefix .. ":" .. k, v, template[k], fix)
            end
        end
    end
    apply_remove(toremove, data, fix)
end

local function validate_itemset_items(prefix, name, items, fix)
    local toremove = {}
    for idx, item in pairs(items) do
        if type(item) ~= "string" and type(item) ~= "number" then
            addon:warn("Invalid item in itemset %s:%s", prefix, name)
            mark_for_remove(toremove, idx)
        end
    end
    apply_remove(toremove, items, fix)
end

local function is_uuid(uuid)
    return type(uuid) == "string" and uuid:match("(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)") ~= nil
end

function addon:validate_itemset(prefix, name, itemset, fix)
    if not is_uuid(name) then
        addon:warn("Invalid ID for itemset %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(itemset)
            if invalidateDependencies then invalidateDependencies(addon,'itemset',name) end
            return
        end
    end
    local template = {
        modified = false,
        name = "test",
        items = {}
    }
    validate_basic(prefix .. ":" .. name, itemset, template, fix)
    validate_itemset_items(prefix, name, itemset.items, fix)
end

function addon:validate_effect(prefix, name, effect, fix)
    if not is_uuid(name) then
        addon:warn("Invalid ID for effect %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(effect)
            if invalidateDependencies then invalidateDependencies(addon,'effect',name) end
            return
        end
    end
    if not effect["type"] then
        addon:warn("No effect type for %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(effect)
            if invalidateDependencies then invalidateDependencies(addon,'effect',name) end
        end
        return
    end

    local function get_effect_template(type)
        if type == "texture" then
            return {
                texture = "some_texture"
            }
        elseif type == "pixel" then
            return {
                lines = 8,
                frequency = 0.25,
                length = 2,
                thickness = 2
            }
        elseif type == "autocast" then
            return {
                particles = 4,
                frequency = 0.25,
                scale = 1.0
            }
        elseif type == "proc" then
            return {duration=1,startAnim=false}
        elseif type == "blizzard" then
            return {
                frequency = 0.125
            }
        elseif type == "dazzle" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "animate" then
            return {
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "pulse" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "custom" then
            return {
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "rotate" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                steps = 4,
                reverse = false
            }
        end
    end

    local template = get_effect_template(effect["type"])
    if not template then
        addon:warn(L["Unknown effect type for %s:%s (%s); record preserved."], prefix, name, tostring(effect.type))
        return
    end
    if template.texture~=nil and type(effect.texture)=="number" then template.texture=1 end
    template["type"] = "texture"
    template["name"] = "some name"
    validate_basic(prefix .. ":" .. name, effect, template, fix)

    if effect["sequence"] then
        local toremove = {}
        for idx, seq in pairs(effect["sequence"]) do
            if effect["type"] == "dazzle" then
                if type(seq) == "table" then
                    local template = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
                    validate_basic(prefix .. ":" .. name .. ":" .. idx, seq, template, fix)
                else
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "animate" then
                if type(seq) ~= "string" and type(seq) ~= "number" then
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "pulse" then
                if type(seq) ~= "number" then
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "custom" then
                if type(seq) == "table" then
                    local template = {
                        texture = type(seq.texture)=="number" and 1 or "some_texture",
                        angle = 0.0,
                        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
                        magnification = 0.0,
                    }
                    validate_basic(prefix .. ":" .. name .. ":" .. idx, seq, template, fix)
                else
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            end
        end
        apply_remove(toremove, effect["sequence"], fix)
    end
end

function addon:validate_announce(prefix, idx, announce, fix)
    if not announce["type"] then
        addon:warn("No announce type for %s:%s", prefix, idx)
        if fix then
            addon.Functions.collections.cleanArray(announce)
        end
        return
    end

    local template = {
        type = "spell",
        disabled = false,
        announce = "party",
        event = "SUCCEEDED",
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        name = "Announcement",
        value = "Some Announce",
        announce_sound = "Sound"
    }

    if announce["type"] == "spell" or announce["type"] == "petspell" or announce["type"] == "pet" then
        template["spell"] = 12345
        template["ranked"] = false
    elseif announce["type"] == "item" then
        template["item"] = {}
    else
        addon:warn("Invalid type for announce %s:%s", prefix, tostring(announce["id"]))
        if fix then
            addon.Functions.collections.cleanArray(announce)
            return
        end
    end

    validate_basic(prefix, announce, template, fix, announce.type=="item" and {item=true} or nil)

    if not announce["id"] or not is_uuid(announce["id"]) then
        addon:warn("Invalid ID for announce %s:%s", prefix, tostring(announce["id"]))
        if fix then
            addon.Functions.collections.cleanArray(announce)
            return
        end
    end

    if announce.type=="item" and not addon:IsValidAnnouncementItemReference(announce.item) then
        local message=fix and L["Invalid item reference for announce %s:%s; reference preserved; announcement disabled."]
            or L["Invalid item reference for announce %s:%s; explicit repair will preserve the reference and disable the announcement."]
        addon:warn(message, prefix, tostring(announce.id))
        if fix then announce.disabled=true end
    end
end

function addon:validate_condition_group(prefix, idx, group, fix)
    local template = {
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        name = "Some Group",
        conditions = {},
        icon = type(group.icon)=="number" and 1 or "Interface\\Icons\\INV_Misc_Book_09"
    }

    validate_basic(prefix .. ":" .. idx, group, template, fix)
    if group.icon~=nil and not (type(group.icon)=="string" and #group.icon>0 and #group.icon<=1024 or type(group.icon)=="number" and group.icon>0 and group.icon<math.huge and group.icon%1==0) then
        addon:warn("Invalid category icon %s:%s",prefix,tostring(idx));if fix then group.icon=nil end
    end
end

function addon:validate_custom_condition(prefix, name, custom_condition, fix)
    local semantic={fields=true,icon=true,disabled=true,fieldOrder=true,bindings=true,parameters=true,requiredFields=true}
    local template={disabled=false,fieldOrder={},bindings={},parameters={},requiredFields={}}
    for key,value in pairs(addon.empty_condition) do template[key]=value end
    validate_basic(prefix .. ":" .. name, custom_condition, template, fix, semantic)

    local function invalid(field,reason)
        local message=fix and L["Invalid custom condition %s:%s field %s (%s); source preserved; condition disabled."]
            or L["Invalid custom condition %s:%s field %s (%s); explicit repair will preserve source and disable the condition."]
        addon:warn(message, prefix, name, field, reason or "invalid-data")
        if fix then
            custom_condition.disabled=true
            local saved=addon.db and addon.db.global and addon.db.global.custom_conditions
            local definition=addon.conditionDefinitions and addon.conditionDefinitions[name]
            if type(saved)=="table" and saved[name]==custom_condition and definition and definition.customCode==true and definition.disabled~=true then
                -- Do not invoke lifecycle hooks or recompile user source from
                -- repair. Selection notices this registry version next pass.
                definition.disabled=true
                addon.conditionRegistryVersion=(addon.conditionRegistryVersion or 0)+1
                if invalidateDependencies then invalidateDependencies(addon,'condition',name) end
            end
        end
    end
    -- Check data contracts only. Repair must not compile callback text, resolve
    -- currently unavailable helper bindings, or execute registration hooks.
    local fields,fieldReason=addon:NormalizeCustomFieldSchema(custom_condition.fields,true)
    if not fields then invalid("fields",fieldReason) end
    if not addon:IsCategoryIcon(custom_condition.icon) then invalid("icon","invalid-icon") end
    if custom_condition.disabled~=nil and type(custom_condition.disabled)~="boolean" then invalid("disabled","invalid-disabled-flag") end
    local parameters,parameterReason=addon:NormalizeCustomConditionParameters(custom_condition.parameters)
    if not parameters then invalid("parameters",parameterReason) end
    if custom_condition.bindings~=nil then
        local arguments={{name="value"},{name="cache"},{name="evalStart"},{name="spec"},{name="parent"},{name="frame"},{name="tag"}}
        for _,aliases in pairs(parameters or {}) do for _,alias in ipairs(aliases) do arguments[#arguments+1]={name=alias} end end
        local bindings,reason=addon:NormalizeFunctionBindings(custom_condition.bindings,arguments)
        if not bindings then invalid("bindings",reason) end
    end
    if custom_condition.requiredFields~=nil and not addon:NormalizeCustomConditionRequiredFields(custom_condition.requiredFields,fields or {}) then invalid("requiredFields","invalid-required-fields") end
    if custom_condition.fieldOrder~=nil and not addon:NormalizeCustomFieldOrder(custom_condition.fieldOrder,fields or {}) then invalid("fieldOrder","invalid-field-order") end
end

local function validate_rotation_condition(prefix, condition, fix)
    if addon.Functions.collections.tablelength(condition) == 0 then
        return
    end

    if type(condition["type"]) ~= "string" then
        addon:warn("Invalid type for %s", prefix)
        if fix then
            addon.Functions.collections.cleanArray(condition)
        end
        return
    end

    local full_id = prefix .. ":" .. condition["type"]
    local fields = addon.Functions.collections.deepcopy(select(4, addon:describeCondition(condition["type"])))
    -- The condition might not exist if you're not playing a class where it is active.
    if not fields then
        return
    end
    fields["type"] = "string"
    fields["disabled"] = "boolean"
    if condition.type=="AND" or condition.type=="OR" or condition.type=="NOT" then fields.name="string" end

    local function handle_array_field(cond, field)
        if type(cond) == "table" then
            for i=1,#field do
                if type(field[i]) == "table" then
                    local allfound = true
                    for j=1,#cond do
                        local subfound = handle_array_field(cond[j], field[i])
                        if not subfound then
                            allfound = false
                            break
                        end
                    end
                    if allfound then
                        return true
                    end
                end
            end
        else
            for i=1,#field do
                if type(field[i]) ~= "table" and type(cond) == field[i] then
                    return true
                end
            end
        end
        return false
    end

    local function handle_fields(cond, f, subtree)
        local keyremove = {}
        for key, data in pairs(cond) do
            local newsubtree = (subtree and (subtree .. ".") or "") .. key
            local field = f[key]
            if field == nil then
                addon:warn("Extra Field %s.%s", full_id, newsubtree)
                mark_for_remove(keyremove, key)
            elseif type(field) == "table" then
                -- The #field specifies this is an array, specifically.
                if #field > 0 then
                    local found = handle_array_field(data, field)
                    if not found then
                        addon:warn("Condition %s.%s has data of the wrong type (got %s)", full_id, newsubtree, type(data))
                        if fix then
                            mark_for_remove(keyremove, key)
                        end
                    end
                elseif type(data) == "table" then
                    handle_fields(data, field, newsubtree)
                else
                    addon:warn("Condition %s.%s has data of the wrong type (got %s)", full_id, newsubtree, type(data))
                    mark_for_remove(keyremove, key)
                end
            elseif field == "condition" then
                validate_rotation_condition(full_id, data, fix)
            elseif type(field) == "string" and type(data) == "table" then
                if addon.Functions.collections.tablelength(data) ~= #data then
                    addon:warn("Condition %s.%s provides a table where an array is required", full_id, subtree)
                    mark_for_remove(keyremove, key)
                elseif #data > 0 then
                    local basetype = field:match("^(.*)%[%]$")
                    if basetype == "condition" then
                        local toremove = {}
                        for i=1,#data do
                            if type(data[i]) == "table" then
                                validate_rotation_condition(full_id .. "[" .. i .. "]", data[i], fix)
                            else
                                addon:warn("Condition %s.%s[%d] has data of the wrong type (expected %s, got %s)", full_id, newsubtree, i, "table", type(data[i]))
                                mark_for_remove(toremove, i)
                            end
                        end
                        apply_remove(toremove, data, fix)
                    elseif basetype then
                        local toremove = {}
                        for i=1,#data do
                            if type(data[i]) ~= basetype then
                                addon:warn("Condition %s.%s[%d] has data of the wrong type (expected %s, got %s)", full_id, newsubtree, i, basetype, type(data[i]))
                                mark_for_remove(toremove, i)
                            end
                        end
                        apply_remove(toremove, data, fix)
                    else
                        addon:error("Unknown field type used in field spec for array on %s:%s", full_id, newsubtree)
                    end
                end
            elseif type(data) ~= field then
                addon:warn("Condition %s.%s has data of the wrong type (expected %s, got %s)", full_id, newsubtree, field, type(data))
                mark_for_remove(keyremove, key)
            end
        end
        apply_remove(keyremove, cond, fix)
    end

    handle_fields(condition, fields)
end

function addon:validate_rotation(prefix, id, rotation, fix)
    if type(rotation)=='table' and rotation.priority~=nil and not self.RotationData.GetRotationPriority(rotation.priority) then
        self:warn(L['Invalid switch priority for %s:%s; explicit repair resets it to zero.'],prefix,id)
        if fix then rotation.priority=nil end
    end
    -- The old template fixer knows only flat actions. Use the non-destructive
    -- schema for branch bodies; never strip their arms or future metadata.
    if type(rotation)=="table" and type(rotation.rotation)=="table" then
        for _,step in pairs(rotation.rotation) do
            if type(step)=="table" and step.type=="branch" then
                local settings=self.GetImportValidationOptions and self:GetImportValidationOptions() or {conditions=self.conditionDefinitions}
                local result=self.RotationData.ValidateBody(rotation,settings)
                for _,diagnostic in ipairs(result.diagnostics) do self:warn("%s:%s %s",prefix,id,diagnostic.code.." "..diagnostic.path) end
                return
            end
        end
    end
    if id ~= DEFAULT and not is_uuid(id) then
        addon:warn("Invalid ID for rotation %s:%s", prefix, id)
        if fix then
            addon.Functions.collections.cleanArray(rotation)
            return
        end
    end

    local template = {
        name = "Some Name",
        revision = 1,
        description = "Rotation description",
        metadata = {},
        tags = {},
        priority = 0,
        disabled = false,
        switch = {},
        cooldowns = {},
        rotation = {}
    }
    validate_basic(prefix .. ":" .. id, rotation, template, fix)

    if id ~= DEFAULT and not rotation["name"] then
        addon:warn("Unnamed non-default rotation %s:%s", prefix, id)
        if fix then
            addon.Functions.collections.cleanArray(rotation)
            return
        end
    end

    -- Normal actions and cooldown actions share the persisted appearance
    -- schema. These examples validate types; they never materialize defaults.
    local rotation_template = {
        use_name = false,
        name = "Some cool name",
        effect = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        type = "spell",
        ranked = false,
        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        magnification = 1.4,
        setpoint = "CENTER",
        xoffs = 0.0,
        yoffs = 0.0,
        announce = "None",
        announce_sound = "LoudSound",
        disabled = false,
        conditions = {},
    }
    local cooldown_template = addon.Functions.collections.deepcopy(rotation_template)

    local function augment_template_type(template, rot)
        if rot.type=="none" then template.suppress_attack=false end
        if rot.type=="spell" or rot.type=="pet" or rot.type=="any" or rot.type=="petspell" or rot.type=="anyspell" then
            template["action"] = 1234
        elseif rot["type"] == "item" then
            if type(rot["action"]) == "table" then
                template["action"] = {}
            else
                template["action"] = "61b36ed1-fa31-4656-ad71-f3d50f193a85"
            end
        end
    end

    if rotation["cooldowns"] then
        local toremove = {}
        for idx, rot in pairs(rotation["cooldowns"]) do
            local template = addon.Functions.collections.deepcopy(cooldown_template)
            augment_template_type(template, rot)
            validate_basic(prefix .. ":" .. id .. ":cooldown:" .. idx, rot, template, fix)
            if not is_uuid(rot["id"]) then
                addon:warn("Invalid ID for cooldown %s:%s:%d", prefix, id, idx)
                mark_for_remove(toremove, idx)
            end
            if rot["effect"] and not is_uuid(rot["effect"]) then
                addon:warn("Invalid effect ID for cooldown %s:%s:%d", prefix, id, idx)
                if fix then
                    rot["effect"] = nil
                end
            end
            if rot["type"] == "item" then
                if type(rot["action"]) == "table" then
                    validate_itemset_items(prefix .. ":" .. id .. ":cooldown", idx, rot["action"], fix)
                elseif type(rot["action"]) ~= "string" then
                    addon:warn("Invalid type for item action in cooldown %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                elseif not is_uuid(rot["action"]) then
                    addon:warn("Invalid itemset ID for cooldown %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                end
            end
            if rot["conditions"] then
                validate_rotation_condition( string.format("%s:%s:cooldowns:%d", prefix, id, idx),
                        rot["conditions"], fix)
            end
            if addon.Functions.collections.tablelength(rot) == 0 then
                mark_for_remove(toremove, idx)
            end
        end
        apply_remove(toremove, rotation["cooldowns"], fix)
    end

    if rotation["rotation"] then
        local toremove = {}
        for idx, rot in pairs(rotation["rotation"]) do
            local template = addon.Functions.collections.deepcopy(rotation_template)
            augment_template_type(template, rot)
            validate_basic(prefix .. ":" .. id .. ":rotation:" .. idx, rot, template, fix)
            if not is_uuid(rot["id"]) then
                addon:warn("Invalid ID for rotation step %s:%s:%d", prefix, id, idx)
                mark_for_remove(toremove, idx)
            end
            if rot.effect and not is_uuid(rot.effect) then
                addon:warn(L["Invalid effect ID for rotation step %s:%s:%d."], prefix, id, idx)
                if fix then rot.effect=nil end
            end
            if rot["type"] == "item" then
                if type(rot["action"]) == "table" then
                    validate_itemset_items(prefix .. ":" .. id .. ":rotation", idx, rot["action"], fix)
                elseif type(rot["action"]) ~= "string" then
                    addon:warn("Invalid type for item action in rotation %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                elseif not is_uuid(rot["action"]) then
                    addon:warn("Invalid itemset ID for rotation %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                end
            end
            if rot["conditions"] then
                validate_rotation_condition( string.format("%s:%s:rotation:%d", prefix, id, idx),
                        rot["conditions"], fix)
            end
            if addon.Functions.collections.tablelength(rot) == 0 then
                mark_for_remove(toremove, idx)
            end
        end
        apply_remove(toremove, rotation["rotation"], fix)
    end

    if rotation["switch"] then
        validate_rotation_condition( string.format("%s:%s:switch", prefix, id),
                rotation["switch"], fix)
    end
end

function addon:validate(template, fix)
    if fix then if invalidateDependencies then invalidateDependencies(addon,'all',nil) end end
    local DB = _G[self.savedVariableName or "RotationMasterDB"]

    local glob_template = addon.Functions.collections.deepcopy(template.global)
    glob_template.itemsets = {}
    glob_template.effects = {}
    validate_basic("global", DB.global, glob_template, fix)

    if DB.global.itemsets then
        local toremove = {}
        for name, itemset in pairs(DB.global.itemsets) do
            addon:validate_itemset("global", name, itemset, fix)
            if addon.Functions.collections.tablelength(itemset) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.itemsets, fix)
    end

    if DB.global.effects then
        local toremove = {}
        for name, effect in pairs(DB.global.effects) do
            addon:validate_effect("global", name, effect, fix)
            if addon.Functions.collections.tablelength(effect) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.effects, fix)
    end

    if DB.global.custom_conditions then
        local toremove = {}
        for name, custom_condition in pairs(DB.global.custom_conditions) do
            addon:validate_custom_condition("global", name, custom_condition, fix)
            if addon.Functions.collections.tablelength(custom_condition) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.custom_conditions, fix)
    end

    -- Offline characters can still own their v1 data until their explicit
    -- login migration. Recognize these roots without moving or inspecting them.
    local char_template=addon.Functions.collections.deepcopy(template.char)
    char_template.rotations={}
    char_template.itemsets={}
    char_template.announces={}
    for char, data in pairs(DB.char) do
        validate_basic("char:" .. char, data, char_template, fix)
        if data.bindings then
            local toremove = {}
            for id,buttons in pairs(data.bindings) do
                if not is_uuid(id) then
                    addon:warn("Binding for invalid itemset %s", id)
                    if fix then
                        mark_for_remove(toremove, id)
                    end
                end

                local i = 1
                while i <= #buttons do
                    if type(buttons[i]) ~= "number" then
                        addon:warn("Invalid button ID in button bindings %s:%s", char, id)
                        if fix then
                            table.remove(buttons, i)
                        else
                            i = i + 1
                        end
                    else
                        i = i + 1
                    end
                end
                if #buttons == 0 then
                    mark_for_remove(toremove, id)
                end
            end
            apply_remove(toremove, data.bindings, fix)
        end
    end

    -- These optional library-owned values are recognized schema, not defaults:
    -- their absence preserves LibDBIcon's own placement and interaction policy.
    local profile_template=addon.Functions.collections.deepcopy(template.profile)
    if type(profile_template.minimap)=="table" then
        profile_template.minimap=addon.Functions.collections.deepcopy(profile_template.minimap)
        profile_template.minimap.minimapPos=0
        profile_template.minimap.radius=0
        profile_template.minimap.lock=false
        profile_template.minimap.showInCompartment=false
    end
    for profile, data in pairs(DB.profiles) do
        -- Ownership archives must never be removed by the legacy shape repair.
        -- Their pure schema is validated independently, without guessing owners
        -- or mutating a future/invalid format that may need explicit recovery.
        validate_basic("profile:" .. profile, data, profile_template, fix,{stockTargets=true,rotationStore=true,rotationFallbackID=true,rotations=addon.InitializeScopedRotationStorage~=nil,rotationLibrary=addon.InitializeScopedRotationStorage~=nil})
        local stockTargets=rawget(data,'stockTargets')
        if stockTargets~=nil then
            local ok,why=addon.StockTargets.Validate(stockTargets)
            if not ok then addon:warn(L['Invalid stock targets in profile %s (%s); data preserved.'],profile,why) end
        end
        local fallback=data.rotationFallbackID
        if (data.rotationStore~=nil or fallback~=nil) and (type(fallback)~='string' or #fallback==0 or #fallback>128 or not fallback:find('%S') or fallback:find('[%z\1-\31\127]')) then
            addon:warn(L['Invalid rotation fallback configuration in profile %s; data preserved.'],profile)
        end
        if data.rotationStore~=nil then
            local ok,why=addon.RotationData.ValidateRotationStore(data.rotationStore)
            if not ok then addon:warn(L["Invalid rotation ownership data in profile %s (%s); record preserved."],profile,tostring(why)) end
        end
        if type(data.minimap)=="table" then
            for _,key in ipairs({"minimapPos","radius"}) do
                local value=data.minimap[key]
                if type(value)=="number" and (value~=value or value==math.huge or value==-math.huge) then
                    addon:warn(L["Non-finite minimap value in profile %s: %s."], profile, key)
                    if fix then data.minimap[key]=nil end
                end
            end
        end

        if data.itemsets then
            local toremove = {}
            for name, itemset in pairs(data.itemsets) do
                addon:validate_itemset("profile:" .. profile, name, itemset, fix)
                if addon.Functions.collections.tablelength(itemset) == 0 then
                    mark_for_remove(toremove, name)
                end
            end
            apply_remove(toremove, data.itemsets, fix)
        end

        if data.announces then
            local toremove = {}
            for idx, announce in pairs(data.announces) do
                addon:validate_announce("profile:" .. profile, idx, announce, fix)
                if addon.Functions.collections.tablelength(announce) == 0 then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.announces, fix)
        end

        if data.rotations and not addon.InitializeScopedRotationStorage then
            local specremove = {}
            for spec, rotations in pairs(data.rotations) do
                if type(spec) ~= "number" then
                    table.insert(specremove, spec)
                end
                local toremove = {}
                for id, rotation in pairs(rotations) do
                    addon:validate_rotation("profile:" .. profile .. ":" .. spec, id, rotation, fix)
                    if addon.Functions.collections.tablelength(rotation) == 0 then
                        mark_for_remove(toremove, id)
                    end
                end
                apply_remove(toremove, rotations, fix)
            end
            if fix then
                for _, key in pairs(specremove) do
                    data.rotations[key] = nil
                end
            end
        end

        if data.condition_groups then
            local toremove = {}
            for idx,group in pairs(data.condition_groups) do
                if type(idx) ~= "number" then
                    mark_for_remove(toremove, idx)
                end
                addon:validate_condition_group("profile:" .. profile, idx, group, fix)
                if addon.Functions.collections.tablelength(group) == 0 then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.condition_groups, fix)
        end

        local toremove = {}
        if data.switch_conditions then
            for idx,cond in pairs(data.switch_conditions) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.switch_conditions, fix)
        end

        if data.other_conditions_order then
            for idx,cond in pairs(data.other_conditions_order) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.other_conditions_order, fix)
        end

        if data.disabled_conditions then
            for idx,cond in pairs(data.disabled_conditions) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.disabled_conditions, fix)
        end
    end
    if fix then if invalidateDependencies then invalidateDependencies(addon,'all',nil) end end
end
]=],persistent=[=[local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

local function mark_for_remove(toremove, key)
    if type(key) ~= "number" or key < 1 then
        toremove.not_array = true
    end
    if not toremove.data then
        toremove.data = {}
    end
    table.insert(toremove.data, key)
end

local function apply_remove(toremove, tbl, fix)
    if fix and toremove.data then
        if toremove.not_array then
            for _, key in pairs(toremove.data) do
                tbl[key] = nil
            end
        else
            local offs = 0
            for idx=1,#toremove.data do
                table.remove(tbl, toremove.data[idx] - offs)
                offs = offs + 1
            end
        end
    end

    addon.Functions.collections.cleanArray(toremove)
end

local function validate_basic(prefix, data, template, fix, preserved)
    local toremove = {}
    for k,v in pairs(data) do
        if preserved and preserved[k] then
            -- Semantic source metadata has its own non-destructive validator.
        elseif template[k] == nil then
            addon:warn("Extra Field %s:%s", prefix, tostring(k))
            mark_for_remove(toremove, k)
        elseif type(v) ~= type(template[k]) then
            addon:warn("Incorrect type for %s:%s (was %s, expected %s)", prefix, tostring(k), type(v), type(template[k]))
            mark_for_remove(toremove, k)
        elseif type(v) == "table" then
            if addon.Functions.collections.tablelength(template[k]) > 0 and #template[k] == 0 then
                validate_basic(prefix .. ":" .. k, v, template[k], fix)
            end
        end
    end
    apply_remove(toremove, data, fix)
end

local function validate_itemset_items(prefix, name, items, fix)
    local toremove = {}
    for idx, item in pairs(items) do
        if type(item) ~= "string" and type(item) ~= "number" then
            addon:warn("Invalid item in itemset %s:%s", prefix, name)
            mark_for_remove(toremove, idx)
        end
    end
    apply_remove(toremove, items, fix)
end

local function is_uuid(uuid)
    return type(uuid) == "string" and uuid:match("(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)") ~= nil
end

function addon:validate_itemset(prefix, name, itemset, fix)
    if not is_uuid(name) then
        addon:warn("Invalid ID for itemset %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(itemset)
            return
        end
    end
    local template = {
        modified = false,
        name = "test",
        items = {}
    }
    validate_basic(prefix .. ":" .. name, itemset, template, fix)
    validate_itemset_items(prefix, name, itemset.items, fix)
end

function addon:validate_effect(prefix, name, effect, fix)
    if not is_uuid(name) then
        addon:warn("Invalid ID for effect %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(effect)
            return
        end
    end
    if not effect["type"] then
        addon:warn("No effect type for %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(effect)
        end
        return
    end

    local function get_effect_template(type)
        if type == "texture" then
            return {
                texture = "some_texture"
            }
        elseif type == "pixel" then
            return {
                lines = 8,
                frequency = 0.25,
                length = 2,
                thickness = 2
            }
        elseif type == "autocast" then
            return {
                particles = 4,
                frequency = 0.25,
                scale = 1.0
            }
        elseif type == "proc" then
            return {duration=1,startAnim=false}
        elseif type == "blizzard" then
            return {
                frequency = 0.125
            }
        elseif type == "dazzle" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "animate" then
            return {
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "pulse" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "custom" then
            return {
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "rotate" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                steps = 4,
                reverse = false
            }
        end
    end

    local template = get_effect_template(effect["type"])
    if not template then
        addon:warn(L["Unknown effect type for %s:%s (%s); record preserved."], prefix, name, tostring(effect.type))
        return
    end
    if template.texture~=nil and type(effect.texture)=="number" then template.texture=1 end
    template["type"] = "texture"
    template["name"] = "some name"
    validate_basic(prefix .. ":" .. name, effect, template, fix)

    if effect["sequence"] then
        local toremove = {}
        for idx, seq in pairs(effect["sequence"]) do
            if effect["type"] == "dazzle" then
                if type(seq) == "table" then
                    local template = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
                    validate_basic(prefix .. ":" .. name .. ":" .. idx, seq, template, fix)
                else
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "animate" then
                if type(seq) ~= "string" and type(seq) ~= "number" then
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "pulse" then
                if type(seq) ~= "number" then
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "custom" then
                if type(seq) == "table" then
                    local template = {
                        texture = type(seq.texture)=="number" and 1 or "some_texture",
                        angle = 0.0,
                        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
                        magnification = 0.0,
                    }
                    validate_basic(prefix .. ":" .. name .. ":" .. idx, seq, template, fix)
                else
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            end
        end
        apply_remove(toremove, effect["sequence"], fix)
    end
end

function addon:validate_announce(prefix, idx, announce, fix)
    if not announce["type"] then
        addon:warn("No announce type for %s:%s", prefix, idx)
        if fix then
            addon.Functions.collections.cleanArray(announce)
        end
        return
    end

    local template = {
        type = "spell",
        disabled = false,
        announce = "party",
        event = "SUCCEEDED",
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        name = "Announcement",
        value = "Some Announce",
        announce_sound = "Sound"
    }

    if announce["type"] == "spell" or announce["type"] == "petspell" or announce["type"] == "pet" then
        template["spell"] = 12345
        template["ranked"] = false
    elseif announce["type"] == "item" then
        template["item"] = {}
    else
        addon:warn("Invalid type for announce %s:%s", prefix, tostring(announce["id"]))
        if fix then
            addon.Functions.collections.cleanArray(announce)
            return
        end
    end

    validate_basic(prefix, announce, template, fix, announce.type=="item" and {item=true} or nil)

    if not announce["id"] or not is_uuid(announce["id"]) then
        addon:warn("Invalid ID for announce %s:%s", prefix, tostring(announce["id"]))
        if fix then
            addon.Functions.collections.cleanArray(announce)
            return
        end
    end

    if announce.type=="item" and not addon:IsValidAnnouncementItemReference(announce.item) then
        local message=fix and L["Invalid item reference for announce %s:%s; reference preserved; announcement disabled."]
            or L["Invalid item reference for announce %s:%s; explicit repair will preserve the reference and disable the announcement."]
        addon:warn(message, prefix, tostring(announce.id))
        if fix then announce.disabled=true end
    end
end

function addon:validate_condition_group(prefix, idx, group, fix)
    local template = {
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        name = "Some Group",
        conditions = {},
        icon = type(group.icon)=="number" and 1 or "Interface\\Icons\\INV_Misc_Book_09"
    }

    validate_basic(prefix .. ":" .. idx, group, template, fix)
    if group.icon~=nil and not (type(group.icon)=="string" and #group.icon>0 and #group.icon<=1024 or type(group.icon)=="number" and group.icon>0 and group.icon<math.huge and group.icon%1==0) then
        addon:warn("Invalid category icon %s:%s",prefix,tostring(idx));if fix then group.icon=nil end
    end
end

function addon:validate_custom_condition(prefix, name, custom_condition, fix)
    local semantic={fields=true,icon=true,disabled=true,fieldOrder=true,bindings=true,parameters=true,requiredFields=true}
    local template={disabled=false,fieldOrder={},bindings={},parameters={},requiredFields={}}
    for key,value in pairs(addon.empty_condition) do template[key]=value end
    validate_basic(prefix .. ":" .. name, custom_condition, template, fix, semantic)

    local function invalid(field,reason)
        local message=fix and L["Invalid custom condition %s:%s field %s (%s); source preserved; condition disabled."]
            or L["Invalid custom condition %s:%s field %s (%s); explicit repair will preserve source and disable the condition."]
        addon:warn(message, prefix, name, field, reason or "invalid-data")
        if fix then
            custom_condition.disabled=true
            local saved=addon.db and addon.db.global and addon.db.global.custom_conditions
            local definition=addon.conditionDefinitions and addon.conditionDefinitions[name]
            if type(saved)=="table" and saved[name]==custom_condition and definition and definition.customCode==true and definition.disabled~=true then
                -- Do not invoke lifecycle hooks or recompile user source from
                -- repair. Selection notices this registry version next pass.
                definition.disabled=true
                addon.conditionRegistryVersion=(addon.conditionRegistryVersion or 0)+1
            end
        end
    end
    -- Check data contracts only. Repair must not compile callback text, resolve
    -- currently unavailable helper bindings, or execute registration hooks.
    local fields,fieldReason=addon:NormalizeCustomFieldSchema(custom_condition.fields,true)
    if not fields then invalid("fields",fieldReason) end
    if not addon:IsCategoryIcon(custom_condition.icon) then invalid("icon","invalid-icon") end
    if custom_condition.disabled~=nil and type(custom_condition.disabled)~="boolean" then invalid("disabled","invalid-disabled-flag") end
    local parameters,parameterReason=addon:NormalizeCustomConditionParameters(custom_condition.parameters)
    if not parameters then invalid("parameters",parameterReason) end
    if custom_condition.bindings~=nil then
        local arguments={{name="value"},{name="cache"},{name="evalStart"},{name="spec"},{name="parent"},{name="frame"},{name="tag"}}
        for _,aliases in pairs(parameters or {}) do for _,alias in ipairs(aliases) do arguments[#arguments+1]={name=alias} end end
        local bindings,reason=addon:NormalizeFunctionBindings(custom_condition.bindings,arguments)
        if not bindings then invalid("bindings",reason) end
    end
    if custom_condition.requiredFields~=nil and not addon:NormalizeCustomConditionRequiredFields(custom_condition.requiredFields,fields or {}) then invalid("requiredFields","invalid-required-fields") end
    if custom_condition.fieldOrder~=nil and not addon:NormalizeCustomFieldOrder(custom_condition.fieldOrder,fields or {}) then invalid("fieldOrder","invalid-field-order") end
end

local function validate_rotation_condition(prefix, condition, fix)
    if addon.Functions.collections.tablelength(condition) == 0 then
        return
    end

    if type(condition["type"]) ~= "string" then
        addon:warn("Invalid type for %s", prefix)
        if fix then
            addon.Functions.collections.cleanArray(condition)
        end
        return
    end

    local full_id = prefix .. ":" .. condition["type"]
    local fields = addon.Functions.collections.deepcopy(select(4, addon:describeCondition(condition["type"])))
    -- The condition might not exist if you're not playing a class where it is active.
    if not fields then
        return
    end
    fields["type"] = "string"
    fields["disabled"] = "boolean"
    if condition.type=="AND" or condition.type=="OR" or condition.type=="NOT" then fields.name="string" end

    local function handle_array_field(cond, field)
        if type(cond) == "table" then
            for i=1,#field do
                if type(field[i]) == "table" then
                    local allfound = true
                    for j=1,#cond do
                        local subfound = handle_array_field(cond[j], field[i])
                        if not subfound then
                            allfound = false
                            break
                        end
                    end
                    if allfound then
                        return true
                    end
                end
            end
        else
            for i=1,#field do
                if type(field[i]) ~= "table" and type(cond) == field[i] then
                    return true
                end
            end
        end
        return false
    end

    local function handle_fields(cond, f, subtree)
        local keyremove = {}
        for key, data in pairs(cond) do
            local newsubtree = (subtree and (subtree .. ".") or "") .. key
            local field = f[key]
            if field == nil then
                addon:warn("Extra Field %s.%s", full_id, newsubtree)
                mark_for_remove(keyremove, key)
            elseif type(field) == "table" then
                -- The #field specifies this is an array, specifically.
                if #field > 0 then
                    local found = handle_array_field(data, field)
                    if not found then
                        addon:warn("Condition %s.%s has data of the wrong type (got %s)", full_id, newsubtree, type(data))
                        if fix then
                            mark_for_remove(keyremove, key)
                        end
                    end
                elseif type(data) == "table" then
                    handle_fields(data, field, newsubtree)
                else
                    addon:warn("Condition %s.%s has data of the wrong type (got %s)", full_id, newsubtree, type(data))
                    mark_for_remove(keyremove, key)
                end
            elseif field == "condition" then
                validate_rotation_condition(full_id, data, fix)
            elseif type(field) == "string" and type(data) == "table" then
                if addon.Functions.collections.tablelength(data) ~= #data then
                    addon:warn("Condition %s.%s provides a table where an array is required", full_id, subtree)
                    mark_for_remove(keyremove, key)
                elseif #data > 0 then
                    local basetype = field:match("^(.*)%[%]$")
                    if basetype == "condition" then
                        local toremove = {}
                        for i=1,#data do
                            if type(data[i]) == "table" then
                                validate_rotation_condition(full_id .. "[" .. i .. "]", data[i], fix)
                            else
                                addon:warn("Condition %s.%s[%d] has data of the wrong type (expected %s, got %s)", full_id, newsubtree, i, "table", type(data[i]))
                                mark_for_remove(toremove, i)
                            end
                        end
                        apply_remove(toremove, data, fix)
                    elseif basetype then
                        local toremove = {}
                        for i=1,#data do
                            if type(data[i]) ~= basetype then
                                addon:warn("Condition %s.%s[%d] has data of the wrong type (expected %s, got %s)", full_id, newsubtree, i, basetype, type(data[i]))
                                mark_for_remove(toremove, i)
                            end
                        end
                        apply_remove(toremove, data, fix)
                    else
                        addon:error("Unknown field type used in field spec for array on %s:%s", full_id, newsubtree)
                    end
                end
            elseif type(data) ~= field then
                addon:warn("Condition %s.%s has data of the wrong type (expected %s, got %s)", full_id, newsubtree, field, type(data))
                mark_for_remove(keyremove, key)
            end
        end
        apply_remove(keyremove, cond, fix)
    end

    handle_fields(condition, fields)
end

function addon:validate_rotation(prefix, id, rotation, fix)
    if type(rotation)=='table' and rotation.priority~=nil and not self.RotationData.GetRotationPriority(rotation.priority) then
        self:warn(L['Invalid switch priority for %s:%s; explicit repair resets it to zero.'],prefix,id)
        if fix then rotation.priority=nil end
    end
    -- The old template fixer knows only flat actions. Use the non-destructive
    -- schema for branch bodies; never strip their arms or future metadata.
    if type(rotation)=="table" and type(rotation.rotation)=="table" then
        for _,step in pairs(rotation.rotation) do
            if type(step)=="table" and step.type=="branch" then
                local settings=self.GetImportValidationOptions and self:GetImportValidationOptions() or {conditions=self.conditionDefinitions}
                local result=self.RotationData.ValidateBody(rotation,settings)
                for _,diagnostic in ipairs(result.diagnostics) do self:warn("%s:%s %s",prefix,id,diagnostic.code.." "..diagnostic.path) end
                return
            end
        end
    end
    if id ~= DEFAULT and not is_uuid(id) then
        addon:warn("Invalid ID for rotation %s:%s", prefix, id)
        if fix then
            addon.Functions.collections.cleanArray(rotation)
            return
        end
    end

    local template = {
        name = "Some Name",
        revision = 1,
        description = "Rotation description",
        metadata = {},
        tags = {},
        priority = 0,
        disabled = false,
        switch = {},
        cooldowns = {},
        rotation = {}
    }
    validate_basic(prefix .. ":" .. id, rotation, template, fix)

    if id ~= DEFAULT and not rotation["name"] then
        addon:warn("Unnamed non-default rotation %s:%s", prefix, id)
        if fix then
            addon.Functions.collections.cleanArray(rotation)
            return
        end
    end

    -- Normal actions and cooldown actions share the persisted appearance
    -- schema. These examples validate types; they never materialize defaults.
    local rotation_template = {
        use_name = false,
        name = "Some cool name",
        effect = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        type = "spell",
        ranked = false,
        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        magnification = 1.4,
        setpoint = "CENTER",
        xoffs = 0.0,
        yoffs = 0.0,
        announce = "None",
        announce_sound = "LoudSound",
        disabled = false,
        conditions = {},
    }
    local cooldown_template = addon.Functions.collections.deepcopy(rotation_template)

    local function augment_template_type(template, rot)
        if rot.type=="none" then template.suppress_attack=false end
        if rot.type=="spell" or rot.type=="pet" or rot.type=="any" or rot.type=="petspell" or rot.type=="anyspell" then
            template["action"] = 1234
        elseif rot["type"] == "item" then
            if type(rot["action"]) == "table" then
                template["action"] = {}
            else
                template["action"] = "61b36ed1-fa31-4656-ad71-f3d50f193a85"
            end
        end
    end

    if rotation["cooldowns"] then
        local toremove = {}
        for idx, rot in pairs(rotation["cooldowns"]) do
            local template = addon.Functions.collections.deepcopy(cooldown_template)
            augment_template_type(template, rot)
            validate_basic(prefix .. ":" .. id .. ":cooldown:" .. idx, rot, template, fix)
            if not is_uuid(rot["id"]) then
                addon:warn("Invalid ID for cooldown %s:%s:%d", prefix, id, idx)
                mark_for_remove(toremove, idx)
            end
            if rot["effect"] and not is_uuid(rot["effect"]) then
                addon:warn("Invalid effect ID for cooldown %s:%s:%d", prefix, id, idx)
                if fix then
                    rot["effect"] = nil
                end
            end
            if rot["type"] == "item" then
                if type(rot["action"]) == "table" then
                    validate_itemset_items(prefix .. ":" .. id .. ":cooldown", idx, rot["action"], fix)
                elseif type(rot["action"]) ~= "string" then
                    addon:warn("Invalid type for item action in cooldown %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                elseif not is_uuid(rot["action"]) then
                    addon:warn("Invalid itemset ID for cooldown %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                end
            end
            if rot["conditions"] then
                validate_rotation_condition( string.format("%s:%s:cooldowns:%d", prefix, id, idx),
                        rot["conditions"], fix)
            end
            if addon.Functions.collections.tablelength(rot) == 0 then
                mark_for_remove(toremove, idx)
            end
        end
        apply_remove(toremove, rotation["cooldowns"], fix)
    end

    if rotation["rotation"] then
        local toremove = {}
        for idx, rot in pairs(rotation["rotation"]) do
            local template = addon.Functions.collections.deepcopy(rotation_template)
            augment_template_type(template, rot)
            validate_basic(prefix .. ":" .. id .. ":rotation:" .. idx, rot, template, fix)
            if not is_uuid(rot["id"]) then
                addon:warn("Invalid ID for rotation step %s:%s:%d", prefix, id, idx)
                mark_for_remove(toremove, idx)
            end
            if rot.effect and not is_uuid(rot.effect) then
                addon:warn(L["Invalid effect ID for rotation step %s:%s:%d."], prefix, id, idx)
                if fix then rot.effect=nil end
            end
            if rot["type"] == "item" then
                if type(rot["action"]) == "table" then
                    validate_itemset_items(prefix .. ":" .. id .. ":rotation", idx, rot["action"], fix)
                elseif type(rot["action"]) ~= "string" then
                    addon:warn("Invalid type for item action in rotation %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                elseif not is_uuid(rot["action"]) then
                    addon:warn("Invalid itemset ID for rotation %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                end
            end
            if rot["conditions"] then
                validate_rotation_condition( string.format("%s:%s:rotation:%d", prefix, id, idx),
                        rot["conditions"], fix)
            end
            if addon.Functions.collections.tablelength(rot) == 0 then
                mark_for_remove(toremove, idx)
            end
        end
        apply_remove(toremove, rotation["rotation"], fix)
    end

    if rotation["switch"] then
        validate_rotation_condition( string.format("%s:%s:switch", prefix, id),
                rotation["switch"], fix)
    end
end

function addon:validate(template, fix)
    local DB = _G[self.savedVariableName or "RotationMasterDB"]

    local glob_template = addon.Functions.collections.deepcopy(template.global)
    glob_template.itemsets = {}
    glob_template.effects = {}
    validate_basic("global", DB.global, glob_template, fix)

    if DB.global.itemsets then
        local toremove = {}
        for name, itemset in pairs(DB.global.itemsets) do
            addon:validate_itemset("global", name, itemset, fix)
            if addon.Functions.collections.tablelength(itemset) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.itemsets, fix)
    end

    if DB.global.effects then
        local toremove = {}
        for name, effect in pairs(DB.global.effects) do
            addon:validate_effect("global", name, effect, fix)
            if addon.Functions.collections.tablelength(effect) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.effects, fix)
    end

    if DB.global.custom_conditions then
        local toremove = {}
        for name, custom_condition in pairs(DB.global.custom_conditions) do
            addon:validate_custom_condition("global", name, custom_condition, fix)
            if addon.Functions.collections.tablelength(custom_condition) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.custom_conditions, fix)
    end

    -- Offline characters can still own their v1 data until their explicit
    -- login migration. Recognize these roots without moving or inspecting them.
    local char_template=addon.Functions.collections.deepcopy(template.char)
    char_template.rotations={}
    char_template.itemsets={}
    char_template.announces={}
    for char, data in pairs(DB.char) do
        validate_basic("char:" .. char, data, char_template, fix)
        if data.bindings then
            local toremove = {}
            for id,buttons in pairs(data.bindings) do
                if not is_uuid(id) then
                    addon:warn("Binding for invalid itemset %s", id)
                    if fix then
                        mark_for_remove(toremove, id)
                    end
                end

                local i = 1
                while i <= #buttons do
                    if type(buttons[i]) ~= "number" then
                        addon:warn("Invalid button ID in button bindings %s:%s", char, id)
                        if fix then
                            table.remove(buttons, i)
                        else
                            i = i + 1
                        end
                    else
                        i = i + 1
                    end
                end
                if #buttons == 0 then
                    mark_for_remove(toremove, id)
                end
            end
            apply_remove(toremove, data.bindings, fix)
        end
    end

    -- These optional library-owned values are recognized schema, not defaults:
    -- their absence preserves LibDBIcon's own placement and interaction policy.
    local profile_template=addon.Functions.collections.deepcopy(template.profile)
    if type(profile_template.minimap)=="table" then
        profile_template.minimap=addon.Functions.collections.deepcopy(profile_template.minimap)
        profile_template.minimap.minimapPos=0
        profile_template.minimap.radius=0
        profile_template.minimap.lock=false
        profile_template.minimap.showInCompartment=false
    end
    for profile, data in pairs(DB.profiles) do
        -- Ownership archives must never be removed by the legacy shape repair.
        -- Their pure schema is validated independently, without guessing owners
        -- or mutating a future/invalid format that may need explicit recovery.
        validate_basic("profile:" .. profile, data, profile_template, fix,{stockTargets=true,rotationStore=true,rotationFallbackID=true,rotations=addon.InitializeScopedRotationStorage~=nil,rotationLibrary=addon.InitializeScopedRotationStorage~=nil})
        local stockTargets=rawget(data,'stockTargets')
        if stockTargets~=nil then
            local ok,why=addon.StockTargets.Validate(stockTargets)
            if not ok then addon:warn(L['Invalid stock targets in profile %s (%s); data preserved.'],profile,why) end
        end
        local fallback=data.rotationFallbackID
        if (data.rotationStore~=nil or fallback~=nil) and (type(fallback)~='string' or #fallback==0 or #fallback>128 or not fallback:find('%S') or fallback:find('[%z\1-\31\127]')) then
            addon:warn(L['Invalid rotation fallback configuration in profile %s; data preserved.'],profile)
        end
        if data.rotationStore~=nil then
            local ok,why=addon.RotationData.ValidateRotationStore(data.rotationStore)
            if not ok then addon:warn(L["Invalid rotation ownership data in profile %s (%s); record preserved."],profile,tostring(why)) end
        end
        if type(data.minimap)=="table" then
            for _,key in ipairs({"minimapPos","radius"}) do
                local value=data.minimap[key]
                if type(value)=="number" and (value~=value or value==math.huge or value==-math.huge) then
                    addon:warn(L["Non-finite minimap value in profile %s: %s."], profile, key)
                    if fix then data.minimap[key]=nil end
                end
            end
        end

        if data.itemsets then
            local toremove = {}
            for name, itemset in pairs(data.itemsets) do
                addon:validate_itemset("profile:" .. profile, name, itemset, fix)
                if addon.Functions.collections.tablelength(itemset) == 0 then
                    mark_for_remove(toremove, name)
                end
            end
            apply_remove(toremove, data.itemsets, fix)
        end

        if data.announces then
            local toremove = {}
            for idx, announce in pairs(data.announces) do
                addon:validate_announce("profile:" .. profile, idx, announce, fix)
                if addon.Functions.collections.tablelength(announce) == 0 then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.announces, fix)
        end

        if data.rotations and not addon.InitializeScopedRotationStorage then
            local specremove = {}
            for spec, rotations in pairs(data.rotations) do
                if type(spec) ~= "number" then
                    table.insert(specremove, spec)
                end
                local toremove = {}
                for id, rotation in pairs(rotations) do
                    addon:validate_rotation("profile:" .. profile .. ":" .. spec, id, rotation, fix)
                    if addon.Functions.collections.tablelength(rotation) == 0 then
                        mark_for_remove(toremove, id)
                    end
                end
                apply_remove(toremove, rotations, fix)
            end
            if fix then
                for _, key in pairs(specremove) do
                    data.rotations[key] = nil
                end
            end
        end

        if data.condition_groups then
            local toremove = {}
            for idx,group in pairs(data.condition_groups) do
                if type(idx) ~= "number" then
                    mark_for_remove(toremove, idx)
                end
                addon:validate_condition_group("profile:" .. profile, idx, group, fix)
                if addon.Functions.collections.tablelength(group) == 0 then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.condition_groups, fix)
        end

        local toremove = {}
        if data.switch_conditions then
            for idx,cond in pairs(data.switch_conditions) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.switch_conditions, fix)
        end

        if data.other_conditions_order then
            for idx,cond in pairs(data.other_conditions_order) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.other_conditions_order, fix)
        end

        if data.disabled_conditions then
            for idx,cond in pairs(data.disabled_conditions) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.disabled_conditions, fix)
        end
    end
end
]=],dependency=[=[local addon_name, addon = ...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

local function mark_for_remove(toremove, key)
    if type(key) ~= "number" or key < 1 then
        toremove.not_array = true
    end
    if not toremove.data then
        toremove.data = {}
    end
    table.insert(toremove.data, key)
end

local function apply_remove(toremove, tbl, fix)
    if fix and toremove.data then
        if toremove.not_array then
            for _, key in pairs(toremove.data) do
                tbl[key] = nil
            end
        else
            local offs = 0
            for idx=1,#toremove.data do
                table.remove(tbl, toremove.data[idx] - offs)
                offs = offs + 1
            end
        end
    end

    if fix and toremove.data and invalidateDependencies then invalidateDependencies(addon,'all',nil) end
    addon.Functions.collections.cleanArray(toremove)
end

local function validate_basic(prefix, data, template, fix, preserved)
    local toremove = {}
    for k,v in pairs(data) do
        if preserved and preserved[k] then
            -- Semantic source metadata has its own non-destructive validator.
        elseif template[k] == nil then
            addon:warn("Extra Field %s:%s", prefix, tostring(k))
            mark_for_remove(toremove, k)
        elseif type(v) ~= type(template[k]) then
            addon:warn("Incorrect type for %s:%s (was %s, expected %s)", prefix, tostring(k), type(v), type(template[k]))
            mark_for_remove(toremove, k)
        elseif type(v) == "table" then
            if addon.Functions.collections.tablelength(template[k]) > 0 and #template[k] == 0 then
                validate_basic(prefix .. ":" .. k, v, template[k], fix)
            end
        end
    end
    apply_remove(toremove, data, fix)
end

local function validate_itemset_items(prefix, name, items, fix)
    local toremove = {}
    for idx, item in pairs(items) do
        if type(item) ~= "string" and type(item) ~= "number" then
            addon:warn("Invalid item in itemset %s:%s", prefix, name)
            mark_for_remove(toremove, idx)
        end
    end
    apply_remove(toremove, items, fix)
end

local function is_uuid(uuid)
    return type(uuid) == "string" and uuid:match("(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)") ~= nil
end

function addon:validate_itemset(prefix, name, itemset, fix)
    if not is_uuid(name) then
        addon:warn("Invalid ID for itemset %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(itemset)
            if invalidateDependencies then invalidateDependencies(addon,'itemset',name) end
            return
        end
    end
    local template = {
        modified = false,
        name = "test",
        items = {}
    }
    validate_basic(prefix .. ":" .. name, itemset, template, fix)
    validate_itemset_items(prefix, name, itemset.items, fix)
end

function addon:validate_effect(prefix, name, effect, fix)
    if not is_uuid(name) then
        addon:warn("Invalid ID for effect %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(effect)
            if invalidateDependencies then invalidateDependencies(addon,'effect',name) end
            return
        end
    end
    if not effect["type"] then
        addon:warn("No effect type for %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(effect)
            if invalidateDependencies then invalidateDependencies(addon,'effect',name) end
        end
        return
    end

    local function get_effect_template(type)
        if type == "texture" then
            return {
                texture = "some_texture"
            }
        elseif type == "pixel" then
            return {
                lines = 8,
                frequency = 0.25,
                length = 2,
                thickness = 2
            }
        elseif type == "autocast" then
            return {
                particles = 4,
                frequency = 0.25,
                scale = 1.0
            }
        elseif type == "proc" then
            return {duration=1,startAnim=false}
        elseif type == "blizzard" then
            return {
                frequency = 0.125
            }
        elseif type == "dazzle" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "animate" then
            return {
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "pulse" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "custom" then
            return {
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "rotate" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                steps = 4,
                reverse = false
            }
        end
    end

    local template = get_effect_template(effect["type"])
    if not template then
        addon:warn(L["Unknown effect type for %s:%s (%s); record preserved."], prefix, name, tostring(effect.type))
        return
    end
    if template.texture~=nil and type(effect.texture)=="number" then template.texture=1 end
    template["type"] = "texture"
    template["name"] = "some name"
    validate_basic(prefix .. ":" .. name, effect, template, fix)

    if effect["sequence"] then
        local toremove = {}
        for idx, seq in pairs(effect["sequence"]) do
            if effect["type"] == "dazzle" then
                if type(seq) == "table" then
                    local template = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
                    validate_basic(prefix .. ":" .. name .. ":" .. idx, seq, template, fix)
                else
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "animate" then
                if type(seq) ~= "string" and type(seq) ~= "number" then
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "pulse" then
                if type(seq) ~= "number" then
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "custom" then
                if type(seq) == "table" then
                    local template = {
                        texture = type(seq.texture)=="number" and 1 or "some_texture",
                        angle = 0.0,
                        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
                        magnification = 0.0,
                    }
                    validate_basic(prefix .. ":" .. name .. ":" .. idx, seq, template, fix)
                else
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            end
        end
        apply_remove(toremove, effect["sequence"], fix)
    end
end

function addon:validate_announce(prefix, idx, announce, fix)
    if not announce["type"] then
        addon:warn("No announce type for %s:%s", prefix, idx)
        if fix then
            addon.Functions.collections.cleanArray(announce)
        end
        return
    end

    local template = {
        type = "spell",
        disabled = false,
        announce = "party",
        event = "SUCCEEDED",
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        name = "Announcement",
        value = "Some Announce",
        announce_sound = "Sound"
    }

    if announce["type"] == "spell" or announce["type"] == "petspell" or announce["type"] == "pet" then
        template["spell"] = 12345
        template["ranked"] = false
    elseif announce["type"] == "item" then
        template["item"] = {}
    else
        addon:warn("Invalid type for announce %s:%s", prefix, tostring(announce["id"]))
        if fix then
            addon.Functions.collections.cleanArray(announce)
            return
        end
    end

    validate_basic(prefix, announce, template, fix, announce.type=="item" and {item=true} or nil)

    if not announce["id"] or not is_uuid(announce["id"]) then
        addon:warn("Invalid ID for announce %s:%s", prefix, tostring(announce["id"]))
        if fix then
            addon.Functions.collections.cleanArray(announce)
            return
        end
    end

    if announce.type=="item" and not addon:IsValidAnnouncementItemReference(announce.item) then
        local message=fix and L["Invalid item reference for announce %s:%s; reference preserved; announcement disabled."]
            or L["Invalid item reference for announce %s:%s; explicit repair will preserve the reference and disable the announcement."]
        addon:warn(message, prefix, tostring(announce.id))
        if fix then announce.disabled=true end
    end
end

function addon:validate_condition_group(prefix, idx, group, fix)
    local template = {
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        name = "Some Group",
        conditions = {},
        icon = type(group.icon)=="number" and 1 or "Interface\\Icons\\INV_Misc_Book_09"
    }

    validate_basic(prefix .. ":" .. idx, group, template, fix)
    if group.icon~=nil and not (type(group.icon)=="string" and #group.icon>0 and #group.icon<=1024 or type(group.icon)=="number" and group.icon>0 and group.icon<math.huge and group.icon%1==0) then
        addon:warn("Invalid category icon %s:%s",prefix,tostring(idx));if fix then group.icon=nil end
    end
end

function addon:validate_custom_condition(prefix, name, custom_condition, fix)
    local semantic={fields=true,icon=true,disabled=true,fieldOrder=true,bindings=true,parameters=true,requiredFields=true}
    local template={disabled=false,fieldOrder={},bindings={},parameters={},requiredFields={}}
    for key,value in pairs(addon.empty_condition) do template[key]=value end
    validate_basic(prefix .. ":" .. name, custom_condition, template, fix, semantic)

    local function invalid(field,reason)
        local message=fix and L["Invalid custom condition %s:%s field %s (%s); source preserved; condition disabled."]
            or L["Invalid custom condition %s:%s field %s (%s); explicit repair will preserve source and disable the condition."]
        addon:warn(message, prefix, name, field, reason or "invalid-data")
        if fix then
            custom_condition.disabled=true
            local saved=addon.db and addon.db.global and addon.db.global.custom_conditions
            local definition=addon.conditionDefinitions and addon.conditionDefinitions[name]
            if type(saved)=="table" and saved[name]==custom_condition and definition and definition.customCode==true and definition.disabled~=true then
                -- Do not invoke lifecycle hooks or recompile user source from
                -- repair. Selection notices this registry version next pass.
                definition.disabled=true
                addon.conditionRegistryVersion=(addon.conditionRegistryVersion or 0)+1
                if invalidateDependencies then invalidateDependencies(addon,'condition',name) end
            end
        end
    end
    -- Check data contracts only. Repair must not compile callback text, resolve
    -- currently unavailable helper bindings, or execute registration hooks.
    local fields,fieldReason=addon:NormalizeCustomFieldSchema(custom_condition.fields,true)
    if not fields then invalid("fields",fieldReason) end
    if not addon:IsCategoryIcon(custom_condition.icon) then invalid("icon","invalid-icon") end
    if custom_condition.disabled~=nil and type(custom_condition.disabled)~="boolean" then invalid("disabled","invalid-disabled-flag") end
    local parameters,parameterReason=addon:NormalizeCustomConditionParameters(custom_condition.parameters)
    if not parameters then invalid("parameters",parameterReason) end
    if custom_condition.bindings~=nil then
        local arguments={{name="value"},{name="cache"},{name="evalStart"},{name="spec"},{name="parent"},{name="frame"},{name="tag"}}
        for _,aliases in pairs(parameters or {}) do for _,alias in ipairs(aliases) do arguments[#arguments+1]={name=alias} end end
        local bindings,reason=addon:NormalizeFunctionBindings(custom_condition.bindings,arguments)
        if not bindings then invalid("bindings",reason) end
    end
    if custom_condition.requiredFields~=nil and not addon:NormalizeCustomConditionRequiredFields(custom_condition.requiredFields,fields or {}) then invalid("requiredFields","invalid-required-fields") end
    if custom_condition.fieldOrder~=nil and not addon:NormalizeCustomFieldOrder(custom_condition.fieldOrder,fields or {}) then invalid("fieldOrder","invalid-field-order") end
end

local function validate_rotation_condition(prefix, condition, fix)
    if addon.Functions.collections.tablelength(condition) == 0 then
        return
    end

    if type(condition["type"]) ~= "string" then
        addon:warn("Invalid type for %s", prefix)
        if fix then
            addon.Functions.collections.cleanArray(condition)
        end
        return
    end

    local full_id = prefix .. ":" .. condition["type"]
    local fields = addon.Functions.collections.deepcopy(select(4, addon:describeCondition(condition["type"])))
    -- The condition might not exist if you're not playing a class where it is active.
    if not fields then
        return
    end
    fields["type"] = "string"
    fields["disabled"] = "boolean"
    if condition.type=="AND" or condition.type=="OR" or condition.type=="NOT" then fields.name="string" end

    local function handle_array_field(cond, field)
        if type(cond) == "table" then
            for i=1,#field do
                if type(field[i]) == "table" then
                    local allfound = true
                    for j=1,#cond do
                        local subfound = handle_array_field(cond[j], field[i])
                        if not subfound then
                            allfound = false
                            break
                        end
                    end
                    if allfound then
                        return true
                    end
                end
            end
        else
            for i=1,#field do
                if type(field[i]) ~= "table" and type(cond) == field[i] then
                    return true
                end
            end
        end
        return false
    end

    local function handle_fields(cond, f, subtree)
        local keyremove = {}
        for key, data in pairs(cond) do
            local newsubtree = (subtree and (subtree .. ".") or "") .. key
            local field = f[key]
            if field == nil then
                addon:warn("Extra Field %s.%s", full_id, newsubtree)
                mark_for_remove(keyremove, key)
            elseif type(field) == "table" then
                -- The #field specifies this is an array, specifically.
                if #field > 0 then
                    local found = handle_array_field(data, field)
                    if not found then
                        addon:warn("Condition %s.%s has data of the wrong type (got %s)", full_id, newsubtree, type(data))
                        if fix then
                            mark_for_remove(keyremove, key)
                        end
                    end
                elseif type(data) == "table" then
                    handle_fields(data, field, newsubtree)
                else
                    addon:warn("Condition %s.%s has data of the wrong type (got %s)", full_id, newsubtree, type(data))
                    mark_for_remove(keyremove, key)
                end
            elseif field == "condition" then
                validate_rotation_condition(full_id, data, fix)
            elseif type(field) == "string" and type(data) == "table" then
                if addon.Functions.collections.tablelength(data) ~= #data then
                    addon:warn("Condition %s.%s provides a table where an array is required", full_id, subtree)
                    mark_for_remove(keyremove, key)
                elseif #data > 0 then
                    local basetype = field:match("^(.*)%[%]$")
                    if basetype == "condition" then
                        local toremove = {}
                        for i=1,#data do
                            if type(data[i]) == "table" then
                                validate_rotation_condition(full_id .. "[" .. i .. "]", data[i], fix)
                            else
                                addon:warn("Condition %s.%s[%d] has data of the wrong type (expected %s, got %s)", full_id, newsubtree, i, "table", type(data[i]))
                                mark_for_remove(toremove, i)
                            end
                        end
                        apply_remove(toremove, data, fix)
                    elseif basetype then
                        local toremove = {}
                        for i=1,#data do
                            if type(data[i]) ~= basetype then
                                addon:warn("Condition %s.%s[%d] has data of the wrong type (expected %s, got %s)", full_id, newsubtree, i, basetype, type(data[i]))
                                mark_for_remove(toremove, i)
                            end
                        end
                        apply_remove(toremove, data, fix)
                    else
                        addon:error("Unknown field type used in field spec for array on %s:%s", full_id, newsubtree)
                    end
                end
            elseif type(data) ~= field then
                addon:warn("Condition %s.%s has data of the wrong type (expected %s, got %s)", full_id, newsubtree, field, type(data))
                mark_for_remove(keyremove, key)
            end
        end
        apply_remove(keyremove, cond, fix)
    end

    handle_fields(condition, fields)
end

function addon:validate_rotation(prefix, id, rotation, fix)
    if type(rotation)=='table' and rotation.priority~=nil and not self.RotationData.GetRotationPriority(rotation.priority) then
        self:warn(L['Invalid switch priority for %s:%s; explicit repair resets it to zero.'],prefix,id)
        if fix then rotation.priority=nil end
    end
    -- The old template fixer knows only flat actions. Use the non-destructive
    -- schema for branch bodies; never strip their arms or future metadata.
    if type(rotation)=="table" and type(rotation.rotation)=="table" then
        for _,step in pairs(rotation.rotation) do
            if type(step)=="table" and step.type=="branch" then
                local settings=self.GetImportValidationOptions and self:GetImportValidationOptions() or {conditions=self.conditionDefinitions}
                local result=self.RotationData.ValidateBody(rotation,settings)
                for _,diagnostic in ipairs(result.diagnostics) do self:warn("%s:%s %s",prefix,id,diagnostic.code.." "..diagnostic.path) end
                return
            end
        end
    end
    if id ~= DEFAULT and not is_uuid(id) then
        addon:warn("Invalid ID for rotation %s:%s", prefix, id)
        if fix then
            addon.Functions.collections.cleanArray(rotation)
            return
        end
    end

    local template = {
        name = "Some Name",
        description = "Rotation description",
        metadata = {},
        tags = {},
        priority = 0,
        disabled = false,
        switch = {},
        cooldowns = {},
        rotation = {}
    }
    validate_basic(prefix .. ":" .. id, rotation, template, fix)

    if id ~= DEFAULT and not rotation["name"] then
        addon:warn("Unnamed non-default rotation %s:%s", prefix, id)
        if fix then
            addon.Functions.collections.cleanArray(rotation)
            return
        end
    end

    -- Normal actions and cooldown actions share the persisted appearance
    -- schema. These examples validate types; they never materialize defaults.
    local rotation_template = {
        use_name = false,
        name = "Some cool name",
        effect = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        type = "spell",
        ranked = false,
        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        magnification = 1.4,
        setpoint = "CENTER",
        xoffs = 0.0,
        yoffs = 0.0,
        announce = "None",
        announce_sound = "LoudSound",
        disabled = false,
        conditions = {},
    }
    local cooldown_template = addon.Functions.collections.deepcopy(rotation_template)

    local function augment_template_type(template, rot)
        if rot.type=="none" then template.suppress_attack=false end
        if rot.type=="spell" or rot.type=="pet" or rot.type=="any" or rot.type=="petspell" or rot.type=="anyspell" then
            template["action"] = 1234
        elseif rot["type"] == "item" then
            if type(rot["action"]) == "table" then
                template["action"] = {}
            else
                template["action"] = "61b36ed1-fa31-4656-ad71-f3d50f193a85"
            end
        end
    end

    if rotation["cooldowns"] then
        local toremove = {}
        for idx, rot in pairs(rotation["cooldowns"]) do
            local template = addon.Functions.collections.deepcopy(cooldown_template)
            augment_template_type(template, rot)
            validate_basic(prefix .. ":" .. id .. ":cooldown:" .. idx, rot, template, fix)
            if not is_uuid(rot["id"]) then
                addon:warn("Invalid ID for cooldown %s:%s:%d", prefix, id, idx)
                mark_for_remove(toremove, idx)
            end
            if rot["effect"] and not is_uuid(rot["effect"]) then
                addon:warn("Invalid effect ID for cooldown %s:%s:%d", prefix, id, idx)
                if fix then
                    rot["effect"] = nil
                end
            end
            if rot["type"] == "item" then
                if type(rot["action"]) == "table" then
                    validate_itemset_items(prefix .. ":" .. id .. ":cooldown", idx, rot["action"], fix)
                elseif type(rot["action"]) ~= "string" then
                    addon:warn("Invalid type for item action in cooldown %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                elseif not is_uuid(rot["action"]) then
                    addon:warn("Invalid itemset ID for cooldown %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                end
            end
            if rot["conditions"] then
                validate_rotation_condition( string.format("%s:%s:cooldowns:%d", prefix, id, idx),
                        rot["conditions"], fix)
            end
            if addon.Functions.collections.tablelength(rot) == 0 then
                mark_for_remove(toremove, idx)
            end
        end
        apply_remove(toremove, rotation["cooldowns"], fix)
    end

    if rotation["rotation"] then
        local toremove = {}
        for idx, rot in pairs(rotation["rotation"]) do
            local template = addon.Functions.collections.deepcopy(rotation_template)
            augment_template_type(template, rot)
            validate_basic(prefix .. ":" .. id .. ":rotation:" .. idx, rot, template, fix)
            if not is_uuid(rot["id"]) then
                addon:warn("Invalid ID for rotation step %s:%s:%d", prefix, id, idx)
                mark_for_remove(toremove, idx)
            end
            if rot.effect and not is_uuid(rot.effect) then
                addon:warn(L["Invalid effect ID for rotation step %s:%s:%d."], prefix, id, idx)
                if fix then rot.effect=nil end
            end
            if rot["type"] == "item" then
                if type(rot["action"]) == "table" then
                    validate_itemset_items(prefix .. ":" .. id .. ":rotation", idx, rot["action"], fix)
                elseif type(rot["action"]) ~= "string" then
                    addon:warn("Invalid type for item action in rotation %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                elseif not is_uuid(rot["action"]) then
                    addon:warn("Invalid itemset ID for rotation %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                end
            end
            if rot["conditions"] then
                validate_rotation_condition( string.format("%s:%s:rotation:%d", prefix, id, idx),
                        rot["conditions"], fix)
            end
            if addon.Functions.collections.tablelength(rot) == 0 then
                mark_for_remove(toremove, idx)
            end
        end
        apply_remove(toremove, rotation["rotation"], fix)
    end

    if rotation["switch"] then
        validate_rotation_condition( string.format("%s:%s:switch", prefix, id),
                rotation["switch"], fix)
    end
end

function addon:validate(template, fix)
    if fix then if invalidateDependencies then invalidateDependencies(addon,'all',nil) end end
    local DB = _G[self.savedVariableName or "RotationMasterDB"]

    local glob_template = addon.Functions.collections.deepcopy(template.global)
    glob_template.itemsets = {}
    glob_template.effects = {}
    validate_basic("global", DB.global, glob_template, fix)

    if DB.global.itemsets then
        local toremove = {}
        for name, itemset in pairs(DB.global.itemsets) do
            addon:validate_itemset("global", name, itemset, fix)
            if addon.Functions.collections.tablelength(itemset) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.itemsets, fix)
    end

    if DB.global.effects then
        local toremove = {}
        for name, effect in pairs(DB.global.effects) do
            addon:validate_effect("global", name, effect, fix)
            if addon.Functions.collections.tablelength(effect) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.effects, fix)
    end

    if DB.global.custom_conditions then
        local toremove = {}
        for name, custom_condition in pairs(DB.global.custom_conditions) do
            addon:validate_custom_condition("global", name, custom_condition, fix)
            if addon.Functions.collections.tablelength(custom_condition) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.custom_conditions, fix)
    end

    -- Offline characters can still own their v1 data until their explicit
    -- login migration. Recognize these roots without moving or inspecting them.
    local char_template=addon.Functions.collections.deepcopy(template.char)
    char_template.rotations={}
    char_template.itemsets={}
    char_template.announces={}
    for char, data in pairs(DB.char) do
        validate_basic("char:" .. char, data, char_template, fix)
        if data.bindings then
            local toremove = {}
            for id,buttons in pairs(data.bindings) do
                if not is_uuid(id) then
                    addon:warn("Binding for invalid itemset %s", id)
                    if fix then
                        mark_for_remove(toremove, id)
                    end
                end

                local i = 1
                while i <= #buttons do
                    if type(buttons[i]) ~= "number" then
                        addon:warn("Invalid button ID in button bindings %s:%s", char, id)
                        if fix then
                            table.remove(buttons, i)
                        else
                            i = i + 1
                        end
                    else
                        i = i + 1
                    end
                end
                if #buttons == 0 then
                    mark_for_remove(toremove, id)
                end
            end
            apply_remove(toremove, data.bindings, fix)
        end
    end

    -- These optional library-owned values are recognized schema, not defaults:
    -- their absence preserves LibDBIcon's own placement and interaction policy.
    local profile_template=addon.Functions.collections.deepcopy(template.profile)
    if type(profile_template.minimap)=="table" then
        profile_template.minimap=addon.Functions.collections.deepcopy(profile_template.minimap)
        profile_template.minimap.minimapPos=0
        profile_template.minimap.radius=0
        profile_template.minimap.lock=false
        profile_template.minimap.showInCompartment=false
    end
    for profile, data in pairs(DB.profiles) do
        -- Ownership archives must never be removed by the legacy shape repair.
        -- Their pure schema is validated independently, without guessing owners
        -- or mutating a future/invalid format that may need explicit recovery.
        validate_basic("profile:" .. profile, data, profile_template, fix,{stockTargets=true,rotationStore=true,rotationFallbackID=true,rotations=addon.InitializeScopedRotationStorage~=nil,rotationLibrary=addon.InitializeScopedRotationStorage~=nil})
        local stockTargets=rawget(data,'stockTargets')
        if stockTargets~=nil then
            local ok,why=addon.StockTargets.Validate(stockTargets)
            if not ok then addon:warn(L['Invalid stock targets in profile %s (%s); data preserved.'],profile,why) end
        end
        local fallback=data.rotationFallbackID
        if (data.rotationStore~=nil or fallback~=nil) and (type(fallback)~='string' or #fallback==0 or #fallback>128 or not fallback:find('%S') or fallback:find('[%z\1-\31\127]')) then
            addon:warn(L['Invalid rotation fallback configuration in profile %s; data preserved.'],profile)
        end
        if data.rotationStore~=nil then
            local ok,why=addon.RotationData.ValidateRotationStore(data.rotationStore)
            if not ok then addon:warn(L["Invalid rotation ownership data in profile %s (%s); record preserved."],profile,tostring(why)) end
        end
        if type(data.minimap)=="table" then
            for _,key in ipairs({"minimapPos","radius"}) do
                local value=data.minimap[key]
                if type(value)=="number" and (value~=value or value==math.huge or value==-math.huge) then
                    addon:warn(L["Non-finite minimap value in profile %s: %s."], profile, key)
                    if fix then data.minimap[key]=nil end
                end
            end
        end

        if data.itemsets then
            local toremove = {}
            for name, itemset in pairs(data.itemsets) do
                addon:validate_itemset("profile:" .. profile, name, itemset, fix)
                if addon.Functions.collections.tablelength(itemset) == 0 then
                    mark_for_remove(toremove, name)
                end
            end
            apply_remove(toremove, data.itemsets, fix)
        end

        if data.announces then
            local toremove = {}
            for idx, announce in pairs(data.announces) do
                addon:validate_announce("profile:" .. profile, idx, announce, fix)
                if addon.Functions.collections.tablelength(announce) == 0 then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.announces, fix)
        end

        if data.rotations and not addon.InitializeScopedRotationStorage then
            local specremove = {}
            for spec, rotations in pairs(data.rotations) do
                if type(spec) ~= "number" then
                    table.insert(specremove, spec)
                end
                local toremove = {}
                for id, rotation in pairs(rotations) do
                    addon:validate_rotation("profile:" .. profile .. ":" .. spec, id, rotation, fix)
                    if addon.Functions.collections.tablelength(rotation) == 0 then
                        mark_for_remove(toremove, id)
                    end
                end
                apply_remove(toremove, rotations, fix)
            end
            if fix then
                for _, key in pairs(specremove) do
                    data.rotations[key] = nil
                end
            end
        end

        if data.condition_groups then
            local toremove = {}
            for idx,group in pairs(data.condition_groups) do
                if type(idx) ~= "number" then
                    mark_for_remove(toremove, idx)
                end
                addon:validate_condition_group("profile:" .. profile, idx, group, fix)
                if addon.Functions.collections.tablelength(group) == 0 then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.condition_groups, fix)
        end

        local toremove = {}
        if data.switch_conditions then
            for idx,cond in pairs(data.switch_conditions) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.switch_conditions, fix)
        end

        if data.other_conditions_order then
            for idx,cond in pairs(data.other_conditions_order) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.other_conditions_order, fix)
        end

        if data.disabled_conditions then
            for idx,cond in pairs(data.disabled_conditions) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.disabled_conditions, fix)
        end
    end
    if fix then if invalidateDependencies then invalidateDependencies(addon,'all',nil) end end
end
]=],baseline=[=[local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

local function mark_for_remove(toremove, key)
    if type(key) ~= "number" or key < 1 then
        toremove.not_array = true
    end
    if not toremove.data then
        toremove.data = {}
    end
    table.insert(toremove.data, key)
end

local function apply_remove(toremove, tbl, fix)
    if fix and toremove.data then
        if toremove.not_array then
            for _, key in pairs(toremove.data) do
                tbl[key] = nil
            end
        else
            local offs = 0
            for idx=1,#toremove.data do
                table.remove(tbl, toremove.data[idx] - offs)
                offs = offs + 1
            end
        end
    end

    addon.Functions.collections.cleanArray(toremove)
end

local function validate_basic(prefix, data, template, fix, preserved)
    local toremove = {}
    for k,v in pairs(data) do
        if preserved and preserved[k] then
            -- Semantic source metadata has its own non-destructive validator.
        elseif template[k] == nil then
            addon:warn("Extra Field %s:%s", prefix, tostring(k))
            mark_for_remove(toremove, k)
        elseif type(v) ~= type(template[k]) then
            addon:warn("Incorrect type for %s:%s (was %s, expected %s)", prefix, tostring(k), type(v), type(template[k]))
            mark_for_remove(toremove, k)
        elseif type(v) == "table" then
            if addon.Functions.collections.tablelength(template[k]) > 0 and #template[k] == 0 then
                validate_basic(prefix .. ":" .. k, v, template[k], fix)
            end
        end
    end
    apply_remove(toremove, data, fix)
end

local function validate_itemset_items(prefix, name, items, fix)
    local toremove = {}
    for idx, item in pairs(items) do
        if type(item) ~= "string" and type(item) ~= "number" then
            addon:warn("Invalid item in itemset %s:%s", prefix, name)
            mark_for_remove(toremove, idx)
        end
    end
    apply_remove(toremove, items, fix)
end

local function is_uuid(uuid)
    return type(uuid) == "string" and uuid:match("(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)") ~= nil
end

function addon:validate_itemset(prefix, name, itemset, fix)
    if not is_uuid(name) then
        addon:warn("Invalid ID for itemset %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(itemset)
            return
        end
    end
    local template = {
        modified = false,
        name = "test",
        items = {}
    }
    validate_basic(prefix .. ":" .. name, itemset, template, fix)
    validate_itemset_items(prefix, name, itemset.items, fix)
end

function addon:validate_effect(prefix, name, effect, fix)
    if not is_uuid(name) then
        addon:warn("Invalid ID for effect %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(effect)
            return
        end
    end
    if not effect["type"] then
        addon:warn("No effect type for %s:%s", prefix, name)
        if fix then
            addon.Functions.collections.cleanArray(effect)
        end
        return
    end

    local function get_effect_template(type)
        if type == "texture" then
            return {
                texture = "some_texture"
            }
        elseif type == "pixel" then
            return {
                lines = 8,
                frequency = 0.25,
                length = 2,
                thickness = 2
            }
        elseif type == "autocast" then
            return {
                particles = 4,
                frequency = 0.25,
                scale = 1.0
            }
        elseif type == "proc" then
            return {duration=1,startAnim=false}
        elseif type == "blizzard" then
            return {
                frequency = 0.125
            }
        elseif type == "dazzle" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "animate" then
            return {
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "pulse" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "custom" then
            return {
                frequency = 0.25,
                sequence = {},
            }
        elseif type == "rotate" then
            return {
                texture = "some_texture",
                frequency = 0.25,
                steps = 4,
                reverse = false
            }
        end
    end

    local template = get_effect_template(effect["type"])
    if not template then
        addon:warn(L["Unknown effect type for %s:%s (%s); record preserved."], prefix, name, tostring(effect.type))
        return
    end
    if template.texture~=nil and type(effect.texture)=="number" then template.texture=1 end
    template["type"] = "texture"
    template["name"] = "some name"
    validate_basic(prefix .. ":" .. name, effect, template, fix)

    if effect["sequence"] then
        local toremove = {}
        for idx, seq in pairs(effect["sequence"]) do
            if effect["type"] == "dazzle" then
                if type(seq) == "table" then
                    local template = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
                    validate_basic(prefix .. ":" .. name .. ":" .. idx, seq, template, fix)
                else
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "animate" then
                if type(seq) ~= "string" and type(seq) ~= "number" then
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "pulse" then
                if type(seq) ~= "number" then
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            elseif effect["type"] == "custom" then
                if type(seq) == "table" then
                    local template = {
                        texture = type(seq.texture)=="number" and 1 or "some_texture",
                        angle = 0.0,
                        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
                        magnification = 0.0,
                    }
                    validate_basic(prefix .. ":" .. name .. ":" .. idx, seq, template, fix)
                else
                    addon:warn("Invalid type on %s effect sequence %s:%s:%d", effect["type"], prefix, name, idx)
                    mark_for_remove(toremove, idx)
                end
            end
        end
        apply_remove(toremove, effect["sequence"], fix)
    end
end

function addon:validate_announce(prefix, idx, announce, fix)
    if not announce["type"] then
        addon:warn("No announce type for %s:%s", prefix, idx)
        if fix then
            addon.Functions.collections.cleanArray(announce)
        end
        return
    end

    local template = {
        type = "spell",
        disabled = false,
        announce = "party",
        event = "SUCCEEDED",
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        name = "Announcement",
        value = "Some Announce",
        announce_sound = "Sound"
    }

    if announce["type"] == "spell" or announce["type"] == "petspell" or announce["type"] == "pet" then
        template["spell"] = 12345
        template["ranked"] = false
    elseif announce["type"] == "item" then
        template["item"] = {}
    else
        addon:warn("Invalid type for announce %s:%s", prefix, tostring(announce["id"]))
        if fix then
            addon.Functions.collections.cleanArray(announce)
            return
        end
    end

    validate_basic(prefix, announce, template, fix, announce.type=="item" and {item=true} or nil)

    if not announce["id"] or not is_uuid(announce["id"]) then
        addon:warn("Invalid ID for announce %s:%s", prefix, tostring(announce["id"]))
        if fix then
            addon.Functions.collections.cleanArray(announce)
            return
        end
    end

    if announce.type=="item" and not addon:IsValidAnnouncementItemReference(announce.item) then
        local message=fix and L["Invalid item reference for announce %s:%s; reference preserved; announcement disabled."]
            or L["Invalid item reference for announce %s:%s; explicit repair will preserve the reference and disable the announcement."]
        addon:warn(message, prefix, tostring(announce.id))
        if fix then announce.disabled=true end
    end
end

function addon:validate_condition_group(prefix, idx, group, fix)
    local template = {
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        name = "Some Group",
        conditions = {},
        icon = type(group.icon)=="number" and 1 or "Interface\\Icons\\INV_Misc_Book_09"
    }

    validate_basic(prefix .. ":" .. idx, group, template, fix)
    if group.icon~=nil and not (type(group.icon)=="string" and #group.icon>0 and #group.icon<=1024 or type(group.icon)=="number" and group.icon>0 and group.icon<math.huge and group.icon%1==0) then
        addon:warn("Invalid category icon %s:%s",prefix,tostring(idx));if fix then group.icon=nil end
    end
end

function addon:validate_custom_condition(prefix, name, custom_condition, fix)
    local semantic={fields=true,icon=true,disabled=true,fieldOrder=true,bindings=true,parameters=true,requiredFields=true}
    local template={disabled=false,fieldOrder={},bindings={},parameters={},requiredFields={}}
    for key,value in pairs(addon.empty_condition) do template[key]=value end
    validate_basic(prefix .. ":" .. name, custom_condition, template, fix, semantic)

    local function invalid(field,reason)
        local message=fix and L["Invalid custom condition %s:%s field %s (%s); source preserved; condition disabled."]
            or L["Invalid custom condition %s:%s field %s (%s); explicit repair will preserve source and disable the condition."]
        addon:warn(message, prefix, name, field, reason or "invalid-data")
        if fix then
            custom_condition.disabled=true
            local saved=addon.db and addon.db.global and addon.db.global.custom_conditions
            local definition=addon.conditionDefinitions and addon.conditionDefinitions[name]
            if type(saved)=="table" and saved[name]==custom_condition and definition and definition.customCode==true and definition.disabled~=true then
                -- Do not invoke lifecycle hooks or recompile user source from
                -- repair. Selection notices this registry version next pass.
                definition.disabled=true
                addon.conditionRegistryVersion=(addon.conditionRegistryVersion or 0)+1
            end
        end
    end
    -- Check data contracts only. Repair must not compile callback text, resolve
    -- currently unavailable helper bindings, or execute registration hooks.
    local fields,fieldReason=addon:NormalizeCustomFieldSchema(custom_condition.fields,true)
    if not fields then invalid("fields",fieldReason) end
    if not addon:IsCategoryIcon(custom_condition.icon) then invalid("icon","invalid-icon") end
    if custom_condition.disabled~=nil and type(custom_condition.disabled)~="boolean" then invalid("disabled","invalid-disabled-flag") end
    local parameters,parameterReason=addon:NormalizeCustomConditionParameters(custom_condition.parameters)
    if not parameters then invalid("parameters",parameterReason) end
    if custom_condition.bindings~=nil then
        local arguments={{name="value"},{name="cache"},{name="evalStart"},{name="spec"},{name="parent"},{name="frame"},{name="tag"}}
        for _,aliases in pairs(parameters or {}) do for _,alias in ipairs(aliases) do arguments[#arguments+1]={name=alias} end end
        local bindings,reason=addon:NormalizeFunctionBindings(custom_condition.bindings,arguments)
        if not bindings then invalid("bindings",reason) end
    end
    if custom_condition.requiredFields~=nil and not addon:NormalizeCustomConditionRequiredFields(custom_condition.requiredFields,fields or {}) then invalid("requiredFields","invalid-required-fields") end
    if custom_condition.fieldOrder~=nil and not addon:NormalizeCustomFieldOrder(custom_condition.fieldOrder,fields or {}) then invalid("fieldOrder","invalid-field-order") end
end

local function validate_rotation_condition(prefix, condition, fix)
    if addon.Functions.collections.tablelength(condition) == 0 then
        return
    end

    if type(condition["type"]) ~= "string" then
        addon:warn("Invalid type for %s", prefix)
        if fix then
            addon.Functions.collections.cleanArray(condition)
        end
        return
    end

    local full_id = prefix .. ":" .. condition["type"]
    local fields = addon.Functions.collections.deepcopy(select(4, addon:describeCondition(condition["type"])))
    -- The condition might not exist if you're not playing a class where it is active.
    if not fields then
        return
    end
    fields["type"] = "string"
    fields["disabled"] = "boolean"
    if condition.type=="AND" or condition.type=="OR" or condition.type=="NOT" then fields.name="string" end

    local function handle_array_field(cond, field)
        if type(cond) == "table" then
            for i=1,#field do
                if type(field[i]) == "table" then
                    local allfound = true
                    for j=1,#cond do
                        local subfound = handle_array_field(cond[j], field[i])
                        if not subfound then
                            allfound = false
                            break
                        end
                    end
                    if allfound then
                        return true
                    end
                end
            end
        else
            for i=1,#field do
                if type(field[i]) ~= "table" and type(cond) == field[i] then
                    return true
                end
            end
        end
        return false
    end

    local function handle_fields(cond, f, subtree)
        local keyremove = {}
        for key, data in pairs(cond) do
            local newsubtree = (subtree and (subtree .. ".") or "") .. key
            local field = f[key]
            if field == nil then
                addon:warn("Extra Field %s.%s", full_id, newsubtree)
                mark_for_remove(keyremove, key)
            elseif type(field) == "table" then
                -- The #field specifies this is an array, specifically.
                if #field > 0 then
                    local found = handle_array_field(data, field)
                    if not found then
                        addon:warn("Condition %s.%s has data of the wrong type (got %s)", full_id, newsubtree, type(data))
                        if fix then
                            mark_for_remove(keyremove, key)
                        end
                    end
                elseif type(data) == "table" then
                    handle_fields(data, field, newsubtree)
                else
                    addon:warn("Condition %s.%s has data of the wrong type (got %s)", full_id, newsubtree, type(data))
                    mark_for_remove(keyremove, key)
                end
            elseif field == "condition" then
                validate_rotation_condition(full_id, data, fix)
            elseif type(field) == "string" and type(data) == "table" then
                if addon.Functions.collections.tablelength(data) ~= #data then
                    addon:warn("Condition %s.%s provides a table where an array is required", full_id, subtree)
                    mark_for_remove(keyremove, key)
                elseif #data > 0 then
                    local basetype = field:match("^(.*)%[%]$")
                    if basetype == "condition" then
                        local toremove = {}
                        for i=1,#data do
                            if type(data[i]) == "table" then
                                validate_rotation_condition(full_id .. "[" .. i .. "]", data[i], fix)
                            else
                                addon:warn("Condition %s.%s[%d] has data of the wrong type (expected %s, got %s)", full_id, newsubtree, i, "table", type(data[i]))
                                mark_for_remove(toremove, i)
                            end
                        end
                        apply_remove(toremove, data, fix)
                    elseif basetype then
                        local toremove = {}
                        for i=1,#data do
                            if type(data[i]) ~= basetype then
                                addon:warn("Condition %s.%s[%d] has data of the wrong type (expected %s, got %s)", full_id, newsubtree, i, basetype, type(data[i]))
                                mark_for_remove(toremove, i)
                            end
                        end
                        apply_remove(toremove, data, fix)
                    else
                        addon:error("Unknown field type used in field spec for array on %s:%s", full_id, newsubtree)
                    end
                end
            elseif type(data) ~= field then
                addon:warn("Condition %s.%s has data of the wrong type (expected %s, got %s)", full_id, newsubtree, field, type(data))
                mark_for_remove(keyremove, key)
            end
        end
        apply_remove(keyremove, cond, fix)
    end

    handle_fields(condition, fields)
end

function addon:validate_rotation(prefix, id, rotation, fix)
    if type(rotation)=='table' and rotation.priority~=nil and not self.RotationData.GetRotationPriority(rotation.priority) then
        self:warn(L['Invalid switch priority for %s:%s; explicit repair resets it to zero.'],prefix,id)
        if fix then rotation.priority=nil end
    end
    -- The old template fixer knows only flat actions. Use the non-destructive
    -- schema for branch bodies; never strip their arms or future metadata.
    if type(rotation)=="table" and type(rotation.rotation)=="table" then
        for _,step in pairs(rotation.rotation) do
            if type(step)=="table" and step.type=="branch" then
                local settings=self.GetImportValidationOptions and self:GetImportValidationOptions() or {conditions=self.conditionDefinitions}
                local result=self.RotationData.ValidateBody(rotation,settings)
                for _,diagnostic in ipairs(result.diagnostics) do self:warn("%s:%s %s",prefix,id,diagnostic.code.." "..diagnostic.path) end
                return
            end
        end
    end
    if id ~= DEFAULT and not is_uuid(id) then
        addon:warn("Invalid ID for rotation %s:%s", prefix, id)
        if fix then
            addon.Functions.collections.cleanArray(rotation)
            return
        end
    end

    local template = {
        name = "Some Name",
        description = "Rotation description",
        metadata = {},
        tags = {},
        priority = 0,
        disabled = false,
        switch = {},
        cooldowns = {},
        rotation = {}
    }
    validate_basic(prefix .. ":" .. id, rotation, template, fix)

    if id ~= DEFAULT and not rotation["name"] then
        addon:warn("Unnamed non-default rotation %s:%s", prefix, id)
        if fix then
            addon.Functions.collections.cleanArray(rotation)
            return
        end
    end

    -- Normal actions and cooldown actions share the persisted appearance
    -- schema. These examples validate types; they never materialize defaults.
    local rotation_template = {
        use_name = false,
        name = "Some cool name",
        effect = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        id = "61b36ed1-fa31-4656-ad71-f3d50f193a85",
        type = "spell",
        ranked = false,
        color = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        magnification = 1.4,
        setpoint = "CENTER",
        xoffs = 0.0,
        yoffs = 0.0,
        announce = "None",
        announce_sound = "LoudSound",
        disabled = false,
        conditions = {},
    }
    local cooldown_template = addon.Functions.collections.deepcopy(rotation_template)

    local function augment_template_type(template, rot)
        if rot.type=="none" then template.suppress_attack=false end
        if rot.type=="spell" or rot.type=="pet" or rot.type=="any" or rot.type=="petspell" or rot.type=="anyspell" then
            template["action"] = 1234
        elseif rot["type"] == "item" then
            if type(rot["action"]) == "table" then
                template["action"] = {}
            else
                template["action"] = "61b36ed1-fa31-4656-ad71-f3d50f193a85"
            end
        end
    end

    if rotation["cooldowns"] then
        local toremove = {}
        for idx, rot in pairs(rotation["cooldowns"]) do
            local template = addon.Functions.collections.deepcopy(cooldown_template)
            augment_template_type(template, rot)
            validate_basic(prefix .. ":" .. id .. ":cooldown:" .. idx, rot, template, fix)
            if not is_uuid(rot["id"]) then
                addon:warn("Invalid ID for cooldown %s:%s:%d", prefix, id, idx)
                mark_for_remove(toremove, idx)
            end
            if rot["effect"] and not is_uuid(rot["effect"]) then
                addon:warn("Invalid effect ID for cooldown %s:%s:%d", prefix, id, idx)
                if fix then
                    rot["effect"] = nil
                end
            end
            if rot["type"] == "item" then
                if type(rot["action"]) == "table" then
                    validate_itemset_items(prefix .. ":" .. id .. ":cooldown", idx, rot["action"], fix)
                elseif type(rot["action"]) ~= "string" then
                    addon:warn("Invalid type for item action in cooldown %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                elseif not is_uuid(rot["action"]) then
                    addon:warn("Invalid itemset ID for cooldown %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                end
            end
            if rot["conditions"] then
                validate_rotation_condition( string.format("%s:%s:cooldowns:%d", prefix, id, idx),
                        rot["conditions"], fix)
            end
            if addon.Functions.collections.tablelength(rot) == 0 then
                mark_for_remove(toremove, idx)
            end
        end
        apply_remove(toremove, rotation["cooldowns"], fix)
    end

    if rotation["rotation"] then
        local toremove = {}
        for idx, rot in pairs(rotation["rotation"]) do
            local template = addon.Functions.collections.deepcopy(rotation_template)
            augment_template_type(template, rot)
            validate_basic(prefix .. ":" .. id .. ":rotation:" .. idx, rot, template, fix)
            if not is_uuid(rot["id"]) then
                addon:warn("Invalid ID for rotation step %s:%s:%d", prefix, id, idx)
                mark_for_remove(toremove, idx)
            end
            if rot.effect and not is_uuid(rot.effect) then
                addon:warn(L["Invalid effect ID for rotation step %s:%s:%d."], prefix, id, idx)
                if fix then rot.effect=nil end
            end
            if rot["type"] == "item" then
                if type(rot["action"]) == "table" then
                    validate_itemset_items(prefix .. ":" .. id .. ":rotation", idx, rot["action"], fix)
                elseif type(rot["action"]) ~= "string" then
                    addon:warn("Invalid type for item action in rotation %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                elseif not is_uuid(rot["action"]) then
                    addon:warn("Invalid itemset ID for rotation %s:%s:%d", prefix, id, idx)
                    if fix then
                        rot["action"] = nil
                    end
                end
            end
            if rot["conditions"] then
                validate_rotation_condition( string.format("%s:%s:rotation:%d", prefix, id, idx),
                        rot["conditions"], fix)
            end
            if addon.Functions.collections.tablelength(rot) == 0 then
                mark_for_remove(toremove, idx)
            end
        end
        apply_remove(toremove, rotation["rotation"], fix)
    end

    if rotation["switch"] then
        validate_rotation_condition( string.format("%s:%s:switch", prefix, id),
                rotation["switch"], fix)
    end
end

function addon:validate(template, fix)
    local DB = _G[self.savedVariableName or "RotationMasterDB"]

    local glob_template = addon.Functions.collections.deepcopy(template.global)
    glob_template.itemsets = {}
    glob_template.effects = {}
    validate_basic("global", DB.global, glob_template, fix)

    if DB.global.itemsets then
        local toremove = {}
        for name, itemset in pairs(DB.global.itemsets) do
            addon:validate_itemset("global", name, itemset, fix)
            if addon.Functions.collections.tablelength(itemset) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.itemsets, fix)
    end

    if DB.global.effects then
        local toremove = {}
        for name, effect in pairs(DB.global.effects) do
            addon:validate_effect("global", name, effect, fix)
            if addon.Functions.collections.tablelength(effect) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.effects, fix)
    end

    if DB.global.custom_conditions then
        local toremove = {}
        for name, custom_condition in pairs(DB.global.custom_conditions) do
            addon:validate_custom_condition("global", name, custom_condition, fix)
            if addon.Functions.collections.tablelength(custom_condition) == 0 then
                mark_for_remove(toremove, name)
            end
        end
        apply_remove(toremove, DB.global.custom_conditions, fix)
    end

    -- Offline characters can still own their v1 data until their explicit
    -- login migration. Recognize these roots without moving or inspecting them.
    local char_template=addon.Functions.collections.deepcopy(template.char)
    char_template.rotations={}
    char_template.itemsets={}
    char_template.announces={}
    for char, data in pairs(DB.char) do
        validate_basic("char:" .. char, data, char_template, fix)
        if data.bindings then
            local toremove = {}
            for id,buttons in pairs(data.bindings) do
                if not is_uuid(id) then
                    addon:warn("Binding for invalid itemset %s", id)
                    if fix then
                        mark_for_remove(toremove, id)
                    end
                end

                local i = 1
                while i <= #buttons do
                    if type(buttons[i]) ~= "number" then
                        addon:warn("Invalid button ID in button bindings %s:%s", char, id)
                        if fix then
                            table.remove(buttons, i)
                        else
                            i = i + 1
                        end
                    else
                        i = i + 1
                    end
                end
                if #buttons == 0 then
                    mark_for_remove(toremove, id)
                end
            end
            apply_remove(toremove, data.bindings, fix)
        end
    end

    -- These optional library-owned values are recognized schema, not defaults:
    -- their absence preserves LibDBIcon's own placement and interaction policy.
    local profile_template=addon.Functions.collections.deepcopy(template.profile)
    if type(profile_template.minimap)=="table" then
        profile_template.minimap=addon.Functions.collections.deepcopy(profile_template.minimap)
        profile_template.minimap.minimapPos=0
        profile_template.minimap.radius=0
        profile_template.minimap.lock=false
        profile_template.minimap.showInCompartment=false
    end
    for profile, data in pairs(DB.profiles) do
        -- Ownership archives must never be removed by the legacy shape repair.
        -- Their pure schema is validated independently, without guessing owners
        -- or mutating a future/invalid format that may need explicit recovery.
        validate_basic("profile:" .. profile, data, profile_template, fix,{stockTargets=true,rotationStore=true,rotationFallbackID=true,rotations=addon.InitializeScopedRotationStorage~=nil,rotationLibrary=addon.InitializeScopedRotationStorage~=nil})
        local stockTargets=rawget(data,'stockTargets')
        if stockTargets~=nil then
            local ok,why=addon.StockTargets.Validate(stockTargets)
            if not ok then addon:warn(L['Invalid stock targets in profile %s (%s); data preserved.'],profile,why) end
        end
        local fallback=data.rotationFallbackID
        if (data.rotationStore~=nil or fallback~=nil) and (type(fallback)~='string' or #fallback==0 or #fallback>128 or not fallback:find('%S') or fallback:find('[%z\1-\31\127]')) then
            addon:warn(L['Invalid rotation fallback configuration in profile %s; data preserved.'],profile)
        end
        if data.rotationStore~=nil then
            local ok,why=addon.RotationData.ValidateRotationStore(data.rotationStore)
            if not ok then addon:warn(L["Invalid rotation ownership data in profile %s (%s); record preserved."],profile,tostring(why)) end
        end
        if type(data.minimap)=="table" then
            for _,key in ipairs({"minimapPos","radius"}) do
                local value=data.minimap[key]
                if type(value)=="number" and (value~=value or value==math.huge or value==-math.huge) then
                    addon:warn(L["Non-finite minimap value in profile %s: %s."], profile, key)
                    if fix then data.minimap[key]=nil end
                end
            end
        end

        if data.itemsets then
            local toremove = {}
            for name, itemset in pairs(data.itemsets) do
                addon:validate_itemset("profile:" .. profile, name, itemset, fix)
                if addon.Functions.collections.tablelength(itemset) == 0 then
                    mark_for_remove(toremove, name)
                end
            end
            apply_remove(toremove, data.itemsets, fix)
        end

        if data.announces then
            local toremove = {}
            for idx, announce in pairs(data.announces) do
                addon:validate_announce("profile:" .. profile, idx, announce, fix)
                if addon.Functions.collections.tablelength(announce) == 0 then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.announces, fix)
        end

        if data.rotations and not addon.InitializeScopedRotationStorage then
            local specremove = {}
            for spec, rotations in pairs(data.rotations) do
                if type(spec) ~= "number" then
                    table.insert(specremove, spec)
                end
                local toremove = {}
                for id, rotation in pairs(rotations) do
                    addon:validate_rotation("profile:" .. profile .. ":" .. spec, id, rotation, fix)
                    if addon.Functions.collections.tablelength(rotation) == 0 then
                        mark_for_remove(toremove, id)
                    end
                end
                apply_remove(toremove, rotations, fix)
            end
            if fix then
                for _, key in pairs(specremove) do
                    data.rotations[key] = nil
                end
            end
        end

        if data.condition_groups then
            local toremove = {}
            for idx,group in pairs(data.condition_groups) do
                if type(idx) ~= "number" then
                    mark_for_remove(toremove, idx)
                end
                addon:validate_condition_group("profile:" .. profile, idx, group, fix)
                if addon.Functions.collections.tablelength(group) == 0 then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.condition_groups, fix)
        end

        local toremove = {}
        if data.switch_conditions then
            for idx,cond in pairs(data.switch_conditions) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.switch_conditions, fix)
        end

        if data.other_conditions_order then
            for idx,cond in pairs(data.other_conditions_order) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.other_conditions_order, fix)
        end

        if data.disabled_conditions then
            for idx,cond in pairs(data.disabled_conditions) do
                if type(idx) ~= "number" or type(cond) ~= "string" then
                    mark_for_remove(toremove, idx)
                end
            end
            apply_remove(toremove, data.disabled_conditions, fix)
        end
    end
end
]=]},
}
local persistent={['Data/validation.lua']=true,['Data/diff.lua']=true,['Data/catalog.lua']=true,['Core/rotation_scope.lua']=true,['Core/rotation_library.lua']=true,['Core/rotation_workspace.lua']=true,['Core/rotation_editor.lua']=true,['Core/imports.lua']=true,['validate.lua']=true}
local dependency={['Core/rotation_references.lua']=true,['Core/conditions.lua']=true,['Core/functions.lua']=true,['Core/custom_authoring.lua']=true,['Core/function_data.lua']=true,['UI/condition_source_pane.lua']=true,['UI/settings_collections.lua']=true,['UI/settings_draft.lua']=true,['UI/settings_effects.lua']=true,['UI/settings_items.lua']=true,['Core/rotation_lifecycle.lua']=true,['UI/settings_profiles.lua']=true,['init.lua']=true,['validate.lua']=true,['tests/fixtures/addon.lua']=true}
local activePaths={['Core/rotation_scope.lua']=true,['Core/rotation_library.lua']=true,['Core/rotation_lifecycle.lua']=true,['Core/rotation_editor.lua']=true,['Core/imports.lua']=true,['tests/fixtures/addon.lua']=true}
return function(text,path,keep)
 text=outer(text,path,'six')
 if path=='init.lua' then text=dofile('tests/fixtures/restore_unit_states.lua')(text,path) end
 if path=='Core/rotation_scope.lua' or path=='Core/rotation_library.lua' then text=dofile('tests/fixtures/restore_runtime_context_projection.lua')(text,path) end
 if path=='Core/conditions.lua' then text=dofile('tests/fixtures/restore_condition_outcomes.lua')(text,path) end
 if activePaths[path] then text=dofile('tests/fixtures/restore_active_rotation_transition.lua')(text,path) end
 assert(keep==nil or keep=='persistent' or keep=='dependency','unknown revision integration stage')
 local row=overlaps[path]
 if row then
  assert(text==row.current,'unrelated combined revision source delta: '..path)
  return row[keep or 'baseline']
 end
 assert(persistent[path] or dependency[path],'unknown revision source path: '..tostring(path))
 if keep=='persistent' then assert(persistent[path]);return text end
 if keep=='dependency' then assert(dependency[path]);return text end
 if persistent[path] then return dofile('tests/fixtures/restore_rotation_content_revision.lua')(text,path) end
 return dofile('tests/fixtures/restore_dependency_revisions.lua')(text,path)
end
