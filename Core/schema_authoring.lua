local _,addon=...
local function copy(value) return addon:CopySettingsData(value) end
local function pathKey(path) local parts={};for _,key in ipairs(path) do parts[#parts+1]=type(key)..':'..tostring(key) end;return table.concat(parts,'/') end
function addon:IsEditableFieldSchemaName(name,root)
    return type(name)=='string' and #name<=64 and name:match('^[%a_][%w_]*$')~=nil and not (root and (name=='type' or name=='disabled'))
end
function addon:NormalizeCustomFieldOrder(order,fields)
    if order==nil then return {} end
    if type(order)~='table' or getmetatable(order) then return nil,'invalid-field-order' end
    local seen,result={},{};local entries=0
    for index,path in pairs(order) do
        entries=entries+1
        if type(index)~='number' or index%1~=0 or index<1 or index>#order or index>4096 or type(path)~='table' or getmetatable(path) or #path==0 or #path>64 then return nil,'invalid-field-order' end
        local value=fields;local parts=0
        for i,key in pairs(path) do
            parts=parts+1
            if type(i)~='number' or i%1~=0 or i<1 or i>#path or (type(key)~='string' and type(key)~='number') then return nil,'invalid-field-order' end
        end
        if parts~=#path then return nil,'invalid-field-order' end
        for _,key in ipairs(path) do value=type(value)=='table' and value[key] or nil;if value==nil then return nil,'invalid-field-order' end end
        local key=pathKey(path);if seen[key] then return nil,'invalid-field-order' end;seen[key]=true;result[index]=copy(path)
    end
    if entries~=#order then return nil,'invalid-field-order' end
    return result
end
-- A schema is data: records have named children; numeric children describe
-- alternatives, including list element schemas. Lua source is never evaluated.
function addon:NewFieldSchemaDraft(fields,fieldOrder)
    local normalized,why=self:NormalizeCustomFieldSchema(fields,true);if not normalized then return nil,why end
    local order,errorCode=self:NormalizeCustomFieldOrder(fieldOrder,normalized);if not order then return nil,errorCode end
    local ranks={};for i,path in ipairs(order) do ranks[pathKey(path)]=i end
    local function build(value,path,name)
        if type(value)=='string' then return {name=name,kind=value} end
        local node={name=name,kind=value[1]~=nil and 'union' or 'record',children={}};local keys={}
        for key in pairs(value) do keys[#keys+1]=key end
        table.sort(keys,function(a,b)
            if type(a)=='number' then return a<b end
            local pa=copy(path);pa[#pa+1]=a;local pb=copy(path);pb[#pb+1]=b
            local ra,rb=ranks[pathKey(pa)] or math.huge,ranks[pathKey(pb)] or math.huge
            if ra~=rb then return ra<rb end;return a<b
        end)
        for _,key in ipairs(keys) do local nextPath=copy(path);nextPath[#nextPath+1]=key;node.children[#node.children+1]=build(value[key],nextPath,key) end
        return node
    end
    local d={root=build(normalized,{}),undo={},redo={},revision=0}
    function d:Change(fn)
        local before=copy(self.root);fn(self.root)
        if addon:SettingsDataEqual(before,self.root) then return false end
        self.revision=self.revision+1;self.undo[#self.undo+1]=before;self.redo={};while #self.undo>50 do table.remove(self.undo,1) end;return true
    end
    function d:Travel(redo)
        local from=redo and self.redo or self.undo;local to=redo and self.undo or self.redo
        if #from==0 then return false end;to[#to+1]=copy(self.root);self.root=table.remove(from);self.revision=self.revision+1;return true
    end
    function d:Node(path)
        local node=self.root
        for _,index in ipairs(path) do
            if type(index)~='number' or index%1~=0 or not node.children then return end
            node=node.children[index];if not node then return end
        end
        return node
    end
    local function parentPath(path) local result=copy(path);table.remove(result);return result end
    local function uniqueName(parent,base,except)
        base=type(base)=='string' and base:match('^[%a_][%w_]*$') and base or 'field'
        if parent==d.root and (base=='type' or base=='disabled') then base='field' end
        local used={};for _,child in ipairs(parent.children) do if child~=except then used[child.name]=true end end
        base=base:sub(1,64);local name=base;local suffix=1
        while used[name] do suffix=suffix+1;local ending='_'..suffix;name=base:sub(1,64-#ending)..ending end;return name
    end
    function d:Add(path,kind)
        local parent=self:Node(path);if not parent or not parent.children then return false end
        return self:Change(function() parent.children[#parent.children+1]={name=uniqueName(parent,'field'),kind=kind or 'string',children=(kind=='record' or kind=='union') and {{name='field',kind='string'}} or nil} end)
    end
    function d:Duplicate(path)
        local node=self:Node(path);local parent=self:Node(parentPath(path));if #path==0 or not node or not parent then return false end
        return self:Change(function()
            local duplicate=copy(node);if parent.kind=='record' then duplicate.name=uniqueName(parent,tostring(node.name):sub(1,59)..'_copy') end
            table.insert(parent.children,path[#path]+1,duplicate)
        end)
    end
    function d:Remove(path)
        if #path==0 or not self:Node(path) then return false end;local parent=self:Node(parentPath(path))
        return self:Change(function() table.remove(parent.children,path[#path]) end)
    end
    function d:SetKind(path,kind)
        local node=self:Node(path);if not node or #path==0 then return false end
        if kind~='record' and kind~='union' and kind~='string' and kind~='number' and kind~='boolean' and kind~='condition' and kind~='condition[]' then return false end
        return self:Change(function()
            node.kind=kind
            if kind=='record' or kind=='union' then
                node.children=node.children or {{name='field',kind='string'}}
                if kind=='record' then
                    local used={}
                    for i,child in ipairs(node.children) do
                        local base=type(child.name)=='string' and child.name:match('^[%a_][%w_]*$') and child.name or 'field'..i
                        local name=base;local suffix=1;while used[name] do suffix=suffix+1;name=base..'_'..suffix end
                        child.name=name;used[name]=true
                    end
                end
            else node.children=nil end
        end)
    end
    function d:CanTransfer(path,destination,gap,tail)
        if #path==0 or not self:Node(path) then return false end
        local parent=self:Node(parentPath(path));local target=self:Node(destination);local index=path[#path]
        if not target or not target.children or type(gap)~='number' or gap%1~=0 or gap<1 or gap>#target.children+1 then return false end
        local last=tail and #parent.children or index
        if target==parent and gap>=index and gap<=last+1 then return false end
        -- A container always carries its descendants. Never insert it inside itself.
        if #destination>=#path then
            local sameParent=true;for i=1,#path-1 do if destination[i]~=path[i] then sameParent=false end end
            if sameParent and destination[#path]>=index and destination[#path]<=last then return false end
        end
        if target~=parent and target.kind=='record' then
            local used={};for _,child in ipairs(target.children) do used[child.name]=true end
            for i=index,last do local name=parent.children[i].name
                if type(name)=='string' then if used[name] then return false end;used[name]=true end
            end
        end
        return true
    end
    function d:Transfer(path,destination,gap,tail)
        if not self:CanTransfer(path,destination,gap,tail) then return false end
        local parent=self:Node(parentPath(path));local target=self:Node(destination);local index=path[#path];local count=tail and #parent.children-index+1 or 1
        return self:Change(function()
            local moved={};for _=1,count do moved[#moved+1]=table.remove(parent.children,index) end
            if parent==target and gap>index then gap=gap-count end
            for i,node in ipairs(moved) do
                if target.kind=='record' and type(node.name)~='string' then node.name=uniqueName(target,'field') end
                table.insert(target.children,gap+i-1,node)
            end
        end)
    end
    function d:Snapshot()
        local order={};local count=0;local active={}
        local function encode(node,path,depth)
            count=count+1;if count>512 or depth>16 or active[node] then error('schema-limit',0) end
            if node.kind~='record' and node.kind~='union' then return node.kind end
            active[node]=true;local result={}
            for i,child in ipairs(node.children) do
                local key=node.kind=='record' and child.name or i
                if node.kind=='record' and not addon:IsEditableFieldSchemaName(key,depth==0) then error('invalid-field-name',0) end
                if result[key]~=nil then error('duplicate-field',0) end
                local nextPath=copy(path);nextPath[#nextPath+1]=key;order[#order+1]=nextPath;result[key]=encode(child,nextPath,depth+1)
            end
            active[node]=nil;return result
        end
        local ok,value=pcall(encode,self.root,{},0);if not ok then return nil,value end
        local checked,problem=addon:NormalizeCustomFieldSchema(value);if not checked then return nil,problem end
        return checked,order
    end
    return d
end
