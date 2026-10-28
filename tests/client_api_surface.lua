-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The addon calls only what each real client provides, or feature-detects it.
-- tests/fixtures/client_api_<client>.lua (tools/generate_client_api.py, from Blizzard's UI
-- source and in-game API dumps) says, per client, whether each global or C_* function the
-- addon references is native, provided only while loadDeprecationFallbacks is on, or gone.
-- Every reference in addon code (TOC-loaded, not Libs/) to a name a client does not provide
-- natively must sit in a file that also uses the native replacement (the C_* API Blizzard's
-- fallback wraps, or the documented successor below), or be a reviewed feature-detected
-- read listed in GUARDED with why it is correct where the name is absent. Fixtures built
-- by tests/fixtures/addon.lua then make those names nil, so suites fail where a client would.
local pass, fail = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)

    if ok then
        pass = pass + 1
        print('PASS ' .. name)
    else
        fail = fail + 1
        print('FAIL ' .. name .. ': ' .. tostring(err))
    end
end

local api = dofile('tests/fixtures/client_api.lua')
local CLIENTS = { 'retail', 'forever', 'mists', 'tbc', 'era' }

-- Successors of globals Blizzard removed or moved behind loadDeprecationFallbacks.
local REPLACEMENT = dofile('tests/fixtures/client_api_successors.lua')

-- Reviewed reads of a name some client lacks, with no successor in the same file: each is
-- feature-detected and the feature is correctly unavailable (or done another way) there.
-- name -> {why, files[, clients=only these clients]}. A new file referencing the name fails
-- until it is reviewed here.
local GUARDED = {
    ActionButton_CalculateAction = {
        'Third-party bars only; Blizzard buttons answer button:CalculateAction() first.',
        { 'buttons.lua' },
    },
    ActionButton_GetPagedID = {
        'Third-party bars only; Blizzard buttons answer button:GetPagedID() first.',
        { 'buttons.lua' },
    },
    BOOKTYPE_SPELL = {
        'Compared as (BOOKTYPE_SPELL or "spell"): the literal Blizzard used before 11.0 removed the global.',
        { 'Platform/actions.lua', 'Platform/spellbook.lua', 'Platform/spells.lua', 'main.lua' },
    },
    BOOKTYPE_PET = {
        'Compared as (BOOKTYPE_PET or "pet"): the literal Blizzard used before 11.0 removed the global.',
        {
            'Conditions/common.lua', 'Conditions/petspell.lua', 'Core/spell_catalog.lua', 'Core/spell_search.lua',
            'Platform/actions.lua', 'Platform/spellbook.lua', 'UI/rotation_fields.lua', 'UI/settings_announces.lua',
            'init.lua', 'main.lua'
        },
    },
    IsPassiveSpell = {
        'Legacy spellbook scan only (no C_SpellBook.GetSpellBookItemInfo); the modern scan reads isPassive from the record.',
        { 'Platform/spellbook.lua' },
    },
    GetRuneType = {
        'Rune types exist only through Mists (DK); elsewhere the RUNE reader reports missing-api, by design.',
        { 'Platform/runes.lua' },
    },
    GetNumGlyphSockets = {
        'Glyph reader is gated on the client\'s glyph layout (Mists); missing-api elsewhere.',
        { 'Platform/glyphs.lua' },
    },
    GetGlyphSocketInfo = {
        'Glyph reader is gated on the client\'s glyph layout (Mists); missing-api elsewhere.',
        { 'Platform/glyphs.lua' },
    },
    GetNumTalentTabs = {
        'Tree talent layout only (Era/TBC); Retail/Forever read trait trees.',
        { 'Platform/talents.lua' },
    },
    GetNumTalents = {
        'Tree talent layout only (Era/TBC); Retail/Forever read trait trees.',
        { 'Platform/talents.lua' },
    },
    GetNumTalentGroups = {
        'Talent-group layout only (Mists); single on Era/TBC, specialization on Retail/Forever.',
        { 'Platform/specializations.lua' },
    },
    AssistedCombatManager = {
        'Assisted highlight reports missing-highlighter where Blizzard has no Assisted Combat (Classic).',
        { 'Platform/assisted_combat.lua' },
    },
    WOW_PROJECT_CAMELOT = {
        'Project constants are compared only when they are numbers.',
        { 'Core/condition_runtime.lua', 'Platform/client.lua' },
    },
    ['C_ClassTalents'] = {
        'Trait loadouts exist only on Retail/Forever; type-checked.',
        { 'Core/build_context.lua', 'Platform/talents.lua', 'Platform/talent_tree.lua', 'Platform/world_state.lua' },
    },
    ['C_ClassTalents.GetActiveHeroTalentSpec'] = {
        'Hero talents exist only on Retail; HERO_TALENT is declared unavailable elsewhere (Core/condition_support.lua) and the reader reports missing-api.',
        { 'Platform/world_state.lua' },
    },
    ['C_ChallengeMode.GetActiveKeystoneInfo'] = {
        'Mythic+ keystones exist only on Retail; KEYSTONE_LEVEL is declared unavailable elsewhere and the reader reports missing-api.',
        { 'Platform/world_state.lua' },
    },
    GetEclipseDirection = {
        'Eclipse exists only in Wrath through Mists; ECLIPSE is declared unavailable elsewhere and the reader reports missing-api.',
        { 'Platform/edition_state.lua' },
    },
    GetPetHappiness = {
        'Hunter pet happiness exists only in Classic Era, Burning Crusade and Wrath; PET_HAPPINESS is declared unavailable elsewhere and the reader reports missing-api.',
        { 'Platform/edition_state.lua' },
    },
    ['C_ClassTalents.GetActiveConfigID'] = {
        'Inside the type-checked C_ClassTalents branch.',
        { 'Core/build_context.lua' },
    },
    ['C_ClassTalents.GetLastSelectedSavedConfigID'] = {
        'Inside the type-checked C_ClassTalents branch.',
        { 'Core/build_context.lua' },
    },
    ['C_Engraving'] = {
        'Season of Discovery runes; type-checked, missing elsewhere by design.',
        { 'Core/build_context.lua', 'Platform/engraving.lua' },
    },
    ['C_GameRules.IsHardcoreActive'] = {
        'Probed only when C_GameRules exists; absent = not hardcore.',
        { 'Platform/client.lua' },
    },
    ['C_GameRules.IsSelfFoundAllowed'] = { 'Probed only when C_GameRules exists.', { 'Platform/client.lua' } },
    ['C_Seasons'] = { 'Classic seasons only; nil-checked.', { 'Platform/client.lua' } },
    ['C_Seasons.GetActiveSeason'] = { 'Inside the nil-checked C_Seasons branch.', { 'Platform/client.lua' } },
    GetItemCooldown = {
        'Classic: C_Item.GetItemCooldown does not exist there and the fallback wraps it; the reader prefers C_Container.GetItemCooldown, the global last.',
        { 'Platform/items.lua' },
    },
    ['C_PaperDollInfo.GetTemporaryEnchantmentInfo'] = {
        'Retail/Forever composed weapon-enchant reader; nil-checked, Classic reads the native GetWeaponEnchantInfo.',
        { 'Conditions/build.lua', 'Conditions/weapon.lua', 'Core/build_context.lua', 'Platform/items.lua' },
    },
    ['C_PaperDollInfo.GetInventorySlotInfo'] = {
        'Forever ranged slot (its global is fallback-only); Classic reads the native GetInventorySlotInfo.',
        { 'Core/build_context.lua' },
    },
    ['C_CombatLog.GetCurrentEventInfo'] = {
        'Retail/Forever never dispatch the combat-log handler (restricted policy); Classic has it.',
        { 'main.lua' },
    },
    UnitAura = { 'Era registers LibClassicDurations only while the UnitAura global it wraps exists.', { 'main.lua' } },
    NUM_TOTAL_EQUIPPED_BAG_SLOTS = {
        'Retail/Forever bag count; nil means the Classic bag range (NUM_BAG_SLOTS).',
        { 'Platform/inventory.lua' },
    },
    WOW_PROJECT_BURNING_CRUSADE_CLASSIC = {
        'Classic project constants are compared only when they are numbers.',
        { 'Core/condition_runtime.lua', 'Platform/client.lua' },
    },
    WOW_PROJECT_WRATH_CLASSIC = {
        'Classic project constants are compared only when they are numbers.',
        { 'Core/condition_runtime.lua', 'Platform/client.lua', 'Platform/points.lua' },
    },
    WOW_PROJECT_CATACLYSM_CLASSIC = {
        'Classic project constants are compared only when they are numbers.',
        { 'Core/condition_runtime.lua', 'Platform/client.lua', 'Platform/points.lua' },
    },
    WOW_PROJECT_MISTS_CLASSIC = {
        'Classic project constants are compared only when they are numbers.',
        { 'Core/condition_runtime.lua', 'Platform/client.lua', 'Platform/points.lua' },
    },
    ['C_Item.GetItemCooldown'] = {
        'Retail/Forever; Classic falls back to C_Container.GetItemCooldown.',
        { 'Platform/items.lua' },
    },
    ['C_Item.GetItemStats'] = { 'Falls back to the native GetItemStats on Classic.', { 'Core/build_context.lua' } },
    ['C_Macro.GetMacroIcons'] = { 'Falls back to the native GetMacroIcons.', { 'UI/icon_picker.lua' } },
    ['C_Macro.GetMacroItemIcons'] = { 'Falls back to the native GetMacroItemIcons.', { 'UI/icon_picker.lua' } },
    ['C_Spell.GetBaseSpell'] = { 'Diagnostic only; protected call.', { 'Diagnostics/glow.lua' } },
    ['C_Spell.GetOverrideSpell'] = { 'Diagnostic only; protected call.', { 'Diagnostics/glow.lua' } },
    ['C_SpellBook.GetNumSpellBookSkillLines'] = {
        'Modern spellbook scan; Classic uses GetNumSpellTabs.',
        { 'Platform/spellbook.lua' },
    },
    ['C_SpellBook.GetSpellBookItemInfo'] = {
        'Modern spellbook scan; Classic uses GetSpellBookItemInfo.',
        { 'Platform/spellbook.lua' },
    },
    ['C_SpellBook.GetSpellBookSkillLineInfo'] = {
        'Modern spellbook scan; Classic uses GetSpellTabInfo.',
        { 'Platform/spellbook.lua' },
    },
    ['C_Traits.GetGroupDisplayInfoByTreeID'] = { 'Forever talent trees; type-checked.', { 'Platform/talents.lua' } },
    CombatLogGetCurrentEventInfo = {
        'Retail/Forever only: combat-log payloads are read under the probe policy (Classic); restricted clients never dispatch the handler.',
        { 'main.lua' },
        clients = { retail = true, forever = true },
    },
}

local manifests, status = {}, {}

for _, client in ipairs(CLIENTS) do
    local m = api.manifest(client)
    manifests[client] = m
    local s = {}

    for _, n in ipairs(m.native) do
        s[n] = 'native'
    end

    for n in pairs(m.deprecated) do
        s[n] = 'deprecated'
    end

    for _, n in ipairs(m.removed) do
        s[n] = 'removed'
    end

    for _, n in ipairs(m.never) do
        s[n] = 'never'
    end

    status[client] = s
end

local excluded = {}

for _, n in ipairs(manifests.retail.excluded) do
    excluded[n] = true
end

-- Addon (TOC-loaded, non-vendor) files and what each reads, from luac's listing.
local files = {}

for line in io.lines('RotationMaster.toc') do
    line = line:gsub('\r', '')

    if line:match('%.lua$') and not line:match('^#') and not line:match('^Libs/') then
        files[#files + 1] = line:gsub('\\', '/')
    end
end

files[#files + 1] = 'LibsAugment/FAIAP.lua'

for line in io.lines('locales.xml') do
    local f = line:match('file="([^"]+%.lua)"')

    if f then
        files[#files + 1] = f:gsub('\\', '/')
    end
end

local refs, sites, assigned, sources = {}, {}, {}, {}

for _, file in ipairs(files) do
    local p = assert(io.popen('luac5.1 -l -p ' .. file .. ' 2>&1'))
    local listing = p:read('*a')
    p:close()
    assert(listing:find('main <'), file .. ': ' .. listing)
    local fileRefs, fileSites, reg = {}, {}, {}

    for line in listing:gmatch('[^\n]+') do
        if line:match('^main <') or line:match('^function <') then
            reg = {}
        else
            local op, a, b, c, comment = line:match(
                '^%s*%d+%s+%[%d+%]%s+(%u+)%s+(%-?%d+)%s*(%-?%d*)%s*(%-?%d*)%s*;?%s*(.*)$'
            )

            if op then
                a = tonumber(a)

                if op == 'GETGLOBAL' then
                    reg[a] = comment
                    fileRefs[comment] = true
                    fileSites[comment] = (fileSites[comment] or 0) + 1
                elseif op == 'GETTABLE' and reg[tonumber(b)] and tonumber(c) and tonumber(c) < 0 and comment:match(
                    '"([^"]*)"%s*$'
                ) then
                    local base = reg[tonumber(b)]
                    local key = comment:match('"([^"]*)"%s*$')
                    local path = base == '_G' and key or base .. '.' .. key
                    fileRefs[path] = true
                    fileSites[path] = (fileSites[path] or 0) + 1
                    reg[a] = path
                else
                    if op == 'SETGLOBAL' then
                        assigned[comment] = true
                    end

                    reg[a] = nil
                end
            end
        end
    end

    local h = assert(io.open(file))
    sources[file] = h:read('*a')
    h:close()
    refs[file], sites[file] = fileRefs, fileSites
end

local function clientName(n)
    local top = n:match('^[^.]+')

    if excluded[top] or assigned[top] then
        return false
    end

    local dots = select(2, n:gsub('%.', ''))

    if dots > 1 and top ~= 'Enum' then
        return false
    end
    if dots == 1 and not (top:match('^C_') or top == 'Enum') then
        return false
    end

    return true
end

-- A file uses NS.Fn when luac sees the path, or it reads NS and names Fn (namespace[name], or
-- a field of a local holding the namespace).
local function uses(file, path)
    if refs[file][path] then
        return true
    end

    local ns, fn = path:match('^([%w_]+)%.([%w_]+)$')

    if not ns then
        return false
    end

    local src = sources[file]

    return refs[file][ns]
        and (src:find('"' .. fn .. '"', 1, true) or src:find("'" .. fn .. "'", 1, true) or src:find(
            '%.' .. fn .. '%f[^%w_]'
        ))
        and true
        or false
end

test('every client name the addon reads is classified for all five clients', function()
    local missing = {}

    for _, file in ipairs(files) do
        for n in pairs(refs[file]) do
            if clientName(n) then
                for _, client in ipairs(CLIENTS) do
                    if not status[client][n] then
                        missing[#missing + 1] = client .. ':' .. n .. ' (' .. file .. ')'
                    end
                end
            end
        end
    end

    table.sort(missing)
    assert(#missing == 0, 'unclassified (run tools/generate_client_api.py --write): ' .. table.concat(missing, ', '))
end)

test(
    'a name a client lacks is read only beside its native successor, or is a reviewed feature-detected read',
    function()
        local problems = {}

        for _, file in ipairs(files) do
            for n in pairs(refs[file]) do
                if clientName(n) then
                    for _, client in ipairs(CLIENTS) do
                        local st = status[client][n]

                        if st and st ~= 'native' then
                            local forward = manifests[client].deprecated[n]
                            local successor = type(forward) == 'string' and forward or REPLACEMENT[n]
                            local ok = false

                            for _, candidate in ipairs({
                                type(forward) == 'string' and forward or false,
                                REPLACEMENT[n] or false,
                            }) do
                                if candidate and status[client][candidate] == 'native' and uses(file, candidate) then
                                    ok = true
                                end
                            end

                            local entry = GUARDED[n]

                            if not ok and entry and (not entry.clients or entry.clients[client]) then
                                for _, allowed in ipairs(entry[2]) do
                                    if allowed == file then
                                        ok = true
                                    end
                                end
                            end

                            if not ok then
                                problems[#problems + 1] = ('%s reads %s (%s on %s%s)'):format(
                                    file,
                                    n,
                                    st,
                                    client,
                                    successor and ', without ' .. successor or ''
                                )
                            end
                        end
                    end
                end
            end
        end

        table.sort(problems)
        assert(#problems == 0, '\n  ' .. table.concat(problems, '\n  '))
    end
)

test('the reviewed list names only reads that still exist', function()
    local stale = {}

    for n, entry in pairs(GUARDED) do
        for _, file in ipairs(entry[2]) do
            if not (refs[file] and refs[file][n]) then
                stale[#stale + 1] = n .. ' in ' .. file
            end
        end
    end

    table.sort(stale)
    assert(#stale == 0, 'no longer read: ' .. table.concat(stale, ', '))
end)

-- A name no current client provides is either a fallback for builds older than these
-- manifests, read only after its native successor was not found, or a mistake (the
-- addon once read C_GameRules.IsSelfFoundActive, which never existed; the API is
-- C_PlayerInfo.IsSelfFoundActive). Each one is listed here after review.
local LEGACY = {
    ActionButton_CalculateAction = true,
    ActionButton_GetPagedID = true,  -- after button:CalculateAction/GetPagedID
    ['C_Macro.GetMacroIcons'] = true,
    ['C_Macro.GetMacroItemIcons'] = true,  -- before the native GetMacroIcons
    GetAddOnMetadata = true,
    IsAddOnLoaded = true,
    LoadAddOn = true,  -- after C_AddOns
    GetContainerItemInfo = true,
    GetContainerNumSlots = true,  -- after C_Container
    GetMouseFocus = true,  -- after GetMouseFoci
    InterfaceOptionsFrame_OpenToCategory = true,
    InterfaceOptions_AddCategory = true,  -- after Settings
    IsRaidLeader = true,  -- after UnitIsGroupLeader
}

test('a name no current client provides is a reviewed legacy fallback', function()
    local found, problems = {}, {}

    for _, file in ipairs(files) do
        for n in pairs(refs[file]) do
            if clientName(n) then
                local provided = false

                for _, client in ipairs(CLIENTS) do
                    local st = status[client][n]

                    if st == 'native' or st == 'deprecated' then
                        provided = true
                    end
                end

                if not provided then
                    found[n] = true

                    if not LEGACY[n] then
                        problems[#problems + 1] = n .. ' (' .. file .. ')'
                    end
                end
            end
        end
    end

    for n in pairs(LEGACY) do
        if not found[n] then
            problems[#problems + 1] = n .. ' is no longer read'
        end
    end

    table.sort(problems)
    assert(#problems == 0, table.concat(problems, ', '))
end)

-- Condition support requirements are alternatives (any one present suffices). A
-- requirement that names a fallback-only global must also name the API it wraps, or the
-- condition is unsupported on a client with the CVar off although it would work.
test('condition requirements name the native API beside any fallback-only global', function()
    local source = sources['Core/condition_support.lua']
    local problems = {}

    for group in source:gmatch('{(\'[^{}]-\')}') do
        local names = {}

        for n in group:gmatch("'([%w_%.]+)'") do
            names[#names + 1] = n
        end

        for _, client in ipairs(CLIENTS) do
            for _, n in ipairs(names) do
                local forward = manifests[client].deprecated[n]

                if type(forward) == 'string' and status[client][forward] == 'native' then
                    local listed = false

                    for _, other in ipairs(names) do
                        if other == forward or other == REPLACEMENT[n] then
                            listed = true
                        end
                    end

                    if not listed then
                        problems[#problems + 1] = ('{%s} on %s needs %s'):format(group, client, forward)
                    end
                end
            end
        end
    end

    table.sort(problems)
    assert(#problems == 0, table.concat(problems, '; '))
end)

test('fixtures built by tests/fixtures/addon.lua hold only what the client provides', function()
    local F = dofile('tests/fixtures/addon.lua')
    local f = F.new(1, 12, 'MONK')
    local e = f.env
    e.BOOKTYPE_SPELL = 'spell'
    e.GetSpellInfo = function() end
    e.HasAction = function() end
    e.C_Item = { GetItemInfo = function() end, GetItemStats = function() end }

    assert(
        e.BOOKTYPE_SPELL == nil and e.GetSpellInfo == nil and e.HasAction == nil,
        'Retail fixture kept a removed or fallback-only global'
    )

    assert(
        type(e.C_Item.GetItemInfo) == 'function' and type(e.C_Item.GetItemStats) == 'function',
        'native C_Item functions dropped'
    )

    assert(
        rawget(e, 'WOW_PROJECT_CAMELOT') == nil and e.WOW_PROJECT_CAMELOT == nil,
        'Retail has no WOW_PROJECT_CAMELOT'
    )

    local g = F.new(1, 12, 'MONK', { fallbacks = true }).env
    g.HasAction = function() end
    g.GetSpellInfo = function() end

    assert(
        type(g.HasAction) == 'function' and g.GetSpellInfo == nil,
        'loadDeprecationFallbacks=1 keeps HasAction, never GetSpellInfo'
    )

    local era = F.new(2, 0, 'MAGE').env
    era.C_Item = { GetItemInfo = function() end, GetItemCooldown = function() end }
    era.GetSpellInfo = function() end
    era.HasAction = function() end

    assert(
        era.C_Item.GetItemCooldown == nil and type(era.C_Item.GetItemInfo) == 'function',
        'Era has no C_Item.GetItemCooldown'
    )

    assert(
        type(era.GetSpellInfo) == 'function' and type(era.HasAction) == 'function',
        'Era default (fallbacks on) keeps both'
    )

    local strict = F.new(2, 0, 'MAGE', { fallbacks = false }).env
    strict.HasAction = function() end
    strict.UnitAura = function() end
    strict.CombatLogGetCurrentEventInfo = function() end

    assert(
        strict.HasAction == nil and strict.UnitAura == nil and strict.CombatLogGetCurrentEventInfo == nil,
        'Era with the CVar off'
    )
end)

test('the manifests record their sources and Blizzard\'s fallback default', function()
    for _, client in ipairs(CLIENTS) do
        local m = manifests[client]

        assert(
            m.client == client and type(m.project) == 'number' and #m.sources.ui == 40 and #m.sources.resources == 40,
            client
        )

        assert(
            m.fallbackCVarDefault == '1',
            client .. ' loadDeprecationFallbacks default ' .. tostring(m.fallbackCVarDefault)
        )

        assert(api.byProject[m.project] == client, client .. ' project ' .. m.project)
    end
end)

print(pass .. ' passed, ' .. fail .. ' failed')
os.exit(fail > 0 and 1 or 0)
