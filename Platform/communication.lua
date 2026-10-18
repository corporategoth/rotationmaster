local _,addon=...
local platform=addon.Platform
local function boolean(fn,...)
    if type(fn)~='function' then return nil,'missing-api' end
    local ok,value=pcall(fn,...)
    if not ok then return nil,'api-error' end
    if not platform:CanReadValue(value) then return nil,'restricted-value' end
    if type(value)~='boolean' then return nil,'invalid-api-result' end
    return value
end

-- Permissions may be unavailable even when group membership is public. Keep
-- those observations separate; callers can still choose ordinary raid chat.
function platform:GetAnnouncementGroup()
    local raid,why=boolean(IsInRaid);if raid==nil then return nil,why end
    if raid then
        local isLeader
        if type(UnitIsGroupLeader)=='function' then isLeader=boolean(UnitIsGroupLeader,'player')
        else isLeader=boolean(IsRaidLeader) end
        local isAssistant=boolean(UnitIsGroupAssistant,'player')
        return {inRaid=true,inGroup=true,isLeader=isLeader,isAssistant=isAssistant}
    end
    local grouped,reason=boolean(IsInGroup);if grouped==nil then return nil,reason end
    return {inRaid=false,inGroup=grouped}
end

local destinations={PARTY=true,RAID=true,RAID_WARNING=true,SAY=true,YELL=true,EMOTE=true}
function platform:SendAnnouncementChat(text,destination)
    if not self:CanReadValue(text) or not self:CanReadValue(destination) then return nil,'restricted-value' end
    if type(text)~='string' or type(destination)~='string' or not destinations[destination] then return nil,'invalid-message' end
    local fn=type(C_ChatInfo)=='table' and C_ChatInfo.SendChatMessage
    if type(fn)~='function' then fn=SendChatMessage end
    if type(fn)~='function' then return nil,'missing-api' end
    -- A selected sender may have side effects before raising. Never retry
    -- through another backend, or attempt to work around client restrictions.
    local ok=pcall(fn,text,destination)
    if not ok then return nil,'api-error' end
    return true
end
