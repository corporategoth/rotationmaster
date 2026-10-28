-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Detail fields of a rotation card in the rotation editor, and the staging of text typed into them. Text fields (name,
-- items, sound, magnification, offsets, color) are held as pending strings per step in `view.pendingFields` and become
-- one `PatchStep` command only when they flush (Enter, Apply or leaving), so a half-typed value never reaches the
-- workspace and invalid text stays red and blocks Apply. Choices, checkboxes and spell and item boxes commit
-- immediately through the same command. This file never writes saved rotations itself; it goes through the workspace
-- owner. Loaded from RotationMaster.toc after UI/rotation_canvas.lua; `addon:InstallRotationFieldDrafts(pane)` is
-- called by UI/rotation_editor.lua, and the cooldown effect rows come from UI/rotation_effect_fields.lua.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Reports whether this client has Blizzard's Assisted Combat API at all (the platform does not report `missing-api`), so
-- the step-type menu offers "Blizzard's suggestion" only where it can ever run.
-- @return boolean  true when the API exists (even if it currently reports itself unavailable); false on clients without it
--
-- A client whose platform cannot be asked is treated as having no API. An existing assisted step stays editable
-- regardless; the caller adds that case.
function addon:HasAssistedCombatAPI()
    local platform = self.Platform

    if type(platform) ~= 'table' or type(platform.GetAssistedAvailability) ~= 'function' then
        return false
    end

    local ok, availability = pcall(platform.GetAssistedAvailability, platform)

    return ok and type(availability) == 'table' and availability.reason ~= 'missing-api'
end

-- Parses pending text for a field key into a patch `{ set = {...}, unset = {...} }`, or returns nil when the text is
-- not valid for that key (a non-finite number, a magnification of 0 or less, a color that is not four 0..1 channels).
-- Empty text unsets the field. The nil result is what marks a field red and blocks Apply.
local function parsedText(key, value)
    local patch = { set = {}, unset = {} }

    -- Queues a field name to be cleared by the patch.
    local function unset(field)
        patch.unset[#patch.unset + 1] = field
    end

    -- Parses the text as a finite number, or returns nil/false.
    local function number()
        local n = tonumber(value)
        return n and n == n and n > -math.huge and n < math.huge and n
    end

    if key == 'name' then
        if value == '' then
            unset('name')
        else
            patch.set.name = value
        end
    elseif key == 'items' then
        local items = {}

        for item in value:gmatch('[^,]+') do
            item = item:match('^%s*(.-)%s*$')

            if item ~= '' then
                items[#items + 1] = tonumber(item) or item
            end
        end

        patch.set.action = items
    elseif key == 'sound' then
        if value == '' then
            unset('announce_sound')
        else
            patch.set.announce_sound = value
        end
    elseif key == 'magnification' or key == 'xoffs' or key == 'yoffs' then
        if value == '' then
            unset(key)
        else
            local n = number()

            if not n or key == 'magnification' and n <= 0 then
                return nil
            end

            patch.set[key] = n
        end
    elseif key == 'color' then
        if value == '' then
            unset('color')
        else
            local values = {}

            for part in (value .. ','):gmatch('(.-),') do
                local n = tonumber(part)

                if not n or n ~= n or n < 0 or n > 1 then
                    return nil
                end

                values[#values + 1] = n
            end

            if #values ~= 4 then
                return nil
            end

            patch.set.color = { r = values[1], g = values[2], b = values[3], a = values[4] }
        end
    else
        return nil
    end

    return patch
end

-- ============================================================================
-- Pending text on the editor pane
-- ============================================================================

-- Adds the pending-field methods to the rotation editor pane `pane` (called once when the pane is built).
function addon:InstallRotationFieldDrafts(pane)
    -- Returns the pending text for a step field, or `fallback` as a string when nothing is pending.
    function pane:FieldText(id, key, fallback)
        local fields = self.view.pendingFields or {}
        local record = fields[id] and fields[id][key]
        return record and record.text or tostring(fallback or '')
    end

    -- Records typed text for a step field, or forgets it when it equals the saved `baseline` again. Refreshes history
    -- and validation, and returns whether the text currently parses. Ignored while the pane is closed or read-only.
    function pane:StageField(id, key, value, baseline, label)
        if not self.active or self.workspace.readOnly then
            return
        end

        self.view.pendingFields = self.view.pendingFields or {}
        local fields = self.view.pendingFields
        fields[id] = fields[id] or {}

        if value == tostring(baseline or '') then
            fields[id][key] = nil
        else
            fields[id][key] = { text = value, label = label or key }
        end

        self:UpdateHistory()
        self:RefreshValidation()
        return parsedText(key, value) ~= nil
    end

    -- Returns the label of the first pending field of step `id` that does not parse, or nil.
    function pane:PendingFieldProblem(id)
        local fields = self.view.pendingFields or {}

        for key, record in pairs(fields[id] or {}) do
            if not parsedText(key, record.text) then
                return record.label
            end
        end
    end

    -- True when any step still in the rotation has pending text that does not parse (pending text of deleted steps is
    -- ignored).
    function pane:HasInvalidPendingFields()
        local tree = addon.RotationData.IndexRotationSteps(self.workspace:Snapshot())

        for id in pairs(self.view.pendingFields or {}) do
            if tree.byId[id] and self:PendingFieldProblem(id) then
                return true
            end
        end

        return false
    end

    -- Applies the parsable pending text to the review `snapshot` so the Apply review shows its effect, and appends an
    -- entry to `pending` for every field that does not parse.
    function pane:ReviewPendingFields(snapshot, pending)
        local tree = addon.RotationData.IndexRotationSteps(snapshot)

        for id, fields in pairs(self.view.pendingFields or {}) do
            local row = tree and tree.byId[id]

            if row then
                for key, record in pairs(fields) do
                    local patch = parsedText(key, record.text)

                    if patch then
                        for name, value in pairs(patch.set) do
                            row.step[name] = value
                        end

                        for _, name in ipairs(patch.unset) do
                            row.step[name] = nil
                        end
                    else
                        pending[#pending + 1] = {
                            label = (row.step.name or L['Action']) .. ' · ' .. record.label,
                            before = row.step[key],
                            after = record.text,
                        }
                    end
                end
            end
        end
    end

    -- True when any step still in the rotation has staged text.
    function pane:HasPendingFields()
        local tree = addon.RotationData.IndexRotationSteps(self.workspace:Snapshot())

        for id, fields in pairs(self.view.pendingFields or {}) do
            if tree.byId[id] and next(fields) then
                return true
            end
        end

        return false
    end

    -- Forgets all staged text without applying it.
    function pane:ClearPendingFields()
        self.view.pendingFields = {}
    end

    -- Commits all staged text as one `PatchStep` per step, in step id order so the result is deterministic. Returns
    -- true, or nil and a reason: the first unparsable field, or the workspace's refusal. Steps already committed stay
    -- committed.
    function pane:FlushFieldEdits()
        local tree = addon.RotationData.IndexRotationSteps(self.workspace:Snapshot())
        local edits = {}

        for id, fields in pairs(self.view.pendingFields or {}) do
            if tree.byId[id] then
                local combined = { set = {}, unset = {} }

                for key, record in pairs(fields) do
                    local patch = parsedText(key, record.text)

                    if not patch then
                        return nil, L['Complete the highlighted input fields before applying.'] .. ' ' .. record.label
                    end

                    for field, value in pairs(patch.set) do
                        combined.set[field] = value
                    end

                    for _, field in ipairs(patch.unset) do
                        combined.unset[#combined.unset + 1] = field
                    end
                end

                if next(combined.set) or #combined.unset > 0 then
                    edits[#edits + 1] = { id = id, patch = combined }
                end
            end
        end

        table.sort(edits, function(a, b) return a.id < b.id end)

        for _, edit in ipairs(edits) do
            local ok, why = self.workspace:Command('PatchStep', edit.id, edit.patch)

            if not ok then
                return nil, why
            end

            self.view.pendingFields[edit.id] = nil
        end

        return true
    end
end

-- ============================================================================
-- Card detail fields
-- ============================================================================

-- Native leaf controls and reference inputs share RM ownership. Every callback
-- commits a detached atomic patch.
-- Builds the detail fields for `model.step` inside `card.fields`; `alive()` says the card is still the current one.
-- Records the needed height in `owner.view.detailsHeights` and installs `card.releaseFields`, which hides the controls
-- and releases the widgets this call created.
function addon:BuildRotationCardFields(owner, card, model, alive)
    local step = model.step
    local readOnly = owner.workspace.readOnly
    local frame = card.fields
    local fieldWidth = model.width - 56
    local controls, menus, widgets = {}, {}, {}
    card.fieldControls = controls
    card.fieldPool = card.fieldPool or { labels = {}, inputs = {}, choices = {}, flags = {} }
    local pool = card.fieldPool
    pool.extras = pool.extras or {}
    local counts = { labels = 0, inputs = 0, choices = 0, flags = 0, extras = 0 }

    -- Returns the next pooled control of `kind` for this card (building it on first use) and shows it. The pool
    -- survives redraws so a card does not create new frames every time it opens.
    local function acquire(kind, build)
        counts[kind] = counts[kind] + 1
        local index = counts[kind]

        if not pool[kind][index] then
            pool[kind][index] = build()
        end

        local control = pool[kind][index]
        control:Show()
        return control
    end

    local y = 0
    local valueX = 108
    local valueWidth = math.max(80, fieldWidth - valueX)

    -- True while the card is still current and the workspace is editable; every callback checks it first.
    local function active()
        return alive() and not readOnly
    end

    -- Sends one `PatchStep` for this step: `set` fields to write and `unset` field names to clear. Does nothing when
    -- stale or read-only.
    local function patch(set, unset)
        if active() then
            return owner:Command('PatchStep', model.id, { set = set or {}, unset = unset or {} })
        end
    end

    -- Places a wrapped caption at the current row `y` and returns it so the control beside it can take the row height.
    local function label(caption)
        local text = acquire('labels', function()
            return frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        end)

        text:ClearAllPoints()
        text:SetPoint('TOPLEFT', 0, -y)
        text:SetWidth(valueX - 8)
        text:SetWordWrap(true)
        text:SetJustifyH('LEFT')
        text:SetJustifyV('MIDDLE')
        text:SetHeight(0)
        text:SetText(caption)
        text:SetHeight(math.max(20, text:GetStringHeight()))
        controls[#controls + 1] = text
        return text
    end

    -- Adds a labeled text box staged through `owner:StageField`; text that does not parse turns red. Enter flushes all
    -- staged fields and redraws, Escape just drops focus. `commit` is not used here: staging goes through the owner.
    local function input(key, caption, value, commit, hideLabel)
        local rowLabel = label(hideLabel and '' or caption)
        local control = acquire('inputs', function() return addon:CreateWorkbenchEditBox(frame) end)
        control:ClearAllPoints()
        control:SetPoint('TOPLEFT', valueX, -y)
        control:SetSize(valueWidth, 24)
        local rowHeight = math.max(24, rowLabel:GetStringHeight())
        rowLabel:SetHeight(rowHeight)
        control:ClearAllPoints()
        control:SetPoint('TOPLEFT', valueX, -y - (rowHeight - 24) / 2)
        local baseline = tostring(value or '')
        control:SetText(owner:FieldText(model.id, key, baseline))
        control:SetMaxLetters(1024)
        controls[key] = control
        controls[#controls + 1] = control
        y = y + rowHeight + 4

        -- Colors the box red while its text does not parse for this key.
        local function mark(field)
            local valid = parsedText(key, field:GetText()) ~= nil
            field:SetTextColor(1, valid and 1 or .35, valid and 1 or .35)
        end

        mark(control)

        addon:SetUIScript(control, 'OnTextChanged', function(field, userInput)
            if active() and userInput then
                owner:StageField(model.id, key, field:GetText(), baseline, caption)
                mark(field)
            end
        end)

        addon:SetUIScript(control, 'OnEnterPressed', function(field)
            if not active() then
                return
            end

            owner:StageField(model.id, key, field:GetText(), baseline, caption)
            local ok, why = owner:FlushFieldEdits()

            if ok then
                field:ClearFocus()
                owner:Render()
            else
                owner:Message(why)
            end
        end)

        addon:SetUIScript(control, 'OnEscapePressed', function(field)
            field:ClearFocus()
        end)

        control:EnableMouse(not readOnly)

        addon:SetUIScript(
            control,
            'OnEditFocusGained',
            readOnly and function(field)
                field:ClearFocus()
            end or nil
        )

        return control
    end

    -- Adds a button that opens the shared selector over `entries` (`{value, text}`) and calls `commit(value)` only when
    -- the choice changed.
    local function choice(key, caption, entries, selected, commit)
        local rowLabel = caption and label(caption)
        local button = acquire('choices', function() return addon:CreateWorkbenchButton(frame, '', fieldWidth) end)
        button:ClearAllPoints()
        button:SetPoint('TOPLEFT', caption and valueX or 0, -y)
        button:SetWidth(caption and valueWidth or fieldWidth)
        controls[key] = button
        controls[#controls + 1] = button
        local rowHeight = math.max(20, rowLabel and rowLabel:GetStringHeight() or 0)

        if rowLabel then
            rowLabel:SetHeight(rowHeight)
        end

        button:ClearAllPoints()
        button:SetPoint('TOPLEFT', caption and valueX or 0, -y - (rowHeight - 20) / 2)
        y = y + rowHeight + 4
        local title = selected

        for _, entry in ipairs(entries) do
            if entry.value == selected then
                title = entry.text
            end
        end

        button:SetText(title or L['Choose'])
        addon:AlignWorkbenchTextLeft(button, 6)
        button.menu = button.menu or addon:CreateWorkbenchSelector()
        local wrapper = button.menu
        wrapper:Hide()
        menus[#menus + 1] = wrapper

        addon:SetUIScript(button, 'OnClick', function()
            if not active() then
                return
            end

            if wrapper.frame:IsShown() then
                wrapper:Hide()
            else
                wrapper:Open(
                    button,
                    entries,
                    selected,
                    function(value)
                        if value ~= selected then
                            commit(value)
                        end
                    end,
                    active
                )
            end
        end)

        if readOnly then
            button:Disable()
        else
            button:Enable()
        end

        return button
    end

    -- Adds a checkbox that calls `commit(not value)` when clicked.
    local function flag(key, caption, value, commit)
        local control = acquire('flags', function() return addon:CreateWorkbenchCheckBox(frame, '', fieldWidth) end)
        control:ClearAllPoints()
        control:SetPoint('TOPLEFT', 0, -y)
        control:SetText(caption)
        control.tooltip = nil
        control:SetChecked(value == true)
        controls[key] = control
        controls[#controls + 1] = control
        y = y + 24

        addon:SetUIScript(control, 'OnClick', function()
            if active() then
                commit(not value)
            end
        end)

        if readOnly then
            control:Disable()
        else
            control:Enable()
        end

        return control
    end

    if step.type == 'branch' then
        local control = acquire('choices', function() return addon:CreateWorkbenchButton(frame, '', fieldWidth) end)
        control:ClearAllPoints()
        control:SetPoint('TOPLEFT', 0, -y)
        control:SetWidth(fieldWidth)
        control:SetText(readOnly and L['View condition'] or L['Edit condition'])
        control:Enable()

        addon:SetUIScript(control, 'OnClick', function()
            if alive() then
                owner:EditCondition(model.id)
            end
        end)

        owner.view.detailsHeights[model.id] = 40

        card.releaseFields = function()
            control:Hide()
            addon:SetUIScript(control, 'OnClick', nil)
        end

        return
    end

    local types = {
        { value = 'spell', text = L['Spell'] },
        { value = 'pet', text = L['Pet Spell'] },
        { value = 'any', text = L['Any Spell'] },
        { value = 'item', text = L['Item'] },
    }

    if model.section == 'rotation' then
        if step.type == 'assisted' or addon:HasAssistedCombatAPI() then
            types[#types + 1] = { value = 'assisted', text = L["Blizzard's suggestion"] }
        end

        -- Set Mark is offered where the client can place marks, and kept for a step that is already one.
        local platform = addon.Platform

        if step.type == 'mark' or platform.GetMarkActionSupport and platform:GetMarkActionSupport() == nil then
            types[#types + 1] = { value = 'mark', text = L['Set Mark'] }
        end

        types[#types + 1] = { value = 'stop', text = L['Stop'] }
    end

    local typeControl = choice('type', nil, types, step.type, function(value)
        local ok, why = owner:FlushFieldEdits()

        if ok and value == 'mark' then
            patch({ type = value, unit = 'target', action = 'skull' }, { 'ranked', 'suppress_attack' })
        elseif ok then
            patch({ type = value }, { 'action', 'ranked', 'suppress_attack', 'unit' })
        else
            owner:Message(why)
        end
    end)

    if step.type ~= 'stop' and step.type ~= 'assisted' and step.type ~= 'mark' then
        card.fieldSpellIcon = card.fieldSpellIcon or addon:CreateWorkbenchIconButton(frame, 'preview')
        local icon = card.fieldSpellIcon
        icon:ClearAllPoints()
        icon:SetPoint('TOPLEFT', -2, 0)
        icon:SetSize(36, 36)
        icon.icon:SetSize(36, 36)

        local itemID = step.type == 'item'
            and type(step.action) == 'table'
            and (tonumber(step.action[1]) or addon:GetReferenceProvider('item').resolve(step.action[1]))

        local itemInfo = itemID and addon:GetReferenceProvider('item').info(itemID)
        local info = step.type ~= 'item' and addon.Platform and addon.Platform:GetSpellInfo(step.action)

        icon.icon:SetTexture(
            itemInfo and itemInfo.icon or info and info.iconID or 'Interface\\Icons\\INV_Misc_QuestionMark'
        )

        icon:Show()

        addon:SetUIScript(icon, 'OnEnter', function(control)
            if alive() and info and info.spellID and GameTooltip then
                GameTooltip:SetOwner(control, 'ANCHOR_RIGHT')
                GameTooltip:SetHyperlink('spell:' .. info.spellID)
            end
        end)

        addon:SetUIScript(icon, 'OnLeave', function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)

        addon:SetUIScript(icon, 'OnClick', function()
            if alive() and info and info.spellID and type(SetItemRef) == 'function' then
                SetItemRef('spell:' .. info.spellID, addon:SpellLabel(step.action), 'LeftButton')
            end
        end)

        controls[#controls + 1] = icon
        typeControl:ClearAllPoints()
        typeControl:SetPoint('TOPLEFT', 44, 0)
        typeControl:SetWidth(fieldWidth - 44)
    end

    if step.type == 'spell' or step.type == 'pet' or step.type == 'any' then
        local field = addon:CreateSpellEditBox(step.type == 'any' and 'Spell_EditBox' or 'Spec_EditBox', step.action)
        widgets[#widgets + 1] = field
        controls.spell = field
        typeControl:ClearAllPoints()
        typeControl:SetPoint('TOPLEFT', 44, 0)
        typeControl:SetWidth(fieldWidth - 44)
        field.frame:SetParent(frame)
        field.frame:ClearAllPoints()
        field.frame:SetPoint('TOPLEFT', 44, -y)
        field:SetWidth(fieldWidth - 44)
        field:SetLabel('')
        field:SetUserData('spec', step.type == 'pet' and (BOOKTYPE_PET or "pet") or owner.workspace.spec)
        field:SetUserData('norank', not step.ranked)
        field:SetText(step.action and addon.SpellCatalog:SpellName(step.action, not step.ranked) or '')

        field:SetCallback('OnEnterPressed', function(_, _, value)
            if not active() then
                return
            end

            local id = tonumber(value)

            if id and id > 0 and id % 1 == 0 then
                patch({ action = id })
            else
                patch(nil, { 'action' })
            end
        end)

        field:SetDisabled(readOnly)
        field.frame:Show()
        local spellY = y

        if addon:ClientHasSpellRanks() then
            local exact = flag('ranked', L['Use this exact spell rank'], step.ranked, function(value)
                patch({ ranked = value })
            end)

            exact.tooltip = L['Unticked, any rank of the spell matches. Ticked, only the rank you chose matches.']

            local height, inputWidth = addon:LayoutWorkbenchFieldOption(
                field.frame,
                exact,
                frame,
                44,
                spellY,
                fieldWidth - 44
            )

            field:SetWidth(inputWidth)
            y = spellY + height + 4
        else
            field:SetWidth(fieldWidth - 44)
            y = spellY + 28
        end
    elseif step.type == 'mark' then
        y = addon:BuildRotationMarkFields(owner, card, model, alive, {
            acquire = acquire,
            choice = choice,
            patch = patch,
            controls = controls,
            width = fieldWidth,
            readOnly = readOnly,
            getY = function() return y end,
            setY = function(value)
                y = value
            end,
        })
    elseif step.type == 'stop' then
        flag('suppress', L['Also suppress auto-attack (Attack or Shoot)'], step.suppress_attack, function(value)
            patch({ suppress_attack = value })
        end)
    elseif step.type == 'item' then
        local entries = { { value = '', text = L['Custom'] } }

        for _, source in ipairs({ addon.db.profile.itemsets or {}, addon.db.global.itemsets or {} }) do
            for id, set in pairs(source) do
                if type(id) == 'string' and type(set) == 'table' then
                    entries[#entries + 1] = { value = id, text = set.name or id }
                end
            end
        end

        table.sort(entries, function(a, b) return a.text < b.text end)

        local itemSet = choice('itemset', nil, entries, type(step.action) == 'string' and step.action or '', function(
            value
        )
            patch({ action = value ~= '' and value or {} })
        end)

        itemSet:ClearAllPoints()
        itemSet:SetPoint('TOPLEFT', 44, -y + 24)
        itemSet:SetWidth(fieldWidth - 44)

        if type(step.action) ~= 'string' then
            local items = type(step.action) == 'table' and step.action or {}

            for index = 1, #items + 1 do
                local item = items[index]
                local field = addon:CreateItemEditBox('Item_EditBox', item)
                widgets[#widgets + 1] = field
                controls['item' .. index] = field
                field.frame:SetParent(frame)
                field.frame:ClearAllPoints()
                field.frame:SetPoint('TOPLEFT', 44, -y)
                field:SetWidth(math.max(40, fieldWidth - 70))
                field:SetLabel('')
                field:SetText(item or '')

                field:SetCallback('OnEnterPressed', function(_, _, value)
                    if not active() then
                        return
                    end

                    local id = tonumber(value)
                    local copy = addon.Functions.collections.deepcopy(items)

                    if id and id > 0 and id % 1 == 0 then
                        copy[index] = id
                    elseif index <= #copy then
                        table.remove(copy, index)
                    else
                        return
                    end

                    patch({ action = copy })
                end)

                field:SetDisabled(readOnly)
                field.frame:Show()

                if item then
                    local remove = acquire('choices', function()
                        return addon:CreateWorkbenchIconButton(frame, 'trash', L['Delete'])
                    end)

                    remove:ClearAllPoints()
                    remove:SetPoint('TOPLEFT', fieldWidth - 22, -y)
                    remove:SetSize(20, 20)
                    controls[#controls + 1] = remove

                    addon:SetUIScript(remove, 'OnClick', function()
                        if active() then
                            local copy = addon.Functions.collections.deepcopy(items)
                            table.remove(copy, index)
                            patch({ action = copy })
                        end
                    end)

                    if readOnly then
                        remove:Disable()
                    else
                        remove:Enable()
                    end
                end

                y = y + 28
            end
        end
    end

    if model.section == 'cooldowns' then
        y = addon:BuildRotationEffectFields(owner, card, model, alive, {
            controls = controls,
            acquire = acquire,
            width = fieldWidth,
            valueX = valueX,
            valueWidth = valueWidth,
            label = label,
            input = input,
            choice = choice,
            patch = patch,
            active = active,
            readOnly = readOnly,
            getY = function() return y end,
            setY = function(value)
                y = value
            end,
        })
    end

    owner.view.detailsHeights[model.id] = math.max(24, y + 8)

    card.releaseFields = function()
        card.RefreshHighlightPreview = nil

        if card.colorPicker then
            card.colorPicker.frame:Hide()
        end
        if card.effectDemo and addon.HideGlow then
            addon:HideGlow(card.effectDemo.target, 'rotation-effect-preview')
        end

        for _, wrapper in ipairs(menus) do
            wrapper:Release()

            for _, row in ipairs(wrapper.rows) do
                addon:SetUIScript(row, 'OnClick', nil)
            end
        end

        for _, control in ipairs(controls) do
            control:Hide()

            if control.ClearFocus then
                control:ClearFocus()
            end
        end

        for _, input in ipairs(pool.inputs) do
            addon:SetUIScript(input, 'OnTextChanged', nil)
            addon:SetUIScript(input, 'OnEnterPressed', nil)
            addon:SetUIScript(input, 'OnEscapePressed', nil)
            addon:SetUIScript(input, 'OnEditFocusGained', nil)
        end

        for _, widget in ipairs(widgets) do
            addon:ReleaseConditionWidget(widget)
        end

        card.fieldControls = nil
    end
end
