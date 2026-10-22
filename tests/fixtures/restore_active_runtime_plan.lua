-- Exact full runtime stage to Git025e44a. No permissive text removal.
local rows={}
do
 local before=[[local _,addon=...
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
    self.currentSpec=spec
    if not identity(operation,pending) then return nil,'rotation-transition-superseded' end
    local db=self.db;local profile=db and db.profile
    local actualSpec,id=self.currentSpec,self.currentRotation
    if not identity(operation,pending) or not identity(profile,pending.profile)
        or not identity(actualSpec,spec) or not identity(id,pending.id) then return nil,'rotation-transition-superseded' end
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
    active=nil;write(self,'currentRotation',nil);pending.id=nil
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
    active={token=prepared.handle,profile=pending.profile,spec=pending.spec,id=id,
        reference=prepared.reference,body=prepared.body,revision=prepared.revision}
    pending.cleanupSpec,pending.cleanupID=nil,nil
    write(addon,'currentRotation',id);pending.id=id
    return prepared.handle,pending.token
end
local function prepareRebind(fallbackKey)
    if raw(addon,'currentRotation')==nil then active=nil;return nil end
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
    if not valid then active=nil;write(addon,'currentRotation',nil);pending.id=nil;return nil,pending.token end
    local revision=raw(copied,'revision') or 1
    if kind(revision)~='number' or revision<1 or revision>9007199254740991 or revision%1~=0 then
        active=nil;write(addon,'currentRotation',nil);pending.id=nil;return nil,pending.token
    end
    local handle={}
    active={token=handle,profile=pending.profile,spec=pending.spec,id=key,reference=resolved,body=copied,revision=revision}
    write(addon,'currentRotation',key);pending.id=key
    return handle,pending.token
end
function addon:BindActiveRotationPublication(receiver)
    if not owned(self) or kind(receiver)~='function' then return nil end
    receiver(preparePublication,finishPublication,prepareRebind,finishRebind)
    return true
end
]]
 local after=before
 after=after:sub(1,14237)..[[    receiver(preparePublication,finishPublication,prepareRebind,finishRebind,runtimeIdentity,runtimeBody)
]]..after:sub(14316)
 after=after:sub(1,14109)..[[-- Source-private runtime access: the identity body never leaves this module.
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
]]..after:sub(14110)
 rows['Core/rotation_active.lua']={before=before,after=after}
end
do
 local before=[[local _,addon=...
local observed,stamp
local dependencyReader
local bindDependency=addon.BindRotationDependencyReader
if type(bindDependency)=='function' then
    bindDependency(addon,function(reader) if type(reader)=='function' then dependencyReader=reader end end)
    addon.BindRotationDependencyReader=nil
end
local dependencyIdentity=rawequal
local managed
-- Trusted standard primitives at module load; changed live pointers disable reuse.
local proofPairs,proofRawget,proofRawequal,proofType,proofGetmetatable=pairs,rawget,rawequal,type,getmetatable
-- Lua5.1 accepts a stack level or function; the checker declares only levels.
---@type fun(f: number|function): table
local proofGetfenv=getfenv
local proofEnvironment=proofType(proofGetfenv)=='function' and proofGetfenv(1) or nil
local function normalized(value)
    return type(value)=='table' and value or false
end
local function entries(value)
    local result,count={},0
    if type(value)=='table' then
        for key,item in pairs(value) do result[key]=normalized(item);count=count+1 end
    end
    return result,count
end
local function sameEntries(value,previous,expected)
    local count=0
    if type(value)=='table' then
        for key,item in pairs(value) do
            if not rawequal(type(item)=='table' and item or false,previous[key]) then return false end
            count=count+1
        end
    end
    return count==expected
end
local function validItemsets(shared,personal)
    return (shared==nil or type(shared)=='table') and (personal==nil or type(personal)=='table')
end
local function sameItemsets(shared,personal,previous,expected)
    if not validItemsets(shared,personal) then return expected==0 end
    local count=0
    if shared then
        for key,item in pairs(shared) do
            -- Only actual personal entries shadow shared entries. A missing-key
            -- lookup could materialize an AceDB default and mutate the source.
            if not personal or rawget(personal,key)==nil then
                if not rawequal(type(item)=='table' and item or false,previous[key]) then return false end
                count=count+1
            end
        end
    end
    if personal then
        for key,item in pairs(personal) do
            if not rawequal(type(item)=='table' and item or false,previous[key]) then return false end
            count=count+1
        end
    end
    return count==expected
end
local function itemsetEntries(shared,personal)
    if not validItemsets(shared,personal) then return {},0 end
    local result,count=entries(shared)
    if personal then
        for key,item in pairs(personal) do
            if result[key]==nil then count=count+1 end
            result[key]=normalized(item)
        end
    end
    return result,count
end
-- Observe identities without copying maps on the common unchanged path.
-- Normalized false markers keep malformed/NaN entries stable, as before.
local function observeLegacy(owner)
    local profile,global=owner.db.profile,owner.db.global
    local shared,personal=global.itemsets,profile.itemsets
    local conditions,effects=owner.conditionDefinitions,global.effects
    local version=owner.conditionRegistryVersion or 0
    if observed and observed.profile==profile and observed.global==global and observed.version==version
        and sameItemsets(shared,personal,observed.itemsets,observed.itemsetCount)
        and sameEntries(conditions,observed.conditions,observed.conditionCount)
        and sameEntries(effects,observed.effects,observed.effectCount) then return end
    local itemsets,itemsetCount=itemsetEntries(shared,personal)
    local conditionEntries,conditionCount=entries(conditions)
    local effectEntries,effectCount=entries(effects)
    observed={profile=profile,global=global,version=version,
        itemsets=itemsets,itemsetCount=itemsetCount,
        conditions=conditionEntries,conditionCount=conditionCount,
        effects=effectEntries,effectCount=effectCount}
    stamp={}
end
-- Managed ownership does not require plain/default-free maps. AceDB may
-- materialize default metatables; contents change through explicit publication.
local function observe(owner)
    if not dependencyReader or not dependencyIdentity(owner,addon) then
        observeLegacy(owner);return observed,stamp
    end
    local epoch=dependencyReader(owner)
    local db=owner.db;local profile,global=db.profile,db.global
    local conditions,version=owner.conditionDefinitions,owner.conditionRegistryVersion or 0
    local shared,personal,effects=global.itemsets,profile.itemsets,global.effects
    if not managed or not dependencyIdentity(managed.epoch,epoch) or not dependencyIdentity(managed.db,db)
        or not dependencyIdentity(managed.profile,profile) or not dependencyIdentity(managed.global,global)
        or not dependencyIdentity(managed.conditions,conditions) or not dependencyIdentity(managed.shared,shared)
        or not dependencyIdentity(managed.personal,personal) or not dependencyIdentity(managed.effects,effects)
        or not dependencyIdentity(managed.version,version) then
        managed={epoch=epoch,db=db,profile=profile,global=global,conditions=conditions,
            shared=shared,personal=personal,effects=effects,version=version,stamp={}}
    end
    -- Public options copy actual source maps, never a retained private map.
    -- Capture this invocation's roots and generation before live iteration.
    return managed,managed.stamp
end
-- Internal authority checks need the current stamp, not detached public maps.
-- Keep checking every dependency at each call, including reentrant mutations.
function addon:GetRotationValidationStamp()
    local _,current=observe(self)
    return current
end
local ownedValidationStamp=addon.GetRotationValidationStamp
-- Even protected metatable metadata can disguise a callback. Only native
-- primitives stored directly in the owned environment can certify this path.
local function proofGlobals()
    return proofType(proofEnvironment)=='table' and proofRawequal(proofRawget(proofEnvironment,'pairs'),proofPairs)
        and proofRawequal(proofRawget(proofEnvironment,'rawget'),proofRawget) and proofRawequal(proofRawget(proofEnvironment,'rawequal'),proofRawequal)
        and proofRawequal(proofRawget(proofEnvironment,'type'),proofType) and proofRawequal(proofRawget(proofEnvironment,'getmetatable'),proofGetmetatable)
        and proofRawequal(proofRawget(proofEnvironment,'getfenv'),proofGetfenv)
        and proofRawequal(proofGetfenv(ownedValidationStamp),proofEnvironment)
        and proofRawequal(proofGetfenv(observe),proofEnvironment) and proofRawequal(proofGetfenv(observeLegacy),proofEnvironment) and proofRawequal(proofGetfenv(normalized),proofEnvironment)
        and proofRawequal(proofGetfenv(entries),proofEnvironment) and proofRawequal(proofGetfenv(sameEntries),proofEnvironment)
        and proofRawequal(proofGetfenv(validItemsets),proofEnvironment) and proofRawequal(proofGetfenv(sameItemsets),proofEnvironment)
        and proofRawequal(proofGetfenv(itemsetEntries),proofEnvironment)
end
local function proofPlain(value)
    return proofType(value)=='table' and proofGetmetatable(value)==nil
end
-- Only raw-present, callback-free layouts can join adjacent observations.
-- AceAddon owners and AceDB db objects may have metatables: every accessed
-- slot is raw-present, and neither object participates in equality/tostring.
local function validationLayout(owner,method)
    if proofType(owner)~='table'
        or method~=ownedValidationStamp or proofRawget(owner,'GetRotationValidationStamp')~=ownedValidationStamp then return end
    -- Public option copying uses live pairs; a prior override can retain its
    -- private input maps. Their later lookups must remain callback-free too.
    if not proofPlain(observed) or not proofPlain(stamp)
        or not proofPlain(proofRawget(observed,'itemsets'))
        or not proofPlain(proofRawget(observed,'conditions'))
        or not proofPlain(proofRawget(observed,'effects')) then return end
    local db=proofRawget(owner,'db');if proofType(db)~='table' then return end
    local profile,global=proofRawget(db,'profile'),proofRawget(db,'global')
    if not proofPlain(profile) or not proofPlain(global) then return end
    local conditions,version=proofRawget(owner,'conditionDefinitions'),proofRawget(owner,'conditionRegistryVersion')
    local shared,personal=proofRawget(global,'itemsets'),proofRawget(profile,'itemsets')
    local effects,state=proofRawget(global,'effects'),proofRawget(profile,'rotationLibrary')
    if not proofPlain(conditions) or proofType(version)~='number' or not proofPlain(shared)
        or not proofPlain(personal) or not proofPlain(effects) or not proofPlain(state) then return end
    return db,profile,global,conditions,shared,personal,effects,version,state
end
local function sameValidationLayout(owner,method,db,profile,global,conditions,shared,personal,effects,version,state)
    local d,p,g,c,s,i,e,v,l=validationLayout(owner,method)
    return d~=nil and proofRawequal(d,db) and proofRawequal(p,profile) and proofRawequal(g,global)
        and proofRawequal(c,conditions) and proofRawequal(s,shared) and proofRawequal(i,personal)
        and proofRawequal(e,effects) and proofRawequal(v,version) and proofRawequal(l,state)
end
local function readValidationStamp(owner,method,entryMethod)
    if dependencyReader and dependencyIdentity(owner,addon) then
        local value=method(owner);return value
    end
    local db,profile,global,conditions,shared,personal,effects,version,state
    -- A successful PRE proof closes the owned scan. POST checks raw layout
    -- again, without repeating globals that no permitted callback can change.
    if entryMethod==ownedValidationStamp and proofGlobals() then db,profile,global,conditions,shared,personal,effects,version,state=validationLayout(owner,method) end
    local value=method(owner)
    if db then return value,db,profile,global,conditions,shared,personal,effects,version,state end
    return value
end
-- Trusted private module handoff, retired by its consumer. This does not
-- authenticate a hostile replacement of the complete loader/binder itself.
function addon:BindRotationValidationReader(bind)
    if type(bind)~='function' then return nil,'invalid-validation-reader-binder' end
    bind(readValidationStamp,sameValidationLayout,proofRawget,proofRawequal,proofType,proofGetmetatable)
    return true
end
-- Dependency maps may carry AceDB defaults metatables. Observe their entries,
-- without copying/traversing definitions or writing into SavedVariables.
function addon:GetRotationValidationOptions()
    local snapshot,current=observe(self)
    -- Public maps remain fresh: consumers cannot poison private observations.
    local conditions=entries(snapshot.conditions)
    local itemsets
    if dependencyReader and dependencyIdentity(self,addon) then
        itemsets=itemsetEntries(snapshot.shared,snapshot.personal)
    else itemsets=entries(snapshot.itemsets) end
    local effects=entries(snapshot.effects)
    return {conditions=conditions,itemsets=itemsets,effects=effects},current
end

-- Legacy bodies have no envelope. Inspect their semantic condition edges too,
-- so a disabled definition cannot be bypassed by a later priority action.
function addon:HasDisabledRotationDependency(body)
    local definitions=self.conditionDefinitions or {}
    local hasDisabled=false
    for _,definition in pairs(definitions) do if type(definition)=='table' and definition.disabled then hasDisabled=true;break end end
    if not hasDisabled then return false end
    local tree=self.RotationData.IndexRotationSteps(body,{allowMissingIds=true})
    if not tree then return true end
    local count=0
    local condition,declared
    declared=function(value,schema,depth)
        if value==nil then return false end
        if depth>64 then return true end
        if schema=='condition' then return condition(value,depth+1) end
        if schema=='condition[]' then
            if type(value)~='table' then return true end
            for _,child in ipairs(value) do if condition(child,depth+1) then return true end end
        elseif type(schema)=='table' and type(value)=='table' then
            if schema[1]~=nil then
                -- Union schemas may contain object/list alternatives. Inspect
                -- only alternatives that declare nested conditions.
                for _,alternative in ipairs(schema) do if declared(value,alternative,depth+1) then return true end end
            else
                for key,kind in pairs(schema) do if declared(value[key],kind,depth+1) then return true end end
            end
        end
        return false
    end
    condition=function(value,depth)
        if value==nil then return false end
        count=count+1;if count>4096 or depth>64 or type(value)~='table' then return true end
        if value.type=='AND' or value.type=='OR' then return declared(value.value,'condition[]',depth+1) end
        if value.type=='NOT' then return condition(value.value,depth+1) end
        local definition=definitions[value.type]
        if type(definition)=='table' then
            if definition.disabled then return true end
            for key,kind in pairs(definition.fields or {}) do if declared(value[key],kind,depth+1) then return true end end
        end
        return false
    end
    if condition(body.switch,0) then return true end
    for _,row in ipairs(tree.rows) do if condition(row.step.conditions,0) then return true end end
    return false
end

-- BEGIN PRIVATE VALIDATION CPU HANDOFF
do
 local bind=addon.BindCPUValidationScopeDiagnostic
 if type(bind)=='function' then bind(addon,'references',ownedValidationStamp,function() return observe,sameEntries,sameItemsets,proofGlobals end) end
end
-- END PRIVATE VALIDATION CPU HANDOFF
]]
 local after=before
 after=after:sub(1,13550)..[[ownedDisabledDependency=addon.HasDisabledRotationDependency

]]..after:sub(13551)
 after=after:sub(1,11124)..[[end

ownedOptions=addon.GetRotationValidationOptions
-- Constant-time managed publication authority; unknown property layouts and
-- public overrides retain the existing eager reader. No membership scan.
runtimeAuthority=function(owner)
    if not dependencyReader or not dependencyIdentity(owner,addon)
        or proofRawget(owner,'GetRotationValidationOptions')~=ownedOptions
        or proofRawget(owner,'GetRotationValidationStamp')~=ownedValidationStamp
        or proofRawget(owner,'HasDisabledRotationDependency')~=ownedDisabledDependency
        or proofType(proofGetfenv)~='function' or proofGetfenv(ownedOptions)~=proofEnvironment
        or proofGetfenv(ownedValidationStamp)~=proofEnvironment or proofGetfenv(ownedDisabledDependency)~=proofEnvironment then return end
    local db=proofRawget(owner,'db');if proofType(db)~='table' then return end
    local profile,global=proofRawget(db,'profile'),proofRawget(db,'global')
    if proofType(profile)~='table' or proofType(global)~='table' then return end
    local conditions,shared,personal,effects=proofRawget(owner,'conditionDefinitions'),proofRawget(global,'itemsets'),proofRawget(profile,'itemsets'),proofRawget(global,'effects')
    if not proofPlain(conditions) or not proofPlain(shared) or not proofPlain(personal) or not proofPlain(effects) then return end
    return dependencyReader(owner),db,profile,global,conditions,
        proofRawget(owner,'conditionRegistryVersion'),proofRawget(global,'itemsets'),
        proofRawget(profile,'itemsets'),proofRawget(global,'effects'),proofRawget(profile,'rotationLibrary')
]]..after:sub(11125)
 after=after:sub(1,10310)..[[    bind(readValidationStamp,sameValidationLayout,proofRawget,proofRawequal,proofType,proofGetmetatable,runtimeAuthority,ownedOptions,ownedDisabledDependency)
]]..after:sub(10416)
 after=after:sub(1,362)..[[local runtimeAuthority,ownedOptions,ownedDisabledDependency
]]..after:sub(363)
 rows['Core/rotation_references.lua']={before=before,after=after}
end
do
 local before=[=[local addon_name, addon = ...
local invalidateChoiceContext=addon.InvalidateRotationChoiceContext
local data = addon.RotationData
local activeCurrent=addon.IsActiveRotationTransitionCurrent
local beginActive=addon.BeginActiveRotationTransition
local retireActive=addon.RetireActiveRotationTransition
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local definitions, definitionVersion = {}, 0
local active
local readValidationStamp,checkValidationLayout,validationRawget,validationRawequal,validationType,validationGetmetatable
local bindValidation=addon.BindRotationValidationReader
if type(bindValidation)=='function' then
    bindValidation(addon,function(read,check,raw,identity,kind,meta)
        if type(read)=='function' and type(check)=='function' and type(raw)=='function'
            and type(identity)=='function' and type(kind)=='function' and type(meta)=='function' then
            readValidationStamp,checkValidationLayout,validationRawget,validationRawequal,validationType,validationGetmetatable=read,check,raw,identity,kind,meta
        end
    end)
    addon.BindRotationValidationReader=nil
end
local function validationPlain(value)
    return validationType(value)=='table' and validationGetmetatable(value)==nil
end

local function contains(list, value)
    for _,entry in ipairs(list or {}) do if entry==value then return true end end
    return false
end
local function matchesClass(view,context)
    local scope=view.applicability
    return not scope or not scope.class or scope.class==context.class
end
local function eligible(view, context, candidates)
    if not view.enabled then return false,"disabled" end
    if not view.validation.valid or not view.validation.supported or not view.validation.resolved then return false,"invalid-or-unsupported" end
    if not matchesClass(view,context) then return false,"class-mismatch" end
    if candidates then return true end
    local scope=view.applicability
    if not scope or not contains(scope.families,context.family) then return false,"edition-mismatch" end
    if scope.specs and not contains(scope.specs,context.spec) then return false,"specialization-mismatch" end
    if scope.actionContext~=context.actionContext then return false,"action-context-mismatch" end
    for _,range in ipairs({{"minLevel","maxLevel","level"},{"minBuild","maxBuild","build"}}) do
        local value=context[range[3]]
        if scope[range[1]] or scope[range[2]] then
            if type(value)~="number" then return false,"missing-"..range[3] end
            if scope[range[1]] and value<scope[range[1]] or scope[range[2]] and value>scope[range[2]] then return false,range[3].."-mismatch" end
        end
    end
    -- These selectors need dedicated context providers before execution is safe.
    -- Keep their definitions visible for reference rather than assuming a match.
    if scope.rulesets or scope.intent or scope.roles then return false,"unsupported-context-selector" end
    if context.combatDataPolicy~="probe" then return false,"restricted-or-unsupported-client" end
    return true
end
local function plainTable(value)
    return type(value)=="table" and getmetatable(value)==nil
end

function addon:RegisterDefaultRotation(envelope)
    local copy,why=data.CopyData(envelope)
    if not copy then return false,why.code end
    if copy.format~="RotationMaster" or copy.schemaVersion~=1 or not data.ValidateEnvelope(copy).valid then return false,"invalid-envelope" end
    if not copy.applicability.class and copy.applicability.universal~=true then return false,"missing-class-scope" end
    if definitions[copy.id] then return false,"duplicate-default-id" end
    definitions[copy.id]=copy;definitionVersion=definitionVersion+1
    return true
end

function addon:InitializeRotationLibrary()
    local profile=self.db.profile
    local validation,referenceStamp=self:GetRotationValidationOptions()
    local state=profile.rotationLibrary
    if state==nil then state={};profile.rotationLibrary=state end
    if not plainTable(state) then active=nil;return false,"invalid-library-state" end
    for _,key in ipairs({"preferences","origins","comparisons","imports"}) do
        if state[key]~=nil and not plainTable(state[key]) then active=nil;return false,"invalid-library-state" end
    end
    state.preferences,state.origins,state.comparisons,state.imports=state.preferences or {},state.origins or {},state.comparisons or {},state.imports or {}
    -- Only preferences are shared with the persisted namespace. Clone construction
    -- uses a temporary catalog; the legacy editor retains the sole saved body.
    local catalog,why=data.NewCatalog({state={preferences=state.preferences},
        validation=validation,newId=self.uuid})
    if not catalog then active=nil;return false,why end
    local views,bodies={},{}
    for id,envelope in pairs(definitions) do
        local ok,reason=catalog:RegisterBuiltin(envelope)
        if not ok then active=nil;return false,reason end
        views[id]=catalog:Get({kind="builtin",id=id})
        bodies[id]=data.CopyData(views[id].envelope.body)
        bodies[id].name=L[views[id].nameKey]
    end
    active={profile=profile,state=state,catalog=catalog,views=views,bodies=bodies,cloneScopes={},version=definitionVersion,referenceStamp=referenceStamp,generation={}}
    for spec,origins in pairs(state.origins) do
        if type(spec)=="number" and plainTable(origins) then
            active.cloneScopes[spec]={}
            for id in pairs(origins) do
                local view=self:GetSourcedRotationView(spec,id)
                if view then
                    view.validation=data.ValidateEnvelope(view.envelope,validation)
                    view.enabled=true
                end
                active.cloneScopes[spec][id]=view or false
            end
        end
    end
    return true
end
local ownedInitializeRotationLibrary=addon.InitializeRotationLibrary
local function ensure(self,needProof)
    local referenceStamp,method,db,profile,global,conditions,shared,personal,effects,version,state
    local plainStamps=false
    if needProof and readValidationStamp then
        local entryMethod=validationType(self)=='table' and validationRawget(self,'GetRotationValidationStamp') or nil
        method=self.GetRotationValidationStamp
        referenceStamp,db,profile,global,conditions,shared,personal,effects,version,state=readValidationStamp(self,method,entryMethod)
        plainStamps=db~=nil and validationPlain(referenceStamp) and active~=nil
            and validationPlain(active.referenceStamp) and validationPlain(active.generation)
    else referenceStamp=self:GetRotationValidationStamp() end
    if not active or active.profile~=self.db.profile or active.state~=self.db.profile.rotationLibrary
        or active.version~=definitionVersion or active.referenceStamp~=referenceStamp then
        -- Initializer overrides may return arbitrary extras; none can authorize
        -- the private unchanged-branch witness. Generation historically used two.
        if needProof then local ok,why=self:InitializeRotationLibrary();return ok,why end
        return self:InitializeRotationLibrary()
    end
    -- An initializer call never issues proof, even if it returns the same generation.
    if plainStamps and validationRawequal(validationRawget(self,'InitializeRotationLibrary'),ownedInitializeRotationLibrary)
        and checkValidationLayout(self,method,db,profile,global,conditions,shared,personal,effects,version,state) then
        return true,nil,referenceStamp,true
    end
    return true
end

-- Platform facts used for selection are public identity/context observations.
-- Restricted results never enter comparisons or portable-data traversal.
function addon:GetRotationContext(spec)
    local context=self.Platform:GetClientInfo()
    local function read(fn,...)
        if type(fn)~="function" then return nil end
        local ok,value=pcall(fn,...)
        if ok and self.Platform:CanReadValue(value) then return value end
    end
    local function class() local _,token=UnitClass("player");return token end
    context.class=read(class)
    context.level=read(UnitLevel,"player")
    context.build=tonumber(context.build)
    context.spec=spec
    context.actionContext="player"
    local vehicle=read(UnitHasVehicleUI,"player")
    if vehicle==nil then vehicle=read(UnitInVehicle,"player") end
    if vehicle then context.actionContext="vehicle" end
    if C_PetBattles and read(C_PetBattles.IsInBattle) then context.actionContext="petbattle" end
    return context
end
local ownedRotationContext=addon.GetRotationContext
local clientContextReader
local ownedReadValue=addon.Platform.CanReadValue
local contextIpairs,contextRawget,contextEqual=ipairs,rawget,rawequal
local contextPairs=pairs
---@type fun(f: number|function): table
local contextGetfenv=getfenv
local contextEnvironment=type(contextGetfenv)=="function" and contextGetfenv(1) or nil
local bindClient=addon.BindRotationClientReader
if type(bindClient)=='function' then
    bindClient(addon,function(reader) clientContextReader=reader end)
    addon.BindRotationClientReader=nil
end
-- Only the exact owned methods use the narrow projection. Overrides retain
-- their actual receiver, first result, shared table and error behavior.
local function rotationContext(owner,spec)
    local method=owner.GetRotationContext
    if method~=ownedRotationContext or not clientContextReader then local value=method(owner,spec);return value,false end
    local context,private=clientContextReader(owner.Platform)
    local function read(fn,...)
        if type(fn)~="function" then return nil end
        local ok,value=pcall(fn,...)
        if ok and owner.Platform:CanReadValue(value) then return value end
    end
    local function class() local _,token=UnitClass("player");return token end
    context.class=read(class)
    context.level=read(UnitLevel,"player")
    context.build=tonumber(context.build)
    context.spec=spec
    context.actionContext="player"
    local vehicle=read(UnitHasVehicleUI,"player")
    if vehicle==nil then vehicle=read(UnitInVehicle,"player") end
    if vehicle then context.actionContext="vehicle" end
    if C_PetBattles and read(C_PetBattles.IsInBattle) then context.actionContext="petbattle" end
    return context,private==true
end
-- Uncovered vehicle/pet-battle notifications retain fresh observation at every
-- publication boundary, even when the other owned eligibility facts are reused.
local function runtimeActionContext(owner)
    local function read(fn,...)
        if type(fn)~="function" then return nil end
        local ok,value=pcall(fn,...)
        if ok and owner.Platform:CanReadValue(value) then return value end
    end
    local result="player"
    local vehicle=read(UnitHasVehicleUI,"player")
    if vehicle==nil then vehicle=read(UnitInVehicle,"player") end
    if vehicle then result="vehicle" end
    if C_PetBattles and read(C_PetBattles.IsInBattle) then result="petbattle" end
    return result
end
local function runtimeKey(id, custom)
    local key="RM-BUILTIN:"..id
    while custom[key]~=nil do key=":"..key end
    return key
end
-- One-time handoff to the scoped coordinator. No canonical source getter stays
-- on the addon surface after its consumer captures this private reader.
function addon:BindRotationLibraryReader(bind)
    if type(bind)~='function' then return nil,'invalid-library-reader-binder' end
    local owner=self;local reader={}
    function reader:OwnsContext(fn) return fn==ownedRotationContext end
    local function contextMethod(self,spec) return rotationContext(owner,spec) end
    reader.Context=contextMethod
    local function ownsPrivateContext(method,projection,dispatch)
        return contextGetfenv and contextEnvironment
            and contextEqual(method,contextMethod) and contextEqual(contextRawget(reader,'Context'),contextMethod)
            and contextEqual(contextGetfenv(contextMethod),contextEnvironment) and contextEqual(contextGetfenv(rotationContext),contextEnvironment)
            and contextEqual(contextGetfenv(projection),contextEnvironment) and contextEqual(contextGetfenv(dispatch),contextEnvironment)
            and contextEqual(contextRawget(contextEnvironment,'ipairs'),contextIpairs)
    end
    local function runtimeContextGuard(value,method,projection,dispatch)
        local platform=owner.Platform
        if not ownsPrivateContext(method,projection,dispatch) or owner.GetRotationContext~=ownedRotationContext
            or platform.CanReadValue~=ownedReadValue or type(value)~='table'
            or value.class==nil or type(value.level)~='number' or value.level~=value.level or value.level<=0 or value.level>=math.huge
            or type(value.build)~='number' or value.build~=value.build or value.build<=0 or value.build>=math.huge or value.family=='unknown'
            or contextRawget(contextEnvironment,'pairs')~=contextPairs then return nil end
        local client,readValue=platform.GetClientInfo,platform.CanReadValue
        local unitClass,unitLevel,buildInfo,project=UnitClass,UnitLevel,GetBuildInfo,WOW_PROJECT_ID
        local hasVehicle,inVehicle,petBattles=UnitHasVehicleUI,UnitInVehicle,C_PetBattles
        local inBattle=petBattles and petBattles.IsInBattle
        local secret,access=issecretvalue,canaccessvalue
        return function()
            if not ownsPrivateContext(method,projection,dispatch) or owner.GetRotationContext~=ownedRotationContext
                or owner.Platform~=platform or platform.GetClientInfo~=client or platform.CanReadValue~=readValue
                or UnitClass~=unitClass or UnitLevel~=unitLevel or GetBuildInfo~=buildInfo or WOW_PROJECT_ID~=project
                or UnitHasVehicleUI~=hasVehicle or UnitInVehicle~=inVehicle or C_PetBattles~=petBattles
                or (petBattles and petBattles.IsInBattle)~=inBattle
                or issecretvalue~=secret or canaccessvalue~=access
                or contextGetfenv(runtimeActionContext)~=contextEnvironment or contextGetfenv(readValue)~=contextEnvironment
                or contextGetfenv(client)~=contextEnvironment
                or contextRawget(contextEnvironment,'pairs')~=contextPairs then return nil end
            return runtimeActionContext(owner)==value.actionContext
        end
    end
    local function generationMethod(self)
        local ok,why,checked,proof=ensure(owner,true);if not ok then return nil,why end
        return active.generation,nil,checked,proof
    end
    reader.Generation=generationMethod
    -- The checker captures the definition-owned method; a replaced reader field
    -- cannot authorize its own returned proof. Nil checks the pre-dispatch layout.
    local function provesGeneration(method,reference,generation)
        return validationRawget~=nil and validationPlain(reader) and validationPlain(reference) and validationPlain(generation)
            and validationRawequal(validationRawget(reader,'Generation'),generationMethod)
            and (method==nil or validationRawequal(method,generationMethod))
    end
    function reader:Read(spec,id,project,candidates)
        local ok,why=ensure(owner);if not ok then return nil,why end
        local view=active.views[id];if not view then return nil,'unknown-rotation' end
        local context=rotationContext(owner,spec);context.spec=spec
        if not matchesClass(view,context) then return nil,'class-mismatch' end
        local allowed,reason=eligible(view,context,candidates)
        return true,project(view,active.bodies[id],allowed,reason),active.generation
    end
    function reader:List(spec,project)
        local ok,why=ensure(owner);if not ok then return nil,why end
        local context=rotationContext(owner,spec);context.spec=spec;local rows={}
        for id,view in pairs(active.views) do if matchesClass(view,context) then rows[#rows+1]=project(id,view,active.bodies[id]) end end
        return rows,active.generation
    end
    function reader:Eligible(view,spec,candidates) local context=rotationContext(owner,spec);context.spec=spec;return eligible(view,context,candidates) end
    function reader:Reserve(used) for id,envelope in pairs(definitions) do used[id]=true;data.ReserveRotationIdentities(envelope,used) end end
    bind(reader,provesGeneration,ownsPrivateContext,runtimeContextGuard);return true
end

function addon:ListDefaultRotations(spec)
    local ok,why=ensure(self)
    if not ok then return {},why end
    local context=self:GetRotationContext(spec);context.spec=spec
    local custom=(self.db.profile.rotations or {})[spec] or {}
    local rows={}
    for id,view in pairs(active.views) do
        if matchesClass(view,context) then
            local row=data.CopyData(view)
            local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
            row.runtimeKey=scoped and scoped:Key({kind='builtin',id=id}) or runtimeKey(id,custom)
            row.eligible,row.eligibilityReason=eligible(view,context)
            row.name=L[row.nameKey or id]
            row.description=L[row.descriptionKey or ""]
            rows[#rows+1]=row
        end
    end
    table.sort(rows,function(a,b) if a.name==b.name then return a.id<b.id end;return a.name<b.name end)
    return rows
end
function addon:GetDefaultRotation(id)
    if not ensure(self) then return nil end
    return active.catalog:Get({kind="builtin",id=id})
end
function addon:SetDefaultRotationEnabled(id,value)
    local change=beginActive(self)
    local ok,why=ensure(self);if not ok then return false,why end
    local selected=self.currentRotation and self:GetDefaultIdForRuntime(self.currentSpec,self.currentRotation)==id
    if not activeCurrent(self,change) then return false,'rotation-transition-superseded' end
    local saved,reason=active.catalog:SetEnabled({kind="builtin",id=id},value)
    if saved then active.views[id]=active.catalog:Get({kind="builtin",id=id});active.generation={}
        if invalidateChoiceContext then invalidateChoiceContext(self) end
    end
    if saved and not value and selected and activeCurrent(self,change) then
        local disable=self.DisableRotation
        if not activeCurrent(self,change) then return saved,reason end
        if type(disable)=='function' then
            local _,nextChange,stopped=disable(self)
            if stopped~=false and activeCurrent(self,nextChange or change) then self.manualRotation=false end
        elseif retireActive(self,change) and activeCurrent(self,change) then self.manualRotation=false end
    end
    return saved,reason
end
function addon:GetEditableRotation(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:GetEditableRotation(spec,id) end
    local rotations=self.db.profile.rotations[spec]
    return rotations and rotations[id]
end
function addon:OwnsRotationCondition(spec,id,step,condition)
    local body=self:GetEditableRotation(spec,id)
    local tree=body and data.IndexRotationSteps(body,{allowMissingIds=true})
    if not tree then return false end
    for _,row in ipairs(tree.rows) do if row.step==step and step.conditions==condition then return true end end
    return false
end
function addon:GetRuntimeRotations(spec, internal, candidates)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    if scoped then local pass,why=scoped:RuntimePass(spec);if not pass then return {},why end;local rows,reason=pass:Candidates(candidates==true);for key,body in pairs(rows) do local ref=scoped:Resolve(spec,key);if ref and ref.kind=='custom' then rows[key]=scoped:GetEditableRotation(spec,key) else rows[key]=data.CopyData(body) end end;return rows,reason end
    local rotations={}
    if spec==nil then return rotations end
    local ready=ensure(self)
    local context=self:GetRotationContext(spec);context.spec=spec
    -- Editing/export use the saved-data facade independently. Legacy bodies
    -- must obey the same client execution policy as packaged/scoped rotations.
    if context.combatDataPolicy~="probe" then return rotations end
    local origins=ready and active.state.origins[spec]
    local scopes=ready and active.cloneScopes[spec]
    for id,body in pairs(self.db.profile.rotations[spec] or {}) do
        local scoped=scopes and scopes[id]
        local imported,importError
        if self.GetImportedRotationView then imported,importError=self:GetImportedRotationView(spec,id) end
        if scoped then
            -- The legacy editor mutates the saved body directly. Inspect its
            -- current structure without copying/traversing the historical baseline.
            scoped.envelope.body=body
            scoped.validation=data.ValidateEnvelope(scoped.envelope,self:GetRotationValidationOptions())
            scoped.applicability=scoped.envelope.applicability
        end
        if not origins or plainTable(origins) and origins[id]==nil
            or scoped and eligible(scoped,context,candidates) then
            if (not self.GetImportedRotationView or importError=="not-imported" or imported and eligible(imported,context,candidates))
                and not self:HasDisabledRotationDependency(body) then rotations[id]=body end
        end
    end
    if not ready then return rotations end
    for id,view in pairs(active.views) do
        if eligible(view,context,candidates) then
            local body=internal and active.bodies[id] or data.CopyData(active.bodies[id])
            -- Only the trusted engine receives private bodies; it must never edit.
            -- Public callers receive independent snapshots.
            rotations[runtimeKey(id,rotations)]=body
        end
    end
    return rotations
end
function addon:GetRuntimeRotation(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then
        local pass,why=scoped:RuntimePass(spec);if not pass then return nil,why end
        local body,bodyReason=pass:Get(id);if not body then return nil,bodyReason end
        local reference=scoped:Resolve(spec,id);if reference.kind=='custom' then return scoped:GetEditableRotation(spec,reference) end
        return data.CopyData(body)
    end
    return self:GetRuntimeRotations(spec,true)[id]
end
function addon:CloneDefaultRotation(spec,id,name,options)
    local coordinator=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if coordinator then return coordinator:Copy(spec,{kind='builtin',id=id},name,options) end
    local ok,why=ensure(self);if not ok then return nil,why end
    local profile=self.db.profile;local roots,library=profile.rotations,profile.rotationLibrary
    local source=active.catalog:Get({kind="builtin",id=id})
    if not source then return nil,"unknown-rotation" end
    local context=self:GetRotationContext(spec)
    if not data.IsRotationClassToken(context.class) or not matchesClass(source,context) then return nil,"class-mismatch" end
    local state={}
    local temporary=data.NewCatalog({state=state,newId=self.uuid})
    assert(temporary:RegisterBuiltin(source.envelope))
    local generated,reason=temporary:Clone({kind="builtin",id=id},name)
    if not generated then return nil,reason end
    if self.db.profile~=profile or profile.rotations~=roots or profile.rotationLibrary~=library then return nil,'rotation-changed-externally' end
    local rotations=self.db.profile.rotations[spec] or {}
    if rotations[generated]~=nil then return nil,"id-collision" end
    local view=temporary:Get({kind="custom",id=generated})
    local manifest=view.envelope;local body=manifest.body;manifest.body=nil
    if manifest.applicability.universal then
        manifest.applicability.universal=nil;manifest.applicability.class=context.class
    end
    local origins=active.state.origins[spec]
    if origins~=nil and not plainTable(origins) then return nil,"invalid-origin-state" end
    origins=origins or {}
    if origins[generated]~=nil then return nil,"id-collision" end
    self.db.profile.rotations[spec]=rotations;rotations[generated]=body
    active.state.origins[spec]=origins;origins[generated]={manifest=manifest,lineage=view.lineage}
    local scoped=self:GetSourcedRotationView(spec,generated)
    scoped.validation=data.ValidateEnvelope(scoped.envelope,self:GetRotationValidationOptions())
    scoped.enabled=true
    active.cloneScopes[spec]=active.cloneScopes[spec] or {};active.cloneScopes[spec][generated]=scoped
    return generated
end
function addon:GetSourcedRotationView(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:SourceView(spec,id,false) end
    local ok,why=ensure(self);if not ok then return nil,why end
    local origins=active.state.origins[spec]
    if origins==nil then return nil,"no-source-baseline" end
    if not plainTable(origins) then return nil,"invalid-origin-state" end
    if origins[id]==nil then return nil,"no-source-baseline" end
    local origin,problem=data.CopyData(origins[id])
    if problem or not plainTable(origin) or not plainTable(origin.manifest) or origin.manifest.id~=id then return nil,"invalid-origin-state" end
    local body=self:GetEditableRotation(spec,id)
    if not body then return nil,"unknown-rotation" end
    local envelope=data.CopyData(origin.manifest);envelope.body=data.CopyData(body)
    if not envelope.body then return nil,"invalid-custom-body" end
    -- Catalog validates both current structure and retained historical lineage.
    local state={custom={[id]=envelope},lineage={[id]=origin.lineage}}
    local catalog,reason=data.NewCatalog({state=state})
    if not catalog then return nil,reason end
    local view=catalog:Get({kind="custom",id=id})
    if view.lineageError then return nil,"invalid-origin-state" end
    return view
end

function addon:IsDefaultRuntimeRotation(spec,key)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return self:GetDefaultIdForRuntime(spec,key)~=nil end
    if not ensure(self) then return false end
    local custom=(self.db.profile.rotations or {})[spec] or {}
    for id in pairs(active.views) do if runtimeKey(id,custom)==key then return true end end
    return false
end

function addon:GetDefaultIdForRuntime(spec,key)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then local ref=scoped:Resolve(spec,key);return ref and ref.kind=='builtin' and ref.id or nil end
    if not ensure(self) then return nil end
    local custom=(self.db.profile.rotations or {})[spec] or {}
    for id in pairs(active.views) do if runtimeKey(id,custom)==key then return id end end
end

-- Candidate identities survive level/context changes within the declared class.
-- Current eligibility is
-- always checked again by the runtime facade when switching or evaluating.
function addon:GetRotationCandidates(spec)
    return self:GetRuntimeRotations(spec,true,true)
end
function addon:GetRotationForCleanup(spec,key)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:Cleanup(spec,key) end
    local custom=self:GetEditableRotation(spec,key)
    if custom then return custom end
    if not ensure(self) then return nil end
    local saved=self.db.profile.rotations[spec] or {}
    for id,body in pairs(active.bodies) do if runtimeKey(id,saved)==key then return body end end
end

-- Correspondence for ordinary duplicates needs only origin IDs. It must not
-- pretend an incomplete legacy body is a validated historical envelope.
function addon:GetRotationComparisonIdentity(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:ComparisonIdentity(spec,id) end
    if not ensure(self) then return nil,"invalid-library-state" end
    local rows=active.state.comparisons[spec]
    if rows~=nil and not plainTable(rows) then return nil,"invalid-comparison-origin" end
    local identity
    if rows and rows[id]~=nil then
        local why
        identity,why=data.CopyData(rows[id])
        if why or not plainTable(identity) or (identity.kind~="custom" and identity.kind~="builtin")
            or type(identity.id)~="string" or not plainTable(identity.origins) then return nil,"invalid-comparison-origin" end
    end
    local view,viewError=self:GetSourcedRotationView(spec,id)
    if not view and viewError~="no-source-baseline" then return nil,viewError end
    if view then
        if identity and (identity.kind~=view.lineage.sourceKind or identity.id~=view.lineage.sourceId) then return nil,"invalid-comparison-origin" end
        identity=identity or {kind=view.lineage.sourceKind,id=view.lineage.sourceId,origins={}}
        for key,origin in pairs(view.lineage.stepOrigins) do identity.origins[key]=origin end
        return identity
    end
    if self.GetImportedRotationView then
        local imported,why=self:GetImportedRotationView(spec,id)
        if imported then return {kind="import",id=imported.sourceId,origins=imported.stepOrigins}
        elseif why~="not-imported" then return nil,why end
    end
    return identity or {kind="custom",id=id}
end

-- Transitional legacy editing still writes bodies directly. Duplication must use
-- a real data copy, fresh step identities, and explicitly retain source lineage.
function addon:DuplicateCustomRotation(spec,id,name,options)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:Copy(spec,id,name,options) end
    local profile=self.db.profile;local roots,library=profile.rotations,profile.rotationLibrary
    if self.GetImportedRotationView then
        local imported,reason=self:GetImportedRotationView(spec,id)
        if imported then
            local prepared={body=imported.envelope.body,manifest=data.CopyData(imported.envelope),sourceId=imported.sourceId,
                sourceRevision=imported.sourceRevision,stepOrigins=imported.stepOrigins}
            local revision,problem=data.GetRotationContentRevision(prepared.body);if not revision then return nil,problem end
            prepared.manifest.body=nil;prepared.body.revision=1
            if self.db.profile~=profile or profile.rotations~=roots or profile.rotationLibrary~=library then return nil,'rotation-changed-externally' end
            return self:CreateImportedRotation(prepared,spec,name)
        elseif reason~="not-imported" then return nil,reason end
    end
    local source=self:GetEditableRotation(spec,id)
    local body,problem=data.CopyData(source)
    if problem or type(body)~="table" then return nil,"invalid-custom-body" end
    local revision,revisionError=data.GetRotationContentRevision(body);if not revision then return nil,revisionError end
    if type(name)~="string" or name=="" then return nil,"invalid-name" end
    if self.db.profile~=profile or profile.rotations~=roots or profile.rotationLibrary~=library then return nil,'rotation-changed-externally' end
    local ok,why=ensure(self);if not ok then return nil,why end
    if library==nil then library=profile.rotationLibrary end
    local origins=active.state.origins[spec]
    if origins~=nil and not plainTable(origins) then return nil,"invalid-origin-state" end
    local sourceView
    if origins and origins[id]~=nil then
        sourceView,why=self:GetSourcedRotationView(spec,id)
        if not sourceView then return nil,why end
    end
    local identity,identityError=self:GetRotationComparisonIdentity(spec,id)
    if not identity then return nil,identityError end
    local correspondence={kind=identity.kind,id=identity.id,origins={}}
    local comparisonRows=active.state.comparisons[spec]
    if comparisonRows~=nil and not plainTable(comparisonRows) then return nil,"invalid-comparison-origin" end
    local used={}
    for _,rotations in pairs(self.db.profile.rotations) do
        if type(rotations)=="table" then
            for key,rotation in pairs(rotations) do
                used[key]=true
                data.ReserveRotationIdentities(rotation,used)
            end
        end
    end
    local function reserve(value) if type(value)=="string" then used[value]=true end end
    local function reserveEnvelope(envelope)
        reserve(envelope.id)
        data.ReserveRotationIdentities(envelope,used)
    end
    for _,envelope in pairs(definitions) do reserveEnvelope(envelope) end
    for _,rows in pairs(active.state.origins) do
        if plainTable(rows) then
            for key,raw in pairs(rows) do
                reserve(key)
                local entry=data.CopyData(raw)
                local retained=type(entry)=="table" and entry.lineage
                if type(retained)=="table" then
                    reserve(retained.sourceId);reserve(retained.clonedFrom)
                    if type(retained.baseline)=="table" then reserveEnvelope(retained.baseline) end
                    if type(retained.stepOrigins)=="table" then for step,origin in pairs(retained.stepOrigins) do reserve(step);reserve(origin) end end
                end
            end
        end
    end
    for _,rows in pairs(active.state.comparisons) do
        if plainTable(rows) then
            for key,raw in pairs(rows) do
                reserve(key)
                local retained=data.CopyData(raw)
                if type(retained)=="table" then
                    reserve(retained.id)
                    if type(retained.origins)=="table" then for step,origin in pairs(retained.origins) do reserve(step);reserve(origin) end end
                end
            end
        end
    end
    local function fresh()
        local generatedOk,value=pcall(self.uuid)
        if not generatedOk or type(value)~="string" or #value>128 or not value:match("^[%w][%w._:%-]*$") then return nil,"invalid-id-provider" end
        if used[value] or definitions[value] then return nil,"id-collision" end
        used[value]=true;return value
    end
    local generated,reason=fresh();if not generated then return nil,reason end
    local lineage=sourceView and data.CopyData(sourceView.lineage)
    local previousOrigins=lineage and lineage.stepOrigins
    if lineage then lineage.clonedFrom=id;lineage.stepOrigins={} end
    local indexed,indexError=data.IndexRotationSteps(body,{allowMissingIds=true})
    if not indexed then return nil,indexError.code end
    for _,row in ipairs(indexed.rows) do
        local entry=row.step
        local stepId,errorCode=fresh();if not stepId then return nil,errorCode end
        if lineage then lineage.stepOrigins[stepId]=previousOrigins[entry.id] end
        correspondence.origins[stepId]=identity.origins and identity.origins[entry.id] or entry.id
        entry.id=stepId
    end
    body.name=name;body.revision=1
    local metadata
    if sourceView then
        local manifest=data.CopyData(sourceView.envelope);manifest.body=nil;manifest.id=generated;manifest.revision=1;manifest.nameKey=name
        metadata={manifest=manifest,lineage=lineage}
    end
    if origins and origins[generated]~=nil or comparisonRows and comparisonRows[generated]~=nil then return nil,"id-collision" end
    if self.db.profile~=profile or profile.rotations~=roots or profile.rotationLibrary~=library then return nil,'rotation-changed-externally' end
    self.db.profile.rotations[spec][generated]=body
    if metadata then origins[generated]=metadata end
    comparisonRows=comparisonRows or {};active.state.comparisons[spec]=comparisonRows
    comparisonRows[generated]=correspondence
    self:InitializeRotationLibrary()
    return generated
end

function addon:BuildRotationComparison(spec,id,target)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    if scoped then
        local reference,why=scoped:Resolve(spec,id);if not reference then return nil,why end
        if not target then return nil,'missing-comparison-target' end
        local targetReference
        if type(target)=='table' and target.kind=='custom' and not target.address then targetReference,why=scoped:Resolve(spec,target.id)
        else targetReference,why=scoped:Resolve(spec,target) end
        if not targetReference then return nil,why end
        local function sameAddress(a,b)
            if a.kind~=b.kind then return false end;if a.kind=='builtin' then return a.id==b.id end
            for _,key in ipairs({'scope','class','owner','spec','id'}) do if a.address[key]~=b.address[key] then return false end end;return true
        end
        if sameAddress(reference,targetReference) then return nil,'self-comparison' end
        local current,currentReason=scoped:Snapshot(spec,reference);if not current then return nil,currentReason end
        local other,targetReason=scoped:Snapshot(spec,targetReference);if not other then return nil,targetReason end
        local view=scoped:SourceView(spec,reference,false)
        if view and targetReference.kind=='builtin' and view.lineage.sourceKind=='builtin' and view.lineage.sourceId==targetReference.id then
            local source=other.source;local result=data.CompareClone(view,source)
            result.views={{key='current',left=data.CopyData(source.envelope),right=data.CopyData(view.envelope),rightOrigins=data.CopyData(view.lineage.stepOrigins),diff=result.currentDifferences},
                {key='source',left=data.CopyData(view.lineage.baseline),right=data.CopyData(source.envelope),diff=result.sourceChanges},
                {key='custom',left=data.CopyData(view.lineage.baseline),right=data.CopyData(view.envelope),rightOrigins=data.CopyData(view.lineage.stepOrigins),diff=result.customChanges}}
            return result
        end
        local left,leftError=scoped:ComparisonIdentity(spec,targetReference);local right,rightError=scoped:ComparisonIdentity(spec,reference)
        if not left or not right then return nil,leftError or rightError end
        local options={}
        local exact=left.kind=='builtin' or left.kind=='import' or left.kind=='custom' and left.sourceAddress and right.sourceAddress and sameAddress({kind='custom',address=left.sourceAddress},{kind='custom',address=right.sourceAddress})
        if exact and left.kind==right.kind and left.id==right.id then options.leftOrigins,options.rightOrigins=left.origins,right.origins end
        local leftValue=data.RotationComparisonValue(other.body,self:GetRotationTags(spec,targetReference))
        local rightValue=data.RotationComparisonValue(current.body,self:GetRotationTags(spec,reference))
        local result=data.DiffRotations(leftValue,rightValue,options)
        result.views={{key='current',left=leftValue,right=rightValue,leftOrigins=data.CopyData(options.leftOrigins),rightOrigins=data.CopyData(options.rightOrigins),diff=data.CopyData(result)}}
        return result
    end
    if target and target.kind=="custom" and target.id==id then return nil,"self-comparison" end
    local body=self:GetEditableRotation(spec,id)
    if not body then return nil,"unknown-rotation" end
    local view,viewError=self:GetSourcedRotationView(spec,id)
    if not view and viewError~="no-source-baseline" then return nil,viewError end
    if target and target.kind=="builtin" then
        local source=self:GetDefaultRotation(target.id)
        if not source then return nil,"unknown-rotation" end
        if view and view.lineage.sourceKind=="builtin" and view.lineage.sourceId==target.id then
            local result=data.CompareClone(view,source)
            result.views={
                {key="current",left=data.CopyData(source.envelope),right=data.CopyData(view.envelope),rightOrigins=data.CopyData(view.lineage.stepOrigins),diff=result.currentDifferences},
                {key="source",left=data.CopyData(view.lineage.baseline),right=data.CopyData(source.envelope),diff=result.sourceChanges},
                {key="custom",left=data.CopyData(view.lineage.baseline),right=data.CopyData(view.envelope),rightOrigins=data.CopyData(view.lineage.stepOrigins),diff=result.customChanges},
            }
            return result
        end
        local leftValue=data.RotationComparisonValue(source.envelope.body,source.envelope.tags)
        local rightValue=data.RotationComparisonValue(body,self:GetRotationTags(spec,id))
        local result=data.DiffRotations(leftValue,rightValue)
        leftValue.nameKey=source.envelope.nameKey
        result.views={{key="current",left=leftValue,right=rightValue,diff=data.CopyData(result)}}
        return result
    elseif target and target.kind=="custom" then
        local other=self:GetEditableRotation(spec,target.id)
        if not other then return nil,"unknown-rotation" end
        local left,leftError=self:GetRotationComparisonIdentity(spec,target.id)
        local right,rightError=self:GetRotationComparisonIdentity(spec,id)
        if not left or not right then return nil,leftError or rightError end
        local options={}
        if left.kind==right.kind and left.id==right.id then options.leftOrigins,options.rightOrigins=left.origins,right.origins end
        local leftValue=data.RotationComparisonValue(other,self:GetRotationTags(spec,target.id))
        local rightValue=data.RotationComparisonValue(body,self:GetRotationTags(spec,id))
        local result=data.DiffRotations(leftValue,rightValue,options)
        result.views={{key="current",left=leftValue,right=rightValue,
            leftOrigins=data.CopyData(options.leftOrigins),rightOrigins=data.CopyData(options.rightOrigins),diff=data.CopyData(result)}}
        return result
    end
    return nil,"missing-comparison-target"
end

function addon:DeleteCustomRotation(spec,id,expected)
    local change=beginActive(self)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then
        local reference,why=scoped:Resolve(spec,id);if not reference then return nil,why end
        if reference.kind=='builtin' then return nil,'read-only-rotation' end
        if not expected then local record;record,expected=scoped:Snapshot(spec,reference);if not record then return nil,expected end end
        local currentReference=self.currentRotation and (self.currentSpec==nil or self.currentSpec==spec) and scoped:Resolve(spec,self.currentRotation)
        local deletingCurrent=currentReference and currentReference.kind=='custom'
        if deletingCurrent then for _,field in ipairs({'scope','class','owner','spec','id'}) do if currentReference.address[field]~=reference.address[field] then deletingCurrent=false;break end end end
        local ok,problem=scoped:Delete(reference,expected)
        if not ok then return nil,problem end
        if deletingCurrent and activeCurrent(self,change) then
            if retireActive(self,change) and activeCurrent(self,change) then
                self.manualRotation=false
                local available=self.RemoveAllCurrentGlows
                if available and activeCurrent(self,change) then
                    local remove=self.RemoveAllCurrentGlows
                    if activeCurrent(self,change) then remove(self) end
                end
            end
        end
        return true
    end
    if id==(DEFAULT or L['Default']) or self:GetDefaultIdForRuntime(spec,id) then return nil,'read-only-rotation' end
    local body=self:GetEditableRotation(spec,id)
    if type(body)~='table' then return nil,'unknown-rotation' end
    local ready,why=ensure(self);if not ready then return nil,why end
    for _,key in ipairs({'origins','comparisons','imports'}) do
        if active.state[key][spec]~=nil and not plainTable(active.state[key][spec]) then return nil,'invalid-library-state' end
    end
    if self.currentRotation==id and (self.currentSpec==nil or self.currentSpec==spec) and activeCurrent(self,change) then
        if retireActive(self,change) and activeCurrent(self,change) then
            self.manualRotation=false
            local available=self.RemoveAllCurrentGlows
            if available and activeCurrent(self,change) then
                local remove=self.RemoveAllCurrentGlows
                if activeCurrent(self,change) then remove(self) end
            end
        end
    end
    if not activeCurrent(self,change) then return nil,'rotation-transition-superseded' end
    self.db.profile.rotations[spec][id]=nil
    for _,key in ipairs({'origins','comparisons','imports'}) do
        if active.state[key][spec] then active.state[key][spec][id]=nil end
    end
    if active.cloneScopes[spec] then active.cloneScopes[spec][id]=nil end
    return true
end

-- BEGIN PRIVATE VALIDATION CPU HANDOFF
do
 local bind=addon.BindCPUValidationScopeDiagnostic
 if type(bind)=='function' then bind(addon,'library',ownedInitializeRotationLibrary,function() return ensure,eligible end) end
end
-- END PRIVATE VALIDATION CPU HANDOFF
]=]
 local after=before
 after=after:sub(1,16241)..[[    local function runtimeGeneration()
        return active and active.generation,definitionVersion
    end
    bind(reader,provesGeneration,ownsPrivateContext,runtimeContextGuard,runtimeAuthority,eligible,ownedRotationContext,ownedReadValue,runtimeGeneration);return true
]]..after:sub(16327)
 after=after:sub(1,1055)..[[            runtimeAuthority,ownedOptions,ownedDisabledDependency=authority,options,disabled
]]..after:sub(1056)
 after=after:sub(1,634)..[[    bindValidation(addon,function(read,check,raw,identity,kind,meta,authority,options,disabled)
]]..after:sub(704)
 after=after:sub(1,537)..[[local runtimeAuthority,ownedOptions,ownedDisabledDependency
]]..after:sub(538)
 rows['Core/rotation_library.lua']={before=before,after=after}
end
do
 local before=[[local addon_name,addon=...
local data=addon.RotationData
local ownedStoreFactory,ownedStoreEnvironment
local bindOwnedStoreFactory=data.BindOwnedRotationStoreFactory
if type(bindOwnedStoreFactory)=='function' then
    bindOwnedStoreFactory(function(factory,environment) ownedStoreFactory,ownedStoreEnvironment=factory,environment end)
    data.BindOwnedRotationStoreFactory=nil
end
---@type fun(f: number|function): table
local storeGetfenv=getfenv
local storeScopeEnvironment=type(storeGetfenv)=='function' and storeGetfenv(1) or nil
local prepareChoicePublication,finishChoicePublication
local consumeChoices=addon.ConsumeRotationChoicePublication
if type(consumeChoices)=='function' then
    prepareChoicePublication,finishChoicePublication=consumeChoices(addon)
    addon.ConsumeRotationChoicePublication=nil
end
local invalidateChoiceContext=addon.InvalidateRotationChoiceContext
local prepareActivePublication,finishActivePublication,prepareActiveRebind,finishActiveRebind
local activeCurrent=addon.IsActiveRotationTransitionCurrent
local protect,raise=pcall,error
local preparedBinding,bindGeneration
local bindIdentity=rawequal
if type(addon.BindActiveRotationPublication)=='function' then
    addon:BindActiveRotationPublication(function(prepare,finish,rebind,complete)
        prepareActivePublication,finishActivePublication,prepareActiveRebind,finishActiveRebind=prepare,finish,rebind,complete
    end)
end
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local libraryReader,libraryGenerationProof,libraryContextProof,libraryRuntimeContextGuard
local evaluationRequest,contextVersion
contextVersion={}
local ownedRuntimePasses=setmetatable({},{__mode="kv"})
local bindLibrary=addon.BindRotationLibraryReader
if type(bindLibrary)=='function' then
    bindLibrary(addon,function(reader,proof,contextProof,runtimeGuard) libraryRuntimeContextGuard=runtimeGuard;libraryReader=reader;if type(proof)=='function' then libraryGenerationProof=proof end;if type(contextProof)=='function'then libraryContextProof=contextProof end end)
    addon.BindRotationLibraryReader=nil
end
local function rotationContext(owner,spec)
    local method=libraryReader and libraryReader.Context
    if type(method)=='function' then local value,private=method(libraryReader,spec);return value,private,method end
    local fallback=owner.GetRotationContext
    local value=fallback(owner,spec);return value,false
end
local current,serial
serial=0
-- Exposure survives explicit Refresh/rebinding while that canonical body lives.
local exposed=setmetatable({},{__mode='k'})
local function plain(v) return type(v)=='table' and getmetatable(v)==nil end
local function text(v,n) return type(v)=='string' and #v>0 and #v<=n and v:find('%S')~=nil and not v:find('[%z\1-\31\127]') end
local function copy(v) return data.CopyData(v) end
local function metadataView(value)
    if not plain(value) then return nil end
    local result={};for _,key in ipairs({'author','realm','email','website','version'}) do if type(value[key])=='string' then result[key]=value[key] end end;return result
end
local function tagsView(value)
    if value==nil then return nil end
    return data.NormalizeRotationTags(value) or false
end
local function same(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function addressKey(a) return a.scope..'\0'..a.class..'\0'..a.owner..'\0'..a.spec..'\0'..a.id end
local function validSpec(v) return type(v)=='number' and v>=0 and v<math.huge and v%1==0 end
local function customReference(r)
    if not plain(r) or r.kind~='custom' or not plain(r.address) then return false end
    for key in pairs(r) do if key~='kind' and key~='address' then return false end end
    for key in pairs(r.address) do if key~='scope' and key~='class' and key~='owner' and key~='spec' and key~='id' then return false end end
    local a=r.address
    return (a.scope=='class' or a.scope=='character') and data.IsRotationClassToken(a.class) and text(a.owner,512) and validSpec(a.spec) and text(a.id,128) and (a.scope~='class' or a.owner==a.class)
end
local function copyRecord(r) local out={} for _,k in ipairs({'body','origin','imported','comparison'}) do if r[k]~=nil then out[k]=copy(r[k]) end end return out end
local function referenceKey(r) return r.kind=='builtin' and 'builtin\0'..r.id or 'custom\0'..addressKey(r.address) end
function addon:GetRotationOwnerContext()
    local class
    local platform=self.Platform
    if libraryReader and type(libraryReader.OwnsContext)=='function' and libraryReader:OwnsContext(self.GetRotationContext)
        and type(platform)=='table' and type(platform.GetPlayerOwnerClassObservation)=='function' then
        class=platform:GetPlayerOwnerClassObservation()
    else
        local context=self:GetRotationContext(self.currentSpec)
        class=context and context.class
    end
    if not data.IsRotationClassToken(class) then return nil,'missing-owner-context' end
    local character=self.db.keys and self.db.keys.char
    if not text(character,512) then character=nil end
    return {class=class,character=character}
end
function addon:GetScopedRotationCoordinator()
    -- Once scoped mode is bound, a profile transition must fail closed until
    -- the explicit event handler rebinds it; never reopen the old flat adapter.
    return current
end
local function rebindContext()
    if not prepareActiveRebind then return nil end
    local ticket,reference,token,spec,id=prepareActiveRebind(DEFAULT)
    if not token then return nil end
    return {ticket=ticket,reference=reference,token=token,spec=spec,id=id}
end
local function completeRebind(binding,coordinator,problem)
    if not binding or not binding.ticket or not activeCurrent(addon,binding.token) then return end
    local function read(object,name,...)
        if not activeCurrent(addon,binding.token) then return nil end
        local method=object[name]
        if not activeCurrent(addon,binding.token) then return nil end
        local value=method(object,...)
        if not activeCurrent(addon,binding.token) then return nil end
        return value
    end
    local function resolve()
        if problem then return nil end
        local key=binding.id
        if key~=DEFAULT then
            if not binding.reference then return nil end
            local reference=read(coordinator,'Resolve',binding.spec,binding.reference)
            if not reference then return nil end
            key=read(coordinator,'Key',reference)
        end
        if not key then return nil end
        local reference=read(coordinator,'Resolve',binding.spec,key)
        local pass=reference and read(coordinator,'RuntimePass',binding.spec)
        local body=pass and read(pass,'Get',key)
        return key,reference,body
    end
    local ok,key,reference,body=protect(resolve)
    if not activeCurrent(addon,binding.token) then return end
    local handle,token=finishActiveRebind(binding.ticket,ok and key or nil,ok and reference or nil,ok and body or nil)
    if not handle and token and activeCurrent(addon,token) then addon.manualRotation=false end
end
local function runPreparedBind(owner,binding,method)
    local previous=preparedBinding;preparedBinding=binding
    local ok,result,reason=protect(method,owner)
    if preparedBinding==binding then preparedBinding=previous end
    if not ok then raise(result,0) end
    return result,reason
end
function addon:BindActiveRotationProfileRebind(receiver)
    if self~=addon or type(receiver)~='function' then return nil end
    receiver(rebindContext,runPreparedBind)
    return true
end
function addon:BindRotationProfile()
    if invalidateChoiceContext then invalidateChoiceContext(addon) end
    local bindToken={};bindGeneration=bindToken
    local binding,profile
    local function bindingCurrent()
        if bindGeneration~=bindToken or binding and not activeCurrent(self,binding.token) then return false end
        if profile then local db=self.db;if not bindIdentity(db and db.profile,profile) then return false end end
        return bindGeneration==bindToken
    end
    if self==addon then
        binding=preparedBinding or rebindContext()
        if binding then
            if binding.used or not bindingCurrent() then return nil,'rotation-transition-superseded' end
            binding.used=true
        end
    end
    if not bindingCurrent() then return nil,'rotation-transition-superseded' end
    local previous=current
    if previous then
        local retire=previous.Retire
        if not bindingCurrent() then return nil,'rotation-transition-superseded' end
        retire(previous)
        if not bindingCurrent() then return nil,'rotation-transition-superseded' end
    end
    local owner=self;profile=self.db.profile;local state=profile.rotationStore;local fallbackID=profile.rotationFallbackID
    local reader,store,problem,ownedPublicationGuard;local alive=true;local managedStoreReader=false
    if not libraryReader then problem='rotation-library-not-ready'
    elseif not text(profile.rotationFallbackID,128) then problem='missing-fallback-configuration'
    else
        local construct=data.NewRotationStore
        if not bindingCurrent() then return nil,'rotation-transition-superseded' end
        local getOptions=self.GetRotationValidationOptions
        if not bindingCurrent() then return nil,'rotation-transition-superseded' end
        local validation=getOptions(self)
        if not bindingCurrent() then return nil,'rotation-transition-superseded' end
        store,problem,ownedPublicationGuard=construct({state=state,fallbackID=profile.rotationFallbackID,validation=validation,bindInternalReader=function(value) reader=value end})
        managedStoreReader=construct==ownedStoreFactory and ownedStoreEnvironment~=nil
            and type(storeGetfenv)=='function' and getfenv==storeGetfenv and storeGetfenv(construct)==ownedStoreEnvironment
    end
    if not bindingCurrent() then return nil,'rotation-transition-superseded' end
    local coordinator={};current=coordinator
    local rosterStamp,rosterOwned,rosterLibrary,rosterValidation,rosterVirtual,rosterBuiltin
    local byKey,byReference,expected,pending,assets,headers,cleanup={},{},setmetatable({},{__mode='k'}),{},{},{},{}
    local function context() return owner:GetRotationOwnerContext() end
    local function ready()
        if not alive or owner.db.profile~=profile or profile.rotationStore~=state or profile.rotationFallbackID~=fallbackID then return nil,'rotation-profile-changed' end
        if problem then return nil,problem end
        return true
    end
    local function keyFor(reference)
        local index=referenceKey(reference);local key=byReference[index]
        if not key then serial=serial+1;key=string.char(1)..'rm:rotation:'..serial;byReference[index]=key;byKey[key]=copy(reference) end
        return key
    end
    local function validateReference(reference,number)
        if plain(reference) and reference.kind=='builtin' and text(reference.id,128) then
            local ok,why=libraryReader:Read(number,reference.id,function() return true end)
            if not ok then return nil,why end;return {kind='builtin',id=reference.id}
        end
        if not customReference(reference) then return nil,'invalid-rotation-reference' end
        local a=reference.address;local c,contextReason=context();if not c then return nil,contextReason end
        if c.class~=a.class or a.scope=='character' and c.character~=a.owner then return nil,'foreign-owner' end
        if a.spec~=number then return nil,'invalid-specialization' end
        -- The private store performs the complete typed address/class gate.
        local ok,reason=reader:Read(a,c,function() return true end)
        if not ok then return nil,reason end
        return copy(reference)
    end
    local function fallbackReference(number)
        local c,why=context();if not c or not c.character then return nil,why or 'missing-owner-context' end
        for _,scope in ipairs({'character','class'}) do
            local reference={kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=profile.rotationFallbackID}}
            local ok,reason=reader:Read(reference.address,c,function() return true end)
            if ok then return reference end
            if reason~='unknown-rotation' then return nil,reason end
        end
        return nil,'unknown-rotation'
    end
    function coordinator:CheckReady() return ready() end
    function coordinator:OwnsProfile(value) return value==profile end
    function coordinator:Retire() alive=false;if reader then reader:Retire() end;return true end
    function coordinator:Resolve(number,value)
        local ok,why=ready();if not ok then return nil,why end
        if not validSpec(number) then return nil,'invalid-specialization' end
        local ownerContext,ownerReason=context();if not ownerContext then return nil,ownerReason end
        if type(value)=='table' then
            if value.kind=='builtin' then return validateReference(value,number) end
            if customReference(value) then
                local p=pending[referenceKey(value)];if p then return self:PendingReference(number,p.reference) end
                return validateReference(value,number)
            end
            return nil,'invalid-rotation-reference'
        end
        if type(value)~='string' then return nil,'invalid-rotation-reference' end
        if byKey[value] then
            local reference=byKey[value];if pending[referenceKey(reference)] then return self:PendingReference(number,reference) end
            return validateReference(reference,number)
        end
        if value==DEFAULT then return fallbackReference(number) end
        local c,errorText=context();if not c then return nil,errorText end
        local rows,reason=reader:ListOwned(number,c);if not rows then return nil,reason end
        local found
        for _,row in ipairs(rows) do if row.address.id==value then
            if found then return nil,'ambiguous-rotation-reference' end
            found={kind='custom',address=row.address}
        end end
        return found or nil,not found and 'unknown-rotation' or nil
    end
    function coordinator:PendingReference(number,r)
        local c,contextReason=context();if not c then return nil,contextReason end
        local a=r.address;if a.spec~=number then return nil,'invalid-specialization' end
        if a.class~=c.class or a.scope=='character' and a.owner~=c.character then return nil,'foreign-owner' end
        return copy(r)
    end
    function coordinator:Key(reference) return keyFor(reference) end
    function coordinator:IsPending(reference) return customReference(reference) and pending[referenceKey(reference)]~=nil end
    function coordinator:StagePending(reference,scope)
        if not customReference(reference) then return nil,'invalid-rotation-reference' end
        local initial=referenceKey(reference);local draft=pending[initial];if not draft then return nil,'unknown-rotation' end
        local c,contextReason=context();if not c then return nil,contextReason end
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local target=copy(reference);target.address.scope=scope;target.address.owner=scope=='class' and c.class or c.character
        local index=referenceKey(target)
        -- A staged collision must not steal the existing owner's issued key.
        if byReference[index] and byReference[index]~=draft.key then return copy(target) end
        if draft.alias and draft.alias~=initial and draft.alias~=index then pending[draft.alias]=nil;byReference[draft.alias]=nil end
        draft.alias=index;draft.reference=target;pending[index]=draft;byReference[index]=draft.key;byKey[draft.key]=copy(target)
        return copy(target)
    end
    function coordinator:TokenCurrent(token)
        local issued=expected[token];if not issued or not ready() then return false end
        local c=context();if not c or not same(c,issued.context) then return false end
        local ok,value=reader:Read(issued.reference.address,c,function(record,seal)
            if seal~=issued.seal then return false end
            for _,key in ipairs({'body','origin','imported','comparison'}) do if not data.CheckPortable(record[key]) or not same(record[key],issued.baseline[key]) then return false end end
            return true
        end)
        return ok and value==true
    end
    function coordinator:Snapshot(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then
            local ok,record=libraryReader:Read(number,reference.id,function(view,body) return {body=copy(body),source=copy(view)} end)
            if not ok then return nil,record end;return record,nil,record.source.validation
        end
        local c,errorText=context();if not c then return nil,errorText end
        local record,token=store:Get(reference.address,c);if not record then return nil,token end
        local _,_,seal=reader:Read(reference.address,c,function() return true end)
        local public={};expected[public]={reference=copy(reference),token=token,context=c,seal=seal,baseline=copyRecord(record)}
        return record,public,data.ValidateBody(record.body,owner:GetRotationValidationOptions())
    end
    function coordinator:NewDraft(number,scope,fallback)
        if not validSpec(number) then return nil,'invalid-specialization' end
        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        scope=scope or 'class';if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local id=profile.rotationFallbackID
        if not fallback then
            local used={};if libraryReader then libraryReader:Reserve(used) end;local rows,errorText=store:AllStored();if not rows then return nil,errorText end
            for _,row in ipairs(rows) do used[row.address.id]=true;for _,component in pairs(row.record) do local ok,why=data.ReserveRotationIdentities(component,used);if not ok then return nil,why.code end end end
            for _,draft in pairs(pending) do used[draft.reference.address.id]=true end
            for _=1,100 do local success,candidate=pcall(owner.uuid);if success and text(candidate,128) and not used[candidate] and candidate~=profile.rotationFallbackID then id=candidate;break end;id=nil end
            if not id then return nil,'id-allocation-exhausted' end
        end
        local reference={kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=id}}
        local previous=pending[referenceKey(reference)];if previous then local resolved,pendingReason=self:PendingReference(number,previous.reference);if not resolved then return nil,pendingReason end;return resolved,previous.key end
        local exists,lookupReason=reader:Read(reference.address,c,function() return true end)
        if exists then return nil,'rotation-id-collision' end;if lookupReason~='unknown-rotation' then return nil,lookupReason end
        local key=keyFor(reference);pending[referenceKey(reference)]={reference=copy(reference),key=key}
        return copy(reference),key
    end
    function coordinator:LegacyDraft(number,id)
        local ok,why=ready();if not ok then return nil,why end
        if not validSpec(number) or not text(id,128) then return nil,'invalid-rotation-target' end
        if id==DEFAULT then return self:NewDraft(number,'class',true) end
        local c,contextReason=context();if not c then return nil,contextReason end
        local reference={kind='custom',address={scope='class',class=c.class,owner=c.class,spec=number,id=id}}
        local draft=pending[referenceKey(reference)];if draft then local resolved,pendingReason=self:PendingReference(number,draft.reference);if not resolved then return nil,pendingReason end;return resolved,draft.key end
        local rows,inventoryReason=store:AllStored();if not rows then return nil,inventoryReason end
        local used={};if libraryReader then libraryReader:Reserve(used) end
        for _,row in ipairs(rows) do used[row.address.id]=true;for _,component in pairs(row.record) do data.ReserveRotationIdentities(component,used) end end
        if used[id] then return nil,'unknown-rotation' end
        local key=keyFor(reference);pending[referenceKey(reference)]={reference=copy(reference),key=key};return reference,key
    end
    function coordinator:Commit(reference,token,record,scope,revisionPolicy)
        local ok,why=ready();if not ok then return nil,why end
        local c,errorText=context();if not c then return nil,errorText end
        if not customReference(reference) then return nil,'invalid-rotation-reference' end
        local a=reference.address;scope=scope or a.scope
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local destination=copy(a);destination.scope=scope;destination.owner=scope=='class' and c.class or c.character
        local issued=token and expected[token];local plan,reason
        if revisionPolicy~=nil and revisionPolicy~='import' then return nil,'invalid-rotation-revision-policy' end
        if not plain(record) then return nil,'invalid-record' end
        if token and (not issued or not same(issued.reference,reference) or not same(issued.context,c)) then return nil,'stale-rotation-record' end
        local previousKey=byReference[referenceKey(reference)]
        local moved=a.scope~=destination.scope or a.owner~=destination.owner
        local previous
        if issued then
            -- Compare the editor's existing empty-list normalization on a
            -- detached public snapshot; keep the issued authority seal exact.
            local snapshot,snapshotProblem=store:Get(a,c)
            if not snapshot then return nil,snapshotProblem end
            previous=snapshot.body
            if plain(previous) and plain(record.body) then
                if previous.rotation==nil and record.body.rotation~=nil then previous.rotation={} end
                if previous.cooldowns==nil and record.body.cooldowns~=nil then previous.cooldowns={} end
            end
        end
        local body,problem=data.PrepareRotationContentRevision(record.body,previous,
            token and 'edit' or revisionPolicy=='import' and 'import' or 'create',moved or revisionPolicy=='import')
        if not body then return nil,problem end
        local detached=copy(record);if not detached then return nil,'invalid-record' end
        record=detached;record.body=body
        local target={kind='custom',address=destination}
        local fallbackKey=destination.id==profile.rotationFallbackID and DEFAULT or nil
        local publication=prepareActivePublication and prepareActivePublication(a.spec,previousKey,reference,target,body,nil,fallbackKey)
        local choicePublication=prepareChoicePublication and prepareChoicePublication(profile,reference,target)
        local now,contextProblem=context()
        local readyNow,currentProblem=ready();if not readyNow then return nil,currentProblem end
        if not now then return nil,contextProblem end
        if not same(now,c) then return nil,'rotation-owner-changed' end
        if token then
            if not issued or not same(issued.reference,reference) or not same(issued.context,c) then return nil,'stale-rotation-record' end
            if a.scope~=destination.scope or a.owner~=destination.owner then plan,reason=store:PlanMove(a,destination,c,issued.token,record)
            else plan,reason=store:PlanReplace(a,record,c,issued.token) end
        else plan,reason=store:PlanCreate(destination,record,c) end
        if not plan then return nil,reason end
        local committed,problemText=store:Commit(plan,c);if not committed then return nil,problemText end
        if finishChoicePublication then finishChoicePublication(choicePublication,alive and current==coordinator) end
        if token then expected[token]=nil end
        local oldIndex=referenceKey(reference);local targetIndex=referenceKey(target)
        local draft=pending[oldIndex]
        if draft then
            for index,value in pairs(pending) do if value==draft then pending[index]=nil;if index~=targetIndex then byReference[index]=nil end end end
            byReference[targetIndex]=draft.key;byKey[draft.key]=copy(target)
        elseif oldIndex~=targetIndex then
            local oldKey=byReference[oldIndex];if oldKey then cleanup[oldKey]=assets[oldIndex] and assets[oldIndex].body;byKey[oldKey]=nil;byReference[oldIndex]=nil end
        end
        local nextKey=keyFor(target)
        local transition
        if finishActivePublication then local _,change=finishActivePublication(publication,nextKey);transition=change end
        return target,nil,transition
    end
    function coordinator:Delete(reference,token)
        local ok,why=ready();if not ok then return nil,why end
        local c,errorText=context();if not c then return nil,errorText end
        local issued=expected[token]
        if not issued or not same(issued.reference,reference) or not same(issued.context,c) then return nil,'stale-rotation-record' end
        if reference.address.id==profile.rotationFallbackID then return nil,'read-only-rotation' end
        local choicePublication=prepareChoicePublication and prepareChoicePublication(profile,reference,nil)
        local plan,reason=store:PlanDelete(reference.address,c,issued.token);if not plan then return nil,reason end
        local committed,problemText=store:Commit(plan,c);if not committed then return nil,problemText end
        if finishChoicePublication then finishChoicePublication(choicePublication,alive and current==coordinator) end
        local index=referenceKey(reference);local key=byReference[index]
        if key then cleanup[key]=assets[index] and assets[index].body;byKey[key]=nil;byReference[index]=nil;headers[key]=nil end
        assets[index]=nil;expected[token]=nil
        return true
    end
    function coordinator:Cleanup(number,value)
        if cleanup[value] then return cleanup[value] end
        local reference=type(value)=='string' and byKey[value]
        if reference and assets[referenceKey(reference)] then return assets[referenceKey(reference)].body end
        local pass=self:RuntimePass(number);return pass and pass:Get(value)
    end
    function coordinator:TagView(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then local ok,result=libraryReader:Read(number,reference.id,function(view) return {tags=copy(view.envelope.tags),sources=copy(view.envelope.sources),body={name=L[view.nameKey or reference.id]}} end);if not ok then return nil,result end;return result end
        local c=context();local ok,result=reader:Read(reference.address,c,function(record)
            local body=record.body;local retained=record.origin or record.imported;local manifest=retained and retained.manifest
            return {body={name=body.name,description=body.description,priority=body.priority,tags=tagsView(body.tags),metadata=metadataView(body.metadata)},tags=manifest and copy(manifest.tags),sources=manifest and copy(manifest.sources)}
        end)
        if not ok then return nil,result end;return result
    end
    function coordinator:StoredRecords() local ok,why=ready();if not ok then return nil,why end;return store:AllStored() end
    function coordinator:Unassigned()
        local ok,why=ready();if not ok then return nil,why end
        local rows,inventoryReason=store:AllStored();if not rows then return nil,inventoryReason end
        local result={};for _,row in ipairs(rows) do if row.address.scope=='legacy' then result[#result+1]=row end end;return result
    end
    local adoptionPlans=setmetatable({},{__mode='k'})
    function coordinator:PlanAdoption(selection,scope)
        local ok,why=ready();if not ok then return nil,why end
        local c,contextReason=context();if not c then return nil,contextReason end
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local target={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=selection.spec,id=selection.id}
        local plan,planReason=store:PlanLegacyAdoption({spec=selection.spec,id=selection.id},target,c);if not plan then return nil,planReason end
        local public={reference={kind='custom',address=copy(target)},selection=copy(selection),scope=scope}
        adoptionPlans[public]={plan=plan,context=c,target=target};return public
    end
    function coordinator:ApplyAdoption(public)
        local ok,why=ready();if not ok then return nil,why end
        local adoption=adoptionPlans[public];if not adoption then return nil,'invalid-adoption-plan' end
        local c,contextReason=context();if not c or not same(c,adoption.context) then return nil,contextReason or 'rotation-owner-changed' end
        local reference={kind='custom',address=copy(adoption.target)}
        local rows=profile.rotationStore.legacy.rotations[adoption.target.spec]
        local body=rows and rows[adoption.target.id]
        local fallbackKey=adoption.target.id==profile.rotationFallbackID and DEFAULT or nil
        local publication=prepareActivePublication and prepareActivePublication(adoption.target.spec,nil,reference,reference,body,nil,fallbackKey)
        local current,currentReason=ready();if not current then return nil,currentReason end
        local now,ownerReason=context();if not now or not same(now,c) then return nil,ownerReason or 'rotation-owner-changed' end
        local committed,commitReason=store:Commit(adoption.plan,c);if not committed then return nil,commitReason end
        if finishChoicePublication then finishChoicePublication(nil) end
        local draft=pending[referenceKey(reference)]
        if draft then
            -- Adoption creates a saved entity, not the old virtual draft's
            -- first Apply. Retire every alias/key so dirty pending workspaces
            -- retain their text but cannot authorize a write over that entity.
            for index,value in pairs(pending) do if value==draft then
                pending[index]=nil;if byReference[index]==draft.key then byReference[index]=nil end
            end end
            byKey[draft.key]=nil;headers[draft.key]=nil
        end
        adoptionPlans[public]=nil;keyFor(reference)
        if finishActivePublication then finishActivePublication(publication) end
        return true,reference
    end
    function coordinator:SourceView(number,value,imported)
        local record,why=self:Snapshot(number,value);if not record then return nil,why end
        if record.source then return nil,imported and 'not-imported' or 'no-source-baseline' end
        local retained;if imported then retained=record.imported else retained=record.origin end
        if not retained then return nil,imported and 'not-imported' or 'no-source-baseline' end
        local envelope=copy(retained.manifest);envelope.body=record.body
        if imported then return {envelope=envelope,applicability=envelope.applicability,enabled=true,validation=data.ValidateEnvelope(envelope,owner:GetRotationValidationOptions()),sourceId=retained.sourceId,sourceRevision=retained.sourceRevision,stepOrigins=copy(retained.stepOrigins)} end
        local catalog,catalogReason=data.NewCatalog({state={custom={[envelope.id]=envelope},lineage={[envelope.id]=retained.lineage}},validation=owner:GetRotationValidationOptions()})
        local view=catalog and catalog:Get({kind='custom',id=envelope.id})
        if not view or view.lineageError then return nil,catalogReason or 'invalid-origin-state' end;return view
    end
    function coordinator:ComparisonIdentity(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then return {kind='builtin',id=reference.id} end
        local record,reason=self:Snapshot(number,reference);if not record then return nil,reason end
        local identity=copy(record.comparison)
        if record.origin then
            local lineage=record.origin.lineage
            identity=identity or {kind=lineage.sourceKind,id=lineage.sourceId,origins={}}
            if identity.kind~=lineage.sourceKind or identity.id~=lineage.sourceId then return nil,'invalid-comparison-origin' end
            for key,origin in pairs(lineage.stepOrigins) do identity.origins[key]=origin end
        elseif record.imported then return {kind='import',id=record.imported.sourceId,origins=copy(record.imported.stepOrigins)} end
        return identity or {kind='custom',id=reference.address.id,sourceAddress=copy(reference.address)}
    end
    function coordinator:Allocator()
        local used={};if libraryReader then libraryReader:Reserve(used) end
        local rows,inventoryReason=store:AllStored();if not rows then return nil,inventoryReason end
        for _,row in ipairs(rows) do used[row.address.id]=true;for _,component in pairs(row.record) do local ok,why=data.ReserveRotationIdentities(component,used);if not ok then return nil,why.code end end end
        for _,draft in pairs(pending) do used[draft.reference.address.id]=true end
        return function()
            local ok,id=pcall(owner.uuid)
            if not ok or not text(id,128) or not id:match('^[%w][%w._:%-]*$') then return nil end
            if used[id] then return nil end;used[id]=true;return id
        end
    end
    function coordinator:Import(prepared,number,name,replacement,options)
        if options~=nil and not plain(options) then return nil,'invalid-rotation-options' end
        if replacement~=nil and not plain(replacement) then return nil,'invalid-replacement-target' end
        if not validSpec(number) then return nil,'invalid-specialization' end
        if type(name)~='string' or not name:find('%S') or #name>256 then return nil,'invalid-name' end
        local ok,why=ready();if not ok then return nil,why end
        local c,contextReason=context();if not c then return nil,contextReason end
        if not plain(prepared) then return nil,'invalid-import' end
        local body=data.CopyData(prepared.body);if not plain(body) then return nil,'invalid-import' end
        local manifest=prepared.manifest and copy(prepared.manifest)
        if prepared.manifest and not manifest then return nil,'invalid-import' end
        if manifest and manifest.applicability and manifest.applicability.class and manifest.applicability.class~=c.class then return nil,'class-mismatch' end
        local validation
        if manifest then local envelope=copy(manifest);envelope.body=body;validation=data.ValidateEnvelope(envelope,owner:GetRotationValidationOptions())
        else validation=data.ValidateBody(body,owner:GetRotationValidationOptions()) end
        if not validation.valid or not validation.supported or not validation.resolved then return nil,'import-not-ready' end
        local reference,token,legacyValid
        if replacement then
            if replacement.profile and replacement.profile~=profile then return nil,'rotation-changed-externally' end
            reference,why=self:Resolve(number,replacement.reference or replacement.id);if not reference then return nil,why end
            if reference.kind~='custom' then return nil,'read-only-rotation' end
            token=replacement.recordToken
            if not token then
                if type(replacement.valid)~='function' then return nil,'stale-rotation-record' end
                local record;record,token=self:Snapshot(number,reference);if not record then return nil,token end
                legacyValid=replacement.valid
            end
        end
        local allocate,allocationReason=self:Allocator();if not allocate then return nil,allocationReason end
        local id=reference and reference.address.id or allocate();if not id then return nil,'id-collision' end
        local origins={};local tree,treeError=data.IndexRotationSteps(body);if not tree then return nil,treeError.code end
        for _,row in ipairs(tree.rows) do
            local old=row.step.id;local id=allocate();if not id then return nil,'id-collision' end
            row.step.id=id;origins[id]=prepared.stepOrigins and prepared.stepOrigins[old] or old
        end
        body.name=name;local record={body=body}
        if manifest then
            local sourceId=prepared.sourceId or manifest.id;local sourceRevision=prepared.sourceRevision or manifest.revision
            manifest.id=id;manifest.revision=1;manifest.nameKey=name
            record.imported={manifest=manifest,sourceId=sourceId,sourceRevision=sourceRevision,stepOrigins=origins}
        end
        local scope=reference and reference.address.scope or options and options.scope or 'class'
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        reference=reference or {kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=id}}
        if legacyValid then local ok,valid=pcall(legacyValid);if not ok or not valid then return nil,'rotation-changed-externally' end end
        local saved,commitReason,transition=self:Commit(reference,token,record,scope,'import');if not saved then return nil,commitReason end
        return id,nil,saved,transition
    end
    function coordinator:Copy(number,value,name,options)
        if options~=nil and not plain(options) then return nil,'invalid-rotation-options' end
        if type(name)~='string' or not name:find('%S') or #name>256 then return nil,'invalid-name' end
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        local record,reason=self:Snapshot(number,reference);if not record then return nil,reason end
        local allocate,allocationReason=self:Allocator();if not allocate then return nil,allocationReason end
        local body=record.body;local copiedRecord={};local id
        if reference.kind=='builtin' then
            local source=record.source;local state={};local catalog=data.NewCatalog({state=state,newId=allocate})
            assert(catalog:RegisterBuiltin(source.envelope));id,why=catalog:Clone({kind='builtin',id=reference.id},name);if not id then return nil,why end
            local view=catalog:Get({kind='custom',id=id});local manifest=view.envelope;copiedRecord.body=manifest.body;manifest.body=nil
            if manifest.applicability.universal then manifest.applicability.universal=nil;manifest.applicability.class=context().class end
            copiedRecord.origin={manifest=manifest,lineage=view.lineage}
        else
            id=allocate();if not id then return nil,'id-collision' end
            local identity,why=self:ComparisonIdentity(number,reference);if not identity then return nil,why end
            local correspondence={kind=identity.kind=='import' and 'custom' or identity.kind,id=identity.id,origins={},sourceAddress=copy(identity.sourceAddress)}
            local tree,errorText=data.IndexRotationSteps(body,{allowMissingIds=true});if not tree then return nil,errorText.code end
            copiedRecord=copyRecord(record);copiedRecord.body=body
            local lineage=copiedRecord.origin and copiedRecord.origin.lineage;local oldOrigins=lineage and copy(lineage.stepOrigins)
            if lineage then lineage.clonedFrom=reference.address.id;lineage.stepOrigins={} end
            local imported=copiedRecord.imported;local oldImported=imported and copy(imported.stepOrigins);if imported then imported.stepOrigins={} end
            for _,row in ipairs(tree.rows) do
                local old=row.step.id;local new=allocate();if not new then return nil,'id-collision' end
                row.step.id=new;correspondence.origins[new]=identity.origins and identity.origins[old] or old
                if lineage then lineage.stepOrigins[new]=oldOrigins[old] end
                if imported then imported.stepOrigins[new]=oldImported[old] or old end
            end
            body.name=name
            for _,source in ipairs({copiedRecord.origin or false,copiedRecord.imported or false}) do if source then source.manifest.id=id;source.manifest.revision=1;source.manifest.nameKey=name end end
            if not imported then copiedRecord.comparison=correspondence else copiedRecord.comparison=nil end
        end
        local c,contextReason=context();if not c then return nil,contextReason end;local scope=options and options.scope or 'class'
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local target={kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=id}}
        local saved,commitReason=self:Commit(target,nil,copiedRecord,scope);if not saved then return nil,commitReason end
        return id,nil,saved
    end
    function coordinator:GetEditableRotation(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then return nil,'readonly-rotation' end
        local c,reason=context();if not c then return nil,reason end
        local readable,alreadyExposed,previousSeal=reader:Read(reference.address,c,function(record) return exposed[record.body]==true end)
        if not readable then return nil,alreadyExposed end
        if not alreadyExposed then
            -- A portable store may legitimately share payload tables between
            -- records or history. The mutable legacy escape must first acquire
            -- an independent canonical body, without changing any data values.
            local detached,token=store:Get(reference.address,c);if not detached then return nil,token end
            local plan,planReason=store:PlanReplace(reference.address,detached,c,token);if not plan then return nil,planReason end
            local committed,commitReason=store:Commit(plan,c);if not committed then return nil,commitReason end
            if finishChoicePublication then finishChoicePublication(nil) end
            -- This transaction changed identity only. Preserve UI authorities
            -- that still describe the exact complete value being detached.
            local _,freshToken=store:Get(reference.address,c)
            local _,_,freshSeal=reader:Read(reference.address,c,function() return true end)
            for _,issued in pairs(expected) do
                if issued.seal==previousSeal and same(issued.reference,reference) and same(issued.context,c) and same(issued.baseline,detached) then issued.token=freshToken;issued.seal=freshSeal end
            end
        end
        local ok,body=reader:Read(reference.address,c,function(record) exposed[record.body]=true;return record.body end)
        if not ok then return nil,body end;return body
    end
    function coordinator:Headers(number)
        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        local rows,stamp=reader:ListOwned(number,c);if not rows then return nil,stamp end
        local fallback=fallbackReference(number);local result={};local presentationChanged=false;local virtualSignature
        local validation,validationStamp=owner:GetRotationValidationOptions()
        for _,row in ipairs(rows) do
            local reference={kind='custom',address=row.address};local key=keyFor(reference)
            local header=headers[key]
            local valid=header and reader:IsCurrent(header.seal,c)
            local projected,view=reader:Read(row.address,c,function(record)
                if header and valid and header.stamp==validationStamp and not exposed[record.body] then return header.view end
                local body=record.body;local manifest=record.origin and record.origin.manifest or record.imported and record.imported.manifest
                local status=data.ValidateBody(body,validation)
                if manifest then local envelope={};for k,v in pairs(manifest) do envelope[k]=v end;envelope.body=body;status=data.ValidateEnvelope(envelope,validation) end
                local state=not status.valid and 'invalid' or not status.supported and 'unsupported' or not status.resolved and 'unresolved' or 'valid'
                local projection={validationState=state,body={name=type(body.name)=='string' and body.name or nil,description=type(body.description)=='string' and body.description or nil,
                    priority=body.priority,disabled=body.disabled,tags=tagsView(body.tags),metadata=metadataView(body.metadata)},tags=manifest and copy(manifest.tags),sources=manifest and copy(manifest.sources)}
                return projection
            end)
            if not projected then return nil,view end
            if not header or not same(header.view,view) then presentationChanged=true end
            headers[key]={seal=row.seal,view=view,stamp=validationStamp}
            result[#result+1]={key=key,reference=copy(reference),canonicalId=row.address.id,kind='custom',scope=row.address.scope,
                name=view.body.name or L['Unnamed rotation'],description=view.body.description or '',enabled=not view.body.disabled,
                priority=data.GetRotationPriority(view.body.priority),tags=data.GetRotationTags(view) or {},search=data.RotationSearchText(view,view.body.name or '',view.body.description or ''),
                readOnly=false,pending=false,virtual=false,fallback=row.address.id==profile.rotationFallbackID,effectiveFallback=fallback and same(fallback,reference) or false,validationState=view.validationState}
        end
        local virtual={kind='custom',address={scope='class',class=c.class,owner=c.class,spec=number,id=profile.rotationFallbackID}}
        local exists,missing=reader:Read(virtual.address,c,function() return true end)
        if not exists and missing=='unknown-rotation' then
            local reference,key=self:NewDraft(number,'class',true)
            if reference then virtualSignature=key..referenceKey(reference);result[#result+1]={key=key,reference=reference,canonicalId=profile.rotationFallbackID,kind='custom',scope='class',name=profile.rotationFallbackID,description='',enabled=true,priority=0,tags={},search=profile.rotationFallbackID:lower(),readOnly=false,pending=true,virtual=true,fallback=true,effectiveFallback=false,validationState='pending'} end
        elseif not exists then return nil,missing end
        local builtinPresentation={}
        if libraryReader then
            local rows,why=libraryReader:List(number,function(id,view,body)
                local reference={kind='builtin',id=id};local name=L[view.nameKey or id];local description=L[view.descriptionKey or '']
                local eligible,eligibilityReason=libraryReader:Eligible(view,number,false)
                builtinPresentation[id]={name=name,description=description,eligible=eligible,reason=eligibilityReason}
                return {key=keyFor(reference),reference=reference,canonicalId=id,kind='builtin',name=name,description=description,enabled=view.enabled,eligible=eligible,eligibilityReason=eligibilityReason,priority=data.GetRotationPriority(body.priority),
                    tags=data.GetRotationTags(view.envelope) or {},search=data.RotationSearchText(view.envelope,name,description),readOnly=true,pending=false,virtual=false,fallback=false,effectiveFallback=false,validationState=view.validation.valid and 'valid' or 'invalid'}
            end)
            if not rows then return nil,why end;for _,row in ipairs(rows) do result[#result+1]=row end
        end
        local libraryStamp=libraryReader and libraryReader:Generation()
        local ownedCurrent=rosterOwned and reader:IsCurrent(rosterOwned,c)
        if not rosterStamp or not ownedCurrent or rosterLibrary~=libraryStamp or rosterValidation~=validationStamp or rosterVirtual~=virtualSignature or not same(rosterBuiltin,builtinPresentation) or presentationChanged then rosterStamp={} end
        if not ownedCurrent then rosterOwned=stamp end
        rosterLibrary=libraryStamp;rosterValidation=validationStamp;rosterVirtual=virtualSignature
        rosterBuiltin=builtinPresentation
        return result,rosterStamp
    end
    function coordinator:RuntimePass(number)
        local request=evaluationRequest;evaluationRequest=nil
        local version=contextVersion
        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        local validation,referenceStamp=owner:GetRotationValidationOptions();local revision=owner.conditionRegistryVersion;local generation=libraryReader and libraryReader:Generation();local pass={}
        local selected,untracked,listSeal={},{},nil
        local publicationSelected={};local makePublicationGuard=managedStoreReader and ownedPublicationGuard
        local observedPrivate,observedMethod
        local function eligibilityContext()
            local value,private,method=rotationContext(owner,number)
            if libraryContextProof and libraryContextProof(method,eligibilityContext,rotationContext)and private==true then observedPrivate,observedMethod=true,method;return value end
            observedPrivate=false
            local result={}
            for _,key in ipairs({'family','class','spec','actionContext','level','build','combatDataPolicy'}) do result[key]=value and value[key] end
            return result
        end
        local observedContext=eligibilityContext()
        local contextGuard=request and observedPrivate and libraryRuntimeContextGuard
            and libraryRuntimeContextGuard(observedContext,observedMethod,eligibilityContext,rotationContext)
        local function baseCurrent()
            local readyNow,problemText=ready();if not readyNow then return nil,problemText end
            local now=context();if not now or not same(now,c) then return nil,'rotation-owner-changed' end
            if request and version~=contextVersion then return nil,'rotation-context-changed' end
            if contextGuard then
                local unchanged=contextGuard()
                if request and version~=contextVersion then return nil,'rotation-context-changed' end
                if unchanged==false then return nil,'rotation-context-changed' end
                if unchanged==nil then contextGuard=nil end
            end
            if not contextGuard and not same(observedContext,eligibilityContext()) then return nil,'rotation-context-changed' end
            local stamp
            if libraryReader then
                local eligible=libraryGenerationProof and libraryGenerationProof(nil,referenceStamp,generation)
                local method=libraryReader.Generation
                local currentGeneration,_,checked,proof=method(libraryReader)
                if currentGeneration~=generation then return nil,'rotation-library-changed' end
                if eligible and proof and libraryGenerationProof(method,referenceStamp,generation) then stamp=checked end
            end
            -- Only the immediately preceding owned, unchanged library check can
            -- supply this observation; every uncertain path repeats the public read.
            if stamp==nil then stamp=owner:GetRotationValidationStamp() end
            if stamp~=referenceStamp or owner.conditionRegistryVersion~=revision then return nil,'rotation-dependencies-changed' end
            return true
        end
        function pass:IsCurrent()
            local current,problemText=baseCurrent();if not current then return nil,problemText end
            if listSeal then
                if not reader:IsCurrent(listSeal,c) then return nil,'rotation-records-changed' end
            else
                for _,seal in pairs(selected) do if not reader:IsCurrent(seal,c) then return nil,'rotation-records-changed' end end
            end
            for _,watch in pairs(untracked) do
                local readable,unchanged=reader:Read(watch.address,c,function(record)
                    return data.CheckPortable(record.body) and same(record.body,watch.baseline)
                end)
                if not readable or not unchanged then return nil,'rotation-records-changed' end
            end
            return true
        end
        local function observeList()
            if listSeal then return true end
            local rows,seal=reader:ListOwned(number,c);if not rows then return nil,seal end
            listSeal=seal;return true
        end
        -- Batch candidates validate their complete list once before publication.
        -- Rechecking an ever-growing selected set for each row would be O(n^2).
        local function get(value,candidates,batch)
            local readyNow,problemText
            if batch then readyNow,problemText=baseCurrent() else readyNow,problemText=pass:IsCurrent() end
            if not readyNow then return nil,problemText end
            local reference,errorText=coordinator:Resolve(number,value);if not reference then return nil,errorText end
            local index=referenceKey(reference)
            if reference.kind=='builtin' then
                local readable,item=libraryReader:Read(number,reference.id,function(view,body,allowed,eligibilityReason)
                    if not allowed then return {reason=eligibilityReason} end
                    local asset=assets[index];if not asset or asset.generation~=generation then asset={body=copy(body),generation=generation};assets[index]=asset end
                    return asset
                end,candidates)
                if not readable then return nil,item end;if item.reason then return nil,item.reason end
                if not batch then local current,problemText=pass:IsCurrent();if not current then return nil,problemText end end
                return item.body
            end
            if reference.address.id==fallbackID then
                local observed,problemText=observeList();if not observed then return nil,problemText end
                local effective,fallbackReason=coordinator:Resolve(number,DEFAULT)
                if not effective then return nil,fallbackReason end
                if not same(reference,effective) then return nil,'inactive-fallback' end
            end
            local okRead,asset,seal=reader:Read(reference.address,c,function(record,recordSeal)
                local previous=assets[index]
                if previous and previous.seal==recordSeal and previous.stamp==referenceStamp and not exposed[record.body] then return previous end
                local portable=data.CheckPortable(record.body);if not portable then return {unavailable='invalid-rotation-body'} end
                if previous and previous.seal==recordSeal and previous.stamp==referenceStamp and exposed[record.body] and same(record.body,previous.baseline) then return previous end
                local status=data.ValidateBody(record.body,validation)
                local provenance=record.origin or record.imported
                local source=provenance and copy(provenance.manifest)
                if source then source.body=copy(record.body);status=data.ValidateEnvelope(source,validation) end
                local item={seal=recordSeal,stamp=referenceStamp,baseline=copy(record.body),body=copy(record.body),validation=status,applicability=source and source.applicability,untracked=exposed[record.body]==true}
                assets[index]=item;return item
            end)
            if not okRead then return nil,asset end
            selected[index]=seal
            if request and type(makePublicationGuard)=='function' then publicationSelected[index]=makePublicationGuard(reader,seal,c) end
            if asset.untracked then untracked[index]={address=copy(reference.address),baseline=asset.baseline} end
            if not batch then local current,problemText=pass:IsCurrent();if not current then return nil,problemText end end
            local status=asset.validation
            if asset.unavailable or not status.valid or not status.supported or not status.resolved then return nil,reference.address.id==fallbackID and 'invalid-fallback' or asset.unavailable or 'rotation-unavailable' end
            if asset.body.disabled then return nil,'disabled' end
            if asset.applicability then local allowed,eligibilityReason=libraryReader:Eligible({enabled=true,validation=status,applicability=asset.applicability},number,candidates);if not allowed then return nil,eligibilityReason end
            elseif rotationContext(owner,number).combatDataPolicy~='probe' then return nil,'restricted-or-unsupported-client' end
            if owner:HasDisabledRotationDependency(asset.body) then return nil,'disabled-dependency' end
            if not batch then local current,problemText=pass:IsCurrent();if not current then return nil,problemText end end
            return asset.body
        end
        function pass:Get(value,candidates) return get(value,candidates,false) end
        function pass:Candidates(candidates)
            local current,problemText=self:IsCurrent();if not current then return {},problemText end
            if candidates==nil then candidates=true end
            local rows,seal=reader:ListOwned(number,c);if not rows then return {},seal end
            -- Keep the original seal when a caller repeats Candidates on the
            -- same pass: stale authority must never be refreshed implicitly.
            listSeal=listSeal or seal
            local fallback=coordinator:Resolve(number,DEFAULT);local result={}
            for _,row in ipairs(rows) do
                local reference={kind='custom',address=row.address}
                local effective=row.address.id==fallbackID and fallback and same(reference,fallback)
                if row.address.id~=fallbackID or effective then
                    local body=get(reference,candidates,true);if body then result[effective and DEFAULT or keyFor(reference)]=body end
                end
            end
            if libraryReader then
                local views,libraryReason=libraryReader:List(number,function(id) return {kind='builtin',id=id} end);if not views then return {},libraryReason end
                for _,reference in ipairs(views) do local body=get(reference,candidates,true);if body then result[keyFor(reference)]=body end end
            end
            local complete,completionReason=self:IsCurrent();if not complete then return {},completionReason end
            return result
        end
        if request and managedStoreReader then
            local originalCurrent=pass.IsCurrent
            request.pass=pass
            request.publication=function()
                -- Public overrides and list/fallback semantics retain the full route.
                if pass.IsCurrent~=originalCurrent or listSeal or not storeScopeEnvironment
                    or getfenv~=storeGetfenv or storeGetfenv(originalCurrent)~=storeScopeEnvironment then return pass:IsCurrent() end
                local current,problemText=baseCurrent();if not current then return nil,problemText end
                if listSeal then
                    if not reader:IsCurrent(listSeal,c) then return nil,'rotation-records-changed' end
                else
                    for index,seal in pairs(selected) do
                        local guard=publicationSelected[index]
                        local unchanged=guard and guard()
                        -- Base authority has already run. Fall back only this
                        -- selected-store check, without repeating callbacks.
                        if unchanged==nil then unchanged=reader:IsCurrent(seal,c) end
                        if not unchanged then return nil,'rotation-records-changed' end
                    end
                end
                -- Retain the supported mutable canonical-body watcher verbatim.
                for _,watch in pairs(untracked) do
                    local readable,unchanged=reader:Read(watch.address,c,function(record)
                        return data.CheckPortable(record.body) and same(record.body,watch.baseline)
                    end)
                    if not readable or not unchanged then return nil,'rotation-records-changed' end
                end
                return true
            end
        end
        return pass
    end
    ownedRuntimePasses[coordinator]=coordinator.RuntimePass
    completeRebind(binding,coordinator,problem)
    if problem then return nil,problem end
    return true
end
local function bound()
    local value=addon:GetScopedRotationCoordinator();if not value then return nil,'rotation-profile-not-bound' end;return value
end
function addon:ResolveRotationReference(spec,value) local c,why=bound();if not c then return nil,why end;return c:Resolve(spec,value) end
function addon:ListRotationHeaders(spec) local c,why=bound();if not c then return nil,why end;return c:Headers(spec) end
function addon:GetRotationRecordSnapshot(spec,value) local c,why=bound();if not c then return nil,why end;return c:Snapshot(spec,value) end
function addon:NewRotationDraftTarget(spec,scope,fallback) local c,why=bound();if not c then return nil,why end;return c:NewDraft(spec,scope,fallback) end
function addon:CommitRotationDraft(reference,token,record,scope) local c,why=bound();if not c then return nil,why end;return c:Commit(reference,token,record,scope) end
function addon:DeleteRotationRecord(reference,token) local c,why=bound();if not c then return nil,why end;return c:Delete(reference,token) end
function addon:AcquireRotationRuntimePass(spec) local c,why=bound();if not c then return nil,why end;return c:RuntimePass(spec) end


local ownedAcquireRuntimePass=addon.AcquireRotationRuntimePass
local ownedScopedCoordinator=addon.GetScopedRotationCoordinator
-- Only main receives this capability. Public/manual RuntimePass callers retain
-- the fresh provider route, and every main invocation starts a new observation.
function addon:BindRuntimeEvaluationContext(bind)
    if self~=addon or type(bind)~='function' then return nil end
    bind(function(owner,spec)
        contextVersion={}
        if owner~=addon or owner.AcquireRotationRuntimePass~=ownedAcquireRuntimePass
            or owner.GetScopedRotationCoordinator~=ownedScopedCoordinator
            or not current or current.RuntimePass~=ownedRuntimePasses[current] then return owner:AcquireRotationRuntimePass(spec) end
        local previous=evaluationRequest;local request={};evaluationRequest=request
        local ok,pass,reason=protect(ownedAcquireRuntimePass,owner,spec)
        evaluationRequest=previous
        if not ok then raise(pass,0) end
        return pass,reason,request.pass==pass and request.publication or nil
    end,function() contextVersion={} end)
    return true
end

-- Inspection of another profile never switches the active database or grants
-- edit authority. Only detached saved headers for the current owner leave here.
function addon:GetProfileRotationHeaders(profile)
    if not plain(profile) then return nil,'invalid-profile' end
    if profile.rotationStore==nil then return nil,'rotation-profile-recovery-required' end
    if not text(profile.rotationFallbackID,128) then return nil,'missing-fallback-configuration' end
    local c,why=self:GetRotationOwnerContext();if not c then return nil,why end
    local state,fallback=profile.rotationStore,profile.rotationFallbackID
    local reader;local store,reason=data.NewRotationStore({state=state,fallbackID=fallback,validation=self:GetRotationValidationOptions(),bindInternalReader=function(value) reader=value end})
    if not store then return nil,reason end
    local function finish(value,problem) reader:Retire();return value,problem end
    local numbers={};local class=state.classes[c.class];for number in pairs(class or {}) do numbers[number]=true end
    local character=c.character and state.characters[c.character]
    if character and character.class~=c.class then return finish(nil,'foreign-owner') end
    for number in pairs(character and character.specs or {}) do numbers[number]=true end
    local specs={};for number in pairs(numbers) do specs[#specs+1]=number end;table.sort(specs)
    local result={}
    for _,number in ipairs(specs) do
        local rows,problem=reader:ListOwned(number,c);if not rows then return finish(nil,problem) end
        for _,row in ipairs(rows) do
            local ok,view=reader:Read(row.address,c,function(record)
                local body=record.body;local manifest=record.origin and record.origin.manifest or record.imported and record.imported.manifest
                local projection={body={name=type(body.name)=='string' and body.name or nil,description=type(body.description)=='string' and body.description or nil,
                    tags=tagsView(body.tags),metadata=metadataView(body.metadata)},tags=manifest and copy(manifest.tags),sources=manifest and copy(manifest.sources)}
                return {reference={kind='custom',address=copy(row.address)},canonicalId=row.address.id,kind='custom',scope=row.address.scope,spec=number,
                    name=projection.body.name or L['Unnamed rotation'],description=projection.body.description or '',enabled=not body.disabled,
                    priority=data.GetRotationPriority(body.priority),tags=data.GetRotationTags(projection) or {},search=data.RotationSearchText(projection,projection.body.name or '',projection.body.description or ''),
                    fallback=row.address.id==fallback,readOnly=false,pending=false}
            end)
            if not ok then return finish(nil,view) end;result[#result+1]=view
        end
    end
    local now=self:GetRotationOwnerContext()
    if not now or not same(c,now) or profile.rotationStore~=state or profile.rotationFallbackID~=fallback then return finish(nil,'rotation-profile-changed') end
    return finish(result)
end

-- BEGIN PRIVATE VALIDATION CPU HANDOFF
do
 local bind=addon.BindCPUValidationScopeDiagnostic
 if type(bind)=='function' then bind(addon,'scope',addon.BindRotationProfile,function() return same end) end
end
-- END PRIVATE VALIDATION CPU HANDOFF
]]
 local after=before
 after=after:sub(1,67096).."\n"..[[-- Cold-consumed by Core/active_runtime_plan, never a public body getter.
function addon:BindScopedActiveRuntimePlan(receiver)
    if self~=addon or type(receiver)~='function' then return end
    receiver(function(owner,spec,key)
        if owner~=addon or not currentPlanSource then return end
        return currentPlanSource(spec,key)
    end,readActiveRuntime)
end
]]..after:sub(67097)
 after=after:sub(1,63701)..[[    end,function() contextVersion={} end,function(owner,spec)
        if owner~=addon or rawget(owner,'AcquireRotationRuntimePass')~=ownedAcquireRuntimePass
            or storeGetfenv(ownedAcquireRuntimePass)~=storeScopeEnvironment
            or rawget(owner,'GetScopedRotationCoordinator')~=ownedScopedCoordinator
            or not current or rawget(current,'RuntimePass')~=ownedRuntimePasses[current] then return owner:AcquireRotationRuntimePass(spec) end
        return current:RuntimePass(spec,privatePlanPass)
    end,function(owner,spec,key,capturedMethod)
        if owner~=addon or capturedMethod~=ownedGetCleanup or rawget(owner,'GetRotationForCleanup')~=ownedGetCleanup
            or storeGetfenv(ownedGetCleanup)~=storeScopeEnvironment
            or rawget(owner,'GetScopedRotationCoordinator')~=ownedScopedCoordinator
            or not current or rawget(current,'RuntimePass')~=ownedRuntimePasses[current] then return capturedMethod(owner,spec,key) end
        return current:Cleanup(spec,key,privatePlanPass)
    end)
]]..after:sub(63744)
 after=after:sub(1,62639)..[[ownedAcquireRuntimePass=addon.AcquireRotationRuntimePass
local ownedGetCleanup=addon.GetRotationForCleanup
]]..after:sub(62767)
 after=after:sub(1,61314)..[[    -- Main alone receives this cold planner; public RuntimePass stays eager.
    local ownedResolve,ownedPass=coordinator.Resolve,coordinator.RuntimePass
    local ownerPlatform=rawget(owner,'Platform')
    local ownerClass=type(ownerPlatform)=='table' and rawget(ownerPlatform,'GetPlayerOwnerClassObservation')
    currentPlanSource=function(spec,key)
        if current~=coordinator or not alive or not managedStoreReader or not readActiveRuntime or not copyActiveRuntime or not planDataCurrent(owner)
            or not runtimeAuthority or not readLibraryRuntime or not planEligible
            or rawget(owner,'AcquireRotationRuntimePass')~=ownedAcquireRuntimePass or storeGetfenv(ownedAcquireRuntimePass)~=storeScopeEnvironment
            or rawget(owner,'GetScopedRotationCoordinator')~=ownedScopedCoordinator or rawget(coordinator,'Resolve')~=ownedResolve or rawget(coordinator,'RuntimePass')~=ownedPass
            or rawget(owner,'GetRotationOwnerContext')~=ownedOwnerContext or rawget(owner,'GetRotationContext')~=ownedRuntimeContext
            or rawget(owner,'Platform')~=ownerPlatform or not ownerPlatform or rawget(ownerPlatform,'CanReadValue')~=ownedRuntimeReadValue
            or rawget(ownerPlatform,'GetPlayerOwnerClassObservation')~=ownerClass then return end
        local known=byKey[key]
        if not known or known.kind~='custom' or known.address.id==fallbackID then return end
        local existing=assets[referenceKey(known)]
        if existing and (existing.untracked or existing.borrowed) then return end
        local handle,revision=readActiveRuntime(owner,spec,key);if not handle then return end
        local epoch,db,p,g,defs,registry,shared,personal,effects,libraryState=runtimeAuthority(owner)
        if not epoch then return end
        local pass=ownedPass(coordinator,spec,privatePlanPass);local body=pass and pass:Get(key)
        if not body or not pass:IsCurrent() then return end
        local reference=ownedResolve(coordinator,spec,key)
        if not reference or reference.kind~='custom' or reference.address.id==fallbackID then return end
        local contextValue=context();if not contextValue then return end
        local ok,selected,seal=reader:Read(reference.address,contextValue,function(record) return record end)
        if not ok or exposed[selected.body] then return end
        local guard=ownedPublicationGuard and ownedPublicationGuard(reader,seal,contextValue)
        if not guard or guard()~=true then return end
        local execution=copyActiveRuntime(owner,handle,body);if not execution then return end
        local asset=assets[referenceKey(reference)];if not asset or not asset.validation then return end
        local generation,definitionVersion=readLibraryRuntime()
        local exposure=exposureVersion
        local function authority()
            local nextEpoch,nextDB,nextProfile,nextGlobal,nextDefs,nextRegistry,nextShared,nextPersonal,nextEffects,nextLibrary=runtimeAuthority(owner)
            local activeHandle,activeRevision=readActiveRuntime(owner,spec,key)
            local libraryGeneration,libraryVersion=readLibraryRuntime()
            return alive and current==coordinator and rawget(owner,'AcquireRotationRuntimePass')==ownedAcquireRuntimePass
                and storeGetfenv(ownedAcquireRuntimePass)==storeScopeEnvironment and planDataCurrent(owner) and bindIdentity(activeHandle,handle) and activeRevision==revision
                and bindIdentity(nextEpoch,epoch) and bindIdentity(nextDB,db) and bindIdentity(nextProfile,p) and bindIdentity(nextGlobal,g)
                and bindIdentity(nextDefs,defs) and bindIdentity(nextRegistry,registry) and bindIdentity(nextShared,shared)
                and bindIdentity(nextPersonal,personal) and bindIdentity(nextEffects,effects) and bindIdentity(nextLibrary,libraryState)
                and bindIdentity(libraryGeneration,generation) and libraryVersion==definitionVersion
                and exposure==exposureVersion and not exposed[selected.body] and not asset.borrowed
                and rawget(owner,'GetScopedRotationCoordinator')==ownedScopedCoordinator and rawget(coordinator,'Resolve')==ownedResolve and rawget(coordinator,'RuntimePass')==ownedPass
                and rawget(owner,'GetRotationOwnerContext')==ownedOwnerContext and rawget(owner,'GetRotationContext')==ownedRuntimeContext
                and rawget(owner,'Platform')==ownerPlatform and ownerPlatform and rawget(ownerPlatform,'CanReadValue')==ownedRuntimeReadValue
                and rawget(ownerPlatform,'GetPlayerOwnerClassObservation')==ownerClass and guard()==true
        end
        if not authority() then return end
        local view={enabled=true,validation=asset.validation,applicability=asset.applicability}
        local function entry()
            if not authority() then return end
            local actor=context()
            if not actor or actor.class~=contextValue.class or actor.character~=contextValue.character then return end
            local info,private,method=rotationContext(owner,spec)
            if private~=true or not libraryContextProof(method,entry,rotationContext) then return end
            if not authority() then return end
            local allowed,reason
            if view.applicability then allowed,reason=planEligible(view,info,false)
            else allowed=info.combatDataPolicy=='probe';reason='restricted-or-unsupported-client' end
            local _,_,operation=readActiveRuntime(owner,spec,key)
            return {version=contextVersion,operation=operation,allowed=allowed==true,reason=reason}
        end
        local function currentEntry(value)
            if not value or value.version~=contextVersion or not authority() then return false end
            local _,_,operation=readActiveRuntime(owner,spec,key)
            return bindIdentity(operation,value.operation)
        end
        -- Only the literal native cooldown publisher receives these views.
        -- Runtime colors already belong to one CopyData graph, separate from
        -- execution: retain sibling aliases and later eager-fallback mutations.
        local presentation={}
        for index,step in planIpairs(execution.cooldowns or {}) do
            local public=body.cooldowns[index]
            presentation[step]={id=public.id,effect=public.effect,color=public.color,
                magnification=public.magnification,setpoint=public.setpoint,
                xoffs=public.xoffs,yoffs=public.yoffs,angle=public.angle}
        end
        return {body=execution,presentation=presentation,handle=handle,token={},entry=entry,current=currentEntry,authority=authority}
    end
]]..after:sub(61315)
 after=after:sub(1,57823)..[[            if not private then asset.borrowed=true end
]]..after:sub(57824)
 after=after:sub(1,54769)..[[                if not private then item.borrowed=true end
]]..after:sub(54770)
 after=after:sub(1,49301)..[[        local private=request~=nil or privateToken==privatePlanPass
]]..after:sub(49302)
 after=after:sub(1,49194)..[[    function coordinator:RuntimePass(number,privateToken)
]]..after:sub(49240)
 after=after:sub(1,43629)..[[        local ok,body=reader:Read(reference.address,c,function(record) exposureVersion={};exposed[record.body]=true;local asset=assets[referenceKey(reference)];if asset then asset.untracked=true end;return record.body end)
]]..after:sub(43751)
 after=after:sub(1,26767)..[[        if reference and assets[referenceKey(reference)] then local asset=assets[referenceKey(reference)];if privateToken~=privatePlanPass then asset.borrowed=true end;return asset.body end
        local pass=self:RuntimePass(number,privateToken);return pass and pass:Get(value)
]]..after:sub(26954)
 after=after:sub(1,26600)..[[    function coordinator:Cleanup(number,value,privateToken)
]]..after:sub(26648)
 after=after:sub(1,6753)..[[        local pass
        local sourcePass=ownedRuntimePasses[coordinator]
        if reference and rawget(coordinator,'RuntimePass')==sourcePass then
            if not activeCurrent(addon,binding.token) then return nil end
            pass=sourcePass(coordinator,binding.spec,privatePlanPass)
            if not activeCurrent(addon,binding.token) then return nil end
        elseif reference then pass=read(coordinator,'RuntimePass',binding.spec) end
]]..after:sub(6832)
 after=after:sub(1,5485)..[[local ownedScopedCoordinator=addon.GetScopedRotationCoordinator
]]..after:sub(5486)
 after=after:sub(1,5257)..[[local ownedOwnerContext=addon.GetRotationOwnerContext
]]..after:sub(5258)
 after=after:sub(1,2561)..[[local exposureVersion={}
]]..after:sub(2562)
 after=after:sub(1,1765)..[[    bindLibrary(addon,function(reader,proof,contextProof,runtimeGuard,authority,eligible,contextMethod,readValue,generation) runtimeAuthority,planEligible,ownedRuntimeContext,ownedRuntimeReadValue,readLibraryRuntime=authority,eligible,contextMethod,readValue,generation;libraryRuntimeContextGuard=runtimeGuard;libraryReader=reader;if type(proof)=='function' then libraryGenerationProof=proof end;if type(contextProof)=='function'then libraryContextProof=contextProof end end)
]]..after:sub(2043)
 after=after:sub(1,1603)..[[local privatePlanPass={}
]]..after:sub(1604)
 after=after:sub(1,1564)..[[local runtimeAuthority,planEligible,ownedRuntimeContext,ownedRuntimeReadValue,readLibraryRuntime
local currentPlanSource,ownedAcquireRuntimePass
]]..after:sub(1565)
 after=after:sub(1,1406)..[[        readActiveRuntime,copyActiveRuntime=readRuntime,copyRuntime
]]..after:sub(1407)
 after=after:sub(1,1198)..[[    addon:BindActiveRotationPublication(function(prepare,finish,rebind,complete,readRuntime,copyRuntime)
]]..after:sub(1280)
 after=after:sub(1,885)..[[local prepareActivePublication,finishActivePublication,prepareActiveRebind,finishActiveRebind,readActiveRuntime,copyActiveRuntime
]]..after:sub(980)
 after=after:sub(1,535)..[[-- These public helpers receive the execution body/path in the default sequence.
-- Unknown helpers keep the public RuntimePass route before private data escapes.
local planIndex,planCopy,planPortable,planIpairs=data.IndexRotationSteps,data.CopyData,data.CheckPortable,ipairs
local function planDataCurrent(owner)
    return rawget(storeScopeEnvironment,'ipairs')==planIpairs and rawget(owner,'RotationData')==data and rawget(data,'IndexRotationSteps')==planIndex
        and rawget(data,'CopyData')==planCopy and rawget(data,'CheckPortable')==planPortable
        and storeGetfenv(planIndex)==storeScopeEnvironment and storeGetfenv(planCopy)==storeScopeEnvironment
        and storeGetfenv(planPortable)==storeScopeEnvironment
end
]]..after:sub(536)
 rows['Core/rotation_scope.lua']={before=before,after=after}
end
do
 local before=[=[local _,addon=...
local platform=addon.Platform
local direct={['local']='LOCAL',emote='EMOTE',gesture='GESTURE'}
local conditionRequest=0
local deliveryRequest=0
local function same(left,right)
    if type(left)~=type(right) then return false end
    if type(left)~='table' then return left==right end
    if getmetatable(left)~=nil or getmetatable(right)~=nil then return false end
    for key,value in pairs(left) do if not same(value,rawget(right,key)) then return false end end
    for key in pairs(right) do if rawget(left,key)==nil then return false end end
    return true
end
-- A cold event owns a detached, immutable witness of its complete entry.
-- Retain this lease across action resolution, conditions and text formatting.
function addon:PrepareAnnouncementDelivery(config,owner)
    deliveryRequest=deliveryRequest+1
    local request=deliveryRequest
    local data=self.RotationData
    if type(config)~='table' or type(owner)~='function' or not data then return nil end
    local portable,copy=data.CheckPortable,data.CopyData
    if not portable(config) then return nil end
    local witness=copy(config)
    local entry=copy(witness)
    if entry.type=='spell' or entry.type=='pet' then entry.action=entry.spell
    elseif entry.type=='item' then entry.action=entry.item end
    local expected=copy(entry)
    local function current()
        if request~=deliveryRequest then return false end
        local ok,valid=pcall(owner)
        return ok and valid==true and request==deliveryRequest and same(witness,config) and same(expected,entry)
    end
    return entry,current
end
-- One prepared parent lease owns all reached cards. Never prepare a card: that
-- would replace the parent delivery serial. Public callbacks see a detached view.
function addon:DispatchAnnouncementSeries(parent,recipient,current,targetUnit,format,deliver)
    local result={chat=false,sound=false,outputs={}}
    local cards=parent.outputs
    if type(cards)~='table' or getmetatable(cards)~=nil or #cards>64 or not current() then return result end
    local count,seen=0,{}
    for key,card in pairs(cards) do
        if not current() then return result end
        if type(key)~='number' or key%1~=0 or key<1 or key>#cards or not self:IsValidAnnouncementOutput(card,parent.type=='macro') or seen[card.id] then return result end
        if not current() then return result end
        count=count+1;seen[card.id]=true
    end
    if count~=#cards or not current() then return result end
    for _,card in ipairs(cards) do
        if not current() then result.retired=true;break end
        if not card.disabled then
            local view=self.RotationData.CopyData(card)
            view.type=parent.type
            local expected=self.RotationData.CopyData(view)
            local function live()return current() and same(view,expected) end
            local matches=self.AnnouncementConditionMatches
            if not live() then result.retired=true;break end
            local ok,matched=pcall(matches,self,view,recipient,live,targetUnit)
            if not live() then result.retired=true;break end
            if ok and matched and not (view.announce=='gesture' and view.emote_target and not recipient) then
                local formatted,value=pcall(format,view,live)
                if not live() then result.retired=true;break end
                if formatted and value~=nil then
                    local sent,output
                    if deliver then sent,output=pcall(deliver,view,value,live)
                    else
                        local dispatch=self.DispatchAnnouncement
                        if not live() then result.retired=true;break end
                        sent,output=pcall(dispatch,self,view,value,recipient,live)
                    end
                    if sent and type(output)=='table' then
                        result.outputs[#result.outputs+1]=output
                        result.chat=result.chat or output.chat==true
                        result.sound=result.sound or output.sound==true
                    end
                    if not live() then result.retired=true;break end
                end
            end
        end
    end
    return result
end
-- Native unit APIs may accept a resolvable name as well as a unit token.
-- Keep the cast's recorded recipient exact; never infer the selected target.
local function automaticTarget(recipient,owned)
    local function readable(value)
        return platform:CanReadValue(value) and (not canaccessvalue or canaccessvalue(value))
    end
    if not readable(recipient) or type(recipient)~='string' or recipient=='' or #recipient>512 or recipient:find('[%z\1-\31\127]') then return end
    local exists,guid=UnitExists,UnitGUID
    if type(exists)~='function' or type(guid)~='function' then return end
    local function live()
        if not owned() then return false end
        return exists==UnitExists and guid==UnitGUID
    end
    local function observe()
        if not live() then return end
        local ok,present=pcall(exists,recipient)
        if not ok or not readable(present) or present~=true or not live() then return end
        local identified,id=pcall(guid,recipient)
        if not identified or not readable(id) then return end
        if canaccessvalue and not canaccessvalue(id) then return end
        if type(id)~='string' or id=='' or #id>256 or not live() then return end
        return id
    end
    local identity=observe()
    if not identity then return end
    return recipient,function()
        local now=observe()
        if canaccessvalue and not canaccessvalue(now) then return false end
        if canaccessvalue and not canaccessvalue(identity) then return false end
        return live() and now==identity
    end
end
-- Called only after a cast matches an announcement, never by cooldown output.
function addon:AnnouncementConditionMatches(config,recipient,current,targetUnit)
    conditionRequest=conditionRequest+1
    local request=conditionRequest
    local function owned()
        if request~=conditionRequest then return false end
        if current then
            local ok,valid=pcall(current)
            return ok and valid==true and request==conditionRequest
        end
        return true
    end
    if not owned() then return false end
    if config.conditions==nil then return true end
    local resolve
    if config.type~='macro' and targetUnit==nil then
        resolve=function(tag)
            local unit,current=automaticTarget(recipient,owned)
            if unit then return tag=='GROUP' and 'spellrecipient' or unit,current end
        end
    end
    local result
    if resolve then result=self:evaluateAnnouncementConditionResult(config.conditions,recipient,targetUnit,resolve)
    else result=self:evaluateAnnouncementConditionResult(config.conditions,recipient,targetUnit) end
    return owned() and type(result)=='table' and result.status=='match'
end
-- Two bounded cold-output observations, never a history or polling cache.
local emoteSerial={automatic=0,test=0}
local emoteObservation={}
local emoteReasons={['restricted-value']=true,['invalid-emote']=true,['emote-unavailable']=true,
    ['missing-api']=true,['api-error']=true,['cast-recipient-unavailable']=true}
local function beginEmote(kind)
    emoteSerial[kind]=emoteSerial[kind]+1
    return emoteSerial[kind]
end
local function emoteDetailCopy(detail)
    if not platform:CanReadValue(detail) or type(detail)~='table' then return nil end
    local copy={}
    for _,key in ipairs({'backend','call','returns','firstType','firstBoolean'}) do
        local value=rawget(detail,key)
        if platform:CanReadValue(value) then
            if key=='backend' and (value=='C_ChatInfo.PerformEmote' or value=='DoEmote') then copy[key]=value
            elseif key=='call' and (value=='completed' or value=='threw') then copy[key]=value
            elseif key=='returns' and type(value)=='number' and value>=0 and value<=16 and value%1==0 then copy[key]=value
            elseif key=='firstType' and (value=='nil' or value=='boolean' or value=='number' or value=='string' or value=='table' or value=='function' or value=='thread' or value=='userdata' or value=='unavailable') then copy[key]=value
            elseif key=='firstBoolean' and type(value)=='boolean' then copy[key]=value end
        end
    end
    return copy
end
local function finishEmote(kind,serial,target,reason,detail)
    local copied,closed=pcall(emoteDetailCopy,detail)
    local checked,safeReason=pcall(function()
        if reason==nil then return 'native-call-completed' end
        if platform:CanReadValue(reason) and type(reason)=='string' and emoteReasons[reason] then return reason end
        return 'unavailable'
    end)
    if serial~=emoteSerial[kind] then return end
    emoteObservation[kind]={target=target,reason=checked and safeReason or 'unavailable',detail=copied and closed or nil}
end
local function destination(mode)
    if not platform:CanReadValue(mode) or type(mode)~='string' then return nil,'invalid-destination' end
    if mode=='say' or mode=='yell' then return nil,'hardware-event-required' end
    if direct[mode] then return direct[mode] end
    if mode=='none' or mode=='audible' then return nil,'not-requested' end
    if mode~='partyraid' and mode~='party' and mode~='raidwarn' then return nil,'invalid-destination' end
    local group,why=platform:GetAnnouncementGroup();if not group then return nil,why end
    if mode=='party' then
        if group.inGroup then return 'PARTY' end
        return nil,'not-grouped'
    end
    if group.inRaid then
        if mode=='raidwarn' and (group.isLeader==true or group.isAssistant==true) then return 'RAID_WARNING' end
        return 'RAID'
    end
    return group.inGroup and 'PARTY' or 'LOCAL'
end
local function active(current)
    if not current then return true end
    local ok,valid=pcall(current)
    return ok and valid==true
end
local function sound(key,current)
    if not active(current) then return false,'announcement-retired' end
    if not platform:CanReadValue(key) then return false,'restricted-value' end
    if key==nil or key=='' then return false,'not-requested' end
    if type(key)~='string' then return false,'invalid-sound' end
    local play=PlaySoundFile
    if type(play)~='function' then return false,'missing-api' end
    local ok,media=pcall(LibStub,'LibSharedMedia-3.0',true)
    if not active(current) then return false,'announcement-retired' end
    if not ok or type(media)~='table' or type(media.Fetch)~='function' then return false,'missing-media' end
    local fetched,path=pcall(media.Fetch,media,'sound',key,true)
    if not fetched then return false,'media-error' end
    if not platform:CanReadValue(path) then return false,'restricted-value' end
    if not (type(path)=='string' and path~='' or type(path)=='number' and path>0 and path<math.huge and path%1==0) then return false,'sound-unavailable' end
    if not active(current) then return false,'announcement-retired' end
    local played,willPlay=pcall(play,path,'Master')
    if not played then return false,'api-error' end
    if not platform:CanReadValue(willPlay) or willPlay==false then return false,'sound-unavailable' end
    return true
end

-- Output is best-effort and independent: a failed chat or audio API must not
-- interrupt cast bookkeeping or recommendation evaluation. This does not
-- construct templates, match events, or retry messages through another path.
function addon:DispatchAnnouncement(config,text,castRecipient,current)
    local result={chat=false,sound=false}
    if not platform:CanReadValue(config) or type(config)~='table' then return result end
    if not active(current) then result.chatReason='announcement-retired';return result end
    local dest,why=destination(config.announce);result.chatReason=why
    if not active(current) then result.chatReason='announcement-retired';return result end
    if dest=='GESTURE' then
        local serial=beginEmote('automatic')
        local target=config.emote_target and castRecipient or ''
        local detail
        if config.emote_target and (not platform:CanReadValue(target) or type(target)~='string' or target=='') then result.chatReason='cast-recipient-unavailable'
        else local sent,reason,observed=platform:PerformAnnouncementEmote(config.emote,target,current);result.chat=sent==true;result.chatReason=reason;detail=observed end
        finishEmote('automatic',serial,config.emote_target and 'cast-recipient' or 'none',result.chatReason,detail)
        dest=nil
    end
    if dest then
        if not platform:CanReadValue(text) or type(text)~='string' then result.chatReason='invalid-message'
        elseif dest=='LOCAL' then
            local announce=self.announce
            if type(announce)=='function' and active(current) then result.chat=pcall(announce,self,text);if not result.chat then result.chatReason='api-error' end
            else result.chatReason='missing-api' end
        else local sent,reason=platform:SendAnnouncementChat(text,dest,current);result.chat=sent==true;result.chatReason=reason end
    end
    if not active(current) then result.soundReason='announcement-retired';return result end
    result.sound,result.soundReason=sound(config.announce_sound,current)
    return result
end

-- Called only by an explicitly labelled diagnostic button. It sends one
-- independent targetless CHEER, never a pending announcement or cast retry.
function addon:TestAnnouncementEmote()
    local serial=beginEmote('test')
    local sent,reason,detail=platform:PerformAnnouncementEmote('CHEER','')
    finishEmote('test',serial,'none',reason,detail)
    return {chat=sent==true,chatReason=reason}
end
function addon:GetAnnouncementEmoteReport()
    local lines={'Rotation Master emote diagnostics',
        'Native call completion does not prove visible output. Native booleans are reported without interpretation.',
        'Only the latest automatic emote and explicit click test are retained; no recipient names or message text.'}
    for _,entry in ipairs({{'automatic','Automatic:'},{'test','Explicit click test:'}}) do
        local row=emoteObservation[entry[1]]
        lines[#lines+1]=entry[2]..(row and (' target='..row.target..'; result='..row.reason) or ' not observed')
        if row and row.detail then
            local detail=row.detail
            lines[#lines+1]='backend='..(detail.backend or 'unavailable')..'; call='..(detail.call or 'unavailable')
            if detail.returns then
                lines[#lines+1]='native returns='..detail.returns..'; first type='..(detail.firstType or 'unavailable')..
                    (detail.firstBoolean~=nil and ('; first boolean='..tostring(detail.firstBoolean)) or '')
            end
        end
    end
    return table.concat(lines,'\n')
end
]=]
 local after=before
 after=after:sub(1,14827).."\n"..[[-- Definition-owned consumer identity, cold-consumed by the runtime planner.
local runtimeDispatch=addon.DispatchAnnouncement
local runtimeDispatchEnvironment=getfenv(1)
function addon:ConsumeAnnouncementRuntimeSource()
    if self~=addon then return end
    return runtimeDispatch,runtimeDispatchEnvironment
end
]]..after:sub(14828)
 rows['Core/announcements.lua']={before=before,after=after}
end
do
 local before=[[local _,addon=...
local data=addon.RotationData
local function unavailable(diagnostic)
    return {status="unavailable",suppressAttack=true,diagnostic=diagnostic}
end
local function execute(body,evaluate,visit,rows,ordinal,kind,each)
    local result={status="complete",suppressAttack=false,fallbackOrdinal=ordinal+1}
    local function check(step,row)
        local observation=evaluate(step.conditions,{stepId=step.id,stepPath=data.CopyData(row.path)})
        if kind(observation)~="table" then return "unavailable" end
        if observation.status=="match" or observation.status=="no-match" then return observation.status end
        return "unavailable"
    end
    local walk
    walk=function(list)
        for _,step in each(list) do
            local row=rows[step]
            if step.type=="branch" then
                local mode=step.mode or "evaluate"
                local status=mode=="true" and "match" or mode=="false" and "no-match" or check(step,row)
                if status=="unavailable" then result.status="unavailable";result.suppressAttack=true;return false end
                if not walk(status=="match" and step.onTrue or step.onFalse) then return false end
            elseif not step.disabled then
                if step.type=="none" then
                    local status=check(step,row)
                    if status~="no-match" then
                        result.status=status=="unavailable" and "unavailable" or "stopped"
                        result.suppressAttack=status=="unavailable" or step.suppress_attack==true
                        return false
                    end
                elseif visit(step,row.ordinal,data.CopyData(row.path))==false then
                    result.status="selected";return false
                end
            end
        end
        return true
    end
    walk(body.rotation or {})
    return result
end
-- The caller owns observation policy and action availability. This executor
-- owns ordered control flow, and deliberately leaves optional upkeep alone.
function addon:EvaluateRotationSequence(body,evaluate,visit)
    local index,why=data.IndexRotationSteps(body,{allowMissingIds=true})
    if not index then return unavailable(why) end
    if type(evaluate)~="function" or type(visit)~="function" then
        return unavailable({code="invalid-sequence-callback",path="$",severity="error"})
    end
    local rows,ordinal={},0
    for _,row in ipairs(index.rows) do
        if row.section=="rotation" then rows[row.step]=row;ordinal=ordinal+1 end
    end
    local function kind(value) return type(value) end
    local function each(list) return ipairs(list) end
    return execute(body,evaluate,visit,rows,ordinal,kind,each)
end

-- Only main receives this reader. Public sequence calls always index afresh.
local sequenceType,sequenceRawget,sequenceEqual=type,rawget,rawequal
local sequenceIpairs=ipairs
---@type fun(f: number|function): table
local sequenceGetfenv=getfenv
local sequenceEnvironment=sequenceType(sequenceGetfenv)=="function" and sequenceGetfenv(1) or nil
local ownedSequence=addon.EvaluateRotationSequence
local readIndex,retireIndex,indexStatus
local bindIndex=addon.BindRotationExecutionIndexReader
if sequenceType(bindIndex)=="function" then
    ---@cast bindIndex function
    bindIndex(addon,function(read,retire,status) readIndex,retireIndex,indexStatus=read,retire,status end)
    addon.BindRotationExecutionIndexReader=nil
end
-- Source-owned status carries no body, cache, method, or profile references.
local function sequenceStatus(owner)
    local result={reason="ready",raw={}}
    local function check(reason,ok) if result.reason=="ready" and not ok then result.reason=reason end end
    local ownerTable=sequenceType(owner)=="table"
    local db=ownerTable and sequenceRawget(owner,"db") or nil
    local profile=sequenceType(db)=="table" and sequenceRawget(db,"profile") or nil
    local environment=sequenceType(sequenceEnvironment)=="table"
    local capability=sequenceType(sequenceGetfenv)=="function"
    check("owner",sequenceEqual(owner,addon))
    check("method",ownerTable and sequenceEqual(sequenceRawget(owner,"EvaluateRotationSequence"),ownedSequence))
    check("namespace",ownerTable and sequenceEqual(sequenceRawget(owner,"RotationData"),data))
    check("db",sequenceType(db)=="table");check("profile",sequenceType(profile)=="table")
    check("index-reader",sequenceType(readIndex)=="function")
    check("capability",capability);check("env",environment)
    check("public-env",capability and sequenceEqual(sequenceGetfenv(ownedSequence),sequenceEnvironment))
    local keys={"type","ipairs","getfenv"};local pointers={sequenceType,sequenceIpairs,sequenceGetfenv}
    for i=1,3 do
        local key=keys[i];local ok=environment and sequenceEqual(sequenceRawget(sequenceEnvironment,key),pointers[i]) or false
        result.raw[key]=ok;check("raw-"..key,ok)
    end
    local status=indexStatus and indexStatus(data) or {portable={reason="unbound"},index={reason="unbound"}}
    status.sequence=result;return status
end
function addon:BindRotationSequenceReader(bind)
    if self~=addon or sequenceType(bind)~="function" then return end
    local function rawMethod(owner)
        return sequenceType(owner)=="table" and sequenceRawget(owner,"EvaluateRotationSequence") or nil
    end
    local function run(owner,before,method,body,evaluate,visit)
        local db=sequenceType(owner)=="table" and sequenceRawget(owner,"db") or nil
        local profile=sequenceType(db)=="table" and sequenceRawget(db,"profile") or nil
        if not (sequenceEqual(owner,addon) and sequenceEqual(before,ownedSequence) and sequenceEqual(method,ownedSequence)
            and sequenceEqual(sequenceRawget(owner,"RotationData"),data) and sequenceType(profile)=="table"
            and readIndex and sequenceType(sequenceEnvironment)=="table"
            and sequenceEqual(sequenceGetfenv(ownedSequence),sequenceEnvironment)
            and sequenceEqual(sequenceRawget(sequenceEnvironment,"type"),sequenceType)
            and sequenceEqual(sequenceRawget(sequenceEnvironment,"ipairs"),sequenceIpairs)
            and sequenceEqual(sequenceRawget(sequenceEnvironment,"getfenv"),sequenceGetfenv)) then
            if retireIndex then retireIndex() end
            return method(owner,body,evaluate,visit)
        end
        local eligible,index,why=readIndex(body,profile,data,db)
        if not eligible then return method(owner,body,evaluate,visit) end
        if not index then return unavailable(why) end
        if sequenceType(evaluate)~="function" or sequenceType(visit)~="function" then
            return unavailable({code="invalid-sequence-callback",path="$",severity="error"})
        end
        local rows,ordinal={},0
        for _,row in sequenceIpairs(index.rows) do
            if row.section=="rotation" then rows[row.step]=row;ordinal=ordinal+1 end
        end
        local function kind(value) return sequenceEnvironment.type(value) end
        local function each(list) return sequenceEnvironment.ipairs(list) end
        return execute(body,evaluate,visit,rows,ordinal,kind,each)
    end
    bind(rawMethod,run,sequenceStatus)
end
]]
 local after=before
 after=after:sub(1,7135)..[[    bind(rawMethod,run,sequenceStatus,ownedSequence)
]]..after:sub(7175)
 rows['Core/rotation_sequence.lua']={before=before,after=after}
end
do
 local before=[[-- This file was originally from the MaxDps addon (https://github.com/kaminaris/MaxDps)
-- That addon is writtn by Kaminaris, and is released under the MIT license.
-- Accordingly, this file is also subject to the MIT license (https://opensource.org/licenses/MIT)

-- This file has been heavily modified from the original.  It is no longer compatible with the original.

local addon_name, addon = ...
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local CustomGlow = LibStub("LibCustomGlow-1.0")

local procSupport,procProbe
local function methods(value,names)
    for _,name in ipairs(names) do if type(value[name])~='function' then return false end end
    return true
end
local function probeProcGlow(atlas)
    for _,name in ipairs({'UI-HUD-ActionBar-Proc-Start-Flipbook','UI-HUD-ActionBar-Proc-Loop-Flipbook'}) do
        if type(atlas(name))~='table' then return false end
    end
    if not procProbe then procProbe=CreateFrame('Frame',nil,UIParent);procProbe:Hide();procProbe:SetSize(40,40) end
    local texture=procProbe:CreateTexture(nil,'ARTWORK');if type(texture.SetAtlas)~='function' then return false end
    texture:SetAtlas('UI-HUD-ActionBar-Proc-Start-Flipbook');texture:SetAtlas('UI-HUD-ActionBar-Proc-Loop-Flipbook')
    procProbe.ProcLoop=texture
    local group=procProbe:CreateAnimationGroup()
    if not methods(group,{'Stop','Play','IsPlaying','SetLooping','SetToFinalAlpha','SetScript'}) then return false end
    group:SetLooping('REPEAT');group:SetToFinalAlpha(true)
    local alpha=group:CreateAnimation('Alpha')
    if not methods(alpha,{'SetChildKey','SetDuration','SetOrder','SetFromAlpha','SetToAlpha'}) then return false end
    alpha:SetChildKey('ProcLoop');alpha:SetDuration(.001);alpha:SetOrder(0);alpha:SetFromAlpha(1);alpha:SetToAlpha(1)
    local flipbook=group:CreateAnimation('FlipBook')
    if not methods(flipbook,{'SetChildKey','SetDuration','SetOrder','SetFlipBookRows','SetFlipBookColumns','SetFlipBookFrames','SetFlipBookFrameWidth','SetFlipBookFrameHeight'}) then return false end
    flipbook:SetChildKey('ProcLoop');flipbook:SetDuration(1);flipbook:SetOrder(0)
    flipbook:SetFlipBookRows(6);flipbook:SetFlipBookColumns(5);flipbook:SetFlipBookFrames(30);flipbook:SetFlipBookFrameWidth(0);flipbook:SetFlipBookFrameHeight(0)
    group:Stop();return true
end
-- Method names alone do not establish animation/atlas support on Classic.
-- This hidden probe never plays, and stable capabilities need no warm allocation.
function addon:GetProcGlowSupport()
    local atlas=C_Texture and C_Texture.GetAtlasInfo or rawget(_G,'GetAtlasInfo')
    if procSupport and procSupport.atlas==atlas and procSupport.create==CreateFrame
        and procSupport.start==CustomGlow.ProcGlow_Start and procSupport.stop==CustomGlow.ProcGlow_Stop then return procSupport.available end
    procSupport={atlas=atlas,create=CreateFrame,start=CustomGlow.ProcGlow_Start,stop=CustomGlow.ProcGlow_Stop,available=false}
    if type(atlas)=='function' and type(CreateFrame)=='function' and type(procSupport.start)=='function' and type(procSupport.stop)=='function' then
        local ok,value=pcall(probeProcGlow,atlas);procSupport.available=ok and value==true
    end
    return procSupport.available
end

local function spellMetadataID(spell)
    local info=addon.Platform:GetSpellInfo(spell)
    return info and info.spellID
end
local function itemUseSpellID(item)
    local info=addon.Platform:GetItemUseSpell(item)
    return info and info.spellID
end

local Spells = {}
local ButtonItems = {}
local ButtonSpells = {}
local MacroButtons = {}
local Flags = {}
local SpellsGlowing = {}
local FramePool = {}

local HighlightOverlay = {
	type = "dazzle",
	texture = "Interface\\Cooldown\\star4",
	frequency = 0.1,
	sequence = {
		{ r = 1.00, g = 0.00, b = 0.00, a = 1 },
		{ r = 0.75, g = 0.25, b = 0.00, a = 1 },
		{ r = 0.50, g = 0.50, b = 0.00, a = 1 },
		{ r = 0.25, g = 0.75, b = 0.00, a = 1 },
		{ r = 0.00, g = 1.00, b = 0.00, a = 1 },
		{ r = 0.00, g = 0.75, b = 0.25, a = 1 },
		{ r = 0.00, g = 0.50, b = 0.50, a = 1 },
		{ r = 0.00, g = 0.25, b = 0.75, a = 1 },
		{ r = 0.00, g = 0.00, b = 1.00, a = 1 },
		{ r = 0.25, g = 0.00, b = 0.75, a = 1 },
		{ r = 0.50, g = 0.00, b = 0.50, a = 1 },
		{ r = 0.75, g = 0.00, b = 0.25, a = 1 },
	}
}
local Highlight = {}

addon.textured_types = { "texture", "dazzle", "animate", "pulse", "rotate", "custom" }

function addon:ApplyCustomGlow(effect, frame, id, color, xoffs, yoffs)
    local c
	if color ~= nil then
		c = { color.r, color.g, color.b, color.a }
	end
	if effect.type == "pixel" then
		CustomGlow.PixelGlow_Start(frame, c, effect.lines, effect.frequency, effect.length, effect.thickness, xoffs, yoffs, false, id)
	elseif effect.type == "autocast" then
		CustomGlow.AutoCastGlow_Start(frame, c, effect.particles, effect.frequency, effect.scale, xoffs, yoffs, id)
	elseif effect.type == "blizzard" then
		CustomGlow.ButtonGlow_Start(frame, c, effect.frequency)
	elseif effect.type == 'proc' then
        if self:GetProcGlowSupport() then
            local duration=effect.duration
            if type(duration)~='number' or duration~=duration or duration<.1 or duration>5 then duration=1 end
            local ok=pcall(CustomGlow.ProcGlow_Start,frame,{key=tostring(id or ''),color=c,duration=duration,startAnim=effect.startAnim==true,xOffset=xoffs or 0,yOffset=yoffs or 0})
            if ok then return end
            procSupport.available=false
        end
        -- Another frame may have retired shared support while this key was lit.
        if type(CustomGlow.ProcGlow_Stop)=='function' then pcall(CustomGlow.ProcGlow_Stop,frame,tostring(id or '')) end
        CustomGlow.PixelGlow_Start(frame,c,nil,nil,nil,nil,xoffs,yoffs,false,id)
	end
end

local function UpdateOverlayRaw(frame, effect, color, mags, setp, xoffs, yoffs, angle)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", frame:GetParent(), setp, xoffs, yoffs)
	frame:SetWidth(frame:GetParent():GetWidth() * (mags or 1.0))
	frame:SetHeight(frame:GetParent():GetHeight() * (mags or 1.0))
	frame.texture:SetVertexColor(color.r, color.g, color.b, color.a)
	if effect then
		frame.texture:SetTexture(effect)
	end
	if angle then
		frame.texture:SetRotation(angle)
	end
end

local function StopOverlay(frame)
	if frame.sequenceTimer then
		addon:CancelTimer(frame.sequenceTimer)
		frame.sequenceTimer = nil
	end
	frame.sequenceIdx = nil
end

function addon:HideGlow(frame, id, keepProc)
	CustomGlow.PixelGlow_Stop(frame, id)
	CustomGlow.AutoCastGlow_Stop(frame, id)
	CustomGlow.ButtonGlow_Stop(frame)
    if not keepProc and type(CustomGlow.ProcGlow_Stop)=='function' then CustomGlow.ProcGlow_Stop(frame,tostring(id or '')) end
	if id ~= nil and frame.rmOverlays and frame.rmOverlays[id] then
		StopOverlay(frame.rmOverlays[id])
		frame.rmOverlays[id]:Hide()
	end
end

local function UpdateOverlay(frame, effect, color, mags, setp, xoffs, yoffs, angle)
	local type =  effect.type
    if type == "texture" then
        UpdateOverlayRaw(frame, effect.texture, color, mags, setp, xoffs, yoffs, angle)
        return true
	elseif type == "rotate" and effect.steps and effect.steps > 0 then
		if frame.sequenceIdx then
			frame.sequenceIdx = frame.sequenceIdx >= effect.steps and 1 or (frame.sequenceIdx + 1)
		else
			frame.sequenceIdx = 1
		end
        if effect.reverse then
            UpdateOverlayRaw(frame, effect.texture, color, mags, setp, xoffs, yoffs, ((2 * math.pi) / effect.steps * (effect.steps - (frame.sequenceIdx - 1))))
		else
			UpdateOverlayRaw(frame, effect.texture, color, mags, setp, xoffs, yoffs, ((2 * math.pi) / effect.steps * (frame.sequenceIdx - 1)))
        end
		if not frame.sequenceTimer then
			frame.sequenceTimer = addon:ScheduleRepeatingTimer(UpdateOverlay, effect.frequency or 0.25,
					frame, effect, color, mags, setp, xoffs, yoffs, angle)
		end
		return true
	elseif effect.sequence and #effect.sequence > 0 then
        local sequence = effect.sequence
        if frame.sequenceIdx then
            frame.sequenceIdx = frame.sequenceIdx >= #sequence and 1 or (frame.sequenceIdx + 1)
        else
            frame.sequenceIdx = 1
        end
        if type == "dazzle" and effect.texture then
			UpdateOverlayRaw(frame, effect.texture, sequence[frame.sequenceIdx], mags, setp, xoffs, yoffs, angle)
		elseif type == "animate" then
			UpdateOverlayRaw(frame, sequence[frame.sequenceIdx], color, mags, setp, xoffs, yoffs, angle)
		elseif type == "pulse" and effect.texture then
			UpdateOverlayRaw(frame, effect.texture, color, sequence[frame.sequenceIdx], setp, xoffs, yoffs, angle)
		elseif type == "custom" and sequence[frame.sequenceIdx].texture and sequence[frame.sequenceIdx].color and sequence[frame.sequenceIdx].magnification then
			UpdateOverlayRaw(frame, sequence[frame.sequenceIdx].texture, sequence[frame.sequenceIdx].color, sequence[frame.sequenceIdx].magnification, setp, xoffs, yoffs, math.rad(sequence[frame.sequenceIdx].angle or 0))
		else
            StopOverlay(frame)
			return false
		end
		if not frame.sequenceTimer then
			frame.sequenceTimer = addon:ScheduleRepeatingTimer(UpdateOverlay, effect.frequency or 0.25,
				frame, effect, color, mags, setp, xoffs, yoffs, angle)
		end
		return true
	end
    return false
end

--- Creates frame overlay over a specific frame, it doesn't need to be a button.
-- @param parent - frame that is suppose to be attached to
-- @param id - string id of overlay because frame can have multiple overlays
local function CreateOverlay(parent)
	local frame = tremove(FramePool)
	if not frame then
		frame = CreateFrame('Frame', addon_name .. '_Overlay_' .. addon.uuid(), parent)
	else
		frame:SetParent(parent)
	end

	frame:SetFrameStrata(parent.GetFrameStrata and parent:GetFrameStrata() or 'HIGH')
    if frame.SetFrameLevel and parent.GetFrameLevel then frame:SetFrameLevel(parent:GetFrameLevel()+1) end

	local t = frame.texture
	if not t then
		t = frame:CreateTexture('GlowOverlay', 'OVERLAY')
		t:SetBlendMode('ADD')
		frame.texture = t
	end

	t:SetAllPoints(frame)
	return frame
end

local function DestroyOverlay(frame, id)
	StopOverlay(frame)
	if frame:GetParent().rmOverlays ~= nil and frame:GetParent().rmOverlays[id] then
		frame:GetParent().rmOverlays[id] = nil
	end
	frame:ClearAllPoints()
	frame:Hide()
	frame:SetParent(UIParent)
	frame.width = nil
	frame.height = nil

	tinsert(FramePool, frame)
end

local function DestroyAllOverlay(parent)
	if parent.rmOverlays ~= nil then
		for id,frame in pairs(parent.rmOverlays) do
			DestroyOverlay(frame, id)
		end
		parent.rmOverlays = nil
	end
end

function addon:DestroyAllGlows()
	-- Clear custom glows on fetch.
	for spellid,v in pairs(Flags) do
		if v then
			for _, button in pairs(Spells[spellid]) do
				self:HideGlow(button, spellid)
				DestroyAllOverlay(button)
			end
		end
	end

	for spellid,v in pairs(SpellsGlowing) do
		if v then
			for _, button in pairs(Spells[spellid]) do
				self:HideGlow(button, "next")
				DestroyAllOverlay(button)
			end
		end
	end
end

function addon:UpdateButtonGlow()
	local LAB
	local LBG
	local origShow
	local noFunction = function() end

	if IsAddOnLoaded('ElvUI') then
		LAB = LibStub:GetLibrary('LibActionButton-1.0-ElvUI')
		LBG = LibStub:GetLibrary('LibCustomGlow-1.0')
		origShow = LBG.ShowOverlayGlow
	elseif IsAddOnLoaded('Bartender4') then
		LAB = LibStub:GetLibrary('LibActionButton-1.0')
	end

	if self.db.global.disableButtonGlow then
		if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
			ActionBarActionEventsFrame:UnregisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
			if LAB then
				LAB.eventFrame:UnregisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
            end
		end

		if LBG then
			LBG.ShowOverlayGlow = noFunction
		end
	else
		if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
			ActionBarActionEventsFrame:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
			if LAB then
				LAB.eventFrame:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
            end
		end

		if LBG then
			LBG.ShowOverlayGlow = origShow
		end
	end
end

function addon:Glow(button, id, effect, color, mags, setp, xoffs, yoffs, angle)
	if not effect then
		return
	end

    color=self:ResolveHighlightColor(color)

	local type = effect.type
	addon:HideGlow(button, id, type=='proc')
	if addon.Functions.collections.index(addon.textured_types, type) then
		if not button.rmOverlays then
			button.rmOverlays = {}
		end
		if not button.rmOverlays[id] then
			button.rmOverlays[id] = CreateOverlay(button, id)
		end

        if UpdateOverlay(button.rmOverlays[id], effect, color, mags, setp, xoffs, yoffs, angle) then
            button.rmOverlays[id]:Show()
        end
	else
		addon:ApplyCustomGlow(effect, button, id, color, xoffs, yoffs)
	end
end

local function AddButton(spellId, button, itemId)
    if not addon.Platform:CanReadValue(spellId) then return end
	if type(spellId)=="number" and spellId>0 and spellId<math.huge and spellId%1==0 then
		if Spells[spellId] == nil then
			Spells[spellId] = {}
		end
        if ButtonSpells[button]~=spellId then tinsert(Spells[spellId], button) end
        ButtonSpells[button]=spellId
        ButtonItems[button]=itemId
	end
end

local function ValidActionSlot(slot)
    return addon.Platform:CanReadValue(slot) and type(slot) == 'number' and slot > 0 and slot < math.huge and slot%1 == 0
end

local function GetActionSlot(button)
    local slot = button:GetAttribute('action')
    if ValidActionSlot(slot) then return slot end

    -- Anniversary uses the same button methods as Retail. Older clients and
    -- third-party bars may still expose the global helpers or only action.
    if button.GetPagedID then
        slot = button:GetPagedID()
    elseif ActionButton_GetPagedID then
        slot = ActionButton_GetPagedID(button)
    end
    if ValidActionSlot(slot) then return slot end

    if button.CalculateAction then
        slot = button:CalculateAction()
    elseif ActionButton_CalculateAction then
        slot = ActionButton_CalculateAction(button)
    end
    if ValidActionSlot(slot) then return slot end
    if ValidActionSlot(button.action) then return button.action end
end

local function ReadStandardAction(button)
    local kind=button:GetAttribute('type')
    if not addon.Platform:CanReadValue(kind) then return end
    if kind~='action' and kind~='macro' and kind~='item' and kind~='spell' then return end
    local action=button:GetAttribute(kind)
    if kind=='action' then
        local slot=GetActionSlot(button)
        if not slot or not HasAction(slot) then return end
        kind,action=GetActionInfo(slot)
    end
    if not addon.Platform:CanReadValue(kind) then return end
    if not addon.Platform:CanReadValue(action) then return kind end
    return kind,action
end

local function ResolveStandardAction(kind,action)
    if kind=='macro' then
        local observed=addon.Platform:GetMacroAction(action)
        if observed then return observed.spellID,observed.itemID end
    elseif kind=='item' then
        local item=addon.Platform:GetItemID(action)
        if item then return itemUseSpellID(item),item end
    elseif kind=='spell' then
        return spellMetadataID(action)
    end
end

local function AddStandardButton(button)
    if not button or ButtonSpells[button] then return end
    local ok,kind,action=pcall(ReadStandardAction,button)
    if not ok then return end
    -- Retain macros whose current observation is unavailable so a later pass
    -- can recover without waiting for a bar-edit event.
    if kind=='macro' then MacroButtons[button]=true end
    local spell,item=ResolveStandardAction(kind,action)
    AddButton(spell,button,item)
end

-- Macro conditionals and cast sequences can change their exposed action
-- without moving a slot or editing the macro. Observe known macro buttons on
-- the existing recommendation cadence; never parse or execute macro bodies.
function addon:RefreshMacroButtons()
    if self.Platform:GetClientInfo().combatDataPolicy~='probe' then
        if next(Spells) then self:Fetch() end
        return
    end
    local observations,changes,affected={},{},{}
    for button in pairs(MacroButtons) do
        local ok,kind,action=pcall(ReadStandardAction,button)
        local spell,item
        if ok then
            local cacheable=kind=='macro' and (type(action)=='string' or
                type(action)=='number' and action>0 and action<math.huge and action%1==0)
            if cacheable then
                local observed=observations[action]
                if observed==nil then
                    observed=self.Platform:GetMacroAction(action) or false
                    observations[action]=observed
                end
                if observed then spell,item=observed.spellID,observed.itemID end
            else
                spell,item=ResolveStandardAction(kind,action)
            end
        end
        local previous=ButtonSpells[button]
        if previous~=spell or ButtonItems[button]~=item then
            changes[#changes+1]={button=button,spell=spell,item=item,previous=previous}
            if previous then affected[previous]=true end
            if spell then affected[spell]=true end
        end
    end
    -- Invalidate the affected identities before reindexing. Other buttons for
    -- those spells need their recommendation/cooldown glow reapplied as well.
    for spell in pairs(affected) do
        for _,button in ipairs(Spells[spell] or {}) do
            self:HideGlow(button,'next')
            self:HideGlow(button,spell)
        end
        SpellsGlowing[spell]=nil
        Flags[spell]=nil
    end
    for _,change in ipairs(changes) do
        local buttons=change.previous and Spells[change.previous]
        if buttons then
            for index=#buttons,1,-1 do
                if buttons[index]==change.button then table.remove(buttons,index) end
            end
            if #buttons==0 then Spells[change.previous]=nil end
        end
        ButtonSpells[change.button],ButtonItems[change.button]=nil,nil
        AddButton(change.spell,change.button,change.item)
    end
end

function FetchNeuron()
	for x = 1, 12 do
		for i = 1, 12 do
			local button = _G['NeuronActionBar' .. x .. '_' .. 'ActionButton' .. i];
			if button then
				AddStandardButton(button);
			end
		end
	end
end

local function FetchDiabolic()
	local diabolicBars = {'EngineBar1', 'EngineBar2', 'EngineBar3', 'EngineBar4', 'EngineBar5'};
	for _, bar in pairs(diabolicBars) do
		for i = 1, 12 do
			local button = _G[bar .. 'Button' .. i];
			if button then
				AddStandardButton(button);
			end
		end
	end
end

local function FetchBartender4()
    -- Non-pet buttons are done via. LibActionButton
	for i = 1, 10 do
		local button = _G['BT4PetButton' .. i];
		if button then
		    local spell = select(7, GetPetActionInfo(button.id))
			AddButton(spell, button);
		end
		button = _G['BT4StanceButton' .. i];
		if button then
			local spell = select(4, GetShapeshiftFormInfo(button:GetID()))
			AddButton(spell, button);
		end
	end
end

local function FetchDominos()
	-- Dominos is using half of the blizzard frames so we just fetch the missing one

	for i = 1, 60 do
		local button = _G['DominosActionButton' .. i]
		if button then
			AddStandardButton(button)
		end
	end
end

local function FetchFarmingBar()
	local i = 1
	while true do
		local button = _G['FarmingBar_Button' .. i]
		if not button then
			break
		end
		local hyperlink = button.obj:GetHyperlink()
		if hyperlink then
			local itemid = tonumber(hyperlink:match("item:(%d+)"))
			if itemid then
				local spellid = itemUseSpellID(itemid)
				if spellid then
					AddButton(spellid, button, itemid)
				end
			end
		end
		i = i + 1
	end
end

local function FetchAzeriteUI()
	for i = 1, 24 do
		local button = _G['AzeriteUIActionButton' .. i];
		if button then
			AddStandardButton(button);
		end
	end
end

local function FetchSamyTotemTimers()
	for i = 1, 6 do
		local button = _G['SamyTotemTimers' .. i .. "CastTotemButton"];
		if button then
			AddStandardButton(button);
		end
	end
end

local function FetchTotemTimers()
    for i=1,10 do
		local button = _G['XiTimers_Timer' .. i];
		if not button then
            break
        end
		local spellid = spellMetadataID(button:GetAttribute("*spell1"))
    	if not spellid then
			spellid = spellMetadataID(button:GetAttribute("spell1"))
		end
		if spellid then
			AddButton(spellid, button)
        end

    	for j=1,10 do
			button = _G['TT_ActionButton' .. i .. j];
			if not button then
				break
            end
			spellid = spellMetadataID(button:GetAttribute("*spell1"))
			if spellid then
				AddButton(spellid, button)
            end
		end
    end
end

local function FetchLUI()
	local luiBars = {
		'LUIBarBottom1', 'LUIBarBottom2', 'LUIBarBottom3', 'LUIBarBottom4', 'LUIBarBottom5', 'LUIBarBottom6',
		'LUIBarRight1', 'LUIBarRight2', 'LUIBarLeft1', 'LUIBarLeft2'
	}

	for _, bar in pairs(luiBars) do
		for i = 1, 12 do
			local button = _G[bar .. 'Button' .. i]
			if button then
				AddStandardButton(button)
			end
		end
	end
end

local function FetchSyncUI()
	local syncbars = {}

	syncbars[1] = SyncUI_ActionBar
	syncbars[2] = SyncUI_MultiBar
	syncbars[3] = SyncUI_SideBar.Bar1
	syncbars[4] = SyncUI_SideBar.Bar2
	syncbars[5] = SyncUI_SideBar.Bar3
	syncbars[6] = SyncUI_PetBar

	for _, bar in pairs(syncbars) do
		for i = 1, 12 do
			local button = bar['Button' .. i]
			if button then
				AddStandardButton(button)
			end
		end
	end
end

local function FetchLibActionButton()
	local LAB = {
		original = LibStub:GetLibrary('LibActionButton-1.0', true),
		elvui = LibStub:GetLibrary('LibActionButton-1.0-ElvUI', true),
	}

	for _, lib in pairs(LAB) do
		if lib and lib.GetAllButtons then
			for button in pairs(lib:GetAllButtons()) do
                AddStandardButton(button)
			end
		end
	end
end

local function FetchBlizzard()
	local BlizzardBars = {'Action', 'MultiBarBottomLeft', 'MultiBarBottomRight', 'MultiBarRight', 'MultiBarLeft'}
	for _, barName in pairs(BlizzardBars) do
		for i = 1, 12 do
			local button = _G[barName .. 'Button' .. i]
			AddStandardButton(button)
		end
    end

	for i = 1, 10 do
		local button = _G['PetActionButton' .. i]
		AddStandardButton(button)
	end
end

local function FetchG15Buttons()
	local i = 2; -- it starts from 2
	while true do
		local button = _G['objG15_btn_' .. i]
		if not button then
			break
		end
		i = i + 1

		AddStandardButton(button)
	end
end

local function FetchButtonForge()
	local i = 1
	while true do
		local button = _G['ButtonForge' .. i]
		if not button then
			break
		end
		i = i + 1

		AddStandardButton(button)
	end
end

function addon:Fetch()
	self = addon
	if self.currentRotation then
		self:DisableRotationTimer()
	end
	self.Spell = nil

	self:GlowClear()
	self:DestroyAllGlows()

	Spells = {}
    ButtonItems = {}
    ButtonSpells = {}
    MacroButtons = {}
	Flags = {}
	SpellsGlowing = {}

    -- The reference/editor modes on restricted clients do not inspect combat
    -- actions. Clear outgoing mappings above before leaving the scanner.
    if addon.Platform:GetClientInfo().combatDataPolicy~="probe" then return end
	addon:debug(L["Button Fetch triggered."])

	FetchLibActionButton()
	FetchBlizzard()

	-- It does not alter original button frames so it needs to be fetched too
	if IsAddOnLoaded('Bartender4') then
		FetchBartender4()
	end

	if IsAddOnLoaded('ButtonForge') then
		FetchButtonForge()
	end

	if IsAddOnLoaded('G15Buttons') then
		FetchG15Buttons()
	end

	if IsAddOnLoaded('SyncUI') then
		FetchSyncUI()
	end

	if IsAddOnLoaded('LUI') then
		FetchLUI()
	end

	if IsAddOnLoaded('Dominos') then
		FetchDominos()
	end

	if IsAddOnLoaded('DiabolicUI') then
		FetchDiabolic();
	end

	if IsAddOnLoaded('AzeriteUI') then
		FetchAzeriteUI();
    end

	if IsAddOnLoaded('Neuron') then
		FetchNeuron();
	end

	if IsAddOnLoaded('FarmingBar') then
		FetchFarmingBar();
	end

	if IsAddOnLoaded('TotemTimers') then
		FetchTotemTimers();
	end

	if IsAddOnLoaded('SamyTotemTimers') then
		FetchSamyTotemTimers();
	end

	if self.currentRotation then
		self:EnableRotationTimer()
		self:EvaluateNextAction()
	end
end

function addon:FindSpell(spellIds,itemIds)
    for index,id in ipairs(spellIds or {}) do
        if Spells[id] then
            if not itemIds then return id,index end
            local wanted=itemIds[index]
            if self.Platform:CanReadValue(wanted) and type(wanted)=="number" then
                for _,button in ipairs(Spells[id]) do
                    if ButtonItems[button]==wanted then return id,index end
                end
            end
        end
    end
end

function addon:IsGlowing(spellId,itemId)
    local current=SpellsGlowing[spellId]
    return current~=nil and current.itemId==itemId
end

local function GlowIndependent(spellId, id, effect, color, mags, setpoint, xoffs, yoffs, angle, itemId)
	if Spells[spellId] ~= nil and addon.db.global.effects[effect] then
		for _, button in pairs(Spells[spellId]) do
			if not itemId or ButtonItems[button]==itemId then
                addon:Glow(button, id, addon.db.global.effects[effect], color, mags, setpoint, xoffs, yoffs, angle)
            end
			addon:verbose(spellId .. " is now glowing")
		end
	end
end

local function ClearGlowIndependent(spellId, id)
	if Spells[spellId] ~= nil then
		for _, button in pairs(Spells[spellId]) do
			addon:HideGlow(button, id)
			addon:verbose(spellId .. " is no longer glowing")
		end
	end
end

function addon:GlowCooldown(spellId, condition, cooldown, itemId)
    if spellId == nil then
		return
    end

	local previous=Flags[spellId]
    if condition and cooldown and (not previous or previous.id~=cooldown.id or previous.itemId~=itemId) then
        if previous then ClearGlowIndependent(spellId,spellId) end
		Flags[spellId] = {id=cooldown.id,itemId=itemId}
		GlowIndependent(spellId, spellId, cooldown.effect or self.db.profile.effect, cooldown.color,
				cooldown.magnification or self.db.profile.magnification,
				cooldown.setpoint or self.db.profile.setpoint,
				cooldown.xoffs or self.db.profile.xoffs,
				cooldown.yoffs or self.db.profile.yoffs,
				cooldown.angle or self.db.profile.angle, itemId)
	elseif not condition and Flags[spellId] then
		Flags[spellId] = nil
		ClearGlowIndependent(spellId, spellId)
	end

	if WeakAuras then WeakAuras.ScanEvents('ROTATIONMASTER_COOLDOWN_UPDATE', self.Flags); end
end

function addon:GlowSpell(spellId,itemId)
	if spellId == nil then
		return
	end

	if Spells[spellId] ~= nil and addon.db.global.effects[self.db.profile.effect] then
		for _, button in pairs(Spells[spellId]) do
            if not itemId or ButtonItems[button]==itemId then
			addon:Glow(button, 'next', addon.db.global.effects[self.db.profile.effect], self.db.profile.color,
				 self.db.profile.magnification, self.db.profile.setpoint,
				 self.db.profile.xoffs, self.db.profile.yoffs, self.db.profile.angle)
            end
		end

		SpellsGlowing[spellId] = {itemId=itemId}
		addon:verbose(spellId .. " is now glowing")
	end
end

function addon:GlowClear()
	for spellId, v in pairs(SpellsGlowing) do
		if v then
			for _, button in pairs(Spells[spellId]) do
				addon:HideGlow(button, 'next')
			end
			SpellsGlowing[spellId] = nil
			addon:verbose(spellId .. " is no longer glowing")
		end
	end
end

function addon:GlowNextSpell(spellId,itemId)
	self:GlowClear()
	self:GlowSpell(spellId,itemId)
end

function addon:EndHighlightSlot()
	for _, button in pairs(Highlight) do
        self:HideGlow(button, "highlight")
    end
    Highlight = {}
end

function addon:HighlightSlots(slots)
	addon:EndHighlightSlot()
	for _, buttons in pairs(Spells) do
		for _, button in pairs(buttons) do
			local type = button:GetAttribute('type')
			if type == 'action' then
				local bslot = GetActionSlot(button)

				if bslot and addon.Functions.collections.index(slots, bslot) ~= nil then
                    self:Glow(button, "highlight", HighlightOverlay, {}, 1.0, "CENTER", 0, 0)
                	table.insert(Highlight, button)
				end
			end
		end
	end
end


-- BEGIN CPU ACTIVITY HANDOFF
-- Only the private RM button maps and their current logical slots are inspected.
-- Shared glow fields establish association, never exclusive caller ownership.
do
    local raw,nextKey,kind,equal,protect,text=rawget,next,type,rawequal,pcall,tostring
    local ownedGlow,ownedFetch=addon.Glow,addon.Fetch
    local starts={pixel=CustomGlow.PixelGlow_Start,autocast=CustomGlow.AutoCastGlow_Start,blizzard=CustomGlow.ButtonGlow_Start}
    local bind=raw(addon,'BindCPUActivityDiagnostic')
    if kind(bind)=='function' then bind(addon,'visual',function(api)
        if not equal(raw(addon,'Glow'),ownedGlow) or not equal(raw(addon,'Fetch'),ownedFetch) then return end
        for name,method in nextKey,starts do
            local key=name=='pixel' and 'PixelGlow_Start' or name=='autocast' and 'AutoCastGlow_Start' or 'ButtonGlow_Start'
            if not equal(raw(CustomGlow,key),method) then return end
        end
        local result={buttons=0,slots=0,logical=0,overlays=0,sequence=0,pixel=0,autocast=0,blizzard=0,proc=0,capped=false,callbacks={overlay=UpdateOverlay},ambiguous={}}
        if kind(api)~='table' or kind(raw(api,'GetParent'))~='function' or kind(raw(api,'IsVisible'))~='function' or kind(raw(api,'GetScript'))~='function' then result.unsupported=true;return result end
        local highlighted,seen={},{};local n=0
        for _,button in nextKey,Highlight do n=n+1;if n>128 then result.capped=true;break end;highlighted[button]=true end
        local function inspect(frame,button,name)
            result.slots=result.slots+1;if result.slots>512 then result.slots=512;result.capped=true;return end
            if kind(frame)~='table' or seen[frame] then return end
            local ok,parent=protect(api.GetParent,frame);if not ok or not equal(parent,button) then return end
            seen[frame]=true
            if name=='overlays' and raw(frame,'sequenceTimer')~=nil then result.sequence=result.sequence+1 end
            local visible,shown=protect(api.IsVisible,frame)
            if not visible then result.unsupported=true;return end
            if shown~=true then return end
            result[name]=result[name]+1
            if name=='overlays' or name=='proc' then return end
            local success,fn=protect(api.GetScript,frame,'OnUpdate')
            if not success or kind(fn)~='function' then return end
            if result.callbacks[name] and not equal(result.callbacks[name],fn) then result.callbacks[name]=nil;result.ambiguous[name]=true
            elseif not result.ambiguous[name] then result.callbacks[name]=fn end
        end
        for button,spell in nextKey,ButtonSpells do
            result.buttons=result.buttons+1;if result.buttons>128 then result.buttons=128;result.capped=true;break end
            if result.capped and result.slots>=512 then break end
            if kind(button)=='table' then
                local ids={}
                local glowing,flag=SpellsGlowing[spell],Flags[spell]
                if glowing and (glowing.itemId==nil or equal(glowing.itemId,ButtonItems[button])) then ids[#ids+1]='next' end
                if flag and (flag.itemId==nil or equal(flag.itemId,ButtonItems[button])) then ids[#ids+1]=spell end
                if highlighted[button] then ids[#ids+1]='highlight' end
                for _,id in nextKey,ids do
                    result.logical=result.logical+1
                    local overlays=raw(button,'rmOverlays');inspect(kind(overlays)=='table' and raw(overlays,id),button,'overlays')
                    local key=text(id)
                    inspect(raw(button,'_PixelGlow'..key),button,'pixel')
                    inspect(raw(button,'_AutoCastGlow'..key),button,'autocast')
                    inspect(raw(button,'_ProcGlow'..key),button,'proc')
                    if result.slots>=512 then result.capped=true;break end
                end
                if #ids>0 then inspect(raw(button,'_ButtonGlow'),button,'blizzard') end
            end
        end
        return result
    end) end
end
-- END CPU ACTIVITY HANDOFF
]]
 local after=before
 after=after:sub(1,26375)..[[if type(publishActivePresentation)=='function' then
    publishActivePresentation(addon,addon.GlowCooldown,getfenv(1))
end

]]..after:sub(26376)
 after=after:sub(1,401)..[[-- The active-plan receiver is consumed before any library callback. Only the
-- literal cooldown publisher below may qualify its private presentation route.
---@type fun(...): any
local publishActivePresentation=addon.BindActiveRuntimePresentationSource
addon.BindActiveRuntimePresentationSource=nil
]]..after:sub(402)
 rows['buttons.lua']={before=before,after=after}
end
return function(text,path,mode)
 if mode==nil then text=dofile('tests/fixtures/restore_observation_lifecycles.lua')(text,path)end
 if mode==nil then text=dofile('tests/fixtures/restore_execution_generation.lua')(text,path)end
 if mode==nil and (path=='Core/rotation_scope.lua' or path=='Core/rotation_references.lua')then text=dofile('tests/fixtures/restore_active_runtime_continuation.lua')(text,path)end
 local row=rows[path];assert(row,'unknown active runtime source path')
 if mode=='before'then assert(text==nil);return row.before end
 assert(mode==nil and text==row.after,'unrelated active runtime source change: '..path)
 return row.before
end
