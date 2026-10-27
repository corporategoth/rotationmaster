local _, addon = ...
local data = addon.RotationData

-- Roster presentation reads only metadata, never copies the action tree or
-- populates optional saved fields while a user is browsing.
function addon:GetRotationTagView(spec, id)
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    if scoped then return scoped:TagView(spec, id) or {} end
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
    if type(body) ~= 'table' then return {} end
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

function addon:GetRotationTags(spec, id)
    return data.GetRotationTags(self:GetRotationTagView(spec, id)) or {}
end

function addon:GetAllRotationTags(spec)
    local scoped = self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()

    if scoped then
        local result, seen = {}, {}
        local headers, why = scoped:Headers(spec)
        if not headers then return {}, why end

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

function addon:GetRotationTagColor(tag)
    local palette = self.db.profile.rotationTagColors
    local color = type(palette) == 'table' and palette[tag:lower()]
    return type(color) == 'table' and data.CopyData(color) or { r = 1, g = 1, b = 1, a = 1 }
end

function addon:SetRotationTagColor(tag, color)
    local tags = data.NormalizeRotationTags({ tag })
    if not tags or type(color) ~= 'table' then return false end
    local copy = {}

    for _, key in ipairs({ 'r', 'g', 'b', 'a' }) do
        local n = color[key]
        if type(n) ~= 'number' or n ~= n or n < 0 or n > 1 then return false end
        copy[key] = n
    end

    self.db.profile.rotationTagColors = self.db.profile.rotationTagColors or {}
    self.db.profile.rotationTagColors[tags[1]:lower()] = copy
    return true
end
