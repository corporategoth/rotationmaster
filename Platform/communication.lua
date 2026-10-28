-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for announcements to chat: IsInRaid, IsInGroup, group leader flags, SendChatMessage
-- (C_ChatInfo.SendChatMessage) and DoEmote (C_ChatInfo.PerformEmote).
-- Owns the `value or nil, reason` readers for the player's announcement group and the emote catalog, and the two
-- writers that speak (chat line, emote); it must not choose what to say or retry through another backend. Each writer
-- takes a "current" callback and refuses once the announcement that asked for it has been retired. Channel
-- resolution lives in Platform/announcement_recipient.lua. Loaded from RotationMaster.toc after Platform/macros.lua.
local _, addon = ...
local platform = addon.Platform

-- Calls a native predicate under pcall and requires a boolean answer; returns it, or nil and a reason code.
local function boolean(fn, ...)
    if type(fn) ~= 'function' then
        return nil, 'missing-api'
    end

    local ok, value = pcall(fn, ...)

    if not ok then
        return nil, 'api-error'
    end
    if not platform:CanReadValue(value) then
        return nil, 'restricted-value'
    end
    if type(value) ~= 'boolean' then
        return nil, 'invalid-api-result'
    end

    return value
end

-- Permissions may be unavailable even when group membership is public. Keep
-- those observations separate; callers can still choose ordinary raid chat.
-- Returns { inRaid, inGroup } plus isLeader and isAssistant when in a raid (either may be nil when unreadable), or nil
-- and a reason code when group state itself cannot be read.
function platform:GetAnnouncementGroup()
    local raid, why = boolean(IsInRaid)

    if raid == nil then
        return nil, why
    end

    if raid then
        local isLeader

        if type(UnitIsGroupLeader) == 'function' then
            isLeader = boolean(UnitIsGroupLeader, 'player')
        else
            isLeader = boolean(IsRaidLeader)
        end

        local isAssistant = boolean(UnitIsGroupAssistant, 'player')
        return { inRaid = true, inGroup = true, isLeader = isLeader, isAssistant = isAssistant }
    end

    local grouped, reason = boolean(IsInGroup)

    if grouped == nil then
        return nil, reason
    end

    return { inRaid = false, inGroup = grouped }
end

-- The chat destinations an announcement may use.
local destinations = { PARTY = true, RAID = true, RAID_WARNING = true, SAY = true, YELL = true, EMOTE = true }

-- Sends one chat line to a destination from the list above. Returns true, or nil and a reason code. current, when
-- given, must still return true or nothing is sent ("announcement-retired").
function platform:SendAnnouncementChat(text, destination, current)
    if not self:CanReadValue(text) or not self:CanReadValue(destination) then
        return nil, 'restricted-value'
    end
    if type(text) ~= 'string' or type(destination) ~= 'string' or not destinations[destination] then
        return nil, 'invalid-message'
    end

    local fn = type(C_ChatInfo) == 'table' and C_ChatInfo.SendChatMessage

    if type(fn) ~= 'function' then
        fn = SendChatMessage
    end

    if type(fn) ~= 'function' then
        return nil, 'missing-api'
    end

    -- A selected sender may have side effects before raising. Never retry
    -- through another backend, or attempt to work around client restrictions.
    if current then
        local owned, valid = pcall(current)

        if not owned or valid ~= true then
            return nil, 'announcement-retired'
        end
    end

    local ok = pcall(fn, text, destination)

    if not ok then
        return nil, 'api-error'
    end

    return true
end

-- Resolve the current client's own slash-command catalog only on editor/output
-- requests. No retained global catalog, native target lookup or polling work.
-- Returns the client's emotes as { value = token, text = slash command } rows sorted by command; an empty list when
-- the catalog cannot be read.
function platform:GetAnnouncementEmotes()
    local limit = MAXEMOTEINDEX

    if not self:CanReadValue(limit) or type(limit) ~= 'number' or limit < 1 or limit > 1024 or limit % 1 ~= 0 then
        return {}
    end

    local rows, seen = {}, {}

    for i = 1, limit do
        local token, command = _G['EMOTE' .. i .. '_TOKEN'], _G['EMOTE' .. i .. '_CMD1']

        if
            self:CanReadValue(token)
            and type(token) == 'string'
            and #token <= 64
            and token:match('^[A-Z][A-Z0-9_]*$')
            and not seen[token]
            and self:CanReadValue(command)
            and type(command) == 'string'
            and #command > 0
            and #command <= 128
        then
            seen[token] = true
            rows[#rows + 1] = { value = token, text = command }
        end
    end

    table.sort(rows, function(a, b) return a.text < b.text end)
    return rows
end

-- Performs one emote from the catalog, aimed at target ("" for none). Returns true (or nil and a reason code) and a
-- bounded observation of the native call (backend, completed or threw, return count and type) for diagnostics.
-- current, when given, must still return true or nothing is performed.
function platform:PerformAnnouncementEmote(token, target, current)
    if not self:CanReadValue(token) or not self:CanReadValue(target) then
        return nil, 'restricted-value'
    end
    if type(token) ~= 'string' or type(target) ~= 'string' or #target > 512 or target:find('[%z\1-\31\127]') then
        return nil, 'invalid-emote'
    end

    local found = false

    for _, row in ipairs(self:GetAnnouncementEmotes()) do
        if row.value == token then
            found = true
            break
        end
    end

    if not found then
        return nil, 'emote-unavailable'
    end

    local fn = DoEmote
    local backend = 'DoEmote'
    local nativeToken, nativeTarget = token:lower(), target == '' and 'none' or target

    if type(fn) ~= 'function' then
        fn = type(C_ChatInfo) == 'table' and C_ChatInfo.PerformEmote
        backend = 'C_ChatInfo.PerformEmote'
        nativeToken = token
    end

    if type(fn) ~= 'function' then
        return nil, 'missing-api'
    end

    -- Explicit 'none' matches the user's working targetless native test. A
    -- missing cast recipient never substitutes the selected unit/prior cast.
    -- Keep only bounded shape observations, never native values, error strings
    -- or recipients. A native boolean has no inferred acceptance semantics.
    local observation = { backend = backend }

    -- Records the shape of a pcall result into observation and returns its success flag.
    local function observed(ok, ...)
        observation.call = ok and 'completed' or 'threw'

        if ok then
            observation.returns = select('#', ...)
            local first = (...)
            observation.firstType = 'unavailable'

            if self:CanReadValue(first) then
                observation.firstType = type(first)

                if observation.firstType == 'boolean' then
                    observation.firstBoolean = first
                end
            end
        end

        return ok
    end

    if current then
        local owned, valid = pcall(current)

        if not owned or valid ~= true then
            return nil, 'announcement-retired'
        end
    end

    local ok = observed(pcall(fn, nativeToken, nativeTarget))

    if not ok then
        return nil, 'api-error', observation
    end

    return true, nil, observation
end
