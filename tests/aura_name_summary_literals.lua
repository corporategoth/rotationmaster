local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local prefix = assert(read('tests/aura_namespaces.lua'):match('^(.-)\ntest%('))
local fixture = assert(loadstring(prefix .. '\nreturn fixture'))()
local tags = { 'BUFF', 'BUFF_REMAIN', 'BUFF_STACKS', 'DEBUFF', 'DEBUFF_REMAIN', 'DEBUFF_STACKS' }

local hashes = {
    BUFF = '905a09e4',
    BUFF_REMAIN = '7453d12e',
    BUFF_STACKS = '9d8e21b3',
    DEBUFF = '165f1e84',
    DEBUFF_REMAIN = 'b439491e',
    DEBUFF_STACKS = '3e4b3d90',
}

local literal = 'Shield {{!blue|red}} 50% {aura}'

local function node(tag, spell)
    return {
        type = tag,
        unit = 'player',
        spell = spell,
        operator = 'LESSTHAN',
        value = 4,
        ownbuff = true,
        owndebuff = true,
    }
end

local function mode(tag)
    return tag:find('STACKS', 1, true) and 'stacks' or tag:find('REMAIN', 1, true) and 'remaining' or 'present'
end

local function setup(modern)
    local f, a, s = fixture(modern ~= false)
    s.metadata = false

    local record = {
        name = literal,
        spellId = 10,
        sourceUnit = 'player',
        applications = 2,
        duration = 30,
        expirationTime = 103,
    }

    s.records.HELPFUL = { record }
    s.records.HARMFUL = { record }
    return f, a, s
end

local function mount(a, id, source)
    a:RegisterCondition(id, assert(a:CompileCustomCondition(id, source)))
end

local function text(a, v)
    local p = a:printCondition(v, 0)
    local n = a:printCondition({ type = 'NOT', value = v }, 0)
    assert(a:printCondition({ type = 'NOT', value = { type = 'NOT', value = v } }, 0) == p)
    return p, n
end

for _, tag in ipairs(tags) do
    test(tag .. ' keeps raw saved-name fallback opaque in actual built-in and current copied source', function()
        for _, modern in ipairs({ false, true }) do
            local _, a = setup(modern)
            assert(a:SpellLabel(literal) == literal)
            local source = a:GetBuiltinConditionSource(tag)
            local before = a:CopySettingsData(source)
            mount(a, 'COPY', source)

            for _, id in ipairs({ tag, 'COPY' }) do
                local v = node(id, literal)
                assert(a:validateCondition(v, 0))
                assert(a:evaluateConditionResult(v).status == 'match')
                local data = a:CopySettingsData(v)
                local p, n = text(a, v)
                assert(p:find(literal, 1, true) and n:find(literal, 1, true), 'aura name reparsed: ' .. n)

                if mode(tag) == 'stacks' then
                    assert(n:find('is not less than 4', 1, true))
                else
                    assert(n:find('do not have', 1, true))

                    if mode(tag) == 'remaining' then
                        assert(n:find('is less than 4 seconds', 1, true) and not n:find('is not less than', 1, true))
                    end
                end

                assert(a:SettingsDataEqual(v, data))
            end

            assert(
                source.bindings[mode(tag) == 'present' and 'AuraLiteral.phrase' or 'AuraSummary.phrase']
                    == 'builtin:Functions/presentation.lua:phrase'
                    and not source.bindings.AuraSummary
                    and not source.bindings.AuraLiteral
            )

            assert((source.bindings['AuraSummary.predicate'] ~= nil) == (mode(tag) ~= 'present'))
            assert(a:SettingsDataEqual(source, before))
        end
    end)
end

local keys = {
    present = '{unit} {{!have|do not have}} {aura}',
    other = '{unit} {{!has|does not have}} {aura}',
    remaining = '{unit} {{!have|do not have}} {aura} where {remaining} {comparison} {duration}',
    remainingOther = '{unit} {{!has|does not have}} {aura} where {remaining} {comparison} {duration}',
    stacks = 'the number of stacks of {aura} on {unit} {comparison} {quantity}',
}

-- Wording these tags changed on purpose: the target REMAIN verb agrees ("has") and STACKS
-- reads "the number of stacks of X on Y"; their archived copies keep the old wording.
local reworded = { BUFF_REMAIN = true, DEBUFF_REMAIN = true, BUFF_STACKS = true, DEBUFF_STACKS = true }

test('whole translations reorder opaque names and secondary operators while keeping the actual primary NOT', function()
    for _, tag in ipairs(tags) do
        local f, a = setup()
        mount(a, 'COPY', a:GetBuiltinConditionSource(tag))
        local which = mode(tag)
        local L = f.libraries['AceLocale-3.0']:GetLocale('rotationmaster')
        L['your own %s'] = 'OWN[%s]'
        L['stacks of %s'] = 'STACKS[%s]'
        L['the remaining time'] = 'remaining-label'
        L['%s seconds'] = '%s sec'
        f.translations[keys.present] = '{aura} -> {unit}: {{!present|absent}}'
        f.translations[keys.other] = '{aura} -> {unit}: {{!present|absent}}'
        f.translations[keys.remaining] = '{comparison} {duration} {remaining} :: {aura} -> {unit}: {{!present|absent}}'
        f.translations[keys.remainingOther] = f.translations[keys.remaining]
        f.translations[keys.stacks] = '{quantity} :: STACKS[{aura}] -> {unit}: {comparison}'

        for _, id in ipairs({ tag, 'COPY' }) do
            local v = node(id, literal)
            local p, n = text(a, v)
            assert(p:find('OWN[' .. literal .. ']', 1, true) and n:find('OWN[' .. literal .. ']', 1, true))

            if which == 'stacks' then
                assert(n:find('is not less than', 1, true) and n:find('STACKS[OWN[', 1, true))
            else
                assert(n:find(': absent', 1, true))

                if which == 'remaining' then
                    assert(n:find('is less than 4 sec remaining-label', 1, true))
                end
            end
        end
    end
end)

test('current summaries preserve public AuraSpellLabel receiver args rank and live operator alias dispatch', function()
    for _, tag in ipairs(tags) do
        local f, a = setup()
        local v = node(tag, 10)
        v.anyrank = true
        local calls = 0
        local marker = 'Label {{!positive|negative}} %s'

        a.AuraSpellLabel = function(self, actual)
            assert(self == a and actual == v and actual.anyrank == true)
            calls = calls + 1
            return marker
        end

        a.operators.LESSTHAN = 'POS'
        a.negatedOperators.LESSTHAN = 'NEG'
        local p, n = text(a, v)
        assert(calls == 3 and p:find(marker, 1, true) and n:find(marker, 1, true))

        if mode(tag) == 'stacks' then
            assert(n:find(' NEG 4', 1, true))
        elseif mode(tag) == 'remaining' then
            assert(n:find(' POS 4 seconds', 1, true))
        end
    end
end)

-- Archive and exact inverse controls are appended after fail-first behavior.
test('native present absence and unavailable facts are independent of summary formatting', function()
    for _, tag in ipairs(tags) do
        local f, a, s = setup()
        mount(a, 'COPY', a:GetBuiltinConditionSource(tag))

        for _, id in ipairs({ tag, 'COPY' }) do
            local v = node(id, literal)
            assert(a:evaluateConditionResult(v).status == 'match')
            s.exists = false

            assert(
                a:evaluateConditionResult(v).status == 'no-match'
                    and a:evaluateConditionResult({ type = 'NOT', value = v }).status == 'match'
            )

            s.exists = true
            s.throw = true

            assert(
                a:evaluateConditionResult(v).status == 'unavailable'
                    and a:evaluateConditionResult({ type = 'NOT', value = v }).status == 'unavailable'
            )

            s.throw = nil
        end
    end
end)

test('existing bounded fallback does not change accepted long-name aura matching', function()
    for _, tag in ipairs(tags) do
        local _, a, s = setup()
        local name = string.rep('x', 64000)
        s.records.HELPFUL[1].name = name
        s.records.HARMFUL[1].name = name
        local v = node(tag, name)
        assert(a:validateCondition(v, 0) and a:evaluateConditionResult(v).status == 'match')
        local p, n = text(a, v)
        assert(p == 'Condition summary unavailable: invalid template or values.' and n == p)
    end
end)

local inverse, oldPrint, newPrint = dofile('tests/fixtures/restore_aura_name_summary_literals.lua')

local function archived(a, tag)
    local source = inverse(a:GetBuiltinConditionSource(tag), tag, 'export')
    assert(a:FunctionSourceHash(source) == hashes[tag])
    return source
end

test(
    'ordinary current wording and localized fragments preserve complete archived semantics across units ownership ranks and metadata',
    function()
        for _, modern in ipairs({ false, true }) do
            for _, tag in ipairs(tags) do
                local f, a, s = setup(modern)
                mount(a, 'ARCHIVED', archived(a, tag))
                s.metadata = true
                f.translations['your own %s'] = 'OWN[%s]'
                f.translations['stacks of %s'] = 'STACK[%s]'
                f.translations['the remaining time'] = 'remaining-label'
                f.translations['%s seconds'] = '%s sec'

                for _, unit in ipairs({ 'player', 'target', 'focus' }) do
                    for _, own in ipairs({ false, true }) do
                        for _, rank in ipairs({ false, true }) do
                            for _, spell in ipairs({ 10, 'Shield' }) do
                                local v = node(tag, spell)
                                v.unit = unit
                                v.ownbuff = own
                                v.owndebuff = own
                                v.anyrank = rank
                                local raw = a:CopySettingsData(v)
                                raw.type = 'ARCHIVED'
                                local p, n = text(a, v)
                                local pp, nn = text(a, raw)

                                assert(
                                    reworded[tag] or (p == pp and n == nn),
                                    tag .. ' changed ordinary/local fragment wording'
                                )
                            end
                        end
                    end
                end

                local v = node(tag)
                local raw = node('ARCHIVED')
                local p, n = text(a, v)
                local pp, nn = text(a, raw)
                assert(reworded[tag] or (p == pp and n == nn))
            end
        end
    end
)

test('raw archived complete sources preserve original marker parsing and stored source identity', function()
    for _, tag in ipairs(tags) do
        local _, a = setup()
        local source = archived(a, tag)
        local before = a:CopySettingsData(source)
        a.db.global.custom_conditions = { ARCHIVED = source }
        mount(a, 'ARCHIVED', source)
        local p, n = text(a, node('ARCHIVED', literal))
        assert(not p:find(literal, 1, true) and not n:find(literal, 1, true))

        if mode(tag) == 'stacks' then
            assert(n:find('Shield red', 1, true) and n:find('is less than 4', 1, true))
        end

        assert(a:SettingsDataEqual(source, before) and a.db.global.custom_conditions.ARCHIVED == source)
    end
end)

test(
    'old and current summaries make equal metadata queries preserve live nullable aliases and never observe gameplay auras',
    function()
        for _, tag in ipairs(tags) do
            local _, a, s = setup()
            mount(a, 'ARCHIVED', archived(a, tag))
            s.metadata = true
            local v = node(tag, 10)
            local raw = a:CopySettingsData(v)
            raw.type = 'ARCHIVED'
            a.operators.LESSTHAN = 'POS'
            a.negatedOperators.LESSTHAN = 'NEG'
            local nullable = a.nullable

            a.nullable = function(value, default)
                if value == 'POS' then
                    return 'ALIAS_POS'
                end

                return nullable(value, default)
            end

            s.spellReads = 0
            local p, n = text(a, v)
            local count = s.spellReads
            s.spellReads = 0
            local pp, nn = text(a, raw)
            assert((reworded[tag] or (p == pp and n == nn)) and s.spellReads == count and s.calls == 0)

            if mode(tag) ~= 'present' then
                assert(p:find('ALIAS_POS', 1, true))
            end
        end
    end
)

finish()
