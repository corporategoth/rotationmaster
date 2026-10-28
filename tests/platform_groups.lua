-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(project)
    local f = F.new(project)
    local s = { group = true, raid = false, calls = {} }

    f.env.IsInGroup = function(...)
        assert(select('#', ...) == 0)
        s.calls.group = (s.calls.group or 0) + 1

        if s.throw == 'group' then
            error('group failed')
        end

        return s.group
    end

    f.env.IsInRaid = function(...)
        assert(select('#', ...) == 0)
        s.calls.raid = (s.calls.raid or 0) + 1

        if s.throw == 'raid' then
            error('raid failed')
        end

        return s.raid
    end

    f.load('Platform/groups.lua')
    return f, f.addon.Platform, s
end

test('membership explicitly selects the requested API and retains known false without fallback', function()
    local _, p, s = fixture()
    assert(p:GetGroupMembership() == true and p:GetGroupMembership(false) == true and s.calls.group == 2)
    assert(p:GetGroupMembership(true) == false and s.calls.raid == 1 and s.calls.group == 2)
    s.group = false
    s.raid = true
    assert(p:GetGroupMembership(false) == false and p:GetGroupMembership(true) == true)
end)

test('public roster state remains readable on retail without an enemy combat policy gate', function()
    for _, project in ipairs({ 1, 2, 5, 11, 14, 19, 18 }) do
        local _, p, s = fixture(project)

        assert(
            p:GetGroupMembership(false) == true
                and p:GetGroupMembership(true) == false
                and s.calls.group == 1
                and s.calls.raid == 1
        )
    end
end)

test('invalid and unreadable queries do not invoke either native function', function()
    local f, p, s = fixture()
    local opaque = {}
    f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end

    for _, value in ipairs({ 0, 1, 'true', {}, opaque }) do
        assert(p:GetGroupMembership(value) == nil)
    end

    assert(next(s.calls) == nil)
end)

test('missing failed nil malformed and unreadable selected results stay unavailable', function()
    for _, raid in ipairs({ false, true }) do
        local f, p, s = fixture()
        local field = raid and 'raid' or 'group'
        local api = raid and 'IsInRaid' or 'IsInGroup'
        s[field] = nil
        local value, why = p:GetGroupMembership(raid)
        assert(value == nil and why == 'group-data-unavailable')
        s.throw = field
        value, why = p:GetGroupMembership(raid)
        assert(value == nil and why == 'api-error')
        s.throw = nil
        local opaque = {}
        f.env.canaccessvalue = function(v) return not rawequal(v, opaque) end
        s[field] = opaque
        value, why = p:GetGroupMembership(raid)
        assert(value == nil and why == 'restricted-value')

        for _, bad in ipairs({ 0, 1, 'false', {} }) do
            s[field] = bad
            value, why = p:GetGroupMembership(raid)
            assert(value == nil and why == 'invalid-api-result')
        end

        f.env[api] = nil
        value, why = p:GetGroupMembership(raid)
        assert(value == nil and why == 'missing-api')
        assert(not s.calls[raid and 'group' or 'raid'])
    end
end)

test('unknown clients never infer roster semantics from present globals', function()
    local _, p, s = fixture(999)
    local value, why = p:GetGroupMembership(true)
    assert(value == nil and why == 'unsupported-client' and next(s.calls) == nil)
end)

finish()
