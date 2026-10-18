local _,addon=...
local platform=addon.Platform
local direct={['local']='LOCAL',say='SAY',yell='YELL',emote='EMOTE'}
local function destination(mode)
    if not platform:CanReadValue(mode) or type(mode)~='string' then return nil,'invalid-destination' end
    if direct[mode] then return direct[mode] end
    if mode=='none' or mode=='audible' then return nil,'not-requested' end
    if mode~='partyraid' and mode~='party' and mode~='raidwarn' then return nil,'invalid-destination' end
    local group,why=platform:GetAnnouncementGroup();if not group then return nil,why end
    if mode=='party' then
        if group.inGroup then return 'PARTY' end
        return nil,'not-grouped'
    end
    if group.inRaid then
        if mode=='raidwarn' and (group.isLeader==true or group.isAssistant==true) then return 'RAID_WARNING' end
        return 'RAID'
    end
    return group.inGroup and 'PARTY' or 'LOCAL'
end
local function sound(key)
    if not platform:CanReadValue(key) then return false,'restricted-value' end
    if key==nil or key=='' then return false,'not-requested' end
    if type(key)~='string' then return false,'invalid-sound' end
    if type(PlaySoundFile)~='function' then return false,'missing-api' end
    local ok,media=pcall(LibStub,'LibSharedMedia-3.0',true)
    if not ok or type(media)~='table' or type(media.Fetch)~='function' then return false,'missing-media' end
    local fetched,path=pcall(media.Fetch,media,'sound',key,true)
    if not fetched then return false,'media-error' end
    if not platform:CanReadValue(path) then return false,'restricted-value' end
    if not (type(path)=='string' and path~='' or type(path)=='number' and path>0 and path<math.huge and path%1==0) then return false,'sound-unavailable' end
    local played,willPlay=pcall(PlaySoundFile,path,'Master')
    if not played then return false,'api-error' end
    if not platform:CanReadValue(willPlay) or willPlay==false then return false,'sound-unavailable' end
    return true
end

-- Output is best-effort and independent: a failed chat or audio API must not
-- interrupt cast bookkeeping or recommendation evaluation. This does not
-- construct templates, match events, or retry messages through another path.
function addon:DispatchAnnouncement(config,text)
    local result={chat=false,sound=false}
    if not platform:CanReadValue(config) or type(config)~='table' then return result end
    local dest,why=destination(config.announce);result.chatReason=why
    if dest then
        if not platform:CanReadValue(text) or type(text)~='string' then result.chatReason='invalid-message'
        elseif dest=='LOCAL' then
            if type(self.announce)=='function' then result.chat=pcall(self.announce,self,text);if not result.chat then result.chatReason='api-error' end
            else result.chatReason='missing-api' end
        else local sent,reason=platform:SendAnnouncementChat(text,dest);result.chat=sent==true;result.chatReason=reason end
    end
    result.sound,result.soundReason=sound(config.announce_sound)
    return result
end
