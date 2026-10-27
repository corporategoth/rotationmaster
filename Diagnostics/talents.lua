local addon_name, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- /rm debug talents [views]: why the Retail/Forever talent lists are empty,
-- short or wrong. It reads the trait API one call at a time, the way
-- Platform/talents.lua does, and shows what each call really answered
-- (the raw error text of a failing call, which field is hidden by the game,
-- how many nodes the client calls visible), then the lists the editor builds
-- from it. The report opens in a copyable window and is kept, newest last, in
-- RotationMasterDB.diagnostics.talents (at most 3 reports of 400 lines), so
-- it survives a /reload and can be read from SavedVariables. Only reads: with
-- "views" it also lists every other specialization of the class, which fills
-- Blizzard's view loadout (the way the editor does when you pick one).
-- Nothing here runs until the command does.

local MAX_REPORTS, MAX_LINES, MAX_NODES = 3, 400, 1200

local function readable(value)
    local platform = addon.Platform
    return not platform or type(platform.CanReadValue) ~= 'function' or platform:CanReadValue(value)
end

local function show(value)
    if not readable(value) then return 'secret' end
    if value == nil then return 'nil' end
    if type(value) == 'number' and value % 1 ~= 0 then return string.format('%.3f', value) end
    return tostring(value)
end

-- A short, flat description of a value: scalars as is, a list by its first
-- members, a record by its first fields (sorted), never deeper than that.
local function describe(value, keys)
    if not readable(value) then return 'secret' end
    if type(value) ~= 'table' then return show(value) end
    local parts = {}

    if keys then
        for _, key in ipairs(keys) do
            local field = value[key]
            local text

            if not readable(field) then
                text = 'secret'
            elseif type(field) == 'table' then
                local items = {}

                for index = 1, math.min(#field, 6) do
                    items[index] = show(field[index])
                end

                text = '[' .. table.concat(items, ',') .. (#field > 6 and ',...' or '') .. '] n=' .. #field
            else
                text = show(field)
            end

            parts[#parts + 1] = key .. '=' .. text
        end

        return '{' .. table.concat(parts, ' ') .. '}'
    end

    if #value > 0 then
        local items = {}

        for index = 1, math.min(#value, 8) do
            items[index] = show(value[index])
        end

        return '[' .. table.concat(items, ',') .. (#value > 8 and ',...' or '') .. '] n=' .. #value
    end

    local names = {}

    for key in pairs(value) do
        names[#names + 1] = tostring(key)
    end

    table.sort(names)

    for index = 1, math.min(#names, 16) do
        local key = names[index]
        local field = value[key]
        if field == nil then field = value[tonumber(key)] end
        parts[#parts + 1] = key .. '=' .. (type(field) == 'table' and '<table>' or show(field))
    end

    return '{' .. table.concat(parts, ' ') .. (#names > 16 and ' ...' or '') .. '}'
end

---@return boolean ok
---@return any ...
local function call(fn, ...)
    if type(fn) ~= 'function' then return false, 'missing' end
    return pcall(fn, ...)
end

local function presence(namespace, name)
    local space = namespace and rawget(_G, namespace)
    if namespace then return type(space) == 'table' and type(space[name]) == 'function' and 'present' or 'missing' end
    return type(rawget(_G, name)) == 'function' and 'present' or 'missing'
end

local function store()
    local saved = rawget(_G, addon.savedVariableName or 'RotationMasterDB')
    if type(saved) ~= 'table' then return nil end
    local diagnostics = rawget(saved, 'diagnostics')

    if type(diagnostics) ~= 'table' then
        diagnostics = {}
        saved.diagnostics = diagnostics
    end

    local reports = diagnostics.talents

    if type(reports) ~= 'table' then
        reports = {}
        diagnostics.talents = reports
    end

    return reports
end

local NODE_KEYS = {
    'ID', 'posX', 'posY', 'type', 'isVisible', 'entryIDs', 'groupIDs', 'subTreeID', 'subTreeActive', 'activeRank',
    'maxRanks'
}

local function newReport()
    local lines = {}

    return lines, function(text, ...)
        if #lines >= MAX_LINES then
            if #lines == MAX_LINES then lines[#lines + 1] = '... (report capped at ' .. MAX_LINES .. ' lines)' end
            return
        end

        if select('#', ...) > 0 then
            local args = { ... }

            for index = 1, select('#', ...) do
                args[index] = show(args[index])
            end

            text = string.format(text, unpack(args, 1, select('#', ...)))
        end

        lines[#lines + 1] = text
    end
end

-- The groups the editor lists, in one line each.
local function listing(add, platform, spec, label)
    local ok, groups, meta = pcall(platform.GetTraitTalents, platform, spec)

    if not ok then
        add('%s: ERROR %s', label, groups)
        return
    end

    if not groups then
        add('%s: not listed, reason=%s', label, meta)
        return
    end

    add(
        '%s: source=%s nodes=%s visible=%s skipped=%s groups=%s',
        label,
        meta.source,
        meta.nodes,
        meta.visible,
        meta.skipped,
        #groups
    )

    for _, group in ipairs(groups) do
        local names = {}

        for index = 1, math.min(#group.talents, 4) do
            names[index] = group.talents[index].name
        end

        add(
            '    [%s] %s: %s talents (%s%s)',
            group.kind or '?',
            group.name or '-',
            #group.talents,
            table.concat(names, ', '),
            #group.talents > 4 and ', ...' or ''
        )
    end
end

function addon:BuildTalentDiagnostic(options)
    local platform = self.Platform
    local lines, add = newReport()
    local client = platform and platform.GetClientInfo and platform:GetClientInfo() or {}
    local okBuild, version, build = call(rawget(_G, 'GetBuildInfo'))
    add('Rotation Master talent diagnostic %s', type(date) == 'function' and date('%Y-%m-%s %H:%M:%S') or '?')

    add(
        'client %s build %s family=%s traits-layout=%s',
        okBuild and version or '?',
        okBuild and build or '?',
        client.family,
        platform and platform.GetTalentLayout and select(1, platform:GetTalentLayout()) or '?'
    )

    local okClass, className, _, classID = call(rawget(_G, 'UnitClass'), 'player')
    local okLevel, level = call(rawget(_G, 'UnitLevel'), 'player')
    local okCombat, combat = call(rawget(_G, 'InCombatLockdown'))

    add(
        'class=%s (%s) level=%s combat=%s',
        okClass and className or '?',
        okClass and classID or '?',
        okLevel and level or '?',
        okCombat and combat or '?'
    )

    local frame = rawget(_G, 'PlayerSpellsFrame')

    if type(frame) == 'table' then
        local okShown, shown = call(frame.IsShown, frame)
        local okInspect, inspecting = call(frame.IsInspecting, frame)

        add(
            "Blizzard's talent window: exists shown=%s inspecting=%s",
            okShown and shown or '?',
            okInspect and inspecting or '?'
        )
    else
        add("Blizzard's talent window: not loaded (the lists never need it)")
    end

    local played = platform and platform.GetPlayerSpecializationID and platform:GetPlayerSpecializationID()
    add('played specialization=%s', played)
    add('')
    add('== APIs')

    local names = {
        { 'C_ClassTalents', 'GetActiveConfigID' },
        { 'C_ClassTalents', 'GetHeroTalentSpecsForClassSpec' },
        { 'C_ClassTalents', 'GetTraitTreeForSpec' },
        { 'C_ClassTalents', 'InitializeViewLoadout' },
        { 'C_Traits', 'GetConfigInfo' },
        { 'C_Traits', 'GetTreeNodes' },
        { 'C_Traits', 'GetNodeInfo' },
        { 'C_Traits', 'GetEntryInfo' },
        { 'C_Traits', 'GetDefinitionInfo' },
        { 'C_Traits', 'GetSubTreeInfo' },
        { 'C_Traits', 'GetGroupDisplayInfoByTreeID' },
        { 'C_Spell', 'GetSpellInfo' },
        { 'C_Spell', 'GetSpellName' },
        { 'C_Spell', 'GetSpellTexture' },
        { 'C_SpecializationInfo', 'GetSpecialization' },
        { nil, 'GetSpecializationInfoForClassID' },
    }

    local row = {}

    for _, entry in ipairs(names) do
        row[#row + 1] = (entry[1] and entry[1] .. '.' or '') .. entry[2] .. '=' .. presence(entry[1], entry[2])
    end

    add('%s', table.concat(row, ' '))
    add('')
    add('== Active config')
    local classTalents, traits = rawget(_G, 'C_ClassTalents'), rawget(_G, 'C_Traits')
    local config, tree

    if type(classTalents) == 'table' then
        local ok, value = call(classTalents.GetActiveConfigID)
        add('C_ClassTalents.GetActiveConfigID() -> %s %s', ok and 'ok' or 'ERROR', ok and describe(value) or value)
        if ok and type(value) == 'number' then config = value end
    end

    if config and type(traits) == 'table' then
        local ok, info = call(traits.GetConfigInfo, config)

        add(
            'C_Traits.GetConfigInfo(%s) -> %s %s',
            config,
            ok and 'ok' or 'ERROR',
            ok and describe(info, { 'ID', 'type', 'name', 'treeIDs' }) or info
        )

        if ok and type(info) == 'table' and readable(info.treeIDs) and type(info.treeIDs) == 'table' then
            tree = info.treeIDs[1]
        end
    end

    if config and tree then
        add('')
        add('== Tree %s', tree)
        local ok, nodes = call(traits.GetTreeNodes, tree)

        add(
            'C_Traits.GetTreeNodes(%s) -> %s %s',
            tree,
            ok and 'ok' or 'ERROR',
            ok and ('n=' .. (type(nodes) == 'table' and #nodes or show(nodes))) or nodes
        )

        if ok and type(nodes) == 'table' then
            local good, bad, mismatch, visible, sub, selection, withSpell = 0, 0, 0, 0, 0, 0, 0
            local firstError
            local types, samples, heroSelection = {}, {}, {}

            for index = 1, math.min(#nodes, MAX_NODES) do
                local okNode, info = call(traits.GetNodeInfo, config, nodes[index])

                if not okNode then
                    bad = bad + 1
                    firstError = firstError or tostring(info)
                elseif type(info) ~= 'table' or not readable(info.ID) then
                    bad = bad + 1
                    firstError = firstError or 'unreadable record'
                elseif info.ID ~= nodes[index] then
                    mismatch = mismatch + 1
                else
                    good = good + 1

                    if readable(info.isVisible) and info.isVisible ~= false then
                        visible = visible + 1
                        local kind = readable(info.type) and tostring(info.type) or 'secret'
                        types[kind] = (types[kind] or 0) + 1
                        if readable(info.subTreeID) and info.subTreeID then sub = sub + 1 end

                        if #samples < 3 and not (readable(info.subTreeID) and info.subTreeID) and info.type ~= 3 then
                            samples[#samples + 1] = info
                        end

                        if info.type == 3 and #heroSelection < 2 then heroSelection[#heroSelection + 1] = info end
                    end
                end
            end

            add(
                'node records: readable=%s failed=%s other-config=%s visible=%s in-hero-subtrees=%s',
                good,
                bad,
                mismatch,
                visible,
                sub
            )

            if firstError then add('first node failure: %s', firstError) end
            local typeRow = {}

            for kind, count in pairs(types) do
                typeRow[#typeRow + 1] = 'type ' .. kind .. '=' .. count
            end

            table.sort(typeRow)
            add('visible node types (0 single, 1 tiered, 2 choice, 3 hero selection): %s', table.concat(typeRow, ' '))

            for _, info in ipairs(samples) do
                add('sample node %s', describe(info, NODE_KEYS))
                local entry = type(info.entryIDs) == 'table' and info.entryIDs[1]

                if entry then
                    local okEntry, entryInfo = call(traits.GetEntryInfo, config, entry)

                    add(
                        '  C_Traits.GetEntryInfo(%s) -> %s %s',
                        entry,
                        okEntry and 'ok' or 'ERROR',
                        okEntry and describe(entryInfo, { 'definitionID', 'subTreeID', 'type', 'maxRanks' })
                            or entryInfo
                    )

                    local definition = okEntry and type(entryInfo) == 'table' and entryInfo.definitionID

                    if definition then
                        local okDef, def = call(traits.GetDefinitionInfo, definition)

                        add(
                            '  C_Traits.GetDefinitionInfo(%s) -> %s %s',
                            definition,
                            okDef and 'ok' or 'ERROR',
                            okDef and describe(def, { 'spellID', 'overrideName', 'overrideIcon' }) or def
                        )

                        local spell = okDef and type(def) == 'table' and def.spellID
                        local space = rawget(_G, 'C_Spell')

                        if spell and type(space) == 'table' then
                            local okInfo, spellInfo = call(space.GetSpellInfo, spell)

                            add(
                                '  C_Spell.GetSpellInfo(%s) -> %s %s',
                                spell,
                                okInfo and 'ok' or 'ERROR',
                                okInfo and describe(spellInfo, { 'name', 'iconID', 'originalIconID', 'spellID' })
                                    or spellInfo
                            )

                            local okName, name = call(space.GetSpellName, spell)
                            add('  C_Spell.GetSpellName(%s) -> %s %s', spell, okName and 'ok' or 'ERROR', show(name))
                            local okTex, icon, original = call(space.GetSpellTexture, spell)

                            add(
                                '  C_Spell.GetSpellTexture(%s) -> %s %s %s',
                                spell,
                                okTex and 'ok' or 'ERROR',
                                show(icon),
                                show(original)
                            )
                        end
                    end
                end
            end

            for _, info in ipairs(heroSelection) do
                add('hero selection node %s', describe(info, NODE_KEYS))

                for _, entry in ipairs(type(info.entryIDs) == 'table' and info.entryIDs or {}) do
                    local okEntry, entryInfo = call(traits.GetEntryInfo, config, entry)

                    add(
                        '  entry %s -> %s %s',
                        entry,
                        okEntry and 'ok' or 'ERROR',
                        okEntry and describe(entryInfo, { 'definitionID', 'subTreeID', 'type' }) or entryInfo
                    )
                end
            end
        end

        if type(classTalents) == 'table' then
            local okHero, heroes, requiredLevel = call(classTalents.GetHeroTalentSpecsForClassSpec, config)

            add(
                'C_ClassTalents.GetHeroTalentSpecsForClassSpec(%s) -> %s %s requiredLevel=%s',
                config,
                okHero and 'ok' or 'ERROR',
                okHero and describe(heroes) or heroes,
                show(requiredLevel)
            )

            if okHero and type(heroes) == 'table' then
                for _, id in ipairs(heroes) do
                    local okSub, sub = call(traits.GetSubTreeInfo, config, id)

                    add(
                        '  C_Traits.GetSubTreeInfo(%s) -> %s %s',
                        id,
                        okSub and 'ok' or 'ERROR',
                        okSub and describe(sub, { 'ID', 'name', 'isActive' }) or sub
                    )
                end
            end
        end
    end

    add('')
    add('== What the editor lists')

    if platform and platform.GetTraitTalents then
        listing(add, platform, nil, 'played specialization')
        local choices

        if platform.GetClassSpecializationChoices and classID then
            choices = platform:GetClassSpecializationChoices(classID)
        end

        if choices then
            for _, choice in ipairs(choices) do
                if choice.id ~= played then
                    if options and options.views then
                        listing(add, platform, choice.id, choice.name .. ' (' .. choice.id .. ')')
                    else
                        add('%s (%s): not read (run /rm debug talents views)', choice.name, choice.id)
                    end
                end
            end
        else
            add('specializations of the class: not available')
        end
    else
        add('Platform:GetTraitTalents is not available on this client')
    end

    return lines
end

function addon:RunTalentDiagnostic(argument)
    local ok, built = pcall(self.BuildTalentDiagnostic, self, { views = argument == 'views' })
    ---@type string[]
    local lines

    if ok then
        lines = built
    else
        lines = { 'Talent diagnostic failed: ' .. tostring(built) }
    end

    local reports = store()

    if reports then
        reports[#reports + 1] = { at = type(date) == 'function' and date('%Y-%m-%s %H:%M:%S') or nil, lines = lines }

        while #reports > MAX_REPORTS do
            table.remove(reports, 1)
        end

        self:print(L['Talent diagnostic saved.'])
    end

    if self.ShowConditionText then self:ShowConditionText(table.concat(lines, '\n'), L['Talent diagnostic']) end
    return lines
end
