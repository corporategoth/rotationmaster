local _,addon=...
local readExecutionGeneration
---@type fun(...): any
local bindExecutionGeneration=addon.BindRotationExecutionGeneration
if type(bindExecutionGeneration)=='function' then
    bindExecutionGeneration(addon,function(read)readExecutionGeneration=read end)
end
local kind,raw,identity=type,rawget,rawequal
local sourcePairs,sourceIpairs=pairs,ipairs
---@type fun(f: number|function): table
local environment=getfenv
local source,readActive,dispatch,dispatchEnvironment
---@type fun(...): any
local bind=addon.BindScopedActiveRuntimePlan
if kind(bind)=='function' then bind(addon,function(value,read)source,readActive=value,read end);addon.BindScopedActiveRuntimePlan=nil end
---@type fun(...): any, any
local consume=addon.ConsumeAnnouncementRuntimeSource
if kind(consume)=='function' then dispatch,dispatchEnvironment=consume(addon);addon.ConsumeAnnouncementRuntimeSource=nil end
local glowCooldown,presentationEnvironment
-- buttons.lua consumes this receiver before its library callbacks, then sends
-- the literal method immediately after definition. Never recapture a live field.
function addon:BindActiveRuntimePresentationSource(method,env)
    if self~=addon or glowCooldown~=nil or kind(method)~='function' or kind(env)~='table' then return end
    glowCooldown,presentationEnvironment=method,env
end
local spellIDs,sequence,mainEnvironment,registered
local request,plan,planGeneration
local plansBuilt,reused,declined,currentRoute=0,0,0,'idle'
local function consumers(owner)
    return registered and identity(owner,addon)
        and kind(environment)=='function' and kind(dispatch)=='function' and kind(dispatchEnvironment)=='table'
        and kind(glowCooldown)=='function' and identity(raw(owner,'GlowCooldown'),glowCooldown)
        and identity(environment(glowCooldown),presentationEnvironment)
        and identity(raw(owner,'GetSpellIds'),spellIDs) and identity(raw(owner,'EvaluateRotationSequence'),sequence)
        and identity(raw(owner,'DispatchAnnouncement'),dispatch)
        and identity(environment(spellIDs),mainEnvironment) and identity(environment(sequence),mainEnvironment)
        and identity(environment(dispatch),dispatchEnvironment)
end
local function register(owner,ids,run,env)
    if registered or owner~=addon or kind(ids)~='function' or kind(run)~='function' or kind(env)~='table' then return end
    spellIDs,sequence,mainEnvironment,registered=ids,run,env,true
    return true
end
local function retired() return false end
local function acquire(owner,spec,key)
    if owner~=addon then return nil,nil,nil,false end
    if not identity(raw(owner,'currentSpec'),spec) or not identity(raw(owner,'currentRotation'),key) then declined=declined+1;currentRoute='retired';return nil,retired,nil,true end
    local db=raw(owner,'db');local profile=kind(db)=='table' and raw(db,'profile')
    local ticket={};request=ticket
    local handle,revision,operation
    if kind(readActive)=='function' then handle,revision,operation=readActive(owner,spec,key) end
    local function requestCurrent()
        if not identity(request,ticket) then return false end
        if not handle then return true end
        local nextHandle,nextRevision,nextOperation=readActive(owner,spec,key)
        return identity(nextHandle,handle) and nextRevision==revision and identity(nextOperation,operation)
    end
    if not consumers(owner) or kind(source)~='function' then plan=nil;planGeneration=nil;declined=declined+1;currentRoute='fallback';return nil,nil,nil,false end
    local built=false
    -- A completed entry proof qualifies only this exact cached plan at this
    -- notification generation. Fresh context/eligibility still ends in a full
    -- proof below, so raw root changes cannot return an old private body.
    local authoritative=plan and (planGeneration~=nil and planGeneration==readExecutionGeneration() or plan.authority())
    if not requestCurrent() then declined=declined+1;currentRoute='retired';return nil,retired,nil,true end
    if not authoritative then
        local prepared=source(owner,spec,key)
        if prepared then plansBuilt=plansBuilt+1;built=true end
        if not requestCurrent() then declined=declined+1;currentRoute='retired';return nil,retired,nil,true end
        plan=prepared;planGeneration=nil
    end
    if not plan or not consumers(owner) then plan=nil;planGeneration=nil;declined=declined+1;currentRoute='fallback';return nil,nil,nil,false end
    -- entry's final source-owned proof covers context and eligibility work.
    -- Capture before those callbacks: never refresh an older request to a
    -- generation published by reentrant work during preparation.
    local executionGeneration=readExecutionGeneration and readExecutionGeneration()
    local selected=plan;local state=selected.entry()
    if not requestCurrent() or executionGeneration==nil or readExecutionGeneration()~=executionGeneration then declined=declined+1;currentRoute='retired';return nil,retired,nil,true end
    if not state then plan=nil;planGeneration=nil;declined=declined+1;currentRoute='fallback';return nil,nil,nil,false end
    -- Publish before late consumer source getters: a notification during those
    -- callouts must never bless an old plan with a newer generation.
    planGeneration=executionGeneration
    local function continuationCurrent()
        return request==ticket and plan==selected and readExecutionGeneration()==executionGeneration
            and raw(owner,'db')==db and kind(db)=='table' and raw(db,'profile')==profile
            and identity(raw(owner,'currentSpec'),spec) and identity(raw(owner,'currentRotation'),key)
    end
    local function current()
        if not continuationCurrent() or not consumers(owner) or not continuationCurrent() then return false end
        -- Scope's full proof ends with one callback-free active snapshot. Use
        -- it for both request and scope authority, then reject late reentry.
        local valid,activeHandle,activeRevision,activeOperation=selected.current(state)
        return continuationCurrent() and valid and identity(activeHandle,handle)
            and activeRevision==revision and identity(activeOperation,operation)
    end
    if not identity(plan,selected) or not consumers(owner) then declined=declined+1;currentRoute='retired';return nil,current,nil,true end
    if not built then reused=reused+1 end
    currentRoute=state.allowed and 'managed' or 'unavailable'
    local function conditionCurrent()
        return identity(request,ticket) and identity(plan,selected) and consumers(owner) and selected.conditionCurrent(state)
    end
    local function notifiedCurrent()
        return executionGeneration~=nil and request==ticket and plan==selected
            and readExecutionGeneration()==executionGeneration
    end
    local function deliveryCurrent()
        -- Completed scalar/detached output follows the managed mutation clock.
        -- Raw profile/spec/selection remain immediate ownership boundaries;
        -- unnotified table edits are re-proved by the next full acquisition.
        if not continuationCurrent()then return false end
        if not identity(raw(owner,'GlowCooldown'),glowCooldown)
            or not identity(environment(glowCooldown),presentationEnvironment)then return false end
        return continuationCurrent()and identity(raw(owner,'GlowCooldown'),glowCooldown)
    end
    local dispatchFailed=false
    local function dispatchCurrent(receiver)
        if dispatchFailed then return false end
        -- These scalar ownership checks have no source lookup or callout.
        -- The graph retains its actual provider certificates at private handoff.
        if receiver=='condition' or receiver=='resume' then
            local valid=continuationCurrent()
            if not valid then dispatchFailed=true end
            return valid
        end
        if not continuationCurrent() then dispatchFailed=true;return false end
        local valid=true
        if receiver=='step' then
            valid=identity(raw(owner,'GetSpellIds'),spellIDs) and identity(environment(spellIDs),mainEnvironment)
                and identity(raw(owner,'GetSpellIds'),spellIDs)
                and identity(raw(mainEnvironment,'type'),kind) and identity(raw(mainEnvironment,'ipairs'),sourceIpairs)
        elseif receiver=='sequence' or receiver=='iterator' or receiver=='pathcopy' then
            valid=identity(raw(owner,'EvaluateRotationSequence'),sequence) and identity(environment(sequence),mainEnvironment)
                and identity(raw(owner,'EvaluateRotationSequence'),sequence)
                and identity(raw(mainEnvironment,'type'),kind) and identity(raw(mainEnvironment,'ipairs'),sourceIpairs)
                and (receiver~='iterator' or identity(raw(mainEnvironment,'pairs'),sourcePairs))
        end
        valid=valid and selected.executionSource(receiver) and continuationCurrent()
        if not valid then dispatchFailed=true end
        return valid
    end
    return state.allowed and selected.body or nil,current,selected.token,true,selected.presentation,conditionCurrent,notifiedCurrent,deliveryCurrent,dispatchCurrent
end
function addon:ConsumeActiveRuntimePlan()
    if self~=addon then return end
    return acquire,register
end

-- Scalar snapshots only; collection does not prepare or inspect a plan.
function addon:GetActiveRuntimePlanDiagnostic()
    if self~=addon then return end
    return {plansBuilt=plansBuilt,reused=reused,declined=declined,currentRoute=currentRoute}
end
