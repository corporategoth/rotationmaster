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
function addon:GetRotationEditWorkspace(spec,id)
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
    local workspace={spec=spec,id=id,builtin=builtin,readOnly=builtin~=nil,
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

function addon:ListPendingRotationDrafts(spec)
    local result={}
    for _,workspace in ipairs(profiles[self.db.profile] or {}) do
        if workspace.spec==spec and workspace.pending and workspace.id~=DEFAULT and workspace:ValidTarget() then
            result[#result+1]={id=workspace.id,name=workspace:Snapshot().name or NEW}
        end
    end
    return result
end
