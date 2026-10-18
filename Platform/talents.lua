local _,addon=...
local platform=addon.Platform
local function integer(value,minimum,maximum)
    return platform:CanReadValue(value) and type(value)=="number" and value>=minimum and value<=maximum and value%1==0
end
local function groupValid(group) return group==nil or integer(group,1,4) end
function platform:GetTalentLayout()
    local client=self:GetClientInfo()
    if client.family=="era" or client.family=="tbc" then return "tree" end
    if client.family=="retail" or client.family=="forever" then return "traits" end
    if client.family=="progression" then
        if client.expansion==2 or client.expansion==3 then return "tree" end
        if client.expansion==4 then return "grid" end
    end
    return nil,"unsupported-talent-layout"
end
local function layout(wanted)
    if platform:GetTalentLayout()~=wanted then return nil,"talent-layout-mismatch" end
    return true
end
local function count(fn,maximum,...)
    if type(fn)~="function" then return nil,"missing-api" end
    local ok,value=pcall(fn,...)
    if not ok then return nil,"api-error" end
    if not platform:CanReadValue(value) then return nil,"restricted-value" end
    if not integer(value,0,maximum) then return nil,"invalid-api-result" end
    return value
end
function platform:GetTalentTreeCount()
    local supported,reason=layout("tree");if not supported then return nil,reason end
    return count(GetNumTalentTabs,16,false,false)
end
function platform:GetTreeTalentCount(tree)
    local supported,reason=layout("tree");if not supported then return nil,reason end
    if not integer(tree,1,16) then return nil,"invalid-talent-tree" end
    return count(GetNumTalents,256,tree,false,false)
end
local function treeMetadata(name,icon,points)
    for _,value in pairs({name=name,icon=icon,points=points}) do
        if not platform:CanReadValue(value) then return nil,"restricted-value" end
    end
    if type(name)~="string" or name=="" then return nil,"invalid-api-result" end
    if icon~=nil and not integer(icon,0,2147483647) and type(icon)~="string" then return nil,"invalid-api-result" end
    if points~=nil and not integer(points,0,512) then return nil,"invalid-api-result" end
    return {name=name,icon=icon,pointsSpent=points}
end
function platform:GetTalentTreeInfo(tree,group)
    local supported,reason=layout("tree");if not supported then return nil,reason end
    if not integer(tree,1,16) or not groupValid(group) then return nil,"invalid-talent-query" end
    local native=C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo
    local fn=native or GetTalentTabInfo
    if type(fn)~="function" then return nil,"missing-api" end
    if native then
        local ok,_,name,_,icon,_,_,points=pcall(fn,tree,false,false,nil,nil,group)
        if not ok then return nil,"api-error" end
        return treeMetadata(name,icon,points)
    end
    local ok,first,second,third,fourth,fifth=pcall(fn,tree,false,false,group)
    if not ok then return nil,"api-error" end
    if not self:CanReadValue(first) then return nil,"restricted-value" end
    -- Historical APIs returned name first; current deprecated wrappers return ID first.
    if type(first)=="string" then return treeMetadata(first,second,third) end
    if type(first)=="number" then return treeMetadata(second,fourth,fifth) end
    return nil,"talent-data-unavailable"
end
local function identity(data)
    if not platform:CanReadValue(data) then return nil,"restricted-value" end
    if type(data)~="table" then return nil,"talent-data-unavailable" end
    for _,key in ipairs({"name","icon","talentID","spellID"}) do
        if not platform:CanReadValue(data[key]) then return nil,"restricted-value" end
    end
    if type(data.name)~="string" or data.name=="" then return nil,"invalid-api-result" end
    if data.icon~=nil and not integer(data.icon,0,2147483647) and type(data.icon)~="string" then return nil,"invalid-api-result" end
    local result={name=data.name,icon=data.icon}
    for _,key in ipairs({"talentID","spellID"}) do
        local id=data[key]
        if id~=nil then
            if not integer(id,0,2147483647) then return nil,"invalid-api-result" end
            if id>0 then result[key]=id end
        end
    end
    return result
end
local function legacyTreeRecord(fn,...)
    local tuple={fn(...)}
    return {name=tuple[1],icon=tuple[2],rank=tuple[5],maxRank=tuple[6],talentID=tuple[12]}
end
function platform:GetTreeTalentInfo(tree,talent,group)
    local supported,reason=layout("tree");if not supported then return nil,reason end
    if not integer(tree,1,16) or not integer(talent,1,256) or not groupValid(group) then return nil,"invalid-talent-query" end
    local native=C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo
    local ok,data
    if type(native)=="function" then
        ok,data=pcall(native,{specializationIndex=tree,talentIndex=talent,groupIndex=group,isInspect=false,isPet=false})
    elseif type(GetTalentInfo)=="function" then
        ok,data=pcall(legacyTreeRecord,GetTalentInfo,tree,talent,false,false,group)
    else return nil,"missing-api" end
    if not ok then return nil,"api-error" end
    local result,why=identity(data)
    if not result then return nil,why end
    if not self:CanReadValue(data.rank) or not self:CanReadValue(data.maxRank) then return nil,"restricted-value" end
    if not integer(data.maxRank,1,64) or not integer(data.rank,0,data.maxRank) then return nil,"invalid-api-result" end
    result.rank,result.maxRank=data.rank,data.maxRank
    return result
end
function platform:GetGridTalentInfo(index,group)
    local supported,reason=layout("grid");if not supported then return nil,reason end
    if not integer(index,1,18) or not groupValid(group) then return nil,"invalid-talent-query" end
    local fn=C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo
    if type(fn)~="function" then return nil,"missing-api" end
    local ok,data=pcall(fn,{tier=math.floor((index-1)/3)+1,column=((index-1)%3)+1,groupIndex=group,isInspect=false})
    if not ok then return nil,"api-error" end
    local result,why=identity(data)
    if not result then return nil,why end
    if not self:CanReadValue(data.selected) then return nil,"restricted-value" end
    if type(data.selected)~="boolean" or not result.talentID or not result.spellID then return nil,"invalid-api-result" end
    result.selected=data.selected
    return result
end
