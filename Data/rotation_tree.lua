local _,addon=...
local data=addon.RotationData
-- The identifier grammar uses the standard pattern operation captured at load,
-- independently of mutable literal-string method dispatch.
local parserString=string
local parserMatch=type(parserString)=="table" and rawget(parserString,"match") or nil
if type(parserMatch)~="function" then parserMatch=nil end
local function child(path,key)
    local result={};for i,part in ipairs(path) do result[i]=part end
    result[#result+1]=key;return result
end
local function location(path)
    local text="$"
    for _,key in ipairs(path) do text=text..(type(key)=="number" and "["..key.."]" or "."..key) end
    return text
end
local function failure(code,path) return nil,{code=code,path=location(path),severity="error"} end
local function identifier(value)
    return type(value)=="string" and #value>0 and #value<=128 and parserMatch(value,"^[%w][%w._:%-]*$")~=nil
end
local function dense(value)
    if type(value)~="table" then return false end
    local count,maximum=0,0
    for key in pairs(value) do
        if type(key)~="number" or key<1 or key%1~=0 then return false end
        count=count+1;maximum=math.max(maximum,key)
    end
    return count==maximum
end
local branchFields={id=true,type=true,mode=true,name=true,conditions=true,onTrue=true,onFalse=true}
local incompatibleBranchFields={action=true,disabled=true,ranked=true,use_name=true,suppress_attack=true,effect=true,
    color=true,magnification=true,setpoint=true,xoffs=true,yoffs=true,announce=true,announce_sound=true}

-- Returns trusted source references for internal identity/ownership operations.
-- Paths and presentation state are private. Public snapshots must copy steps.
-- Inspect only declared rotation edges; a condition's arbitrary data is opaque.
function data.IndexRotationSteps(body,options)
    local portable,why=data.CheckPortable(body)
    if not portable then return nil,why end
    if type(body)~="table" then return failure("expected-rotation-object",{}) end
    options=options or {}
    local result={rows={},byId={},lists={}}
    local walk
    walk=function(list,path,section,depth,parentId,arm,unreachable)
        if not dense(list) then return failure("invalid-priority-list",path) end
        result.lists[#result.lists+1]={list=list,path=child(path,nil),section=section,depth=depth,parentId=parentId,arm=arm,unreachable=unreachable==true}
        for index,step in ipairs(list) do
            local at=child(path,index)
            if #result.rows>=2000 then return failure("rotation-node-limit",at) end
            if type(step)~="table" then return failure("expected-step-object",at) end
            if not identifier(step.id) and not (step.id==nil and options.allowMissingIds==true) then return failure("invalid-step-id",child(at,"id")) end
            if step.id and result.byId[step.id] then return failure("duplicate-step-id",child(at,"id")) end
            local row={step=step,path=at,section=section,index=index,ordinal=#result.rows+1,depth=depth,parentId=parentId,arm=arm,unreachable=unreachable==true}
            result.rows[#result.rows+1]=row
            if step.id then result.byId[step.id]=row end
            if step.type=="branch" then
                if section~="rotation" then return failure("branch-in-optional-list",at) end
                if depth>=16 then return failure("rotation-depth-limit",at) end
                local mode=step.mode;if mode==nil then mode="evaluate" end
                if mode~="evaluate" and mode~="true" and mode~="false" then return failure("invalid-branch-mode",child(at,"mode")) end
                local keys={};for key in pairs(step) do keys[#keys+1]=key end
                table.sort(keys,function(a,b) if type(a)==type(b) then return a<b end;return type(a)=="number" end)
                for _,key in ipairs(keys) do if not branchFields[key] and (incompatibleBranchFields[key] or options.allowUnknownBranchFields~=true) then return failure("unexpected-branch-field",child(at,key)) end end
                for _,choice in ipairs({{field="onTrue",arm="true",excluded=mode=="false"},{field="onFalse",arm="false",excluded=mode=="true"}}) do
                    if step[choice.field]==nil then return failure("missing-branch-arm",child(at,choice.field)) end
                    local ok,problem=walk(step[choice.field],child(at,choice.field),section,depth+1,step.id,choice.arm,unreachable or choice.excluded)
                    if not ok then return nil,problem end
                end
            end
        end
        return true
    end
    for _,section in ipairs({"rotation","cooldowns"}) do
        local list=body[section];if list==nil then list={} end
        local ok,problem=walk(list,{section},section,0,nil,nil,false)
        if not ok then return nil,problem end
    end
    return result
end

-- Allocation reserves even identities retained in malformed-but-portable data
-- and provenance. Treating every string conservatively prevents hidden nested
-- IDs from colliding without interpreting unknown future structures.
function data.ReserveRotationIdentities(value,used)
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
local indexTable,indexMath=table,math
local indexSort,indexMax,indexHuge=table.sort,math.max,math.huge
local indexEnvironment=indexType(indexGetfenv)=="function" and indexGetfenv(1) or nil
local ownedIndex=data.IndexRotationSteps
local portableOwned,portableStatus
local bindPortable=addon.BindRotationPortableReader
if indexType(bindPortable)=="function" then
    ---@cast bindPortable function
    bindPortable(addon,function(reader,status) portableOwned,portableStatus=reader,status end)
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
        and indexType(parserMatch)=="function"
end
-- A pure explanation of captured ownership facts, sampled only by the profiler.
local function indexStatus(namespace)
    local portable=portableStatus and portableStatus(data) or {reason="unbound",raw={}}
    local result={reason="ready",raw={}}
    local function check(reason,ok) if result.reason=="ready" and not ok then result.reason=reason end end
    local environment=indexType(indexEnvironment)=="table"
    local capability=indexType(indexGetfenv)=="function"
    check("namespace",indexEqual(namespace,data));check("portable-proof",portable.reason=="ready")
    check("capability",capability);check("env",environment)
    check("method",indexEqual(indexRawget(data,"IndexRotationSteps"),ownedIndex))
    local functions={ownedIndex,child,location,failure,identifier,dense}
    local reasons={"public-env","child-env","location-env","failure-env","identifier-env","dense-env"}
    for i=1,6 do check(reasons[i],capability and indexEqual(indexGetfenv(functions[i]),indexEnvironment)) end
    local keys={"type","pairs","ipairs","getmetatable","getfenv","table","math"}
    local pointers={indexType,indexPairs,indexIpairs,indexGetmetatable,indexGetfenv,indexTable,indexMath}
    for i=1,7 do
        local key=keys[i];local ok=environment and indexEqual(indexRawget(indexEnvironment,key),pointers[i]) or false
        result.raw[key]=ok;check("raw-"..key,ok)
        if key=="table" then check("table-sort",indexType(indexTable)=="table" and indexEqual(indexRawget(indexTable,"sort"),indexSort)) end
        if key=="math" then
            check("math-max",indexType(indexMath)=="table" and indexEqual(indexRawget(indexMath,"max"),indexMax))
            check("math-huge",indexType(indexMath)=="table" and indexEqual(indexRawget(indexMath,"huge"),indexHuge))
        end
    end
    result.parserMatch=indexType(parserMatch)=="function"
    check("parser-match-unavailable",result.parserMatch)
    return {portable=portable,index=result}
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
    bind(read,retire,indexStatus)
end
