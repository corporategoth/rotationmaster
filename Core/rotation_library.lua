local addon_name, addon = ...
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
local contextIpairs,contextRawget,contextEqual=ipairs,rawget,rawequal
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
    bind(reader,provesGeneration,ownsPrivateContext);return true
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
    if saved then active.views[id]=active.catalog:Get({kind="builtin",id=id});active.generation={} end
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
