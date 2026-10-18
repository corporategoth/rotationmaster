local _,addon=...
local data=addon.RotationData
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
    return type(value)=="string" and #value>0 and #value<=128 and value:match("^[%w][%w._:%-]*$")~=nil
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
