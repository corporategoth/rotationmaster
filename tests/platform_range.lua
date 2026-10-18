local F=dofile('tests/fixtures/addon.lua')
local fixture=dofile('tests/fixtures/platform.lua')
local test,finish=F.suite()
local modules={'Platform/client.lua','Platform/spells.lua','Platform/range.lua'}
test('native attack range uses normalized booleans and legacy numeric results',function()
    local result=true
    local p=fixture({C_Spell={IsSpellInRange=function(id,unit) assert(id==6603 and unit=='target');return result end},
        LibStub=function() error('must not use an estimate after a native result') end},modules)
    assert(p:IsBeyondMeleeRange('target')==false)
    result=false;assert(p:IsBeyondMeleeRange('target')==true)
    p=fixture({GetSpellInfo=function(id) assert(id==6603);return 'Localized Attack',nil,123,nil,nil,nil,6603 end,
        IsSpellInRange=function(name,unit) assert(name=='Localized Attack' and unit=='target');return 0 end},modules)
    assert(p:IsBeyondMeleeRange('target')==true)
end)
test('interval estimates distinguish known close, known beyond and uncertainty',function()
    local low,high=0,5
    local p=fixture({C_Spell={IsSpellInRange=function() return nil end},LibStub=function()
        return {GetRange=function(_,unit,visible) assert(unit=='target' and visible);return low,high end}
    end},modules)
    assert(p:IsBeyondMeleeRange('target')==false)
    low,high=5,8;assert(p:IsBeyondMeleeRange('target')==true)
    high=nil;assert(p:IsBeyondMeleeRange('target')==true)
    low,high=0,8
    local beyond,why=p:IsBeyondMeleeRange('target');assert(beyond==nil and why=='range-uncertain')
    low,high=nil,nil;beyond,why=p:IsBeyondMeleeRange('target');assert(beyond==nil and why=='range-unavailable')
end)
test('restricted or failed native checks never fall through to an estimate',function()
    local opaque={}
    local p=fixture({C_Spell={IsSpellInRange=function() return opaque end},
        canaccessvalue=function(v) return not rawequal(v,opaque) end,
        LibStub=function() error('restricted result fell through') end},modules)
    local result,why=p:IsBeyondMeleeRange('target');assert(result==nil and why=='restricted-value')
    p=fixture({C_Spell={IsSpellInRange=function() error('blocked') end},LibStub=function() error('failed result fell through') end},modules)
    result,why=p:IsBeyondMeleeRange('target');assert(result==nil and why=='api-error')
end)
test('beyond-melee condition preserves unavailable estimates under NOT',function()
    local f=F.new();f.env.UnitExists=function() return true end
    f.load('Platform/client.lua');f.load('Platform/spells.lua');f.load('Platform/range.lua');f.load('Core/conditions.lua');f.load('Conditions/range.lua')
    local value={type='NOT',value={type='BEYOND_MELEE',unit='target'}}
    assert(f.addon:evaluateConditionResult(value).status=='unavailable')
    f.env.C_Spell={IsSpellInRange=function() return false end}
    assert(not f.addon:evaluateCondition(value))
end)
finish()
