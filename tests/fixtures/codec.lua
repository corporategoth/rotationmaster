-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

return function()
    local env = setmetatable({ bit = require('bit'), sort = table.sort, UIParent = {} }, { __index = _G })
    env._G = env

    env.CreateFrame = function()
        return {
            SetScript = function() end,
            Hide = function() end,
            Show = function() end,
            IsShown = function() return false end,
        }
    end

    local addon = {}

    local function load(path)
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk('rotationmaster', addon)
    end

    for _, path in ipairs({
        'Libs/LibStub/LibStub.lua', 'Libs/LibCompress/LibCompress.lua', 'Libs/AceSerializer-3.0/AceSerializer-3.0.lua',
        'Data/plain.lua', 'Data/rotation_revision.lua', 'Data/tags.lua', 'Data/rotation_tree.lua',
        'Data/export_text.lua', 'Data/codec.lua', 'Data/validation.lua', 'Data/diff.lua', 'Data/import_session.lua'
    }) do
        load(path)
    end

    local compressor, serializer = env.LibStub('LibCompress'), env.LibStub('AceSerializer-3.0')
    local calls = { decompress = 0, deserialize = 0 }

    local dependencies = {
        serialize = function(value) return serializer:Serialize(value) end,
        deserialize = function(raw)
            calls.deserialize = calls.deserialize + 1
            return serializer:Deserialize(raw)
        end,
        compress = function(raw) return compressor:Compress(raw, 1) end,
        decompress = function(stream)
            calls.decompress = calls.decompress + 1
            return compressor:Decompress(stream)
        end,
    }

    return addon.RotationData, dependencies, calls, compressor, serializer, env
end
