-- The real addon loaded as the client loads it: every file the TOC lists, in order, with the
-- real embedded libraries (embeds.xml), the English locale, then the character's Built In
-- class module loaded on demand from its edition's TOC (Core/builtin_modules.lua), and the
-- AceAddon lifecycle (OnInitialize, OnEnable) run as ADDON_LOADED and PLAYER_LOGIN would.
-- Only the WoW API is modelled; the environment holds only what the named client provides
-- (tests/fixtures/client_api.lua), so a stub cannot model an API that client lacks.
--
-- T.new{project=1, expansion=12, class='MONK', classID=10, level=10, spec=268, specIndex=1,
--       saved=<RotationMasterDB>, specs={[index]={id,name}}}
-- returns {env, addon, state, fire(event,...), load(path)}; state.level / state.specIndex /
-- state.inCombat may be changed and an event fired (PLAYER_LEVEL_UP, PLAYER_SPECIALIZATION_CHANGED).
local T = {}
local client = dofile('tests/fixtures/client_api.lua')

local function lines(path)
    local list = {}

    for line in io.lines(path) do
        list[#list + 1] = line:gsub('\r', '')
    end

    return list
end

-- Paths an XML include list names, recursively, in order.
local function xmlFiles(path, out)
    out = out or {}
    local dir = path:match('^(.*)/[^/]*$') or '.'
    local h = assert(io.open(path))
    local text = h:read('*a'):gsub('<!%-%-.-%-%->', '')
    h:close()

    for tag, file in text:gmatch('<(%a+)%s+file%s*=%s*"([^"]+)"') do
        local resolved = (dir == '.' and '' or dir .. '/') .. file:gsub('\\', '/')

        if tag == 'Script' then
            out[#out + 1] = resolved
        elseif tag == 'Include' then
            xmlFiles(resolved, out)
        end
    end

    return out
end

local CLASSES = {
    WARRIOR = 1,
    PALADIN = 2,
    HUNTER = 3,
    ROGUE = 4,
    PRIEST = 5,
    DEATHKNIGHT = 6,
    SHAMAN = 7,
    MAGE = 8,
    WARLOCK = 9,
    MONK = 10,
    DRUID = 11,
    DEMONHUNTER = 12,
    EVOKER = 13,
}

local FAMILY = { [1] = 'retail', [18] = 'forever', [19] = 'mists', [5] = 'tbc', [2] = 'era' }
local MODULE_FLAVOR = { retail = 'Standard', forever = 'Forever', mists = 'Mists', tbc = 'TBC', era = 'Vanilla' }

function T.new(o)
    o = o or {}
    local project, expansion, class = o.project or 1, o.expansion or 12, o.class or 'MONK'
    local classID = o.classID or CLASSES[class]
    local state = { level = o.level or 10, specIndex = o.specIndex or 1, inCombat = false, clock = 100 }
    local env = setmetatable({}, { __index = _G })
    env._G = env

    -- Lua globals the client has, raw on the environment (the addon captures some).
    for _, key in ipairs({
        'type', 'pairs', 'ipairs', 'next', 'rawget', 'rawset', 'rawequal', 'getmetatable', 'setmetatable', 'getfenv',
        'setfenv', 'math', 'table', 'string', 'tonumber', 'tostring', 'unpack', 'select', 'pcall', 'xpcall', 'error',
        'assert', 'loadstring', 'coroutine', 'debugstack', 'date', 'time'
    }) do
        rawset(env, key, _G[key])
    end

    -- WoW's xpcall passes extra arguments to the function (Lua 5.1's does not).
    rawset(env, 'xpcall', function(fn, handler, ...)
        local n, args = select('#', ...), { ... }
        return xpcall(function() return fn(unpack(args, 1, n)) end, handler)
    end)

    -- getfenv(0) is the client's global table: this environment.
    local hostGetfenv = getfenv

    rawset(env, 'getfenv', function(f)
        if f == 0 then
            return env
        end

        if f == nil then
            f = 1
        end

        local result

        if type(f) == 'number' then
            result = hostGetfenv(f + 1)
        else
            result = hostGetfenv(f)
        end

        return result  -- not a tail call: LuaJIT drops this frame from a tail call's level count
    end)

    local clientName = client.byProject[project]

    client.install(env, clientName, {
        fallbacks = o.fallbacks == true or (clientName ~= 'retail' and clientName ~= 'forever'),
    })

    dofile('tests/fixtures/native_ui.lua')(env)
    env.WOW_PROJECT_MAINLINE, env.WOW_PROJECT_CLASSIC, env.WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 1, 2, 5

    env.WOW_PROJECT_MISTS_CLASSIC, env.WOW_PROJECT_WRATH_CLASSIC, env.WOW_PROJECT_CATACLYSM_CLASSIC, env.WOW_PROJECT_CAMELOT =
        19, 11, 14, 18

    env.WOW_PROJECT_ID, env.LE_EXPANSION_LEVEL_CURRENT = project, expansion

    env.DEFAULT, env.NAME, env.DELETE, env.OFF, env.PRIMARY, env.SECONDARY =
        'Default', 'Name', 'Delete', 'Off', 'Primary', 'Secondary'

    env.EDIT, env.COMBAT, env.HEALTH, env.MANA = 'Edit', 'Combat', 'Health', 'Mana'
    env.NORMAL_FONT_COLOR_CODE, env.FONT_COLOR_CODE_CLOSE = '', ''
    env.BOOKTYPE_SPELL, env.BOOKTYPE_PET = 'spell', 'pet'
    env.NUM_BAG_SLOTS = 4

    env.Enum = {
        SpellBookSpellBank = { Player = 0, Pet = 1 },
        PowerType = {
            Mana = 0,
            Rage = 1,
            Focus = 2,
            Energy = 3,
            ComboPoints = 4,
            Runes = 5,
            RunicPower = 6,
            SoulShards = 7,
            LunarPower = 8,
            HolyPower = 9,
            Maelstrom = 11,
            Chi = 12,
            Insanity = 13,
            ArcaneCharges = 16,
            Fury = 17,
            Pain = 18,
            Essence = 19,
        },
    }

    -- The client's 32-bit bit library (LuaJIT's under luajit; arithmetic under lua5.1).
    local ok, bitlib = pcall(require, 'bit')

    if not ok then
        local function op(a, b, f)
            local r, p = 0, 1
            a, b = a % 4294967296, b % 4294967296

            for _ = 1, 32 do
                local x, y = a % 2, b % 2

                if f(x, y) then
                    r = r + p
                end

                a, b = (a - x) / 2, (b - y) / 2
                p = p * 2
            end

            return r
        end

        bitlib = {
            band = function(a, b) return op(a, b, function(x, y) return x == 1 and y == 1 end) end,
            bor = function(a, b) return op(a, b, function(x, y) return x == 1 or y == 1 end) end,
            bxor = function(a, b) return op(a, b, function(x, y) return x ~= y end) end,
            bnot = function(a) return 4294967295 - a % 4294967296 end,
            lshift = function(a, n) return (a * 2 ^ n) % 4294967296 end,
            rshift = function(a, n) return math.floor((a % 4294967296) / 2 ^ n) end,
        }
    end

    env.bit = bitlib
    env.issecretvalue = function() return false end
    env.canaccessvalue = function() return true end
    env.C_Secrets = { HasSecretRestrictions = function() return project == 1 or project == 18 end }
    env.GetTime = function() return state.clock end
    env.time = os.time
    env.GetLocale = function() return o.locale or 'enUS' end

    local BUILDS = {
        [1] = { '12.1.5', '70575', 120105 },
        [18] = { '12.0.5', '70000', 120005 },
        [19] = { '5.5.1', '63000', 50501 },
        [5] = { '2.5.5', '65000', 20505 },
        [2] = { '1.15.7', '64000', 11507 },
    }

    local build = BUILDS[project] or BUILDS[1]
    env.GetBuildInfo = function() return build[1], build[2], 'Oct 1 2026', build[3] end
    env.GetRealmName = function() return 'Fixture Realm' end
    env.GetCurrentRegion = function() return 1 end
    env.GetCurrentRegionName = function() return 'US' end
    env.UnitName = function(unit) return unit == 'player' and 'Fixture' or nil end
    env.UnitNameUnmodified = env.UnitName
    env.UnitGUID = function(unit) return unit == 'player' and 'Player-1-0001' or nil end

    env.UnitClass = function(unit)
        if unit == 'player' then
            return class:sub(1, 1) .. class:sub(2):lower(), class, classID
        end
    end

    env.UnitRace = function() return 'Pandaren', 'Pandaren' end
    env.UnitFactionGroup = function() return 'Horde' end
    env.UnitLevel = function(unit) return unit == 'player' and state.level or 0 end
    env.UnitExists = function(unit) return unit == 'player' end
    env.UnitAffectingCombat = function(unit) return unit == 'player' and state.inCombat end
    env.InCombatLockdown = function() return state.inCombat end
    env.UnitHasVehicleUI = function() return false end
    env.UnitInVehicle = function() return false end
    env.UnitIsDeadOrGhost = function() return false end
    env.strlenutf8 = function(s) return #s end
    env.securecallfunction = function(fn, ...) return fn(...) end

    env.geterrorhandler = function()
        return function(e)
            error(e, 0)
        end
    end

    env.hooksecurefunc = function() end

    env.tinsert, env.tremove, env.wipe = table.insert, table.remove, function(t)
        for k in pairs(t) do
            t[k] = nil
        end

        return t
    end

    env.strsplit = function(sep, s)
        local out = {}

        for part in (s .. sep):gmatch('(.-)' .. sep:gsub('%p', '%%%0')) do
            out[#out + 1] = part
        end

        return unpack(out)
    end

    env.strtrim = function(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end
    env.format = string.format
    env.IsLoggedIn = function() return true end
    env.GetCVar = function() return '0' end
    env.C_CVar = { GetCVar = function() return '0' end }
    env.C_EventUtils = { IsEventValid = function() return true end }
    env.IsSpellKnown = function() return true end
    env.IsPlayerSpell = function() return true end
    env.GetNumShapeshiftForms = function() return 0 end
    env.GetSpecialization = nil

    local specs = o.specs or {
        [1] = { 268, 'Brewmaster' },
        [2] = { 270, 'Mistweaver' },
        [3] = { 269, 'Windwalker' },
        [5] = { 1450, 'Initial' },
    }

    env.C_SpecializationInfo = {
        GetSpecialization = function() return state.specIndex end,
        GetSpecializationInfo = function(i)
            local entry = specs[i]

            if entry then
                return entry[1], entry[2], '', 1, 'DAMAGER'
            end
        end,
        GetNumSpecializationsForClassID = function()
            local n = 0

            for i = 1, 4 do
                if specs[i] then
                    n = i
                end
            end

            return n
        end,
        GetActiveSpecGroup = function() return 1 end,
    }

    env.GetSpecializationInfoForClassID = function(_, i)
        local entry = specs[i]

        if entry and i < 5 then
            return entry[1], entry[2], '', 1, 'DAMAGER'
        end
    end

    env.GetNumSpecializationsForClassID = env.C_SpecializationInfo.GetNumSpecializationsForClassID

    env.C_AssistedCombat = {
        IsAvailable = function() return true end,
        GetNextCastSpell = function() return nil end,
        GetRotationSpells = function() return {} end,
        GetActionSpell = function() return nil end,
    }

    env.C_Spell = {
        GetSpellInfo = function(id) return { spellID = id, name = 'Spell ' .. tostring(id), iconID = 1 } end,
        GetSpellName = function(id) return 'Spell ' .. tostring(id) end,
        GetSpellLink = function(id) return 'spell:' .. tostring(id) end,
        GetSpellCooldown = function() return { startTime = 0, duration = 0, isEnabled = true, modRate = 1 } end,
        IsSpellUsable = function() return true, false end,
        SpellHasRange = function() return true end,
        IsSpellInRange = function() return true end,
        IsCurrentSpell = function() return false end,
        GetSpellTexture = function() return 1 end,
        DoesSpellExist = function() return true end,
        GetSpellCharges = function()
            return {
                currentCharges = 1,
                maxCharges = 1,
                cooldownStartTime = 0,
                cooldownDuration = 0,
                chargeModRate = 1,
            }
        end,
    }

    env.GetNumTalentTabs = function() return 3 end
    env.GetTalentTabInfo = function(i) return 'Tree ' .. i, '', 0, 'tree' .. i end
    env.GetNumTotemSlots = function() return 4 end

    env.C_SpellBook = {
        IsSpellKnown = function() return true end,
        IsSpellInSpellBook = function() return true end,
        GetSpellBookItemInfo = function() return nil end,
        FindSpellBookSlotForSpell = function() return nil end,
    }

    env.C_UnitAuras = {
        GetAuraDataByIndex = function() return nil end,
        GetPlayerAuraBySpellID = function() return nil end,
    }

    env.C_PetBattles = { IsInBattle = function() return false end }

    env.C_ActionBar = {
        HasVehicleActionBar = function() return false end,
        HasOverrideActionBar = function() return false end,
        IsPossessBarVisible = function() return false end,
        FindSpellActionButtons = function() return nil end,
    }

    -- Timers are recorded, never run by themselves; state.timers lists them.
    state.timers = {}

    local function timer(delay, callback, iterations)
        local t = { delay = delay, callback = callback, iterations = iterations }

        function t:Cancel()
            self.cancelled = true
        end

        function t:IsCancelled()
            return self.cancelled == true
        end

        state.timers[#state.timers + 1] = t
        return t
    end

    env.C_Timer = {
        After = function(delay, callback)
            timer(delay, callback, 1)
        end,
        NewTimer = function(delay, callback) return timer(delay, callback, 1) end,
        NewTicker = function(delay, callback, iterations) return timer(delay, callback, iterations) end,
    }

    env.C_UIFileAsset = { IsKnownFile = function() return true end }
    env.SlashCmdList, env.hash_SlashCmdList = {}, {}
    local categories = {}

    env.Settings = {
        RegisterCanvasLayoutCategory = function(frame, name)
            local c = { ID = name, frame = frame }
            categories[name] = c
            return c
        end,
        RegisterCanvasLayoutSubcategory = function(_, frame, name)
            local c = { ID = name, frame = frame }
            categories[name] = c
            return c
        end,
        RegisterAddOnCategory = function() end,
        GetCategory = function(name) return categories[name] end,
        OpenToCategory = function() end,
    }

    -- Unit, cast and combat readers every client has (their values are not under test here).
    for _, name in ipairs({
        'UnitCastingInfo', 'UnitChannelInfo', 'UnitIsPVP', 'UnitAttackSpeed', 'UnitIsEnemy', 'UnitIsFriend',
        'UnitCanAttack', 'UnitIsDead', 'UnitClassification', 'UnitThreatSituation', 'UnitDetailedThreatSituation',
        'GetUnitSpeed', 'IsStealthed', 'HasFullControl', 'IsOutdoors', 'IsIndoors', 'UnitIsUnit', 'UnitCreatureType',
        'UnitCreatureFamily', 'IsInRaid', 'IsInGroup', 'UnitPosition', 'UnitIsPlayer', 'UnitPlayerControlled',
        'UnitIsTapDenied', 'IsMounted', 'IsFlying', 'IsSwimming', 'IsFalling', 'IsResting', 'UnitInParty', 'UnitInRaid',
        'GetNumGroupMembers', 'UnitGroupRolesAssigned', 'IsInInstance', 'GetInstanceInfo', 'GetZoneText',
        'GetSubZoneText', 'GetRealZoneText', 'GetZonePVPInfo', 'UnitHealth', 'UnitHealthMax', 'UnitPower',
        'UnitPowerMax', 'UnitPowerType', 'GetComboPoints', 'GetShapeshiftForm', 'GetShapeshiftFormInfo', 'HasPetUI',
        'UnitStat', 'GetHaste', 'GetCritChance', 'GetMastery', 'GetVersatilityBonus', 'GetCombatRatingBonus',
        'UnitArmor', 'GetSpellBonusDamage', 'GetSpellCritChance', 'UnitRangedAttackPower', 'UnitAttackPower',
        'GetWeaponEnchantInfo', 'GetInventoryItemID', 'GetInventoryItemLink', 'GetItemCount', 'IsUsableItem',
        'GetItemCooldown', 'IsEquippedItem', 'UnitIsCharmed', 'UnitIsPossessed', 'IsInGuild', 'GetNumSubgroupMembers',
        'UnitIsGroupLeader', 'UnitIsGroupAssistant', 'GetRaidRosterInfo', 'GetTotemInfo', 'GetRuneCooldown',
        'GetRuneType', 'UnitPowerDisplayMod', 'IsSpellInRange', 'GetSpellCooldown', 'GetPetActionInfo',
        'UnitIsQuestBoss', 'CheckInteractDistance', 'GetShapeshiftFormID', 'UnitGetIncomingHeals',
        'UnitGetTotalAbsorbs', 'UnitGetTotalHealAbsorbs', 'IsCurrentSpell', 'IsAutoRepeatSpell', 'GetNetStats',
        'GetFramerate', 'UnitSex', 'UnitEffectiveLevel', 'UnitBattlePetLevel', 'GetPVPTimer',
        'IsActiveBattlefieldArena', 'UnitInBattleground', 'GetNumSkillLines', 'GetMoney', 'GetPlayerInfoByGUID',
        'IsPlayerMoving', 'GetMirrorTimerInfo', 'GetMirrorTimerProgress', 'IsSubmerged', 'GetSpellCharges',
        'UnitSpellHaste', 'UnitRangedDamage', 'UnitDamage', 'GetMeleeHaste', 'GetRangedHaste', 'GetPowerRegen',
        'GetManaRegen', 'UnitIsAFK', 'UnitIsDND', 'IsFlyableArea', 'IsAdvancedFlyableArea', 'GetRestState',
        'GetXPExhaustion', 'UnitXP', 'UnitXPMax'
    }) do
        if rawget(env, name) == nil then
            env[name] = function() end
        end
    end

    state.chat = {}

    env.DEFAULT_CHAT_FRAME = {
        AddMessage = function(_, text)
            state.chat[#state.chat + 1] = text
        end,
    }

    env.ChatFrame1 = env.DEFAULT_CHAT_FRAME

    env.GetInventorySlotInfo = function(name)
        return ({ HandsSlot = 10, MainHandSlot = 16, SecondaryHandSlot = 17, RangedSlot = 18 })[name] or 1
    end

    local function pool(kind)
        return {
            Acquire = function(self)
                local t = env.CreateFrame(kind)
                return t, true
            end,
            Release = function() end,
            ReleaseAll = function() end,
        }
    end

    env.CreateTexturePool = function() return pool('Texture') end
    env.CreateFramePool = function(kind) return pool(kind or 'Frame') end

    env.CreateFromMixins = function(...)
        local t = {}

        for i = 1, select('#', ...) do
            for k, v in pairs((select(i, ...))) do
                t[k] = v
            end
        end

        return t
    end

    env.Minimap = env.CreateFrame('Frame', 'Minimap', env.UIParent)
    env.GetCursorPosition = function() return 0, 0 end
    env.UIDropDownMenu_CreateInfo = function() return {} end
    env.UIDropDownMenu_AddButton = function() end

    env.UIDropDownMenu_Initialize = function(_, fn)
        fn()
    end

    env.ToggleDropDownMenu = function() end

    -- Saved variables, as the client restores them before the addon's files run.
    if o.saved then
        env.RotationMasterDB = o.saved
    end

    local addon = {}
    local folder = 'rotationmaster'
    local metadata = { Title = 'Rotation Master', Version = 'test' }

    local function load(path, name, namespace)
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        return chunk(name or folder, namespace or addon)
    end

    -- Load-on-demand Built In modules: the client runs the module's flavour TOC with a fresh namespace.
    local loaded = {}
    local family = FAMILY[project]

    local function loadAddOn(name)
        if loaded[name] then
            return true
        end

        local dir = 'Modules/' .. name
        local toc = dir .. '/' .. name .. '_' .. MODULE_FLAVOR[family] .. '.toc'
        local h = io.open(toc)

        -- A text or converter add-on has one TOC for every client; a class module without this client's TOC has nothing to load.
        if not h then
            toc = dir .. '/' .. name .. '.toc'
            h = io.open(toc)

            if h then
                local listed = false

                for line in h:lines() do
                    if line:match('%.lua%s*$') then
                        listed = true
                    end
                end

                h:close()
                h = listed and io.open(toc) or nil
            end
        end

        if not h then
            return false, 'MISSING'
        end

        h:close()
        local namespace = {}

        for _, line in ipairs(lines(toc)) do
            if line:match('%.lua$') then
                load(dir .. '/' .. line, name, namespace)
            end
        end

        loaded[name] = true
        return true
    end

    env.C_AddOns = {
        GetAddOnMetadata = function(_, field) return metadata[field] end,
        IsAddOnLoaded = function(name) return loaded[name] == true end,
        LoadAddOn = loadAddOn,
        GetAddOnEnableState = function() return 0 end,
        DoesAddOnExist = function() return false end,
    }

    env.GetAddOnMetadata = function(_, field) return metadata[field] end
    env.IsAddOnLoaded = function(name) return loaded[name] == true end
    -- The event frames AceEvent/AceAddon register through.
    local frames = {}
    local create = env.CreateFrame

    -- Widget methods this model does not define do nothing (layout is not under test).
    local noop = {
        __index = function(_, key)
            if type(key) == 'string' and key:match('^%u') then
                return function() end
            end
        end,
    }

    local function wrapWidget(widget)
        setmetatable(widget, noop)

        for _, name in ipairs({
            'CreateTexture',
            'CreateFontString',
            'CreateMaskTexture',
            'CreateAnimationGroup',
            'CreateAnimation',
            'CreateLine',
        }) do
            local make = rawget(widget, name)

            widget[name] = function(...)
                local child = make and make(...) or { scripts = {} }
                return wrapWidget(child)
            end
        end

        return widget
    end

    env.CreateFrame = function(...)
        local frame = create(...)
        local events = {}
        frame.modelEvents = events
        frames[#frames + 1] = frame
        wrapWidget(frame)

        function frame:RegisterEvent(event)
            events[event] = true
        end

        function frame:RegisterUnitEvent(event)
            events[event] = true
        end

        function frame:UnregisterEvent(event)
            events[event] = nil
        end

        function frame:UnregisterAllEvents()
            for event in pairs(events) do
                events[event] = nil
            end
        end

        function frame:IsEventRegistered(event)
            return events[event] == true
        end

        function frame:HasScript()
            return true
        end

        return frame
    end

    local function fire(event, ...)
        for _, frame in ipairs(frames) do
            local callback = frame.scripts and frame.scripts.OnEvent

            if callback and frame.modelEvents[event] then
                callback(frame, event, ...)
            end
        end
    end

    -- The client reports a file that errors while loading and carries on with the next;
    -- loadErrors records them (path -> message) so a test can require none.
    local loadErrors = {}

    local function clientLoad(path)
        local ok, why = pcall(load, path)

        if not ok then
            loadErrors[#loadErrors + 1] = path .. ': ' .. tostring(why)
        end
    end

    local toc = lines('RotationMaster.toc')

    for _, line in ipairs(toc) do
        if line:match('^%s*#') or not line:find('%S') then
        elseif line == 'embeds.xml' then
            for _, path in ipairs(xmlFiles('embeds.xml')) do
                clientLoad(path)
            end
        elseif line == 'locales.xml' then
            -- The game language's file first, then English, as locales.xml lists them (the other languages' files return at once).
            if o.locale and o.locale ~= 'enUS' then
                clientLoad('Locales/' .. o.locale .. '.lua')
            end

            clientLoad('Locales/enUS.lua')
        elseif line:match('%.lua$') then
            clientLoad(line)
        end
    end

    -- Each library frame's update timers are not driven; AceTimer runs nothing by itself.
    fire('ADDON_LOADED', folder)
    fire('PLAYER_LOGIN')
    fire('PLAYER_ENTERING_WORLD', true, false)

    -- Run the one-shot timers pending now (deferred work such as a level-up's selection), once each.
    local function runPending()
        local pending = {}

        for _, t in ipairs(state.timers) do
            if t.iterations == 1 and not t.ran and not t.cancelled then
                pending[#pending + 1] = t
            end
        end

        for _, t in ipairs(pending) do
            t.ran = true
            t.callback(t)
        end

        return #pending
    end

    return {
        env = env,
        addon = addon,
        state = state,
        fire = fire,
        load = load,
        frames = frames,
        loadErrors = loadErrors,
        runPending = runPending,
    }
end

return T
