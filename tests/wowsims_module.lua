-- The WowSims converters on their own (Modules/RotationMaster_WowSims, no game): hostile and malformed text, the
-- messages a person is shown for text that holds no rotation, class and edition checks, how an id is verified,
-- the limits, the export of structure (branches, Stops, cooldowns, pre-pull), the id data against its pinned
-- JSON, and that every word the reports can show is in the locale files.
local F = dofile('tests/fixtures/addon.lua')
local W = dofile('tests/fixtures/wowsims.lua')
local test, finish = F.suite()

local ns = W.loadModule()
local json, import = ns.json, ns.import
local limits = ns.mapping.limits
local data = W.websiteData(ns)

local function text(error_) return ns.api.describeError({error = error_}, setmetatable({}, {__index = function(_, k) return k end}), {}) end
local NO_APL = 'This export contains no rotation to import. In WowSims, open the Rotation tab, choose an APL (or a preset), then export again.'
local function api(textInput, context)
    context = context or {}
    context.edition = context.edition or 'era'
    context.cls = context.cls or 'SHAMAN'
    return ns.api.import(textInput, context)
end
local function failure(result) return result.error and result.error.code end

-- ---- the JSON reader --------------------------------------------------------------------------------------------
test('the JSON reader keeps to its limits and says which one a text broke', function()
    local deep = string.rep('[', limits.depth + 1) .. string.rep(']', limits.depth + 1)
    assert(json.parse(deep, limits).error.code == 'too-deep')
    assert(json.parse(string.rep('[', 60) .. string.rep(']', 60), limits).ok, 'a document within the limit')
    assert(json.parse(string.rep(' ', limits.text + 2) .. '1', limits).ok, 'surrounding whitespace is not counted')
    assert(json.parse('"' .. string.rep('a', limits.text) .. '"', limits).error.code == 'too-large')
    assert(json.parse('"' .. string.rep('a', limits.string + 1) .. '"', limits).error.code == 'string-too-long')
    local many = {}
    for i = 1, limits.array + 1 do many[i] = '0' end
    assert(json.parse('[' .. table.concat(many, ',') .. ']', limits).error.code == 'array-too-long')
    local keys = {}
    for i = 1, limits.keys + 1 do keys[i] = '"k' .. i .. '":1' end
    assert(json.parse('{' .. table.concat(keys, ',') .. '}', limits).error.code == 'too-many-keys')
    local nodes = {}
    for i = 1, 150 do nodes[i] = '[' .. string.rep('0,', 999) .. '0]' end
    assert(json.parse('[' .. table.concat(nodes, ',') .. ']', limits).error.code == 'too-many-values')
    assert(json.parse('1e999', limits).error.code == 'not-finite')
    for _, key in ipairs({'__proto__', 'constructor', 'prototype'}) do
        local r = json.parse('{"a":{"' .. key .. '":1}}', limits)
        assert(r.error.code == 'forbidden-key' and r.error.key == key, key)
    end
    assert(json.parse('', limits).error.code == 'empty' and json.parse('   ', limits).error.code == 'empty')
    assert(json.parse(nil, limits).error.code == 'not-text' and json.parse(42, limits).error.code == 'not-text')
end)
test('malformed JSON is refused with a reason and never raises', function()
    for _, bad in ipairs({'{', '[1,]', '{"a":}', '{"a" 1}', "{'a':1}", '[1 2]', '{"a":1,}', 'nul', '01', '1.', '.5', '-', '"\\x"', '"\\u12"',
        '"abc', '{"a":1}}', '[1] x', '{"a":"\1"}', '\0', 'true false'}) do
        local ok, r = pcall(json.parse, bad, limits)
        assert(ok, 'raised on ' .. bad)
        assert(not r.ok and r.error.code, 'accepted ' .. bad)
    end
    local r = json.parse('{"a":"\\ud83d\\ude00 \\u00e9 \\n","b":[1,2.5,-3e2,true,false,null],"c":{"d":null}}', limits)
    assert(r.ok and r.value.a == '\240\159\152\128 \195\169 \n' and r.value.b[3] == -300 and r.value.b[6] == json.null and r.value.c.d == nil)
    assert(json.keys(r.value)[1] == 'a' and #json.keys(r.value.c) == 0, 'a null value is an absent key')
    assert(json.encode(r.value) == '{"a":"\240\159\152\128 \195\169 \\n","b":[1,2.5,-300,true,false,null],"c":{}}')
end)
test('pasted text: JSON as it is, base64 of JSON, a share link refused', function()
    assert(json.pastedText('  {"a":1} ', limits).via == 'json')
    local b64 = 'eyJhIjoxfQ=='
    local r = json.pastedText(b64, limits)
    assert(r.ok and r.text == '{"a":1}' and r.via == 'base64')
    assert(json.pastedText('eyJh\n  Ijox\r\nfQ==', limits).text == '{"a":1}', 'wrapped base64 reads')
    assert(json.pastedText('eyJh\226\128\139Ijox\239\187\191fQ==', limits).text == '{"a":1}', 'invisible characters are dropped')
    local link = json.pastedText('https://www.wowsims.com/classic/elemental_shaman/#abcdef', limits)
    assert(link.error.code == 'share-link' and link.link.era == 'classic' and link.link.spec == 'elemental_shaman')
    assert(json.pastedText('eJzLSM3JyQcABiwCFQ==', limits).error.code == 'share-link', 'a zlib stream is a share link')
    assert(json.pastedText('RM1:abcd', limits).error.code == 'not-json' and json.pastedText('hello world', limits).error.code == 'not-json')
    assert(json.pastedText('/w==', limits).error.code == 'not-json', 'not UTF-8')
    assert(json.pastedText(string.rep('A', limits.text * 2), limits).error.code == 'too-large')
end)

-- ---- text that holds no rotation ----------------------------------------------------------------------------------
test('an export with no APL says to choose one in WowSims and export again', function()
    for _, body in ipairs({'{"player":{"class":"ClassShaman","rotation":{"type":"TypeAuto"}}}', '{"type":"TypeAuto"}', '{"player":{"class":"ClassShaman"}}',
        '{"rotation":{"type":"TypeLegacy"}}', '[1,2]', '{"hello":"world"}'}) do
        local r = api(body)
        assert(not r.ok and (failure(r) == 'not-an-apl' or failure(r) == 'not-apl'), body .. ' -> ' .. tostring(failure(r)))
        assert(text(r.error) == NO_APL, body)
    end
    local simple = api('{"player":{"class":"ClassMage","rotation":{"type":"TypeSimple"}}}')
    assert(failure(simple) == 'not-an-apl' and text(simple.error):find('Simple rotation', 1, true) and text(simple.error):find('choose an APL', 1, true))
    assert(text(api('{"type":"TypeAPL","priorityList":[],"prepullActions":[]}').error) == 'This rotation is empty: it has no actions to import.')
    assert(text(api('').error) == 'Paste a WowSims rotation first.')
    assert(text(api('RM1:abc').error):find('does not look like JSON', 1, true))
    assert(failure(api('{"a":{"__proto__":{}}}')) == 'forbidden-key')
end)
test('a saved-rotations map names what it holds; one is picked by name', function()
    local text_ = '{"one":{"rotation":{"type":"TypeAPL","priorityList":[{"action":{"castSpell":{"spellId":{"spellId":403}}}}]}},"two":{"rotation":{"type":"TypeAPL","priorityList":[{"action":{"castSpell":{"spellId":{"spellId":324}}}}]}}}'
    local r = api(text_, {edition = 'tbc'})
    assert(failure(r) == 'several-rotations' and #r.error.names == 2 and text(r.error):find('several saved rotations', 1, true))
    local picked = api(text_, {edition = 'tbc', pick = 'two'})
    assert(picked.ok and picked.body.rotation[1].action == 324 and picked.report.detected.name == 'two')
end)

-- ---- class and edition ----------------------------------------------------------------------------------------
test('a class that is not the character\'s is refused; a different specialization is recorded', function()
    local mage = '{"player":{"class":"ClassMage","rotation":{"type":"TypeAPL","priorityList":[{"action":{"castSpell":{"spellId":{"spellId":10150}}}}]}}}'
    local r = api(mage, {edition = 'era', cls = 'SHAMAN'})
    assert(failure(r) == 'class-mismatch' and r.error.declared == 'MAGE' and r.error.chosen == 'SHAMAN')
    local words = ns.api.describeError(r, setmetatable({}, {__index = function(_, k) return k end}), {classLabel = function(c) return c:lower() end})
    assert(words == 'The file is for mage, but this character is shaman.', words)
    local spec = '{"player":{"class":"ClassShaman","enhancementShaman":{"options":{}},"rotation":{"type":"TypeAPL","priorityList":[{"action":{"castSpell":{"spellId":{"spellId":403}}}}]}}}'
    local ok = api(spec, {edition = 'tbc', cls = 'SHAMAN', spec = 'elemental'})
    assert(ok.ok and ok.target.spec == 'elemental' and ok.target.specSource == 'chosen', 'a spec the player picked is recorded')
    local fromFile = api(spec, {edition = 'tbc', cls = 'SHAMAN'})
    assert(fromFile.ok and fromFile.target.spec == 'enhancement' and fromFile.target.specSource == 'file', 'the file\'s own spec is recorded')
end)
test('an edition the file cannot be for is refused', function()
    -- Ranks exist on Era, TBC and Forever only: a file with ranks is not a Wrath/Cataclysm/Mists file.
    local ranked = '{"player":{"class":"ClassShaman","rotation":{"type":"TypeAPL","priorityList":[{"action":{"castSpell":{"spellId":{"spellId":10438,"rank":6}}}}]}}}'
    local r = api(ranked, {edition = 'progression'})
    assert(failure(r) == 'edition-mismatch' and r.error.chosen == 'progression', tostring(failure(r)))
    local words = ns.api.describeError(r, setmetatable({}, {__index = function(_, k) return k end}), {editionLabel = function(e) return 'E:' .. e end})
    assert(words:find('E:progression', 1, true) and words:find('E:era', 1, true), words)
    -- Groups of actions and variables exist only in the newer simulators.
    local modern = '{"type":"TypeAPL","groups":[{"name":"g","actions":[]}],"priorityList":[{"action":{"castSpell":{"spellId":{"spellId":403}}}}]}'
    assert(failure(api(modern, {edition = 'era'})) == 'edition-mismatch')
    assert(api(modern, {edition = 'forever'}).ok)
    -- Another edition's spells.
    local wrath = W.read(W.dir .. 'wotlk_ele_default.apl.json')
    local mismatch = api(wrath, {edition = 'tbc', cls = 'SHAMAN'})
    assert(mismatch.ok or failure(mismatch) == 'edition-ids-mismatch', tostring(failure(mismatch)))
    -- A Mists rotation on a Classic Era client: its Mists-only spells are not known there, and the report says so.
    local ele = api(W.read(W.dir .. 'mop_ele.apl.json'), {edition = 'era', cls = 'SHAMAN', checkSpell = function(id) return id < 30000 end})
    assert(not ele.ok or #ele.report.ids.unknown > 0, 'a Mists rotation on a Classic Era client goes unnoticed')
end)
test('spells that belong to another class refuse the file; a lone foreign id only disables its step', function()
    local mage = W.read(W.dir .. 'era_mage_p1.apl.json')
    local r = api(mage, {edition = 'era', cls = 'SHAMAN'})
    assert(failure(r) == 'class-ids-mismatch' and r.error.looksLike == 'MAGE', tostring(failure(r)) .. tostring(r.error and r.error.looksLike))
    local one = '{"type":"TypeAPL","priorityList":[{"action":{"castSpell":{"spellId":{"spellId":403}}}},{"action":{"castSpell":{"spellId":{"spellId":10150}}}}]}'
    local ok = api(one, {edition = 'era', cls = 'SHAMAN'})
    assert(ok.ok and ok.report.items[1].outcome == 'enabled', 'the shaman spell stays enabled')
end)

-- ---- how an id is verified ------------------------------------------------------------------------------------
test('the game client confirms an id no list contradicts, and never overrides another class\'s list', function()
    local verify = import.verifyId
    local sim = {code = 'sim:x', sets = import.knownSets({all = {spell = {1, 2, 3}}, classes = {SHAMAN = {spell = {1}}, MAGE = {spell = {2}}}})}
    local game = function(known) return {code = 'game', weak = true, check = function(_, id) if known[id] then return 'known' end return 'unknown' end} end
    local both = {sim, game({[1] = true, [2] = true, [9] = true})}
    local r1 = verify(both, 'SHAMAN', 1, 'spell')
    assert(r1.status == 'known' and r1.via[1] == 'sim:x' and r1.via[2] == 'game')
    local r2 = verify(both, 'SHAMAN', 2, 'spell')
    assert(r2.status == 'other-class' and #r2.via == 0, 'the client knowing the spell does not make it ours')
    local r9 = verify(both, 'SHAMAN', 9, 'spell')
    assert(r9.status == 'known' and r9.via[1] == 'game' and r9.checked[2] == 'game')
    assert(verify(both, 'SHAMAN', 77, 'spell').status == 'unknown')
    local blind = {code = 'game', weak = true, check = function() return 'unchecked' end}
    assert(verify({blind}, 'SHAMAN', 5, 'spell').status == 'unchecked' and verify({}, 'SHAMAN', 5, 'spell').status == 'unchecked')
    assert(verify({sim, blind}, 'SHAMAN', 77, 'spell').status == 'unknown' and verify({sim, blind}, 'SHAMAN', 77, 'spell').checked[1] == 'sim:x')
end)
test('an id nothing confirms is flagged and stays enabled unless the person asks; another class\'s id is disabled', function()
    local apl = '{"type":"TypeAPL","priorityList":[{"action":{"castSpell":{"spellId":{"spellId":4000001}}}},{"action":{"castSpell":{"spellId":{"spellId":403}}}}]}'
    local missing = function(id) return id ~= 4000001 end
    local r = api(apl, {edition = 'tbc', checkSpell = missing})
    assert(r.ok and r.report.items[1].outcome == 'enabled' and #r.report.ids.unknown == 1, 'flagged, not disabled')
    local reason
    for _, x in ipairs(r.report.items[1].reasons) do if x.code == 'id-unknown' then reason = x end end
    assert(reason and reason.params.id == 4000001 and reason.params.sources:find('game', 1, true))
    local strict = api(apl, {edition = 'tbc', checkSpell = missing, disableUnconfirmed = true})
    assert(strict.report.items[1].outcome == 'disabled' and strict.report.items[2].outcome == 'enabled')
    local blind = api(apl, {edition = 'tbc'})
    assert(blind.ok and blind.report.ids.unchecked == 0, 'the simulator data still answers when the client cannot')
end)
test('the id data is the pinned JSON, decoded: spells per class, rank ladders, potions', function()
    local pinned = W.decode(ns, 'Data/wowsims/ids.json')
    for _, edition in ipairs(ns.mapping.editionOrder) do
        local verifiers = ns.ids.verifiers(edition)
        local want = pinned[edition]
        assert(#verifiers == #want.sources, edition)
        for index, src in ipairs(want.sources) do
            local v = verifiers[index]
            assert(v.repo == src.repo and v.ref == src.ref and v.url == src.url and v.items == src.items, edition .. ' ' .. src.repo)
            for _, cls in ipairs(json.keys(src.spells)) do
                local entry = v.sets.classes[cls]
                assert(entry, cls)
                local count = 0
                for _, id in ipairs(src.spells[cls]) do assert(entry.spell[id], edition .. ' ' .. cls .. ' ' .. id); count = count + 1 end
                local have = 0
                for _ in pairs(entry.spell) do have = have + 1 end
                assert(have == count, edition .. ' ' .. cls .. ' has ' .. have .. ' ids, the pinned data has ' .. count)
            end
        end
        local ladders = ns.ids.ladders(edition)
        for _, l in ipairs(want.ladders) do
            for _, pair in ipairs(l) do
                local got = ladders[pair[1]]
                assert(got, edition .. ' ladder of ' .. pair[1])
            end
        end
        local potions = ns.ids.potions(edition)
        assert(#potions == #want.manaPotions)
        for i, id in ipairs(want.manaPotions) do assert(potions[i] == id) end
    end
    ns.ids.release()
end)

-- ---- limits -----------------------------------------------------------------------------------------------------
test('a very long list stops at the step limit with a reason; nothing raises', function()
    local items = {}
    for i = 1, limits.items + 5 do items[i] = '{"action":{"castSpell":{"spellId":{"spellId":403}}}}' end
    local r = api('{"type":"TypeAPL","priorityList":[' .. table.concat(items, ',') .. ']}', {edition = 'tbc', checkSpell = function() return true end})
    assert(r.ok and r.report.summary.steps <= limits.steps)
    local limited = false
    for _, item in ipairs(r.report.items) do for _, x in ipairs(item.reasons) do if x.code == 'item-limit' or x.code == 'step-limit' then limited = true end end end
    assert(limited, 'the cut is reported')
    -- Deeply nested conditions are bounded, not recursed without end.
    local cond = '{"const":{"val":"true"}}'
    for _ = 1, 60 do cond = '{"not":{"val":' .. cond .. '}}' end
    local deep = api('{"type":"TypeAPL","priorityList":[{"action":{"condition":' .. cond .. ',"castSpell":{"spellId":{"spellId":403}}}}]}', {edition = 'tbc'})
    assert(deep.ok or failure(deep) == 'nothing-imported' or failure(deep) == 'too-deep')
    -- Groups that contain themselves.
    local cyc = '{"type":"TypeAPL","groups":[{"name":"a","actions":[{"action":{"groupReference":{"groupName":"a"}}}]}],"priorityList":[{"action":{"groupReference":{"groupName":"a"}}}]}'
    local c = api(cyc, {edition = 'forever'})
    assert(not c.ok and failure(c) == 'nothing-imported', tostring(failure(c)))
    local code
    for _, item in ipairs(c.report.items) do for _, x in ipairs(item.reasons) do if x.code == 'group-cycle' then code = x.code end end end
    assert(code == 'group-cycle')
end)

-- ---- conversion keeps the rules ------------------------------------------------------------------------------
test('a condition the client hides is imported disabled with the game\'s reason; Retail and Forever differ from Era', function()
    local forever = W.read(W.dir .. 'forever_shaman_enhancement_default.apl.json')
    local supports = W.supports(F, 'forever')
    local r = api(forever, {edition = 'forever', cls = 'SHAMAN', supports = supports})
    assert(r.ok)
    local restricted = 0
    for _, item in ipairs(r.report.items) do
        for _, x in ipairs(item.reasons) do
            if x.code == 'cond-restricted' then
                restricted = restricted + 1
                assert(item.outcome == 'disabled' and (x.params.restricted == 'secret-power' or x.params.restricted == 'secret-health'
                    or x.params.restricted == 'combat-log-unavailable'), item.path)
            end
        end
    end
    assert(restricted > 0, 'mana, health and the combat log are hidden on Forever')
    local era = api(W.read(W.dir .. 'era_ele.apl.json'), {edition = 'era', cls = 'SHAMAN', supports = W.supports(F, 'era')})
    for _, item in ipairs(era.report.items) do
        for _, x in ipairs(item.reasons) do assert(x.code ~= 'cond-restricted', 'Era hides nothing') end
    end
end)
test('import never enables a step it could not copy exactly', function()
    local r = api(W.read(W.dir .. 'tbcnew_shaman_enhancement_default.apl.json'), {edition = 'tbc', cls = 'SHAMAN', supports = W.supports(F, 'tbc'),
        checkSpell = function() return true end})
    assert(r.ok)
    local enabledNotExact = 0
    for _, item in ipairs(r.report.items) do
        if item.outcome == 'enabled' and item.fidelity ~= 'exact' then
            for _, x in ipairs(item.reasons) do if x.level ~= 'exact' and not x.benign and x.level ~= 'check' then enabledNotExact = enabledNotExact + 1 end end
        end
    end
    -- Pre-pull timing is the one lossy-but-benign reason; everything else that is not exact is disabled.
    for _, item in ipairs(r.report.items) do
        if item.fidelity ~= 'exact' and not item.prepull then assert(item.outcome ~= 'enabled', item.path) end
    end
    assert(enabledNotExact == 0)
    local ids = {}
    for _, step in ipairs(r.body.rotation) do
        assert(type(step.id) == 'string' and not ids[step.id], 'step ids are unique')
        ids[step.id] = true
        assert(step.type == 'spell' or step.type == 'item')
    end
    -- the enable-approximate option keeps approximate steps enabled
    local keep = api(W.read(W.dir .. 'tbcnew_shaman_enhancement_default.apl.json'), {edition = 'tbc', cls = 'SHAMAN', supports = W.supports(F, 'tbc'), enableApproximate = true})
    assert(keep.report.summary.disabled <= r.report.summary.disabled)
end)

-- ---- the export of structure ---------------------------------------------------------------------------------
local function export(body, edition, cls)
    edition = edition or 'tbc'
    return ns.api.export(body, {edition = edition, cls = cls or 'SHAMAN'})
end
local function spell(id, conditions, extra)
    local step = {id = 's' .. id, type = 'spell', action = id, conditions = conditions}
    for k, v in pairs(extra or {}) do step[k] = v end
    return step
end
test('export: a Stop adds NOT its condition to every step after it; an unconditional Stop ends the list', function()
    local r = export({rotation = {spell(403), {id = 'stop', type = 'stop', conditions = {type = 'BUFF', unit = 'player', spell = 2825}}, spell(324), spell(8042)}, cooldowns = {}})
    assert(r.ok)
    assert(#r.apl.priorityList == 3)
    local third = json.parse(json.encode(r.apl.priorityList[3]), W.BIG).value
    assert(third.action.condition['not'].val.auraIsActive.auraId.spellId == 2825 and third.action.castSpell.spellId.spellId == 8042)
    local first = json.parse(json.encode(r.apl.priorityList[1]), W.BIG).value
    assert(first.action.condition == nil, 'the step before the Stop is not touched')
    local unconditional = export({rotation = {spell(403), {id = 'stop', type = 'stop', conditions = {}}, spell(324)}, cooldowns = {}})
    assert(#unconditional.apl.priorityList == 1)
    assert(unconditional.report.items[3].outcome == 'skipped' and unconditional.report.items[3].reasons[1].code == 'x-unreachable')
end)
test('export: a branch is flattened into its arms\' conditions; the cooldowns list comes first', function()
    local r = export({rotation = {{id = 'b', type = 'branch', mode = 'evaluate', conditions = {type = 'BUFF', unit = 'player', spell = 2825},
        onTrue = {spell(403)}, onFalse = {spell(324)}}}, cooldowns = {spell(8042, nil, {})}})
    assert(r.ok and #r.apl.priorityList == 3)
    local first = r.apl.priorityList[1]
    assert(first.action.castSpell.spellId.spellId == 8042 and first.notes:find('cooldown', 1, true))
    local onTrue = json.parse(json.encode(r.apl.priorityList[2].action.condition), W.BIG).value
    assert(onTrue.auraIsActive, 'the arm carries the branch condition')
    local onFalse = json.parse(json.encode(r.apl.priorityList[3].action.condition), W.BIG).value
    assert(onFalse['not'] and onFalse['not'].val.auraIsActive, 'the other arm carries its negation')
end)
test('export: out of combat becomes pre-pull, a condition WowSims lacks is left out and listed, a pet step is not exported', function()
    local r = export({rotation = {
        spell(324, {type = 'NOT', value = {type = 'COMBAT', unit = 'player'}}),
        spell(403, {type = 'AND', value = {{type = 'SPELL_AVAIL', spell = 403}, {type = 'EQUIPPED', slot = 16}}}),
        {id = 'pet', type = 'pet', action = 1, conditions = {}},
        spell(8042, nil, {disabled = true}),
    }, cooldowns = {}})
    assert(r.ok)
    assert(#r.apl.prepullActions == 1 and #r.apl.priorityList == 1)
    local item = r.report.items[2]
    assert(item.fidelity == 'lossy' and item.reasons[1].code == 'x-cond-dropped' and item.reasons[1].params.type == 'EQUIPPED')
    assert(r.report.items[3].outcome == 'dropped' and r.report.items[3].reasons[1].code == 'x-action-pet')
    assert(r.report.items[4].outcome == 'skipped' and r.report.items[4].reasons[1].code == 'x-disabled')
    assert(r.report.summary.exported == 2 and r.report.summary.dropped == 1)
    assert(r.apl.priorityList[1].notes:find('left out', 1, true), 'the note travels with the step')
end)
test('export: on a ranked edition the first rank becomes the highest, another rank is kept; potions become the resource potion', function()
    local r = export({rotation = {spell(8042), spell(8044), {id = 'p', type = 'item', action = ns.ids.potions('era'), conditions = {}}}, cooldowns = {}}, 'era', 'MAGE')
    assert(r.ok)
    local top = r.apl.priorityList[1].action.castSpell.spellId
    assert(top.spellId == 10414 and top.rank == 7, 'first rank became the highest: ' .. tostring(top.spellId))
    local kept = r.apl.priorityList[2].action.castSpell.spellId
    assert(kept.spellId == 8044 and kept.rank == 2, 'a chosen rank is kept')
    assert(r.apl.priorityList[3].action.castSpell.spellId.otherId == 'OtherActionResourcePotion')
    -- an edition without ranks leaves ids alone
    local plain = export({rotation = {spell(8042)}, cooldowns = {}}, 'progression')
    assert(plain.apl.priorityList[1].action.castSpell.spellId.spellId == 8042 and plain.apl.priorityList[1].action.castSpell.spellId.rank == nil)
    ns.ids.release()
end)
test('export: a rotation of a class that does not use mana keeps its potions as items', function()
    local potions = ns.ids.potions('era')
    local r = export({rotation = {{id = 'p', type = 'item', action = potions, conditions = {}}}, cooldowns = {}}, 'era', 'WARRIOR')
    assert(r.ok and #r.apl.priorityList == #potions and r.apl.priorityList[1].action.castSpell.spellId.itemId == potions[1])
    local mage = export({rotation = {{id = 'p', type = 'item', action = potions, conditions = {}}}, cooldowns = {}}, 'era', 'MAGE')
    assert(#mage.apl.priorityList == 1 and mage.apl.priorityList[1].action.castSpell.spellId.otherId == 'OtherActionResourcePotion')
    ns.ids.release()
end)
test('export: the text is pretty JSON the reader takes back, and a bare APL or the settings wrapper both import', function()
    local body = W.decode(ns, W.dir .. 'export-bodies.json')['rm.tbc.shaman.enhancement.wowsims']
    local r = export({rotation = body.rotation, cooldowns = body.cooldowns}, 'tbc', 'SHAMAN')
    assert(r.ok and r.text:sub(-1) == '\n' and r.text:find('\n  "player": {', 1, true), 'two-space indent')
    assert(not r.text:find('\t'), 'no tabs')
    local back = api(r.text, {edition = 'tbc', cls = 'SHAMAN'})
    assert(back.ok, tostring(failure(back)))
    local bare = api(r.aplText, {edition = 'tbc', cls = 'SHAMAN'})
    assert(bare.ok and bare.report.summary.steps == back.report.summary.steps)
    assert(export({rotation = {}, cooldowns = {}}, 'retail').ok == false and export('nope').ok == false)
end)

-- ---- words ----------------------------------------------------------------------------------------------------------
local function loadLocale(path)
    local entries = {}
    local L = setmetatable({}, {__newindex = function(_, key, value) entries[key] = value == true and key or value end})
    local env = setmetatable({LibStub = function() return {NewLocale = function() return L end} end}, {__index = _G})
    -- enUS builds some keys from the color codes globals.lua defines first.
    local globals = assert(loadfile('globals.lua'))
    setfenv(globals, env)
    globals('RotationMaster', {})
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)
    chunk('RotationMaster')
    return entries
end
-- What the window and the host say besides the reports (UI/transfer_format.lua, UI/transfer.lua, Core/transfer_formats.lua).
local WINDOW_WORDS = {'WowSims', 'Format', 'Check export', 'WowSims has no simulator for this game version, so only the Rotation Master format is available here.',
    'The WowSims converter could not be loaded (%s). Rotation Master keeps working; use the Rotation Master format.', 'The WowSims text could not be converted: %s',
    'WowSims: {name}', 'WowSims import: {label}',
    'Imported from a WowSims rotation (APL). Steps: {steps}, disabled: {disabled}, items not imported: {skipped}. Review the disabled steps before enabling them.',
    'There is nothing to export.', 'The rotation could not be converted to WowSims: %s',
    'Converted from WowSims: %d steps, %d disabled. Choose Check import for the full report.',
    'This looks like a Rotation Master export. Set Format to Rotation Master to import it.', 'The converted rotation is too large to import (%s).',
    'This looks like WowSims JSON. Set Format to WowSims to import it.',
    "Choose the format of the text this window shows and reads. Rotation Master is the default; WowSims is the simulator's Action Priority List (JSON).",
    'Some detail may be lost converting to WowSims.', 'Some detail may be lost converting from WowSims.', 'The rotation could not be converted to WowSims.',
    'Copy this text to use it in WowSims, or paste WowSims JSON here to import it.', 'Format changed. Preview the pasted text again before importing.',
    'WowSims export report', 'WowSims import report', 'Rotation Master has no such condition', 'Help.Transfers.rotation_format',
    'The Format choice could not be shown: %s', 'The WowSims export is too long for this box (%d characters), so it cannot be shown here.'}
test('every word a report or failure can show is in the English locale, and in the other ten', function()
    local english = loadLocale('Locales/enUS.lua')
    local locales = {'deDE', 'esES', 'esMX', 'frFR', 'itIT', 'koKR', 'ptBR', 'ruRU', 'zhCN', 'zhTW'}
    local required = {}
    for _, message in ipairs(ns.api.messages()) do required[#required + 1] = message end
    assert(#required > 150)
    for _, key in ipairs(WINDOW_WORDS) do required[#required + 1] = key end
    local missing = {}
    for _, key in ipairs(required) do if english[key] == nil then missing[#missing + 1] = 'enUS: ' .. key end end
    assert(#missing == 0, table.concat(missing, '\n'))
    for _, locale in ipairs(locales) do
        local entries = loadLocale('Locales/' .. locale .. '.lua')
        local gone, same = {}, 0
        for _, key in ipairs(required) do
            if entries[key] == nil then gone[#gone + 1] = key
            elseif entries[key] == key and key:find('%s') and #key > 24 then same = same + 1 end
        end
        assert(#gone == 0, locale .. ' lacks ' .. #gone .. ' of them, for example: ' .. tostring(gone[1]))
        assert(same < 12, locale .. ' left ' .. same .. ' long sentences in English')
    end
end)
test('every reason code the converters can raise has words', function()
    local seen = {}
    local function note(report)
        for _, item in ipairs(report.items) do for _, x in ipairs(item.reasons) do seen[x.code] = true end end
    end
    for _, file in ipairs(json.keys(W.decode(ns, W.dir .. 'SOURCES.json').files)) do
        local meta = W.decode(ns, W.dir .. 'SOURCES.json').files[file]
        local r = api(W.read(W.dir .. file), {edition = meta.edition, cls = meta.class, supports = W.supports(F, meta.edition)})
        if r.ok then note(r.report) end
    end
    local bodies = W.decode(ns, W.dir .. 'export-bodies.json')
    local exported = {}
    for id, b in pairs(bodies) do
        local r = export({rotation = b.rotation, cooldowns = b.cooldowns}, b.editions[1], b.class)
        for _, item in ipairs(r.report.items) do for _, x in ipairs(item.reasons) do exported[x.code] = true end end
    end
    for code in pairs(seen) do
        if code ~= 'check' then assert(ns.render.REASON[code] or ns.render.WARNING[code], 'no words for ' .. code) end
    end
    for code in pairs(exported) do
        if code ~= 'x-branch' and code ~= 'x-stop' then assert(ns.render.XREASON[code] or code == 'x-disabled', 'no words for ' .. code) end
    end
    for code in pairs(ns.mapping.unsupportedValues) do end
    local why = {}
    for _, v in pairs(ns.mapping.unsupportedValues) do why[v] = true end
    for _, v in pairs(ns.mapping.unsupportedActions) do why[v] = true end
    for key in pairs(why) do assert(ns.render.WHY[key], 'no words for the reason ' .. key) end
    for _, entry in pairs(ns.mapping.values) do if entry.note then assert(ns.render.NOTE[entry.note], entry.note) end end
    for _, entry in pairs(ns.mapping.actions) do if entry.note and entry.handler == 'noop' then assert(ns.render.NOTE[entry.note], entry.note) end end
    for _, note_ in pairs(ns.mapping.export.trueIf) do assert(ns.render.XNOTE[note_], note_) end
    for _, note_ in pairs(ns.mapping.export.falseIf) do assert(ns.render.XNOTE[note_], note_) end
    for _, entry in pairs(ns.mapping.export.conditions) do if entry.note then assert(ns.render.XNOTE[entry.note], entry.note) end end
end)
test('the reports read as plain text with the counts, the sources and what needs attention', function()
    local L = setmetatable({}, {__index = function(_, k) return k end})
    local r = api(W.read(W.dir .. 'era_ele.apl.json'), {edition = 'era', cls = 'SHAMAN', supports = W.supports(F, 'era'), checkSpell = function() return true end})
    local words = ns.api.renderImportReport(r.report, L, {classLabel = function() return 'Shaman' end, editionLabel = function() return 'Classic Era' end})
    assert(words:find('WowSims import report', 1, true) and words:find('Converted for Shaman on Classic Era.', 1, true))
    assert(words:find('Items in the rotation: 9 (6 exact, 2 approximate, 1 lossy, 0 not representable).', 1, true), words)
    assert(words:find('Steps created: 8, disabled: 3. Items not imported: 1.', 1, true))
    assert(words:find('Confirmed by: the game client', 1, true) or words:find('WowSims simulator data', 1, true))
    assert(words:find('priorityList[1] - Approximate - Imported disabled', 1, true) and words:find('Became: spell 10438 (disabled)', 1, true))
    local x = export({rotation = {spell(403, {type = 'AND', value = {{type = 'SPELL_AVAIL', spell = 403}, {type = 'EQUIPPED', slot = 16}}})}, cooldowns = {}}, 'tbc')
    local out = ns.api.renderExportReport(x.report, L, {classLabel = function() return 'Shaman' end, editionLabel = function() return 'TBC' end})
    assert(out:find('WowSims export report', 1, true) and out:find('Steps that need attention: 1', 1, true) and out:find('EQUIPPED', 1, true) and out:find('Readable by: wowsims/tbc-new.', 1, true), out)
end)

finish()
