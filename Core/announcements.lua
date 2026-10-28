-- Announcement delivery: copies an announcement for one cast (a lease), walks a series' output cards, checks each
-- card's conditions against the cast recipient, and sends the text to chat, an emote or a sound. Owns the delivery and
-- emote request serials and the two retained emote diagnostics; it never builds the message text (the caller passes a
-- `format` callback), never matches events and never retries. Everything it does is best-effort and runs under pcall,
-- so a failing chat or sound API cannot interrupt cast bookkeeping or recommendations. Chat and emotes go through
-- Platform adapters and game values pass platform:CanReadValue. A lease's `current()` turns false as soon as the
-- announcement, its owner or a newer delivery changes, and every step re-checks it. Validation lives in
-- Core/announcement_data.lua, which loads first; the callers are main.lua and Core/macro_announcements.lua.
local _, addon = ...
local platform = addon.Platform
local direct = { ['local'] = 'LOCAL', emote = 'EMOTE', gesture = 'GESTURE' }
local conditionRequest = 0
local deliveryRequest = 0

-- ============================================================================
-- Delivery lease
-- ============================================================================

-- Structural equality for plain data: same types, same keys, same leaves, and false for any table that has a
-- metatable. Used to prove a configuration has not been edited since it was copied.
local function same(left, right)
    if type(left) ~= type(right) then
        return false
    end
    if type(left) ~= 'table' then
        return left == right
    end
    if getmetatable(left) ~= nil or getmetatable(right) ~= nil then
        return false
    end

    for key, value in pairs(left) do
        if not same(value, rawget(right, key)) then
            return false
        end
    end

    for key in pairs(right) do
        if rawget(left, key) == nil then
            return false
        end
    end

    return true
end

-- A cold event owns a detached, immutable witness of its complete entry.
-- Retain this lease across action resolution, conditions and text formatting.
-- Returns a private copy of `config` with `action` set from its spell or item, and a `current()` function that is true
-- only while this is still the newest prepared delivery, `owner()` still returns true and `config` is unchanged.
-- Returns nil when `config` is not portable data or `owner` is not a function.
function addon:PrepareAnnouncementDelivery(config, owner)
    deliveryRequest = deliveryRequest + 1
    local request = deliveryRequest
    local data = self.RotationData

    if type(config) ~= 'table' or type(owner) ~= 'function' or not data then
        return nil
    end

    local portable, copy = data.CheckPortable, data.CopyData

    if not portable(config) then
        return nil
    end

    local witness = copy(config)
    local entry = copy(witness)

    if entry.type == 'spell' or entry.type == 'pet' then
        entry.action = entry.spell
    elseif entry.type == 'item' then
        entry.action = entry.item
    end

    local expected = copy(entry)

    local function current()
        if request ~= deliveryRequest then
            return false
        end

        local ok, valid = pcall(owner)
        return ok and valid == true and request == deliveryRequest and same(witness, config) and same(expected, entry)
    end

    return entry, current
end

-- ============================================================================
-- Series dispatch
-- ============================================================================

-- One prepared parent lease owns all reached cards. Never prepare a card: that
-- would replace the parent delivery serial. Public callbacks see a detached view.
-- Delivers each enabled card of `parent.outputs` whose conditions match: `format(view, live)` builds the text and
-- `deliver` (default DispatchAnnouncement) sends it. Returns { chat, sound, outputs, retired }, where chat and sound
-- say whether anything was sent or played and `retired` is set when the lease lapsed part way. All cards are validated
-- before the first one is sent, and an invalid series sends nothing.
function addon:DispatchAnnouncementSeries(parent, recipient, current, targetUnit, format, deliver)
    local result = { chat = false, sound = false, outputs = {} }
    local cards = parent.outputs

    if type(cards) ~= 'table' or getmetatable(cards) ~= nil or #cards > 64 or not current() then
        return result
    end

    local count, seen = 0, {}

    for key, card in pairs(cards) do
        if not current() then
            return result
        end
        if
            type(key) ~= 'number'
            or key % 1 ~= 0
            or key < 1
            or key > #cards
            or not self:IsValidAnnouncementOutput(card, parent.type == 'macro')
            or seen[card.id]
        then
            return result
        end
        if not current() then
            return result
        end

        count = count + 1
        seen[card.id] = true
    end

    if count ~= #cards or not current() then
        return result
    end

    for _, card in ipairs(cards) do
        if not current() then
            result.retired = true
            break
        end

        if not card.disabled then
            local view = self.RotationData.CopyData(card)
            view.type = parent.type
            local expected = self.RotationData.CopyData(view)

            local function live()
                return current() and same(view, expected)
            end

            local matches = self.AnnouncementConditionMatches

            if not live() then
                result.retired = true
                break
            end

            local ok, matched = pcall(matches, self, view, recipient, live, targetUnit)

            if not live() then
                result.retired = true
                break
            end

            if ok and matched and not (view.announce == 'gesture' and view.emote_target and not recipient) then
                local formatted, value = pcall(format, view, live)

                if not live() then
                    result.retired = true
                    break
                end

                if formatted and value ~= nil then
                    local sent, output

                    if deliver then
                        sent, output = pcall(deliver, view, value, live)
                    else
                        local dispatch = self.DispatchAnnouncement

                        if not live() then
                            result.retired = true
                            break
                        end

                        sent, output = pcall(dispatch, self, view, value, recipient, live)
                    end

                    if sent and type(output) == 'table' then
                        result.outputs[#result.outputs + 1] = output
                        result.chat = result.chat or output.chat == true
                        result.sound = result.sound or output.sound == true
                    end

                    if not live() then
                        result.retired = true
                        break
                    end
                end
            end
        end
    end

    return result
end

-- ============================================================================
-- Condition matching
-- ============================================================================

-- Native unit APIs may accept a resolvable name as well as a unit token.
-- Keep the cast's recorded recipient exact; never infer the selected target.
-- Resolves the cast recipient to a unit usable by conditions after proving it exists and has a readable GUID. Returns
-- the recipient and a function that is true while the same unit is still there, or nothing when the recipient cannot
-- be read or does not exist. `owned` is the caller's lease check.
local function automaticTarget(recipient, owned)
    -- Restricted clients hide values with canaccessvalue as well as CanReadValue; require both before comparing.
    local function readable(value)
        return platform:CanReadValue(value) and (not canaccessvalue or canaccessvalue(value))
    end

    if not readable(recipient) or type(recipient) ~= 'string' or recipient == '' or #recipient > 512 or recipient:find(
        '[%z\1-\31\127]'
    ) then
        return
    end

    local exists, guid = UnitExists, UnitGUID

    if type(exists) ~= 'function' or type(guid) ~= 'function' then
        return
    end

    -- The unit APIs are captured above; a replaced global ends the lease so the proof cannot be redirected.
    local function live()
        if not owned() then
            return false
        end

        return exists == UnitExists and guid == UnitGUID
    end

    local function observe()
        if not live() then
            return
        end

        local ok, present = pcall(exists, recipient)

        if not ok or not readable(present) or present ~= true or not live() then
            return
        end

        local identified, id = pcall(guid, recipient)

        if not identified or not readable(id) then
            return
        end
        if canaccessvalue and not canaccessvalue(id) then
            return
        end
        if type(id) ~= 'string' or id == '' or #id > 256 or not live() then
            return
        end

        return id
    end

    local identity = observe()

    if not identity then
        return
    end

    return recipient, function()
        local now = observe()

        if canaccessvalue and not canaccessvalue(now) then
            return false
        end
        if canaccessvalue and not canaccessvalue(identity) then
            return false
        end

        return live() and now == identity
    end
end

-- Called only after a cast matches an announcement, never by cooldown output.
-- True when `config` has no conditions or they evaluate to a match for `recipient`. A spell, pet or item announcement
-- with no explicit `targetUnit` resolves the recipient through automaticTarget; a macro announcement does not.
-- `current` is the lease check; any lapse makes the answer false.
function addon:AnnouncementConditionMatches(config, recipient, current, targetUnit)
    conditionRequest = conditionRequest + 1
    local request = conditionRequest

    local function owned()
        if request ~= conditionRequest then
            return false
        end

        if current then
            local ok, valid = pcall(current)
            return ok and valid == true and request == conditionRequest
        end

        return true
    end

    if not owned() then
        return false
    end
    if config.conditions == nil then
        return true
    end

    local resolve

    if config.type ~= 'macro' and targetUnit == nil then
        resolve = function(tag)
            local unit, current = automaticTarget(recipient, owned)

            if unit then
                return tag == 'GROUP' and 'spellrecipient' or unit, current
            end
        end
    end

    local result

    if resolve then
        result = self:evaluateAnnouncementConditionResult(config.conditions, recipient, targetUnit, resolve)
    else
        result = self:evaluateAnnouncementConditionResult(config.conditions, recipient, targetUnit)
    end

    return owned() and type(result) == 'table' and result.status == 'match'
end

-- ============================================================================
-- Emote diagnostics
-- ============================================================================

-- Two bounded cold-output observations, never a history or polling cache.
local emoteSerial = { automatic = 0, test = 0 }
local emoteObservation = {}

local emoteReasons = {
    ['restricted-value'] = true,
    ['invalid-emote'] = true,
    ['emote-unavailable'] = true,
    ['missing-api'] = true,
    ['api-error'] = true,
    ['cast-recipient-unavailable'] = true,
}

-- Starts an emote attempt of `kind` ('automatic' or 'test') and returns its serial; a newer attempt of the same kind
-- makes older ones drop their observation.
local function beginEmote(kind)
    emoteSerial[kind] = emoteSerial[kind] + 1
    return emoteSerial[kind]
end

-- Copies the adapter's emote detail through a whitelist of keys and values, so the report can never hold game data
-- or free text. Returns the safe copy, or nil when the detail is hidden or not a table.
local function emoteDetailCopy(detail)
    if not platform:CanReadValue(detail) or type(detail) ~= 'table' then
        return nil
    end

    local copy = {}

    for _, key in ipairs({ 'backend', 'call', 'returns', 'firstType', 'firstBoolean' }) do
        local value = rawget(detail, key)

        if platform:CanReadValue(value) then
            if key == 'backend' and (value == 'C_ChatInfo.PerformEmote' or value == 'DoEmote') then
                copy[key] = value
            elseif key == 'call' and (value == 'completed' or value == 'threw') then
                copy[key] = value
            elseif key == 'returns' and type(value) == 'number' and value >= 0 and value <= 16 and value % 1 == 0 then
                copy[key] = value
            elseif
                key == 'firstType'
                and (value == 'nil'
                    or value == 'boolean'
                    or value == 'number'
                    or value == 'string'
                    or value == 'table'
                    or value == 'function'
                    or value == 'thread'
                    or value == 'userdata'
                    or value == 'unavailable')
            then
                copy[key] = value
            elseif key == 'firstBoolean' and type(value) == 'boolean' then
                copy[key] = value
            end
        end
    end

    return copy
end

-- Records the outcome of an emote attempt as the retained observation for `kind`, unless a newer attempt superseded
-- it. The reason is reduced to a known code and the detail to the whitelisted copy; a hidden or unknown value is stored
-- as 'unavailable'.
local function finishEmote(kind, serial, target, reason, detail)
    local copied, closed = pcall(emoteDetailCopy, detail)

    local checked, safeReason = pcall(function()
        if reason == nil then
            return 'native-call-completed'
        end
        if platform:CanReadValue(reason) and type(reason) == 'string' and emoteReasons[reason] then
            return reason
        end

        return 'unavailable'
    end)

    if serial ~= emoteSerial[kind] then
        return
    end

    emoteObservation[kind] = {
        target = target,
        reason = checked and safeReason or 'unavailable',
        detail = copied and closed or nil,
    }
end

-- ============================================================================
-- Chat and sound output
-- ============================================================================

-- Maps an announce mode to a chat channel name, 'LOCAL' or 'GESTURE'. Returns nil and a reason when nothing should be
-- sent: say and yell need a hardware event and are never sent from here; 'none' and 'audible' send no text. Group modes
-- read the group from the platform and fall back to PARTY or LOCAL when the player is not in a raid.
local function destination(mode)
    if not platform:CanReadValue(mode) or type(mode) ~= 'string' then
        return nil, 'invalid-destination'
    end
    if mode == 'say' or mode == 'yell' then
        return nil, 'hardware-event-required'
    end
    if direct[mode] then
        return direct[mode]
    end
    if mode == 'none' or mode == 'audible' then
        return nil, 'not-requested'
    end
    if mode ~= 'partyraid' and mode ~= 'party' and mode ~= 'raidwarn' then
        return nil, 'invalid-destination'
    end

    local group, why = platform:GetAnnouncementGroup()

    if not group then
        return nil, why
    end

    if mode == 'party' then
        if group.inGroup then
            return 'PARTY'
        end

        return nil, 'not-grouped'
    end

    if group.inRaid then
        if mode == 'raidwarn' and (group.isLeader == true or group.isAssistant == true) then
            return 'RAID_WARNING'
        end

        return 'RAID'
    end

    return group.inGroup and 'PARTY' or 'LOCAL'
end

-- True when the optional lease check `current` is absent or reports true; an error in it counts as retired.
local function active(current)
    if not current then
        return true
    end

    local ok, valid = pcall(current)
    return ok and valid == true
end

-- Plays the LibSharedMedia sound `key` on the Master channel. Returns true, or false and a reason code. The lease is
-- re-checked after each call that can yield to other code, so a retired announcement stays silent.
local function sound(key, current)
    if not active(current) then
        return false, 'announcement-retired'
    end
    if not platform:CanReadValue(key) then
        return false, 'restricted-value'
    end
    if key == nil or key == '' then
        return false, 'not-requested'
    end
    if type(key) ~= 'string' then
        return false, 'invalid-sound'
    end

    local play = PlaySoundFile

    if type(play) ~= 'function' then
        return false, 'missing-api'
    end

    local ok, media = pcall(LibStub, 'LibSharedMedia-3.0', true)

    if not active(current) then
        return false, 'announcement-retired'
    end
    if not ok or type(media) ~= 'table' or type(media.Fetch) ~= 'function' then
        return false, 'missing-media'
    end

    local fetched, path = pcall(media.Fetch, media, 'sound', key, true)

    if not fetched then
        return false, 'media-error'
    end
    if not platform:CanReadValue(path) then
        return false, 'restricted-value'
    end
    if not (type(path) == 'string' and path ~= ''
        or type(path) == 'number' and path > 0 and path < math.huge and path % 1 == 0) then
        return false, 'sound-unavailable'
    end
    if not active(current) then
        return false, 'announcement-retired'
    end

    local played, willPlay = pcall(play, path, 'Master')

    if not played then
        return false, 'api-error'
    end
    if not platform:CanReadValue(willPlay) or willPlay == false then
        return false, 'sound-unavailable'
    end

    return true
end

-- Output is best-effort and independent: a failed chat or audio API must not
-- interrupt cast bookkeeping or recommendation evaluation. This does not
-- construct templates, match events, or retry messages through another path.
-- Sends `text` for one announcement config and plays its sound. Returns { chat, sound, chatReason, soundReason }:
-- booleans for what happened and reason codes for what did not. `castRecipient` is the gesture target and `current`
-- the lease check.
function addon:DispatchAnnouncement(config, text, castRecipient, current)
    local result = { chat = false, sound = false }

    if not platform:CanReadValue(config) or type(config) ~= 'table' then
        return result
    end

    if not active(current) then
        result.chatReason = 'announcement-retired'
        return result
    end

    local dest, why = destination(config.announce)
    result.chatReason = why

    if not active(current) then
        result.chatReason = 'announcement-retired'
        return result
    end

    if dest == 'GESTURE' then
        local serial = beginEmote('automatic')
        local target = config.emote_target and castRecipient or ''
        local detail

        if config.emote_target and (not platform:CanReadValue(target) or type(target) ~= 'string' or target == '') then
            result.chatReason = 'cast-recipient-unavailable'
        else
            local sent, reason, observed = platform:PerformAnnouncementEmote(config.emote, target, current)
            result.chat = sent == true
            result.chatReason = reason
            detail = observed
        end

        finishEmote('automatic', serial, config.emote_target and 'cast-recipient' or 'none', result.chatReason, detail)
        dest = nil
    end

    if dest then
        if not platform:CanReadValue(text) or type(text) ~= 'string' then
            result.chatReason = 'invalid-message'
        elseif dest == 'LOCAL' then
            local announce = self.announce

            if type(announce) == 'function' and active(current) then
                result.chat = pcall(announce, self, text)

                if not result.chat then
                    result.chatReason = 'api-error'
                end
            else
                result.chatReason = 'missing-api'
            end
        else
            local sent, reason = platform:SendAnnouncementChat(text, dest, current)
            result.chat = sent == true
            result.chatReason = reason
        end
    end

    if not active(current) then
        result.soundReason = 'announcement-retired'
        return result
    end

    result.sound, result.soundReason = sound(config.announce_sound, current)
    return result
end

-- ============================================================================
-- Diagnostics and runtime source
-- ============================================================================

-- Called only by an explicitly labelled diagnostic button. It sends one
-- independent targetless CHEER, never a pending announcement or cast retry.
-- Returns { chat, chatReason } for the button to show.
function addon:TestAnnouncementEmote()
    local serial = beginEmote('test')
    local sent, reason, detail = platform:PerformAnnouncementEmote('CHEER', '')
    finishEmote('test', serial, 'none', reason, detail)
    return { chat = sent == true, chatReason = reason }
end

-- Builds the plain-text emote diagnostics report from the two retained observations. Holds no recipient names or
-- message text, only the whitelisted backend and call facts.
function addon:GetAnnouncementEmoteReport()
    local lines = {
        'Rotation Master emote diagnostics',
        'Native call completion does not prove visible output. Native booleans are reported without interpretation.',
        'Only the latest automatic emote and explicit click test are retained; no recipient names or message text.',
    }

    for _, entry in ipairs({ { 'automatic', 'Automatic:' }, { 'test', 'Explicit click test:' } }) do
        local row = emoteObservation[entry[1]]

        lines[#lines + 1] = entry[2]
            .. (row and (' target=' .. row.target .. '; result=' .. row.reason) or ' not observed')

        if row and row.detail then
            local detail = row.detail

            lines[#lines + 1] = 'backend='
                .. (detail.backend or 'unavailable')
                .. '; call='
                .. (detail.call or 'unavailable')

            if detail.returns then
                lines[#lines + 1] = 'native returns='
                    .. detail.returns
                    .. '; first type='
                    .. (detail.firstType or 'unavailable')
                    .. (detail.firstBoolean ~= nil and ('; first boolean=' .. tostring(detail.firstBoolean)) or '')
            end
        end
    end

    return table.concat(lines, '\n')
end

-- Definition-owned consumer identity, cold-consumed by the runtime planner.
local runtimeDispatch = addon.DispatchAnnouncement
local runtimeDispatchEnvironment = getfenv(1)

-- Hands the active runtime plan the original DispatchAnnouncement and its environment so it can later prove neither was
-- replaced. Works only for the addon itself.
function addon:ConsumeAnnouncementRuntimeSource()
    if self ~= addon then
        return
    end

    return runtimeDispatch, runtimeDispatchEnvironment
end
