local _,addon=...
local readExecutionGeneration
---@type fun(...): any
local bindExecutionGeneration=addon.BindRotationExecutionGeneration
if type(bindExecutionGeneration)=='function' then
    bindExecutionGeneration(addon,function(read)readExecutionGeneration=read end)
end
local kind,raw,identity=type,rawget,rawequal
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
local request,plan
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
    local ticket={};request=ticket
    local handle,revision,operation
    if kind(readActive)=='function' then handle,revision,operation=readActive(owner,spec,key) end
    local function requestCurrent()
        if not identity(request,ticket) then return false end
        if not handle then return true end
        local nextHandle,nextRevision,nextOperation=readActive(owner,spec,key)
        return identity(nextHandle,handle) and nextRevision==revision and identity(nextOperation,operation)
    end
    if not consumers(owner) or kind(source)~='function' then plan=nil;declined=declined+1;currentRoute='fallback';return nil,nil,nil,false end
    local built=false
    local authoritative=plan and plan.authority()
    if not requestCurrent() then declined=declined+1;currentRoute='retired';return nil,retired,nil,true end
    if not authoritative then
        local prepared=source(owner,spec,key)
        if prepared then plansBuilt=plansBuilt+1;built=true end
        if not requestCurrent() then declined=declined+1;currentRoute='retired';return nil,retired,nil,true end
        plan=prepared
    end
    if not plan or not consumers(owner) then plan=nil;declined=declined+1;currentRoute='fallback';return nil,nil,nil,false end
    local selected=plan;local state=selected.entry()
    if not requestCurrent() then declined=declined+1;currentRoute='retired';return nil,retired,nil,true end
    if not state then plan=nil;declined=declined+1;currentRoute='fallback';return nil,nil,nil,false end
    local function current()
        return requestCurrent() and identity(plan,selected) and consumers(owner) and selected.current(state)
    end
    if not current() then declined=declined+1;currentRoute='retired';return nil,current,nil,true end
    if not built then reused=reused+1 end
    currentRoute=state.allowed and 'managed' or 'unavailable'
    local function conditionCurrent()
        return identity(request,ticket) and identity(plan,selected) and consumers(owner) and selected.conditionCurrent(state)
    end
    local executionGeneration=readExecutionGeneration and readExecutionGeneration()
    local function notifiedCurrent()
        return executionGeneration~=nil and request==ticket and plan==selected
            and readExecutionGeneration()==executionGeneration
    end
    return state.allowed and selected.body or nil,current,selected.token,true,selected.presentation,conditionCurrent,notifiedCurrent
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
