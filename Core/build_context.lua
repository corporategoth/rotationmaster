-- Cached snapshot of the player's build (equipment, item-set pieces, enchants, gems, talents or loadout, season and
-- ruleset, engraved runes) that conditions, rotation applicability and the UI read instead of the game. Owns the
-- snapshot, its dirty flags and the notification frame, and rebuilds a section lazily after an event marks it dirty; it
-- must not read the game per poll and callers must treat the snapshot as read-only. Every game value goes through
-- `platform:CanReadValue` (restricted clients hide secret values) and every native API is feature-detected per client.
-- Loaded from RotationMaster.toc after Core/inventory.lua; the long description below the header explains the client
-- differences.

local _, addon = ...

-- Build context: the player's equipment, enchants, gems, item-set pieces,
-- temporary weapon enchants, talents/loadout and season/game mode, normalized
-- once per change. Every section is rebuilt lazily after a notification marks
-- it dirty; nothing here is read per poll. Consumers (conditions, rotation
-- applicability, UI) read the cached snapshot. Equipment and talent
-- notifications already advance the evaluation context epoch in main.lua;
-- the rest only feed conditions, which read this cache on every evaluation,
-- so they need no plan rebuild.
--
-- Client differences are feature-detected: Era/TBC/Wrath/Cata use talent
-- trees, MoP Classic a talent grid, Retail/Forever trait loadouts. Item set
-- IDs come from item metadata (sixteenth GetItemInfo result) and stay pending
-- until the client has the item cached. Seasons and game rules exist only
-- where C_Seasons/C_GameRules do. Season of Discovery runes engraved on the
-- equipped items (C_Engraving) are read only where that API exists.

-- ============================================================================
-- Snapshot state and notifications
-- ============================================================================

local SLOT_FIRST, SLOT_LAST = 1, 19
local sections = { equipment = true, weapons = true, talents = true, client = true, runes = true }
local dirty = { equipment = true, weapons = true, talents = true, client = true, runes = true }

local snapshot = {
    equipment = {},
    sets = {},
    weapons = {},
    talents = {},
    season = {},
    rulesets = {},
    runes = {},
    pending = false,
}

local revision = 0
local frame, watching

-- True when `value` is not a secret value this client refuses to expose.
local function readable(value)
    return addon.Platform:CanReadValue(value)
end

-- Returns `value` when it is a readable positive whole number, else nil.
local function positive(value)
    return readable(value) and type(value) == 'number' and value > 0 and value < math.huge and value % 1 == 0 and value
        or nil
end

-- pcall wrapper that returns false when `fn` is not a function, so a missing native API reads as a failed call.
local function call(fn, ...)
    if type(fn) ~= 'function' then
        return false
    end

    return pcall(fn, ...)
end

-- Marks the named sections for rebuilding and advances the revision that consumers use to detect change.
local function markDirty(...)
    for i = 1, select('#', ...) do
        dirty[(select(i, ...))] = true
    end

    revision = revision + 1
end

-- Notifications that change a section. Registration is lazy (first read) and
-- per name, so an event a client does not know never blocks the others.
local notifications = {
    PLAYER_ENTERING_WORLD = { 'equipment', 'weapons', 'talents', 'client', 'runes' },
    PLAYER_EQUIPMENT_CHANGED = { 'equipment', 'weapons', 'runes' },
    UNIT_INVENTORY_CHANGED = { 'equipment', 'weapons', 'runes' },
    SOCKET_INFO_SUCCESS = { 'equipment' },
    GET_ITEM_INFO_RECEIVED = { 'pending' },
    ITEM_DATA_LOAD_RESULT = { 'pending' },
    CHARACTER_POINTS_CHANGED = { 'talents' },
    PLAYER_TALENT_UPDATE = { 'talents' },
    ACTIVE_TALENT_GROUP_CHANGED = { 'talents' },
    PLAYER_SPECIALIZATION_CHANGED = { 'talents' },
    ACTIVE_PLAYER_SPECIALIZATION_CHANGED = { 'talents' },
    TRAIT_CONFIG_UPDATED = { 'talents' },
    TRAIT_CONFIG_LIST_UPDATED = { 'talents' },
    ACTIVE_COMBAT_CONFIG_CHANGED = { 'talents' },
    TRAIT_CONFIG_CREATED = { 'talents' },
    TRAIT_SUB_TREE_CHANGED = { 'talents' },
    TRAIT_TREE_CURRENCY_INFO_UPDATED = { 'talents' },
}

-- Engraving notifications exist only on the Classic Era client.
local engravingNotifications = {
    RUNE_UPDATED = { 'runes' },
    ENGRAVING_MODE_CHANGED = { 'runes' },
    NEW_RECIPE_LEARNED = { 'runes' },
}

-- Maps a game notification to the sections it dirties. Inventory changes for other units are ignored, and item metadata
-- arriving only matters while an equipped item's set ID is still pending.
local function onEvent(_, event, unit)
    local parts = notifications[event] or engravingNotifications[event]

    if not parts then
        return
    end
    if event == 'UNIT_INVENTORY_CHANGED' and unit ~= nil and unit ~= 'player' then
        return
    end

    if parts[1] == 'pending' then
        -- Item metadata arriving matters only while a set ID is still missing.
        if snapshot.pending then
            markDirty('equipment')
        end

        return
    end

    markDirty(unpack(parts))
end

-- Creates the notification frame and registers the events once (lazily, on the first read); each registration is
-- guarded so an event this client lacks does not block the others. Returns false when no frame can be made, which makes
-- every read rebuild.
local function watch()
    if watching ~= nil then
        return watching
    end

    watching = false

    if type(CreateFrame) ~= 'function' then
        return false
    end

    local ok, created = pcall(CreateFrame, 'Frame')

    if not ok or type(created) ~= 'table' then
        return false
    end

    frame = created

    if type(frame.SetScript) == 'function' then
        frame:SetScript('OnEvent', onEvent)
    end

    for event in pairs(notifications) do
        if event == 'UNIT_INVENTORY_CHANGED' and type(frame.RegisterUnitEvent) == 'function' then
            pcall(frame.RegisterUnitEvent, frame, event, 'player')
        elseif type(frame.RegisterEvent) == 'function' then
            pcall(frame.RegisterEvent, frame, event)
        end
    end

    if type(C_Engraving) == 'table' and type(frame.RegisterEvent) == 'function' then
        for event in pairs(engravingNotifications) do
            pcall(frame.RegisterEvent, frame, event)
        end
    end

    watching = true
    return true
end

-- ============================================================================
-- Reading equipment
-- ============================================================================

-- Item string fields: itemID:enchantID:gem1:gem2:gem3:gem4:suffixID:...
local function parseLink(link)
    if type(link) ~= 'string' or not readable(link) then
        return nil
    end

    local body = link:match('item:([%-%d:]+)')

    if not body then
        return nil
    end

    local fields, index = {}, 0

    for field in (body .. ':'):gmatch('([^:]*):') do
        index = index + 1
        fields[index] = tonumber(field)
    end

    local gems = {}

    for i = 3, 6 do
        local gem = fields[i]

        if gem and gem > 0 then
            gems[#gems + 1] = gem
        end
    end

    return {
        enchantID = fields[2] and fields[2] > 0 and fields[2] or nil,
        gems = gems,
        suffixID = fields[7] and fields[7] ~= 0 and fields[7] or nil,
    }
end

-- Returns the item's set ID, false when it has none, or nil and a reason ('item-data-pending' until the client has
-- cached the item).
local function itemSetID(itemID)
    local info = C_Item and C_Item.GetItemInfo or GetItemInfo

    if type(info) ~= 'function' then
        return nil, 'missing-api'
    end

    local result = { pcall(info, itemID) }

    if not result[1] then
        return nil, 'api-error'
    end
    if result[2] == nil then
        return nil, 'item-data-pending'
    end

    local setID = result[17]

    if not readable(setID) then
        return nil, 'restricted-value'
    end

    return positive(setID) or false
end

-- Number of empty sockets in the item link's stat table, or nil when the stats cannot be read.
local function socketCount(link)
    local stats = C_Item and C_Item.GetItemStats or GetItemStats

    if type(stats) ~= 'function' or type(link) ~= 'string' then
        return nil
    end

    local ok, values = pcall(stats, link)

    if not ok or type(values) ~= 'table' or not readable(values) then
        return nil
    end

    local count = 0

    for key, amount in pairs(values) do
        if type(key) == 'string' and key:find('^EMPTY_SOCKET_') and type(amount) == 'number' then
            count = count + amount
        end
    end

    return count
end

-- Weapon slots carry their item class, subclass and equip location
-- (Platform GetItemInfoInstant: IDs and INVTYPE_* tokens, never localized
-- names), read once per equipment change for WEAPON_TYPE.
local WEAPON_SLOTS = { [16] = true, [17] = true, [18] = true }

-- Fills the record's class, subclass and equip location (or a reason) from the item's instant info.
local function weaponType(record)
    local reader = addon.Platform and addon.Platform.GetItemInfoInstant

    if type(reader) ~= 'function' then
        record.typeReason = 'missing-api'
        return
    end

    local info, why = reader(addon.Platform, record.itemID)

    if not info then
        record.typeReason = why or 'item-data-unavailable'
        return
    end

    record.classID, record.subClassID, record.equipLoc = info.classID, info.subClassID, info.equipLoc
end

-- The ranged slot (bows, guns, wands, relics) exists through Cataclysm; Mists
-- of Pandaria removed it and Retail followed. Elsewhere the client says.
local function rangedSlot()
    local info = addon.Platform:GetClientInfo()

    if
        info.family == 'retail'
        or info.family == 'progression' and type(info.expansion) == 'number' and info.expansion >= 4
    then
        return nil, 'no-ranged-slot'
    end

    -- Forever keeps the global only behind loadDeprecationFallbacks; C_PaperDollInfo first.
    local slotInfo = type(C_PaperDollInfo) == 'table' and C_PaperDollInfo.GetInventorySlotInfo or nil

    if type(slotInfo) ~= 'function' then
        slotInfo = GetInventorySlotInfo
    end

    if type(slotInfo) ~= 'function' then
        return nil, 'missing-api'
    end

    local ok, slot = pcall(slotInfo, 'RANGEDSLOT')
    slot = ok and positive(slot)

    if not slot then
        return nil, 'no-ranged-slot'
    end

    return slot
end

-- ============================================================================
-- Section builders
-- ============================================================================

-- Rebuilds slots 1 to 19: item, enchant, gems, sockets, set membership and weapon type. Marks the snapshot pending
-- while any item's metadata is still loading.
local function buildEquipment()
    snapshot.rangedSlot, snapshot.rangedReason = rangedSlot()
    local equipment, sets, pending = {}, {}, false
    local idOf = GetInventoryItemID

    if type(idOf) ~= 'function' then
        snapshot.equipment, snapshot.sets, snapshot.pending, snapshot.equipmentReason =
            equipment, sets, false, 'missing-api'

        return
    end

    for slot = SLOT_FIRST, SLOT_LAST do
        local ok, itemID = call(idOf, 'player', slot)
        itemID = ok and positive(itemID)

        if itemID then
            local okLink, link = call(GetInventoryItemLink, 'player', slot)
            local record = { itemID = itemID, slot = slot }
            local parsed = okLink and parseLink(link)

            if parsed then
                record.enchantID, record.gems, record.suffixID = parsed.enchantID, parsed.gems, parsed.suffixID
                record.sockets = socketCount(link)
            end

            local setID, why = itemSetID(itemID)

            if setID then
                sets[setID] = (sets[setID] or 0) + 1
                record.setID = setID
            elseif setID == nil then
                record.setReason = why

                if why == 'item-data-pending' then
                    pending = true
                end
            end

            if WEAPON_SLOTS[slot] then
                weaponType(record)
            end

            equipment[slot] = record
        end
    end

    snapshot.equipment, snapshot.sets, snapshot.pending, snapshot.equipmentReason = equipment, sets, pending, nil
end

-- Rebuilds the temporary main-hand and off-hand enchant state (Retail and Forever compose it from C_PaperDollInfo).
local function buildWeapons()
    local weapons = {}
    -- Retail/Forever: the global is a loadDeprecationFallbacks alias; the
    -- Platform composes the same tuple from C_PaperDollInfo (Conditions/weapon.lua).
    local reader = GetWeaponEnchantInfo

    if type(C_PaperDollInfo) == 'table' and type(C_PaperDollInfo.GetTemporaryEnchantmentInfo) == 'function' then
        reader = addon.Platform.ComposedWeaponEnchantInfo
    end

    local ok, main, _, _, mainID, off, _, _, offID = call(reader)

    if ok and readable(main) and readable(off) and readable(mainID) and readable(offID) then
        weapons.main = { enchanted = main == true or main == 1, enchantID = positive(mainID) }
        weapons.off = { enchanted = off == true or off == 1, enchantID = positive(offID) }
    else
        weapons.reason = type(reader) == 'function' and 'api-error' or 'missing-api'
    end

    snapshot.weapons = weapons
end

-- Active talent group (1 to 4) on clients with talent groups, or nil.
local function activeGroup()
    local native = C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup
    local fn = type(native) == 'function' and native or GetActiveTalentGroup
    local ok, group = call(fn, false, false)
    group = ok and positive(group)
    return group and group <= 4 and group or nil
end

-- Rebuilds the talent section for this client's layout: tree points, grid picks or trait loadout and node groups, the
-- player's class, and the specialization and rotation-specialization values conditions compare.
local function buildTalents()
    local platform = addon.Platform
    local talents = {}
    local layout, why

    if platform.GetTalentLayout then
        layout, why = platform:GetTalentLayout()
    else
        why = 'missing-api'
    end

    talents.layout = layout
    talents.reason = why

    if layout == 'tree' or layout == 'grid' then
        talents.group = activeGroup()
    end

    if layout == 'tree' then
        local count = platform:GetTalentTreeCount()
        local trees, best, maximum = {}, nil, 0

        for tree = 1, count or 0 do
            local info = platform:GetTalentTreeInfo(tree, talents.group)
            local points = info and info.pointsSpent
            trees[tree] = { name = info and info.name, points = points }

            if type(points) == 'number' and points > maximum then
                best, maximum = tree, points
            end
        end

        talents.trees, talents.primary = trees, best
        local spent = {}

        for tree = 1, count or 0 do
            spent[#spent + 1] = tostring(trees[tree].points or '?')
        end

        talents.summary = table.concat(spent, '/')
    elseif layout == 'grid' then
        local selected = {}

        for index = 1, 18 do
            local info = platform:GetGridTalentInfo(index, talents.group)

            if info and info.selected then
                selected[#selected + 1] = info.talentID
            end
        end

        talents.selected = selected
    elseif layout == 'traits' then
        local loadout = {}
        -- C_SpecializationInfo first: Retail keeps the globals only behind
        -- loadDeprecationFallbacks, Forever not at all.
        local specs = type(C_SpecializationInfo) == 'table' and C_SpecializationInfo or {}
        local getSpec = type(specs.GetSpecialization) == 'function' and specs.GetSpecialization or GetSpecialization

        local getInfo = type(specs.GetSpecializationInfo) == 'function' and specs.GetSpecializationInfo
            or GetSpecializationInfo

        local okSpec, specIndex = call(getSpec)
        specIndex = okSpec and positive(specIndex)

        if specIndex then
            local okID, specID = call(getInfo, specIndex)
            loadout.specID = okID and positive(specID) or nil
        end

        local classTalents = C_ClassTalents

        if type(classTalents) == 'table' then
            local okActive, active = call(classTalents.GetActiveConfigID)
            loadout.configID = okActive and positive(active) or nil

            if loadout.specID then
                local okSaved, saved = call(classTalents.GetLastSelectedSavedConfigID, loadout.specID)
                loadout.savedConfigID = okSaved and positive(saved) or nil
            end

            local traits = C_Traits
            local config = loadout.savedConfigID or loadout.configID

            if config and type(traits) == 'table' then
                local okInfo, info = call(traits.GetConfigInfo, config)

                if
                    okInfo
                    and type(info) == 'table'
                    and readable(info)
                    and readable(info.name)
                    and type(info.name) == 'string'
                then
                    loadout.name = info.name
                end
            end
        else
            loadout.reason = 'missing-api'
        end

        talents.loadout = loadout
        -- Node ranks are read on first use and kept until the next talent
        -- notification; Forever's trees (node groups) are read here.
        talents.nodes = {}
        local config, tree

        if platform.GetActiveTraitConfig then
            config, tree = platform:GetActiveTraitConfig()
        else
            tree = 'missing-api'
        end

        talents.config, talents.tree, talents.configReason = config, config and tree or nil, not config and tree or nil

        if config then
            local groups, reason = platform:GetTraitTreeGroups(config, tree)

            if groups then
                local trees, best, maximum, tied = {}, nil, 0, false

                for index, group in ipairs(groups) do
                    trees[index] = { name = group.name, icon = group.icon, points = group.pointsSpent }

                    if group.pointsSpent > maximum then
                        best, maximum, tied = index, group.pointsSpent, false
                    elseif group.pointsSpent == maximum and maximum > 0 then
                        tied = true
                    end
                end

                talents.trees = trees

                if maximum == 0 then
                    talents.primaryReason = 'no-talents-spent'
                elseif tied then
                    talents.primaryReason = 'ambiguous-primary-talent-tree'
                else
                    talents.primary = best
                end
            else
                talents.treesReason = reason
            end
        else
            talents.treesReason = tree
        end
    end

    -- SPECIALIZATION: talent-tree clients compare the primary tree (the
    -- unique tree with the most points); specialization clients compare the
    -- active specialization ID. Either way unavailable stays a reason.
    local okClass, _, class = call(UnitClass, 'player')
    talents.class = okClass and readable(class) and type(class) == 'string' and class or nil

    if layout == 'tree' then
        local primary, reason = platform:GetPrimaryTalentTree(talents.group)
        talents.specMode, talents.specValue, talents.specReason = 'tree', primary and primary.index, reason
    elseif platform.GetPlayerSpecializationID then
        talents.specMode = 'id'
        talents.specValue, talents.specReason = platform:GetPlayerSpecializationID()
    else
        talents.specReason = 'missing-api'
    end

    -- The rotation specialization value (body.specs): a specialization ID or
    -- a talent group, as Platform/specializations.lua classifies this client.
    -- Read once: the specialization ID or talent group already observed above
    -- is reused, so a notification costs no extra native reads.
    local kind = platform.GetRotationSpecKind and platform:GetRotationSpecKind()

    if kind == 'portable' and talents.specMode == 'id' then
        talents.rotationSpec, talents.rotationSpecReason = talents.specValue, talents.specReason
    elseif kind == 'slot' and talents.group then
        talents.rotationSpec = talents.group
    elseif kind and platform.GetRotationSpecValue then
        talents.rotationSpec, talents.rotationSpecReason = platform:GetRotationSpecValue()
    end

    snapshot.talents = talents
end

-- ============================================================================
-- Rulesets and the client section
-- ============================================================================

-- Rulesets are the realm's season and game rules: a pack's
-- applicability.rulesets matches when any listed token is active.
-- 'standard' (no season, not hardcore), 'hardcore', 'self-found',
-- 'season:<id>', 'season:<name>' (Enum.SeasonID name, lower case) and
-- 'mode:<id>' (C_GameRules game mode record).
local function seasonName(id)
    local enum = type(Enum) == 'table' and Enum.SeasonID

    if type(enum) ~= 'table' then
        return nil
    end

    for name, value in pairs(enum) do
        if value == id and type(name) == 'string' then
            return name
        end
    end
end

-- Rebuilds the season facts and the ruleset tokens that premade rotations match against.
local function buildClient()
    local info = addon.Platform:GetClientInfo()

    local season = {
        family = info.family,
        id = positive(info.seasonId),
        gameModeId = positive(info.gameModeId),
        hardcore = info.hardcore == true,
        selfFoundAllowed = info.selfFoundAllowed == true,
    }

    -- The character's Self-Found flag is C_PlayerInfo.IsSelfFoundActive on every
    -- client that has the mode (C_GameRules only says whether the realm allows it).
    local playerInfo = type(C_PlayerInfo) == 'table' and C_PlayerInfo or nil

    if playerInfo and type(playerInfo.IsSelfFoundActive) == 'function' then
        local ok, active = pcall(playerInfo.IsSelfFoundActive)
        season.selfFound = ok and readable(active) and active == true
    end

    local rulesets = {}

    if season.id then
        rulesets['season:' .. season.id] = true
        season.name = seasonName(season.id)

        if season.name then
            rulesets['season:' .. season.name:lower()] = true
        end
    end

    if season.hardcore then
        rulesets.hardcore = true
    end
    if season.selfFound then
        rulesets['self-found'] = true
    end
    if season.gameModeId then
        rulesets['mode:' .. season.gameModeId] = true
    end
    if not season.id and not season.hardcore then
        rulesets.standard = true
    end

    snapshot.season, snapshot.rulesets = season, rulesets
end

-- Runes engraved on the equipped items. A rune list that has not loaded yet
-- stays dirty, so the next read tries again.
local function buildRunes()
    local platform = addon.Platform

    if type(platform.GetEngravedRunes) ~= 'function' then
        snapshot.runes = { reason = 'missing-api' }
        return
    end

    local engraved, why = platform:GetEngravedRunes()
    snapshot.runes = engraved or { reason = why }

    if why == 'rune-data-pending' then
        dirty.runes = true
    end
end

-- ============================================================================
-- Refresh and public readers
-- ============================================================================

local builders = {
    equipment = buildEquipment,
    weapons = buildWeapons,
    talents = buildTalents,
    client = buildClient,
    runes = buildRunes,
}

-- Rebuilds the dirty sections (or `only` one of them) and returns the snapshot. A builder that errors stays dirty and
-- its message is kept in `snapshot.<section>Error`. When the frame cannot be created every read rebuilds.
local function refresh(only)
    local watched = watch()

    for section in pairs(sections) do
        if (only == nil or only == section) and (dirty[section] or not watched) then
            dirty[section] = false
            local ok, why = pcall(builders[section])

            if not ok then
                dirty[section] = true
                snapshot[section .. 'Error'] = tostring(why)
            end
        end
    end

    snapshot.revision = revision
    return snapshot
end

-- The shared normalized snapshot. It is replaced section by section on
-- change; callers must treat it as read-only.
function addon:GetBuildContext()
    return refresh()
end

-- Marks one section (or all) dirty, e.g. after a test or a manual refresh.
function addon:InvalidateBuildContext(section)
    if section == nil then
        markDirty('equipment', 'weapons', 'talents', 'client', 'runes')
    elseif sections[section] then
        markDirty(section)
    end
end

-- Set of active ruleset tokens ('standard', 'hardcore', 'season:<id>', ...) for the premade applicability check.
function addon:GetBuildRulesets()
    return refresh('client').rulesets
end

-- Equipment record for an inventory slot, false when empty, or nil and a reason.
function addon:GetEquippedSlotInfo(slot)
    local value = refresh('equipment')

    if value.equipmentReason then
        return nil, value.equipmentReason
    end

    return value.equipment[slot] or false
end

-- Equipped pieces of one game item set. Unknown while any equipped item's
-- metadata is still loading, so a count is never understated.
function addon:GetEquippedSetPieces(setID)
    local value = refresh('equipment')

    if value.equipmentReason then
        return nil, value.equipmentReason
    end
    if value.pending then
        return nil, 'item-data-pending'
    end

    return value.sets[setID] or 0
end

-- Returns the table of equipped piece counts per set ID and whether any item data is still pending.
function addon:GetEquippedSets()
    local value = refresh('equipment')

    if value.equipmentReason then
        return nil, value.equipmentReason
    end

    return value.sets, value.pending
end

-- A game item set's display name where the client exposes one.
function addon:GetItemSetName(setID)
    local fn = C_Item and C_Item.GetItemSetInfo or GetItemSetInfo
    local ok, name = call(fn, setID)

    if ok and readable(name) and type(name) == 'string' and name ~= '' then
        return name
    end
end

-- ============================================================================
-- Specialization, weapon, season and rune readers
-- ============================================================================

-- The talent section of the snapshot (layout, trees or loadout, specialization values).
function addon:GetTalentBuild()
    return refresh('talents').talents
end

-- The character's rotation specialization value (a specialization ID, or a
-- talent group on dual-specialization clients) and the reason when unknown.
-- Cached until a talent or specialization notification.
function addon:GetRotationSpecValue()
    local talents = refresh('talents').talents
    return talents.rotationSpec, talents.rotationSpecReason
end

-- mode ('tree' or 'id'), value (primary tree index or specialization ID),
-- reason when the value is unavailable, and the player's class token.
-- Cached until a talent or specialization notification; no allocation.
function addon:GetPlayerSpecializationObservation()
    local talents = refresh('talents').talents
    return talents.specMode, talents.specValue, talents.specReason, talents.class
end

-- One weapon slot ('mainhand', 'offhand' or 'ranged'): its equipment record
-- (with classID/subClassID/equipLoc or typeReason), false when empty, or nil
-- and a reason (no ranged slot on this client, missing API).
local weaponSlotIDs = { mainhand = 16, offhand = 17 }

function addon:GetEquippedWeaponSlot(kind)
    local value = refresh('equipment')

    if value.equipmentReason then
        return nil, value.equipmentReason
    end

    local slot = weaponSlotIDs[kind]

    if kind == 'ranged' then
        slot = value.rangedSlot

        if not slot then
            return nil, value.rangedReason or 'no-ranged-slot'
        end
    end

    if not slot then
        return nil, 'invalid-weapon-slot'
    end

    return value.equipment[slot] or false
end

-- The season and game-mode facts of the client section.
function addon:GetSeasonInfo()
    return refresh('client').season
end

-- Whether a Season of Discovery rune is engraved on an equipped item, by
-- rune (skillLineAbilityID) or by a spell the rune teaches. nil plus a
-- reason when engraving cannot be read here.
function addon:IsRuneEngraved(rune, spell)
    local runes = refresh('runes').runes

    if runes.reason then
        return nil, runes.reason
    end
    if rune ~= nil then
        return runes.byRune[rune] ~= nil
    end
    if spell ~= nil then
        return runes.bySpell[spell] ~= nil
    end

    return nil, 'invalid-rune'
end

-- ============================================================================
-- Trait talents
-- ============================================================================

-- Trait talents (Retail, Forever): a node's committed rank, or for a choice
-- node's entry the rank when that entry is the chosen one (else 0).
-- One node's state, read on first use and kept until the next talent
-- notification. withEntries also keeps the node's entry IDs, which matching a
-- saved spell ID needs.
local function traitNode(talents, node, withEntries)
    local nodes = talents.nodes
    local state = nodes[node]

    if state == nil or (withEntries and not state.reason and not state.entries) then
        local why
        state, why = addon.Platform:GetTraitNodeState(talents.config, node, withEntries)

        if not state then
            -- A node this config lacks stays lacking until the next talent
            -- notification; anything else is read again next time.
            if why == 'talent-node-unavailable' then
                nodes[node] = { reason = why }
            end

            return nil, why
        end

        nodes[node] = state
    end

    if state.reason then
        return nil, state.reason
    end

    return state
end

-- Whether a node (with its entries read) still holds the saved spell: the
-- given choice entry, else any of its entries. nil and a reason when a read
-- fails.
local function traitHolds(talents, state, entry, spell)
    local spells = talents.entrySpells

    if not spells then
        spells = {}
        talents.entrySpells = spells
    end

    for _, id in ipairs(state.entries) do
        if entry == nil or id == entry then
            local known = spells[id]

            if known == nil then
                local found, why = addon.Platform:GetTraitEntrySpell(talents.config, id)

                if found == nil and why ~= 'talent-entry-unavailable' then
                    return nil, why
                end

                known = found or false
                spells[id] = known
            end

            if known == spell then
                return true
            end
        end
    end

    return false
end

-- Where a spell ID sits in the tree now: node, choice entry. The index is
-- built once per talent notification, and only for a reference that needs it.
local function traitSpellAt(talents, spell)
    local index = talents.spellIndex

    if not index then
        local why
        index, why = addon.Platform:GetTraitSpellIndex(talents.config, talents.tree)

        if not index then
            return nil, why
        end

        talents.spellIndex = index
    end

    local at = index[spell]

    if not at then
        return nil, 'talent-node-unavailable'
    end

    return at
end

-- spell is the spell ID saved with the reference: when the saved node no
-- longer holds it (Blizzard renumbered the tree), the talent is found again
-- by spell.
function addon:GetTraitNodeRank(node, entry, spell)
    local talents = refresh('talents').talents

    if talents.layout ~= 'traits' then
        return nil, 'talent-layout-mismatch'
    end
    if not talents.config then
        return nil, talents.configReason or 'talent-config-unavailable'
    end

    local state, why = traitNode(talents, node, spell ~= nil)

    if spell ~= nil then
        if not state and why ~= 'talent-node-unavailable' then
            return nil, why
        end

        local holds, reason = false, nil

        if state then
            holds, reason = traitHolds(talents, state, entry, spell)

            if holds == nil then
                return nil, reason
            end
        end

        if not holds then
            local at
            at, reason = traitSpellAt(talents, spell)

            if not at then
                return nil, reason
            end

            entry = at.entry
            state, why = traitNode(talents, at.node, false)
        end
    end

    if not state then
        return nil, why
    end
    if entry == nil then
        return state.rank
    end
    if state.entry == entry then
        return state.rank
    end

    return 0
end

-- Forever's trees as read at the last talent notification: points spent per
-- tree (display order) and the unique primary tree.
function addon:GetTraitTreePoints(tree)
    local talents = refresh('talents').talents

    if talents.layout ~= 'traits' then
        return nil, 'talent-layout-mismatch'
    end
    if not talents.trees then
        return nil, talents.treesReason or 'talent-groups-unavailable'
    end

    local record = talents.trees[tree]

    if not record then
        return nil, 'talent-tree-unavailable'
    end

    return record.points
end

-- Index of the unique tree with the most points spent, or nil and the reason ('no-talents-spent' or ambiguous).
function addon:GetTraitPrimaryTree()
    local talents = refresh('talents').talents

    if talents.layout ~= 'traits' then
        return nil, 'talent-layout-mismatch'
    end
    if not talents.trees then
        return nil, talents.treesReason or 'talent-groups-unavailable'
    end
    if not talents.primary then
        return nil, talents.primaryReason
    end

    return talents.primary
end
