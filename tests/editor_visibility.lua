-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local env = setmetatable({}, { __index = _G })
env._G = env
local locale = setmetatable({}, { __index = function(_, key) return key end })
env.LibStub = function() return { GetLocale = function() return locale end } end
local methods = {}

function methods:SetText(value)
    self.text = value
end

function methods:GetStringWidth()
    return #(self.text or '') * 6
end

function methods:GetStringHeight()
    return 18
end

function methods:GetWidth()
    return 800
end

function methods:GetHeight()
    return 20
end

function methods:CreateFontString()
    return setmetatable({}, { __index = methods })
end

function methods:GetFontString()
    return self.font
end

setmetatable(methods, { __index = function() return function() end end })

local function widget()
    local w = setmetatable({}, { __index = methods })
    w.font = setmetatable({}, { __index = methods })
    w.art = setmetatable({}, { __index = methods })
    w.icon = setmetatable({}, { __index = methods })
    return w
end

env.CreateFrame = function() return widget() end
local addon = { Platform = { GetClientInfo = function() return { family = 'progression', interface = 50504 } end } }

function addon:ListLuaEditorProviders()
    return { { value = 'native' }, { value = 'plain' }, { value = 'auto' } }
end

function addon:GetIntegrationClientSupport(id)
    if id == '!!!LuaWorkbench' then
        return 'unsupported'
    end

    return 'supported'
end

function addon:ListIntegrationStatus()
    return {
        { id = '!!!LuaWorkbench', name = 'LuaWorkbench', state = 'missing', projectURL = 'https://example.test/lwb' },
        { id = 'WowLua', name = 'WowLua', state = 'missing', projectURL = 'https://example.test/wowlua' },
    }
end

function addon:CreateRoundedCardDecoration()
    return widget()
end

function addon:CreateWorkbenchButton()
    return widget()
end

function addon:CreateWorkbenchPill()
    return widget()
end

function addon:CreateWorkbenchHelpButton()
    return widget()
end

function addon:SetUIScript() end
local p = { fields = {}, frame = widget(), child = widget(), generation = 1, y = 0 }

function p:SettingsData()
    return { profile = {} }
end

function p:Valid()
    return true
end

function p:Acquire(_, factory)
    return factory()
end

function p:Guard(fn)
    return fn
end

function p:Section(_, _, fn)
    fn()
end

function p:Check()
    return widget()
end

local chunk = assert(loadfile('UI/settings_integrations.lua'))
setfenv(chunk, env)
chunk('RotationMaster', addon)
addon:BuildIntegrationSettings(p)

for _, id in ipairs({ 'LuaWorkbench', 'WowLua' }) do
    assert(p.fields['integration_card_editor_' .. id], id .. ' row missing')
    assert(p.fields['integration_status_editor_' .. id].text == 'Not loaded', id .. ' should say Not loaded')
    assert(p.fields['integration_name_editor_' .. id], id .. ' project link missing')
end

function addon:ListLuaEditorProviders()
    return {
        { value = 'native' },
        { value = 'auto' },
        { value = 'WowLua', text = 'WowLua' },
        { value = 'LuaWorkbench', text = 'LuaWorkbench' },
    }
end

function addon:IsWowLuaIntegrationAvailable()
    return true
end

function addon:IsLuaWorkbenchIntegrationAvailable()
    return true
end

p.fields = {}
p.y = 0
addon:BuildIntegrationSettings(p)
assert(p.fields.integration_status_editor_LuaWorkbench.text == 'Not loaded', 'unsupported provider was made selectable')
assert(p.fields.integration_status_editor_WowLua.text == 'Selected', 'loaded WowLua was not selected')
print('PASS missing rows and supported/unsupported loaded editor states on MoP')
