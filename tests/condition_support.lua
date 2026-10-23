-- Conditions that can never work on a client (missing API, restricted combat
-- data policy, another talent or glyph layout, an unknown family) are caught
-- statically: validation reports them unresolved, so the rotation is
-- incomplete and inactive through the ordinary eligibility path, with a
-- message naming the condition and the reason. Momentary causes stay
-- runtime-only. Support checks never evaluate the condition.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local corpus=dofile('tests/fixtures/default_corpus.lua')

local function client(project,expansion,class)
    local f=corpus.load(project,expansion,class or 'ROGUE',{modules=false})
    if type(f.addon.Platform.GetTalentLayout)~='function' then f.load('Platform/talents.lua') end
    f.load('Core/condition_support.lua')
    -- The universal unit natives these checks look for, as on every real client.
    for _,name in ipairs({'UnitExists','UnitIsPVP','UnitLevel','UnitAttackSpeed','UnitIsEnemy','UnitGUID'}) do
        if type(f.env[name])~='function' then f.env[name]=function() end end
    end
    f.env.C_CVar=f.env.C_CVar or {GetCVar=function() return '40' end}
    return f,f.addon
end
local function body(conditions)
    return {name='Support',priority=1,switch={},rotation={{id='step',type='spell',action=1752,conditions=conditions}},cooldowns={}}
end
local function validate(a,conditions)
    return a.RotationData.ValidateBody(body(conditions),a:GetRotationValidationOptions())
end
local function unsupported(report)
    for _,d in ipairs(report.diagnostics) do if d.code=='unsupported-condition' then return d end end
end

test('a probe-only condition is unresolved on Retail and Forever, supported on Era/TBC/Mists',function()
    local pvp={type='PVP',unit='player'}
    for _,c in ipairs({{2,0},{5,1},{19,4}})do
        local _,a=client(c[1],c[2]);local report=validate(a,pvp)
        assert(report.resolved and not unsupported(report),'project '..c[1]..' flagged PVP')
        assert(a:GetConditionSupport('PVP',a.conditionDefinitions.PVP,pvp)==nil)
        assert(a:validateCondition(pvp,0),'validateCondition refused a supported condition')
    end
    for _,c in ipairs({{1,12},{18,12}})do
        local _,a=client(c[1],c[2]);local report=validate(a,pvp);local d=unsupported(report)
        assert(not report.resolved and d and d.condition=='PVP' and d.reason=='unsupported-policy' and d.path=='$.body.rotation[1].conditions.type',
            'project '..c[1]..': '..tostring(d and d.reason))
        assert(report.valid,'an unsupported condition is incomplete, not invalid data')
        assert(not a:validateCondition(pvp,0),'auto-switch validity accepted an unsupported condition')
        local text=a:DescribeUnsupportedCondition(d)
        assert(text and text:find(a.conditionDefinitions.PVP.description,1,true) and text:find('not supported on this client',1,true)
            and text:find('restricted',1,true),tostring(text))
    end
end)

test('a missing native API is unresolved; a fallback name suffices',function()
    local f,a=client(2,0)
    local assisted={type='ASSISTED_SUGGESTION'}
    f.env.C_AssistedCombat=nil
    local d=unsupported(validate(a,assisted));assert(d and d.reason=='missing-api','no Assisted Combat API: '..tostring(d and d.reason))
    f.env.C_AssistedCombat={GetNextCastSpell=function() end}
    assert(not unsupported(validate(a,assisted)),'present Assisted Combat API still flagged')
    -- ZONEPVP accepts the namespaced reader or the global.
    local zone={type='ZONEPVP',zone='sanctuary'}
    f.env.C_PvP=nil;f.env.GetZonePVPInfo=nil
    assert(a:GetConditionSupport('ZONEPVP',a.conditionDefinitions.ZONEPVP,zone)=='missing-api')
    f.env.GetZonePVPInfo=function() end
    assert(a:GetConditionSupport('ZONEPVP',a.conditionDefinitions.ZONEPVP,zone)==nil)
    f.env.GetZonePVPInfo=nil;f.env.C_PvP={GetZonePVPInfo=function() end}
    assert(a:GetConditionSupport('ZONEPVP',a.conditionDefinitions.ZONEPVP,zone)==nil)
end)

test('talent references follow the client talent layout, and never read talents',function()
    local tree={type='TALENT',tree=1,talent=2,operator='GREATERTHANOREQUALS',value=1}
    local grid={type='TALENT',layout='grid',value=4}
    local legacy={type='TALENT',value=4}
    local _,era=client(2,0)
    assert(era:GetConditionSupport('TALENT',era.conditionDefinitions.TALENT,tree)==nil)
    assert(era:GetConditionSupport('TALENT',era.conditionDefinitions.TALENT,grid)=='talent-layout-mismatch')
    assert(era:GetConditionSupport('TALENT',era.conditionDefinitions.TALENT,legacy)=='historical-talent-layout')
    local _,mists=client(19,4)
    assert(mists:GetConditionSupport('TALENT',mists.conditionDefinitions.TALENT,grid)==nil)
    assert(mists:GetConditionSupport('TALENT',mists.conditionDefinitions.TALENT,tree)=='talent-layout-mismatch')
    assert(mists:GetConditionSupport('TALENT_TREE_POINTS',mists.conditionDefinitions.TALENT_TREE_POINTS,{type='TALENT_TREE_POINTS'})=='talent-layout-mismatch')
end)

test('momentary causes stay runtime-only: range and distance conditions are supported',function()
    local _,a=client(2,0)
    for _,value in ipairs({{type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHAN',value=1},{type='BEYOND_MELEE',unit='target'},
        {type='SWING_TIME',offhand=true,operator='GREATERTHAN',value=0}}) do
        assert(a:GetConditionSupport(value.type,a.conditionDefinitions[value.type],value)==nil,value.type..' flagged statically')
    end
end)

test('declared support on a definition wins; custom definitions are not looked up by tag',function()
    local _,a=client(2,0)
    assert(a:GetConditionSupport('PVP',{supported=function() return 'my-reason' end},{})=='my-reason')
    assert(a:GetConditionSupport('PVP',{supported=function() error('boom') end},{})=='support-check-error')
    assert(a:GetConditionSupport('PVP',{customCode=true},{})==nil)
    local _,retail=client(1,12)
    assert(retail:GetConditionSupport('PVP',{customCode=true},{})==nil,'custom code borrowed a Built In declaration')
end)

test('every declared tag is a registered condition somewhere',function()
    local _,a=client(2,0)
    local known={}
    for _,path in ipairs({'Conditions'}) do
        for line in io.lines('RotationMaster.toc') do local p=line:match('^(Conditions/.-%.lua)') if p then
            local h=io.open(p);local s=h:read('*a');h:close()
            for tag in s:gmatch('RegisterCondition%(%s*["\']([%w_]+)["\']') do known[tag]=true end
        end end
    end
    for tag,list in pairs(a.conditionRequirements) do
        assert(known[tag],'declared tag '..tag..' is never registered')
        assert(type(list)=='table' and #list>0,tag..' declares nothing')
    end
end)

test('the validation stamp moves when the client changes',function()
    local f,a=client(2,0)
    local before=a:GetRotationValidationStamp();local version=a.conditionRegistryVersion or 0
    assert(a:GetRotationValidationStamp()==before,'stamp unstable without a change')
    local platform=a.Platform;local native=platform.GetClientInfo
    platform.GetClientInfo=function(self) local info=native(self);info.family='retail';info.combatDataPolicy='restricted';return info end
    local after=a:GetRotationValidationStamp()
    assert(after~=before and (a.conditionRegistryVersion or 0)>version,'stamp kept across a client change')
    local d=unsupported(validate(a,{type='PVP',unit='player'}));assert(d and d.reason=='unsupported-policy','swapped client not seen')
    platform.GetClientInfo=native
    assert(a:GetRotationValidationStamp()~=after)
    assert(not unsupported(validate(a,{type='PVP',unit='player'})),'restored client still flagged')
end)

test('SWING_TIME off-hand with no off-hand weapon reads false, main hand stays strict',function()
    local f,a=client(2,0)
    for tag,definition in pairs(a.conditionDefinitions) do definition.evaluate=nil end
    f.load('Conditions/weapon.lua')
    f.env.UnitAttackSpeed=function() return 2.6,nil end
    local off={type='SWING_TIME',offhand=true,operator='GREATERTHAN',value=0}
    local r=a:evaluateConditionResult(off);assert(r.status=='no-match','no off-hand: '..tostring(r.status)..' '..tostring(r.reason))
    r=a:evaluateConditionResult({type='NOT',value=off});assert(r.status=='match','NOT no off-hand: '..tostring(r.status))
    local remain={type='SWING_TIME_REMAIN',offhand=true,operator='LESSTHAN',value=5}
    r=a:evaluateConditionResult(remain);assert(r.status=='no-match','remain, no off-hand: '..tostring(r.status))
    f.env.UnitAttackSpeed=function() return 2.6,1.8 end
    r=a:evaluateConditionResult(off);assert(r.status=='match','with off-hand: '..tostring(r.status))
    f.env.UnitAttackSpeed=function() return nil,1.8 end
    r=a:evaluateConditionResult({type='SWING_TIME',operator='GREATERTHAN',value=0});assert(r.status=='unavailable','main hand nil stays unavailable')
end)
finish()
