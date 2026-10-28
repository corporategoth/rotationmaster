-- Exact source inverse to a609a28; compose before the prior complete proofs.
local rows = {
    ["Data/rotation_store.lua"] = {
        bytes = 41494,
        hash = [========[11e30f95]========],
        oldBytes = 36975,
        oldHash = [========[896a1f48]========],
        changes = {
            {
                current = [========[    -- This capability is bound only to trusted facade code. Canonical borrows
    -- must not escape its synchronous projectors; UI keeps snapshot APIs.
    local reader,readerState,readerBusy={},'binding',false
    local readIndex,readEpoch,readRevision=nil,0,0
    local publicationWriteVersion=0
    local readSeals=setmetatable({},{__mode='k'})
    local nilCharacter={}
    local function detachedAddress(a)
        return {scope=a.scope,class=a.class,owner=a.owner,spec=a.spec,id=a.id}
]========],
                previous = [========[    -- This capability is bound only to trusted facade code. Canonical borrows
    -- must not escape its synchronous projectors; UI keeps snapshot APIs.
    local reader,readerState,readerBusy={},'binding',false
    local readIndex,readEpoch,readRevision=nil,0,0
    local readSeals=setmetatable({},{__mode='k'})
    local nilCharacter={}
    local function detachedAddress(a)
        return {scope=a.scope,class=a.class,owner=a.owner,spec=a.spec,id=a.id}
]========],
            },
            {
                current = [========[            if not current or #current~=#entry.items then return nil,'stale-rotation-read-seal' end
            for i,meta in ipairs(current) do if meta~=entry.items[i] then return nil,'stale-rotation-read-seal' end end
        end
        return true
    end
    local ownedReaderIsCurrent=reader.IsCurrent
    -- Only an owned factory admission may consume this private capability.
    local guardType,guardPairs,guardGetmetatable,guardRawget=type,pairs,getmetatable,rawget
    local stringMeta=guardGetmetatable('')
    local stringIndex=guardType(stringMeta)=='table' and guardRawget(stringMeta,'__index')
    local stringFind=guardType(stringIndex)=='table' and guardRawget(stringIndex,'find')
    local function makePublicationGuard(_,seal,c)
        local entry=readSeals[seal]
        if not entry or entry.kind~='record' then return nil end
        local meta=entry.meta;local a=meta.address;c=c or entry.context
        local owners=a.scope=='class' and readIndex.classes or readIndex.characters
        local owner=owners[a.owner];local scope=owner and owner.specs[a.spec]
        local epoch,writeVersion=entry.epoch,publicationWriteVersion
        local expectedRoots=readIndex.roots;local chain=meta.chain
        local record,payload=meta.record,meta.payload
        return function()
            if reader.IsCurrent~=ownedReaderIsCurrent or type~=guardType or pairs~=guardPairs
                or getmetatable~=guardGetmetatable or rawget~=guardRawget then return nil end
            if guardType(stringIndex)~='table' or guardType(stringFind)~='function'
                or guardGetmetatable('')~=stringMeta or guardRawget(stringMeta,'__index')~=stringIndex
                or guardRawget(stringIndex,'find')~=stringFind then return nil end
            -- These retained scalar validators can call custom code. Finish
            -- them before checking the current lifetime/metadata/raw witnesses.
            if not plain(c) or not isClass(c.class) or c.class~=entry.context.class or c.character~=entry.context.character then return false end
            if not isClass(a.class) then return false end
            if readerState~='active' or readEpoch~=epoch or publicationWriteVersion~=writeVersion
                or not scope or scope.metadata[a.id]~=meta then return false end
            -- Preserve all raw state/header/container/component witnesses checked
            -- by readRows/privateRecord; omit only revalidating immutable private
            -- addresses and duplicate checks of the same plain class map/body.
            if not fields(state,stateFields) or state.version~=1 then return false end
            local classes,characters,legacy=state.classes,state.characters,state.legacy
            if classes~=expectedRoots[1] or characters~=expectedRoots[2] or legacy~=expectedRoots[3]
                or not plain(classes) or not plain(characters) or not plain(legacy) then return false end
            local root=a.scope=='class' and classes or characters
            if root~=chain[1] then return false end
            local bucket=root[a.owner]
            if bucket~=chain[2] or not plain(bucket) then return false end
            local map=bucket
            if a.scope=='character' then
                if bucket.class~=a.class or bucket.class~=owner.class or not fields(bucket,{class=true,specs=true}) then return false end
                map=bucket.specs
                if not plain(map) then return false end
            end
            if map~=chain[3] then return false end
            local rows=map[a.spec]
            if rows~=chain[4] or not plain(rows) or rows[a.id]~=record then return false end
            if not fields(record,recordFields) then return false end
            for _,component in ipairs(components) do
                local value=record[component]
                if value~=payload[component] or value~=nil and not plain(value) then return false end
            end
            return true
        end
    end
    function reader:ListOwned(number,c)
        local ready,reason=readerReady(true);if not ready then return nil,reason end
        local items,problem=privateRows(number,c);if not items then return nil,problem end
]========],
                previous = [========[            if not current or #current~=#entry.items then return nil,'stale-rotation-read-seal' end
            for i,meta in ipairs(current) do if meta~=entry.items[i] then return nil,'stale-rotation-read-seal' end end
        end
        return true
    end
    function reader:ListOwned(number,c)
        local ready,reason=readerReady(true);if not ready then return nil,reason end
        local items,problem=privateRows(number,c);if not items then return nil,problem end
]========],
            },
            {
                current = [========[        if readIndex then
            advanceDestination=readRows(destination,c,readIndex)
            if pending.operation=='move' then advanceSource=readRows(pending.address,c,readIndex) end
        end
        -- A successful write with an unadvanceable stale
        -- index must retire private publication witnesses, without blessing it
        -- or changing public unrelated-record seal semantics.
        if readIndex and (not advanceDestination or pending.operation=='move' and not advanceSource) then
            publicationWriteVersion=publicationWriteVersion+1
        end
        -- All checks and copies precede plain table assignments; no callbacks run.
        if pending.operation=='delete' then write(pending.address,nil)
        else
            write(destination,payload)
]========],
                previous = [========[        if readIndex then
            advanceDestination=readRows(destination,c,readIndex)
            if pending.operation=='move' then advanceSource=readRows(pending.address,c,readIndex) end
        end
        -- All checks and copies precede plain table assignments; no callbacks run.
        if pending.operation=='delete' then write(pending.address,nil)
        else
            write(destination,payload)
]========],
            },
            {
                current = [========[        local valid,reason=validState(state)
        if not valid then readerState='retired';return nil,reason end
        index=buildIndex();resetReaderIndex();readerState='active'
    end
    -- Keep this capability out of the mutable reader callback transport.
    return service,nil,makePublicationGuard
end
local ownedRotationStoreFactory=data.NewRotationStore
local storeFactoryEnvironment=type(getfenv)=='function' and getfenv(1) or nil
function data.BindOwnedRotationStoreFactory(bind)
    if type(bind)=='function' then bind(ownedRotationStoreFactory,storeFactoryEnvironment) end
end

-- BEGIN CPU RUNTIME WORK HANDOFF
do
 local bind=addon.BindCPURuntimeWorkDiagnostic
 if type(bind)=='function' then bind(addon,'store',data.NewRotationStore,function() return plain,fields,validAddress end) end
]========],
                previous = [========[        local valid,reason=validState(state)
        if not valid then readerState='retired';return nil,reason end
        index=buildIndex();resetReaderIndex();readerState='active'
    end
    return service
end
-- BEGIN CPU RUNTIME WORK HANDOFF
do
 local bind=addon.BindCPURuntimeWorkDiagnostic
 if type(bind)=='function' then bind(addon,'store',data.NewRotationStore,function() return plain,fields,validAddress end) end
]========],
            },
        },
    },
    ["Core/rotation_scope.lua"] = {
        bytes = 66058,
        hash = [========[9703e477]========],
        oldBytes = 63157,
        oldHash = [========[0473c689]========],
        changes = {
            {
                current = [========[local addon_name,addon=...
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
local prepareActivePublication,finishActivePublication,prepareActiveRebind,finishActiveRebind
local activeCurrent=addon.IsActiveRotationTransitionCurrent
local protect,raise=pcall,error
local preparedBinding,bindGeneration
]========],
                previous = [========[local addon_name,addon=...
local data=addon.RotationData
local prepareActivePublication,finishActivePublication,prepareActiveRebind,finishActiveRebind
local activeCurrent=addon.IsActiveRotationTransitionCurrent
local protect,raise=pcall,error
local preparedBinding,bindGeneration
]========],
            },
            {
                current = [========[        retire(previous)
        if not bindingCurrent() then return nil,'rotation-transition-superseded' end
    end
    local owner=self;profile=self.db.profile;local state=profile.rotationStore;local fallbackID=profile.rotationFallbackID
    local reader,store,problem,ownedPublicationGuard;local alive=true;local managedStoreReader=false
    if not libraryReader then problem='rotation-library-not-ready'
    elseif not text(profile.rotationFallbackID,128) then problem='missing-fallback-configuration'
    else
        local construct=data.NewRotationStore
]========],
                previous = [========[        retire(previous)
        if not bindingCurrent() then return nil,'rotation-transition-superseded' end
    end
    local owner=self;profile=self.db.profile;local state=profile.rotationStore;local fallbackID=profile.rotationFallbackID
    local reader,store,problem;local alive=true
    if not libraryReader then problem='rotation-library-not-ready'
    elseif not text(profile.rotationFallbackID,128) then problem='missing-fallback-configuration'
    else
        local construct=data.NewRotationStore
]========],
            },
            {
                current = [========[        local getOptions=self.GetRotationValidationOptions
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
]========],
                previous = [========[        local getOptions=self.GetRotationValidationOptions
        if not bindingCurrent() then return nil,'rotation-transition-superseded' end
        local validation=getOptions(self)
        if not bindingCurrent() then return nil,'rotation-transition-superseded' end
        store,problem=construct({state=state,fallbackID=profile.rotationFallbackID,validation=validation,bindInternalReader=function(value) reader=value end})
    end
    if not bindingCurrent() then return nil,'rotation-transition-superseded' end
    local coordinator={};current=coordinator
    local rosterStamp,rosterOwned,rosterLibrary,rosterValidation,rosterVirtual,rosterBuiltin
]========],
            },
            {
                current = [========[        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        local validation,referenceStamp=owner:GetRotationValidationOptions();local revision=owner.conditionRegistryVersion;local generation=libraryReader and libraryReader:Generation();local pass={}
        local selected,untracked,listSeal={},{},nil
        local publicationSelected={};local makePublicationGuard=managedStoreReader and ownedPublicationGuard
        local observedPrivate,observedMethod
        local function eligibilityContext()
            local value,private,method=rotationContext(owner,number)
            if libraryContextProof and libraryContextProof(method,eligibilityContext,rotationContext)and private==true then observedPrivate,observedMethod=true,method;return value end
]========],
                previous = [========[        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        local validation,referenceStamp=owner:GetRotationValidationOptions();local revision=owner.conditionRegistryVersion;local generation=libraryReader and libraryReader:Generation();local pass={}
        local selected,untracked,listSeal={},{},nil
        local observedPrivate,observedMethod
        local function eligibilityContext()
            local value,private,method=rotationContext(owner,number)
            if libraryContextProof and libraryContextProof(method,eligibilityContext,rotationContext)and private==true then observedPrivate,observedMethod=true,method;return value end
]========],
            },
            {
                current = [========[                assets[index]=item;return item
            end)
            if not okRead then return nil,asset end
            selected[index]=seal
            if request and type(makePublicationGuard)=='function' then publicationSelected[index]=makePublicationGuard(reader,seal,c) end
            if asset.untracked then untracked[index]={address=copy(reference.address),baseline=asset.baseline} end
            if not batch then local current,problemText=pass:IsCurrent();if not current then return nil,problemText end end
            local status=asset.validation
            if asset.unavailable or not status.valid or not status.supported or not status.resolved then return nil,reference.address.id==fallbackID and 'invalid-fallback' or asset.unavailable or 'rotation-unavailable' end
]========],
                previous = [========[                assets[index]=item;return item
            end)
            if not okRead then return nil,asset end
            selected[index]=seal
            if asset.untracked then untracked[index]={address=copy(reference.address),baseline=asset.baseline} end
            if not batch then local current,problemText=pass:IsCurrent();if not current then return nil,problemText end end
            local status=asset.validation
            if asset.unavailable or not status.valid or not status.supported or not status.resolved then return nil,reference.address.id==fallbackID and 'invalid-fallback' or asset.unavailable or 'rotation-unavailable' end
]========],
            },
            {
                current = [========[            end
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
]========],
                previous = [========[            end
            local complete,completionReason=self:IsCurrent();if not complete then return {},completionReason end
            return result
        end
        return pass
    end
    ownedRuntimePasses[coordinator]=coordinator.RuntimePass
    completeRebind(binding,coordinator,problem)
]========],
            },
            {
                current = [========[        contextVersion={}
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

]========],
                previous = [========[        contextVersion={}
        if owner~=addon or owner.AcquireRotationRuntimePass~=ownedAcquireRuntimePass
            or owner.GetScopedRotationCoordinator~=ownedScopedCoordinator
            or not current or current.RuntimePass~=ownedRuntimePasses[current] then return owner:AcquireRotationRuntimePass(spec) end
        local previous=evaluationRequest;evaluationRequest={}
        local ok,pass,reason=protect(ownedAcquireRuntimePass,owner,spec)
        evaluationRequest=previous
        if not ok then raise(pass,0) end
        return pass,reason
    end,function() contextVersion={} end)
    return true
end

]========],
            },
        },
    },
    ["main.lua"] = {
        bytes = 86781,
        hash = [========[50e6cf45]========],
        oldBytes = 86599,
        oldHash = [========[c0b43855]========],
        changes = {
            {
                current = [========[end

function addon:EvaluateNextActionInternal()
    local selectedRotation,selectedSpec,selectedProfile=self.currentRotation,self.currentSpec,self.db.profile
    local runtimePass,rot,publicationGuard
    if selectedRotation~=nil then
        if self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator() then
            if acquireEvaluationPass then local reason;runtimePass,reason,publicationGuard=acquireEvaluationPass(self,selectedSpec)
            else runtimePass=self:AcquireRotationRuntimePass(selectedSpec) end
            if runtimePass then rot=runtimePass:Get(selectedRotation) end
        else rot=self:GetRuntimeRotation(selectedSpec,selectedRotation) end
    end
]========],
                previous = [========[end

function addon:EvaluateNextActionInternal()
    local selectedRotation,selectedSpec,selectedProfile=self.currentRotation,self.currentSpec,self.db.profile
    local runtimePass,rot
    if selectedRotation~=nil then
        if self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator() then
            if acquireEvaluationPass then runtimePass=acquireEvaluationPass(self,selectedSpec)
            else runtimePass=self:AcquireRotationRuntimePass(selectedSpec) end
            if runtimePass then rot=runtimePass:Get(selectedRotation) end
        else rot=self:GetRuntimeRotation(selectedSpec,selectedRotation) end
    end
]========],
            },
            {
                current = [========[        local previewWindow=self.nextWindow
        local nativePreview=previewWindow and type(previewWindow.AddRecommendation)=="function"
        local staged={}
        local function current()
            if self.currentRotation~=selectedRotation or self.currentSpec~=selectedSpec or self.db.profile~=selectedProfile
                or self.nextWindow~=previewWindow then return false end
            if not runtimePass then return true end
            if publicationGuard then return publicationGuard() end
            return runtimePass:IsCurrent()
        end
        local function stage(callback) staged[#staged+1]=callback end
        if nativePreview then
            stage(function() previewWindow:ReleaseChildren();if current() then previewWindow:PauseLayout() end end)
]========],
                previous = [========[        local previewWindow=self.nextWindow
        local nativePreview=previewWindow and type(previewWindow.AddRecommendation)=="function"
        local staged={}
        local function current()
            return self.currentRotation==selectedRotation and self.currentSpec==selectedSpec and self.db.profile==selectedProfile
                and self.nextWindow==previewWindow and (not runtimePass or runtimePass:IsCurrent())
        end
        local function stage(callback) staged[#staged+1]=callback end
        if nativePreview then
            stage(function() previewWindow:ReleaseChildren();if current() then previewWindow:PauseLayout() end end)
]========],
            },
        },
    },
}

local function hash(s)
    local n = 5381

    for i = 1, #s do
        n = (n * 33 + s:byte(i)) % 4294967296
    end

    return string.format('%08x', n)
end

return function(text, path)
    text = dofile('tests/fixtures/restore_execution_generation.lua')(text, path)

    if path == 'Data/rotation_store.lua' and text:find('local function continuationCurrent()', 1, true) then
        text = dofile('tests/fixtures/restore_active_runtime_continuation.lua')(text, path)
    end
    if path == 'Core/rotation_scope.lua' and text:find('currentPlanSource=function', 1, true) then
        text = dofile('tests/fixtures/restore_active_runtime_plan.lua')(text, path)
    end
    if path == 'main.lua' then
        text = dofile('tests/fixtures/restore_active_runtime_main.lua')(text, path)
    end
    if path == 'Core/rotation_scope.lua' and text:find('local prepareChoicePublication', 1, true) then
        text = dofile('tests/fixtures/restore_rotation_choice_preferences.lua')(text, path)
    end
    if path == 'main.lua' and text:find('-- BEGIN ANALYTICS ADVICE HANDOFF', 1, true) then
        text = dofile('tests/fixtures/restore_analytics_preview_delivery.lua')(text, path)
    end
    if path == 'Data/rotation_store.lua' and text:find("-- Preserve public-reader admission", 1, true) then
        text = dofile('tests/fixtures/restore_runtime_store_native_gate.lua')(text, path)
    end

    local row = rows[path]

    if not row then
        return text
    end

    assert(#text == row.bytes and hash(text) == row.hash, 'unrelated publication-store source: ' .. path)

    for _, change in ipairs(row.changes) do
        local a, b = text:find(change.current, 1, true)
        assert(a and not text:find(change.current, b + 1, true), 'publication-store inverse anchor: ' .. path)
        text = text:sub(1, a - 1) .. change.previous .. text:sub(b + 1)
    end

    assert(#text == row.oldBytes and hash(text) == row.oldHash, 'publication-store inverse predecessor: ' .. path)
    return text
end
