local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    f.load('Core/custom_authoring.lua')
    f.load('Core/schema_authoring.lua')
    return f.addon
end

test('graph schema roundtrips records unions and list alternatives without executing source', function()
    local a = fixture()

    local fields = {
        spell = { 'string', 'number' },
        tests = 'condition[]',
        position = { x = 'number', y = 'number' },
        items = { 'string', { 'string', 'number' } },
    }

    local d = assert(a:NewFieldSchemaDraft(fields))
    local value, order = d:Snapshot()
    assert(a:SettingsDataEqual(fields, value) and #order > 4)

    d:Change(function(root)
        local first = table.remove(root.children, 1)
        root.children[#root.children + 1] = first
    end)

    local changed, layout = d:Snapshot()
    assert(a:SettingsDataEqual(changed, fields))
    local reopened = assert(a:NewFieldSchemaDraft(changed, layout))
    assert(reopened.root.children[1].name == d.root.children[1].name)
    assert(d:Travel(false) and d:Travel(true))
end)

test('invalid graph schemas and forged orders remain unsaved with explicit errors', function()
    local a = fixture()
    local d = assert(a:NewFieldSchemaDraft({ one = 'string' }))

    d:Change(function(root)
        root.children[2] = { name = 'one', kind = 'number' }
    end)

    local value, why = d:Snapshot()
    assert(not value and why == 'duplicate-field')
    assert(not a:NormalizeCustomFieldOrder({ { 'missing' } }, { one = 'string' }))
    assert(not a:NormalizeCustomFieldOrder({ [2] = { 'one' } }, { one = 'string' }))
end)

test('nested fields move atomically between containers with reversible order', function()
    local a = fixture()
    local d = assert(a:NewFieldSchemaDraft({ a = 'string', group = { x = 'number' }, z = 'boolean' }))
    local before = d:Snapshot()
    assert(d:CanTransfer({ 1 }, { 2 }, 2))
    assert(d:Transfer({ 1 }, { 2 }, 2))
    assert(#d.root.children == 2 and d.root.children[1].children[2].name == 'a')
    local fields, order = d:Snapshot()
    assert(fields.group.a == 'string' and not fields.a and order[3][2] == 'a')
    assert(d:Travel(false) and a:SettingsDataEqual(d:Snapshot(), before))
    assert(d:Travel(true) and d:Snapshot().group.a == 'string')
end)

test('schema move rejects cycles no-op gaps duplicate fields and stale paths without dirtying history', function()
    local a = fixture()
    local d = assert(a:NewFieldSchemaDraft({ a = 'string', group = { a = 'number' } }))
    assert(not d:CanTransfer({ 2 }, { 2 }, 1))
    assert(not d:CanTransfer({ 1 }, {}, 1))
    assert(not d:CanTransfer({ 1 }, {}, 2))
    assert(not d:CanTransfer({ 1 }, { 2 }, 2))
    assert(not d:Transfer({ 9 }, {}, 1))
    assert(#d.undo == 0)
    assert(d:Transfer({ 2 }, {}, 1))
    assert(d.root.children[1].name == 'group')
end)

test('schema duplicates carry nested children and get unique field names', function()
    local a = fixture()
    local d = assert(a:NewFieldSchemaDraft({ group = { child = 'string' } }))
    assert(d:Duplicate({ 1 }))
    assert(d.root.children[2].name == 'group_copy')
    d.root.children[2].children[1].kind = 'number'
    assert(d.root.children[1].children[1].kind == 'string')
    assert(d:Duplicate({ 1 }))
    assert(d.root.children[2].name == 'group_copy_2')
    assert(d:Remove({ 2 }))
    assert(d:Add({}, 'record'))
    assert(d:Snapshot())
end)

test('Ctrl schema move carries following siblings and converts list names safely', function()
    local a = fixture()
    local d = assert(a:NewFieldSchemaDraft({ a = 'string', b = 'boolean', group = { x = 'number' } }))
    assert(not d:Transfer({ 1 }, { 3 }, 2, true), 'suffix moved into its own descendant')
    assert(d:Transfer({ 2 }, {}, 1, true))
    assert(d.root.children[1].name == 'b' and d.root.children[2].name == 'group')
    d = assert(a:NewFieldSchemaDraft({ choices = { 'string', 'number' }, target = { x = 'boolean' } }))
    assert(d:Transfer({ 1, 1 }, { 2 }, 2))
    local fields = d:Snapshot()
    assert(fields.target.field == 'string' and fields.choices[1] == 'number')
    assert(d:SetKind({ 2 }, 'union'))
    assert(d:SetKind({ 2 }, 'record'))
    assert(d:Snapshot())
end)

test('copy and generated names stay within the editable schema name limit', function()
    local a = fixture()
    local name = string.rep('x', 64)
    local d = assert(a:NewFieldSchemaDraft({ [name] = 'number' }))
    assert(d:Duplicate({ 1 }))
    assert(d:Duplicate({ 1 }))
    local fields = assert(d:Snapshot())
    local seen = {}

    for _, child in ipairs(d.root.children) do
        assert(#child.name <= 64 and not seen[child.name])
        seen[child.name] = true
    end

    assert(fields[name] == 'number')
end)

test('root requirements follow names copies ordering deletion and history', function()
    local a = fixture()
    local fields = { unit = 'string', other = 'number' }
    local d = assert(a:NewFieldSchemaDraft(fields, { { 'unit' }, { 'other' } }, { 'unit' }))
    assert(d.root.children[1].required and not d.root.children[2].required, 'root requirement missing')

    d:Change(function(root)
        root.children[1].name = 'renamed'
    end)

    assert(d:Duplicate({ 1 }))
    assert(d:Transfer({ 1 }, {}, 4))
    local value, _, required = d:Snapshot()
    assert(value.renamed == 'string' and required[1] == 'renamed_copy' and required[2] == 'renamed')
    assert(d:Remove({ 1 }))
    _, _, required = d:Snapshot()
    assert(#required == 1 and required[1] == 'renamed')
    assert(d:Travel(false))
    _, _, required = d:Snapshot()
    assert(#required == 2)
    assert(a:SettingsDataEqual(fields, { unit = 'string', other = 'number' }))
end)

test('only named root fields can require values and nesting clears that contract reversibly', function()
    local a = fixture()

    local d = assert(a:NewFieldSchemaDraft(
        { unit = 'string', group = { child = 'number' } },
        { { 'unit' }, { 'group' } },
        { 'unit' }
    ))

    assert(not d:SetRequired({ 2, 1 }, true) and not d:SetRequired({}, true))
    assert(d:Transfer({ 1 }, { 2 }, 2))
    local _, _, required = d:Snapshot()
    assert(#required == 0 and not d.root.children[1].children[2].required)
    assert(d:Travel(false) and d.root.children[1].required)
    assert(d:SetRequired({ 1 }, false))
    _, _, required = d:Snapshot()
    assert(#required == 0)
    assert(d:Travel(false))
    _, _, required = d:Snapshot()
    assert(required[1] == 'unit')
end)

test('root requirements preserve absent and empty metadata and explicitly repair invalid references', function()
    local a = fixture()
    local d = assert(a:NewFieldSchemaDraft({ unit = 'string' }))
    local _, _, required = d:Snapshot()
    assert(required == nil)
    assert(not d:SetRequired({ 1 }, false))
    _, _, required = d:Snapshot()
    assert(required == nil)
    assert(d:SetRequired({ 1 }, true))
    _, _, required = d:Snapshot()
    assert(required[1] == 'unit')
    assert(d:Travel(false))
    _, _, required = d:Snapshot()
    assert(required == nil)
    d = assert(a:NewFieldSchemaDraft({ unit = 'string' }, nil, {}))
    _, _, required = d:Snapshot()
    assert(type(required) == 'table' and #required == 0)
    local original = { 'missing', 'unit', 'unit' }
    d = assert(a:NewFieldSchemaDraft({ unit = 'string' }, nil, original))
    assert(d.requiredFieldsInvalid)
    _, _, required = d:Snapshot()
    assert(#required == 1 and required[1] == 'unit' and #original == 3)
end)

test('requirements retain the source limit and raw reconciliation only keeps existing names', function()
    local a = fixture()
    local fields = {}

    for i = 1, 129 do
        fields['field' .. i] = 'string'
    end

    local d = assert(a:NewFieldSchemaDraft(fields))

    for i = 1, 129 do
        assert(d:SetRequired({ i }, true))
    end

    local value, why = d:Snapshot()
    assert(not value and why == 'invalid-required-fields')
    local original = { 'unit', 'count', 'unit' }
    local filtered = a:FilterCustomRequiredFields(original, { count = 'number' })
    assert(#filtered == 1 and filtered[1] == 'count' and #original == 3)
end)

finish()
