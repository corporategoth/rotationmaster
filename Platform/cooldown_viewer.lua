-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Aura presence from Blizzard's Cooldown Manager (Blizzard_CooldownViewer, loaded on Retail and Forever). Its buff
-- viewers read aura data as Blizzard code, and each item frame keeps a plain presence bit in combat: auraInstanceID is
-- a secret value while the aura is up and nil while it is down (Hekili Forever measured this). So for the auras a player
-- tracks in the Cooldown Manager, "is it up" stays answerable while the aura list is hidden. Presence only: no stacks or
-- remaining time. The cooldownID to spell map is built out of combat; item frames are hooked once (OnShow, OnHide) and
-- re-read on target changes. Nothing is written to the viewer. Loaded from RotationMaster.toc after
-- Platform/swing_timer.lua; Core/aura_conditions.lua asks it when an aura read is unavailable.
local _, addon = ...
local platform = addon.Platform

local VIEWERS = { 'BuffIconCooldownViewer', 'BuffBarCooldownViewer' }

-- spell id -> { player = boolean|nil, target = boolean|nil }; item -> spell ids; item -> the unit it last showed.
local presence, itemSpells, itemUnits, hooked =
    {}, setmetatable({}, { __mode = 'k' }), setmetatable({}, { __mode = 'k' }), setmetatable({}, { __mode = 'k' })

local items = {}

-- Reads a field of an item frame when it is a plain value.
-- @param item table  The viewer item frame.
-- @param key string  The field.
-- @return any  The value; nil when it is missing or secret.
local function plain(item, key)
    local value = rawget(item, key)
    return platform:CanReadValue(value) and value or nil
end

-- The spell ids an item tracks (its spell, override and linked spells), read from its cooldown info once.
-- @param item table  The viewer item frame.
-- @return table|nil  The spell ids; nil when the item has no readable cooldown id or info.
local function spellsOf(item)
    local known = itemSpells[item]

    if known then
        return known
    end

    local id = plain(item, 'cooldownID')
    local viewer = C_CooldownViewer

    if type(id) ~= 'number' or type(viewer) ~= 'table' or type(viewer.GetCooldownViewerCooldownInfo) ~= 'function' then
        return nil
    end

    local ok, info = pcall(viewer.GetCooldownViewerCooldownInfo, id)

    if not ok or not platform:CanReadValue(info) or type(info) ~= 'table' then
        return nil
    end

    local ids = {}

    for _, key in ipairs({ 'spellID', 'overrideSpellID' }) do
        local spell = info[key]

        if platform:CanReadValue(spell) and type(spell) == 'number' and spell > 0 then
            ids[#ids + 1] = spell
        end
    end

    local links = info.linkedSpellIDs

    if platform:CanReadValue(links) and type(links) == 'table' then
        for _, spell in ipairs(links) do
            if platform:CanReadValue(spell) and type(spell) == 'number' and spell > 0 then
                ids[#ids + 1] = spell
            end
        end
    end

    itemSpells[item] = ids
    return ids
end

-- Reads an item's presence now and records it for each of its spells.
-- @param item table  The viewer item frame.
function platform:ReadCooldownViewerItem(item)
    local ids = spellsOf(item)

    if not ids then
        return
    end

    local raw = rawget(item, 'auraInstanceID')
    local up = (type(issecretvalue) == 'function' and issecretvalue(raw)) or raw ~= nil
    local unit = plain(item, 'auraDataUnit')

    if unit == 'player' or unit == 'target' then
        itemUnits[item] = unit
    end

    unit = itemUnits[item]

    if not unit then
        return
    end

    for _, spell in ipairs(ids) do
        local entry = presence[spell]

        if not entry then
            entry = {}
            presence[spell] = entry
        end

        entry[unit] = up
    end
end

-- Builds the item list and hooks new items; out of combat only, since frame children and cooldown info may be
-- restricted in combat.
function platform:RefreshCooldownViewer()
    if type(InCombatLockdown) == 'function' and InCombatLockdown() then
        return
    end

    for index = #items, 1, -1 do
        items[index] = nil
    end

    for _, name in ipairs(VIEWERS) do
        local viewer = rawget(_G, name)

        if type(viewer) == 'table' and type(viewer.GetChildren) == 'function' then
            for _, item in ipairs({ viewer:GetChildren() }) do
                if rawget(item, 'cooldownID') ~= nil then
                    items[#items + 1] = item

                    if not hooked[item] and item.HookScript then
                        hooked[item] = true

                        local function read()
                            platform:ReadCooldownViewerItem(item)
                        end

                        item:HookScript('OnShow', read)
                        item:HookScript('OnHide', read)
                    end

                    self:ReadCooldownViewerItem(item)
                end
            end
        end
    end
end

-- Reads whether the Cooldown Manager shows an aura of a spell up on a unit.
-- @param spell number  The spell id.
-- @param unit string  'player' or 'target'.
-- @return boolean|nil  True or false for a tracked spell; nil when the Cooldown Manager does not track it on that unit.
function platform:GetCooldownViewerPresence(spell, unit)
    local entry = presence[spell]
    return entry and entry[unit]
end

if type(CreateFrame) == 'function' then
    local events = CreateFrame('Frame')

    for _, event in ipairs({
        'PLAYER_ENTERING_WORLD',
        'PLAYER_REGEN_ENABLED',
        'COOLDOWN_VIEWER_DATA_LOADED',
        'PLAYER_TARGET_CHANGED',
        'PLAYER_SPECIALIZATION_CHANGED',
    }) do
        pcall(events.RegisterEvent, events, event)
    end

    events:SetScript('OnEvent', function(_, event)
        if event == 'PLAYER_TARGET_CHANGED' then
            for _, entry in pairs(presence) do
                entry.target = nil
            end

            for _, item in ipairs(items) do
                platform:ReadCooldownViewerItem(item)
            end
        else
            platform:RefreshCooldownViewer()
        end
    end)
end
