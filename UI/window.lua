-- The window registry: one place that decides what is in front of what for every RM window, popup, prompt and menu, the
-- Escape target that closes only the frontmost one, window scale and opacity, and the shared dialog chrome (title bar,
-- drag, right-click close). Windows open through `addon:OpenPopup` and never set their own strata, frame level or
-- click-raise; the rules and layer map are in docs/architecture/window-layering.md. It must not move a protected
-- Blizzard frame in combat. Loaded from RotationMaster.toc after UI/controls.lua and before the windows that register
-- with it. Registry state lives in file locals, not saved data.
local addon_name, addon = ...
local scaledWindows = setmetatable({}, { __mode = 'k' })

-- ============================================================================
-- Scale and opacity
-- ============================================================================

-- Clamps a saved scale to the allowed 0.7 to 1.3 range (anything else reads as 1) and rounds it to two decimals.
-- @param value any  The saved scale.
-- @return number  The scale to use.
local function scaleValue(value)
    if type(value) ~= 'number' or value ~= value or value < .7 or value > 1.3 then
        return 1
    end

    return math.floor(value * 100 + .5) / 100
end

-- Returns the largest scale at which a frame still fits the screen: a window has a fixed size in its own units and is
-- drawn scale times larger, and a frame cannot be shrunk by SetClampedToScreen. The wanted scale is returned unchanged
-- when the frame sizes itself to the screen (`rmFitsOwnSize`, the resizable main window) or when a size is not known
-- yet; otherwise the smaller of the wanted scale and the scale at which the frame's width and height equal the
-- screen's, to two decimals and never below 0.5.
-- @param frame table  The window frame.
-- @param wanted number  The scale the player asked for.
-- @return number  The scale to apply.
local function fittedScale(frame, wanted)
    if frame.rmFitsOwnSize or not UIParent then
        return wanted
    end

    local fit = wanted

    for _, pair in ipairs({
        { UIParent.GetHeight, frame.GetHeight },
        { UIParent.GetWidth, frame.GetWidth },
    }) do
        local screen, size = pair[1] and pair[1](UIParent), pair[2] and pair[2](frame)

        if type(screen) == 'number' and type(size) == 'number' and screen > 0 and size > 0 then
            fit = math.min(fit, screen / size)
        end
    end

    if fit >= wanted then
        return wanted
    end

    return math.max(.5, math.floor(fit * 100 + 1e-6) / 100)
end

-- Applies the saved window scale (`db.global.uiScale`) to a frame parented to UIParent and remembers it so a later
-- scale change reaches it. The scale is reduced when the frame, at its current size, would not fit the screen (a 650
-- pixel window at 130 percent on a 768 pixel screen). Frames nested in another window keep their parent's scale.
-- @param frame table|nil  The window frame.
function addon:ApplyWorkbenchScale(frame)
    if frame and frame.GetParent and frame:GetParent() == UIParent and frame.SetScale then
        scaledWindows[frame] = true
        frame:SetScale(fittedScale(frame, scaleValue(self.db and self.db.global and self.db.global.uiScale)))
    end
end

-- Rescales every window that was registered for scaling (each still limited to what fits the screen); called when the
-- scale setting changes.
-- @param value number  The new scale setting.
function addon:ScaleWorkbenchWindows(value)
    for frame in pairs(scaledWindows) do
        frame:SetScale(fittedScale(frame, scaleValue(value)))
    end
end

-- Puts an opaque layer beneath a dialog's native art, so overlapping configuration windows stay readable. Apply only to
-- RM-owned dialogs.
-- @param widget table|nil  The dialog's widget table, or a bare frame.
function addon:MakeWindowOpaque(widget)
    local frame = widget and (widget.frame or widget)

    if not frame or not frame.CreateTexture then
        return
    end

    if not frame.rmOpaqueBackground then
        local background = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        background:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
        background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
        background:SetColorTexture(0.035, 0.045, 0.055, 1)
        frame.rmOpaqueBackground = background
    end

    if not widget.rmOpaqueActive and widget.frame then
        local original = widget.OnRelease
        local alpha = frame.GetAlpha and frame:GetAlpha() or 1
        local previousScale = frame.GetScale and frame:GetScale() or 1
        widget.rmOpaqueActive = true

        -- Undoes the opaque treatment when the widget is released: hides the background, restores alpha and scale,
        -- restores the original OnRelease and runs it.
        -- @param control table  The widget being released.
        -- @param ... any  The arguments passed on to the original release.
        -- @return any  What the original release returns.
        widget.OnRelease = function(control, ...)
            frame.rmOpaqueBackground:Hide()

            if frame.SetAlpha then
                frame:SetAlpha(alpha)
            end

            if scaledWindows[frame] then
                scaledWindows[frame] = nil
                frame:SetScale(previousScale)
            end

            control.rmOpaqueActive = nil
            control.OnRelease = original

            if original then
                return original(control, ...)
            end
        end
    end

    if frame.SetAlpha then
        frame:SetAlpha(1)
    end

    self:ApplyWorkbenchScale(frame)
    frame.rmOpaqueBackground:Show()
end

-- ============================================================================
-- Window layering registry
-- ============================================================================

-- Window layering -------------------------------------------------------------
-- ONE place decides what is in front of what; docs/architecture/window-layering.md
-- has the rules and the layer map. Every RM window, popup, prompt and menu is
-- an entry here. The client orders frames by (strata, level) only: a frame
-- level is global within a strata, not relative to a parent, and a window's
-- own level says nothing about its content, which can sit well above it.
--   * A popup is placed above everything that is open, measured from the
--     highest level in the other windows' CONTENT, never from their own level.
--   * A popup stays above the window that opened it (its opener) and above
--     everything inside that window, however the opener was raised since:
--     native click-raise (SetToplevel) lifts a clicked window over its child,
--     and the next sync puts the child back before it can be drawn.
--   * Every open goes through here, including one that re-shows a window that
--     is already visible (OnShow does not fire for that).
-- The Escape target below is the same registry: one proxy closes the
-- frontmost RM window, so one Escape never closes the window under it too.
local STRATA_RANK = {
    BACKGROUND = 1,
    LOW = 2,
    MEDIUM = 3,
    HIGH = 4,
    DIALOG = 5,
    FULLSCREEN = 6,
    FULLSCREEN_DIALOG = 7,
    TOOLTIP = 8,
}

local WINDOW_STRATA = 'FULLSCREEN_DIALOG'
-- Levels left between one window's content and the next window. The client
-- rejects levels above 10000; a stack that would pass the ceiling is compacted.
local LEVEL_GAP, LEVEL_FLOOR, LEVEL_CEILING = 10, 10, 8000
local escapeName = "RotationMasterFrontmostDialog"
local escapeProxyName = "RotationMasterEscapeTarget"
local dialogs = {}
local entryOf = setmetatable({}, { __mode = 'k' })
local watcher
local escapeProxy
local settling, compacting, needCompact, lastFront = false, false, false, nil
local serial = 0

-- Returns the frame for a widget table (its `.frame`) or for a bare frame.
-- @param value any  The widget or frame.
-- @return table|nil  The frame; nil for anything else.
local function frameOf(value)
    if type(value) ~= 'table' then
        return nil
    end
    if type(value.frame) == 'table' then
        return value.frame
    end
    if type(value.GetFrameLevel) == 'function' then
        return value
    end
end

-- Returns the frame level, or 0 for an object without one.
-- @param frame table  The frame.
-- @return number  The level.
local function levelOf(frame)
    return type(frame.GetFrameLevel) == 'function' and frame:GetFrameLevel() or 0
end

-- Returns the frame strata name, or MEDIUM for an object without one.
-- @param frame table  The frame.
-- @return string  The strata name.
local function strataOf(frame)
    return type(frame.GetFrameStrata) == 'function' and frame:GetFrameStrata() or 'MEDIUM'
end

-- Returns the numeric order of a strata name (0 for an unknown one) so strata can be compared.
-- @param strata string  The strata name.
-- @return number  The order, 1 (BACKGROUND) to 8 (TOOLTIP).
local function rank(strata)
    return STRATA_RANK[strata] or 0
end

-- Finds the registry entry for a widget or frame, walking up to 200 parents so any frame inside a registered window
-- resolves to that window.
-- @param value any  The widget or frame.
-- @return table|nil  The registry entry; nil when none is found.
local function entryFor(value)
    local frame = frameOf(value)

    for _ = 1, 200 do
        if not frame then
            return nil
        end

        local entry = entryOf[frame]

        if entry then
            return entry
        end

        frame = type(frame.GetParent) == 'function' and frame:GetParent() or nil
    end
end

-- Tells whether the entry's own frame is shown, whether or not its ancestors are.
-- @param entry table  The registry entry.
-- @return boolean  True when the frame is shown.
local function isShown(entry)
    return entry.frame:IsShown()
end

-- Tells whether an entry is drawn right now (the frame and every ancestor shown). Windows that only look shown, inside
-- a hidden pane, do not take part.
-- @param entry table  The registry entry.
-- @return boolean  True when drawn.
local function isVisible(entry)
    local frame = entry.frame

    if type(frame.IsVisible) == 'function' then
        return frame:IsVisible() and true or false
    end

    return frame:IsShown()
end

-- Tells whether a frame may be moved: never a protected Blizzard frame in combat; RM's own frames are not protected.
-- @param frame table  The frame.
-- @return boolean  True when it may be changed now.
local function touchable(frame)
    local locked = rawget(_G, 'InCombatLockdown')

    if type(locked) == 'function' and locked() and type(frame.IsProtected) == 'function' then
        local ok, protected = pcall(frame.IsProtected, frame)
        return ok and not protected
    end

    return true
end

-- Sets a frame level, clamped to `LEVEL_CEILING` (which flags a compaction), only when it differs and the frame may be
-- touched.
-- @param entry table  The registry entry.
-- @param level number  The wanted level.
local function setLevel(entry, level)
    local frame = entry.frame

    if level > LEVEL_CEILING then
        needCompact = true
        level = LEVEL_CEILING
    end

    if levelOf(frame) ~= level and type(frame.SetFrameLevel) == 'function' and touchable(frame) then
        frame:SetFrameLevel(level)
    end
end

-- Sets the frame strata only when it differs and the frame may be touched.
-- @param entry table  The registry entry.
-- @param strata string  The wanted strata.
local function setStrata(entry, strata)
    local frame = entry.frame

    if strataOf(frame) ~= strata and type(frame.SetFrameStrata) == 'function' and touchable(frame) then
        frame:SetFrameStrata(strata)
    end
end

-- Returns the highest level among a frame and its descendants in one strata. A nested window (a registered frame inside
-- this one) places itself and is skipped when pruned.
-- @param frame table  The frame.
-- @param strata string  The strata to look at.
-- @param pruned boolean  True skips nested registered windows.
-- @return number  The highest level.
local function topOf(frame, strata, pruned)
    local top = levelOf(frame)

    -- Visits the descendants of a node (depth limited to 64) and raises `top` to the highest level found in the strata,
    -- skipping nested registered windows when `pruned`.
    -- @param node table  The frame to visit.
    -- @param depth number  The current depth.
    local function walk(node, depth)
        if depth > 64 or type(node.GetChildren) ~= 'function' then
            return
        end

        for _, child in ipairs({ node:GetChildren() }) do
            if not (pruned and entryOf[child]) then
                if strataOf(child) == strata then
                    local level = levelOf(child)

                    if level > top then
                        top = level
                    end
                end

                walk(child, depth + 1)
            end
        end
    end

    walk(frame, 0)
    return top
end

-- Returns the highest level used by a window's own content, ignoring nested registered windows, which place themselves.
-- @param entry table  The registry entry.
-- @return number  The highest level.
local function extentOf(entry)
    return topOf(entry.frame, strataOf(entry.frame), true)
end

-- Tells whether `other` is opened by `entry` (directly or through a chain) or sits inside its frame.
-- @param other table  The candidate entry.
-- @param entry table  The owning entry.
-- @return boolean  True when it belongs to the entry.
local function belongsTo(other, entry)
    local current, hops = other.opener, 0

    while current and hops < 24 do
        if current == entry then
            return true
        end

        current, hops = current.opener, hops + 1
    end

    local frame = type(other.frame.GetParent) == 'function' and other.frame:GetParent() or nil

    for _ = 1, 200 do
        if not frame then
            return false
        end
        if frame == entry.frame then
            return true
        end

        frame = type(frame.GetParent) == 'function' and frame:GetParent() or nil
    end

    return false
end

-- Returns the nearest opener in the chain that is still open: closing a menu or a hidden-for-child owner hands its
-- popups to the window beneath it.
-- @param entry table  The registry entry.
-- @return table|nil  The opener's entry; nil when none is open.
local function liveOpener(entry)
    local current, hops = entry.opener, 0

    while current and hops < 24 do
        if isVisible(current) then
            return current
        end

        current, hops = current.opener, hops + 1
    end
end

-- Returns the strata an entry needs: its own, raised to the strata of its opener or of any foreign frame it must clear.
-- @param entry table  The registry entry.
-- @param opener table|nil  The entry's live opener.
-- @return string  The strata name.
local function wantedStrata(entry, opener)
    local want = entry.strata

    if opener and rank(strataOf(opener.frame)) > rank(want) then
        want = strataOf(opener.frame)
    end

    for _, foreign in ipairs(entry.over) do
        if rank(strataOf(foreign)) > rank(want) then
            want = strataOf(foreign)
        end
    end

    return want
end

local updateEscapeTarget

-- Compacts the level stack: assigns the shown windows' levels again from the floor upward in their current order, each
-- separated from the next by the extent of its content plus a gap. Used when a level reached the ceiling.
local function compact()
    needCompact = false
    local order = {}

    for _, entry in ipairs(dialogs) do
        if entry.layered and isVisible(entry) then
            order[#order + 1] = entry
        end
    end

    table.sort(order, function(a, b)
        local first, second = levelOf(a.frame), levelOf(b.frame)

        if first ~= second then
            return first < second
        end

        return a.serial < b.serial
    end)

    local cursor = LEVEL_FLOOR

    for _, entry in ipairs(order) do
        local span = extentOf(entry) - levelOf(entry.frame)
        setLevel(entry, cursor)
        cursor = cursor + span + LEVEL_GAP
    end

    needCompact = false
end

-- Restores the order: every shown popup ends up above its opener's content and above the foreign frames it must clear,
-- lifting only what is out of order and keeping the relative order of what moved. Re-entrant calls return at once; when
-- a level hit the ceiling it compacts the stack and settles again. Cheap when nothing is out of order, so it also runs
-- whenever the frontmost window changes (a click raised one natively).
local function settle()
    if settling then
        return
    end

    settling = true
    local order = {}

    for _, entry in ipairs(dialogs) do
        if entry.layered and isVisible(entry) then
            order[#order + 1] = entry
        end
    end

    table.sort(order, function(a, b)
        local first, second = levelOf(a.frame), levelOf(b.frame)

        if first ~= second then
            return first < second
        end

        return a.serial < b.serial
    end)

    local done, lifted = {}, 0

    -- Places one entry above its opener (placed first, recursively) and above the foreign frames it must clear.
    -- @param entry table  The registry entry.
    -- @param depth number  The recursion depth (the opener chain is followed at most 24 deep).
    local function fix(entry, depth)
        if done[entry] then
            return
        end

        done[entry] = true
        local opener = depth <= 24 and liveOpener(entry) or nil
        local need = 0

        if opener then
            fix(opener, depth + 1)
            need = extentOf(opener) + LEVEL_GAP
        end

        for _, foreign in ipairs(entry.over) do
            local value = topOf(foreign, strataOf(foreign), false) + LEVEL_GAP

            if value > need then
                need = value
            end
        end

        if need == 0 then
            return
        end

        setStrata(entry, wantedStrata(entry, opener))

        if levelOf(entry.frame) < need then
            if lifted + LEVEL_GAP > need then
                need = lifted + LEVEL_GAP
            end

            setLevel(entry, need)
            lifted = extentOf(entry)
        end
    end

    for _, entry in ipairs(order) do
        fix(entry, 0)
    end

    settling = false

    if needCompact and not compacting then
        compacting = true
        compact()
        settle()
        compacting = false
        needCompact = false
    end
end

-- Returns the highest level occupied by any other open window's content (and by any foreign frame this one must clear).
-- Windows this one opened, or that sit inside it, move with it and do not count.
-- @param entry table  The registry entry.
-- @return number  The highest level.
local function frontLevel(entry)
    local top = 0

    for _, other in ipairs(dialogs) do
        if other ~= entry and other.layered and isVisible(other) and not belongsTo(other, entry) and strataOf(
            other.frame
        )
            == strataOf(entry.frame) then
            local value = extentOf(other)

            if value > top then
                top = value
            end
        end
    end

    for _, foreign in ipairs(entry.over) do
        local value = topOf(foreign, strataOf(foreign), false)

        if value > top then
            top = value
        end
    end

    return top
end

-- Works out who opened this window: an explicit opener, the window it is nested in, or (only when it is first shown,
-- and never for a peer window) the frontmost window that was open. The first two are firm. The last is a guess (the
-- window the user was in), so it holds only until that window is itself opened again: showing a window again brings it
-- in front of the popups guessed to belong to it. Peers never constrain each other.
-- @param entry table  The registry entry; its opener and guessed fields are set.
-- @param opening boolean  True when the window is being opened (a guess is allowed).
local function resolveOpener(entry, opening)
    local opener = entry.hint and entryFor(entry.hint)

    if not opener then
        local parent = type(entry.frame.GetParent) == 'function' and entry.frame:GetParent() or nil
        opener = parent and entryFor(parent)
    end

    local guessed = false

    if not opener and opening and entry.kind ~= 'window' then
        guessed = true
        local best

        for _, other in ipairs(dialogs) do
            if
                other ~= entry
                and other.layered
                and isVisible(other)
                and not belongsTo(other, entry)
                and (not best or levelOf(other.frame) >= levelOf(best.frame))
            then
                best = other
            end
        end

        opener = best
    end

    if opener == entry or opener and belongsTo(opener, entry) then
        opener = nil
    end

    if opener or opening or entry.hint then
        entry.opener = opener
        entry.guessed = opener ~= nil and guessed
    end
end

-- Releases the popups that were only guessed to belong to a window, when the window is opened again.
-- @param entry table  The window's registry entry.
local function releaseGuessed(entry)
    for _, other in ipairs(dialogs) do
        if other.guessed and other.opener == entry then
            other.opener = nil
            other.guessed = false
        end
    end
end

-- Brings one window to the front of everything open and keeps its own popups, and its opener's chain, in order.
-- @param entry table  The registry entry.
-- @param opening boolean  True when the window is being opened.
local function present(entry, opening)
    local frame = entry.frame

    if not entry.layered then
        updateEscapeTarget(true)
        return
    end

    -- The first placement after a hide is an opening, however it was reached.
    resolveOpener(entry, opening or not entry.placed)
    entry.placed = true
    setStrata(entry, wantedStrata(entry, liveOpener(entry)))
    local floor = frontLevel(entry)

    if levelOf(frame) <= floor then
        -- Let the client act first (it also clears frames outside RM), then guarantee the order.
        if type(frame.Raise) == 'function' and touchable(frame) then
            frame:Raise()
        end
        if levelOf(frame) <= floor then
            setLevel(entry, floor + LEVEL_GAP)
        end
    end

    settle()
    updateEscapeTarget(true)
end

-- Makes one pass over the registry.
-- @return table|nil  The Escape target frame (the highest shown Escape window).
-- @return table|nil  The Escape target's entry.
-- @return table|nil  The frontmost layered entry.
-- @return boolean|nil  True when a foreign panel it must clear was raised above it by a click.
local function scan()
    local target, level, selected, front, frontValue, foreignRaised

    for _, entry in ipairs(dialogs) do
        if entry.frame:IsShown() then
            local current = entry.frame:GetFrameLevel()

            if entry.escape and (not level or current >= level) then
                target, level, selected = entry.frame, current, entry
            end
            if entry.layered and (not frontValue or current >= frontValue) then
                front, frontValue = entry, current
            end

            -- A foreign panel it must clear (Blizzard's) was raised by a click: not a registry change.
            for _, foreign in ipairs(entry.over) do
                if levelOf(foreign) >= current then
                    foreignRaised = true
                end
            end
        end
    end

    return target, selected, front, foreignRaised
end

-- Recomputes the Escape target and publishes it (`RotationMasterFrontmostDialog`, the proxy frame, and the watcher's
-- visibility). Unless `settled`, a change of frontmost window or a raised foreign panel triggers `settle()` first, so a
-- native click-raise is undone before the frame is drawn.
-- @param settled boolean|nil  True when the order was just restored by the caller.
function updateEscapeTarget(settled)
    local target, selected, front, foreignRaised = scan()

    -- A click raised a different window natively, or a foreign panel: restore the order before anything is drawn.
    if not settled and (front ~= lastFront or foreignRaised) then
        settle()
        target, selected, front = scan()
    end

    lastFront = front
    _G[escapeName] = target

    if escapeProxy then
        escapeProxy.target = selected
        escapeProxy.syncing = true

        if target then
            escapeProxy:Show()
        else
            escapeProxy:Hide()
        end

        escapeProxy.syncing = false
    end

    if watcher then
        if target then
            watcher:Show()
        else
            watcher:Hide()
        end
    end
end

-- Drops an entry from the registry list.
-- @param entry table  The registry entry.
local function remove(entry)
    for index, current in ipairs(dialogs) do
        if current == entry then
            table.remove(dialogs, index)
            break
        end
    end
end

-- Creates, once, the proxy frame registered in UISpecialFrames and the OnUpdate watcher.
-- @return boolean  False on a client without UISpecialFrames; otherwise true.
local function ensureEscape()
    if type(UISpecialFrames) ~= "table" then
        return false
    end

    local registered = false

    for _, name in pairs(UISpecialFrames) do
        if name == escapeProxyName then
            registered = true
            break
        end
    end

    if not registered then
        UISpecialFrames[#UISpecialFrames + 1] = escapeProxyName
    end

    if not escapeProxy then
        -- CloseSpecialWindows hides its registered Frame directly. A private
        -- proxy routes that request through the owner's guarded Hide method.
        escapeProxy = CreateFrame('Frame', escapeProxyName, UIParent)
        _G[escapeProxyName] = escapeProxy
        escapeProxy:EnableMouse(false)
        escapeProxy.syncing = true
        escapeProxy:Hide()
        escapeProxy.syncing = false

        -- Hides the Escape target through its owner's guarded Hide method when the game's special-frame close hides the
        -- proxy (CloseSpecialWindows hides its registered Frame directly; the proxy routes that request to the owner).
        escapeProxy:SetScript('OnHide', function()
            if escapeProxy.syncing or escapeProxy.closing then
                return
            end

            local target = escapeProxy.target
            escapeProxy.closing = true

            if target then
                if type(target.widget.Hide) == 'function' then
                    target.widget:Hide()
                else
                    target.frame:Hide()
                end
            end

            escapeProxy.closing = false
            updateEscapeTarget()
        end)
    end

    if not watcher then
        watcher = CreateFrame("Frame", nil, UIParent)

        -- Native SetToplevel can raise any already-shown window on a child
        -- click without OnShow. Observe only RM roots while they are open.
        watcher:SetScript("OnUpdate", function()
            updateEscapeTarget()
        end)
    end

    return true
end

-- Registers a window with the layer registry (and optionally the Escape target). Idempotent: returns the existing
-- entry. Does not place it.
-- @param widget table  The widget table, or a bare frame.
-- @param options table  escape (false for a window that is not an Escape target), layer (false opts out of ordering),
-- strata and kind.
-- @return table|nil  The registry entry; nil when the value is not a frame.
local function register(widget, options)
    local frame = widget and (widget.frame or widget)

    if type(frame) ~= 'table' or not frame.GetScript or not frame.IsShown then
        return nil
    end

    local wantEscape = options.escape ~= false
    -- A frame is one entry however many throwaway widget tables name it.
    local entry = widget.rmLayerEntry or entryOf[frame]

    if entry then
        if wantEscape and not entry.escape and ensureEscape() then
            entry.escape = true
            frame.rmEscapeOwner = widget
        end

        return entry
    end

    serial = serial + 1
    -- A frame already above the window strata (a drag ghost) keeps its own; layer=false opts out of ordering entirely.
    local current = strataOf(frame)

    entry = {
        frame = frame,
        widget = widget,
        level = levelOf(frame),
        originalStrata = current,
        serial = serial,
        over = {},
        layered = options.layer ~= false,
        strata = options.strata
            or widget.rmLayerStrata
            or rank(current) > rank(WINDOW_STRATA) and current
            or WINDOW_STRATA,
        kind = options.kind or widget.rmLayerKind or 'popup',
    }

    if wantEscape and ensureEscape() then
        entry.escape = true
        frame.rmEscapeOwner = widget
    end

    widget.rmLayerEntry = entry
    entryOf[frame] = entry
    dialogs[#dialogs + 1] = entry

    if entry.layered then
        setStrata(entry, entry.strata)
    end

    -- Click-raise belongs to windows that hang from UIParent; the registry
    -- puts any popup its opened back above it (see updateEscapeTarget).
    if
        entry.layered
        and type(frame.SetToplevel) == 'function'
        and type(frame.GetParent) == 'function'
        and frame:GetParent() == UIParent
    then
        frame:SetToplevel(true)
    end

    local onShow, onHide = frame:GetScript("OnShow"), frame:GetScript("OnHide")

    -- Wraps the window's OnShow: applies the scale, runs the original script and places the window.
    -- @param self table  The frame being shown.
    -- @param ... any  The arguments passed on to the original script.
    local show = function(self, ...)
        addon:ApplyWorkbenchScale(self)

        if onShow then
            onShow(self, ...)
        end

        if widget.rmLayerEntry == entry then
            releaseGuessed(entry)
            present(entry, true)
        end
    end

    -- Wraps the window's OnHide: runs the original script, forgets the opener hint and foreign frames, and updates the
    -- Escape target.
    -- @param self table  The frame being hidden.
    -- @param ... any  The arguments passed on to the original script.
    local hide = function(self, ...)
        if onHide then
            onHide(self, ...)
        end

        entry.hint = nil
        entry.over = {}
        entry.placed = false
        updateEscapeTarget()
    end

    frame:SetScript("OnShow", show)
    frame:SetScript("OnHide", hide)
    local release = widget.OnRelease

    -- Unregisters the window when the widget is released: removes the entry, restores the scripts, level and strata,
    -- hands its popups to its opener and then runs the original release.
    -- @param control table  The widget being released.
    -- @param ... any  The arguments passed on to the original release.
    -- @return any  What the original release returns.
    widget.OnRelease = function(control, ...)
        remove(entry)
        entryOf[frame] = nil
        control.rmLayerEntry = nil
        control.OnRelease = release

        for _, other in ipairs(dialogs) do
            if other.opener == entry then
                other.opener = entry.opener
            end
        end

        if frame:GetScript("OnShow") == show then
            frame:SetScript("OnShow", onShow)
        end
        if frame:GetScript("OnHide") == hide then
            frame:SetScript("OnHide", onHide)
        end

        frame:SetFrameLevel(entry.level)
        frame:SetFrameStrata(entry.originalStrata)

        if lastFront == entry then
            lastFront = nil
        end

        updateEscapeTarget()

        if release then
            return release(control, ...)
        end
    end

    return entry
end

-- ============================================================================
-- Public API
-- ============================================================================

-- Opens (or re-opens) a window: registers it once, then places it above everything open and above its opener. Call
-- after every Show, including one that re-shows a window that is already visible.
-- @param widget table  The window widget or frame.
-- @param opener table|nil  A frame or widget inside the window that opened it.
-- @param options table|nil  over (foreign frames it must clear, e.g. Blizzard panels it was opened over), kind
--   ('window'
-- for a peer window) and escape (false for a window that is not an Escape target).
-- @return boolean  False when the value cannot be registered; otherwise true.
function addon:OpenPopup(widget, opener, options)
    options = options or {}
    local entry = register(widget, options)

    if not entry then
        return false
    end

    if opener then
        entry.hint = opener
    end

    releaseGuessed(entry)

    if options.over then
        entry.over = {}

        for _, foreign in ipairs(
            type(options.over) == 'table' and not options.over.GetFrameLevel and options.over or { options.over }
        ) do
            entry.over[#entry.over + 1] = foreign
        end
    end

    if isShown(entry) then
        present(entry, false)
    end

    return true
end

-- Brings a window to the front when the user (or a command) wants it: it and the whole chain of windows that opened it
-- come forward, their popups staying above them.
-- @param widget table  The window widget or frame.
-- @return boolean  True when it was raised; false when it is not a shown registered window.
function addon:RaiseWindow(widget)
    local entry = entryFor(widget)

    if not entry or not isShown(entry) then
        return false
    end

    local root, hops = entry, 0

    while hops < 24 do
        local up = liveOpener(root)

        if not up then
            break
        end

        root, hops = up, hops + 1
    end

    present(root, false)
    return true
end

-- Puts a foreign frame (a Blizzard panel this addon opened) in front of every RM window except one (the popup that must
-- stay above it).
-- @param frame table  The foreign frame.
-- @param except any  The popup (widget or frame) that must stay above it.
-- @return boolean  False when it may not be moved (not a frame, or protected in combat); otherwise true.
function addon:RaiseForeignWindow(frame, except)
    if type(frame) ~= 'table' or not touchable(frame) then
        return false
    end

    local excluded = entryFor(except)
    local top = 0

    for _, entry in ipairs(dialogs) do
        if
            entry ~= excluded and entry.layered and isVisible(entry) and not (excluded and belongsTo(entry, excluded))
        then
            local value = extentOf(entry)

            if value > top then
                top = value
            end
        end
    end

    if rank(strataOf(frame)) < rank(WINDOW_STRATA) and type(frame.SetFrameStrata) == 'function' then
        pcall(frame.SetFrameStrata, frame, WINDOW_STRATA)
    end
    if levelOf(frame) <= top and type(frame.SetFrameLevel) == 'function' then
        pcall(frame.SetFrameLevel, frame, math.min(LEVEL_CEILING, top + LEVEL_GAP))
    end

    return true
end

-- Returns the layer registry in registration order (a test and diagnostics hook).
-- @return table[]  The windows, each { frame, widget, kind, escape, opener, shown }.
function addon:GetWindowLayers()
    local result = {}

    for _, entry in ipairs(dialogs) do
        result[#result + 1] = {
            frame = entry.frame,
            widget = entry.widget,
            kind = entry.kind,
            escape = entry.escape,
            opener = entry.opener and entry.opener.frame or nil,
            shown = isShown(entry),
        }
    end

    return result
end

-- Performs one frame of the sync the Escape watcher performs (tests drive it directly).
function addon:SyncWindowLayers()
    updateEscapeTarget()
end

-- Registers a window as an Escape target only (the compatibility entry used by `addon.HideOnEscape`) and places it if
-- it is already shown.
-- @param widget table  The window widget or frame.
-- @return boolean  True when it is an Escape target.
function addon:RegisterWindowForEscape(widget)
    local frame = widget and (widget.frame or widget)

    if frame then
        frame.rmEscapeOwner = widget
    end

    local entry = register(widget, { escape = true })

    if not entry then
        return false
    end

    if isShown(entry) then
        present(entry, false)
    end

    return entry.escape == true
end

-- ============================================================================
-- Dialog chrome
-- ============================================================================

-- Closes the window on a right click inside it, when it is the frontmost registered window; also closes it when its
-- owner-bound Help has gone away. A click whose pointer is over a control flagged `rmOwnsRightClick` (reference fields,
-- the spell icon) is left to that control. Installs a polling watcher (one per frame, idempotent).
-- @param frame table  The dialog frame.
--
-- Child editors share the main workbench chrome without navigation tabs.
function addon:EnableWorkbenchRightClickClose(frame)
    if frame.rmRightClickWatcher then
        return
    end

    local watcher = CreateFrame('Frame', nil, frame)
    frame.rmRightClickWatcher = watcher
    watcher:EnableMouse(false)
    local rightDown = IsMouseButtonDown and IsMouseButtonDown('RightButton') or false
    local onShow = frame:GetScript('OnShow')

    addon:SetUIScript(frame, 'OnShow', function(...)
        rightDown = IsMouseButtonDown and IsMouseButtonDown('RightButton') or false

        if onShow then
            onShow(...)
        end
    end)

    -- Per-frame check: retires the window when its owner-bound Help is gone, and closes it on a new right click inside
    -- it (through its owner's Hide when it has one).
    addon:SetUIScript(watcher, 'OnUpdate', function()
        -- The existing visible-dialog observer also retires owner-bound Help.
        local current = frame.rmHelpCurrent

        if current then
            local ok, live = pcall(current)

            if (not ok or not live) and frame.rmHelpCurrent == current then
                frame:Hide()
                return
            end
        end

        local down = IsMouseButtonDown and IsMouseButtonDown('RightButton') or false

        if down and not rightDown and frame:IsShown() then
            local top = _G.RotationMasterFrontmostDialog
            local focus

            if GetMouseFoci then
                focus = GetMouseFoci()[1]
            elseif GetMouseFocus then
                focus = GetMouseFocus()
            end

            local inside = false

            for _ = 1, 100 do
                if focus == frame then
                    inside = true
                    break
                end

                if not focus or type(focus.GetParent) ~= 'function' then
                    break
                end

                -- A control that gives a right click its own meaning keeps it (the main window honors the same flag).
                if focus.rmOwnsRightClick then
                    break
                end

                focus = focus:GetParent()
            end

            if inside and (not top or top == frame) then
                local owner = frame.rmEscapeOwner

                if owner and type(owner.Hide) == 'function' then
                    owner:Hide()
                else
                    frame:Hide()
                end
            end
        end

        rightDown = down
    end)
end

-- Makes the header the only part of the frame that moves it. Body EditBoxes and controls keep their native mouse
-- selection, dragging and right-click behavior.
-- @param frame table  The dialog frame.
-- @return table  The drag handle frame (cached on the frame).
function addon:EnableWorkbenchTitleDrag(frame)
    if frame.rmWorkbenchTitleDrag then
        return frame.rmWorkbenchTitleDrag
    end

    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    local drag = CreateFrame('Frame', nil, frame)
    frame.rmWorkbenchTitleDrag = drag
    drag:SetPoint('TOPLEFT', 1, -1)
    drag:SetPoint('TOPRIGHT', -58, -1)
    drag:SetHeight(28)
    drag:EnableMouse(true)
    drag:RegisterForDrag('LeftButton')

    -- Ends a title drag.
    local function stop()
        drag.moving = nil
        frame:StopMovingOrSizing()
    end

    addon:SetUIScript(drag, 'OnDragStart', function(_, button)
        if button and button ~= 'LeftButton' or not frame:IsShown() then
            return
        end

        drag.moving = true
        frame:StartMoving()
    end)

    addon:SetUIScript(drag, 'OnDragStop', stop)

    addon:SetUIScript(drag, 'OnMouseUp', function(_, button)
        if button == 'LeftButton' and drag.moving then
            stop()
        end
    end)

    addon:SetUIScript(drag, 'OnHide', stop)
    return drag
end

-- Paints the standard dialog frame (background, header, footer, border, logo, title, version and edition, creator and
-- right-click hints) and enables title drag and right-click close.
-- @param frame table  The dialog frame.
-- @param title table  A font string the caller owns.
-- @param help table|nil  When given, a Help button is added (the argument of addon:OpenWorkbenchHelp, with an optional
-- valid function).
-- @return table  The chrome object, with `SetContext(heading, kind, rotationName)` and `LayoutTitle()`.
function addon:CreateWorkbenchDialogChrome(frame, title, help)
    local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)
    local chrome = {}
    self:EnableWorkbenchRightClickClose(frame)
    chrome.drag = self:EnableWorkbenchTitleDrag(frame)

    -- Covers a parent with a solid color texture.
    -- @param parent table  The frame to cover.
    -- @param r number  Red, 0 to 1.
    -- @param g number  Green, 0 to 1.
    -- @param b number  Blue, 0 to 1.
    -- @return table  The texture.
    local function fill(parent, r, g, b)
        local art = parent:CreateTexture(nil, 'BACKGROUND')
        art:SetAllPoints(parent)
        art:SetColorTexture(r, g, b, 1)
        return art
    end

    chrome.background = fill(frame, .075, .08, .085)
    chrome.header = frame:CreateTexture(nil, 'BACKGROUND')
    chrome.header:SetPoint('TOPLEFT', 1, -1)
    chrome.header:SetPoint('TOPRIGHT', -1, -1)
    chrome.header:SetHeight(28)
    chrome.header:SetColorTexture(.12, .125, .13, 1)
    chrome.footer = CreateFrame('Frame', nil, frame)
    chrome.footer:SetPoint('BOTTOMLEFT', 1, 1)
    chrome.footer:SetPoint('BOTTOMRIGHT', -1, 1)
    chrome.footer:SetHeight(20)
    fill(chrome.footer, .09, .10, .11)

    for _, edge in ipairs({
        { 'TOPLEFT', 'TOPRIGHT', true },
        { 'BOTTOMLEFT', 'BOTTOMRIGHT', true },
        { 'TOPLEFT', 'BOTTOMLEFT' },
        { 'TOPRIGHT', 'BOTTOMRIGHT' },
    }) do
        local art = frame:CreateTexture(nil, 'BORDER')
        art:SetColorTexture(.33, .35, .37, 1)
        art:SetPoint(edge[1], frame, edge[1])
        art:SetPoint(edge[2], frame, edge[2])

        if edge[3] then
            art:SetHeight(1)
        else
            art:SetWidth(1)
        end
    end

    -- Creates a small label anchored at a point with the given offsets and text.
    -- @param parent table  The frame that owns the font string.
    -- @param point string  The anchor point.
    -- @param x number  The horizontal offset.
    -- @param y number  The vertical offset.
    -- @param value string  The text.
    -- @return table  The font string.
    local function text(parent, point, x, y, value)
        local label = parent:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        label:SetPoint(point, x, y)
        label:SetText(value)
        return label
    end

    chrome.icon = frame:CreateTexture(nil, 'ARTWORK')
    chrome.icon:SetSize(18, 18)
    chrome.icon:SetPoint('TOPLEFT', 12, -5)
    chrome.icon:SetTexture(addon.logoTexture)
    title:ClearAllPoints()
    title:SetPoint('TOPLEFT', 36, -5)
    title:SetHeight(18)
    title:SetJustifyV('MIDDLE')
    title:SetJustifyH('LEFT')
    title:SetWordWrap(false)
    title:SetMaxLines(1)
    title:SetTextColor(.94, .95, .96)

    local getter = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local version = type(getter) == 'function' and getter(addon_name, 'Version') or L['Development']

    if not version or version:find('@', 1, true) then
        version = L['Development']
    end

    local client = addon.Platform and addon.Platform.GetClientInfo and addon.Platform:GetClientInfo() or {}

    local edition = ({
        tbc = L['TBC'],
        era = L['Classic Era'],
        progression = L['Classic Progression'],
        retail = L['Retail'],
        forever = L['Forever'],
    })[client.family] or L['Unknown']

    chrome.version = text(
        frame,
        'TOPRIGHT',
        -62,
        -5,
        version .. ' · ' .. edition .. (client.version and ' ' .. client.version or '')
    )

    chrome.version:SetWidth(220)
    chrome.version:SetHeight(18)
    chrome.version:SetJustifyH('RIGHT')
    chrome.version:SetJustifyV('MIDDLE')
    chrome.version:SetWordWrap(false)
    chrome.version:SetMaxLines(1)
    chrome.author = text(chrome.footer, 'LEFT', 8, 0, string.format(L['Created by %s'], 'PreZ'))
    chrome.hint = text(chrome.footer, 'RIGHT', -24, 0, L['Right-click to close'])

    -- Sizes the title and the footer text to the current frame width so they truncate instead of overlapping.
    function chrome:LayoutTitle()
        title:SetWidth(math.max(100, frame:GetWidth() - 36 - 62 - (self.contextWidth or 220) - 16))
        self.author:SetWidth(math.max(40, frame:GetWidth() - self.hint:GetStringWidth() - 40))
        self.author:SetJustifyH('LEFT')
        self.author:SetWordWrap(false)
        self.author:SetMaxLines(1)
    end

    -- Sets the title ("Rotation Master: heading"), the kind label at the top right and the rotation name in the footer.
    -- @param heading string|nil  The heading shown after the addon name.
    -- @param kind string|nil  The kind label at the top right; nil means "Condition".
    -- @param rotationName string|nil  The name shown in the footer.
    function chrome:SetContext(heading, kind, rotationName)
        title:SetText(string.format(L['%s: %s'], addon.pretty_name or L['Rotation Master'], addon:PlainWorkbenchName(
            heading or ''
        )))

        self.version:SetText(kind or L['Condition'])
        self.contextWidth = math.min(220, math.max(48, self.version:GetStringWidth() + 8))
        self.version:SetWidth(self.contextWidth)
        self.author:SetText(addon:PlainWorkbenchName(rotationName or ''))
        self:LayoutTitle()
    end

    if help then
        chrome.help = self:CreateWorkbenchHelpButton(frame, L['Help'])
        chrome.help:SetPoint('TOPRIGHT', -31, -5)
        self:SetUIScript(chrome.help, 'OnClick', function() return addon:OpenWorkbenchHelp(help) end)
        self:BindWorkbenchHelp(chrome.help, { brief = L['Help.Brief.full'], valid = help.valid })
    end

    return chrome
end
