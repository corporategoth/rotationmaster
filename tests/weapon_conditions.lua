-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(...)
    local f = F.new(...)
    f.load('Core/conditions.lua')
    f.load('Conditions/common.lua')
    f.load('Conditions/weapon.lua')
    f.load('Conditions/misc.lua')
    f.env.UnitCastingInfo = function() end
    f.env.UnitChannelInfo = function() end
    return f, f.addon
end

local function node(kind, offhand, value)
    return { type = kind, offhand = offhand, operator = 'EQUALS', value = value }
end

test('weapon enchant predicates select only their requested hand for every presence combination', function()
    local f, a = fixture()

    for _, main in ipairs({ false, true }) do
        for _, off in ipairs({ false, true }) do
            f.env.GetWeaponEnchantInfo = function() return main, 12000, 4, 1, off, 3000, 2, 2 end

            for _, selected in ipairs({ false, true }) do
                local expected = main

                if selected then
                    expected = off
                end

                for _, kind in ipairs({ 'WEAPON', 'WEAPON_REMAIN', 'WEAPON_STACKS' }) do
                    local amount = kind == 'WEAPON_REMAIN' and (selected and 3 or 12) or (selected and 2 or 4)

                    assert(
                        a:evaluateCondition(node(kind, selected, amount)) == expected,
                        kind .. ' consulted the other hand'
                    )
                end
            end
        end
    end
end)

test('offhand swing remainder uses its own history even before any mainhand swing', function()
    local f, a = fixture()
    f.env.GetTime = function() return 100 end
    f.env.UnitAttackSpeed = function() return 3, 2 end
    a.lastMainSwing = nil
    a.lastOffSwing = 99
    assert(a:evaluateCondition(node('SWING_TIME_REMAIN', true, 1)), 'offhand ignored its own swing history')
    a.lastMainSwing = 99
    a.lastOffSwing = nil
    assert(a:evaluateCondition(node('SWING_TIME_REMAIN', false, 2)), 'mainhand consulted missing offhand history')
end)

test('selected missing or restricted weapon observations remain unavailable under NOT', function()
    local f, a = fixture()
    local opaque = {}
    a.Platform.CanReadValue = function(_, value) return value ~= opaque end
    f.env.GetWeaponEnchantInfo = function() return true, 12000, 4, 1, opaque, 3000, 2, 2 end

    assert(
        a:evaluateConditionResult({ type = 'NOT', value = node('WEAPON', true, 0) }).status == 'unavailable',
        'restricted enchant became a boolean'
    )

    f.env.GetWeaponEnchantInfo = function() return true, 12000, 4, 1, true, opaque, 2, 2 end

    assert(
        a:evaluateConditionResult({ type = 'NOT', value = node('WEAPON_REMAIN', true, 0) }).status == 'unavailable',
        'restricted duration became a comparison'
    )

    f.env.GetWeaponEnchantInfo = function() return true, 12000, 4, 1, true, 3000, opaque, 2 end

    assert(
        a:evaluateConditionResult({ type = 'NOT', value = node('WEAPON_STACKS', true, 0) }).status == 'unavailable',
        'restricted charges became a comparison'
    )

    f.env.UnitAttackSpeed = function() return 3, nil end

    -- No off-hand weapon is a reading: off-hand checks are false, so NOT matches
    -- (a fallback to the main hand's 3 seconds would not).
    for _, kind in ipairs({ 'SWING_TIME', 'SWING_TIME_REMAIN' }) do
        assert(
            a:evaluateConditionResult({ type = 'NOT', value = node(kind, true, 0) }).status == 'match',
            'missing offhand speed fell back to mainhand'
        )
    end

    f.env.UnitAttackSpeed = function() return 3, opaque end

    for _, kind in ipairs({ 'SWING_TIME', 'SWING_TIME_REMAIN' }) do
        assert(
            a:evaluateConditionResult({ type = 'NOT', value = node(kind, true, 0) }).status == 'unavailable',
            'restricted offhand speed became a comparison'
        )
    end

    f.env.GetWeaponEnchantInfo = function()
        error('failed observation')
    end

    assert(
        a:evaluateConditionResult({ type = 'NOT', value = node('WEAPON', false, 0) }).status == 'unavailable',
        'failed observation escaped unavailable'
    )
end)

test('PvP player summary chooses the same unit as validation and fields', function()
    local _, a = fixture()
    local text = a.conditionDefinitions.PVP.print(0, { unit = 'player' })
    assert(text:find('you are PVP flagged', 1, true), 'player summary used third-person grammar')
end)

local function sourceFixture(...)
    local f, a = fixture(...)
    f.load('Data/builtin_sources.lua')
    f.load('Core/builtin_sources.lua')
    f.load('Core/custom_authoring.lua')
    f.load('Core/function_data.lua')

    f.env.loadstring = function(text, name)
        local fn, why = loadstring(text, name)

        if fn then
            setfenv(fn, f.env)
        end

        return fn, why
    end

    return f, a
end

test(
    'weapon authored comparison callbacks declare canonical private dependencies without changing local observation helpers',
    function()
        local _, a = sourceFixture()

        for _, tag in ipairs({ 'WEAPON_REMAIN', 'WEAPON_STACKS', 'SWING_TIME', 'SWING_TIME_REMAIN' }) do
            local source = assert(a:GetBuiltinConditionSource(tag))

            assert(
                source.valid:find('Functions.values.isin', 1, true) and source.evaluate:find(
                    'Functions.values.compare',
                    1,
                    true
                ),
                tag .. ' still uses legacy comparison calls'
            )

            assert(
                source.print:find('Functions.presentation.compareString', 1, true) and source.print:find(
                    'Functions.presentation.nullable',
                    1,
                    true
                ),
                tag .. ' still uses legacy presentation calls'
            )

            assert(
                source.bindings['Functions.values.compare'] == 'builtin:utils.lua:compare'
                    and source.bindings['Functions.values.isin'] == 'builtin:utils.lua:isin'
            )

            assert(
                source.bindings['Functions.presentation.compareString'] == 'builtin:utils.lua:compareString'
                    and source.bindings['Functions.presentation.nullable'] == 'builtin:utils.lua:nullable'
            )

            assert(source.bindings['Functions.cache.getCached'] == 'builtin:utils.lua:getCached')
            assert(source.bindings.Functions == nil, 'namespace became an opaque captured table')
        end

        -- swingSpeed changed on purpose: with no off-hand weapon the check reads false (994be32a), and it reads the ranged weapon when the condition says so.
        for name, hash in pairs({
            enchantObservation = '5abf63f3',
            numericObservation = '02dee6a9',
            swingSpeed = 'cf9027ac',
        }) do
            local id = 'builtin:Conditions/weapon.lua:' .. name
            local record = assert(a.builtinFunctions[id])

            assert(
                a:FunctionSourceHash(record.source) == hash,
                'native observation helper changed during pure-call migration'
            )

            assert(
                a:ResolveFunctionBinding(id) == a.builtinSourceModules['Conditions/weapon.lua'](name),
                'legacy observation getter identity changed'
            )
        end
    end
)

test(
    'registered weapon clones preserve selected-hand outcomes negation summaries and client registration boundaries',
    function()
        local tags = { 'WEAPON', 'WEAPON_REMAIN', 'WEAPON_STACKS', 'SWING_TIME', 'SWING_TIME_REMAIN' }

        local summaries = {
            WEAPON = 'Your off hand weapon is enchanted',
            WEAPON_REMAIN = 'the time remaining on your off hand weapon buff is equal to 2 seconds',
            WEAPON_STACKS = 'the number of stacks of your off hand weapon buff is equal to 2',
            SWING_TIME = 'Your off hand weapon attack speed is equal to 2 seconds',
            SWING_TIME_REMAIN = 'Your off hand weapon swing time remaining is equal to 2 seconds',
        }

        for _, case in ipairs(dofile('tests/fixtures/catalog_inventory.lua').branches) do
            local f, a = sourceFixture(unpack(case[1]))
            f.env.UnitAttackSpeed = function() return 3, 2 end
            a.lastMainSwing = 98
            a.lastOffSwing = 99

            for _, tag in ipairs(tags) do
                local definition = a.conditionDefinitions[tag]

                if tag:find('WEAPON', 1, true) then
                    assert(definition ~= nil, 'weapon enchant conditions are registered on every client')
                end

                if definition then
                    local source = assert(a:GetBuiltinConditionSource(tag))
                    local copy = assert(a:CompileCustomCondition('COPY_' .. tag, source))
                    a:RegisterCondition('COPY_' .. tag, copy)
                    local printed = node(tag, true, 2)

                    assert(
                        definition.print(0, printed) == summaries[tag] and copy.print(0, printed) == summaries[tag],
                        tag .. ' summary changed'
                    )

                    assert(
                        copy.print(0, printed, true) == definition.print(0, printed, true),
                        tag .. ' negated summary changed'
                    )

                    for _, main in ipairs({ false, true }) do
                        for _, off in ipairs({ false, true }) do
                            f.env.GetWeaponEnchantInfo = function() return main, 12000, 4, 1, off, 3000, 2, 2 end

                            for _, selected in ipairs({ false, true }) do
                                local amount = tag == 'WEAPON_REMAIN' and (selected and 3 or 12)
                                    or tag == 'WEAPON_STACKS' and (selected and 2 or 4)
                                    or tag == 'SWING_TIME_REMAIN' and 1
                                    or 2

                                local original = node(tag, selected, amount)
                                local duplicate = node('COPY_' .. tag, selected, amount)

                                assert(
                                    copy.valid(0, duplicate) == definition.valid(0, original),
                                    tag .. ' validator changed'
                                )

                                for _, negated in ipairs({ false, true }) do
                                    local left = negated and { type = 'NOT', value = original } or original
                                    local right = negated and { type = 'NOT', value = duplicate } or duplicate

                                    assert(
                                        a:evaluateConditionResult(left).status
                                            == a:evaluateConditionResult(right).status,
                                        tag .. ' clone observation/negation changed'
                                    )
                                end
                            end
                        end
                    end
                end
            end

            assert(not f.env.Functions and not f.env.functions, 'weapon clone leaked namespace globals')
        end
    end
)

test(
    'weapon clones keep failed restricted and missing observations unavailable with the same raw cached APIs',
    function()
        local f, a = sourceFixture()
        local opaque = {}
        a.Platform.CanReadValue = function(_, value) return value ~= opaque end

        for _, tag in ipairs({ 'WEAPON', 'WEAPON_REMAIN', 'WEAPON_STACKS', 'SWING_TIME', 'SWING_TIME_REMAIN' }) do
            local copy = assert(a:CompileCustomCondition('COPY_' .. tag, assert(a:GetBuiltinConditionSource(tag))))
            a:RegisterCondition('COPY_' .. tag, copy)

            for _, mode in ipairs({ 'failed', 'restricted', 'missing', 'absent' }) do
                f.env.GetWeaponEnchantInfo = function()
                    if mode == 'failed' then
                        error('blocked')
                    end

                    if mode == 'restricted' then
                        return opaque, nil, nil, nil, opaque
                    end

                    return nil
                end

                f.env.UnitAttackSpeed = function()
                    if mode == 'failed' then
                        error('blocked')
                    end

                    if mode == 'restricted' then
                        return opaque, opaque
                    end
                end

                if mode == 'absent' then
                    f.env.GetWeaponEnchantInfo = nil
                    f.env.UnitAttackSpeed = nil
                end

                local result = a:evaluateConditionResult({ type = 'NOT', value = node(tag, false, 0) })
                local clone = a:evaluateConditionResult({ type = 'NOT', value = node('COPY_' .. tag, false, 0) })

                assert(
                    result.status == clone.status and result.reason == clone.reason,
                    tag .. ' changed availability reason'
                )

                if not (mode == 'missing' and tag:find('WEAPON', 1, true)) then
                    assert(clone.status == 'unavailable', tag .. ' authorized action from unknown data')
                end
            end
        end

        local calls = 0

        f.env.GetWeaponEnchantInfo = function()
            calls = calls + 1
            return true, 12000, 4, 1, true, 3000, 2, 2
        end

        assert(
            a:evaluateCondition({
                type = 'AND',
                value = { node('WEAPON_REMAIN', false, 12), node('COPY_WEAPON_REMAIN', true, 3) },
            }) and calls == 1,
            'canonical calls changed cached native observation reuse'
        )
    end
)

finish()
