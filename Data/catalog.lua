local _, addon = ...
local data = addon.RotationData

local function id(value)
    return type(value) == "string" and #value > 0 and #value <= 128 and value:match("^[%w][%w._:%-]*$") ~= nil
end
local function steps(envelope, callback)
    if type(envelope) ~= "table" or type(envelope.body) ~= "table" then return end
    local index,why=data.IndexRotationSteps(envelope.body)
    if not index then return nil,why end
    for _,row in ipairs(index.rows) do callback(row.step) end
    return true
end
local function validLineage(value)
    if type(value) ~= "table" or not id(value.sourceId) or
        (value.sourceKind ~= "builtin" and value.sourceKind ~= "custom") or
        type(value.sourceRevision) ~= "number" or value.sourceRevision < 1 or value.sourceRevision % 1 ~= 0 or
        type(value.baseline) ~= "table" or value.baseline.format ~= "RotationMaster" or value.baseline.schemaVersion ~= 1 or
        value.baseline.id ~= value.sourceId or
        value.baseline.revision ~= value.sourceRevision or type(value.stepOrigins) ~= "table" then return false end
    -- Validate historical envelope structure independently of today's condition
    -- catalog. An unavailable old condition must not erase source evidence.
    if not data.ValidateEnvelope(value.baseline).valid then return false end
    local baselineIds = {}
    if not steps(value.baseline, function(step) baselineIds[step.id] = true end) then return false end
    for key, origin in pairs(value.stepOrigins) do
        if not id(key) or not id(origin) or not baselineIds[origin] then return false end
    end
    return true
end

-- State is the catalog's SavedVariables namespace, not an entire legacy profile.
-- Validation catalogs/newId are trusted application dependencies.
function data.NewCatalog(options)
    options = options or {}
    local state = options.state
    if state == nil then state = {} end
    if type(state) ~= "table" or getmetatable(state) ~= nil then return nil, "invalid-catalog-state" end
    for _, key in ipairs({"custom", "preferences", "lineage"}) do
        if state[key] ~= nil and (type(state[key]) ~= "table" or getmetatable(state[key]) ~= nil) then return nil, "invalid-catalog-state" end
    end
    if state.custom then
        for key in pairs(state.custom) do if not id(key) then return nil, "invalid-custom-id" end end
    end
    state.custom, state.preferences, state.lineage = state.custom or {}, state.preferences or {}, state.lineage or {}
    local builtins, withdrawn = {}, {}
    local catalog = {}

    local function resolve(reference)
        if type(reference) == "table" then
            if (reference.kind == "builtin" or reference.kind == "custom") and id(reference.id) then
                return reference.kind, reference.id
            end
        elseif id(reference) then
            return builtins[reference] and "builtin" or "custom", reference
        end
    end
    local function owned(reference)
        local kind, key = resolve(reference)
        if kind == "builtin" then return nil, "read-only" end
        if not key or state.custom[key] == nil then return nil, "unknown-rotation" end
        return key
    end
    local function enabled(kind, key, envelope)
        if kind == "builtin" then
            if withdrawn[key] then return false end
            local preference = state.preferences[key]
            if preference ~= nil then
                if type(preference) ~= "table" or getmetatable(preference) ~= nil or type(preference.enabled) ~= "boolean" then return false end
                return preference.enabled
            end
        end
        return type(envelope) == "table" and type(envelope.body) == "table" and envelope.body.disabled ~= true
    end
    local function snapshot(kind, key, summary)
        local source
        if kind == "builtin" then source = builtins[key] else source = state.custom[key] end
        if source == nil then return nil end
        local validation = data.ValidateEnvelope(source, options.validation)
        local cleanSource, copyError = data.CopyData(source)
        if type(cleanSource) == "table" and cleanSource.id ~= key then
            validation.valid, validation.executionStatus = false, "unavailable"
            if #validation.diagnostics < 100 then
                validation.diagnostics[#validation.diagnostics+1] = {code="catalog-id-mismatch",path="$.id",severity="error"}
            end
        end
        local view = {id=key, reference={kind=kind,id=key}, builtin=kind == "builtin", readOnly=kind == "builtin",
            enabled=validation.valid and not copyError and enabled(kind,key,cleanSource), validation=validation,
            withdrawn=withdrawn[key] ~= nil and kind == "builtin"}
        if view.withdrawn then view.withdrawalReason = withdrawn[key] end
        if type(cleanSource) == "table" then
            view.nameKey = type(cleanSource.nameKey) == "string" and cleanSource.nameKey ~= "" and cleanSource.nameKey or nil
            view.descriptionKey = type(cleanSource.descriptionKey) == "string" and cleanSource.descriptionKey ~= "" and cleanSource.descriptionKey or nil
            local revision = cleanSource.revision
            view.revision = type(revision) == "number" and revision >= 1 and revision % 1 == 0 and revision or nil
            if validation.valid and cleanSource.schemaVersion == 1 then
                view.applicability, view.tags = data.CopyData(cleanSource.applicability), data.CopyData(cleanSource.tags)
            end
        end
        if not summary then
            view.envelope, view.dataError = cleanSource, copyError
            if kind == "custom" and state.lineage[key] ~= nil then
                local lineage, problem = data.CopyData(state.lineage[key])
                if not problem and validLineage(lineage) then view.lineage = lineage
                else view.lineageError = {code="invalid-lineage",path="lineage",severity="error"} end
            end
        end
        return view
    end
    local function storable(envelope)
        local validation = data.ValidateEnvelope(envelope, options.validation)
        if not validation.valid or not id(envelope.id) or type(envelope.revision) ~= "number"
            or envelope.revision < 1 or envelope.revision % 1 ~= 0 then return nil, "invalid-envelope", validation end
        local copy, why = data.CopyData(envelope)
        if not copy then return nil, why.code, validation end
        return copy
    end

    function catalog:RegisterBuiltin(envelope)
        local copy, why, validation = storable(envelope)
        if not copy then return false, why, validation end
        local previous = builtins[copy.id]
        if previous and copy.revision <= previous.revision then return false, "revision-not-newer" end
        builtins[copy.id] = copy
        return true
    end
    function catalog:Get(reference)
        local kind, key = resolve(reference)
        if not key then return nil end
        return snapshot(kind, key, false)
    end
    function catalog:List()
        local rows = {}
        for key in pairs(builtins) do rows[#rows+1] = snapshot("builtin", key, true) end
        for key in pairs(state.custom) do rows[#rows+1] = snapshot("custom", key, true) end
        table.sort(rows, function(a,b)
            if a.id == b.id then return a.builtin and not b.builtin end
            return a.id < b.id
        end)
        return rows
    end
    function catalog:SetEnabled(reference, value)
        if type(value) ~= "boolean" then return false, "invalid-enabled-value" end
        local kind, key = resolve(reference)
        if not key then return false, "unknown-rotation" end
        if kind == "builtin" then
            if not builtins[key] then return false, "unknown-rotation" end
            if withdrawn[key] then return false, "withdrawn-built-in" end
            if type(state.preferences[key]) == "table" and getmetatable(state.preferences[key]) ~= nil then
                return false, "invalid-preference"
            end
            if type(state.preferences[key]) ~= "table" then state.preferences[key] = {} end
            state.preferences[key].enabled = value
            return true
        end
        local view = self:Get(reference)
        if not view then return false, "unknown-rotation" end
        if not view.validation.valid or type(view.envelope.body) ~= "table" then return false, "invalid-envelope" end
        view.envelope.body.disabled = not value
        return self:Save(reference, view.envelope)
    end
    function catalog:Save(reference, envelope)
        local key, why = owned(reference)
        if not key then return false, why end
        local copy, reason, validation = storable(envelope)
        if not copy then return false, reason, validation end
        if copy.id ~= key then return false, "id-mismatch" end
        local previous = state.custom[key]
        if copy.schemaVersion == 1 then
            local revision = type(previous) == "table" and previous.revision
            if type(revision) == "number" and revision >= 1 and revision < 9007199254740991 and revision % 1 == 0 then
                copy.revision = revision+1
            else copy.revision = 1 end
        end
        state.custom[key] = copy
        return true
    end
    function catalog:AddCustom(envelope)
        local copy, why, validation = storable(envelope)
        if not copy then return false, why, validation end
        if builtins[copy.id] then return false, "read-only" end
        if state.custom[copy.id] ~= nil then return false, "duplicate-id" end
        state.custom[copy.id] = copy
        return true
    end
    function catalog:Rename(reference, name)
        local key, why = owned(reference)
        if not key then return false, why end
        if type(name) ~= "string" or name == "" then return false, "invalid-name" end
        local view = self:Get({kind="custom",id=key})
        if not view.envelope or type(view.envelope.body) ~= "table" then return false, "invalid-envelope" end
        view.envelope.nameKey, view.envelope.body.name = name, name
        return self:Save({kind="custom",id=key}, view.envelope)
    end
    function catalog:Delete(reference)
        local key, why = owned(reference)
        if not key then return false, why end
        state.custom[key], state.lineage[key] = nil, nil
        return true
    end
    function catalog:WithdrawBuiltin(reference, reason)
        local kind, key = resolve(reference)
        if kind ~= "builtin" or not builtins[key] then return false, "unknown-built-in" end
        if type(reason) ~= "string" or reason == "" then return false, "missing-withdrawal-reason" end
        withdrawn[key] = reason
        return true
    end
    function catalog:Clone(reference, name)
        local source = self:Get(reference)
        if not source then return nil, "unknown-rotation" end
        if source.lineageError then return nil, "invalid-lineage" end
        if not source.validation.valid or not source.envelope or source.envelope.schemaVersion ~= 1 then return nil, "unsupported-source" end
        if type(options.newId) ~= "function" then return nil, "missing-id-provider" end
        if name ~= nil and (type(name) ~= "string" or name == "") then return nil, "invalid-name" end
        local used = {}
        for _, rows in ipairs({builtins,state.custom}) do
            for key, envelope in pairs(rows) do
                used[key] = true
                if data.CheckPortable(envelope) then
                    data.ReserveRotationIdentities(envelope,used)
                end
            end
        end
        for key,retained in pairs(state.lineage) do
            used[key]=true;data.ReserveRotationIdentities(retained,used)
        end
        if source.lineage and type(source.lineage.stepOrigins) == "table" then
            for _, origin in pairs(source.lineage.stepOrigins) do if id(origin) then used[origin] = true end end
        end
        local function fresh()
            local ok, value = pcall(options.newId)
            if not ok or not id(value) then return nil, "invalid-id-provider" end
            if used[value] then return nil, "id-collision" end
            used[value] = true
            return value
        end
        local newId, why = fresh()
        if not newId then return nil, why end
        local clone = source.envelope
        local baseline = source.lineage and source.lineage.baseline or data.CopyData(source.envelope)
        local lineage = {sourceId=source.lineage and source.lineage.sourceId or source.id,
            sourceKind=source.lineage and source.lineage.sourceKind or source.reference.kind,
            sourceRevision=source.lineage and source.lineage.sourceRevision or clone.revision,
            baseline=baseline, stepOrigins={}, clonedFrom=source.id}
        clone.id, clone.revision = newId, 1
        if name then clone.nameKey, clone.body.name = name, name end
        local failed
        local indexed,indexError=steps(clone, function(step)
            if failed then return end
            local original = step.id
            local generated, reason = fresh()
            if not generated then failed = reason;return end
            step.id = generated
            if source.lineage then lineage.stepOrigins[generated] = source.lineage.stepOrigins and source.lineage.stepOrigins[original]
            else lineage.stepOrigins[generated] = original end
        end)
        if not indexed then return nil,indexError and indexError.code or "invalid-priority-list" end
        if failed then return nil, failed end
        local cleanLineage, problem = data.CopyData(lineage)
        if not cleanLineage then return nil, problem.code end
        local ok, reason = self:AddCustom(clone)
        if not ok then return nil, reason end
        state.lineage[newId] = cleanLineage
        return newId
    end
    return catalog
end
