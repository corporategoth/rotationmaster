-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for talents on every client family. Three layouts (platform:GetTalentLayout): "tree" (Era, TBC,
-- Wrath and Cataclysm Classic talent tabs), "grid" (Mists of Pandaria Classic tiers and columns) and "traits" (Retail
-- and Forever trait nodes, C_Traits and C_ClassTalents). Readers return `value, nil` or `nil, reason`, never throw,
-- and pass every game value through platform:CanReadValue first. Must not change talents or select a specialization;
-- Platform/specializations.lua owns that. Loaded from RotationMaster.toc after Platform/specializations.lua and before
-- Platform/talent_tree.lua; the talent conditions, Core/build_context.lua and UI/talent_popup.lua consume it.

local _, addon = ...
local platform = addon.Platform

-- ============================================================================
-- Shared helpers
-- ============================================================================

-- Whether a value is readable and is an integer within a range.
-- @param value any  The value to test.
-- @param minimum number  The smallest accepted value.
-- @param maximum number  The largest accepted value.
-- @return boolean  True for a readable integer in [minimum, maximum].
local function integer(value, minimum, maximum)
    return platform:CanReadValue(value)
        and type(value) == "number"
        and value >= minimum
        and value <= maximum
        and value % 1 == 0
end

-- Whether a talent group argument is valid.
-- @param group any  The candidate: nil (the active group) or an integer from 1 to 4.
-- @return boolean  True when valid.
local function groupValid(group)
    return group == nil or integer(group, 1, 4)
end

-- Tells which talent layout this client uses.
-- @return string|nil  "tree", "grid" or "traits"; nil when the layout is unsupported.
-- @return string|nil  "unsupported-talent-layout" when the first return is nil; nil otherwise.
--
-- Every other reader here checks it first and answers "talent-layout-mismatch" when called on the wrong layout.
function platform:GetTalentLayout()
    local client = self:GetClientInfo()

    if client.family == "era" or client.family == "tbc" then
        return "tree"
    end
    if client.family == "retail" or client.family == "forever" then
        return "traits"
    end

    if client.family == "progression" then
        if client.expansion == 2 or client.expansion == 3 then
            return "tree"
        end
        if client.expansion == 4 then
            return "grid"
        end
    end

    return nil, "unsupported-talent-layout"
end

-- Checks that the client's talent layout is the wanted one.
-- @param wanted string  The layout: "tree", "grid" or "traits".
-- @return boolean|nil  True when it matches; nil otherwise.
-- @return string|nil  "talent-layout-mismatch" when the first return is nil; nil otherwise.
local function layout(wanted)
    if platform:GetTalentLayout() ~= wanted then
        return nil, "talent-layout-mismatch"
    end

    return true
end

-- Calls fn(...) under pcall and returns the result when it is a readable integer from 0 to a maximum.
-- @param fn function|nil  The native function.
-- @param maximum number  The largest accepted result.
-- @param ... any  The arguments passed to fn.
-- @return number|nil  The integer result; nil on failure.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
local function count(fn, maximum, ...)
    if type(fn) ~= "function" then
        return nil, "missing-api"
    end

    local ok, value = pcall(fn, ...)

    if not ok then
        return nil, "api-error"
    end
    if not platform:CanReadValue(value) then
        return nil, "restricted-value"
    end
    if not integer(value, 0, maximum) then
        return nil, "invalid-api-result"
    end

    return value
end

-- ============================================================================
-- Talent trees (tab layout, and Forever's trait node groups)
-- ============================================================================

-- Whether this client reads its talent trees from trait node groups.
-- @return boolean  True when the client is Forever or Retail and has C_Traits.GetGroupDisplayInfoByTreeID.
--
-- Forever's classic trees are trait node groups (GetTraitTreeGroups below); the tree count, tree names and points
-- read them there. Retail has none.
local function traitTrees()
    local family = platform:GetClientFamily()

    if family ~= "forever" and family ~= "retail" then
        return false
    end

    return type(C_Traits) == "table" and type(C_Traits.GetGroupDisplayInfoByTreeID) == "function"
end

-- Counts the talent trees the class has.
-- @return number|nil  The tree count (Forever: its node groups); nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
function platform:GetTalentTreeCount()
    if traitTrees() then
        local groups, why = self:GetTraitTreeGroups()

        if not groups then
            return nil, why
        end

        return #groups
    end

    local supported, reason = layout("tree")

    if not supported then
        return nil, reason
    end

    return count(GetNumTalentTabs, 16, false, false)
end

-- Counts the talents in one tree on a "tree" layout client.
-- @param tree number  The tree index, an integer from 1 to 16.
-- @return number|nil  The talent count; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
function platform:GetTreeTalentCount(tree)
    local supported, reason = layout("tree")

    if not supported then
        return nil, reason
    end
    if not integer(tree, 1, 16) then
        return nil, "invalid-talent-tree"
    end

    return count(GetNumTalents, 256, tree, false, false)
end

-- Validates a tree's name, icon and points-spent values.
-- @param name string|nil  The tree name.
-- @param icon number|string|nil  The tree icon.
-- @param points number|nil  The points spent in the tree.
-- @return table{name=string,icon=number|string|nil,pointsSpent=number|nil}|nil  The record; nil when a value is
--   restricted or invalid.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
local function treeMetadata(name, icon, points)
    for _, value in pairs({ name = name, icon = icon, points = points }) do
        if not platform:CanReadValue(value) then
            return nil, "restricted-value"
        end
    end

    if type(name) ~= "string" or name == "" then
        return nil, "invalid-api-result"
    end
    if icon ~= nil and not integer(icon, 0, 2147483647) and type(icon) ~= "string" then
        return nil, "invalid-api-result"
    end
    if points ~= nil and not integer(points, 0, 512) then
        return nil, "invalid-api-result"
    end

    return { name = name, icon = icon, pointsSpent = points }
end

-- Reads the name, icon and points spent of one talent tree.
-- @param tree number  The tree index, an integer from 1 to 16.
-- @param group number|nil  The talent group (1 to 4); nil means the active one.
-- @return table{name=string,icon=number|string|nil,pointsSpent=number|nil}|nil  The record; nil when it cannot be
--   read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Handles both return orders of the legacy GetTalentTabInfo (see the comment inside).
function platform:GetTalentTreeInfo(tree, group)
    if traitTrees() then
        if not integer(tree, 1, 16) or not groupValid(group) then
            return nil, "invalid-talent-query"
        end

        local groups, why = self:GetTraitTreeGroups()

        if not groups then
            return nil, why
        end

        local found = groups[tree]

        if not found then
            return nil, "talent-tree-unavailable"
        end

        return { name = found.name, icon = found.icon, pointsSpent = found.pointsSpent }
    end

    local supported, reason = layout("tree")

    if not supported then
        return nil, reason
    end
    if not integer(tree, 1, 16) or not groupValid(group) then
        return nil, "invalid-talent-query"
    end

    local native = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo
    local fn = native or GetTalentTabInfo

    if type(fn) ~= "function" then
        return nil, "missing-api"
    end

    if native then
        local ok, _, name, _, icon, _, _, points = pcall(fn, tree, false, false, nil, nil, group)

        if not ok then
            return nil, "api-error"
        end

        return treeMetadata(name, icon, points)
    end

    local ok, first, second, third, fourth, fifth = pcall(fn, tree, false, false, group)

    if not ok then
        return nil, "api-error"
    end
    if not self:CanReadValue(first) then
        return nil, "restricted-value"
    end

    -- Historical APIs returned name first; current deprecated wrappers return ID first.
    if type(first) == "string" then
        return treeMetadata(first, second, third)
    end
    if type(first) == "number" then
        return treeMetadata(second, fourth, fifth)
    end

    return nil, "talent-data-unavailable"
end

-- Finds the talent tree with the most points spent.
-- @param group number|nil  The talent group (1 to 4); nil means the active one.
-- @return table|nil  The GetTalentTreeInfo record plus its index; nil when there is none.
-- @return string|nil  The reason code when the first return is nil: "no-talents-spent" when every tree is at zero and
--   "ambiguous-primary-talent-tree" on a tie for the lead, or another reason; nil otherwise.
function platform:GetPrimaryTalentTree(group)
    if not groupValid(group) then
        return nil, 'invalid-talent-query'
    end

    local count, reason = self:GetTalentTreeCount()

    if count == nil then
        return nil, reason
    end

    local best, maximum, tied = nil, 0, false

    for index = 1, count do
        local info, why = self:GetTalentTreeInfo(index, group)

        if not info then
            return nil, why
        end
        if not integer(info.pointsSpent, 0, 512) then
            return nil, 'talent-points-unavailable'
        end

        if info.pointsSpent > maximum then
            best = info
            best.index = index
            maximum = info.pointsSpent
            tied = false
        elseif info.pointsSpent == maximum and maximum > 0 then
            tied = true
        end
    end

    if maximum == 0 then
        return nil, 'no-talents-spent'
    end
    if tied then
        return nil, 'ambiguous-primary-talent-tree'
    end

    return best
end

-- ============================================================================
-- Individual talents (tree and grid layouts)
-- ============================================================================

-- Validates a talent record's name, icon, talent id and spell id.
-- @param data any  The native talent record.
-- @return table|nil  { name, icon, talentID?, spellID? } (an id of zero is dropped); nil when it is restricted or
--   invalid.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
local function identity(data)
    if not platform:CanReadValue(data) then
        return nil, "restricted-value"
    end
    if type(data) ~= "table" then
        return nil, "talent-data-unavailable"
    end

    for _, key in ipairs({ "name", "icon", "talentID", "spellID" }) do
        if not platform:CanReadValue(data[key]) then
            return nil, "restricted-value"
        end
    end

    if type(data.name) ~= "string" or data.name == "" then
        return nil, "invalid-api-result"
    end
    if data.icon ~= nil and not integer(data.icon, 0, 2147483647) and type(data.icon) ~= "string" then
        return nil, "invalid-api-result"
    end

    local result = { name = data.name, icon = data.icon }

    for _, key in ipairs({ "talentID", "spellID" }) do
        local id = data[key]

        if id ~= nil then
            if not integer(id, 0, 2147483647) then
                return nil, "invalid-api-result"
            end

            if id > 0 then
                result[key] = id
            end
        end
    end

    return result
end

-- Calls the legacy multi-return GetTalentInfo and names the fields the modern record would carry.
-- @param fn function  The legacy GetTalentInfo function.
-- @param ... any  The arguments passed to fn.
-- @return table  { name, icon, rank, maxRank, talentID } from positions 1, 2, 5, 6 and 12 of the tuple.
--
-- Run under pcall by the caller.
local function legacyTreeRecord(fn, ...)
    local tuple = { fn(...) }
    return { name = tuple[1], icon = tuple[2], rank = tuple[5], maxRank = tuple[6], talentID = tuple[12] }
end

-- Reads one talent of a tree on a "tree" layout client.
-- @param tree number  The tree index, an integer from 1 to 16.
-- @param talent number  The talent index, an integer from 1 to 256.
-- @param group number|nil  The talent group (1 to 4); nil means the active one.
-- @return table|nil  { name, icon, talentID?, spellID?, rank, maxRank }; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
function platform:GetTreeTalentInfo(tree, talent, group)
    local supported, reason = layout("tree")

    if not supported then
        return nil, reason
    end
    if not integer(tree, 1, 16) or not integer(talent, 1, 256) or not groupValid(group) then
        return nil, "invalid-talent-query"
    end

    local native = C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo
    local ok, data

    if type(native) == "function" then
        ok, data = pcall(native, {
            specializationIndex = tree,
            talentIndex = talent,
            groupIndex = group,
            isInspect = false,
            isPet = false,
        })
    elseif type(GetTalentInfo) == "function" then
        ok, data = pcall(legacyTreeRecord, GetTalentInfo, tree, talent, false, false, group)
    else
        return nil, "missing-api"
    end

    if not ok then
        return nil, "api-error"
    end

    local result, why = identity(data)

    if not result then
        return nil, why
    end
    if not self:CanReadValue(data.rank) or not self:CanReadValue(data.maxRank) then
        return nil, "restricted-value"
    end
    if not integer(data.maxRank, 1, 64) or not integer(data.rank, 0, data.maxRank) then
        return nil, "invalid-api-result"
    end

    result.rank, result.maxRank = data.rank, data.maxRank
    return result
end

-- Reads one talent slot on a "grid" layout client.
-- @param index number  The grid slot, an integer from 1 to 18 (three columns per tier).
-- @param group number|nil  The talent group (1 to 4); nil means the active one.
-- @return table|nil  { name, icon, talentID, spellID, selected }; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
function platform:GetGridTalentInfo(index, group)
    local supported, reason = layout("grid")

    if not supported then
        return nil, reason
    end
    if not integer(index, 1, 18) or not groupValid(group) then
        return nil, "invalid-talent-query"
    end

    local fn = C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo

    if type(fn) ~= "function" then
        return nil, "missing-api"
    end

    local ok, data = pcall(fn, {
        tier = math.floor((index - 1) / 3) + 1,
        column = ((index - 1) % 3) + 1,
        groupIndex = group,
        isInspect = false,
    })

    if not ok then
        return nil, "api-error"
    end

    local result, why = identity(data)

    if not result then
        return nil, why
    end
    if not self:CanReadValue(data.selected) then
        return nil, "restricted-value"
    end
    if type(data.selected) ~= "boolean" or not result.talentID or not result.spellID then
        return nil, "invalid-api-result"
    end

    result.selected = data.selected
    return result
end

-- ============================================================================
-- Trait talents (Retail and Forever: the "traits" layout)
-- ============================================================================

-- Contract (Blizzard's generated API documentation, Gethe/wow-ui-source
-- forever ca8368f2 (1.60.1) and live, Blizzard_APIDocumentationGenerated/
-- ClassTalentsDocumentation.lua and SharedTraitsDocumentation.lua, read
-- 2026-10-23). None of these returns is declared secret; every value is still
-- readability-checked.
--   C_ClassTalents.GetActiveConfigID() -> configID?
--   C_Traits.GetConfigInfo(configID) -> {ID, type, name, treeIDs}
--   C_Traits.GetTreeNodes(treeID) -> nodeIDs
--   C_Traits.GetNodeInfo(configID, nodeID) -> TraitNodeInfo {ID, posX, posY,
--     entryIDs, isVisible, activeRank, ranksPurchased, maxRanks,
--     activeEntry={entryID, rank}?, groupIDs, subTreeID?, subTreeActive?}
--     (ID is 0 for a node the config does not contain)
--   C_Traits.GetEntryInfo(configID, entryID) -> {definitionID?, maxRanks, type}
--   C_Traits.GetDefinitionInfo(definitionID) -> {spellID?, overrideName?, overrideIcon?}
--   C_Traits.GetSubTreeInfo(configID, subTreeID) -> {name, ...}
-- Forever only (absent on live): the three classic trees are node groups of
-- one trait tree. Blizzard_PlayerSpells/Camelot/ClassTalents/
-- Blizzard_ClassTalentsFrame.lua draws one header per
--   C_Traits.GetGroupDisplayInfoByTreeID(treeID) -> {groupID, treeID,
--     skillLineID, orderIndex, displayName, icon}[]
-- showing GetGroupCurrencyInfo(configID, groupIDs)[i].currencyInfos[1].spent
-- as the points spent in that tree.

-- Whether a value is a readable positive integer below 2^31, the range of trait ids.
-- @param value any  The value to test.
-- @return boolean  True for such an id.
local function traitID(value)
    return platform:CanReadValue(value)
        and type(value) == 'number'
        and value > 0
        and value < 2147483648
        and value % 1 == 0
end

-- Blizzard's view loadout config (Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID,
-- TraitConstantsDocumentation.lua) has a negative ID; every other config is positive.
local VIEW_CONFIG = -3

-- Whether a value is a trait config id.
-- @param value any  The value to test.
-- @return boolean  True for a positive id or the negative view-loadout config.
local function traitConfig(value)
    return traitID(value) or (platform:CanReadValue(value) and value == VIEW_CONFIG)
end

-- Calls C_Traits[name](...) under pcall.
-- @param name string  The C_Traits function name.
-- @param ... any  The arguments passed to the function.
-- @return boolean  True when the call produced a readable result.
-- @return any  The readable result; the reason code when the first return is false.
local function traits(name, ...)
    local namespace = C_Traits
    local fn = type(namespace) == 'table' and namespace[name] or nil

    if type(fn) ~= 'function' then
        return false, 'missing-api'
    end

    local ok, value = pcall(fn, ...)

    if not ok then
        return false, 'api-error'
    end
    if not platform:CanReadValue(value) then
        return false, 'restricted-value'
    end

    return true, value
end

-- Checks that the client uses the trait layout.
-- @return boolean|nil  True on Retail and Forever; nil otherwise.
-- @return string|nil  "talent-layout-mismatch" when the first return is nil; nil otherwise.
local function traitsLayout()
    local family = platform:GetClientFamily()

    if family ~= 'retail' and family ~= 'forever' then
        return nil, 'talent-layout-mismatch'
    end

    return true
end

-- Reads the active trait config and its talent tree.
-- @return number|nil  The config id; nil when it cannot be read.
-- @return number|string|nil  The tree id; the reason code when the first return is nil.
function platform:GetActiveTraitConfig()
    local supported, reason = traitsLayout()

    if not supported then
        return nil, reason
    end

    local namespace = C_ClassTalents
    local fn = type(namespace) == 'table' and namespace.GetActiveConfigID or nil

    if type(fn) ~= 'function' then
        return nil, 'missing-api'
    end

    local ok, config = pcall(fn)

    if not ok then
        return nil, 'api-error'
    end
    if not self:CanReadValue(config) then
        return nil, 'restricted-value'
    end
    if config == nil then
        return nil, 'talent-config-unavailable'
    end
    if not traitID(config) then
        return nil, 'invalid-api-result'
    end

    local okInfo, info = traits('GetConfigInfo', config)

    if not okInfo then
        return nil, info
    end
    if type(info) ~= 'table' or type(info.treeIDs) ~= 'table' then
        return nil, 'talent-config-unavailable'
    end

    local tree = info.treeIDs[1]

    if not self:CanReadValue(tree) then
        return nil, 'restricted-value'
    end
    if not traitID(tree) then
        return nil, 'talent-config-unavailable'
    end

    return config, tree
end

-- Lists Forever's talent trees: the node groups of the class trait tree in display order.
-- @param config number|nil  The trait config id; nil means the active one.
-- @param tree number|nil  The trait tree id; nil means the active one (used with config).
-- @return table[]|nil  The groups, each { groupID, name, icon, pointsSpent }; nil when it cannot be read. Retail has no
--   such groups.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
function platform:GetTraitTreeGroups(config, tree)
    local supported, reason = traitsLayout()

    if not supported then
        return nil, reason
    end

    if config == nil then
        config, tree = self:GetActiveTraitConfig()

        if not config then
            return nil, tree
        end
    end

    if not traitID(config) or not traitID(tree) then
        return nil, 'invalid-talent-query'
    end

    local ok, displays = traits('GetGroupDisplayInfoByTreeID', tree)

    if not ok then
        return nil, displays
    end
    if type(displays) ~= 'table' then
        return nil, 'invalid-api-result'
    end

    local groups, ids = {}, {}

    for index = 1, #displays do
        local display = displays[index]

        if not self:CanReadValue(display) or type(display) ~= 'table' then
            return nil, 'restricted-value'
        end

        for _, key in ipairs({ 'groupID', 'orderIndex', 'displayName', 'icon' }) do
            if not self:CanReadValue(display[key]) then
                return nil, 'restricted-value'
            end
        end

        if not traitID(display.groupID) or type(display.displayName) ~= 'string' or display.displayName == '' then
            return nil, 'invalid-api-result'
        end

        groups[#groups + 1] = {
            groupID = display.groupID,
            name = display.displayName,
            icon = display.icon,
            order = type(display.orderIndex) == 'number' and display.orderIndex or index,
            position = index,
        }

        ids[#ids + 1] = display.groupID
    end

    if #groups == 0 or #groups > 16 then
        return nil, 'talent-groups-unavailable'
    end

    table.sort(groups, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end

        return a.position < b.position
    end)

    local okSpent, currencies = traits('GetGroupCurrencyInfo', config, ids)

    if not okSpent then
        return nil, currencies
    end
    if type(currencies) ~= 'table' then
        return nil, 'invalid-api-result'
    end

    local spent = {}

    for index = 1, #currencies do
        local info = currencies[index]

        if not self:CanReadValue(info) or type(info) ~= 'table' then
            return nil, 'restricted-value'
        end

        local list = info.currencyInfos

        if not self:CanReadValue(info.traitNodeGroupID) or not self:CanReadValue(list) then
            return nil, 'restricted-value'
        end

        local first = type(list) == 'table' and list[1] or nil
        local points = 0

        if first ~= nil then
            if not self:CanReadValue(first) or type(first) ~= 'table' or not self:CanReadValue(first.spent) then
                return nil, 'restricted-value'
            end
            if not integer(first.spent, 0, 512) then
                return nil, 'invalid-api-result'
            end

            points = first.spent
        end

        if traitID(info.traitNodeGroupID) then
            spent[info.traitNodeGroupID] = points
        end
    end

    -- The Blizzard header shows 0 for a group with no currency record.
    for _, group in ipairs(groups) do
        group.pointsSpent = spent[group.groupID] or 0
        group.order, group.position = nil, nil
    end

    return groups
end

-- Reads one node's committed state in a config.
-- @param config number  The trait config id.
-- @param node number  The trait node id.
-- @param withEntries boolean|nil  True to also return the node's entry ids (a fresh list), for matching a saved spell
--   id against the node.
-- @return table|nil  { rank, entry, maxRanks, entries? }; rank is 0 when the node's hero subtree is not chosen, entry
--   is the active entry. nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
function platform:GetTraitNodeState(config, node, withEntries)
    local supported, reason = traitsLayout()

    if not supported then
        return nil, reason
    end
    if not traitID(config) or not traitID(node) then
        return nil, 'invalid-talent-query'
    end

    local ok, info = traits('GetNodeInfo', config, node)

    if not ok then
        return nil, info
    end
    if type(info) ~= 'table' then
        return nil, 'talent-node-unavailable'
    end

    for _, key in ipairs({ 'ID', 'activeRank', 'maxRanks', 'activeEntry', 'subTreeID', 'subTreeActive' }) do
        if not self:CanReadValue(info[key]) then
            return nil, 'restricted-value'
        end
    end

    if info.ID ~= node then
        return nil, 'talent-node-unavailable'
    end
    if not integer(info.maxRanks, 0, 64) or not integer(info.activeRank, 0, 64) then
        return nil, 'invalid-api-result'
    end

    local entry

    if info.activeEntry ~= nil then
        if type(info.activeEntry) ~= 'table' or not self:CanReadValue(info.activeEntry.entryID) then
            return nil, 'restricted-value'
        end

        if traitID(info.activeEntry.entryID) then
            entry = info.activeEntry.entryID
        end
    end

    local rank = info.activeRank

    if info.subTreeID ~= nil and info.subTreeActive ~= true then
        rank = 0
    end

    local state = { rank = rank, entry = entry, maxRanks = info.maxRanks }

    if withEntries then
        if not self:CanReadValue(info.entryIDs) or type(info.entryIDs) ~= 'table' then
            return nil, 'restricted-value'
        end

        local entries = {}

        for _, id in ipairs(info.entryIDs) do
            if not self:CanReadValue(id) then
                return nil, 'restricted-value'
            end

            if traitID(id) then
                entries[#entries + 1] = id
            end
        end

        state.entries = entries
    end

    return state
end

-- ============================================================================
-- Trait entries and identities
-- ============================================================================

-- Reads a trait entry's definition: the spell id it teaches and its display overrides.
-- @param config number  The trait config id.
-- @param entry number  The trait entry id.
-- @return table|nil  The entry info table; nil when it cannot be read.
-- @return table|string|nil  The definition info table; the reason code when the first return is nil.
--
-- Two C_Traits reads, no spell lookup.
local function entryDefinition(config, entry)
    if not traitConfig(config) or not traitID(entry) then
        return nil, 'invalid-talent-query'
    end

    local ok, info = traits('GetEntryInfo', config, entry)

    if not ok then
        return nil, info
    end
    if
        type(info) ~= 'table'
        or not platform:CanReadValue(info.definitionID)
        or not platform:CanReadValue(info.maxRanks)
    then
        return nil, 'restricted-value'
    end
    if not traitID(info.definitionID) then
        return nil, 'talent-entry-unavailable'
    end

    local okDef, definition = traits('GetDefinitionInfo', info.definitionID)

    if not okDef then
        return nil, definition
    end
    if type(definition) ~= 'table' then
        return nil, 'talent-entry-unavailable'
    end

    for _, key in ipairs({ 'spellID', 'overrideName', 'overrideIcon' }) do
        if not platform:CanReadValue(definition[key]) then
            return nil, 'restricted-value'
        end
    end

    return info, definition
end

-- Reads the spell id a trait entry teaches.
-- @param config number  The trait config id.
-- @param entry number  The trait entry id.
-- @return number|nil  The spell id; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
function platform:GetTraitEntrySpell(config, entry)
    local info, definition = entryDefinition(config, entry)

    if not info then
        return nil, definition
    end
    if not traitID(definition.spellID) then
        return nil, 'talent-entry-unavailable'
    end

    return definition.spellID
end

-- Reads a trait entry's display identity: name, icon and spell id.
-- @param config number  The trait config id.
-- @param entry number  The trait entry id.
-- @return table|nil  { name, icon, spellID?, maxRanks?, entryType? }; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- The name and icon are the talent window's own: the definition's override, else the spell's name and (original) icon
-- (TalentUtil.GetTalentName, TalentButtonUtil.CalculateIconTexture).
function platform:GetTraitEntryIdentity(config, entry)
    local info, definition = entryDefinition(config, entry)

    if not info then
        return nil, definition
    end

    local spell = traitID(definition.spellID) and definition.spellID or nil

    local name = type(definition.overrideName) == 'string' and definition.overrideName ~= '' and definition.overrideName
        or nil

    local icon = definition.overrideIcon

    if spell and (name == nil or icon == nil) then
        local spellInfo = self.GetSpellInfo and self:GetSpellInfo(spell)

        if spellInfo then
            name = name or spellInfo.name
            icon = icon or spellInfo.originalIconID or spellInfo.iconID
        end
    end

    if not name then
        return nil, 'talent-entry-unavailable'
    end

    return {
        name = name,
        icon = icon,
        spellID = spell,
        maxRanks = integer(info.maxRanks, 0, 64) and info.maxRanks or nil,
        entryType = platform:CanReadValue(info.type) and type(info.type) == 'number' and info.type or nil,
    }
end

-- Reads a node's display identity (its chosen entry, else the given or first one).
-- @param node number  The trait node id.
-- @param entry number|nil  The entry to name; nil means the active entry, else the node's first one.
-- @param spell number|nil  A saved spell id that names the talent when the node is gone from the tree.
-- @return table|nil  The GetTraitEntryIdentity record, or { name, icon, spellID } from the saved spell; nil when it
--   cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
function platform:GetTraitTalentIdentity(node, entry, spell)
    local config, why = self:GetActiveTraitConfig()

    if not config then
        return nil, why
    end
    if not traitID(node) then
        return nil, 'invalid-talent-query'
    end

    local identity, reason

    if entry == nil then
        local ok, info = traits('GetNodeInfo', config, node)

        if not ok then
            identity, reason = nil, info
        elseif
            type(info) ~= 'table'
            or not self:CanReadValue(info.ID)
            or info.ID ~= node
            or not self:CanReadValue(info.entryIDs)
        then
            reason = 'talent-node-unavailable'
        else
            local active = info.activeEntry

            if type(active) == 'table' and self:CanReadValue(active.entryID) and traitID(active.entryID) then
                entry = active.entryID
            elseif type(info.entryIDs) == 'table' and self:CanReadValue(info.entryIDs[1]) and traitID(
                info.entryIDs[1]
            ) then
                entry = info.entryIDs[1]
            end

            if entry == nil then
                reason = 'talent-node-unavailable'
            end
        end
    end

    if entry ~= nil then
        identity, reason = self:GetTraitEntryIdentity(config, entry)
    end

    if identity then
        return identity
    end

    if traitID(spell) and self.GetSpellInfo then
        local spellInfo = self:GetSpellInfo(spell)

        if spellInfo then
            return { name = spellInfo.name, icon = spellInfo.iconID, spellID = spell }
        end
    end

    return nil, reason
end

-- ============================================================================
-- Reading a specialization's tree
-- ============================================================================

-- Calls C_ClassTalents[name](...) under pcall.
-- @param name string  The C_ClassTalents function name.
-- @param ... any  The arguments passed to the function.
-- @return boolean  True when the call produced a readable result.
-- @return any  The readable result; the reason code when the first return is false.
local function classTalents(name, ...)
    local namespace = C_ClassTalents
    local fn = type(namespace) == 'table' and namespace[name] or nil

    if type(fn) ~= 'function' then
        return false, 'missing-api'
    end

    local ok, value = pcall(fn, ...)

    if not ok then
        return false, 'api-error'
    end
    if not platform:CanReadValue(value) then
        return false, 'restricted-value'
    end

    return true, value
end

-- Reads the level a view loadout is built for.
-- @return number  The expansion maximum level, else the player's level, else 80.
--
-- Same rule as platform:GetTraitViewLevel in Platform/talent_tree.lua, which cannot be called from here because it
-- loads later.
local function viewLevel()
    for _, name in ipairs({ 'GetMaxLevelForPlayerExpansion', 'GetMaxLevelForLatestExpansion' }) do
        local fn = rawget(_G, name)

        if type(fn) == 'function' then
            local ok, level = pcall(fn)

            if ok and integer(level, 1, 200) then
                return level
            end
        end
    end

    local ok, level = pcall(UnitLevel, 'player')

    if ok and integer(level, 1, 200) then
        return level
    end

    return 80
end

-- Tells whether Blizzard's talent window is showing an inspected build.
-- @return boolean  True only when PlayerSpellsFrame exists, is shown and is inspecting another build.
--
-- Reading another specialization fills the shared view config (-3), the one Blizzard's talent window shows a linked
-- or inspected build from: it is left alone while that window is on screen showing such a build. Nothing here opens,
-- loads or needs the window; it is only looked at when it already exists.
local function talentWindowInspecting()
    local frame = rawget(_G, 'PlayerSpellsFrame')

    if type(frame) ~= 'table' or type(frame.IsShown) ~= 'function' or type(frame.IsInspecting) ~= 'function' then
        return false
    end

    local okShown, shown = pcall(frame.IsShown, frame)
    local okInspecting, inspecting = pcall(frame.IsInspecting, frame)
    return okShown and okInspecting and shown == true and inspecting == true
end

-- Finds where a specialization's talents are read from.
-- @param specID number|nil  A Retail specialization id; nil means the one being played.
-- @param options table|nil  { ignoreInspect = boolean }; true skips the talent window check.
-- @return number|nil  The config id; nil when no tree can be read.
-- @return number|string|nil  The tree id; the reason code when the first return is nil. A view read refuses
--   ("in-combat", "talent-window-inspecting") rather than disturb the shared view config.
-- @return string|nil  "active" or "view".
--
-- The specialization being played (or any, on a client with one tree per class) is the active config. Another
-- specialization of the class is read from Blizzard's view loadout, the config the talent window fills to show a
-- shared build (C_ClassTalents.InitializeViewLoadout(specID, level), tree from
-- C_ClassTalents.GetTraitTreeForSpec(specID); Blizzard_ClassTalentImportExport.lua ViewLoadout).
function platform:GetTraitSpecTree(specID, options)
    local supported, reason = traitsLayout()

    if not supported then
        return nil, reason
    end

    local active, tree = self:GetActiveTraitConfig()
    local wanted = self:GetClientFamily() == 'retail' and integer(specID, 1, 2147483647) and specID or nil

    if wanted and self.GetPlayerSpecializationID and active then
        if self:GetPlayerSpecializationID() == wanted then
            wanted = nil
        end
    end

    if not wanted then
        if not active then
            return nil, tree
        end

        return active, tree, 'active'
    end

    if self.IsInitialSpecialization and self:IsInitialSpecialization(wanted) then
        return nil, 'talent-tree-unavailable'
    end
    if type(InCombatLockdown) == 'function' and InCombatLockdown() then
        return nil, 'in-combat'
    end
    if not (options and options.ignoreInspect) and talentWindowInspecting() then
        return nil, 'talent-window-inspecting'
    end

    local okTree, viewTree = classTalents('GetTraitTreeForSpec', wanted)

    if not okTree then
        return nil, viewTree
    end
    if viewTree == nil then
        return nil, 'talent-tree-unavailable'
    end
    if not traitID(viewTree) then
        return nil, 'invalid-api-result'
    end

    local okView, why = classTalents('InitializeViewLoadout', wanted, viewLevel())

    if not okView then
        return nil, why
    end

    local okInfo, info = traits('GetConfigInfo', VIEW_CONFIG)

    if not okInfo then
        return nil, info
    end
    if type(info) ~= 'table' then
        return nil, 'talent-config-unavailable'
    end

    return VIEW_CONFIG, viewTree, 'view'
end

-- Finds where the class talents end and the specialization talents begin.
-- @param columns number[]  The node x positions (tenths of a pixel).
-- @return number|nil  The x midpoint of the widest gap; nil when there is no clean gap, in which case the caller keeps
--   the talents as one group rather than guess.
--
-- Uses the columns the talent window puts them in (class tree left, specialization tree right, a gap between).
local function classSpecBoundary(columns)
    local distinct, seen = {}, {}

    for _, x in ipairs(columns) do
        if not seen[x] then
            seen[x] = true
            distinct[#distinct + 1] = x
        end
    end

    if #distinct < 4 then
        return nil
    end

    table.sort(distinct)
    local gaps = {}

    for index = 2, #distinct do
        gaps[#gaps + 1] = distinct[index] - distinct[index - 1]
    end

    local widest, at = 0, nil

    for index, gap in ipairs(gaps) do
        if gap > widest then
            widest, at = gap, index
        end
    end

    local ordered = {}

    for index, gap in ipairs(gaps) do
        ordered[index] = gap
    end

    table.sort(ordered)
    local median = ordered[math.ceil(#ordered / 2)]

    if widest < math.max(500, median * 3) then
        return nil
    end

    return (distinct[at] + distinct[at + 1]) / 2
end

-- Lists the talents of a specialization for the editor, grouped.
-- @param specID number|nil  A Retail specialization id; nil means the one being played.
-- @param options table|nil  Passed to GetTraitSpecTree ({ ignoreInspect = boolean }).
-- @return table[]|nil  The groups { name, hero, kind, talents }: kind is "class", "spec" or "hero" ("talents" when
--   the first two could not be told apart) on Retail and "tree" on Forever. Each talent is { node, entry (choice
--   nodes only), name, icon, spellID, maxRanks }. nil with a reason when nothing could be listed, never an empty list.
-- @return table|string|nil  Where the talents were read: { spec, source ("active" or "view"), hero (the subtree ids
--   the specialization can choose, when the client says), nodes, visible, skipped (entries that could not be named) };
--   the reason code when the first return is nil.
--
-- Groups: the class talents, the specialization talents and one group per hero subtree the specialization can choose
-- on Retail, one group per tree on Forever. Reads many C_Traits records and allocates freely, so it is for editors
-- and diagnostics, not the poll path.
function platform:GetTraitTalents(specID, options)
    local config, tree, source = self:GetTraitSpecTree(specID, options)

    if not config then
        return nil, tree
    end

    local ok, nodes = traits('GetTreeNodes', tree)

    if not ok then
        return nil, nodes
    end
    if type(nodes) ~= 'table' then
        return nil, 'invalid-api-result'
    end

    local trees = source == 'active' and self:GetTraitTreeGroups(config, tree) or nil
    local groupIndex = {}

    for index, group in ipairs(trees or {}) do
        groupIndex[group.groupID] = index
    end

    -- The first read that failed, reported when nothing could be listed.
    local failure
    local infos = {}

    for index = 1, #nodes do
        local node = nodes[index]
        local okNode, info = traits('GetNodeInfo', config, node)

        if not okNode then
            failure = failure or info
        end
        if
            okNode
            and type(info) == 'table'
            and self:CanReadValue(info.ID)
            and info.ID == node
            and self:CanReadValue(info.isVisible)
            and info.isVisible ~= false
            and self:CanReadValue(info.entryIDs)
            and type(info.entryIDs) == 'table'
        then
            infos[#infos + 1] = info
        end
    end

    -- Blizzard lists a hero subtree's nodes only when the specialization can
    -- choose it (HeroTalentsContainer IsNodeInAvailableSubTree). The client
    -- may answer nothing ("if none available"); the selection node's entries
    -- then name the subtrees the specialization can choose.
    local heroAllowed

    if self:GetClientFamily() == 'retail' then
        local okHero, ids = classTalents('GetHeroTalentSpecsForClassSpec', config, source == 'view' and specID or nil)

        if okHero and type(ids) == 'table' then
            local allowed, any = {}, false

            for _, id in ipairs(ids) do
                if traitID(id) then
                    allowed[id] = true
                    any = true
                end
            end

            if any then
                heroAllowed = allowed
            end
        end

        if not heroAllowed then
            local allowed, any = {}, false

            for _, info in ipairs(infos) do
                if info.type == 3 and self:CanReadValue(info.isAvailable) and info.isAvailable ~= false then  -- Enum.TraitNodeType.SubTreeSelection
                    for _, entry in ipairs(info.entryIDs) do
                        local okEntry, entryInfo = false, nil

                        if self:CanReadValue(entry) and traitID(entry) then
                            okEntry, entryInfo = traits('GetEntryInfo', config, entry)
                        end

                        if
                            okEntry
                            and type(entryInfo) == 'table'
                            and self:CanReadValue(entryInfo.subTreeID)
                            and traitID(entryInfo.subTreeID)
                        then
                            allowed[entryInfo.subTreeID] = true
                            any = true
                        end
                    end
                end
            end

            if any then
                heroAllowed = allowed
            end
        end
    end

    local selection = 2  -- Enum.TraitNodeType.Selection
    local groups, byKey = {}, {}

    -- Finds or creates a talent group.
    -- @param key string  The group key.
    -- @param name string|nil  The group name.
    -- @param hero number|nil  The hero subtree id, for a hero group.
    -- @param kind string  The group kind.
    -- @return table  The group registered under key, created (in first-seen order) when needed.
    local function groupFor(key, name, hero, kind)
        local group = byKey[key]

        if not group then
            group = { key = key, name = name, hero = hero, kind = kind, talents = {} }
            byKey[key] = group
            groups[#groups + 1] = group
        end

        return group
    end

    for _, group in ipairs(trees or {}) do
        groupFor('group:' .. group.groupID, group.name, nil, 'tree')
    end

    local skipped = 0

    for _, info in ipairs(infos) do
        local node = info.ID
        local key, name, hero, kind = 'talents', nil, nil, 'talents'

        if self:CanReadValue(info.groupIDs) and type(info.groupIDs) == 'table' then
            for _, id in ipairs(info.groupIDs) do
                if self:CanReadValue(id) and groupIndex[id] then
                    key, name, kind = 'group:' .. id, trees[groupIndex[id]].name, 'tree'
                    break
                end
            end
        end

        local skip = false

        if key == 'talents' and self:CanReadValue(info.subTreeID) and traitID(info.subTreeID) then
            if heroAllowed and not heroAllowed[info.subTreeID] then
                skip = true
            else
                -- The subtree's name is optional in the record; its talents stay
                -- together under it either way.
                local okSub, sub = traits('GetSubTreeInfo', config, info.subTreeID)

                if
                    okSub
                    and type(sub) == 'table'
                    and self:CanReadValue(sub.name)
                    and type(sub.name) == 'string'
                    and sub.name ~= ''
                then
                    name = sub.name
                end

                key, hero, kind = 'subtree:' .. info.subTreeID, info.subTreeID, 'hero'
            end
        end

        if not skip then
            -- Only a selection node offers its entries as alternatives; a
            -- tiered node's entries are the tiers of one talent.
            local entries = info.entryIDs
            local choice = #entries > 1 and (info.type == selection or info.type == nil)
            local shown = entries

            if #entries > 1 and not choice then
                local active = type(info.activeEntry) == 'table'
                    and self:CanReadValue(info.activeEntry.entryID)
                    and info.activeEntry.entryID
                    or nil

                shown = { active or entries[1] }
            end

            for _, entry in ipairs(shown) do
                local identity, why

                if self:CanReadValue(entry) then
                    identity, why = self:GetTraitEntryIdentity(config, entry)
                else
                    why = 'restricted-value'
                end

                if not identity then
                    -- A hero selection node has entries without a talent; any other
                    -- entry that cannot be named is counted.
                    if info.type ~= 3 then
                        skipped = skipped + 1
                    end
                    if why ~= 'talent-entry-unavailable' then
                        failure = failure or why
                    end
                end

                if identity then
                    identity.node, identity.entry = node, choice and entry or nil
                    identity.y = self:CanReadValue(info.posY) and type(info.posY) == 'number' and info.posY or 0
                    identity.x = self:CanReadValue(info.posX) and type(info.posX) == 'number' and info.posX or 0
                    local list = groupFor(key, name, hero, kind).talents
                    list[#list + 1] = identity
                end
            end
        end
    end

    -- The plain group is the class and specialization talents; split them where
    -- the talent window's columns have a clean gap.
    local plain = byKey.talents

    if plain and #plain.talents > 0 then
        local columns = {}

        for _, talent in ipairs(plain.talents) do
            columns[#columns + 1] = talent.x
        end

        local boundary = classSpecBoundary(columns)

        if boundary then
            local left, right = {}, {}

            for _, talent in ipairs(plain.talents) do
                if talent.x < boundary then
                    left[#left + 1] = talent
                else
                    right[#right + 1] = talent
                end
            end

            if #left >= 3 and #right >= 3 then
                plain.kind, plain.talents = 'class', left
                local spec = { key = 'spec', kind = 'spec', talents = right }

                for index, group in ipairs(groups) do
                    if group == plain then
                        table.insert(groups, index + 1, spec)
                        break
                    end
                end
            end
        end
    end

    local result, heroes = {}, {}

    for _, group in ipairs(groups) do
        table.sort(group.talents, function(a, b)
            if a.y ~= b.y then
                return a.y < b.y
            end
            if a.x ~= b.x then
                return a.x < b.x
            end

            return (a.entry or 0) < (b.entry or 0)
        end)

        for _, talent in ipairs(group.talents) do
            talent.x, talent.y = nil, nil
        end

        if #group.talents > 0 then
            local list = group.hero and heroes or result
            list[#list + 1] = { name = group.name, hero = group.hero, kind = group.kind, talents = group.talents }
        end
    end

    -- The class and specialization talents first, then each hero tree.
    for _, group in ipairs(heroes) do
        result[#result + 1] = group
    end

    if #result == 0 then
        return nil, failure or (skipped > 0 and 'talent-entry-unavailable') or 'talent-tree-unavailable'
    end

    local hero

    if heroAllowed then
        hero = {}

        for id in pairs(heroAllowed) do
            hero[#hero + 1] = id
        end

        table.sort(hero)
    end

    return result, {
        spec = source == 'view' and specID or nil,
        source = source,
        hero = hero,
        nodes = #nodes,
        visible = #infos,
        skipped = skipped,
    }
end

-- Indexes every spell the config's tree teaches.
-- @param config number  The trait config id.
-- @param tree number  The trait tree id.
-- @return table|nil  spell -> { node, entry (choice nodes only), visible }; a visible node wins over a hidden one that
--   teaches the same spell. nil when it cannot be built.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Built on demand by the build context when a saved node id no longer holds its talent (node ids can change between
-- patches; spell ids do not).
function platform:GetTraitSpellIndex(config, tree)
    if not traitID(config) or not traitID(tree) then
        return nil, 'invalid-talent-query'
    end

    local ok, nodes = traits('GetTreeNodes', tree)

    if not ok then
        return nil, nodes
    end
    if type(nodes) ~= 'table' then
        return nil, 'invalid-api-result'
    end

    local selection = 2  -- Enum.TraitNodeType.Selection
    local index = {}

    for position = 1, #nodes do
        local node = nodes[position]
        local okNode, info = traits('GetNodeInfo', config, node)

        if
            okNode
            and type(info) == 'table'
            and self:CanReadValue(info.ID)
            and info.ID == node
            and self:CanReadValue(info.entryIDs)
            and type(info.entryIDs) == 'table'
            and self:CanReadValue(info.isVisible)
        then
            local choice = #info.entryIDs > 1 and (info.type == selection or info.type == nil)

            for _, entry in ipairs(info.entryIDs) do
                local spell = self:CanReadValue(entry) and self:GetTraitEntrySpell(config, entry)

                if spell then
                    local known = index[spell]

                    if not known or (info.isVisible ~= false and not known.visible) then
                        index[spell] = {
                            node = node,
                            entry = choice and entry or nil,
                            visible = info.isVisible ~= false,
                        }
                    end
                end
            end
        end
    end

    return index
end
