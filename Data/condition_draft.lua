local _,addon=...
local data=addon.RotationData

local function copy(value)
    local ok,why=data.CheckPortable(value)
    if not ok then return nil,why.code end
    -- A condition tree has independent operands, even if its source reused a
    -- table. Portable checking bounds the total traversal before copying.
    local function visit(current)
        if type(current)~="table" then return current end
        local result={}
        for key,child in pairs(current) do result[key]=visit(child) end
        return result
    end
    return visit(value)
end
local function pathCopy(path)
    local result={};for index,part in ipairs(path) do result[index]=part end;return result
end
local function dense(list)
    if type(list)~="table" then return false end
    local count,maximum=0,0
    for key in pairs(list) do
        if type(key)~="number" or key<1 or key%1~=0 then return false end
        count=count+1;maximum=math.max(maximum,key)
    end
    return count==maximum
end
local function schemas(definitions)
    local result={}
    for tag,definition in pairs(definitions or {}) do
        local fields=type(definition)=="table" and rawget(definition,"fields")
        if type(tag)=="string" and type(fields)=="table" then
            result[tag]={}
            for field,kind in pairs(fields) do
                if type(field)=="string" and (kind=="condition" or kind=="condition[]") then result[tag][field]=kind end
            end
        end
    end
    return result
end

function data.NewConditionDraft(original,definitions)
    local root,reason=copy(original)
    if root==nil then return nil,reason or "invalid-condition" end
    if type(root)~="table" then return nil,"invalid-condition" end
    local declarations=schemas(definitions)
    local function edges(node)
        if type(node)~="table" then return nil,"invalid-condition" end
        if node.type~=nil and type(node.type)~="string" then return nil,"invalid-condition-type" end
        local result={}
        local function field(name,kind)
            local value=node[name]
            if value==nil then return true end
            if kind=="condition[]" then
                if not dense(value) then return nil,"invalid-condition-list" end
                for index,child in ipairs(value) do
                    result[#result+1]={node=child,parts={name,index},container=value,key=index,relation="list"}
                end
            else result[#result+1]={node=value,parts={name},container=node,key=name,relation="single"} end
            return true
        end
        if node.type=="AND" or node.type=="OR" then
            local ok,why=field("value","condition[]");if not ok then return nil,why end
        elseif node.type=="NOT" then
            field("value","condition")
        else
            local fields=declarations[node.type] or {}
            local names={};for name in pairs(fields) do names[#names+1]=name end;table.sort(names)
            for _,name in ipairs(names) do local ok,why=field(name,fields[name]);if not ok then return nil,why end end
        end
        return result
    end
    local function validate(candidate)
        local count=0
        local function visit(node,depth)
            count=count+1
            if count>4096 or depth>64 then return nil,"condition-limit" end
            local children,why=edges(node);if not children then return nil,why end
            for _,edge in ipairs(children) do local ok,errorCode=visit(edge.node,depth+1);if not ok then return nil,errorCode end end
            return true
        end
        return visit(candidate,0)
    end
    local valid,why=validate(root);if not valid then return nil,why end
    local function resolve(candidate,path)
        if type(path)~="table" or not data.CheckPortable(path) or not dense(path) or #path>128 then return nil,nil,nil,nil,"invalid-condition-path" end
        local node,container,key,relation=candidate,nil,nil,"root"
        local offset=1
        while offset<=#path do
            local children=edges(node);local matched
            for _,edge in ipairs(children) do
                local same=true
                for index,part in ipairs(edge.parts) do if path[offset+index-1]~=part then same=false;break end end
                if same then matched=edge;break end
            end
            if not matched then return nil,nil,nil,nil,"invalid-condition-path" end
            node,container,key,relation=matched.node,matched.container,matched.key,matched.relation
            offset=offset+#matched.parts
        end
        return node,container,key,relation
    end
    local function transaction(operation)
        local candidate=assert(copy(root))
        local changed,problem,selection=operation(candidate)
        if not changed then return nil,problem end
        local checked,copyError=copy(changed);if not checked then return nil,copyError end
        local ok,shapeError=validate(checked);if not ok then return nil,shapeError end
        root=checked;return true,selection
    end
    local function edit(path,operation)
        return transaction(function(candidate)
        local node,container,key,relation,errorCode=resolve(candidate,path)
        if not node then return nil,errorCode end
        return operation(node,container,key,relation,candidate)
        end)
    end
    local function replace(container,key,value,candidate)
        if not container then return value end
        container[key]=value;return candidate
    end
    local draft={}
    function draft:Snapshot() return copy(root) end
    function draft:Replace(path,value)
        local replacement,errorCode=copy(value)
        if replacement==nil then return nil,errorCode or "invalid-condition" end
        if type(replacement)~="table" then return nil,"invalid-condition" end
        return edit(path,function(_,container,key,_,candidate) return replace(container,key,replacement,candidate) end)
    end
    function draft:Wrap(path,kind)
        if kind~="AND" and kind~="OR" and kind~="NOT" then return nil,"invalid-condition-group" end
        return edit(path,function(node,container,key,_,candidate)
            local wrapper={type=kind,value=kind=="NOT" and node or {node}}
            return replace(container,key,wrapper,candidate)
        end)
    end
    function draft:Unwrap(path)
        return edit(path,function(node,container,key,relation,candidate)
            local child
            if node.type=="NOT" then child=node.value or {}
            elseif node.type=="AND" or node.type=="OR" then
                local values=node.value or {}
                if #values>1 then
                    local parent=pathCopy(path);table.remove(parent);table.remove(parent)
                    local owner=resolve(candidate,parent)
                    if relation~="list" or not owner or owner.type~=node.type then return nil,"ambiguous-group-unwrapping" end
                    table.remove(container,key)
                    for index=#values,1,-1 do table.insert(container,key,values[index]) end
                    return candidate
                end
                child=values[1] or {}
            else return nil,"not-a-condition-group" end
            return replace(container,key,child,candidate)
        end)
    end
    function draft:Add(path,value)
        if value==nil then value={} end
        local child,errorCode=copy(value)
        if child==nil then return nil,errorCode or "invalid-condition" end
        if type(child)~="table" then return nil,"invalid-condition" end
        return edit(path,function(node,container,key,_,candidate)
            if node.type=="AND" or node.type=="OR" then node.value=node.value or {};table.insert(node.value,child)
            elseif node.type=="NOT" and (not node.value or next(node.value)==nil) then node.value=child
            elseif node.type==nil and next(node)==nil then return replace(container,key,child,candidate)
            else return nil,"not-an-empty-condition-group" end
            return candidate
        end)
    end
    function draft:Remove(path)
        return edit(path,function(_,container,key,relation,candidate)
            if relation=="list" then table.remove(container,key)
            elseif container then container[key]={}
            else return {} end
            return candidate
        end)
    end
    function draft:Move(path,delta)
        if delta~=-1 and delta~=1 then return nil,"invalid-condition-move" end
        return edit(path,function(_,container,key,relation,candidate)
            if relation~="list" or key+delta<1 or key+delta>#container then return nil,"invalid-condition-move" end
            container[key],container[key+delta]=container[key+delta],container[key]
            return candidate
        end)
    end
    function draft:SetDisabled(path,disabled)
        if type(disabled)~="boolean" then return nil,"invalid-disabled-flag" end
        return edit(path,function(node,_,_,_,candidate) node.disabled=disabled or nil;return candidate end)
    end
    local function prefix(left,right)
        if #left>#right then return false end
        for i,part in ipairs(left) do if right[i]~=part then return false end end
        return true
    end
    local function selected(candidate,paths)
        if not data.CheckPortable(paths) or not dense(paths) or #paths==0 or #paths>4096 then return nil,"invalid-condition-selection" end
        local result={}
        for _,path in ipairs(paths) do
            local node,container,key,relation,why=resolve(candidate,path)
            if not node then return nil,why end
            for _,other in ipairs(result) do
                if prefix(path,other.path) or prefix(other.path,path) then return nil,"overlapping-condition-selection" end
            end
            result[#result+1]={node=node,container=container,key=key,relation=relation,path=pathCopy(path)}
        end
        table.sort(result,function(a,b)
            for i,part in ipairs(a.path) do
                local other=b.path[i]
                if part~=other then
                    if type(part)==type(other) then return part<other end
                    return type(part)=="string"
                end
            end
            return false
        end)
        return result
    end
    local function locations(candidate,nodes)
        local found={}
        local function visit(node,path)
            for index,wanted in ipairs(nodes) do if wanted==node then found[index]=pathCopy(path) end end
            for _,edge in ipairs(edges(node)) do
                local child=pathCopy(path);for _,part in ipairs(edge.parts) do child[#child+1]=part end
                visit(edge.node,child)
            end
        end
        visit(candidate,{})
        return found
    end
    local function remove(records)
        for i=#records,1,-1 do
            local record=records[i]
            if record.relation=="list" then table.remove(record.container,record.key)
            elseif record.container then record.container[record.key]={} end
        end
    end
    function draft:GroupSelection(paths,kind)
        if kind~="AND" and kind~="OR" then return nil,"invalid-condition-group" end
        return transaction(function(candidate)
            local records,why=selected(candidate,paths);if not records then return nil,why end
            local first=records[1];local wrapper={type=kind,value={}}
            for _,record in ipairs(records) do
                if #records>1 and (record.relation~="list" or record.container~=first.container) then return nil,"condition-siblings-required" end
                wrapper.value[#wrapper.value+1]=record.node
            end
            if #records>1 then remove(records);table.insert(first.container,first.key,wrapper)
            else candidate=replace(first.container,first.key,wrapper,candidate) end
            return candidate,nil,locations(candidate,{wrapper})
        end)
    end
    function draft:NegateSelection(paths)
        return transaction(function(candidate)
            local records,why=selected(candidate,paths);if not records then return nil,why end
            local nodes={}
            for _,record in ipairs(records) do
                local replacement=record.node.type=="NOT" and (record.node.value or {}) or {type="NOT",value=record.node}
                if record.node.type~="NOT" then
                    replacement.disabled=record.node.disabled;record.node.disabled=nil
                else
                    for key in pairs(record.node) do
                        if key~="type" and key~="value" and key~="name" and key~="disabled" then return nil,"condition-property-conflict" end
                    end
                    if record.node.name~=nil then
                        if replacement.type~="AND" and replacement.type~="OR" and replacement.type~="NOT" then return nil,"condition-property-conflict" end
                        if replacement.name~=nil and replacement.name~=record.node.name then return nil,"condition-property-conflict" end
                        replacement.name=record.node.name
                    end
                    if record.node.disabled~=nil then
                        if type(record.node.disabled)~="boolean" then return nil,"condition-property-conflict" end
                        if record.node.disabled then replacement.disabled=true end
                    end
                end
                candidate=replace(record.container,record.key,replacement,candidate);nodes[#nodes+1]=replacement
            end
            return candidate,nil,locations(candidate,nodes)
        end)
    end
    function draft:SetProjectedDisabled(path,disabled)
        if type(disabled)~="boolean" then return nil,"invalid-disabled-flag" end
        return edit(path,function(node,_,_,_,candidate)
            local current=node
            while current.type=="NOT" and type(current.value)=="table" do current.disabled=nil;current=current.value end
            current.disabled=nil;node.disabled=disabled or nil;return candidate
        end)
    end
    -- Selection-wide Duplicate and Enable/Disable: one transaction, so one
    -- undo step, keeping the selection on the copies or the same nodes.
    function draft:DuplicateSelection(paths)
        return transaction(function(candidate)
            local records,why=selected(candidate,paths);if not records then return nil,why end
            local copies={}
            for i=#records,1,-1 do
                local record=records[i];local child=assert(copy(record.node))
                if record.relation=="list" then table.insert(record.container,record.key+1,child)
                else candidate=replace(record.container,record.key,{type="AND",value={record.node,child}},candidate) end
                table.insert(copies,1,child)
            end
            return candidate,nil,locations(candidate,copies)
        end)
    end
    function draft:SetSelectionDisabled(paths,disabled)
        if type(disabled)~="boolean" then return nil,"invalid-disabled-flag" end
        return transaction(function(candidate)
            local records,why=selected(candidate,paths);if not records then return nil,why end
            local nodes={}
            for _,record in ipairs(records) do
                local node=record.node;local current=node
                while current.type=="NOT" and type(current.value)=="table" do current.disabled=nil;current=current.value end
                current.disabled=nil;node.disabled=disabled or nil;nodes[#nodes+1]=node
            end
            return candidate,nil,locations(candidate,nodes)
        end)
    end
    function draft:RemoveSelection(paths)
        return transaction(function(candidate)
            local records,why=selected(candidate,paths);if not records then return nil,why end
            if records[1].relation=="root" then candidate={} else remove(records) end
            return candidate,nil,{{}}
        end)
    end
    function draft:Transfer(paths,destination)
        if type(destination)~="table" or not data.CheckPortable(destination) then return nil,"invalid-condition-destination" end
        return transaction(function(candidate)
            local records,why=selected(candidate,paths);if not records then return nil,why end
            local target=resolve(candidate,destination.path)
            if not target then return nil,"invalid-condition-destination" end
            for _,record in ipairs(records) do
                if record.relation=="root" or prefix(record.path,destination.path) then return nil,"cyclic-condition-transfer" end
            end
            local field=destination.field or "value"
            local kind
            if (target.type=="AND" or target.type=="OR") and field=="value" then kind="condition[]"
            elseif target.type=="NOT" and field=="value" then kind="condition"
            else kind=(declarations[target.type] or {})[field] end
            if not kind then return nil,"invalid-condition-destination" end
            local nodes={};for _,record in ipairs(records) do nodes[#nodes+1]=record.node end
            if kind=="condition[]" then
                local list=target[field] or {};local index=destination.index or #list+1
                if type(index)~="number" or index%1~=0 or index<1 or index>#list+1 then return nil,"invalid-condition-destination" end
                local adjusted=index
                for _,record in ipairs(records) do if record.container==list and record.key<index then adjusted=adjusted-1 end end
                remove(records);target[field]=list
                for i,node in ipairs(nodes) do table.insert(list,adjusted+i-1,node) end
            else
                if #records~=1 or destination.index~=nil or (target[field] and next(target[field])~=nil) then return nil,"occupied-condition-slot" end
                remove(records);target[field]=nodes[1]
            end
            return candidate,nil,locations(candidate,nodes)
        end)
    end
    function draft:AddSibling(path,value)
        local child,why=copy(value==nil and {} or value)
        if type(child)~="table" then return nil,why or "invalid-condition" end
        return edit(path,function(node,container,key,relation,candidate)
            if relation=="list" then table.insert(container,key+1,child)
            elseif next(node)==nil then candidate=replace(container,key,child,candidate)
            else candidate=replace(container,key,{type="AND",value={node,child}},candidate) end
            return candidate,nil,locations(candidate,{child})
        end)
    end
    function draft:Duplicate(path)
        return edit(path,function(node,container,key,relation,candidate)
            local child=assert(copy(node))
            if relation=="list" then table.insert(container,key+1,child)
            else candidate=replace(container,key,{type="AND",value={node,child}},candidate) end
            return candidate,nil,locations(candidate,{child})
        end)
    end
    function draft:Insert(destination,value)
        if type(destination)~="table" or not data.CheckPortable(destination) then return nil,"invalid-condition-destination" end
        local child,why=copy(value==nil and {} or value)
        if type(child)~="table" then return nil,why or "invalid-condition" end
        return edit(destination.path,function(node,container,key,relation,candidate)
            if destination.relation then
                if destination.relation~="before" and destination.relation~="after" then return nil,"invalid-condition-destination" end
                local before=destination.relation=="before"
                if relation=="list" then table.insert(container,key+(before and 0 or 1),child)
                else
                    local values=before and {child,node} or {node,child}
                    candidate=replace(container,key,{type="AND",value=values},candidate)
                end
            elseif next(node)==nil and destination.field==nil and destination.index==nil then
                candidate=replace(container,key,child,candidate)
            else
                local field=destination.field or "value";local kind
                if (node.type=="AND" or node.type=="OR") and field=="value" then kind="condition[]"
                elseif node.type=="NOT" and field=="value" then kind="condition"
                else kind=(declarations[node.type] or {})[field] end
                if kind=="condition[]" then
                    local list=node[field] or {};local index=destination.index or #list+1
                    if type(index)~="number" or index%1~=0 or index<1 or index>#list+1 then return nil,"invalid-condition-destination" end
                    table.insert(list,index,child);node[field]=list
                elseif kind=="condition" then
                    if destination.index~=nil or (node[field] and next(node[field])~=nil) then return nil,"occupied-condition-slot" end
                    node[field]=child
                else return nil,"invalid-condition-destination" end
            end
            return candidate,nil,locations(candidate,{child})
        end)
    end
    function draft:SetName(path,name)
        if type(name)~="string" or #name>512 or name:find("%c") then return nil,"invalid-condition-name" end
        name=name:match("^%s*(.-)%s*$")
        return edit(path,function(node,_,_,_,candidate)
            if node.type~="AND" and node.type~="OR" and node.type~="NOT" then return nil,"not-a-condition-group" end
            node.name=name~="" and name or nil;return candidate
        end)
    end
    function draft:SetGroupType(path,kind)
        if kind~="AND" and kind~="OR" then return nil,"invalid-condition-group" end
        return edit(path,function(node,_,_,_,candidate)
            if node.type~="AND" and node.type~="OR" then return nil,"not-a-condition-group" end
            node.type=kind;return candidate
        end)
    end
    function draft:Rows(limit)
        limit=type(limit)=="number" and limit==limit and limit%1==0 and math.max(1,math.min(4096,limit)) or 200
        local rows,complete={},true
        local function visit(node,path,depth)
            if #rows>=limit then complete=false;return end
            local children=edges(node)
            rows[#rows+1]={path=pathCopy(path),type=node.type,disabled=node.disabled==true,
                invalidDisabled=node.disabled~=nil and type(node.disabled)~="boolean",depth=depth,childCount=#children}
            for _,edge in ipairs(children) do
                local childPath=pathCopy(path)
                for _,part in ipairs(edge.parts) do childPath[#childPath+1]=part end
                visit(edge.node,childPath,depth+1)
                if not complete then break end
            end
        end
        visit(root,{},0);return rows,complete
    end
    return draft
end
