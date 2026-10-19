-- Test-only byte normalization for frozen pre-removal module hashes. This does
-- not register or resolve a library; only one exact retired generated line is
-- restored in an in-memory copy before the original whole-file hash check.
return function(source)
    local retired='        if name=="AceGUI" then return addon:GetConditionWidgetCompatibilityLibrary() end\n'
    assert(not source:find(retired,1,true),'retired GUI getter is still present in the current module')
    local header='    local function sourceGetter(name)\n'
    local start=assert(source:find(header,1,true),'generated source getter header missing')
    assert(not source:find(header,start+1,true),'ambiguous generated source getter header')
    local stop=start+#header
    return source:sub(1,stop-1)..retired..source:sub(stop)
end
