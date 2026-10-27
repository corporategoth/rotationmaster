-- The Help window and its tooltips. Builds the help content for the settings pages, the rotation and condition
-- editors and the window chrome (sections of title and text, localized through L), shows one shared Help window with an
-- optional mounted document, and binds hover tooltips to controls. Every callback runs under Diagnostics so a faulty
-- help renderer cannot break the editor, and a request counter makes a newer request retire an older one. It owns a
-- document lease only and must never open an edit or history transaction. Loaded in the UI/ block of RotationMaster.toc
-- after UI/window.lua; the authored help text itself lives in Help/ and the localized text bundles.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- ============================================================================
-- Request guards
-- ============================================================================

-- Builds one help section record from a title and body text.
local function section(title, text)
    return { title = title, text = text }
end

-- Help owns a document lease, never an edit/history transaction.
-- Request counter. Each open request and each hide bumps it, so a stale request can tell it was superseded.
local helpRequest = 0

-- Calls `callback` under Diagnostics with a help render context (or a plain pcall when diagnostics are absent).
-- Returns ok followed by the callback's results.
---@return boolean, any
local function callHelpContext(context, callback, ...)
    if addon.Diagnostics then
        return addon.Diagnostics:Call(context or { module = 'help', operation = 'render' }, callback, ...)
    end

    return pcall(callback, ...)
end

-- callHelpContext with the default render context.
local function callHelp(callback, ...)
    return callHelpContext(nil, callback, ...)
end

-- True when there is no validity callback, or it runs cleanly and returns exactly true. An error counts as invalid.
local function validHelp(valid)
    if not valid then return true end
    local ok, current = callHelp(valid)
    return ok and current == true
end

-- Wraps `callback` so it runs only while `valid` still reports the help subject as current.
function addon:GuardWorkbenchHelp(valid, callback)
    return function(...)
        if validHelp(valid) then return callback(...) end
    end
end

-- ============================================================================
-- Opening the window
-- ============================================================================

-- Opens Help for a request { valid, sections (table or function), heading, owner, render, renderContext }. Sections
-- may be a function, which is called safely. Returns a handle with Hide, or nothing when the request is invalid or was
-- superseded by a newer one while it was being prepared.
function addon:OpenWorkbenchHelp(request)
    local valid = request.valid
    local previous = helpRequest
    if not validHelp(valid) or previous ~= helpRequest then return end
    helpRequest = helpRequest + 1
    local token = helpRequest

    -- True while this request is still the newest and its subject is still valid.
    local function current()
        if token ~= helpRequest then return false end
        local live = validHelp(valid)
        return live and token == helpRequest
    end

    -- Drops any content already mounted and hides the window, but only if no newer request has taken it over.
    local function failed()
        local d = self.helpWindow

        if token == helpRequest and d then
            d:ReleaseMount()
            if token == helpRequest then d.frame:Hide() end
        end
    end

    if not current() then
        failed()
        return
    end

    local sections = request.sections or {}

    if type(sections) == 'function' then
        local ok, value = callHelp(sections)

        if not ok or not current() then
            failed()
            return
        end

        sections = value
    end

    if type(sections) ~= 'table' or not current() then
        failed()
        return
    end

    local heading = request.heading or L['Help']
    -- Capture only diagnostic scalars from the accepted subject, per request.
    local metadata = request.renderContext

    local context = {
        module = 'help',
        operation = 'render',
        customCode = type(metadata) == 'table' and rawget(metadata, 'customCode') == true,
        conditionTag = type(metadata) == 'table' and rawget(metadata, 'conditionTag') or nil,
    }

    local document = self:ShowWorkbenchHelp(heading, sections, request.owner, {
        current = current,
        render = request.render,
        renderContext = context,
    })

    if not document or not current() then return end
    local handle = { frame = document.frame, heading = heading, sections = sections }

    -- Hides the window only if this handle's request is still the current one.
    function handle:Hide()
        if token == helpRequest then document:Hide() end
    end

    return handle
end

-- ============================================================================
-- Authored help sections
-- ============================================================================

-- Help sections for the shared window chrome (navigation, scale, controls, drafts, help).
function addon:WorkbenchWindowHelp()
    return {
        section(L['Navigation'], L['Help.Window.navigation']),
        section(L['Scale'], L['Help.Window.scale']),
        section(L['Window controls'], L['Help.Window.controls']),
        section(L['Apply / Discard'], L['Help.Window.drafts']),
        section(L['Help'], L['Help.Window.help']),
    }
end

-- Some bound controls are Lua wrappers (editor objects), not frames; the
-- tooltip's owner APIs reject those with "Wrong object type".
-- True when GameTooltip is currently owned by `control`; false when it is not, or when the owner check rejects it.
local function tooltipOwned(control)
    if not GameTooltip then return false end
    local ok, owned = pcall(GameTooltip.IsOwned, GameTooltip, control)
    return ok and owned
end

-- ============================================================================
-- Tooltip binding
-- ============================================================================

-- Descriptors are held only by their owning control and retired on pool reuse.
-- Chains a hover tooltip onto `control`: descriptor.brief (text or a function read at hover time) is shown after the
-- control's own OnEnter, and descriptor.valid retires it. Returns a clear function that restores the previous scripts;
-- binding a control again clears its earlier binding first.
function addon:BindWorkbenchHelp(control, descriptor)
    if control.rmHelpBinding then control.rmHelpBinding.clear() end
    local binding = {}
    control.rmHelpBinding = binding
    local enter, leave = control:GetScript('OnEnter'), control:GetScript('OnLeave')

    -- True while this binding is still the control's binding. The binding is checked on both sides of the validity
    -- callback because that callback may rebind the control.
    local function current()
        return control.rmHelpBinding == binding and validHelp(descriptor.valid) and control.rmHelpBinding == binding
    end

    -- Hover handler: runs the control's original OnEnter first, then adds or sets the tooltip text.
    local function onEnter(...)
        if not current() then return end
        if enter then enter(...) end
        -- A brief may be a function, read each time the tip opens, for a control whose meaning follows a mode.
        local brief = descriptor.brief

        if type(brief) == 'function' then
            local ok, value = pcall(brief)
            brief = ok and value or nil
        end

        if not current() or not brief or not GameTooltip then return end

        if tooltipOwned(control) then
            if brief ~= control.tooltip then GameTooltip:AddLine(brief, 1, 1, 1, true) end
        else
            if not pcall(GameTooltip.SetOwner, GameTooltip, control, 'ANCHOR_RIGHT') then return end
            GameTooltip:SetText(brief, 1, 1, 1, 1, true)
        end

        GameTooltip:Show()
    end

    -- Leave handler: runs the original OnLeave, then hides the tooltip if this control still owns it.
    local function onLeave(...)
        if not current() then return end
        if leave then leave(...) end
        if current() and tooltipOwned(control) then GameTooltip:Hide() end
    end

    addon:SetUIScript(control, 'OnEnter', onEnter)
    local installedEnter = control:GetScript('OnEnter')
    addon:SetUIScript(control, 'OnLeave', onLeave)
    local installedLeave = control:GetScript('OnLeave')

    -- Restores the control's original scripts, but only the ones still installed by this binding so a later
    -- replacement by someone else is left alone.
    function binding.clear()
        if control.rmHelpBinding ~= binding then return end
        control.rmHelpBinding = nil
        if control:GetScript('OnEnter') == installedEnter then control:SetScript('OnEnter', enter) end
        if control:GetScript('OnLeave') == installedLeave then control:SetScript('OnLeave', leave) end
        if tooltipOwned(control) then GameTooltip:Hide() end
    end

    return binding.clear
end

-- Per-option help entries for the Profiles page (id, title, text).
function addon:GetProfileOptionHelp()
    return {
        { id = 'activate', title = L['Activate profile'], text = L['Help.Profiles.activate'] },
        { id = 'copy', title = L['Copy from profile'], text = L['Help.Profiles.copy'] },
        { id = 'reset', title = L['Reset current profile'], text = L['Help.Profiles.reset'] },
        { id = 'delete', title = L['Delete'], text = L['Help.Profiles.delete'] },
        { id = 'new_name', title = L['New profile name'], text = L['Help.Profiles.new_name'] },
        { id = 'collections', title = L['New / Duplicate / Import / Compare'], text = L['Help.Profiles.collections'] },
    }
end

-- Per-option help entries for the Integrations page (id, title, text).
function addon:GetIntegrationOptionHelp()
    return {
        { id = 'lua_editor', title = L['Editor'], text = L['Help.Integrations.lua_editor'] },
        { id = 'lua_line_numbers', title = L['Show line numbers'], text = L['Help.Integrations.lua_line_numbers'] },
        { id = 'optional_addons', title = L['Optional addons'], text = L['Help.Integrations.optional_addons'] },
        {
            id = 'preview_masque',
            title = L['Skin preview buttons with Masque'],
            text = L['Help.Integrations.preview_masque'],
        },
        {
            id = 'questie_enabled',
            title = L['Enable Questie integration'],
            text = L['Help.Integrations.questie_enabled'],
        },
        { id = 'encounter_provider', title = L['Boss mods'], text = L['Help.Integrations.encounter_provider'] },
        { id = 'top_panels', title = L['Top panels'], text = L['Help.Integrations.top_panels'] },
        {
            id = 'native_highlighting',
            title = L['Syntax highlighting'],
            text = L['Help.Integrations.native_highlighting'],
        },
    }
end

-- Help sections for the card editors. `kind` is 'condition' for the condition editor; 'branch', 'cooldown' or any
-- other value for the rotation editor, which adds the matching branch, bar and effect sections.
function addon:WorkbenchInteractionHelp(kind)
    local result = {
        section(
            L['Names and details'],
            L['Click a name to rename it. Clear a custom step name to restore its action name. Click a collapsed title to show its summary. Click action or condition text to open its details; the double chevron returns from fields to the summary.']
        ),
    }

    if kind == 'condition' then
        result = {
            section(
                L['Choose and edit'],
                L['Click a condition type to search or browse categories. Dismissing the picker or choosing the same type keeps its fields. Click the condition summary to edit its fields. The chevron switches between name only and summary; the double chevron closes the fields.']
            ),
            section(
                L['Groups and toggles'],
                L['If / Unless toggles negation. Enabled / Disabled keeps the saved fields while skipping evaluation. All / Any changes AND / OR. Click a group name to rename it; the branch icon hides or shows its children. Gray descendants cannot be reached.']
            ),
            section(
                L['Select several cards'],
                L['Ctrl-click cards to add or remove them from the selection; Shift-click selects the siblings between it and the last clicked card. Shift-drag on empty canvas draws a box that selects every card it touches (Ctrl+Shift-drag adds). With several cards selected, the strip above the canvas groups them as All or Any, and Duplicate, Enable, Disable and Delete act on every selected card; one Undo reverses each. Drag any selected card to move the selection.']
            ),
            section(
                L['Move, copy and remove'],
                L['Drag a card into one highlighted gap, or use the left-side Up / Down arrows. Hold Ctrl when starting a drag to carry the card and all following siblings. Groups always carry their children. Unavailable moves are gray. Ctrl-click or Shift-click selects several cards for grouping; dragging an existing selection moves that selection. Duplicate copies a card; Split group removes its wrapper; the red trash can deletes it. Add condition and Add group append when clicked or insert where dropped.']
            ),
        }
    else
        result[#result + 1] = section(
            L['Move, copy and remove'],
            L['Drag one card into a highlighted gap; hold Ctrl when starting the drag to carry that card and all following siblings. A branch always carries its children. Use Up / Down on the left to move one card. Duplicate copies the card and the red trash can deletes it. Cooldowns are independent, so they have no move arrows.']
        )

        result[#result + 1] = section(
            L['Select several cards'],
            L['Ctrl-click cards to add or remove them from the selection; Shift-click a title or condition to select the siblings between it and the last clicked card. Shift-drag on empty canvas draws a box that selects every card it touches (Ctrl+Shift-drag adds). Drag any selected card to move the whole selection to one gap. Beside Apply, Duplicate, Enable, Disable and Delete act on every selected card, and one Undo reverses each. Branches keep their Evaluate / Always mode. Click empty canvas to clear the selection.']
        )

        result[#result + 1] = section(
            L['Conditions and state'],
            kind == 'branch'
                and L['Click the guard text to edit the branch condition. Evaluate uses that condition; Always true / Always false skips it. False is left and red; True is right and green. The branch icon hides both arms without changing them. Click True or False to fold only that arm; its hidden count remains visible. Gray cards in a forced arm are unreachable.']
                or L['Click condition text to edit when this card can run. Enabled / Disabled preserves the card while switching its participation. Actions also require known or carried actions, usable resources, cooldown readiness and valid range.']
        )

        if kind ~= 'branch' then
            result[#result + 1] = section(
                L['Not on your action bars'],
                L['An amber border and warning mark a card whose action no action bar button holds right now. Rotation Master highlights an action by lighting the button that holds it, so that step is skipped (a cooldown is never shown) until you put it on a bar. The warning updates when your bars change. Red still marks invalid data.']
            )
        end

        if kind == 'cooldown' then
            result[#result + 1] = section(
                L['Highlight effects'],
                L['Click the action to edit its type, spell or item. The leading icon previews the effect. Effect selects a style; Magnification changes its size. Click the swatch or edit RGBA on the 0–1 scale. Arrows adjust position; V / H show offsets. Default restores profile values. Sound selection and Play preview an audible reminder.']
            )
        end
    end

    result[#result + 1] = section(
        L['Help and saving'],
        L['The question mark explains the visible controls. With condition fields open, it adds that condition’s help below the fields. Undo / Redo affect the draft. Apply saves; Discard or Cancel abandons draft changes. Red borders mark invalid or incomplete data.']
    )

    return result
end

-- Full help for one settings page, by topic name ('General', 'Conditions', 'Effects', 'ItemSets', 'Announces',
-- 'Profiles', 'About', 'Rotations', 'Integrations' or 'Functions'): an intro, the shared Apply / Discard note, the
-- page's authored option entries and the window controls. Returns a list of sections.
function addon:WorkbenchPageHelp(topic)
    if topic == 'Functions' then
        return {
            section(
                L['Using this page'],
                L['Search helpers by name or description, then filter Built In / Custom and namespace. Packaged helpers use the same read-only pane. Duplicate creates an editable custom copy.']
            ),
            section(
                L['Namespace'],
                L['Choose an existing namespace from the suggestions or type a new dotted namespace. Built In namespaces follow source files; custom namespaces are implied by saved functions and need no separate maintenance.']
            ),
            section(
                L['Name'],
                L['Function names use letters, numbers and underscores, beginning with a letter or underscore. The code signature shows the qualified namespace.name used by callers.']
            ),
            section(
                L['Arguments and returns'],
                L['Click an Arguments or Returns heading to collapse or expand it. + Argument and + Return append when clicked, or insert at a highlighted gap when dragged. Drag a row or use Up / Down to reorder; Ctrl-drag carries following rows. The trash can removes a row. Type and Nullable document accepted values; Description explains each input or result. Lua can return several ordered results. Return rows describe those results; moving them does not rewrite return statements. Reordering a saved function warns because positional callers may need changes; RM does not rewrite call sites.']
            ),
            section(
                L['Editing code'],
                L['Undo and Redo edit the Lua body. Reset restores the saved body or new-function template and can be undone. Check syntax executes no custom Lua. Apply saves the body and metadata together; Discard abandons the draft. Leaving with changes offers Apply, Discard or Cancel.']
            ),
            section(L['Function dependencies'], L['Help.Functions.bindings']),
            section(
                L['Import/Export'],
                L['Include custom function dependencies exports their source with the selected definition. Without it, the bundle records required helper identities and versions. Review source shows every imported Lua body. Resolve each original name and destination with Reuse, Replace or a new identifier. Apply import saves the complete reviewed bundle and can register imported Lua. Only apply code you trust.']
            ),
            section(L['Window controls'], L['Help.Window.controls']),
        }
    end

    local description = {
        General = L['Configure recommendation timing, automatic switching, history, preview and profile highlight defaults. Labels are on the left. Checkboxes toggle options, sliders show numeric values, and fields validate before saving.'],
        Conditions = L['Choose a category and search for a condition. Hidden removes it from pickers without deleting its definition. Switch Condition controls its availability for automatic rotation switching. Move To stages a category destination; its Apply button confirms the move. The assigned category opens category management. Sidebar arrows and dragging order entries. Page Apply saves the draft; Discard abandons edits to a saved entry. Custom conditions can be edited, duplicated or deleted.'],
        Effects = L['Select an effect to edit its name, type and type-specific settings. The icon previews it live. Sequence sections edit animation, color, pulse or custom frames in order. Duplicate creates an independent effect. Drag a sequence card surface to reorder it; fields remain editable. New effects can be configured before naming. Apply saves the draft; Discard abandons edits to a saved entry. Import stages a validated replacement.'],
        ItemSets = L['Choose an item set and edit its priority list. Global shares the set across profiles. Move arrows change item priority. Bind item set picks up an available item for placement on an action bar; The binding pill removes matching bound bar actions when unbinding, outside combat. Reset restores a packaged set. Search or drag items into reference fields. Apply saves settings; Discard abandons edits to a saved entry. Binding changes are explicit action-bar operations.'],
        Announces = L['Choose an announcement trigger, then edit its always expanded output cards. Each card has a destination, conditions, enabled state and Help. Add, duplicate, delete, move or drag outputs within the announcement. Joined channel names are available for Via Script/Macro. New opens a draft; Apply saves it and Discard restores it. Imports are validated and never execute code.'],
        Profiles = L['Select a profile in the sidebar to inspect it, then Activate profile to switch. New and Duplicate open a named draft with Apply and Cancel. Import stages a validated new profile; Compare shows setting differences. Copy and Reset replace the active profile after confirmation; the red trash deletes an inactive profile.'],
        About = L['Version, author, credits and project links are shown here. Click a link field to select its text for copying.'],
        Rotations = L['Search or filter the rotation roster, then select a rotation. Blue Built In rotations use the same editor but remain read-only; Duplicate makes an editable copy. The name and Metadata describe the rotation. Switch condition selects when it applies. Use the Rotation and Cooldowns tabs to select the content below the switch condition. Cooldowns highlight independently of the ordered rotation.'],
    }

    description.Integrations = L['Help.Integrations.overview']
    local result = { section(L['Using this page'], description[topic] or L['Optional addon settings.']) }

    if topic ~= 'Profiles' and topic ~= 'Rotations' and topic ~= 'About' then
        result[#result + 1] = section(
            L['Apply / Discard'],
            L['Edits stay in a draft until Apply. Discard abandons pending changes. Leaving with changes offers Apply, Discard or Cancel; Cancel keeps the page and draft open. Effect previews do not save changes. Action-bar binding operations are explicit and immediate.']
        )
    end

    if topic == 'General' and self.GetGeneralOptionHelp then
        for _, entry in ipairs(self:GetGeneralOptionHelp()) do
            result[#result + 1] = entry
        end
    end

    local authored = {
        Conditions = self.GetDocument_layout_conditions_options_help,
        Effects = self.GetDocument_layout_effects_options_help,
        ItemSets = self.GetDocument_layout_itemsets_options_help,
        Announces = self.GetDocument_layout_announce_options_help,
        Profiles = self.GetProfileOptionHelp,
        Integrations = self.GetIntegrationOptionHelp,
    }

    if authored[topic] then
        for _, entry in ipairs(authored[topic](self)) do
            result[#result + 1] = entry
        end
    end

    if topic == 'Rotations' then
        result[#result + 1] = section(
            L['Applies to'],
            L['Rotations belong to the active settings profile. New copies use Class, shared by your characters of that class; Metadata can change this to This character. Built In rotations show only for their declared class or universal use. Equal identifiers in different owners remain separate entries.']
        )

        result[#result + 1] = section(
            L['Recover unassigned rotations'],
            L['Older rotations without a recorded owner stay in an archive. Recover unassigned rotations opens the current profile and character archives for inspection or copying. Choose Class or This character to adopt one. Adoption preserves its identifier and evidence, refuses an existing destination, and leaves incomplete records unavailable until repaired.']
        )

        result[#result + 1] = section(
            L['Adopt several at once'],
            L['Adopt all and Adopt all from specialization adopt every listed record in one step, for the owner chosen under Applies to. Each record is adopted on its own, exactly as a single adoption would be: a record whose destination already exists, or that is incomplete, stays in the archive and is named in the result.']
        )

        result[#result + 1] = section(
            L['Navigating rotations'],
            L['Diagram / List changes only the rotation view; General settings choose the default. Diagram has floating minus, percentage and plus controls at the bottom right. Scroll to zoom from 25% to 200%; click the percentage or middle-click to reset to 100%. Drag empty diagram space to pan. List uses normal scrollbars with touching cards and boxed branch arms, False before True. Cooldowns use a separate scrolling grid. Dragging cards reorders them in every view. Valid rotation bodies can contain up to 2,000 total steps; large workspaces reuse nearby card controls as you navigate. Folded branches intentionally hide their children.']
        )

        for _, entry in ipairs(self:WorkbenchInteractionHelp('rotation')) do
            result[#result + 1] = entry
        end
    elseif topic == 'Announces' then
        result[#result + 1] = section(L['Editing settings'], L['Help.Announces.editing'])
    elseif topic ~= 'Profiles' and topic ~= 'About' then
        result[#result + 1] = section(
            L['Editing settings'],
            L['Press Enter or leave a text field to stage its value; Apply saves the draft. Invalid text stays red and must be corrected before Apply; Discard can abandon it. Searchable selectors open on click and filter as you type. Section headings collapse or expand their contents.']
        )
    end

    result[#result + 1] = section(L['Window controls'], L['Help.Window.controls'])
    return result
end

-- ============================================================================
-- The shared Help window
-- ============================================================================

-- Fills and shows the single shared Help window with `sections` under `heading`, optionally mounting a rendered
-- document below them (request.render). `request.current` retires the call if a newer one starts; with no request a
-- private one is made. Returns the window record, or nothing when the call was superseded or the mounted document
-- failed validation.
function addon:ShowWorkbenchHelp(heading, sections, owner, request)
    if not request then
        helpRequest = helpRequest + 1
        local token = helpRequest
        request = { current = function() return token == helpRequest end }
    end

    local current = request.current
    if not current() then return end
    local d = self.helpWindow

    if not d then
        d = { frame = CreateFrame('Frame', nil, UIParent), rows = {} }
        self.helpWindow = d
        local frame = d.frame
        frame:SetPoint('CENTER')
        frame:SetSize(540, 360)
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        addon:MakeWindowOpaque(frame)
        d.title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
        d.chrome = addon:CreateWorkbenchDialogChrome(frame, d.title)
        d.scroll = addon:CreateWorkbenchScrollFrame(frame)
        d.scroll:SetPoint('TOPLEFT', 12, -38)
        d.child = CreateFrame('Frame', nil, d.scroll)
        d.scroll:SetScrollChild(d.child)
        d.child:SetWidth(490)
        d.close = addon:CreateWorkbenchIconButton(frame, 'close', L['Close'])
        d.close:SetPoint('TOPRIGHT', -5, -5)

        local function hide()
            frame:Hide()
        end

        addon:SetUIScript(d.close, 'OnClick', hide)

        for _, surface in ipairs({ frame, d.scroll }) do
            addon:SetUIScript(surface, 'OnMouseUp', function(_, button)
                if button == 'RightButton' then hide() end
            end)
        end

        -- Releases the mounted document (if any) through its own Release under Diagnostics, clearing the fields first
        -- so a release that reopens Help cannot release it twice.
        function d:ReleaseMount()
            local mount, release, context = self.mount, self.mountRelease, self.mountContext
            self.mount = nil
            self.mountRelease = nil
            self.mountContext = nil
            if release then callHelpContext(context, release, mount) end
        end

        -- Registry-facing hide for the window.
        function d:Hide()
            frame:Hide()
        end

        frame:Hide()

        addon:SetUIScript(frame, 'OnHide', function()
            helpRequest = helpRequest + 1
            frame.rmHelpCurrent = nil
            d:ReleaseMount()
        end)

        addon.HideOnEscape(d)
    end

    d:ReleaseMount()
    if not current() then return end
    d.heading = heading
    d.sections = sections
    d.chrome:SetContext(heading, L['Help'], owner or addon.pretty_name or L['Rotation Master'])
    if not current() then return end
    local y = 0
    local n = 0

    for _, entry in ipairs(sections or {}) do
        for i, value in ipairs({ entry.title or '', entry.text or '' }) do
            n = n + 1
            local t = d.rows[n]

            if not t then
                t = d.child:CreateFontString(nil, 'OVERLAY', i == 1 and 'GameFontNormal' or 'GameFontHighlightSmall')
                d.rows[n] = t
            end

            t:SetFontObject(i == 1 and 'GameFontNormal' or 'GameFontHighlightSmall')
            t:ClearAllPoints()
            t:SetPoint('TOPLEFT', 0, -y)
            t:SetWidth(490)
            t:SetJustifyH('LEFT')
            t:SetWordWrap(true)
            t:SetText(value)
            t:SetTextColor(i == 1 and 1 or .85, i == 1 and .82 or .88, i == 1 and .2 or .9)
            t:SetHeight(0)
            t:SetHeight(math.max(16, t:GetStringHeight()))
            t:Show()
            y = y + t:GetHeight() + (i == 1 and 4 or 14)
        end
    end

    for i = n + 1, #d.rows do
        d.rows[i]:Hide()
    end

    if not current() then return end

    if request.render then
        local ok, mount = callHelpContext(request.renderContext, request.render, d.child, current, y, 490)
        local height, release

        -- Accessors may open newer Help: consume once before publishing ownership.
        local readable = ok and type(mount) == 'table' and callHelpContext(request.renderContext, function()
            release = mount.Release
            if current() then height = mount.height end
        end)

        if
            not readable
            or not current()
            or type(height) ~= 'number'
            or height ~= height
            or height < 0
            or height == math.huge
            or type(release) ~= 'function'
        then
            if type(release) == 'function' then callHelpContext(request.renderContext, release, mount) end
            if current() then d.frame:Hide() end
            return
        end

        d.mount = mount
        d.mountRelease = release
        d.mountContext = request.renderContext
        y = y + height
    end

    if not current() then return end
    d.child:SetHeight(math.max(1, y))
    local visible = math.min(300, math.max(100, y))
    d.frame:SetHeight(38 + visible + 28)
    d.scroll:SetSize(510, visible)
    d.chrome:LayoutTitle()
    d.frame.rmHelpCurrent = current
    d.frame:Show()
    d.scroll.workbenchBar:SetValue(0)
    d.scroll:UpdateWorkbenchScroll()
    addon:OpenPopup(d)
    return d
end

-- ============================================================================
-- Integration project links
-- ============================================================================

-- Release pages use their own small, pooled table; ordinary diagnostic reports
-- retain the full copyable report window and its independent selection.
-- Shows the provider, URL and copy buttons for integration `id` (links come from GetIntegrationProjectLinks). The URL
-- boxes are read-only in effect: any edit is reverted so the player can select and copy but never change a link.
-- Returns the window record, or nothing when the integration has no links.
function addon:ShowIntegrationProjectLink(id)
    if type(self.GetIntegrationProjectLinks) ~= 'function' then return end
    local links, name = self:GetIntegrationProjectLinks(id)
    if type(links) ~= 'table' or #links == 0 then return end
    local d = self.integrationProjectWindow

    if not d then
        d = { frame = CreateFrame('Frame', nil, UIParent), rows = {}, generation = 0 }
        self.integrationProjectWindow = d
        local frame = d.frame
        frame:SetPoint('CENTER')
        frame:SetSize(640, 140)
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        d.title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
        d.chrome = self:CreateWorkbenchDialogChrome(frame, d.title)

        -- Creates one column heading label at x across the top of the link table.
        local function heading(text, x, width)
            local label = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
            label:SetPoint('TOPLEFT', x, -36)
            label:SetWidth(width)
            label:SetHeight(18)
            label:SetJustifyH('LEFT')
            label:SetText(text)
            return label
        end

        d.providerHeading = heading(L['Provider'], 12, 148)
        d.urlHeading = heading(L['URL'], 172, 404)
        d.copyHeading = heading(L['Copy'], 584, 40)
        d.scroll = self:CreateWorkbenchScrollFrame(frame)
        d.scroll:SetPoint('TOPLEFT', 12, -58)
        d.scroll:SetWidth(616)
        d.child = CreateFrame('Frame', nil, d.scroll)
        d.child:SetWidth(600)
        d.scroll:SetScrollChild(d.child)
        d.close = self:CreateWorkbenchIconButton(frame, 'close', L['Close'])
        d.close:SetPoint('TOPRIGHT', -5, -5)
        addon:SetUIScript(d.close, 'OnClick', function() frame:Hide() end)

        -- Invalidates every row callback (generation bump) and clears the rows, so stale handlers do nothing.
        function d:Retire()
            self.generation = self.generation + 1
            self.active = false

            for _, row in ipairs(self.rows) do
                row.edit:ClearFocus()
                row.edit:HighlightText(0, 0)
                row.url = nil
                row.provider.tooltip = nil

                for _, event in ipairs({ 'OnTextChanged', 'OnEditFocusGained', 'OnMouseUp', 'OnEscapePressed' }) do
                    addon:SetUIScript(row.edit, event, nil)
                end

                addon:SetUIScript(row.copy, 'OnClick', nil)
                row.frame:Hide()
            end
        end

        addon:SetUIScript(frame, 'OnHide', function() d:Retire() end)

        -- Registry-facing hide and show for the window.
        function d:Hide()
            self.frame:Hide()
        end

        function d:Show()
            self.frame:Show()
        end

        addon.HideOnEscape(d)
    end

    d:Retire()
    d.active = true
    local token = d.generation

    -- True while this row still belongs to the call that populated it and is visible.
    local function current(row)
        return d.active and d.generation == token and row.url ~= nil and row.frame:IsShown()
    end

    -- Selects the whole URL of one row so Ctrl+C copies it, and drops the selection from every other row.
    local function selectRow(row)
        if not current(row) then return end

        for _, other in ipairs(d.rows) do
            if other ~= row then
                other.edit:ClearFocus()
                other.edit:HighlightText(0, 0)
            end
        end

        if not row.edit:HasFocus() then row.edit:SetFocus() end
        row.edit:SetCursorPosition(0)
        row.edit:HighlightText(0, -1)
    end

    local y = 0

    for i, entry in ipairs(links) do
        if i > 32 then break end
        local row = d.rows[i]

        if not row then
            row = { frame = CreateFrame('Frame', nil, d.child) }
            d.rows[i] = row
            row.frame:SetWidth(600)
            row.provider = self:CreateWorkbenchButton(row.frame, '', 148)
            row.provider.art:Hide()
            row.provider:SetPoint('LEFT', row.frame, 'LEFT', 0, 0)
            local label = row.provider:GetFontString()
            label:ClearAllPoints()
            label:SetPoint('LEFT')
            label:SetWidth(148)
            label:SetJustifyH('LEFT')
            label:SetJustifyV('MIDDLE')
            label:SetWordWrap(true)
            row.edit = self:CreateWorkbenchEditBox(row.frame)
            row.edit:SetPoint('LEFT', row.frame, 'LEFT', 160, 0)
            row.edit:SetSize(404, 24)
            row.edit:SetMultiLine(false)
            row.edit:SetMaxLetters(4096)
            row.copy = self:CreateWorkbenchIconButton(row.frame, 'copy', L['Select URL for copying (Ctrl+C)'])
            row.copy:SetPoint('LEFT', row.frame, 'LEFT', 576, 0)
        end

        row.url = entry.url
        row.provider:SetText(entry.label)
        row.provider.tooltip = entry.note
        local label = row.provider:GetFontString()
        label:SetHeight(0)
        local height = math.max(28, label:GetStringHeight() + 6)
        label:SetHeight(height - 4)
        row.provider:SetHeight(height - 4)
        row.frame:ClearAllPoints()
        row.frame:SetPoint('TOPLEFT', 0, -y)
        row.frame:SetHeight(height)
        row.frame:Show()
        row.edit:SetText(row.url)
        row.edit:SetCursorPosition(0)
        row.edit:HighlightText(0, 0)
        row.edit:ClearFocus()
        addon:SetUIScript(row.copy, 'OnClick', function() selectRow(row) end)
        addon:SetUIScript(row.edit, 'OnEditFocusGained', function() selectRow(row) end)

        addon:SetUIScript(row.edit, 'OnMouseUp', function(_, button)
            if button == 'LeftButton' then selectRow(row) end
        end)

        -- Native EditBoxes allow selection/copy; retain the canonical URL across
        -- typing, paste, deletion and cut without publishing any edited value.
        addon:SetUIScript(row.edit, 'OnTextChanged', function()
            if current(row) and row.edit:GetText() ~= row.url then
                row.edit:SetText(row.url)
                row.edit:SetCursorPosition(0)
                row.edit:HighlightText(0, -1)
            end
        end)

        addon:SetUIScript(row.edit, 'OnEscapePressed', function()
            if current(row) then d:Hide() end
        end)

        y = y + height + 4
    end

    d.child:SetHeight(math.max(1, y))
    d.scroll:SetHeight(math.min(240, y))
    d.scroll:SetVerticalScroll(0)
    d.frame:SetSize(640, 86 + math.min(240, y))
    d.chrome:SetContext(name or id, L['Links'], '')
    d.title:SetText(name or id)
    d:Show()
    self:OpenPopup(d)
    return d
end
