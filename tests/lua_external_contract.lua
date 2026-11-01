-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local env = setmetatable({}, { __index = _G })
env._G = env

env.LibStub = function()
    return { GetLocale = function() return setmetatable({}, { __index = function(_, key) return key end }) end }
end

env.C_AddOns = { IsAddOnLoaded = function(name) return name == '!!!LuaWorkbench' end }
env.LuaWorkbench = { db = { options = {}, drafts = { existing = { source = 'preserve' } } } }
local addon = {}
local path = arg[1] or 'LibsAugment/LuaWorkbench.lua'
local chunk = assert(loadfile(path))
setfenv(chunk, env)
chunk('RotationMaster', addon)
assert(not addon:IsLuaWorkbenchIntegrationAvailable(), 'standalone without an editor API must fall back safely')
local ok, engine, why = pcall(addon.CreateLuaWorkbenchEngine, addon, {})
assert(ok and engine == nil and why, 'missing standalone editor API must not raise an error')
assert(env.LuaWorkbench.db.drafts.existing.source == 'preserve', 'standalone draft changed')
print('PASS missing standalone integration API leaves native editor usable')
