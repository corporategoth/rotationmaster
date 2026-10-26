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
-- Blizzard's view loadout config (Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID,
-- TraitConstantsDocumentation.lua) has a negative ID; every other config is positive.
local VIEW_CONFIG=-3
local function traitConfig(value)
    return traitID(value) or (platform:CanReadValue(value) and value==VIEW_CONFIG)
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
-- subtree is not chosen), the active entry and the maximum rank. With
-- withEntries the node's entry IDs come back too (a fresh list), for matching
-- a saved spell ID against the node.
function platform:GetTraitNodeState(config,node,withEntries)
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
    local state={rank=rank,entry=entry,maxRanks=info.maxRanks}
    if withEntries then
        if not self:CanReadValue(info.entryIDs) or type(info.entryIDs)~='table' then return nil,'restricted-value' end
        local entries={}
        for _,id in ipairs(info.entryIDs) do
            if not self:CanReadValue(id) then return nil,'restricted-value' end
            if traitID(id) then entries[#entries+1]=id end
        end
        state.entries=entries
    end
    return state
end

-- A trait entry's definition: the spell ID it teaches and its display
-- overrides. Two C_Traits reads, no spell lookup.
local function entryDefinition(config,entry)
    if not traitConfig(config) or not traitID(entry) then return nil,'invalid-talent-query' end
    local ok,info=traits('GetEntryInfo',config,entry)
    if not ok then return nil,info end
    if type(info)~='table' or not platform:CanReadValue(info.definitionID) or not platform:CanReadValue(info.maxRanks) then return nil,'restricted-value' end
    if not traitID(info.definitionID) then return nil,'talent-entry-unavailable' end
    local okDef,definition=traits('GetDefinitionInfo',info.definitionID)
    if not okDef then return nil,definition end
    if type(definition)~='table' then return nil,'talent-entry-unavailable' end
    for _,key in ipairs({'spellID','overrideName','overrideIcon'}) do
        if not platform:CanReadValue(definition[key]) then return nil,'restricted-value' end
    end
    return info,definition
end

-- The spell ID a trait entry teaches, or nil and a reason.
function platform:GetTraitEntrySpell(config,entry)
    local info,definition=entryDefinition(config,entry)
    if not info then return nil,definition end
    if not traitID(definition.spellID) then return nil,'talent-entry-unavailable' end
    return definition.spellID
end

-- A trait entry's display identity: name, icon and spell ID. The name and icon
-- are the talent window's own: the definition's override, else the spell's name
-- and (original) icon (TalentUtil.GetTalentName, TalentButtonUtil.CalculateIconTexture).
function platform:GetTraitEntryIdentity(config,entry)
    local info,definition=entryDefinition(config,entry)
    if not info then return nil,definition end
    local spell=traitID(definition.spellID) and definition.spellID or nil
    local name=type(definition.overrideName)=='string' and definition.overrideName~='' and definition.overrideName or nil
    local icon=definition.overrideIcon
    if spell and (name==nil or icon==nil) then
        local spellInfo=self.GetSpellInfo and self:GetSpellInfo(spell)
        if spellInfo then name=name or spellInfo.name;icon=icon or spellInfo.originalIconID or spellInfo.iconID end
    end
    if not name then return nil,'talent-entry-unavailable' end
    return {name=name,icon=icon,spellID=spell,maxRanks=integer(info.maxRanks,0,64) and info.maxRanks or nil,
        entryType=platform:CanReadValue(info.type) and type(info.type)=='number' and info.type or nil}
end

-- A node's display identity (its chosen entry, else the given or first one).
-- A saved spell ID names the talent when the node is gone from the tree.
function platform:GetTraitTalentIdentity(node,entry,spell)
    local config,why=self:GetActiveTraitConfig();if not config then return nil,why end
    if not traitID(node) then return nil,'invalid-talent-query' end
    local identity,reason
    if entry==nil then
        local ok,info=traits('GetNodeInfo',config,node)
        if not ok then identity,reason=nil,info
        elseif type(info)~='table' or not self:CanReadValue(info.ID) or info.ID~=node or not self:CanReadValue(info.entryIDs) then reason='talent-node-unavailable'
        else
            local active=info.activeEntry
            if type(active)=='table' and self:CanReadValue(active.entryID) and traitID(active.entryID) then entry=active.entryID
            elseif type(info.entryIDs)=='table' and self:CanReadValue(info.entryIDs[1]) and traitID(info.entryIDs[1]) then entry=info.entryIDs[1] end
            if entry==nil then reason='talent-node-unavailable' end
        end
    end
    if entry~=nil then identity,reason=self:GetTraitEntryIdentity(config,entry) end
    if identity then return identity end
    if traitID(spell) and self.GetSpellInfo then
        local spellInfo=self:GetSpellInfo(spell)
        if spellInfo then return {name=spellInfo.name,icon=spellInfo.iconID,spellID=spell} end
    end
    return nil,reason
end

-- Where a specialization's talents are read. The specialization being played
-- (or any, on a client with one tree per class) is the active config. Another
-- specialization of the class is read from Blizzard's view loadout, the config
-- the talent window fills to show a shared build
-- (C_ClassTalents.InitializeViewLoadout(specID, level), tree from
-- C_ClassTalents.GetTraitTreeForSpec(specID); Blizzard_ClassTalentImportExport.lua
-- ViewLoadout). Returns config, tree and "active" or "view".
local function classTalents(name,...)
    local namespace=C_ClassTalents
    local fn=type(namespace)=='table' and namespace[name] or nil
    if type(fn)~='function' then return false,'missing-api' end
    local ok,value=pcall(fn,...)
    if not ok then return false,'api-error' end
    if not platform:CanReadValue(value) then return false,'restricted-value' end
    return true,value
end
local function viewLevel()
    for _,name in ipairs({'GetMaxLevelForPlayerExpansion','GetMaxLevelForLatestExpansion'}) do
        local fn=rawget(_G,name)
        if type(fn)=='function' then
            local ok,level=pcall(fn)
            if ok and integer(level,1,200) then return level end
        end
    end
    local ok,level=pcall(UnitLevel,'player')
    if ok and integer(level,1,200) then return level end
    return 80
end
-- Reading another specialization fills the shared view config (-3), the one
-- Blizzard's talent window shows a linked or inspected build from: it is left
-- alone while that window is on screen showing such a build. Nothing here
-- opens, loads or needs the window; it is only looked at when it already exists.
local function talentWindowInspecting()
    local frame=rawget(_G,'PlayerSpellsFrame')
    if type(frame)~='table' or type(frame.IsShown)~='function' or type(frame.IsInspecting)~='function' then return false end
    local okShown,shown=pcall(frame.IsShown,frame)
    local okInspecting,inspecting=pcall(frame.IsInspecting,frame)
    return okShown and okInspecting and shown==true and inspecting==true
end
function platform:GetTraitSpecTree(specID,options)
    local supported,reason=traitsLayout();if not supported then return nil,reason end
    local active,tree=self:GetActiveTraitConfig()
    local wanted=self:GetClientFamily()=='retail' and integer(specID,1,2147483647) and specID or nil
    if wanted and self.GetPlayerSpecializationID and active then
        if self:GetPlayerSpecializationID()==wanted then wanted=nil end
    end
    if not wanted then
        if not active then return nil,tree end
        return active,tree,'active'
    end
    if self.IsInitialSpecialization and self:IsInitialSpecialization(wanted) then return nil,'talent-tree-unavailable' end
    if type(InCombatLockdown)=='function' and InCombatLockdown() then return nil,'in-combat' end
    if not (options and options.ignoreInspect) and talentWindowInspecting() then return nil,'talent-window-inspecting' end
    local okTree,viewTree=classTalents('GetTraitTreeForSpec',wanted)
    if not okTree then return nil,viewTree end
    if viewTree==nil then return nil,'talent-tree-unavailable' end
    if not traitID(viewTree) then return nil,'invalid-api-result' end
    local okView,why=classTalents('InitializeViewLoadout',wanted,viewLevel())
    if not okView then return nil,why end
    local okInfo,info=traits('GetConfigInfo',VIEW_CONFIG)
    if not okInfo then return nil,info end
    if type(info)~='table' then return nil,'talent-config-unavailable' end
    return VIEW_CONFIG,viewTree,'view'
end

-- Where the class talents end and the specialization talents begin, from the
-- columns the talent window puts them in (class tree left, specialization tree
-- right, a gap between). nil when there is no clean gap: the caller then keeps
-- them as one group rather than guess.
local function classSpecBoundary(columns)
    local distinct,seen={},{}
    for _,x in ipairs(columns) do if not seen[x] then seen[x]=true;distinct[#distinct+1]=x end end
    if #distinct<4 then return nil end
    table.sort(distinct)
    local gaps={}
    for index=2,#distinct do gaps[#gaps+1]=distinct[index]-distinct[index-1] end
    local widest,at=0,nil
    for index,gap in ipairs(gaps) do if gap>widest then widest,at=gap,index end end
    local ordered={};for index,gap in ipairs(gaps) do ordered[index]=gap end
    table.sort(ordered)
    local median=ordered[math.ceil(#ordered/2)]
    if widest<math.max(500,median*3) then return nil end
    return (distinct[at]+distinct[at+1])/2
end

-- The talents of a specialization for the editor, grouped: the class talents,
-- the specialization talents and one group per hero subtree the specialization
-- can choose on Retail (kind "class", "spec", "hero"; "talents" when the two
-- could not be told apart), one group per tree on Forever (kind "tree").
-- specID names a Retail specialization (default: the one being played). Each
-- talent is {node, entry (choice nodes only), name, icon, spellID, maxRanks};
-- a second result describes where they were read: {spec, source ("active" or
-- "view"), hero (the subtree IDs the specialization can choose, when the
-- client says), nodes, visible, skipped (entries that could not be named)}.
-- Nothing listed is a reason, never an empty list.
function platform:GetTraitTalents(specID,options)
    local config,tree,source=self:GetTraitSpecTree(specID,options)
    if not config then return nil,tree end
    local ok,nodes=traits('GetTreeNodes',tree)
    if not ok then return nil,nodes end
    if type(nodes)~='table' then return nil,'invalid-api-result' end
    local trees=source=='active' and self:GetTraitTreeGroups(config,tree) or nil
    local groupIndex={}
    for index,group in ipairs(trees or {}) do groupIndex[group.groupID]=index end
    -- The first read that failed, reported when nothing could be listed.
    local failure
    local infos={}
    for index=1,#nodes do
        local node=nodes[index]
        local okNode,info=traits('GetNodeInfo',config,node)
        if not okNode then failure=failure or info end
        if okNode and type(info)=='table' and self:CanReadValue(info.ID) and info.ID==node and self:CanReadValue(info.isVisible)
            and info.isVisible~=false and self:CanReadValue(info.entryIDs) and type(info.entryIDs)=='table' then
            infos[#infos+1]=info
        end
    end
    -- Blizzard lists a hero subtree's nodes only when the specialization can
    -- choose it (HeroTalentsContainer IsNodeInAvailableSubTree). The client
    -- may answer nothing ("if none available"); the selection node's entries
    -- then name the subtrees the specialization can choose.
    local heroAllowed
    if self:GetClientFamily()=='retail' then
        local okHero,ids=classTalents('GetHeroTalentSpecsForClassSpec',config,source=='view' and specID or nil)
        if okHero and type(ids)=='table' then
            local allowed,any={},false
            for _,id in ipairs(ids) do if traitID(id) then allowed[id]=true;any=true end end
            if any then heroAllowed=allowed end
        end
        if not heroAllowed then
            local allowed,any={},false
            for _,info in ipairs(infos) do
                if info.type==3 and self:CanReadValue(info.isAvailable) and info.isAvailable~=false then -- Enum.TraitNodeType.SubTreeSelection
                    for _,entry in ipairs(info.entryIDs) do
                        local okEntry,entryInfo=false,nil
                        if self:CanReadValue(entry) and traitID(entry) then okEntry,entryInfo=traits('GetEntryInfo',config,entry) end
                        if okEntry and type(entryInfo)=='table' and self:CanReadValue(entryInfo.subTreeID) and traitID(entryInfo.subTreeID) then
                            allowed[entryInfo.subTreeID]=true;any=true
                        end
                    end
                end
            end
            if any then heroAllowed=allowed end
        end
    end
    local selection=2 -- Enum.TraitNodeType.Selection
    local groups,byKey={},{}
    local function groupFor(key,name,hero,kind)
        local group=byKey[key]
        if not group then group={key=key,name=name,hero=hero,kind=kind,talents={}};byKey[key]=group;groups[#groups+1]=group end
        return group
    end
    for _,group in ipairs(trees or {}) do groupFor('group:'..group.groupID,group.name,nil,'tree') end
    local skipped=0
    for _,info in ipairs(infos) do
        local node=info.ID
        local key,name,hero,kind='talents',nil,nil,'talents'
        if self:CanReadValue(info.groupIDs) and type(info.groupIDs)=='table' then
            for _,id in ipairs(info.groupIDs) do
                if self:CanReadValue(id) and groupIndex[id] then key,name,kind='group:'..id,trees[groupIndex[id]].name,'tree';break end
            end
        end
        local skip=false
        if key=='talents' and self:CanReadValue(info.subTreeID) and traitID(info.subTreeID) then
            if heroAllowed and not heroAllowed[info.subTreeID] then skip=true
            else
                -- The subtree's name is optional in the record; its talents stay
                -- together under it either way.
                local okSub,sub=traits('GetSubTreeInfo',config,info.subTreeID)
                if okSub and type(sub)=='table' and self:CanReadValue(sub.name) and type(sub.name)=='string' and sub.name~='' then name=sub.name end
                key,hero,kind='subtree:'..info.subTreeID,info.subTreeID,'hero'
            end
        end
        if not skip then
            -- Only a selection node offers its entries as alternatives; a
            -- tiered node's entries are the tiers of one talent.
            local entries=info.entryIDs
            local choice=#entries>1 and (info.type==selection or info.type==nil)
            local shown=entries
            if #entries>1 and not choice then
                local active=type(info.activeEntry)=='table' and self:CanReadValue(info.activeEntry.entryID) and info.activeEntry.entryID or nil
                shown={active or entries[1]}
            end
            for _,entry in ipairs(shown) do
                local identity,why
                if self:CanReadValue(entry) then identity,why=self:GetTraitEntryIdentity(config,entry) else why='restricted-value' end
                if not identity then
                    -- A hero selection node has entries without a talent; any other
                    -- entry that cannot be named is counted.
                    if info.type~=3 then skipped=skipped+1 end
                    if why~='talent-entry-unavailable' then failure=failure or why end
                end
                if identity then
                    identity.node,identity.entry=node,choice and entry or nil
                    identity.y=self:CanReadValue(info.posY) and type(info.posY)=='number' and info.posY or 0
                    identity.x=self:CanReadValue(info.posX) and type(info.posX)=='number' and info.posX or 0
                    local list=groupFor(key,name,hero,kind).talents
                    list[#list+1]=identity
                end
            end
        end
    end
    -- The plain group is the class and specialization talents; split them where
    -- the talent window's columns have a clean gap.
    local plain=byKey.talents
    if plain and #plain.talents>0 then
        local columns={}
        for _,talent in ipairs(plain.talents) do columns[#columns+1]=talent.x end
        local boundary=classSpecBoundary(columns)
        if boundary then
            local left,right={},{}
            for _,talent in ipairs(plain.talents) do if talent.x<boundary then left[#left+1]=talent else right[#right+1]=talent end end
            if #left>=3 and #right>=3 then
                plain.kind,plain.talents='class',left
                local spec={key='spec',kind='spec',talents=right}
                for index,group in ipairs(groups) do if group==plain then table.insert(groups,index+1,spec);break end end
            end
        end
    end
    local result,heroes={},{}
    for _,group in ipairs(groups) do
        table.sort(group.talents,function(a,b)
            if a.y~=b.y then return a.y<b.y end
            if a.x~=b.x then return a.x<b.x end
            return (a.entry or 0)<(b.entry or 0)
        end)
        for _,talent in ipairs(group.talents) do talent.x,talent.y=nil,nil end
        if #group.talents>0 then
            local list=group.hero and heroes or result
            list[#list+1]={name=group.name,hero=group.hero,kind=group.kind,talents=group.talents}
        end
    end
    -- The class and specialization talents first, then each hero tree.
    for _,group in ipairs(heroes) do result[#result+1]=group end
    if #result==0 then return nil,failure or (skipped>0 and 'talent-entry-unavailable') or 'talent-tree-unavailable' end
    local hero
    if heroAllowed then hero={};for id in pairs(heroAllowed) do hero[#hero+1]=id end;table.sort(hero) end
    return result,{spec=source=='view' and specID or nil,source=source,hero=hero,nodes=#nodes,visible=#infos,skipped=skipped}
end

-- Every spell ID the config's tree teaches and where: spell -> {node, entry
-- (choice nodes only), visible}. Built on demand by the build context when a
-- saved node ID no longer holds its talent (node IDs can change between
-- patches; spell IDs do not).
function platform:GetTraitSpellIndex(config,tree)
    if not traitID(config) or not traitID(tree) then return nil,'invalid-talent-query' end
    local ok,nodes=traits('GetTreeNodes',tree)
    if not ok then return nil,nodes end
    if type(nodes)~='table' then return nil,'invalid-api-result' end
    local selection=2 -- Enum.TraitNodeType.Selection
    local index={}
    for position=1,#nodes do
        local node=nodes[position]
        local okNode,info=traits('GetNodeInfo',config,node)
        if okNode and type(info)=='table' and self:CanReadValue(info.ID) and info.ID==node and self:CanReadValue(info.entryIDs)
            and type(info.entryIDs)=='table' and self:CanReadValue(info.isVisible) then
            local choice=#info.entryIDs>1 and (info.type==selection or info.type==nil)
            for _,entry in ipairs(info.entryIDs) do
                local spell=self:CanReadValue(entry) and self:GetTraitEntrySpell(config,entry)
                if spell then
                    local known=index[spell]
                    if not known or (info.isVisible~=false and not known.visible) then
                        index[spell]={node=node,entry=choice and entry or nil,visible=info.isVisible~=false}
                    end
                end
            end
        end
    end
    return index
end
