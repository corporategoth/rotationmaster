-- Exercise the vendored library's load-time event registration with TBC APIs.
-- Run from repository root: lua5.1 tests/rangecheck.lua [library-path]
local path = arg[1] or 'Libs/LibRangeCheck-3.0/LibRangeCheck-3.0.lua'
dofile('Libs/LibStub/LibStub.lua')
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC = 5, 1, 2
WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
WOW_PROJECT_WRATH_CLASSIC, WOW_PROJECT_CATACLYSM_CLASSIC, WOW_PROJECT_MISTS_CLASSIC = 11, 14, 19
BOOKTYPE_SPELL = 'spell'
tinsert, tremove, sort = table.insert, table.remove, table.sort
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
GetBuildInfo = function() return '2.5.6', 'fixture', 'fixture', 20506 end
GetInventorySlotInfo = function(slot) assert(slot:upper() == 'HANDSSLOT'); return 10 end
GetSpellBookItemName = function() end
GetNumSpellTabs = function() return 0 end
GetSpellTabInfo = function() return nil, nil, 0, 0 end
UnitClass = function() return 'Warrior', 'WARRIOR' end
local events = {}
C_EventUtils = {IsEventValid = function(event) return event ~= 'LEARNED_SPELL_IN_TAB' end}
C_Item = {}
C_Timer = {NewTicker = function() return {} end}
CreateFrame = function()
    return {
        RegisterEvent = function(_, event)
            assert(event ~= 'LEARNED_SPELL_IN_TAB', 'attempt to register unknown event ' .. event)
            events[event] = true
        end,
        SetScript = function() end,
        Show = function() end,
    }
end
dofile(path)
local range = LibStub('LibRangeCheck-3.0')
assert(events.SPELLS_CHANGED, 'range checkers will not refresh when spells change')
assert(type(range.GetRange) == 'function')
print('PASS vendored RangeCheck loads on TBC without registering removed events')
