-- Registry and lifecycle for the native condition widgets (the AceGUI replacement used by the condition editor, Help
-- and Test surfaces). Owns the pool of reusable widgets per kind, the base widget methods (callbacks, userdata, sizing,
-- parenting) and the lease that stops a released widget's callbacks from firing. It does not draw anything: concrete
-- kinds such as RM-ConditionPositionPad register a constructor here. Loaded from RotationMaster.toc before every other
-- UI/condition_*.lua file, which all create widgets through `addon:AcquireConditionWidget`. Widget state is per session
-- and never saved.
local _, addon = ...
local available, observers = {}, {}
local known = setmetatable({}, { __mode = 'k' })

-- Empties a table in place, keeping the table identity that callers and callbacks hold.
local function clear(t)
    for key in pairs(t or {}) do
        t[key] = nil
    end
end

-- True only for tables registered through `RegisterConditionWidget`; a table that merely looks like a widget is not
-- one.
function addon:IsConditionWidget(widget)
    return type(widget) == 'table' and known[widget] == true
end

-- Calls `callback(widget)` for every widget acquired until the returned function is called. Used to collect the widgets
-- a Test or debugger run creates so they can be released afterwards.
function addon:ObserveConditionWidgets(callback)
    local token = { callback = callback }
    observers[token] = true
    return function() observers[token] = nil end
end

-- Notifies the observers of a newly acquired widget. Snapshots the observer list first so a callback may unsubscribe
-- while it runs.
local function observed(widget)
    local callbacks = {}

    for token in pairs(observers) do
        callbacks[#callbacks + 1] = token
    end

    for _, token in ipairs(callbacks) do
        if observers[token] then token.callback(widget) end
    end
end

-- ============================================================================
-- Base widget methods
-- ============================================================================

---@class RMConditionWidget
---@field type string
---@field frame Frame
---@field content? Frame
---@field parent? RMConditionWidget
---@field userdata table
---@field events table
---@field rmLease? table
---@field rmActive? boolean
---@field isQueuedForRelease? boolean
---@field SetCallback fun(self: RMConditionWidget, event: string, callback: function?)
---@field Fire fun(self: RMConditionWidget, event: string, ...: any): any
---@field GetUserData fun(self: RMConditionWidget, key: any): any
---@field SetUserData fun(self: RMConditionWidget, key: any, value: any)
---@field GetUserDataTable fun(self: RMConditionWidget): table
---@field SetParent fun(self: RMConditionWidget, parent: RMConditionWidget)
---@field SetWidth fun(self: RMConditionWidget, width: number)
---@field SetHeight fun(self: RMConditionWidget, height: number)
---@field SetFullWidth fun(self: RMConditionWidget, value: boolean)
---@field SetFullHeight fun(self: RMConditionWidget, value: boolean)
---@field IsFullWidth fun(self: RMConditionWidget): boolean
---@field IsFullHeight fun(self: RMConditionWidget): boolean
---@field SetRelativeWidth fun(self: RMConditionWidget, value: number)
---@field IsShown fun(self: RMConditionWidget): boolean
---@field IsVisible fun(self: RMConditionWidget): boolean
---@field SetPoint fun(self: RMConditionWidget, ...: any)
---@field ClearAllPoints fun(self: RMConditionWidget)
---@field GetPoint fun(self: RMConditionWidget, ...: any): any
---@field GetNumPoints fun(self: RMConditionWidget): number
---@field IsReleasing fun(self: RMConditionWidget): boolean
---@field Release fun(self: RMConditionWidget): boolean
---@field OnAcquire fun(self: RMConditionWidget)
---@field OnRelease fun(self: RMConditionWidget)
local base = {}
local inherited = { Release = function(self) return addon:ReleaseConditionWidget(self) end }

-- Stores `callback` for `event`, wrapped so it only runs while this acquisition of the widget is still the live one: a
-- callback queued before a release must not touch the next owner of the pooled widget. OnRelease is the one event that
-- still fires during release.
function base:SetCallback(event, callback)
    local lease = self.rmLease

    self.events[event] = type(callback) == 'function' and function(...)
        if self.rmLease == lease and self.rmActive and (not self:IsReleasing() or event == 'OnRelease') then
            return callback(...)
        end
    end or nil
end

-- Runs the callback registered for `event` (if any) with the widget and the event name first, and returns its result.
function base:Fire(event, ...)
    local callback = self.events[event]
    if not callback then return end
    return callback(self, event, ...)
end

-- Reads a caller-owned value stored on this acquisition of the widget.
function base:GetUserData(key)
    return self.userdata[key]
end

-- Stores a caller-owned value; cleared when the widget is released.
function base:SetUserData(key, value)
    self.userdata[key] = value
end

-- Returns the live userdata table.
function base:GetUserDataTable()
    return self.userdata
end

-- Attaches the widget under a live registered parent, or raises a short error code. Refuses a second owner and any
-- parent cycle (the walk is bounded at 128 levels so a corrupt chain cannot loop).
function base:SetParent(parent)
    if not addon:IsConditionWidget(self) or not self.rmActive or self:IsReleasing() then
        error('inactive-condition-widget', 0)
    end

    if not addon:IsConditionWidget(parent) or not parent.rmActive or parent:IsReleasing() then
        error('foreign-condition-widget-parent', 0)
    end

    if self.parent and self.parent ~= parent then error('condition-child-already-owned', 0) end
    local current = parent

    for _ = 1, 128 do
        if not current then break end
        if current == self then error('condition-widget-parent-cycle', 0) end
        current = current.parent
    end

    if current then error('condition-widget-parent-cycle', 0) end
    self.parent = parent
    self.frame:SetParent(parent.content or parent.frame)
end

-- Sets the frame width and records it on the frame; `sizing` stops the OnSizeChanged hook from reporting our own
-- change.
function base:SetWidth(width)
    self.sizing = true
    self.frame:SetWidth(width)
    self.frame.width = width
    self.sizing = false
    if self.OnWidthSet then self:OnWidthSet(width) end
end

-- Sets the frame height and records it on the frame; `sizing` stops the OnSizeChanged hook from reporting our own
-- change.
function base:SetHeight(height)
    self.sizing = true
    self.frame:SetHeight(height)
    self.frame.height = height
    self.sizing = false
    if self.OnHeightSet then self:OnHeightSet(height) end
end

-- Asks the parent layout to stretch the widget across its width.
function base:SetFullWidth(value)
    self.width = value and 'fill' or nil
end

-- Asks the parent layout to stretch the widget down its height.
function base:SetFullHeight(value)
    self.height = value and 'fill' or nil
end

-- True when the widget was asked to fill its parent width.
function base:IsFullWidth()
    return self.width == 'fill'
end

-- True when the widget was asked to fill its parent height.
function base:IsFullHeight()
    return self.height == 'fill'
end

-- Asks the parent layout for a fraction (0 to 1] of its width.
function base:SetRelativeWidth(value)
    assert(type(value) == 'number' and value > 0 and value <= 1, 'invalid-relative-width')
    self.width = 'relative'
    self.relWidth = value
end

-- Forwards to the frame.
function base:IsShown()
    return self.frame:IsShown()
end

-- Forwards to the frame.
function base:IsVisible()
    return self.frame:IsVisible()
end

-- Forwards to the frame.
function base:SetPoint(...)
    return self.frame:SetPoint(...)
end

-- Forwards to the frame.
function base:ClearAllPoints()
    self.frame:ClearAllPoints()
end

-- Forwards to the frame.
function base:GetPoint(...)
    return self.frame:GetPoint(...)
end

-- Forwards to the frame.
function base:GetNumPoints()
    return self.frame:GetNumPoints()
end

-- True when this widget or any ancestor is being released. A chain deeper than 128 levels is treated as releasing, so a
-- corrupt parent loop fails closed.
function base:IsReleasing()
    local current = self

    for _ = 1, 128 do
        if not current then return false end
        if current.isQueuedForRelease then return true end
        current = current.parent
    end

    return true
end

-- ============================================================================
-- Registration, acquire and release
-- ============================================================================

-- Native registration establishes ownership; public shape flags are not authority.
function addon:RegisterConditionWidget(widget)
    if type(widget) ~= 'table' or known[widget] or not widget.frame then
        error('invalid-condition-widget-registration', 0)
    end

    local w = widget
    known[w] = true
    setmetatable(w, { __index = inherited })
    w.userdata = {}
    w.events = {}
    w.frame.obj = w
    w.rmWidget = true
    if w.content then w.content.obj = w end

    for name, method in pairs(base) do
        if w[name] == nil then w[name] = method end
    end

    local acquire, release = w.OnAcquire, w.OnRelease

    -- Wraps the kind's own OnAcquire: starts a fresh lease and empty userdata and events, so nothing from a previous
    -- owner of the pooled widget survives.
    function w:OnAcquire()
        self.rmLease = {}
        self.rmActive = true
        self.parent = nil
        self.configure = nil
        self.userdata = {}
        self.events = {}
        self.isQueuedForRelease = nil
        if acquire then acquire(self) end
    end

    -- Wraps the kind's own OnRelease: marks the widget inactive first so every callback guarded by the lease goes
    -- quiet.
    function w:OnRelease()
        self.rmActive = false
        if release then return release(self) end
    end

    addon:SetUIScript(w.frame, 'OnSizeChanged', function(_, width, height)
        local oldWidth, oldHeight = w.frame.width, w.frame.height
        w.frame.width = width
        w.frame.height = height

        if not w.sizing and w.rmActive then
            if width ~= oldWidth and w.OnWidthSet then w:OnWidthSet(width) end
            if height ~= oldHeight and w.OnHeightSet then w:OnHeightSet(height) end
        end
    end)

    return w
end

-- Returns an active widget of `kind`, reusing a pooled one when possible and otherwise calling `constructor`. A widget
-- whose OnAcquire fails is quarantined (never pooled again) and the error is rethrown. Observers hear of the widget
-- last.
function addon:AcquireConditionWidget(kind, constructor)
    local pool = available[kind] or {}
    available[kind] = pool
    local widget

    for candidate in pairs(pool) do
        if not candidate.isQueuedForRelease and not candidate.rmActive and not candidate.rmQuarantined then
            widget = candidate
            pool[candidate] = nil
            break
        end
    end

    if not widget then widget = constructor() end

    if not self:IsConditionWidget(widget) or widget.type ~= kind or widget.rmActive then
        error('condition-widget-construction-failed', 0)
    end

    local ok, why = pcall(widget.OnAcquire, widget)

    if not ok then
        widget.rmActive = false
        widget.rmQuarantined = true
        error(why, 0)
    end

    if kind == 'RM-ConditionGroup' and self.PrepareNativeConditionTable then
        self:PrepareNativeConditionTable(widget)
    end

    observed(widget)
    return widget
end

-- Releases a widget back to its pool: hides it, fires OnRelease, releases children, wipes its state and re-parents the
-- frame to UIParent. Each step runs under pcall so one failure cannot strand the rest; the first failure quarantines
-- the widget and is rethrown after cleanup. Returns false when it was already released.
function addon:ReleaseConditionWidget(widget)
    if widget == nil then return false end
    if not self:IsConditionWidget(widget) then error('foreign-condition-widget', 0) end
    if widget.isQueuedForRelease or not widget.rmActive then return false end
    widget.isQueuedForRelease = true
    if available[widget.type] then available[widget.type][widget] = nil end
    local problem

    -- Runs one cleanup step under pcall and remembers the first failure, so a failing step cannot skip the ones after
    -- it.
    local function perform(callback, ...)
        if type(callback) ~= 'function' then return end
        local ok, why = pcall(callback, ...)
        if not ok then problem = problem or why end
    end

    perform(widget.PauseLayout, widget)
    perform(widget.frame.Hide, widget.frame)
    perform(widget.Fire, widget, 'OnRelease')
    perform(widget.ReleaseChildren, widget)
    perform(widget.OnRelease, widget)
    widget.rmActive = false
    widget.rmLease = nil
    widget.parent = nil
    clear(widget.userdata)
    clear(widget.events)
    widget.width = nil
    widget.height = nil
    widget.relWidth = nil
    widget.relHeight = nil
    widget.noAutoHeight = nil
    widget.sizing = nil
    perform(widget.frame.ClearAllPoints, widget.frame)
    perform(widget.frame.Hide, widget.frame)
    perform(widget.frame.SetParent, widget.frame, UIParent)
    widget.isQueuedForRelease = nil

    if problem then
        widget.rmQuarantined = true
        error(problem, 0)
    end

    available[widget.type] = available[widget.type] or {}
    available[widget.type][widget] = true
    return true
end
