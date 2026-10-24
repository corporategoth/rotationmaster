-- Retail action bars: the spell -> button -> glow path on a Retail 12.x model,
-- and the /rm debug glow diagnostic (Diagnostics/glow.lua) that reports
-- where that path stops.
local pass,fail=0,0
local function test(name,fn)local ok,err=pcall(fn);if ok then pass=pass+1;print('PASS '..name)else fail=fail+1;print('FAIL '..name..': '..tostring(err))end end
local root=assert(io.popen('pwd'):read('*l'))

-- The whole addon (tests/fixtures/wholepoll_shaman.lua), polling, with four
-- action buttons; the diagnostic is loaded as the TOC loads it.
local function whole(engine)
    local build=assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('trace',root,true,root,true)
    local c=build({buttons=true,target=true,poll=.15})
    c.a.db.profile.idle_poll=0;assert(c.a:SetEvaluationEngine(engine or 'standard'))
    c.load('Diagnostics/glow.lua')
    c.e.RotationMasterDB=c.e.RotationMasterDB or {}
    c.printed={};c.a.print=function(_,message,...) c.printed[#c.printed+1]=string.format(message,...) end
    c.a.ShowConditionText=function(_,text,heading) c.shown,c.heading=text,heading end
    for _=1,4 do c.tick() end
    return c
end
local function find(lines,pattern)
    for _,line in ipairs(lines) do if line:find(pattern) then return line end end
end

-- Diagnostic ------------------------------------------------------------------
test('diagnostic: walks the chain, names the step, the button and the glow, and saves the report',function()
    local c=whole()
    local lines,stop=c.a:RunGlowDiagnostic()
    assert(c.a.currentSpell==403,'fixture did not recommend 403: '..tostring(c.a.currentSpell))
    assert(find(lines,'^index: 4 buttons, 4 spells'),'index summary missing')
    assert(find(lines,'^ActionButton1%-12: 4 frames, type=action 4, holding an action 4, indexed 4, read errors 0'),'bar summary missing')
    assert(find(lines,'^  #1 spell action=403 conditions=match'),'first step missing')
    assert(find(lines,'spell 403 .* mapped=true'),'mapping missing')
    assert(find(lines,'ready=true known=true usable=true noPower=false cooldownReady=true range=true'),'readiness breakdown missing')
    assert(find(lines,'currentSpell=403 lastRequest spell=403 .* result=lit buttonsLit=1'),'glow request missing')
    assert(find(lines,'^expected=403'),'expected spell missing')
    assert(stop and stop:find('^none'),'unexpected stop: '..tostring(stop))
    assert(c.heading=='Glow diagnostic' and c.shown==table.concat(lines,'\n'),'report window not opened')
    local saved=c.e.RotationMasterDB.diagnostics.glow
    assert(#saved==1 and saved[1].lines==lines,'report not saved to RotationMasterDB.diagnostics.glow')
end)

test('diagnostic: keeps at most five reports, and shows the newest on request',function()
    local c=whole()
    for _=1,7 do c.a:RunGlowDiagnostic() end
    local saved=c.e.RotationMasterDB.diagnostics.glow
    assert(#saved==5,'reports not capped: '..#saved)
    c.shown=nil;c.a:HandleDebugCommand('glow show');assert(c.shown==table.concat(saved[5].lines,'\n'),'show did not open the newest report')
    c.a:HandleDebugCommand('nonsense');assert(c.printed[#c.printed]:find('Usage: /rm debug glow'),'usage not printed')
end)

test('diagnostic: names the first read error when the scan indexes nothing',function()
    local c=whole()
    c.e.GetActionInfo=function() error('modelled failure') end
    c.a:Fetch();for _=1,3 do c.tick() end
    local lines,stop=c.a:RunGlowDiagnostic()
    assert(stop:find('^the button scan indexed no buttons; first read error: .*modelled failure'),stop)
    assert(find(lines,'read errors 4'),'per-bar error count missing')
end)

test('diagnostic: an unready spell is reported with the piece that failed',function()
    local c=whole()
    c.setSpellReady(false);for _=1,3 do c.tick() end
    local lines=c.a:RunGlowDiagnostic()
    assert(find(lines,'cooldownReady=false'),'cooldown piece missing')
end)

test('diagnostic: a watch appends one line per second to the saved report',function()
    local c=whole()
    local timers={}
    c.a.ScheduleRepeatingTimer=function(_,fn,delay) local t={fn=fn,delay=delay};timers[#timers+1]=t;return t end
    c.a.CancelTimer=function(_,t) t.cancelled=true end
    local lines=c.a:RunGlowDiagnostic('3')
    assert(#timers==1 and timers[1].delay==1,'watch timer not scheduled')
    for _=1,3 do timers[1].fn() end
    assert(timers[1].cancelled,'watch did not stop')
    local watch=0;for _,line in ipairs(lines) do if line:find('^t=') then watch=watch+1 end end
    assert(watch==3,'watch lines: '..watch)
    assert(find(lines,'#1:selected=403'),'watch line lacks the step verdict')
    assert(c.e.RotationMasterDB.diagnostics.glow[1].lines==lines,'watch lines are not in the saved report')
end)

test('diagnostic: costs nothing until run (no frames, timers or saved data at load)',function()
    local c=whole()
    assert(c.e.RotationMasterDB.diagnostics==nil,'diagnostic wrote saved data before it was run')
end)

print(pass..' passed, '..fail..' failed');if fail>0 then os.exit(1)end
