local addon_name,addon=...
local L=LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- /rm debug timeline [seconds|show]: what Blizzard's encounter timeline
-- (C_EncounterTimeline, Retail and Forever) offers to an addon, read-only.
-- Rotation Master has no condition for the timeline yet: Blizzard's generated
-- API documentation marks an event's spell, icon and severity secret during an
-- encounter (SecretWhenEncounterEvent) while an event's ID, source, duration,
-- state and time remaining carry no such flag, but nobody has confirmed in
-- game which values a real encounter hands to an addon. This report is that
-- probe. It lists which functions exist, the timeline's state, every event
-- the client lists with each field marked readable or secret, and, with a
-- number of seconds, one line per second plus every timeline event as it
-- arrives (with the readability of its payload), so a run through a boss
-- fight answers the question for each field. A condition ("a boss ability is
-- due in N seconds") will be built from the answer, not before.
-- The report opens in a copyable window and is kept, newest last, in
-- RotationMasterDB.diagnostics.timeline (at most 3 reports of 500 lines).
-- Only reads: nothing here changes the timeline, and nothing runs until the
-- command does. The event watch registers its events only for its duration.

local MAX_REPORTS,MAX_LINES,MAX_WATCH,MAX_EVENTS=3,500,300,12
local EVENTS={'ENCOUNTER_START','ENCOUNTER_END','ENCOUNTER_TIMELINE_EVENT_ADDED','ENCOUNTER_TIMELINE_EVENT_REMOVED',
    'ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED','ENCOUNTER_TIMELINE_EVENT_BLOCK_STATE_CHANGED','ENCOUNTER_TIMELINE_STATE_UPDATED'}
-- The functions the report asks about, with the arguments of the ones that need an event.
local FUNCTIONS={'IsFeatureAvailable','IsFeatureEnabled','HasAnyEvents','HasActiveEvents','HasPausedEvents','HasVisibleEvents',
    'GetCurrentTime','GetViewType','GetEventList','GetSortedEventList','GetEventState','GetEventTimeRemaining','GetEventTimeElapsed',
    'GetEventTrack','GetEventInfo','IsEventBlocked','GetEventCountBySource'}
-- EncounterTimelineEventInfo fields, and which the documentation marks NeverSecret.
local INFO_FIELDS={{'id',true},{'source',true},{'duration',true},{'maxQueueDuration',true},{'spellName'},{'spellID'},{'iconFileID'},
    {'icons'},{'severity'},{'isApproximate'}}

local function readable(value)
    local platform=addon.Platform
    return not platform or type(platform.CanReadValue)~='function' or platform:CanReadValue(value)
end
local function show(value)
    if not readable(value) then return 'secret' end
    if value==nil then return 'nil' end
    if type(value)=='number' and value%1~=0 then return string.format('%.3f',value) end
    return tostring(value)
end
local function protect(fn,...)
    if type(fn)~='function' then return false,'missing' end
    return pcall(fn,...)
end
local function timeline(name)
    local space=rawget(_G,'C_EncounterTimeline')
    return type(space)=='table' and space[name] or nil
end

local function store()
    local saved=rawget(_G,addon.savedVariableName or 'RotationMasterDB')
    if type(saved)~='table' then return nil end
    local diagnostics=rawget(saved,'diagnostics')
    if type(diagnostics)~='table' then diagnostics={};saved.diagnostics=diagnostics end
    local reports=diagnostics.timeline
    if type(reports)~='table' then reports={};diagnostics.timeline=reports end
    return reports
end
local function save(lines)
    local reports=store()
    if not reports then return nil end
    local entry={at=type(date)=='function' and date('%Y-%m-%d %H:%M:%S') or nil,lines=lines}
    reports[#reports+1]=entry
    while #reports>MAX_REPORTS do table.remove(reports,1) end
    return entry
end

-- One event's fields: readable ones with their value, secret ones as such.
local function describeInfo(info)
    if not readable(info) then return 'record is secret' end
    if type(info)~='table' then return 'record='..show(info) end
    local parts={}
    for _,field in ipairs(INFO_FIELDS) do
        local value=info[field[1]]
        parts[#parts+1]=field[1]..'='..show(value)..(field[2] and not readable(value) and ' (documented NeverSecret!)' or '')
    end
    return table.concat(parts,' ')
end

local function eventLines(add,id)
    local okState,state=protect(timeline('GetEventState'),id)
    local okLeft,left=protect(timeline('GetEventTimeRemaining'),id)
    local okTrack,track=protect(timeline('GetEventTrack'),id)
    local okBlocked,blocked=protect(timeline('IsEventBlocked'),id)
    add('  event %s: state=%s remaining=%s track=%s blocked=%s',show(id),okState and show(state) or 'error',
        okLeft and show(left) or 'error',okTrack and show(track) or 'error',okBlocked and show(blocked) or 'error')
    local okInfo,info=protect(timeline('GetEventInfo'),id)
    add('    info: %s',okInfo and describeInfo(info) or ('error: '..tostring(info)))
end

local function snapshot(add)
    add('== Encounter timeline probe')
    local client=addon.Platform and addon.Platform.GetClientInfo and addon.Platform:GetClientInfo() or {}
    add('client family=%s build=%s',show(client.family),show(client.build))
    local okRestrict,restricted=protect(type(C_Secrets)=='table' and C_Secrets.HasSecretRestrictions or nil)
    add('HasSecretRestrictions=%s',okRestrict and show(restricted) or 'unavailable')
    if type(rawget(_G,'C_EncounterTimeline'))~='table' then
        add('C_EncounterTimeline is MISSING on this client: nothing to read here.')
        return
    end
    local missing={}
    for _,name in ipairs(FUNCTIONS) do if type(timeline(name))~='function' then missing[#missing+1]=name end end
    add('functions missing: %s',#missing>0 and table.concat(missing,', ') or 'none')
    for _,name in ipairs({'IsFeatureAvailable','IsFeatureEnabled','HasAnyEvents','HasActiveEvents','HasPausedEvents','HasVisibleEvents','GetCurrentTime','GetViewType'}) do
        local ok,value=protect(timeline(name))
        add('%s -> %s',name,ok and show(value) or ('error: '..tostring(value)))
    end
    local okEnc,encounter=protect(rawget(_G,'IsEncounterInProgress') or (type(C_InstanceEncounter)=='table' and C_InstanceEncounter.IsEncounterInProgress))
    add('encounter in progress=%s',okEnc and show(encounter) or 'unavailable')
    local ok,list=protect(timeline('GetEventList'))
    if not ok then add('GetEventList error: %s',tostring(list));return end
    if not readable(list) or type(list)~='table' then add('GetEventList -> %s',show(list));return end
    add('GetEventList -> %d events',#list)
    for index=1,math.min(#list,MAX_EVENTS) do eventLines(add,list[index]) end
    local okSorted,sorted=protect(timeline('GetSortedEventList'),MAX_EVENTS)
    if okSorted and readable(sorted) and type(sorted)=='table' then
        local ids={}
        for index=1,math.min(#sorted,MAX_EVENTS) do ids[index]=show(sorted[index]) end
        add('GetSortedEventList(%d) -> [%s] n=%d',MAX_EVENTS,table.concat(ids,','),#sorted)
    else add('GetSortedEventList -> %s',okSorted and show(sorted) or ('error: '..tostring(sorted))) end
end

local watcher
local function finish(self)
    if not watcher then return end
    if watcher.timer then self:CancelTimer(watcher.timer) end
    if watcher.frame then watcher.frame:UnregisterAllEvents();watcher.frame:SetScript('OnEvent',nil) end
    watcher=nil
    self:print(L['Timeline watch finished. Run /rm debug timeline show to view it.'])
end

function addon:BuildTimelineDiagnostic()
    local lines={}
    local function add(text,...)
        if #lines>=MAX_LINES then return end
        lines[#lines+1]=select('#',...)>0 and string.format(text,...) or text
    end
    local ok,problem=pcall(snapshot,add)
    if not ok then add('probe error: %s',tostring(problem)) end
    return lines
end

function addon:RunTimelineDiagnostic(argument)
    argument=(argument or ''):match('^%s*(.-)%s*$')
    if argument=='show' then return self:ShowTimelineDiagnostic() end
    if argument=='stop' then
        if watcher then finish(self) else self:print(L['No timeline watch is running.']) end
        return
    end
    local seconds=tonumber(argument)
    if argument~='' and not seconds then
        self:print(L['Usage: /rm debug timeline [seconds|show|stop]'])
        return
    end
    local lines=self:BuildTimelineDiagnostic()
    local entry=save(lines)
    if seconds and seconds>=1 and entry and type(self.ScheduleRepeatingTimer)=='function' and type(CreateFrame)=='function' then
        seconds=math.min(math.floor(seconds),MAX_WATCH)
        if watcher then finish(self) end
        lines[#lines+1]=''
        lines[#lines+1]='== Watch for '..seconds..'s: one line per second, and each event as it arrives'
        local remaining=seconds
        local started=type(GetTime)=='function' and GetTime() or 0
        local frame=CreateFrame('Frame')
        local function stamp() return string.format('%+.1fs',(type(GetTime)=='function' and GetTime() or 0)-started) end
        frame:SetScript('OnEvent',function(_,event,...)
            if #lines>=MAX_LINES then return end
            local first=...
            local payload=first~=nil and (type(first)=='table' and describeInfo(first) or show(first)) or ''
            lines[#lines+1]=stamp()..' '..event..' '..payload
        end)
        for _,event in ipairs(EVENTS) do pcall(frame.RegisterEvent,frame,event) end
        watcher={frame=frame}
        watcher.timer=self:ScheduleRepeatingTimer(function()
            remaining=remaining-1
            if #lines<MAX_LINES then
                local okList,list=protect(timeline('GetSortedEventList'),3)
                local parts={}
                if okList and readable(list) and type(list)=='table' then
                    for index=1,math.min(#list,3) do
                        local okLeft,left=protect(timeline('GetEventTimeRemaining'),list[index])
                        local okState,state=protect(timeline('GetEventState'),list[index])
                        parts[#parts+1]=show(list[index])..':'..(okLeft and show(left) or 'err')..'s/'..(okState and show(state) or 'err')
                    end
                end
                local okActive,active=protect(timeline('HasActiveEvents'))
                local okEnc,encounter=protect(rawget(_G,'IsEncounterInProgress') or (type(C_InstanceEncounter)=='table' and C_InstanceEncounter.IsEncounterInProgress))
                lines[#lines+1]=stamp()..' encounter='..(okEnc and show(encounter) or '?')..' active='..(okActive and show(active) or '?')..' next=['..table.concat(parts,' ')..']'
            end
            if remaining<=0 then finish(self) end
        end,1)
        self:print(L['Timeline diagnostic saved. Watching for %d seconds.'],seconds)
    else
        self:print(L['Timeline diagnostic saved.'])
        if self.ShowConditionText then self:ShowConditionText(table.concat(lines,'\n'),L['Timeline diagnostic']) end
    end
    return lines
end

-- The newest stored report, in the copyable window.
function addon:ShowTimelineDiagnostic()
    local reports=store()
    local entry=reports and reports[#reports]
    if not entry or type(entry.lines)~='table' then self:print(L['No timeline diagnostic is saved yet. Run /rm debug timeline.']);return end
    if self.ShowConditionText then self:ShowConditionText(table.concat(entry.lines,'\n'),L['Timeline diagnostic']) end
end
