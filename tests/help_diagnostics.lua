-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function setup(custom)
    local h = assert(io.open('tests/condition_subject_help.lua'))
    local s = h:read('*a')
    h:close()
    local pre = assert(s:match('^(.-)\ntest%('))

    local f, a, e, shell, card, count, definition = assert(loadstring(
        pre .. '\nreturn setup({custom=' .. tostring(custom) .. '})',
        '@help-diagnostics-fixture'
    ))()

    f.load('Diagnostics/errors.lua')
    e.debugstack = function() return debug.traceback('', 2) end
    e.geterrorhandler = function() return function() end end
    return f, a, e, shell, card, count, definition
end

local function reports(a)
    local values = a.Diagnostics:GetReports()
    assert(#values > 0, 'Help error was not recorded')
    return values
end

local function omitted(report, sentinel)
    assert(not report.message:find(sentinel, 1, true), 'custom Help text escaped default diagnostic redaction')
    assert(report.context.conditionTag == 'SUBJECT', 'registered identity metadata missing')
end

test('registered custom Help retains redaction while native Help retains ordinary diagnostic text', function()
    for _, custom in ipairs({ true, false }) do
        local _, a, e, _, card, _, definition = setup(custom)
        local sentinel = custom and 'CUSTOM_HELP_PRIVATE_SENTINEL' or 'NATIVE_HELP_SENTINEL'

        local help = assert(loadstring(
            'return function(parent) error("' .. sentinel .. '",0) end',
            '@registered-help-error'
        ))()

        setfenv(help, e)
        definition.help = help
        card.controls.help:Click()
        local values = reports(a)
        assert(#values == 1, 'Help failure reported more than once')

        if custom then
            omitted(values[1], sentinel)
        else
            assert(values[1].message:find(sentinel, 1, true), 'native Help error incorrectly hidden')
        end
    end
end)

test('reentrant custom and newer native Help use independent captured diagnostic metadata', function()
    local _, a, _, shell, card, _, definition = setup(true)

    definition.help = function()
        a.conditionDefinitions.SUBJECT = {
            description = 'New native subject',
            customCode = false,
            help = function()
                error('NEW_NATIVE_HELP_SENTINEL', 0)
            end,
        }

        a.conditionRegistryVersion = a.conditionRegistryVersion + 1
        shell:ShowSubjectHelp(card.model, function() return true end)
        error('OLD_CUSTOM_HELP_PRIVATE_SENTINEL', 0)
    end

    card.controls.help:Click()
    local values = reports(a)
    assert(#values == 2, 'nested Help errors not recorded independently')
    local native, custom

    for _, report in ipairs(values) do
        if report.message:find('NEW_NATIVE_HELP_SENTINEL', 1, true) then
            native = report
        else
            omitted(report, 'OLD_CUSTOM_HELP_PRIVATE_SENTINEL')
            custom = report
        end
    end

    assert(native and custom, 'request diagnostic metadata leaked across reentry')
end)

test('custom metadata lookup reentry cannot render stale Help or classify a newer native error as custom', function()
    local _, a, _, shell, card, count, definition = setup(true)
    definition.customCode = nil
    local entered = false

    setmetatable(definition, {
        __index = function(_, key)
            if key == 'customCode' then
                if not entered then
                    entered = true

                    a.conditionDefinitions.SUBJECT = {
                        description = 'Replacement',
                        customCode = false,
                        help = function()
                            error('REPLACEMENT_NATIVE_HELP_SENTINEL', 0)
                        end,
                    }

                    a.conditionRegistryVersion = a.conditionRegistryVersion + 1
                    shell:ShowSubjectHelp(card.model, function() return true end)
                end

                return true
            end
        end,
    })

    card.controls.help:Click()
    assert(entered, 'registered custom metadata was not consumed')
    assert(count.help == 0, 'stale registered Help ran')
    local values = reports(a)

    assert(
        #values == 1 and values[1].message:find('REPLACEMENT_NATIVE_HELP_SENTINEL', 1, true),
        'stale metadata contaminated newer Help'
    )
end)

finish()
