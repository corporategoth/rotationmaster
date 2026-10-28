local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local function make(path)
    local prefix = assert(read(path):match('^(.-)\ntest%('))
    return assert(loadstring(prefix .. '\nreturn fixture'))()
end

local zoneFixture = make('tests/zone_text_conditions.lua')
local castFixture = make('tests/casting_conditions.lua')
local literal = 'Scout {{!blue|red}} 50% {name}'

local specs = {
    {
        tag = 'ZONE',
        path = 'Conditions/spatial.lua',
        field = 'value',
        key = '{{!in|not in}} {zone}',
        old = '\n        return string.format(L["{{!in|not in}} %s"], Functions.presentation.nullable(value.value, L["<zone>"]))\n    ',
        hash = '78667367',
    },
    {
        tag = 'CASTING_SPELL',
        path = 'Conditions/casting.lua',
        field = 'spell',
        key = '{unit} {{!are|are not}} currently casting {spell}',
        old = '\n        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!are|are not}} currently casting %s"], L["%s {{!is|is not}} currently casting %s"]),\n            Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]), Functions.presentation.nullable(value.spell, L["<spell>"]))\n    ',
        hash = '3fd663d5',
    },
    {
        tag = 'CHANNELING_SPELL',
        path = 'Conditions/channeling.lua',
        field = 'spell',
        key = '{unit} {{!are|are not}} currently channeling {spell}',
        old = '\n        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!are|are not}} currently channeling %s"], L["%s {{!is|is not}} currently casting %s"]),\n            Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]), Functions.presentation.nullable(value.spell, L["<spell>"]))\n    ',
        hash = '31ba8a04',
    },
}

local function setup(spec)
    local f, a, s = (spec.tag == 'ZONE' and zoneFixture or castFixture)()
    return f, a, s
end

local function node(spec, tag, value)
    local v = { type = tag or spec.tag, unit = 'player' }
    v[spec.field] = value
    return v
end

local function mount(a, tag, source)
    a:RegisterCondition(tag, assert(a:CompileCustomCondition(tag, source)))
end

local function rawSource(a, spec)
    local source = a:GetBuiltinConditionSource(spec.tag)
    source.print = spec.old
    source.bindings['LiteralSummary.phrase'] = nil
    return source
end

local function text(a, v)
    local positive = a:printCondition(v, 0)
    local negative = a:printCondition({ type = 'NOT', value = v }, 0)
    assert(a:printCondition({ type = 'NOT', value = { type = 'NOT', value = v } }, 0) == positive)
    return positive, negative
end

for _, spec in ipairs(specs) do
    test(spec.tag .. ' native built-in and current editable copies preserve accepted literal names', function()
        local _, a = setup(spec)
        local source = a:GetBuiltinConditionSource(spec.tag)
        local before = a:CopySettingsData(source)
        mount(a, 'COPY', source)

        for _, tag in ipairs({ spec.tag, 'COPY' }) do
            for _, name in ipairs({
                literal,
                '{{yes|no}} {{!one|two}}',
                '100% %s {unit} {zone}',
                '|cff123456{{!Hot|Cold}}|r',
                '|Hspell:1|h[{{!A|B}}]|h',
                '',
            }) do
                local v = node(spec, tag, name)
                assert(a:validateCondition(v, 0))
                local old = a:CopySettingsData(v)
                local p, n = text(a, v)
                assert(p:find(name, 1, true) and n:find(name, 1, true), 'literal changed ' .. p)
                assert(a:SettingsDataEqual(v, old))
            end
        end

        assert(
            source.bindings['LiteralSummary.phrase'] == 'builtin:Functions/presentation.lua:phrase'
                and not source.bindings.LiteralSummary
        )

        assert(a:SettingsDataEqual(source, before))
    end)

    test(spec.tag .. ' reordered whole translation keeps literal before primary negation', function()
        local f, a = setup(spec)
        mount(a, 'COPY', a:GetBuiltinConditionSource(spec.tag))

        f.translations[spec.key] = spec.tag == 'ZONE' and '{zone}: {{!inside|outside}} :: 50%'
            or '{spell} -> {unit}: {{!active|inactive}} :: 50%'

        for _, tag in ipairs({ spec.tag, 'COPY' }) do
            local p, n = text(a, node(spec, tag, literal))

            assert(
                p:find(literal, 1, true) and n:find(literal, 1, true) and p:find(' :: 50%', 1, true) and n:find(
                    ' :: 50%',
                    1,
                    true
                )
            )

            assert(
                n:find(spec.tag == 'ZONE' and ': outside' or ': inactive', 1, true),
                'name consumed primary NOT: ' .. n
            )
        end
    end)

    test(spec.tag .. ' ordinary nil placeholders units and subzone choices preserve old wording exactly', function()
        local _, a = setup(spec)
        mount(a, 'ARCHIVED', rawSource(a, spec))

        for _, unit in ipairs({ 'player', 'target', 'focus' }) do
            for _, name in ipairs({ 'Ordinary', '', 'Arcane Missiles' }) do
                for _, subzone in ipairs({ false, true }) do
                    local v = node(spec, nil, name)
                    v.unit = unit
                    v.subzone = subzone
                    local old = a:CopySettingsData(v)
                    old.type = 'ARCHIVED'
                    local p, n = text(a, v)
                    local pp, nn = text(a, old)

                    if spec.tag == 'CHANNELING_SPELL' and v.unit ~= 'player' then
                        pp = pp:gsub('currently casting', 'currently channeling')
                        nn = nn:gsub('currently casting', 'currently channeling')
                    end

                    assert(p == pp and n == nn)
                end
            end
        end

        local v = node(spec)
        local old = node(spec, 'ARCHIVED')
        local p, n = text(a, v)
        local pp, nn = text(a, old)

        if spec.tag == 'CHANNELING_SPELL' and v.unit ~= 'player' then
            pp = pp:gsub('currently casting', 'currently channeling')
            nn = nn:gsub('currently casting', 'currently channeling')
        end

        assert(p == pp and n == nn)
    end)
end

test(
    'all three archived complete exports retain source identity and historical token parsing without rewrites',
    function()
        for _, spec in ipairs(specs) do
            local _, a = setup(spec)
            local source = rawSource(a, spec)
            local before = a:CopySettingsData(source)
            a.db.global.custom_conditions = { ARCHIVED = source }
            mount(a, 'ARCHIVED', source)
            local p, n = text(a, node(spec, 'ARCHIVED', literal))
            assert(not p:find(literal, 1, true) and not n:find(literal, 1, true) and p:find('Scout blue', 1, true))
            assert(a:SettingsDataEqual(source, before) and a.db.global.custom_conditions.ARCHIVED == source)
        end
    end
)

test('all summaries remain query-free and do not write configured state', function()
    for _, spec in ipairs(specs) do
        local f, a, s = setup(spec)
        local v = node(spec, nil, literal)
        local before = a:CopySettingsData(v)

        for _, name in ipairs({
            'GetZoneText',
            'GetSubZoneText',
            'UnitExists',
            'UnitCastingInfo',
            'UnitChannelInfo',
        }) do
            f.env[name] = function()
                error('summary queried ' .. name)
            end
        end

        local p, n = text(a, v)
        assert(p:find(literal, 1, true) and n:find(literal, 1, true))
        assert(a:SettingsDataEqual(v, before))
    end
end)

test(
    'native facts retain exact match no-match unavailable and branch selection for built-ins and current copies',
    function()
        for _, spec in ipairs(specs) do
            local f, a, s = setup(spec)
            mount(a, 'COPY', a:GetBuiltinConditionSource(spec.tag))
            local exists = f.env.UnitExists

            for _, tag in ipairs({ spec.tag, 'COPY' }) do
                local v = node(spec, tag, literal)

                for _, case in ipairs({
                    { literal, 'match', 'yes' },
                    { 'Other', 'no-match', 'no' },
                    { false, 'unavailable' },
                }) do
                    if spec.tag == 'ZONE' then
                        s.zone = case[1] or nil
                    else
                        s.name = case[1] or nil
                        f.env.UnitExists = case[3] and exists or nil
                    end

                    assert(a:evaluateConditionResult(v).status == case[2])
                    local selected

                    local branch = {
                        rotation = {
                            {
                                id = 'guard',
                                type = 'branch',
                                conditions = v,
                                onTrue = { { id = 'yes', type = 'spell', action = 5143 } },
                                onFalse = { { id = 'no', type = 'spell', action = 5143 } },
                            },
                        },
                    }

                    local r = a:EvaluateRotationSequence(
                        branch,
                        function(n) return a:evaluateConditionResult(n) end,
                        function(n)
                            selected = n.id
                            return true
                        end
                    )

                    if case[2] == 'unavailable' then
                        assert(
                            r.status == 'unavailable'
                                and selected == nil
                                and a:evaluateConditionResult({ type = 'NOT', value = v }).status == 'unavailable'
                        )
                    else
                        assert(selected == case[3])
                    end
                end
            end
        end
    end
)

test('accepted oversized names use existing bounded fallback without changing native truth', function()
    for _, spec in ipairs(specs) do
        local _, a, s = setup(spec)
        local name = string.rep('x', 64000)
        local v = node(spec, nil, name)

        if spec.tag == 'ZONE' then
            s.zone = name
        else
            s.name = name
        end

        assert(a:validateCondition(v, 0) and a:evaluateConditionResult(v).status == 'match')
        local p, n = text(a, v)
        assert(p == 'Condition summary unavailable: invalid template or values.' and n == p)
    end
end)

finish()
