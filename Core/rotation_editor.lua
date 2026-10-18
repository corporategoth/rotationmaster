local _,addon=...
local data=addon.RotationData

local function equal(left,right)
    if not data.CheckPortable(left) or not data.CheckPortable(right) then return false end
    local function compare(a,b)
        if type(a)~=type(b) then return false end
        if type(a)~='table' then return a==b end
        for key,value in pairs(a) do if not compare(value,b[key]) then return false end end
        for key in pairs(b) do if a[key]==nil then return false end end
        return true
    end
    return compare(left,right)
end
local function weight(value)
    if type(value)=='string' then return 32+#value end
    if type(value)~='table' then return 16 end
    local total=64;for key,child in pairs(value) do total=total+32+weight(key)+weight(child) end;return total
end

function addon:NewRotationEditSession(spec,original,options)
    options=options or {}
    if type(options)~='table' or getmetatable(options)~=nil or
        options.targetValid~=nil and type(options.targetValid)~='function' or
        options.readOnly~=nil and type(options.readOnly)~='boolean' then return nil,'invalid-rotation-editor-options' end
    local newId=options.newId or self.uuid
    local draft,why=data.NewRotationDraft(original,newId,options.reserved)
    if not draft then return nil,why end
    local baseline=data.CopyData(original)
    -- Absent empty priority lists are an old storage shape, not a user edit.
    -- Keep the exact original separately for concurrent-change detection.
    local dirtyBaseline=data.CopyData(original)
    if dirtyBaseline.rotation==nil then dirtyBaseline.rotation={} end
    if dirtyBaseline.cooldowns==nil then dirtyBaseline.cooldowns={} end
    local readOnly=options.readOnly==true
    local targetValid=options.targetValid
    local closed,busy=false,false
    local undo,redo,bytes={},{},0
    local function push(stack,value)
        local size=weight(value);stack[#stack+1]={value=value,bytes=size};bytes=bytes+size
    end
    local function pop(stack,at)
        local entry=table.remove(stack,at or #stack);if entry then bytes=bytes-entry.bytes end;return entry
    end
    local function trim()
        while #undo+#redo>100 or bytes>8388608 do
            if #undo>0 then pop(undo,1) elseif #redo>0 then pop(redo,1) else break end
        end
    end
    local function writable()
        if closed then return nil,'rotation-editor-closed' end
        if busy then return nil,'rotation-editor-busy' end
        if readOnly then return nil,'readonly-rotation' end
        return true
    end
    local function owner()
        if not targetValid then return true end
        local ok,valid=pcall(targetValid);return ok and valid==true
    end
    local function close() closed=true;undo={};redo={};bytes=0 end
    local session={}
    function session:Snapshot() return draft:Snapshot() end
    function session:IsDirty() return not equal(dirtyBaseline,draft:Snapshot()) end
    function session:HistoryState()
        return {canUndo=not closed and not busy and not readOnly and #undo>0,
            canRedo=not closed and not busy and not readOnly and #redo>0}
    end
    function session:Command(name,...)
        local ok,reason=writable();if not ok then return nil,reason end
        local before=draft:Snapshot()
        local changed,result=draft:Command(name,...)
        if changed and not equal(before,draft:Snapshot()) then
            while #redo>0 do pop(redo) end
            push(undo,before);trim()
        end
        return changed,result
    end
    local function travel(source,destination)
        local ok,reason=writable();if not ok then return nil,reason end
        if #source==0 then return nil,'rotation-history-empty' end
        local previous=draft:Snapshot()
        local restored,problem=draft:Restore(source[#source].value)
        if not restored then return nil,problem end
        pop(source);push(destination,previous);trim()
        return true
    end
    function session:Undo() return travel(undo,redo) end
    function session:Redo() return travel(redo,undo) end
    function session:Cancel()
        if busy then return nil,'rotation-editor-busy' end
        close();return true
    end
    function session:Apply()
        local writableOk,reason=writable();if not writableOk then return nil,reason end
        busy=true
        local function finish(ok,problem,details) busy=false;return ok,problem,details end
        if not owner() then return finish(nil,'rotation-target-missing') end
        if not equal(baseline,original) then return finish(nil,'rotation-changed-externally') end
        local snapshot=draft:Snapshot()
        local validation=data.ValidateBody(snapshot,addon:GetImportValidationOptions())
        if not validation.valid then return finish(nil,'invalid-rotation-data',validation) end
        if not validation.supported then return finish(nil,'unsupported-rotation-data',validation) end
        if not validation.resolved then return finish(nil,'unresolved-rotation-data',validation) end
        local candidate=data.CopyData(snapshot)
        local tree=data.IndexRotationSteps(candidate)
        local function validate()
            local valid=addon:validateCondition(candidate.switch or {},spec)
            for _,row in ipairs(tree.rows) do
                -- Validate both arms, including forced/unreachable branches.
                if not addon:validateCondition(row.step.conditions or {},spec) then valid=false end
            end
            return valid
        end
        local ok,valid
        if addon.Diagnostics then ok,valid=addon.Diagnostics:Call({module='rotation-editor',operation='validate',customCode=true},validate)
        else ok,valid=pcall(validate) end
        if not ok then return finish(nil,'rotation-validation-error') end
        if not equal(snapshot,candidate) then return finish(nil,'validation-mutated-rotation') end
        if not valid then return finish(nil,'invalid-condition-fields') end
        if not owner() then return finish(nil,'rotation-target-missing') end
        if not equal(baseline,original) then return finish(nil,'rotation-changed-externally') end
        for key in pairs(original) do original[key]=nil end
        for key,value in pairs(snapshot) do original[key]=value end
        close();return finish(true)
    end
    return session
end
