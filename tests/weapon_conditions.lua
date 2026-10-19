local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();f.load('Core/conditions.lua');f.load('Conditions/common.lua');f.load('Conditions/weapon.lua');f.load('Conditions/misc.lua')
    f.env.UnitCastingInfo=function() end;f.env.UnitChannelInfo=function() end
    return f,f.addon
end
local function node(kind,offhand,value) return {type=kind,offhand=offhand,operator='EQUALS',value=value} end
test('weapon enchant predicates select only their requested hand for every presence combination',function()
    local f,a=fixture()
    for _,main in ipairs({false,true}) do for _,off in ipairs({false,true}) do
        f.env.GetWeaponEnchantInfo=function() return main,12000,4,1,off,3000,2,2 end
        for _,selected in ipairs({false,true}) do local expected=main;if selected then expected=off end
            for _,kind in ipairs({'WEAPON','WEAPON_REMAIN','WEAPON_STACKS'}) do
                local amount=kind=='WEAPON_REMAIN' and (selected and 3 or 12) or (selected and 2 or 4)
                assert(a:evaluateCondition(node(kind,selected,amount))==expected,kind..' consulted the other hand')
            end
        end
    end end
end)
test('offhand swing remainder uses its own history even before any mainhand swing',function()
    local f,a=fixture();f.env.GetTime=function() return 100 end
    f.env.UnitAttackSpeed=function() return 3,2 end;a.lastMainSwing=nil;a.lastOffSwing=99
    assert(a:evaluateCondition(node('SWING_TIME_REMAIN',true,1)),'offhand ignored its own swing history')
    a.lastMainSwing=99;a.lastOffSwing=nil
    assert(a:evaluateCondition(node('SWING_TIME_REMAIN',false,2)),'mainhand consulted missing offhand history')
end)
test('selected missing or restricted weapon observations remain unavailable under NOT',function()
    local f,a=fixture();local opaque={};a.Platform.CanReadValue=function(_,value) return value~=opaque end
    f.env.GetWeaponEnchantInfo=function() return true,12000,4,1,opaque,3000,2,2 end
    assert(a:evaluateConditionResult({type='NOT',value=node('WEAPON',true,0)}).status=='unavailable','restricted enchant became a boolean')
    f.env.GetWeaponEnchantInfo=function() return true,12000,4,1,true,opaque,2,2 end
    assert(a:evaluateConditionResult({type='NOT',value=node('WEAPON_REMAIN',true,0)}).status=='unavailable','restricted duration became a comparison')
    f.env.GetWeaponEnchantInfo=function() return true,12000,4,1,true,3000,opaque,2 end
    assert(a:evaluateConditionResult({type='NOT',value=node('WEAPON_STACKS',true,0)}).status=='unavailable','restricted charges became a comparison')
    f.env.UnitAttackSpeed=function() return 3,nil end
    for _,kind in ipairs({'SWING_TIME','SWING_TIME_REMAIN'}) do assert(a:evaluateConditionResult({type='NOT',value=node(kind,true,0)}).status=='unavailable','missing offhand speed fell back to mainhand') end
    f.env.GetWeaponEnchantInfo=function() error('failed observation') end
    assert(a:evaluateConditionResult({type='NOT',value=node('WEAPON',false,0)}).status=='unavailable','failed observation escaped unavailable')
end)
test('PvP player summary chooses the same unit as validation and fields',function()
    local _,a=fixture();local text=a.conditionDefinitions.PVP.print(0,{unit='player'})
    assert(text:find('you are PVP flagged',1,true),'player summary used third-person grammar')
end)
finish()
