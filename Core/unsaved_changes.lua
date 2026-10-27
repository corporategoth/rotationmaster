local _, addon = ...

function addon:UnsavedDataEqual(a, b, seen)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    seen = seen or {}
    if seen[a] == b then return true end
    seen[a] = b

    for key, value in pairs(a) do
        if not self:UnsavedDataEqual(value, b[key], seen) then return false end
    end

    for key in pairs(b) do
        if a[key] == nil then return false end
    end

    return true
end

function addon:RotationUnsavedState(before, after)
    before = before or {}
    after = after or {}
    local result = { cards = {} }

    for _, field in ipairs({ 'name', 'switch', 'description', 'metadata', 'tags', 'priority' }) do
        result[field] = not self:UnsavedDataEqual(before[field], after[field])
    end

    local old = self.RotationData.IndexRotationSteps(before, { allowMissingIds = true })
    local current = self.RotationData.IndexRotationSteps(after)

    for _, row in ipairs(current and current.rows or {}) do
        local previous = old and old.byId[row.step.id]

        result.cards[row.step.id] = not previous
            or not self:UnsavedDataEqual(previous.step, row.step)
            or not self:UnsavedDataEqual(previous.path, row.path)
    end

    return result
end
