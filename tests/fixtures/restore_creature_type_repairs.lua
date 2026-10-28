-- Strict test-only inverse of the sole CREATURE identity repair from e3fb19e.
local oldBody = "\
        local observed,reason=Functions.cache.getCached(cache, addon.Platform.GetUnitMetadataObservation, addon.Platform, value.unit, \"creature\")\
        if observed==nil then return nil,reason end\
        if observed==false then return false end\
        return observed == addon.creatures[value.value]\
    "

local newBody = "\
        return addon:GetConditionCreatureTypeMatch(value.unit,value.value,cache)\
    "

local oldBindings = {
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
    ["Functions.collections.deepcopy"] = "builtin:Functions/collections.lua:deepcopy",
    ["Functions.collections.keys"] = "builtin:Functions/collections.lua:keys",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.playerize"] = "builtin:utils.lua:playerize",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["color"] = "builtin:Conditions/character.lua:color",
    ["helpers"] = "builtin:Conditions/character.lua:helpers",
}

local oldParameters = { [1] = "value", [2] = "cache" }

local function hash(text)
    local n = 5381

    for i = 1, #text do
        n = (n * 33 + text:byte(i)) % 4294967296
    end

    return string.format('%08x', n)
end

local function restore(text, callback)
    assert(type(text) == 'string', 'expected complete source text')

    if callback then
        assert(text == newBody, 'unexpected complete CREATURE evaluator')
        return oldBody, oldBody, newBody, oldBindings, oldParameters
    end

    if text:find('GetUnitGroupMembership', 1, true) then
        text = dofile('tests/fixtures/restore_group_unit_membership.lua')(text, 'Conditions/character.lua')
    end

    local header = '    evaluate = function(value, cache)'
    local from, to = header .. newBody .. 'end,', header .. oldBody .. 'end,'
    local first, last = text:find(from, 1, true)
    assert(first and not text:find(from, last + 1, true), 'missing or duplicate complete CREATURE evaluator')
    local restored = text:sub(1, first - 1) .. to .. text:sub(last + 1)

    assert(
        #restored == 36302 and hash(restored) == '380362d6',
        'unrelated Character source change beyond CREATURE identity'
    )

    return restored, oldBody, newBody, oldBindings, oldParameters
end

return restore, oldBody, newBody, oldBindings, oldParameters
