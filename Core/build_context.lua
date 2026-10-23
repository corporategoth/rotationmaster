local _,addon=...

-- Build context: the player's equipment, enchants, gems, item-set pieces,
-- temporary weapon enchants, talents/loadout and season/game mode, normalized
-- once per change. Every section is rebuilt lazily after a notification marks
-- it dirty; nothing here is read per poll. Consumers (conditions, rotation
-- applicability, UI) read the cached snapshot. Equipment and talent
-- notifications already advance the evaluation context epoch in main.lua;
-- the rest only feed conditions, which read this cache on every evaluation,
-- so they need no plan rebuild.
--
-- Client differences are feature-detected: Era/TBC/Wrath/Cata use talent
-- trees, MoP Classic a talent grid, Retail/Forever trait loadouts. Item set
-- IDs come from item metadata (sixteenth GetItemInfo result) and stay pending
-- until the client has the item cached. Seasons and game rules exist only
-- where C_Seasons/C_GameRules do.

local SLOT_FIRST,SLOT_LAST=1,19
local sections={equipment=true,weapons=true,talents=true,client=true}
local dirty={equipment=true,weapons=true,talents=true,client=true}
local snapshot={equipment={},sets={},weapons={},talents={},season={},rulesets={},pending=false}
local revision=0
local frame,watching

local function readable(value) return addon.Platform:CanReadValue(value) end
local function positive(value)
    return readable(value) and type(value)=='number' and value>0 and value<math.huge and value%1==0 and value or nil
end
local function call(fn,...)
    if type(fn)~='function' then return false end
    return pcall(fn,...)
end

local function markDirty(...)
    for i=1,select('#',...) do dirty[(select(i,...))]=true end
    revision=revision+1
end

-- Notifications that change a section. Registration is lazy (first read) and
-- per name, so an event a client does not know never blocks the others.
local notifications={
    PLAYER_ENTERING_WORLD={'equipment','weapons','talents','client'},
    PLAYER_EQUIPMENT_CHANGED={'equipment','weapons'},
    UNIT_INVENTORY_CHANGED={'equipment','weapons'},
    SOCKET_INFO_SUCCESS={'equipment'},
    GET_ITEM_INFO_RECEIVED={'pending'},
    ITEM_DATA_LOAD_RESULT={'pending'},
    CHARACTER_POINTS_CHANGED={'talents'},
    PLAYER_TALENT_UPDATE={'talents'},
    ACTIVE_TALENT_GROUP_CHANGED={'talents'},
    PLAYER_SPECIALIZATION_CHANGED={'talents'},
    ACTIVE_PLAYER_SPECIALIZATION_CHANGED={'talents'},
    TRAIT_CONFIG_UPDATED={'talents'},
    TRAIT_CONFIG_LIST_UPDATED={'talents'},
    ACTIVE_COMBAT_CONFIG_CHANGED={'talents'},
}
local function onEvent(_,event,unit)
    local parts=notifications[event]
    if not parts then return end
    if event=='UNIT_INVENTORY_CHANGED' and unit~=nil and unit~='player' then return end
    if parts[1]=='pending' then
        -- Item metadata arriving matters only while a set ID is still missing.
        if snapshot.pending then markDirty('equipment') end
        return
    end
    markDirty(unpack(parts))
end
local function watch()
    if watching~=nil then return watching end
    watching=false
    if type(CreateFrame)~='function' then return false end
    local ok,created=pcall(CreateFrame,'Frame')
    if not ok or type(created)~='table' then return false end
    frame=created
    if type(frame.SetScript)=='function' then frame:SetScript('OnEvent',onEvent) end
    for event in pairs(notifications) do
        if event=='UNIT_INVENTORY_CHANGED' and type(frame.RegisterUnitEvent)=='function' then
            pcall(frame.RegisterUnitEvent,frame,event,'player')
        elseif type(frame.RegisterEvent)=='function' then
            pcall(frame.RegisterEvent,frame,event)
        end
    end
    watching=true
    return true
end

-- Item string fields: itemID:enchantID:gem1:gem2:gem3:gem4:suffixID:...
local function parseLink(link)
    if type(link)~='string' or not readable(link) then return nil end
    local body=link:match('item:([%-%d:]+)')
    if not body then return nil end
    local fields,index={},0
    for field in (body..':'):gmatch('([^:]*):') do index=index+1;fields[index]=tonumber(field) end
    local gems={}
    for i=3,6 do local gem=fields[i];if gem and gem>0 then gems[#gems+1]=gem end end
    return {enchantID=fields[2] and fields[2]>0 and fields[2] or nil,gems=gems,
        suffixID=fields[7] and fields[7]~=0 and fields[7] or nil}
end
local function itemSetID(itemID)
    local info=C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(info)~='function' then return nil,'missing-api' end
    local result={pcall(info,itemID)}
    if not result[1] then return nil,'api-error' end
    if result[2]==nil then return nil,'item-data-pending' end
    local setID=result[17]
    if not readable(setID) then return nil,'restricted-value' end
    return positive(setID) or false
end
local function socketCount(link)
    local stats=C_Item and C_Item.GetItemStats or GetItemStats
    if type(stats)~='function' or type(link)~='string' then return nil end
    local ok,values=pcall(stats,link)
    if not ok or type(values)~='table' or not readable(values) then return nil end
    local count=0
    for key,amount in pairs(values) do
        if type(key)=='string' and key:find('^EMPTY_SOCKET_') and type(amount)=='number' then count=count+amount end
    end
    return count
end
local function buildEquipment()
    local equipment,sets,pending={},{},false
    local idOf=GetInventoryItemID
    if type(idOf)~='function' then
        snapshot.equipment,snapshot.sets,snapshot.pending,snapshot.equipmentReason=equipment,sets,false,'missing-api'
        return
    end
    for slot=SLOT_FIRST,SLOT_LAST do
        local ok,itemID=call(idOf,'player',slot)
        itemID=ok and positive(itemID)
        if itemID then
            local okLink,link=call(GetInventoryItemLink,'player',slot)
            local record={itemID=itemID,slot=slot}
            local parsed=okLink and parseLink(link)
            if parsed then
                record.enchantID,record.gems,record.suffixID=parsed.enchantID,parsed.gems,parsed.suffixID
                record.sockets=socketCount(link)
            end
            local setID,why=itemSetID(itemID)
            if setID then sets[setID]=(sets[setID] or 0)+1;record.setID=setID
            elseif setID==nil then record.setReason=why;if why=='item-data-pending' then pending=true end end
            equipment[slot]=record
        end
    end
    snapshot.equipment,snapshot.sets,snapshot.pending,snapshot.equipmentReason=equipment,sets,pending,nil
end
local function buildWeapons()
    local weapons={}
    local ok,main,_,_,mainID,off,_,_,offID=call(GetWeaponEnchantInfo)
    if ok and readable(main) and readable(off) and readable(mainID) and readable(offID) then
        weapons.main={enchanted=main==true or main==1,enchantID=positive(mainID)}
        weapons.off={enchanted=off==true or off==1,enchantID=positive(offID)}
    else weapons.reason=type(GetWeaponEnchantInfo)=='function' and 'api-error' or 'missing-api' end
    snapshot.weapons=weapons
end
local function activeGroup()
    local native=C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup
    local fn=type(native)=='function' and native or GetActiveTalentGroup
    local ok,group=call(fn,false,false)
    group=ok and positive(group)
    return group and group<=4 and group or nil
end
local function buildTalents()
    local platform=addon.Platform
    local talents={}
    local layout,why
    if platform.GetTalentLayout then layout,why=platform:GetTalentLayout() else why='missing-api' end
    talents.layout=layout;talents.reason=why
    if layout=='tree' or layout=='grid' then talents.group=activeGroup() end
    if layout=='tree' then
        local count=platform:GetTalentTreeCount()
        local trees,best,maximum={},nil,0
        for tree=1,count or 0 do
            local info=platform:GetTalentTreeInfo(tree,talents.group)
            local points=info and info.pointsSpent
            trees[tree]={name=info and info.name,points=points}
            if type(points)=='number' and points>maximum then best,maximum=tree,points end
        end
        talents.trees,talents.primary=trees,best
        local spent={}
        for tree=1,count or 0 do spent[#spent+1]=tostring(trees[tree].points or '?') end
        talents.summary=table.concat(spent,'/')
    elseif layout=='grid' then
        local selected={}
        for index=1,18 do
            local info=platform:GetGridTalentInfo(index,talents.group)
            if info and info.selected then selected[#selected+1]=info.talentID end
        end
        talents.selected=selected
    elseif layout=='traits' then
        local loadout={}
        local okSpec,specIndex=call(GetSpecialization)
        specIndex=okSpec and positive(specIndex)
        if specIndex then
            local okID,specID=call(GetSpecializationInfo,specIndex)
            loadout.specID=okID and positive(specID) or nil
        end
        local classTalents=C_ClassTalents
        if type(classTalents)=='table' then
            local okActive,active=call(classTalents.GetActiveConfigID)
            loadout.configID=okActive and positive(active) or nil
            if loadout.specID then
                local okSaved,saved=call(classTalents.GetLastSelectedSavedConfigID,loadout.specID)
                loadout.savedConfigID=okSaved and positive(saved) or nil
            end
            local traits=C_Traits
            local config=loadout.savedConfigID or loadout.configID
            if config and type(traits)=='table' then
                local okInfo,info=call(traits.GetConfigInfo,config)
                if okInfo and type(info)=='table' and readable(info) and readable(info.name) and type(info.name)=='string' then loadout.name=info.name end
            end
        else loadout.reason='missing-api' end
        talents.loadout=loadout
    end
    snapshot.talents=talents
end
-- Rulesets are the realm's season and game rules: a pack's
-- applicability.rulesets matches when any listed token is active.
-- 'standard' (no season, not hardcore), 'hardcore', 'self-found',
-- 'season:<id>', 'season:<name>' (Enum.SeasonID name, lower case) and
-- 'mode:<id>' (C_GameRules game mode record).
local function seasonName(id)
    local enum=type(Enum)=='table' and Enum.SeasonID
    if type(enum)~='table' then return nil end
    for name,value in pairs(enum) do if value==id and type(name)=='string' then return name end end
end
local function buildClient()
    local info=addon.Platform:GetClientInfo()
    local season={family=info.family,id=positive(info.seasonId),gameModeId=positive(info.gameModeId),
        hardcore=info.hardcore==true,selfFoundAllowed=info.selfFoundAllowed==true}
    if C_GameRules and type(C_GameRules.IsSelfFoundActive)=='function' then
        local ok,active=pcall(C_GameRules.IsSelfFoundActive)
        season.selfFound=ok and readable(active) and active==true
    end
    local rulesets={}
    if season.id then
        rulesets['season:'..season.id]=true
        season.name=seasonName(season.id)
        if season.name then rulesets['season:'..season.name:lower()]=true end
    end
    if season.hardcore then rulesets.hardcore=true end
    if season.selfFound then rulesets['self-found']=true end
    if season.gameModeId then rulesets['mode:'..season.gameModeId]=true end
    if not season.id and not season.hardcore then rulesets.standard=true end
    snapshot.season,snapshot.rulesets=season,rulesets
end
local builders={equipment=buildEquipment,weapons=buildWeapons,talents=buildTalents,client=buildClient}

local function refresh(only)
    local watched=watch()
    for section in pairs(sections) do
        if (only==nil or only==section) and (dirty[section] or not watched) then
            dirty[section]=false
            local ok,why=pcall(builders[section])
            if not ok then dirty[section]=true;snapshot[section..'Error']=tostring(why) end
        end
    end
    snapshot.revision=revision
    return snapshot
end

-- The shared normalized snapshot. It is replaced section by section on
-- change; callers must treat it as read-only.
function addon:GetBuildContext() return refresh() end
function addon:GetBuildContextRevision() return revision end
-- Marks one section (or all) dirty, e.g. after a test or a manual refresh.
function addon:InvalidateBuildContext(section)
    if section==nil then markDirty('equipment','weapons','talents','client')
    elseif sections[section] then markDirty(section) end
end
function addon:GetBuildRulesets() return refresh('client').rulesets end
function addon:GetEquippedSlotInfo(slot)
    local value=refresh('equipment')
    if value.equipmentReason then return nil,value.equipmentReason end
    return value.equipment[slot] or false
end
-- Equipped pieces of one game item set. Unknown while any equipped item's
-- metadata is still loading, so a count is never understated.
function addon:GetEquippedSetPieces(setID)
    local value=refresh('equipment')
    if value.equipmentReason then return nil,value.equipmentReason end
    if value.pending then return nil,'item-data-pending' end
    return value.sets[setID] or 0
end
function addon:GetEquippedSets()
    local value=refresh('equipment')
    if value.equipmentReason then return nil,value.equipmentReason end
    return value.sets,value.pending
end
-- A game item set's display name where the client exposes one.
function addon:GetItemSetName(setID)
    local fn=C_Item and C_Item.GetItemSetInfo or GetItemSetInfo
    local ok,name=call(fn,setID)
    if ok and readable(name) and type(name)=='string' and name~='' then return name end
end
function addon:GetTalentBuild() return refresh('talents').talents end
function addon:GetSeasonInfo() return refresh('client').season end
