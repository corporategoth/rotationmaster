local _,addon=...

local function pack(...) return {n=select('#',...),...} end

-- Keep one synchronous allocation scope for Test and the debugger. The caller
-- supplies its existing protected executor, so diagnostics and nil tuples keep
-- their original shape. Nested scopes retain each surrounding native subscription.
function addon:WithConditionWidgetObservation(guard,invoke,callback,...)
    local unsubscribe=self:ObserveConditionWidgets(guard)
    local result=pack(pcall(invoke or pcall,callback,...))
    unsubscribe()
    if not result[1] then error(result[2],0) end
    return unpack(result,2,result.n)
end

function addon:ClearConditionWidgetFocus()
    local getter=GetCurrentKeyBoardFocus
    if type(getter)=='function' then
        local ok,focus=pcall(getter)
        if ok and focus and type(focus.ClearFocus)=='function' then focus:ClearFocus() end
    end
end
