-- A real addon on one client family, every Conditions/*.lua file loaded and
-- evaluable, with one sentinel standing in for every secret value (Lua cannot
-- make a real secret; issecretvalue and canaccessvalue recognise the sentinel).
-- Callers add the natives they need to the returned environment.
local F = dofile('tests/fixtures/addon.lua')
local corpus = dofile('tests/fixtures/default_corpus.lua')
local M = {}

-- name -> {WOW_PROJECT_ID, LE_EXPANSION_LEVEL_CURRENT}. wrath and cata have no API manifest, so
-- their environment is unrestricted; they exist for the edition rules that name them.
M.clients = {
    retail = { 1, 12 },
    forever = { 18, 12 },
    mists = { 19, 4 },
    tbc = { 5, 1 },
    era = { 2, 0 },
    wrath = { 11, 2 },
    cata = { 14, 3 },
}

M.order = { 'retail', 'forever', 'mists', 'tbc', 'era' }
M.SECRET = setmetatable({}, { __tostring = function() return 'secret' end })

function M.isSecret(value)
    return rawequal(value, M.SECRET)
end

function M.canAccess(value)
    return not rawequal(value, M.SECRET)
end

-- extra: platform files to load after the support table (Platform/world_state.lua ...).
function M.load(name, class, extra)
    local project, expansion = M.clients[name][1], M.clients[name][2]
    local f = corpus.load(project, expansion, class or 'WARRIOR', { modules = false })
    local a, e = f.addon, f.env
    f.load('Core/condition_support.lua')

    for _, path in ipairs(extra or {}) do
        f.load(path)
    end

    for _, definition in pairs(a.conditionDefinitions) do
        definition.evaluate = nil
    end

    for line in io.lines('RotationMaster.toc') do
        local path = line:gsub('\r', ''):match('^%s*(Conditions/.-%.lua)%s*$')

        if path then
            f.load(path)
        end
    end

    e.issecretvalue = M.isSecret
    e.canaccessvalue = M.canAccess

    a.Platform.CanReadValue = function(_, v)
        if M.isSecret(v) or not M.canAccess(v) then
            return false, 'restricted-value'
        end

        return true
    end

    a.conditionRegistryVersion = (a.conditionRegistryVersion or 0) + 1
    return f, a, e
end

function M.status(a, condition)
    local r = a:evaluateConditionResult(condition)
    return r.status, r.reason
end

-- The condition's status, and the same under NOT: unavailable stays unavailable, match and no-match swap.
function M.expect(a, condition, wanted, label)
    local got, reason = M.status(a, condition)

    assert(
        got == wanted,
        (label or condition.type) .. ': ' .. tostring(got) .. ' (' .. tostring(reason) .. '), wanted ' .. wanted
    )

    local negated = { match = 'no-match', ['no-match'] = 'match', unavailable = 'unavailable' }
    local under = M.status(a, { type = 'NOT', value = condition })
    assert(under == negated[wanted], (label or condition.type) .. ' under NOT: ' .. tostring(under))
end

function M.support(a, tag, value)
    return a:GetConditionSupport(tag, a.conditionDefinitions[tag], value or {})
end

return M
