-- Exact event-context stage inverse before historical complete-source proofs.
local rows={
['Core/rotation_scope.lua']={bytes=63157,hash='0473c689',oldBytes=60973,oldHash='af6f6739',changes={{current=[====[
local libraryReader,libraryGenerationProof,libraryContextProof,libraryRuntimeContextGuard
local evaluationRequest,contextVersion
contextVersion={}
local ownedRuntimePasses=setmetatable({},{__mode="kv"})
]====],previous=[====[
local libraryReader,libraryGenerationProof,libraryContextProof
]====]},
{current=[====[
    bindLibrary(addon,function(reader,proof,contextProof,runtimeGuard) libraryRuntimeContextGuard=runtimeGuard;libraryReader=reader;if type(proof)=='function' then libraryGenerationProof=proof end;if type(contextProof)=='function'then libraryContextProof=contextProof end end)
]====],previous=[====[
    bindLibrary(addon,function(reader,proof,contextProof) libraryReader=reader;if type(proof)=='function' then libraryGenerationProof=proof end;if type(contextProof)=='function'then libraryContextProof=contextProof end end)
]====]},
{current=[====[
        local request=evaluationRequest;evaluationRequest=nil
        local version=contextVersion
]====],previous=[====[
]====]},
{current=[====[
        local observedPrivate,observedMethod
]====],previous=[====[
]====]},
{current=[====[
            if libraryContextProof and libraryContextProof(method,eligibilityContext,rotationContext)and private==true then observedPrivate,observedMethod=true,method;return value end
            observedPrivate=false
]====],previous=[====[
            if libraryContextProof and libraryContextProof(method,eligibilityContext,rotationContext)and private==true then return value end
]====]},
{current=[====[
        local contextGuard=request and observedPrivate and libraryRuntimeContextGuard
            and libraryRuntimeContextGuard(observedContext,observedMethod,eligibilityContext,rotationContext)
]====],previous=[====[
]====]},
{current=[====[
            if request and version~=contextVersion then return nil,'rotation-context-changed' end
            if contextGuard then
                local unchanged=contextGuard()
                if request and version~=contextVersion then return nil,'rotation-context-changed' end
                if unchanged==false then return nil,'rotation-context-changed' end
                if unchanged==nil then contextGuard=nil end
            end
            if not contextGuard and not same(observedContext,eligibilityContext()) then return nil,'rotation-context-changed' end
]====],previous=[====[
            if not same(observedContext,eligibilityContext()) then return nil,'rotation-context-changed' end
]====]},
{current=[====[
    ownedRuntimePasses[coordinator]=coordinator.RuntimePass
]====],previous=[====[
]====]},
{current=[====[


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
        local previous=evaluationRequest;evaluationRequest={}
        local ok,pass,reason=protect(ownedAcquireRuntimePass,owner,spec)
        evaluationRequest=previous
        if not ok then raise(pass,0) end
        return pass,reason
    end,function() contextVersion={} end)
    return true
end
]====],previous=[====[
]====]}}},
['Core/rotation_library.lua']={bytes=44694,hash='858703e0',oldBytes=41871,oldHash='5dd9f2e4',changes={{current=[====[
local ownedReadValue=addon.Platform.CanReadValue
]====],previous=[====[
]====]},
{current=[====[
local contextPairs=pairs
]====],previous=[====[
]====]},
{current=[====[
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
]====],previous=[====[
]====]},
{current=[====[
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
]====],previous=[====[
]====]},
{current=[====[
    bind(reader,provesGeneration,ownsPrivateContext,runtimeContextGuard);return true
]====],previous=[====[
    bind(reader,provesGeneration,ownsPrivateContext);return true
]====]}}},
['main.lua']={bytes=85546,hash='d64c4f0b',oldBytes=84322,oldHash='6c5a80f6',changes={{current=[====[
local acquireEvaluationPass,invalidateEvaluationContext
local bindEvaluationContext=addon.BindRuntimeEvaluationContext
if type(bindEvaluationContext)=='function' then
    bindEvaluationContext(addon,function(acquire,invalidate) acquireEvaluationPass,invalidateEvaluationContext=acquire,invalidate end)
    addon.BindRuntimeEvaluationContext=nil
end
]====],previous=[====[
]====]},
{current=[====[
            if acquireEvaluationPass then runtimePass=acquireEvaluationPass(self,selectedSpec)
            else runtimePass=self:AcquireRotationRuntimePass(selectedSpec) end
]====],previous=[====[
            runtimePass=self:AcquireRotationRuntimePass(selectedSpec)
]====]},
{current=[====[
-- These notifications may change eligibility facts or their readability. Other
-- event handlers do not invalidate a snapshot of player/session eligibility.
local runtimeContextEvents={PLAYER_LEVEL_UP=true,UNIT_LEVEL=true,PLAYER_ENTERING_WORLD=true,PLAYER_LEAVING_WORLD=true,
    PLAYER_SPECIALIZATION_CHANGED=true,PLAYER_TALENT_UPDATE=true,ACTIVE_TALENT_GROUP_CHANGED=true,
    CHARACTER_POINTS_CHANGED=true,SPELLS_CHANGED=true,PLAYER_CONTROL_GAINED=true,PLAYER_CONTROL_LOST=true,
    UPDATE_SHAPESHIFT_FORM=true,VEHICLE_UPDATE=true,UNIT_ENTERED_VEHICLE=true,UNIT_EXITED_VEHICLE=true,
    PLAYER_REGEN_ENABLED=true,PLAYER_REGEN_DISABLED=true}
]====],previous=[====[
]====]},
{current=[====[
        if invalidateEvaluationContext and (event==nil or runtimeContextEvents[event]) then invalidateEvaluationContext() end
]====],previous=[====[
]====]}}}}
local function hash(s)local n=5381;for i=1,#s do n=(n*33+s:byte(i))%4294967296 end;return string.format('%08x',n)end
return function(text,path)
 local r=rows[path];if not r then return text end
 assert(#text==r.bytes and hash(text)==r.hash,'unrelated event-context source: '..path)
 for _,c in ipairs(r.changes)do local a,b=text:find(c.current,1,true);assert(a and not text:find(c.current,b+1,true),'event inverse anchor: '..path);text=text:sub(1,a-1)..c.previous..text:sub(b+1)end
 assert(#text==r.oldBytes and hash(text)==r.oldHash,'event inverse predecessor: '..path);return text
end
