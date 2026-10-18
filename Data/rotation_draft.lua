local _,addon=...
local data=addon.RotationData

-- Independent copies deliberately break aliases: editing one card or its
-- condition cannot also edit a sibling that reused the same source table.
local function detach(value)
    if type(value)~='table' then return value end
    local result={};for key,child in pairs(value) do result[key]=detach(child) end;return result
end
local function samePath(a,b)
    if #a~=#b then return false end
    for key in pairs(b) do if type(key)~='number' or key<1 or key%1~=0 or key>#a then return false end end
    for i,key in ipairs(a) do if key~=b[i] then return false end end;return true
end
local function prefix(a,b)
    if #a>#b then return false end
    for i,key in ipairs(a) do if key~=b[i] then return false end end;return true
end
local function identifier(value)
    return type(value)=='string' and #value>0 and #value<=128 and value:match('^[%w][%w._:%-]*$')~=nil
end
local function fresh(newId,used)
    if type(newId)~='function' then return nil,'missing-id-allocator' end
    for _=1,100 do
        local ok,id=pcall(newId)
        if not ok then return nil,'id-allocation-error' end
        if identifier(id) and not used[id] then used[id]=true;return id end
    end
    return nil,'id-allocation-exhausted'
end
local function inspect(body,legacy)
    local tree,why=data.IndexRotationSteps(body,{allowMissingIds=legacy})
    return tree,why and why.code
end

function data.NewRotationDraft(original,newId,reserved)
    local portable,why=data.CheckPortable(original);if not portable then return nil,why.code end
    if type(original)~='table' then return nil,'expected-rotation-object' end
    local used={}
    local ok,problem=data.ReserveRotationIdentities(original,used);if not ok then return nil,problem.code end
    if reserved~=nil then ok,problem=data.ReserveRotationIdentities(reserved,used);if not ok then return nil,problem.code end end
    local root=detach(original)
    if root.rotation==nil then root.rotation={} end
    if root.cooldowns==nil then root.cooldowns={} end
    local tree,errorCode=inspect(root,true);if not tree then return nil,errorCode end
    for _,row in ipairs(tree.rows) do
        if not row.step.id then
            local id,reason=fresh(newId,used);if not id then return nil,reason end;row.step.id=id
        end
    end
    local draft={}
    function draft:Snapshot() return detach(root) end
    -- History snapshots are bounded body data; reservation bookkeeping is an
    -- internal set and may grow beyond a transport object's node count.
    function draft:Restore(snapshot)
        local valid,reason=inspect(snapshot);if not valid then return nil,reason end
        local allocated=detach(used)
        for _,row in ipairs(valid.rows) do allocated[row.step.id]=true end
        root,used=detach(snapshot),allocated;return true
    end
    function draft:Command(name,first,second)
        if not data.CheckPortable(first) or not data.CheckPortable(second) then return nil,'non-portable-edit' end
        local candidate,allocated=detach(root),detach(used)
        local index=assert(inspect(candidate))
        local function destination(value)
            if type(value)~='table' or type(value.path)~='table' or type(value.index)~='number' or value.index%1~=0 then return nil,'invalid-destination' end
            for _,list in ipairs(index.lists) do
                if samePath(list.path,value.path) then
                    if value.parentId~=list.parentId then return nil,'stale-rotation-destination' end
                    if value.index<1 or value.index>#list.list+1 then return nil,'invalid-destination-index' end
                    return list
                end
            end
            return nil,'missing-priority-list'
        end
        local function row(id)
            if type(id)~='string' or not index.byId[id] then return nil,'missing-rotation-step' end
            return index.byId[id]
        end
        local function parent(entry)
            local list=candidate
            for i=1,#entry.path-1 do list=list[entry.path[i]] end
            return list
        end
        local function reidentify(step)
            local wrapper={rotation={step},cooldowns={}}
            local nodes,reason=inspect(wrapper,true);if not nodes then return nil,reason end
            for _,entry in ipairs(nodes.rows) do
                local id,allocationError=fresh(newId,allocated);if not id then return nil,allocationError end
                entry.step.id=id
            end
            return true
        end
        local result
        if name=='Insert' then
            local list,reason=destination(first);if not list then return nil,reason end
            if type(second)~='table' then return nil,'invalid-rotation-step' end
            local step=detach(second);local assigned,allocationError=reidentify(step)
            if not assigned then return nil,allocationError end
            if step.type=='branch' then
                while #list.list>=first.index do step.onTrue[#step.onTrue+1]=table.remove(list.list,first.index) end
            end
            table.insert(list.list,first.index,step);result=step.id
        elseif name=='Remove' or name=='Move' or name=='MoveTail' or name=='Duplicate' or name=='UpdateStep' or name=='UnsetStepField' or name=='PatchStep' then
            local entry,reason=row(first);if not entry then return nil,reason end
            local list=parent(entry)
            if name=='Remove' then table.remove(list,entry.index);result=first
            elseif name=='Duplicate' then
                local step=detach(entry.step);local assigned,allocationError=reidentify(step)
                if not assigned then return nil,allocationError end
                table.insert(list,entry.index+1,step);result=step.id
            elseif name=='Move' or name=='MoveTail' then
                local target,targetError=destination(second);if not target then return nil,targetError end
                if prefix(entry.path,target.path) then return nil,'rotation-cycle' end
                if name=='MoveTail' then
                    if entry.section~='rotation' or not target.parentId or target.list==list then return nil,'invalid-tail-destination' end
                    for i=entry.index,#list do
                        local carriedPath={};for j=1,#entry.path-1 do carriedPath[j]=entry.path[j] end;carriedPath[#entry.path]=i
                        if prefix(carriedPath,target.path) then return nil,'rotation-cycle' end
                    end
                    local at=second.index
                    while #list>=entry.index do table.insert(target.list,at,table.remove(list,entry.index));at=at+1 end
                    result=first
                else
                local at=second.index
                if target.list==list and entry.index<at then at=at-1 end
                table.remove(list,entry.index);table.insert(target.list,at,entry.step);result=first
                end
            elseif name=='UnsetStepField' then
                if type(second)~='string' or second=='id' or second=='onTrue' or second=='onFalse' or second=='type' then return nil,'protected-step-field' end
                entry.step[second]=nil;result=first
            else
                if type(second)~='table' then return nil,'invalid-step-patch' end
                local fields=second
                if name=='PatchStep' then
                    fields=second.set or {};local unset=second.unset or {}
                    if type(fields)~='table' or type(unset)~='table' then return nil,'invalid-step-patch' end
                    for key,field in pairs(unset) do
                        if type(key)~='number' or key<1 or key%1~=0 or key>#unset or type(field)~='string' then return nil,'invalid-step-patch' end
                        if field=='id' or field=='onTrue' or field=='onFalse' or field=='type' then return nil,'protected-step-field' end
                        entry.step[field]=nil
                    end
                end
                for key,value in pairs(fields) do
                    if key=='id' or key=='onTrue' or key=='onFalse' then return nil,'protected-step-field' end
                    if key=='type' and (entry.step.type=='branch' or value=='branch') and value~=entry.step.type then return nil,'branch-conversion-forbidden' end
                    entry.step[key]=detach(value)
                end
                result=first
            end
        elseif name=='SetCondition' then
            if type(second)~='table' then return nil,'invalid-condition' end
            if type(first)=='table' and first.kind=='switch' then candidate.switch=detach(second)
            else local entry,reason=row(first);if not entry then return nil,reason end;entry.step.conditions=detach(second) end
            result=first
        elseif name=='SetDetails' then
            if type(first)~='table' then return nil,'invalid-metadata' end
            for key in pairs(first) do if key~='description' and key~='metadata' and key~='tags' then return nil,'protected-body-field' end end
            candidate.description=detach(first.description);candidate.metadata=detach(first.metadata);if first.tags~=nil then candidate.tags=detach(first.tags) end;result='metadata'
        elseif name=='SetBodyField' then
            if first~='name' and first~='description' and first~='metadata' and first~='tags' and first~='disabled' and first~='switch' then return nil,'protected-body-field' end
            candidate[first]=detach(second);result=first
        else return nil,'invalid-rotation-command' end
        local valid,reason=inspect(candidate);if not valid then return nil,reason end
        -- Only declared card identities are newly reserved. Opaque condition
        -- strings are not IDs and must not accumulate outside bounded history.
        for _,entry in ipairs(valid.rows) do allocated[entry.step.id]=true end
        root,used=candidate,allocated
        return true,result
    end
    return draft
end
