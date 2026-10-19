local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function fixture()
    local forwarded={}
    local handler=function(message) forwarded[#forwarded+1]=message end
    local env=setmetatable({GetTime=function() return 12 end,
        debugstack=function() return 'Interface/AddOns/rotationmaster/example.lua:7: callback' end,
        GetBuildInfo=function() return '2.5.6','12345','date',20506 end,
        GetLocale=function() return 'enUS' end,
        C_AddOns={GetAddOnMetadata=function(_,key) return key=='Version' and 'test-version' or nil end},
    }, {__index=_G})
    env.geterrorhandler=function() return handler end
    local addon={}
    local chunk=assert(loadfile('Diagnostics/errors.lua'));setfenv(chunk,env);chunk('rotationmaster',addon)
    return addon.Diagnostics, env, forwarded, function(fn) handler=fn end, addon
end

test('diagnostics preserve arguments and nil-hole returns',function()
    local d=fixture()
    local receiver={}
    local ok,a,b,c=d:Call({module='test'},function(self,x,y)
        assert(self==receiver and x==nil and y==4)
        return 1,nil,3
    end,receiver,nil,4)
    assert(ok and a==1 and b==nil and c==3)
    assert(#d:GetReports()==0)
end)
test('original error forwards once to current collector and retains stack/context',function()
    local d,_,original,setHandler=fixture()
    local newer={}
    setHandler(function(message) newer[#newer+1]=message end)
    local ok,id=d:Call({module='conditions',operation='evaluate',conditionPath='root.value[1]',conditionTag='BUFF',stepId='step-9',
                       rotationId='rotation-1',private={playerName='Private'}},function() error('bad condition',0) end)
    assert(not ok and type(id)=='number')
    assert(#original==0 and #newer==1 and newer[1]=='bad condition')
    local text=d:FormatReport(id)
    assert(text:find('bad condition',1,true) and text:find('example.lua:7',1,true))
    assert(text:find('root.value[1]',1,true) and text:find('rotation-1',1,true))
    assert(not text:find('Private',1,true))
    assert(text:find('step-9',1,true) and text:find('BUFF',1,true))
end)
test('opaque rotation handles are resolved to canonical diagnostic IDs and retired handles are omitted',function()
    local d,_,_,_,addon=fixture();local handle=string.char(1)..'rm:rotation:7';addon.currentSpec=0
    addon.ResolveRotationReference=function(_,spec,value) assert(spec==0 and value==handle);return {kind='custom',address={id='canonical-id'}} end
    local _,id=d:Call({rotationId=handle},function() error('current failure',0) end)
    assert(d:GetReports()[1].context.rotationId=='canonical-id' and not d:FormatReport(id):find(handle,1,true))
    addon.ResolveRotationReference=function() return nil,'retired' end
    local _,nextId=d:Call({rotationId=handle},function() error('retired failure',0) end)
    assert(not d:FormatReport(nextId):find(handle,1,true))
end)
test('repeated errors group locally and records are bounded',function()
    local d=fixture()
    for _=1,4 do d:Call({module='same'},function() error('repeat',0) end) end
    local reports=d:GetReports()
    assert(#reports==1 and reports[1].count==4)
    reports[1].count=999
    assert(d:GetReports()[1].count==4,'caller mutated stored report')
    for i=1,130 do d:Call({module='distinct'},function() error('failure '..i,0) end) end
    assert(#d:GetReports()<=100)
    d:Clear();assert(#d:GetReports()==0)
end)
test('missing or throwing collector does not recurse or lose original record',function()
    local d,env,_,setHandler=fixture()
    env.geterrorhandler=nil
    assert(not d:Call({},function() error('no collector',0) end))
    local calls=0
    env.geterrorhandler=function() return function()
        calls=calls+1
        d:Call({},function() error('nested collector error',0) end)
        error('collector failed',0)
    end end
    assert(not d:Call({},function() error('original failure',0) end))
    assert(calls==1)
    local all=d:FormatReport()
    assert(all:find('original failure',1,true))
end)
test('reports identify exact build and omit unreadable context fields',function()
    local d,env=fixture()
    local secret={}
    env.issecretvalue=function(value) return value==secret end
    local ok,id=d:Call({module='tests',event=secret},function() error('test',0) end)
    assert(not ok)
    local text=d:FormatReport(id)
    assert(text:find('12345',1,true) and text:find('20506',1,true))
    assert(d:GetReports()[1].context.event==nil)
end)
test('default report redacts identities while explicitly requested original detail is preserved',function()
    local d,env,forwarded=fixture()
    env.UnitName=function(unit) if unit=='player' then return 'Alice','ExampleRealm' end end
    env.GetRealmName=function() return 'ExampleRealm' end
    local message='Alice-ExampleRealm Player-1234-00ABCDEF failed a spell'
    local ok,id=d:Call({},function() error(message,0) end)
    assert(not ok and forwarded[1]==message)
    local safe=d:FormatReport(id)
    assert(not safe:find('Alice',1,true) and not safe:find('ExampleRealm',1,true))
    assert(not safe:find('Player-1234-00ABCDEF',1,true))
    assert(d:FormatReport(id,true):find(message,1,true))
    assert(d:GetReports()[1].rawMessage==nil)
end)
test('custom-source detail requires an explicit raw export choice',function()
    local d,env=fixture()
    env.debugstack=function() return '[string "local privateKey = SECRET"]:4: callback' end
    local ok,id=d:Call({customCode=true},function() error('private custom source SECRET',0) end)
    assert(not ok)
    assert(not d:FormatReport(id):find('SECRET',1,true))
    assert(d:FormatReport(id,true):find('SECRET',1,true))
end)
test('diagnostics include guarded product ruleset and unverified combat policy',function()
    local d,env,_,_,addon=fixture()
    env.WOW_PROJECT_ID=18;env.WOW_PROJECT_CAMELOT=18
    env.C_GameRules={GetCurrentGameModeRecordID=function() return 77 end}
    local chunk=assert(loadfile('Platform/client.lua'));setfenv(chunk,env);chunk('rotationmaster',addon)
    local ok,id=d:Call({},function() error('platform report',0) end)
    assert(not ok)
    local text=d:FormatReport(id)
    assert(text:find('Platform family: forever',1,true))
    assert(text:find('gameModeId: 77',1,true))
    assert(text:find('runtimeVerified: false',1,true))
    assert(text:find('combatDataPolicy: restricted',1,true))
    addon.Platform.GetClientInfo=function() error('metadata unavailable') end
    assert(not d:Call({},function() error('still captured',0) end))
    assert(d:FormatReport():find('still captured',1,true))
end)
test('diagnostic handoff checks access permission even for ordinary scalar types',function()
    local d,env,forwarded,_,addon=fixture()
    env.canaccessvalue=function(v) return v~='access-denied-scalar' end
    addon.Platform={GetClientInfo=function() return {family='tbc',seasonId='access-denied-scalar',private='private-text'} end}
    local ok,id=d:Call({event='access-denied-scalar',private='private-text'},function() error('handoff test',0) end)
    assert(not ok and forwarded[1]=='handoff test')
    local report=d:GetReports()[1]
    assert(report.context.event==nil and report.context.platform_seasonId==nil)
    local text=d:FormatReport(id)
    assert(not text:find('access-denied-scalar',1,true) and not text:find('private-text',1,true))
end)
test('owned callback wrappers preserve returns and forward a failure once without replacing the global collector',function()
    local d,env,forwarded=fixture();local original=env.geterrorhandler()
    local wrapped=d:Wrap({module='ui',operation='OnClick'},function(_,value) if value then return 1,nil,3 end;error('owned UI callback failed',0) end)
    local x,y,z=wrapped({},true);assert(x==1 and y==nil and z==3)
    wrapped({});wrapped({});assert(#forwarded==1 and env.geterrorhandler()==original)
    local report=d:GetReports()[1];assert(report.context.module=='ui' and report.context.operation=='OnClick')
end)
test('reported RM warnings chain the existing collector and exclude unrelated addons and recursive forwarding',function()
    local d,env,forwarded,setHandler=fixture();local original=env.geterrorhandler()
    env.seterrorhandler=setHandler
    assert(d:ObserveReportedErrors());local report=env.geterrorhandler();assert(report~=original)
    local message="AceLocale-3.0: rotationmaster: Missing entry for 'Weapon'"
    assert(d:Call({module='ui',operation='OnClick'},function() report(message) end))
    assert(#forwarded==1 and #d:GetReports()==1 and d:GetReports()[1].context.operation=='OnClick')
    env.debugstack=function() return 'Interface/AddOns/rotationmaster/Diagnostics/errors.lua:140\nInterface/AddOns/OtherAddon/main.lua:2' end;report('other addon warning');assert(#forwarded==2 and #d:GetReports()==1)
    env.debugstack=function() return 'Interface/AddOns/rotationmaster/example.lua:7: callback' end
    d:Call({module='ui'},function() error('thrown',0) end);assert(#d:GetReports()==2 and #forwarded==3,'thrown failure double captured')
    setHandler(function(message) report(message) end);d:ObserveReportedErrors();env.geterrorhandler()('new collector forwards through older wrapper')
    assert(#d:GetReports()==3 and #forwarded==4,'collector chaining double captured')
end)

finish()
