local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local a = {}

    for _, file in ipairs({
        'Data/plain.lua',
        'Data/rotation_revision.lua',
        'Data/tags.lua',
        'Data/rotation_tree.lua',
        'Data/rotation_draft.lua',
        'Data/validation.lua',
    }) do
        assert(loadfile(file))('rotationmaster', a)
    end

    local file = io.open('Core/rotation_editor.lua')

    if file then
        file:close()
        assert(loadfile('Core/rotation_editor.lua'))('rotationmaster', a)
    end

    a.conditionDefinitions = { KNOWN = { fields = { spell = 'number' }, requiredFields = { 'spell' } } }

    function a:GetImportValidationOptions()
        return { conditions = self.conditionDefinitions }
    end

    function a:validateCondition(c, spec)
        assert(spec == 0)
        return c.type == nil or c.spell == 403
    end

    local n = 0

    function a.uuid()
        n = n + 1
        return 'new-' .. n
    end

    return a
end

local function body()
    return {
        name = 'Mine',
        switch = {},
        rotation = {
            {
                id = 'b',
                type = 'branch',
                conditions = {},
                onTrue = { { id = 'a', type = 'spell', action = 403, conditions = {} } },
                onFalse = {},
            },
        },
        cooldowns = {},
    }
end

test('stacked edits stay detached until explicit Apply and Cancel never writes', function()
    local a = fixture()
    local original = body()
    local s = assert(a:NewRotationEditSession(0, original))
    assert(not s:IsDirty() and not s:HistoryState().canUndo)
    assert(s:Command('SetBodyField', 'name', 'Edited'))
    assert(s:Command('Remove', 'a'))
    assert(original.name == 'Mine' and #original.rotation[1].onTrue == 1 and s:IsDirty())
    assert(s:Undo())
    assert(s:Undo())
    assert(not s:IsDirty())
    assert(s:Redo())
    assert(s:Apply())
    assert(original.name == 'Edited' and #original.rotation[1].onTrue == 1 and not s:Undo() and not s:Apply())
    s = assert(a:NewRotationEditSession(0, original))
    assert(s:Command('Remove', 'b'))
    s:Cancel()
    assert(not s:Apply() and #original.rotation == 1)
end)

test('readonly sessions expose the same snapshot but reject mutation Apply and history', function()
    local a = fixture()
    local original = body()
    local s = assert(a:NewRotationEditSession(0, original, { readOnly = true }))
    assert(s:Snapshot().rotation[1].onTrue[1].id == 'a')
    assert(not s:Command('Remove', 'a') and not s:Apply() and not s:Undo() and not s:Redo())
    assert(not s:IsDirty() and not s:HistoryState().canUndo and #original.rotation[1].onTrue == 1)
end)

test('semantic validation covers switch guards and both arms without evaluating live conditions', function()
    local a = fixture()
    local original = body()
    local s = assert(a:NewRotationEditSession(0, original))
    assert(s:Command('SetCondition', 'b', { type = 'KNOWN', spell = 99 }))
    local ok, why = s:Apply()
    assert(not ok and why == 'invalid-condition-fields')
    assert(s:Command('SetCondition', 'b', { type = 'KNOWN', spell = 403 }))
    assert(s:Command('SetCondition', { kind = 'switch' }, { type = 'KNOWN', spell = 99 }))
    assert(not s:Apply())
    assert(s:Command('SetCondition', { kind = 'switch' }, {}))
    assert(s:Command('SetCondition', 'a', { type = 'KNOWN' }))
    ok, why = s:Apply()
    assert(not ok and why == 'invalid-rotation-data')
    assert(s:Command('SetCondition', 'a', { type = 'KNOWN', spell = 403 }))
    assert(s:Apply())
    assert(original.rotation[1].conditions.spell == 403)
end)

test('missing owners concurrent changes and mutation by semantic validators block atomic Apply', function()
    for _, scenario in ipairs({ 'owner', 'external', 'mutate', 'throw', 'replace-during-validation' }) do
        local a = fixture()
        local original = body()
        local exists = true
        local s = assert(a:NewRotationEditSession(0, original, { targetValid = function() return exists end }))
        assert(s:Command('SetBodyField', 'name', 'Unsaved'))

        if scenario == 'owner' then
            exists = false
        elseif scenario == 'external' then
            original.name = 'Other editor'
        elseif scenario == 'mutate' then
            function a:validateCondition(c)
                c.surprise = true
                return true
            end
        elseif scenario == 'throw' then
            function a:validateCondition()
                error('broken validator')
            end
        else
            function a:validateCondition()
                exists = false
                return true
            end
        end

        assert(not s:Apply(), scenario)
        assert(original.name ~= 'Unsaved' and original.rotation[1].conditions.surprise == nil)
        assert(s:HistoryState().canUndo, 'failed Apply lost the draft history')
    end
end)

test('failed no-op commands retain redo and a new edit discards it', function()
    local a = fixture()
    local s = assert(a:NewRotationEditSession(0, body()))
    assert(s:Command('UpdateStep', 'a', { disabled = true }))
    assert(s:Undo())
    assert(not s:Command('Remove', 'missing'))
    assert(s:Command('Move', 'a', { path = { 'rotation', 1, 'onTrue' }, parentId = 'b', index = 2 }))
    assert(s:HistoryState().canRedo)
    assert(s:Redo())
    assert(s:Snapshot().rotation[1].onTrue[1].disabled)
    assert(s:Undo())
    assert(s:Command('SetBodyField', 'name', 'New'))
    assert(not s:Redo())
end)

test('history has a 100-state bound and deleted identities stay reserved across undo', function()
    local a = fixture()
    local original = body()
    local s = assert(a:NewRotationEditSession(0, original))

    for i = 1, 120 do
        assert(s:Command('SetBodyField', 'name', 'Edit ' .. i))
    end

    local count = 0

    while s:Undo() do
        count = count + 1
    end

    assert(count == 100 and s:Snapshot().name == 'Edit 20')
    assert(s:Command('Remove', 'a'))
    assert(s:Undo())
    assert(s:Redo())
    local ids = { 'a', 'unique' }
    local n = 0

    local r = assert(a:NewRotationEditSession(0, original, {
        newId = function()
            n = n + 1
            return ids[n]
        end,
    }))

    assert(r:Command('Remove', 'a'))

    local ok, id = r:Command('Insert', { path = { 'rotation' }, index = 1 }, {
        type = 'spell',
        action = 403,
        conditions = {},
    })

    assert(ok and id == 'unique')
end)

test('legacy missing identities are private until Apply and count as unsaved normalization', function()
    local a = fixture()
    local original = body()
    original.rotation[1].onTrue[1].id = nil
    local s = assert(a:NewRotationEditSession(0, original))
    assert(s:IsDirty() and s:Snapshot().rotation[1].onTrue[1].id == 'new-1')
    assert(original.rotation[1].onTrue[1].id == nil)
    assert(s:Apply())
    assert(original.rotation[1].onTrue[1].id == 'new-1')
end)

test('history byte estimate evicts oldest states before retaining over eight MiB', function()
    local a = fixture()
    local original = body()
    original.rotation[1].conditions = {}
    -- Portable strings remain below 256KiB and the whole body below 1MiB.
    local s = assert(a:NewRotationEditSession(0, original))
    local payload = string.rep('x', 200000)

    for i = 1, 60 do
        assert(s:Command('SetCondition', 'a', { type = 'KNOWN', spell = 403, note = payload, version = i }))
    end

    local count = 0

    while s:Undo() do
        count = count + 1
    end

    assert(count > 0 and count < 60, 'byte bound failed to evict history states')
end)

test('semantic callbacks cannot reenter draft mutations or Cancel during Apply', function()
    local a = fixture()
    local original = body()
    local s = assert(a:NewRotationEditSession(0, original))
    assert(s:Command('SetBodyField', 'name', 'Expected'))

    function a:validateCondition()
        local ok, why = s:Command('SetBodyField', 'name', 'Reentrant')
        assert(not ok and why == 'rotation-editor-busy')
        assert(not s:Cancel() and not s:Undo())
        return true
    end

    assert(s:Apply())
    assert(original.name == 'Expected')
end)

test('large valid provenance reservations do not disable Undo or Redo after edits', function()
    local a = fixture()
    local reserved = {}

    for i = 1, 9990 do
        reserved[i] = 'historical-' .. i
    end

    local s = assert(a:NewRotationEditSession(0, body(), { reserved = reserved }))

    for i = 1, 20 do
        assert(s:Command('SetBodyField', 'name', 'Edit ' .. i))
    end

    local ok, why = s:Undo()
    assert(ok, why)
    assert(s:Snapshot().name == 'Edit 19')
    ok, why = s:Redo()
    assert(ok, why)
    assert(s:Snapshot().name == 'Edit 20')
end)

finish()
