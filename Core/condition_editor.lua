local _,addon=...
local data=addon.RotationData
local commands={Replace=true,Wrap=true,Unwrap=true,Add=true,Remove=true,Move=true,SetDisabled=true,
    GroupSelection=true,NegateSelection=true,RemoveSelection=true,Transfer=true,Insert=true,Duplicate=true,AddSibling=true,SetName=true,SetGroupType=true,SetProjectedDisabled=true}

local function unchanged(left,right)
    if not data.CheckPortable(left) or not data.CheckPortable(right) then return false end
    -- Conditions may legally use names such as body.rotation for their own
    -- fields. Compare plain values without envelope/step identity semantics.
    local function equal(a,b)
        if type(a)~=type(b) then return false end
        if type(a)~="table" then return a==b end
        for key,value in pairs(a) do if not equal(value,b[key]) then return false end end
        for key in pairs(b) do if a[key]==nil then return false end end
        return true
    end
    return equal(left,right)
end

-- Editing is detached from the running rotation. Only explicit Apply writes
-- the original plain table, after schema, semantic and concurrent-edit checks.
function addon:NewConditionEditSession(spec,original,targetValid,options)
    options=options or {}
    if type(options)~='table' or options.readOnly~=nil and type(options.readOnly)~='boolean' then return nil,'invalid-editor-options' end
    local readOnly=options.readOnly==true
    if targetValid~=nil and type(targetValid)~="function" then return nil,"invalid-editor-owner" end
    local function targetExists()
        if not targetValid then return true end
        local ok,exists=pcall(targetValid);return ok and exists==true
    end
    local draft,why=data.NewConditionDraft(original,self.conditionDefinitions)
    if not draft then return nil,why end
    local baseline=draft:Snapshot()
    local closed=false
    -- History belongs to this unsaved draft. Bound both the number of edits
    -- and an estimate of retained table/string storage, including redo states.
    local undo,redo,historyBytes={},{},0
    local function weight(value)
        if type(value)=="string" then return 32+#value end
        if type(value)~="table" then return 16 end
        local total=64
        for key,child in pairs(value) do total=total+32+weight(key)+weight(child) end
        return total
    end
    local function push(stack,value)
        local bytes=weight(value);stack[#stack+1]={value=value,bytes=bytes};historyBytes=historyBytes+bytes
    end
    local function pop(stack,index)
        local entry=table.remove(stack,index or #stack)
        if entry then historyBytes=historyBytes-entry.bytes end
        return entry
    end
    local function trim()
        while #undo+#redo>100 or historyBytes>8388608 do
            if #undo>0 then pop(undo,1) elseif #redo>0 then pop(redo,1) else break end
        end
    end
    local function close() closed=true;undo={};redo={};historyBytes=0 end
    local session={}
    function session:Snapshot() return draft:Snapshot() end
    function session:Baseline() return data.CopyData(baseline) end
    function session:IsDirty() return not unchanged(baseline,draft:Snapshot()) end
    function session:Rows(limit) return draft:Rows(limit) end
    function session:Command(name,path,value)
        if closed then return nil,"condition-editor-closed" end
        if readOnly then return nil,"readonly-condition" end
        if not commands[name] then return nil,"invalid-editor-command" end
        local before=draft:Snapshot()
        local ok,result=draft[name](draft,path,value)
        if ok and not unchanged(before,draft:Snapshot()) then
            while #redo>0 do pop(redo) end
            push(undo,before);trim()
        end
        return ok,result
    end
    function session:HistoryState()
        return {canUndo=not closed and not readOnly and #undo>0,canRedo=not closed and not readOnly and #redo>0}
    end
    local function travel(source,destination)
        if closed then return nil,"condition-editor-closed" end
        if readOnly then return nil,"readonly-condition" end
        if #source==0 then return nil,"condition-history-empty" end
        local entry=source[#source]
        local current=draft:Snapshot()
        local ok,problem=draft:Replace({},entry.value)
        if not ok then return nil,problem end
        pop(source);push(destination,current);trim();return true
    end
    function session:Undo() return travel(undo,redo) end
    function session:Redo() return travel(redo,undo) end
    function session:Cancel() close() end
    function session:Apply()
        if closed then return nil,"condition-editor-closed" end
        if readOnly then return nil,"readonly-condition" end
        if not targetExists() then return nil,"condition-target-missing" end
        if not unchanged(baseline,original) then return nil,"condition-changed-externally" end
        local snapshot=draft:Snapshot()
        local body={name="Condition draft",switch=snapshot,rotation={},cooldowns={}}
        local result=data.ValidateBody(body,addon:GetImportValidationOptions())
        if not result.valid then return nil,"invalid-condition-data",result end
        if not result.supported then return nil,"unsupported-condition-data",result end
        if not result.resolved then return nil,"unresolved-condition-data",result end
        local candidate=data.CopyData(snapshot)
        local function validate() return addon:validateCondition(candidate,spec) end
        local ok,valid
        if addon.Diagnostics then
            ok,valid=addon.Diagnostics:Call({module="condition-editor",operation="validate",customCode=true},validate)
        else ok,valid=pcall(validate) end
        if not ok then return nil,"condition-validation-error" end
        if not unchanged(snapshot,candidate) then return nil,"validation-mutated-condition" end
        if not valid then return nil,"invalid-condition-fields" end
        if not targetExists() then return nil,"condition-target-missing" end
        if not unchanged(baseline,original) then return nil,"condition-changed-externally" end
        for key in pairs(original) do original[key]=nil end
        for key,value in pairs(snapshot) do original[key]=value end
        close()
        return true
    end
    return session
end
