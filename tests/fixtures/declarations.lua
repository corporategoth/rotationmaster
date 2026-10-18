-- Offline guard for the documented condition declaration grammar. This checks
-- declarations, not player data, and never executes custom-condition source.
return function(fields)
    local active, nodes = {}, 0
    local kinds = {string=true, number=true, boolean=true, condition=true, ['condition[]']=true}
    local checkType, checkTable
    checkTable = function(value, path, depth, root)
        if depth > 32 then return false, 'declaration-depth', path end
        if type(value) ~= 'table' then return false, 'expected-declaration-table', path end
        if active[value] then return false, 'declaration-cycle', path end
        active[value] = true
        local count, numeric, named, maximum = 0, false, false, 0
        for key in pairs(value) do
            nodes=nodes+1
            if nodes>4096 then return false, 'declaration-size', path end
            count=count+1
            if type(key)=='string' and key:match('^[%a_][%w_]*$') then named=true
            elseif not root and type(key)=='number' and key>=1 and key<math.huge and key%1==0 then
                numeric=true;maximum=math.max(maximum,key)
            else return false, 'invalid-field-name', path end
        end
        if numeric and named or numeric and maximum~=count or not root and count==0 then
            return false, 'invalid-declaration-shape', path
        end
        for key, declaration in pairs(value) do
            local ok,reason,where=checkType(declaration,path..'.'..key,depth+1)
            if not ok then return false,reason,where end
        end
        active[value]=nil
        return true
    end
    checkType = function(value, path, depth)
        if type(value)=='string' then
            if kinds[value] then return true end
            return false,'unknown-field-type',path
        end
        if type(value)=='table' then return checkTable(value,path,depth,false) end
        return false,'invalid-field-type',path
    end
    return checkTable(fields,'fields',0,true)
end
