-- The "Recover unassigned rotations" window. Older rotations saved without an owner sit in a profile or character
-- archive; this window lists them, shows the archived record as text, and lets the player explicitly adopt one (or
-- all) for the class or the current character. It must never infer an owner and never change the archive except
-- through addon:ApplyRotationAdoption and addon:AdoptAllUnassignedRotations (Core/). The window closes itself when the
-- opening window, profile or character changes underneath it. Opened from the rotation browser
-- (UI/rotation_browser.lua); loaded in the UI/ block of RotationMaster.toc after UI/transfer_format.lua.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- ============================================================================
-- Helpers
-- ============================================================================

-- Stable identity string for one archived record, used as the roster value.
local function key(selection)
    return selection.kind .. '\0' .. selection.spec .. '\0' .. selection.id
end

-- Localized class name for display, falling back to the raw token (or empty) when the client has no name table.
local function className(class)
    local names = type(LOCALIZED_CLASS_NAMES_MALE) == 'table' and LOCALIZED_CLASS_NAMES_MALE
    return names and names[class] or class or ''
end

-- Archival inspection is text only. Bounds apply to the report, never to the
-- saved record or the complete recovery roster.
-- Serializes an archived record to indented text for the copyable report, capped at 64 KB, 20,000 nodes or keys and 32
-- levels of depth; cycles print as <cycle>. Appends a notice when anything was cut. Read-only on `value`.
local function describe(value)
    local parts, bytes, nodes, active = {}, 0, 0, {}
    local truncated = false

    -- Appends a piece of text; returns false (and marks the report truncated) when the byte budget is exhausted.
    local function put(text)
        if bytes + #text > 65500 then
            truncated = true
            return false
        end

        parts[#parts + 1] = text
        bytes = bytes + #text
        return true
    end

    -- Writes one value recursively, with keys sorted by type then value so the report is stable between runs.
    local function visit(current, depth)
        nodes = nodes + 1

        if nodes > 20000 or depth > 32 then
            truncated = true
            return
        end

        local kind = type(current)

        if kind == 'string' then
            put(string.format('%q', current:sub(1, 65500)))
            if #current > 65500 then truncated = true end
        elseif kind == 'number' or kind == 'boolean' or kind == 'nil' then
            put(tostring(current))
        elseif kind ~= 'table' then
            put('<' .. kind .. '>')
        elseif active[current] then
            put('<cycle>')
        else
            active[current] = true
            put('{\n')
            local keys = {}

            for field in pairs(current) do
                if #keys >= 20000 then
                    truncated = true
                    break
                end

                keys[#keys + 1] = field
            end

            table.sort(keys, function(a, b)
                if type(a) == type(b) and (type(a) == 'string' or type(a) == 'number') then return a < b end
                return type(a) < type(b)
            end)

            for _, field in ipairs(keys) do
                if truncated then break end
                if not put(string.rep('  ', depth + 1) .. '[') then break end
                visit(field, depth + 1)
                put('] = ')
                visit(current[field], depth + 1)
                put(',\n')
            end

            put(string.rep('  ', depth) .. '}')
            active[current] = nil
        end
    end

    visit(value, 0)
    if truncated then parts[#parts + 1] = '\n' .. L['Archive report truncated; saved data is unchanged.'] end
    return table.concat(parts):sub(1, 65536)
end

-- ============================================================================
-- Adoption window
-- ============================================================================

-- Opens the recovery window. `owner` is the window that opened it (its generation, lease and serial are captured so
-- the window closes if that owner goes away; may be nil), and `onApplied(reference)` is called with a copy of the last
-- adopted rotation's reference after a successful adoption, only if the owner is still current. Returns the window.
function addon:ShowRotationAdoption(owner, onApplied)
    local window = self.rotationAdoptionWindow

    if not window then
        window = { frame = CreateFrame('Frame', nil, UIParent) }
        self.rotationAdoptionWindow = window
        local frame = window.frame
        frame:SetSize(1000, 650)
        frame:SetPoint('CENTER')
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        self:MakeWindowOpaque(frame)
        window.title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
        window.chrome = self:CreateWorkbenchDialogChrome(frame, window.title)
        window.close = self:CreateWorkbenchIconButton(frame, 'close', L['Close'])
        window.close:SetPoint('TOPRIGHT', -5, -5)
        window.content = CreateFrame('Frame', nil, frame)
        window.content:SetPoint('TOPLEFT', 12, -40)
        window.content:SetSize(976, 598)
        window.form = self:CreateSettingsForm(window.content)
        window.form:SetWidth(976)
        window.form:SetHeight(598)

        -- Registry-facing hide for the window.
        function window:Hide()
            self.frame:Hide()
        end

        -- Marks the window inactive (so every callback from the previous draw stops working), releases the form and
        -- hides any open archive report. Runs on every hide and before each reopening.
        function window:Clear()
            self.active = false
            self.form:Release()
            if self.report then self.report.frame:Hide() end
        end

        self:SetUIScript(window.close, 'OnClick', function() window:Hide() end)
        self:SetUIScript(frame, 'OnHide', function() window:Clear() end)
        frame:Hide()
    end

    window:Clear()
    window.serial = (window.serial or 0) + 1
    local serial = window.serial
    local profile = self.db.profile
    local coordinator = self:GetScopedRotationCoordinator()
    local context = self:GetRotationOwnerContext()
    local ownerGeneration = owner and owner.generation
    local ownerLease = owner and owner.rmLease
    local ownerSerial = owner and owner.serial

    -- True when there is no owner, or the owner window is still shown, with the same generation, lease and serial
    -- it had when this window opened.
    local function ownerValid()
        return not owner
            or (not owner.frame or owner.frame:IsShown())
                and owner.generation == ownerGeneration
                and owner.rmLease == ownerLease
                and owner.serial == ownerSerial
                and owner.active ~= false
    end

    -- True while the profile and the class and character that the window opened under are unchanged and the owner is
    -- still valid; adoption writes to that profile and owner, so a switch must stop it.
    local function identityCurrent()
        local now = addon:GetRotationOwnerContext()

        return addon.db.profile == profile
            and (not context and not now
                or context and now and context.class == now.class and context.character == now.character)
            and ownerValid()
    end

    -- True while this opening is current: window active, same serial, shown, same identity and same coordinator.
    local function valid()
        return window.active
            and window.serial == serial
            and window.frame:IsShown()
            and identityCurrent()
            and addon:GetScopedRotationCoordinator() == coordinator
    end

    local scope = 'class'
    window.active = true
    window.chrome:SetContext(L['Recover unassigned rotations'], L['Ownership required'], addon.pretty_name)
    window.frame:Show()

    window.form:Open(function(p)
        p:Message('')
        p:Heading(L['Recover unassigned rotations'])

        p:Text(
            L['These records have no assigned owner. Choose Class or This character explicitly. No ownership is inferred from names, spells or profile history.']
        )

        p:Button('refresh', L['Refresh'], function()
            if valid() then p:Draw() end
        end)

        local rows, why = addon:ListUnassignedRotations()

        if not rows then
            local report = string.format(L['Recovery unavailable: %s'], why)
            p:Text(report)

            p:Button('export', L['Copy diagnostic details'], function()
                if valid() then
                    window.report = window.report or addon:CreateWorkbenchTextReport(820, 500)
                    window.report:SetReport(L['Unassigned rotation archive'], report)
                end
            end)

            return
        end

        local entries, selected = {}, nil

        for _, row in ipairs(rows) do
            local entry = {
                value = key(row.selection),
                selection = addon.RotationData.CopyData(row.selection),
                text = row.name
                    .. ' · '
                    .. (row.kind == 'character' and L['Character archive'] or L['Profile archive'])
                    .. ' · '
                    .. row.spec
                    .. ' · '
                    .. row.id,
            }

            entries[#entries + 1] = entry
            if entry.value == p.selection then selected = row end
        end

        if not selected and rows[1] then
            selected = rows[1]
            p.selection = key(selected.selection)
        end

        p:UseRoster(entries, p.selection, function(value)
            if valid() then
                p.selection = value
                p:Draw()
            end
        end)

        if not selected then
            p:Text(L['No unassigned rotations.'])
            return
        end

        local selection = addon.RotationData.CopyData(selected.selection)
        p:Heading(selected.name)

        p:Text(string.format(
            L['Archive: %s; specialization: %s; identifier: %s'],
            selected.kind == 'character' and L['Character archive'] or L['Profile archive'],
            selected.spec,
            selected.id
        ))

        local snapshot, snapshotReason = addon:GetUnassignedRotationSnapshot(selection)

        local report = string.format(
            L['Archive: %s; specialization: %s; identifier: %s'],
            selection.kind,
            selection.spec,
            selection.id
        )
            .. '\n\n'
            .. (snapshot and describe(snapshot) or tostring(snapshotReason))

        p:Button('export', L['Export archive'], function()
            if valid() then
                window.report = window.report or addon:CreateWorkbenchTextReport(820, 500)
                window.report:SetReport(L['Unassigned rotation archive'], report)
            end
        end)

        p:Text(L['Applies to'])

        -- Switches the adoption owner between 'class' and 'character' and redraws the page.
        local function choose(value)
            if valid() then
                scope = value
                p:Draw()
            end
        end

        p:Check('class', L['Class'], scope == 'class', function() choose('class') end)

        local character = p:Check('character', L['This character'], scope == 'character', function()
            choose('character')
        end)

        if not context or not context.character then character:Disable() end
        local plan, reason

        if snapshot then
            plan, reason = addon:PlanRotationAdoption(selection, scope)
        else
            reason = snapshotReason
        end

        if not selected.hasBody then
            reason = reason or 'missing-archival-body'
            plan = nil
        end

        local adopt

        adopt = p:Button('adopt', L['Adopt rotation'], function()
            if not valid() or not plan then return end
            local ok, reference = addon:ApplyRotationAdoption(plan)

            if not ok then
                plan = nil
                adopt:Disable()
                p:Message(string.format(L['Could not adopt this record: %s'], reference))
                return
            end

            local notify = identityCurrent()
            window:Hide()
            if notify and onApplied then onApplied(addon.RotationData.CopyData(reference)) end
        end)

        if not plan then
            adopt:Disable()
            p:Message(string.format(L['Could not adopt this record: %s'], reason or 'missing-archival-body'))
        end

        -- Several at once. The choice above names the owner; every record is still
        -- planned and applied on its own, and one that is refused stays in the archive.
        local total, group = 0, 0

        for _, row in ipairs(rows) do
            if row.hasBody then
                total = total + 1
                if row.spec == selected.spec then group = group + 1 end
            end
        end

        if total > 1 then
            local target = scope == 'class' and className(context and context.class) or L['This character']

            -- Confirms, then adopts `count` records for the chosen owner (optionally limited to one specialization).
            -- Records that cannot be adopted stay in the archive and are named in a message.
            local function run(count, options)
                p:Confirm(
                    string.format(
                        L['Adopt %d unassigned rotations for %s? Each keeps its identifier. A rotation that cannot be adopted stays in the archive.'],
                        count,
                        target
                    ),
                    function()
                        if not valid() then return end
                        local result, why = addon:AdoptAllUnassignedRotations(scope, options)

                        if not result then
                            p:Message(string.format(L['Could not adopt this record: %s'], why))
                            return
                        end

                        local last = result.references[#result.references]
                        local notify = identityCurrent()

                        if #result.failed == 0 then
                            window:Hide()
                            if notify and onApplied and last then onApplied(addon.RotationData.CopyData(last)) end
                            return
                        end

                        local names = {}

                        for _, failure in ipairs(result.failed) do
                            names[#names + 1] = failure.name
                        end

                        p:Draw()

                        p:Message(string.format(
                            L['Adopted %d of %d. These stay in the archive: %s'],
                            result.adopted,
                            result.adopted + #result.failed,
                            table.concat(names, ', ')
                        ))

                        if notify and onApplied and last then onApplied(addon.RotationData.CopyData(last)) end
                    end
                )
            end

            local bulkGroup

            if group > 1 and group < total then
                bulkGroup = p:Button(
                    'adoptGroup',
                    string.format(L['Adopt all %d from specialization %d for %s'], group, selected.spec, target),
                    function()
                        if valid() then run(group, { spec = selected.spec }) end
                    end
                )
            end

            local bulk = p:Button('adoptAll', string.format(L['Adopt all %d for %s'], total, target), function()
                if valid() then run(total) end
            end)

            if scope == 'character' and (not context or not context.character) then
                bulk:Disable()
                if bulkGroup then bulkGroup:Disable() end
            end
        end
    end)

    self:SetUIScript(window.frame, 'OnUpdate', function()
        if window.active and window.serial == serial and not valid() then window:Hide() end
    end)

    self:OpenPopup(window)
    return window
end
