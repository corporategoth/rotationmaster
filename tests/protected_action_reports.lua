local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function fixture(options)
    options=options or {};local listeners,forwarded={},{}
    local env=setmetatable({_G=false,GetTime=function() return 1 end,
        geterrorhandler=function() return function(v) forwarded[#forwarded+1]=v end end,
        debugstack=function() return 'Interface/AddOns/rotationmaster/Platform/communication.lua:1' end,
    },{__index=_G});env._G=env
    env.CreateFrame=function()
        local frame={events={}};listeners[#listeners+1]=frame
        function frame:RegisterEvent(event) if options.registrationError then error('registration failed') end;self.events[event]=true end
        function frame:UnregisterAllEvents() self.events={} end
        function frame:SetScript(name,handler) self[name]=handler end
        return frame
    end
    local addon={};local chunk=assert(loadfile('Diagnostics/errors.lua'));setfenv(chunk,env);chunk('rotationmaster',addon)
    local function emit(event,owner,fn)
        for _,frame in ipairs(listeners) do if frame.events[event] and frame.OnEvent then frame.OnEvent(frame,event,owner,fn) end end
    end
    return addon.Diagnostics,env,emit,forwarded,listeners
end
test('native blocked actions become copyable reports without a thrown Lua error',function()
    local d,_,emit,forwarded,listeners=fixture()
    local ok=d:Call({module='events',event='UNIT_SPELLCAST_START'},function()
        emit('ADDON_ACTION_BLOCKED','rotationmaster','UNKNOWN()');return 'continued'
    end)
    assert(ok,'native block is not a thrown Lua error')
    local reports=d:GetReports();assert(#reports==1,'missing blocked-action report')
    local text=d:FormatReport(reports[1].id)
    assert(text:find('ADDON_ACTION_BLOCKED',1,true) and text:find('UNKNOWN()',1,true))
    assert(text:find('UNIT_SPELLCAST_START',1,true),'originating event lost')
    assert(#forwarded==0,'observer must not re-forward BugJar event as a Lua error')
    assert(#listeners==1 and not listeners[1].OnUpdate,'no polling observer')
end)
test('only exact readable RM attribution is accepted for either native security event',function()
    local d,e,emit=fixture();local secret={};e.issecretvalue=function(v)return v==secret end
    for _,owner in ipairs({'OtherAddon','rotationmaster-helper','Interface/AddOns/rotationmaster',secret}) do emit('ADDON_ACTION_FORBIDDEN',owner,'DoSomething()') end
    assert(#d:GetReports()==0)
    emit('ADDON_ACTION_FORBIDDEN','RotationMaster',secret)
    local text=d:FormatReport();assert(#d:GetReports()==1 and text:find('ADDON_ACTION_FORBIDDEN',1,true))
    assert(not text:find('table:',1,true),'opaque function label escaped')
end)
test('repeated native blocks group and Clear retires their reports',function()
    local d,_,emit=fixture()
    for _=1,5 do emit('ADDON_ACTION_BLOCKED','rotationmaster','UNKNOWN()') end
    assert(#d:GetReports()==1 and d:GetReports()[1].count==5)
    for i=1,110 do emit('ADDON_ACTION_FORBIDDEN','rotationmaster','Function'..i..'()') end
    assert(#d:GetReports()==100)
    d:Clear();emit('ADDON_ACTION_BLOCKED','rotationmaster','UNKNOWN()')
    assert(#d:GetReports()==1 and d:GetReports()[1].count==1)
end)
test('diagnostic recursion and failed registration do not escape or affect other collectors',function()
    local d,e,emit,forwarded=fixture();e.GetTime=function() emit('ADDON_ACTION_BLOCKED','rotationmaster','recursive()');return 1 end
    emit('ADDON_ACTION_BLOCKED','rotationmaster','outer()');assert(#d:GetReports()==1 and #forwarded==0)
    local broken,_,_,_,listeners=fixture({registrationError=true})
    assert(#broken:GetReports()==0 and not next(listeners[1].events) and not listeners[1].OnEvent)
end)
finish()
