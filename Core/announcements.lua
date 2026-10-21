local _,addon=...
local platform=addon.Platform
local direct={['local']='LOCAL',emote='EMOTE',gesture='GESTURE'}
-- Two bounded cold-output observations, never a history or polling cache.
local emoteSerial={automatic=0,test=0}
local emoteObservation={}
local emoteReasons={['restricted-value']=true,['invalid-emote']=true,['emote-unavailable']=true,
    ['missing-api']=true,['api-error']=true,['cast-recipient-unavailable']=true}
local function beginEmote(kind)
    emoteSerial[kind]=emoteSerial[kind]+1
    return emoteSerial[kind]
end
local function emoteDetailCopy(detail)
    if not platform:CanReadValue(detail) or type(detail)~='table' then return nil end
    local copy={}
    for _,key in ipairs({'backend','call','returns','firstType','firstBoolean'}) do
        local value=rawget(detail,key)
        if platform:CanReadValue(value) then
            if key=='backend' and (value=='C_ChatInfo.PerformEmote' or value=='DoEmote') then copy[key]=value
            elseif key=='call' and (value=='completed' or value=='threw') then copy[key]=value
            elseif key=='returns' and type(value)=='number' and value>=0 and value<=16 and value%1==0 then copy[key]=value
            elseif key=='firstType' and (value=='nil' or value=='boolean' or value=='number' or value=='string' or value=='table' or value=='function' or value=='thread' or value=='userdata' or value=='unavailable') then copy[key]=value
            elseif key=='firstBoolean' and type(value)=='boolean' then copy[key]=value end
        end
    end
    return copy
end
local function finishEmote(kind,serial,target,reason,detail)
    local copied,closed=pcall(emoteDetailCopy,detail)
    local checked,safeReason=pcall(function()
        if reason==nil then return 'native-call-completed' end
        if platform:CanReadValue(reason) and type(reason)=='string' and emoteReasons[reason] then return reason end
        return 'unavailable'
    end)
    if serial~=emoteSerial[kind] then return end
    emoteObservation[kind]={target=target,reason=checked and safeReason or 'unavailable',detail=copied and closed or nil}
end
local function destination(mode)
    if not platform:CanReadValue(mode) or type(mode)~='string' then return nil,'invalid-destination' end
    if mode=='say' or mode=='yell' then return nil,'hardware-event-required' end
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
function addon:DispatchAnnouncement(config,text,castRecipient)
    local result={chat=false,sound=false}
    if not platform:CanReadValue(config) or type(config)~='table' then return result end
    local dest,why=destination(config.announce);result.chatReason=why
    if dest=='GESTURE' then
        local serial=beginEmote('automatic')
        local target=config.emote_target and castRecipient or ''
        local detail
        if config.emote_target and (not platform:CanReadValue(target) or type(target)~='string' or target=='') then result.chatReason='cast-recipient-unavailable'
        else local sent,reason,observed=platform:PerformAnnouncementEmote(config.emote,target);result.chat=sent==true;result.chatReason=reason;detail=observed end
        finishEmote('automatic',serial,config.emote_target and 'cast-recipient' or 'none',result.chatReason,detail)
        dest=nil
    end
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

-- Called only by an explicitly labelled diagnostic button. It sends one
-- independent targetless CHEER, never a pending announcement or cast retry.
function addon:TestAnnouncementEmote()
    local serial=beginEmote('test')
    local sent,reason,detail=platform:PerformAnnouncementEmote('CHEER','')
    finishEmote('test',serial,'none',reason,detail)
    return {chat=sent==true,chatReason=reason}
end
function addon:GetAnnouncementEmoteReport()
    local lines={'Rotation Master emote diagnostics',
        'Native call completion does not prove visible output. Native booleans are reported without interpretation.',
        'Only the latest automatic emote and explicit click test are retained; no recipient names or message text.'}
    for _,entry in ipairs({{'automatic','Automatic:'},{'test','Explicit click test:'}}) do
        local row=emoteObservation[entry[1]]
        lines[#lines+1]=entry[2]..(row and (' target='..row.target..'; result='..row.reason) or ' not observed')
        if row and row.detail then
            local detail=row.detail
            lines[#lines+1]='backend='..(detail.backend or 'unavailable')..'; call='..(detail.call or 'unavailable')
            if detail.returns then
                lines[#lines+1]='native returns='..detail.returns..'; first type='..(detail.firstType or 'unavailable')..
                    (detail.firstBoolean~=nil and ('; first boolean='..tostring(detail.firstBoolean)) or '')
            end
        end
    end
    return table.concat(lines,'\n')
end
