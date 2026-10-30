-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Condition editor window: the native window that edits one condition tree (a rotation step's conditions, a rotation's
-- switch condition, or an announcement's condition) as cards on a canvas, with undo/redo, Apply and Cancel.
-- It owns the shell (window, toolbar, status line), the working copy of the tree and the guards that keep it from
-- writing into a rotation that has since changed; the edit model and history are in Core/condition_editor.lua and the
-- card layout in UI/condition_canvas.lua. It never saves directly: Apply hands the validated tree to the caller's
-- callback.
-- Loaded from RotationMaster.toc after UI/condition_canvas.lua and before UI/condition_text.lua;
-- UI/rotation_editor.lua, UI/settings_announces.lua and UI/condition_entrypoints.lua open it through
-- addon:ShowConditionEditor.

local addon_name, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- ============================================================================
-- Path and tree helpers
-- ============================================================================

-- Returns a shallow copy of a path so it can be edited without touching the original.
-- @param path table  A condition path (a list of keys and indexes).
-- @return table  A new list with the same entries.
local function copyPath(path)
    local result = {}

    for index, part in ipairs(path) do
        result[index] = part
    end

    return result
end

local pathKey = addon.ConditionPathKey

-- Follows `path` down from `root`.
-- @param root any  The tree to start from.
-- @param path table  The keys and indexes to follow.
-- @return any  The value at the end of the path; nil when a level is missing or not a table.
local function at(root, path)
    local node = root

    for _, part in ipairs(path) do
        if type(node) ~= "table" then
            return nil
        end

        node = node[part]
    end

    return node
end

-- Path of the group that holds the node at `path`: drops a trailing child index and then the key it hangs from.
-- @param path table  The path of a condition node.
-- @return table  A new path to the enclosing group.
local function parentPath(path)
    local result = copyPath(path)

    if type(result[#result]) == "number" then
        table.remove(result)
    end

    table.remove(result)
    return result
end

-- Walks a widget tree for fields with typed-but-uncommitted input.
-- @param widget table  The root of the condition widget tree (uses CommitPending, IsPending and children).
-- @param commit boolean|nil  True to commit every pending field; nil or false to only look.
-- @return boolean|nil  With commit: true when every field committed, nil as soon as a field refuses (its text is
--   invalid). Without it: true if any field is pending, false otherwise.
local function pendingFields(widget, commit)
    if commit then
        if widget.CommitPending and not widget:CommitPending() then
            return nil
        end
    elseif widget.IsPending and widget:IsPending() then
        return true
    end

    for _, child in ipairs(widget.children or {}) do
        local result = pendingFields(child, commit)

        if commit and not result then
            return nil
        end
        if not commit and result then
            return true
        end
    end

    return commit == true
end

-- Card title for a condition node: the group operator, "Always", or the condition's description, with the spell name
-- appended when the node has a spell. An unregistered type reads as "Unknown condition".
-- @param node table  A condition node ({ type, spell, ... }).
-- @return string  The localized title.
local function caption(node)
    if node.type == "AND" then
        return L["All (AND)"]
    end
    if node.type == "OR" then
        return L["Any (OR)"]
    end
    if node.type == "NOT" then
        return L["Not (NOT)"]
    end
    if not node.type then
        return L["Always (no condition)"]
    end

    local definition = addon.conditionDefinitions[node.type]

    local text = definition and type(definition.description) == "string" and definition.description or string.format(
        L["Unknown condition: %s"],
        node.type
    )

    if node.spell and addon.Platform then
        local info = addon.Platform:GetSpellInfo(node.spell)

        if info then
            text = text .. ": " .. info.name

            if info.subtext and info.subtext ~= "" then
                text = text .. " (" .. info.subtext .. ")"
            end
        end
    end

    return text
end

-- Status-line text for each reason code the editor core can return; shell:Message falls back to a generic line.
local messages = {
    ["condition-limit"] = L["This condition exceeds the supported editor limits."],
    ["condition-property-conflict"] = L["Resolve the wrapper's name or unsupported fields before removing its negation."],
    ["condition-target-missing"] = L["The original rotation or step was removed or replaced. Cancel this draft and reopen the current one."],
    ["condition-changed-externally"] = L["This condition changed in another editor. Cancel and reopen it before applying."],
    ["invalid-condition-fields"] = L["Complete the selected condition's fields before applying."],
    ["invalid-condition-data"] = L["Some condition fields have invalid values. Check them before applying."],
    ["unsupported-condition-data"] = L["This draft contains conditions or fields that this version cannot apply."],
    ["unresolved-condition-data"] = L["This draft refers to missing data. Resolve those references before applying."],
    ["condition-validation-error"] = L["A condition could not be validated. Use /rm errors for details."],
    ["validation-mutated-condition"] = L["A custom validator changed the condition while checking it. Fix the validator before applying."],
    ["ambiguous-group-unwrapping"] = L["Ungroup requires a group with at most one child."],
    ["invalid-condition-move"] = L["This condition has no adjacent sibling in that direction."],
}

-- ============================================================================
-- The shell
-- ============================================================================

-- Builds the editor window and its shell object once; the shell is reused for every condition the editor opens (the
-- per-open state lives in shell.active). The methods below are defined on it.
-- @return table  The shell { frame, title, status, chrome, canvas, ... } with its methods.
local function createShell()
    local window = addon:TrackWorkbenchSize(CreateFrame("Frame", nil, UIParent))
    window:SetSize(760, 620)
    window:SetPoint("CENTER")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:SetResizable(true)
    window:EnableMouse(true)

    if window.SetResizeBounds then
        window:SetResizeBounds(660, 460)
    end

    local shell = { frame = window, tools = {}, userdata = {} }
    shell.title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    shell.title:SetPoint("TOPLEFT", 16, -10)
    shell.status = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    shell.status:SetPoint("BOTTOMLEFT", 16, 16)
    shell.status:SetJustifyH("LEFT")
    shell.status:SetWordWrap(false)
    shell.chrome = addon:CreateWorkbenchDialogChrome(window, shell.title)
    shell.title:SetWidth(370)
    local drag = CreateFrame("Frame", nil, window)
    drag:SetPoint("TOPLEFT", 8, -1)
    drag:SetPoint("TOPRIGHT", -250, -1)
    drag:SetHeight(28)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")

    addon:SetUIScript(drag, "OnDragStart", function()
        window:StartMoving()
    end)

    addon:SetUIScript(drag, "OnDragStop", function()
        window:StopMovingOrSizing()
    end)

    -- Shows the status text for a reason code from the core.
    -- @param reason string|nil  A reason code from the messages table; anything else shows a generic line.
    function shell:Message(reason)
        self.status:SetText(messages[reason] or L["That change could not be applied. Check the selected condition."])
    end

    -- Shows the window only while an edit is open.
    function shell:Show()
        if self.active then
            window:Show()
        end
    end

    -- Hides the window; the OnHide handler ends the edit.
    function shell:Hide()
        window:Hide()
    end

    -- Accepts the one event this shell supports: OnClose installs an override that replaces the default close.
    -- @param event string  The event name; only "OnClose" is honoured.
    -- @param callback function|nil  The close override.
    function shell:SetCallback(event, callback)
        if event == "OnClose" then
            self.closeOverride = callback
        end
    end

    -- Per-shell flags set by the opener (for example announcementTarget).
    -- @param key string  The flag name.
    -- @param value any  The flag value.
    function shell:SetUserData(key, value)
        self.userdata[key] = value
    end

    -- Read side of the user data; root, spec and index answer from the active edit so condition widgets can ask the
    -- shell about the tree they live in.
    -- @param key string  The flag name, or "root", "spec" or "index".
    -- @return any  The stored or derived value; nil when unset.
    function shell:GetUserData(key)
        if self.active then
            if key == "root" then
                return self.active.working
            end
            if key == "spec" then
                return self.active.spec
            end
            if key == "index" then
                return self.active.index
            end
        end

        return self.userdata[key]
    end

    -- Commits every card's pending input into the session. A read-only edit has nothing to sync.
    -- @return boolean|nil  True on success; nil after showing why (a field refused its text, or the core rejected the
    --   whole-tree replace) or when no edit is open.
    function shell:SyncWorking()
        if not self.active then
            return nil
        end
        if self.active.readOnly then
            return true
        end

        for _, card in ipairs(self.canvas.cards) do
            if card.pane and not pendingFields(card.pane, true) then
                self:Message('invalid-condition-fields')
                return nil
            end
        end

        local ok, why = self.active.session:Command("Replace", {}, self.active.working)

        if not ok then
            self:Message(why)
        end

        return ok
    end

    -- After any edit: syncs the pending input and, if that worked, clears the status line and reflows the canvas.
    function shell:SetStatusText()
        if self.loading or not self.active then
            return
        end

        if self:SyncWorking() then
            self.status:SetText("")
            self.canvas:Reflow()
        end
    end

    -- Marks changed cards as unsaved and enables Undo, Redo and Apply from the session's history and dirty state.
    --
    -- Pending typed input counts as a change (it enables Undo and Apply) but blocks Redo.
    function shell:UpdateHistoryButtons()
        if not self.active or not self.undo then
            return
        end

        local state = self.active.session:HistoryState()
        local baseline = self.active.session:Baseline()

        for _, card in ipairs(self.canvas.cards) do
            if card.model then
                addon:SetWorkbenchUnsaved(
                    card.frame,
                    not self.active.readOnly
                        and (not addon:UnsavedDataEqual(at(self.active.working, card.model.path), at(
                            baseline,
                            card.model.path
                        ))
                            or card.pane and pendingFields(card.pane, false))
                )
            end
        end

        local pending = false

        for _, card in ipairs(self.canvas.cards) do
            if card.pane and pendingFields(card.pane, false) then
                pending = true
                break
            end
        end

        if state.canUndo or not self.active.readOnly and pending then
            self.undo:Enable()
        else
            self.undo:Disable()
        end

        if state.canRedo and not pending then
            self.redo:Enable()
        else
            self.redo:Disable()
        end

        if not self.active.readOnly and (self.active.session:IsDirty() or pending) then
            self.apply:Enable()
        else
            self.apply:Disable()
        end
    end

    -- Opens the help window for the condition on a card.
    -- @param model table  The canvas card model the help was requested from (fieldPath, path, name).
    -- @param cardAlive function  Returns true while the card is still bound to that condition.
    -- @return any  Whatever OpenWorkbenchHelp returns; nil when the card is stale or no help window exists.
    --
    -- The help is rendered by the condition's own help function, so every step re-checks that the edit, the saved data,
    -- the condition definition and the target are all still the ones the card was drawn for (`current`); a stale card
    -- closes its help instead of showing the wrong text.
    function shell:ShowSubjectHelp(model, cardAlive)
        local active = self.active

        if not active or not cardAlive() then
            return
        end

        local working = active.working
        local path = copyPath(model.fieldPath or model.path)
        local node = at(working, path)

        if type(node) ~= 'table' then
            return
        end

        local tag = node.type
        local definitions = addon.conditionDefinitions
        local revision = addon.conditionRegistryVersion
        local definition = definitions and rawget(definitions, tag)
        local profile, global, char = active.profile, active.global, active.char

        -- True while the same edit, working tree, saved-data tables, node and condition registry are still current.
        -- @return boolean  True when nothing the help depends on has been replaced.
        local function owned()
            return self.active == active
                and active.working == working
                and cardAlive()
                and addon.db.profile == profile
                and addon.db.global == global
                and addon.db.char == char
                and (active.persistentOwner or active.generation == addon.configPaneGeneration)
                and at(working, path) == node
                and node.type == tag
                and addon.conditionDefinitions == definitions
                and addon.conditionRegistryVersion == revision
                and (not definitions or rawget(definitions, tag) == definition)
        end

        -- `owned` plus the opener's own target check (the rotation or step still exists).
        -- @return boolean  True when the help's owner is still valid.
        --
        -- The target check runs under pcall and may itself change state, so ownership is verified again afterwards.
        local function ownerValid()
            if not owned() then
                return false
            end

            if active.targetValid then
                local ok, value = pcall(active.targetValid)

                if not ok or value ~= true then
                    return false
                end
            end

            return owned()
        end

        local group = tag == 'AND' or tag == 'OR' or tag == 'NOT'
        local available, help, initialized

        -- True while the help should stay open: the owner is valid and, once rendered, the condition is still available
        -- and its help function is unchanged.
        -- @return boolean  True when the help is still current.
        local function current()
            if not ownerValid() then
                return false
            end

            if initialized and not group then
                local now = definition
                    and not definition.disabled
                    and not definition.functionUnavailable
                    and not definition.functionSuspended

                if now ~= available then
                    return false
                end

                local same = not available or definition.help == help
                return same and ownerValid()
            end

            return ownerValid()
        end

        local request = { heading = L['Condition'], valid = current }

        -- Help request callback: returns the text sections for groups and for conditions without usable help (an empty
        -- list when the condition has its own help function, which request.render draws).
        -- @return table[]  Sections shaped { title=string, text=string }; empty when stale or when request.render will
        --   draw the help.
        request.sections = function()
            if not ownerValid() then
                return {}
            end

            available = definition
                and not definition.disabled
                and not definition.functionUnavailable
                and not definition.functionSuspended

            help = not group and available and definition.help
            initialized = true
            local heading = model.name or definition and definition.description or L['Condition']
            request.heading = addon:PlainWorkbenchName(type(heading) == 'string' and heading or L['Condition'])
            request.owner = self.chrome.author:GetText()
            request.renderContext = { customCode = definition and definition.customCode == true, conditionTag = tag }

            if not current() then
                return {}
            end

            if group then
                request.render = nil

                return {
                    {
                        title = L['Groups and toggles'],
                        text = L["AND stops at the first non-match; OR stops at the first match. NOT reverses a known result. Encountered unavailable data remains unavailable. Skipped children are not evaluated."],
                    },
                }
            elseif not available then
                request.render = nil

                return {
                    {
                        title = L['Unavailable'],
                        text = L["Help for this condition is unavailable. Its registered definition is missing, disabled or waiting for required functions. Opening Help does not register pending or imported source."],
                    },
                }
            elseif type(help) ~= 'function' then
                request.render = nil
                return { { title = L['Help'], text = L["This registered condition does not provide Help."] } }
            end

            return {}
        end

        -- Renders the condition's own help function into a group at (0, -y), under a lease so a stale render never
        -- touches a reused widget. Errors are rethrown after release.
        -- @param parent Frame  The frame the help group is parented to.
        -- @param requestCurrent function  Returns true while the help window still wants this render.
        -- @param y number  The vertical offset of the group below the top of the parent.
        -- @param width number  The width of the group.
        -- @return table  The mount { height=number, Release=function } with the rendered height.
        request.render = function(parent, requestCurrent, y, width)
            local pane, lease
            local mount = { height = 0 }

            -- Releases the help group, but only if it is still the lease this mount created.
            function mount:Release()
                if self.released then
                    return
                end

                self.released = true

                if pane and pane.rmActive and pane.rmLease == lease then
                    addon:ReleaseConditionWidget(pane)
                end
            end

            -- True while the group, if created, is still the one this mount owns.
            -- @return boolean  True when no group exists yet or the group is on its original lease.
            local function paneCurrent()
                return not pane or pane.rmActive and pane.rmLease == lease
            end

            -- True while this render is still wanted; checked between every step because the help function is custom
            -- code that can take a while or change the world.
            -- @return boolean  True when the mount, its group, the editor and the request are all still current.
            local function live()
                if mount.released or not paneCurrent() or not current() or not requestCurrent() then
                    return false
                end

                return not mount.released and paneCurrent()
            end

            -- Creates the group, runs the condition's help function into it and guards the callbacks it registered,
            -- stopping at the first step where live() turns false; runs under pcall so the mount can be released on
            -- error.
            local ok, why = pcall(function()
                if not live() then
                    return
                end

                pane = addon:CreateConditionGroup()
                lease = pane.rmLease

                if not live() then
                    return
                end

                pane.frame:SetParent(parent)
                pane.frame:ClearAllPoints()
                pane.frame:SetPoint('TOPLEFT', 0, -y)
                pane:SetWidth(width)
                pane:SetLayout('List')

                if not live() then
                    return
                end

                help(pane)

                if not live() then
                    return
                end

                -- Wraps every callback the help function registered so it fires only while this render is live and the
                -- widget is still on its original lease.
                -- @param widget table  A condition widget; its children are wrapped recursively.
                local function guardCallbacks(widget)
                    local widgetLease = widget.rmLease
                    local callbacks = {}

                    for event, callback in pairs(widget.events or widget.callbacks or {}) do
                        callbacks[event] = callback
                    end

                    for event, callback in pairs(callbacks) do
                        if type(callback) == 'function' then
                            widget:SetCallback(event, function(...)
                                if live() and widget.rmActive and widget.rmLease == widgetLease then
                                    return callback(...)
                                end
                            end)
                        end
                    end

                    for _, child in ipairs(widget.children or {}) do
                        guardCallbacks(child)
                    end
                end

                guardCallbacks(pane)
                pane:DoLayout()

                if live() then
                    mount.height = pane.frame:GetHeight()
                end
            end)

            if not ok or not live() then
                mount:Release()
            end
            if not ok then
                error(why, 0)
            end

            return mount
        end

        local open = rawget(addon, 'OpenWorkbenchHelp')

        if type(open) == 'function' then
            return open(addon, request)
        end
    end

    -- Builds the card scene for the working tree and flags each card that changed from the baseline or that the import
    -- validator reports a problem for.
    -- @param includeHidden boolean|nil  When true, collapsed and hidden cards are expanded in a copy of the view, so
    --   validation sees every card.
    -- @return table|nil  The scene from addon:BuildConditionCanvas; nil after showing why.
    function shell:Scene(includeHidden)
        self.view.width = self.canvas.frame:GetWidth() - 8
        self.view.definitions = addon.conditionDefinitions
        local rows, complete = self.active.session:Rows(4096)
        self.rows = rows
        local view = self.view

        if includeHidden then
            view = {}

            for key, value in pairs(self.view) do
                view[key] = value
            end

            view.collapsed = {}
            view.hiddenChildren = {}
        end

        local scene, problem = addon:BuildConditionCanvas(self.active.working, rows, view, complete)

        if not scene then
            self:Message(problem and problem.code)
            return nil
        end

        local baseline = self.active.session:Baseline()

        local result = addon.RotationData.ValidateBody({
            switch = self.active.working,
            rotation = {},
            cooldowns = {},
        }, addon:GetImportValidationOptions())

        local byDiagnosticPath = {}

        for _, card in ipairs(scene.cards) do
            card.changed = not self.active.readOnly
                and not addon:UnsavedDataEqual(at(self.active.working, card.path), at(baseline, card.path))

            local path = "$.body.switch"

            for _, part in ipairs(card.path) do
                path = path .. (type(part) == "number" and "[" .. part .. "]" or "." .. part)
            end

            byDiagnosticPath[path] = card
        end

        for _, diagnostic in ipairs(result.diagnostics) do
            -- Marks the card at a diagnostic path invalid, once, with the first problem found for it.
            -- @param path string  The diagnostic path ("$.body.switch..." form) of the card to mark.
            local function flag(path)
                local card = byDiagnosticPath[path]

                if card and not card.invalid then
                    card.invalid = true
                    card.problem = diagnostic.code
                    card.problemField = diagnostic.path:match("%.([%w_]+)$")

                    card.problemText = addon.DescribeUnsupportedCondition and addon:DescribeUnsupportedCondition(
                        diagnostic
                    )
                        or nil
                end
            end

            -- A problem in a field also marks every ancestor card, so a collapsed group shows it.
            flag(diagnostic.path)

            for cursor = 1, #diagnostic.path do
                local ch = diagnostic.path:sub(cursor, cursor)

                if ch == '.' or ch == '[' then
                    flag(diagnostic.path:sub(1, cursor - 1))
                end
            end
        end

        return scene
    end

    -- Validates the cards at or under `paths` and expands the invalid ones. Seed editable fields only at entry or for
    -- newly added/replaced subtrees; redrawing and ordinary field edits retain the user's current fold state.
    -- @param paths table[]  The condition paths whose cards (and descendants) to check.
    -- @return boolean  False when the edit changed while this ran (nothing more to do); true otherwise.
    --
    -- For each card at or under one of `paths`, validates its condition (custom validators run through
    -- addon.Diagnostics, and a validator that changes the condition counts as invalid) and expands the card and its
    -- ancestors when it is invalid.
    function shell:ExpandInvalid(paths)
        local active, view = self.active, self.view
        local working = active.working
        local definitions, revision = addon.conditionDefinitions, addon.conditionRegistryVersion

        -- True while the same edit, view, working tree, saved-data tables and condition registry are current.
        -- @return boolean  True when none of them was replaced.
        local function owned()
            return self.active == active
                and self.view == view
                and active.working == working
                and addon.db.profile == active.profile
                and addon.db.global == active.global
                and addon.db.char == active.char
                and (active.persistentOwner or active.generation == addon.configPaneGeneration)
                and addon.conditionDefinitions == definitions
                and addon.conditionRegistryVersion == revision
        end

        -- `owned` plus the opener's target check, with ownership verified again after it.
        -- @return boolean  True when the edit is still current and its target still exists.
        local function current()
            if not owned() then
                return false
            end

            if active.targetValid then
                local ok, valid = pcall(active.targetValid)

                if not ok or valid ~= true then
                    return false
                end
            end

            return owned()
        end

        if not current() then
            return false
        end

        local scene = self:Scene(true)

        if not scene or not current() then
            return false
        end

        for _, card in ipairs(scene.cards) do
            local selected = false

            for _, path in ipairs(paths) do
                local matches = #path <= #card.fieldPath

                for index, part in ipairs(path) do
                    if card.fieldPath[index] ~= part then
                        matches = false
                        break
                    end
                end

                if matches then
                    selected = true
                    break
                end
            end

            if selected then
                local invalid = card.invalid

                if not invalid and not card.group then
                    local candidate = addon.RotationData.CopyData(at(working, card.fieldPath))

                    if candidate then
                        candidate.disabled = nil
                        local before = addon.RotationData.CopyData(candidate)

                        -- Runs the validator for the editor's kind of target (announcement or rotation).
                        -- @return boolean  True when the candidate condition is valid.
                        local function validate()
                            if self.userdata.announcementTarget then
                                return addon:validateAnnouncementCondition(candidate, active.spec)
                            end

                            return addon:validateCondition(candidate, active.spec)
                        end

                        local ok, valid

                        if addon.Diagnostics then
                            local definition = definitions[candidate.type]

                            ok, valid = addon.Diagnostics:Call({
                                module = 'condition-editor',
                                operation = 'validate',
                                customCode = definition and definition.customCode == true,
                            }, validate)
                        else
                            ok, valid = pcall(validate)
                        end

                        if not current() then
                            return false
                        end

                        invalid = not ok or not valid or not addon:UnsavedDataEqual(before, candidate)
                    end
                end

                if invalid then
                    view.cardStates[card.key] = 'expanded'
                    local path = {}

                    for index = 0, #card.path do
                        if index > 0 then
                            path[index] = card.path[index]
                        end

                        local key = pathKey(path)
                        view.hiddenChildren[key] = nil
                        view.collapsed[key] = nil
                        local parent = scene.cardsByKey[key]

                        if parent then
                            view.cardStates[key] = 'expanded'
                        end
                    end
                end
            end
        end

        return true
    end

    -- Card title for a model; a missing operand shows the "Always" caption.
    -- @param model table  The canvas card model (fieldPath, missingOperand).
    -- @return string  The localized title.
    function shell:Caption(model)
        local node = model.missingOperand and {} or at(self.active.working, model.fieldPath) or {}
        local label = caption(node)
        return label
    end

    -- One-line description under a card title: the problem when the card is invalid, a hint for an empty group,
    -- otherwise the condition read as prose.
    -- @param model table  The canvas card model (invalid, problem, problemText, type, childCount, fieldPath,
    --   missingOperand).
    -- @return string  The summary text.
    function shell:Summary(model)
        if model.invalid then
            if model.problemText then
                return model.problemText
            end

            return model.problem == "missing-field" and string.format(
                L["Incomplete: %s is required"],
                model.problemField or "?"
            )
                or L["Invalid or unsupported condition fields"]
        end

        if model.type == "AND" and model.childCount == 0 then
            return L["An empty AND group always matches. Add a condition to restrict it."]
        end
        if model.type == "OR" and model.childCount == 0 then
            return L["An empty OR group never matches. Add a condition that can match."]
        end

        local node = model.missingOperand and {} or at(self.active.working, model.fieldPath) or {}
        return addon:DescribeCardCondition(node, self.active.spec)
    end

    -- Opens the condition type picker on a card to add (a missing operand) or replace its condition. A choice goes
    -- through the session as an Add or Replace command.
    -- @param card table  The card whose type button anchors the picker.
    -- @param model table  The canvas card model (fieldPath, missingOperand).
    -- @param alive function  Returns true while the card is still the one the picker was opened for.
    --
    -- Syncs pending input first and releases any picker still open.
    function shell:OpenTypePicker(card, model, alive)
        if not alive() or self.active.readOnly or not self:SyncWorking() then
            return
        end

        if self.openPicker then
            self.openPicker:Release()
        end

        local active = self.active
        local node = at(active.working, model.fieldPath)

        local picker = addon:CreateConditionTypePicker(
            window,
            self.userdata.announcement and "ANNOUNCEMENT" or active.index and active.index > 0 and "ALL" or "SWITCH",
            node and node.type,
            -- Picker choice: stages the chosen type as an Add (missing operand) or Replace command on the card's
            -- condition; ignored when the card is gone or the type is unchanged.
            -- @param tag string  The chosen condition type tag.
            function(tag)
                if not alive() then
                    return
                end

                local current = at(active.working, model.fieldPath)

                if not model.missingOperand and current and current.type == tag then
                    return
                end

                self:Command(
                    model.missingOperand and "Add" or "Replace",
                    model.fieldPath,
                    addon.NewConditionValue and addon:NewConditionValue(tag) or { type = tag }
                )
            end,
            alive,
            card.picker
        )

        card.picker = picker
        self.openPicker = picker
        picker:Open(card.typeButton)
    end

    -- Builds the editable body of a card. A group card gets the All/Any toggle. A condition card gets a pane of the
    -- condition's own widgets, built from a PRIVATE copy of the tree.
    -- @param card table  The card whose field area is filled.
    -- @param model table  The canvas card model (group, type, fieldPath, missingOperand, key, width).
    -- @param alive function  Returns true while the card is still bound; it must return false once the card is redrawn
    --   or released.
    --
    -- Those widgets mutate their input before telling the owner, so edits reach the working tree only through
    -- syncField, which merges the changes as a session command.
    function shell:BuildFields(card, model, alive)
        if model.group then
            card.groupControls = card.groupControls or {}

            for i, entry in ipairs({ { 'AND', L['All'] }, { 'OR', L['Any'] } }) do
                local operator = entry[1]
                local control = card.groupControls[i]

                if not control then
                    control = addon:CreateWorkbenchPill(card.fields, entry[2], 72)
                    card.groupControls[i] = control
                end

                control:SetPoint('TOPLEFT', (i - 1) * 78, -4)
                control:SetSelected(model.type == operator)

                if self.active.readOnly then
                    control:Disable()
                else
                    control:Enable()
                end

                addon:SetUIScript(control, 'OnClick', function()
                    if alive() and not self.active.readOnly then
                        self:Command('SetGroupType', model.fieldPath, operator)
                    end
                end)

                control:Show()
            end

            self.view.detailsHeights[model.key] = 32

            -- Hides the All/Any toggles and the help text and clears their click scripts when the card is released.
            card.releaseFields = function()
                for _, control in ipairs(card.groupControls) do
                    control:Hide()
                    addon:SetUIScript(control, 'OnClick', nil)
                end

                if card.helpText then
                    card.helpText:Hide()
                end
            end

            return
        end

        local active = self.active
        -- Legacy widgets capture and mutate their input table before notifying
        -- their owner. Give each pane a private copy so released callbacks can
        -- only change an abandoned copy, never the current editor draft.
        local fieldRoot = addon.RotationData.CopyData(active.working)
        local node = model.missingOperand and {} or at(fieldRoot, model.fieldPath)
        self.loading = true
        local fieldBaseline = addon.RotationData.CopyData(node)

        -- Deep copy of plain data.
        -- @param value any  The value to copy.
        -- @return any  A copy of a table; any other value unchanged.
        local function clone(value)
            if type(value) ~= "table" then
                return value
            end

            local result = {}

            for key, child in pairs(value) do
                result[key] = clone(child)
            end

            return result
        end

        -- Three-way merge: applies what the user changed between `before` and `edited` onto `current`, so changes made
        -- to the same node elsewhere in the meantime (an undo, another card) are kept.
        -- @param current any  The latest value in the working tree.
        -- @param before any  The value the pane was built from.
        -- @param edited any  The pane's value now.
        -- @return any  A new value; a copy of `edited` when `before` or `edited` is not a table.
        local function merge(current, before, edited)
            if type(before) ~= "table" or type(edited) ~= "table" then
                return clone(edited)
            end

            local result = type(current) == "table" and clone(current) or {}

            for key, value in pairs(edited) do
                if type(value) == "table" and type(before[key]) == "table" then
                    result[key] = merge(result[key], before[key], value)
                elseif value ~= before[key] then
                    result[key] = clone(value)
                end
            end

            for key in pairs(before) do
                if edited[key] == nil then
                    result[key] = nil
                end
            end

            return result
        end

        -- Pushes the pane's edits into the session as one Add or Replace command.
        -- @return boolean|nil  True when there was nothing to push or the command succeeded; nil after showing why (not
        --   portable, or rejected by the core), or when the card is no longer alive or the edit is read-only.
        local function syncField()
            if not alive() then
                return
            end
            if active.readOnly then
                return
            end
            if model.missingOperand and next(node) == nil then
                return true
            end
            if addon:UnsavedDataEqual(node, fieldBaseline) then
                return true
            end

            local portable = addon.RotationData.CheckPortable(node)

            if not portable then
                self:Message("invalid-condition-data")
                return
            end

            local latest = at(active.working, model.fieldPath)
            local candidate = merge(latest, fieldBaseline, node)

            local ok, why = active.session:Command(
                model.missingOperand and "Add" or "Replace",
                model.fieldPath,
                candidate
            )

            if not ok then
                self:Message(why)
                return
            end

            fieldBaseline = clone(node)
            active.working = active.session:Snapshot()

            if not self.loading then
                self.status:SetText("")
                self.canvas:Reflow()
            end

            return true
        end

        -- The "top" object the condition's widgets talk to instead of the shell: it forwards to the shell only while
        -- the card is alive, so a callback from a released pane cannot reach the editor.
        local proxy = {}
        local resumeAllowed = false

        -- Answers a widget's user data query: "root" is the pane's private tree copy, everything else comes from the
        -- shell.
        -- @param key string  The user data key.
        -- @return any  The value.
        function proxy:GetUserData(key)
            if key == "root" then
                return fieldRoot
            end

            return shell:GetUserData(key)
        end

        -- Forwards a user data write to the shell while the card is alive.
        -- @param key string  The flag name.
        -- @param value any  The flag value.
        function proxy:SetUserData(key, value)
            if alive() then
                shell:SetUserData(key, value)
            end
        end

        -- Pushes the pane's pending edits into the session (the widgets call this after a change).
        function proxy:SetStatusText()
            syncField()
        end

        -- Forwards the shell callback registration (OnClose) while the card is alive.
        -- @param event string  The event name.
        -- @param callback function|nil  The handler.
        function proxy:SetCallback(event, callback)
            if alive() then
                shell:SetCallback(event, callback)
            end
        end

        -- Hides the editor window while the card is alive.
        function proxy:Hide()
            if alive() then
                shell:Hide()
            end
        end

        -- Shows the editor window again, only while the card is alive or a child window just handed control back.
        function proxy:Show()
            if alive() or (resumeAllowed and shell.active == active) then
                resumeAllowed = false
                shell:Show()
            end
        end

        local childProfile, childGlobal = addon.db.profile, addon.db.global

        -- Called when a child window (such as a nested editor) closes: re-renders the editor and shows it again.
        -- @return boolean  False when the edit, the saved-data tables or the target changed meanwhile; true when the
        --   editor resumed.
        proxy.rmResumeFromChild = function()
            if shell.active ~= active or addon.db.profile ~= childProfile or addon.db.global ~= childGlobal then
                return false
            end

            if active.targetValid then
                local ok, current = pcall(active.targetValid)

                if not ok or current ~= true then
                    return false
                end
            end

            shell.closeOverride = nil
            shell:Render()
            shell:Show()
            return true
        end

        -- Called by widgets that need the layout refreshed: syncs the pane, then asks the shell to refresh.
        proxy.rmCompactRefresh = function()
            if syncField() then
                resumeAllowed = shell.closeOverride ~= nil and not window:IsShown()
                shell.rmCompactRefresh()
            end
        end

        card.proxy = proxy
        local pane = addon:CreateConditionGroup()
        card.pane = pane
        pane:SetLayout("List")
        pane:SetFullWidth(true)
        pane.frame:SetParent(card.fields)
        pane.frame:ClearAllPoints()
        pane.frame:SetPoint("TOPLEFT", 0, 0)
        pane:SetWidth(model.width - 58)
        pane.frame:Show()
        pane:SetUserData("top", proxy)
        pane.frame:ClearAllPoints()
        pane.frame:SetPoint("TOPLEFT", card.fields, "TOPLEFT", 0, 0)
        local oldLayout = pane.LayoutFinished

        -- Wraps the group's layout callback: records the measured pane height for the card and reflows the canvas when
        -- it changed.
        -- @param widget table  The group that finished laying out.
        -- @param width number  The laid out width.
        -- @param height number  The laid out height; ignored unless a non-negative number.
        pane.LayoutFinished = function(widget, width, height)
            if oldLayout then
                oldLayout(widget, width, height)
            end

            if alive() and type(height) == "number" and height >= 0 then
                local measured = math.min(5000, height + 12)

                if self.view.detailsHeights[model.key] ~= measured then
                    self.view.detailsHeights[model.key] = measured

                    if not self.canvas.building then
                        self.canvas:Reflow()
                    end
                end
            end
        end

        -- Restores the group's layout callback and releases the group when the card is released.
        card.releaseFields = function()
            pane.LayoutFinished = oldLayout
            addon:ReleaseConditionWidget(pane)
        end

        local definition = addon.conditionDefinitions[node.type]

        -- Builds the condition's widgets (custom code may run here, so it goes through Diagnostics below), guards their
        -- callbacks with `alive`, and disables them all in a read-only edit.
        local function build()
            if definition then
                addon:widgetCondition(pane, active.spec, node)
                addon:configure_frame(pane)

                -- Wraps every widget callback so it runs only while the card is alive, and reports pending input
                -- changes to the history buttons.
                -- @param widget table  A condition widget; its children are wrapped recursively.
                local function bindPending(widget)
                    local callbacks = {}

                    for event, callback in pairs(widget.events or widget.callbacks or {}) do
                        callbacks[event] = callback
                    end

                    for event, callback in pairs(callbacks) do
                        if type(callback) == 'function' then
                            widget:SetCallback(event, function(...)
                                if alive() then
                                    return callback(...)
                                end
                            end)
                        end
                    end

                    if widget.CommitPending then
                        widget:SetCallback('OnPendingChanged', function()
                            if alive() then
                                shell:UpdateHistoryButtons()
                            end
                        end)
                    end

                    for _, child in ipairs(widget.children or {}) do
                        bindPending(child)
                    end
                end

                bindPending(pane)

                if active.readOnly then
                    -- Disables a widget and all its children.
                    -- @param widget table  A condition widget.
                    local function disable(widget)
                        if widget.SetDisabled then
                            widget:SetDisabled(true)
                        end

                        for _, child in ipairs(widget.children or {}) do
                            disable(child)
                        end
                    end

                    disable(pane)
                end
            end
        end

        local ok

        if addon.Diagnostics then
            ok = addon.Diagnostics:Call({
                module = "condition-editor",
                operation = "fields",
                customCode = definition and definition.customCode == true,
            }, build)
        else
            ok = pcall(build)
        end

        self.loading = false

        if not ok then
            self.status:SetText(L["The condition editor could not display these fields. Use /rm errors for details."])
        else
            syncField()
        end
    end

    -- Redraws every card.
    function shell:Render()
        self.canvas:Render()
    end

    -- Runs one edit command on the session after syncing pending input, then reselects the affected paths, expands new
    -- cards that fail validation and lays out again.
    -- @param name string  The command (Add, Replace, Remove, Move, Insert, Duplicate, SetGroupType, ...).
    -- @param path table|table[]  The condition path the command acts on (a list of paths for the selection commands).
    -- @param value any  The command argument (a node, a group type, a direction, ...).
    -- @return boolean|nil  True on success; nil when no edit is open or the command failed (the reason is shown and the
    --   tree is left as it was).
    function shell:Command(name, path, value)
        if not self.active or not self:SyncWorking() then
            return
        end

        local ok, result = self.active.session:Command(name, path, value)

        if not ok then
            self:Message(result)
            return
        end

        self.active.working = self.active.session:Snapshot()
        local paths

        if type(result) == "table" then
            paths = result
        elseif name == "Remove" then
            paths = { parentPath(path) }
        elseif name == "Move" then
            local moved = copyPath(path)
            moved[#moved] = moved[#moved] + value
            paths = { moved }
        else
            paths = { copyPath(path) }
        end

        local scene = self:Scene()

        if not scene then
            return
        end

        for index, selected in ipairs(paths) do
            local projected = scene.commandPathsByKey[pathKey(selected)]

            if projected then
                paths[index] = copyPath(projected)
            end
        end

        self.view.selection = {}

        for _, selected in ipairs(paths) do
            self.view.selection[pathKey(selected)] = true
        end

        if name == "Insert" then
            for _, selected in ipairs(paths) do
                self.view.expanded[pathKey(selected)] = true
            end
        end

        if name == "Replace" or name == "Add" or name == "AddSibling" or name == "Insert" or name == "Duplicate" then
            local added = paths

            if name == "Add" then
                local node = at(self.active.working, path)

                if node and (node.type == "AND" or node.type == "OR") then
                    local child = copyPath(path)
                    child[#child + 1] = 'value'
                    child[#child + 1] = #node.value
                    added = { child }
                end
            end

            if not self:ExpandInvalid(added) then
                return
            end
        end

        self.active.selected = paths[1] or {}
        self.status:SetText("")
        self:Layout()
        return true
    end

    -- Runs a command on the currently selected cards; does nothing with an empty selection.
    -- @param name string  The command name.
    -- @param value any  The command argument.
    -- @return boolean|nil  Whatever Command returns; nil with an empty selection.
    function shell:SelectedCommand(name, value)
        local paths = self.canvas:Selection()

        if #paths == 0 then
            return
        end

        return self:Command(name, paths, value)
    end

    -- Ends the open edit.
    -- @param applied boolean  True when the session was committed; false cancels it.
    --
    -- The caller's callback runs last, under Diagnostics, and only if the target still exists and the settings pane
    -- that opened the edit is still the current one, so a late close cannot write into a different rotation.
    function shell:Finish(applied)
        local active = self.active

        if not active then
            return
        end

        self.active = nil
        self.closeOverride = nil
        self.canvas:Release()
        self.userdata = {}
        self.view = nil

        if self.openPicker then
            self.openPicker:Release()
            self.openPicker = nil
        end

        if not applied then
            active.session:Cancel()
        end

        -- After an apply, re-evaluates auto-switching (a switch condition may have changed), then tells the opener.
        local function notify()
            if applied and not active.persistentOwner then
                addon:UpdateAutoSwitch()
                addon:SwitchRotation()
            end

            local available = true

            if active.targetValid then
                local ok, exists = pcall(active.targetValid)
                available = ok and exists == true
            end

            if
                available
                and active.callback
                and (active.persistentOwner or active.generation == addon.configPaneGeneration)
            then
                active.callback(applied)
            end
        end

        if addon.Diagnostics then
            addon.Diagnostics:Call({ module = "condition-editor", operation = "close" }, notify)
        else
            pcall(notify)
        end
    end

    shell.canvas = addon:CreateConditionCanvas(window, shell)

    -- Creates a toolbar button (expand and collapse get an icon) and records it in shell.tools unless it is a footer
    -- button.
    -- @param label string  The button text.
    -- @param width number  The button width.
    -- @param callback function  The OnClick handler.
    -- @param footer boolean|nil  True for a footer button, which is not added to shell.tools.
    -- @return Button  The new button.
    local function button(label, width, callback, footer)
        local icon = label == L['Expand all'] and 'expand-all' or label == L['Collapse all'] and 'collapse-all'

        local control = icon and addon:CreateWorkbenchLabeledIconButton(window, icon, label, width + 16)
            or addon:CreateWorkbenchButton(window, label, width)

        addon:SetUIScript(control, "OnClick", callback)

        if not footer then
            shell.tools[#shell.tools + 1] = control
        end

        return control
    end

    -- Undo or Redo after syncing pending input, then reselects the root and lays out again.
    -- @param direction string  The session method to call: "Undo" or "Redo".
    local function history(direction)
        if not shell.active or not shell:SyncWorking() then
            return
        end

        local ok, why = shell.active.session[direction](shell.active.session)

        if not ok then
            shell:Message(why)
            return
        end

        shell.active.working = shell.active.session:Snapshot()
        shell.active.selected = {}
        shell.view.selection = { [""] = true }
        shell.status:SetText("")
        shell:Layout()
    end

    shell.undo = addon:CreateWorkbenchHistoryButton(window, "undo", L["Undo"])

    addon:SetUIScript(shell.undo, "OnClick", function()
        history("Undo")
    end)

    shell.tools[#shell.tools + 1] = shell.undo
    shell.redo = addon:CreateWorkbenchHistoryButton(window, "redo", L["Redo"])

    addon:SetUIScript(shell.redo, "OnClick", function()
        history("Redo")
    end)

    shell.tools[#shell.tools + 1] = shell.redo
    shell.palette = {}

    for _, entry in ipairs({
        { "condition", L["Add condition"], {} },
        { "group", L["Add group"], { type = "AND", value = {} } },
    }) do
        local key, label, node = entry[1], entry[2], entry[3]

        local control = addon:CreateWorkbenchLabeledIconButton(
            window,
            key == 'group' and 'group-add' or 'plus',
            label,
            key == 'group' and 110 or 134
        )

        shell.palette[key] = control
        control:RegisterForDrag("LeftButton")
        control.tooltip = L["Click to append; drag into a gap to insert."]

        addon:SetUIScript(control, "OnClick", function()
            if shell.active then
                local root = shell.active.working
                local destination = { path = {} }

                if next(root) ~= nil and root.type ~= "AND" and root.type ~= "OR" then
                    destination.relation = "after"
                end

                shell:Command("Insert", destination, node)
            end
        end)

        addon:BindWorkbenchDragSource(
            control,
            function()
                shell.canvas:StartInsert(node, control)
            end,
            function()
                shell.canvas:EndDrag()
            end
        )
    end

    -- Expand all or Collapse all: resets the fold state of every card. Expanding also reveals hidden children.
    -- @param expanded boolean  True for Expand all, false for Collapse all.
    local function expandAll(expanded)
        if not shell.active or not shell:SyncWorking() then
            return
        end

        shell.view.collapsed = {}
        shell.view.expanded = {}
        shell.view.cardStates = {}
        shell.view.help = {}

        if expanded then
            shell.view.hiddenChildren = {}
        end

        for _, row in ipairs(shell.active.session:Rows(4096)) do
            local key = pathKey(row.path)
            shell.view.expanded[key] = false
            shell.view.cardStates[key] = expanded and 'normal' or 'compact'
        end

        shell:Render()
    end

    shell.collapseAll = button(L["Collapse all"], 94, function()
        expandAll(false)
    end)

    shell.expandAll = button(L["Expand all"], 94, function()
        expandAll(true)
    end)

    local separator = CreateFrame("Frame", nil, window)
    separator:SetSize(10, 20)
    local divider = separator:CreateTexture(nil, "ARTWORK")
    divider:SetSize(1, 14)
    divider:SetPoint("CENTER")
    divider:SetColorTexture(.4, .4, .4, .6)
    separator:Hide()
    shell.dragHint = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    shell.dragHint:SetWidth(100)
    shell.dragHint:SetText("")
    shell.dragHint:Hide()
    shell.description = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    shell.description:SetPoint("BOTTOMLEFT", 16, 34)
    shell.description:SetJustifyH("LEFT")
    shell.description:SetWordWrap(true)

    shell.copyExpression = button(
        L["Copy condition description"],
        140,
        function()
            if addon.ShowConditionText then
                addon:ShowConditionText(shell.fullDescription)
            end
        end,
        true
    )

    shell.copyExpression:SetWidth(math.max(140, shell.copyExpression:GetFontString():GetStringWidth() + 20))
    shell.copyExpression:Hide()
    addon:InstallSpellHyperlinks(window)

    -- Sizes the canvas to what is left of the window under the toolbar and above the description footer.
    function shell:LayoutBody()
        if not self.bodyTop then
            return
        end

        self.canvas.frame:SetSize(math.max(1, window:GetWidth() - 52), math.max(
            40,
            window:GetHeight() - self.bodyTop - (self.footerHeight or 28) - 58
        ))

        self.canvas:LayoutScrollBar()
    end

    -- Rewrites the prose description of the whole condition in the footer.
    --
    -- A description taller than 35 percent of the window is cut to fit and the Copy button appears so the full text can
    -- still be read; the status line and the canvas move to make room.
    function shell:UpdateDescription()
        if not self.active then
            return
        end

        self.fullDescription = addon:DescribeCondition(self.active.working, self.active.spec)

        if self.description.SetMaxLines then
            self.description:SetMaxLines(0)
        end

        self.description:SetText(self.fullDescription)
        self.description:SetWidth(math.max(1, window:GetWidth() - 376))
        local natural = self.description.GetStringHeight and self.description:GetStringHeight() or 28
        local maximum = math.max(28, math.floor(window:GetHeight() * .35))
        local height = math.min(maximum, math.max(14, natural))
        self.description:SetHeight(height)
        local extra = 0

        if natural > maximum then
            if self.description.SetMaxLines then
                self.description:SetMaxLines(math.max(1, math.floor(height / 14)))
            end

            self.copyExpression:ClearAllPoints()
            self.copyExpression:SetPoint("BOTTOMLEFT", 16, height + 38)
            self.copyExpression:Show()
            extra = 24
        else
            self.copyExpression:Hide()
        end

        self.status:ClearAllPoints()
        self.status:SetPoint("BOTTOMLEFT", 16, height + extra + 40)
        self.footerHeight = height + extra + ((self.status:GetText() or "") ~= "" and 20 or 0)
        self:LayoutBody()
    end

    shell.groupAll = button(
        L["Group as All"],
        100,
        function()
            shell:SelectedCommand("GroupSelection", "AND")
        end,
        true
    )

    shell.groupAny = button(
        L["Group as Any"],
        100,
        function()
            shell:SelectedCommand("GroupSelection", "OR")
        end,
        true
    )

    shell.selectionLabel = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    -- The same selection-wide actions as the rotation editor, one undo step each.
    shell.selectionActions = {}

    for _, entry in ipairs({
        {
            "duplicate",
            "copy",
            L["Duplicate selected cards"],
            function()
                shell:SelectedCommand("DuplicateSelection")
            end,
        },
        {
            "enable",
            "check",
            L["Enable selected cards"],
            function()
                shell:SelectedCommand("SetSelectionDisabled", false)
            end,
        },
        {
            "disable",
            "minus",
            L["Disable selected cards"],
            function()
                shell:SelectedCommand("SetSelectionDisabled", true)
            end,
        },
        {
            "remove",
            "trash",
            L["Delete selected cards"],
            function()
                shell:SelectedCommand("RemoveSelection")
            end,
        },
    }) do
        local control = addon:CreateWorkbenchIconButton(window, entry[2], entry[3])
        control:SetSize(20, 20)
        control:Hide()

        if entry[1] == "remove" then
            control.icon:SetVertexColor(1, .3, .3, 1)
        end

        addon:SetUIScript(control, "OnClick", function()
            if shell.active then
                entry[4]()
            end
        end)

        shell.selectionActions[#shell.selectionActions + 1] = control
        shell["selection_" .. entry[1]] = control
    end

    shell.apply = button(
        L["Apply"],
        100,
        function()
            if not shell.active or not shell:SyncWorking() then
                return
            end

            local ok, why = shell.active.session:Apply()

            if not ok then
                shell:Message(why)
                return
            end

            shell:Finish(true)
            window:Hide()
        end,
        true
    )

    shell.apply:SetPoint("BOTTOMRIGHT", -126, 34)

    shell.cancel = button(
        L["Cancel"],
        100,
        function()
            shell.closeOverride = nil
            shell:Finish(false)
            window:Hide()
        end,
        true
    )

    shell.cancel:SetPoint("BOTTOMRIGHT", -16, 34)
    local close = addon:CreateWorkbenchIconButton(window, "close", L["Close"])
    shell.close = close
    close:SetPoint("TOPRIGHT", -5, -5)

    addon:SetUIScript(close, "OnClick", function()
        shell.cancel:Click()
    end)

    shell.help = addon:CreateWorkbenchHelpButton(window, L["Help"])
    shell.help:SetPoint("TOPRIGHT", -31, -5)
    shell.help:SetSize(20, 20)
    shell.help.icon:SetSize(16, 16)

    addon:SetUIScript(shell.help, "OnClick", function()
        if addon.ShowWorkbenchHelp then
            addon:ShowWorkbenchHelp(
                L['Condition editor'],
                addon:WorkbenchInteractionHelp('condition'),
                shell.chrome.author:GetText()
            )
        end
    end)

    addon:SetUIScript(window, "OnMouseUp", function(_, button)
        if button == "RightButton" then
            shell.cancel:Click()
        end
    end)

    local grip = CreateFrame("Button", nil, window)
    grip:SetSize(20, 20)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    local texture = grip:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints(grip)
    texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")

    addon:SetUIScript(grip, "OnMouseDown", function(_, key)
        if key == "LeftButton" then
            window:StartSizing("BOTTOMRIGHT")
        end
    end)

    addon:SetUIScript(grip, "OnMouseUp", function()
        window:StopMovingOrSizing()
    end)

    -- Places the toolbar (wrapping to new rows when narrow), the Add palette, the multi-selection strip and the canvas,
    -- then redraws the cards and the description when an edit is open. Runs on every resize.
    function shell:Layout()
        local width = window:GetWidth()
        self.chrome:LayoutTitle()
        local x, y = 16, -34

        for _, control in ipairs(self.tools) do
            if x + control:GetWidth() > width - 272 then
                x = 16
                y = y - 24
            end

            control:ClearAllPoints()
            control:SetPoint("TOPLEFT", window, "TOPLEFT", x, y)
            x = x + control:GetWidth() + 4
        end

        self.palette.group:ClearAllPoints()
        self.palette.group:SetPoint('TOPRIGHT', window, 'TOPRIGHT', -16, -34)
        self.palette.condition:ClearAllPoints()
        self.palette.condition:SetPoint('TOPRIGHT', window, 'TOPRIGHT', -130, -34)
        self.dragHint:ClearAllPoints()
        self.dragHint:SetPoint('TOPLEFT', window, 'TOPLEFT', x, y + 4)
        self.dragHint:Hide()
        local top = -y + 28
        local count = #self.canvas:Selection()
        self.selectionStrip = count > 1

        if self.selectionStrip then
            top = top + 30
            self.selectionLabel:SetText(string.format(L["%d selected"], count))
            self.selectionLabel:ClearAllPoints()
            self.selectionLabel:SetPoint("TOPLEFT", 16, -top + 26)
            self.selectionLabel:Show()
            self.groupAll:ClearAllPoints()
            self.groupAll:SetPoint("TOPLEFT", 140, -top + 34)
            self.groupAll:Show()
            self.groupAny:ClearAllPoints()
            self.groupAny:SetPoint("TOPLEFT", 244, -top + 34)
            self.groupAny:Show()

            for i, control in ipairs(self.selectionActions) do
                control:ClearAllPoints()
                control:SetPoint("TOPLEFT", 352 + (i - 1) * 22, -top + 32)
                control:Show()

                if self.active and self.active.readOnly then
                    control:Disable()
                else
                    control:Enable()
                end
            end
        else
            self.selectionLabel:Hide()
            self.groupAll:Hide()
            self.groupAny:Hide()

            for _, control in ipairs(self.selectionActions) do
                control:Hide()
            end
        end

        self.canvas.frame:ClearAllPoints()
        self.canvas.frame:SetPoint("TOPLEFT", 16, -top)
        self.bodyTop = top
        self:LayoutBody()
        self.status:SetWidth(math.max(1, width - 392))

        if self.active then
            self.canvas:Render()
            self:UpdateDescription()
        end
    end

    -- Called by a card's proxy when a nested editor finished: clears the close override, syncs and redraws.
    shell.rmCompactRefresh = function()
        shell.closeOverride = nil

        if shell:SyncWorking() then
            shell.active.working = shell.active.session:Snapshot()
            shell:Render()
        end
    end

    addon:SetUIScript(window, "OnSizeChanged", function()
        shell:Layout()
    end)

    -- Any hide ends the edit: a nested editor's close override runs instead when one is installed, otherwise the
    -- edit is cancelled. Apply and Cancel call Finish themselves first, which makes this a no-op for them.
    addon:SetUIScript(window, "OnHide", function()
        shell.canvas:CancelDrag()

        if shell.closeOverride then
            shell.closeOverride(shell)
        else
            shell:Finish(false)
        end
    end)

    addon:InstallConditionChangeReview(shell)
    addon.HideOnEscape(shell)
    shell:Layout()
    return shell
end

-- ============================================================================
-- Opening the editor
-- ============================================================================

-- Opens the condition editor on `value` (a condition tree) for class spec `spec`. Only one condition can be open at a
-- time: asking again brings the open one forward and tells the user to apply or cancel it first.
-- @param index number|nil  The step number shown in the title; 0 or nil for a switch condition.
-- @param spec string  The class spec the condition belongs to.
-- @param value table  The condition tree to edit; the session works on a copy.
-- @param callback function  Called as callback(applied) after the edit ends.
-- @param targetValid function|nil  Returns true while the rotation or step being edited still exists.
-- @param options table|nil  May set readOnly, persistentOwner, announcement, announcementTarget, savedValue, title,
--   contextLabel and rotationName.
-- @return table|nil  The shell; nil when the edit session could not be created.
-- @return string|nil  The reason code when the first value is nil.
function addon:ShowConditionEditor(index, spec, value, callback, targetValid, options)
    options = options or {}
    local shell = self.compactConditionEditor

    if shell and shell.active then
        -- It may be hidden behind the window that was clicked since: bring it forward again.
        shell:Show()
        addon:OpenPopup(shell, addon.configWindow)
        shell.status:SetText(L["Apply or cancel the open condition before editing another."])
        return shell
    end

    local session, why = self:NewConditionEditSession(spec, value, targetValid, options)

    if not session then
        return nil, why
    end

    if not shell then
        shell = createShell()
        self.compactConditionEditor = shell
    end

    shell.active = {
        session = session,
        working = session:Snapshot(),
        selected = {},
        spec = spec,
        index = index,
        callback = callback,
        generation = self.configPaneGeneration,
        targetValid = targetValid,
        profile = self.db.profile,
        global = self.db.global,
        char = self.db.char,
        comparisonBaseline = options.savedValue and addon.RotationData.CopyData(options.savedValue),
        readOnly = options.readOnly == true,
        persistentOwner = options.persistentOwner == true,
    }

    shell.view = {
        selection = { [""] = true },
        collapsed = {},
        cardStates = {},
        hiddenChildren = {},
        expanded = {},
        detailsHeights = {},
        help = {},
    }

    shell.userdata = {
        funcs = { print = function() return "" end },
        announcement = options.announcement == true,
        announcementTarget = options.announcementTarget == true,
    }

    local heading = type(options.title) == "string" and addon:PlainWorkbenchName(options.title)

    shell.chrome:SetContext(
        heading and heading:find("%S") and heading
            or index and index > 0 and string.format(L["Edit Condition #%d"], index)
            or L["Edit Condition"],
        options.contextLabel or L["Condition"],
        options.rotationName
    )

    shell.title:Show()
    shell.status:SetText("")
    shell.showHelp = false
    shell.closeOverride = nil

    -- Enables or disables a control according to `value`.
    -- @param control Button  The control to change.
    -- @param value boolean|nil  True to enable, otherwise disable.
    local function enabled(control, value)
        if value then
            control:Enable()
        else
            control:Disable()
        end
    end

    enabled(shell.apply, not shell.active.readOnly)
    enabled(shell.groupAll, not shell.active.readOnly)
    enabled(shell.groupAny, not shell.active.readOnly)

    for _, control in pairs(shell.palette) do
        enabled(control, not shell.active.readOnly)
    end

    shell.cancel:SetText(shell.active.readOnly and L["Close"] or L["Cancel"])

    if shell.active.readOnly then
        shell.status:SetText(L["Read-only condition"])
    end

    if not shell:ExpandInvalid({ {} }) then
        return shell
    end

    shell:Show()
    addon:OpenPopup(shell, addon.configWindow)
    shell:Layout()
    shell:Render()
    return shell
end
