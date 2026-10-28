local F = dofile('tests/fixtures/addon.lua')
local make = dofile('tests/fixtures/rotation_data.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    local d, envelope, options = make()
    f.addon.RotationData = d
    f.load('Data/diff.lua')
    f.load('Data/import_session.lua')
    local objects = { legacy = envelope().body, modern = envelope() }

    local codec = {
        Decode = function(_, text)
            if not objects[text] then
                return nil, 'invalid-base64'
            end

            return {
                value = d.CopyData(objects[text]),
                kind = text == 'legacy' and 'legacy' or 'envelope',
                original = text,
            }
        end,
    }

    return d.NewImportSession(codec, options), objects, d
end

test('staging retains original text and scope without mutating or evaluating data', function()
    local session, objects = fixture()
    local candidate = assert(session:Stage('legacy'))
    assert(candidate.original == 'legacy' and candidate.scopeStatus == 'unknown' and candidate.validation.valid)
    assert(objects.legacy.applicability == nil)
    candidate.value.rotation[1].action = 999
    assert(session:GetCandidate().value.rotation[1].action == 403, 'candidate copy mutated staged body')
    candidate = assert(session:Stage('modern'))
    assert(candidate.scopeStatus == 'declared' and candidate.value.applicability.families[1] == 'tbc')
end)

test('invalid unsupported and unresolved imports stay inspectable but cannot be prepared', function()
    local session, objects = fixture()
    objects.legacy.rotation[1].action = '403'
    local candidate = assert(session:Stage('legacy'))
    assert(not candidate.validation.valid)
    local value, why = session:GetReady(candidate.token)
    assert(not value and why == 'invalid-import')
    objects.legacy.rotation[1].action = 403
    objects.legacy.future = { foo = 42 }
    candidate = assert(session:Stage('legacy'))
    assert(candidate.value.future.foo == 42 and not candidate.validation.supported)
    value, why = session:GetReady(candidate.token)
    assert(not value and why == 'unsupported-import')
    objects.legacy.future = nil
    objects.legacy.rotation[1].conditions = { type = 'FUTURE_CONDITION' }
    candidate = assert(session:Stage('legacy'))
    value, why = session:GetReady(candidate.token)
    assert(not value and why == 'unresolved-import')
end)

test('preview compares the incoming body without applying it and stale tokens are refused', function()
    local session, objects, d = fixture()
    local candidate = assert(session:Stage('legacy'))
    local own = d.CopyData(objects.legacy)
    own.rotation[1].action = 8042
    local comparison = assert(session:Compare(candidate.token, own))

    assert(
        comparison.diff.valid
            and comparison.left.body.rotation[1].action == 8042
            and comparison.right.body.rotation[1].action == 403
    )

    assert(own.rotation[1].action == 8042)
    comparison.right.body.rotation[1].action = 999
    assert(session:GetReady(candidate.token).body.rotation[1].action == 403)
    session:Clear()
    local ready, why = session:GetReady(candidate.token)
    assert(not ready and why == 'stale-import')
    candidate = assert(session:Stage('legacy'))
    assert(not session:Stage('bad'))
    ready, why = session:GetReady(candidate.token)
    assert(not ready and why == 'stale-import')
end)

test('future envelopes without a recognized body remain inspectable without a fabricated graph', function()
    local session, objects = fixture()
    objects.modern.schemaVersion = 2
    objects.modern.body = nil
    local candidate = assert(session:Stage('modern'))
    assert(candidate.value.schemaVersion == 2 and not candidate.validation.supported)
    local graph, why = session:Compare(candidate.token, { rotation = {} })
    assert(not graph and why == 'no-previewable-body')
end)

finish()
