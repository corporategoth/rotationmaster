-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Draft changes: the "View Changes" comparison between a saved document and its unsaved draft (a rotation, a condition
-- or a whole profile-shaped table), plus the button that opens it and the collection of half-typed input that has not
-- been committed to the draft yet. It builds comparison rows and hands them to UI/collection_compare.lua; it never
-- edits either side.
-- Loaded from RotationMaster.toc right after UI/collection_compare.lua and before UI/draft_change_controls.lua, which
-- wires the button into every editor pane. Rows are bounded in length so a huge saved value cannot freeze the window.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- ============================================================================
-- Value helpers
-- ============================================================================

-- Short display text for a pending-input value: "None" for nil, "Fields" for a table, otherwise tostring.
-- @param value any  The value to show.
-- @return string  The display text.
---@param value any
local function text(value)
    if value == nil then
        return L['None']
    end
    if type(value) == 'table' then
        return L['Fields']
    end

    return tostring(value)
end

-- Caps a displayed value at 8192 characters (adding an ellipsis) so one giant string cannot make a row unmeasurable.
-- @param value any  The value to show; nil reads as an empty string.
-- @return string  The text, at most 8192 characters plus the ellipsis.
---@param value any
local function bounded(value)
    value = tostring(value or '')
    return #value > 8192 and value:sub(1, 8192) .. '…' or value
end

-- Follows `path` (a list of keys) down from `root`.
-- @param root any  The tree to start from.
-- @param path table  The keys to follow.
-- @return any  The value at the end of the path; nil as soon as a level is not a table or the key is absent.
local function at(root, path)
    for _, key in ipairs(path) do
        root = type(root) == 'table' and root[key] or nil
    end

    return root
end

-- ============================================================================
-- Building the rows
-- ============================================================================

-- Builds the comparison rows from the saved `before` and the draft `after`. With `showSame` the unchanged rows are
-- listed too.
-- @param kind string  'rotation', 'condition', or anything else for a profile-shaped table.
-- @param before table  The saved document.
-- @param after table  The draft document.
-- @param showSame boolean|nil  True lists unchanged rows too.
-- @param spec string|nil  The class spec used to describe conditions in prose.
-- @return table[]  Rows shaped { label, left, right, changed, leftIcon, rightIcon }.
-- @return number  The number of changed rows.
function addon:BuildDraftChangeRows(kind, before, after, showSame, spec)
    if kind ~= 'rotation' and kind ~= 'condition' then
        return self:CollectionComparisonRows('profile', { profile = before }, { profile = after }, showSame)
    end

    local rows, total = {}, 0

    -- Appends one row for a pair of values when they differ (or showSame is set) and counts it if it changed.
    -- @param label string  The row label.
    -- @param a any  The saved value.
    -- @param b any  The draft value.
    -- @param format function  Turns a value into its text.
    -- @param icon function|nil  Returns a texture id for either side.
    local function add(label, a, b, format, icon)
        local changed = not self:UnsavedDataEqual(a, b)

        if changed then
            total = total + 1
        end
        if changed or showSame then
            rows[#rows + 1] = {
                label = label,
                left = bounded(a == nil and L['None'] or format(a)),
                right = bounded(b == nil and L['None'] or format(b)),
                changed = changed,
                leftIcon = icon and icon(a),
                rightIcon = icon and icon(b),
            }
        end
    end

    -- When two conditions differ but read the same in prose (the description leaves some declared value out), lists the
    -- raw field differences under `label` so no changed value is hidden.
    -- @param label string  The row label prefix.
    -- @param a table|nil  The saved condition.
    -- @param b table|nil  The draft condition.
    local function omittedConditionFields(label, a, b)
        if self:UnsavedDataEqual(a, b) or not a or not b or self:DescribeCondition(a, spec) ~= self:DescribeCondition(
            b,
            spec
        ) then
            return
        end

        local details, count = self:CollectionComparisonRows('profile', { profile = a }, { profile = b }, false)

        for _, row in ipairs(details) do
            row.label = label .. ' / ' .. row.label
            rows[#rows + 1] = row
        end

        total = total + count
    end

    if kind == 'condition' then
        local maps, keys, seen = {}, {}, {}
        local complete = true

        for side, root in ipairs({ before, after }) do
            maps[side] = {}
            local draft = self.RotationData.NewConditionDraft(root, self.conditionDefinitions)
            local treeRows, all

            if draft then
                treeRows, all = draft:Rows(512)
            else
                treeRows, all = { { path = {} } }, true
            end

            complete = complete and all

            for _, row in ipairs(treeRows) do
                local key = table.concat(row.path, '/')
                maps[side][key] = at(root, row.path)

                if not seen[key] then
                    seen[key] = true
                    keys[#keys + 1] = key
                end
            end
        end

        for _, key in ipairs(keys) do
            local a, b = maps[1][key], maps[2][key]
            local node = b or a
            local definition = node and (self.conditionDefinitions or {})[node.type]
            local label = node and node.name or definition and definition.description or L['Condition']
            add(label, a, b, function(v) return self:DescribeCondition(v, spec) end)
            -- Custom prose can omit declared values. Keep every changed value
            -- reviewable even when both human-readable summaries are identical.
            omittedConditionFields(label, a, b)
        end

        if not complete then
            rows[#rows + 1] = {
                label = L['Comparison limit'],
                left = L['Showing the first 512 conditions per side.'],
                right = L['Showing the first 512 conditions per side.'],
                changed = false,
            }
        end

        return rows, total
    end

    local a, b = self.RotationData.CopyData(before), self.RotationData.CopyData(after)

    for _, root in ipairs({ a, b }) do
        root.rotation = nil
        root.cooldowns = nil
        root.switch = nil
    end

    rows, total = self:CollectionComparisonRows('profile', { profile = a }, { profile = b }, showSame)

    add(L['Switch condition'], before.switch or {}, after.switch or {}, function(v)
        return self:DescribeCondition(v, spec)
    end)

    omittedConditionFields(L['Switch condition'], before.switch or {}, after.switch or {})
    local maps, keys, seen = {}, {}, {}

    for side, body in ipairs({ before, after }) do
        maps[side] = {}
        local index = self.RotationData.IndexRotationSteps(body, { allowMissingIds = true })

        for _, row in ipairs(index and index.rows or {}) do
            local key = row.step.id or table.concat(row.path, '/')
            maps[side][key] = { step = row.step, path = row.path, section = row.section, index = row.index }

            if not seen[key] then
                seen[key] = true
                keys[#keys + 1] = key
            end
        end
    end

    -- Display name of what a step does: its spell or item names, or the fixed label for a branch, stop or assisted
    -- step.
    -- @param step table  A rotation step.
    -- @return string  The name.
    local function action(step)
        if step.type == 'branch' then
            return L['Condition']
        elseif step.type == 'stop' then
            return L['Stop']
        elseif step.type == 'assisted' then
            return L["Blizzard's suggestion"]
        elseif step.type == 'mark' then
            return self:DescribeMarkStep(step)
        end

        if step.type == 'spell' or step.type == 'pet' or step.type == 'any' then
            return self:PlainWorkbenchName(self:SpellLabel(step.action))
        end

        if step.type == 'item' then
            local provider = self:GetReferenceProvider('item')
            local names = {}

            for _, value in ipairs(type(step.action) == 'table' and step.action or { step.action }) do
                names[#names + 1] = (provider.name(tonumber(value) or provider.resolve(value))
                    or L['Item data loading'])
                    .. ' ('
                    .. tostring(value)
                    .. ')'
            end

            return table.concat(names, '\n')
        end

        return L['Item']
    end

    -- Spell icon texture for a step record.
    -- @param value table|nil  A step record { step, path, section, index }.
    -- @return number|string|nil  The icon; nil for any step that is not a single known spell id.
    local function icon(value)
        local step = value and value.step

        if
            step
            and (step.type == 'spell' or step.type == 'pet' or step.type == 'any')
            and type(step.action) == 'number'
        then
            local info = self.Platform:GetSpellInfo(step.action)
            return info and info.iconID
        end
    end

    -- Multi-line summary of a step record: name, action, type, position, conditions, any remaining fields and the
    -- branch targets. Two summaries differ exactly when something visible in the step changed.
    -- @param value table  A step record { step, path, section, index }.
    -- @return string  The summary.
    local function format(value)
        local step = value.step

        local parts = {
            action(step),
            L['Type'] .. ': ' .. ((self.actions or {})[step.type] or step.type or L['None']),
            L['Position'] .. ': ' .. value.index,
            self:DescribeCondition(step.conditions or {}, spec),
        }

        if step.name and step.name ~= '' then
            table.insert(parts, 1, step.name)
        end

        if step.disabled then
            parts[#parts + 1] = L['Disabled']
        end

        local fields = self.RotationData.CopyData(step)

        for _, key in ipairs({'id', 'type', 'action', 'name', 'conditions', 'disabled', 'onTrue', 'onFalse', 'mode'}) do
            fields[key] = nil
        end

        if fields.effect then
            fields.effect = (self.db.global.effects or {})[fields.effect] and self.db.global.effects[fields.effect].name
                or fields.effect
        end

        local extra = self:CollectionComparisonRows('profile', { profile = fields }, { profile = {} }, true)

        for _, field in ipairs(extra) do
            parts[#parts + 1] = field.label .. ': ' .. field.left
        end

        if step.type == 'branch' then
            parts[#parts + 1] = (step.mode == 'true' and L['Always true']
                or step.mode == 'false' and L['Always false']
                or L['Evaluate condition'])

            parts[#parts + 1] = L['False']
                .. ': '
                .. #(step.onFalse or {})
                .. '  '
                .. L['True']
                .. ': '
                .. #(step.onTrue or {})
        end

        if #value.path > 2 then
            local path = {}

            for _, part in ipairs(value.path) do
                if part == 'onTrue' then
                    path[#path + 1] = L['True']
                elseif part == 'onFalse' then
                    path[#path + 1] = L['False']
                end
            end

            if #path > 0 then
                parts[#parts + 1] = table.concat(path, ' / ')
            end
        end

        return table.concat(parts, '\n')
    end

    for _, key in ipairs(keys) do
        local old, new = maps[1][key], maps[2][key]
        local row = new or old

        local label = (row.section == 'cooldowns' and L['Cooldown'] or L['Rotation'])
            .. ' · '
            .. (row.step.name or action(row.step))

        add(label, old, new, format, icon)

        if old and new then
            omittedConditionFields(
                label .. ' / ' .. L['Conditions'],
                old.step.conditions or {},
                new.step.conditions or {}
            )
        end
    end

    return rows, total
end

-- ============================================================================
-- The View Changes window and its button
-- ============================================================================

-- Opens the comparison window for `owner` between `before` and `after`. Each call bumps the adapter's generation so a
-- window opened for an older drawing stops reacting.
-- @param owner table  The editor that owns the window; the adapter is kept in owner.draftComparisonOwner.
-- @param kind string  'rotation', 'condition', or anything else for a profile-shaped table.
-- @param before table  The saved document.
-- @param after table  The draft document.
-- @param valid function  Returns false once the owning editor drawing is gone.
-- @param spec string|nil  The class spec used to describe conditions in prose.
-- @param pending table[]|nil  The list from PendingWidgetChanges, shown as extra rows.
-- @return table  What addon:ShowCollectionComparison returns (the window).
function addon:ShowWorkbenchDraftChanges(owner, kind, before, after, valid, spec, pending)
    local adapter = owner.draftComparisonOwner or { frame = owner.frame, generation = 0 }
    owner.draftComparisonOwner = adapter
    adapter.generation = adapter.generation + 1
    adapter.cleanups = {}

    -- True while `token` is the latest generation and the owner's drawing is still alive.
    -- @param token number  The generation the caller was opened for.
    -- @return boolean  True when the window may still react.
    function adapter:Valid(token)
        return token == self.generation and valid()
    end

    local options = {
        title = L['View Changes'],
        leftHeading = L['Saved'],
        rightHeading = L['Unsaved'],
        -- Row builder for the comparison window: the draft change rows followed by one row per pending input.
        -- @param first table  The saved document copy.
        -- @param second table  The draft document copy.
        -- @param showSame boolean|nil  True lists unchanged rows too.
        -- @return table[]  The rows.
        -- @return number  The number of changed rows.
        rows = function(first, second, showSame)
            local rows, count = addon:BuildDraftChangeRows(kind, first, second, showSame, spec)

            for _, row in ipairs(pending or {}) do
                rows[#rows + 1] = {
                    label = L['Pending input'] .. ': ' .. (row.label or L['Fields']),
                    left = bounded(text(row.before)),
                    right = bounded(text(row.after)),
                    changed = true,
                }

                count = count + 1
            end

            return rows, count
        end,
    }

    return self:ShowCollectionComparison(adapter, 'profile', before, after, options)
end

-- Creates the View Changes button left of the `apply` button; it starts disabled, and the editor enables it while a
-- draft differs from what is saved.
-- @param parent Frame  The parent frame.
-- @param apply Button  The Apply button the new button is placed beside.
-- @param callback function  The OnClick handler.
-- @return Button  The new button.
function addon:CreateViewChangesButton(parent, apply, callback)
    local button = self:CreateWorkbenchButton(parent, L['View Changes'], 116)
    button:SetPoint('RIGHT', apply, 'LEFT', -6, 0)
    self:SetUIScript(button, 'OnClick', callback)
    button:Disable()
    return button
end

-- ============================================================================
-- Pending input
-- ============================================================================

-- Walks a widget tree and collects every field with typed-but-uncommitted input as {label, before, after} records. A
-- custom widget with pending input that RM cannot read is reported as "Not inspected".
-- @param widget table  The root of the widget tree.
-- @param result table[]|nil  The list to append to; created when absent.
-- @return table[]  The list of { label, before, after } records.
function addon:PendingWidgetChanges(widget, result)
    result = result or {}

    if widget.IsPending and widget:IsPending() then
        local input = widget.editbox

        if input and type(widget.type) == 'string' and widget.type:find('^RM%-') then
            result[#result + 1] = {
                label = widget.label or L['Fields'],
                before = widget.value or widget.text or '',
                after = input:GetText(),
            }
        else
            result[#result + 1] = {
                label = L['Fields'],
                before = L['Not inspected'],
                after = L['Custom widget has pending input.'],
            }
        end
    end

    for _, child in ipairs(widget.children or {}) do
        self:PendingWidgetChanges(child, result)
    end

    return result
end
