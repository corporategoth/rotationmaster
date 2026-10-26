-- Words for what the converters report: the failure messages and the plain-text reports the transfer window shows
-- ("Check import" / "Check export"). The caller passes its locale table L; every English text below is a key of
-- Rotation Master's locale files (Locales/enUS.lua, translated in the others), and a text with {name} slots has
-- them filled by name so a translation may reorder them. Pure: no game API.
local _, ns = ...
local render = {}
ns.render = render

local ERROR = {
    ['empty'] = 'Paste a WowSims rotation first.',
    ['not-text'] = 'That is not text.',
    ['too-large'] = 'That is larger than the limit of {limit} characters.',
    ['too-deep'] = 'The JSON is nested more than {limit} levels deep.',
    ['too-many-values'] = 'The JSON has too many values (more than {limit}).',
    ['string-too-long'] = 'The JSON has a text longer than {limit} characters.',
    ['array-too-long'] = 'The JSON has a list longer than {limit} entries.',
    ['too-many-keys'] = 'The JSON has an object with more than {limit} keys.',
    ['not-finite'] = 'The JSON has a number that is not finite.',
    ['forbidden-key'] = 'The JSON uses the key {key}, which is not allowed.',
    ['invalid-json'] = 'That is not valid JSON ({detail}).',
    ['not-json'] = "That does not look like JSON. Paste the rotation's JSON: an .apl.json file, or the simulator's exported settings.",
    ['share-link'] = 'That is a WowSims share link. It holds a compressed binary form that cannot be read here. In the simulator, export the settings as JSON and paste that instead.',
    ['not-apl'] = 'This export contains no rotation to import. In WowSims, open the Rotation tab, choose an APL (or a preset), then export again.',
    ['simple-rotation'] = 'This is a WowSims Simple rotation (fixed options and cooldown times), not an APL, so it has no priority list to import. In WowSims, open the Rotation tab, choose an APL (or a preset), then export again.',
    ['empty-apl'] = 'This rotation is empty: it has no actions to import.',
    ['several-rotations'] = 'That holds several saved rotations ({names}). Paste only the one you want.',
    ['class-mismatch'] = 'The file is for {declared}, but this character is {chosen}.',
    ['edition-mismatch'] = 'The file cannot be for {chosen}: what it contains fits only {candidates}.',
    ['edition-ids-mismatch'] = "The file's spells look like {looksLike}, not {chosen}.",
    ['class-ids-mismatch'] = "The file's spells look like {looksLike}, not {chosen}.",
    ['class-edition'] = '{cls} does not exist on {edition}.',
    ['edition-unsupported'] = 'WowSims import is not available for that edition.',
    ['edition-required'] = 'Rotation Master could not tell which game version this is.',
    ['class-required'] = 'Rotation Master could not tell which class this character is.',
    ['class-unknown'] = 'That class is not one Rotation Master knows.',
    ['nothing-imported'] = 'Nothing in that rotation could be imported. Choose Check import to see why.',
    ['not-rotation'] = 'Only rotations can be exported to WowSims.',
}
ERROR['not-an-apl'] = ERROR['not-apl']

local REASON = {
    ['action-empty'] = 'This item has no action.',
    ['action-unsupported'] = 'The action {kind} cannot be imported: {why}.',
    ['action-other-id'] = 'The action casts {id}, which is a simulator setting such as the potion, not a spell or item with an id.',
    ['action-no-id'] = 'The action has no spell or item id.',
    ['action-target'] = 'The action targets {unit}; that target is not imported.',
    ['action-friendly-spell'] = 'A cast on a friendly target is imported as a plain cast, without the target.',
    ['action-channel'] = 'Channeled spell: {parts} cannot be imported.',
    ['action-multidot'] = 'Casting on several targets is imported as a plain cast on your target, with a check that the debuff is missing; switching targets is not imported.',
    ['action-sequence'] = 'A sequence of actions is imported as {count} separate steps; Rotation Master cannot require them to follow one another.',
    ['cond-unsupported'] = 'The condition {kind} has no equivalent ({why}), so it was left out.',
    ['cond-empty'] = 'An empty condition value was left out.',
    ['cond-missing'] = 'A comparison with the maximum became a comparison with what is missing from the maximum, which Rotation Master reads as a negative number.',
    ['cond-approx'] = '{kind} was converted approximately: {note}.',
    ['cond-cmp'] = 'A comparison was left out: {why}.',
    ['cond-unit'] = 'The unit {unit} (another target or player) has no equivalent, so its condition was left out.',
    ['cond-id'] = 'A spell reference was left out: {why}.',
    ['cond-value'] = 'A value ({what}) could not be read, so its condition was left out.',
    ['cond-variable'] = 'The variable {name} is missing or refers to itself, so its condition was left out.',
    ['cond-unavailable'] = '{type} is not available on this client ({reason}), so it was left out.',
    ['cond-restricted'] = '{type} cannot be used on {edition}: {restricted}. It was left out, so the step is imported disabled.',
    ['always-false'] = 'The condition is always false in the source, so the step is imported disabled.',
    ['hidden'] = 'Hidden in the source.',
    ['id-unknown'] = 'Spell {id} was not found in: {sources}. The step is imported as converted.',
    ['id-unknown-item'] = 'Item {id} was not found in: {sources}. The step is imported as converted.',
    ['id-other-class'] = "Spell {id} appears only in other classes' lists in the simulator data, so it may belong to another class. The step is imported disabled.",
    ['group-unknown'] = 'The action group {name} does not exist in the file.',
    ['group-cycle'] = 'The action group {name} contains itself or is nested too deeply.',
    ['too-complex'] = 'Too complex to convert: its conditions expand too far.',
    ['step-limit'] = 'Rotation Master allows {limit} steps in a rotation; the rest were not imported.',
    ['item-limit'] = 'Only the first {limit} items are read.',
    ['item-bad'] = 'This entry is not an action item.',
    ['nothing-to-import'] = 'Nothing in this item can be imported.',
    ['prepull-timing'] = 'Pre-pull action ({time}): imported as a step that applies only out of combat, ahead of the priority list. The seconds are dropped.',
    ['action-noop'] = 'The action {kind} has no step to import: {note}.',
    ['action-potion'] = "The simulator's resource potion became an item step with this edition's mana potions, best first. The simulator uses the potion chosen in its settings.",
}
local WARNING = {
    ['class-unreadable'] = 'The class {text} in the file is not one Rotation Master knows.',
    ['spec-unreadable'] = 'The specialization in the file could not be matched, so none is recorded.',
    ['spec-not-in-edition'] = 'The specialization {spec} does not exist on {edition}, so none is recorded.',
}
local WHY = {
    ['fight-length'] = 'Rotation Master does not know how long the fight lasts',
    ['arithmetic'] = 'conditions cannot do arithmetic',
    ['cast-time'] = 'cast times, the global cooldown and swing timers are not conditions here',
    ['proc-tracking'] = 'trinket and proc tracking exists only in the simulator',
    ['sim-state'] = "it reads the simulator's internal state",
    ['multi-target'] = 'it looks at every target at once',
    ['spec-logic'] = "it is the simulator's own logic for this specialization",
    ['maximums'] = 'maximum values are not conditions here',
    ['regen'] = 'resource regeneration is not a condition here',
    ['boss'] = 'boss spell timers are not available',
    ['runes'] = 'this rune detail is not available',
    ['distance'] = 'unit distance is not available',
    ['sequences'] = 'sequences are not tracked',
    ['constant'] = 'not a condition',
    ['metadata'] = 'not a condition',
    ['unknown'] = 'Rotation Master does not know it',
    ['cooldowns'] = 'Rotation Master keeps cooldowns in their own Cooldowns list',
    ['timing'] = 'waiting and timed actions have no counterpart',
    ['targets'] = 'switching targets has no counterpart',
    ['sim-only'] = 'it only changes the simulation',
    ['operator'] = 'an unknown comparison',
    ['nonconst'] = 'both sides change, and Rotation Master compares only with a fixed number',
    ['operand'] = 'one side is not a number Rotation Master can read',
    ['unit'] = 'the number\'s unit does not fit, for example a percent compared with seconds',
    ['range'] = 'the number is outside what Rotation Master accepts',
    ['item-id'] = 'it names an item, not a spell',
    ['other-id'] = 'it is a simulator setting, not a spell',
    ['no-id'] = 'it has no spell id',
    ['consumables'] = "it reads the potions and food chosen in the simulator's settings",
    ['movement'] = 'movement speed is not a condition here',
}
local NOTE = {
    ['target-count'] = "the simulator's number of targets became the number of enemies you have threat on, which can differ",
    ['execute-phase'] = "the simulator's execute phase became the target's health at or below the threshold",
    ['aura-known'] = 'an aura that is known (a talent) became a spell that is known',
    ['can-cast'] = 'can cast became off cooldown; resources and range are not checked',
    ['generic-resource'] = "the class's special resource became the main power bar",
    ['rune-count'] = 'the number of runes counts the runes of that kind',
    ['autocast-cooldowns'] = 'Rotation Master runs your cooldowns from its own Cooldowns list, so add the ones you want there',
    ['auto-attack'] = 'Rotation Master suggests Attack or Shoot by itself, unless a Stop card suppresses it',
    ['gcd-ready'] = 'Rotation Master advises when you can act, so this is taken as always true',
    ['talent-known'] = 'a known talent became a known spell',
    ['swing-timer'] = 'the time until the next swing, from the swing timer',
    ['fight-length'] = 'the time left in the fight became the estimated time until your target dies, which needs the target\'s health and the combat log',
    ['rune-cooldown'] = 'the time until the next rune of that type',
}
local RESTRICTED = {
    ['secret-power'] = 'the game hides mana and the other power bars from addons there, and Rotation Master offers no condition on them',
    ['secret-health'] = 'the game hides health from addons there',
    ['combat-log-unavailable'] = 'the game does not give addons the combat log there',
    ['unsupported-policy'] = 'the game restricts combat data for addons there',
}
local XREASON = {
    ['x-cooldown-first'] = 'A Rotation Master cooldown. Cooldowns run on their own there; here the step comes first in the priority list.',
    ['x-rank'] = 'Spell {from} became {to} (rank {rank}), the highest rank, which is what a character at the level cap casts.',
    ['x-cond-dropped'] = 'The condition {type} has no WowSims equivalent ({why}), so it was left out and the step does not check it.',
    ['x-cond-approx'] = '{type} was converted approximately: {note}.',
    ['x-prepull-time'] = 'Pre-pull action: WowSims needs a time before the pull and Rotation Master has none, so the times are approximated, one second apart, the last one a second before the pull.',
    ['x-prepull-cond'] = "A pre-pull action carries no conditions, so this step's other conditions were lost.",
    ['x-item-list'] = '{count} alternative items became separate steps.',
    ['x-potion'] = "This edition's mana potions became the simulator's resource potion, which uses the potion chosen in the simulator's settings.",
    ['x-cond-never'] = 'Its conditions can never be true in the simulator (for example, only out of combat), so it was not exported.',
    ['x-disabled'] = 'Disabled in Rotation Master, so it was not exported.',
    ['x-unreachable'] = 'Never reached ({why}), so it was not exported.',
    ['x-action-pet'] = "Pet actions have no equivalent: the simulator's pet acts on its own.",
    ['x-action-assisted'] = 'Assisted Combat steps have no equivalent.',
    ['x-action-itemset'] = 'An item set by name has no equivalent: the simulator needs item ids.',
    ['x-action-id'] = 'The spell is not given by id.',
    ['x-action-unknown'] = 'This kind of step has no equivalent.',
}
local XWHY = {
    ['no-equivalent'] = 'nothing in the simulator corresponds to it',
    ['unit'] = 'that unit has none',
    ['id'] = 'the spell is not given by id',
    ['operator'] = 'that comparison has none',
    ['incomplete'] = 'the condition is incomplete',
    ['value'] = 'that value has none',
    ['class'] = 'no matching value for this class',
    ['depth'] = 'it is nested too deeply',
    ['stop'] = 'an earlier Stop ends the list',
    ['mode'] = 'its branch arm is switched off',
}
local XNOTE = {
    ['sim-combat'] = 'the simulator is always in combat, so this is always true there',
    ['sim-target'] = "the simulator's target can always be attacked",
    ['power-form'] = "a druid's power bar depends on its form; energy was assumed",
    ['target-count'] = "the number of enemies you have threat on became the simulator's number of targets",
    ['fight-length'] = 'the estimated time until your target dies became the time left in the fight',
    ['rune-cooldown'] = 'the time until the next rune of that type',
    ['rune-count'] = "the number of runes of that kind became the simulator's rune count",
    ['swing-timer'] = "the time until your next swing became the simulator's time to the next auto attack",
    ['sim-idle'] = 'the simulator only chooses an action when you are free to act, so this is never true there',
    ['sim-boss'] = "the simulator's target is a boss, so this is true for a boss or elite target and false for any other",
}
local TEXT = {
    levelExact = 'Exact', levelApproximate = 'Approximate', levelLossy = 'Lossy', levelUnsupported = 'Not representable',
    outcomeEnabled = 'Enabled', outcomeDisabled = 'Imported disabled', outcomeSkipped = 'Not imported',
    xoutcomeExported = 'Exported', xoutcomeDropped = 'Not exported', xoutcomeSkipped = 'Skipped',
    importTitle = 'WowSims import report',
    exportTitle = 'WowSims export report',
    target = 'Converted for {class} on {edition}.',
    spec = 'Specialization: {spec}.',
    summary = 'Items in the rotation: {items} ({exact} exact, {approximate} approximate, {lossy} lossy, {unsupported} not representable).',
    steps = 'Steps created: {steps}, disabled: {disabled}. Items not imported: {skipped}.',
    prepull = 'Pre-pull actions that became steps applying only out of combat, ahead of the priority list: {count}.',
    hidden = 'Hidden items skipped: {count}.',
    caveat = 'The simulator knows the whole fight; Rotation Master advises live. Even an exact step can suggest something different, so check the result in the game.',
    attention = 'Items that need attention: {count}',
    clean = 'Items imported exactly and enabled: {count}',
    original = 'Original (WowSims): {text}',
    became = 'Became: {step}',
    idsChecked = 'Spell and item ids checked: {count}.',
    idsConfirmed = 'Confirmed by: {list}.',
    idsMissing = 'Not found in those sources: {unknown} unknown, {otherClass} that belong to another class.',
    idsUnchecked = 'Could not be checked: {count}.',
    sourceClient = 'the game client',
    sourceSim = 'WowSims simulator data ({repo})',
    xsummary = 'Steps: {items} ({exact} exact, {approximate} approximate, {lossy} lossy, {unsupported} not representable).',
    xactions = 'Actions in the priority list: {actions}. Pre-pull actions: {prepull}. Steps not exported: {dropped}.',
    xreaders = 'Readable by: {list}.',
    xnoReader = 'No single simulator reads every part of it (checked: {list}), so the simulator may report unknown actions or values.',
    xstructure = 'Branches and Stops are flattened into conditions on the steps they cover, and the Cooldowns list comes first.',
    xattention = 'Steps that need attention: {count}',
    xclean = 'Steps exported exactly: {count}',
    xskipped = 'Steps skipped: {count}',
    truncated = 'The list is cut here: {count} more.',
    disabledMark = ' (disabled)',
}
render.TEXT, render.ERROR, render.REASON, render.WARNING, render.WHY, render.NOTE = TEXT, ERROR, REASON, WARNING, WHY, NOTE
render.RESTRICTED, render.XREASON, render.XWHY, render.XNOTE = RESTRICTED, XREASON, XWHY, XNOTE

--- Every English text the renderer can show (the locale files carry each of them).
function render.messages()
    local out, seen = {}, {}
    for _, group in ipairs({ERROR, REASON, WARNING, WHY, NOTE, RESTRICTED, XREASON, XWHY, XNOTE, TEXT}) do
        for _, text in pairs(group) do
            if not seen[text] then seen[text] = true; out[#out + 1] = text end
        end
    end
    table.sort(out)
    return out
end

local function fill(text, params)
    return (text:gsub('{([%w_]+)}', function(key)
        local value = params and params[key]
        if value == nil then return nil end
        if type(value) == 'number' and value == math.floor(value) then return string.format('%d', value) end
        if type(value) == 'table' then
            local parts = {}
            for _, x in ipairs(value) do parts[#parts + 1] = tostring(x) end
            return table.concat(parts, ', ')
        end
        return tostring(value)
    end))
end
local function say(L, text, params) return fill(L[text] or text, params) end

local function titleCase(slug)
    return (tostring(slug):gsub('%-', ' '):gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b end))
end

--- Words for a failed conversion (the result of api.import / api.export with ok = false).
--- opts: {classLabel(token), editionLabel(edition)}.
function render.describeError(result, L, opts)
    opts = opts or {}
    local err = result and result.error or {}
    local code = err.code or 'not-apl'
    local classLabel = opts.classLabel or function(c) return c end
    local editionLabel = opts.editionLabel or function(e) return e end
    local params = {}
    for k, v in pairs(err) do params[k] = v end
    if code == 'not-an-apl' and err.type == 'TypeSimple' then code = 'simple-rotation' end
    for _, key in ipairs({'declared', 'chosen', 'looksLike', 'cls'}) do
        if type(params[key]) == 'string' then
            local value = params[key]
            if ns.mapping.classSpecs[value] then params[key] = classLabel(value)
            elseif ns.mapping.editions[value] then params[key] = editionLabel(value) end
        end
    end
    if type(params.candidates) == 'table' then
        local labels = {}
        for _, e in ipairs(params.candidates) do labels[#labels + 1] = editionLabel(e) end
        params.candidates = labels
    end
    if params.edition then params.edition = editionLabel(params.edition) end
    if code == 'class-mismatch' then
        -- "chosen" is this character's class: say it as a class.
        params.chosen = classLabel(err.chosen)
    end
    local text = ERROR[code]
    if not text then text = ERROR['not-apl'] end
    return say(L, text, params)
end

local function reasonWords(L, reason, opts, tables)
    local params = {}
    for k, v in pairs(reason.params or {}) do params[k] = v end
    local code = reason.code
    local text = tables.reason[code]
    if not text then return code end
    -- Codes inside a reason read as words.
    if params.why then
        local why = tables.why[params.why]
        if why then params.why = say(L, why, {}) end
    end
    if params.note then
        local note = tables.note[params.note]
        if note then params.note = say(L, note, {}) end
    end
    if params.restricted then
        local restricted = RESTRICTED[params.restricted]
        if restricted then params.restricted = say(L, restricted, {}) end
    end
    if params.edition and opts.editionLabel then params.edition = opts.editionLabel(params.edition) end
    if code == 'cond-unavailable' and opts.supportReason then params.reason = opts.supportReason(params.reason) end
    if code == 'id-unknown' or code == 'id-unknown-item' then
        -- the checked sources by their words
        local words = {}
        for source in tostring(params.sources or ''):gmatch('%S+') do
            if source == 'game' then words[#words + 1] = say(L, TEXT.sourceClient, {})
            elseif source:sub(1, 4) == 'sim:' then words[#words + 1] = say(L, TEXT.sourceSim, {repo = source:sub(5)})
            else words[#words + 1] = source end
        end
        params.sources = #words > 0 and table.concat(words, ', ') or '-'
    end
    return say(L, text, params)
end

local FIDELITY_TEXT = {exact = 'levelExact', approximate = 'levelApproximate', lossy = 'levelLossy', unsupported = 'levelUnsupported'}
local OUTCOME_TEXT = {enabled = 'outcomeEnabled', disabled = 'outcomeDisabled', skipped = 'outcomeSkipped'}
local XOUTCOME_TEXT = {exported = 'xoutcomeExported', dropped = 'xoutcomeDropped', skipped = 'xoutcomeSkipped'}
local MAX_ITEMS = 300

local function describeStep(L, b)
    local action = type(b.action) == 'table' and table.concat(b.action, '+') or tostring(b.action)
    local text = b.type .. ' ' .. action .. (b.disabled and say(L, TEXT.disabledMark, {}) or '')
    if b.conditions and b.conditions ~= '' then text = text .. ': ' .. b.conditions end
    return text
end

--- The import report as plain text for the report window.
function render.importReport(report, L, opts)
    opts = opts or {}
    local classLabel = opts.classLabel or function(c) return c end
    local editionLabel = opts.editionLabel or function(e) return e end
    local lines = {}
    local function add(text) lines[#lines + 1] = text end
    local detected, summary = report.detected or {}, report.summary
    add(say(L, TEXT.importTitle, {}))
    add('')
    if detected.class and detected.edition then
        add(say(L, TEXT.target, {class = classLabel(detected.class), edition = editionLabel(detected.edition)}))
    end
    if detected.spec then add(say(L, TEXT.spec, {spec = titleCase(detected.spec)})) end
    add(say(L, TEXT.summary, summary))
    add(say(L, TEXT.steps, summary))
    if summary.prepull > 0 then add(say(L, TEXT.prepull, {count = summary.prepull})) end
    if summary.hidden > 0 then add(say(L, TEXT.hidden, {count = summary.hidden})) end
    for _, warning in ipairs(report.warnings or {}) do
        local text = WARNING[warning.code]
        if text then add(say(L, text, warning.params)) end
    end
    local ids = report.ids
    if ids then
        add(say(L, TEXT.idsChecked, {count = ids.checked}))
        local confirmed = {}
        for code in pairs(ids.bySource or {}) do
            if code == 'game' then confirmed[#confirmed + 1] = say(L, TEXT.sourceClient, {})
            elseif code:sub(1, 4) == 'sim:' then confirmed[#confirmed + 1] = say(L, TEXT.sourceSim, {repo = code:sub(5)})
            else confirmed[#confirmed + 1] = code end
        end
        table.sort(confirmed)
        if #confirmed > 0 then add(say(L, TEXT.idsConfirmed, {list = confirmed})) end
        if #ids.unknown + #ids.otherClass > 0 then add(say(L, TEXT.idsMissing, {unknown = #ids.unknown, otherClass = #ids.otherClass})) end
        if ids.unchecked > 0 then add(say(L, TEXT.idsUnchecked, {count = ids.unchecked})) end
    end
    add('')
    add(say(L, TEXT.caveat, {}))
    local tables = {reason = REASON, why = WHY, note = NOTE}
    local clean, attention = 0, {}
    for _, item in ipairs(report.items or {}) do
        if not item.hidden then
            local notable = item.fidelity ~= 'exact' or item.outcome ~= 'enabled'
            for _, r in ipairs(item.reasons) do if r.level == 'check' then notable = true end end
            if notable then attention[#attention + 1] = item else clean = clean + 1 end
        end
    end
    if #attention > 0 then
        add('')
        add(say(L, TEXT.attention, {count = #attention}))
        for index, item in ipairs(attention) do
            if index > MAX_ITEMS then add(say(L, TEXT.truncated, {count = #attention - MAX_ITEMS})); break end
            add('')
            add(item.path .. ' - ' .. say(L, TEXT[FIDELITY_TEXT[item.fidelity]], {}) .. ' - ' .. say(L, TEXT[OUTCOME_TEXT[item.outcome]], {}))
            if item.original and item.original ~= '' then add('  ' .. say(L, TEXT.original, {text = item.original})) end
            for _, step in ipairs(item.became or {}) do add('  ' .. say(L, TEXT.became, {step = describeStep(L, step)})) end
            for _, r in ipairs(item.reasons) do
                if r.level ~= 'exact' or r.code == 'always-false' then add('  - ' .. reasonWords(L, r, opts, tables)) end
            end
        end
    end
    if clean > 0 then
        add('')
        add(say(L, TEXT.clean, {count = clean}))
    end
    return table.concat(lines, '\n')
end

--- The export report as plain text.
function render.exportReport(report, L, opts)
    opts = opts or {}
    local classLabel = opts.classLabel or function(c) return c end
    local editionLabel = opts.editionLabel or function(e) return e end
    local lines = {}
    local function add(text) lines[#lines + 1] = text end
    local summary, target = report.summary, report.target
    add(say(L, TEXT.exportTitle, {}))
    add('')
    add(say(L, TEXT.target, {class = classLabel(target.cls), edition = editionLabel(target.edition)}))
    add(say(L, TEXT.xsummary, summary))
    add(say(L, TEXT.xactions, {actions = summary.actions, prepull = summary.prepull, dropped = summary.dropped}))
    local function named(list)
        local out = {}
        for _, name in ipairs(list) do out[#out + 1] = 'wowsims/' .. name end
        return out
    end
    if #target.sims > 0 then add(say(L, TEXT.xreaders, {list = named(target.sims)}))
    else add(say(L, TEXT.xnoReader, {list = named(target.candidates)})) end
    add(say(L, TEXT.xstructure, {}))
    local tables = {reason = XREASON, why = XWHY, note = XNOTE}
    local clean, attention = 0, {}
    for _, item in ipairs(report.items or {}) do
        if item.type ~= 'branch' and item.type ~= 'stop' then
            if item.outcome == 'skipped' then
                -- counted below
            elseif item.fidelity ~= 'exact' or item.outcome ~= 'exported' then attention[#attention + 1] = item
            else clean = clean + 1 end
        end
    end
    if #attention > 0 then
        add('')
        add(say(L, TEXT.xattention, {count = #attention}))
        for index, item in ipairs(attention) do
            if index > MAX_ITEMS then add(say(L, TEXT.truncated, {count = #attention - MAX_ITEMS})); break end
            add('')
            local label = item.label ~= '' and (' ' .. item.label) or ''
            local name = item.name ~= '' and (' (' .. item.name .. ')') or ''
            add(item.path .. label .. name .. ' - ' .. say(L, TEXT[FIDELITY_TEXT[item.fidelity]], {}) .. ' - ' .. say(L, TEXT[XOUTCOME_TEXT[item.outcome]], {}))
            for _, r in ipairs(item.reasons) do
                if r.level ~= 'exact' then
                    local params = {}
                    for k, v in pairs(r.params or {}) do params[k] = v end
                    local text = XREASON[r.code]
                    if text then
                        if params.why then
                            local why = XWHY[params.why]
                            if why then params.why = say(L, why, {}) end
                        end
                        if params.note then
                            local note = XNOTE[params.note]
                            if note then params.note = say(L, note, {}) end
                        end
                        add('  - ' .. say(L, text, params))
                    else add('  - ' .. tostring(r.code)) end
                end
            end
        end
    end
    local skipped = summary.skipped or 0
    if clean > 0 then add(''); add(say(L, TEXT.xclean, {count = clean})) end
    if skipped > 0 then add(say(L, TEXT.xskipped, {count = skipped})) end
    return table.concat(lines, '\n')
end
