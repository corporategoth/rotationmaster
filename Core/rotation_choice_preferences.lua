-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Per-profile memory of which rotation the player chose for each specialization context. A preference is one row
-- keyed by family, character, class, specialization and action context (player, pet, vehicle, ...) that holds a
-- reference to a Built In rotation or a custom rotation address; db.profile.rotationChoicePreferences is the
-- { version = 1, entries } table. This file validates that table, reads the row for the current context, and keeps rows
-- in step when a rotation is renamed, moved or deleted. It never starts advice or activates a rotation. main.lua and
-- Core/rotation_scope.lua each take their private functions once (Consume...); loaded from the Core rotation group of
-- RotationMaster.toc after Core/rotation_active.lua.
local _, addon = ...
-- Desired choice is portable data. Effective activation remains owned by the
-- existing active-rotation coordinator; this module never starts advice.
local kind, get, set, step, meta, equal = type, rawget, rawset, next, getmetatable, rawequal
local find = string.find
local infinity = math.huge
local families = { retail = true, era = true, progression = true, tbc = true, forever = true }
local contexts = { player = true, pet = true, vehicle = true, possession = true, override = true, petbattle = true }

local classes = {
    WARRIOR = true,
    PALADIN = true,
    HUNTER = true,
    ROGUE = true,
    PRIEST = true,
    DEATHKNIGHT = true,
    SHAMAN = true,
    MAGE = true,
    WARLOCK = true,
    MONK = true,
    DRUID = true,
    DEMONHUNTER = true,
    EVOKER = true,
}

-- ============================================================================
-- Validation
-- ============================================================================

-- Reports whether a value is a table without a metatable.
-- @param v any  The value.
-- @return boolean  True for such a table.
local function plain(v)
    return kind(v) == 'table' and meta(v) == nil
end

-- Reports whether a value is a printable string.
-- @param v any  The value.
-- @param n number  The most bytes allowed.
-- @return boolean  True for a string of 1 to `n` bytes with at least one non-space character and no control characters.
local function text(v, n)
    return kind(v) == 'string' and #v > 0 and #v <= n and find(v, '%S') ~= nil and not find(v, '[%z\1-\31\127]')
end

-- Reports whether a value is a valid specialization index.
-- @param v any  The value.
-- @return boolean  True for a non-negative integer.
local function spec(v)
    return kind(v) == 'number' and v >= 0 and v < infinity and v % 1 == 0
end

-- Reports whether a value is a plain table whose keys are all in a set.
-- @param v any  The value.
-- @param fields table  The set of allowed keys.
-- @return boolean  True when it is.
local function closed(v, fields)
    if not plain(v) then
        return false
    end

    for k in step, v do
        if not fields[k] then
            return false
        end
    end

    return true
end

-- Structural equality for plain data with raw reads.
-- @param a any  The first value.
-- @param b any  The second value.
-- @return boolean  True when equal; false for any table with a metatable.
local function same(a, b)
    if kind(a) ~= kind(b) then
        return false
    end
    if kind(a) ~= 'table' then
        return a == b
    end
    if not plain(a) or not plain(b) then
        return false
    end

    for k, v in step, a do
        if not same(v, get(b, k)) then
            return false
        end
    end

    for k in step, b do
        if get(a, k) == nil then
            return false
        end
    end

    return true
end

-- Deep copy of plain, already validated data.
-- @param v any  The value to copy; non-tables are returned as they are.
-- @return any  The copy.
local function copy(v)
    if kind(v) ~= 'table' then
        return v
    end

    local r = {}

    for k, x in step, v do
        r[k] = copy(x)
    end

    return r
end

-- Reports whether a value is a valid rotation reference for a row's class, specialization and character.
-- @param v any  The candidate reference: { kind = 'builtin', id } or { kind = 'custom', address }, where the address
--   scope is class or character and its owner matches the row.
-- @param row table  The preference row.
-- @return boolean  True when it is.
local function reference(v, row)
    if not plain(v) then
        return false
    end
    if v.kind == 'builtin' then
        return closed(v, { kind = true, id = true }) and text(v.id, 128)
    end
    if
        v.kind ~= 'custom'
        or not closed(v, { kind = true, address = true })
        or not closed(v.address, { scope = true, class = true, owner = true, spec = true, id = true })
    then
        return false
    end

    local a = v.address

    return (a.scope == 'class' or a.scope == 'character')
        and a.class == row.class
        and a.spec == row.spec
        and text(a.id, 128)
        and a.owner == (a.scope == 'class' and row.class or row.character)
end

-- Reports whether two rows describe the same context (family, character, class, specialization, action context).
-- @param a table  The first row.
-- @param b table  The second row.
-- @return boolean  True when they do.
local function domain(a, b)
    return a.family == b.family
        and a.character == b.character
        and a.class == b.class
        and a.spec == b.spec
        and a.actionContext == b.actionContext
end

-- Reports whether a value is a well-formed preference table.
-- @param value any  The candidate table.
-- @return boolean  True for version 1, a dense list of at most 256 rows, every row closed and valid, no shared
--   sub-tables, and at most one row per context.
local function validate(value)
    if not closed(value, { version = true, entries = true }) or value.version ~= 1 or not plain(value.entries) then
        return false
    end

    local n = 0
    local seen = {}

    for k, row in step, value.entries do
        n = n + 1

        if
            n > 256
            or kind(k) ~= 'number'
            or k < 1
            or k % 1 ~= 0
            or k > 256
            or not closed(row, {
                family = true,
                character = true,
                class = true,
                spec = true,
                actionContext = true,
                reference = true,
            })
        then
            return false
        end
        if
            not families[row.family]
            or not contexts[row.actionContext]
            or not classes[row.class]
            or not text(row.character, 512)
            or not spec(row.spec)
            or not reference(row.reference, row)
        then
            return false
        end

        -- Shared records/addresses cannot hide ownership or duplicate a domain.
        if seen[row] or seen[row.reference] or row.reference.address and seen[row.reference.address] then
            return false
        end

        seen[row] = true
        seen[row.reference] = true

        if row.reference.address then
            seen[row.reference.address] = true
        end

        for j = 1, k - 1 do
            local prior = get(value.entries, j)

            if prior and domain(row, prior) then
                return false
            end
        end
    end

    for i = 1, n do
        if get(value.entries, i) == nil then
            return false
        end
    end

    return true
end

-- Validates a preference table; the public validator used by profile validation.
-- @param value any  The candidate preference table.
-- @return boolean  True when valid; false for any caller other than the addon.
function addon:ValidateRotationChoicePreferences(value)
    return self == addon and validate(value)
end

-- ============================================================================
-- Observation and tickets
-- ============================================================================

local generation = {}
local publicationEpoch = {}
local cache, dirty = nil, true

-- Returns the saved profile table with a raw read.
-- @return table|nil  The profile; nil (or false) when there is none.
local function profile()
    local db = get(addon, 'db')
    return kind(db) == 'table' and get(db, 'profile')
end

-- Returns the preference table stored in a profile, if any.
-- @param p any  The profile.
-- @return table|nil  The preference table; nil (or false) when there is none.
local function root(p)
    return plain(p) and get(p, 'rotationChoicePreferences')
end

-- Snapshots the profile, the preference table and a copy of it into a ticket.
-- @return table|nil  The ticket { profile, root, snapshot, generation }; nil when the saved table is invalid.
--
-- A ticket is only good while nothing it captured has changed (see current).
local function capture()
    local p = profile()

    if not plain(p) then
        return nil
    end

    local r = root(p)

    if r ~= nil and not validate(r) then
        return nil
    end

    return { profile = p, root = r, snapshot = r and copy(r), generation = generation }
end

-- Reports whether a ticket is still good.
-- @param ticket table|nil  The ticket from capture().
-- @return boolean  True while the ticket's profile, preference table and generation are untouched since capture().
local function current(ticket)
    return ticket
        and equal(profile(), ticket.profile)
        and equal(root(ticket.profile), ticket.root)
        and generation == ticket.generation
        and (ticket.root == nil or same(ticket.root, ticket.snapshot))
end

-- Writes a preference table into the profile if the ticket is still current, and marks the cache dirty.
-- @param ticket table  The ticket from capture().
-- @param value table  The new preference table; it is dropped when it has no rows.
-- @return boolean  True when written.
local function publish(ticket, value)
    if not current(ticket) then
        return false
    end

    set(ticket.profile, 'rotationChoicePreferences', #value.entries > 0 and value or nil)
    generation = {}
    dirty = true
    return true
end

-- Returns the current character key (db.keys.char).
-- @return string|nil  The key; nil when there is none.
local function characterKey()
    local db = get(addon, 'db')
    local keys = kind(db) == 'table' and get(db, 'keys')
    return kind(keys) == 'table' and get(keys, 'char')
end

-- Reports whether the cached observation is stale.
-- @param owner table  The addon; anything else gives false.
-- @return boolean  True when the cached observation no longer matches the profile, preference table, specialization,
--   character or GetRotationContext method, or has been marked dirty.
local function needsRefresh(owner)
    if owner ~= addon then
        return false
    end

    local p = profile()

    return dirty
        or not cache
        or not equal(cache.profile, p)
        or not equal(cache.root, root(p))
        or cache.spec ~= get(owner, 'currentSpec')
        or cache.character ~= characterKey()
        or cache.contextMethod ~= get(owner, 'GetRotationContext')
end

-- Resolves the current context (through GetRotationContext) and the stored reference for it.
-- @param owner table  The addon.
-- @param needDomain boolean|nil  True to look up the context even when there are no saved rows.
-- @return table|nil  The cached state { profile, root, spec, character, contextMethod, domain, reference }; nil when
--   the context is unusable.
-- @return boolean  Whether the state was recomputed.
--
-- With no saved rows and no `needDomain` it skips the context lookup. The state is rebuilt only after an invalidation,
-- never on every poll; only cold profile/spec/context/publication invalidations reach observation.
local function observe(owner, needDomain)
    local p = profile()
    local number = get(owner, 'currentSpec')
    local r = root(p)

    if not needsRefresh(owner) then
        return cache, false
    end

    -- Only cold profile/spec/context/publication invalidations reach observation.
    local character, method = characterKey(), get(owner, 'GetRotationContext')
    dirty = false
    cache = { profile = p, root = r, spec = number, character = character, contextMethod = method }
    local ticket = capture()

    if not ticket or not spec(number) or r == nil and not needDomain then
        return nil, true
    end

    local c = owner:GetRotationContext(number)

    if
        not current(ticket)
        or get(owner, 'currentSpec') ~= number
        or characterKey() ~= character
        or get(owner, 'GetRotationContext') ~= method
        or not plain(c)
        or not families[c.family]
        or not classes[c.class]
        or not contexts[c.actionContext]
        or not text(character, 512)
    then
        return nil, true
    end

    local state = {
        profile = p,
        root = r,
        spec = number,
        character = character,
        contextMethod = method,
        domain = {
            family = c.family,
            character = character,
            class = c.class,
            spec = number,
            actionContext = c.actionContext,
        },
    }

    if r then
        for i = 1, #r.entries do
            if domain(r.entries[i], state.domain) then
                state.reference = copy(r.entries[i].reference)
                break
            end
        end
    end

    cache = state
    return state, true
end

-- Marks the cached context stale; call after anything that changes family, class, specialization or action context.
-- @return boolean  True when marked; false for any caller other than the addon.
function addon:InvalidateRotationChoiceContext()
    if self ~= addon then
        return false
    end

    dirty = true
    return true
end

-- ============================================================================
-- Selection and publication handoffs
-- ============================================================================

-- Step one of choosing a rotation: builds the new table for the current context, replacing its row with one holding the
-- reference, or removing it when that is nil.
-- @param owner table  The addon.
-- @param referenceValue table|nil  The rotation reference to remember; nil removes the row.
-- @return table|nil  A ticket; nil when the context, the reference or the 256-row limit forbid it.
--
-- Nothing is written until finishSelection.
local function prepareSelection(owner, referenceValue)
    if owner ~= addon then
        return nil
    end

    dirty = true
    local state = observe(owner, true)

    if not state then
        return nil
    end
    if referenceValue ~= nil and not reference(referenceValue, state.domain) then
        return nil
    end

    local ticket = capture()

    if not ticket then
        return nil
    end

    local value = ticket.snapshot or { version = 1, entries = {} }
    local entries = {}

    for i = 1, #value.entries do
        if not domain(value.entries[i], state.domain) then
            entries[#entries + 1] = value.entries[i]
        end
    end

    if referenceValue then
        local row = copy(state.domain)
        row.reference = copy(referenceValue)
        entries[#entries + 1] = row
    end

    if #entries > 256 then
        return nil
    end

    ticket.value = { version = 1, entries = entries }
    return ticket
end

-- Step two: writes the prepared table if nothing changed since prepare.
-- @param ticket table|nil  The ticket from prepareSelection.
-- @return boolean  True when written.
local function finishSelection(ticket)
    return ticket and publish(ticket, ticket.value) or false
end

-- Returns the stored reference for the current context.
-- @param owner table  The addon.
-- @return table|nil  A copy of the stored reference; nil when there is none or the state was not recomputed.
-- @return boolean  Whether the state was recomputed.
local function readDesired(owner)
    if owner ~= addon then
        return nil, false
    end

    local state, changed = observe(owner)
    return changed and state and state.reference and copy(state.reference) or nil, changed
end

-- Direct one-time cold handoffs. No callback registry, public post-write
-- notification, game API or extensible copying is used by either finalizer.
local selectionBound, publicationBound = false, false

-- One-time handoff to main.lua, which then refuses any later caller.
-- @return function|nil  prepareSelection.
-- @return function|nil  finishSelection.
-- @return function|nil  readDesired.
-- @return function|nil  needsRefresh.
--
-- Direct one-time cold handoffs. No callback registry, public post-write notification, game API or extensible copying
-- is used by either finalizer.
function addon:ConsumeRotationChoiceSelection()
    if self ~= addon or selectionBound then
        return nil
    end

    selectionBound = true
    return prepareSelection, finishSelection, readDesired, needsRefresh
end

-- Step one of a rotation change that affects saved preferences.
-- @param p table  The profile.
-- @param oldReference table  The reference that is changing.
-- @param nextReference table|nil  The reference rows now point at; a row is removed when this is nil or invalid for it.
-- @return table|nil  A ticket holding the table in which every row pointing at `oldReference` now points at
--   `nextReference`, and a second table with those rows removed for use if the target disappears; nil when no row is
--   affected.
local function preparePublication(p, oldReference, nextReference)
    if nextReference and same(oldReference, nextReference) then
        return nil
    end

    local ticket = capture()

    if not ticket or not equal(p, ticket.profile) or not ticket.snapshot then
        return nil
    end

    local value = { version = 1, entries = {} }
    local removed = { version = 1, entries = {} }
    local changed = false

    for i = 1, #ticket.snapshot.entries do
        local row = copy(ticket.snapshot.entries[i])

        if same(row.reference, oldReference) then
            changed = true

            if nextReference and reference(nextReference, row) then
                row.reference = copy(nextReference)
                value.entries[#value.entries + 1] = row
            end
        else
            value.entries[#value.entries + 1] = row
            removed.entries[#removed.entries + 1] = copy(row)
        end
    end

    if not changed then
        return nil
    end

    ticket.value = value
    ticket.removed = removed
    ticket.target = nextReference and copy(nextReference)
    ticket.store = get(p, 'rotationStore')
    ticket.publicationEpoch = publicationEpoch
    return ticket
end

-- Reads `value[key]` raw when `value` is a plain table.
-- @param value any  The table.
-- @param key any  The key.
-- @return any  The value; nil (or false) when `value` is not a plain table.
local function child(value, key)
    return plain(value) and get(value, key)
end

-- Reports whether the custom rotation a ticket points at still has a body in the store.
-- @param ticket table  The publication ticket.
-- @return boolean  True when it does (a Built In target always counts).
local function targetPresent(ticket)
    local r = ticket.target

    if not r or r.kind ~= 'custom' then
        return true
    end

    local a = r.address
    local state = child(ticket.profile, 'rotationStore')
    local records

    if a.scope == 'class' then
        records = child(child(child(state, 'classes'), a.class), a.spec)
    else
        records = child(child(child(child(child(state, 'characters'), a.owner), 'specs'), a.spec), a.id)
        return plain(records) and plain(get(records, 'body'))
    end

    local record = child(records, a.id)
    return plain(record) and plain(get(record, 'body'))
end

-- Step two: after the store write, publishes the prepared table, or the table with the affected rows removed when the
-- write was nested or the target vanished.
-- @param ticket table|nil  The ticket from preparePublication.
-- @param authorized boolean  True when the store writer was authorized.
-- @return boolean  True when written; false when the store changed or the writer was not authorized.
local function finishPublication(ticket, authorized)
    local nested = ticket and ticket.publicationEpoch ~= publicationEpoch
    publicationEpoch = {}
    dirty = true

    if not ticket or authorized ~= true or not equal(get(ticket.profile, 'rotationStore'), ticket.store) then
        return false
    end

    -- Custom Store transports can recursively remove/move the just-saved target
    -- before returning. Do not resurrect it or infer a replacement address.
    return publish(ticket, not nested and targetPresent(ticket) and ticket.value or ticket.removed)
end

-- One-time handoff to Core/rotation_scope.lua, which then refuses any later caller.
-- @return function|nil  preparePublication.
-- @return function|nil  finishPublication.
function addon:ConsumeRotationChoicePublication()
    if self ~= addon or publicationBound then
        return nil
    end

    publicationBound = true
    return preparePublication, finishPublication
end
