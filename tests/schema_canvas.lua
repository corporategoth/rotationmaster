local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    f.load('Core/custom_authoring.lua')
    f.load('Core/schema_authoring.lua')
    local file = io.open('Core/schema_canvas.lua')

    if file then
        file:close()
        f.load('Core/schema_canvas.lua')
    end

    return f.addon
end

test('complete schema geometry includes supported and compatibility rows with exact final gaps', function()
    local a = fixture()
    local fields = {}

    for i = 1, 511 do
        fields[string.format('field%03d', i)] = 'number'
    end

    local model = assert(a:NewFieldSchemaDraft(fields))
    local scene = a:BuildFieldSchemaScene(model, {}, 700, a:CopySettingsData(model.root))
    assert(#scene.rows == 511 and scene.byKey['511'].node.name == 'field511' and #scene.gaps == 512)
    assert(scene.gaps[#scene.gaps].gap == 512 and #scene.gaps[#scene.gaps].path == 0 and scene.height > 38000)
    local visible = a:GetFieldSchemaViewport(scene, scene.height - 500, scene.height)
    assert(#visible < 12 and visible[#visible].key == '511')
    fields.field512 = 'string'
    model = assert(a:NewFieldSchemaDraft(fields))
    scene = a:BuildFieldSchemaScene(model, {}, 700, model.root)
    assert(#scene.rows == 512 and not model:Snapshot(), 'legacy repair geometry changed the snapshot bound')
end)

test('schema validation visits each named node once per revision and caches unchanged scrolling', function()
    local a = fixture()
    local fields = {}

    for i = 1, 511 do
        fields[string.format('field%03d', i)] = 'number'
    end

    local model = assert(a:NewFieldSchemaDraft(fields))
    local baseline = a:CopySettingsData(model.root)
    local calls = 0
    local original = a.IsEditableFieldSchemaName

    a.IsEditableFieldSchemaName = function(...)
        calls = calls + 1
        return original(...)
    end

    local scene = a:BuildFieldSchemaScene(model, {}, 700, baseline)
    assert(calls == 511 and not scene.index.dirty)

    for i = 1, 10 do
        a:GetFieldSchemaViewport(scene, i * 500, i * 500 + 400)
        a:BuildFieldSchemaScene(model, {}, 700, baseline)
    end

    assert(calls == 511)

    model:Change(function(root)
        root.children[511].name = root.children[1].name
    end)

    scene = a:BuildFieldSchemaScene(model, {}, 700, baseline)
    assert(calls == 1022 and scene.index.byKey['1'].invalid and scene.index.byKey['511'].invalid and scene.index.dirty)
end)

test('nested schema geometry retains ancestor bounds and all final typed destinations', function()
    local a = fixture()
    local fields = {}

    for i = 1, 50 do
        local child = {}

        for j = 1, 9 do
            child['child' .. j] = 'string'
        end

        fields[string.format('group%02d', i)] = child
    end

    local model = assert(a:NewFieldSchemaDraft(fields))
    local scene = a:BuildFieldSchemaScene(model, {}, 700, model.root)
    assert(#scene.rows == 500 and #scene.gaps == 551 and scene.byKey['50/9'])
    local visible = a:GetFieldSchemaViewport(scene, scene.height - 200, scene.height)
    local keys = {}

    for _, row in ipairs(visible) do
        keys[row.key] = true
    end

    assert(keys['50'] and keys['50/9'] and scene.byKey['50/9'].x > scene.byKey['50'].x)
    local folded = a:BuildFieldSchemaScene(model, { ['1'] = true }, 700, model.root)
    assert(#folded.rows == 491 and not folded.byKey['1/1'] and folded.byKey['50/9'])
end)

test('duplicate and invalid container names retain their own invalid flag as well as ancestor flags', function()
    local a = fixture()
    local model = assert(a:NewFieldSchemaDraft({ a = { child = 'number' }, b = { child = 'string' } }))
    local baseline = a:CopySettingsData(model.root)

    model:Change(function(root)
        root.children[2].name = 'a'
    end)

    local index = a:GetFieldSchemaIndex(model, baseline)
    assert(index.byKey['1'].invalid and index.byKey['2'].invalid and index.byKey[''].invalid)
end)

test('deep container Add footers remain visible after the last descendant header scrolls away', function()
    local a = fixture()
    local fields = 'number'

    for i = 1, 36 do
        fields = { field = fields }
    end

    local model = assert(a:NewFieldSchemaDraft(fields))
    local scene = a:BuildFieldSchemaScene(model, {}, 700, model.root)
    local rows = a:GetFieldSchemaViewport(scene, scene.height - 300, scene.height)
    assert(#rows > 0 and rows[1].key == '1', 'ancestor footer was excluded when its last leaf is above the viewport')
end)

test('full compatibility model geometry preserves navigation while new snapshots keep their bounds', function()
    local a = fixture()
    local fields = {}

    for i = 1, 19999 do
        fields[string.format('field%05d', i)] = 'number'
    end

    local model = assert(a:NewFieldSchemaDraft(fields))
    local scene = a:BuildFieldSchemaScene(model, {}, 700, model.root)

    assert(
        #scene.rows == 19999 and scene.byKey['19999'].node.name == 'field19999' and scene.gaps[#scene.gaps].gap == 20000
    )

    assert(not model:Snapshot())
    fields.extra = 'number'
    assert(not a:NewFieldSchemaDraft(fields))
end)

finish()
