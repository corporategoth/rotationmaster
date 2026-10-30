-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- QA only: exact private-index successor to its deployed b55 predecessor.
local before = [======[local _,addon=...
local data=addon.RotationData
local function unavailable(diagnostic)
    return {status="unavailable",suppressAttack=true,diagnostic=diagnostic}
end
local function execute(body,evaluate,visit,rows,ordinal,kind,each,managed)
    local result={status="complete",suppressAttack=false,fallbackOrdinal=ordinal+1}
    local function permitted(receiver)
        if managed(receiver) then return true end
        result.status="unavailable";result.suppressAttack=true;return false
    end
    local function check(step,row)
        local observation
        if managed then
            if not permitted('pathcopy') then return "unavailable" end
            local conditions,stepId=step.conditions,step.id
            local path=data.CopyData(row.path)
            observation=evaluate(conditions,{stepId=stepId,stepPath=path})
            if not permitted('resume') then return "unavailable" end
        else
            observation=evaluate(step.conditions,{stepId=step.id,stepPath=data.CopyData(row.path)})
        end
        if kind(observation)~="table" then return "unavailable" end
        if observation.status=="match" or observation.status=="no-match" then return observation.status end
        return "unavailable"
    end
    local walk
    walk=function(list)
        if managed and not permitted('iterator') then return false end
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
                elseif not managed then
                    if visit(step,row.ordinal,data.CopyData(row.path))==false then
                        result.status="selected";return false
                    end
                else
                    if not permitted('pathcopy') then return false end
                    local position=row.ordinal
                    local path=data.CopyData(row.path)
                    local keepGoing=visit(step,position,path)
                    if keepGoing==false then result.status="selected";return false end
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
    local function run(owner,before,method,body,evaluate,visit,managed)
        if managed and not managed('sequence') then return unavailable({code="retired-managed-sequence"}) end
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
            if managed then return unavailable({code="unowned-managed-sequence"}) end
            return method(owner,body,evaluate,visit)
        end
        local eligible,index,why=readIndex(body,profile,data,db)
        if managed and not managed('resume') then return unavailable({code="retired-managed-sequence"}) end
        if not eligible then
            if managed then return unavailable({code="unowned-managed-index"}) end
            return method(owner,body,evaluate,visit)
        end
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
        return execute(body,evaluate,visit,rows,ordinal,kind,each,managed)
    end
    bind(rawMethod,run,sequenceStatus,ownedSequence)
end
]======]

local after = [======[local _,addon=...
local data=addon.RotationData
local function unavailable(diagnostic)
    return {status="unavailable",suppressAttack=true,diagnostic=diagnostic}
end
local function execute(body,evaluate,visit,rows,ordinal,kind,each,managed)
    local result={status="complete",suppressAttack=false,fallbackOrdinal=ordinal+1}
    local function permitted(receiver)
        if managed(receiver) then return true end
        result.status="unavailable";result.suppressAttack=true;return false
    end
    local function check(step,row)
        local observation
        if managed then
            if not permitted('pathcopy') then return "unavailable" end
            local conditions,stepId=step.conditions,step.id
            local path=data.CopyData(row.path)
            observation=evaluate(conditions,{stepId=stepId,stepPath=path})
            if not permitted('resume') then return "unavailable" end
        else
            observation=evaluate(step.conditions,{stepId=step.id,stepPath=data.CopyData(row.path)})
        end
        if kind(observation)~="table" then return "unavailable" end
        if observation.status=="match" or observation.status=="no-match" then return observation.status end
        return "unavailable"
    end
    local walk
    walk=function(list)
        if managed and not permitted('iterator') then return false end
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
                elseif not managed then
                    if visit(step,row.ordinal,data.CopyData(row.path))==false then
                        result.status="selected";return false
                    end
                else
                    if not permitted('pathcopy') then return false end
                    local position=row.ordinal
                    local path=data.CopyData(row.path)
                    local keepGoing=visit(step,position,path)
                    if keepGoing==false then result.status="selected";return false end
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
    -- Only the admitted managed caller owns immutable execution bodies. Keep
    -- one private map; ordinary mutable callers retain the live index reader.
    local managedEntry
    local function run(owner,before,method,body,evaluate,visit,managed)
        if managed and not managed('sequence') then return unavailable({code="retired-managed-sequence"}) end
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
            if managed then return unavailable({code="unowned-managed-sequence"}) end
            return method(owner,body,evaluate,visit)
        end
        local cached=managed and managedEntry
        local rows,ordinal
        if cached and sequenceEqual(cached.body,body) and sequenceEqual(cached.db,db)
            and sequenceEqual(cached.profile,profile) then
            if sequenceType(evaluate)~="function" or sequenceType(visit)~="function" then
                return unavailable({code="invalid-sequence-callback",path="$",severity="error"})
            end
            rows,ordinal=cached.rows,cached.ordinal
        else
            local eligible,index,why=readIndex(body,profile,data,db)
            if managed and not managed('resume') then return unavailable({code="retired-managed-sequence"}) end
            if not eligible then
                if managed then return unavailable({code="unowned-managed-index"}) end
                return method(owner,body,evaluate,visit)
            end
            if not index then return unavailable(why) end
            -- Preserve the ordinary reader's callback validation before any
            -- row-map iteration, including its original error ordering.
            if sequenceType(evaluate)~="function" or sequenceType(visit)~="function" then
                return unavailable({code="invalid-sequence-callback",path="$",severity="error"})
            end
            rows,ordinal={},0
            for _,row in sequenceIpairs(index.rows) do
                if row.section=="rotation" then rows[row.step]=row;ordinal=ordinal+1 end
            end
            if managed then
                -- A failed older invocation must not erase or replace a map
                -- published by a nested, newer managed continuation.
                if not managed('resume') then return unavailable({code="retired-managed-sequence"}) end
                managedEntry={body=body,db=db,profile=profile,rows=rows,ordinal=ordinal}
            end
        end
        local function kind(value) return sequenceEnvironment.type(value) end
        local function each(list) return sequenceEnvironment.ipairs(list) end
        return execute(body,evaluate,visit,rows,ordinal,kind,each,managed)
    end
    bind(rawMethod,run,sequenceStatus,ownedSequence)
end
]======]

return function(text, path)
    if path == "Core/rotation_sequence.lua" and text == after then
        return before
    end

    return text
end
