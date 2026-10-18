-- Exercise the actual vendored About panel with Rotation Master's TOC metadata.
-- Run from repository root: lua5.1 tests/aboutpanel.lua
local metadata = {}
for line in io.lines('RotationMaster.toc') do
    local key, value = line:match('^## ([^:]+):%s*(.*)')
    if key then metadata[key] = value end
end
local failures = 0
for _, locale in ipairs({'enUS', 'enGB', 'deDE', 'frFR', 'itIT', 'esES', 'esMX', 'ptBR', 'ruRU', 'koKR', 'zhCN', 'zhTW'}) do
    local ok, err = pcall(function()
        local env = setmetatable({}, {__index = _G})
        env._G = env
        env.strmatch = string.match
        env.GetLocale = function() return locale end
        env.CreateFrame = function()
            return {Hide = function() end, SetScript = function() end,
                SetFontObject = function() end, HighlightText = function() end}
        end
        env.GAME_VERSION_LABEL, env.CATEGORY = 'Version', 'Category'
        env.FACTION_ALLIANCE, env.FACTION_HORDE = 'Alliance', 'Horde'
        env.C_AddOns = {GetAddOnMetadata = function(name, field)
            assert(name == 'rotationmaster'); return metadata[field]
        end}
        local function load(path)
            local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk()
        end
        load('Libs/LibStub/LibStub.lua')
        load('Libs/LibAboutPanel-2.0/LibAboutPanel-2.0.lua')
        local panel = env.LibStub('LibAboutPanel-2.0'):AboutOptionsTable('rotationmaster')
        assert(type(panel.name) == 'string' and panel.type == 'group')
        assert(type(panel.args.Date.name) == 'string')
        assert(type(panel.args.License.name) == 'string')
        assert(type(panel.args.Credits.name) == 'string')
    end)
    if ok then print('PASS About panel ' .. locale)
    else failures = failures + 1; print('FAIL About panel ' .. locale .. ': ' .. tostring(err)) end
end
os.exit(failures == 0 and 0 or 1)
