-- The drift guard for the WowSims transport: the Lua converters hold to what the Rotation Master website's
-- converters make of the same real WowSims presets (tests/fixtures/wowsims/, from tools/wowsims_test_data.py):
-- the same step counts, the same grade and outcome per item, the same reason codes, the same conditions; and the
-- export of real Built In rotations is the same APL. The website's id data (its Built In ids and the simulators'
-- sources) is narrowed to the ids the fixtures mention; the condition-support check is the game's own, on a
-- simulated client of each edition.
local F = dofile('tests/fixtures/addon.lua')
local W = dofile('tests/fixtures/wowsims.lua')
local test, finish = F.suite()

local ns = W.loadModule()
local json = ns.json
local data = W.websiteData(ns)
local sources = W.decode(ns, W.dir .. 'SOURCES.json').files
local golden = W.decode(ns, W.dir .. 'golden.json')
local supports = {}
local function supportsFor(edition)
    if not supports[edition] then supports[edition] = W.supports(F, edition) end
    return supports[edition]
end
local function convert(text, options)
    options = options or {}
    local o = {mapping = ns.mapping, known = data.known, verifiers = data.verifiers, potions = data.potions}
    if options.edition then o.supports = supportsFor(options.edition) end
    for k, v in pairs(options) do o[k] = v end
    return ns.import.importWowsims(text, o)
end

local files = json.keys(sources)
assert(#files == 22, 'the fixture set changed: ' .. #files)
for _, file in ipairs(files) do
    test(file .. ': converts as the website converts it', function()
        local meta = sources[file]
        local r = convert(W.read(W.dir .. file), {edition = meta.edition, cls = meta.class})
        assert(r.ok, r.error and r.error.code)
        local differences = W.diff(W.digest(r), W.normalizeGolden(golden[file]))
        assert(#differences == 0, table.concat(differences, '\n'))
    end)
end

test('the real exports from wowsims.com: edition and class are found from the file', function()
    local real = W.decode(ns, W.dir .. 'real/golden.json')
    local realSources = W.decode(ns, W.dir .. 'real/SOURCES.json').files
    local count = 0
    for _, file in ipairs(json.keys(real)) do
        local meta = realSources[file]
        local text = W.read(W.dir .. 'real/' .. file)
        -- Which edition the file belongs to is what the website's golden says; the game's check follows it.
        local expected = W.normalizeGolden(real[file])
        local r = convert(text, {supports = supportsFor(expected.target.edition)})
        assert(r.ok, file .. ': ' .. tostring(r.error and r.error.code))
        assert(r.target.edition == meta.edition and r.target.cls == meta.class:upper(), file .. ' target ' .. r.target.edition .. ' ' .. tostring(r.target.cls))
        local differences = W.diff(W.digest(r), expected)
        assert(#differences == 0, file .. '\n' .. table.concat(differences, '\n'))
        count = count + 1
    end
    assert(count == 2)
end)

-- ---- the export -----------------------------------------------------------------------------------------------
local bodies = W.decode(ns, W.dir .. 'export-bodies.json')
local exportGolden = W.decode(ns, W.dir .. 'export-golden.json')
for _, id in ipairs(json.keys(bodies)) do
    test(id .. ': exports as the website exports it', function()
        local b = bodies[id]
        local edition = b.editions[1]
        local r = ns.export.exportWowsims({rotation = b.rotation, cooldowns = b.cooldowns},
            {mapping = ns.mapping, kinds = ns.kinds, ladders = data.ladders[edition], potions = data.potions[edition], edition = edition, cls = b.class})
        assert(r.ok)
        local apl = json.parse(json.encode(r.apl), W.BIG).value
        local summary = json.parse(json.encode(r.report.summary), W.BIG).value
        local sims = json.parse(json.encode(r.report.target.sims), W.BIG).value
        local expected = exportGolden[id]
        local differences = W.diff(apl, expected.apl, 'apl')
        W.diff(summary, expected.summary, 'summary', differences)
        W.diff(sims, expected.sims, 'sims', differences)
        assert(#differences == 0, table.concat(differences, '\n'))
    end)
end

-- ---- the round trip -------------------------------------------------------------------------------------------
local SKIP = {rank = true, notes = true, uuid = true, includeReactionTime = true, tag = true, maxOverlap = true, target = true}
local function canonVal(v)
    local s = tostring(v):match('^%s*(.-)%s*$')
    for _, suffix in ipairs({'ms', 's', 'm', '%'}) do
        if s:sub(-#suffix) == suffix then
            local body = s:sub(1, -#suffix - 1)
            if body:match('^%-?%d+%.?%d*$') or body:match('^%-?%.%d+$') then
                local n = tonumber(body)
                if suffix == '%' then return tostring(n) .. '%' end
                if suffix == 'ms' then return tostring(n / 1000) end
                if suffix == 'm' then return tostring(n * 60) end
                return tostring(n)
            end
        end
    end
    if s:match('^%-?%d+%.?%d*$') or s:match('^%-?%.%d+$') then return tostring(tonumber(s)) end
    return tostring(v)
end
-- An APL item in a form that ignores what the conversion legitimately changes: ranks and tags, notes, the
-- reaction-time flag, nested and/or, single-part and/or, the second spelling of the primary target, and the units
-- a number was written in.
local MAXOF = {maxMana = 'currentMana', maxRage = 'currentRage', maxEnergy = 'currentEnergy', maxFocus = 'currentFocus', maxRunicPower = 'currentRunicPower',
    maxHealth = 'currentHealth'}
local SWAPOP = {OpLt = 'OpGt', OpGt = 'OpLt', OpLe = 'OpGe', OpGe = 'OpLe', OpEq = 'OpEq', OpNe = 'OpNe'}
-- The one key of a table that has exactly one, else nil.
local function soleKey(t)
    if type(t) ~= 'table' then return nil end
    local key = next(t)
    if key == nil or next(t, key) ~= nil then return nil end
    return key
end
local norm
function norm(v)
    if json.isArray(v) then
        local out = {}
        for i, x in ipairs(v) do out[i] = norm(x) end
        return out
    end
    if not json.isObject(v) then return v end
    local out = {}
    for _, k0 in ipairs(json.keys(v)) do
        local x = v[k0]
        local skip = SKIP[k0]
        if k0 == 'targetUnit' and json.isObject(x) and (x.type == 'CurrentTarget' or (x.type == 'Target' and (x.index == nil or x.index == 0))) then skip = true end
        if not skip then
            local k = k0:gsub('WithReactionTime$', '')
            if k == 'const' and json.isObject(x) and x.val ~= nil then out[k] = {val = canonVal(x.val)} else out[k] = norm(x) end
        end
    end
    if out.type == 'Target' and (out.index == nil or out.index == 0) then
        local only = true
        for k in pairs(out) do if k ~= 'type' and k ~= 'index' then only = false end end
        if only then return {type = 'CurrentTarget'} end
    end
    for _, k in ipairs({'and', 'or'}) do
        local body = out[k]
        if type(body) == 'table' and body.vals then
            local vals = {}
            for _, x in ipairs(body.vals) do
                if type(x) == 'table' and type(x[k]) == 'table' and x[k].vals then for _, y in ipairs(x[k].vals) do vals[#vals + 1] = y end
                else vals[#vals + 1] = x end
            end
            if #vals == 1 then return vals[1] end
            out[k] = {vals = vals}
        end
    end
    -- A sequence of one action is that action.
    for _, k in ipairs({'sequence', 'strictSequence'}) do
        local seq = out[k]
        if type(seq) == 'table' and type(seq.actions) == 'table' and #seq.actions == 1 then
            local merged = {}
            for key, x in pairs(out) do if key ~= k then merged[key] = x end end
            for key, x in pairs(seq.actions[1]) do merged[key] = x end
            if out.condition and seq.actions[1].condition then
                merged.condition = norm(json.object({['and'] = json.object({vals = json.array({out.condition, seq.actions[1].condition})})}))
            end
            return merged
        end
    end
    if out.auraIsInactive then return {['not'] = {val = {auraIsActive = out.auraIsInactive}}} end
    -- A fraction written as a plain number (0.1) is the percent it means (10%) next to a reading that is a percent.
    local cmp = out.cmp
    if type(cmp) == 'table' and type(cmp.lhs) == 'table' and type(cmp.rhs) == 'table' then
        local lk = soleKey(cmp.lhs)
        local rc = type(cmp.rhs.const) == 'table' and cmp.rhs.const.val or nil
        if lk and lk:match('Percent$') and type(rc) == 'string' and rc:match('^%-?%d*%.?%d+$') and math.abs(tonumber(rc)) <= 1 then
            out.cmp = {op = cmp.op, lhs = cmp.lhs, rhs = {const = {val = canonVal(tostring(tonumber(rc) * 100) .. '%')}}}
            cmp = out.cmp
        end
        -- "What is missing from the maximum", in whichever of its spellings: R op (max - C), (R + C) op max, (max - R) op C.
        local op, lhs, rhs = cmp.op, cmp.lhs, cmp.rhs
        local function miss(resource, c, o)
            local max
            for m, r in pairs(MAXOF) do if r == resource then max = m end end
            return {cmp = {op = o, lhs = {math = {lhs = {[max] = {}}, op = 'OpSub', rhs = {[resource] = {}}}}, rhs = c}}
        end
        local mr = soleKey(rhs) == 'math' and rhs.math or nil
        local ml = soleKey(lhs) == 'math' and lhs.math or nil
        if mr and mr.op == 'OpSub' and MAXOF[soleKey(mr.lhs)] and soleKey(lhs) == MAXOF[soleKey(mr.lhs)] and soleKey(mr.rhs) == 'const' and SWAPOP[op] then
            return miss(soleKey(lhs), mr.rhs, SWAPOP[op])
        end
        if ml and ml.op == 'OpAdd' and MAXOF[soleKey(rhs)] and soleKey(ml.lhs) == MAXOF[soleKey(rhs)] and soleKey(ml.rhs) == 'const' and SWAPOP[op] then
            return miss(soleKey(ml.lhs), ml.rhs, SWAPOP[op])
        end
    end
    return out
end

test('round trip over the real presets: what the import graded exact comes back structurally equal', function()
    local exactChecked = 0
    for _, file in ipairs(files) do
        local meta = sources[file]
        local text = W.read(W.dir .. file)
        local imported = convert(text, {edition = meta.edition, cls = meta.class})
        assert(imported.ok, file)
        local exported = ns.export.exportWowsims({rotation = imported.body.rotation, cooldowns = {}},
            {mapping = ns.mapping, kinds = ns.kinds, ladders = data.ladders[meta.edition], potions = data.potions[meta.edition], edition = meta.edition, cls = meta.class})
        assert(exported.ok, file)
        local original = json.parse(text, W.BIG).value
        local out = json.parse(json.encode(exported.apl), W.BIG).value
        local step = 0
        for _, item in ipairs(imported.report.items) do
            if not item.hidden then
                local n = #item.became
                local first = step + 1
                step = step + n
                if not (item.prepull or n ~= 1 or item.outcome ~= 'enabled' or item.fidelity ~= 'exact' or not item.path:match('^priorityList%[%d+%]$')) then
                    local rec
                    for _, r in ipairs(exported.report.items) do if r.path == 'rotation[' .. first .. ']' then rec = r end end
                    assert(rec, file .. ' step ' .. first)
                    if rec.fidelity == 'exact' and rec.outcome == 'exported' then
                        local index = tonumber(item.path:match('%[(%d+)%]'))
                        local originalItem = original.priorityList[index]
                        local encoded = json.encode(originalItem)
                        if not (encoded:find('variableRef', 1, true) or encoded:find('variablePlaceholder', 1, true)) then
                            local back = out.priorityList[rec.at[1] + 1]
                            assert(back, file .. ' ' .. item.path)
                            local differences = W.diff(norm(json.object({action = back.action})), norm(json.object({action = originalItem.action})), file .. ' ' .. item.path)
                            assert(#differences == 0, table.concat(differences, '\n'))
                            exactChecked = exactChecked + 1
                        end
                    end
                end
            end
        end
        for _, item in ipairs(exported.report.items) do
            if item.fidelity ~= 'exact' and item.outcome ~= 'skipped' then assert(#item.reasons > 0, file .. ' ' .. item.path) end
        end
    end
    assert(exactChecked >= 80, 'exact items compared: ' .. exactChecked)
end)

finish()
