-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Strict original-module accessor; implementation patches are filled after RED.
local records = {
    ["Core/rotation_references.lua"] = [====[local _,addon=...
local observed,stamp
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
local function observe(owner)
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
-- Internal authority checks need the current stamp, not detached public maps.
-- Keep checking every dependency at each call, including reentrant mutations.
function addon:GetRotationValidationStamp()
    observe(self)
    return stamp
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
        and proofRawequal(proofGetfenv(observe),proofEnvironment) and proofRawequal(proofGetfenv(normalized),proofEnvironment)
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
    observe(self)
    -- Public maps remain fresh: consumers cannot poison private observations.
    local conditions=entries(observed.conditions)
    local itemsets=entries(observed.itemsets)
    local effects=entries(observed.effects)
    return {conditions=conditions,itemsets=itemsets,effects=effects},stamp
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
]====],
    ["Core/rotation_library.lua"] = [====[local addon_name, addon = ...
local data = addon.RotationData
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
local bindClient=addon.BindRotationClientReader
if type(bindClient)=='function' then
    bindClient(addon,function(reader) clientContextReader=reader end)
    addon.BindRotationClientReader=nil
end
-- Only the exact owned methods use the narrow projection. Overrides retain
-- their actual receiver, first result, shared table and error behavior.
local function rotationContext(owner,spec)
    local method=owner.GetRotationContext
    if method~=ownedRotationContext or not clientContextReader then return method(owner,spec) end
    local context=clientContextReader(owner.Platform)
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
    return context
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
    function reader:Context(spec) return rotationContext(owner,spec) end
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
    bind(reader,provesGeneration);return true
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
    local ok,why=ensure(self);if not ok then return false,why end
    local saved,reason=active.catalog:SetEnabled({kind="builtin",id=id},value)
    if saved then active.views[id]=active.catalog:Get({kind="builtin",id=id});active.generation={} end
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
    local source=active.catalog:Get({kind="builtin",id=id})
    if not source then return nil,"unknown-rotation" end
    local context=self:GetRotationContext(spec)
    if not data.IsRotationClassToken(context.class) or not matchesClass(source,context) then return nil,"class-mismatch" end
    local state={}
    local temporary=data.NewCatalog({state=state,newId=self.uuid})
    assert(temporary:RegisterBuiltin(source.envelope))
    local generated,reason=temporary:Clone({kind="builtin",id=id},name)
    if not generated then return nil,reason end
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
    if self.GetImportedRotationView then
        local imported,reason=self:GetImportedRotationView(spec,id)
        if imported then
            local prepared={body=imported.envelope.body,manifest=data.CopyData(imported.envelope),sourceId=imported.sourceId,
                sourceRevision=imported.sourceRevision,stepOrigins=imported.stepOrigins}
            prepared.manifest.body=nil
            return self:CreateImportedRotation(prepared,spec,name)
        elseif reason~="not-imported" then return nil,reason end
    end
    local source=self:GetEditableRotation(spec,id)
    local body,problem=data.CopyData(source)
    if problem or type(body)~="table" then return nil,"invalid-custom-body" end
    if type(name)~="string" or name=="" then return nil,"invalid-name" end
    local ok,why=ensure(self);if not ok then return nil,why end
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
    body.name=name
    local metadata
    if sourceView then
        local manifest=data.CopyData(sourceView.envelope);manifest.body=nil;manifest.id=generated;manifest.revision=1;manifest.nameKey=name
        metadata={manifest=manifest,lineage=lineage}
    end
    if origins and origins[generated]~=nil or comparisonRows and comparisonRows[generated]~=nil then return nil,"id-collision" end
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
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then
        local reference,why=scoped:Resolve(spec,id);if not reference then return nil,why end
        if reference.kind=='builtin' then return nil,'read-only-rotation' end
        if not expected then local record;record,expected=scoped:Snapshot(spec,reference);if not record then return nil,expected end end
        local currentReference=self.currentRotation and (self.currentSpec==nil or self.currentSpec==spec) and scoped:Resolve(spec,self.currentRotation)
        local deletingCurrent=currentReference and currentReference.kind=='custom'
        if deletingCurrent then for _,field in ipairs({'scope','class','owner','spec','id'}) do if currentReference.address[field]~=reference.address[field] then deletingCurrent=false;break end end end
        local ok,problem=scoped:Delete(reference,expected)
        if not ok then return nil,problem end
        if deletingCurrent then
            if self.RemoveAllCurrentGlows then self:RemoveAllCurrentGlows() end
            self.currentRotation=nil;self.manualRotation=false
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
    if self.currentRotation==id and (self.currentSpec==nil or self.currentSpec==spec) then
        if self.RemoveAllCurrentGlows then self:RemoveAllCurrentGlows() end
        self.currentRotation=nil;self.manualRotation=false
    end
    self.db.profile.rotations[spec][id]=nil
    for _,key in ipairs({'origins','comparisons','imports'}) do
        if active.state[key][spec] then active.state[key][spec][id]=nil end
    end
    if active.cloneScopes[spec] then active.cloneScopes[spec][id]=nil end
    return true
end
]====],
    ["Core/rotation_scope.lua"] = [====[local addon_name,addon=...
local data=addon.RotationData
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local libraryReader,libraryGenerationProof
local bindLibrary=addon.BindRotationLibraryReader
if type(bindLibrary)=='function' then
    bindLibrary(addon,function(reader,proof) libraryReader=reader;if type(proof)=='function' then libraryGenerationProof=proof end end)
    addon.BindRotationLibraryReader=nil
end
local function rotationContext(owner,spec)
    local method=libraryReader and libraryReader.Context
    if type(method)=='function' then return method(libraryReader,spec) end
    local fallback=owner.GetRotationContext
    return fallback(owner,spec)
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
function addon:BindRotationProfile()
    if current then current:Retire() end
    local owner=self;local profile=self.db.profile;local state=profile.rotationStore;local fallbackID=profile.rotationFallbackID
    local reader,store,problem;local alive=true
    if not libraryReader then problem='rotation-library-not-ready'
    elseif not text(profile.rotationFallbackID,128) then problem='missing-fallback-configuration'
    else store,problem=data.NewRotationStore({state=state,fallbackID=profile.rotationFallbackID,validation=self:GetRotationValidationOptions(),bindInternalReader=function(value) reader=value end}) end
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
    function coordinator:Commit(reference,token,record,scope)
        local ok,why=ready();if not ok then return nil,why end
        local c,errorText=context();if not c then return nil,errorText end
        if not customReference(reference) then return nil,'invalid-rotation-reference' end
        local a=reference.address;scope=scope or a.scope
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local destination=copy(a);destination.scope=scope;destination.owner=scope=='class' and c.class or c.character
        local issued=token and expected[token];local plan,reason
        if token then
            if not issued or not same(issued.reference,reference) or not same(issued.context,c) then return nil,'stale-rotation-record' end
            if a.scope~=destination.scope or a.owner~=destination.owner then plan,reason=store:PlanMove(a,destination,c,issued.token,record)
            else plan,reason=store:PlanReplace(a,record,c,issued.token) end
        else plan,reason=store:PlanCreate(destination,record,c) end
        if not plan then return nil,reason end
        local committed,problemText=store:Commit(plan,c);if not committed then return nil,problemText end
        if token then expected[token]=nil end
        local target={kind='custom',address=destination};local oldIndex=referenceKey(reference);local targetIndex=referenceKey(target)
        local draft=pending[oldIndex]
        if draft then
            for index,value in pairs(pending) do if value==draft then pending[index]=nil;if index~=targetIndex then byReference[index]=nil end end end
            byReference[targetIndex]=draft.key;byKey[draft.key]=copy(target)
        elseif oldIndex~=targetIndex then
            local oldKey=byReference[oldIndex];if oldKey then cleanup[oldKey]=assets[oldIndex] and assets[oldIndex].body;byKey[oldKey]=nil;byReference[oldIndex]=nil end
        end
        keyFor(target);return target
    end
    function coordinator:Delete(reference,token)
        local ok,why=ready();if not ok then return nil,why end
        local c,errorText=context();if not c then return nil,errorText end
        local issued=expected[token]
        if not issued or not same(issued.reference,reference) or not same(issued.context,c) then return nil,'stale-rotation-record' end
        if reference.address.id==profile.rotationFallbackID then return nil,'read-only-rotation' end
        local plan,reason=store:PlanDelete(reference.address,c,issued.token);if not plan then return nil,reason end
        local committed,problemText=store:Commit(plan,c);if not committed then return nil,problemText end
        local index=referenceKey(reference);local key=byReference[index]
        if key then cleanup[key]=assets[index] and assets[index].body;byKey[key]=nil;byReference[index]=nil;headers[key]=nil end
        assets[index]=nil;expected[token]=nil;return true
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
        local committed,commitReason=store:Commit(adoption.plan,c);if not committed then return nil,commitReason end
        local reference={kind='custom',address=copy(adoption.target)}
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
        adoptionPlans[public]=nil;keyFor(reference);return true,reference
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
        local saved,commitReason=self:Commit(reference,token,record,scope);if not saved then return nil,commitReason end
        return id,nil,saved
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
        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        local validation,referenceStamp=owner:GetRotationValidationOptions();local revision=owner.conditionRegistryVersion;local generation=libraryReader and libraryReader:Generation();local pass={}
        local selected,untracked,listSeal={},{},nil
        local function eligibilityContext()
            local value=rotationContext(owner,number);local result={}
            for _,key in ipairs({'family','class','spec','actionContext','level','build','combatDataPolicy'}) do result[key]=value and value[key] end
            return result
        end
        local observedContext=eligibilityContext()
        local function baseCurrent()
            local readyNow,problemText=ready();if not readyNow then return nil,problemText end
            local now=context();if not now or not same(now,c) then return nil,'rotation-owner-changed' end
            if not same(observedContext,eligibilityContext()) then return nil,'rotation-context-changed' end
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
        return pass
    end
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
]====],
    ["Diagnostics/cpu.lua"] = [====[local addon_name,addon=...
-- Opt-in cumulative snapshots. No functions are wrapped and shared counters are
-- never reset. Only this module's one completion timer exists during capture.
local active,lastReport
-- Fixed, source-free proof snapshots. The installer is retired by main;
-- this reader is private and is never invoked outside capture boundaries.
local proofType,proofRawget,proofPcall=type,rawget,pcall
-- BEGIN PRIVATE CACHE ANCHORS
local cacheSourceEqual=rawequal
local cacheSourceModules=proofRawget(addon,'builtinSourceModules')
local cacheSourceGetter=proofType(cacheSourceModules)=='table' and proofRawget(cacheSourceModules,'Functions/cache.lua') or nil
-- END PRIVATE CACHE ANCHORS
local executionIndexDiagnostic
function addon:BindCPUExecutionIndexDiagnostic(provider)
 if self~=addon or executionIndexDiagnostic or proofType(provider)~="function" then return end
 executionIndexDiagnostic=provider;addon.BindCPUExecutionIndexDiagnostic=nil
end
local proofReasons={}
for _,reason in ipairs({"ready","unbound","namespace","capability","env","method","public-env","finite-env","diagnostic-env","raw-type","raw-pairs","raw-ipairs","raw-getmetatable","raw-getfenv","raw-math","raw-table","math-huge","math-max","table-sort","portable-proof","child-env","location-env","failure-env","identifier-env","dense-env","parser-match-unavailable","parser-sub-unavailable","owner","db","profile","index-reader"}) do proofReasons[reason]=true end
local proofOwners={"main","sequence","portable","index"}
local proofRawKeys={"type","pairs","ipairs","getmetatable","getfenv","math","table"}
local function executionIndexProof()
 if not executionIndexDiagnostic then return "probe-unavailable" end
 local ok,text=proofPcall(function()
  local status=executionIndexDiagnostic()
  if proofType(status)~="table" then return "probe-unavailable" end
  local parts={}
  for i=1,4 do
   local name=proofOwners[i];local row=proofRawget(status,name)
   local reason=proofType(row)=="table" and proofRawget(row,"reason") or nil
   reason=proofType(reason)=="string" and proofRawget(proofReasons,reason) and reason or "unavailable"
   local part=name.."="..reason
   if reason~="ready" and name~="main" then
    local flags=proofType(row)=="table" and proofRawget(row,"raw") or nil
    part=part.."["
    for keyIndex=1,7 do
     local key=proofRawKeys[keyIndex]
     if name~="sequence" or key=="type" or key=="ipairs" or key=="getfenv" then
      local flag=proofType(flags)=="table" and proofRawget(flags,key)
      part=part..key.."="..(flag==true and "1" or flag==false and "0" or "?").."," end
    end
    part=part.."]"
   end
   parts[i]=part
  end
  local function parserFlag(owner,key)
   local row=proofRawget(status,owner)
   local value=proofType(row)=="table" and proofRawget(row,key)
   return value==true and "1" or value==false and "0" or "?"
  end
  return parts[1].."; "..parts[2].."; "..parts[3].."; "..parts[4].."; parser-match="..parserFlag("index","parserMatch").."; parser-sub="..parserFlag("portable","parserSub")
 end)
 return ok and text or "probe-unavailable"
end
local function appendExecutionIndexProof(report,started,ended)
 local bytes=#report-1
 for i=1,#report do bytes=bytes+#report[i] end
 local first="Execution index proof start: "..(started or "probe-unavailable")
 local last="Execution index proof end: "..ended
 if bytes+1+#first+1+#last<16000 then
  report[#report+1]=first;report[#report+1]=last
 else
  local omitted="Execution index proof omitted to keep report bounded."
  if bytes+1+#omitted<16000 then report[#report+1]=omitted end
 end
end
local MAX_FUNCTIONS,MAX_SCAN,TOP=384,512,20
local runtimeNames={
 'EvaluateNextAction','EvaluateNextActionInternal','UpdateCurrentCondition','Fetch','UpdateBagContents',
 'GetRotationOwnerContext','GetRotationContext','GetRotationValidationStamp','GetRotationValidationOptions',
 'AcquireRotationRuntimePass','GetRuntimeRotations','GetRuntimeRotation','GetRotationCandidates',
 'EvaluateRotationSequence','rotationValidConditions','evaluateConditionResult','validateCondition',
 'NewActionReadiness','GetConditionUnitLevel','GetConditionPointResource','GetClassGroupCount','EvaluateItemCondition',
 'RefreshPreviewWindow','RemoveAllCurrentGlows','DestroyAllGlows','RefreshMacroButtons','UpdateButtonGlow','GlowNextSpell','GlowSpell','GlowCooldown','IsGlowing','FindSpell','GetSpellIds','RefreshSpellCatalog',
}
local platformNames={}
for name in ([[AuraRemaining CanReadValue GetAPISurface GetAnnouncementGroup GetAssistedAvailability GetAuraByIndex GetBagItemCounts GetBagSnapshot GetClientInfo GetGlobalCooldown GetGlyphItemInfo GetGlyphSocketSnapshot GetGridTalentInfo GetGroupMembership GetInstanceObservation GetItemCooldown GetItemCount GetItemDisplayInfo GetItemID GetItemInfoInstant GetItemMetadata GetItemRangeState GetItemUseSpell GetLossOfControlCount GetLossOfControlEvent GetMobInfo2Observation GetMacroAction GetNameplateMaxDistance GetPetObservation GetPlayerFlagObservation GetPlayerFormObservation GetPlayerMovementObservation GetPlayerOwnerClassObservation GetPrimaryTalentTree GetRangeCheckBounds GetRosterClassObservation GetRotationSpecialization GetRotationSpecializations GetRuneCooldownObservation GetRuneEvaluationTime GetRuneTypeObservation GetSpellBookSnapshot GetSpellCharges GetSpellCooldown GetSpellInfo GetSpellLink GetSpellRangeState GetTalentLayout GetTalentTreeCount GetTalentTreeInfo GetTotemInfo GetTotemSlotCount GetTreeTalentCount GetTreeTalentInfo GetUnitAttackabilityObservation GetUnitCastObservation GetUnitFlagObservation GetUnitHealthObservation GetUnitIdentityObservation GetUnitLevelObservation GetUnitMetadataObservation GetUnitPointIdentityObservation GetUnitPointPowerObservation GetUnitPowerObservation GetUnitThreatObservation GetZonePVPObservation IsAutoRepeatActive IsBeyondMeleeRange IsCurrentSpell IsItemEquipped IsItemLevelAllowed IsItemReady IsMeleeAttackNeeded IsSpellKnown IsSpellReady IsSpellUsable NewSpellRangeReader ReadAuraField SendAnnouncementChat]]):gmatch('%S+') do platformNames[#platformNames+1]=name end
local function readable(value)
 if type(issecretvalue)=='function' then local ok,secret=pcall(issecretvalue,value);if not ok or secret then return false end end
 if type(canaccessvalue)=='function' then local ok,allowed=pcall(canaccessvalue,value);if not ok or not allowed then return false end end
 return true
end
local function finite(value) return readable(value) and type(value)=='number' and value==value and value~=math.huge and value~=-math.huge end
local function counter(value,integer) return finite(value) and value>=0 and (not integer or value%1==0) end
local function field(owner,key) if type(owner)=='table' then return rawget(owner,key) end end
local function addonCPUAPI(name,legacy)
 local candidate=field(C_AddOns,name)
 if type(candidate)=='function' then return candidate end
 if type(legacy)=='function' then return legacy end
end
local function totalAPI() return addonCPUAPI('GetAddOnCPUUsage',GetAddOnCPUUsage) end
local function updateAPI() return addonCPUAPI('UpdateAddOnCPUUsage',UpdateAddOnCPUUsage) end
local function cvarAPI() return type(GetCVar)=='function' and GetCVar or type(C_CVar)=='table' and type(C_CVar.GetCVar)=='function' and C_CVar.GetCVar or nil end
local function enabled(fn)
 if type(fn)~='function' then return false,'missing-script-profile-api' end
 local ok,value=pcall(fn,'scriptProfile');if not ok then return false,'script-profile-query-error' end
 if not readable(value) then return false,'restricted-script-profile' end
 if value=='0' then return false,'script-profile-disabled' end
 if value~='1' then return false,'invalid-script-profile-result' end
 return true
end
local function clockAPI() return type(GetTimePreciseSec)=='function' and GetTimePreciseSec or type(GetTime)=='function' and GetTime or nil end
local function clock(fn)
 if type(fn)~='function' then return nil,'missing-clock-api' end
 local ok,value=pcall(fn);if not ok then return nil,'clock-error' end
 if not counter(value) then return nil,'invalid-clock' end
 return value
end
local function total(run)
 local ok=pcall(run.update);if not ok then return nil,'addon-cpu-update-error' end
 local good,value=pcall(run.total,addon_name);if not good then return nil,'addon-cpu-query-error' end
 if not counter(value) then return nil,'invalid-addon-cpu-counter' end
 return value
end
local function snapshot(run,fn)
 local ok,exclusive,calls=pcall(run.query,fn,false)
 if not ok then return nil,'function-cpu-query-error' end
 if not counter(exclusive) or not counter(calls,true) then return nil,'invalid-function-cpu-counter' end
 local good,inclusive,inclusiveCalls=pcall(run.query,fn,true)
 if not good then return nil,'function-cpu-query-error' end
 if not counter(inclusive) or not counter(inclusiveCalls,true) then return nil,'invalid-function-cpu-counter' end
 return {exclusive=exclusive,inclusive=inclusive,calls=calls,inclusiveCalls=inclusiveCalls}
end
local function visibility(owner)
 local frame=field(owner,'frame') or owner
 local method=type(frame)=='table' and frame.IsShown
 if type(method)~='function' then return nil end
 local ok,shown=pcall(method,frame);if ok and readable(shown) and type(shown)=='boolean' then return shown end
end
local function context(owner)
 local config=visibility(field(owner,'configWindow'));local dialog=visibility(field(owner,'nativeCustomConditionDialog'))
 if dialog==true then config=true end
 local combat='unavailable';if type(InCombatLockdown)=='function' then local ok,value=pcall(InCombatLockdown);if ok and readable(value) and type(value)=='boolean' then combat=tostring(value) end end
 local profile=field(field(owner,'db'),'profile')
 local function interval(key) local value=field(profile,key);if finite(value) or readable(value) and type(value)=='boolean' then return tostring(value) end;return 'unavailable' end
 local result='config='..(config==true and 'shown' or config==false and 'hidden' or 'unavailable')..' combat='..combat..' poll='..interval('poll')..' live='..interval('live_config_update')
 -- BEGIN CACHE MODE CONTEXT
 local mode=field(owner,'GetCacheDiagnosticMode')
 if type(mode)=='function' then
  local ok,loaded,requested,pending=pcall(mode,owner)
  local function known(value) return readable(value) and type(value)=='string' and (value=='cached' or value=='direct') end
  if ok and known(loaded) and known(requested) and readable(pending) and type(pending)=='boolean' then
   result=result..' observation-cache='..loaded..' requested='..requested..' reload='..tostring(pending)
  else result=result..' observation-cache=unavailable' end
 end
 return result
 -- END CACHE MODE CONTEXT
end
-- BEGIN STANDALONE PREVIEW CONTEXT
-- Canonical-slot observation only; this does not authenticate foreign frames.
local previewNumbers={[0]='0','1','2','3','4','5'}
local function standalonePreviewContext(owner)
 local ok,text=pcall(function()
  local selected,canonical=field(owner,'nextWindow'),field(owner,'nativePreviewWindow')
  if not readable(selected) then return 'selected=unavailable' end
  if selected==nil then return 'selected=none' end
  local marker=field(selected,'nativePreview')
  if not readable(canonical) or not readable(marker) then return 'selected=unavailable' end
  if type(selected)~='table' or not rawequal(selected,canonical) or marker~=true then return 'selected=custom' end
  local db=field(owner,'db');local profile=field(db,'profile');local frame=field(selected,'frame')
  local activeValue,count,slots,windowProfile=field(selected,'active'),field(selected,'count'),field(selected,'slots'),field(selected,'profile')
  local setting,generation=field(profile,'preview_spells'),field(selected,'generation')
  local capture=active
  local function current()
   return active==capture and rawequal(field(owner,'nextWindow'),selected) and rawequal(field(owner,'nativePreviewWindow'),canonical)
    and rawequal(field(owner,'db'),db) and rawequal(field(db,'profile'),profile) and rawequal(field(selected,'frame'),frame)
    and rawequal(field(selected,'nativePreview'),marker) and rawequal(field(selected,'active'),activeValue)
    and rawequal(field(selected,'count'),count) and rawequal(field(selected,'slots'),slots)
    and rawequal(field(selected,'profile'),windowProfile) and rawequal(field(profile,'preview_spells'),setting)
    and rawequal(field(selected,'generation'),generation)
  end
  local function number(value)
   if readable(value) and type(value)=='number' and value==value and value>=0 and value<=5 and value%1==0 then return previewNumbers[value] end
   return '?'
  end
  local function boolean(value)
   if readable(value) and type(value)=='boolean' then return value and '1' or '0' end
   return '?'
  end
  local shown='?'
  if readable(frame) and type(frame)=='table' then
   local valid,value=pcall(function()
    local method=frame.IsShown
    if readable(method) and type(method)=='function' and current() then return method(frame) end
   end)
   if valid then shown=boolean(value) end
  end
  local sameProfile='?'
  if readable(profile) and readable(windowProfile) and type(profile)=='table' and type(windowProfile)=='table' then
   sameProfile=rawequal(profile,windowProfile) and 'current' or 'different'
  end
  local result='selected=canonical shown='..shown..' active='..boolean(activeValue)..' setting='..number(setting)
   ..' slots='..number(slots)..' recommendations='..number(count)..' profile='..sameProfile
  -- A getter or visibility method may retire/rebind this surface mid-snapshot.
  if not current() then return 'selected=unavailable' end
  return result
 end)
 return ok and text or 'selected=unavailable'
end
local function appendStandalonePreviewContext(report,started,ended)
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local first='Standalone preview start: '..(started or 'selected=unavailable')
 local last='Standalone preview end: '..ended
 if bytes+1+#first+1+#last<16000 then report[#report+1]=first;report[#report+1]=last
 else
  local omitted='Standalone preview context omitted to keep report bounded.'
  if bytes+1+#omitted<16000 then report[#report+1]=omitted end
 end
end
-- END STANDALONE PREVIEW CONTEXT
local function reference(owner,...)
 local keys={...}
 return function() local value=owner;for _,key in ipairs(keys) do value=field(value,key) end;return value end
end
local function definitionsOf(owner) return field(owner,'conditionDefinitions') or field(owner,'definitions') end
local function conditionReference(owner,key,callback)
 return function() return field(field(definitionsOf(owner),key),callback) end
end
local function selectFunctions(owner)
 local rows,seen,validationRows={},{},{};local truncated=false
 local function add(container,key,label,resolve)
  local fn=field(container,key);if type(fn)~='function' then return end
  resolve=resolve or reference(container,key)
  local previous=seen[fn]
  if previous then previous.refs[#previous.refs+1]=resolve;return previous end
  if #rows>=MAX_FUNCTIONS then truncated=true;return end
  local row={fn=fn,label=label,refs={resolve}};seen[fn]=row;rows[#rows+1]=row;return row
 end
 for _,name in ipairs(runtimeNames) do add(owner,name,'Runtime.'..name) end
 for _,name in ipairs(platformNames) do add(field(owner,'Platform'),name,'Platform.'..name,reference(owner,'Platform',name)) end
 for _,entry in ipairs({{'RotationData','IndexRotationSteps'},{'RotationData','CheckPortable'},{'SpellCatalog','GetAllSpellIds'},{'SpellCatalog','GetSpellId'}}) do
  local row=add(field(owner,entry[1]),entry[2],entry[1]..'.'..entry[2],reference(owner,entry[1],entry[2]))
  if entry[2]=='IndexRotationSteps' then validationRows.IndexRotationSteps=row end
 end
 for _,name in ipairs({'ValidateEnvelope','ValidateBody'}) do validationRows[name]=add(field(owner,'RotationData'),name,'RotationData.'..name,reference(owner,'RotationData',name)) end
 local functions=field(owner,'Functions');local cache=field(functions,'cache');add(cache,'getCached','Functions.cache.getCached',reference(owner,'Functions','cache','getCached'));add(cache,'getRetryCached','Functions.cache.getRetryCached',reference(owner,'Functions','cache','getRetryCached'))
 local definitions=definitionsOf(owner);local catalog=field(field(owner,'BuiltinSourceCatalog'),'conditions');local keys={};local scanned=0
 if type(definitions)=='table' then for key in pairs(definitions) do
  scanned=scanned+1;if scanned>MAX_SCAN then truncated=true;break end
  if readable(key) and type(key)=='string' then keys[#keys+1]=key end
 end end
 table.sort(keys,function(a,b)
  local aBuiltin=type(field(catalog,a))=='table';local bBuiltin=type(field(catalog,b))=='table'
  if aBuiltin~=bBuiltin then return aBuiltin end;return a<b
 end)
 local custom=0
 for _,key in ipairs(keys) do
  local definition=field(definitions,key);local label
  if type(field(catalog,key))=='table' and #key<=64 and key:match('^[A-Z][A-Z_0-9]*$') then label='Condition.'..key
  else custom=custom+1;label='Condition.custom'..custom end
  add(definition,'evaluate',label..'.evaluate',conditionReference(owner,key,'evaluate'));add(definition,'valid',label..'.valid',conditionReference(owner,key,'valid'))
 end
 return rows,truncated,validationRows
end
-- BEGIN PRIVATE CACHE SAMPLES
local function cacheFunction(owner,alias)
 if proofType(cacheSourceModules)~='table' or proofType(cacheSourceGetter)~='function' then return nil,'source-reader-unavailable' end
 if not cacheSourceEqual(owner,addon) or not cacheSourceEqual(proofRawget(owner,'builtinSourceModules'),cacheSourceModules)
  or not cacheSourceEqual(proofRawget(cacheSourceModules,'Functions/cache.lua'),cacheSourceGetter) then return nil,'source-reader-changed' end
 local ok,fn=proofPcall(cacheSourceGetter,alias)
 if not ok then return nil,'source-reader-error' end
 if not readable(fn) or proofType(fn)~='function' then return nil,'invalid-source-function' end
 return fn
end
local function privateCacheSelection(owner,rows)
 local result={views={},samples={}};local seen={}
 for _,row in ipairs(rows) do seen[row.fn]=row end
 for _,alias in ipairs({'getCachedInternal','packResults'}) do
  local fn,reason=cacheFunction(owner,alias)
  local view={alias=alias,label='Functions.cache.'..alias,reason=reason};result.views[#result.views+1]=view
  if fn then
   local sample=seen[fn]
   if not sample then
    if #rows+#result.samples>=MAX_FUNCTIONS then view.reason='selection-limit'
    else sample={fn=fn};seen[fn]=sample;result.samples[#result.samples+1]=sample end
   end
   view.sample=sample
  end
 end
 return result
end
local function finishSample(run,row)
 if not row.sampled then row.sampled=true;row.current,row.currentReason=snapshot(run,row.fn) end
 return row.current,row.currentReason
end
local function appendPrivateCache(report,run)
 local lines={'Private cache helpers (native counters; shared functions overlap):'}
 local available=0
 for _,view in ipairs(run.privateCache.views) do
  local sample,problem=view.sample,view.reason
  if not problem then
   local fn;fn,problem=cacheFunction(run.owner,view.alias)
   if not problem and not cacheSourceEqual(fn,sample.fn) then problem='function-replaced' end
   problem=problem or sample.reason
  end
  local current
  if not problem then current,problem=finishSample(run,sample) end
  if not problem then
   for _,key in ipairs({'exclusive','inclusive','calls','inclusiveCalls'}) do if current[key]<sample.before[key] then problem='function-cpu-counter-reset';break end end
  end
  local exclusive,inclusive,calls
  if not problem then
   exclusive,inclusive,calls=current.exclusive-sample.before.exclusive,current.inclusive-sample.before.inclusive,current.calls-sample.before.calls
   if not finite(exclusive) or not finite(inclusive) or not counter(calls,true) then problem='invalid-function-cpu-delta' end
  end
  lines[#lines+1]=problem and view.label..' | unavailable: '..problem
   or string.format('%s | exclusive=%.3f ms | inclusive=%.3f ms | calls=%s',view.label,exclusive,inclusive,tostring(calls))
  if not problem then available=available+1 end
 end
 lines[#lines+1]=string.format('Private helper views: aliases=2; available=%d; unavailable=%d (excluded from rankings above).',available,2-available)
 lines[#lines+1]='Shared helper counters include all callers, including archived copies; inclusive costs overlap.'
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local extra=#lines;for _,line in ipairs(lines) do extra=extra+#line end
 if bytes+extra<16000 then for _,line in ipairs(lines) do report[#report+1]=line end
 else local omitted='Private cache helpers omitted to keep report bounded.';if bytes+1+#omitted<16000 then report[#report+1]=omitted end end
end
-- END PRIVATE CACHE SAMPLES
-- BEGIN CPU ACTIVITY DIAGNOSTICS
local activityProviders,activityFrame,activityAPI={},nil,nil
local activityEqual,activityCreate=rawequal,CreateFrame
function addon:BindCPUActivityDiagnostic(name,reader)
 if self~=addon or (name~='spell' and name~='item' and name~='visual') or proofType(reader)~='function' or activityProviders[name] then return false end
 activityProviders[name]=reader
 if activityProviders.spell and activityProviders.item and activityProviders.visual then addon.BindCPUActivityDiagnostic=nil end
 return true
end
local function activityRead()
 local result={}
 for _,name in ipairs({'spell','item','visual'}) do
  local reader=activityProviders[name]
  if reader then local ok,value=proofPcall(reader,activityAPI);if ok and proofType(value)=='table' then result[name]=value end end
 end
 return result
end
local function activityEvent(run,event,_,success)
 if not readable(success) or proofType(success)~='boolean' then run.activity.events.unknown=run.activity.events.unknown+1;return end
 if success then
  if event=='SPELL_DATA_LOAD_RESULT' then run.activity.events.spell=run.activity.events.spell+1
  elseif event=='ITEM_DATA_LOAD_RESULT' then run.activity.events.item=run.activity.events.item+1 end
 end
end
local function activityStop(run)
 local state=run.activity;if not state then return end
 if state.lease then state.lease.run=nil;state.lease=nil end
 local frame,api=state.frame,state.api;state.frame=nil;state.api=nil
 if frame and api then
  local ok,current=proofPcall(api.GetScript,frame,'OnEvent')
  local released=false
  if ok and activityEqual(current,state.handler) then
   local events=proofPcall(api.UnregisterAllEvents,frame);local handler=proofPcall(api.SetScript,frame,'OnEvent',nil);released=events and handler
  end
  if not released then
   state.events.available=false
   if activityEqual(activityFrame,frame) then activityFrame=nil;activityAPI=nil end
  end
 end
 state.handler=nil
end
local function activityStart(run)
 addon.BindCPUActivityDiagnostic=nil
 run.activity={events={spell=0,item=0,unknown=0,available=false},views={},samples={}}
 local state=run.activity
 if not activityFrame and proofType(activityCreate)=='function' then
  local ok,frame=proofPcall(activityCreate,'Frame')
  if ok and frame then
   local api={};local valid=true
   for _,name in ipairs({'GetScript','SetScript','RegisterEvent','UnregisterAllEvents','Hide','GetParent','IsVisible'}) do
    local method=frame[name];if proofType(method)~='function' then valid=false end;api[name]=method
   end
   if valid then activityFrame,activityAPI=frame,api;proofPcall(api.Hide,frame) end
  end
 end
 if activityFrame then
  state.frame=activityFrame;state.api=activityAPI
  local lease={run=run};state.lease=lease
  state.handler=function(_,event,...)
   local current=lease.run;if not current or active~=current then return end
   if not proofPcall(activityEvent,current,event,...) then current.activity.events.unknown=current.activity.events.unknown+1 end
  end
  local ok=proofPcall(function()
   activityAPI.SetScript(activityFrame,'OnEvent',state.handler)
   activityAPI.RegisterEvent(activityFrame,'SPELL_DATA_LOAD_RESULT');activityAPI.RegisterEvent(activityFrame,'ITEM_DATA_LOAD_RESULT')
  end)
  if ok then state.events.available=true else activityStop(run) end
 end
 state.started=activityRead()
 local seen,totalSamples={},#run.rows+#run.privateCache.samples
 for _,row in ipairs(run.rows) do seen[row.fn]=row end
 for _,row in ipairs(run.privateCache.samples) do seen[row.fn]=row end
 local visual=state.started.visual
 for _,name in ipairs({'overlay','pixel','autocast','blizzard'}) do
  local view={name=name};state.views[#state.views+1]=view
  local callbacks=field(visual,'callbacks');local ambiguous=field(visual,'ambiguous')
  local fn=field(callbacks,name)
  if field(ambiguous,name)==true then view.reason='ambiguous-callback'
  elseif proofType(fn)~='function' or not readable(fn) then view.reason='no-start-callback'
  else
   local sample=seen[fn]
   if not sample then
    if totalSamples>=MAX_FUNCTIONS then view.reason='selection-limit'
    else sample={fn=fn};seen[fn]=sample;totalSamples=totalSamples+1;state.samples[#state.samples+1]=sample;sample.before,sample.reason=snapshot(run,fn) end
   end
   view.sample=sample
  end
 end
end
local function appendActivity(report,run)
 local state=run.activity;if not state then return end
 local lines={'Retained catalogs and animation activity (capture only):'}
 local function retained(root,key)
  local object=field(root,key);local n=field(object,'n');local capped=field(object,'capped')
  if not counter(n,true) or n>4096 or proofType(capped)~='boolean' then return 'unavailable' end
  return (capped and '>=' or '')..tostring(n),not capped and n or nil
 end
 for _,entry in ipairs({{'spell','spellIDs','spell IDs'},{'spell','spellNames','spell name groups'},{'item','itemRecords','item records'},{'item','itemIndex','item index'},{'item','itemBlocked','blocked items'}}) do
  local start,before=retained(field(state.started,entry[1]),entry[2]);local ending,after=retained(field(state.ended,entry[1]),entry[2])
  lines[#lines+1]=entry[3]..': start='..start..'; end='..ending..'; change='..(before~=nil and after~=nil and tostring(after-before) or 'unavailable')
 end
 local events=state.events
 lines[#lines+1]=events.available and string.format('metadata successes: spell=%s; item=%s; unknown=%s',tostring(events.spell),tostring(events.item),tostring(events.unknown)) or 'metadata successes: unavailable'
 local function visual(label,value)
  if proofType(value)~='table' then return label..' visuals: unavailable' end
  local parts={label..' visuals:'}
  for _,key in ipairs({'buttons','slots','logical','overlays','sequence','pixel','autocast','blizzard','proc'}) do
   local n=field(value,key);parts[#parts+1]=key..'='..(counter(n,true) and n<=4096 and tostring(n) or 'unavailable')
  end
  parts[#parts+1]='capped='..(field(value,'capped')==true and 'true' or 'false')
  if field(value,'unsupported')==true then parts[#parts+1]='native-observation=unavailable' end
  return table.concat(parts,' ')
 end
 lines[#lines+1]=visual('start',field(state.started,'visual'));lines[#lines+1]=visual('end',field(state.ended,'visual'))
 local labels={overlay='RM.UpdateOverlay',pixel='SharedGlow.Pixel.OnUpdate',autocast='SharedGlow.AutoCast.OnUpdate',blizzard='SharedGlow.Blizzard.OnUpdate'}
 local available=0
 for _,view in ipairs(state.views) do
  local sample,problem=view.sample,view.reason
  if not field(state.ended,'visual') then problem=problem or 'source-reader-changed' end
  problem=problem or sample and sample.reason
  local current
  if not problem then current,problem=finishSample(run,sample) end
  if not problem then
   for _,key in ipairs({'exclusive','inclusive','calls','inclusiveCalls'}) do if current[key]<sample.before[key] then problem='function-cpu-counter-reset';break end end
  end
  local exclusive,inclusive,calls
  if not problem then
   exclusive,inclusive,calls=current.exclusive-sample.before.exclusive,current.inclusive-sample.before.inclusive,current.calls-sample.before.calls
   if not finite(exclusive) or not finite(inclusive) or not counter(calls,true) then problem='invalid-function-cpu-delta' end
  end
  lines[#lines+1]=problem and labels[view.name]..' | unavailable: '..problem or string.format('%s | exclusive=%.3f ms | inclusive=%.3f ms | calls=%s',labels[view.name],exclusive,inclusive,tostring(calls))
  if not problem then available=available+1 end
 end
 lines[#lines+1]=string.format('Animation views: aliases=4; available=%d; unavailable=%d (excluded from rankings above).',available,4-available)
 lines[#lines+1]='Catalog counts are keys, not bytes; global metadata arrivals may originate outside RM. Capped counts are lower bounds; sequence counts timer handles regardless of visibility, not measured executions.'
 lines[#lines+1]='Shared glow frames are associated with RM-active slots; shared callback counters include all callers. Start callbacks only; end-only callbacks lack a baseline. Proc uses native animations.'
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local extra=#lines;for _,line in ipairs(lines) do extra=extra+#line end
 if bytes+extra<16000 then for _,line in ipairs(lines) do report[#report+1]=line end
 else local omitted='Retained activity omitted to keep report bounded.';if bytes+1+#omitted<16000 then report[#report+1]=omitted end end
end
-- END CPU ACTIVITY DIAGNOSTICS
local function finish(run,status,reason)
 if active~=run then return end
 active=nil;run.timer=nil
 -- BEGIN CPU ACTIVITY STOP
 activityStop(run)
 -- END CPU ACTIVITY STOP
 local text
 if status=='complete' then
  local now,why=clock(run.clock);local elapsed=now and now-run.started
  if not elapsed or not finite(elapsed) or elapsed<=0 then status,reason='invalid',why or 'clock-reset' end
  if status=='complete' then
   local allowed,problem=enabled(run.cvar)
   if clockAPI()~=run.clock or cvarAPI()~=run.cvar or GetFunctionCPUUsage~=run.query or totalAPI()~=run.total or updateAPI()~=run.update then status,reason='invalid','profiling-api-changed'
   elseif not allowed then status,reason='invalid',problem end
  end
  local used,rate
  if status=='complete' then local value,problem=total(run);if value==nil or value<run.initialTotal then status,reason='invalid',problem or 'addon-cpu-counter-reset' else used=value-run.initialTotal;if not finite(used) then status,reason='invalid','invalid-addon-cpu-delta' end end end
  if status=='complete' then rate=used/elapsed;if not finite(rate) then status,reason='invalid','invalid-cpu-rate' end end
  if status=='complete' then
   -- BEGIN CPU ACTIVITY END
   if run.activity then run.activity.ended=activityRead() end
   -- END CPU ACTIVITY END
   local ranked,unavailable={},{}
   for _,row in ipairs(run.rows) do
    local problem=row.reason
    for _,ref in ipairs(row.refs) do if ref()~=row.fn then problem='function-replaced';break end end
    local current;if not problem then current,problem=finishSample(run,row) end
    if not problem then
     for _,key in ipairs({'exclusive','inclusive','calls','inclusiveCalls'}) do if current[key]<row.before[key] then problem='function-cpu-counter-reset';break end end
    end
    if not problem then
     local result={label=row.label,exclusive=current.exclusive-row.before.exclusive,inclusive=current.inclusive-row.before.inclusive,calls=current.calls-row.before.calls}
     if not finite(result.exclusive) or not finite(result.inclusive) or not counter(result.calls,true) then problem='invalid-function-cpu-delta' else ranked[#ranked+1]=result;row.deltaCalls=result.calls end
    end
    if problem then unavailable[#unavailable+1]={label=row.label,reason=problem} end
   end
   table.sort(ranked,function(a,b) if a.exclusive~=b.exclusive then return a.exclusive>b.exclusive end;if a.inclusive~=b.inclusive then return a.inclusive>b.inclusive end;return a.label<b.label end)
   local report={'Rotation Master CPU profile: complete',string.format('duration=%.3f s; addon CPU=%.3f ms; addon rate=%.3f ms/s',elapsed,used,rate),
    'start '..run.context,'end '..context(run.owner),'States describe capture boundaries only; activity may change within the interval.',
    'Native cumulative counters include collection and profiling overhead. Inclusive rows overlap and are not additive.',
    'Rows are selected coverage, not complete CPU accounting; addon and function snapshot boundaries differ slightly.',
    string.format('selected=%d; available=%d; unavailable=%d; top=%d%s',#run.rows,#ranked,#unavailable,math.min(TOP,#ranked),run.truncated and '; selection truncated' or '')}
   local function validationCount(name)
    local row=run.validationRows[name]
    return row and row.deltaCalls~=nil and tostring(row.deltaCalls) or 'unavailable'
   end
   report[#report+1]='Structural validation calls: ValidateEnvelope='..validationCount('ValidateEnvelope')..'; ValidateBody='..validationCount('ValidateBody')..' (native counters; shared functions overlap).'
   report[#report+1]='Execution indexing calls: IndexRotationSteps='..validationCount('IndexRotationSteps')..' (native counter).'
   for index=1,math.min(TOP,#ranked) do local row=ranked[index];local mean=row.calls>0 and row.exclusive/row.calls or nil
    report[#report+1]=string.format('%s | exclusive=%.3f ms | inclusive=%.3f ms | calls=%s | mean=%s ms',row.label,row.exclusive,row.inclusive,tostring(row.calls),mean and string.format('%.3f',mean) or 'unavailable')
   end
   for index=1,math.min(10,#unavailable) do local row=unavailable[index];report[#report+1]=row.label..' | unavailable: '..row.reason end
   if #unavailable>10 then report[#report+1]='Additional unavailable rows omitted.' end
   -- BEGIN INCLUSIVE CPU SCOPES
   -- Existing lines are complete before this second view of the same rows.
   local reportBytes=#report-1
   for _,line in ipairs(report) do reportBytes=reportBytes+#line end
   local title='Inclusive scopes (top 10; includes descendants; overlapping, not additive):'
   local omitted='Additional inclusive scopes omitted to keep report bounded.'
   if reportBytes+1+#title+1+#omitted<16000 then
    report[#report+1]=title;reportBytes=reportBytes+1+#title
    table.sort(ranked,function(a,b) if a.inclusive~=b.inclusive then return a.inclusive>b.inclusive end;if a.exclusive~=b.exclusive then return a.exclusive>b.exclusive end;return a.label<b.label end)
    for index=1,math.min(10,#ranked) do local row=ranked[index]
     local line=string.format('%s | inclusive=%.3f ms | exclusive=%.3f ms | calls=%s',row.label,row.inclusive,row.exclusive,tostring(row.calls))
     if reportBytes+1+#line+1+#omitted>=16000 then report[#report+1]=omitted;break end
     report[#report+1]=line;reportBytes=reportBytes+1+#line
    end
   end
   -- END INCLUSIVE CPU SCOPES
   -- BEGIN EXECUTION INDEX DIAGNOSTICS
   appendExecutionIndexProof(report,run.executionIndexProof,executionIndexProof())
   -- END EXECUTION INDEX DIAGNOSTICS
   -- BEGIN PRIVATE CACHE APPENDIX
   appendPrivateCache(report,run)
   -- END PRIVATE CACHE APPENDIX
   -- BEGIN CPU ACTIVITY APPENDIX
   appendActivity(report,run)
   -- END CPU ACTIVITY APPENDIX
   -- BEGIN STANDALONE PREVIEW APPENDIX
   appendStandalonePreviewContext(report,run.previewContext,standalonePreviewContext(run.owner))
   -- END STANDALONE PREVIEW APPENDIX
   text=table.concat(report,'\n')
  end
 end
 text=text or 'Rotation Master CPU profile: '..status..(reason and ' ('..reason..')' or '')
 lastReport=text
 local callback=field(run.owner,'OnCPUProfileFinished');if type(callback)=='function' then pcall(callback,run.owner,text,status) end
end
function addon:StartCPUProfile(duration)
 if active then return false,'already-running' end
 if duration==nil then duration=10 end
 if not finite(duration) or duration<1 or duration>60 then return false,'invalid-duration' end
 local cvar=cvarAPI();local allowed,reason=enabled(cvar);if not allowed then return false,reason end
 if type(GetFunctionCPUUsage)~='function' then return false,'missing-function-cpu-api' end
 if not totalAPI() or not updateAPI() then return false,'missing-addon-cpu-api' end
 if type(self.ScheduleTimer)~='function' or type(self.CancelTimer)~='function' then return false,'missing-timer-api' end
 local run={owner=self,query=GetFunctionCPUUsage,total=totalAPI(),update=updateAPI(),clock=clockAPI(),cvar=cvar,duration=duration,cancel=self.CancelTimer}
 run.started,reason=clock(run.clock);if run.started==nil then return false,reason end
 run.initialTotal,reason=total(run);if run.initialTotal==nil then return false,reason end
 run.rows,run.truncated,run.validationRows=selectFunctions(self);run.context=context(self)
 local available=0
 for _,row in ipairs(run.rows) do row.before,row.reason=snapshot(run,row.fn);if row.before then available=available+1 end end
 if available==0 then return false,'function-cpu-unavailable' end
 -- BEGIN PRIVATE CACHE START
 run.privateCache=privateCacheSelection(self,run.rows)
 for _,sample in ipairs(run.privateCache.samples) do sample.before,sample.reason=snapshot(run,sample.fn) end
 -- END PRIVATE CACHE START
 active=run
 -- BEGIN CPU ACTIVITY START
 local activityOK=proofPcall(activityStart,run)
 if not activityOK then activityStop(run);run.activity=nil end
 -- END CPU ACTIVITY START
 local ok,timer=pcall(self.ScheduleTimer,self,function() finish(run,'complete') end,duration)
 if not ok or not timer then if active==run then active=nil end;activityStop(run);return false,'timer-error' end
 run.timer=timer;if active==run then run.executionIndexProof=executionIndexProof() end;lastReport=nil
 -- BEGIN STANDALONE PREVIEW START
 if active==run then run.previewContext=standalonePreviewContext(self) end
 -- END STANDALONE PREVIEW START
 return true
end
function addon:CancelCPUProfile()
 local run=active;if not run then return false,'not-running' end
 if run.timer then pcall(run.cancel,run.owner,run.timer) end
 finish(run,'cancelled');return true
end
function addon:IsCPUProfileRunning() return active~=nil end
function addon:GetCPUProfileReport()
 if active then return string.format('Rotation Master CPU profile: running (requested %.3f s)',active.duration) end
 if lastReport then return lastReport end
 return nil,'not-captured'
end
-- AceAddon invokes this before AceTimer retires the addon's embedded timers.
-- The ordinary rotation enable/disable toggle remains independent of capture.
function addon:OnDisable()
 self:CancelCPUProfile()
end
]====],
}

local patches = {
    ["Core/rotation_references.lua"] = {
        {
            old = [====[]====],
            current = '\n'
                .. [====[-- BEGIN PRIVATE VALIDATION CPU HANDOFF
do
 local bind=addon.BindCPUValidationScopeDiagnostic
 if type(bind)=='function' then bind(addon,'references',ownedValidationStamp,function() return observe,sameEntries,sameItemsets,proofGlobals end) end
end
-- END PRIVATE VALIDATION CPU HANDOFF
]====],
        },
    },
    ["Core/rotation_library.lua"] = {
        {
            old = [====[]====],
            current = '\n'
                .. [====[-- BEGIN PRIVATE VALIDATION CPU HANDOFF
do
 local bind=addon.BindCPUValidationScopeDiagnostic
 if type(bind)=='function' then bind(addon,'library',ownedInitializeRotationLibrary,function() return ensure,eligible end) end
end
-- END PRIVATE VALIDATION CPU HANDOFF
]====],
        },
    },
    ["Core/rotation_scope.lua"] = {
        {
            old = [====[]====],
            current = '\n'
                .. [====[-- BEGIN PRIVATE VALIDATION CPU HANDOFF
do
 local bind=addon.BindCPUValidationScopeDiagnostic
 if type(bind)=='function' then bind(addon,'scope',addon.BindRotationProfile,function() return same end) end
end
-- END PRIVATE VALIDATION CPU HANDOFF
]====],
        },
    },
    ["Diagnostics/cpu.lua"] = {
        {
            old = [====[local function finishSample(run,row)
 if not row.sampled then row.sampled=true;row.current,row.currentReason=snapshot(run,row.fn) end
 return row.current,row.currentReason
end
]====],
            current = [====[-- BEGIN PRIVATE VALIDATION SCOPES
local validationEqual,validationSelect=rawequal,select
local validationSpecs={
 {name='references',anchor='GetRotationValidationStamp',slots={'observe','sameEntries','sameItemsets','proofGlobals'}},
 {name='library',anchor='InitializeRotationLibrary',slots={'ensure','eligible'}},
 {name='scope',anchor='BindRotationProfile',slots={'same'}},
}
local validationGroups,validationClosed,validationCount,validationCapture={},false,0,nil
local validationInstaller
local function validationRetire()
 validationClosed=true
 if validationEqual(proofRawget(addon,'BindCPUValidationScopeDiagnostic'),validationInstaller) then addon.BindCPUValidationScopeDiagnostic=nil end
end
validationInstaller=function(self,name,anchor,reader)
 if validationClosed or not validationEqual(self,addon) or proofType(name)~='string'
  or proofType(anchor)~='function' or proofType(reader)~='function' or validationGroups[name] then return false end
 local found
 for _,spec in ipairs(validationSpecs) do if name==spec.name then found=true;break end end
 if not found then return false end
 validationGroups[name]={anchor=anchor,reader=reader};validationCount=validationCount+1
 if validationCount==3 then validationRetire() end
 return true
end
addon.BindCPUValidationScopeDiagnostic=validationInstaller
local function validationClear(run)
 local state=run.validationScopes
 if state then state.phase='retired' end
 run.validationScopes=nil
 if validationCapture==run then validationCapture=nil end
end
local function validationEnding(run,status)
 if status~='complete' then validationClear(run)
 elseif run.validationScopes then run.validationScopes.phase='end' end
end
local function validationTuple(...) return {n=validationSelect('#',...),...} end
local function validationSnapshot(run,fn,current)
 if not current() then return nil,'capture-retired' end
 local ok,exclusive,calls=proofPcall(run.query,fn,false)
 if not current() then return nil,'capture-retired' end
 if not ok then return nil,'function-cpu-query-error' end
 if not counter(exclusive) or not counter(calls,true) then return nil,'invalid-function-cpu-counter' end
 if not current() then return nil,'capture-retired' end
 local good,inclusive,inclusiveCalls=proofPcall(run.query,fn,true)
 if not current() then return nil,'capture-retired' end
 if not good then return nil,'function-cpu-query-error' end
 if not counter(inclusive) or not counter(inclusiveCalls,true) then return nil,'invalid-function-cpu-counter' end
 if not current() then return nil,'capture-retired' end
 return {exclusive=exclusive,inclusive=inclusive,calls=calls,inclusiveCalls=inclusiveCalls}
end
local function validationFunctions(run,spec,group,current)
 if not current() then return nil,'capture-retired' end
 if not validationEqual(run.owner,addon) then return nil,'owner-changed' end
 if not group then return nil,'unbound' end
 local anchor=proofRawget(addon,spec.anchor)
 if not readable(anchor) or not validationEqual(anchor,group.anchor) then return nil,'owner-changed' end
 if not current() then return nil,'capture-retired' end
 local values=validationTuple(proofPcall(group.reader))
 if not current() then return nil,'capture-retired' end
 if not values[1] then return nil,'provider-unavailable' end
 if values.n~=#spec.slots+1 then return nil,'invalid-source-function' end
 for i=1,#spec.slots do
  local fn=values[i+1]
  if not readable(fn) or proofType(fn)~='function' then return nil,'invalid-source-function' end
 end
 anchor=proofRawget(addon,spec.anchor)
 if not readable(anchor) or not validationEqual(anchor,group.anchor) then return nil,'owner-changed' end
 if not current() then return nil,'capture-retired' end
 return values
end
local function validationStart(run)
 if active~=run then return end
 local state={phase='start',views={},samples={},groups={}}
 run.validationScopes=state;validationCapture=run
 state.current=function()
  return validationCapture==run and run.validationScopes==state
   and (state.phase=='start' and active==run or state.phase=='end' and active==nil)
 end
 local seen,total={},0
 local function remember(row) if not seen[row.fn] then seen[row.fn]=row;total=total+1 end end
 for _,row in ipairs(run.rows) do remember(row) end
 for _,row in ipairs(run.privateCache.samples) do remember(row) end
 for _,row in ipairs(run.activity and run.activity.samples or {}) do remember(row) end
 for _,spec in ipairs(validationSpecs) do
  local group=validationGroups[spec.name];local funcs,reason=validationFunctions(run,spec,group,state.current)
  local source={spec=spec,group=group};state.groups[#state.groups+1]=source
  for i,name in ipairs(spec.slots) do
   local view={label='Validation.'..spec.name..'.'..name,group=source,slot=i,reason=reason};state.views[#state.views+1]=view
   if funcs then
    local fn=funcs[i+1];view.fn=fn
    local sample=seen[fn]
    if not sample then
     if total>=MAX_FUNCTIONS then view.reason='selection-limit'
     else
      sample={fn=fn};seen[fn]=sample;total=total+1;state.samples[#state.samples+1]=sample
      sample.before,sample.reason=validationSnapshot(run,fn,state.current)
     end
    end
    view.sample=sample
   end
  end
 end
end
local function appendValidationScopes(report,run,sampleEnd)
 local state=run.validationScopes
 local lines={'Private validation scopes (native counters; shared functions overlap):'};local available=0
 if state then
  for _,source in ipairs(state.groups) do source.functions,source.reason=validationFunctions(run,source.spec,source.group,state.current) end
 end
 local index=0
 for _,spec in ipairs(validationSpecs) do for _,name in ipairs(spec.slots) do
  index=index+1;local view=state and state.views[index];local problem
  if view then problem=view.reason else problem='baseline-unavailable' end
  local sample,current
  if view and not problem then
   local source=view.group;problem=source.reason
   if not problem and not validationEqual(source.functions[view.slot+1],view.fn) then problem='function-replaced' end
   sample=view.sample;problem=problem or sample.reason
   if not problem then current,problem=sampleEnd(run,sample,state.current) end
   if not problem then
    for _,key in ipairs({'exclusive','inclusive','calls','inclusiveCalls'}) do if current[key]<sample.before[key] then problem='function-cpu-counter-reset';break end end
   end
  end
  local exclusive,inclusive,calls
  if not problem then
   exclusive,inclusive,calls=current.exclusive-sample.before.exclusive,current.inclusive-sample.before.inclusive,current.calls-sample.before.calls
   if not finite(exclusive) or not finite(inclusive) or not counter(calls,true) then problem='invalid-function-cpu-delta' end
  end
  local label='Validation.'..spec.name..'.'..name
  lines[#lines+1]=problem and label..' | unavailable: '..problem
   or string.format('%s | exclusive=%.3f ms | inclusive=%.3f ms | calls=%s',label,exclusive,inclusive,tostring(calls))
  if not problem then available=available+1 end
 end end
 lines[#lines+1]=string.format('Fixed validation views: aliases=7; available=%d; unavailable=%d (excluded from rankings above).',available,7-available)
 lines[#lines+1]='Shared helper counters include all callers; inclusive scopes overlap, not additive.'
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local extra=#lines;for _,line in ipairs(lines) do extra=extra+#line end
 if bytes+extra<16000 then for _,line in ipairs(lines) do report[#report+1]=line end
 else local omitted='Private validation scopes omitted to keep report bounded.';if bytes+1+#omitted<16000 then report[#report+1]=omitted end end
end
-- END PRIVATE VALIDATION SCOPES
local function finishSample(run,row,guard)
 if not row.sampled then
  row.sampled=true
  if guard then row.current,row.currentReason=validationSnapshot(run,row.fn,guard)
  else row.current,row.currentReason=snapshot(run,row.fn) end
 end
 return row.current,row.currentReason
end
]====],
        },
        {
            old = [====[ if active~=run then return end
 active=nil;run.timer=nil]====],
            current = [====[ if active~=run then return end
 -- BEGIN PRIVATE VALIDATION END TOKEN
 validationEnding(run,status)
 -- END PRIVATE VALIDATION END TOKEN
 active=nil;run.timer=nil]====],
        },
        {
            old = [====[   text=table.concat(report,'\n')]====],
            current = [====[   -- BEGIN PRIVATE VALIDATION APPENDIX
   local validationState=run.validationScopes
   local validationEntered=validationState and validationState.current()
   appendValidationScopes(report,run,finishSample)
   if validationEntered and not validationState.current() then validationClear(run);return end
   -- END PRIVATE VALIDATION APPENDIX
   text=table.concat(report,'\n')]====],
        },
        {
            old = [====[ lastReport=text
 local callback=]====],
            current = [====[ -- BEGIN PRIVATE VALIDATION CLEANUP
 validationClear(run)
 -- END PRIVATE VALIDATION CLEANUP
 lastReport=text
 local callback=]====],
        },
        {
            old = [====[function addon:StartCPUProfile(duration)
]====],
            current = [====[function addon:StartCPUProfile(duration)
 -- BEGIN PRIVATE VALIDATION RETIRE
 validationRetire()
 -- END PRIVATE VALIDATION RETIRE
]====],
        },
        {
            old = [====[ -- END CPU ACTIVITY START
 local ok,timer=]====],
            current = [====[ -- END CPU ACTIVITY START
 -- BEGIN PRIVATE VALIDATION START
 local validationEntered=active==run
 validationStart(run)
 if validationEntered and active~=run then validationClear(run);return true end
 -- END PRIVATE VALIDATION START
 local ok,timer=]====],
        },
        {
            old = [====[ if not ok or not timer then if active==run then active=nil end;activityStop(run);return false,'timer-error' end]====],
            current = [====[ -- BEGIN PRIVATE VALIDATION TIMER FAILURE
 if not ok or not timer then validationClear(run) end
 -- END PRIVATE VALIDATION TIMER FAILURE
 if not ok or not timer then if active==run then active=nil end;activityStop(run);return false,'timer-error' end]====],
        },
    },
}

return function(text, path, baseline)
    local old = assert(records[path], "unknown validation-scope module")

    if baseline then
        assert(text == nil)
        return old
    end

    assert(type(text) == "string")

    if path == 'Diagnostics/cpu.lua' then
        text = dofile('tests/fixtures/restore_cpu_work_views.lua')(text, path)
    end

    for _, patch in ipairs(patches[path]) do
        local first, last = text:find(patch.current, 1, true)
        assert(first, "exact validation-scope block missing")
        assert(not text:find(patch.current, last + 1, true), "validation-scope block repeated")
        text = text:sub(1, first - 1) .. patch.old .. text:sub(last + 1)
    end

    assert(text == old, "module changed outside private validation scopes")
    return old
end
