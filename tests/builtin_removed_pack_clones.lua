-- Profiles saved before the TBC Warrior/Rogue/Hunter rewrite keep working: clones of removed
-- Built In packs are independent copies, so they load, edit, export, run and auto-select as
-- before; their origins and enable preferences for removed IDs are inert, never errors.
local M = dofile('tests/fixtures/tbc_physical_premades.lua')
local test, finish = M.F.suite()
local saved = dofile('tests/fixtures/removed_builtin_clones.lua')

local function copy(v)
    if type(v) ~= 'table' then
        return v
    end

    local out = {}

    for k, x in pairs(v) do
        out[k] = copy(x)
    end

    return out
end

local function same(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= 'table' then
        return a == b
    end

    for k, v in pairs(a) do
        if not same(v, b[k]) then
            return false
        end
    end

    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end

    return true
end

local new = {
    WARRIOR = {
        'rm.tbc.warrior.dps.wowsims',
        'rm.tbc.warrior.dps.icyveins',
        'rm.tbc.warrior.protection.wowhead',
        'rm.tbc.warrior.protection.icyveins',
    },
    ROGUE = { 'rm.tbc.rogue.dps.wowsims', 'rm.tbc.rogue.dps.wowhead' },
    HUNTER = { 'rm.tbc.hunter.ranged.wowsims', 'rm.tbc.hunter.ranged.wowhead' },
}

-- Same-switch alternatives of the recommended premades ship disabled.
local off = {
    ['rm.tbc.warrior.dps.icyveins'] = true,
    ['rm.tbc.warrior.protection.icyveins'] = true,
    ['rm.tbc.rogue.dps.wowhead'] = true,
    ['rm.tbc.hunter.ranged.wowhead'] = true,
}

-- The clone of each class's 40–49 (Rogue 30–39) pack, and a level inside its saved bracket.
local bracket = {
    WARRIOR = { 45, 'rm.tbc.warrior.starter.40-49', 78 },
    ROGUE = { 35, 'rm.tbc.rogue.starter.30-39', 1752 },
    HUNTER = { 45, 'rm.tbc.hunter.starter.40-49', 75 },
}

local function load(class, level)
    local p = copy(saved[class])

    local f, s = M.fixture(class, {
        level = level,
        profile = { rotations = p.rotations, itemsets = {}, rotationLibrary = p.rotationLibrary },
    })

    f.load('Core/imports.lua')
    M.know(s, 6603, 78, 1752, 2098, 75)
    s.range[6603] = class ~= 'HUNTER'
    s.power = class == 'WARRIOR' and 20 or 100
    return f, s, p
end

for _, class in ipairs({ 'WARRIOR', 'ROGUE', 'HUNTER' }) do
    test(class .. ': saved clones of removed packs load unchanged and stay editable and exportable', function()
        local f, s, p = load(class, bracket[class][1])
        local a = f.addon
        local listed = {}

        for _, r in ipairs(a:ListDefaultRotations(0)) do
            listed[r.id] = r
        end

        for _, id in ipairs(new[class]) do
            assert(listed[id] and listed[id].enabled == not off[id], id .. ' not listed, or enabled state wrong')
        end

        for id in pairs(p.rotationLibrary.preferences) do
            assert(not listed[id] and a:GetDefaultRotation(id) == nil, id .. ' still shipped')
        end

        for _, id in ipairs(p.clones) do
            local body = assert(a:GetEditableRotation(0, id), 'clone ' .. id .. ' lost')
            assert(same(body, saved[class].rotations[0][id]), 'clone body changed on load')
            local exported = assert(a:GetRotationExportData(0, id))
            assert(a.RotationData.ValidateEnvelope(exported).valid)
            local view = assert(a:GetSourcedRotationView(0, id))
            assert(view.lineage.sourceKind == 'builtin' and not a:GetDefaultRotation(view.lineage.sourceId))
            local comparison, why = a:BuildRotationComparison(0, id, { kind = 'builtin', id = view.lineage.sourceId })
            assert(comparison == nil and why == 'unknown-rotation')
        end

        assert(same(a.db.profile.rotationLibrary.origins, saved[class].rotationLibrary.origins), 'origins rewritten')
    end)

    test(class .. ': a matching clone still runs and competes with the new premades on priority', function()
        local f, s, p = load(class, bracket[class][1])
        local a = f.addon
        local clone

        for _, id in ipairs(p.clones) do
            if a:GetSourcedRotationView(0, id).lineage.sourceId == bracket[class][2] then
                clone = id
            end
        end

        assert(clone and a:GetRuntimeRotation(0, clone), 'bracket clone is not runnable')
        local poll, selected = M.publisher(f, s)
        -- Your rotations and Built Ins compete on priority alone: the new premade's higher
        -- priority wins until the clone's priority is raised above it.
        poll()

        assert(
            selected() == new[class][1],
            class .. ' selected ' .. tostring(selected()) .. ' over the higher-priority premade'
        )

        a.db.profile.rotations[0][clone].priority = 100
        poll()
        assert(selected() == clone, class .. ' selected ' .. tostring(selected()) .. ' over a higher-priority clone')
        assert(f.addon.currentSpell == bracket[class][3], 'clone advice ' .. tostring(f.addon.currentSpell))
        -- Outside the clone's saved bracket the new premade takes over.
        s.level = 70
        poll()
        assert(selected() == new[class][1], 'level 70 selected ' .. tostring(selected()))
    end)
end

finish()
