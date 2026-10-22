local _,addon=...
local readExecutionGeneration,advanceExecutionGeneration
---@type fun(...): any
local bindExecutionGeneration=addon.BindRotationExecutionGeneration
if type(bindExecutionGeneration)=='function' then
    bindExecutionGeneration(addon,function(read,advance)
        readExecutionGeneration,advanceExecutionGeneration=read,advance
    end)
end
local function invalidateExecution()
    if advanceExecutionGeneration then advanceExecutionGeneration() end
end
local kind,raw,write,identity,meta,iterate=type,rawget,rawset,rawequal,getmetatable,next
local infinity,protect=math.huge,pcall
local operation,active
local function detached(value)
    local seen,stack,nodes={},{},0
    local function copy(v,depth)
        nodes=nodes+1
        if nodes>20000 or depth>64 then return nil end
        local t=kind(v)
        if t~='table' then
            if t=='string' or t=='boolean' or t=='nil' then return v end
            if t=='number' and v==v and v~=infinity and v~=-infinity then return v end
            return nil
        end
        if meta(v)~=nil or stack[v] then return nil end
        if seen[v] then return seen[v] end
        local result={};seen[v]=result;stack[v]=true
        for key in iterate,v do
            nodes=nodes+1
            local tKey=kind(key)
            if nodes>20000 or not (tKey=='string' or tKey=='number' and key>=1 and key%1==0) then return nil end
            local child=copy(raw(v,key),depth+1);if child==nil then return nil end;result[key]=child
        end
        stack[v]=nil;return result
    end
    return copy(value,0)
end
local function equal(a,b)
    if kind(a)~=kind(b) then return false end
    if kind(a)~='table' then return a==b end
    if meta(a)~=nil or meta(b)~=nil then return false end
    for key,value in iterate,a do if not equal(value,raw(b,key)) then return false end end
    for key in iterate,b do if raw(a,key)==nil then return false end end
    return true
end
local function owned(self) return identity(self,addon) end
local function current(self,token)
    if not owned(self) then return false end
    local pending=operation
    if not pending or not identity(pending.token,token) then return false end
    local db=self.db;local profile=db and db.profile
    local spec,id=self.currentSpec,self.currentRotation
    return identity(operation,pending) and identity(profile,pending.profile) and identity(spec,pending.spec) and identity(id,pending.id)
end
local function begin(self)
    if not owned(self) then return nil,'foreign-rotation-owner' end
    local pending={token={}};operation=pending
    invalidateExecution()
    local db=self.db;pending.profile=db and db.profile
    pending.spec,pending.id=self.currentSpec,self.currentRotation
    if not identity(operation,pending) then return nil,'rotation-transition-superseded' end
    return pending.token
end
function addon:BeginActiveRotationTransition() return begin(self) end
function addon:IsActiveRotationTransitionCurrent(token) return current(self,token) end
function addon:AdvanceActiveRotationSpecialization(token,spec)
    if not current(self,token) then return nil,'rotation-transition-superseded' end
    local pending=operation
    invalidateExecution()
    self.currentSpec=spec
    if not identity(operation,pending) then return nil,'rotation-transition-superseded' end
    local db=self.db;local profile=db and db.profile
    local actualSpec,id=self.currentSpec,self.currentRotation
    if not identity(operation,pending) or not identity(profile,pending.profile)
        or not identity(actualSpec,spec) or not identity(id,pending.id) then return nil,'rotation-transition-superseded' end
    invalidateExecution()
    local nextToken={};pending.token=nextToken;pending.spec=spec
    pending.cleanupSpec,pending.cleanupID=nil,nil
    return nextToken
end
local function retire(self,token)
    local pending=operation
    if not current(self,token) then return nil,'rotation-transition-superseded' end
    local spec,id=self.currentSpec,self.currentRotation
    if not identity(operation,pending) or not current(self,token) then return nil,'rotation-transition-superseded' end
    if id~=nil then pending.cleanupSpec,pending.cleanupID=spec,id end
    invalidateExecution();active=nil;write(self,'currentRotation',nil);pending.id=nil
    return true
end
addon.RetireActiveRotationTransition=retire
function addon:GetActiveRotationCleanupSelection()
    local pending=operation
    if not owned(self) or not pending or not current(self,pending.token) then return nil end
    return pending.cleanupSpec,pending.cleanupID,pending.token
end
local function commit(self,token,spec,id,body)
    if not current(self,token) then return nil,'rotation-transition-superseded' end
    local pending=operation
    if kind(spec)~='number' or spec<0 or spec%1~=0 or spec~=pending.spec
        or kind(id)~='string' or id=='' then return nil,'invalid-active-rotation' end
    if body==nil then
        local get=self.GetRuntimeRotation
        if not current(self,token) then return nil,'rotation-transition-superseded' end
        body=get(self,spec,id)
    end
    if not current(self,token) then return nil,'rotation-transition-superseded' end
    local data=self.RotationData
    if not current(self,token) then return nil,'rotation-transition-superseded' end
    if kind(body)~='table' or meta(body)~=nil then return nil,'rotation-unavailable' end
    local getRevision=data.GetRotationContentRevision
    if not current(self,token) then return nil,'rotation-transition-superseded' end
    local revision,why=getRevision(body)
    if not current(self,token) then return nil,'rotation-transition-superseded' end
    if not revision then return nil,why end
    local copy=data.CopyData
    if not current(self,token) then return nil,'rotation-transition-superseded' end
    local copied,problem=copy(body)
    if not current(self,token) then return nil,'rotation-transition-superseded' end
    if not copied then return nil,problem and problem.code or 'rotation-unavailable' end
    copied=detached(copied);if not copied then return nil,'rotation-unavailable' end
    local available=self.GetScopedRotationCoordinator
    if not current(self,token) then return nil,'rotation-transition-superseded' end
    local coordinator
    if available then
        local get=self.GetScopedRotationCoordinator
        if not current(self,token) then return nil,'rotation-transition-superseded' end
        coordinator=get(self)
    end
    if not current(self,token) then return nil,'rotation-transition-superseded' end
    local reference
    if coordinator then
        local resolve=coordinator.Resolve
        if not current(self,token) then return nil,'rotation-transition-superseded' end
        reference,why=resolve(coordinator,spec,id)
        if not current(self,token) then return nil,'rotation-transition-superseded' end
        if not reference then return nil,why end
        copy=data.CopyData
        if not current(self,token) then return nil,'rotation-transition-superseded' end
        reference,problem=copy(reference)
        if not current(self,token) then return nil,'rotation-transition-superseded' end
        if not reference then return nil,problem and problem.code or 'rotation-unavailable' end
        reference=detached(reference);if not reference then return nil,'rotation-unavailable' end
    end
    local unchanged=active and identity(active.profile,pending.profile) and active.spec==spec and active.id==id
        and equal(active.reference,reference) and equal(active.body,copied)
    if not current(self,token) then return nil,'rotation-transition-superseded' end
    local handle=unchanged and active.token or {}
    invalidateExecution()
    active={token=handle,profile=pending.profile,spec=spec,id=id,reference=reference,body=copied,revision=revision}
    pending.cleanupSpec,pending.cleanupID=nil,nil
    write(self,'currentRotation',id);pending.id=id
    return handle
end
addon.CommitActiveRotationTransition=commit
function addon:RefreshActiveRotation(spec,previousKey,nextKey)
    if not owned(self) then return nil,'foreign-rotation-owner' end
    if spec~=self.currentSpec or self.currentRotation==nil then return true end
    local token,why=begin(self);if not token then return nil,why end
    local id=self.currentRotation
    if previousKey and id==previousKey then id=nextKey or id end
    local handle,problem=commit(self,token,spec,id)
    if not handle and current(self,token) then retire(self,token) end
    return handle,problem
end

-- Trusted module handoff: writers prepare before their final authority checks;
-- the owned completion has no extension/native/copy/iterator callouts.
local function preparePublication(spec,previousKey,previousReference,nextReference,body,original,fallbackKey)
    if not identity(spec,raw(addon,'currentSpec')) or raw(addon,'currentRotation')==nil then return nil end
    local token=begin(addon)
    if not current(addon,token) then return nil end
    local pending=operation;local id=pending.id
    local selected=previousKey~=nil and id==previousKey
    if previousReference then
        local reference=active and active.reference
        if not reference then
            local available=addon.GetScopedRotationCoordinator
            if not current(addon,token) then return nil end
            local coordinator
            if available then
                local get=addon.GetScopedRotationCoordinator
                if not current(addon,token) then return nil end
                coordinator=get(addon)
            end
            if not current(addon,token) then return nil end
            if coordinator then
                local resolve=coordinator.Resolve
                if not current(addon,token) then return nil end
                reference=resolve(coordinator,spec,id)
            end
            if not current(addon,token) then return nil end
        end
        selected=selected or equal(reference,previousReference)
        if fallbackKey and id==fallbackKey and nextReference then
            local nextAddress=raw(nextReference,'address')
            local oldAddress=kind(reference)=='table' and raw(reference,'address')
            selected=selected or kind(nextAddress)=='table' and (raw(nextAddress,'scope')=='character'
                or kind(oldAddress)=='table' and raw(oldAddress,'scope')=='class')
        end
    elseif original then
        local roots=kind(pending.profile)=='table' and raw(pending.profile,'rotations')
        local rows=kind(roots)=='table' and raw(roots,spec)
        local selectedBody=kind(rows)=='table' and raw(rows,id)
        selected=identity(selectedBody,original)
    end
    local ticket={};pending.publication={token=ticket,selected=selected}
    if not selected then return ticket end
    local copied=detached(body);local reference=nextReference and detached(nextReference)
    if not copied or nextReference and not reference then return nil end
    local revision=raw(copied,'revision')
    if revision~=nil and (kind(revision)~='number' or revision<1 or revision>9007199254740991 or revision%1~=0) then return nil end
    local unchanged=active and identity(active.profile,pending.profile) and active.spec==spec and active.id==id
        and equal(active.reference,reference) and equal(active.body,copied)
    pending.publication={token=ticket,selected=true,body=copied,reference=reference,revision=revision or 1,
        handle=unchanged and active.token or {},previousKey=previousKey}
    return ticket
end
local function finishPublication(ticket,nextKey)
    if ticket==nil then return true end
    local pending=operation;local prepared=pending and pending.publication
    if not prepared or not identity(prepared.token,ticket) then return nil end
    local db=raw(addon,'db')
    if kind(db)~='table' or not identity(raw(db,'profile'),pending.profile)
        or not identity(raw(addon,'currentSpec'),pending.spec) or not identity(raw(addon,'currentRotation'),pending.id) then return nil end
    pending.publication=nil
    if not prepared.selected then return true,pending.token end
    local id=pending.id
    if nextKey and prepared.previousKey==id then id=nextKey end
    invalidateExecution()
    active={token=prepared.handle,profile=pending.profile,spec=pending.spec,id=id,
        reference=prepared.reference,body=prepared.body,revision=prepared.revision}
    pending.cleanupSpec,pending.cleanupID=nil,nil
    write(addon,'currentRotation',id);pending.id=id
    return prepared.handle,pending.token
end
local function prepareRebind(fallbackKey)
    if raw(addon,'currentRotation')==nil then invalidateExecution();active=nil;return nil end
    local token=begin(addon)
    if not token or not current(addon,token) then return nil,nil,token end
    local pending=operation;local spec,id=pending.spec,pending.id
    if id==nil then return nil,nil,token,spec,id end
    protect(commit,addon,token,spec,id)
    if not current(addon,token) then return nil,nil,token,spec,id end
    local reference
    if active and identity(active.profile,pending.profile) and active.spec==spec and active.id==id then
        reference=active.reference
    end
    local ticket={};pending.rebind={token=ticket,reference=reference and detached(reference),fallbackKey=fallbackKey}
    return ticket,reference and detached(reference),token,spec,id
end
local function finishRebind(ticket,key,reference,body)
    if ticket==nil then return true end
    local pending=operation;local prepared=pending and pending.rebind
    if not prepared or not identity(prepared.token,ticket) then return nil end
    local db=raw(addon,'db')
    if kind(db)~='table' or not identity(raw(db,'profile'),pending.profile)
        or not identity(raw(addon,'currentSpec'),pending.spec) or not identity(raw(addon,'currentRotation'),pending.id) then return nil end
    local copied=detached(body);local resolved=detached(reference)
    local valid=kind(key)=='string' and key~='' and copied and resolved
        and (pending.id==prepared.fallbackKey or prepared.reference and equal(prepared.reference,resolved))
    pending.rebind=nil;pending.cleanupSpec,pending.cleanupID=nil,nil
    if not valid then invalidateExecution();active=nil;write(addon,'currentRotation',nil);pending.id=nil;return nil,pending.token end
    local revision=raw(copied,'revision') or 1
    if kind(revision)~='number' or revision<1 or revision>9007199254740991 or revision%1~=0 then
        invalidateExecution();active=nil;write(addon,'currentRotation',nil);pending.id=nil;return nil,pending.token
    end
    local handle={}
    invalidateExecution()
    active={token=handle,profile=pending.profile,spec=pending.spec,id=key,reference=resolved,body=copied,revision=revision}
    write(addon,'currentRotation',key);pending.id=key
    return handle,pending.token
end
-- Source-private runtime access: the identity body never leaves this module.
local function runtimeIdentity(owner,spec,key)
    if not owned(owner) or not active or kind(raw(owner,'db'))~='table' then return end
    if not identity(raw(raw(owner,'db'),'profile'),active.profile)
        or not identity(raw(owner,'currentSpec'),spec) or not identity(active.spec,spec)
        or not identity(raw(owner,'currentRotation'),key) or not identity(active.id,key) then return end
    return active.token,active.revision,operation and operation.token
end
local function runtimeBody(owner,handle,expected)
    if not active or not identity(active.token,handle) or not runtimeIdentity(owner,active.spec,active.id) then return end
    if expected~=nil and not equal(active.body,expected) then return end
    return detached(active.body)
end
function addon:BindActiveRotationPublication(receiver)
    if not owned(self) or kind(receiver)~='function' then return nil end
    receiver(preparePublication,finishPublication,prepareRebind,finishRebind,runtimeIdentity,runtimeBody)
    return true
end
