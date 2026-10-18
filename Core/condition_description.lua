local addon_name,addon=...
local L=LibStub("AceLocale-3.0"):GetLocale(addon_name)
local function needsDataOnly(value,definitions)
    local count=0
    local function inspect(node,depth)
        count=count+1
        if count>4096 or depth>32 then return true end
        if type(node)~="table" then return false end
        if node.disabled then return true end
        if node.type=="NOT" and (type(node.value)~="table" or node.value.type==nil) then return true end
        if node.type=="AND" or node.type=="OR" then
            if type(node.value)~="table" or next(node.value)==nil then return true end
            for _,operand in pairs(node.value) do if type(operand)~="table" or operand.type==nil then return true end end
        end
        local definition=type(node.type)=="string" and definitions[node.type]
        if definition and definition.customCode then return true end
        if node.type and node.type~="AND" and node.type~="OR" and node.type~="NOT" and not definition then return true end
        for _,child in pairs(node) do if inspect(child,depth+1) then return true end end
        return false
    end
    return inspect(value,0)
end
local function describeData(value,definitions)
    local count,truncated=0,false
    ---@param text string
    local function bounded(text)
        if #text>8000 then truncated=true;return text:sub(1,8000) end
        return text
    end
    local function render(node,depth)
        count=count+1
        if count>200 or depth>16 then truncated=true;return "..." end
        if node==nil then return L["Always"] end
        if type(node)~="table" then local text=tostring(node);if #text>160 then truncated=true end;return text:sub(1,160) end
        if next(node)==nil then return L["Always"] end
        if node.type=="AND" or node.type=="OR" or node.type=="NOT" then
            local text
            if type(node.value)~="table" then text=L["Incomplete condition group: choose its conditions."]
            elseif node.type=="NOT" then text=L["NOT"].." ("..render(node.value,depth+1)..")"
            else
                local parts={}
                for _,operand in ipairs(node.value) do
                    if count>=200 then truncated=true;parts[#parts+1]="...";break end
                    parts[#parts+1]=render(operand,depth+1)
                end
                if #parts==0 then text=node.type=="AND" and L["Always (empty All group)"] or L["Never (empty Any group)"]
                else text=(node.type=="AND" and L["All"] or L["Any"]).." ("..table.concat(parts,"; ")..")" end
            end
            if type(node.name)=="string" and node.name~="" then text=node.name:sub(1,512)..": "..text end
            if node.disabled then text=L["Disabled"]..": "..text end
            return bounded(text)
        end
        local definition=type(node.type)=="string" and definitions[node.type]
        local title=definition and type(definition.description)=="string" and definition.description or node.type
        local parts={type(title)=="string" and title:sub(1,160) or ""}
        local keys={};for key in pairs(node) do if key~="type" then keys[#keys+1]=key end end
        table.sort(keys,function(a,b) if type(a)==type(b) then return a<b end;return type(a)=="number" end)
        for _,key in ipairs(keys) do
            if count>=200 then truncated=true;parts[#parts+1]="...";break end
            parts[#parts+1]=tostring(key):sub(1,80)..": "..render(node[key],depth+1)
        end
        return bounded(table.concat(parts,"; "))
    end
    local text=render(value,0):gsub("|","||")
    return text,truncated
end
function addon:DescribeCondition(condition,spec)
    if self.RotationData and not self.RotationData.CheckPortable(condition) then return L["Condition description unavailable: invalid data."] end
    if type(condition)=="table" and next(condition)==nil then return L["Always"] end
    local definitions=self.conditionDefinitions or self.definitions or {}
    local text,truncated
    if not needsDataOnly(condition,definitions) then
        local value=self.RotationData and self.RotationData.CopyData(condition) or condition
        local ok,result=pcall(self.printCondition,self,value,spec)
        if ok and type(result)=="string" and result~="" then text=result end
    end
    if not text then
        text,truncated=describeData(condition,definitions)
        text=L["Condition reference (code is not run)."].." "..text
    end
    if #text>64000 then text=text:sub(1,64000);truncated=true end
    if truncated then text=text.."\n"..L["Condition description truncated; the draft is unchanged."] end
    return text
end

-- Disabled is a visual state on cards. Remove only flags on semantic condition
-- nodes in a detached copy; opaque custom payloads remain intact and data-only.
function addon:DescribeCardCondition(condition,spec)
    if not self.RotationData.CheckPortable(condition) then return self:DescribeCondition(condition,spec) end
    local value=self.RotationData.CopyData(condition)
    local function strip(node,depth)
        if type(node)~="table" or depth>32 then return end
        node.disabled=nil
        if node.type=="AND" or node.type=="OR" then
            for _,child in ipairs(type(node.value)=="table" and node.value or {}) do strip(child,depth+1) end
        elseif node.type=="NOT" then strip(node.value,depth+1) end
    end
    strip(value,0)
    return self:DescribeCondition(value,spec)
end
