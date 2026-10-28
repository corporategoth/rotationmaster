-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.
-- A model of the parts of a client that raid marks touch, for the raid mark suites: unit tokens that point at units
-- (a unit has a GUID, a mark and a hostility), the group, the event frames Platform/raid_marks.lua creates, the timer,
-- the clock and the macro calls the Bind button makes. Every capability can be switched off, so a suite can model a
-- client that has no UnitTokenFromGUID, no nameplates, no event catalog or no mark API at all. Nothing here says which
-- real client has what: the suites model shapes, and /rm debug marks reports the truth in game.
local C = dofile('tests/fixtures/condition_client.lua')
local W = {}

W.SECRET = C.SECRET

W.platformFiles = {
    'Platform/focus_unit.lua',
    'Platform/group_units.lua',
    'Platform/raid_marks.lua',
    'Platform/raid_mark_actions.lua',
    'Core/group_unit_resolution.lua',
}

-- The events a client with every capability knows.
W.allEvents = {
    'RAID_TARGET_UPDATE', 'PLAYER_TARGET_CHANGED', 'PLAYER_FOCUS_CHANGED', 'UPDATE_MOUSEOVER_UNIT',
    'NAME_PLATE_UNIT_ADDED', 'NAME_PLATE_UNIT_REMOVED', 'GROUP_ROSTER_UPDATE', 'UNIT_TARGET',
    'INSTANCE_ENCOUNTER_ENGAGE_UNIT', 'ARENA_OPPONENT_UPDATE', 'PLAYER_SOFT_ENEMY_CHANGED',
    'PLAYER_SOFT_FRIEND_CHANGED', 'PLAYER_ENTERING_WORLD'
}

-- Builds an addon on one client family, loaded with the real files, and its world.
-- Arguments:
--   name (string): a family of tests/fixtures/condition_client.lua (retail, forever, mists, tbc, era).
--   options (table|nil): read = false (no GetRaidTargetIndex), set = false (no SetRaidTarget and no command),
--     tokenFromGUID = false, catalog = false (no C_EventUtils), events = a list of the events the client knows
--     (default all), lenient = true (RegisterEvent accepts an event the client does not know, as some clients do),
--     timer = false, group = { raid, size }, units = false to leave Core/raid_mark_units.lua unloaded.
-- Returns:
--   f, a, e (table): the fixture, the addon and its environment.
--   w (table): the world: tokens, frames, timers, calls, and the helpers set, remove, fire, advance, runTimers.
function W.client(name, options)
    options = options or {}
    local f, a, e = C.load(name, 'WARRIOR', W.platformFiles)

    local w = {
        now = 1000,
        tokens = {},
        order = {},
        frames = {},
        timers = {},
        calls = {},
        group = options.group or { raid = false, size = 0 },
        known = {},
        macros = {},
        nextMacro = 1,
        secretMarks = {},
        secretGuids = {},
        attributeWrites = {},
        combat = false,
        fetches = 0,
        registerAttempts = 0,
    }

    for _, event in ipairs(options.events or W.allEvents) do
        w.known[event] = true
    end

    -- Counts one call of a game function by name.
    local function hit(label)
        w.calls[label] = (w.calls[label] or 0) + 1
    end

    e.GetTime = function() return w.now end

    if options.read ~= false then
        e.GetRaidTargetIndex = function(token)
            hit('GetRaidTargetIndex')

            if w.secretMarks[token] then
                return C.SECRET
            end

            local unit = w.tokens[token]
            return unit and unit.mark or nil
        end
    else
        e.GetRaidTargetIndex = nil
    end

    if options.set ~= false then
        e.SetRaidTarget = function() end
        e.SecureCmdList = { TARGET_MARKER = function() end }
    else
        e.SetRaidTarget = nil
        e.SecureCmdList = nil
        e.SlashCmdList = nil
    end

    e.UnitGUID = function(token)
        hit('UnitGUID')

        if w.secretGuids[token] then
            return C.SECRET
        end

        local unit = w.tokens[token]
        return unit and unit.guid or nil
    end

    e.UnitExists = function(token)
        local unit = w.tokens[token]
        return unit ~= nil
    end

    e.UnitCanAttack = function(_, token)
        local unit = w.tokens[token]
        return unit and unit.enemy == true or false
    end

    e.UnitIsFriend = function(_, token)
        local unit = w.tokens[token]
        return unit and unit.friend == true or false
    end

    if options.tokenFromGUID ~= false then
        e.UnitTokenFromGUID = function(guid)
            hit('UnitTokenFromGUID')

            for _, token in ipairs(w.order) do
                local unit = w.tokens[token]

                if unit and unit.guid == guid then
                    return token
                end
            end

            return nil
        end
    else
        e.UnitTokenFromGUID = nil
    end

    e.UnitAffectingCombat = function() return false end
    e.UnitIsUnit = function() return false end
    e.GetNumGroupMembers = function() return w.group.size end
    e.IsInRaid = function() return w.group.raid end
    e.UnitIsGroupLeader = function() return w.group.leader == true end
    e.UnitIsGroupAssistant = function() return w.group.assistant == true end

    if options.catalog ~= false then
        e.C_EventUtils = {
            IsEventValid = function(event)
                return w.known[event] == true
            end,
        }
    else
        e.C_EventUtils = nil
    end

    if options.timer ~= false then
        e.C_Timer = {
            After = function(delay, callback)
                w.timers[#w.timers + 1] = { at = w.now + delay, callback = callback }
            end,
        }
    else
        e.C_Timer = nil
    end

    -- Frames are the native model's, with the event registration the watch needs added; w.baseline counts the frames
    -- that existed once the addon was loaded, so a suite can tell whether the watch made one.
    local native = e.CreateFrame

    e.CreateFrame = function(kind, frameName, ...)
        local frame = native(kind, frameName, ...)
        frame.events = {}
        frame.unregisterAll = 0
        frame.attributes = {}

        function frame:SetAttribute(key, value)
            self.attributes[key] = value
            w.attributeWrites[#w.attributeWrites + 1] = { frame = self, name = self.name, key = key, value = value }
        end

        function frame:GetAttribute(key)
            return self.attributes[key]
        end

        -- A named frame is a global, as in the client.
        if frameName then
            e[frameName] = frame
        end

        function frame:RegisterEvent(event)
            w.registerAttempts = w.registerAttempts + 1

            if not w.known[event] and not options.lenient then
                error('Attempt to register unknown event: ' .. tostring(event))
            end

            self.events[event] = true
        end

        function frame:UnregisterAllEvents()
            self.unregisterAll = self.unregisterAll + 1
            self.events = {}
        end

        w.frames[#w.frames + 1] = frame
        return frame
    end

    -- Puts a unit behind a token. The same table behind two tokens is the same unit.
    -- Arguments: token (string), unit (table: guid, mark, enemy, friend).
    function w:set(token, unit)
        if self.tokens[token] == nil then
            self.order[#self.order + 1] = token
        end

        self.tokens[token] = unit
    end

    -- Takes the unit away from a token.
    function w:remove(token)
        self.tokens[token] = nil
    end

    -- The events registered on the watch frame now, as a sorted list.
    function w:registered()
        local list = {}

        for _, frame in ipairs(self.frames) do
            for event in pairs(frame.events) do
                list[#list + 1] = event
            end
        end

        table.sort(list)
        return list
    end

    -- How many events are registered across every frame.
    function w:registeredCount()
        return #self:registered()
    end

    -- Delivers an event to every frame that registered it, as the client would.
    function w:fire(event, ...)
        for _, frame in ipairs(self.frames) do
            if frame.events[event] and frame.scripts and frame.scripts.OnEvent then
                frame.scripts.OnEvent(frame, event, ...)
            end
        end
    end

    -- Moves the clock.
    function w:advance(seconds)
        self.now = self.now + seconds
    end

    -- Runs every timer that is due.
    function w:runTimers()
        local due = {}
        local waiting = {}

        for _, timer in ipairs(self.timers) do
            if timer.at <= self.now then
                due[#due + 1] = timer
            else
                waiting[#waiting + 1] = timer
            end
        end

        self.timers = waiting

        for _, timer in ipairs(due) do
            timer.callback()
        end
    end

    e.InCombatLockdown = function() return w.combat end
    e.GetCursorInfo = function() return w.cursor end

    a.ButtonFetch = function()
        w.fetches = w.fetches + 1
    end

    -- Macro calls the Bind button makes.
    e.GetMacroIndexByName = function(macroName)
        for index, macro in ipairs(w.macros) do
            if macro.name == macroName then
                return index
            end
        end

        return 0
    end

    e.CreateMacro = function(macroName, icon, body, perCharacter)
        w.macros[#w.macros + 1] = { name = macroName, icon = icon, body = body, perCharacter = perCharacter }
        return #w.macros
    end

    e.PickupMacro = function(index)
        w.picked = index
    end

    e.GetMacroBody = function(index)
        local macro = w.macros[index]
        return macro and macro.body or nil
    end

    -- The mark files are loaded again now that the client model is complete, so what they do at load time is seen.
    f.load('Platform/raid_marks.lua')
    f.load('Platform/raid_mark_actions.lua')
    f.load('constants.lua')

    if options.buttons ~= false then
        f.load('Core/raid_mark_buttons.lua')
    end

    w.baseline = #w.frames

    if options.units ~= false then
        f.load('Core/raid_mark_units.lua')
    end

    a.conditionRegistryVersion = (a.conditionRegistryVersion or 0) + 1
    return f, a, e, w
end

return W
