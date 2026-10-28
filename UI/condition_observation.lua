-- Small helpers around the condition widget registry (UI/condition_widgets.lua): run a callback while every widget it
-- creates is observed, and clear keyboard focus. Owns no widgets and no saved data. Callers are the Test and debugger
-- paths (Integrations/lua_workbench.lua) and the config and browser windows. Loaded from RotationMaster.toc right after
-- UI/condition_widgets.lua, whose `addon:ObserveConditionWidgets` it depends on.
local _, addon = ...

-- Packs a call result into a table that remembers its length, so trailing nils survive the round trip.
-- @param ... any  The values to pack.
-- @return table  { n = count, ... }.
local function pack(...)
    return { n = select('#', ...), ... }
end

-- Runs `callback` while every condition widget it creates is observed.
-- @param guard function  The observer, called with each widget as it is created (see addon:ObserveConditionWidgets).
-- @param invoke function|nil  The protected executor to call the callback through; defaults to pcall.
-- @param callback function  The function to run.
-- @param ... any  The arguments passed to the callback.
-- @return any  The callback's results, with trailing nils preserved; an error from the executor is rethrown unchanged.
--
-- Keep one synchronous allocation scope for Test and the debugger. The caller supplies its existing protected executor,
-- so diagnostics and nil tuples keep their original shape. Nested scopes retain each surrounding native subscription.
function addon:WithConditionWidgetObservation(guard, invoke, callback, ...)
    local unsubscribe = self:ObserveConditionWidgets(guard)
    local result = pack(pcall(invoke or pcall, callback, ...))
    unsubscribe()

    if not result[1] then
        error(result[2], 0)
    end

    return unpack(result, 2, result.n)
end

-- Drops keyboard focus from whichever edit box has it, so an in-progress edit is committed or abandoned before a window
-- rebuilds its fields. Safe when the client has no focus API or the focused object cannot clear focus.
function addon:ClearConditionWidgetFocus()
    local getter = GetCurrentKeyBoardFocus

    if type(getter) == 'function' then
        local ok, focus = pcall(getter)

        if ok and focus and type(focus.ClearFocus) == 'function' then
            focus:ClearFocus()
        end
    end
end
