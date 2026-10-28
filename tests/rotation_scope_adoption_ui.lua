-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local make = dofile('tests/fixtures/rotation_data.lua')
local test, finish = F.suite()

local function body(name)
    return { name = name, switch = {}, rotation = {}, cooldowns = {} }
end

local function fixture(count)
    local f = F.new()
    local a = f.addon
    local data, _, validation = make()
    a.RotationData = data
    a.conditionDefinitions = validation.conditions
    local records = { Unknown = body('Unassigned') }

    for i = 1, count or 0 do
        records['row' .. i] = body('Record ' .. i)
    end

    a.db = {
        keys = { char = 'A - Realm' },
        global = { effects = {} },
        char = {},
        profile = {
            rotationFallbackID = 'Saved fallback',
            rotationStore = {
                version = 1,
                classes = {},
                characters = {},
                legacy = {
                    rotations = { [0] = records },
                    comparisons = { [0] = { orphan = { note = 'Preserve orphan' } } },
                },
            },
        },
        sv = {
            char = {
                ['A - Realm'] = { rotations = { [0] = { charold = body('Legacy character') } } },
                ['B - Realm'] = { rotations = { [0] = { offline = body('Offline secret') } } },
            },
        },
    }

    local context = { class = 'SHAMAN', family = 'tbc', spec = 0, combatDataPolicy = 'probe' }

    for _, path in ipairs({
        'Data/catalog.lua', 'Data/diff.lua', 'Data/rotation_store.lua', 'Core/rotation_references.lua',
        'Core/rotation_library.lua', 'Core/rotation_tags.lua', 'Core/rotation_scope.lua', 'Core/rotation_migration.lua',
        'UI/settings_layout.lua', 'UI/settings_roster_order.lua', 'UI/settings_history.lua', 'UI/settings_ordered.lua',
        'UI/settings_form.lua', 'UI/settings_transfer.lua', 'UI/rotation_comparison.lua'
    }) do
        f.load(path)
    end

    a.GetRotationContext = function() return context end
    assert(a:BindRotationProfile())

    if io.open('UI/rotation_adoption.lua') then
        f.load('UI/rotation_adoption.lua')
    end

    return f, a, context
end

local function open(a, ...)
    assert(a.ShowRotationAdoption, 'native recovery UI missing')
    return assert(a:ShowRotationAdoption(...))
end

local function select(w, id, kind)
    for _, entry in ipairs(w.form.roster.entries) do
        if entry.selection.id == id and (not kind or entry.selection.kind == kind) then
            w.form.roster.choose(entry.value)
            return
        end
    end

    error('missing recovery row ' .. id)
end

test(
    'recovery lists unassigned profile and current character without claiming ownership or exposing offline rows',
    function()
        local _, a = fixture()
        local baseline = a:CopySettingsData(a.db)
        local w = open(a)
        assert(w.frame:IsShown() and #w.form.roster.entries == 3)

        for _, entry in ipairs(w.form.roster.entries) do
            assert(not entry.text:find('Offline', 1, true))
        end

        assert(a:SettingsDataEqual(baseline, a.db) and next(a.db.profile.rotationStore.classes) == nil)
    end
)

test('explicit Class adoption retains ID and returns complete reference to caller', function()
    local _, a = fixture()
    local applied

    local w = open(a, nil, function(reference)
        applied = reference
    end)

    select(w, 'Unknown')
    assert(w.form.fields.adopt:IsEnabled())
    w.form.fields.adopt:Click()
    assert(not w.frame:IsShown() and applied.address.scope == 'class' and applied.address.id == 'Unknown')

    assert(
        a.db.profile.rotationStore.classes.SHAMAN[0].Unknown.body.name == 'Unassigned'
            and a.db.profile.rotationStore.legacy.rotations[0].Unknown == nil
    )
end)

test('explicit This character adoption handles legacy character archive and preserves offline archive', function()
    local _, a = fixture()
    local w = open(a)
    select(w, 'charold', 'character')
    w.form.fields.character:Click()
    w.form.fields.adopt:Click()

    assert(
        a.db.profile.rotationStore.characters['A - Realm'].specs[0].charold.body.name == 'Legacy character'
            and a.db.sv.char['A - Realm'].rotations[0].charold == nil
    )

    assert(a.db.sv.char['B - Realm'].rotations[0].offline.name == 'Offline secret')
end)

test('orphan and malformed archival records remain exportable with explicit blocked adoption reason', function()
    local _, a = fixture()
    a.db.profile.rotationStore.legacy.rotations[0].broken = 42
    assert(a:BindRotationProfile())
    local w = open(a)
    select(w, 'orphan')
    assert(not w.form.fields.adopt:IsEnabled())
    w.form.fields.export:Click()
    local report = w.report
    assert(report and report.input:GetText():find('Preserve orphan', 1, true))
    select(w, 'broken')
    assert(not w.form.fields.adopt:IsEnabled())
    w.form.fields.export:Click()
    assert(report.input:GetText():find('42', 1, true) and a.db.profile.rotationStore.legacy.rotations[0].broken == 42)
end)

test('collision and stale reviewed adoption preserve archive and current destination unchanged', function()
    local _, a = fixture()
    a.db.profile.rotationStore.classes.SHAMAN = { [0] = { Unknown = { body = body('Existing') } } }
    assert(a:BindRotationProfile())
    local w = open(a)
    select(w, 'Unknown')
    assert(not w.form.fields.adopt:IsEnabled() and w.form.message:GetText():find('rotation%-id%-collision'))
    w.form.fields.character:Click()
    assert(w.form.fields.adopt:IsEnabled())
    a.db.profile.rotationStore.legacy.rotations[0].Unknown.name = 'Changed'
    w.form.fields.adopt:Click()

    assert(
        w.frame:IsShown()
            and a.db.profile.rotationStore.legacy.rotations[0].Unknown.name == 'Changed'
            and a.db.profile.rotationStore.characters['A - Realm'] == nil
    )
end)

test('reopened window and retired owner callbacks cannot adopt into a newer session', function()
    local f, a = fixture()
    local owner = { frame = f.env.CreateFrame('Frame'), generation = 1 }
    owner.frame:Show()
    local w = open(a, owner)
    select(w, 'Unknown')
    local stale = w.form.fields.adopt:GetScript('OnClick')
    local exported = w.form.fields.export:GetScript('OnClick')
    w = open(a, owner)
    select(w, 'charold')
    stale()
    exported()

    assert(
        a.db.profile.rotationStore.legacy.rotations[0].Unknown
            and a.db.sv.char['A - Realm'].rotations[0].charold
            and not w.report
    )

    owner.generation = 2
    w.form.fields.adopt:Click()
    w.frame:GetScript('OnUpdate')()
    assert(not w.frame:IsShown() and a.db.sv.char['A - Realm'].rotations[0].charold)
end)

test('profile and owner transitions fail closed and missing character identity disables destination', function()
    local _, a, c = fixture()
    local w = open(a)
    select(w, 'Unknown')
    c.class = 'MAGE'
    w.form.fields.adopt:Click()
    w.frame:GetScript('OnUpdate')()
    assert(not w.frame:IsShown() and a.db.profile.rotationStore.legacy.rotations[0].Unknown)
    c.class = 'SHAMAN'
    w = open(a)
    select(w, 'Unknown')
    a.db.profile = a:CopySettingsData(a.db.profile)
    w.form.fields.adopt:Click()
    assert(a.db.profile.rotationStore.legacy.rotations[0].Unknown)
    w.frame:GetScript('OnUpdate')()
    assert(not w.frame:IsShown())
    assert(a:BindRotationProfile())
    a.db.keys.char = nil
    w = open(a)
    select(w, 'Unknown')
    assert(not w.form.fields.character:IsEnabled() and w.form.fields.class:GetChecked())
end)

test('one thousand unassigned records use bounded reusable roster rows and complete search', function()
    local _, a = fixture(1000)
    local w = open(a)
    local p = w.form
    local r = p.roster
    assert(#r.entries == 1003 and #r.rows < 40)
    local warm = #r.rows

    for i = 1, 10 do
        r.scroll.workbenchBar:SetValue(i % 2 == 0 and 0 or 34000)
    end

    assert(#r.rows <= warm + 2)
    r.search:SetText('Record 999')
    r.search:GetScript('OnTextChanged')(r.search, true)
    assert(#r.matches == 1 and r.matches[1].selection.id == 'row999')
    r.choose(r.matches[1].value)
    assert(p.fields.adopt:IsEnabled())
end)

test('recovering an archived fallback retires its earlier virtual pending target', function()
    local _, a = fixture()
    a.db.profile.rotationFallbackID = 'Unknown'
    assert(a:BindRotationProfile())
    local rows = a:ListRotationHeaders(0)
    assert(rows[1].pending)
    local applied

    local w = open(a, nil, function(reference)
        applied = reference
    end)

    select(w, 'Unknown')
    w.form.fields.adopt:Click()

    assert(
        applied and not a:GetScopedRotationCoordinator():IsPending(applied),
        'saved adoption remained a virtual pending draft'
    )
end)

test('unavailable recovery remains readable as a diagnostic without hiding or mutating roots', function()
    local _, a = fixture()
    a.db.profile.rotationFallbackID = nil
    assert(not a:BindRotationProfile())
    local w = open(a)
    assert(w.frame:IsShown() and not w.form.fields.adopt)
    w.frame:GetScript('OnUpdate')()
    assert(w.frame:IsShown())
    w.form.fields.export:Click()
    assert(w.report.input:GetText():find('missing%-fallback%-configuration') and a.db.profile.rotationFallbackID == nil)
end)

test('browser serial retirement closes recovery even when frame profile and generation stay unchanged', function()
    local f, a = fixture()
    local owner = { frame = f.env.CreateFrame('Frame'), serial = 1 }
    owner.frame:Show()
    local w = open(a, owner)
    select(w, 'Unknown')
    owner.serial = 2
    w.form.fields.adopt:Click()
    w.frame:GetScript('OnUpdate')()
    assert(not w.frame:IsShown() and a.db.profile.rotationStore.legacy.rotations[0].Unknown)
end)

finish()
