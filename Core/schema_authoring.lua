local _,addon=...
local function copy(value) return addon:CopySettingsData(value) end
local function pathKey(path) local parts={};for _,key in ipairs(path) do parts[#parts+1]=type(key)..':'..tostring(key) end;return table.concat(parts,'/') end
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
    local d={root=build(normalized,{}),undo={},redo={}}
    function d:Change(fn)
        local before=copy(self.root);fn(self.root)
        if addon:SettingsDataEqual(before,self.root) then return false end
        self.undo[#self.undo+1]=before;self.redo={};while #self.undo>50 do table.remove(self.undo,1) end;return true
    end
    function d:Travel(redo)
        local from=redo and self.redo or self.undo;local to=redo and self.undo or self.redo
        if #from==0 then return false end;to[#to+1]=copy(self.root);self.root=table.remove(from);return true
    end
    function d:Node(path) local node=self.root;for _,index in ipairs(path) do node=node.children and node.children[index];if not node then return end end;return node end
    function d:Snapshot()
        local order={};local count=0;local active={}
        local function encode(node,path,depth)
            count=count+1;if count>512 or depth>16 or active[node] then error('schema-limit',0) end
            if node.kind~='record' and node.kind~='union' then return node.kind end
            active[node]=true;local result={}
            for i,child in ipairs(node.children) do
                local key=node.kind=='record' and child.name or i
                if node.kind=='record' and (type(key)~='string' or not key:match('^[%a_][%w_]*$') or depth==0 and (key=='type' or key=='disabled')) then error('invalid-field-name',0) end
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
