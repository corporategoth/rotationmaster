-- Read and color access to rotation tags for the roster and tag filters. Owns the lookups (one rotation's tag view, its
-- tags, every tag in use for a specification) and the per-profile tag color palette in db.profile.rotationTagColors,
-- keyed by lower-cased tag. Reads metadata only: it never copies an action tree and never writes a rotation, so
-- browsing the roster cannot change saved data. The tag rules themselves (normalization, limits) live in Data/ via
-- addon.RotationData. Loaded from the Core rotation group of RotationMaster.toc, after Core/rotation_scope.lua whose
-- scoped coordinator answers when the scoped store is active; the profile-table paths are the legacy fallback.
local _, addon = ...
local data = addon.RotationData

-- ============================================================================
-- Tag lookups
-- ============================================================================

-- Returns the metadata view of one rotation for roster presentation and tag filters.
-- @param spec number  The specialization ID or talent group the rotation is stored under.
-- @param id string  The rotation id.
-- @return table  The rotation's `body` (name, description, priority, tags, metadata) plus the import manifest's `tags`
--   and `sources` when one exists; a Built In rotation returns its envelope. Always a table, empty when the rotation is
--   not found.
--
-- Source order: scoped store, Built In pack, then the profile's saved rotation. Roster presentation reads only
-- metadata, never copies the action tree or populates optional saved fields while a user is browsing.
function addon:GetRotationTagView(spec, id)
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped then
        return scoped:TagView(spec, id) or {}
    end

    local default = self:GetDefaultIdForRuntime(spec, id)

    if default then
        local source = self.GetDefaultRotation and self:GetDefaultRotation(default)

        if not source and self.ListDefaultRotations then
            for _, entry in ipairs(self:ListDefaultRotations(spec)) do
                if entry.id == default then
                    source = entry
                    break
                end
            end
        end

        return source and source.envelope or {}
    end

    local root = self.db.profile.rotations
    local rows = type(root) == 'table' and root[spec]
    local body = type(rows) == 'table' and rows[id]

    if type(body) ~= 'table' then
        return {}
    end

    local manifest
    local state = self.db.profile.rotationLibrary

    if type(state) == 'table' then
        for _, kind in ipairs({ 'origins', 'imports' }) do
            local all = state[kind]
            local scope = type(all) == 'table' and all[spec]
            local record = type(scope) == 'table' and scope[id]

            if type(record) == 'table' and type(record.manifest) == 'table' then
                manifest = record.manifest
                break
            end
        end
    end

    return {
        body = {
            name = body.name,
            description = body.description,
            priority = body.priority,
            tags = data.CopyData(body.tags),
            metadata = data.CopyData(body.metadata),
        },
        tags = manifest and data.CopyData(manifest.tags),
        sources = manifest and data.CopyData(manifest.sources),
    }
end

-- Returns the normalized tag list of one rotation.
-- @param spec number  The specialization ID or talent group the rotation is stored under.
-- @param id string  The rotation id.
-- @return string[]  The tags; empty when the rotation has none or is missing.
function addon:GetRotationTags(spec, id)
    return data.GetRotationTags(self:GetRotationTagView(spec, id)) or {}
end

-- Returns every distinct tag used by the Built In and saved rotations of a specialization.
-- @param spec number  The specialization ID or talent group.
-- @return string[]  The tags, case-insensitively de-duplicated and sorted without regard to case.
-- @return string|nil  With the scoped store, the reason when the headers are unavailable (the list is then empty); nil
--   otherwise.
function addon:GetAllRotationTags(spec)
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped then
        local result, seen = {}, {}
        local headers, why = scoped:Headers(spec)

        if not headers then
            return {}, why
        end

        for _, row in ipairs(headers) do
            for _, tag in ipairs(row.tags) do
                if not seen[tag:lower()] then
                    seen[tag:lower()] = true
                    result[#result + 1] = tag
                end
            end
        end

        table.sort(result, function(a, b) return a:lower() < b:lower() end)
        return result
    end

    local result, seen = {}, {}

    -- Adds tags to the result list, skipping any already seen (case-insensitively).
    -- @param tags string[]|nil  The tags to add; nil adds nothing.
    local function add(tags)
        for _, tag in ipairs(tags or {}) do
            if not seen[tag:lower()] then
                seen[tag:lower()] = true
                result[#result + 1] = tag
            end
        end
    end

    for _, entry in ipairs(self.ListDefaultRotations and self:ListDefaultRotations(spec) or {}) do
        add(data.GetRotationTags(entry.envelope))
    end

    for id in pairs((self.db.profile.rotations or {})[spec] or {}) do
        add(self:GetRotationTags(spec, id))
    end

    table.sort(result, function(a, b) return a:lower() < b:lower() end)
    return result
end

-- ============================================================================
-- Tag colors
-- ============================================================================

-- Returns the saved color for a tag.
-- @param tag string  The tag text; the lookup is case-insensitive.
-- @return table  A copy of the saved color ({ r, g, b, a } in 0..1), or opaque white when none is saved.
function addon:GetRotationTagColor(tag)
    local palette = self.db.profile.rotationTagColors
    local color = type(palette) == 'table' and palette[tag:lower()]
    return type(color) == 'table' and data.CopyData(color) or { r = 1, g = 1, b = 1, a = 1 }
end

-- Saves a color for a tag after validating both.
-- @param tag string  The tag text; it must normalize to a valid rotation tag.
-- @param color table  { r, g, b, a }, each a real number in 0..1.
-- @return boolean  True when saved; false (and nothing is written) when either is invalid.
function addon:SetRotationTagColor(tag, color)
    local tags = data.NormalizeRotationTags({ tag })

    if not tags or type(color) ~= 'table' then
        return false
    end

    local copy = {}

    for _, key in ipairs({ 'r', 'g', 'b', 'a' }) do
        local n = color[key]

        if type(n) ~= 'number' or n ~= n or n < 0 or n > 1 then
            return false
        end

        copy[key] = n
    end

    self.db.profile.rotationTagColors = self.db.profile.rotationTagColors or {}
    self.db.profile.rotationTagColors[tags[1]:lower()] = copy
    return true
end
