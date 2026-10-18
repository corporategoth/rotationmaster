-- Run from repository root: lua5.1 tests/logging.lua
-- Use actual AceDB shutdown to reproduce defaults disappearing before late events.
local frames, messages = {}, {}
CreateFrame = function()
    local frame = {RegisterEvent = function() end}
    function frame:SetScript(name, handler) self[name] = handler end
    frames[#frames + 1] = frame
    return frame
end
UnitFactionGroup = function() return 'Horde' end
GetLocale = function() return 'enUS' end
UnitClass = function() return 'Mage', 'MAGE' end
UnitRace = function() return 'Undead', 'Scourge' end
UnitNameUnmodified = function() return 'Fixture' end
GetRealmName = function() return 'Fixture Realm' end
GetCurrentRegionName = function() return 'US' end
GetCurrentRegion = function() return 1 end
securecallfunction = function(fn, ...) return fn(...) end
NORMAL_FONT_COLOR_CODE = ''
dofile('globals.lua')
dofile('Libs/LibStub/LibStub.lua')
dofile('Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua')
dofile('Libs/AceDB-3.0/AceDB-3.0.lua')
local console = LibStub:NewLibrary('AceConsole-3.0', 1)
function console:Printf(format, ...) messages[#messages + 1] = string.format(format, ...) end
local locale = LibStub:NewLibrary('AceLocale-3.0', 1)
function locale:GetLocale() return setmetatable({}, {__index = function(_, key) return key end}) end
LibStub:NewLibrary('LibCompress', 1)
local addon = {pretty_name = 'Rotation Master'}
assert(loadfile('utils.lua'))('rotationmaster', addon)
local function logAll()
    addon:verbose('verbose %s', 'fixture')
    addon:debug('debug %s', 'fixture')
    addon:info('info %s', 'fixture')
    addon:warn('warn %s', 'fixture')
end
for level = 0, 4 do
    addon.db = {profile = {loglevel = level}}
    messages = {}; logAll()
    assert(#messages == level, 'configured logging threshold was ignored')
end
print('PASS configured logging levels 0 through 4')
addon.db = LibStub('AceDB-3.0'):New({}, {profile = {loglevel = 2}}, true)
assert(addon.db.profile.loglevel == 2)
LibStub('AceDB-3.0').frame:OnEvent('PLAYER_LOGOUT')
assert(addon.db.profile.loglevel == nil, 'fixture did not remove AceDB defaults')
messages = {}; logAll()
assert(#messages == 2, 'missing log level should use the normal info/warn threshold')
assert(addon.db.profile.loglevel == nil, 'logging must not repopulate saved defaults during shutdown')
print('PASS late-event logging after real AceDB shutdown')
