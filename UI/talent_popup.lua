local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)
local platform = addon.Platform

-- "Show talent tree": the talent tree of a class and specialization, shown for
-- the TALENT condition so a talent is chosen by clicking it. Two providers
-- (Platform/talent_tree.lua) serve Retail and Forever; docs/talent-selector.md
-- has the research behind them.
--   blizzard  Blizzard's own talent window in its view (inspect) mode, driven
--             with a loadout string for the wanted specialization and hero
--             tree. Blizzard draws the tree and every tooltip; RM adds a ring on
--             the selected talent and takes the click (EventRegistry
--             "TalentButton.OnClick"), then closes the window again.
--   drawn     RM's own tree from the node positions and edges the client
--             reports, with plain textures and GameTooltip:SetSpellByID, used
--             when Blizzard's window cannot be driven.
-- This window is the small control strip both share (specialization and hero
-- tree switchers, the current choice and the reason a tree cannot be shown); the
-- drawn provider also puts its tree in it.

local SELECTION, SUBTREE_SELECTION = 2, 3  -- Enum.TraitNodeType
local QUESTION = 'Interface\\Icons\\INV_Misc_QuestionMark'

local function readable(value)
    return platform:CanReadValue(value)
end

local function traitID(value)
    return readable(value) and type(value) == 'number' and value > 0 and value < 2147483648 and value % 1 == 0
end

-- Runs outside the click that asked for it (Blizzard's button handler).
local function after(fn)
    if C_Timer and type(C_Timer.After) == 'function' then
        C_Timer.After(0, fn)
    else
        fn()
    end
end

local function reasonText(why)
    if why == 'in-combat' then return L['The talent tree cannot be shown during combat.'] end
    if why == 'talent-window-busy' then return L['Finish or discard the changes in your own talent window first.'] end
    if why == 'talent-window-inspecting' then return L['Close the build shown in your own talent window first.'] end
    return L['The talent tree cannot be shown right now. Use the Talent list instead.']
end

local function field(object, method, ...)
    if type(object) ~= 'table' or type(object[method]) ~= 'function' then return nil end
    local ok, value = pcall(object[method], object, ...)
    if ok and readable(value) then return value end
end

-- The window ------------------------------------------------------------------
local endSession

local function getWindow()
    local d = addon.talentTreeWindow
    if d then return d end

    d = {
        frame = CreateFrame('Frame', nil, UIParent),
        specButtons = {},
        heroButtons = {},
        slots = {},
        lines = {},
        paneLabels = {},
        serial = 0,
    }

    addon.talentTreeWindow = d
    local frame = d.frame
    frame:SetSize(760, 150)
    frame:SetPoint('TOP', UIParent, 'TOP', 0, -40)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    addon:MakeWindowOpaque(frame)
    d.title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    d.chrome = addon:CreateWorkbenchDialogChrome(frame, d.title)
    d.close = addon:CreateWorkbenchIconButton(frame, 'close', L['Close'])
    d.close:SetPoint('TOPRIGHT', -5, -5)
    addon:SetUIScript(d.close, 'OnClick', function() frame:Hide() end)
    d.specLabel = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    d.specLabel:SetText(L['Specialization'])
    d.heroLabel = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    d.heroLabel:SetText(L['Hero Talents'])
    d.status = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    d.status:SetJustifyH('LEFT')
    d.status:SetJustifyV('TOP')
    d.canvas = CreateFrame('Frame', nil, frame)
    d.shade = d.canvas:CreateTexture(nil, 'BACKGROUND')
    d.shade:SetAllPoints(d.canvas)
    d.shade:SetColorTexture(.03, .035, .04, 1)
    d.background = d.canvas:CreateTexture(nil, 'BACKGROUND', nil, 1)
    d.background:SetAllPoints(d.canvas)
    d.background:SetAlpha(.7)
    d.background:Hide()
    d.content = CreateFrame('Frame', nil, d.canvas)
    d.canvas:Hide()
    addon:SetUIScript(frame, 'OnHide', function() endSession(d) end)
    frame:Hide()
    return d
end

local function visible(region, flag)
    if flag then
        region:Show()
    else
        region:Hide()
    end
end

local function bar(list, d, index, text, width)
    local button = list[index]

    if not button then
        button = addon:CreateWorkbenchButton(d.frame, '', width)
        list[index] = button
    end

    button:SetText(text)
    button:SetWidth(width)
    button:Show()
    return button
end

-- Places the switchers, the status line and (drawn tree) the canvas for the
-- provider in use, and sizes the window to fit.
local function layout(d)
    local frame, handle = d.frame, d.handle
    local width = 760
    if d.mode == 'drawn' then width = math.max(640, math.min(1240, (UIParent:GetWidth() or 1280) - 40)) end
    local y = -36
    local specs = d.request and d.request.specs
    local showSpecs = specs and #specs > 1
    d.specLabel:ClearAllPoints()
    d.specLabel:SetPoint('TOPLEFT', 12, y - 4)
    visible(d.specLabel, showSpecs)
    local x = 124

    for index, spec in ipairs(specs or {}) do
        if showSpecs then
            local button = bar(
                d.specButtons,
                d,
                index,
                spec.name or tostring(spec.id),
                math.max(70, #(spec.name or '') * 7 + 16)
            )

            button:ClearAllPoints()
            button:SetPoint('TOPLEFT', x, y)
            x = x + button:GetWidth() + 4
            button:SetSelected(handle ~= nil and handle.spec == spec.id)
            addon:SetUIScript(button, 'OnClick', function() d.OnSpec(spec.id) end)
        end
    end

    for index = (showSpecs and #specs or 0) + 1, #d.specButtons do
        d.specButtons[index]:Hide()
    end

    if showSpecs then y = y - 26 end
    local heroes = handle and handle.heroes or {}
    local showHeroes = #heroes > 0
    d.heroLabel:ClearAllPoints()
    d.heroLabel:SetPoint('TOPLEFT', 12, y - 4)
    visible(d.heroLabel, showHeroes)
    x = 124

    for index, hero in ipairs(heroes) do
        local button = bar(d.heroButtons, d, index, hero.name, math.max(90, #hero.name * 7 + 16))
        button:ClearAllPoints()
        button:SetPoint('TOPLEFT', x, y)
        x = x + button:GetWidth() + 4
        button:SetSelected(handle.hero == hero.id)
        addon:SetUIScript(button, 'OnClick', function() d.OnHero(hero.id) end)
    end

    for index = #heroes + 1, #d.heroButtons do
        d.heroButtons[index]:Hide()
    end

    if showHeroes then y = y - 26 end
    d.status:ClearAllPoints()
    d.status:SetPoint('TOPLEFT', 12, y)
    d.status:SetWidth(width - 24)
    d.status:SetHeight(30)
    y = y - 34

    if d.mode == 'drawn' then
        local height = math.max(420, math.min(820, (UIParent:GetHeight() or 800) - 80))
        d.canvasWidth, d.canvasHeight = width - 16, height + y - 26
        d.canvas:ClearAllPoints()
        d.canvas:SetPoint('TOPLEFT', frame, 'TOPLEFT', 8, y)
        d.canvas:SetSize(d.canvasWidth, d.canvasHeight)
        d.canvas:Show()
        frame:SetSize(width, height)
    else
        d.canvas:Hide()
        frame:SetSize(width, -y + 26)
    end
end

local function showStatus(d)
    local text

    if d.failure then
        text = reasonText(d.failure)
    elseif d.handle then
        text = L['Click a talent to choose it for this condition.']
        local name = d.request and d.request.selectionName
        if name then text = text .. '\n' .. string.format(L['Selected: %s'], name) end
    else
        text = ''
    end

    d.status:SetText(text)
end

-- The context a provider receives (Platform/talent_tree.lua).
local function context(d)
    local request, serial = d.request, d.serial
    local ctx = { spec = d.spec, hero = d.hero, selection = request.selection, specs = request.specs, window = d }

    function ctx.onSelect(selection)
        if d.serial ~= serial or not d.frame:IsShown() or d.chosen then return end
        d.chosen = true

        -- Not inside the click that chose it: Blizzard's handler is still running.
        after(function()
            if d.serial ~= serial then return end
            local callback = request.onSelect
            if callback then callback(selection) end
            if d.serial == serial then d.frame:Hide() end
        end)
    end

    function ctx.onClose()
        if d.serial == serial and d.frame:IsShown() then d.frame:Hide() end
    end

    return ctx
end

local function reload(d)
    if not d.handle then return end
    local ctx = context(d)
    local ok, done, why = pcall(d.handle.Reload, d.handle, ctx)

    if not ok or not done then
        d.failure = ok and why or 'talent-window-unavailable'
    else
        d.failure = nil
    end

    layout(d)
    showStatus(d)
end

function endSession(d)
    local handle, request = d.handle, d.request
    d.handle = nil
    d.request = nil
    d.serial = d.serial + 1
    d.chosen = nil
    d.mode = nil
    if handle then pcall(handle.Close, handle) end

    for _, slot in ipairs(d.slots) do
        slot:Hide()
    end

    if GameTooltip and d.tooltipOwner and GameTooltip:IsOwned(d.tooltipOwner) then GameTooltip:Hide() end
    if request and request.onClose then request.onClose() end
end

local function start(d)
    d.frame:ClearAllPoints()
    d.frame:SetPoint('TOP', UIParent, 'TOP', 0, -40)
    local ctx = context(d)
    local failure

    for _, provider in ipairs(platform:GetTalentTreeProviders()) do
        local ok, handle, why = pcall(provider.open, ctx)

        if ok and handle then
            d.handle, d.mode, d.failure = handle, provider.id, nil
            layout(d)
            showStatus(d)
            return true
        end

        failure = failure or (ok and why) or 'talent-window-unavailable'
    end

    d.handle, d.mode, d.failure = nil, nil, failure
    layout(d)
    showStatus(d)
    return false
end

-- request = { owner (any table, to tell whose tree this is), spec, hero, selection={node,entry,spell}, selectionName, name,
--   specs={{id,name,icon}}, onSelect(selection), onSpec(spec), onClose() }
function addon:OpenTalentTree(request)
    if type(request) ~= 'table' then return nil end
    local d = getWindow()
    if d.frame:IsShown() then d.frame:Hide() end
    d.request = request
    d.spec = request.spec
    d.hero = request.hero
    d.serial = d.serial + 1
    d.chosen = nil

    function d.OnSpec(spec)
        if not d.request or d.handle and d.handle.spec == spec then return end
        d.spec, d.hero = spec, nil
        if d.request.onSpec then d.request.onSpec(spec) end
        reload(d)
    end

    function d.OnHero(hero)
        if not d.request then return end
        d.hero = hero
        reload(d)
    end

    d.chrome:SetContext(L['Talent Tree'], L['Talent'], request.name or '')
    d.frame:Show()
    self:OpenPopup(d, request.owner)
    start(d)
    return d
end

function addon:CloseTalentTree(owner)
    local d = addon.talentTreeWindow
    if d and d.frame:IsShown() and (owner == nil or d.request and d.request.owner == owner) then d.frame:Hide() end
end

function addon:IsTalentTreeOpen()
    local d = addon.talentTreeWindow
    return d ~= nil and d.frame:IsShown() and d.request ~= nil
end

-- The condition's talent changed elsewhere (the Talent list): follow it.
function addon:RefreshTalentTree(owner, selection, name)
    local d = addon.talentTreeWindow
    if not d or not d.frame:IsShown() or not d.request or d.request.owner ~= owner then return end
    d.request.selection, d.request.selectionName = selection, name
    reload(d)
end

-- Provider: Blizzard's talent window in view mode ----------------------------------
local A  -- the one session

local function blizzardFrame()
    local frame = rawget(_G, 'PlayerSpellsFrame')

    if type(frame) ~= 'table' then
        local load = rawget(_G, 'PlayerSpellsFrame_LoadUI')

        if type(load) == 'function' then
            pcall(load)
            frame = rawget(_G, 'PlayerSpellsFrame')
        end
    end

    if type(frame) ~= 'table' or type(frame.TalentsFrame) ~= 'table' then return nil end

    for _, name in ipairs({
        'SetInspectString',
        'IsInspecting',
        'ClearInspectUnit',
        'GetTab',
        'SetTab',
        'IsShown',
        'Hide',
    }) do
        if type(frame[name]) ~= 'function' then return nil end
    end

    if type(frame.TalentsFrame.GetTalentButtonByNodeID) ~= 'function' then return nil end
    return frame, frame.TalentsFrame
end

local ring, watcher

local function ringFrame()
    if ring then return ring end
    ring = CreateFrame('Frame', nil, UIParent)
    ring:EnableMouse(false)
    addon.talentTreeRing = ring
    local glow = ring:CreateTexture(nil, 'BACKGROUND')
    glow:SetAllPoints(ring)
    glow:SetColorTexture(1, .82, 0, .18)

    for _, edge in ipairs({
        { from = 'TOPLEFT', to = 'TOPRIGHT', flat = true },
        { from = 'BOTTOMLEFT', to = 'BOTTOMRIGHT', flat = true },
        { from = 'TOPLEFT', to = 'BOTTOMLEFT' },
        { from = 'TOPRIGHT', to = 'BOTTOMRIGHT' },
    }) do
        local art = ring:CreateTexture(nil, 'OVERLAY')
        art:SetColorTexture(1, .82, 0, 1)
        art:SetPoint(edge.from, ring, edge.from)
        art:SetPoint(edge.to, ring, edge.to)

        if edge.flat then
            art:SetHeight(3)
        else
            art:SetWidth(3)
        end
    end

    ring:Hide()
    return ring
end

local function glow(button, flag)
    if type(button) == 'table' and type(button.SetGlowing) == 'function' then pcall(button.SetGlowing, button, flag) end
end

local function placeRing()
    if not A then return end
    local frame = ringFrame()
    local node = A.selection and A.selection.node
    local button = node and field(A.talents, 'GetTalentButtonByNodeID', node)

    if A.glowing and A.glowing ~= button then
        glow(A.glowing, false)
        A.glowing = nil
    end

    if type(button) == 'table' and field(button, 'IsShown') then
        frame:ClearAllPoints()
        frame:SetPoint('TOPLEFT', button, 'TOPLEFT', -5, 5)
        frame:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', 5, -5)
        frame:SetFrameStrata(button:GetFrameStrata())
        frame:SetFrameLevel(button:GetFrameLevel() + 20)
        frame:Show()
        glow(button, true)
        A.glowing = button
    else
        frame:Hide()
    end
end

-- What a clicked talent button stands for: node, the chosen entry of a choice
-- node, and the spell. Blizzard's choice entries answer for their base button.
local function identify(button)
    if type(button) ~= 'table' then return nil end
    local base = field(button, 'GetBaseButton') or button
    if A and field(base, 'GetTalentFrame') ~= A.talents then return nil end
    local node, entry, spell = field(base, 'GetNodeID'), field(button, 'GetEntryID'), field(button, 'GetSpellID')
    local info = field(base, 'GetNodeInfo')
    local kind = type(info) == 'table' and readable(info.type) and info.type or nil

    -- A node nobody bought has no active entry to name its spell: the tree knows it.
    if not traitID(spell) and kind ~= SELECTION and A and A.view and traitID(node) then
        local record = A.view.nodes[node]
        spell = record and record.entries[1] and platform:GetTraitEntrySpell(A.view.config, record.entries[1]) or nil
    end

    if not traitID(node) or not traitID(spell) or kind == SUBTREE_SELECTION or field(button, 'GetEntrySubTreeID') then
        return nil
    end

    if kind == SELECTION and not traitID(entry) then return nil end
    return { node = node, entry = kind == SELECTION and entry or nil, spell = spell }
end

local function onTalentClick(_, button, mouse)
    if not A or A.closing or mouse ~= 'LeftButton' then return end
    local ok, selection = pcall(identify, button)
    if not ok or not selection then return end
    local info = platform.GetSpellInfo and platform:GetSpellInfo(selection.spell)
    if info then selection.name, selection.icon = info.name, info.iconID end
    A.ctx.onSelect(selection)
end

local closeBlizzard

local function onWindowClosed()
    if not A or A.closing then return end
    -- The player closed Blizzard's window (Escape, the X): the session ends.
    local ctx = A.ctx
    A.external = true
    ctx.onClose()
end

local function registry()
    local events = rawget(_G, 'EventRegistry')

    if
        type(events) == 'table'
        and type(events.RegisterCallback) == 'function'
        and type(events.UnregisterCallback) == 'function'
    then
        return events
    end
end

local function showBlizzard(ctx)
    local frame, talents = A.frame, A.talents
    local view, why = platform:GetTraitView(ctx.spec, { ignoreInspect = true })
    if not view then return nil, why end
    local selection = ctx.selection and platform:FindTraitViewSelection(view, ctx.selection) or nil
    local hero

    for _, candidate in ipairs(view.heroes) do
        if candidate.id == ctx.hero then hero = candidate end
    end

    if not hero and selection and selection.hero then
        for _, candidate in ipairs(view.heroes) do
            if candidate.id == selection.hero then hero = candidate end
        end
    end

    hero = hero or view.heroes[1]
    local heroPick = hero and { node = hero.node, position = hero.position } or nil
    local selectionPick

    if selection and selection.position and (not selection.hero or hero and selection.hero == hero.id) then
        selectionPick = { node = selection.node, position = selection.position }
    end

    -- Most complete first. A loadout the client refuses (a talent whose path is
    -- not bought) falls back to the hero choice alone, then to the bare tree.
    local attempts = {}
    if selectionPick then attempts[#attempts + 1] = { heroPick, selectionPick } end
    if heroPick then attempts[#attempts + 1] = { heroPick } end
    attempts[#attempts + 1] = {}
    local level = platform:GetTraitViewLevel()
    local shown

    for _, picks in ipairs(attempts) do
        local text = platform:EncodeTraitView(view, picks)

        if text then
            pcall(frame.SetInspectString, frame, text, level)

            if field(frame, 'IsInspecting') then
                shown = true
                break
            end
        end
    end

    if not shown then return nil, 'talent-window-unavailable' end

    if not field(frame, 'IsShown') then
        local show = rawget(_G, 'ShowUIPanel')

        if type(show) == 'function' then
            pcall(show, frame)
        else
            pcall(frame.Show, frame)
        end
    end

    -- Above the RM windows (full-screen dialogs), with the control strip above Blizzard's window.
    local d = ctx.window
    addon:RaiseForeignWindow(frame, d)
    A.view, A.selection, A.heroID, A.ctx = view, selection, hero and hero.id or nil, ctx
    placeRing()

    if d and d.frame then
        d.frame:ClearAllPoints()
        d.frame:SetPoint('BOTTOM', frame, 'TOP', 0, 6)
        addon:OpenPopup(d, nil, { over = frame })
    end

    return true
end

function closeBlizzard()
    local session = A
    if not session or session.closing then return end
    session.closing = true
    local events = registry()

    if events then
        events:UnregisterCallback('TalentButton.OnClick', session)
        events:UnregisterCallback('TalentFrameBase.ButtonsUpdated', session)
        events:UnregisterCallback('PlayerSpellsFrame.CloseFrame', session)
    end

    if ring then ring:Hide() end
    if session.glowing then glow(session.glowing, false) end
    if session.watcher then session.watcher:UnregisterEvent('PLAYER_REGEN_DISABLED') end
    local frame = session.frame
    -- Leave Blizzard's window as it was: out of view mode, on its old tab and
    -- shown or hidden as before.
    if field(frame, 'IsInspecting') then pcall(frame.ClearInspectUnit, frame) end
    pcall(frame.SetFrameStrata, frame, session.strata or 'MEDIUM')

    if session.level and type(frame.SetFrameLevel) == 'function' then
        pcall(frame.SetFrameLevel, frame, session.level)
    end

    if session.external then
        -- Already closing by itself.
    elseif session.wasShown then
        if session.tab then pcall(frame.SetTab, frame, session.tab) end
    else
        local hide = rawget(_G, 'HideUIPanel')

        if type(hide) == 'function' then
            pcall(hide, frame)
        else
            pcall(frame.Hide, frame)
        end
    end

    A = nil
end

local blizzard = { families = { retail = true, forever = true }, priority = 10 }

-- Opt-in only: in the first real-client test Blizzard's view showed the player's own
-- purchased talents, greyed every row it counted as locked and gave no usable click
-- (docs/talent-selector.md section 3). Turn it on with
--   /run RotationMaster.db.global.talent_popup_provider='blizzard'
function blizzard.available()
    local db = addon.db
    local choice = db and db.global and db.global.talent_popup_provider

    return choice == 'blizzard'
        and platform:CanShowTraitViewLoadout()
        and (type(rawget(_G, 'PlayerSpellsFrame_LoadUI')) == 'function'
            or type(rawget(_G, 'PlayerSpellsFrame')) == 'table')
        and registry() ~= nil
end

function blizzard.open(ctx)
    if type(InCombatLockdown) == 'function' and InCombatLockdown() then return nil, 'in-combat' end
    if A then closeBlizzard() end
    local frame, talents = blizzardFrame()
    if not frame then return nil, 'talent-window-unavailable' end
    -- Someone else is looking at a build (a link, an inspected player), or the
    -- player has talent changes staged: leave their window alone.
    if field(frame, 'IsInspecting') then return nil, 'talent-window-busy' end
    local wasShown = field(frame, 'IsShown')
    if wasShown and field(talents, 'HasAnyConfigChanges') then return nil, 'talent-window-busy' end

    A = {
        frame = frame,
        talents = talents,
        wasShown = wasShown and true or false,
        tab = field(frame, 'GetTab'),
        strata = field(frame, 'GetFrameStrata'),
        level = field(frame, 'GetFrameLevel'),
    }

    local events = registry()
    events:RegisterCallback('TalentButton.OnClick', onTalentClick, A)
    events:RegisterCallback('TalentFrameBase.ButtonsUpdated', placeRing, A)
    events:RegisterCallback('PlayerSpellsFrame.CloseFrame', onWindowClosed, A)

    -- Entering combat ends the session: closing Blizzard's window in combat can fail,
    -- so it is closed before the lockdown if the client allows.
    if not watcher then
        watcher = CreateFrame('Frame')

        addon:SetUIScript(watcher, 'OnEvent', function()
            if A and not A.closing then A.ctx.onClose() end
        end)
    end

    watcher:RegisterEvent('PLAYER_REGEN_DISABLED')
    A.watcher = watcher
    local ok, why = showBlizzard(ctx)

    if not ok then
        closeBlizzard()
        return nil, why
    end

    local handle = {}

    local function describe()
        handle.heroes, handle.spec, handle.hero = A.view.heroes, A.view.spec, A.heroID
    end

    function handle.Reload(_, context)
        if not A then return nil, 'talent-window-unavailable' end
        if type(InCombatLockdown) == 'function' and InCombatLockdown() then return nil, 'in-combat' end
        local done, reason = showBlizzard(context)
        if done then describe() end
        return done, reason
    end

    function handle.Close()
        closeBlizzard()
    end

    describe()
    return handle
end

platform:RegisterTalentTreeProvider('blizzard', blizzard)

-- Provider: RM's own drawn tree ---------------------------------------------------
-- Blizzard's talent look from Blizzard's own art (the talents-node-* atlases and the
-- spec backgrounds), drawn without Blizzard's talent frame: the tree is read from
-- the trait API as it stands, so every talent shows as a choice that can be
-- clicked (the green "selectable" frame), nothing is greyed for locked rows, and
-- the player's own purchased talents are not shown at all. Where the client lacks
-- an atlas or a mask the plain textures below are used instead.
local NODE, HALF, GAP = 34, 24, 4
local PANE_GAP = 1500  -- tenths of a pixel: the empty strip between the class and specialization trees

local function atlasExists(name)
    return type(name) == 'string'
        and C_Texture
        and type(C_Texture.GetAtlasInfo) == 'function'
        and C_Texture.GetAtlasInfo(name) ~= nil
end

local function setAtlas(texture, name)
    if type(texture.SetAtlas) == 'function' and atlasExists(name) then
        local ok = pcall(texture.SetAtlas, texture, name, false)
        return ok
    end

    return false
end

-- Square for an ability, circle for a passive (Blizzard's SpendSquare / SpendCircle entry types).
local function shapeOf(entryType)
    local enum = rawget(_G, 'Enum')
    local kinds = type(enum) == 'table' and enum['TraitNodeEntryType'] or nil

    if type(kinds) == 'table' and (entryType == kinds['SpendSquare'] or entryType == kinds['SpendCapstoneSquare']) then
        return 'square'
    end

    return 'circle'
end

local function setEdges(slot, r, g, b, a)
    for _, edge in ipairs(slot.edges) do
        edge:SetColorTexture(r, g, b, a)
    end
end

local function paintSlot(slot)
    local selected = slot.selected

    if slot.fancy then
        setAtlas(slot.art, 'talents-node-' .. slot.shape .. (selected and '-yellow' or '-green'))

        if slot.hovered then
            slot.hover:Show()
        else
            slot.hover:Hide()
        end

        if selected then
            setEdges(slot, 1, .82, 0, 1)
        else
            setEdges(slot, 0, 0, 0, 0)
        end
    else
        if selected then
            setEdges(slot, 1, .82, 0, 1)
        elseif slot.hovered then
            setEdges(slot, .9, .95, 1, 1)
        else
            setEdges(slot, .38, .4, .42, 1)
        end
    end

    if selected then
        slot.glow:Show()
    else
        slot.glow:Hide()
    end
end

local function newSlot(d, index)
    local slot = CreateFrame('Button', nil, d.content)
    slot:RegisterForClicks('LeftButtonUp')
    slot.glow = slot:CreateTexture(nil, 'BACKGROUND')
    slot.glow:SetPoint('TOPLEFT', slot, 'TOPLEFT', -7, 7)
    slot.glow:SetPoint('BOTTOMRIGHT', slot, 'BOTTOMRIGHT', 7, -7)
    slot.glow:SetColorTexture(1, .82, 0, .28)
    slot.icon = slot:CreateTexture(nil, 'ARTWORK', nil, 1)
    slot.icon:SetPoint('CENTER')
    slot.art = slot:CreateTexture(nil, 'ARTWORK', nil, 3)
    slot.art:SetPoint('CENTER')
    slot.hover = slot:CreateTexture(nil, 'OVERLAY')
    slot.hover:SetPoint('CENTER')
    slot.hover:Hide()
    if type(slot.CreateMaskTexture) == 'function' then slot.mask = slot:CreateMaskTexture() end
    slot.edges = {}

    for _, edge in ipairs({
        { from = 'TOPLEFT', to = 'TOPRIGHT', flat = true },
        { from = 'BOTTOMLEFT', to = 'BOTTOMRIGHT', flat = true },
        { from = 'TOPLEFT', to = 'BOTTOMLEFT' },
        { from = 'TOPRIGHT', to = 'BOTTOMRIGHT' },
    }) do
        local art = slot:CreateTexture(nil, 'OVERLAY')
        art:SetPoint(edge.from, slot, edge.from)
        art:SetPoint(edge.to, slot, edge.to)

        if edge.flat then
            art:SetHeight(2)
        else
            art:SetWidth(2)
        end

        slot.edges[#slot.edges + 1] = art
    end

    slot.rank = slot:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    slot.rank:SetPoint('BOTTOMRIGHT', 3, -3)

    addon:SetUIScript(slot, 'OnEnter', function(self)
        self.hovered = true
        paintSlot(self)
        local data = self.data

        if data and GameTooltip then
            d.tooltipOwner = self
            GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')

            if data.spell and GameTooltip.SetSpellByID then
                pcall(GameTooltip.SetSpellByID, GameTooltip, data.spell)
            else
                GameTooltip:SetText(data.name or '')
            end

            if data.maxRanks and data.maxRanks > 1 then
                GameTooltip:AddLine(string.format(L['Ranks: %d'], data.maxRanks), 1, 1, 1)
            end

            if data.choice then GameTooltip:AddLine(L['Choose one of the talents on this node.'], .7, .7, .7) end

            GameTooltip:AddLine(
                self.selected and L['Click to clear this talent.'] or L['Click to choose this talent.'],
                .5,
                .8,
                .5
            )

            GameTooltip:Show()
        end
    end)

    addon:SetUIScript(slot, 'OnLeave', function(self)
        self.hovered = nil
        paintSlot(self)
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)

    addon:SetUIScript(slot, 'OnClick', function(self)
        local data = self.data
        if not data or not self.ctx then return end

        -- Clicking the chosen talent again clears the choice.
        if self.selected then
            self.ctx.onSelect(false)
        else
            self.ctx.onSelect({
                node = data.node,
                entry = data.entry,
                spell = data.spell,
                name = data.name,
                icon = data.icon,
            })
        end
    end)

    d.slots[index] = slot
    return slot
end

-- Sizes and art for one entry: full size for a talent, half size for either of a choice's two.
local function styleSlot(slot, size, shape)
    slot:SetSize(size, size)

    local fancy = atlasExists('talents-node-' .. shape .. '-green')
        and atlasExists('talents-node-' .. shape .. '-yellow')
        and atlasExists('talents-node-' .. shape .. '-greenglow')

    slot.fancy, slot.shape = fancy, shape
    local icon = fancy and size * .86 or size - 4
    slot.icon:SetSize(icon, icon)
    slot.art:SetSize(size * 1.3, size * 1.3)
    slot.hover:SetSize(size * 1.3, size * 1.3)

    if fancy then
        slot.art:Show()
        setAtlas(slot.hover, 'talents-node-' .. shape .. '-greenglow')
    else
        slot.art:Hide()
    end

    if slot.mask then
        if fancy and shape == 'circle' and setAtlas(slot.mask, 'talents-node-circle-mask') then
            slot.mask:ClearAllPoints()
            slot.mask:SetAllPoints(slot.icon)

            if not slot.masked then
                slot.icon:AddMaskTexture(slot.mask)
                slot.masked = true
            end
        elseif slot.masked then
            slot.icon:RemoveMaskTexture(slot.mask)
            slot.masked = false
        end
    end
end

local drawn = { families = { retail = true, forever = true }, priority = 50 }

function drawn.available()
    return platform:CanReadTraitTree()
end

local function label(d, index)
    local text = d.paneLabels[index]

    if not text then
        text = d.content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
        d.paneLabels[index] = text
    end

    return text
end

-- The class, hero and specialization panes: hero nodes are their own pane, and the
-- others split at the widest empty strip (the class tree on the left, the specialization's on the right).
local function panes(nodes, hero)
    local result = {}
    local plain, heroNodes = {}, {}

    for _, node in ipairs(nodes) do
        if node.hero and node.hero == hero then
            heroNodes[#heroNodes + 1] = node
        else
            plain[#plain + 1] = node
        end
    end

    table.sort(plain, function(a, b) return a.x < b.x end)
    local split, widest = nil, PANE_GAP

    for index = 2, #plain do
        local gap = plain[index].x - plain[index - 1].x
        if gap > widest then widest, split = gap, index end
    end

    local function box(list, kind)
        if #list == 0 then return end
        local low, high = list[1].x, list[1].x

        for _, node in ipairs(list) do
            low = math.min(low, node.x)
            high = math.max(high, node.x)
        end

        result[#result + 1] = { kind = kind, x = (low + high) / 2 }
    end

    if split then
        local left, right = {}, {}

        for index, node in ipairs(plain) do
            if index < split then
                left[#left + 1] = node
            else
                right[#right + 1] = node
            end
        end

        box(left, 'class')
        box(right, 'spec')
    else
        box(plain, 'tree')
    end

    box(heroNodes, 'hero')
    return result
end

local function draw(d, ctx)
    local view, why = platform:GetTraitView(ctx.spec)
    if not view then return nil, why end
    local selection = ctx.selection and platform:FindTraitViewSelection(view, ctx.selection) or nil
    local hero = ctx.hero
    if not hero and selection then hero = selection.hero end
    local known = false

    for _, candidate in ipairs(view.heroes) do
        if candidate.id == hero then known = true end
    end

    if not known then hero = view.heroes[1] and view.heroes[1].id or nil end
    local shownNodes = {}
    local minX, minY, maxX, maxY

    for _, id in ipairs(view.order) do
        local node = view.nodes[id]

        -- A hero tree's talents belong to the tree being shown even when the client
        -- marks them hidden until that hero tree is bought.
        if
            node
            and node.kind ~= SUBTREE_SELECTION
            and #node.entries > 0
            and (node.hero and node.hero == hero or not node.hero and node.visible)
        then
            shownNodes[#shownNodes + 1] = node
            minX = math.min(minX or node.x, node.x)
            maxX = math.max(maxX or node.x, node.x)
            minY = math.min(minY or node.y, node.y)
            maxY = math.max(maxY or node.y, node.y)
        end
    end

    if #shownNodes == 0 then return nil, 'talent-tree-unavailable' end
    local margin, top = NODE + 8, NODE + 30
    local width, height = (maxX - minX) / 10 + margin * 2, (maxY - minY) / 10 + margin + top
    local scale = math.max(.35, math.min(1.25, (d.canvasWidth or width) / width, (d.canvasHeight or height) / height))
    d.content:SetScale(scale)
    d.content:SetSize(width, height)
    d.content:ClearAllPoints()

    d.content:SetPoint(
        'TOPLEFT',
        d.canvas,
        'TOPLEFT',
        math.max(0, ((d.canvasWidth or width) - width * scale) / 2) / scale,
        -math.max(0, ((d.canvasHeight or height) - height * scale) / 2) / scale
    )

    -- The spec's own backdrop, when Blizzard's talent art is loaded.
    local backdrop
    local util = rawget(_G, 'ClassTalentUtil')

    if type(util) == 'table' and type(util.GetVisualsForSpecID) == 'function' and traitID(view.spec) then
        local ok, visuals = pcall(util.GetVisualsForSpecID, view.spec)

        backdrop = ok and type(visuals) == 'table' and type(visuals.background) == 'string' and visuals.background
            or nil
    end

    if backdrop and setAtlas(d.background, backdrop) then
        d.background:Show()
    else
        d.background:Hide()
    end

    local drawnAt = {}
    local used = 0

    for _, node in ipairs(shownNodes) do
        local cx, cy = (node.x - minX) / 10 + margin, (node.y - minY) / 10 + top
        drawnAt[node.id] = { cx, cy }
        local choice = node.kind == SELECTION and #node.entries > 1

        for position, entry in ipairs(node.entries) do
            used = used + 1
            local slot = d.slots[used] or newSlot(d, used)
            local identity = platform:GetTraitEntryIdentity(view.config, entry) or {}
            styleSlot(slot, choice and HALF or NODE, shapeOf(identity.entryType))
            slot:ClearAllPoints()
            local offset = choice and (position - (#node.entries + 1) / 2) * (HALF + GAP + 6) or 0
            slot:SetPoint('CENTER', d.content, 'TOPLEFT', cx + offset, -cy)
            slot.icon:SetTexture(identity.icon or QUESTION)

            slot.data = {
                node = node.id,
                entry = choice and entry or nil,
                spell = identity.spellID,
                name = identity.name,
                icon = identity.icon,
                maxRanks = node.maxRanks,
                choice = choice,
            }

            slot.ctx = ctx
            slot.rank:SetText(node.maxRanks > 1 and tostring(node.maxRanks) or '')
            slot.selected = selection ~= nil and selection.node == node.id and (not choice or selection.entry == entry)
            slot.hovered = nil
            paintSlot(slot)
            slot:Show()
        end
    end

    for index = used + 1, #d.slots do
        d.slots[index]:Hide()
        d.slots[index].data = nil
        d.slots[index].ctx = nil
    end

    -- Pane titles.
    local request = ctx.window and ctx.window.request
    local className = select(1, UnitClass('player'))
    local specName

    for _, spec in ipairs(request and request.specs or {}) do
        if spec.id == view.spec then specName = spec.name end
    end

    local heroName

    for _, candidate in ipairs(view.heroes) do
        if candidate.id == hero then heroName = candidate.name end
    end

    local titles = 0

    for _, pane in ipairs(panes(shownNodes, hero)) do
        titles = titles + 1
        local text = label(d, titles)

        local name = pane.kind == 'class' and className
            or pane.kind == 'spec' and specName
            or pane.kind == 'hero' and heroName
            or nil

        text:ClearAllPoints()
        text:SetPoint('TOP', d.content, 'TOPLEFT', (pane.x - minX) / 10 + margin, -8)
        text:SetText(name or '')
        text:Show()
    end

    for index = titles + 1, #d.paneLabels do
        d.paneLabels[index]:Hide()
    end

    -- Faint lines between talents that lead to one another (what each one requires).
    local lines = 0

    if d.content.CreateLine then
        for _, node in ipairs(shownNodes) do
            for _, target in ipairs(node.edges) do
                local from, to = drawnAt[node.id], drawnAt[target]

                if from and to then
                    lines = lines + 1
                    local line = d.lines[lines]

                    if not line then
                        line = d.content:CreateLine(nil, 'BACKGROUND')
                        line:SetThickness(3)
                        d.lines[lines] = line
                    end

                    line:SetColorTexture(.55, .58, .62, .55)
                    line:SetStartPoint('TOPLEFT', d.content, from[1], -from[2])
                    line:SetEndPoint('TOPLEFT', d.content, to[1], -to[2])
                    line:Show()
                end
            end
        end
    end

    for index = lines + 1, #d.lines do
        d.lines[index]:Hide()
    end

    return view, hero
end

function drawn.open(ctx)
    local d = ctx.window
    if type(InCombatLockdown) == 'function' and InCombatLockdown() then return nil, 'in-combat' end
    d.mode = 'drawn'
    d.frame:ClearAllPoints()
    d.frame:SetPoint('CENTER')
    layout(d)
    local handle = {}

    function handle.Reload(_, context)
        if type(InCombatLockdown) == 'function' and InCombatLockdown() then return nil, 'in-combat' end
        local view, hero = draw(d, context)
        if not view then return nil, hero end
        handle.heroes, handle.spec, handle.hero = view.heroes, view.spec, hero
        return true
    end

    function handle.Close()
        for _, slot in ipairs(d.slots) do
            slot:Hide()
            slot.data = nil
            slot.ctx = nil
        end

        for _, line in ipairs(d.lines) do
            line:Hide()
        end

        for _, text in ipairs(d.paneLabels) do
            text:Hide()
        end

        d.canvas:Hide()
    end

    local done, why = handle.Reload(nil, ctx)
    if not done then return nil, why end
    return handle
end

platform:RegisterTalentTreeProvider('drawn', drawn)
