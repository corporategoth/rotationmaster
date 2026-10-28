local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

test('unchanged private store seal checks avoid allocating schema tables on every read', function()
    local data = dofile('tests/fixtures/rotation_data.lua')()
    local addon = { RotationData = data }

    for _, path in ipairs({ 'Data/catalog.lua', 'Data/rotation_store.lua' }) do
        assert(loadfile(path))('rotationmaster', addon)
    end

    local reader

    local state = {
        version = 1,
        classes = {
            SHAMAN = {
                [0] = { Default = { body = { name = 'Fallback', switch = {}, rotation = {}, cooldowns = {} } } },
            },
        },
        characters = {},
        legacy = {},
    }

    assert(data.NewRotationStore({
        state = state,
        fallbackID = 'Default',
        bindInternalReader = function(value)
            reader = value
        end,
    }))

    local context = { class = 'SHAMAN', character = 'Player - Realm' }
    local address = { scope = 'class', class = 'SHAMAN', owner = 'SHAMAN', spec = 0, id = 'Default' }
    local ok, _, seal = reader:Read(address, context, function(record) return record.body.name end)
    assert(ok)
    -- Count interpreter allocations on both VMs, independent of JIT elimination.
    local compiled = jit and jit.status()

    if jit then
        jit.off()
        jit.flush()
    end

    collectgarbage('collect')
    collectgarbage('stop')
    local before = collectgarbage('count')

    for i = 1, 1000 do
        assert(reader:IsCurrent(seal, context))
    end

    local allocated = collectgarbage('count') - before
    collectgarbage('restart')

    if jit and compiled then
        jit.on()
    end

    assert(allocated < 200, 'schema bookkeeping allocated ' .. allocated .. ' KiB for 1000 unchanged reads')
    -- Reuse must still scan live keys; no validation result is cached.
    state.extra = true
    assert(not reader:IsCurrent(seal, context))
    state.extra = nil
    state.classes.SHAMAN[0].Default.extra = true
    assert(not reader:IsCurrent(seal, context))
end)

finish()
