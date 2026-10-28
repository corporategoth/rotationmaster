-- Validators for announcement configuration: a single announcement, a series (an announcement that owns a list of
-- output cards), one output card, and the macro identifiers and item references they carry. Pure checks over saved or
-- imported data; they build nothing, store nothing and read no game API. Every validator is strict: an unknown key, a
-- wrong type, an oversized string or a table with a metatable makes the whole entry invalid, so imports and the
-- settings draft can reject it before it is saved. Loaded from the Core group of RotationMaster.toc, before
-- Core/announcements.lua (delivery) and Core/profile_data.lua and validate.lua, which call these.
local _, addon = ...

-- ============================================================================
-- Shared field checks
-- ============================================================================

-- Reports whether a value is a usable item reference for an announcement.
-- @param items any  The candidate reference.
-- @return boolean  True for a string of at most 128 bytes (an item set), or a dense list of at most 256 entries of
--   positive integer item ids or strings of at most 1024 bytes.
function addon:IsValidAnnouncementItemReference(items)
    if type(items) == 'string' then
        return #items > 0 and #items <= 128
    end
    if type(items) ~= 'table' or #items == 0 or #items > 256 then
        return false
    end

    local count = 0

    for key, item in pairs(items) do
        if
            type(key) ~= 'number'
            or key < 1
            or key % 1 ~= 0
            or key > #items
            or not (type(item) == 'number' and item > 0 and item < math.huge and item % 1 == 0
                or type(item) == 'string' and #item > 0 and #item <= 1024)
        then
            return false
        end

        count = count + 1
    end

    return count == #items
end

-- Reports whether a value is a macro announcement identifier.
-- @param value any  The candidate identifier.
-- @return boolean  True for a string of at most 64 characters, starting with a letter or underscore and continuing with
--   letters, digits, underscore, dot or hyphen.
function addon:IsValidMacroAnnouncementIdentifier(value)
    return type(value) == 'string' and #value <= 64 and value:match('^[A-Za-z_][A-Za-z0-9_.-]*$') ~= nil
end

-- Reports whether every macro announcement in a list has a valid identifier, and no two share one.
-- @param entries table  The list of announcements; entries that are not macros are ignored.
-- @return boolean  True when the identifiers are valid and unique; false otherwise, including when `entries` is not a
--   table.
--
-- Cold configuration/import check; no retained lookup registry or polling work.
function addon:AreMacroAnnouncementIdentifiersUnique(entries)
    if type(entries) ~= 'table' then
        return false
    end

    local seen = {}

    for _, entry in ipairs(entries) do
        if type(entry) == 'table' and entry.type == 'macro' then
            if not self:IsValidMacroAnnouncementIdentifier(entry.identifier) or seen[entry.identifier] then
                return false
            end

            seen[entry.identifier] = true
        end
    end

    return true
end

-- Reports whether a value is a canonical UUID string (8-4-4-4-12 hex digits), the form used for announcement and output
-- card ids.
-- @param value any  The candidate id.
-- @return boolean  True for a canonical UUID string.
local function outputIdentity(value)
    return type(value) == 'string'
        and value:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') ~= nil
end

-- ============================================================================
-- Output cards
-- ============================================================================

-- Reports whether a value is one well-formed output card of a series.
-- @param value any  The candidate output card.
-- @param macro boolean|nil  True for a macro series, the only kind that may use say, yell, whisper or channel.
-- @return boolean  True for a UUID id, only known keys, an announce mode, and conditions that pass the portable-data
--   and
--   body validators.
--
-- Output cards are bounded configuration data; imports never execute callbacks.
function addon:IsValidAnnouncementOutput(value, macro)
    if type(value) ~= 'table' or getmetatable(value) ~= nil or not outputIdentity(value.id) then
        return false
    end

    local allowed = {
        id = true,
        announce = true,
        value = true,
        announce_sound = true,
        emote = true,
        emote_target = true,
        conditions = true,
        disabled = true,
        channel_name = true,
    }

    for key in pairs(value) do
        if not allowed[key] then
            return false
        end
    end

    if not ({
        partyraid = true,
        party = true,
        raidwarn = true,
        emote = true,
        ['local'] = true,
        audible = true,
        gesture = true,
        say = macro,
        yell = macro,
        whisper = macro,
        channel = macro,
    })[value.announce] then
        return false
    end
    if
        value.disabled ~= nil and type(value.disabled) ~= 'boolean'
        or value.emote_target ~= nil and type(value.emote_target) ~= 'boolean'
    then
        return false
    end
    if value.value ~= nil and (type(value.value) ~= 'string' or #value.value > 4096) then
        return false
    end
    if value.announce_sound ~= nil and (type(value.announce_sound) ~= 'string' or #value.announce_sound > 256) then
        return false
    end
    if
        value.emote ~= nil
        and (type(value.emote) ~= 'string' or #value.emote > 64 or not value.emote:match('^[A-Z][A-Z0-9_]*$'))
    then
        return false
    end
    if value.announce == 'gesture' and value.emote == nil then
        return false
    end
    if value.announce == 'audible' and (not value.announce_sound or not value.announce_sound:find('%S')) then
        return false
    end
    if
        value.channel_name ~= nil
        and (type(value.channel_name) ~= 'string'
            or #value.channel_name == 0
            or #value.channel_name > 256
            or value.channel_name:find('[%z\1-\31\127]'))
    then
        return false
    end
    if value.announce == 'channel' and value.channel_name == nil then
        return false
    end

    if value.conditions ~= nil then
        if type(value.conditions) ~= 'table' or not self.RotationData.CheckPortable(value.conditions) then
            return false
        end

        local result = self.RotationData.ValidateBody({ switch = value.conditions, rotation = {}, cooldowns = {} }, {
            conditions = self.conditionDefinitions,
        })

        if not result.valid or not result.supported then
            return false
        end
    end

    return true
end

-- ============================================================================
-- Announcements and series
-- ============================================================================

-- Validates a series: an announcement with an `outputs` list of at most 64 cards, each valid for this series' kind with
-- a unique id.
-- @param owner table  The addon, whose validators and event table are used.
-- @param value table  The candidate series.
-- @param requireIdentity boolean|nil  True to demand a UUID id on the series itself.
-- @return boolean  True when the series is well-formed.
--
-- Spell, pet and item series need a known event; a macro series needs an identifier and none of the spell, item, ranked
-- or event fields.
local function validSeries(owner, value, requireIdentity)
    if getmetatable(value) ~= nil or requireIdentity and not outputIdentity(value.id) then
        return false
    end

    local allowed = {
        id = true,
        name = true,
        type = true,
        spell = true,
        item = true,
        ranked = true,
        event = true,
        identifier = true,
        disabled = true,
        outputs = true,
    }

    for key in pairs(value) do
        if not allowed[key] then
            return false
        end
    end

    for _, key in ipairs({ 'disabled', 'ranked' }) do
        if value[key] ~= nil and type(value[key]) ~= 'boolean' then
            return false
        end
    end

    if value.name ~= nil and (type(value.name) ~= 'string' or #value.name > 256) then
        return false
    end

    local macro = value.type == 'macro'

    if macro then
        if
            not owner:IsValidMacroAnnouncementIdentifier(value.identifier)
            or value.spell ~= nil
            or value.item ~= nil
            or value.ranked ~= nil
            or value.event ~= nil
        then
            return false
        end
    elseif value.type ~= 'spell' and value.type ~= 'pet' and value.type ~= 'item' then
        return false
    elseif value.identifier ~= nil or type(value.event) ~= 'string' or not (owner.events or {})[value.event] then
        return false
    elseif value.type == 'item' then
        if not owner:IsValidAnnouncementItemReference(value.item) then
            return false
        end
    elseif type(value.spell) ~= 'number' or value.spell <= 0 or value.spell == math.huge or value.spell % 1 ~= 0 then
        return false
    end

    local outputs = value.outputs

    if type(outputs) ~= 'table' or getmetatable(outputs) ~= nil or #outputs > 64 then
        return false
    end

    local count, seen = 0, {}

    for index, output in pairs(outputs) do
        if
            type(index) ~= 'number'
            or index < 1
            or index % 1 ~= 0
            or index > #outputs
            or not owner:IsValidAnnouncementOutput(output, macro)
            or seen[output.id]
        then
            return false
        end

        count = count + 1
        seen[output.id] = true
    end

    return count == #outputs
end

-- Reports whether a value is a well-formed announcement of either shape.
-- @param value any  The candidate announcement: a series (it has `outputs`) or the older single announcement that
--   carries its own announce mode, text, sound, emote and conditions.
-- @param requireIdentity boolean|nil  True to demand a UUID id, as the saved profile does.
-- @return boolean  True when the announcement is well-formed.
--
-- Note the single form allows say and yell for every type and whisper only for macros.
function addon:IsValidAnnouncement(value, requireIdentity)
    if type(value) ~= 'table' then
        return false
    end
    if value.outputs ~= nil then
        return validSeries(self, value, requireIdentity)
    end
    if
        requireIdentity
        and (type(value.id) ~= 'string'
            or not value.id:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$'))
    then
        return false
    end

    local allowed = {
        name = true,
        id = true,
        type = true,
        spell = true,
        item = true,
        ranked = true,
        disabled = true,
        event = true,
        announce = true,
        value = true,
        announce_sound = true,
        emote = true,
        emote_target = true,
        conditions = true,
        identifier = true,
    }

    for key in pairs(value) do
        if not allowed[key] then
            return false
        end
    end

    local macro = value.type == 'macro'

    if macro then
        if
            not self:IsValidMacroAnnouncementIdentifier(value.identifier)
            or value.spell ~= nil
            or value.item ~= nil
            or value.ranked ~= nil
            or value.event ~= nil
        then
            return false
        end
    elseif value.type ~= 'spell' and value.type ~= 'pet' and value.type ~= 'item' then
        return false
    elseif value.identifier ~= nil or type(value.event) ~= 'string' or not (self.events or {})[value.event] then
        return false
    end

    if not ({
        partyraid = true,
        party = true,
        raidwarn = true,
        emote = true,
        ['local'] = true,
        audible = true,
        say = true,
        yell = true,
        gesture = true,
        whisper = macro,
    })[value.announce] then
        return false
    end

    for _, key in ipairs({ 'disabled', 'ranked' }) do
        if value[key] ~= nil and type(value[key]) ~= 'boolean' then
            return false
        end
    end

    if value.name ~= nil and (type(value.name) ~= 'string' or #value.name > 256) then
        return false
    end
    if value.value ~= nil and (type(value.value) ~= 'string' or #value.value > 4096) then
        return false
    end
    if value.announce_sound ~= nil and (type(value.announce_sound) ~= 'string' or #value.announce_sound > 256) then
        return false
    end
    if value.emote_target ~= nil and type(value.emote_target) ~= 'boolean' then
        return false
    end
    if
        value.emote ~= nil
        and (type(value.emote) ~= 'string' or #value.emote > 64 or not value.emote:match('^[A-Z][A-Z0-9_]*$'))
    then
        return false
    end
    if value.announce == 'gesture' and value.emote == nil then
        return false
    end
    if value.announce == 'audible' and (not value.announce_sound or not value.announce_sound:find('%S')) then
        return false
    end

    if value.conditions ~= nil then
        if type(value.conditions) ~= 'table' or not self.RotationData.CheckPortable(value.conditions) then
            return false
        end

        local result = self.RotationData.ValidateBody({ switch = value.conditions, rotation = {}, cooldowns = {} }, {
            conditions = self.conditionDefinitions,
        })

        if not result.valid or not result.supported then
            return false
        end
    end

    if macro then
        return true
    end
    if value.type ~= 'item' then
        return type(value.spell) == 'number' and value.spell > 0 and value.spell % 1 == 0
    end

    return self:IsValidAnnouncementItemReference(value.item)
end
