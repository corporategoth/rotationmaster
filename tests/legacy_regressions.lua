-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function spatial()
    local f=F.new();local a=f.addon
    for _,path in ipairs({'Core/conditions.lua','Conditions/common.lua','Conditions/spatial.lua','Conditions/spatial_stats.lua'}) do f.load(path) end
    a.getCached=function(_,fn,...) if fn then return fn(...) end end
    f.env.Enum.PowerType.Mana=0
    f.env.UnitExists=function(unit) return unit=='player' or unit=='party1' or unit=='party2' end
    f.env.IsInRaid=function() return false end
    f.env.IsInGroup=function() return true end
    f.env.UnitPlayerOrPetInParty=function() return true end
    f.env.UnitPosition=function(unit)
        if unit=='player' then return 0,0,0,1 end
        if unit=='party1' then return 3,4,0,1 end
        if unit=='party2' then return 6,8,0,1 end
    end
    f.env.UnitHealth=function(unit) return ({player=50,party1=20,party2=80})[unit] end
    f.env.UnitHealthMax=function() return 100 end
    f.env.UnitPower=function(unit) return ({player=30,party1=10,party2=60})[unit] end
    f.env.UnitPowerMax=function() return 100 end
    return f
end
test('Distance keeps missing invalid and restricted range observations unavailable under NOT',function()
    local f=spatial();local a=f.addon;local provider=f.libraries['LibRangeCheck-3.0'];local low,high
    provider.GetRange=function() return low,high end
    local value={type='NOT',value={type='DISTANCE',unit='player',value=20}}
    assert(a:evaluateConditionResult(value).status=='unavailable','missing distance became true under NOT')
    low,high=0,10;assert(not a:evaluateCondition(value),'readable nearby interval did not match Distance')
    low,high=20,30;assert(a:evaluateCondition(value),'readable distant upper bound lost existing Distance semantics')
    for _,invalid in ipairs({-1,0/0,math.huge,'unknown'}) do high=invalid;assert(a:evaluateConditionResult(value).status=='unavailable','invalid interval became actionable') end
    local opaque={};low,high=0,opaque;a.Platform.CanReadValue=function(_,v) return v~=opaque end
    assert(a:evaluateConditionResult(value).status=='unavailable','restricted upper bound became actionable')
    provider.GetRange=function() error('provider failed') end
    assert(a:evaluateConditionResult(value).status=='unavailable','provider error escaped protected observation')
end)
test('proximity health and mana aggregates consume actual party values for min average and max',function()
    local f=spatial()
    for _,entry in ipairs({{'PROXIMITY_HEALTH',20,50,80},{'PROXIMITY_HEALTHPCT',.2,.5,.8},
        {'PROXIMITY_MANA',10,100/3,60},{'PROXIMITY_MANAPCT',.1,1/3,.6}}) do
        for i,operation in ipairs({'minimum','average','maximum'}) do
            local v={type=entry[1],unit='player',distance=20,operation=operation,operator='GREATERTHAN',value=entry[i+1]-.001}
            assert(f.addon:evaluateCondition(v),'aggregate failed for '..entry[1]..' '..operation)
            v.value=entry[i+1]+.001;assert(not f.addon:evaluateCondition(v),'aggregate compared the wrong values')
        end
    end
end)
test('empty proximity aggregates remain unavailable under NOT',function()
    local f=spatial();f.env.UnitExists=function() return false end
    local condition={type='NOT',value={type='PROXIMITY_HEALTH',unit='player',distance=20,operation='minimum',operator='LESSTHAN',value=50}}
    assert(f.addon:evaluateConditionResult(condition).status=='unavailable')
end)
test('proximity counters use the health and mana threshold rather than the requested count',function()
    local f=spatial()
    for _,entry in ipairs({{'PROXIMITY_HEALTHPCT_COUNT','health','healthoperator',.6},
        {'PROXIMITY_MANAPCT_COUNT','mana','manaoperator',.5},{'PROXIMITY_HEALTH_COUNT','health','healthoperator',-60}}) do
        local value={type=entry[1],unit='player',distance=20,operator='EQUALS',value=2}
        value[entry[2]]=entry[4];value[entry[3]]='LESSTHAN'
        assert(f.addon:evaluateCondition(value),'wrong threshold field in '..entry[1])
    end
end)
test('every proximity statistics editor renders and updates the shared distance controls',function()
    local f=spatial()
    for _,tag in ipairs({'PROXIMITY_HEALTH','PROXIMITY_HEALTH_COUNT','PROXIMITY_HEALTHPCT','PROXIMITY_HEALTHPCT_COUNT',
        'PROXIMITY_MANA','PROXIMITY_MANA_COUNT','PROXIMITY_MANAPCT','PROXIMITY_MANAPCT_COUNT'}) do
        local value={type=tag,unit='player',distance=20,operation='minimum',operator='EQUALS',value=2,
            health=50,healthoperator='LESSTHAN',mana=50,manaoperator='LESSTHAN'}
        local parent,top=f.widget('Group'),f.widget('Frame')
        parent:SetUserData('top',top);top:SetUserData('root',value);top:SetUserData('funcs',{print=function() return 'Updated condition' end})
        f.addon.conditionDefinitions[tag].widget(parent,0,value)
        local distance
        for _,child in ipairs(parent.children) do if child.type=='RM-ConditionEditBox' and child.label=='Distance' then distance=child end end
        assert(distance,'missing distance editor for '..tag)
        distance:Fire('OnEnterPressed','35');assert(value.distance==35 and top.statusText=='Updated condition')
    end
end)
test('swing time uses the real channel API and resets the estimate while channeling',function()
    local f=F.new();f.load('Conditions/weapon.lua')
    f.addon.getCached=function(_,fn,...) if fn then return fn(...) end end
    f.env.UnitAttackSpeed=function() return 2.6,2.6 end
    f.env.UnitCastingInfo=function() return nil end
    f.env.UnitChannelInfo=function() return 'Channel' end
    f.addon.lastMainSwing=99
    local value={operator='GREATERTHAN',value=2}
    assert(f.addon.definitions.SWING_TIME_REMAIN.evaluate(value,{},100))
    f.env.UnitChannelInfo=function() return nil end
    assert(not f.addon.definitions.SWING_TIME_REMAIN.evaluate(value,{},100))
end)
test('Lua editor default indentation uses the declared two-space setting',function()
    local f=F.new();f.load('LibsAugment/FAIAP.lua')
    local library=assert(f.addon.LuaSyntax)
    local text=library.indentCode('if true then\nprint(1)\nend',nil,nil)
    assert(text:find('\n  print(1)',1,true),'default indentation looked up an accidental global')
end)
test('explicit legacy repair removes a malformed union field without losing valid siblings',function()
    local f=F.new();f.load('Core/conditions.lua');f.load('Core/condition_catalog.lua');f.load('UI/condition_entrypoints.lua');f.load('validate.lua')
    f.addon:RegisterCondition('UNION_FIXTURE',{description='Fixture',fields={choice={'string','number'},kept='number'}})
    f.addon.warn=function() end
    local body={name='Fixture',switch={type='UNION_FIXTURE',choice={invalid=true},kept=7},rotation={},cooldowns={}}
    f.addon:validate_rotation('Fixture',f.env.DEFAULT,body,true)
    assert(body.switch.choice==nil and body.switch.type=='UNION_FIXTURE' and body.switch.kept==7)
end)
test('explicit repair preserves supported Boolean labels and Stop suppression',function()
    local f=F.new();f.load('Core/conditions.lua');f.load('Core/condition_catalog.lua');f.load('UI/condition_entrypoints.lua');f.load('validate.lua')
    f.addon.warn=function() end
    local body={name='Fixture',switch={type='AND',name='Opening checks',value={}},cooldowns={},rotation={
        {id='00000000-0000-0000-0000-000000000001',type='stop',suppress_attack=true,conditions={type='NOT',name='Combat boundary',value={}}}}}
    f.addon:validate_rotation('Fixture',f.env.DEFAULT,body,true)
    assert(body.switch.name=='Opening checks' and body.rotation[1].suppress_attack==true and body.rotation[1].conditions.name=='Combat boundary')
end)
test('explicit repair preserves tags description and attribution on flat rotations',function()
    local f=F.new();f.load('Core/conditions.lua');f.load('Core/condition_catalog.lua');f.load('UI/condition_entrypoints.lua');f.load('validate.lua')
    local warnings={};f.addon.warn=function(_,message,...) warnings[#warnings+1]=string.format(message,...) end
    f.addon.RotationData=dofile('tests/fixtures/rotation_data.lua')()
    local body={name='Fixture',description='A leveling rotation',tags={'AOE','MyLittlePony'},metadata={author='PreZ'},priority=42,switch={},cooldowns={},rotation={}}
    f.addon:validate_rotation('Fixture',f.env.DEFAULT,body,true)
    assert(body.tags and body.tags[2]=='MyLittlePony' and body.description=='A leveling rotation' and body.metadata.author=='PreZ','repair removed supported rotation metadata')
    assert(body.priority==42,'repair removed supported priority')
    assert(#warnings==0,'supported metadata was diagnosed as an extra field')
end)
test('legacy validation diagnoses malformed priorities and explicit repair restores the implicit zero',function()
    local f=F.new();local data=dofile('tests/fixtures/rotation_data.lua')();f.addon.RotationData=data;f.load('validate.lua')
    local warnings={};f.addon.warn=function(_,message,...) warnings[#warnings+1]=string.format(message,...) end
    for _,priority in ipairs({.5,100001,-100001,'bad',false}) do
        local body={name='Fixture',priority=priority,rotation={},cooldowns={},switch={}}
        warnings={};f.addon:validate_rotation('Fixture',f.env.DEFAULT,body,false)
        assert(#warnings>0 and body.priority==priority,'check silently accepted an invalid priority or changed data')
        warnings={};f.addon:validate_rotation('Fixture',f.env.DEFAULT,body,true)
        assert(#warnings>0 and body.priority==nil,'repair did not report and reset malformed priority')
    end
end)
test('legacy repair preserves nested branch data and refuses destructive repair of future branch fields',function()
    local f=F.new();f.load('Data/plain.lua');f.load('Data/tags.lua');f.load('Data/rotation_tree.lua');f.load('Data/validation.lua');f.load('Core/conditions.lua');f.load('Core/condition_catalog.lua');f.load('UI/condition_entrypoints.lua');f.load('validate.lua')
    f.addon.warn=function() end
    local body={name='Branch fixture',switch={},cooldowns={},rotation={{id='branch',type='branch',mode='true',name='Combat',conditions={},
        onTrue={{id='yes',type='spell',action=403,conditions={}}},onFalse={{id='no',type='stop',conditions={},suppress_attack=true}}}}}
    f.addon:validate_rotation('Fixture',f.env.DEFAULT,body,true)
    assert(body.rotation[1] and body.rotation[1].mode=='true' and body.rotation[1].onTrue[1].action==403 and body.rotation[1].onFalse[1].suppress_attack)
    body.rotation[1].future={coefficient=42};f.addon:validate_rotation('Fixture',f.env.DEFAULT,body,true)
    assert(body.rotation[1].future.coefficient==42,'legacy repair deleted unknown branch data')
end)
finish()
