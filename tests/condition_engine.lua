-- Real headless engine; asking for AceGUI fails immediately.
local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local addon={currentSpec=0,db={profile={}}}
local env=setmetatable({GetTime=function() return 100 end, DELETE='Delete'}, {__index=_G})
env.LibStub=function(name)
    assert(name=='AceLocale-3.0','Headless engine requested '..name)
    return {GetLocale=function() return setmetatable({}, {__index=function(_,key) return key end}) end}
end
local core=assert(loadfile('Core/conditions.lua'));setfenv(core,env);core('rotationmaster',addon)
local function definition(result)
    return {valid=function() return true end,evaluate=function() return result end,
            print=function() return result and 'yes' or 'no' end,fields={},description='Fixture'}
end
addon:RegisterCondition('YES',definition(true));addon:RegisterCondition('NO',definition(false))
test('nested Boolean evaluation preserves priority-condition truth tables',function()
    assert(addon:evaluateCondition({type='AND',value={{type='YES'},{type='NOT',value={type='NO'}}}}))
    assert(not addon:evaluateCondition({type='AND',value={{type='YES'},{type='NO'}}}))
    assert(addon:evaluateCondition({type='OR',value={{type='NO'},{type='YES'}}}))
    assert(not addon:evaluateCondition({type='OR',value={{type='NO'}}}))
    assert(addon:evaluateCondition({type='AND',value={}}))
    assert(not addon:evaluateCondition({type='OR',value={}}))
    assert(addon:evaluateCondition(nil))
    assert(addon:evaluateCondition({type='NO',disabled=true}))
end)
test('condition evaluation shares one cache and timestamp within a tree',function()
    local caches,times={},{}
    addon:RegisterCondition('RECORD',{valid=function() return true end,evaluate=function(_,cache,start)
        caches[#caches+1]=cache;times[#times+1]=start;return true
    end})
    assert(addon:evaluateCondition({type='AND',value={{type='RECORD'},{type='RECORD'}}}))
    assert(#caches==2 and caches[1]==caches[2] and times[1]==100 and times[2]==100)
end)
test('headless registry replacement and removal affect the same engine',function()
    addon:RegisterCondition('SWAP',definition(true));assert(addon:evaluateCondition({type='SWAP'}))
    addon:RegisterCondition('SWAP',definition(false));assert(not addon:evaluateCondition({type='SWAP'}))
    addon:UnregisterCondition('SWAP');assert(not addon:validateCondition({type='SWAP'},0))
    assert(addon.conditionDefinitions.YES)
end)
test('print validation and usefulness work without options rendering',function()
    assert(addon:printCondition({type='NOT',value={type='NO'}},0)=='NOT no')
    assert(addon:validateCondition({type='AND',value={{type='YES'}}},0))
    assert(not addon:validateCondition({type='UNKNOWN'},0))
    assert(addon:usefulCondition({type='YES'}))
    assert(not addon:usefulCondition({type='OR',value={}}))
end)
test('unknown invalid and unreadable conditions stay unavailable under NOT',function()
    addon:RegisterCondition('INVALID',{valid=function() return false end,evaluate=function() error('must not run') end})
    addon:RegisterCondition('UNREADABLE',{valid=function() return true end,evaluate=function() return nil,'restricted-aura' end})
    for _,tag in ipairs({'UNKNOWN','INVALID','UNREADABLE'}) do
        local tree={type='NOT',value={type=tag}}
        local result=addon:evaluateConditionResult(tree)
        assert(result.status=='unavailable',tag)
        assert(not addon:evaluateCondition(tree),tag)
        assert(type(result.reason)=='string')
    end
end)
test('unavailable propagates through AND and OR regardless of sibling order',function()
    for _,op in ipairs({'AND','OR'}) do
        for _,children in ipairs({{{type='YES'},{type='UNKNOWN'}},{{type='UNKNOWN'},{type='NO'}}}) do
            assert(addon:evaluateConditionResult({type=op,value=children}).status=='unavailable')
        end
    end
end)
test('malformed cyclic and overdeep trees fail closed without throwing',function()
    local cycle={type='NOT'};cycle.value=cycle
    local deep={type='YES'}
    for _=1,70 do deep={type='NOT',value=deep} end
    local sparse={[1]={type='YES'},[3]={type='YES'}}
    for _,tree in ipairs({42,'bad',{type='AND',value=1},{type='AND',value=sparse},
                         {type='AND',value={wrong={type='YES'}}}, {type='NOT'},cycle,deep}) do
        assert(addon:evaluateConditionResult(tree).status=='unavailable')
        assert(not addon:evaluateCondition(tree))
    end
end)
test('false child lists and non-Boolean disabled flags cannot enable advice',function()
    for _,tree in ipairs({{type='AND',value=false}, {type='OR',value=false},
                         {type='UNKNOWN',disabled='false'}, {type='YES',disabled=1}}) do
        assert(addon:evaluateConditionResult(tree).status=='unavailable')
        assert(not addon:evaluateCondition(tree))
        assert(not addon:evaluateCondition({type='NOT',value=tree}))
    end
end)
test('wide child lists are bounded before inspecting every entry',function()
    local children={}
    for i=1,100000 do children[i]={type='YES'} end
    debug.sethook(function() error('instruction budget exhausted') end,'',500000)
    local ok,result=pcall(function() return addon:evaluateConditionResult({type='AND',value=children}) end)
    debug.sethook()
    assert(ok,result)
    assert(result.status=='unavailable' and result.reason=='condition-limit')
end)
test('failing callbacks become unavailable and quarantine until replaced',function()
    local forwarded={}
    env.geterrorhandler=function() return function(err) forwarded[#forwarded+1]=err end end
    local diag=assert(loadfile('Diagnostics/errors.lua'));setfenv(diag,env);diag('rotationmaster',addon)
    local calls=0
    addon:RegisterCondition('BROKEN',{valid=function() return true end,evaluate=function()
        calls=calls+1;error('broken evaluator')
    end})
    for _=1,3 do
        local result=addon:evaluateConditionResult({type='NOT',value={type='BROKEN'}})
        assert(result.status=='unavailable')
    end
    assert(calls==1 and #forwarded==1)
    assert(addon.Diagnostics:FormatReport():find('condition.value',1,true))
    addon:RegisterCondition('BROKEN',definition(true))
    assert(addon:evaluateCondition({type='BROKEN'}))
    addon:RegisterCondition('BAD_VALID',{valid=function() error('bad fields') end,evaluate=function() error('must not run') end})
    assert(not addon:evaluateCondition({type='NOT',value={type='BAD_VALID'}}))
    assert(#forwarded==2)
end)
test('legacy nil predicates remain false without an unavailable reason',function()
    addon:RegisterCondition('LEGACY_NIL',definition(nil))
    assert(addon:evaluateConditionResult({type='LEGACY_NIL'}).status=='no-match')
    assert(addon:evaluateConditionResult({type='NOT',value={type='LEGACY_NIL'}}).status=='match')
end)
test('lifecycle callbacks receive only the documented tag on replacement and removal',function()
    local calls={}
    local function hook(label)
        return function(...)
            assert(select('#',...)==1 and (...)=='LIFECYCLE','lifecycle callback expected one tag argument')
            calls[#calls+1]=label
        end
    end
    addon:RegisterCondition('LIFECYCLE',{on_register=hook('register-old'),on_unregister=hook('unregister-old')})
    addon:RegisterCondition('LIFECYCLE',{on_register=hook('register-new'),on_unregister=hook('unregister-new')})
    addon:UnregisterCondition('LIFECYCLE')
    assert(table.concat(calls,',')=='register-old,unregister-old,register-new,unregister-new')
end)
finish()
