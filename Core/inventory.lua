-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The runtime snapshot of what the player carries in bags (addon.bagContents), kept in the legacy shape that custom
-- conditions and the UI still read. It owns only that snapshot; it never queries the bag APIs itself, every read goes
-- through addon.Platform (GetBagSnapshot, GetItemUseSpell), so restricted-client rules are already applied.
-- Loaded from RotationMaster.toc after Core/item_sets.lua; main.lua refreshes it on bag events and before a poll.
-- Item predicates in the conditions query Platform directly and do not use this table.

local _, addon = ...

-- Rebuilds addon.bagContents from the carried-bag snapshot, keyed by item id with count, use-spell name, and the slot
-- and bag/slot locations.
-- @param cache table|nil  The per-poll evaluation cache the snapshot read goes through; nil reads uncached.
-- @return boolean  True when the snapshot was rebuilt; false when the bag snapshot is unavailable.
-- @return string|nil  The reason the snapshot is unavailable (default 'inventory-unavailable'); nil on success.
--
-- Keeps the legacy snapshot shape for custom/UI consumers while publishing only complete, normalized bag observations.
-- Runtime item predicates query Platform directly. On failure it clears the table and records the reason in
-- addon.bagContentsUnavailable, so a stale snapshot is never read. The snapshot is session data and is never saved.
-- Runs on the poll path, so the shared evaluation cache is passed through.
function addon:UpdateBagContents(cache)
    local snapshot, reason = self.Functions.cache.getCached(cache, self.Platform.GetBagSnapshot, self.Platform)

    if not snapshot then
        self.bagContents = {}
        self.bagContentsUnavailable = reason or 'inventory-unavailable'
        return false, self.bagContentsUnavailable
    end

    local contents = {}

    for id, record in pairs(snapshot) do
        local use = self.Platform:GetItemUseSpell(id)
        local entry = { count = record.count, spell = use and use.name, slots = {}, locations = {} }

        for index, location in ipairs(record.slots) do
            entry.slots[index] = location.slot
            entry.locations[index] = { bag = location.bag, slot = location.slot }
        end

        contents[id] = entry
    end

    self.bagContents = contents
    self.bagContentsUnavailable = nil
    return true
end
