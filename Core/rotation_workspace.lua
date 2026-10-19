local _,addon=...
local data=addon.RotationData
local profiles={}
local function equal(a,b)
    if not data.CheckPortable(a) or not data.CheckPortable(b) then return false end
    local function compare(x,y)
        if type(x)~=type(y) then return false end
        if type(x)~='table' then return x==y end
        for key,value in pairs(x) do if not compare(value,y[key]) then return false end end
        for key in pairs(y) do if x[key]==nil then return false end end
        return true
    end
    return compare(a,b)
end
local function originalAt(profile,spec,id)
    local list=profile.rotations and profile.rotations[spec]
    return type(list)=='table' and list[id] or nil
end
local function retained(profile,spec,id)
    local result={};local library=profile.rotationLibrary
    if type(library)=='table' then
        for _,kind in ipairs({'origins','comparisons','imports'}) do
            local all=library[kind];local scope=type(all)=='table' and all[spec]
            if type(scope)=='table' then result[kind]=scope[id] end
        end
    end
    return result
end
local function scopedWorkspace(owner,coordinator,spec,value)
    local reference,why=coordinator:Resolve(spec,value)
    if not reference and why=='unknown-rotation' and type(value)=='string' then reference,why=coordinator:LegacyDraft(spec,value) end
    if not reference then return nil,why end
    local profile=owner.db.profile;local key=coordinator:Key(reference)
    local cache=profiles[profile];if not cache then cache={};profiles[profile]=cache end
    for _,w in ipairs(cache) do if w.spec==spec and w.id==key and w:ValidTarget() then return w end end
    local pending=coordinator:IsPending(reference)
    local record,expected,status
    if not pending then record,expected,status=coordinator:Snapshot(spec,reference);if not record then return nil,expected end end
    local builtin=reference.kind=='builtin' and reference.id or nil
    record=record or {body={name=reference.address.id==profile.rotationFallbackID and profile.rotationFallbackID or NEW,switch={},rotation={},cooldowns={}}}
    local sourceReference=data.CopyData(reference)
    local workspace={spec=spec,id=key,canonicalId=builtin or reference.address.id,reference=data.CopyData(reference),builtin=builtin,readOnly=builtin~=nil,
        fallback=not builtin and reference.address.id==profile.rotationFallbackID or false,pending=pending,
        original=pending and nil or data.CopyData(record.body),title=record.body.name or NEW,description=record.body.description or ''}
    workspace.source=record.source
    local baseline=data.CopyData(record.body)
    local function flags()
        workspace.scope=workspace.session and workspace.session:Ownership() or (not builtin and workspace.reference.address.scope)
        if workspace.pending and workspace.session then local staged=coordinator:StagePending(sourceReference,workspace.scope);if staged then workspace.reference=staged end end
        local effective=coordinator:Resolve(spec,DEFAULT)
        workspace.effectiveFallback=effective and equal(effective,workspace.reference) or false
    end
    function workspace:ValidTarget()
        if owner:GetScopedRotationCoordinator()~=coordinator then return false end
        if builtin then return coordinator:Resolve(spec,sourceReference)~=nil end
        if self.pending then return coordinator:IsPending(sourceReference) and coordinator:Resolve(spec,sourceReference)~=nil end
        return coordinator:TokenCurrent(expected)
    end
    local function sessionFor(body)
        workspace.reserved={origins=data.CopyData(record.origin),imports=data.CopyData(record.imported),comparisons=data.CopyData(record.comparison)}
        local used={};for _,component in pairs(workspace.reserved) do local ok,problem=data.ReserveRotationIdentities(component,used);if not ok then return nil,problem.code end end
        local function fresh()
            for _=1,100 do local id=owner.uuid();if not used[id] then used[id]=true;return id end end
        end
        return owner:NewRotationEditSession(spec,body,{readOnly=workspace.readOnly,newId=fresh,
            ownership=not builtin and sourceReference.address.scope or nil,setOwnershipAllowed=not builtin,
            targetValid=function() return workspace:ValidTarget() end,
            commit=function(candidate,scope)
                local replacement={body=candidate,origin=record.origin,imported=record.imported,comparison=record.comparison}
                local saved,problem=coordinator:Commit(sourceReference,expected,replacement,scope)
                if not saved then return nil,problem end
                return true,saved
            end})
    end
    local session,problem=sessionFor(baseline);if not session then return nil,problem end;workspace.session=session;flags()
    function workspace:Snapshot() flags();return self.session:Snapshot() end
    function workspace:TargetReference()
        local result=data.CopyData(self.reference)
        if not self.readOnly then
            local c=owner:GetRotationOwnerContext();if not c then return nil,'missing-owner-context' end
            result.address.scope=self.session:Ownership();result.address.owner=result.address.scope=='class' and c.class or c.character
            if not result.address.owner then return nil,'missing-owner-context' end
        end
        return result
    end
    function workspace:Metadata() return {id=self.id,reference=self:TargetReference(),scope=self.session:Ownership(),kind=self.readOnly and 'builtin' or 'custom',metadata=data.CopyData(self:Snapshot().metadata or {}),source=self.source or self.reserved} end
    function workspace:IsDirty() flags();return not self.readOnly and self.session:IsDirty() end
    function workspace:Command(name,...)
        if not self:ValidTarget() then return nil,'rotation-target-missing' end
        if self.fallback and name=='SetBodyField' and (...)=='name' then return nil,'protected-rotation-name' end
        if name=='SetOwnership' and (...)=='character' then local c=owner:GetRotationOwnerContext();if not c or not c.character then return nil,'missing-owner-context' end end
        local ok,result=self.session:Command(name,...);flags();return ok,result
    end
    function workspace:Apply()
        if self.pending and not self.fallback then local name=self:Snapshot().name;if type(name)~='string' or not name:find('%S') or name==NEW or name==DEFAULT then return nil,'invalid-rotation-name' end end
        local ok,why,saved=self.session:Apply();if not ok then return nil,why,saved end
        sourceReference=data.CopyData(saved);self.reference=data.CopyData(saved);self.id=coordinator:Key(saved);self.canonicalId=saved.address.id;self.pending=false
        record,expected,status=coordinator:Snapshot(spec,saved);baseline=data.CopyData(record.body);self.original=data.CopyData(record.body)
        self.title=record.body.name or self.canonicalId;self.description=record.body.description or ''
        local nextSession,problem=sessionFor(baseline);if not nextSession then return nil,problem end;self.session=nextSession;flags();return true,nil,data.CopyData(saved)
    end
    function workspace:Discard()
        if not self:ValidTarget() then return nil,'rotation-target-missing' end
        local replacement,why=sessionFor(baseline);if not replacement then return nil,why end
        self.session:Cancel();self.session=replacement;flags();return true
    end
    function workspace:ConditionEditorTarget(target)
        local captured=self.session
        local function condition()
            local body=captured:Snapshot();if type(target)=='table' and target.kind=='switch' then return body.switch or {} end
            local tree=data.IndexRotationSteps(body);local row=tree and tree.byId[target];return row and (row.step.conditions or {})
        end
        local baselineCondition=condition();if not baselineCondition then return nil,'missing-rotation-step' end
        local committed=false
        local function valid() return not committed and workspace.session==captured and workspace:ValidTarget() and equal(baselineCondition,condition()) end
        return {condition=data.CopyData(baselineCondition),readOnly=self.readOnly,valid=valid,commit=function(edited)
            if workspace.readOnly then return nil,'readonly-rotation' end;if not valid() then return nil,'condition-target-changed' end
            local ok,why=workspace:Command('SetCondition',target,edited);if ok then committed=true end;return ok,why
        end}
    end
    cache[#cache+1]=workspace;return workspace
end

function addon:GetRotationEditWorkspace(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scopedWorkspace(self,scoped,spec,id) end
    if type(spec)~='number' or spec<0 or spec%1~=0 or type(id)~='string' or id=='' then return nil,'invalid-rotation-target' end
    local profile=self.db.profile
    if type(profile.rotations)~='table' then return nil,'invalid-rotation-storage' end
    local builtin=self:GetDefaultIdForRuntime(spec,id)
    local source,original
    if builtin then
        for _,entry in ipairs(self:ListDefaultRotations(spec)) do if entry.id==builtin then source=entry;break end end
        if not source or not source.envelope then return nil,'unknown-default-rotation' end
    else original=originalAt(profile,spec,id) end
    local cache=profiles[profile]
    if not cache then cache={};profiles[profile]=cache end
    for _,workspace in ipairs(cache) do
        if workspace.spec==spec and workspace.id==id and workspace.builtin==builtin and
            (builtin or workspace.original==original) and workspace:ValidTarget() then return workspace end
    end
    local workspace={spec=spec,id=id,canonicalId=id,builtin=builtin,readOnly=builtin~=nil,fallback=not builtin and id==DEFAULT or false,
        title=source and source.name or id==DEFAULT and DEFAULT or original and original.name or NEW,
        description=source and source.description or original and original.description or '',source=source,original=original,pending=not builtin and original==nil}
    local capturedRoot=profile.rotations
    local value=source and data.CopyData(source.envelope.body) or original
    if not value then value={name=id==DEFAULT and DEFAULT or NEW,switch={},rotation={},cooldowns={}} end
    if builtin then value.name=source.name end
    function workspace:ValidTarget()
        if addon.db.profile~=profile or profile.rotations~=capturedRoot then return false end
        if self.builtin then return addon:GetDefaultIdForRuntime(spec,id)==self.builtin end
        return originalAt(profile,spec,id)==self.original and not addon:GetDefaultIdForRuntime(spec,id)
    end
    local function sessionFor(body)
        return addon:NewRotationEditSession(spec,body,{readOnly=workspace.readOnly,newId=addon.uuid,
            reserved=workspace.reserved,targetValid=function() return workspace:ValidTarget() end})
    end
    local reservations,copyError=data.CopyData(retained(profile,spec,id))
    if not reservations then return nil,copyError.code end
    workspace.reserved=reservations
    local session,why=sessionFor(value);if not session then return nil,why end
    workspace.session=session
    function workspace:Snapshot() return self.session:Snapshot() end
    function workspace:Metadata()
        return {id=id,kind=self.readOnly and 'builtin' or 'custom',metadata=data.CopyData(self:Snapshot().metadata or {}),
            source=self.source and data.CopyData(self.source.envelope) or data.CopyData(self.reserved)}
    end
    function workspace:IsDirty() return not self.readOnly and self.session:IsDirty() end
    function workspace:Command(name,...)
        if not self:ValidTarget() then return nil,'rotation-target-missing' end
        if id==DEFAULT and name=='SetBodyField' and (...)=='name' then return nil,'protected-rotation-name' end
        return self.session:Command(name,...)
    end
    function workspace:Apply()
        if self.pending and id~=DEFAULT then
            local name=self:Snapshot().name
            if type(name)~='string' or not name:find('%S') or name==NEW or name==DEFAULT then return nil,'invalid-rotation-name' end
        end
        local ok,reason,details=self.session:Apply();if not ok then return nil,reason,details end
        if self.pending then
            local list=profile.rotations[spec] or {};profile.rotations[spec]=list
            list[id]=value;self.original=value;self.pending=false
        end
        self.title=value.name or id
        local replacement,problem=sessionFor(value)
        if not replacement then return nil,problem end
        self.session=replacement;return true
    end
    function workspace:Discard()
        if not self:ValidTarget() then return nil,'rotation-target-missing' end
        local replacement,problem=sessionFor(value);if not replacement then return nil,problem end
        self.session:Cancel();self.session=replacement;return true
    end
    function workspace:ConditionEditorTarget(target)
        local sessionToken=self.session
        local function condition()
            local snapshot=sessionToken:Snapshot()
            if type(target)=='table' and target.kind=='switch' then return snapshot.switch or {} end
            local tree=data.IndexRotationSteps(snapshot);local row=tree and tree.byId[target]
            return row and (row.step.conditions or {})
        end
        local baseline=condition();if not baseline then return nil,'missing-rotation-step' end
        local committed=false
        local function valid()
            return not committed and workspace.session==sessionToken and workspace:ValidTarget() and equal(baseline,condition())
        end
        return {condition=data.CopyData(baseline),readOnly=self.readOnly,valid=valid,
            commit=function(edited)
                if workspace.readOnly then return nil,'readonly-rotation' end
                if not valid() then return nil,'condition-target-changed' end
                local ok,reason=workspace:Command('SetCondition',target,edited)
                if ok then committed=true end
                return ok,reason
            end}
    end
    cache[#cache+1]=workspace
    return workspace
end

function addon:GetRotationWorkspace(spec,value)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    local reference=scoped and scoped:Resolve(spec,value)
    for _,w in ipairs(profiles[self.db.profile] or {}) do if w.spec==spec and (w.id==value or scoped and reference and equal(w.reference,reference)) and w:ValidTarget() then return w end end
end
function addon:ListPendingRotationDrafts(spec)
    local result={}
    for _,workspace in ipairs(profiles[self.db.profile] or {}) do
        if workspace.spec==spec and workspace.pending and workspace.id~=DEFAULT and workspace:ValidTarget() then
            local snapshot=workspace:Snapshot();result[#result+1]={id=workspace.id,key=workspace.id,reference=workspace.TargetReference and workspace:TargetReference(),canonicalId=workspace.canonicalId,scope=workspace.scope,pending=true,fallback=workspace.fallback,effectiveFallback=false,name=snapshot.name or NEW,presentation={name=snapshot.name,description=snapshot.description,priority=snapshot.priority,tags=snapshot.tags,metadata=snapshot.metadata}}
        end
    end
    return result
end
