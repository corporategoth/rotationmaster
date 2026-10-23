local _,addon=...
local platform=addon.Platform

local function integer(value,minimum,maximum)
    return platform:CanReadValue(value) and type(value)=="number" and value>=minimum
        and value<math.huge and value<=maximum and value%1==0
end

local function mode()
    local client=platform:GetClientInfo()
    if client.family=="retail" or client.family=="forever" then return "specialization" end
    if client.family=="era" or client.family=="tbc" then return "single" end
    if client.family=="progression" and integer(client.expansion,2,100) then return "group" end
    return nil,"unsupported-client"
end

local function method(name,legacy)
    if C_SpecializationInfo and type(C_SpecializationInfo[name])=="function" then return C_SpecializationInfo[name] end
    return legacy
end

local function queryInteger(fn,maximum,...)
    if type(fn)~="function" then return nil,"missing-api" end
    local ok,value=pcall(fn,...)
    if not ok then return nil,"api-error" end
    if not platform:CanReadValue(value) then return nil,"restricted-value" end
    if value==nil then return nil,"specialization-unavailable" end
    if not integer(value,1,maximum) then return nil,"invalid-api-result" end
    return value
end

-- key is the saved rotation namespace; index is the native API selector.
function platform:GetRotationSpecialization()
    local kind,reason=mode()
    if not kind then return nil,reason end
    if kind=="single" then return {kind=kind,index=0,key=0} end
    if kind=="group" then
        local group,why=queryInteger(method("GetActiveSpecGroup",GetActiveTalentGroup),4,false,false)
        if not group then return nil,why end
        return {kind=kind,index=group,key=group}
    end
    local index,why=queryInteger(method("GetSpecialization",GetSpecialization),16)
    if not index then return nil,why end
    local id,unavailable=queryInteger(method("GetSpecializationInfo",GetSpecializationInfo),math.huge,index)
    if not id then return nil,unavailable end
    return {kind=kind,index=index,key=id}
end

-- The player's active specialization INDEX (1..4), for an observation that
-- depends on it: POINT's per-specialization resource on Mists of Pandaria
-- Classic. It is not the rotation storage key above (progression stores per
-- talent group). Blizzard's 5.5.4 resource bars compare
-- C_SpecializationInfo.GetSpecialization() with the SPEC_* indices
-- (Gethe/wow-ui-source classic 45eb466ddb, Blizzard_FrameXMLBase/Classic/
-- Constants.lua; Blizzard_UnitFrame/Mists/ShardBar.lua, PriestBar.lua).
-- No specialization yet (below level 10) is unavailable, never index 1.
function platform:GetPlayerSpecializationIndex()
    return queryInteger(method("GetSpecialization",GetSpecialization),16)
end

function platform:GetRotationSpecializations(classID)
    local kind,reason=mode()
    if not kind then return nil,reason end
    if kind=="single" then return {{id=0}} end
    if kind=="group" then
        local count,why=queryInteger(GetNumTalentGroups,4,false,false)
        if not count then return nil,why end
        local choices={}
        for index=1,count do choices[index]={id=index} end
        return choices
    end
    if not integer(classID,1,math.huge) then return nil,"invalid-class" end
    local count,why=queryInteger(method("GetNumSpecializationsForClassID",GetNumSpecializationsForClassID),16,classID)
    if not count then return nil,why end
    if type(GetSpecializationInfoForClassID)~="function" then return nil,"missing-api" end
    local choices,seen={},{}
    for index=1,count do
        local ok,id,name=pcall(GetSpecializationInfoForClassID,classID,index)
        if not ok then return nil,"api-error" end
        if not self:CanReadValue(id) or not self:CanReadValue(name) then return nil,"restricted-value" end
        if not integer(id,1,math.huge) or type(name)~="string" or name=="" or seen[id] then return nil,"invalid-api-result" end
        seen[id]=true
        choices[index]={id=id,name=name}
    end
    return choices
end
