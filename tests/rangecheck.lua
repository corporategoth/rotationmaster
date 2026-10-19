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
local observedDistance=0
UnitExists=function() return true end
UnitCanAssist=function() return true end
UnitCanAttack=function() return false end
UnitIsDeadOrGhost=function() return false end
UnitIsUnit=function() return false end
UnitGUID=function() return 'RangeFixture' end
InCombatLockdown=function() return false end
GetTime=function() return 0 end
dofile(path)
local range = LibStub('LibRangeCheck-3.0')
assert(events.SPELLS_CHANGED, 'range checkers will not refresh when spells change')
assert(type(range.GetRange) == 'function')
print('PASS vendored RangeCheck loads on TBC without registering removed events')

-- Exercise the shipped public interval algorithm, not a copied approximation.
-- Successful checkers give inclusive upper bounds; positive lower bounds come
-- from failed checkers. Its synthetic zero floor is not a failed zero check.
range.friendRC={}
for _,limit in ipairs({20,10,5}) do
    local boundary=limit;range.friendRC[#range.friendRC+1]={range=boundary,checker=function() return observedDistance<=boundary end}
end
for _,case in ipairs({{0,0,5},{5,0,5},{5.1,5,10},{10,5,10},{10.1,10,20},{20.1,20}}) do
    observedDistance=case[1];local minimum,maximum=range:GetRange('party1',false,false,0)
    assert(minimum==case[2] and maximum==case[3],'shipped range interval boundary contract changed')
end
print('PASS shipped RangeCheck distinguishes inclusive upper failed positive lower and synthetic zero bounds')
