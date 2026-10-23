local F=dofile('tests/fixtures/addon.lua')
local platform=dofile('tests/fixtures/platform.lua')
local test,finish=F.suite()
local modules={'Platform/client.lua','Platform/spells.lua','Platform/actions.lua'}
local function setup(extra)
    local env={WOW_PROJECT_ID=5,WOW_PROJECT_BURNING_CRUSADE_CLASSIC=5,
        UnitAffectingCombat=function(unit)assert(unit=='player');return false end}
    for key,value in pairs(extra or{})do env[key]=value end
    return platform(env,modules)
end

test('idle implicit attack check does not allocate a discarded query plan',function()
    local p=setup()
    -- Measure actual product allocations without trace-elimination of the
    -- temporary containers. This is a gross allocation budget, not elapsed CPU.
    if jit then jit.off(p.IsMeleeAttackNeeded,true)end
    collectgarbage('collect');collectgarbage('stop')
    local before=collectgarbage('count')
    local ok,reason=pcall(function()
        for _=1,128 do assert(p:IsMeleeAttackNeeded('target')==false)end
    end)
    local perCall=(collectgarbage('count')-before)/128
    collectgarbage('restart')
    assert(ok,reason)
    assert(perCall<0.125,'idle implicit attack allocated '..perCall..' KiB per call')
end)

test('implicit checks retain their original order and captured provider heads',function()
    local trace={}
    local function note(label,expected,...)
        assert(select('#',...)==#expected)
        for i=1,#expected do assert(select(i,...)==expected[i])end
        trace[#trace+1]=label
    end
    local p,e=setup()
    e.UnitAffectingCombat=function(...)
        note('combat',{'player'},...)
        e.UnitCanAttack=function()error('adopted a later provider within one check')end
        return true
    end
    e.UnitExists=function(...)note('exists',{'target'},...);return true end
    e.UnitCanAttack=function(...)note('attackable',{'player','target'},...);return true end
    e.UnitIsDeadOrGhost=function(...)note('dead',{'target'},...);return false end
    e.UnitHasVehicleUI=function(...)note('vehicle',{'player'},...);return false end
    p.IsCurrentSpell=function(_,id)assert(id==6603);trace[#trace+1]='active';return false end
    p.IsBeyondMeleeRange=function(_,unit)assert(unit=='target');trace[#trace+1]='range';return false end
    assert(p:IsMeleeAttackNeeded('target')==true)
    assert(table.concat(trace,',')=='combat,exists,attackable,dead,vehicle,active,range')
end)

test('first unavailable or false implicit check still short circuits later queries',function()
    local p,e=setup({UnitExists=function()error('unreached existence query')end})
    assert(p:IsMeleeAttackNeeded('target')==false)
    e.UnitAffectingCombat=function()return nil end
    local value,reason=p:IsMeleeAttackNeeded('target')
    assert(value==nil and reason=='invalid-api-result')
    e.UnitAffectingCombat=function()error('unavailable')end
    value,reason=p:IsMeleeAttackNeeded('target')
    assert(value==nil and reason=='api-error')
    e.UnitAffectingCombat=nil
    value,reason=p:IsMeleeAttackNeeded('target')
    assert(value==nil and reason=='missing-api')
end)

test('boolean validation preserves the public method entry environment',function()
    for _,replaceDuringCall in ipairs({false,true})do
        local p,e=setup()
        local realType=type
        local proxy=setmetatable({type=function(value)
            if realType(value)=='boolean'then return 'number'end
            return realType(value)
        end},{__index=e})
        setfenv(p.IsMeleeAttackNeeded,proxy)
        if replaceDuringCall then
            e.UnitAffectingCombat=function()
                setfenv(p.IsMeleeAttackNeeded,e)
                return false
            end
        end
        local value,reason=p:IsMeleeAttackNeeded('target')
        assert(value==nil and reason=='invalid-api-result')
    end
end)

finish()
