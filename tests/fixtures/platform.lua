-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local function fixture(values, modules)
    local addon = {}
    local env = setmetatable(values or {}, { __index = _G })
    env._G = env

    for _, path in ipairs(modules or { 'Platform/client.lua', 'Platform/spells.lua' }) do
        local load = assert(loadfile(path))
        setfenv(load, env)
        load('rotationmaster', addon)
    end

    return addon.Platform, env, addon
end

return fixture
