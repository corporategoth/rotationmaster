-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Blizzard Assisted Combat: the Platform reader contract, the
-- ASSISTED_SUGGESTION condition and the "Blizzard's suggestion" rotation step
-- on the real addon (TOC-order whole-poll fixture, TBC Shaman bars 403, 8042,
-- 324, 8017). C_AssistedCombat is modelled from Blizzard's generated API
-- documentation (Gethe/wow-ui-source live e7aa82019d).
local F = dofile('tests/fixtures/addon.lua')
local pass, fail = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)

    if ok then
        pass = pass + 1
        print('PASS ' .. name)
    else
        fail = fail + 1
        print('FAIL ' .. name .. ': ' .. tostring(err))
    end
end

local root = assert(io.popen('pwd'):read('*l'))

-- A modelled C_AssistedCombat. state.next is the suggestion GetNextCastSpell
-- returns; state.available/state.reason drive IsAvailable.
local function model(state)
    state.calls = state.calls or {}

    local function count(name)
        state.calls[name] = (state.calls[name] or 0) + 1
    end

    return {
        IsAvailable = function()
            count('IsAvailable')

            if state.availableError then
                error('blocked')
            end

            return state.available ~= false, state.reason or ''
        end,
        GetNextCastSpell = function(check)
            count('GetNextCastSpell')
            state.lastCheck = check

            if state.nextError then
                error('blocked')
            end

            return state.next
        end,
        GetRotationSpells = function()
            count('GetRotationSpells')
            return state.rotation or {}
        end,
        GetActionSpell = function()
            count('GetActionSpell')
            return state.action
        end,
    }
end

local function reader(product)
    local f = F.new(product or 1, 12, 'PALADIN')
    f.load('Platform/assisted_combat.lua')
    return f.addon.Platform, f.env, f
end

test('reader: a client without C_AssistedCombat (TBC/Era) reports missing-api everywhere, without errors', function()
    local p, e = reader(5)
    e.C_AssistedCombat = nil

    for _, name in ipairs({
        'GetAssistedSuggestion',
        'GetAssistedRotationSpells',
        'GetAssistedActionSpell',
        'GetAssistedCombatAvailability',
    }) do
        local value, why = p[name](p)
        assert(value == nil and why == 'missing-api', name .. ' ' .. tostring(value) .. ' ' .. tostring(why))
    end

    e.C_AssistedCombat = {}
    local value, why = p:GetAssistedSuggestion()
    assert(value == nil and why == 'missing-api', 'empty namespace')
    e.C_AssistedCombat = 'junk'
    value, why = p:GetAssistedSuggestion()
    assert(value == nil and why == 'missing-api', 'non-table namespace')
    assert(#p:GetAssistedSpellCandidates(nil) == 0)
end)

test('reader: suggestion, no suggestion, rotation set and action spell follow the documented contract', function()
    local p, e = reader()
    local state = { next = 85256, rotation = { 85256, 20271, 35395 }, action = 1229376 }
    e.C_AssistedCombat = model(state)

    assert(
        p:GetAssistedSuggestion() == 85256 and state.lastCheck == false,
        'suggestion not read with checkForVisibleButton=false'
    )

    local available, reason = p:GetAssistedCombatAvailability()
    assert(available == true and reason == nil)
    local spells = assert(p:GetAssistedRotationSpells())
    assert(#spells == 3 and spells[2] == 20271 and spells ~= state.rotation, 'rotation set not copied')
    assert(p:GetAssistedActionSpell() == 1229376)
    state.next = nil
    local value, why = p:GetAssistedSuggestion()
    assert(value == false and why == nil, 'no suggestion is not false')
    state.next = 0
    assert(p:GetAssistedSuggestion() == false, 'zero suggestion is not false')
    state.action = nil
    assert(p:GetAssistedActionSpell() == false)
    state.rotation = {}
    assert(#assert(p:GetAssistedRotationSpells()) == 0)
end)

test('reader: unavailable, failing, secret and malformed observations are reported, never guessed', function()
    local p, e = reader()
    local state = { next = 85256, available = false, reason = 'Not available for this specialization' }
    e.C_AssistedCombat = model(state)
    local value, why = p:GetAssistedSuggestion()
    assert(value == nil and why == 'assisted-unavailable', tostring(why))
    assert(state.calls.GetNextCastSpell == nil, 'suggestion read while Assisted Combat is unavailable')
    local available, reason = p:GetAssistedCombatAvailability()
    assert(available == false and reason == 'Not available for this specialization')
    state.available = true
    state.nextError = true
    value, why = p:GetAssistedSuggestion()
    assert(value == nil and why == 'api-error')
    state.nextError = nil
    state.availableError = true
    value, why = p:GetAssistedSuggestion()
    assert(value == nil and why == 'api-error', 'availability failure ignored')
    state.availableError = nil
    e.issecretvalue = function(v) return v == 85256 end
    value, why = p:GetAssistedSuggestion()
    assert(value == nil and why == 'restricted-value', 'secret suggestion: ' .. tostring(why))
    state.rotation = { 1, 85256 }
    value, why = p:GetAssistedRotationSpells()
    assert(value == nil and why == 'restricted-value')
    e.issecretvalue = function() return false end
    state.next = 'Templar\'s Verdict'
    value, why = p:GetAssistedSuggestion()
    assert(value == nil and why == 'invalid-api-result')
    state.next = 1.5
    value, why = p:GetAssistedSuggestion()
    assert(value == nil and why == 'invalid-api-result')
    -- IsAvailable absent: the suggestion alone is read.
    state.next = 85256
    e.C_AssistedCombat.IsAvailable = nil
    assert(p:GetAssistedSuggestion() == 85256)
end)

test('reader: override relations map the suggestion to its base and override spell', function()
    local p, e = reader()
    e.C_Spell = e.C_Spell or {}
    local base = { [427453] = 255937 }
    local over = { [255937] = 427453 }
    e.C_Spell.GetBaseSpell = function(id) return base[id] or id end
    e.C_Spell.GetOverrideSpell = function(id) return over[id] or id end
    local candidates = p:GetAssistedSpellCandidates(427453)
    assert(#candidates == 2 and candidates[1] == 427453 and candidates[2] == 255937, 'base not offered')
    candidates = p:GetAssistedSpellCandidates(255937)
    assert(#candidates == 2 and candidates[2] == 427453, 'override not offered')
    candidates = p:GetAssistedSpellCandidates(35395)
    assert(#candidates == 1, 'plain spell duplicated')
    assert(p:IsAssistedSpellMatch(255937, 427453) == true, 'override suggestion does not match its base spell')
    assert(p:IsAssistedSpellMatch(427453, 255937) == true, 'base suggestion does not match the override spell')
    assert(p:IsAssistedSpellMatch(35395, 427453) == false)
    e.C_Spell.GetBaseSpell = nil
    e.C_Spell.GetOverrideSpell = nil

    assert(
        #p:GetAssistedSpellCandidates(427453) == 1 and p:IsAssistedSpellMatch(35395, 427453) == false,
        'missing relation APIs'
    )
end)

local function condition(product)
    local f = F.new(product or 1, 12, 'PALADIN')
    f.load('Platform/spells.lua')
    f.load('Platform/assisted_combat.lua')
    f.load('Conditions/common.lua')
    f.load('Conditions/assisted.lua')

    f.env.C_Spell = {
        GetSpellInfo = function(id) return { spellID = id, name = 'Spell ' .. id, iconID = 1 } end,
        GetSpellLink = function(id) return 'spell:' .. id end,
    }

    return assert(f.addon.definitions.ASSISTED_SUGGESTION, 'condition not registered'), f.env, f.addon
end

test('condition: true, false and unavailable, with and without a chosen spell', function()
    local d, e = condition()
    local state = { next = 85256 }
    e.C_AssistedCombat = model(state)

    assert(
        d.valid(nil, {})
            and d.valid(nil, { spell = 85256 })
            and not d.valid(nil, { spell = -1 })
            and not d.valid(nil, { spell = 85256, ranked = 'yes' })
    )

    assert(d.evaluate({}, {}) == true, 'any suggestion')
    assert(d.evaluate({ spell = 85256 }, {}) == true, 'chosen suggestion')
    assert(d.evaluate({ spell = 20271 }, {}) == false, 'other spell')
    state.next = nil

    assert(
        d.evaluate({}, {}) == false and d.evaluate({ spell = 85256 }, {}) == false,
        'nothing suggested is a real false'
    )

    state.next = 85256
    e.issecretvalue = function(v) return v == 85256 end
    local value, why = d.evaluate({ spell = 85256 }, {})
    assert(value == nil and why == 'restricted-value', 'secret: ' .. tostring(why))
    value, why = d.evaluate({}, {})
    assert(value == nil and why == 'restricted-value')
    e.issecretvalue = function() return false end
    state.available = false
    value, why = d.evaluate({}, {})
    assert(value == nil and why == 'assisted-unavailable')
    e.C_AssistedCombat = nil
    value, why = d.evaluate({ spell = 85256 }, {})
    assert(value == nil and why == 'missing-api')
    assert(type(d.print(nil, {})) == 'string' and type(d.print(nil, { spell = 85256 })) == 'string')
end)

test('condition: overrides match the way Blizzard highlights them, and one poll reads once', function()
    local d, e = condition()
    local state = { next = 427453 }
    e.C_AssistedCombat = model(state)
    e.C_Spell = e.C_Spell or {}
    e.C_Spell.GetBaseSpell = function(id) return id == 427453 and 255937 or id end
    e.C_Spell.GetOverrideSpell = function(id) return id == 255937 and 427453 or id end
    assert(d.evaluate({ spell = 255937 }, {}) == true, 'base spell does not match its suggested override')
    state.calls.GetNextCastSpell = 0
    local cache = {}
    d.evaluate({ spell = 255937 }, cache)
    d.evaluate({ spell = 20271 }, cache)
    d.evaluate({}, cache)

    assert(
        state.calls.GetNextCastSpell == 1,
        'one evaluation cache read the suggestion more than once: ' .. state.calls.GetNextCastSpell
    )
end)

-- Whole-poll fixture: TBC Shaman with buttons for 403, 8042, 324 and 8017.
local function fixture(options)
    options = options or {}

    local c = assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('price', root, true, root, true)({
        target = true,
        combat = true,
        buttons = true,
        poll = .15,
        preview = options.preview,
    })

    local a, e = c.a, c.e
    c.load('Platform/assisted_combat.lua')
    local state = { next = 8042 }

    if options.api ~= false then
        e.C_AssistedCombat = model(state)
    end

    local added = {}

    if a.nextWindow then
        local window = a.nextWindow
        local add = window.AddRecommendation

        window.AddRecommendation = function(self, spell, ...)
            added[#added + 1] = spell
            return add(self, spell, ...)
        end
    end

    return c, a, e, state, added
end

local function custom(a, id, body)
    local reference = {
        kind = 'custom',
        address = { scope = 'class', class = 'SHAMAN', owner = 'SHAMAN', spec = 0, id = id },
    }

    assert(a:CommitRotationDraft(reference, nil, { body = body }, 'class'))
    return a:GetScopedRotationCoordinator():Key(reference)
end

local function assistedBody(name, extra)
    local rotation = { { id = 'blizzard', type = 'assisted', conditions = {} } }

    for _, step in ipairs(extra or {}) do
        rotation[#rotation + 1] = step
    end

    return { name = name, priority = 0, rotation = rotation, cooldowns = {} }
end

local function select(c, a, name)
    a:HandleCommand('set ' .. name)

    for _ = 1, 3 do
        c.tick()
    end
end

test('step: Blizzard\'s suggestion highlights the suggested spell\'s button and follows it every poll', function()
    local c, a, _, state = fixture()
    local key = custom(a, 'assisted', assistedBody('Assisted'))
    select(c, a, 'Assisted')
    assert(a.currentRotation == key, 'assisted rotation not selected')

    assert(
        a.currentSpell == 8042 and a:IsGlowing(8042),
        'suggested spell not highlighted: ' .. tostring(a.currentSpell)
    )

    local lean = a.leanStats.polls
    state.next = 403
    c.tick()
    assert(a.currentSpell == 403 and a:IsGlowing(403) and not a:IsGlowing(8042), 'a new suggestion was not followed')
    state.next = 324
    c.tick()
    c.tick()
    assert(a.currentSpell == 324, 'third suggestion ' .. tostring(a.currentSpell))
    assert(a.leanStats.polls > lean, 'the lean engine did not serve the assisted rotation')
    assert(state.lastCheck == false)
end)

test(
    'step: no suggestion, a suggestion not on the bars, or one that is not ready falls through to the next step',
    function()
        local c, a, _, state, _ = fixture()

        custom(a, 'fallthrough', assistedBody('Fallthrough', {
            { id = 'bolt', type = 'spell', action = 403, conditions = {} },
        }))

        select(c, a, 'Fallthrough')
        assert(a.currentSpell == 8042, 'suggestion ' .. tostring(a.currentSpell))
        state.next = nil
        c.tick()
        assert(a.currentSpell == 403, 'no suggestion did not fall through: ' .. tostring(a.currentSpell))
        state.next = 99999
        c.tick()
        assert(a.currentSpell == 403, 'unbound suggestion did not fall through')
        state.next = 8042
        c.tick()
        assert(a.currentSpell == 8042)
        c.setSpellReady(false)
        c.tick()
        assert(a.currentSpell ~= 8042, 'a cooling suggestion was recommended')
        c.setSpellReady(true)
        c.tick()
        assert(a.currentSpell == 8042, 'readiness did not recover')
        state.available = false
        c.tick()
        assert(a.currentSpell == 403, 'unavailable Assisted Combat did not fall through')
    end
)

test('step: an override suggestion highlights the button that holds its base spell', function()
    local c, a, e, state = fixture()
    local spell = e.C_Spell
    spell.GetBaseSpell = function(id) return id == 777001 and 8042 or id end
    spell.GetOverrideSpell = function(id) return id end
    custom(a, 'override', assistedBody('Override'))
    select(c, a, 'Override')
    state.next = 777001
    c.tick()
    c.tick()

    assert(
        a.currentSpell == 8042 and a:IsGlowing(8042),
        'override not mapped to its base button: ' .. tostring(a.currentSpell)
    )
end)

test('step: the standard engine resolves the suggestion the same way', function()
    local c, a, _, state = fixture()
    assert(a:SetEvaluationEngine('standard'))
    custom(a, 'standard', assistedBody('Standard', { { id = 'bolt', type = 'spell', action = 403, conditions = {} } }))
    select(c, a, 'Standard')
    assert(a:GetEvaluationEngine() == 'standard' and a.currentSpell == 8042)
    state.next = 324
    c.tick()
    assert(a.currentSpell == 324)
    state.next = nil
    c.tick()
    assert(a.currentSpell == 403)
    assert(a:SetEvaluationEngine('lean'))
end)

test('step: the suggestion shows in the preview window', function()
    local c, a, _, state, added = fixture({ preview = 3 })
    custom(a, 'preview', assistedBody('Preview', { { id = 'bolt', type = 'spell', action = 403, conditions = {} } }))
    select(c, a, 'Preview')

    for i = #added, 1, -1 do
        added[i] = nil
    end

    state.next = 324
    c.tick()
    assert(added[1] == 324 and added[2] == 403, 'preview rows: ' .. tostring(added[1]) .. ',' .. tostring(added[2]))
end)

test('step: TBC without C_AssistedCombat skips the step with no error, and the condition is unavailable', function()
    local c, a, e = fixture({ api = false })
    assert(e.C_AssistedCombat == nil)
    local value, why = a.Platform:GetAssistedSuggestion()
    assert(value == nil and why == 'missing-api')
    custom(a, 'tbc', assistedBody('TBC', { { id = 'bolt', type = 'spell', action = 403, conditions = {} } }))
    select(c, a, 'TBC')
    assert(a.currentSpell == 403, 'TBC advice ' .. tostring(a.currentSpell))
    assert(not a.adviceErrorReport and #a.Diagnostics:GetReports() == 0, 'assisted step raised an error on TBC')
    local result = a:evaluateConditionResult({ type = 'NOT', value = { type = 'ASSISTED_SUGGESTION' } })
    assert(result.status == 'unavailable', 'NOT of a missing API is ' .. tostring(result.status))
    result = a:evaluateConditionResult({ type = 'ASSISTED_SUGGESTION', spell = 8042 })
    assert(result.status == 'unavailable')
end)

test('step: a rotation gated on the condition, and the condition under NOT, use the same observation', function()
    local c, a, _, state = fixture()

    custom(a, 'gated', {
        name = 'Gated',
        priority = 0,
        cooldowns = {},
        rotation = {
            {
                id = 'shock',
                type = 'spell',
                action = 8042,
                conditions = { type = 'ASSISTED_SUGGESTION', spell = 8042 },
            },
            {
                id = 'bolt',
                type = 'spell',
                action = 403,
                conditions = { type = 'NOT', value = { type = 'ASSISTED_SUGGESTION' } },
            },
            { id = 'stop', type = 'stop', conditions = {} },
        },
    })

    select(c, a, 'Gated')
    assert(a.currentSpell == 8042, 'gated step ' .. tostring(a.currentSpell))
    state.next = nil
    c.tick()
    assert(a.currentSpell == 403, 'NOT with nothing suggested ' .. tostring(a.currentSpell))
    state.next = 324
    c.tick()
    assert(a.currentSpell == nil, 'other suggestion should stop: ' .. tostring(a.currentSpell))
end)

test('validation, export/import and clone accept the assisted step', function()
    local c, a = fixture()
    c.load('Data/diff.lua')
    c.load('Data/import_session.lua')
    c.load('Core/imports.lua')
    local data = a.RotationData
    local options = a:GetImportValidationOptions()
    local body = assistedBody('Portable', { { id = 'bolt', type = 'spell', action = 403, conditions = {} } })
    local result = data.ValidateBody(body, options)

    assert(
        result.valid and result.supported and result.executionStatus ~= 'unavailable',
        'assisted body rejected: ' .. (result.diagnostics[1] and result.diagnostics[1].code or '?')
    )

    local bad = data.CopyData(body)
    bad.rotation[1].action = 403
    result = data.ValidateBody(bad, options)
    assert(not result.supported and result.diagnostics[1].code == 'unexpected-assisted-action')
    bad = data.CopyData(body)
    bad.cooldowns = { { id = 'cd', type = 'assisted' } }
    result = data.ValidateBody(bad, options)

    assert(
        not result.supported and result.diagnostics[1].code == 'assisted-in-optional-list',
        'assisted cooldown accepted'
    )

    local key = custom(a, 'portable', body)
    c.tick()
    local exported = assert(a:GetRotationExportData(0, key))
    -- The binary transport (AceSerializer + LibCompress) needs the bit library,
    -- as in tests/rotation_codec.lua; plain Lua 5.1 imports the copied data.
    local codec, text

    if pcall(require, 'bit') then
        local codecData, deps = dofile('tests/fixtures/codec.lua')()
        codec = assert(codecData.NewCodec(deps))
        text = assert(codec:Encode(exported))
    else
        text = 'copied'

        codec = {
            Decode = function(_, value)
                assert(value == text)
                local copy = data.CopyData(exported)

                return {
                    kind = copy.format == 'RotationMaster' and 'envelope' or 'legacy',
                    original = value,
                    value = copy,
                }
            end,
        }
    end

    local decoded = assert(codec:Decode(text))
    local value = decoded.value.body or decoded.value
    assert(value.rotation[1].type == 'assisted' and value.rotation[1].action == nil, 'assisted step lost in transport')
    local session = data.NewImportSession(codec, options)
    local candidate = assert(session:Stage(text))
    local imported = assert(a:ApplyRotationImport(session, candidate.token, 0, 'Imported assisted'))
    local copy = assert(a:GetEditableRotation(0, imported))
    assert(copy.rotation[1].type == 'assisted', 'import dropped the step')
    local clone = assert(a:DuplicateCustomRotation(0, imported, 'Cloned assisted'))
    local cloned = assert(a:GetEditableRotation(0, clone))
    assert(cloned.rotation[1].type == 'assisted', 'clone dropped the step')
    assert(data.ValidateBody(cloned, options).executionStatus ~= 'unavailable')
    select(c, a, 'Cloned assisted')
    assert(a.currentSpell == 8042, 'cloned rotation advice ' .. tostring(a.currentSpell))
end)

test('the rotation editor offers Blizzard\'s suggestion in the rotation list only and drops the action', function()
    local source = assert(io.open('tests/rotation_editor_ui.lua')):read('*a')
    local editor, card = assert(loadstring(assert(source:match('^(.-)\ntest%(')) .. '\nreturn fixture,card'))()
    local f, parent = editor()
    f.addon.Platform.GetAssistedAvailability = function() return { available = true } end
    local pane = assert(f.addon:CreateRotationEditor(parent, 0, 'mine'))

    local function rows(id)
        card(pane, id).action:Click()
        local control = card(pane, id).fieldControls.type
        control:Click()
        local found

        for _, row in ipairs(control.menu.rows) do
            if row:GetText() == "Blizzard's suggestion" then
                found = row
            end
        end

        return found
    end

    assert(not rows('optional'), 'offered in the optional highlight list')
    local row = assert(rows('yes'), 'not offered in the rotation list')
    row:Click()
    local step = pane.workspace:Snapshot().rotation[1].onTrue[1]

    assert(
        step.type == 'assisted' and step.action == nil and step.suppress_attack == nil,
        'type change kept stale fields'
    )

    assert(
        card(pane, 'yes').title:GetText() == "Blizzard's suggestion",
        'card title ' .. tostring(card(pane, 'yes').title:GetText())
    )

    pane.apply:Click()
    assert(f.addon:GetEditableRotation(0, 'mine').rotation[1].onTrue[1].type == 'assisted', 'apply lost the step')
end)

test('the legacy validity check admits assisted steps in the rotation list only', function()
    local _, a = fixture()

    assert(
        a:rotationValidConditions({
            rotation = { { id = 'b', type = 'assisted', conditions = {} } },
            cooldowns = {},
        }, 0),
        'assisted rotation step rejected'
    )

    assert(
        not a:rotationValidConditions({
            rotation = {},
            cooldowns = { { id = 'b', type = 'assisted', conditions = {} } },
        }, 0),
        'assisted cooldown admitted'
    )
end)

test('the condition joins the Spells category once per profile', function()
    local c, a = fixture()
    local spells

    for _, category in ipairs(a.db.profile.condition_groups) do
        if category.id == '8034819e-26f5-4f4e-9153-d8cab5e65f31' then
            spells = category
        end
    end

    assert(spells and a.db.profile.assistedConditionsSeeded, 'not seeded')
    local count = 0

    for _, tag in ipairs(spells.conditions) do
        if tag == 'ASSISTED_SUGGESTION' then
            count = count + 1
        end
    end

    assert(count == 1, 'seeded ' .. count .. ' times')

    for i = #spells.conditions, 1, -1 do
        if spells.conditions[i] == 'ASSISTED_SUGGESTION' then
            table.remove(spells.conditions, i)
        end
    end

    a:InitializeUnitStateConditions(nil, a.db)

    for _, tag in ipairs(spells.conditions) do
        assert(tag ~= 'ASSISTED_SUGGESTION', 'a removed seed came back')
    end

    c.load('UI/settings_draft.lua')
    c.load('Core/profile_data.lua')

    assert(
        a:ValidateProfileTransfer({ assistedConditionsSeeded = true })
            and not a:ValidateProfileTransfer({ assistedConditionsSeeded = 'yes' })
    )
end)

print(pass .. ' passed, ' .. fail .. ' failed')

if fail > 0 then
    os.exit(1)
end
