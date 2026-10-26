-- Rotation Master rotation -> WowSims APL. A faithful Lua port of the website's wowsims/export.mjs: the inverse of
-- import.lua, reading the `export` section of the same rule table (mapping.lua). Pure: no game API, no files; what it
-- needs besides the rule table (the simulators' APL kinds, the spell rank ladders, the mana potions) comes in as
-- arguments.
--
-- The input is a rotation body as plain data: {rotation={step...}, cooldowns={step...}}, a step being
-- {id, type, action, conditions, disabled, mode, onTrue, onFalse, ...} with conditions as plain trees
-- ({type='AND', value={...}} / {type='BUFF', unit=..., spell=...}). The output is an APLRotation as proto-JSON data
-- (camelCase, what the simulator's preset files hold), the minimal settings wrapper around it, and a fidelity report
-- that says, step by step, what became of it: exact, approximate (a close substitute), lossy (a part left out) or not
-- representable (the step is not exported). Nothing is dropped silently.
--
-- What the structure becomes:
--  * a branch is flattened: each arm's steps carry the branch condition (or its negation) as an extra condition;
--  * a Stop with conditions C adds NOT C to every step after it; an unconditional Stop ends the list;
--  * the Cooldowns list (independent in Rotation Master) becomes the first items of the priority list;
--  * a step that applies only out of combat becomes a pre-pull action (the seconds are assumed);
--  * a condition with no APL counterpart is left out of its AND (the step fires more often) and listed; one that
--    cannot be left out of an OR makes the whole OR unknown, which is left out the same way.
local _, ns = ...
local json = ns.json
local export = {}
ns.export = export

local LEVELS = {'exact', 'approximate', 'lossy', 'unsupported'}
local LEVEL_RANK = {}
for index, level in ipairs(LEVELS) do LEVEL_RANK[level] = index end
local function worse(a, b) return LEVEL_RANK[b] > LEVEL_RANK[a] and b or a end
local function own(o, k) return type(o) == 'table' and rawget(o, k) ~= nil end
local function isInteger(v) return type(v) == 'number' and v == math.floor(v) and v > -math.huge and v < math.huge end
local function numstr(n) if isInteger(n) then return string.format('%d', n) end return tostring(n) end
local function copy(v)
    if type(v) ~= 'table' then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x) end
    return out
end

local TRUE, FALSE, DROP = {k = 'true'}, {k = 'false'}, {k = 'drop'}
-- JS String(Number(n.toFixed(3))): at most three decimals, none when they are zero.
local function trim(n)
    local s = string.format('%.3f', n)
    s = s:gsub('0+$', ''):gsub('%.$', '')
    if s == '-0' then s = '0' end
    return s
end
local FORMAT = {
    seconds = function(v) return trim(v) .. 's' end,
    fraction = function(v) return trim(v * 100) .. '%' end,
    count = function(v) return string.format('%d', math.floor(v + 0.5)) end,
    raw = function(v) return trim(v) end,
}
local MAX_STEPS = 2000
local MAX_FLAT = 4000

--- A condition tree in plain form: an empty one (a missing tree, an empty list) is nil.
local function cleanTree(tree)
    if type(tree) ~= 'table' or type(tree.type) ~= 'string' then return nil end
    return tree
end
local function andOf(list)
    local kept = {}
    for _, t in ipairs(list) do if t then kept[#kept + 1] = t end end
    if #kept == 0 then return nil end
    if #kept == 1 then return kept[1] end
    return {type = 'AND', value = kept}
end
-- NOT of a NOT is the inner tree; the negation of a missing (always true) tree is never true.
local function notOf(tree)
    if not tree then return {type = 'NOT', value = {type = 'AND', value = {}}} end
    if tree.type == 'NOT' and type(tree.value) == 'table' then return tree.value end
    return {type = 'NOT', value = tree}
end
local function list(t)
    if type(t) ~= 'table' then return {} end
    return t
end
local function values(v)
    if type(v) ~= 'table' then return {} end
    local out = {}
    for _, x in ipairs(v) do out[#out + 1] = x end
    return out
end

--- Exports a rotation body for an edition and class.
--- options: {mapping, kinds (the kinds table: sim name -> {values, actions} as sets or lists), ladders (spell id ->
--- {{id, rank}, ...}), potions (mana potion item ids), edition, cls}.
--- Returns {ok=true, apl, wrapper, report, kinds} or {ok=false, error={code}}.
function export.exportWowsims(body, options)
    local mapping, edition, cls = options.mapping, options.edition, options.cls
    if type(body) ~= 'table' then return {ok = false, error = {code = 'not-rotation'}} end
    local EXP = mapping.export
    if not own(mapping.editions, edition) then return {ok = false, error = {code = 'edition-unsupported', edition = tostring(edition)}} end
    local hasRanks = mapping.editions[edition].ranks == true
    local simNames = mapping.editions[edition].wowsims
    local kindSets = {}
    local sims = {}
    if options.kinds then
        for _, name in ipairs(simNames) do
            local sim = options.kinds[name]
            if sim then
                sims[#sims + 1] = name
                local v, a = {}, {}
                for _, x in ipairs(sim.values) do v[x] = true end
                for _, x in ipairs(sim.actions) do a[x] = true end
                kindSets[name] = {values = v, actions = a}
            end
        end
    end
    local ladders = options.ladders or {}
    local usedKinds, usedActions = {}, {castSpell = true}

    local items = {}           -- the report
    local prepull = {}         -- APL prepull actions
    local priority = {}        -- APL items
    local flat = 0
    local item = nil           -- the report item being worked on
    local function note(code, level, params)
        if item and #item.reasons < 40 then item.reasons[#item.reasons + 1] = {code = code, level = level, params = params or {}} end
    end

    -- ---- ids ----
    -- An RM spell id as the simulator's ActionID: on editions with ranks, the highest rank of its ladder (what a
    -- character at the level cap casts), with the rank the preset files carry.
    local function actionId(raw, kind)
        if type(raw) ~= 'number' or not isInteger(raw) or raw < 1 then return {fail = 'id'} end
        if kind == 'item' then return {id = {itemId = raw}} end
        local ladder = hasRanks and ladders[raw] or nil
        if ladder and #ladder > 0 then
            -- Rotation Master's Built Ins name a spell by its first rank and let it match every rank (ranked: false); the
            -- simulator needs the rank its character casts, which for a character at the level cap is the highest. Any
            -- other rank is taken as chosen on purpose (a downranked spell) and kept.
            local mine
            for _, x in ipairs(ladder) do if x[1] == raw then mine = x; break end end
            local top = ladder[#ladder]
            if mine and mine[1] == ladder[1][1] and top[1] ~= raw then
                note('x-rank', 'approximate', {from = raw, to = top[1], rank = top[2]})
                return {id = {spellId = top[1], rank = top[2]}}
            end
            local id = {spellId = raw}
            if mine then id.rank = mine[2] end
            return {id = id}
        end
        return {id = {spellId = raw}}
    end
    local function unitRef(unit)
        local u = (unit == nil) and 'player' or unit
        if not own(EXP.units, u) then return {fail = tostring(u):sub(1, 30)} end
        return {ref = EXP.units[u]}
    end

    -- ---- conditions ----
    local function val(v) return {k = 'val', v = v} end
    local function dropLeaf(tree, why, extra)
        local params = {type = tree.type, why = why}
        if extra then for k, v in pairs(extra) do params[k] = v end end
        note('x-cond-dropped', 'lossy', params)
        return DROP
    end
    local function build(args, tree)
        local out = {}
        for key, spec in pairs(args or {}) do
            if type(spec) ~= 'string' or spec:sub(1, 1) ~= '@' then
                out[key] = spec
            else
                local parts = {}
                for part in (spec .. ':'):gmatch('([^:]*):') do parts[#parts + 1] = part end
                local head = parts[1]
                if head == '@id' then
                    local r = actionId(tree[parts[2]])
                    if r.fail then return {fail = 'id'} end
                    out[key] = r.id
                elseif head == '@target' then
                    -- A dot's target defaults to your current target, so only another unit is written.
                    local r = unitRef(tree[parts[2]])
                    if r.fail then return {fail = 'unit', unit = r.fail} end
                    if r.ref and r.ref.type ~= 'CurrentTarget' then out[key] = copy(r.ref) end
                elseif head == '@unit' then
                    local r = unitRef(tree[parts[2]])
                    if r.fail then return {fail = 'unit', unit = r.fail} end
                    if r.ref then out[key] = copy(r.ref) end
                elseif head == '@table' then
                    local tbl = EXP.tables[parts[2]]
                    local raw = tree[parts[3]]
                    local k
                    if type(raw) == 'boolean' then k = tostring(raw)
                    elseif raw == nil and parts[2]:sub(1, 5) == 'swing' then k = 'false'
                    elseif type(raw) == 'number' then k = numstr(raw)
                    else k = tostring(raw) end
                    if not tbl or rawget(tbl, k) == nil then return {fail = 'value'} end
                    out[key] = tbl[k]
                else
                    return {fail = 'value'}
                end
            end
        end
        return {args = out}
    end
    local function valueNode(tree, entry)
        -- Which kind: a variant picked by the RM fields, a class-specific one, or the entry's own.
        local kind, args = entry.kind, entry.args
        local approx = entry.fidelity == 'approximate' and entry.note or nil
        if entry.variants then
            local chosen
            for _, v in ipairs(entry.variants) do
                local matches = true
                if v.when then for k, want in pairs(v.when) do if tree[k] ~= want then matches = false end end end
                if matches then chosen = v; break end
            end
            if not chosen then return {fail = 'no-equivalent'} end
            kind = chosen.kind; args = chosen.args
            if chosen.fidelity == 'approximate' then approx = chosen.note end
        end
        if entry.handler == 'power' then
            kind = own(EXP.power, cls) and EXP.power[cls] or nil
            if not kind then return {fail = 'class'} end
            args = {}
            if own(EXP.powerApprox, cls) then approx = EXP.powerApprox[cls] end
            if tree.unit and tree.unit ~= 'player' then return {fail = 'unit', unit = tostring(tree.unit)} end
        elseif entry.handler == 'points' then
            kind = own(EXP.points, cls) and EXP.points[cls] or nil
            if not kind then return {fail = 'class'} end
            args = {}
            if tree.unit and tree.unit ~= 'player' then return {fail = 'unit', unit = tostring(tree.unit)} end
        elseif entry.handler == 'pet' then
            kind = own(EXP.petKinds, cls) and EXP.petKinds[cls] or nil
            if not kind then return {fail = 'class'} end
            args = {}
        end
        -- Only a kind one of this edition's simulators reads can be written.
        if options.kinds then
            local readable = false
            for _, name in ipairs(sims) do if kindSets[name].values[kind] then readable = true end end
            if not readable then return {fail = 'no-equivalent'} end
        end
        if entry.self and tree.unit and tree.unit ~= 'player' then return {fail = 'unit', unit = tostring(tree.unit)} end
        if entry['not'] then for k, want in pairs(entry['not']) do if tree[k] == want then return {fail = 'no-equivalent'} end end end
        if entry.only then
            for k, want in pairs(entry.only) do
                local have = tree[k]
                if have == nil and k == 'unit' then have = 'player' end
                if have ~= want then return {fail = 'no-equivalent'} end
            end
        end
        local built = build(args, tree)
        if built.fail then return built end
        return {kind = kind, args = built.args, approx = approx}
    end
    local function leaf(tree)
        local utype = tree.type
        if own(EXP.trueIf, utype) then
            note('x-cond-approx', 'approximate', {type = utype, note = EXP.trueIf[utype]})
            return TRUE
        end
        -- What the simulator decides itself: it only chooses an action when you are free to act (never casting or channeling),
        -- and its target is a boss.
        if own(EXP.falseIf, utype) and (tree.unit == nil or tree.unit == 'player') then
            note('x-cond-approx', 'approximate', {type = utype, note = EXP.falseIf[utype]})
            return FALSE
        end
        if utype == 'CLASSIFICATION' and (tree.unit == nil or tree.unit == 'target') and type(tree.value) == 'string' and EXP.classification then
            local word = tree.value:lower()
            local boss, other = false, false
            for _, w in ipairs(EXP.classification.boss) do if w == word then boss = true end end
            for _, w in ipairs(EXP.classification.other) do if w == word then other = true end end
            if boss or other then
                note('x-cond-approx', 'approximate', {type = utype, note = 'sim-boss'})
                return boss and TRUE or FALSE
            end
        end
        if not own(EXP.conditions, utype) then return dropLeaf(tree, 'no-equivalent') end
        local entry = EXP.conditions[utype]
        local made = valueNode(tree, entry)
        if made.fail then return dropLeaf(tree, made.fail, made.unit and {unit = made.unit} or nil) end
        usedKinds[made.kind] = true
        local node = {[made.kind] = made.args}
        if made.approx then note('x-cond-approx', 'approximate', {type = utype, note = made.approx}) end
        if entry.t == 'bool' then
            if entry.cmp then return val({cmp = {op = entry.cmp.op, lhs = node, rhs = {const = {val = entry.cmp.val}}}}) end
            return val(node)
        end
        local op = own(EXP.ops, tree.operator) and EXP.ops[tree.operator] or nil
        if not op then return dropLeaf(tree, tree.operator == nil and 'incomplete' or 'operator') end
        if type(tree.value) ~= 'number' or tree.value ~= tree.value or tree.value == math.huge or tree.value == -math.huge then
            return dropLeaf(tree, 'incomplete')
        end
        if tree.value < 0 and (utype == 'POINT' or utype == 'HEALTH' or utype == 'MANA' or utype == 'POWER') then return dropLeaf(tree, 'value') end
        return val({cmp = {op = op, lhs = node, rhs = {const = {val = FORMAT[entry.unit](tree.value)}}}})
    end
    local function convert(tree, depth)
        if depth > 64 then return dropLeaf({type = 'AND'}, 'depth') end
        tree = cleanTree(tree)
        if not tree or tree.disabled == true then return TRUE end
        if tree.type == 'AND' or tree.type == 'OR' then
            local kids = {}
            for i, c in ipairs(values(tree.value)) do kids[i] = convert(c, depth + 1) end
            local isAnd = tree.type == 'AND'
            local vals, unknown = {}, false
            for _, k in ipairs(kids) do
                if k.k == 'true' then if not isAnd then return TRUE end
                elseif k.k == 'false' then if isAnd then return FALSE end
                elseif k.k == 'drop' then unknown = true
                else vals[#vals + 1] = k.v end
            end
            if not isAnd and unknown then return DROP end            -- an unknown alternative could be the true one
            if #vals == 0 then
                if unknown then return DROP end
                return isAnd and TRUE or FALSE
            end
            if #vals == 1 then return val(vals[1]) end
            return val({[isAnd and 'and' or 'or'] = {vals = json.array(vals)}})
        end
        if tree.type == 'NOT' then
            local inner = convert(tree.value, depth + 1)
            if inner.k == 'true' then return FALSE end
            if inner.k == 'false' then return TRUE end
            if inner.k == 'drop' then return DROP end
            return val({['not'] = {val = inner.v}})
        end
        return leaf(tree)
    end
    -- A tree is "out of combat" when it is exactly NOT COMBAT(player), or an AND that has it among its parts.
    local function isNotCombat(t)
        return t and t.type == 'NOT' and type(t.value) == 'table' and t.value.type == 'COMBAT' and (t.value.unit == nil or t.value.unit == 'player')
    end
    local function conjuncts(tree, out, depth)
        out = out or {}
        depth = depth or 0
        tree = cleanTree(tree)
        if not tree or depth > 32 then return out end
        if tree.type == 'AND' and tree.disabled ~= true then
            for _, c in ipairs(values(tree.value)) do conjuncts(c, out, depth + 1) end
        else out[#out + 1] = tree end
        return out
    end
    local function splitOutOfCombat(tree)
        local parts = conjuncts(tree)
        -- "Not in combat" together with "in combat" can never be true; that is not a pre-pull action.
        local hasNot, hasCombat = false, false
        for _, p in ipairs(parts) do
            if isNotCombat(p) then hasNot = true end
            if p.type == 'COMBAT' and (p.unit == nil or p.unit == 'player') then hasCombat = true end
        end
        if not hasNot or hasCombat then return {out = false, rest = tree} end
        local rest = {}
        for _, p in ipairs(parts) do if not isNotCombat(p) then rest[#rest + 1] = p end end
        return {out = true, rest = andOf(rest)}
    end

    -- ---- actions ----
    -- A step's casts: {casts = {ActionID...}} or {fail = code}.
    local function castsOf(step)
        local utype = step.type
        if utype == 'spell' or utype == 'any' then
            local r = actionId(step.action)
            if r.fail then return {fail = 'x-action-id'} end
            return {casts = {r.id}}
        end
        if utype == 'item' then
            local ids
            if type(step.action) == 'table' then ids = step.action elseif type(step.action) == 'number' then ids = {step.action} end
            if not ids then return {fail = 'x-action-itemset'} end
            local good = {}
            for _, x in ipairs(ids) do if type(x) == 'number' and isInteger(x) and x > 0 then good[#good + 1] = x end end
            if #good == 0 then return {fail = 'x-action-itemset'} end
            -- Every id a mana potion of this edition: the simulator's resource potion placeholder, as the import made it.
            local potions = options.potions or {}
            local isPotion = {}
            for _, p in ipairs(potions) do isPotion[p] = true end
            local all = #potions > 0
            for _, id in ipairs(good) do if not isPotion[id] then all = false end end
            local noMana = false
            for _, c in ipairs(mapping.noManaClasses or {}) do if c == cls then noMana = true end end
            if all and not noMana then
                note('x-potion', 'approximate', {})
                return {casts = {{otherId = EXP.resourcePotion}}}
            end
            if #good > 1 then note('x-item-list', 'approximate', {count = #good}) end
            local casts = {}
            for _, id in ipairs(good) do casts[#casts + 1] = {itemId = id} end
            return {casts = casts}
        end
        if utype == 'pet' then return {fail = 'x-action-pet'} end
        if utype == 'assisted' then return {fail = 'x-action-assisted'} end
        return {fail = 'x-action-unknown'}
    end
    local function labelOf(step)
        if step.type == 'item' then
            if type(step.action) ~= 'table' then return '' end
            local out = {}
            for _, x in ipairs(step.action) do if type(x) == 'number' then out[#out + 1] = '#' .. numstr(x) end end
            return table.concat(out, ',')
        end
        return type(step.action) == 'number' and '#' .. numstr(step.action) or ''
    end
    local NOTES = {
        ['x-rank'] = 'rank raised', ['x-prepull-cond'] = 'its other conditions were lost as a pre-pull action',
        ['x-cond-dropped'] = 'a condition has no WowSims equivalent and was left out',
        ['x-cond-approx'] = 'a condition was converted approximately', ['x-cooldown-first'] = 'a Rotation Master cooldown, placed first',
        ['x-prepull-time'] = 'pre-pull time assumed', ['x-item-list'] = 'one of several items',
        ['x-cond-never'] = 'its condition can never be true in the simulator'}
    local NOTE_ORDER = {'x-rank', 'x-prepull-cond', 'x-cond-dropped', 'x-cond-approx', 'x-cooldown-first', 'x-prepull-time', 'x-item-list', 'x-cond-never'}
    local function noteText(reasons)
        -- The words in the order the reasons appeared, each once (the website's order).
        local words, seen = {}, {}
        for _, r in ipairs(reasons) do
            if r.level ~= 'exact' and NOTES[r.code] and not seen[NOTES[r.code]] then
                seen[NOTES[r.code]] = true; words[#words + 1] = NOTES[r.code]
            end
        end
        if #words == 0 then return nil end
        return 'Rotation Master: ' .. table.concat(words, '; ') .. '.'
    end
    local _ = NOTE_ORDER

    local function newItem(path, step, section)
        return {path = path, section = section, label = labelOf(step), type = step.type,
            name = type(step.name) == 'string' and step.name:sub(1, 120) or '', fidelity = 'exact', outcome = 'exported',
            reasons = {}, became = 0, at = {}, flags = {}}
    end
    local function finishItem(rec)
        local level = 'exact'
        for _, r in ipairs(rec.reasons) do if LEVEL_RANK[r.level] then level = worse(level, r.level) end end
        rec.fidelity = level
        items[#items + 1] = rec
    end

    local walk, markUnreachable, exportStep
    -- Walks a list of steps. guards: RM trees every step in the list also needs; stops: the NOT(stop condition) trees
    -- that apply to everything after a Stop. state.ended: an unconditional Stop was passed.
    function walk(steps, path, section, guards, state, depth)
        steps = list(steps)
        for i, step in ipairs(steps) do
            if type(step) == 'table' then
                flat = flat + 1
                if flat <= MAX_FLAT then
                    local here = path .. '[' .. i .. ']'
                    item = newItem(here, step, section)
                    if step.disabled == true then
                        item.outcome = 'skipped'; note('x-disabled', 'exact'); finishItem(item); item = nil
                    elseif state.ended then
                        item.outcome = 'skipped'; note('x-unreachable', 'exact', {why = 'stop'}); finishItem(item); item = nil
                    elseif step.type == 'branch' then
                        local guard = cleanTree(step.conditions)
                        -- A branch with no condition is always true; a forced mode leaves the other arm unreachable.
                        local mode = step.mode or 'evaluate'
                        if mode == 'evaluate' and not guard then mode = 'true' end
                        item.type = 'branch'; item.label = ''
                        note('x-branch', 'exact', {mode = mode})
                        finishItem(item); item = nil
                        local arms = {
                            {list = step.onTrue, name = '.onTrue', reach = mode ~= 'false', guards = mode == 'true' and {} or {guard or false}},
                            {list = step.onFalse, name = '.onFalse', reach = mode ~= 'true', guards = mode == 'false' and {} or {notOf(guard)}},
                        }
                        for _, arm in ipairs(arms) do
                            if not arm.reach then
                                markUnreachable(arm.list, here .. arm.name, section)
                            else
                                local armState = {ended = false, stops = {}}
                                for _, s in ipairs(state.stops) do armState.stops[#armState.stops + 1] = s end
                                local armGuards = {}
                                for _, g in ipairs(guards) do armGuards[#armGuards + 1] = g end
                                for _, g in ipairs(arm.guards) do armGuards[#armGuards + 1] = g end
                                walk(arm.list, here .. arm.name, section, armGuards, armState, depth + 1)
                                -- A Stop inside an arm ends the whole list when the arm was taken: it carries on as a condition on everything after.
                                for j = #state.stops + 1, #armState.stops do state.stops[#state.stops + 1] = armState.stops[j] end
                                if armState.ended then
                                    local fullList = {}
                                    for _, g in ipairs(guards) do fullList[#fullList + 1] = g end
                                    for _, g in ipairs(arm.guards) do fullList[#fullList + 1] = g end
                                    local full = andOf(fullList)
                                    if full then state.stops[#state.stops + 1] = notOf(full) else state.ended = true end
                                end
                            end
                        end
                    elseif step.type == 'stop' then
                        local cond = cleanTree(step.conditions)
                        note('x-stop', 'exact')
                        finishItem(item); item = nil
                        -- Unconditional: everything after it in this list is unreachable. Conditional: it needs "not (this condition)".
                        if not cond then state.ended = true
                        else
                            local all = {}
                            for _, g in ipairs(guards) do all[#all + 1] = g end
                            all[#all + 1] = cond
                            state.stops[#state.stops + 1] = notOf(andOf(all))
                        end
                    else
                        local all = {}
                        for _, g in ipairs(guards) do all[#all + 1] = g end
                        for _, g in ipairs(state.stops) do all[#all + 1] = g end
                        exportStep(step, here, section, all)
                    end
                end
            end
        end
    end
    function markUnreachable(steps, path, section)
        for i, step in ipairs(list(steps)) do
            if type(step) == 'table' then
                local rec = newItem(path .. '[' .. i .. ']', step, section)
                rec.outcome = 'skipped'
                item = rec; note('x-unreachable', 'exact', {why = 'mode'}); finishItem(rec); item = nil
                if step.type == 'branch' then
                    markUnreachable(step.onTrue, path .. '[' .. i .. '].onTrue', section)
                    markUnreachable(step.onFalse, path .. '[' .. i .. '].onFalse', section)
                end
            end
        end
    end
    function exportStep(step, path, section, guards)
        local casts = castsOf(step)
        if casts.fail then
            item.outcome = 'dropped'; item.fidelity = 'unsupported'
            note(casts.fail, 'unsupported'); finishItem(item); item = nil
            return
        end
        local ownTree = cleanTree(step.conditions)
        -- A step that applies only out of combat is a pre-pull action to the simulator. Pre-pull actions carry no
        -- conditions, so any other condition on the step is lost (and said so), and the seconds are assumed.
        local all = {}
        for _, g in ipairs(guards) do all[#all + 1] = g end
        all[#all + 1] = ownTree or false
        local split = splitOutOfCombat(andOf(all))
        if split.out then
            if split.rest then
                local converted = convert(split.rest, 0)
                if converted.k ~= 'true' then note('x-prepull-cond', 'lossy') end
            end
            note('x-prepull-time', 'lossy')
            for _, id in ipairs(casts.casts) do prepull[#prepull + 1] = {id = id, item = item, order = #prepull} end
            item.became = #casts.casts
            finishItem(item); item = nil
            return
        end
        local cond = convert(andOf(all), 0)
        if cond.k == 'false' then
            item.outcome = 'dropped'; note('x-cond-never', 'lossy'); finishItem(item); item = nil
            return
        end
        if section == 'cooldowns' then note('x-cooldown-first', 'approximate') end
        for _, id in ipairs(casts.casts) do
            if #priority >= MAX_STEPS then break end
            local action = {}
            if cond.k == 'val' then action.condition = cond.v end
            action.castSpell = {spellId = id}
            priority[#priority + 1] = {section = section, order = #priority, action = action, item = item}
        end
        item.became = #casts.casts
        finishItem(item); item = nil
    end

    -- Cooldowns are independent in Rotation Master: no Stop or branch touches them.
    walk(body.cooldowns, 'cooldowns', 'cooldowns', {}, {ended = false, stops = {}}, 0)
    local cooldownItems = priority
    priority = {}
    walk(body.rotation, 'rotation', 'rotation', {}, {ended = false, stops = {}}, 0)
    local mainItems = priority
    local all = {}
    for _, e in ipairs(cooldownItems) do all[#all + 1] = e end
    for _, e in ipairs(mainItems) do all[#all + 1] = e end

    -- Where each report item's actions ended up in the priority list.
    for i, entry in ipairs(all) do entry.item.at[#entry.item.at + 1] = i - 1 end
    -- Item notes carry the item's own reasons, once the item is final.
    local aplItems = {}
    for _, entry in ipairs(all) do
        local out = {}
        local text = noteText(entry.item.reasons)
        if text then out.notes = text end
        out.action = entry.action
        aplItems[#aplItems + 1] = out
    end
    -- Pre-pull: earliest first, one second apart, the last one a second before the pull.
    local aplPrepull = {}
    for i, p in ipairs(prepull) do
        aplPrepull[i] = {action = {castSpell = {spellId = p.id}}, doAtValue = {const = {val = '-' .. (#prepull - i + 1) .. 's'}}}
    end

    local apl = {type = 'TypeAPL', prepullActions = json.array(aplPrepull), priorityList = json.array(aplItems)}
    local player = {}
    if own(EXP.classEnum, cls) then player.class = EXP.classEnum[cls] end
    player.rotation = apl
    local wrapper = {player = player}

    -- The simulators that can read every kind this uses.
    local readers = {}
    for _, name in ipairs(sims) do
        local k = kindSets[name]
        local readable = true
        for kind in pairs(usedKinds) do if not k.values[kind] then readable = false end end
        for kind in pairs(usedActions) do if not k.actions[kind] then readable = false end end
        if readable then readers[#readers + 1] = name end
    end
    local summary = {items = 0, exact = 0, approximate = 0, lossy = 0, unsupported = 0, exported = 0, dropped = 0, skipped = 0,
        actions = #aplItems, prepull = #aplPrepull, truncated = flat > MAX_FLAT and flat - MAX_FLAT or 0}
    for _, r in ipairs(items) do
        if r.type ~= 'branch' and r.type ~= 'stop' and r.outcome ~= 'skipped' then
            summary.items = summary.items + 1
            summary[r.fidelity] = summary[r.fidelity] + 1
            summary[r.outcome] = summary[r.outcome] + 1
        end
    end
    local skipped = 0
    for _, r in ipairs(items) do if r.outcome == 'skipped' and r.type ~= 'branch' and r.type ~= 'stop' then skipped = skipped + 1 end end
    summary.skipped = skipped
    local report = {direction = 'export', target = {edition = edition, cls = cls, sims = readers, candidates = sims}, summary = summary, items = items}
    local kinds = {}
    for kind in pairs(usedKinds) do kinds[#kinds + 1] = kind end
    table.sort(kinds)
    return {ok = true, apl = apl, wrapper = wrapper, report = report, kinds = kinds}
end

--- Pretty-printed JSON with two-space indent, as the simulator writes its own exports.
function export.stringify(value) return json.encode(value, 2) end
