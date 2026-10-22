local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)

local function failure(reason)
    if reason=='script-profile-disabled' then
        return L['CPU capture requires WoW scriptProfile to be enabled before a reload. RM does not change this setting.']
    elseif reason=='running' or reason=='already-running' then return L['CPU capture is running. Open the report after it finishes.']
    elseif reason=='not-captured' then return L['No CPU capture is available. Start a capture first.']
    elseif reason=='not-running' then return L['No CPU capture is running.'] end
    return L['CPU capture is unavailable: %s']:format(tostring(reason or L['Unknown']))
end

-- Cold, explicit capability experiment. The measured function touches only
-- constants/local counters and the optional named profiler marker, never advice.
local nativeProbeBusy=false
local function probePack(...)return{n=select('#',...),...}end
local function probeReadable(value)
    local secret=rawget(_G,'issecretvalue')
    if type(secret)=='function' then local ok,v=pcall(secret,value);if not ok or type(v)~='boolean' or v then return false end
    elseif secret~=nil then return false end
    local access=rawget(_G,'canaccessvalue')
    if type(access)=='function' then local ok,v=pcall(access,value);if not ok or type(v)~='boolean' or not v then return false end
    elseif access~=nil then return false end
    return true
end
local function probeNumber(value,bytes)
    if not probeReadable(value) then return L['unavailable'] end
    if bytes and type(value)=='string' and #value>0 and #value<=20 and value:match('^%d+$')
        and (#value<20 or value<='18446744073709551615') then return value end
    if type(value)~='number' or value~=value or value<0 or value==math.huge then return L['unavailable'] end
    if bytes then
        if value%1~=0 or value>9007199254740991 then return L['unavailable'] end
        return string.format('%.0f',value)
    end
    return string.format('%.6g',value)
end
local function probeRunning(owner,getter)
    if not probeReadable(getter) or type(getter)~='function' then return nil end
    local ok,value=pcall(getter,owner)
    if not ok or not probeReadable(value) or type(value)~='boolean' then return nil end
    return value
end
local function buildNativeProbe(owner,getter)
    local runtimeGetter=rawget(owner,'IsCPURuntimeCaptureRunning')
    local state={provider='absent',enabled='absent',measure='absent',event='absent',calls='not run',arguments='not run',returns='not run'}
    local metrics={L['unavailable'],L['unavailable'],L['unavailable']}
    -- Explicit probe snapshot only. No capability query occurs at module load or
    -- when an existing CPU report is viewed/copied.
    local secret,access,secrets=rawget(_G,'issecretvalue'),rawget(_G,'canaccessvalue'),rawget(_G,'C_Secrets')
    local restrictions,restrictionType=nil,'nil'
    if type(secrets)=='table' then
        local ok,method=pcall(rawget,secrets,'HasSecretRestrictions')
        if ok then restrictions,restrictionType=method,type(method) else restrictionType='unavailable' end
    end
    local restrictionsResult=L['unavailable']
    local function render()
        return table.concat({L['Native profiler probe'],L['Capability probe only; no evaluator or gameplay was measured.'],L['Native acceptance: unverified'],
            'C_AddOnProfiler: '..L[state.provider],'IsEnabled: '..L[state.enabled],'MeasureCall: '..L[state.measure],
            'AddMeasuredCallEvent: '..L[state.event],L['Callback calls']..': '..((state.calls=='0' or state.calls=='1') and state.calls or L[state.calls]),
            L['Callback arguments']..': '..L[state.arguments],L['Callback returns']..': '..L[state.returns],
            'elapsedMilliseconds: '..metrics[1],'allocatedBytes: '..metrics[2],'deallocatedBytes: '..metrics[3],
            'issecretvalue type: '..type(secret),'canaccessvalue type: '..type(access),
            'C_Secrets type: '..type(secrets),'HasSecretRestrictions type: '..restrictionType,
            'HasSecretRestrictions result: '..restrictionsResult},'\n')
    end
    local provider=rawget(_G,'C_AddOnProfiler')
    if not probeReadable(provider) then state.provider='restricted';return render() end
    if provider==nil then return render() end
    if type(provider)~='table' then state.provider='malformed';return render() end
    state.provider='present'
    local enabled,measure,event=rawget(provider,'IsEnabled'),rawget(provider,'MeasureCall'),rawget(provider,'AddMeasuredCallEvent')
    local function presence(value)
        if not probeReadable(value) then return 'restricted' end
        return value==nil and 'absent' or type(value)=='function' and 'present' or 'malformed'
    end
    state.enabled,state.measure,state.event=presence(enabled),presence(measure),presence(event)
    local db=owner.db;local profile=db.profile
    local function sameProvider()
        local namespace=rawget(_G,'C_AddOnProfiler')
        return probeReadable(namespace) and rawequal(namespace,provider) and rawequal(rawget(provider,'IsEnabled'),enabled)
            and rawequal(rawget(provider,'MeasureCall'),measure) and rawequal(rawget(provider,'AddMeasuredCallEvent'),event)
            and owner.db==db and db.profile==profile and rawequal(rawget(owner,'IsCPUProfileRunning'),getter)
            and rawequal(rawget(owner,'IsCPURuntimeCaptureRunning'),runtimeGetter)
    end
    local function current()
        return sameProvider() and probeRunning(owner,getter)==false
            and (runtimeGetter==nil or probeRunning(owner,runtimeGetter)==false) and sameProvider()
    end
    local function changed()
        state.measure='unavailable (context changed)';metrics={L['unavailable'],L['unavailable'],L['unavailable']};return render()
    end
    if not current() then return changed() end
    if state.enabled~='present' then return render() end
    local ok,value=pcall(enabled)
    if not current() then return changed() end
    if not ok then state.enabled='call failed';return render() end
    if not probeReadable(value) then state.enabled='restricted';return render() end
    if not current() then return changed() end
    if type(value)~='boolean' then state.enabled='malformed';return render() end
    state.enabled=value and 'enabled' or 'disabled'
    if not value or state.measure~='present' then return render() end
    local calls,arguments,eventOK=0,true,nil
    local function inert(...)
        calls=math.min(calls+1,2)
        if calls==1 then
            local word,empty,flag=...
            arguments=select('#',...)==3 and probeReadable(word) and probeReadable(empty) and probeReadable(flag)
                and word=='RM' and empty==nil and flag==false
            if state.event=='present' and current() then eventOK=pcall(event,'RM:probe') end
        end
        return 'RM',nil,false
    end
    local results=probePack(pcall(measure,inert,'RM',nil,false))
    state.calls=calls==2 and 'more than one' or calls==1 and '1' or '0'
    state.arguments=arguments and calls==1 and 'exact' or 'mismatch'
    if not current() then return changed() end
    if eventOK~=nil then state.event=eventOK and 'call completed' or 'call failed' end
    if not results[1] then state.measure='call failed';return render() end
    local record=results[2]
    if not probeReadable(record) or type(record)~='table' then state.measure='malformed';return render() end
    local exact=results.n==5 and probeReadable(results[3]) and probeReadable(results[4]) and probeReadable(results[5])
        and results[3]=='RM' and results[4]==nil and results[5]==false
    state.returns=exact and 'exact' or 'mismatch'
    state.measure=calls==1 and arguments and exact and 'call completed' or 'malformed'
    if not current() then return changed() end
    if state.measure~='call completed' then return render() end
    metrics={probeNumber(rawget(record,'elapsedMilliseconds')),probeNumber(rawget(record,'allocatedBytes'),true),probeNumber(rawget(record,'deallocatedBytes'),true)}
    if not current() then return changed() end
    -- This readonly build-capability call is outside the inert measurement.
    -- Recheck exact captured methods after every callback-capable boundary.
    local function sameEligibility()
        return rawequal(rawget(_G,'issecretvalue'),secret) and rawequal(rawget(_G,'canaccessvalue'),access)
            and rawequal(rawget(_G,'C_Secrets'),secrets)
            and rawequal(rawget(secrets,'HasSecretRestrictions'),restrictions)
    end
    if type(restrictions)=='function' and sameEligibility() and probeReadable(secrets)
        and sameEligibility() and probeReadable(restrictions) and current() and sameEligibility() then
        local ok,result=pcall(restrictions)
        if not current() then return changed() end
        local readable=ok and sameEligibility() and probeReadable(result)
        if not current() then return changed() end
        if readable and sameEligibility() and type(result)=='boolean' then restrictionsResult=result and 'true' or 'false' end
    end
    if not current() then return changed() end
    return render()
end
local function runNativeProbe(owner)
    local unavailable=L['Native profiler probe is unavailable.']
    if not rawequal(owner,addon) or nativeProbeBusy then return false,unavailable end
    nativeProbeBusy=true
    local accepted,result,message=pcall(function()
        local runtimeGetter=rawget(owner,'IsCPURuntimeCaptureRunning')
        if runtimeGetter~=nil and probeRunning(owner,runtimeGetter)~=false then
            return false,L['Native profiler probe is unavailable while CPU capture is running.']
        end
        local getter=rawget(owner,'IsCPUProfileRunning');local running=probeRunning(owner,getter)
        if running==nil then return false,unavailable end
        if running then
            local reason=L['Native profiler probe is unavailable while CPU capture is running.'];owner:print(reason);return false,reason
        end
        local ok,text=pcall(buildNativeProbe,owner,getter)
        if not ok then text=L['Native profiler probe']..'\n'..L['Capability probe only; no evaluator or gameplay was measured.']..'\n'..L['Native acceptance: unverified']..'\n'..unavailable end
        local show=rawget(owner,'ShowConditionText')
        if type(show)~='function' or not pcall(show,owner,text,L['Native profiler probe']) then return false,unavailable end
        return true,''
    end)
    nativeProbeBusy=false
    if not accepted then return false,unavailable end
    return result,message
end

-- These actions affect diagnostic state only, independently of settings drafts.
function addon:RunCPUProfileAction(action)
    if nativeProbeBusy then return false,L['Native profiler probe is already running.'] end
    local ok,message
    if action==nil or action=='' or action=='start' then
        local reason;ok,reason=self:StartCPUProfile(10)
        message=ok and L['CPU capture started for 10 seconds. Close configuration to measure normal gameplay, then open CPU report.'] or failure(reason)
    elseif action=='cancel' then
        local reason
        if type(self.IsCPURuntimeCaptureRunning)=='function' and self:IsCPURuntimeCaptureRunning() then
            ok,reason=self:CancelCPURuntimeCapture()
        else ok,reason=self:CancelCPUProfile() end
        message=ok and L['CPU capture cancelled.'] or failure(reason)
    elseif action=='runtime' then
        local reason
        if type(self.StartCPURuntimeCapture)=='function' then ok,reason=self:StartCPURuntimeCapture(10)
        else ok,reason=false,'missing-native-profiler' end
        message=ok and L['Runtime capture started for 10 seconds. Close configuration, then open Runtime report.']
            or L['Runtime capture is unavailable: %s']:format(tostring(reason or L['Unknown']))
    elseif action=='runtimereport' then
        local report,reason
        if type(self.GetCPURuntimeCaptureReport)=='function' then report,reason=self:GetCPURuntimeCaptureReport() end
        if report then self:ShowConditionText(report,L['Runtime profile']);return true,'' end
        ok=false;message=L['Runtime capture is unavailable: %s']:format(tostring(reason or 'not-captured'))
    elseif action=='memory' then
        local reason
        if type(self.StartMemoryCapture)=='function' then ok,reason=self:StartMemoryCapture()
        else ok,reason=false,'missing-memory-api' end
        message=ok and L['Memory capture started for 10 minutes. Normal polling is unchanged; attribution refreshes every 30 seconds and their cost is reported.']
            or L['Memory capture is unavailable: %s']:format(tostring(reason or L['Unknown']))
    elseif action=='memorystop' then
        local reason
        if type(self.StopMemoryCapture)=='function' then ok,reason=self:StopMemoryCapture()
        else ok,reason=false,'missing-memory-api' end
        message=ok and L['Memory capture stopped. Open Memory report to copy the observations.']
            or L['Memory capture is unavailable: %s']:format(tostring(reason or L['Unknown']))
    elseif action=='memoryreport' then
        local report,reason
        if type(self.GetMemoryCaptureReport)=='function' then report,reason=self:GetMemoryCaptureReport() end
        if report then self:ShowConditionText(report,L['Memory capture']);return true,'' end
        ok=false;message=L['Memory capture is unavailable: %s']:format(tostring(reason or 'not-captured'))
    elseif action=='probe' then
        return runNativeProbe(self)
    elseif action=='report' then
        local report,reason=self:GetCPUProfileReport()
        if report then self:ShowConditionText(report,L['CPU profile']);return true,'' end
        ok=false;message=failure(reason)
    else
        ok=false;message=L['Usage: /rm cpu [start|report|cancel|probe|runtime|runtimereport|memory|memorystop|memoryreport]']
    end
    self:print(message)
    return ok,message
end

function addon:OnCPURuntimeCaptureFinished(_,status)
    if status=='complete' then
        self:print(L['Runtime capture complete. Use General > Runtime report or /rm cpu runtimereport to view and copy it.'])
    elseif status=='invalid' then
        self:print(L['Runtime capture ended without complete measurements. Open Runtime report for details.'])
    end
end

function addon:OnCPUProfileFinished(_,status)
    if status=='complete' then
        self:print(L['CPU capture complete. Use General > CPU report or /rm cpu report to view and copy it.'])
    elseif status=='invalid' then
        self:print(L['CPU capture could not produce valid measurements. Open CPU report for details.'])
    end
end

function addon:OnMemoryCaptureFinished(_,status)
    if status=='complete' then self:print(L['Memory capture complete. Use General > Memory report or /rm cpu memoryreport to view and copy it.'])
    elseif status=='invalid' then self:print(L['Memory capture ended with unavailable observations. Open Memory report for details.']) end
end
