-- Detached edit sessions for one condition tree: a draft copy, bounded undo and redo, and a validated Apply.
-- It owns the session object and its history rules; the window that shows it is UI/condition_editor.lua. Nothing here
-- writes the live condition except Apply, which checks schema, semantics and concurrent edits first and then mutates
-- the original table in place. Loaded from RotationMaster.toc after Core/imports.lua; it needs
-- addon.RotationData (Data/condition_draft.lua, Data/validation.lua) loaded earlier.

local _, addon = ...
local data = addon.RotationData

-- ============================================================================
-- Draft commands and comparison
-- ============================================================================

-- The draft commands an edit session forwards by name; anything else is refused so the UI cannot reach other methods
-- of the draft object.
local commands = {
    Replace = true,
    Wrap = true,
    Unwrap = true,
    Add = true,
    Remove = true,
    Move = true,
    SetDisabled = true,
    GroupSelection = true,
    NegateSelection = true,
    RemoveSelection = true,
    DuplicateSelection = true,
    SetSelectionDisabled = true,
    Transfer = true,
    Insert = true,
    Duplicate = true,
    AddSibling = true,
    SetName = true,
    SetGroupType = true,
    SetProjectedDisabled = true,
}

-- True when two portable plain-data trees are equal by value. Non-portable data (functions, cycles) is never equal, so
-- such a draft always reads as changed.
local function unchanged(left, right)
    if not data.CheckPortable(left) or not data.CheckPortable(right) then
        return false
    end

    -- Conditions may legally use names such as body.rotation for their own
    -- fields. Compare plain values without envelope/step identity semantics.
    local function equal(a, b)
        if type(a) ~= type(b) then
            return false
        end
        if type(a) ~= "table" then
            return a == b
        end

        for key, value in pairs(a) do
            if not equal(value, b[key]) then
                return false
            end
        end

        for key in pairs(b) do
            if a[key] == nil then
                return false
            end
        end

        return true
    end

    return equal(left, right)
end

-- ============================================================================
-- Condition values
-- ============================================================================

-- The value a newly chosen condition type starts with. Aura conditions start
-- with every rank matching (`anyrank`) on clients that have spell ranks, so
-- "Use this exact spell rank" starts unticked like the other rank options.
-- Saved conditions without the field keep matching the exact ID.
function addon:NewConditionValue(tag)
    local value = { type = tag }
    local definition = self.conditionDefinitions and self.conditionDefinitions[tag]

    if
        type(definition) == "table"
        and type(definition.fields) == "table"
        and definition.fields.anyrank == "boolean"
        and type(self.ClientHasSpellRanks) == "function"
        and self:ClientHasSpellRanks()
    then
        value.anyrank = true
    end

    return value
end

-- ============================================================================
-- Edit session
-- ============================================================================

-- Editing is detached from the running rotation. Only explicit Apply writes
-- the original plain table, after schema, semantic and concurrent-edit checks.
-- Returns a session object (Snapshot, Baseline, IsDirty, Rows, Command, HistoryState, Undo, Redo, Cancel, Apply) over a
-- draft copy of the condition tree `original`, or nil and a reason. targetValid, when given, says whether the owner
-- the condition belongs to still exists; options.readOnly refuses every edit and options.announcementTarget selects the
-- announcement validator. Apply returns true after writing back into `original`, or nil and a reason code.
function addon:NewConditionEditSession(spec, original, targetValid, options)
    options = options or {}

    if type(options) ~= 'table' or options.readOnly ~= nil and type(options.readOnly) ~= 'boolean' then
        return nil, 'invalid-editor-options'
    end

    local readOnly = options.readOnly == true

    if targetValid ~= nil and type(targetValid) ~= "function" then
        return nil, "invalid-editor-owner"
    end

    -- True when the owner of the condition still exists; a throwing owner check counts as gone.
    local function targetExists()
        if not targetValid then
            return true
        end

        local ok, exists = pcall(targetValid)
        return ok and exists == true
    end

    local draft, why = data.NewConditionDraft(original, self.conditionDefinitions)

    if not draft then
        return nil, why
    end

    local baseline = draft:Snapshot()
    local closed = false
    -- History belongs to this unsaved draft. Bound both the number of edits
    -- and an estimate of retained table/string storage, including redo states.
    local undo, redo, historyBytes = {}, {}, 0

    -- Rough byte cost of a value, used only to bound how much undo history one draft may retain.
    local function weight(value)
        if type(value) == "string" then
            return 32 + #value
        end
        if type(value) ~= "table" then
            return 16
        end

        local total = 64

        for key, child in pairs(value) do
            total = total + 32 + weight(key) + weight(child)
        end

        return total
    end

    -- Pushes a snapshot on the undo or redo stack and adds its weight to the retained total.
    local function push(stack, value)
        local bytes = weight(value)
        stack[#stack + 1] = { value = value, bytes = bytes }
        historyBytes = historyBytes + bytes
    end

    -- Removes and returns an entry (the newest unless an index is given), releasing its weight.
    local function pop(stack, index)
        local entry = table.remove(stack, index or #stack)

        if entry then
            historyBytes = historyBytes - entry.bytes
        end

        return entry
    end

    -- Drops the oldest history while the edit count or retained size is over its cap.
    local function trim()
        while #undo + #redo > 100 or historyBytes > 8388608 do
            if #undo > 0 then
                pop(undo, 1)
            elseif #redo > 0 then
                pop(redo, 1)
            else
                break
            end
        end
    end

    -- Ends the session: further commands are refused and the history is released.
    local function close()
        closed = true
        undo = {}
        redo = {}
        historyBytes = 0
    end

    local session = {}

    -- Returns a copy of the draft as it stands now.
    function session:Snapshot()
        return draft:Snapshot()
    end

    -- Returns a copy of the condition as it was when the session opened.
    function session:Baseline()
        return data.CopyData(baseline)
    end

    -- True when the draft differs from the baseline by value.
    function session:IsDirty()
        return not unchanged(baseline, draft:Snapshot())
    end

    -- Returns the draft's display rows, up to limit.
    function session:Rows(limit)
        return draft:Rows(limit)
    end

    -- Runs a whitelisted draft command. A command that really changes the draft pushes the prior state on the undo
    -- stack and clears redo. Returns the draft's own ok, result, or nil and a reason when closed, read-only or unknown.
    function session:Command(name, path, value)
        if closed then
            return nil, "condition-editor-closed"
        end
        if readOnly then
            return nil, "readonly-condition"
        end
        if not commands[name] then
            return nil, "invalid-editor-command"
        end

        local before = draft:Snapshot()
        local ok, result = draft[name](draft, path, value)

        if ok and not unchanged(before, draft:Snapshot()) then
            while #redo > 0 do
                pop(redo)
            end

            push(undo, before)
            trim()
        end

        return ok, result
    end

    -- Reports whether undo and redo are currently possible, for enabling the buttons.
    function session:HistoryState()
        return {
            canUndo = not closed and not readOnly and #undo > 0,
            canRedo = not closed and not readOnly and #redo > 0,
        }
    end

    -- Moves one history step: restores the newest entry of source and stacks the current state on destination.
    local function travel(source, destination)
        if closed then
            return nil, "condition-editor-closed"
        end
        if readOnly then
            return nil, "readonly-condition"
        end
        if #source == 0 then
            return nil, "condition-history-empty"
        end

        local entry = source[#source]
        local current = draft:Snapshot()
        local ok, problem = draft:Replace({}, entry.value)

        if not ok then
            return nil, problem
        end

        pop(source)
        push(destination, current)
        trim()
        return true
    end

    -- Steps back one edit; returns true, or nil and a reason when there is nothing to undo.
    function session:Undo()
        return travel(undo, redo)
    end

    -- Re-applies the last undone edit; returns true, or nil and a reason when there is nothing to redo.
    function session:Redo()
        return travel(redo, undo)
    end

    -- Abandons the draft without touching the original condition.
    function session:Cancel()
        close()
    end

    -- Validates the draft and, only if every check passes, copies it into the original table and closes the session.
    -- Returns true, or nil and a reason code (with the validation result for the schema failures). The checks run
    -- twice around the validator because it runs custom code: the draft must not have been mutated by it and the
    -- original and its owner must not have changed meanwhile.
    function session:Apply()
        if closed then
            return nil, "condition-editor-closed"
        end
        if readOnly then
            return nil, "readonly-condition"
        end
        if not targetExists() then
            return nil, "condition-target-missing"
        end
        if not unchanged(baseline, original) then
            return nil, "condition-changed-externally"
        end

        local snapshot = draft:Snapshot()
        local body = { name = "Condition draft", switch = snapshot, rotation = {}, cooldowns = {} }
        local result = data.ValidateBody(body, addon:GetImportValidationOptions())

        if not result.valid then
            return nil, "invalid-condition-data", result
        end
        if not result.supported then
            return nil, "unsupported-condition-data", result
        end
        if not result.resolved then
            return nil, "unresolved-condition-data", result
        end

        local candidate = data.CopyData(snapshot)

        -- Runs the announcement or the ordinary condition validator on the candidate copy; it may run custom code,
        -- hence the checks around it.
        local function validate()
            if options.announcementTarget then
                return addon:validateAnnouncementCondition(candidate, spec)
            end

            return addon:validateCondition(candidate, spec)
        end

        local ok, valid

        if addon.Diagnostics then
            ok, valid = addon.Diagnostics:Call({
                module = "condition-editor",
                operation = "validate",
                customCode = true,
            }, validate)
        else
            ok, valid = pcall(validate)
        end

        if not ok then
            return nil, "condition-validation-error"
        end
        if not unchanged(snapshot, candidate) then
            return nil, "validation-mutated-condition"
        end
        if not valid then
            return nil, "invalid-condition-fields"
        end
        if not targetExists() then
            return nil, "condition-target-missing"
        end
        if not unchanged(baseline, original) then
            return nil, "condition-changed-externally"
        end

        for key in pairs(original) do
            original[key] = nil
        end

        for key, value in pairs(snapshot) do
            original[key] = value
        end

        close()
        return true
    end

    return session
end
