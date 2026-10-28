-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Strict test-only inverse of the ECS_STAT_PCT evaluator from fc06db4.
local old = '\n'
    .. [=[
        local curs = Functions.cache.getCached(cache, ecs_state.data.GetStatInfo, value.stat)
        local cur = tonumber(curs:match("^(%d+%.?%d*)"))
        return Functions.values.compare(value.operator, cur, value.value * 100)
    ]=]

local repaired = '\n'
    .. [=[
        local curs = Functions.cache.getCached(cache, ecs_state.data.GetStatInfo, value.stat)
        local cur = tonumber(curs:match("^(%-?%d+%.?%d*)"))
        return Functions.values.compare(value.operator, cur, value.value * 100)
    ]=]

local function inverse(text, callback)
    assert(type(text) == 'string', 'ECS percentage inverse requires text')

    if callback then
        assert(text == repaired, 'unexpected ECS_STAT_PCT evaluate body')
        return old
    end

    if text:find('local ECSLabels=', 1, true) then
        text = dofile('tests/fixtures/restore_ecs_summary_literals.lua')(text)
    end

    local from, to =
        'evaluate = function(value, cache)' .. repaired .. 'end,', 'evaluate = function(value, cache)' .. old .. 'end,'

    local first, last = text:find(from, 1, true)
    assert(first and not text:find(from, last + 1, true), 'missing or duplicate ECS_STAT_PCT evaluate')
    return text:sub(1, first - 1) .. to .. text:sub(last + 1)
end

return inverse, old, repaired
