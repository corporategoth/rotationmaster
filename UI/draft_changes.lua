local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

---@param value any
local function text(value)
    if value == nil then return L['None'] end
    if type(value) == 'table' then return L['Fields'] end
    return tostring(value)
end

---@param value any
local function bounded(value)
    value = tostring(value or '')
    return #value > 8192 and value:sub(1, 8192) .. '…' or value
end

local function at(root, path)
    for _, key in ipairs(path) do
        root = type(root) == 'table' and root[key] or nil
    end

    return root
end

function addon:BuildDraftChangeRows(kind, before, after, showSame, spec)
    if kind ~= 'rotation' and kind ~= 'condition' then
        return self:CollectionComparisonRows('profile', { profile = before }, { profile = after }, showSame)
    end

    local rows, total = {}, 0

    local function add(label, a, b, format, icon)
        local changed = not self:UnsavedDataEqual(a, b)
        if changed then total = total + 1 end

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

    local function action(step)
        if step.type == 'branch' then
            return L['Condition']
        elseif step.type == 'stop' then
            return L['Stop']
        elseif step.type == 'assisted' then
            return L["Blizzard's suggestion"]
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

    local function format(value)
        local step = value.step

        local parts = {
            action(step),
            L['Type'] .. ': ' .. ((self.actions or {})[step.type] or step.type or L['None']),
            L['Position'] .. ': ' .. value.index,
            self:DescribeCondition(step.conditions or {}, spec),
        }

        if step.name and step.name ~= '' then table.insert(parts, 1, step.name) end
        if step.disabled then parts[#parts + 1] = L['Disabled'] end
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

            if #path > 0 then parts[#parts + 1] = table.concat(path, ' / ') end
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

function addon:ShowWorkbenchDraftChanges(owner, kind, before, after, valid, spec, pending)
    local adapter = owner.draftComparisonOwner or { frame = owner.frame, generation = 0 }
    owner.draftComparisonOwner = adapter
    adapter.generation = adapter.generation + 1
    adapter.cleanups = {}

    function adapter:Valid(token)
        return token == self.generation and valid()
    end

    local options = {
        title = L['View Changes'],
        leftHeading = L['Saved'],
        rightHeading = L['Unsaved'],
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

function addon:CreateViewChangesButton(parent, apply, callback)
    local button = self:CreateWorkbenchButton(parent, L['View Changes'], 116)
    button:SetPoint('RIGHT', apply, 'LEFT', -6, 0)
    self:SetUIScript(button, 'OnClick', callback)
    button:Disable()
    return button
end

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
