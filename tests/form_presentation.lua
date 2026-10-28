local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local question = 'Interface\\Icons\\INV_Misc_QuestionMark'

local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local function fixture(class, legacy)
    local f = F.new(11, 2, class or 'DRUID')
    local a, e = f.addon, f.env
    local s = { trace = {}, mode = 'ready', icon = 123, form = 1, count = 2 }

    local function log(kind, id, ...)
        assert(select('#', ...) == 0, 'extra native args')
        s.trace[#s.trace + 1] = kind .. ':' .. tostring(id)
    end

    e.GetNumShapeshiftForms = function(...)
        assert(select('#', ...) == 0)
        s.trace[#s.trace + 1] = 'count'
        return s.count
    end

    e.GetShapeshiftFormInfo = function(index, ...)
        log('form', index, ...)

        if index == s.stop then
            return 900 + index, false, true, nil
        end

        return 900 + index, false, true, index == 1 and 123 or 456
    end

    e.GetShapeshiftForm = function(...)
        assert(select('#', ...) == 0)
        s.trace[#s.trace + 1] = 'current'
        return s.form
    end

    local function info(id, ...)
        log('spell', id, ...)

        if s.mode == 'throw' then
            error('metadata failure')
        elseif s.mode == 'missing' then
            return nil
        elseif s.mode == 'restricted' then
            return s.opaque
        end

        return {
            name = (id == 'Ghost Wolf' or id == 2645) and 'Ghost Wolf label' or 'Form ' .. id,
            iconID = s.icon,
            spellID = type(id) == 'number' and id or 2645,
        }
    end

    if legacy then
        e.GetSpellInfo = function(id, ...)
            local r = info(id, ...)

            if r then
                return r.name, nil, r.iconID, 0, 0, 0, r.spellID
            end
        end

        e.GetSpellTexture = function(id, ...)
            log('texture', id, ...)
            return s.icon
        end
    else
        e.C_Spell = { GetSpellInfo = info }
        e.GetSpellInfo = nil
        e.GetSpellTexture = nil
    end

    for _, path in ipairs({
        'Diagnostics/errors.lua',
        'Platform/spells.lua',
        'Core/conditions.lua',
        'Conditions/combat.lua',
        'Data/builtin_sources.lua',
        'Core/builtin_sources.lua',
        'Core/custom_authoring.lua',
        'Core/function_data.lua',
    }) do
        f.load(path)
    end

    e.loadstring = function(code, name)
        local fn, why = loadstring(code, name)

        if fn then
            setfenv(fn, e)
        end

        return fn, why
    end

    s.opaque = {}
    e.canaccessvalue = function(value) return not rawequal(value, s.opaque) end
    return f, a, s
end

local function mount(a, value, definition)
    definition = definition or a.conditionDefinitions.FORM
    local parent = a:CreateConditionGroup()
    parent:SetWidth(640)
    local state = { prints = 0, statuses = 0 }
    local top = {}
    local funcs = {}

    function top:GetUserData(key)
        if key == 'root' then
            return value
        elseif key == 'funcs' then
            return funcs
        end
    end

    function funcs:print(root, spec)
        assert(root == value and spec == 7)
        state.prints = state.prints + 1
        return definition.print(spec, value)
    end

    function top:SetStatusText(text)
        state.statuses = state.statuses + 1
        state.status = text
    end

    parent:SetUserData('top', top)
    definition.widget(parent, 7, value)
    a:configure_frame(parent)
    parent:DoLayout()

    assert(
        #parent.children == 2 and a:IsConditionWidget(parent.children[1]) and a:IsConditionWidget(parent.children[2])
    )

    return parent.children[1], parent.children[2], parent, state
end

local function choose(dropdown, key)
    dropdown.button:Click()

    for _, row in ipairs(dropdown.selector.rows) do
        if row.menuEntry and row.menuEntry.value == key then
            row:Click()
            return
        end
    end

    error('form choice missing ' .. key)
end

local function reset(s)
    s.trace = {}
end

-- The editor offers forms by spell: stance bar first, then the class's other
-- forms on this client (project 11 is a Mists-family client), and a saved
-- stance-bar slot keeps its own entry.
local DRUID_FORMS = {5487, 1066, 768, 783, 24858, 33891, 33943, 40120, 114282}

local function candidates(ids)
    local t = {}

    for _, id in ipairs(ids) do
        t[#t + 1] = 'spell:' .. id
    end

    local one = table.concat(t, ',')
    return one .. ',' .. one
end

test('modern-only summaries retain humanoid and selected native spell identities', function()
    for _, class in ipairs({ 'DRUID', 'SHAMAN' }) do
        local _, a, s = fixture(class)
        local v = { type = 'FORM', value = 1 }
        assert(a.conditionDefinitions.FORM.valid(0, v))
        reset(s)
        local text = a:printCondition(v, 7)
        assert(text:find(class == 'SHAMAN' and 'Ghost Wolf label' or 'Form 123', 1, true))
        assert(table.concat(s.trace, ',') == (class == 'SHAMAN' and 'spell:2645' or 'form:1,spell:123'))
        reset(s)
        v.value = 0
        assert(a:printCondition(v, 7):find('humanoid', 1, true) and #s.trace == 0)
    end
end)

test('native form choices preserve count order native icon and exact selected numeric value', function()
    local _, a, s = fixture()
    local marker = {}
    local v = { value = 1, sentinel = marker }
    reset(s)
    local icon, dropdown, parent, state = mount(a, v)

    assert(
        table.concat(s.trace, ',')
            == 'count,form:1,spell:123,form:2,spell:456,' .. candidates(DRUID_FORMS) .. ',form:1,spell:123,form:1'
    )

    assert(
        icon.image:GetTexture() == 901
            and dropdown.list['0'] == 'humanoid'
            and dropdown.list['spell:123'] == 'Form 123'
            and dropdown.list['spell:456'] == 'Form 456'
            and dropdown.list['1'] == 'Stance bar slot 1 (Form 123)'
            and dropdown:GetValue() == '1'
    )

    local order = table.concat(dropdown.order, ',')
    assert(order:sub(1, 24) == '0,spell:123,spell:456,sp' and order:sub(-2) == ',1')
    choose(dropdown, 'spell:456')

    assert(
        v.form == 456
            and v.value == nil
            and v.sentinel == marker
            and state.prints == 1
            and state.statuses == 1
            and icon.image:GetTexture() == 123
            and state.status:find('Form 456', 1, true)
    )

    parent:Release()
    local _, b, t = fixture('SHAMAN')
    t.count = 0
    reset(t)
    local image, select, owner = mount(b, { value = 1 })

    assert(
        table.concat(t.trace, ',') == 'count,spell:2645,spell:2645,spell:2645,spell:2645'
            and image.image:GetTexture() == 123
            and select.list['1'] == 'Stance bar slot 1 (Ghost Wolf label)'
            and select.list['spell:2645'] == 'Ghost Wolf label'
    )

    owner:Release()
end)

test(
    'missing failed and restricted metadata decorate without changing form selection or using legacy fallback',
    function()
        for _, class in ipairs({ 'DRUID', 'SHAMAN' }) do
            for _, mode in ipairs({ 'missing', 'throw', 'restricted' }) do
                local f, a, s = fixture(class)
                s.mode = mode

                f.env.GetSpellInfo = function()
                    error('selected modern failure fell back')
                end

                f.env.GetSpellTexture = function()
                    error('legacy texture used')
                end

                local v = { type = 'FORM', value = 1 }
                assert(a:printCondition(v, 7):find('<form>', 1, true))
                local icon, dropdown, parent = mount(a, v)

                assert(
                    v.value == 1 and dropdown:GetValue() == '1' and dropdown.list['1'] == 'Stance bar slot 1 (<form>)'
                )

                assert(icon.image:GetTexture() == (class == 'SHAMAN' and question or 901))
                parent:Release()
            end
        end
    end
)

test('metadata is live after failure and preserves numeric or path Ghost Wolf icons', function()
    local _, a, s = fixture('SHAMAN')
    s.mode = 'missing'
    local value = { value = 1 }
    local icon, dropdown, parent = mount(a, value)
    assert(icon.image:GetTexture() == question)

    for _, texture in ipairs({ 456, 'Interface\\Icons\\Spell_Nature_SpiritWolf' }) do
        s.mode = 'ready'
        s.icon = texture
        dropdown:Fire('OnValueChanged', '1')
        assert(icon.image:GetTexture() == texture and value.value == 1)
    end

    parent:Release()
    s.mode = 'ready'
    local _, d, p = mount(a, value)
    assert(d.list['1'] == 'Stance bar slot 1 (Ghost Wolf label)' and d.list['spell:2645'] == 'Ghost Wolf label')
    p:Release()
end)

test('legacy-only native metadata keeps labels icons and missing form spell stops enumeration', function()
    for _, class in ipairs({ 'DRUID', 'SHAMAN' }) do
        local _, a = fixture(class, true)

        assert(a:printCondition({ type = 'FORM', value = 1 }, 7):find(
            class == 'SHAMAN' and 'Ghost Wolf label' or 'Form 123',
            1,
            true
        ))

        local icon, _, parent = mount(a, { value = 1 })
        assert(icon.image:GetTexture() == (class == 'SHAMAN' and 123 or 901))
        parent:Release()
    end

    local _, a, s = fixture()
    s.stop = 2
    reset(s)
    local _, dropdown, parent = mount(a, { value = 1 })

    assert(
        table.concat(s.trace, ',')
            == 'count,form:1,spell:123,form:2,' .. candidates(DRUID_FORMS) .. ',form:1,spell:123,form:1'
            and dropdown.list['spell:456'] == nil
            and dropdown.order[2] == 'spell:123'
            and #dropdown.order == 2 + #DRUID_FORMS + 1
    )

    parent:Release()
end)

test('retired native popup callback cannot edit a recycled form field or its previous owner', function()
    local _, a = fixture()
    local old = { value = 1 }
    local _, dropdown, parent, state = mount(a, old)
    dropdown.button:Click()
    local row

    for _, r in ipairs(dropdown.selector.rows) do
        if r.menuEntry and r.menuEntry.value == '0' then
            row = r
        end
    end

    assert(row)
    local stale = row.scripts.OnClick
    parent:Release()
    local fresh = { value = 1 }
    local _, reused, owner, nextState = mount(a, fresh)
    assert(reused == dropdown)
    stale(row)
    assert(old.value == 1 and fresh.value == 1 and state.prints == 0 and nextState.prints == 0)
    owner:Release()
end)

local localized, _, currentBodies = dofile('tests/fixtures/restore_form_localization.lua')
local inverse, old, repaired = dofile('tests/fixtures/restore_form_presentation_repairs.lua')

test('current editable copies use actual modern metadata and preserve all unrelated source fields', function()
    for _, class in ipairs({ 'DRUID', 'SHAMAN' }) do
        local _, a, s = fixture(class)
        local source = assert(a:GetBuiltinConditionSource('FORM'))
        local before = a:CopySettingsData(source)
        local copy = assert(a:CompileCustomCondition('COPY_FORM', source))
        a:RegisterCondition('COPY_FORM', copy)
        local value = { type = 'COPY_FORM', value = 1 }

        assert(
            copy.valid(0, value) and a:printCondition(value, 7):find(
                class == 'SHAMAN' and 'Ghost Wolf label' or 'Form 123',
                1,
                true
            )
        )

        local icon, dropdown, parent = mount(a, value, copy)
        assert(icon.image:GetTexture() == (class == 'SHAMAN' and 123 or 901))
        choose(dropdown, '0')
        assert(value.value == 0)
        parent:Release()
        s.mode = 'throw'
        assert(a:printCondition(value, 7):find('humanoid', 1, true))
        value.value = 1
        assert(a:printCondition(value, 7):find('<form>', 1, true))
        assert(a:SettingsDataEqual(before, source), 'editable source rewritten')
    end
end)

test('archived raw callbacks preserve legacy dispatch and stored source without migration', function()
    for _, class in ipairs({ 'DRUID', 'SHAMAN' }) do
        local f, a = fixture(class, true)
        local source = a:GetBuiltinConditionSource('FORM')
        source.print = old.print
        source.widget = old.widget
        local before = a:CopySettingsData(source)
        a.db.global.custom_conditions = { RAW_FORM = source }
        local copy = assert(a:CompileCustomCondition('RAW_FORM', source))
        a:RegisterCondition('RAW_FORM', copy)
        local value = { type = 'RAW_FORM', value = 1 }
        assert(a:printCondition(value, 7):find(class == 'SHAMAN' and 'Ghost Wolf label' or 'Form 123', 1, true))
        local _, _, parent = mount(a, value, copy)
        parent:Release()
        local marker = {}

        f.env.GetSpellInfo = function()
            error(marker)
        end

        local ok, why = pcall(a.printCondition, a, value, 7)
        assert(not ok and why == marker, 'old global dispatch changed')
        assert(a:SettingsDataEqual(before, source) and a.db.global.custom_conditions.RAW_FORM == source)
    end
end)

test('presentation never changes field validity current equality or normalized cache behavior', function()
    local _, a, s = fixture()
    local def = a.conditionDefinitions.FORM
    local value = { type = 'FORM', value = 1 }
    assert(def.valid(0, value))
    local cache = {}
    reset(s)
    assert(def.evaluate(value, cache) == true)
    assert(def.evaluate(value, cache) == true and table.concat(s.trace, ',') == 'current')
    s.form = 0
    assert(def.evaluate(value, cache) == true and def.evaluate(value, {}) == false)
    assert(not def.valid(0, { value = 3 }) and def.valid(0, { value = .5 }))
    s.form = nil
    local result, reason = def.evaluate(value, {})
    assert(result == nil and type(reason) == 'string')
end)

finish()
