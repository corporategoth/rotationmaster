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

local function plain(v)
    return kind(v) == 'table' and meta(v) == nil
end

local function text(v, n)
    return kind(v) == 'string' and #v > 0 and #v <= n and find(v, '%S') ~= nil and not find(v, '[%z\1-\31\127]')
end

local function spec(v)
    return kind(v) == 'number' and v >= 0 and v < infinity and v % 1 == 0
end

local function closed(v, fields)
    if not plain(v) then return false end

    for k in step, v do
        if not fields[k] then return false end
    end

    return true
end

local function same(a, b)
    if kind(a) ~= kind(b) then return false end
    if kind(a) ~= 'table' then return a == b end
    if not plain(a) or not plain(b) then return false end

    for k, v in step, a do
        if not same(v, get(b, k)) then return false end
    end

    for k in step, b do
        if get(a, k) == nil then return false end
    end

    return true
end

local function copy(v)
    if kind(v) ~= 'table' then return v end
    local r = {}

    for k, x in step, v do
        r[k] = copy(x)
    end

    return r
end

local function reference(v, row)
    if not plain(v) then return false end
    if v.kind == 'builtin' then return closed(v, { kind = true, id = true }) and text(v.id, 128) end

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

local function domain(a, b)
    return a.family == b.family
        and a.character == b.character
        and a.class == b.class
        and a.spec == b.spec
        and a.actionContext == b.actionContext
end

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
        if row.reference.address then seen[row.reference.address] = true end

        for j = 1, k - 1 do
            local prior = get(value.entries, j)
            if prior and domain(row, prior) then return false end
        end
    end

    for i = 1, n do
        if get(value.entries, i) == nil then return false end
    end

    return true
end

function addon:ValidateRotationChoicePreferences(value)
    return self == addon and validate(value)
end

local generation = {}
local publicationEpoch = {}
local cache, dirty = nil, true

local function profile()
    local db = get(addon, 'db')
    return kind(db) == 'table' and get(db, 'profile')
end

local function root(p)
    return plain(p) and get(p, 'rotationChoicePreferences')
end

local function capture()
    local p = profile()
    if not plain(p) then return nil end
    local r = root(p)
    if r ~= nil and not validate(r) then return nil end
    return { profile = p, root = r, snapshot = r and copy(r), generation = generation }
end

local function current(ticket)
    return ticket
        and equal(profile(), ticket.profile)
        and equal(root(ticket.profile), ticket.root)
        and generation == ticket.generation
        and (ticket.root == nil or same(ticket.root, ticket.snapshot))
end

local function publish(ticket, value)
    if not current(ticket) then return false end
    set(ticket.profile, 'rotationChoicePreferences', #value.entries > 0 and value or nil)
    generation = {}
    dirty = true
    return true
end

local function characterKey()
    local db = get(addon, 'db')
    local keys = kind(db) == 'table' and get(db, 'keys')
    return kind(keys) == 'table' and get(keys, 'char')
end

local function needsRefresh(owner)
    if owner ~= addon then return false end
    local p = profile()

    return dirty
        or not cache
        or not equal(cache.profile, p)
        or not equal(cache.root, root(p))
        or cache.spec ~= get(owner, 'currentSpec')
        or cache.character ~= characterKey()
        or cache.contextMethod ~= get(owner, 'GetRotationContext')
end

local function observe(owner, needDomain)
    local p = profile()
    local number = get(owner, 'currentSpec')
    local r = root(p)
    if not needsRefresh(owner) then return cache, false end
    -- Only cold profile/spec/context/publication invalidations reach observation.
    local character, method = characterKey(), get(owner, 'GetRotationContext')
    dirty = false
    cache = { profile = p, root = r, spec = number, character = character, contextMethod = method }
    local ticket = capture()
    if not ticket or not spec(number) or r == nil and not needDomain then return nil, true end
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

function addon:InvalidateRotationChoiceContext()
    if self ~= addon then return false end
    dirty = true
    return true
end

local function prepareSelection(owner, referenceValue)
    if owner ~= addon then return nil end
    dirty = true
    local state = observe(owner, true)
    if not state then return nil end
    if referenceValue ~= nil and not reference(referenceValue, state.domain) then return nil end
    local ticket = capture()
    if not ticket then return nil end
    local value = ticket.snapshot or { version = 1, entries = {} }
    local entries = {}

    for i = 1, #value.entries do
        if not domain(value.entries[i], state.domain) then entries[#entries + 1] = value.entries[i] end
    end

    if referenceValue then
        local row = copy(state.domain)
        row.reference = copy(referenceValue)
        entries[#entries + 1] = row
    end

    if #entries > 256 then return nil end
    ticket.value = { version = 1, entries = entries }
    return ticket
end

local function finishSelection(ticket)
    return ticket and publish(ticket, ticket.value) or false
end

local function readDesired(owner)
    if owner ~= addon then return nil, false end
    local state, changed = observe(owner)
    return changed and state and state.reference and copy(state.reference) or nil, changed
end

-- Direct one-time cold handoffs. No callback registry, public post-write
-- notification, game API or extensible copying is used by either finalizer.
local selectionBound, publicationBound = false, false

function addon:ConsumeRotationChoiceSelection()
    if self ~= addon or selectionBound then return nil end
    selectionBound = true
    return prepareSelection, finishSelection, readDesired, needsRefresh
end

local function preparePublication(p, oldReference, nextReference)
    if nextReference and same(oldReference, nextReference) then return nil end
    local ticket = capture()
    if not ticket or not equal(p, ticket.profile) or not ticket.snapshot then return nil end
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

    if not changed then return nil end
    ticket.value = value
    ticket.removed = removed
    ticket.target = nextReference and copy(nextReference)
    ticket.store = get(p, 'rotationStore')
    ticket.publicationEpoch = publicationEpoch
    return ticket
end

local function child(value, key)
    return plain(value) and get(value, key)
end

local function targetPresent(ticket)
    local r = ticket.target
    if not r or r.kind ~= 'custom' then return true end
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

function addon:ConsumeRotationChoicePublication()
    if self ~= addon or publicationBound then return nil end
    publicationBound = true
    return preparePublication, finishPublication
end
