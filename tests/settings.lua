-- Run from repository root: lua5.1 tests/settings.lua
local addon = {}
local env = setmetatable({}, { __index = _G })

local function loadCompat()
    local chunk = assert(loadfile('compat.lua'))
    setfenv(chunk, env)
    chunk('rotationmaster', addon)
end

local root = { name = 'Rotation Master' }
local child = { name = 'Rotations' }
local categories, registered, opened = {}, {}, {}

env.Settings = {
    RegisterCanvasLayoutCategory = function(frame, name)
        assert(frame == root and name == 'Rotation Master')
        categories[123] = { ID = 123 }
        return categories[123]
    end,
    RegisterCanvasLayoutSubcategory = function(parent, frame, name)
        assert(parent == categories[123] and frame == child and name == 'Rotations')
        categories[124] = { ID = 124 }
        return categories[124]
    end,
    RegisterAddOnCategory = function(category)
        registered[#registered + 1] = category
    end,
    GetCategory = function(id) return categories[id] end,
    OpenToCategory = function(id)
        opened[#opened + 1] = id
    end,
}

loadCompat()
addon:RegisterOptionsCategory(root)
child.parent = root.name
addon:RegisterOptionsCategory(child)
addon:OpenOptions(child)
assert(root.name == 123 and child.name == 124)
assert(#registered == 1 and registered[1] == categories[123])
assert(#opened == 1 and opened[1] == 124)
print('PASS modern Settings root, subcategory and open use registered category IDs')

env.Settings = nil
local legacyOpened, legacyRegistered = {}, nil

env.InterfaceOptions_AddCategory = function(frame)
    legacyRegistered = frame
end

env.InterfaceOptionsFrame_OpenToCategory = function(frame)
    legacyOpened[#legacyOpened + 1] = frame
end

loadCompat()
local legacy = { name = 'Rotation Master' }
addon:RegisterOptionsCategory(legacy)
addon:OpenOptions(legacy)
assert(legacyRegistered == legacy)
assert(#legacyOpened == 2 and legacyOpened[1] == legacy and legacyOpened[2] == legacy)
print('PASS legacy Interface Options fallback')
