local _,addon=...

-- Native hosts can operate without Ace. Explicit legacy construction and saved
-- library bindings use the separate strict compatibility resolver instead.
local function compatibilityLibrary()
    if not LibStub then return end
    local ok,library=pcall(LibStub,'AceGUI-3.0',true)
    if ok then return library end
end
local function pack(...) return {n=select('#',...),...} end

-- Keep one synchronous allocation scope for Test and the debugger. The caller
-- supplies its existing protected executor, so diagnostics and nil tuples keep
-- their original shape. Nested scopes restore their exact surrounding wrapper.
function addon:WithConditionWidgetObservation(guard,invoke,callback,...)
    local library=compatibilityLibrary()
    local create=library and library.Create
    local unsubscribe=self:ObserveConditionWidgets(guard)
    if type(create)=='function' then
        library.Create=function(owner,...)
            local widget=create(owner,...);guard(widget);return widget
        end
    end
    local result=pack(pcall(invoke or pcall,callback,...))
    unsubscribe()
    if type(create)=='function' then library.Create=create end
    if not result[1] then error(result[2],0) end
    return unpack(result,2,result.n)
end

function addon:ClearConditionWidgetFocus()
    local getter=GetCurrentKeyBoardFocus
    if type(getter)=='function' then
        local ok,focus=pcall(getter)
        if ok and focus and type(focus.ClearFocus)=='function' then focus:ClearFocus() end
    end
    local library=compatibilityLibrary()
    if library and type(library.ClearFocus)=='function' then library:ClearFocus() end
end
