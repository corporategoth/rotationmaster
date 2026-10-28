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

-- True for a table without a metatable.
local function plain(v)
    return kind(v) == 'table' and meta(v) == nil
end

-- True for a printable string of 1 to `n` bytes with at least one non-space character and no control characters.
local function text(v, n)
    return kind(v) == 'string' and #v > 0 and #v <= n and find(v, '%S') ~= nil and not find(v, '[%z\1-\31\127]')
end

-- True for a non-negative integer specialization index.
local function spec(v)
    return kind(v) == 'number' and v >= 0 and v < infinity and v % 1 == 0
end

-- True when `v` is a plain table whose keys are all in the `fields` set.
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

-- Structural equality for plain data with raw reads; false for any table with a metatable.
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

-- True when `v` is a valid rotation reference for `row`'s class, specialization and character: { kind = 'builtin', id }
-- or { kind = 'custom', address } where the address scope is class or character and its owner matches the row.
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

-- True when two rows describe the same context (family, character, class, specialization, action context).
local function domain(a, b)
    return a.family == b.family
        and a.character == b.character
        and a.class == b.class
        and a.spec == b.spec
        and a.actionContext == b.actionContext
end

-- True when `value` is a well-formed preference table: version 1, a dense list of at most 256 rows, every row closed
-- and valid, no shared sub-tables, and at most one row per context.
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

-- Public validator used by profile validation; false for any caller other than the addon.
function addon:ValidateRotationChoicePreferences(value)
    return self == addon and validate(value)
end

-- ============================================================================
-- Observation and tickets
-- ============================================================================

local generation = {}
local publicationEpoch = {}
local cache, dirty = nil, true

-- Returns the saved profile table with a raw read, or nil.
local function profile()
    local db = get(addon, 'db')
    return kind(db) == 'table' and get(db, 'profile')
end

-- Returns the preference table stored in profile `p`, if any.
local function root(p)
    return plain(p) and get(p, 'rotationChoicePreferences')
end

-- Snapshots the profile, the preference table and a copy of it into a ticket, or returns nil when the saved table is
-- invalid. A ticket is only good while nothing it captured has changed (see current).
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

-- True while a ticket's profile, preference table and generation are untouched since capture().
local function current(ticket)
    return ticket
        and equal(profile(), ticket.profile)
        and equal(root(ticket.profile), ticket.root)
        and generation == ticket.generation
        and (ticket.root == nil or same(ticket.root, ticket.snapshot))
end

-- Writes `value` into the profile if the ticket is still current, dropping the table when it has no rows, and marks the
-- cache dirty. Returns true when written.
local function publish(ticket, value)
    if not current(ticket) then
        return false
    end

    set(ticket.profile, 'rotationChoicePreferences', #value.entries > 0 and value or nil)
    generation = {}
    dirty = true
    return true
end

-- Returns the current character key (db.keys.char), or nil.
local function characterKey()
    local db = get(addon, 'db')
    local keys = kind(db) == 'table' and get(db, 'keys')
    return kind(keys) == 'table' and get(keys, 'char')
end

-- True when the cached observation no longer matches the profile, preference table, specialization, character or
-- GetRotationContext method, or has been marked dirty.
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

-- Resolves the current context (through GetRotationContext) and the stored reference for it. Returns the cached state
-- and whether it was recomputed; nil when the context is unusable. With no saved rows and no `needDomain` it skips the
-- context lookup. The state is rebuilt only after an invalidation, never on every poll.
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

-- Step one of choosing a rotation: builds the new table for the current context, replacing its row with one holding
-- `referenceValue`, or removing it when that is nil. Returns a ticket, or nil when the context, the reference or the
-- 256-row limit forbid it. Nothing is written until finishSelection.
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

-- Step two: writes the prepared table if nothing changed since prepare. Returns true when written.
local function finishSelection(ticket)
    return ticket and publish(ticket, ticket.value) or false
end

-- Returns a copy of the stored reference for the current context (or nil) and whether the state was recomputed.
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

-- One-time handoff to main.lua: returns prepareSelection, finishSelection, readDesired and needsRefresh, then refuses
-- any later caller.
function addon:ConsumeRotationChoiceSelection()
    if self ~= addon or selectionBound then
        return nil
    end

    selectionBound = true
    return prepareSelection, finishSelection, readDesired, needsRefresh
end

-- Step one of a rotation change that affects saved preferences: builds the table in which every row pointing at
-- `oldReference` now points at `nextReference` (or is removed when that is nil or invalid for the row), and a second
-- table with those rows removed for use if the target disappears. Returns a ticket, or nil when no row is affected.
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
local function child(value, key)
    return plain(value) and get(value, key)
end

-- True when the custom rotation the ticket points at still has a body in the store (a Built In target always counts).
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
-- write was nested or the target vanished. Returns true when written; false when the store changed or the writer was
-- not authorized.
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

-- One-time handoff to Core/rotation_scope.lua: returns preparePublication and finishPublication, then refuses any later
-- caller.
function addon:ConsumeRotationChoicePublication()
    if self ~= addon or publicationBound then
        return nil
    end

    publicationBound = true
    return preparePublication, finishPublication
end
