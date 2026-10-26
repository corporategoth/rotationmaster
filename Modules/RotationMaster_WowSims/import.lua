-- WowSims APL -> Rotation Master rotation. A faithful Lua port of the website's wowsims/import.mjs, driven by the
-- same rule table (mapping.lua, generated from Data/wowsims/mapping.json), so both sides convert the same way.
-- Pure: no game API, no files; everything it needs comes in as arguments (the rule table, the id verifiers, a
-- condition-support check), so the game, the tests and the website read the same rules.
--
-- The input is text a person pasted: an APL (the preset files' `.apl.json`), a saved rotation, the in-game
-- exporter's JSON with a `rotation` key, or the simulator's full settings export (`player.rotation`). The output is
-- an RM rotation body as plain data (steps, conditions, the target edition and class) and a fidelity report that
-- says, item by item, what became of every part of the original. Nothing is dropped silently: a part with no
-- equivalent is reported, and a step that is not an exact copy is imported DISABLED.
--
-- Every reason in the report is a {code, level, params} the caller words in the reader's language.
local _, ns = ...
local json = ns.json
local import = {}
ns.import = import

local LEVELS = {'exact', 'approximate', 'lossy', 'unsupported'}
import.LEVELS = LEVELS
local LEVEL_RANK = {}
for index, level in ipairs(LEVELS) do LEVEL_RANK[level] = index end
local function worse(a, b) return LEVEL_RANK[b] > LEVEL_RANK[a] and b or a end
local function own(o, k) return type(o) == 'table' and rawget(o, k) ~= nil end
local isObj = json.isObject
local isArray = json.isArray
local function asList(v) if isArray(v) then return v end return {} end
local function isInteger(v) return type(v) == 'number' and v == math.floor(v) and v > -math.huge and v < math.huge end
local function numstr(n) if isInteger(n) then return string.format('%d', n) end return tostring(n) end
local function fail(code, params, extra)
    local error_ = {code = code}
    if params then for k, v in pairs(params) do error_[k] = v end end
    local result = {ok = false, error = error_}
    if extra then for k, v in pairs(extra) do result[k] = v end end
    return result
end
local function copy(v, depth)
    if type(v) ~= 'table' then return v end
    depth = depth or 0
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x, depth + 1) end
    return out
end
local function slice(list, count)
    local out = {}
    for i = 1, math.min(count, #list) do out[i] = list[i] end
    return out
end
local function trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end

-- ---- finding the APL in what was pasted ----------------------------------------------------------------------
local SPEC_NOT = {}
for _, key in ipairs({'name', 'race', 'class', 'equipment', 'consumes', 'consumables', 'bonusStats', 'buffs', 'talentsString',
    'glyphs', 'profession1', 'profession2', 'cooldowns', 'rotation', 'reactionTimeMs', 'channelClipDelayMs', 'inFrontOfTarget',
    'distanceFromTarget', 'healingModel', 'nibelungAverageCasts', 'level', 'faction', 'database', 'playerOptions',
    'enableItemSwap', 'itemSwap', 'miscOptions', 'apl', 'simple', 'talents', 'professions', 'gear', 'unit', 'id', 'realm',
    'version', 'spec'}) do SPEC_NOT[key] = true end
local function isApl(v)
    return isObj(v) and (isArray(v.priorityList) or isArray(v.prepullActions) or v.type == 'TypeAPL' or v.type == 3) and not own(v, 'player')
end
local function aplKind(t) return type(t) == 'string' and (t == 'TypeAuto' or t == 'TypeSimple' or t == 'TypeLegacy') end

--- Where the APL is and what the surroundings say: {ok, apl, shape, hints} or a failure.
function import.locateApl(value, options)
    options = options or {}
    local hints = {}
    local root = value
    if not isObj(root) then return fail('not-apl') end
    local player = isObj(root.player) and root.player or nil
    local function take(src)
        if not src then return end
        if type(src.class) == 'string' and not hints.classText then hints.classText = src.class end
        if type(src.race) == 'string' and not hints.race then hints.race = src.race end
        if type(src.talentsString) == 'string' and not hints.talents then hints.talents = src.talentsString:sub(1, 200) end
        if type(src.talents) == 'string' and not hints.talents then hints.talents = src.talents:sub(1, 200) end
        if type(src.spec) == 'string' and not hints.specText then hints.specText = src.spec end
        if type(src.level) == 'number' and isInteger(src.level) and not hints.level then hints.level = src.level end
        if type(src.version) == 'string' and not hints.version then hints.version = src.version:sub(1, 40) end
        if type(src.name) == 'string' and not hints.name then hints.name = src.name:sub(1, 120) end
    end
    take(root); take(player)
    -- Which settings key the export uses for consumables tells the simulator generation: Classic Era's and Wrath's
    -- older `consumes`, the newer simulators' `consumables`.
    if player then
        if own(player, 'consumables') then hints.consumablesKey = 'consumables' elseif own(player, 'consumes') then hints.consumablesKey = 'consumes' end
    end
    if player then
        local keys = {}
        for _, k in ipairs(json.keys(player)) do
            if not SPEC_NOT[k] and isObj(player[k]) then keys[#keys + 1] = k end
        end
        hints.playerKeys = slice(keys, 100)
    end
    local apl, shape
    if isApl(root) then apl = root; shape = 'apl'
    elseif player and isObj(player.rotation) and isApl(player.rotation) then apl = player.rotation; shape = 'settings'
    elseif isObj(root.rotation) and isApl(root.rotation) then
        apl = root.rotation; shape = (own(root, 'class') or own(root, 'spec')) and 'exporter' or 'saved'
    elseif isObj(root.apl) and isApl(root.apl) then apl = root.apl; shape = 'saved'
    elseif isObj(root.rotation) and isObj(root.rotation.rotation) and isApl(root.rotation.rotation) then apl = root.rotation.rotation; shape = 'saved'
    else
        -- The sim's browser storage: a map of saved rotation name -> {rotation: APL}.
        local named = {}
        for _, k in ipairs(json.keys(root)) do
            if isObj(root[k]) and isApl(root[k].rotation) then named[#named + 1] = k end
        end
        if #named > 0 then
            local chosen
            local pick = options.pick
            local picked = false
            if pick then for _, k in ipairs(named) do if k == pick then picked = true end end end
            if picked then chosen = pick elseif #named == 1 then chosen = named[1] end
            if not chosen then return fail('several-rotations', {names = slice(named, 20)}) end
            apl = root[chosen].rotation; shape = 'saved'; hints.name = chosen:sub(1, 120)
        end
    end
    if not apl then
        local kind
        if player and isObj(player.rotation) then kind = player.rotation.type
        elseif isObj(root.rotation) then kind = root.rotation.type else kind = root.type end
        if aplKind(kind) then return fail('not-an-apl', {type = kind}) end
        return fail('not-apl')
    end
    local kind = apl.type
    if aplKind(kind) then return fail('not-an-apl', {type = kind}) end
    if kind ~= nil and kind ~= 'TypeAPL' and kind ~= 3 and kind ~= 'TypeUnknown' and kind ~= 0 then
        return fail('not-an-apl', {type = tostring(kind)})
    end
    return {ok = true, apl = apl, shape = shape, hints = hints}
end

-- ---- spec, class, edition ------------------------------------------------------------------------------------
local function classOf(mapping, text)
    if type(text) ~= 'string' then return nil end
    if own(mapping.classes, text) then return mapping.classes[text] end
    local low = text:lower():gsub('[^a-z]', '')
    return own(mapping.classes, low) and mapping.classes[low] or nil
end
--- The RM specialization slug a spec word names for a class, or nil.
local function specSlug(mapping, cls, word)
    if not cls or type(word) ~= 'string' then return nil end
    local slugs = mapping.classSpecs[cls] or {}
    local low = word:lower():gsub('[^a-z-]', '')
    if own(mapping.specAliases, low) then
        low = mapping.specAliases[low]
        if low == false then return nil end
    end
    for _, slug in ipairs(slugs) do if slug == low then return low end end
    local squeezed = low:gsub('%-', '')
    for _, slug in ipairs(slugs) do if (slug:gsub('%-', '')) == squeezed then return slug end end
    return nil
end
local CLASS_WORDS = {Druid = true, Hunter = true, Mage = true, Paladin = true, Priest = true, Rogue = true, Shaman = true,
    Warlock = true, Warrior = true, Deathknight = true, DeathKnight = true, Monk = true}
-- A spec key such as elementalShaman or beastMasteryHunter: the class word at the end, the spec before it.
local function specFromKey(mapping, key)
    if type(key) ~= 'string' then return nil end
    local bare = classOf(mapping, key)
    if bare then return {cls = bare, slug = nil} end
    for i = 1, #key do
        local rest = key:sub(i)
        if CLASS_WORDS[rest] then
            local cls = classOf(mapping, rest)
            local prefix = key:sub(1, i - 1)
            return {cls = cls, slug = prefix ~= '' and specSlug(mapping, cls, prefix) or nil}
        end
    end
    return nil
end

-- ---- known ids -----------------------------------------------------------------------------------------------
local function setOf(...)
    local out = {}
    for i = 1, select('#', ...) do
        local list = select(i, ...)
        if type(list) == 'table' then for _, id in ipairs(list) do out[id] = true end end
    end
    return out
end
--- Known ids of one edition as sets: knownIds data {all={spell=,pet=,item=}, classes={CLASS={spell=,pet=,item=}}}.
function import.knownSets(data)
    if type(data) ~= 'table' then return nil end
    local all = type(data.all) == 'table' and data.all or {}
    local out = {all = {spell = setOf(all.spell, all.pet), item = setOf(all.item)}, classes = {}}
    for cls, entry in pairs(type(data.classes) == 'table' and data.classes or {}) do
        out.classes[cls] = {spell = setOf(entry.spell, entry.pet), item = setOf(entry.item)}
    end
    return out
end
--- known | other-class | unknown | unchecked for one id. An id several classes' lists share (racials) counts as known.
local function classifyId(sets, cls, id, kind)
    if not sets then return 'unchecked' end
    if kind == 'item' then return sets.all.item[id] and 'known' or 'unknown' end
    local own_ = sets.classes[cls]
    local any = sets.classes.ANY
    if (own_ and own_.spell[id]) or (any and any.spell[id]) then return 'known' end
    if not sets.all.spell[id] then return 'unknown' end
    -- UNSORTED: spells the simulator lists without saying whose they are. Only another class's own list can contradict the class.
    local holders = 0
    for c, entry in pairs(sets.classes) do
        if c ~= cls and c ~= 'UNSORTED' and entry.spell[id] then holders = holders + 1 end
    end
    return holders == 1 and 'other-class' or 'known'
end
import.classifyId = classifyId
--- The union of several id sets (knownSets results): what the votes for edition and class read.
function import.mergeSets(list)
    local sets = {}
    for _, s in ipairs(list) do if s then sets[#sets + 1] = s end end
    if #sets == 0 then return nil end
    local out = {all = {spell = {}, item = {}}, classes = {}}
    for _, s in ipairs(sets) do
        for id in pairs(s.all.spell) do out.all.spell[id] = true end
        for id in pairs(s.all.item) do out.all.item[id] = true end
        for cls, entry in pairs(s.classes) do
            local into = out.classes[cls]
            if not into then into = {spell = {}, item = {}}; out.classes[cls] = into end
            for id in pairs(entry.spell) do into.spell[id] = true end
            for id in pairs(entry.item) do into.item[id] = true end
        end
    end
    return out
end
--- One id against every source that can check it: verifiers is a list of {code, sets} or {code, check(cls, id, kind)}.
--- A `weak` verifier (the game client) confirms an id no source contradicts, but never overrides another class's
--- list. Returns {status = known|other-class|unknown|unchecked, via = {codes that confirmed it}, checked = {codes}}.
function import.verifyId(verifiers, cls, id, kind)
    if not verifiers or #verifiers == 0 then return {status = 'unchecked', via = {}, checked = {}} end
    local strong, weak, checked, other = {}, {}, {}, false
    for _, v in ipairs(verifiers) do
        local status
        if v.check then status = v.check(cls, id, kind) else status = classifyId(v.sets, cls, id, kind) end
        if status ~= 'unchecked' then checked[#checked + 1] = v.code end
        if status == 'known' then
            local list = v.weak and weak or strong
            list[#list + 1] = v.code
        elseif status == 'other-class' then other = true end
    end
    if #checked == 0 then return {status = 'unchecked', via = {}, checked = {}} end
    if #strong > 0 then
        local via = {}
        for _, code in ipairs(strong) do via[#via + 1] = code end
        for _, code in ipairs(weak) do via[#via + 1] = code end
        return {status = 'known', via = via, checked = checked}
    end
    if other then return {status = 'other-class', via = {}, checked = checked} end
    if #weak > 0 then return {status = 'known', via = weak, checked = checked} end
    return {status = 'unknown', via = {}, checked = checked}
end

-- Every spell/item id an APL mentions (for the votes), found without interpreting the APL.
local MODERN = {groups = true, valueVariables = true, groupReference = true, variableRef = true, variablePlaceholder = true}
local function mentionedIds(apl, limit)
    limit = limit or 5000
    local spells, items = {list = {}, set = {}}, {list = {}, set = {}}
    local ranks, modern, seen = false, false, 0
    local function add(bag, id)
        if not bag.set[id] then bag.set[id] = true; bag.list[#bag.list + 1] = id end
    end
    local function walk(v, depth)
        seen = seen + 1
        if depth > 80 or seen > 200000 then return end
        if isArray(v) then for _, x in ipairs(v) do walk(x, depth + 1) end return end
        if not isObj(v) then return end
        for _, k in ipairs(json.keys(v)) do
            local x = v[k]
            if MODERN[k] then modern = true end
            if k == 'rank' and type(x) == 'number' and x > 0 then ranks = true end
            if isObj(x) and (k == 'spellId' or k == 'auraId') and type(x.spellId) == 'number' and #spells.list < limit then add(spells, x.spellId) end
            if isObj(x) and (k == 'spellId' or k == 'auraId') and type(x.itemId) == 'number' and #items.list < limit then add(items, x.itemId) end
            walk(x, depth + 1)
        end
    end
    walk(apl, 0)
    return {spells = spells, items = items, ranks = ranks, modern = modern}
end

--- Which editions the APL could be for, with the evidence: {candidates, evidence, votes, exclusive}.
local function editionEvidence(mapping, sets, mentioned, hints)
    local names = mapping.editionOrder
    local candidates = {}
    for _, e in ipairs(names) do candidates[#candidates + 1] = e end
    local evidence = {}
    local function keep(predicate)
        local out = {}
        for _, e in ipairs(candidates) do if predicate(e) then out[#out + 1] = e end end
        candidates = out
    end
    if mentioned.ranks then keep(function(e) return mapping.editions[e].ranks end); evidence[#evidence + 1] = {code = 'ranks'} end
    if mentioned.modern then keep(function(e) return e ~= 'era' end); evidence[#evidence + 1] = {code = 'groups'} end
    if isInteger(hints.level) and hints.level > 0 then
        keep(function(e) return hints.level <= mapping.editions[e].maxLevel end)
        evidence[#evidence + 1] = {code = 'level', level = hints.level}
    end
    -- A race that did not exist yet: no Blood Elf or Draenei before TBC, no Goblin, Worgen or Pandaren before Cataclysm and Mists.
    if type(hints.race) == 'string' then
        local race = hints.race:gsub('^Race', ''):gsub('[^A-Za-z]', ''):lower()
        if race ~= '' then
            keep(function(e)
                if not own(mapping.races, e) then return true end
                for _, r in ipairs(mapping.races[e]) do if r == race then return true end end
                return false
            end)
            evidence[#evidence + 1] = {code = 'race', race = race}
        end
    end
    if hints.consumablesKey and mapping.consumablesKeys and own(mapping.consumablesKeys, hints.consumablesKey) then
        local allowed = mapping.consumablesKeys[hints.consumablesKey]
        keep(function(e) for _, a in ipairs(allowed) do if a == e then return true end end return false end)
        evidence[#evidence + 1] = {code = 'consumables', key = hints.consumablesKey}
    end
    -- Votes are counted when asked for (an edition's id lists are decoded on demand).
    local votes = setmetatable({}, {__index = function(t, e)
        local s = sets and sets[e]
        local n = 0
        if s then for _, id in ipairs(mentioned.spells.list) do if s.all.spell[id] then n = n + 1 end end end
        rawset(t, e, n)
        return n
    end})
    -- Ids only one of the remaining editions knows say more than ids they all share.
    local exclusive = setmetatable({}, {__index = function(t, e)
        local n = 0
        local s = sets and sets[e]
        if s then
            for _, id in ipairs(mentioned.spells.list) do
                if s.all.spell[id] then
                    local alone = true
                    for _, o in ipairs(candidates) do
                        if o ~= e then
                            local so = sets and sets[o]
                            if so and so.all.spell[id] then alone = false; break end
                        end
                    end
                    if alone then n = n + 1 end
                end
            end
        end
        rawset(t, e, n)
        return n
    end})
    return {candidates = candidates, evidence = evidence, votes = votes, exclusive = exclusive}
end

-- ---- conditions ----------------------------------------------------------------------------------------------
local BUDGET = {}
local TRUE, FALSE = {k = 'true'}, {k = 'false'}
local function dropNode() return {k = 'drop'} end

--- A constant as {num=, suffix=} or {bool=}; nil when it is neither.
local function parseConst(text)
    if type(text) == 'number' then
        if text ~= text or text == math.huge or text == -math.huge then return nil end
        return {num = text, suffix = ''}
    end
    if type(text) == 'boolean' then return {bool = text} end
    if type(text) ~= 'string' then return nil end
    local s = trim(text):lower()
    if s == 'true' then return {bool = true} end
    if s == 'false' then return {bool = false} end
    local suffix = ''
    local body = s
    if s:sub(-2) == 'ms' then suffix = 'ms'; body = s:sub(1, -3)
    elseif s:sub(-1) == 's' or s:sub(-1) == 'm' or s:sub(-1) == '%' then suffix = s:sub(-1); body = s:sub(1, -2) end
    if not (body:match('^%-?%d+$') or body:match('^%-?%d+%.%d+$') or body:match('^%-?%.%d+$')) then return nil end
    local num = tonumber(body)
    if not num or num ~= num or num == math.huge or num == -math.huge then return nil end
    return {num = num, suffix = suffix}
end
local UNIT_BOUNDS = {seconds = {0, 3600}, fraction = {0, 1}, count = {0, 9999}, raw = {-1e9, 1e9}}
-- A constant in the unit a numeric value is measured in: the number, nil when it cannot be that, false when it is a
-- number outside what RM stores.
local function constIn(parsed, unit)
    if not parsed or parsed.bool ~= nil then return nil end
    local v = parsed.num
    if unit == 'seconds' then
        if parsed.suffix == '%' then return nil end
        if parsed.suffix == 'ms' then v = v / 1000 elseif parsed.suffix == 'm' then v = v * 60 end
    elseif unit == 'fraction' then
        if parsed.suffix == '%' then v = v / 100 elseif parsed.suffix ~= '' or v > 1 then return nil end
    else
        if parsed.suffix ~= '' then return nil end
    end
    local bounds = UNIT_BOUNDS[unit] or UNIT_BOUNDS.raw
    if v >= bounds[1] and v <= bounds[2] then return v end
    return false
end
local function fold(op, a, b)
    if op == 'OpEq' then return a == b elseif op == 'OpNe' then return a ~= b elseif op == 'OpLt' then return a < b
    elseif op == 'OpLe' then return a <= b elseif op == 'OpGt' then return a > b elseif op == 'OpGe' then return a >= b end
    return nil
end
local function compact(v, limit)
    local s = json.encode(v)
    if #s > limit then return s:sub(1, limit - 1) .. '\226\128\166' end
    return s
end

local function makeConverter(ctx)
    local mapping = ctx.mapping
    local lim = mapping.limits
    local function note(code, level, params)
        local r = ctx.item.reasons
        if #r < 50 then r[#r + 1] = {code = code, level = level, params = params or {}} end
    end
    local function tick()
        ctx.item.nodes = ctx.item.nodes + 1
        if ctx.item.nodes > lim.expansion then error(BUDGET, 0) end
        ctx.totalNodes = ctx.totalNodes + 1
        if ctx.totalNodes > lim.total then
            ctx.stop = true
            local r = ctx.item.reasons
            r[#r + 1] = {code = 'too-complex', level = 'unsupported', params = {}}
            error(BUDGET, 0)
        end
    end
    local function kindOf(v)
        if not isObj(v) then return nil end
        for _, k in ipairs(json.keys(v)) do if k ~= 'uuid' then return k end end
        return nil
    end
    local function baseKind(k)
        if #k > 16 and k:sub(-16) == 'WithReactionTime' then return k:sub(1, -17) end
        return k
    end

    -- An ActionID's spell id: {id} or {fail}.
    local function spellOf(arg)
        if not isObj(arg) then return {fail = 'no-id'} end
        if type(arg.spellId) == 'number' and isInteger(arg.spellId) and arg.spellId > 0 and arg.spellId <= mapping.validation.idMax then
            return {id = arg.spellId}
        end
        if own(arg, 'itemId') then return {fail = 'item-id'} end
        if own(arg, 'otherId') then return {fail = 'other-id', other = tostring(arg.otherId)} end
        return {fail = 'no-id'}
    end
    local function unitName(ref, dflt)
        if ref == nil then return {unit = mapping.units[dflt]} end
        if not isObj(ref) then return {fail = 'bad'} end
        local utype = ref.type
        if type(utype) == 'number' then utype = mapping.unitTypes[utype + 1] end
        if utype == nil or utype == 'Unknown' then return {unit = mapping.units[dflt]} end
        if type(utype) ~= 'string' or not own(mapping.units, utype) then return {fail = utype == nil and 'unknown' or tostring(utype)} end
        local entry = mapping.units[utype]
        if type(entry) == 'string' then return {unit = entry} end
        local index = type(ref.index) == 'number' and ref.index or 0
        if own(entry, numstr(index)) then return {unit = entry[numstr(index)]} end
        return {fail = utype .. ' ' .. numstr(index)}
    end

    -- Resolves a template's directives against a value's arguments: {tree} or {fail={code, params}}.
    local function build(template, body, unitInfo)
        local out = {}
        for key, val in pairs(template) do
            if type(val) == 'table' then
                local inner = build(val, body, unitInfo)
                if inner.fail then return inner end
                out[key] = inner.tree
            elseif type(val) ~= 'string' or val:sub(1, 1) ~= '@' then
                out[key] = val
            else
                local parts = {}
                for part in (val .. ':'):gmatch('([^:]*):') do parts[#parts + 1] = part end
                local head = parts[1]
                if head == '@ranks' then
                    if ctx.ranks then out[key] = true end
                elseif head == '@item' then
                    out[key] = {ctx.itemId}
                elseif head == '@spell' then
                    local r = spellOf(body and body[parts[2]])
                    if r.fail then return {fail = {code = 'cond-id', params = {why = r.fail}}} end
                    out[key] = r.id
                elseif head == '@unit' then
                    if #parts == 1 and unitInfo then
                        out[key] = unitInfo.unit
                    else
                        local r = unitName(body and body[parts[2]], parts[3] or 'Self')
                        if r.fail then return {fail = {code = 'cond-unit', params = {unit = r.fail}}} end
                        out[key] = r.unit
                    end
                elseif head == '@table' then
                    local tbl = mapping.tables[parts[2]]
                    local raw = body and body[parts[3]]
                    local order = mapping.tableOrder and mapping.tableOrder[parts[2]]
                    local name
                    if type(raw) == 'number' then name = order and order[raw] or nil else name = raw end
                    if not tbl or type(name) ~= 'string' or rawget(tbl, name) == nil then
                        return {fail = {code = 'cond-value', params = {what = parts[3]}}}
                    end
                    out[key] = tbl[name]
                else
                    return {fail = {code = 'cond-value', params = {what = val}}}
                end
            end
        end
        return {tree = out}
    end

    -- ---- the value converter ----
    -- A converted value is {k = 'true'|'false'|'drop'|'cond'|'num'|'const'|'bool', ...}.
    local function lookupVariable(name, scope)
        if scope.refVars and scope.refVars[name] then return scope.refVars[name] end
        if scope.groupVars and scope.groupVars[name] ~= nil then return {value = scope.groupVars[name], scope = scope} end
        if ctx.rootVars[name] ~= nil then return {value = ctx.rootVars[name], scope = ctx.rootScope} end
        return nil
    end
    local convert, leaf, asBool, combine, compare, foldMissing
    local SWAP = {OpLt = 'OpGt', OpLe = 'OpGe', OpGt = 'OpLt', OpGe = 'OpLe', OpEq = 'OpEq', OpNe = 'OpNe'}

    function asBool(node)
        if node.k == 'const' then return node.truthy and TRUE or FALSE end
        if node.k == 'num' then
            -- A number used as a condition means "is not zero".
            local tree = copy(node.tree)
            tree.operator = 'NOTEQUALS'; tree.value = 0
            return {k = 'cond', tree = tree}
        end
        return node
    end
    function combine(kind, vals)
        local nodes = {}
        for i, v in ipairs(vals) do nodes[i] = asBool(v) end
        local isAnd = kind == 'and'
        local children, dropped = {}, false
        for _, n in ipairs(nodes) do
            if n.k == 'drop' then dropped = true
            elseif n.k == 'true' then if not isAnd then return TRUE end
            elseif n.k == 'false' then if isAnd then return FALSE end
            else
                local t = n.tree
                if t.type == (isAnd and 'AND' or 'OR') then for _, c in ipairs(t.value) do children[#children + 1] = c end
                else children[#children + 1] = t end
            end
        end
        if #children == 0 then
            if dropped then return dropNode() end
            return isAnd and TRUE or FALSE
        end
        if #children == 1 then return {k = 'cond', tree = children[1]} end
        return {k = 'cond', tree = {type = isAnd and 'AND' or 'OR', value = children}}
    end

    function convert(v, scope, depth)
        tick()
        if depth > lim.depth then error(BUDGET, 0) end
        if not isObj(v) or kindOf(v) == nil then note('cond-empty', 'lossy'); return dropNode() end
        local rawKind = kindOf(v)
        local kind = baseKind(rawKind)
        local body = v[rawKind]
        if kind == 'const' then
            local c = parseConst(isObj(body) and body.val or nil)
            if not c then return dropNode() end
            if c.bool ~= nil then return c.bool and {k = 'const', bool = true, truthy = true} or {k = 'const', bool = false, truthy = false} end
            return {k = 'const', parsed = c, truthy = c.num ~= 0}
        elseif kind == 'and' or kind == 'or' then
            local vals = {}
            local list = asList(isObj(body) and body.vals or nil)
            for i, x in ipairs(list) do vals[i] = convert(x, scope, depth + 1) end
            return combine(kind, vals)
        elseif kind == 'not' then
            local inner = asBool(convert(isObj(body) and body.val or nil, scope, depth + 1))
            if inner.k == 'true' then return FALSE end
            if inner.k == 'false' then return TRUE end
            if inner.k == 'drop' then return inner end
            return {k = 'cond', tree = {type = 'NOT', value = inner.tree}}
        elseif kind == 'cmp' then
            return compare(isObj(body) and body or {}, scope, depth)
        elseif kind == 'variableRef' or kind == 'variablePlaceholder' then
            local name = isObj(body) and type(body.name) == 'string' and body.name or nil
            local found
            if name ~= nil then
                if kind == 'variablePlaceholder' then found = scope.refVars and scope.refVars[name] or nil else found = lookupVariable(name, scope) end
            end
            if not found then note('cond-variable', 'lossy', {name = tostring(name):sub(1, 60)}); return dropNode() end
            local mark = name .. '\0' .. kind
            local stack = ctx.item.varStack
            local seenBefore = false
            for _, m in ipairs(stack) do if m == mark then seenBefore = true end end
            if #stack >= lim.variableDepth or seenBefore then
                note('cond-variable', 'lossy', {name = tostring(name):sub(1, 60)}); return dropNode()
            end
            stack[#stack + 1] = mark
            local ok, result = pcall(convert, found.value, found.scope or scope, depth + 1)
            stack[#stack] = nil
            if not ok then error(result, 0) end
            return result
        end
        if own(mapping.values, kind) then return leaf(kind, mapping.values[kind], isObj(body) and body or {}) end
        local why = own(mapping.unsupportedValues, kind) and mapping.unsupportedValues[kind] or 'unknown'
        note('cond-unsupported', 'lossy', {kind = kind, why = why})
        return dropNode()
    end

    function leaf(kind, entry, body)
        local template = entry.rm
        local unitInfo
        if entry.constTrue then
            -- Something Rotation Master decides for itself (it advises when you can act): always true.
            if entry.fidelity == 'approximate' then note('cond-approx', 'approximate', {kind = kind, note = entry.note or kind}) end
            return TRUE
        end
        -- A condition about an item (a trinket's cooldown) instead of a spell.
        if entry.itemRm then
            local arg = body[entry.itemArg or 'spellId']
            if isObj(arg) and isInteger(arg.itemId) and arg.itemId > 0 and arg.itemId <= mapping.validation.idMax then
                template = entry.itemRm; ctx.itemId = arg.itemId
            end
        end
        if entry.byUnit then
            local u = unitName(body[entry.byUnit.arg], entry.byUnit.default)
            if u.fail then note('cond-unit', 'lossy', {unit = u.fail}); return dropNode() end
            unitInfo = u
            template = (u.unit == 'player' or u.unit == 'pet') and entry.byUnit.friendly or entry.byUnit.hostile
        end
        if entry.self then
            local u = unitName(body[entry.self], 'Self')
            if u.fail or u.unit ~= 'player' then note('cond-unit', 'lossy', {unit = u.fail or u.unit}); return dropNode() end
        end
        local built = build(template, body, unitInfo)
        ctx.itemId = nil
        if built.fail then note(built.fail.code, 'lossy', built.fail.params); return dropNode() end
        -- A number's condition is checked with a placeholder comparison (the real operator and value come with the cmp).
        local sup
        if ctx.supports then
            if entry.t == 'num' then
                local probe = copy(built.tree)
                probe.operator = 'GREATERTHAN'; probe.value = 0
                sup = ctx.supports(probe)
            else sup = ctx.supports(built.tree) end
        end
        if sup and sup.ok == false then
            -- A client that hides a value from addons (mana, health, the combat log on Forever and Retail) is a different
            -- thing from a condition that simply is not offered there: the report says exactly what is hidden.
            if sup.code and mapping.restricted and own(mapping.restricted, sup.code) then
                note('cond-restricted', 'lossy', {type = built.tree.type, restricted = sup.code, edition = ctx.edition})
            else
                note('cond-unavailable', 'lossy', {type = built.tree.type, reason = sup.reason or sup.code or 'unsupported'})
            end
            return dropNode()
        end
        if entry.fidelity == 'approximate' then note('cond-approx', 'approximate', {kind = kind, note = entry.note or kind}) end
        if entry.t == 'num' then return {k = 'num', tree = built.tree, unit = entry.unit, kind = kind} end
        if entry['not'] then return {k = 'cond', tree = {type = 'NOT', value = built.tree}} end
        return {k = 'cond', tree = built.tree}
    end

    -- "Power against its maximum": rage >= max rage - 20, max mana - mana > 500, mana + 300 < max mana. Rotation
    -- Master compares a negative number with how much the unit is MISSING from its maximum, so these are one condition.
    function foldMissing(op, lhs, rhs, scope, depth)
        local maxOf = mapping.maxKinds
        if not maxOf or not isObj(lhs) or not isObj(rhs) then return nil end
        local maxValues = {}
        for _, v in pairs(maxOf) do maxValues[v] = true end
        local function plain(n)
            local c = kindOf(n) == 'const' and isObj(n.const) and parseConst(n.const.val) or nil
            if c and c.bool == nil and c.suffix == '' then return c.num end
            return nil
        end
        local function math_(n)
            if kindOf(n) == 'math' and isObj(n.math) then return n.math end
            return nil
        end
        local function noArgs(x) return not isObj(x) or #json.keys(x) == 0 end
        local function resource(n)
            local k = kindOf(n)
            if k and maxValues[k] and noArgs(n[k]) then return k end
            return nil
        end
        local function maxKind(n)
            local k = kindOf(n)
            if k and own(maxOf, k) and noArgs(n[k]) then return maxOf[k] end
            return nil
        end
        local target, operator, missing
        local ml, mr = math_(lhs), math_(rhs)
        if resource(lhs) and mr and mr.op == 'OpSub' and maxKind(mr.lhs) == resource(lhs) and plain(mr.rhs) ~= nil then
            -- R op (max - C)
            target = lhs; operator = SWAP[op]; missing = plain(mr.rhs)
        elseif ml and ml.op == 'OpSub' and maxKind(ml.lhs) and resource(ml.rhs) == maxKind(ml.lhs) and plain(rhs) ~= nil then
            -- (max - R) op C
            target = ml.rhs; operator = op; missing = plain(rhs)
        elseif ml and ml.op == 'OpAdd' and resource(ml.lhs) and maxKind(rhs) == resource(ml.lhs) and plain(ml.rhs) ~= nil then
            -- (R + C) op max
            target = ml.lhs; operator = SWAP[op]; missing = plain(ml.rhs)
        end
        if not target or not own(mapping.opNames, operator) or not (missing >= 0) then return nil end
        local r = convert(target, scope, depth + 1)
        if r.k ~= 'num' or r.unit ~= 'raw' then return nil end
        note('cond-missing', 'exact', {})
        local tree = copy(r.tree)
        tree.operator = mapping.opNames[operator]; tree.value = -missing
        return {k = 'cond', tree = tree}
    end
    function compare(body, scope, depth)
        local op = body.op
        if type(op) == 'number' then op = mapping.ops[op + 1] end
        if type(op) ~= 'string' or not own(mapping.opNames, op) then note('cond-cmp', 'lossy', {why = 'operator'}); return dropNode() end
        local folded = foldMissing(op, body.lhs, body.rhs, scope, depth)
        if folded then return folded end
        local l, r = convert(body.lhs, scope, depth + 1), convert(body.rhs, scope, depth + 1)
        if l.k == 'drop' or r.k == 'drop' then return dropNode() end
        if l.k == 'const' and r.k == 'const' then
            local a = l.parsed and l.parsed.num or (l.bool and 1 or 0)
            local b = r.parsed and r.parsed.num or (r.bool and 1 or 0)
            local res = fold(op, a, b)
            if res == nil then return dropNode() end
            return res and TRUE or FALSE
        end
        local numeric = l.k == 'num' and l or (r.k == 'num' and r or nil)
        if numeric and l.k == 'num' and r.k == 'num' then
            note('cond-cmp', 'lossy', {why = 'nonconst', left = l.kind, right = r.kind}); return dropNode()
        end
        if numeric then
            local other = numeric == l and r or l
            if other.k ~= 'const' or not other.parsed then note('cond-cmp', 'lossy', {why = 'operand'}); return dropNode() end
            local value = constIn(other.parsed, numeric.unit)
            if value == nil then note('cond-cmp', 'lossy', {why = 'unit', kind = numeric.kind}); return dropNode() end
            if value == false then note('cond-cmp', 'lossy', {why = 'range', kind = numeric.kind}); return dropNode() end
            local operator = mapping.opNames[op]
            if numeric == r then operator = mapping.opFlip[operator] end
            local tree = copy(numeric.tree)
            tree.operator = operator; tree.value = value
            return {k = 'cond', tree = tree}
        end
        -- A condition compared with true/false (or 1/0).
        local boolSide = l.k == 'const' and r or l
        local constSide = l.k == 'const' and l or r
        if constSide.k == 'const' and boolSide.k ~= 'const' and (op == 'OpEq' or op == 'OpNe') then
            local want
            if constSide.parsed then want = constSide.parsed.num ~= 0 else want = constSide.bool end
            local same
            if op == 'OpEq' then same = want else same = not want end
            local b = asBool(boolSide)
            if b.k == 'drop' then return b end
            if b.k == 'true' or b.k == 'false' then return (same == (b.k == 'true')) and TRUE or FALSE end
            if same then return b end
            return {k = 'cond', tree = {type = 'NOT', value = b.tree}}
        end
        note('cond-cmp', 'lossy', {why = 'operand'})
        return dropNode()
    end

    -- ---- actions ----
    -- conds: {value, scope} (an APL condition) or {tree} (an RM condition the converter adds) AND-ed.
    local function conditionOf(conds)
        local nodes = {}
        for _, c in ipairs(conds) do
            if c.tree then nodes[#nodes + 1] = {k = 'cond', tree = copy(c.tree)}
            elseif c.value ~= nil then nodes[#nodes + 1] = convert(c.value, c.scope, 0) end
        end
        if #nodes == 0 then return TRUE end
        return combine('and', nodes)
    end

    return {convert = convert, conditionOf = conditionOf, spellOf = spellOf, unitName = unitName, build = build, note = note, kindOf = kindOf}
end

-- A pre-pull action applies only before the fight: RM's "in combat" condition, negated.
local function outOfCombat() return {type = 'NOT', value = {type = 'COMBAT', unit = 'player'}} end
local function dedupe(list)
    local seen, out = {}, {}
    for _, r in ipairs(list) do
        local key = r.code .. json.encode(r.params)
        if not seen[key] then seen[key] = true; out[#out + 1] = r end
    end
    return out
end
-- The item ids a condition tree names.
local function treeItemIds(tree, out, depth)
    out = out or {}
    depth = depth or 0
    if not tree or depth > 64 then return out end
    if tree.type == 'AND' or tree.type == 'OR' then
        for _, c in ipairs(tree.value) do treeItemIds(c, out, depth + 1) end
        return out
    end
    if tree.type == 'NOT' then return treeItemIds(tree.value, out, depth + 1) end
    if type(tree.item) == 'table' then for _, id in ipairs(tree.item) do if type(id) == 'number' then out[#out + 1] = id end end end
    return out
end
-- The spell ids a condition tree names (a totem slot is not one).
local function treeSpellIds(tree, out, depth)
    out = out or {}
    depth = depth or 0
    if not tree or depth > 64 then return out end
    if tree.type == 'AND' or tree.type == 'OR' then
        for _, c in ipairs(tree.value) do treeSpellIds(c, out, depth + 1) end
        return out
    end
    if tree.type == 'NOT' then return treeSpellIds(tree.value, out, depth + 1) end
    if type(tree.spell) == 'number' and tree.type ~= 'TOTEM_REMAIN' and tree.type ~= 'TOTEM' then out[#out + 1] = tree.spell end
    return out
end

-- ---- compact text of an RM condition (for the report) ----------------------------------------------------------
local SYMBOL = {EQUALS = '=', NOTEQUALS = '!=', LESSTHAN = '<', LESSTHANOREQUALS = '<=', GREATERTHAN = '>', GREATERTHANOREQUALS = '>='}
local function conditionText(tree, depth)
    depth = depth or 0
    if not tree or depth > 40 then return '' end
    if tree.type == 'AND' or tree.type == 'OR' then
        local parts = {}
        for i, c in ipairs(tree.value) do parts[i] = conditionText(c, depth + 1) end
        return tree.type .. '(' .. table.concat(parts, ', ') .. ')'
    end
    if tree.type == 'NOT' then return 'NOT(' .. conditionText(tree.value, depth + 1) .. ')' end
    local parts = {tree.type}
    if tree.unit then parts[#parts + 1] = tree.unit end
    if type(tree.spell) == 'number' then parts[#parts + 1] = '#' .. numstr(tree.spell) end
    if tree.operator then
        parts[#parts + 1] = (SYMBOL[tree.operator] or tree.operator) .. ' ' .. (type(tree.value) == 'number' and numstr(tree.value) or tostring(tree.value))
    elseif tree.value ~= nil then
        parts[#parts + 1] = type(tree.value) == 'number' and numstr(tree.value) or tostring(tree.value)
    end
    return table.concat(parts, ' ')
end
import.conditionText = conditionText

-- ---- the conversion --------------------------------------------------------------------------------------------
local function policyDisables(policy, level, options)
    if level == 'exact' then return false end
    if level == 'approximate' then return policy.approximate == 'disable' and not options.enableApproximate end
    return true
end

--- Converts an APL (parsed JSON) for a chosen edition and class.
--- options: {mapping, edition, cls, known, verifiers, potions, supports(tree), newId(), enableApproximate, disableUnconfirmed}.
--- Returns {steps, items, summary, ids}.
function import.convertApl(apl, options)
    local mapping, edition, cls = options.mapping, options.edition, options.cls
    local lim = mapping.limits
    local verifiers = options.verifiers and options.verifiers[edition] or nil
    local sets = options.known and options.known[edition] or nil
    local ranks = mapping.editions[edition].ranks == true
    local rootVars = {}
    for _, v in ipairs(asList(apl.valueVariables)) do
        if isObj(v) and type(v.name) == 'string' and rootVars[v.name] == nil then rootVars[v.name] = v.value end
    end
    local groups = {}
    for _, g in ipairs(asList(apl.groups)) do
        if isObj(g) and type(g.name) == 'string' and groups[g.name] == nil then groups[g.name] = g end
    end
    local rootScope = {refVars = nil, groupVars = nil}
    local ctx = {mapping = mapping, edition = edition, cls = cls, ranks = ranks, supports = options.supports, rootVars = rootVars,
        rootScope = rootScope, item = nil, totalNodes = 0, entries = 0, ids = {}}
    local conv = makeConverter(ctx)
    local counter = 0
    local newId = options.newId or function() counter = counter + 1; return 'ws-' .. counter end
    local steps, items = {}, {}
    local function addItem(item)
        if #items < lim.reports then items[#items + 1] = item else ctx.truncated = (ctx.truncated or 0) + 1 end
    end
    -- The original of an item, cut short; computed once per item however often a group puts it in the list.
    local snippets = setmetatable({}, {__mode = 'k'})
    local function snippet(v)
        if type(v) ~= 'table' then return compact(v, lim.snippet) end
        if not snippets[v] then snippets[v] = compact(v, lim.snippet) end
        return snippets[v]
    end

    local function combineNodes(a, b)
        local function ok(n) return (n.k == 'cond' or n.k == 'true' or n.k == 'false' or n.k == 'drop') and n or TRUE end
        local na, nb = ok(a), ok(b)
        if na.k == 'false' or nb.k == 'false' then return FALSE end
        if na.k == 'drop' or nb.k == 'drop' then
            local keep = na.k == 'cond' and na or (nb.k == 'cond' and nb or nil)
            if keep then return {k = 'cond', tree = keep.tree, dropped = true} end
            return dropNode()
        end
        if na.k == 'true' then return nb end
        if nb.k == 'true' then return na end
        local value = {}
        for _, t in ipairs({na.tree, nb.tree}) do
            if t.type == 'AND' then for _, c in ipairs(t.value) do value[#value + 1] = c end else value[#value + 1] = t end
        end
        return {k = 'cond', tree = {type = 'AND', value = value}}
    end

    -- Decides fidelity and outcome, builds the steps, checks ids, and fills the report record.
    local function finish(record, created, handler)
        local reasons = dedupe(ctx.item.reasons)
        ctx.item.reasons = reasons
        local level, effective = 'exact', 'exact'
        for _, r in ipairs(reasons) do
            if LEVEL_RANK[r.level] then
                level = worse(level, r.level)
                if not r.benign then effective = worse(effective, r.level) end
            end
        end
        local made = {}
        for _, m in ipairs(created) do if m then made[#made + 1] = m end end
        if #made == 0 and handler and handler.handler == 'noop' then
            record.fidelity = handler.fidelity or 'lossy'; record.outcome = 'skipped'; record.reasons = reasons
            return
        end
        if #made == 0 then
            record.fidelity = 'unsupported'; record.outcome = 'skipped'; record.reasons = reasons
            local has = false
            for _, r in ipairs(reasons) do if r.level == 'unsupported' then has = true end end
            if not has then record.reasons[#record.reasons + 1] = {code = 'nothing-to-import', level = 'unsupported', params = {}} end
            return
        end
        if level == 'unsupported' then level = 'lossy' end
        if effective == 'unsupported' then effective = 'lossy' end
        -- Conditions: dropped parts show in the reasons already; always-false disables.
        local alwaysFalse = false
        for _, m in ipairs(made) do
            local node = m.condNode
            if m.extra and node.k ~= 'false' then
                node = combineNodes(node, {k = 'cond', tree = m.extra})
            end
            m.tree = node.k == 'cond' and node.tree or nil
            if node.k == 'false' then alwaysFalse = true end
        end
        -- Ids: every spell and item the item uses, against what is known for this edition and class.
        local flags = {}
        local checked = {}
        local used = {}
        for _, m in ipairs(made) do
            if m.type == 'item' then for _, id in ipairs(m.action) do used[#used + 1] = {id = id, kind = 'item'} end
            else used[#used + 1] = {id = m.action, kind = 'spell'} end
            for _, id in ipairs(treeSpellIds(m.tree)) do used[#used + 1] = {id = id, kind = 'spell'} end
            for _, id in ipairs(treeItemIds(m.tree)) do used[#used + 1] = {id = id, kind = 'item'} end
        end
        for _, u in ipairs(used) do
            local key = u.kind .. numstr(u.id)
            if not checked[key] then
                checked[key] = true
                local found
                if verifiers then found = import.verifyId(verifiers, cls, u.id, u.kind)
                else found = {status = classifyId(sets, cls, u.id, u.kind), via = {}, checked = {}} end
                local status = found.status
                if status == 'unknown' then
                    flags[#flags + 1] = 'unknown-id'
                    reasons[#reasons + 1] = {code = u.kind == 'item' and 'id-unknown-item' or 'id-unknown', level = 'check',
                        params = {id = u.id, sources = table.concat(found.checked, ' ')}}
                elseif status == 'other-class' then
                    flags[#flags + 1] = 'other-class-id'
                    reasons[#reasons + 1] = {code = 'id-other-class', level = 'check', params = {id = u.id}}
                end
                ctx.ids[#ctx.ids + 1] = {id = u.id, kind = u.kind, status = status, via = found.via}
            end
        end
        if alwaysFalse then reasons[#reasons + 1] = {code = 'always-false', level = 'exact', params = {}} end
        local policy = mapping.policy
        -- An id this build cannot confirm is flagged and, by default, the step stays enabled; an id that looks like
        -- another class's always disables, and the person can ask for every unconfirmed id to disable too.
        local function has(flag) for _, f in ipairs(flags) do if f == flag then return true end end return false end
        local idTrouble = (has('other-class-id') and policy.otherClassId == 'disable')
            or (has('unknown-id') and (policy.unknownId == 'disable' or options.disableUnconfirmed == true))
        local disabled = alwaysFalse or policyDisables(policy, effective, options) or idTrouble
        record.fidelity = level
        record.outcome = disabled and 'disabled' or 'enabled'
        local uniq, seenFlag = {}, {}
        for _, f in ipairs(flags) do if not seenFlag[f] then seenFlag[f] = true; uniq[#uniq + 1] = f end end
        record.flags = uniq
        record.reasons = reasons
        for _, m in ipairs(made) do
            if #steps >= lim.steps then
                record.reasons[#record.reasons + 1] = {code = 'step-limit', level = 'unsupported', params = {limit = lim.steps}}
                record.outcome = 'skipped'; record.fidelity = 'unsupported'; ctx.stop = true
                break
            end
            local step = {id = newId(), type = m.type, action = m.action}
            if ranks and m.type == 'spell' then step.ranked = false end
            if m.tree then step.conditions = m.tree end
            if disabled then step.disabled = true end
            steps[#steps + 1] = step
            record.became[#record.became + 1] = {type = step.type, action = step.action, disabled = disabled, conditions = conditionText(m.tree)}
        end
    end

    -- The steps an action makes: {type, action, condNode, extra}.
    local function doAction(handler, kind, action, entry)
        local scope, inherited = entry.scope, entry.inherited
        local body = isObj(action[kind]) and action[kind] or {}
        local conds = {}
        for _, c in ipairs(inherited) do conds[#conds + 1] = c end
        conds[#conds + 1] = {value = action.condition, scope = scope}
        local condNode = conv.conditionOf(conds)
        local function cast(sub, subKind)
            local node = isObj(sub) and sub[subKind] or nil
            local r = conv.spellOf(isObj(node) and node.spellId or nil)
            if r.fail == 'item-id' then
                local id = node.spellId.itemId
                if isInteger(id) and id > 0 and id <= mapping.validation.idMax then return {type = 'item', action = {id}} end
                conv.note('action-no-id', 'unsupported'); return nil
            end
            if r.fail == 'other-id' then
                -- The simulator's "resource potion" is whichever mana potion its consumables setting names; for a class that
                -- uses mana, Rotation Master's nearest is an item step with this edition's mana potions.
                local potions = options.potions and options.potions[edition] or nil
                local noMana = false
                for _, c in ipairs(mapping.noManaClasses or {}) do if c == cls then noMana = true end end
                if r.other == 'OtherActionResourcePotion' and potions and #potions > 0 and not noMana then
                    conv.note('action-potion', 'approximate', {edition = edition})
                    return {type = 'item', action = slice(potions, #potions)}
                end
                conv.note('action-other-id', 'unsupported', {id = r.other:sub(1, 60)}); return nil
            end
            if r.fail then conv.note('action-no-id', 'unsupported'); return nil end
            if node.target ~= nil then
                local u = conv.unitName(node.target, 'Self')
                if u.fail or (u.unit ~= 'player' and u.unit ~= 'target') then
                    conv.note('action-target', 'approximate', {unit = tostring(u.fail or u.unit)})
                end
            end
            return {type = 'spell', action = r.id}
        end
        if handler.handler == 'cast' then
            local level = handler.fidelity
            if handler.lossyIf then
                local used = {}
                for _, k in ipairs(handler.lossyIf) do
                    if body[k] ~= nil and body[k] ~= false then used[#used + 1] = k end
                end
                if #used > 0 then
                    conv.note('action-' .. handler.note, 'lossy', {parts = table.concat(used, ', ')}); level = nil
                end
            elseif level then conv.note('action-' .. handler.note, level, {}) end
            local made = cast(action, kind)
            if not made then return {} end
            local extra
            if handler.guard then
                local g = conv.build(handler.guard, body, nil)
                if g.fail then conv.note(g.fail.code, 'lossy', g.fail.params) else extra = g.tree end
            end
            made.condNode = condNode; made.extra = extra
            return {made}
        end
        if handler.handler == 'sequence' then
            local out = {}
            for _, sub in ipairs(asList(body.actions)) do
                if isObj(sub) then
                    local sk
                    for _, k in ipairs(json.keys(sub)) do if k ~= 'condition' then sk = k; break end end
                    if sk == 'castSpell' or sk == 'castFriendlySpell' or sk == 'channelSpell' then
                        local made = cast(sub, sk)
                        if made then
                            local subCond = sub.condition ~= nil and conv.conditionOf({{value = sub.condition, scope = scope}}) or TRUE
                            made.condNode = combineNodes(condNode, subCond); made.extra = nil
                            out[#out + 1] = made
                        end
                    else
                        conv.note('action-unsupported', 'lossy', {kind = tostring(sk), why = own(mapping.unsupportedActions, sk) and mapping.unsupportedActions[sk] or 'unknown'})
                    end
                end
            end
            conv.note('action-sequence', 'lossy', {count = #out})
            return out
        end
        return {}
    end

    -- Turns one APL list entry into steps and a report item.
    local doEntry
    function doEntry(entry)
        local item, path, scope, inherited, depth = entry.item, entry.path, entry.scope, entry.inherited, entry.depth
        -- Work is bounded however groups and references multiply the entries.
        ctx.entries = ctx.entries + 1
        if ctx.entries > lim.entries then
            if not ctx.stop then
                ctx.stop = true
                items[#items + 1] = {path = path, original = '', fidelity = 'unsupported', outcome = 'skipped',
                    reasons = {{code = 'item-limit', level = 'unsupported', params = {limit = lim.entries}}}, became = {}, flags = {}}
            end
            return
        end
        if ctx.stop then return end
        local record = {path = path, original = snippet(item), fidelity = 'exact', outcome = 'enabled', reasons = {}, became = {}, flags = {}}
        if entry.prepull then record.prepull = true end
        if not isObj(item) then
            record.fidelity = 'unsupported'; record.outcome = 'skipped'
            record.reasons[#record.reasons + 1] = {code = 'item-bad', level = 'unsupported', params = {}}
            addItem(record); return
        end
        if item.hide == true then
            record.outcome = 'skipped'; record.hidden = true
            record.reasons[#record.reasons + 1] = {code = 'hidden', level = 'exact', params = {}}
            addItem(record); return
        end
        local action = isObj(item.action) and item.action or json.object({})
        local seed = {}
        if entry.reasons then for _, r in ipairs(entry.reasons) do seed[#seed + 1] = {code = r.code, level = r.level, benign = r.benign, params = copy(r.params)} end end
        ctx.item = {reasons = seed, nodes = 0, varStack = {}}
        local created, handler, kind = {}, nil, nil
        local grouped = false
        local ok, err = pcall(function()
            for _, k in ipairs(json.keys(action)) do if k ~= 'condition' then kind = k; break end end
            if kind == nil then conv.note('action-empty', 'unsupported')
            elseif own(mapping.actions, kind) then handler = mapping.actions[kind]
            elseif own(mapping.unsupportedActions, kind) then conv.note('action-unsupported', 'unsupported', {kind = kind, why = mapping.unsupportedActions[kind]})
            else conv.note('action-unsupported', 'unsupported', {kind = kind, why = 'unknown'}) end
            if handler and handler.handler == 'group' then
                local ref = action[kind]
                local name = isObj(ref) and type(ref.groupName) == 'string' and ref.groupName or nil
                local group = name ~= nil and groups[name] or nil
                local cyclic = false
                if name then for _, s in ipairs(entry.stack or {}) do if s == name then cyclic = true end end end
                if not group then
                    conv.note('group-unknown', 'unsupported', {name = tostring(name):sub(1, 80)})
                elseif depth >= lim.groupDepth or cyclic then
                    conv.note('group-cycle', 'unsupported', {name = name:sub(1, 80)})
                else
                    local refVars = {}
                    for _, v in ipairs(asList(ref.variables)) do
                        if isObj(v) and type(v.name) == 'string' then refVars[v.name] = {value = v.value, scope = scope} end
                    end
                    local groupVars = {}
                    for _, v in ipairs(asList(group.variables)) do
                        if isObj(v) and type(v.name) == 'string' and groupVars[v.name] == nil then groupVars[v.name] = v.value end
                    end
                    local inner = {refVars = refVars, groupVars = groupVars}
                    local inheritedNext = {}
                    for _, c in ipairs(inherited) do inheritedNext[#inheritedNext + 1] = c end
                    inheritedNext[#inheritedNext + 1] = {value = action.condition, scope = scope}
                    local stack = {}
                    for _, s in ipairs(entry.stack or {}) do stack[#stack + 1] = s end
                    stack[#stack + 1] = name
                    for i, child in ipairs(asList(group.actions)) do
                        if not ctx.stop then
                            doEntry({item = child, path = path .. ' > ' .. name .. '[' .. i .. ']', scope = inner, inherited = inheritedNext,
                                depth = depth + 1, stack = stack, prepull = entry.prepull, reasons = entry.reasons})
                        end
                    end
                    grouped = true
                end
            elseif handler and handler.handler == 'noop' then
                -- Nothing to create, but not nothing to say: what Rotation Master does instead.
                conv.note('action-noop', handler.fidelity or 'lossy', {kind = kind, note = handler.note})
            elseif handler then
                created = doAction(handler, kind, action, entry)
            end
        end)
        if not ok then
            if err == BUDGET then
                local r = ctx.item.reasons
                r[#r + 1] = {code = 'too-complex', level = 'unsupported', params = {}}
                created = {}
            else
                ctx.item = nil
                error(err, 0)
            end
        end
        if grouped and ok then ctx.item = nil; return end
        finish(record, created, handler)
        ctx.item = nil
        addItem(record)
    end

    -- Pre-pull actions run before the fight in the simulator, at a time before the pull. Rotation Master has no
    -- timeline, but it has "not in combat": each becomes a step that only applies out of combat, ahead of the priority
    -- list, in the order the simulator runs them (earliest first). The seconds are the one thing dropped.
    local prepull = {}
    for i, p in ipairs(slice(asList(apl.prepullActions), 200)) do
        local raw
        if isObj(p) and isObj(p.doAtValue) and isObj(p.doAtValue.const) then raw = p.doAtValue.const.val end
        local parsed = parseConst(raw)
        local seconds = 0
        if parsed and parsed.bool == nil and parsed.num == parsed.num then
            seconds = parsed.num * (parsed.suffix == 'ms' and 0.001 or (parsed.suffix == 'm' and 60 or 1))
        end
        prepull[#prepull + 1] = {p = p, i = i, when = type(raw) == 'string' and raw:sub(1, 20) or '', seconds = seconds == seconds and seconds or 0}
    end
    table.sort(prepull, function(a, b)
        if a.seconds ~= b.seconds then return a.seconds < b.seconds end
        return a.i < b.i
    end)
    for _, entry in ipairs(prepull) do
        if ctx.stop then break end
        doEntry({item = entry.p, path = 'prepullActions[' .. entry.i .. ']', scope = rootScope, inherited = {{tree = outOfCombat()}},
            depth = 0, stack = {}, prepull = true,
            reasons = {{code = 'prepull-timing', level = 'lossy', benign = true, params = {time = entry.when}}}})
    end
    -- The priority list, in order.
    for i, item in ipairs(slice(asList(apl.priorityList), lim.items)) do
        if not ctx.stop then
            doEntry({item = item, path = 'priorityList[' .. i .. ']', scope = rootScope, inherited = {}, depth = 0, stack = {}})
        end
    end
    if #asList(apl.priorityList) > lim.items then
        addItem({path = 'priorityList', original = '', fidelity = 'unsupported', outcome = 'skipped',
            reasons = {{code = 'item-limit', level = 'unsupported', params = {limit = lim.items}}}, became = {}, flags = {}})
    end
    local summary = {items = 0, exact = 0, approximate = 0, lossy = 0, unsupported = 0, hidden = 0, prepull = 0, enabled = 0,
        disabled = 0, skipped = 0, steps = #steps, truncated = ctx.truncated or 0}
    for _, r in ipairs(items) do
        if r.hidden then summary.hidden = summary.hidden + 1
        else
            if r.prepull then summary.prepull = summary.prepull + 1 end
            summary.items = summary.items + 1
            summary[r.fidelity] = summary[r.fidelity] + 1
            summary[r.outcome] = summary[r.outcome] + 1
        end
    end
    local idSummary = {checked = 0, known = 0, unknown = {}, otherClass = {}, unchecked = 0, list = {}, bySource = {}, verifiers = {}}
    for _, v in ipairs(verifiers or {}) do
        idSummary.verifiers[#idSummary.verifiers + 1] = {code = v.code, repo = v.repo, ref = v.ref, url = v.url, spells = v.spells or 0, items = v.items or 0}
    end
    local seenIds, count = {}, 0
    for _, entry in ipairs(ctx.ids) do
        local key = entry.kind .. numstr(entry.id)
        if not seenIds[key] then
            seenIds[key] = true; count = count + 1
            if entry.status == 'known' then
                idSummary.known = idSummary.known + 1
                for _, code in ipairs(entry.via) do idSummary.bySource[code] = (idSummary.bySource[code] or 0) + 1 end
            elseif entry.status == 'unchecked' then idSummary.unchecked = idSummary.unchecked + 1
            elseif entry.status == 'other-class' then idSummary.otherClass[#idSummary.otherClass + 1] = entry.id
            else idSummary.unknown[#idSummary.unknown + 1] = entry.id end
            if #idSummary.list < 600 then idSummary.list[#idSummary.list + 1] = {id = entry.id, kind = entry.kind, status = entry.status, via = entry.via} end
        end
    end
    idSummary.checked = count
    return {steps = steps, items = items, summary = summary, ids = idSummary}
end

-- ---- the whole pipeline ----------------------------------------------------------------------------------------
--- Text a person pasted -> {ok=true, body, target, report} or {ok=false, error={code,...}, detected=}.
--- options: see convertApl, plus edition/cls/spec (the destination chosen, each optional), classEditions
--- ({CLASS={edition,...}}), pick (which saved rotation of several), supportsFor(edition, cls) or supports.
local function importText(input, options)
    local mapping = options.mapping
    local lim = mapping.limits
    local pasted = json.pastedText(input, lim)
    if not pasted.ok then return pasted end
    local parsed = json.parse(pasted.text, lim)
    if not parsed.ok then return parsed end
    local found = import.locateApl(parsed.value, {pick = options.pick})
    if not found.ok then return found end
    local apl, shape, hints = found.apl, found.shape, found.hints
    -- A preset with no actions at all (the simulator ships blank ones): say so rather than "nothing could be imported".
    if #asList(apl.priorityList) == 0 and #asList(apl.prepullActions) == 0 then return fail('empty-apl') end
    local sets = options.known or nil
    local mentioned = mentionedIds(apl)
    local ev = editionEvidence(mapping, sets, mentioned, hints)
    local detected = {shape = shape, via = pasted.via, editions = ev.candidates, evidence = ev.evidence, votes = ev.votes,
        exclusive = ev.exclusive, class = nil, spec = nil, race = hints.race, version = hints.version, name = hints.name}

    -- Class: what the file says, what the person chose.
    local specKey, keyed
    for _, key in ipairs(hints.playerKeys or {}) do
        local r = specFromKey(mapping, key)
        if r then specKey = key; keyed = r; break end
    end
    local declaredClass = classOf(mapping, hints.classText) or (keyed and keyed.cls) or nil
    local warnings = {}
    if hints.classText and not classOf(mapping, hints.classText) then
        warnings[#warnings + 1] = {code = 'class-unreadable', params = {text = tostring(hints.classText):sub(1, 40)}}
    end
    detected.class = declaredClass
    if options.cls and declaredClass and options.cls ~= declaredClass then
        return fail('class-mismatch', {declared = declaredClass, chosen = options.cls}, {detected = detected})
    end

    -- Edition: structural evidence first, then what the person chose.
    local edition, editionSource
    local function candidate(e) for _, c in ipairs(ev.candidates) do if c == e then return true end end return false end
    if options.edition then
        if not own(mapping.editions, options.edition) then
            return fail('edition-unsupported', {edition = tostring(options.edition):sub(1, 30)}, {detected = detected})
        end
        if not candidate(options.edition) then
            local codes = {}
            for _, e in ipairs(ev.evidence) do codes[#codes + 1] = e.code end
            return fail('edition-mismatch', {chosen = options.edition, evidence = codes, candidates = ev.candidates}, {detected = detected})
        end
        edition = options.edition; editionSource = 'chosen'
    elseif #ev.candidates == 1 then edition = ev.candidates[1]; editionSource = 'file'
    else
        local ranked = {}
        for _, e in ipairs(ev.candidates) do ranked[#ranked + 1] = e end
        local order = {}
        for i, e in ipairs(ranked) do order[e] = i end
        table.sort(ranked, function(a, b)
            if ev.votes[a] ~= ev.votes[b] then return ev.votes[a] > ev.votes[b] end
            return order[a] < order[b]
        end)
        local top, nextOne = ranked[1], ranked[2]
        local byExclusive = {}
        for _, e in ipairs(ev.candidates) do byExclusive[#byExclusive + 1] = e end
        table.sort(byExclusive, function(a, b)
            if ev.exclusive[a] ~= ev.exclusive[b] then return ev.exclusive[a] > ev.exclusive[b] end
            return order[a] < order[b]
        end)
        if sets and top and ev.votes[top] >= mapping.validation.foreignEditionIds and (not nextOne or ev.votes[nextOne] == 0) then
            edition = top; editionSource = 'ids'
        elseif sets and byExclusive[1] and ev.exclusive[byExclusive[1]] >= mapping.validation.exclusiveEditionIds
            and (byExclusive[2] == nil and 0 or ev.exclusive[byExclusive[2]]) == 0 then
            edition = byExclusive[1]; editionSource = 'ids'
        else return fail('edition-required', {candidates = ranked}, {detected = detected}) end
    end
    detected.edition = edition; detected.editionSource = editionSource
    -- The ids of other editions: an APL whose spells this edition does not know, but another does.
    if sets and ev.votes[edition] == 0 then
        for _, e in ipairs(ev.candidates) do
            if e ~= edition and ev.votes[e] >= mapping.validation.foreignEditionIds then
                return fail('edition-ids-mismatch', {chosen = edition, looksLike = e}, {detected = detected})
            end
        end
    end

    -- Class, by the person's choice, the file, or the ids.
    local cls = options.cls or declaredClass or nil
    local classSource = options.cls and 'chosen' or (declaredClass and 'file' or nil)
    local classVotes = {}
    local editionSets = sets and sets[edition] or nil
    if editionSets then
        for c, entry in pairs(editionSets.classes) do
            local n = 0
            for _, id in ipairs(mentioned.spells.list) do if entry.spell[id] then n = n + 1 end end
            classVotes[c] = n
        end
    end
    local function sortedVotes()
        local list = {}
        for c, n in pairs(classVotes) do list[#list + 1] = {c, n} end
        table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
        return list
    end
    if not cls then
        local ranked = {}
        for _, e in ipairs(sortedVotes()) do if e[2] > 0 and e[1] ~= 'ANY' and e[1] ~= 'UNSORTED' then ranked[#ranked + 1] = e end end
        if #ranked > 0 and ranked[1][2] >= 2 and (not ranked[2] or ranked[2][2] * 2 <= ranked[1][2]) then
            cls = ranked[1][1]; classSource = 'ids'
        else return fail('class-required', {}, {detected = detected}) end
    elseif editionSets then
        local ownVotes = classVotes[cls] or 0
        local foreign
        for _, e in ipairs(sortedVotes()) do
            if e[1] ~= cls and e[1] ~= 'ANY' and e[1] ~= 'UNSORTED' and e[2] > 0 then foreign = e; break end
        end
        -- Foreign: ids that only another class's lists use (not shared ones).
        local onlyOther, bestOther = 0, nil
        for _, id in ipairs(mentioned.spells.list) do
            local mine = editionSets.classes[cls]
            if not (mine and mine.spell[id]) then
                local holders = {}
                for c, e in pairs(editionSets.classes) do
                    if c ~= cls and c ~= 'ANY' and c ~= 'UNSORTED' and e.spell[id] then holders[#holders + 1] = c end
                end
                if #holders == 1 then
                    onlyOther = onlyOther + 1
                    if not bestOther or (classVotes[holders[1]] or 0) > (classVotes[bestOther] or 0) then bestOther = holders[1] end
                end
            end
        end
        if ownVotes == 0 and onlyOther >= mapping.validation.foreignClassIds then
            return fail('class-ids-mismatch', {chosen = cls, looksLike = bestOther or (foreign and foreign[1]) or ''}, {detected = detected})
        end
    end
    if not own(mapping.classSpecs, cls) then return fail('class-unknown', {cls = tostring(cls):sub(1, 30)}, {detected = detected}) end
    detected.class = cls; detected.classSource = classSource
    if options.classEditions and options.classEditions[cls] then
        local allowed = false
        for _, e in ipairs(options.classEditions[cls]) do if e == edition then allowed = true end end
        if not allowed then return fail('class-edition', {cls = cls, edition = edition}, {detected = detected}) end
    end

    -- Specialization: a different one is fine; it is recorded.
    local spec, specSource
    if type(options.spec) == 'string' and options.spec ~= '' then
        spec = specSlug(mapping, cls, options.spec); specSource = spec and 'chosen' or nil
    end
    if not spec then
        if keyed and keyed.cls == cls and keyed.slug then spec = keyed.slug; specSource = 'file'
        elseif hints.specText then
            local s = specSlug(mapping, cls, hints.specText)
            if s then spec = s; specSource = 'file' end
        end
    end
    detected.spec = spec; detected.specSource = specSource

    local supports = options.supportsFor and options.supportsFor(edition, cls) or options.supports
    local convertOptions = {}
    for k, v in pairs(options) do convertOptions[k] = v end
    convertOptions.edition = edition; convertOptions.cls = cls; convertOptions.supports = supports
    local converted = import.convertApl(apl, convertOptions)
    if not spec and (keyed or hints.specText) then warnings[#warnings + 1] = {code = 'spec-unreadable', params = {}} end
    local report = {detected = detected, summary = converted.summary, items = converted.items, ids = converted.ids, warnings = warnings}
    if #converted.steps == 0 then return fail('nothing-imported', {}, {detected = detected, report = report}) end
    return {ok = true, body = {tags = {'wowsims'}, rotation = converted.steps, cooldowns = {}},
        target = {edition = edition, cls = cls, spec = spec, specSource = specSource}, report = report}
end

-- The vote counts are computed when asked for (an edition's id lists are decoded on demand); what a result keeps is the
-- numbers, not the closures that would keep every decoded list alive.
local function snapshot(lazy, mapping)
    if type(lazy) ~= 'table' or getmetatable(lazy) == nil then return lazy end
    local out = {}
    for _, edition in ipairs(mapping.editionOrder) do
        local value = rawget(lazy, edition)
        if value ~= nil then out[edition] = value end
    end
    return out
end
function import.importWowsims(input, options)
    local result = importText(input, options)
    local detected = result.detected or (result.report and result.report.detected)
    if detected then
        detected.votes = snapshot(detected.votes, options.mapping)
        detected.exclusive = snapshot(detected.exclusive, options.mapping)
    end
    return result
end
