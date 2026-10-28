-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Exact authorized source delta; rejects partial, repeated or unrelated edits.
local changes = {
    ['Core/rotation_sequence.lua'] = {
        hash = '07870379',
        bytes = 2480,
        patches = {
            {
                old = ([====[!local _,addon=...
local data=addon.RotationData
local function unavailable(diagnostic)
    return {status="unavailable",suppressAttack=true,diagnostic=diagnostic}
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
    local result={status="complete",suppressAttack=false,fallbackOrdinal=ordinal+1}
    local function check(step,row)
        local observation=evaluate(step.conditions,{stepId=step.id,stepPath=data.CopyData(row.path)})
        if type(observation)~="table" then return "unavailable" end
        if observation.status=="match" or observation.status=="no-match" then return observation.status end
        return "unavailable"
    end
    local walk
    walk=function(list)
        for _,step in ipairs(list) do
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
]====]):sub(2),
                new = ([====[!local _,addon=...
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
local readIndex,retireIndex
local bindIndex=addon.BindRotationExecutionIndexReader
if sequenceType(bindIndex)=="function" then
    ---@cast bindIndex function
    bindIndex(addon,function(read,retire) readIndex,retireIndex=read,retire end)
    addon.BindRotationExecutionIndexReader=nil
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
    bind(rawMethod,run)
end
]====]):sub(2),
            },
        },
    },
    ['main.lua'] = {
        hash = '22faab04',
        bytes = 65177,
        patches = {
            {
                old = ([====[!local getCached
]====]):sub(2),
                new = ([====[!local getCached
local sequenceRawMethod,sequenceRun
local bindSequence=addon.BindRotationSequenceReader
if type(bindSequence)=="function" then
    bindSequence(addon,function(rawMethod,run) sequenceRawMethod,sequenceRun=rawMethod,run end)
    addon.BindRotationSequenceReader=nil
end
local function evaluateSequence(owner,body,evaluate,visit)
    local before=sequenceRawMethod and sequenceRawMethod(owner)
    local method=owner.EvaluateRotationSequence
    if sequenceRun then return sequenceRun(owner,before,method,body,evaluate,visit) end
    return method(owner,body,evaluate,visit)
end
]====]):sub(2),
            },
            {
                old = ([====[!local sequence=self:EvaluateRotationSequence(rot,]====]):sub(2),
                new = ([====[!local sequence=evaluateSequence(self,rot,]====]):sub(2),
            },
        },
    },
    ['Data/plain.lua'] = {
        hash = 'e86f4e25',
        bytes = 3442,
        patches = {
            {
                old = ([====[!function data.CopyData(value)
    local ok, why = data.CheckPortable(value)
    if not ok then return nil, why end
    local copies = {}
    local function copy(current)
        if type(current) ~= "table" then return current end
        if copies[current] then return copies[current] end
        local result = {}
        copies[current] = result
        for key, child in pairs(current) do result[key] = copy(child) end
        return result
    end
    return copy(value)
end
]====]):sub(2),
                new = ([====[!function data.CopyData(value)
    local ok, why = data.CheckPortable(value)
    if not ok then return nil, why end
    local copies = {}
    local function copy(current)
        if type(current) ~= "table" then return current end
        if copies[current] then return copies[current] end
        local result = {}
        copies[current] = result
        for key, child in pairs(current) do result[key] = copy(child) end
        return result
    end
    return copy(value)
end

-- Private source-owner proof. Public portable/copy APIs remain fresh and live.
local portableType,portableRawget,portableEqual=type,rawget,rawequal
local portableGetmetatable=getmetatable
---@type fun(f: number|function): table
local portableGetfenv=getfenv
local portablePairs,portableIpairs=pairs,ipairs
local portableTable,portableMath=table,math
local portableSort,portableHuge=table.sort,math.huge
local portableEnvironment=portableType(portableGetfenv)=="function" and portableGetfenv(1) or nil
local ownedPortable=data.CheckPortable
local function portableOwned(namespace)
    return portableEqual(namespace,data) and portableType(portableEnvironment)=="table"
        and portableEqual(portableRawget(data,"CheckPortable"),ownedPortable)
        and portableEqual(portableGetfenv(ownedPortable),portableEnvironment)
        and portableEqual(portableGetfenv(finite),portableEnvironment)
        and portableEqual(portableGetfenv(diagnostic),portableEnvironment)
        and portableEqual(portableRawget(portableEnvironment,"type"),portableType)
        and portableEqual(portableRawget(portableEnvironment,"pairs"),portablePairs)
        and portableEqual(portableRawget(portableEnvironment,"ipairs"),portableIpairs)
        and portableEqual(portableRawget(portableEnvironment,"getmetatable"),portableGetmetatable)
        and portableEqual(portableRawget(portableEnvironment,"getfenv"),portableGetfenv)
        and portableEqual(portableRawget(portableEnvironment,"math"),portableMath)
        and portableEqual(portableRawget(portableMath,"huge"),portableHuge)
        and portableEqual(portableRawget(portableEnvironment,"table"),portableTable)
        and portableEqual(portableRawget(portableTable,"sort"),portableSort)
end
function addon:BindRotationPortableReader(bind)
    if self~=addon or portableType(bind)~="function" then return end
    bind(portableOwned)
end
]====]):sub(2),
            },
        },
    },
    ['Data/rotation_tree.lua'] = {
        hash = '0e9aa290',
        bytes = 5155,
        patches = {
            {
                old = ([====[!function data.ReserveRotationIdentities(value,used)
    local portable,why=data.CheckPortable(value)
    if not portable then return nil,why end
    local function reserve(current)
        if type(current)=="string" then used[current]=true
        elseif type(current)=="table" then
            for key,childValue in pairs(current) do reserve(key);reserve(childValue) end
        end
    end
    reserve(value);return true
end
]====]):sub(2),
                new = ([====[!function data.ReserveRotationIdentities(value,used)
    local portable,why=data.CheckPortable(value)
    if not portable then return nil,why end
    local function reserve(current)
        if type(current)=="string" then used[current]=true
        elseif type(current)=="table" then
            for key,childValue in pairs(current) do reserve(key);reserve(childValue) end
        end
    end
    reserve(value);return true
end

-- The private execution reader never exposes its index or graph witness.
-- Trusted standard-at-load primitives; inherited globals never certify reuse.
local indexType,indexRawget,indexNext,indexEqual=type,rawget,next,rawequal
local indexGetmetatable=getmetatable
---@type fun(f: number|function): table
local indexGetfenv=getfenv
local indexPairs,indexIpairs=pairs,ipairs
local indexTable,indexMath,indexString=table,math,string
local indexSort,indexMax,indexHuge=table.sort,math.max,math.huge
local indexEnvironment=indexType(indexGetfenv)=="function" and indexGetfenv(1) or nil
local indexStringMeta=indexGetmetatable("")
local indexStringMethods=indexType(indexStringMeta)=="table" and indexRawget(indexStringMeta,"__index") or nil
local indexMatch=indexType(indexStringMethods)=="table" and indexRawget(indexStringMethods,"match") or nil
local indexSub=indexType(indexStringMethods)=="table" and indexRawget(indexStringMethods,"sub") or nil
local ownedIndex=data.IndexRotationSteps
local portableOwned
local bindPortable=addon.BindRotationPortableReader
if indexType(bindPortable)=="function" then
    ---@cast bindPortable function
    bindPortable(addon,function(reader) portableOwned=reader end)
    addon.BindRotationPortableReader=nil
end
local function indexOwned()
    return portableOwned and portableOwned(data) and indexType(indexEnvironment)=="table"
        and indexEqual(indexRawget(data,"IndexRotationSteps"),ownedIndex)
        and indexEqual(indexGetfenv(ownedIndex),indexEnvironment)
        and indexEqual(indexGetfenv(child),indexEnvironment)
        and indexEqual(indexGetfenv(location),indexEnvironment)
        and indexEqual(indexGetfenv(failure),indexEnvironment)
        and indexEqual(indexGetfenv(identifier),indexEnvironment)
        and indexEqual(indexGetfenv(dense),indexEnvironment)
        and indexEqual(indexRawget(indexEnvironment,"type"),indexType)
        and indexEqual(indexRawget(indexEnvironment,"pairs"),indexPairs)
        and indexEqual(indexRawget(indexEnvironment,"ipairs"),indexIpairs)
        and indexEqual(indexRawget(indexEnvironment,"getmetatable"),indexGetmetatable)
        and indexEqual(indexRawget(indexEnvironment,"getfenv"),indexGetfenv)
        and indexEqual(indexRawget(indexEnvironment,"table"),indexTable)
        and indexEqual(indexRawget(indexTable,"sort"),indexSort)
        and indexEqual(indexRawget(indexEnvironment,"math"),indexMath)
        and indexEqual(indexRawget(indexMath,"max"),indexMax)
        and indexEqual(indexRawget(indexMath,"huge"),indexHuge)
        and indexType(indexStringMeta)=="table" and indexEqual(indexStringMethods,indexString)
        and indexType(indexMatch)=="function" and indexType(indexSub)=="function"
        and indexEqual(indexGetmetatable(""),indexStringMeta)
        and indexEqual(indexRawget(indexStringMeta,"__index"),indexStringMethods)
        and indexEqual(indexRawget(indexStringMethods,"match"),indexMatch)
        and indexEqual(indexRawget(indexStringMethods,"sub"),indexSub)
end
local function witness(body)
    local records,seen={},{}
    local function visit(value)
        if indexType(value)~="table" or seen[value] then return end
        seen[value]=true
        local row={object=value,values={},count=0};records[#records+1]=row
        for key,item in indexNext,value do
            row.values[key]=item;row.count=row.count+1;visit(item)
        end
    end
    visit(body);return records
end
local function unchanged(records)
    for i=1,#records do
        local row=records[i];local object=row.object
        if indexGetmetatable(object)~=nil then return false end
        local count=0
        for key,value in indexNext,object do
            if not indexEqual(value,indexRawget(row.values,key)) then return false end
            count=count+1
        end
        if count~=row.count then return false end
    end
    return true
end
local function materialize(index)
    local rows,paths={},{}
    for i=1,#index.rows do
        local row=index.rows[i];local fresh={}
        for key,value in indexNext,row do fresh[key]=value end
        local path=row.path;local copy=paths[path]
        if not copy then
            copy={};paths[path]=copy
            for key,value in indexNext,path do copy[key]=value end
        end
        fresh.path=copy;rows[i]=fresh
    end
    return {rows=rows}
end
function addon:BindRotationExecutionIndexReader(bind)
    if self~=addon or indexType(bind)~="function" then return end
    local entry,attempt
    local function retire() entry=nil;attempt={} end
    local function read(body,profile,namespace,db)
        if not indexEqual(namespace,data) or not indexOwned() then retire();return false end
        if entry and indexEqual(entry.body,body) and indexEqual(entry.profile,profile) and indexEqual(entry.db,db) and unchanged(entry.graph) then
            return true,materialize(entry.index)
        end
        retire();local token=attempt
        local index,why=ownedIndex(body,{allowMissingIds=true})
        if not index then return true,nil,why end
        local graph=witness(body)
        if indexEqual(attempt,token) and indexOwned() then entry={body=body,profile=profile,db=db,index=index,graph=graph} end
        return true,materialize(index)
    end
    bind(read,retire)
end
]====]):sub(2),
            },
        },
    },
}

return function(text, path)
    local change = assert(changes[path], "unknown execution source")

    for _, patch in ipairs(change.patches) do
        local first, last = text:find(patch.new, 1, true)
        assert(first and not text:find(patch.new, last + 1, true), "execution delta missing/repeated: " .. path)
        text = text:sub(1, first - 1) .. patch.old .. text:sub(last + 1)
    end

    local hash = 0

    for i = 1, #text do
        hash = (hash * 33 + text:byte(i)) % 4294967296
    end

    assert(
        #text == change.bytes and string.format("%08x", hash) == change.hash,
        "unrelated execution source delta: " .. path
    )

    return text
end
