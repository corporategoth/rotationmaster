local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local platform=addon.Platform
local request=0
local restricted={say='SAY',yell='YELL',whisper='WHISPER'}
local function failure(reason)return {chat=false,sound=false,chatReason=reason}end
local function text(value,limit)
    return platform:CanReadValue(value) and type(value)=='string' and #value>0 and #value<=limit and not value:find('[%z\1-\31\127]')
end
-- Cold invocation-only observation. Nothing is retained between macro calls.
local function target(unit,whisper)
    if unit==nil then return nil,function()return true end end
    if not text(unit,64) or not unit:match('^[a-z][a-z0-9]*$') then return nil,nil,'invalid-unit' end
    local exists,guid,full,name,isPlayer=UnitExists,UnitGUID,UnitFullName,UnitName,UnitIsPlayer
    local named=type(full)=='function' and full or name
    if type(exists)~='function' or type(guid)~='function' or type(named)~='function' or whisper and type(isPlayer)~='function' then return nil,nil,'missing-api' end
    local function observe()
        local ok,present=pcall(exists,unit)
        if not ok or not platform:CanReadValue(present) or present~=true then return end
        local identified,id=pcall(guid,unit)
        local got,first,realm=pcall(named,unit)
        if not identified or not got or not text(id,256) or not text(first,256) or not platform:CanReadValue(realm) then return end
        if realm~=nil and (type(realm)~='string' or #realm>256 or realm:find('[%z\1-\31\127]')) then return end
        if whisper then local checked,player=pcall(isPlayer,unit);if not checked or not platform:CanReadValue(player) or player~=true then return end end
        return id,type(realm)=='string' and realm~='' and first..'-'..realm or first
    end
    local id,resolved=observe()
    if not id then return nil,nil,'target-unavailable' end
    local function sameAPI()
        return exists==UnitExists and guid==UnitGUID and full==UnitFullName and name==UnitName and isPlayer==UnitIsPlayer
    end
    local function current()
        if not sameAPI() then return false end
        local now,nowName=observe()
        if canaccessvalue and not canaccessvalue(now) then return false end
        if canaccessvalue and not canaccessvalue(nowName) then return false end
        if canaccessvalue and not canaccessvalue(id) then return false end
        if canaccessvalue and not canaccessvalue(resolved) then return false end
        return sameAPI() and now==id and nowName==resolved
    end
    return resolved,current
end
-- Series may contain independent outputs even when a valid supplied unit is
-- absent. Preserve that negative observation until the synchronous call ends.
local function seriesTarget(unit)
    if unit==nil then return nil,function()return true end end
    if not text(unit,64) or not unit:match('^[a-z][a-z0-9]*$') then return nil,nil,'invalid-unit' end
    local exists=UnitExists
    if type(exists)~='function' then return nil,nil,'missing-api' end
    local ok,present=pcall(exists,unit)
    if not ok or not platform:CanReadValue(present) or type(present)~='boolean' or exists~=UnitExists then return nil,nil,'target-unavailable' end
    if present then return target(unit,false) end
    return nil,function()
        if exists~=UnitExists then return false end
        local got,now=pcall(exists,unit)
        if not got or not platform:CanReadValue(now) then return false end
        if canaccessvalue and not canaccessvalue(now) then return false end
        return exists==UnitExists and now==false
    end
end
local function seriesSend(view,value,recipient,unit,current,installTargetWitness)
    local destination=restricted[view.announce]
    if view.announce=='channel' then destination='CHANNEL' end
    if not destination then return addon:DispatchAnnouncement(view,value,recipient,current) end
    if destination=='WHISPER' then
        local player=UnitIsPlayer
        if not recipient or not unit or type(player)~='function' or not current() then return failure('target-required') end
        local ok,isPlayer=pcall(player,unit)
        if not ok or not platform:CanReadValue(isPlayer) or isPlayer~=true or player~=UnitIsPlayer or not current() then return failure('target-required') end
    end
    local fn=type(C_ChatInfo)=='table' and C_ChatInfo.SendChatMessage
    if type(fn)~='function' then fn=SendChatMessage end
    if type(fn)~='function' or not current() then return failure('missing-api') end
    local address=destination=='WHISPER' and recipient or nil
    local channelCurrent
    if destination=='CHANNEL' then
        local resolve=platform.ResolveAnnouncementChannel
        if type(resolve)~='function' or not current() then return failure('channel-unavailable') end
        address,channelCurrent=resolve(platform,view.channel_name)
        if not address or not channelCurrent then return failure('channel-unavailable') end
        installTargetWitness(channelCurrent)
    end
    if not text(value,16384) or not current() then return failure('announcement-retired') end
    local ok=pcall(fn,value,destination,nil,address)
    local result={chat=ok,sound=false,chatReason=not ok and 'api-error' or nil}
    if current() then
        local audio=addon:DispatchAnnouncement({announce='audible',announce_sound=view.announce_sound},nil,nil,current)
        result.sound=audio.sound;result.soundReason=audio.soundReason
    end
    return result
end
local function send(textValue,destination,recipient,current)
    if not text(textValue,16384) or destination=='WHISPER' and not text(recipient,512) then return false,'invalid-message' end
    local fn=type(C_ChatInfo)=='table' and C_ChatInfo.SendChatMessage
    if type(fn)~='function' then fn=SendChatMessage end
    if type(fn)~='function' then return false,'missing-api' end
    if not current() then return false,'announcement-retired' end
    -- A completed native call is an attempt, not proof of visible delivery.
    -- Never retry a selected backend, defer output or attest the caller.
    local ok=pcall(fn,textValue,destination,nil,destination=='WHISPER' and recipient or nil)
    return ok,not ok and 'api-error' or nil
end
local function execute(serial,identifier,unit,spell)
    if not platform:CanReadValue(identifier) or not addon:IsValidMacroAnnouncementIdentifier(identifier) then return failure('invalid-identifier') end
    local db=addon.db;local profile=db and db.profile;local list=profile and profile.announces
    if type(list)~='table' or getmetatable(list)~=nil then return failure('announcement-unavailable') end
    local selected,index,count
    local n=0
    for key,value in pairs(list) do
        if type(key)~='number' or key%1~=0 or key<1 or key>#list or type(value)~='table' or getmetatable(value)~=nil then return failure('invalid-announcements') end
        n=n+1
        if rawget(value,'type')=='macro' and rawget(value,'identifier')==identifier then selected,index,count=value,key,(count or 0)+1 end
    end
    if n~=#list or count~=1 or selected.disabled or not addon:IsValidAnnouncement(selected) then return failure('announcement-unavailable') end
    local function selectionCurrent()
        if getmetatable(list)~=nil then return false end
        local size,matches=0,0
        for key,value in pairs(list) do
            if type(key)~='number' or key%1~=0 or key<1 or key>#list or type(value)~='table' or getmetatable(value)~=nil then return false end
            size=size+1
            if rawget(value,'type')=='macro' and rawget(value,'identifier')==identifier then
                if value~=selected or key~=index then return false end
                matches=matches+1
            end
        end
        return size==#list and matches==1
    end
    local registry=addon.conditionRegistryVersion
    local lifecycle=addon.IsEnabled
    local function enabled()
        if lifecycle~=addon.IsEnabled then return false end
        if lifecycle==nil then return true end
        if type(lifecycle)~='function' then return false end
        local ok,value=pcall(lifecycle,addon);return ok and value==true
    end
    local targetCurrent=function()return true end
    local function owner()
        if serial~=request or addon.db~=db or db.profile~=profile or profile.announces~=list or list[index]~=selected or selected.disabled or addon.conditionRegistryVersion~=registry then return false end
        if not enabled() then return false end
        -- Finish callback-capable lifecycle validation before the unit witness.
        if not enabled() then return false end
        local state=rawget(addon,'enabledState') -- AceAddon's IsEnabled source field.
        if state~=nil and state~=true then return false end
        local live=targetCurrent()
        return live and lifecycle==addon.IsEnabled and rawget(addon,'enabledState')==state and selectionCurrent()
            and serial==request and addon.db==db and db.profile==profile and profile.announces==list and list[index]==selected
            and not selected.disabled and addon.conditionRegistryVersion==registry
    end
    local entry,current=addon:PrepareAnnouncementDelivery(selected,owner)
    if not entry or not current() then return failure('announcement-retired') end
    local recipient,unitCurrent,why
    if entry.outputs~=nil then recipient,unitCurrent,why=seriesTarget(unit)
    else recipient,unitCurrent,why=target(unit,entry.announce=='whisper') end
    if not unitCurrent then return failure(why) end
    targetCurrent=unitCurrent
    if entry.announce=='whisper' and not recipient then return failure('target-required') end
    if not current() then return failure('announcement-retired') end
    local link
    if spell~=nil then
        if not platform:CanReadValue(spell) or not (type(spell)=='number' and spell>0 and spell<math.huge and spell%1==0 or text(spell,256)) then return failure('invalid-spell') end
        local info=platform:GetSpellInfo(spell);if not info or not current() then return failure('spell-unavailable') end
        link=platform:GetSpellLink(spell);if not text(link,4096) then return failure('spell-unavailable') end
    end
    if not current() then return failure('announcement-retired') end
    if entry.outputs~=nil then
        return addon:DispatchAnnouncementSeries(entry,recipient,current,recipient and unit or nil,function(view)
            local value=view.value or ''
            if value:find('{{item}}',1,true) or value:find('{{target}}',1,true) and not recipient or value:find('{{spell}}',1,true) and not link then return nil end
            return value:gsub('{{target}}',function()return recipient end):gsub('{{spell}}',function()return link end):gsub('{{event}}',function()return L['Via Macro']end)
        end,function(view,value,live)
            local previous=targetCurrent
            if view.announce=='whisper' then
                local named,whisperCurrent=target(unit,true)
                if not named or named~=recipient or not whisperCurrent then return failure('target-required') end
                targetCurrent=function()return previous() and whisperCurrent()end
            end
            local function install(witness)
                local prior=targetCurrent
                targetCurrent=function()return prior() and witness()end
            end
            local ok,result=pcall(seriesSend,view,value,recipient,unit,live,install)
            targetCurrent=previous
            return ok and result or failure('api-error')
        end)
    end
    -- Fourth argument is the separately composed event-only context contract.
    ---@type fun(self: table, config: table, recipient: string|nil, current: function, targetUnit: string|nil): boolean
    local matches=addon.AnnouncementConditionMatches
    if not matches(addon,entry,recipient,current,unit) or not current() then return failure('condition-no-match') end
    local value=entry.value or ''
    if value:find('{{item}}',1,true) then return failure('argument-required') end
    if value:find('{{target}}',1,true) and not recipient or value:find('{{spell}}',1,true) and not link then return failure('argument-required') end
    value=value:gsub('{{target}}',function()return recipient end):gsub('{{spell}}',function()return link end):gsub('{{event}}',function()return L['Via Macro']end)
    if not current() then return failure('announcement-retired') end
    local destination=restricted[entry.announce]
    if not destination then return addon:DispatchAnnouncement(entry,value,recipient,current) end
    local sent,reason=send(value,destination,recipient,current)
    local result={chat=sent,chatReason=reason,sound=false}
    if current() then
        local audio=addon:DispatchAnnouncement({announce='audible',announce_sound=entry.announce_sound},nil,nil,current)
        result.sound=audio.sound;result.soundReason=audio.soundReason
    end
    return result
end
local function invoke(identifier,unit,spell)
    request=request+1;local serial=request
    local ok,result
    if addon.Diagnostics then ok,result=addon.Diagnostics:Call({module='macro-announcements',operation='invoke'},execute,serial,identifier,unit,spell)
    else ok,result=pcall(execute,serial,identifier,unit,spell) end
    return ok and type(result)=='table' and result or failure('invocation-error')
end
-- Both public names are the same captured synchronous closure.
_G.RM_Annouce=invoke
_G.RM_Announce=invoke
