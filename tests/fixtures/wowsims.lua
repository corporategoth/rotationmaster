-- Shared by the WowSims transport suites: the load-on-demand module loaded outside the game, the website's
-- fixtures (tests/fixtures/wowsims/, from tools/wowsims_test_data.py), the verifier data the website's golden
-- outputs were made with, and a condition-support check that is the game's own (Core/condition_support.lua) on a
-- simulated client of each edition.
local M = {}
local DIR = 'tests/fixtures/wowsims/'
M.dir = DIR
local MODULE = 'Modules/RotationMaster_WowSims/'

function M.read(path)
    local handle = assert(io.open(path, 'rb'))
    local text = handle:read('*a')
    handle:close()
    return text
end

local BIG = {text = 1e9, base64 = 1e9, depth = 200, nodes = 1e9, string = 1e9, array = 1e9, keys = 1e9}
M.BIG = BIG

--- A fresh copy of the module's namespace with every module file loaded (the order of its TOC).
function M.loadModule(options)
    options = options or {}
    local ns = {}
    for _, name in ipairs({'json', 'mapping', 'ids', 'import', 'export', 'render', 'api'}) do
        local chunk = assert(loadfile(MODULE .. name .. '.lua'))
        chunk('RotationMaster_WowSims', ns)
    end
    return ns
end

function M.decode(ns, path)
    local result = ns.json.parse(M.read(path), BIG)
    assert(result.ok, path .. ': ' .. tostring(result.error and result.error.code))
    return result.value
end

-- The website's verifiers: Rotation Master's Built In ids ("rm") and each simulator's source ("sim:<repo>"), narrowed to
-- the ids the fixtures mention (tests/fixtures/wowsims/ids-subset.json).
function M.websiteData(ns)
    local data = M.decode(ns, DIR .. 'ids-subset.json')
    local import = ns.import
    local known, verifiers, potions, ladders = {}, {}, {}, {}
    for _, edition in ipairs(ns.mapping.editionOrder) do
        local d = data[edition]
        local list = {{code = 'rm', sets = import.knownSets(d.rm)}}
        for _, src in ipairs(d.sims) do
            local sets = {all = {spell = {}, item = {}}, classes = {}}
            for _, id in ipairs(src.items) do sets.all.item[id] = true end
            local count = 0
            for _, cls in ipairs(ns.json.keys(src.spells)) do
                local entry = {spell = {}, item = {}}
                sets.classes[cls] = entry
                for _, id in ipairs(src.spells[cls]) do entry.spell[id] = true; sets.all.spell[id] = true; count = count + 1 end
            end
            list[#list + 1] = {code = 'sim:' .. src.repo, repo = src.repo, ref = src.ref, url = src.url, sets = sets, spells = count, items = src.itemsTotal}
        end
        verifiers[edition] = list
        local all = {}
        for _, v in ipairs(list) do all[#all + 1] = v.sets end
        known[edition] = import.mergeSets(all)
        potions[edition] = {}
        for _, p in ipairs(d.potions) do potions[edition][#potions[edition] + 1] = p end
        local byId = {}
        for _, l in ipairs(d.ladders) do
            local ladder = {}
            for _, pair in ipairs(l) do ladder[#ladder + 1] = {pair[1], pair[2]} end
            for _, pair in ipairs(ladder) do if not byId[pair[1]] then byId[pair[1]] = ladder end end
        end
        ladders[edition] = byId
    end
    return {known = known, verifiers = verifiers, potions = potions, ladders = ladders}
end

-- WoW project ids of the simulated clients (tests/fixtures/client_api.lua).
M.PRODUCT = {retail = 1, era = 2, tbc = 5, progression = 19, forever = 18}
-- LE_EXPANSION_LEVEL_CURRENT of each (Mists is expansion 4).
M.EXPANSION = {retail = 11, era = 0, tbc = 1, progression = 4, forever = 0}

-- Defines every game API the condition requirements name that the simulated client has (the client fixture lists
-- what each client lacks), so Core/condition_support.lua answers as it would on that client.
local function stubApis(env, requirements, absent)
    local function define(path)
        if absent[path] then return end
        local parent, last = env, nil
        local parts = {}
        for part in path:gmatch('[^.]+') do parts[#parts + 1] = part end
        for index = 1, #parts - 1 do
            local child = rawget(parent, parts[index])
            if type(child) ~= 'table' then child = {}; rawset(parent, parts[index], child) end
            parent = child
        end
        last = parts[#parts]
        if rawget(parent, last) == nil then rawset(parent, last, function() end) end
    end
    for _, requirement in pairs(requirements) do
        for _, entry in ipairs(requirement) do
            if type(entry) == 'table' then for _, path in ipairs(entry) do define(path) end end
        end
    end
end

M.stubApis = stubApis

--- The game's own condition-support check on a simulated client of the edition: tree -> {ok, reason, code}.
function M.supports(F, edition)
    local product = M.PRODUCT[edition]
    local f = F.new(product, M.EXPANSION[edition])
    local a = f.addon
    f.load('Platform/client.lua')
    f.load('Core/condition_support.lua')
    local api = dofile('tests/fixtures/client_api.lua')
    local name = api.byProject[product]
    stubApis(f.env, a.conditionRequirements, api.absent(name, name ~= 'retail' and name ~= 'forever'))
    return function(tree)
        local reason = a:GetConditionSupport(tree.type, {}, tree)
        if reason then return {ok = false, reason = reason, code = reason} end
        return {ok = true}
    end, f
end

-- Condition definitions that accept every field the converter writes (a stand-in for the game's real schemas, which
-- tests/wowsims_real_catalog.lua uses): one per condition type the rule table can produce.
function M.permissiveConditions(ns)
    local union = {'string', 'number', 'boolean', 'number[]'}
    local fields = {}
    local function visit(tree)
        if type(tree) ~= 'table' then return end
        if type(tree.type) == 'string' and tree.type ~= 'NOT' and tree.type ~= 'AND' and tree.type ~= 'OR' then
            local entry = fields[tree.type] or {}
            fields[tree.type] = entry
            for key in pairs(tree) do if key ~= 'type' then entry[key] = union end end
            entry.operator = union
            entry.value = union
        end
        for _, child in pairs(tree) do visit(child) end
    end
    for _, value in pairs(ns.mapping.values) do
        visit(value.rm); visit(value.itemRm)
        if value.byUnit then visit(value.byUnit.friendly); visit(value.byUnit.hostile) end
    end
    for _, action in pairs(ns.mapping.actions) do visit(action.guard) end
    visit({type = 'COMBAT', unit = 'player'})
    local definitions = {}
    for tag, set in pairs(fields) do definitions[tag] = {fields = set, requiredFields = {}} end
    return definitions
end

local function sorted(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) if type(a) == type(b) then return a < b end return type(a) == 'number' end)
    return keys
end
--- Differences between two plain values, as lines.
function M.diff(a, b, path, out)
    path = path or ''
    out = out or {}
    if type(a) ~= type(b) then out[#out + 1] = path .. ': ' .. type(a) .. ' vs ' .. type(b); return out end
    if type(a) ~= 'table' then
        if a ~= b then out[#out + 1] = path .. ': ' .. tostring(a) .. ' vs ' .. tostring(b) end
        return out
    end
    for _, k in ipairs(sorted(a)) do M.diff(a[k], b[k], path .. '.' .. tostring(k), out) end
    for _, k in ipairs(sorted(b)) do if a[k] == nil then out[#out + 1] = path .. '.' .. tostring(k) .. ': missing' end end
    return out
end

--- What a conversion did, small and stable (the website's digest, tests/support/wowsims.mjs): the target, the counts,
--- and per item its fidelity, outcome, reason codes and steps.
function M.digest(result)
    local report = result.report
    local items = {}
    for _, item in ipairs(report.items) do
        local codes = {}
        for _, reason in ipairs(item.reasons) do codes[#codes + 1] = reason.code end
        local row = {item.path, item.fidelity, item.outcome, table.concat(codes, ',')}
        for _, became in ipairs(item.became) do
            -- A Stop step has no action; the website's digest prints that as JavaScript's undefined.
            local action = became.action == nil and 'undefined' or type(became.action) == 'table' and table.concat(became.action, '+') or string.format('%d', became.action)
            row[#row + 1] = became.type .. ':' .. action .. (became.disabled and ':off' or '') .. ' ' .. (became.conditions or '')
        end
        items[#items + 1] = row
    end
    local target = {edition = result.target.edition, cls = result.target.cls}
    if result.target.spec then target.spec = result.target.spec; target.specSource = result.target.specSource end
    return {target = target, summary = report.summary, ids = {known = report.ids.known, unknown = #report.ids.unknown, otherClass = #report.ids.otherClass}, items = items}
end

--- The website's golden entry in the same shape (its null spec is simply absent here).
function M.normalizeGolden(entry)
    local target = {edition = entry.target.edition, cls = entry.target.cls}
    if entry.target.spec then target.spec = entry.target.spec; target.specSource = entry.target.specSource end
    return {target = target, summary = entry.summary, ids = entry.ids, items = entry.items}
end

return M
