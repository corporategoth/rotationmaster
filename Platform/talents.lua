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
-- Forever's classic trees are trait node groups (GetTraitTreeGroups below);
-- the tree count, tree names and points read them there. Retail has none.
local function traitTrees()
    local family=platform:GetClientFamily()
    if family~="forever" and family~="retail" then return false end
    return type(C_Traits)=="table" and type(C_Traits.GetGroupDisplayInfoByTreeID)=="function"
end
function platform:GetTalentTreeCount()
    if traitTrees() then
        local groups,why=self:GetTraitTreeGroups();if not groups then return nil,why end
        return #groups
    end
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
    if traitTrees() then
        if not integer(tree,1,16) or not groupValid(group) then return nil,"invalid-talent-query" end
        local groups,why=self:GetTraitTreeGroups();if not groups then return nil,why end
        local found=groups[tree]
        if not found then return nil,"talent-tree-unavailable" end
        return {name=found.name,icon=found.icon,pointsSpent=found.pointsSpent}
    end
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
function platform:GetPrimaryTalentTree(group)
    if not groupValid(group) then return nil,'invalid-talent-query' end
    local count,reason=self:GetTalentTreeCount();if count==nil then return nil,reason end
    local best,maximum,tied=nil,0,false
    for index=1,count do
        local info,why=self:GetTalentTreeInfo(index,group)
        if not info then return nil,why end
        if not integer(info.pointsSpent,0,512) then return nil,'talent-points-unavailable' end
        if info.pointsSpent>maximum then best=info;best.index=index;maximum=info.pointsSpent;tied=false
        elseif info.pointsSpent==maximum and maximum>0 then tied=true end
    end
    if maximum==0 then return nil,'no-talents-spent' end
    if tied then return nil,'ambiguous-primary-talent-tree' end
    return best
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

-- Trait talents (Retail and Forever: the "traits" layout).
--
-- Contract (Blizzard's generated API documentation, Gethe/wow-ui-source
-- forever ca8368f2 (1.60.1) and live, Blizzard_APIDocumentationGenerated/
-- ClassTalentsDocumentation.lua and SharedTraitsDocumentation.lua, read
-- 2026-10-23). None of these returns is declared secret; every value is still
-- readability-checked.
--   C_ClassTalents.GetActiveConfigID() -> configID?
--   C_Traits.GetConfigInfo(configID) -> {ID, type, name, treeIDs}
--   C_Traits.GetTreeNodes(treeID) -> nodeIDs
--   C_Traits.GetNodeInfo(configID, nodeID) -> TraitNodeInfo {ID, posX, posY,
--     entryIDs, isVisible, activeRank, ranksPurchased, maxRanks,
--     activeEntry={entryID, rank}?, groupIDs, subTreeID?, subTreeActive?}
--     (ID is 0 for a node the config does not contain)
--   C_Traits.GetEntryInfo(configID, entryID) -> {definitionID?, maxRanks, type}
--   C_Traits.GetDefinitionInfo(definitionID) -> {spellID?, overrideName?, overrideIcon?}
--   C_Traits.GetSubTreeInfo(configID, subTreeID) -> {name, ...}
-- Forever only (absent on live): the three classic trees are node groups of
-- one trait tree. Blizzard_PlayerSpells/Camelot/ClassTalents/
-- Blizzard_ClassTalentsFrame.lua draws one header per
--   C_Traits.GetGroupDisplayInfoByTreeID(treeID) -> {groupID, treeID,
--     skillLineID, orderIndex, displayName, icon}[]
-- showing GetGroupCurrencyInfo(configID, groupIDs)[i].currencyInfos[1].spent
-- as the points spent in that tree.
local function traitID(value)
    return platform:CanReadValue(value) and type(value)=='number' and value>0 and value<2147483648 and value%1==0
end
local function traits(name,...)
    local namespace=C_Traits
    local fn=type(namespace)=='table' and namespace[name] or nil
    if type(fn)~='function' then return false,'missing-api' end
    local ok,value=pcall(fn,...)
    if not ok then return false,'api-error' end
    if not platform:CanReadValue(value) then return false,'restricted-value' end
    return true,value
end
local function traitsLayout()
    local family=platform:GetClientFamily()
    if family~='retail' and family~='forever' then return nil,'talent-layout-mismatch' end
    return true
end

-- The active trait config and its talent tree.
function platform:GetActiveTraitConfig()
    local supported,reason=traitsLayout();if not supported then return nil,reason end
    local namespace=C_ClassTalents
    local fn=type(namespace)=='table' and namespace.GetActiveConfigID or nil
    if type(fn)~='function' then return nil,'missing-api' end
    local ok,config=pcall(fn)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(config) then return nil,'restricted-value' end
    if config==nil then return nil,'talent-config-unavailable' end
    if not traitID(config) then return nil,'invalid-api-result' end
    local okInfo,info=traits('GetConfigInfo',config)
    if not okInfo then return nil,info end
    if type(info)~='table' or type(info.treeIDs)~='table' then return nil,'talent-config-unavailable' end
    local tree=info.treeIDs[1]
    if not self:CanReadValue(tree) then return nil,'restricted-value' end
    if not traitID(tree) then return nil,'talent-config-unavailable' end
    return config,tree
end

-- Forever's trees: the node groups of the class trait tree in display order,
-- each {groupID, name, icon, pointsSpent}. Retail has no such groups.
function platform:GetTraitTreeGroups(config,tree)
    local supported,reason=traitsLayout();if not supported then return nil,reason end
    if config==nil then config,tree=self:GetActiveTraitConfig();if not config then return nil,tree end end
    if not traitID(config) or not traitID(tree) then return nil,'invalid-talent-query' end
    local ok,displays=traits('GetGroupDisplayInfoByTreeID',tree)
    if not ok then return nil,displays end
    if type(displays)~='table' then return nil,'invalid-api-result' end
    local groups,ids={},{}
    for index=1,#displays do
        local display=displays[index]
        if not self:CanReadValue(display) or type(display)~='table' then return nil,'restricted-value' end
        for _,key in ipairs({'groupID','orderIndex','displayName','icon'}) do
            if not self:CanReadValue(display[key]) then return nil,'restricted-value' end
        end
        if not traitID(display.groupID) or type(display.displayName)~='string' or display.displayName=='' then return nil,'invalid-api-result' end
        groups[#groups+1]={groupID=display.groupID,name=display.displayName,icon=display.icon,
            order=type(display.orderIndex)=='number' and display.orderIndex or index,position=index}
        ids[#ids+1]=display.groupID
    end
    if #groups==0 or #groups>16 then return nil,'talent-groups-unavailable' end
    table.sort(groups,function(a,b) if a.order~=b.order then return a.order<b.order end return a.position<b.position end)
    local okSpent,currencies=traits('GetGroupCurrencyInfo',config,ids)
    if not okSpent then return nil,currencies end
    if type(currencies)~='table' then return nil,'invalid-api-result' end
    local spent={}
    for index=1,#currencies do
        local info=currencies[index]
        if not self:CanReadValue(info) or type(info)~='table' then return nil,'restricted-value' end
        local list=info.currencyInfos
        if not self:CanReadValue(info.traitNodeGroupID) or not self:CanReadValue(list) then return nil,'restricted-value' end
        local first=type(list)=='table' and list[1] or nil
        local points=0
        if first~=nil then
            if not self:CanReadValue(first) or type(first)~='table' or not self:CanReadValue(first.spent) then return nil,'restricted-value' end
            if not integer(first.spent,0,512) then return nil,'invalid-api-result' end
            points=first.spent
        end
        if traitID(info.traitNodeGroupID) then spent[info.traitNodeGroupID]=points end
    end
    -- The Blizzard header shows 0 for a group with no currency record.
    for _,group in ipairs(groups) do group.pointsSpent=spent[group.groupID] or 0;group.order,group.position=nil,nil end
    return groups
end

-- One node's committed state in a config: rank (0 when the node's hero
-- subtree is not chosen), the active entry and the maximum rank.
function platform:GetTraitNodeState(config,node)
    local supported,reason=traitsLayout();if not supported then return nil,reason end
    if not traitID(config) or not traitID(node) then return nil,'invalid-talent-query' end
    local ok,info=traits('GetNodeInfo',config,node)
    if not ok then return nil,info end
    if type(info)~='table' then return nil,'talent-node-unavailable' end
    for _,key in ipairs({'ID','activeRank','maxRanks','activeEntry','subTreeID','subTreeActive'}) do
        if not self:CanReadValue(info[key]) then return nil,'restricted-value' end
    end
    if info.ID~=node then return nil,'talent-node-unavailable' end
    if not integer(info.maxRanks,0,64) or not integer(info.activeRank,0,64) then return nil,'invalid-api-result' end
    local entry
    if info.activeEntry~=nil then
        if type(info.activeEntry)~='table' or not self:CanReadValue(info.activeEntry.entryID) then return nil,'restricted-value' end
        if traitID(info.activeEntry.entryID) then entry=info.activeEntry.entryID end
    end
    local rank=info.activeRank
    if info.subTreeID~=nil and info.subTreeActive~=true then rank=0 end
    return {rank=rank,entry=entry,maxRanks=info.maxRanks}
end

-- A trait entry's display identity: name, icon and spell ID.
function platform:GetTraitEntryIdentity(config,entry)
    if not traitID(config) or not traitID(entry) then return nil,'invalid-talent-query' end
    local ok,info=traits('GetEntryInfo',config,entry)
    if not ok then return nil,info end
    if type(info)~='table' or not self:CanReadValue(info.definitionID) or not self:CanReadValue(info.maxRanks) then return nil,'restricted-value' end
    if not traitID(info.definitionID) then return nil,'talent-entry-unavailable' end
    local okDef,definition=traits('GetDefinitionInfo',info.definitionID)
    if not okDef then return nil,definition end
    if type(definition)~='table' then return nil,'talent-entry-unavailable' end
    for _,key in ipairs({'spellID','overrideName','overrideIcon'}) do
        if not self:CanReadValue(definition[key]) then return nil,'restricted-value' end
    end
    local spell=traitID(definition.spellID) and definition.spellID or nil
    local name=type(definition.overrideName)=='string' and definition.overrideName~='' and definition.overrideName or nil
    local icon=definition.overrideIcon
    if spell and (name==nil or icon==nil) and self.GetSpellInfo then
        local spellInfo=self:GetSpellInfo(spell)
        if spellInfo then name=name or spellInfo.name;icon=icon or spellInfo.iconID end
    end
    if not name then return nil,'talent-entry-unavailable' end
    return {name=name,icon=icon,spellID=spell,maxRanks=integer(info.maxRanks,0,64) and info.maxRanks or nil}
end

-- A node's display identity (its chosen entry, else the given or first one).
function platform:GetTraitTalentIdentity(node,entry)
    local config,why=self:GetActiveTraitConfig();if not config then return nil,why end
    if not traitID(node) then return nil,'invalid-talent-query' end
    if entry==nil then
        local ok,info=traits('GetNodeInfo',config,node)
        if not ok then return nil,info end
        if type(info)~='table' or not self:CanReadValue(info.ID) or info.ID~=node or not self:CanReadValue(info.entryIDs) then return nil,'talent-node-unavailable' end
        local active=info.activeEntry
        if type(active)=='table' and self:CanReadValue(active.entryID) and traitID(active.entryID) then entry=active.entryID
        elseif type(info.entryIDs)=='table' and self:CanReadValue(info.entryIDs[1]) and traitID(info.entryIDs[1]) then entry=info.entryIDs[1] end
        if entry==nil then return nil,'talent-node-unavailable' end
    end
    return self:GetTraitEntryIdentity(config,entry)
end

-- The character's talents for the editor, grouped: by tree on Forever, by
-- hero subtree (else one "Talents" group, groupName nil) on Retail. Each
-- talent is {node, entry (choice nodes only), name, icon, spellID, maxRanks}.
function platform:GetTraitTalents()
    local config,tree=self:GetActiveTraitConfig();if not config then return nil,tree end
    local ok,nodes=traits('GetTreeNodes',tree)
    if not ok then return nil,nodes end
    if type(nodes)~='table' then return nil,'invalid-api-result' end
    local trees=self:GetTraitTreeGroups(config,tree)
    local groupIndex={}
    for index,group in ipairs(trees or {}) do groupIndex[group.groupID]=index end
    local groups,byKey={},{}
    local function groupFor(key,name)
        local group=byKey[key]
        if not group then group={key=key,name=name,talents={}};byKey[key]=group;groups[#groups+1]=group end
        return group
    end
    for _,group in ipairs(trees or {}) do groupFor('group:'..group.groupID,group.name) end
    for index=1,#nodes do
        local node=nodes[index]
        local okNode,info=traits('GetNodeInfo',config,node)
        if okNode and type(info)=='table' and self:CanReadValue(info.ID) and info.ID==node and self:CanReadValue(info.isVisible)
            and info.isVisible~=false and self:CanReadValue(info.entryIDs) and type(info.entryIDs)=='table' then
            local key,name='talents',nil
            if self:CanReadValue(info.groupIDs) and type(info.groupIDs)=='table' then
                for _,id in ipairs(info.groupIDs) do
                    if self:CanReadValue(id) and groupIndex[id] then key,name='group:'..id,trees[groupIndex[id]].name;break end
                end
            end
            if key=='talents' and self:CanReadValue(info.subTreeID) and traitID(info.subTreeID) then
                local okSub,sub=traits('GetSubTreeInfo',config,info.subTreeID)
                if okSub and type(sub)=='table' and self:CanReadValue(sub.name) and type(sub.name)=='string' and sub.name~='' then
                    key,name='subtree:'..info.subTreeID,sub.name
                end
            end
            local choice=#info.entryIDs>1
            for _,entry in ipairs(info.entryIDs) do
                local identity=self:CanReadValue(entry) and self:GetTraitEntryIdentity(config,entry)
                if identity then
                    identity.node,identity.entry=node,choice and entry or nil
                    identity.y=self:CanReadValue(info.posY) and type(info.posY)=='number' and info.posY or 0
                    identity.x=self:CanReadValue(info.posX) and type(info.posX)=='number' and info.posX or 0
                    local list=groupFor(key,name).talents
                    list[#list+1]=identity
                end
            end
        end
    end
    local result={}
    for _,group in ipairs(groups) do
        table.sort(group.talents,function(a,b)
            if a.y~=b.y then return a.y<b.y end
            if a.x~=b.x then return a.x<b.x end
            return (a.entry or 0)<(b.entry or 0)
        end)
        for _,talent in ipairs(group.talents) do talent.x,talent.y=nil,nil end
        if #group.talents>0 then result[#result+1]={name=group.name,talents=group.talents} end
    end
    return result
end
