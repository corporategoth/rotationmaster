-- Explicit external boundaries; production constants/utilities/help stay real.
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
    load('globals.lua');load('Core/dependency_revisions.lua');load('Core/rotation_active.lua');load('Platform/client.lua');load('Platform/rotation_owner.lua');load('Platform/groups.lua');load('Platform/roster_class.lua');load('Platform/role.lua');load('Platform/mobinfo2.lua');load('Platform/casting.lua');load('Platform/unit_health.lua');load('Platform/unit_stat.lua');load('Platform/health_forecast.lua');load('Platform/unit_level.lua');load('Platform/unit_power.lua');load('Platform/player_movement.lua');load('Platform/unit_attackability.lua');load('Platform/unit_flags.lua');load('Platform/player_flags.lua');load('Platform/form.lua');load('Platform/points.lua');load('Platform/runes.lua');load('Platform/unit_identity.lua');load('Platform/unit_metadata.lua');load('Platform/creature_type.lua');load('Platform/unit_presence.lua');load('Platform/pet.lua');load('Platform/threat.lua');load('Platform/instance.lua');load('Platform/zone_pvp.lua');load('Platform/loss_of_control.lua');load('Platform/items.lua');load('Platform/glyphs.lua');load('Platform/specializations.lua')
    load('Locales/enUS.lua'); load('constants.lua');load('Data/artwork.lua');load('Functions/values.lua');load('Functions/presentation.lua');load('Functions/text.lua');load('Functions/collections.lua');load('Functions/cache.lua');load('Functions/trends.lua');load('Functions/forecast.lua'); load('utils.lua');load('Core/level_conditions.lua');load('Core/point_conditions.lua');load('Core/class_group_conditions.lua');load('Core/creature_conditions.lua');load('Core/health_forecast_conditions.lua');load('Core/threat_count_conditions.lua')
    load('UI/controls.lua');load('UI/condition_widgets.lua');load('UI/condition_observation.lua');load('UI/condition_icon.lua');load('UI/condition_position.lua');load('UI/condition_display.lua');load('UI/drag_presentation.lua');load('Core/unsaved_changes.lua');load('UI/unsaved.lua');load('UI/settings_draft.lua');load('UI/collection_compare.lua');load('UI/draft_changes.lua');load('UI/draft_change_controls.lua');load('UI/window.lua');load('UI/selector.lua');load('UI/tag_picker.lua');load('UI/checkbox.lua');load('UI/condition_inputs.lua');load('UI/condition_layout.lua');load('UI/condition_table.lua');load('UI/condition_unit.lua');load('Core/item_conditions.lua');load('Core/rotation_references.lua');load('Help/common.lua'); load('Help/conditional.lua'); load('Core/presentation.lua');load('Core/condition_description.lua'); load('Core/spell_catalog.lua');load('Core/spell_search.lua');load('Core/reference_catalog.lua');load('Core/category_data.lua');load('Core/announcement_data.lua');load('Core/profile_data.lua');load('Core/collection_data.lua');load('Core/custom_condition_data.lua');load('Core/functions.lua');load('UI/spell_search.lua');load('UI/spell_icon.lua')
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
