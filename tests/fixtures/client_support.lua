-- Restricted clients run complete rotations like any other; a Built In that
-- uses a condition the restricted policy keeps secret is incomplete, so it is
-- listed but never eligible. Every shipped Retail and Forever premade uses
-- only conditions its client can read (S.complete). Premade fixtures model the client's policy but
-- not every native, so tests install the real support declarations and judge
-- a row by its policy diagnostics (a fixture-only missing native is noise).
local S = {}
-- options.stubNatives models the universal natives every real client has
-- (fixtures omit most): each declared API name that is absent becomes a stub.
-- Client-specific namespaces stay as the fixture has them.
local clientSpecific = { C_Engraving = true, C_AssistedCombat = true }

local function stub(env, path)
    local node = env
    local parts = {}

    for part in path:gmatch('[^.]+') do
        parts[#parts + 1] = part
    end

    if clientSpecific[parts[1]] then
        return
    end

    for i = 1, #parts - 1 do
        if node[parts[i]] == nil then
            node[parts[i]] = {}
        end

        node = node[parts[i]]

        if type(node) ~= 'table' then
            return
        end
    end

    local last = parts[#parts]

    if node[last] == nil then
        node[last] = (path == 'Enum.PowerType' or path == 'bit') and {} or function() end
    end
end

function S.install(f, options)
    local a = f.addon

    if type(a.Platform.GetTalentLayout) ~= 'function' then
        f.load('Platform/talents.lua')
    end
    if type(a.GetConditionSupport) ~= 'function' then
        f.load('Core/condition_support.lua')
    end

    if options and options.stubNatives then
        for _, list in pairs(a.conditionRequirements) do
            for _, requirement in ipairs(list) do
                if type(requirement) == 'table' then
                    local present = false

                    for _, path in ipairs(requirement) do
                        local node = f.env

                        for part in path:gmatch('[^.]+') do
                            node = type(node) == 'table' and node[part] or nil
                        end

                        if node ~= nil then
                            present = true
                        end
                    end

                    if not present then
                        stub(f.env, requirement[1])
                    end
                end
            end
        end
    end

    -- Validation results are cached by stamp; installing changes what they are.
    a.conditionRegistryVersion = (a.conditionRegistryVersion or 0) + 1
    return a
end

local secret = {
    ['unsupported-policy'] = true,
    ['combat-log-unavailable'] = true,
    ['secret-health'] = true,
    ['secret-power'] = true,
}

function S.incomplete(row, label)
    label = label or tostring(row and row.id)

    assert(
        row and not row.eligible and row.eligibilityReason == 'invalid-or-unsupported',
        label .. ' ' .. tostring(row and row.eligibilityReason)
    )

    for _, d in ipairs(row.validation and row.validation.diagnostics or {}) do
        if d.code == 'unsupported-condition' and secret[d.reason] then
            return d
        end
    end

    error(label .. ' is incomplete without a restricted-policy condition')
end

-- A shipped premade on its real client: no unsupported condition at all, and
-- eligible unless it ships disabled.
function S.complete(row, label)
    label = label or tostring(row and row.id)
    assert(row, label .. ' not listed')

    for _, d in ipairs(row.validation and row.validation.diagnostics or {}) do
        assert(
            d.code ~= 'unsupported-condition',
            label .. ' uses ' .. tostring(d.condition) .. ' (' .. tostring(d.reason) .. ')'
        )
    end

    if row.eligibilityReason == 'disabled' then
        assert(not row.eligible, label)
        return 'disabled'
    end

    assert(row.eligible, label .. ' not eligible: ' .. tostring(row.eligibilityReason))
    return 'eligible'
end

return S
