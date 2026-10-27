-- Unit types: focus where the client has a focus system (probed, not a project
-- id), and the group unit types (main tank, main assist, assigned tank,
-- assigned healer, group leader) that resolve to a real token when a
-- condition is evaluated. See docs/unit-types.md.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local C=dofile('tests/fixtures/condition_client.lua')
local SECRET,expect,status,support=C.SECRET,C.expect,C.status,C.support
local KINDS={'maintank','mainassist','assignedtank','assignedhealer','groupleader'}

-- A client with a fake group. s.raid, s.members, s.roster[i]={role=...}, s.roles[token], s.leader=token.
local function client(name,setup)
    local f,a,e=C.load(name,'WARRIOR',{'Platform/focus_unit.lua','Platform/group_units.lua','Core/group_unit_resolution.lua'})
    local s={calls={},raid=false,members=0,roster={},roles={},leader=nil,combat={}}
    local function hit(n) s.calls[n]=(s.calls[n] or 0)+1 end
    e.GetNumGroupMembers=function() hit('GetNumGroupMembers');return s.members end
    e.IsInRaid=function() return s.raid end
    e.GetRaidRosterInfo=function(index) hit('GetRaidRosterInfo');local row=s.roster[index];if not row then return nil end
        return 'Name'..index,0,1,60,'Warrior','WARRIOR','Zone',true,false,row.role,false,'NONE' end
    e.UnitGroupRolesAssigned=function(unit) hit('UnitGroupRolesAssigned');return s.roles[unit] or 'NONE' end
    e.UnitIsGroupLeader=function(unit) hit('UnitIsGroupLeader');return s.leader==unit end
    e.UnitAffectingCombat=function(unit) hit('UnitAffectingCombat');s.asked=unit;return s.combat[unit] or false end
    e.UnitExists=function() return true end
    e.UnitIsUnit=function(a,b) return a==b end
    e.UnitGUID=function(unit) return unit end;e.UnitIsEnemy=function() return true end;e.C_CVar={GetCVar=function() return '40' end}
    if setup then setup(e,s) end
    f.load('constants.lua')
    a.conditionRegistryVersion=(a.conditionRegistryVersion or 0)+1
    return f,a,e,s
end

local function hasFocus(a) return a.units.focus~=nil and a.units.focustarget~=nil and a.unitsPossessive.focus~=nil end
test('the focus units are offered where the client has a focus system, probed rather than read from the project id',function()
    for _,name in ipairs({'retail','forever','mists','tbc'}) do
        local _,a=client(name);assert(hasFocus(a),name..' lost the focus units')
    end
    -- Era without any sign of a focus system and without an event catalog: the family answers no.
    local _,era=client('era',function(e) e.C_EventUtils=nil;e.FocusUnit=nil;e.FocusFrame=nil end);assert(not hasFocus(era),'Era without a focus system offered focus')
    -- The event catalog is the probe: a client that knows PLAYER_FOCUS_CHANGED has focus, whatever its project.
    local _,known=client('era',function(e) e.C_EventUtils={IsEventValid=function(event) return event=='PLAYER_FOCUS_CHANGED' end};e.FocusUnit=nil;e.FocusFrame=nil end)
    assert(hasFocus(known),'Era whose event catalog lists PLAYER_FOCUS_CHANGED did not offer focus')
    -- ...and one whose catalog does not, and has no FocusUnit or FocusFrame, has none (even on a family that used to have it).
    local _,none=client('retail',function(e) e.C_EventUtils={IsEventValid=function() return false end};e.FocusUnit=nil;e.FocusFrame=nil end)
    assert(not hasFocus(none),'a client with no focus system offered focus')
    -- The function and the frame are signs of their own.
    local _,fn=client('era',function(e) e.C_EventUtils={IsEventValid=function() return false end};e.FocusUnit=function() end end);assert(hasFocus(fn))
    local _,frame=client('era',function(e) e.C_EventUtils=nil;e.FocusUnit=nil;e.FocusFrame={} end);assert(hasFocus(frame))
    local _,failing=client('era',function(e) e.C_EventUtils={IsEventValid=function() error('boom') end};e.FocusUnit=nil;e.FocusFrame=nil end)
    assert(not hasFocus(failing),'a failing probe on Era is the family answer: no')
    local _,b=client('tbc',function(e) e.C_EventUtils=nil;e.FocusUnit=nil;e.FocusFrame=nil end);assert(hasFocus(b),'a client that cannot be probed keeps its family answer')
end)

test('a unit condition accepts focus exactly where it is offered',function()
    local _,a=client('mists');local def=a.conditionDefinitions.COMBAT
    assert(def.valid(0,{unit='focus'}) and def.valid(0,{unit='focustarget'}))
    local _,era=client('era',function(e) e.C_EventUtils=nil;e.FocusUnit=nil;e.FocusFrame=nil end)
    assert(not era.conditionDefinitions.COMBAT.valid(0,{unit='focus'}) and era.conditionDefinitions.COMBAT.valid(0,{unit='target'}))
end)

test('the group unit types are offered where the client can resolve them',function()
    for _,name in ipairs({'retail','forever','mists','wrath'}) do
        local _,a=client(name);for _,kind in ipairs(KINDS) do assert(a.units[kind] and a.unitsPossessive[kind] and a.groupUnitKinds[kind],kind..' missing on '..name) end
    end
    for _,name in ipairs({'tbc','era'}) do
        local _,a=client(name)
        for _,kind in ipairs({'maintank','mainassist','groupleader'}) do assert(a.units[kind],kind..' missing on '..name) end
        for _,kind in ipairs({'assignedtank','assignedhealer'}) do assert(not a.units[kind] and a.groupUnitKinds[kind],kind..' offered on '..name..' or forgotten') end
    end
    local _,a=client('retail',function(e) e.GetRaidRosterInfo=nil end)
    assert(not a.units.maintank and not a.units.mainassist and a.units.groupleader,'a missing API hid the wrong kinds')
end)

local function raid(s,members,roles) s.raid=true;s.members=members;s.roster={};for i=1,members do s.roster[i]={role=roles and roles[i]} end end
test('maintank and mainassist read the raid roster role and resolve to the first holder',function()
    for _,name in ipairs(C.order) do
        local _,a,_,s=client(name)
        raid(s,10,{[3]='MAINTANK',[4]='MAINASSIST',[7]='MAINTANK'})
        assert(a.Platform:ResolveGroupUnit('maintank')=='raid3',name);assert(a.Platform:ResolveGroupUnit('mainassist')=='raid4',name)
        raid(s,10,{[5]='maintank',[6]='MainAssist'});assert(a.Platform:ResolveGroupUnit('maintank')=='raid5' and a.Platform:ResolveGroupUnit('mainassist')=='raid6',name..' the role case must not matter')
        raid(s,40,{[40]='MAINTANK'});assert(a.Platform:ResolveGroupUnit('maintank')=='raid40',name..' a full raid of 40 is still resolved')
        raid(s,10);local token,why=a.Platform:ResolveGroupUnit('maintank');assert(token==nil and why=='no-assigned-unit',name..' nobody is main tank')
        s.raid=false;s.members=5;token,why=a.Platform:ResolveGroupUnit('mainassist');assert(token==nil and why=='no-assigned-unit',name..' a party has no main assist')
        raid(s,3,{[2]=SECRET});token,why=a.Platform:ResolveGroupUnit('maintank');assert(token==nil and why=='restricted-value',name..' an unreadable role')
        raid(s,3,{[2]=7});token,why=a.Platform:ResolveGroupUnit('maintank');assert(token==nil and why=='invalid-api-result',name..' a malformed role')
    end
    local _,a,e,s=client('retail');raid(s,3,{[1]='MAINTANK'});e.GetRaidRosterInfo=function() error('boom') end
    local token,why=a.Platform:ResolveGroupUnit('maintank');assert(token==nil and why=='api-error')
end)

test('assignedtank and assignedhealer read the assigned role over the party or raid tokens, you included',function()
    for _,name in ipairs({'retail','forever','mists'}) do
        local _,a,_,s=client(name)
        s.raid=false;s.members=4;s.roles={party2='HEALER',party3='TANK',party1='TANK'}
        assert(a.Platform:ResolveGroupUnit('assignedtank')=='party1',name..' the first tank');assert(a.Platform:ResolveGroupUnit('assignedhealer')=='party2',name)
        s.roles={player='TANK'};assert(a.Platform:ResolveGroupUnit('assignedtank')=='player',name..' you are the tank')
        s.raid=true;s.members=5;s.roles={raid5='HEALER'};assert(a.Platform:ResolveGroupUnit('assignedhealer')=='raid5',name..' in a raid')
        s.roles={};local token,why=a.Platform:ResolveGroupUnit('assignedtank');assert(token==nil and why=='no-assigned-unit',name)
        s.roles={raid2=SECRET};token,why=a.Platform:ResolveGroupUnit('assignedtank');assert(token==nil and why=='restricted-value',name..' an unreadable member is never skipped')
        s.roles={raid1=4};token,why=a.Platform:ResolveGroupUnit('assignedtank');assert(token==nil and why=='invalid-api-result',name)
    end
    for _,name in ipairs({'tbc','era'}) do
        local _,a=client(name);local token,why=a.Platform:ResolveGroupUnit('assignedtank');assert(token==nil and why=='no-group-roles',name)
    end
end)

test('groupleader resolves to the member who leads, and to nobody when alone',function()
    for _,name in ipairs(C.order) do
        local _,a,_,s=client(name)
        s.raid=false;s.members=3;s.leader='party1';assert(a.Platform:ResolveGroupUnit('groupleader')=='party1',name)
        s.leader='player';assert(a.Platform:ResolveGroupUnit('groupleader')=='player',name..' you lead')
        s.raid=true;s.members=6;s.leader='raid6';assert(a.Platform:ResolveGroupUnit('groupleader')=='raid6',name)
        s.raid=false;s.members=0;s.leader=nil;local token,why=a.Platform:ResolveGroupUnit('groupleader');assert(token==nil and why=='no-assigned-unit',name..' alone')
    end
    local _,a,e=client('retail',nil);e.UnitIsGroupLeader=function() return SECRET end
    local _,_,_,s=client('retail');
    local token,why=a.Platform:ResolveGroupUnit('groupleader');assert(token==nil and (why=='restricted-value' or why=='no-assigned-unit'))
end)

test('a condition on a group unit type evaluates its resolved token, once per kind per evaluation',function()
    for _,name in ipairs({'retail','mists'}) do
        local _,a,_,s=client(name)
        raid(s,10,{[3]='MAINTANK'});s.combat.raid3=true
        local tank={type='COMBAT',unit='maintank'}
        expect(a,tank,'match',name);assert(s.asked=='raid3','the condition asked about '..tostring(s.asked))
        s.combat.raid3=false;expect(a,tank,'no-match',name)
        raid(s,10);expect(a,tank,'unavailable',name..' nobody is main tank: unavailable, also under NOT')
        raid(s,10,{[2]='MAINTANK'});s.combat.raid2=true;s.calls={}
        local both=a:evaluateConditionResult({type='AND',value={tank,{type='COMBAT',unit='maintank'}}})
        assert(both.status=='match' and s.calls.GetRaidRosterInfo<=2 and s.calls.UnitAffectingCombat==1,name..' resolved more than once: '..tostring(s.calls.GetRaidRosterInfo))
        assert(a.conditionDefinitions.COMBAT.valid(0,tank),'the saved unit is a valid choice')
        assert(a.printCondition and a:printCondition(tank,0):find("main tank",1,true),'the summary names the unit')
    end
end)

test('the original condition value is never changed by resolution',function()
    local _,a,_,s=client('retail');raid(s,4,{[4]='MAINASSIST'});s.combat.raid4=true
    local value={type='COMBAT',unit='mainassist'};local before=a:CopySettingsData(value)
    expect(a,value,'match');assert(a:SettingsDataEqual(before,value) and value.unit=='mainassist')
    local resolved,why=a:ResolveConditionUnits({type='ISSAME',unit='maintank',otherunit='player'},{});assert(resolved==nil and why=='no-assigned-unit')
    raid(s,4,{[1]='MAINTANK',[4]='MAINASSIST'})
    resolved=a:ResolveConditionUnits({type='ISSAME',unit='maintank',otherunit='mainassist'},{});assert(resolved.unit=='raid1' and resolved.otherunit=='raid4' and resolved.type=='ISSAME')
    local plain={type='COMBAT',unit='target'};assert(a:ResolveConditionUnits(plain,{})==plain,'an ordinary unit is passed through untouched')
end)

test('support: a group unit type needs a client that can resolve it, for any condition',function()
    for _,name in ipairs({'retail','forever','mists'}) do local _,a=client(name)
        for _,kind in ipairs(KINDS) do assert(support(a,'COMBAT',{unit=kind})==nil,name..' '..kind) end
        assert(support(a,'ISSAME',{unit='player',otherunit='assignedhealer'})==nil)
    end
    for _,name in ipairs({'tbc','era'}) do local _,a=client(name)
        assert(support(a,'COMBAT',{unit='assignedtank'})=='no-group-roles' and support(a,'ISSAME',{unit='player',otherunit='assignedhealer'})=='no-group-roles',name)
        assert(support(a,'COMBAT',{unit='maintank'})==nil and support(a,'COMBAT',{unit='groupleader'})==nil,name)
    end
    local _,a=client('retail',function(e) e.GetRaidRosterInfo=nil end)
    assert(support(a,'COMBAT',{unit='maintank'})=='missing-api' and support(a,'COMBAT',{unit='groupleader'})==nil)
    assert(support(a,'COMBAT',{unit='target'})==nil,'ordinary units are not affected')
    local _,b=client('retail');assert(support(b,'DISTANCE_COUNT',{incombat=true})==nil)
    local _,c,e=client('retail');e.UnitAffectingCombat=nil
    assert(support(c,'DISTANCE_COUNT',{incombat=true})=='missing-api' and support(c,'DISTANCE_COUNT',{})==nil,'only the incombat option needs UnitAffectingCombat')
end)

test('a switch condition on a group unit type is present when someone holds it',function()
    local _,a,_,s=client('retail')
    local switch=a:ConsumeSwitchConditionEvaluator()
    if not switch then return end
    a.Platform.GetUnitPresenceObservation=function(_,unit) return unit=='raid3' end
    raid(s,5,{[3]='MAINTANK'});s.combat.raid3=true
    assert(switch(a,{type='COMBAT',unit='maintank'})==true,'the main tank was not found')
    raid(s,5);assert(switch(a,{type='COMBAT',unit='maintank'})==false,'nobody holding it must not match')
end)

-- Whole poll: the real addon in TOC order; a step gated on the group leader's combat state.
local root=assert(io.popen('pwd'):read('*l'))
test('whole poll: both engines follow a group unit type as its holder changes',function()
    local c=assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('price',root,true,root,true)({target=true,combat=true,buttons=true,poll=.15})
    local a,e=c.a,c.e
    for _,path in ipairs({'Platform/focus_unit.lua','Platform/group_units.lua','Core/group_unit_resolution.lua'}) do c.load(path) end
    local state={leader='party1',combat={party1=true,party2=false},members=3}
    e.GetNumGroupMembers=function() return state.members end;e.IsInRaid=function() return false end
    e.UnitIsGroupLeader=function(unit) return state.leader==unit end
    local original=e.UnitAffectingCombat
    e.UnitAffectingCombat=function(unit) if unit=='party1' or unit=='party2' then return state.combat[unit] end;return original(unit) end
    local exists=e.UnitExists
    e.UnitExists=function(unit) if unit=='party1' or unit=='party2' then return true end;return exists(unit) end
    c.load('constants.lua')
    a.db.profile.idle_poll=0
    local reference={kind='custom',address={scope='class',class='SHAMAN',owner='SHAMAN',spec=0,id='lead'}}
    assert(a:CommitRotationDraft(reference,nil,{body={name='Lead',priority=0,cooldowns={},rotation={
        {id='lead',type='spell',action=8042,conditions={type='COMBAT',unit='groupleader'}},
        {id='bolt',type='spell',action=403,conditions={}}}}},'class'))
    a:HandleCommand('set Lead');for _=1,3 do c.tick() end
    for _,engine in ipairs({'lean','standard'}) do
        assert(a:SetEvaluationEngine(engine))
        state.leader='party1';c.tick();c.tick();assert(a.currentSpell==8042,engine..' the leader fights: '..tostring(a.currentSpell))
        state.leader='party2';c.tick();c.tick();assert(a.currentSpell==403,engine..' the new leader does not: '..tostring(a.currentSpell))
        state.leader=nil;c.tick();c.tick();assert(a.currentSpell==403,engine..' nobody leads: the step is skipped, not guessed: '..tostring(a.currentSpell))
    end
    assert(a:SetEvaluationEngine('lean'));assert(not a.adviceErrorReport,'evaluation raised an error')
end)

-- constants.lua builds the unit lists when it loads, from what Platform/focus_unit.lua and Platform/group_units.lua
-- report, so the TOC has to list those two before it. Loaded the way the client loads the addon, a file moved after
-- constants.lua silently drops the focus unit (Classic Era) or every group unit type.
test('the real TOC order gives Classic Era its focus unit and Retail every group unit type',function()
    local T=dofile('tests/fixtures/toc_addon.lua')
    local era=T.new{project=2,expansion=1,class='WARRIOR'}.addon.units
    assert(era.focus,'Classic Era lost its focus unit')
    assert(era.maintank and era.groupleader,'Classic Era lost its group unit types')
    local retail=T.new{project=1,class='WARRIOR'}.addon.units
    for _,kind in ipairs(KINDS) do assert(retail[kind],'Retail lost the '..kind..' unit type') end
    assert(retail.focus,'Retail lost its focus unit')
end)

finish()
