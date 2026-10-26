-- The WowSims transport as Rotation Master uses it: the two converters (import.lua, export.lua) with the id data
-- of this build (ids.lua) and what only the game knows (condition support, the client's own spell and item data)
-- passed in by the caller. This file is the last one the module's TOC loads; it hands the finished API to the
-- host (Core/transfer_formats.lua), which loads this add-on the first time a transfer window needs it.
local _, ns = ...
local json, import, export = ns.json, ns.import, ns.export

local ids = {}
ns.ids = ids
local cache = {}

local function expand(delta, into)
    local value = 0
    for step in delta:gmatch('%d+') do
        value = value + tonumber(step)
        into[value] = true
    end
end
local function simSets(src)
    local sets = {all = {spell = {}, item = {}}, classes = {}}
    local count = 0
    for cls, delta in pairs(src.spells) do
        local entry = {spell = {}, item = {}}
        expand(delta, entry.spell)
        sets.classes[cls] = entry
        for id in pairs(entry.spell) do sets.all.spell[id] = true; count = count + 1 end
    end
    return sets, count
end

local function entryOf(edition)
    local data = ns.idData[edition]
    if not data then return nil end
    local entry = cache[edition]
    if not entry then entry = {}; cache[edition] = entry end
    return entry, data
end
--- The simulator verifiers of one edition: {code = 'sim:<repo>', repo, ref, url, sets, spells, items}.
function ids.verifiers(edition)
    local entry, data = entryOf(edition)
    if not entry then return {} end
    if not entry.verifiers then
        local list = {}
        for _, src in ipairs(data.sources) do
            local sets, count = simSets(src)
            list[#list + 1] = {code = 'sim:' .. src.repo, repo = src.repo, ref = src.ref, url = src.url, sets = sets, spells = count, items = src.items}
        end
        entry.verifiers = list
    end
    return entry.verifiers
end
--- Every simulator list of the edition merged (what the votes for edition and class read).
function ids.known(edition)
    local entry = entryOf(edition)
    if not entry then return nil end
    if entry.known == nil then
        local sets = {}
        for _, v in ipairs(ids.verifiers(edition)) do sets[#sets + 1] = v.sets end
        entry.known = import.mergeSets(sets) or false
    end
    return entry.known or nil
end
--- Spell rank ladders: spell id -> {{id, rank}, ...} (the first simulator that lists the spell wins).
function ids.ladders(edition)
    local entry, data = entryOf(edition)
    if not entry then return {} end
    if not entry.ladders then
        local byId = {}
        for _, text in ipairs(data.ladders) do
            local ladder, position = {}, 0
            for part in text:gmatch('[^,]+') do
                position = position + 1
                local id, rank = part:match('^(%d+)/(%d+)$')
                if id then ladder[position] = {tonumber(id), tonumber(rank)} else ladder[position] = {tonumber(part), position} end
            end
            for _, pair in ipairs(ladder) do if not byId[pair[1]] then byId[pair[1]] = ladder end end
        end
        entry.ladders = byId
    end
    return entry.ladders
end
function ids.potions(edition)
    local data = ns.idData[edition]
    if not data then return {} end
    local out = {}
    for i, id in ipairs(data.manaPotions) do out[i] = id end
    return out
end
--- Drops what was decoded: a conversion decodes what it needs and leaves nothing behind.
function ids.release() cache = {} end

local api = {version = 1}
ns.api = api

local function gameVerifier(context)
    if not context.checkSpell and not context.checkItem then return nil end
    return {code = 'game', weak = true, check = function(_, id, kind)
        local check = kind == 'item' and context.checkItem or context.checkSpell
        if not check then return 'unchecked' end
        local ok, answer = pcall(check, id)
        if not ok or answer == nil then return 'unchecked' end
        return answer and 'known' or 'unknown'
    end}
end

--- Which editions this module converts for.
function api.editions()
    local out = {}
    for _, e in ipairs(ns.mapping.editionOrder) do out[#out + 1] = e end
    return out
end
function api.supportsEdition(edition) return ns.mapping.editions[edition] ~= nil end
function api.limits() return ns.mapping.limits end

--- Pasted WowSims text -> {ok = true, body, target, report} or {ok = false, error = {code, ...}, detected, report, link}.
--- context: {edition, cls, spec, supports(tree) -> {ok, reason, code}, checkSpell(id), checkItem(id), newId(),
--- enableApproximate, disableUnconfirmed, pick}.
function api.import(text, context)
    local game = gameVerifier(context)
    local verifiers = setmetatable({}, {__index = function(t, e)
        local list = {}
        for _, v in ipairs(ids.verifiers(e)) do list[#list + 1] = v end
        if game then list[#list + 1] = game end
        rawset(t, e, list)
        return list
    end})
    local known = setmetatable({}, {__index = function(t, e)
        local sets = ids.known(e)
        if sets == nil then return nil end
        rawset(t, e, sets)
        return sets
    end})
    local potions = setmetatable({}, {__index = function(t, e)
        local list = ids.potions(e)
        rawset(t, e, list)
        return list
    end})
    local ok, result = pcall(import.importWowsims, text, {mapping = ns.mapping, known = known, verifiers = verifiers, potions = potions,
        edition = context.edition, cls = context.cls, spec = context.spec, supports = context.supports,
        enableApproximate = context.enableApproximate, disableUnconfirmed = context.disableUnconfirmed,
        newId = context.newId, pick = context.pick})
    ids.release()
    if not ok then error(result, 0) end
    return result
end

--- A Rotation Master rotation body -> {ok = true, text (the settings JSON), aplText (the rotation only), apl, wrapper,
--- report} or {ok = false, error = {code}}. context: {edition, cls}.
function api.export(body, context)
    local ok, result = pcall(function()
        local r = export.exportWowsims(body, {mapping = ns.mapping, kinds = ns.kinds, ladders = ids.ladders(context.edition),
            potions = ids.potions(context.edition), edition = context.edition, cls = context.cls})
        if r.ok then
            r.text = export.stringify(r.wrapper) .. '\n'
            r.aplText = export.stringify(r.apl) .. '\n'
            r.compactText = json.encode(r.wrapper) .. '\n'
        end
        return r
    end)
    ids.release()
    if not ok then error(result, 0) end
    return result
end

--- Where the id data came from (for the report): per edition, the simulator sources it lists.
function api.sources(edition)
    local data = ns.idData[edition]
    local out = {}
    if data then for _, src in ipairs(data.sources) do out[#out + 1] = {repo = src.repo, ref = src.ref, url = src.url} end end
    return out
end

api.conditionText = import.conditionText
api.LEVELS = import.LEVELS
api.json = json
api.describeError = ns.render.describeError
api.renderImportReport = ns.render.importReport
api.renderExportReport = ns.render.exportReport
api.messages = ns.render.messages

local host = _G.RotationMasterTransferFormats
if type(host) == 'table' and type(host.Register) == 'function' then host.Register('wowsims', api) end
