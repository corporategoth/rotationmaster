-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local names = { 'getCached', 'getRetryCached' }

local hashes = {
    getCached = '8acb0039',
    getRetryCached = 'c1047351',
    getCachedInternal = '30f6c84c',
    packResults = 'a848589f',
    _G = 'd0fcf0a2',
    cacheHits = 'b6f8fd16',
    cacheMisses = 'fe8c5bd4',
    nilArgument = '27cc94b2',
    cachedResult = '6a545284',
}

local function id(name)
    return 'builtin:utils.lua:' .. name
end

local function fixture()
    local f = F.new()
    local a = f.addon
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

local function owner(a)
    return assert(a.Functions.cache, 'owned cache module missing')
end

local function pack(...)
    return { n = select('#', ...), ... }
end

test('cache owner preserves public aliases private IDs exact hashes and live source getters', function()
    local f, a = fixture()
    local c = owner(a)
    local old = a.builtinSourceModules['utils.lua']
    local current = assert(a.builtinSourceModules['Functions/cache.lua'])

    for name, hash in pairs(hashes) do
        local record = assert(a.builtinFunctions[id(name)])
        local source = a:CopySettingsData(record.source)

        if name == 'getCached' or name == 'getRetryCached' then
            assert(source.namespace == 'Functions.cache')
            source.namespace = 'utils'
        end

        assert(a:FunctionSourceHash(source) == hash, 'historical source contract changed: ' .. name)
        assert(a:ResolveFunctionBinding(id(name)) == old(name), 'old getter changed: ' .. name)

        if name ~= '_G' then
            assert(rawequal(old(name), current(name)), 'owner getter differs: ' .. name)
        end

        assert(not a.builtinFunctions['builtin:Functions/cache.lua:' .. name], 'duplicate new cache identity')
    end

    for _, name in ipairs(names) do
        assert(a[name] == c[name] and a:ResolveFunctionBinding(id(name)) == c[name])
        assert(a.builtinFunctions[id(name)].source.bindings.getCachedInternal == id('getCachedInternal'))
    end

    local bindings = a.builtinFunctions[id('getCachedInternal')].source.bindings
    local count = 0

    for alias, binding in pairs(bindings) do
        count = count + 1
        assert(binding == id(alias), 'internal capture changed')
    end

    assert(count == 6 and next(a.builtinFunctions[id('packResults')].source.bindings) == nil)

    assert(
        a.ReportCacheStats == c.ReportCacheStats and not a.builtinFunctions[id('ReportCacheStats')],
        'invented historical report ID'
    )

    assert(not f.env.Functions)
end)

test('native legacy canonical and compiled public calls share exact argument keys results and counter state', function()
    local _, a = fixture()
    local c = owner(a)
    local old = a.builtinSourceModules['utils.lua']
    local current = a.builtinSourceModules['Functions/cache.lua']
    a.debug = function() end
    a:ReportCacheStats()
    local copies = {}

    for _, name in ipairs(names) do
        assert(a:InstallCustomFunction('COPY_' .. name, a:CopySettingsData(a.builtinFunctions[id(name)].source)))
        copies[name] = assert(a:ResolveFunctionBinding('COPY_' .. name))
    end

    local calls = 0

    local fn = function(...)
        calls = calls + 1
        assert(select('#', ...) == 2 and select(1, ...) == nil and select(2, ...) == 9)
        return nil, 'reason', nil
    end

    local cache = {}

    for _, call in ipairs({
        a.getCached,
        c.getCached,
        copies.getCached,
        a.getRetryCached,
        c.getRetryCached,
        copies.getRetryCached,
    }) do
        local result = pack(call(cache, fn, nil, 9))
        assert(result.n == 3 and result[1] == nil and result[2] == 'reason' and result[3] == nil)
    end

    assert(calls == 1 and old('cacheHits') == 5 and old('cacheMisses') == 1)
    assert(current('cacheHits') == 5 and current('cacheMisses') == 1, 'state getter captured initial numeric aliases')

    assert(
        rawequal(old('nilArgument'), current('nilArgument'))
            and rawequal(old('cachedResult'), current('cachedResult'))
            and not rawequal(old('nilArgument'), old('cachedResult'))
    )

    local reports = {}

    a.debug = function(_, format, value)
        reports[#reports + 1] = { format, value }
    end

    c.ReportCacheStats(a)

    assert(
        #reports == 1 and reports[1][1] == 'Cache hit rate at %.02f%%' and math.abs(reports[1][2] - 100 * 5 / 6) < 1e-10
    )

    assert(old('cacheHits') == 0 and current('cacheMisses') == 0)
    local retries = 0

    local retry = function()
        retries = retries + 1
        return nil, nil
    end

    c.getRetryCached(cache, retry)
    copies.getRetryCached(cache, retry)
    assert(retries == 2 and cache[retry] == nil)
    a:ReportCacheStats()
    assert(old('cacheHits') == 0 and old('cacheMisses') == 0)
end)

test('historical public bundle requirements allow only the namespace ownership change', function()
    local _, a = fixture()
    owner(a)

    for _, name in ipairs(names) do
        local current = a.builtinFunctions[id(name)].source
        local old = a:CopySettingsData(current)
        old.namespace = 'utils'

        local bundle = assert(a:BuildFunctionBundle(
            'function',
            'LEGACY_' .. name,
            {
                description = 'Legacy cache consumer',
                args = {},
                returns = {},
                code = 'return helper(nil,function() return 7 end)',
                bindings = { helper = id(name) },
            },
            false
        ))

        for _, requirement in ipairs(bundle.requirements) do
            if requirement.id == id(name) then
                requirement.hash = hashes[name]
            end
        end

        local plan = assert(a:PlanFunctionBundleImport(bundle))
        assert(plan.valid, 'historical public cache hash rejected')
        assert(a:ApplyFunctionBundleImport(plan))
        assert(assert(a:ResolveFunctionBinding('LEGACY_' .. name))() == 7)

        for _, change in ipairs({
            function(s)
                s.code = s.code .. '\nreturn nil'
            end,
            function(s)
                s.bindings.getCachedInternal = id('packResults')
            end,
            function(s)
                s.args[1].type = 'string'
            end,
            function(s)
                s.description = s.description .. ' changed'
            end,
            function(s)
                s.namespace = 'arbitrary'
            end,
        }) do
            local changed = a:CopySettingsData(old)
            change(changed)

            for _, requirement in ipairs(bundle.requirements) do
                if requirement.id == id(name) then
                    requirement.hash = a:FunctionSourceHash(changed)
                end
            end

            assert(
                not assert(a:PlanFunctionBundleImport(bundle)).valid,
                'ownership migration relaxed source hash comparison'
            )
        end
    end
end)

local function badManifest(change)
    local env = setmetatable({
        dofile = function(path)
            local result = dofile(path)

            if path == 'tools/cache_ownership.lua' then
                change(result)
            end

            return result
        end,
        print = function() end,
    }, { __index = _G })

    local tool = assert(loadfile('tools/collect_builtin_sources.lua'))
    setfenv(tool, env)
    local ok, why = pcall(tool)

    assert(
        not ok and tostring(why):find('cache ownership', 1, true),
        'collector accepted wrong cache ownership: ' .. tostring(why)
    )
end

local function badGetter(alias, replacement)
    local env = setmetatable({
        dofile = function(path)
            local result = dofile(path)

            if path == 'tests/fixtures/addon.lua' then
                local new = result.new

                result.new = function(...)
                    local f = new(...)
                    local getters = f.addon.builtinSourceModules
                    local original = getters['utils.lua']

                    getters['utils.lua'] = function(name)
                        if name == alias then
                            return getters['Functions/cache.lua'](replacement)
                        end

                        return original(name)
                    end

                    return f
                end
            end

            return result
        end,
        print = function() end,
    }, { __index = _G })

    local tool = assert(loadfile('tools/collect_builtin_sources.lua'))
    setfenv(tool, env)
    local ok, why = pcall(tool)

    assert(
        not ok and tostring(why):find('cache ownership getter mismatch', 1, true),
        'collector accepted a mismapped live getter: ' .. tostring(why)
    )
end

test('collector rejects wrong function ownership capture identity and swapped sentinels', function()
    local f, a = fixture()
    owner(a)

    badManifest(function(m)
        m.bindings.getCachedInternal.bindingID = id('packResults')
    end)

    badManifest(function(m)
        m.bindings.getCachedInternal.captureBindings.nilArgument = id('cachedResult')
    end)

    badManifest(function(m)
        m.bindings.getCachedInternal.captureBindings._G = nil
    end)

    badManifest(function(m)
        m.bindings.nilArgument.bindingID = id('cachedResult')
        m.bindings.cachedResult.bindingID = id('nilArgument')
    end)

    badGetter('getCachedInternal', 'packResults')
    badGetter('nilArgument', 'cachedResult')
    badGetter('cachedResult', 'nilArgument')
end)

finish()
