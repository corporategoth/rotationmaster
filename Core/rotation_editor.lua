-- Rotation edit session: the transaction object behind the rotation editor window. A session holds a private draft of
-- one rotation body, an undo and redo history bounded by count and size, the pending ownership change and the Apply
-- step that validates the draft and publishes it into the saved record. It must not draw, and nothing outside a
-- successful Apply (or the caller's commit callback) may write the original record. Loaded after
-- Core/unsaved_changes.lua; the workspace (Core/rotation_workspace.lua) creates one session per open rotation. Body
-- shape and drafts: Data/ (addon.RotationData).

local _, addon = ...
local data = addon.RotationData
local prepareActivePublication, finishActivePublication

if type(addon.BindActiveRotationPublication) == 'function' then
    addon:BindActiveRotationPublication(function(prepare, finish)
        prepareActivePublication, finishActivePublication = prepare, finish
    end)
end

-- Deep equality of two portable data trees (no cycles, no functions).
-- @param left any  The first tree.
-- @param right any  The second tree.
-- @return boolean  True when equal; false when either side is not portable data, so a draft holding a stray function or
--   cycle never compares equal to anything.
local function equal(left, right)
    if not data.CheckPortable(left) or not data.CheckPortable(right) then
        return false
    end

    -- Compares two values deeply.
    -- @param a any  The first value.
    -- @param b any  The second value.
    -- @return boolean  True when equal.
    local function compare(a, b)
        if type(a) ~= type(b) then
            return false
        end
        if type(a) ~= 'table' then
            return a == b
        end

        for key, value in pairs(a) do
            if not compare(value, b[key]) then
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

    return compare(left, right)
end

-- Estimates the memory cost in bytes of a value, used only to bound the undo history; it is a budget, not an exact
-- size.
-- @param value any  The value to measure.
-- @return number  The estimated bytes.
local function weight(value)
    if type(value) == 'string' then
        return 32 + #value
    end
    if type(value) ~= 'table' then
        return 16
    end

    local total = 64

    for key, child in pairs(value) do
        total = total + 32 + weight(key) + weight(child)
    end

    return total
end

-- Opens an edit session on a saved rotation body.
-- @param spec number  The specialization ID or talent group the rotation is edited for.
-- @param original table  The saved rotation body.
-- @param options table|nil  Plain table: targetValid, commit, readOnly, newRecord, ownership, setOwnershipAllowed,
--   newId and reserved.
-- @return table|nil  The session (Snapshot, Baseline, BaselineOwnership, Ownership, IsDirty, HistoryState, Command,
--   Undo, Redo, Cancel, Apply); nil when the options or the body are invalid.
-- @return string|nil  The reason when the first return is nil; nil otherwise.
--
-- Only Apply writes `original`, and it does so in place so every holder of the record sees the new body.
function addon:NewRotationEditSession(spec, original, options)
    options = options or {}

    if
        type(options) ~= 'table'
        or getmetatable(options) ~= nil
        or options.targetValid ~= nil and type(options.targetValid) ~= 'function'
        or options.readOnly ~= nil and type(options.readOnly) ~= 'boolean'
        or options.newRecord ~= nil and type(options.newRecord) ~= 'boolean'
        or options.commit ~= nil and type(options.commit) ~= 'function'
        or options.ownership ~= nil and options.ownership ~= 'class' and options.ownership ~= 'character'
        or options.setOwnershipAllowed ~= nil and type(options.setOwnershipAllowed) ~= 'boolean'
    then
        return nil, 'invalid-rotation-editor-options'
    end

    local newId = options.newId or self.uuid
    local draft, why = data.NewRotationDraft(original, newId, options.reserved)

    if not draft then
        return nil, why
    end

    local baseline = data.CopyData(original)
    -- Absent empty priority lists are an old storage shape, not a user edit.
    -- Keep the exact original separately for concurrent-change detection.
    local dirtyBaseline = data.CopyData(original)

    if dirtyBaseline.rotation == nil then
        dirtyBaseline.rotation = {}
    end
    if dirtyBaseline.cooldowns == nil then
        dirtyBaseline.cooldowns = {}
    end

    local ownership, originalOwnership = options.ownership, options.ownership
    local readOnly = options.readOnly == true
    local targetValid = options.targetValid
    local closed, busy = false, false
    local undo, redo, bytes = {}, {}, 0

    -- Pushes a snapshot frame on an undo or redo stack and adds its weight to the shared byte budget.
    -- @param stack table  The undo or redo stack.
    -- @param value table  The frame { body, ownership }.
    local function push(stack, value)
        local size = weight(value)
        stack[#stack + 1] = { value = value, bytes = size }
        bytes = bytes + size
    end

    -- Removes a frame and releases its weight.
    -- @param stack table  The undo or redo stack.
    -- @param at number|nil  The frame to remove; the top one when nil.
    -- @return table|nil  The removed frame { value, bytes }; nil when the stack was empty.
    local function pop(stack, at)
        local entry = table.remove(stack, at or #stack)

        if entry then
            bytes = bytes - entry.bytes
        end

        return entry
    end

    -- Drops the oldest frames until the history is within 100 entries and 8 MiB.
    local function trim()
        while #undo + #redo > 100 or bytes > 8388608 do
            if #undo > 0 then
                pop(undo, 1)
            elseif #redo > 0 then
                pop(redo, 1)
            else
                break
            end
        end
    end

    -- Reports whether a change may be made now.
    -- @return boolean|nil  True when it may; nil otherwise.
    -- @return string|nil  'rotation-editor-closed', 'rotation-editor-busy' or 'readonly-rotation' when not; nil
    --   otherwise.
    local function writable()
        if closed then
            return nil, 'rotation-editor-closed'
        end
        if busy then
            return nil, 'rotation-editor-busy'
        end
        if readOnly then
            return nil, 'readonly-rotation'
        end

        return true
    end

    -- Reports whether the record this session edits still exists.
    -- @return boolean  True while it does; a throwing targetValid counts as gone.
    local function owner()
        if not targetValid then
            return true
        end

        local ok, valid = pcall(targetValid)
        return ok and valid == true
    end

    -- Ends the session and frees the history; every later change reports 'rotation-editor-closed'.
    local function close()
        closed = true
        undo = {}
        redo = {}
        bytes = 0
    end

    local session = {}

    -- Returns a detached copy of the draft body as it stands now.
    -- @return table  The copy.
    function session:Snapshot()
        return draft:Snapshot()
    end

    -- Returns a detached copy of the original body that unsaved-change detection compares against.
    -- @return table  The copy.
    function session:Baseline()
        return data.CopyData(dirtyBaseline)
    end

    -- Returns the pending ownership scope.
    -- @return string|nil  'class' or 'character'; nil when the caller does not manage it.
    function session:Ownership()
        return ownership
    end

    -- Returns the ownership scope the rotation had when the session opened.
    -- @return string|nil  'class' or 'character'; nil when the caller does not manage it.
    function session:BaselineOwnership()
        return originalOwnership
    end

    -- Reports whether the draft content or the ownership differs from what was opened.
    -- @return boolean  True when it does.
    function session:IsDirty()
        return ownership ~= originalOwnership or not data.SameRotationContent(dirtyBaseline, draft:Snapshot())
    end

    -- Reports whether undo and redo are currently possible, for enabling the editor's buttons.
    -- @return table  { canUndo = boolean, canRedo = boolean }; both are false while closed, busy or read-only.
    function session:HistoryState()
        return {
            canUndo = not closed and not busy and not readOnly and #undo > 0,
            canRedo = not closed and not busy and not readOnly and #redo > 0,
        }
    end

    -- Runs one named editing command on the draft (or 'SetOwnership').
    -- @param name string  The draft command name, or 'SetOwnership'.
    -- @param ... any  The command's arguments ('SetOwnership' takes the scope, 'class' or 'character').
    -- @return boolean|nil  Whether the command changed something; nil when it was refused.
    -- @return any  The command's result; the reason code when the first return is nil.
    --
    -- A command that changed something is recorded for undo and clears the redo stack.
    function session:Command(name, ...)
        local ok, reason = writable()

        if not ok then
            return nil, reason
        end

        local before = { body = draft:Snapshot(), ownership = ownership }
        local changed, result

        if name == 'SetOwnership' then
            local scope = (...)

            if not options.setOwnershipAllowed or (scope ~= 'class' and scope ~= 'character') then
                return nil, 'invalid-owner-scope'
            end

            changed = true
            ownership = scope
        else
            changed, result = draft:Command(name, ...)
        end

        if changed and (before.ownership ~= ownership or not equal(before.body, draft:Snapshot())) then
            while #redo > 0 do
                pop(redo)
            end

            push(undo, before)
            trim()
        end

        return changed, result
    end

    -- Moves one history frame from `source` to `destination`, restoring the draft to it.
    -- @param source table  The stack to take the frame from.
    -- @param destination table  The stack that receives the current state.
    -- @return boolean|nil  True when a step was taken; nil otherwise.
    -- @return string|nil  The reason when the first return is nil; nil otherwise.
    local function travel(source, destination)
        local ok, reason = writable()

        if not ok then
            return nil, reason
        end
        if #source == 0 then
            return nil, 'rotation-history-empty'
        end

        local previous = { body = draft:Snapshot(), ownership = ownership }
        local frame = source[#source].value
        local restored, problem = draft:Restore(frame.body)

        if not restored then
            return nil, problem
        end

        ownership = frame.ownership
        pop(source)
        push(destination, previous)
        trim()
        return true
    end

    -- Restores the previous draft state, if any.
    -- @return boolean|nil  True when a step was taken; nil otherwise.
    -- @return string|nil  The reason when the first return is nil; nil otherwise.
    function session:Undo()
        return travel(undo, redo)
    end

    -- Re-applies the most recently undone draft state, if any.
    -- @return boolean|nil  True when a step was taken; nil otherwise.
    -- @return string|nil  The reason when the first return is nil; nil otherwise.
    function session:Redo()
        return travel(redo, undo)
    end

    -- Discards the session without touching the original.
    -- @return boolean|nil  True when cancelled; nil while an Apply is running.
    -- @return string|nil  'rotation-editor-busy' when the first return is nil; nil otherwise.
    function session:Cancel()
        if busy then
            return nil, 'rotation-editor-busy'
        end

        close()
        return true
    end

    -- Validates the draft and publishes it.
    -- @return boolean|nil  True when published; nil on failure.
    -- @return string|nil  The reason code when the first return is nil; nil otherwise.
    -- @return table|nil  Optional details (a validation report, or what the commit callback returned).
    --
    -- Validation runs condition code that can call back into the addon, so the target and the baseline are re-checked
    -- afterwards, and a validator that mutated the candidate is rejected rather than saved.
    function session:Apply()
        local writableOk, reason = writable()

        if not writableOk then
            return nil, reason
        end

        busy = true

        -- Clears the busy flag on every exit path and passes the result through.
        -- @param ok any  The result to pass through.
        -- @param problem any  The reason to pass through.
        -- @param details any  The details to pass through.
        -- @return any  `ok`.
        -- @return any  `problem`.
        -- @return any  `details`.
        local function finish(ok, problem, details)
            busy = false
            return ok, problem, details
        end

        if not owner() then
            return finish(nil, 'rotation-target-missing')
        end
        if not equal(baseline, original) then
            return finish(nil, 'rotation-changed-externally')
        end

        local snapshot = draft:Snapshot()
        local validation = data.ValidateBody(snapshot, addon:GetImportValidationOptions())

        if not validation.valid then
            return finish(nil, 'invalid-rotation-data', validation)
        end
        if not validation.supported then
            return finish(nil, 'unsupported-rotation-data', validation)
        end
        if not validation.resolved then
            return finish(nil, 'unresolved-rotation-data', validation)
        end

        local candidate = data.CopyData(snapshot)
        local tree = data.IndexRotationSteps(candidate)

        -- Validates the switch and every step's conditions against the spec.
        -- @return boolean  True only when all of them are valid.
        local function validate()
            local valid = addon:validateCondition(candidate.switch or {}, spec)

            for _, row in ipairs(tree.rows) do
                -- Validate both arms, including forced/unreachable branches.
                if not addon:validateCondition(row.step.conditions or {}, spec) then
                    valid = false
                end
            end

            return valid
        end

        local ok, valid

        if addon.Diagnostics then
            ok, valid = addon.Diagnostics:Call({
                module = 'rotation-editor',
                operation = 'validate',
                customCode = true,
            }, validate)
        else
            ok, valid = pcall(validate)
        end

        if not ok then
            return finish(nil, 'rotation-validation-error')
        end
        if not equal(snapshot, candidate) then
            return finish(nil, 'validation-mutated-rotation')
        end
        if not valid then
            return finish(nil, 'invalid-condition-fields')
        end
        if not owner() then
            return finish(nil, 'rotation-target-missing')
        end
        if not equal(baseline, original) then
            return finish(nil, 'rotation-changed-externally')
        end

        if options.commit then
            local success, committed, problem, details = pcall(options.commit, snapshot, ownership)

            if not success then
                return finish(nil, 'rotation-commit-error')
            end
            if not committed then
                return finish(nil, problem, details)
            end

            close()
            return finish(true, nil, problem)
        end

        local previous

        if not options.newRecord then
            previous = data.CopyData(original)

            if not previous then
                return finish(nil, 'invalid-rotation-data')
            end

            if previous.rotation == nil then
                previous.rotation = {}
            end
            if previous.cooldowns == nil then
                previous.cooldowns = {}
            end
        end

        local saved, problem = data.PrepareRotationContentRevision(
            snapshot,
            previous,
            options.newRecord and 'create' or 'edit',
            ownership ~= originalOwnership
        )

        if not saved then
            return finish(nil, problem)
        end

        local publication = prepareActivePublication and prepareActivePublication(spec, nil, nil, nil, saved, original)

        if not owner() then
            return finish(nil, 'rotation-target-missing')
        end
        if not equal(baseline, original) then
            return finish(nil, 'rotation-changed-externally')
        end

        -- Publish in place, after the last check and with no callout between, so the record is never seen half-written.
        for key in pairs(original) do
            original[key] = nil
        end

        for key, value in pairs(saved) do
            original[key] = value
        end

        if finishActivePublication then
            finishActivePublication(publication)
        end

        close()
        return finish(true)
    end

    return session
end
