-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Game-played announcement sounds for cooldowns that wait on your own buffs. On Retail and Forever the game hides your
-- auras in combat, so a cooldown such as "you have neither Water Shield nor Lightning Shield" never becomes available to
-- RM there and its audible announcement stays silent. The game can still play a sound itself when an aura is added or
-- removed (C_UnitAuras.AddAuraSound): this module registers the cooldown's announcement sound for that trigger, so you
-- hear it in combat. It only plays a sound; the game tells addons nothing, so the glow cannot follow. While a cooldown's
-- sound is registered, RM's own availability announcement leaves its sound out (Core/announcements.lua), so it is
-- never heard twice. Registrations change only out of combat. Loaded from the TOC after Core/announcements.lua;
-- main.lua calls SyncAuraSounds when it records a lean plan and ClearAuraSounds when the rotation stops.
local _, addon = ...

-- [step id] = { key = signature, handles = { auraSoundID, ... } }
local registered = {}
-- The cooldowns to register, held while in combat until PLAYER_REGEN_ENABLED.
local pending

-- Reports whether a node is a check of one of your own buffs by spell ID.
-- @param node any  A condition node.
-- @return boolean  True for an enabled BUFF on the player with a numeric spell.
local function ownBuff(node)
    return type(node) == 'table'
        and not node.disabled
        and node.type == 'BUFF'
        and node.unit == 'player'
        and type(node.spell) == 'number'
end

-- Returns the child of a one-child AND or OR (the editor's root group), repeatedly; other nodes as they are.
-- @param node any  A condition node.
-- @return any  The node it amounts to.
local function unwrap(node)
    while
        type(node) == 'table'
        and not node.disabled
        and (node.type == 'AND' or node.type == 'OR')
        and type(node.value) == 'table'
        and #node.value == 1
    do
        node = node.value[1]
    end

    return node
end

-- Reports whether every node of a list passes a test.
-- @param list any  The nodes.
-- @param check function  The test.
-- @return boolean  True for a non-empty list whose every node passes.
local function every(list, check)
    if type(list) ~= 'table' or not list[1] then
        return false
    end

    for _, node in ipairs(list) do
        if not check(node) then
            return false
        end
    end

    return true
end

-- Works out which aura event makes a cooldown's (folded) conditions true, when they are only own-buff checks.
-- @param tree any  The folded condition tree.
-- @return string|nil  'Added' (you have the buff) or 'Removed' (you lack the buff, or all of several); nil otherwise.
-- @return table|nil  The BUFF leaves whose event triggers it.
function addon:GetAuraSoundTrigger(tree)
    tree = unwrap(tree)

    if ownBuff(tree) then
        return 'Added', { tree }
    end
    if type(tree) ~= 'table' or tree.disabled then
        return nil
    end

    if tree.type == 'NOT' then
        local inner = unwrap(tree.value)

        if ownBuff(inner) then
            return 'Removed', { inner }
        end
        if type(inner) == 'table' and not inner.disabled and inner.type == 'OR' and every(inner.value, ownBuff) then
            return 'Removed', inner.value
        end
    elseif tree.type == 'AND' then
        local leaves = {}

        local all = every(tree.value, function(node)
            local inner = type(node) == 'table' and not node.disabled and node.type == 'NOT' and unwrap(node.value)
            leaves[#leaves + 1] = inner
            return ownBuff(inner)
        end)

        if all then
            return 'Removed', leaves
        end
    end

    return nil
end

-- Resolves an announcement sound key through LibSharedMedia.
-- @param key any  The saved sound key.
-- @return string|nil  'soundFileName' or 'soundFileID'; nil when the key does not resolve.
-- @return any  The path or file ID.
local function soundFile(key)
    if type(key) ~= 'string' or key == '' then
        return nil
    end

    local ok, media = pcall(LibStub, 'LibSharedMedia-3.0', true)

    if not ok or type(media) ~= 'table' or type(media.Fetch) ~= 'function' then
        return nil
    end

    local fetched, path = pcall(media.Fetch, media, 'sound', key, true)

    if not fetched or not addon.Platform:CanReadValue(path) then
        return nil
    end
    if type(path) == 'string' and path ~= '' then
        return 'soundFileName', path
    end
    if type(path) == 'number' and path > 0 and path % 1 == 0 then
        return 'soundFileID', path
    end

    return nil
end

-- Lists the spell IDs a BUFF leaf matches: every rank unless it asks for the exact one.
-- @param leaf table  The BUFF condition.
-- @return table  The spell IDs.
local function spellIds(leaf)
    local catalog = addon.SpellCatalog

    if leaf.anyrank ~= false and catalog and catalog.GetAllSpellIds then
        local ok, ids = pcall(catalog.GetAllSpellIds, catalog, leaf.spell)

        if ok and type(ids) == 'table' and ids[1] then
            return ids
        end
    end

    return { leaf.spell }
end

-- Unregisters one cooldown's sounds.
-- @param id string  The step id.
local function unregister(id)
    local entry = registered[id]
    registered[id] = nil

    if entry and type(C_UnitAuras) == 'table' and type(C_UnitAuras.RemoveAuraSound) == 'function' then
        for _, handle in ipairs(entry.handles) do
            pcall(C_UnitAuras.RemoveAuraSound, handle)
        end
    end
end

-- Registers the wanted set, replacing what changed and dropping what is no longer wanted.
-- @param wanted table  [step id] = { key, trigger, ids, field, file }.
local function apply(wanted)
    for id, entry in pairs(registered) do
        if not wanted[id] or wanted[id].key ~= entry.key then
            unregister(id)
        end
    end

    local trigger = Enum and Enum.UnitAuraSoundTrigger

    for id, want in pairs(wanted) do
        if not registered[id] and trigger and trigger[want.trigger] ~= nil then
            local handles = {}

            for _, spell in ipairs(want.ids) do
                local ok, handle = pcall(C_UnitAuras.AddAuraSound, trigger[want.trigger], {
                    unitToken = 'player',
                    spellID = spell,
                    [want.field] = want.file,
                    outputChannel = 'Master',
                    throttleSeconds = 1,
                })

                if ok and type(handle) == 'number' then
                    handles[#handles + 1] = handle
                end
            end

            if handles[1] then
                registered[id] = { key = want.key, handles = handles }
            end
        end
    end
end

-- Applies a held set once combat ends.
local frame = type(CreateFrame) == 'function' and CreateFrame('Frame') or nil

if frame then
    frame:RegisterEvent('PLAYER_REGEN_ENABLED')

    frame:SetScript('OnEvent', function()
        if pending then
            local wanted = pending
            pending = nil
            apply(wanted)
        end
    end)
end

-- Registers game-played sounds for the cooldowns of the active rotation whose conditions, after folding, are only
-- own-buff checks and whose announcement has a sound; drops registrations for anything else. Only on clients that hide
-- auras (the restricted policy), where RM cannot announce these itself in combat.
-- @param cooldowns table  The cooldown steps (or their views) of the active rotation.
function addon:SyncAuraSounds(cooldowns)
    local wanted = {}

    if
        self.Platform:GetCombatDataPolicy() == 'restricted'
        and type(C_UnitAuras) == 'table'
        and type(C_UnitAuras.AddAuraSound) == 'function'
        and type(C_UnitAuras.RemoveAuraSound) == 'function'
    then
        for _, step in ipairs(cooldowns or {}) do
            local field, file = soundFile(step.announce_sound)

            if field and not step.disabled and type(step.id) == 'string' then
                local folded = self.FoldInvariantConditions and self:FoldInvariantConditions(step.conditions)
                local trigger, leaves = self:GetAuraSoundTrigger(folded)

                if trigger then
                    local ids = {}

                    for _, leaf in ipairs(leaves) do
                        for _, spell in ipairs(spellIds(leaf)) do
                            ids[#ids + 1] = spell
                        end
                    end

                    wanted[step.id] = {
                        key = trigger .. ':' .. table.concat(ids, ',') .. ':' .. tostring(file),
                        trigger = trigger,
                        ids = ids,
                        field = field,
                        file = file,
                    }
                end
            end
        end
    end

    if type(InCombatLockdown) == 'function' and InCombatLockdown() then
        pending = wanted
    else
        pending = nil
        apply(wanted)
    end
end

-- Drops every registration (the rotation stopped); in combat, once combat ends.
function addon:ClearAuraSounds()
    self:SyncAuraSounds({})
end

-- Reports whether the game plays a cooldown's announcement sound for it.
-- @param id any  The step id.
-- @return boolean  True while the cooldown's sound is registered with the game.
function addon:IsAuraSoundRegistered(id)
    return registered[id] ~= nil
end
