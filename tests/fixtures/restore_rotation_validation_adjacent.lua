-- Strict inverse of only the private adjacent validation observation protocol.
local changes={
 ["Core/rotation_references.lua"]={
  {[==[local _,addon=...
local observed,stamp
-- Trusted standard primitives at module load; changed live pointers disable reuse.
local proofPairs,proofRawget,proofRawequal,proofType,proofGetmetatable=pairs,rawget,rawequal,type,getmetatable
-- Lua5.1 accepts a stack level or function; the checker declares only levels.
---@type fun(f: number|function): table
local proofGetfenv=getfenv
local proofEnvironment=proofType(proofGetfenv)=='function' and proofGetfenv(1) or nil
local function normalized(value)
    return type(value)=='table' and value or false
]==],[==[local _,addon=...
local observed,stamp
local function normalized(value)
    return type(value)=='table' and value or false
]==]},
  {[==[    return stamp
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
]==],[==[    return stamp
end
-- Dependency maps may carry AceDB defaults metatables. Observe their entries,
-- without copying/traversing definitions or writing into SavedVariables.
]==]},
 },
 ["Core/rotation_library.lua"]={
  {[==[local definitions, definitionVersion = {}, 0
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
]==],[==[local definitions, definitionVersion = {}, 0
local active

local function contains(list, value)
]==]},
  {[==[    return true
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
]==],[==[    return true
end
local function ensure(self)
    local referenceStamp=self:GetRotationValidationStamp()
    if not active or active.profile~=self.db.profile or active.state~=self.db.profile.rotationLibrary
        or active.version~=definitionVersion or active.referenceStamp~=referenceStamp then return self:InitializeRotationLibrary() end
    return true
end
]==]},
  {[==[    function reader:OwnsContext(fn) return fn==ownedRotationContext end
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
]==],[==[    function reader:OwnsContext(fn) return fn==ownedRotationContext end
    function reader:Context(spec) return rotationContext(owner,spec) end
    function reader:Generation() local ok,why=ensure(owner);if not ok then return nil,why end;return active.generation end
    function reader:Read(spec,id,project,candidates)
        local ok,why=ensure(owner);if not ok then return nil,why end
]==]},
  {[==[    function reader:Eligible(view,spec,candidates) local context=rotationContext(owner,spec);context.spec=spec;return eligible(view,context,candidates) end
    function reader:Reserve(used) for id,envelope in pairs(definitions) do used[id]=true;data.ReserveRotationIdentities(envelope,used) end end
    bind(reader,provesGeneration);return true
end

]==],[==[    function reader:Eligible(view,spec,candidates) local context=rotationContext(owner,spec);context.spec=spec;return eligible(view,context,candidates) end
    function reader:Reserve(used) for id,envelope in pairs(definitions) do used[id]=true;data.ReserveRotationIdentities(envelope,used) end end
    bind(reader);return true
end

]==]},
 },
 ["Core/rotation_scope.lua"]={
  {[==[local data=addon.RotationData
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local libraryReader,libraryGenerationProof
local bindLibrary=addon.BindRotationLibraryReader
if type(bindLibrary)=='function' then
    bindLibrary(addon,function(reader,proof) libraryReader=reader;if type(proof)=='function' then libraryGenerationProof=proof end end)
    addon.BindRotationLibraryReader=nil
end
local function rotationContext(owner,spec)
    local method=libraryReader and libraryReader.Context
]==],[==[local data=addon.RotationData
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local libraryReader
local bindLibrary=addon.BindRotationLibraryReader
if type(bindLibrary)=='function' then bindLibrary(addon,function(reader) libraryReader=reader end);addon.BindRotationLibraryReader=nil end
local function rotationContext(owner,spec)
    local method=libraryReader and libraryReader.Context
]==]},
  {[==[            local now=context();if not now or not same(now,c) then return nil,'rotation-owner-changed' end
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
]==],[==[            local now=context();if not now or not same(now,c) then return nil,'rotation-owner-changed' end
            if not same(observedContext,eligibilityContext()) then return nil,'rotation-context-changed' end
            if libraryReader and libraryReader:Generation()~=generation then return nil,'rotation-library-changed' end
            local stamp=owner:GetRotationValidationStamp();if stamp~=referenceStamp or owner.conditionRegistryVersion~=revision then return nil,'rotation-dependencies-changed' end
            return true
        end
]==]},
 },
}
local hashes={["Core/rotation_references.lua"]="ed72c190",["Core/rotation_library.lua"]="051d323c",["Core/rotation_scope.lua"]="9aeff4f1"}
return function(text,path,hash)
 assert(type(text)=='string' and type(hash)=='function' and changes[path],'unknown adjacent validation inverse input')
 for _,entry in ipairs(changes[path]) do
  local first,last=text:find(entry[1],1,true)
  assert(first and not text:find(entry[1],last+1,true),'unexpected adjacent validation protocol count or body')
  text=text:sub(1,first-1)..entry[2]..text:sub(last+1)
 end
 assert(hash(text)==hashes[path],'module differs beyond the approved adjacent validation protocol')
 return text
end
