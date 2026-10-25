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

test('an always-secret condition is unresolved on Retail and Forever, supported on Era/TBC/Mists',function()
    local health={type='HEALTH',unit='player',operator='GREATERTHAN',value=1}
    for _,c in ipairs({{2,0},{5,1},{19,4}})do
        local f,a=client(c[1],c[2]);f.env.UnitHealth=f.env.UnitHealth or function() end;local report=validate(a,health)
        assert(report.resolved and not unsupported(report),'project '..c[1]..' flagged HEALTH')
        assert(a:GetConditionSupport('HEALTH',a.conditionDefinitions.HEALTH,health)==nil)
        assert(a:validateCondition(health,0),'validateCondition refused a supported condition')
    end
    for _,c in ipairs({{1,12},{18,12}})do
        local f,a=client(c[1],c[2]);f.env.UnitHealth=f.env.UnitHealth or function() end;local report=validate(a,health);local d=unsupported(report)
        assert(not report.resolved and d and d.condition=='HEALTH' and d.reason=='secret-health' and d.path=='$.body.rotation[1].conditions.type',
            'project '..c[1]..': '..tostring(d and d.reason))
        assert(report.valid,'an unsupported condition is incomplete, not invalid data')
        assert(not a:validateCondition(health,0),'auto-switch validity accepted an unsupported condition')
        local text=a:DescribeUnsupportedCondition(d)
        assert(text and text:find(a.conditionDefinitions.HEALTH.description,1,true) and text:find('not available on this client',1,true)
            and text:find('secret',1,true),tostring(text))
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
    -- Forever's classic trees are trait node groups read through C_Traits; Retail's tree has none.
    local points,primary={type='TALENT_TREE_POINTS',tree=2,operator='GREATERTHAN',value=0},{type='PRIMARY_TALENT_TREE',tree=2}
    local ff,forever=client(18,12)
    local rf,retail=client(1,12)
    for _,value in ipairs({points,primary}) do
        local definition=forever.conditionDefinitions[value.type]
        ff.env.C_Traits=nil;ff.env.GetNumTalentTabs=nil
        assert(forever:GetConditionSupport(value.type,definition,value)=='missing-api',value.type..' without the group reader')
        ff.env.C_Traits={GetGroupDisplayInfoByTreeID=function() error('support read talents') end}
        assert(forever:GetConditionSupport(value.type,definition,value)==nil,value.type..' refused on Forever')
        rf.env.C_Traits={GetGroupDisplayInfoByTreeID=function() error('support read talents') end}
        assert(retail:GetConditionSupport(value.type,retail.conditionDefinitions[value.type],value)=='talent-layout-mismatch',value.type..' accepted on Retail')
        getfenv(era.GetConditionSupport).GetNumTalentTabs=function() error('support read talents') end
        assert(era:GetConditionSupport(value.type,era.conditionDefinitions[value.type],value)==nil,value.type..' refused on Era')
    end
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
    f.env.UnitHealth=f.env.UnitHealth or function() end
    local d=unsupported(validate(a,{type='HEALTH',unit='player',operator='GREATERTHAN',value=1}));assert(d and d.reason=='secret-health','swapped client not seen')
    platform.GetClientInfo=native
    assert(a:GetRotationValidationStamp()~=after)
    assert(not unsupported(validate(a,{type='HEALTH',unit='player',operator='GREATERTHAN',value=1})),'restored client still flagged')
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
test('the merged conditions declare their client support, field by field',function()
    local f,era=client(2,0)
    f.env.C_Engraving=nil
    assert(era:GetConditionSupport('RUNE_ENGRAVED',era.conditionDefinitions.RUNE_ENGRAVED,{type='RUNE_ENGRAVED',rune=1})=='missing-api')
    f.env.C_Engraving={IsEngravingEnabled=function() return true end}
    assert(era:GetConditionSupport('RUNE_ENGRAVED',era.conditionDefinitions.RUNE_ENGRAVED,{type='RUNE_ENGRAVED',rune=1})==nil)
    assert(era:GetConditionSupport('TALENT',era.conditionDefinitions.TALENT,{type='TALENT',layout='traits',node=1,entry=1})=='talent-layout-mismatch')
    assert(era:GetConditionSupport('WEAPON_TYPE',era.conditionDefinitions.WEAPON_TYPE,{type='WEAPON_TYPE',slot='ranged',kind='bow'})==nil)
    local _,mists=client(19,4)
    assert(mists:GetConditionSupport('WEAPON_TYPE',mists.conditionDefinitions.WEAPON_TYPE,{type='WEAPON_TYPE',slot='ranged',kind='bow'})=='no-ranged-slot')
    assert(mists:GetConditionSupport('WEAPON_TYPE',mists.conditionDefinitions.WEAPON_TYPE,{type='WEAPON_TYPE',slot='mainhand',kind='dagger'})==nil)
    local ff,forever=client(18,12,'ROGUE');ff.env.UnitClass=function() return 'Rogue','ROGUE',4 end
    local spec=forever.conditionDefinitions.SPECIALIZATION
    assert(spec and forever:GetConditionSupport('SPECIALIZATION',spec,{type='SPECIALIZATION',spec=259})=='specialization-unsupported','own class on Forever')
    assert(forever:GetConditionSupport('SPECIALIZATION',spec,{type='SPECIALIZATION',spec=71})==nil,'another class is an ordinary false')
    local _,retail=client(1,12)
    assert(retail:GetConditionSupport('SPECIALIZATION',retail.conditionDefinitions.SPECIALIZATION,{type='SPECIALIZATION',spec=259})==nil)
    -- History fed by the combat log is never recorded there (SecureOnly);
    -- histories fed by unit and nameplate events are.
    for _,tag in ipairs({'SWING_TIME_REMAIN','TT_HEALTH'}) do
        assert(retail.conditionDefinitions[tag]==nil or retail:GetConditionSupport(tag,retail.conditionDefinitions[tag],{})~=nil,tag..' supported on Retail')
    end
    local natives=getfenv(retail.GetConditionSupport)
    natives.UnitCastingInfo=natives.UnitCastingInfo or function() end;natives.GetTime=natives.GetTime or function() return 0 end
    for _,tag in ipairs({'SPELL_HISTORY','COMBAT_HISTORY','DISTANCE_COUNT','CASTING_PROGRESS'}) do
        local reason=retail:GetConditionSupport(tag,retail.conditionDefinitions[tag],{})
        assert(reason==nil,tag..' flagged on Retail: '..tostring(reason))
    end
    -- Never-secret readers stay available on Retail (its natives modeled).
    local re=getfenv(retail.GetConditionSupport)
    re.C_Spell={GetSpellCooldown=function() end};re.C_SpellBook={IsSpellKnown=function() end};re.C_AssistedCombat={GetNextCastSpell=function() end}
    for _,tag in ipairs({'LEVEL','SPELL_AVAIL','SPELL_KNOWN','ASSISTED_SUGGESTION','TIME_IN_COMBAT'}) do
        local reason=retail:GetConditionSupport(tag,retail.conditionDefinitions[tag],{})
        assert(reason==nil,tag..' flagged on Retail: '..tostring(reason))
    end
end)

test('pickers hide conditions this client cannot run; the full list keeps them',function()
    local rf,retail=client(1,12);rf.load('Core/condition_catalog.lua')
    local function has(list,tag) for _,v in ipairs(list) do if v==tag then return true end end end
    rf.env.UnitHealth=function() end
    assert(not has(retail:listConditions('ALL'),'HEALTH'),'Retail picker offers HEALTH')
    assert(has(retail:listConditions('ALL'),'LEVEL'),'Retail picker lost LEVEL')
    assert(has(retail:listConditions('ALL',true),'HEALTH'),'the unhidden list dropped HEALTH')
    local ef,era=client(2,0);ef.load('Core/condition_catalog.lua')
    ef.env.UnitHealth=function() end
    assert(has(era:listConditions('ALL'),'HEALTH'),'Era picker lost HEALTH')
end)

test('restricted clients run complete Built Ins; incomplete ones say why',function()
    local f,packs,state=corpus.load(1,12,'ROGUE')
    if type(f.addon.Platform.GetTalentLayout)~='function' then f.load('Platform/talents.lua') end
    f.load('Core/condition_support.lua')
    local a=f.addon;f.env.UnitExists=f.env.UnitExists or function() end;f.env.UnitLevel=f.env.UnitLevel or function() end
    local shipped
    for _,x in ipairs(packs) do local ap=x.applicability or {};if ap.class=='ROGUE' and (ap.families or {})[1]=='retail' then shipped=x;break end end
    assert(shipped,'no Retail rogue pack')
    local copy=a.RotationData.CopyData(shipped);copy.id='rm.test.complete'
    local level={type='LEVEL',unit='player',operator='GREATERTHAN',value=0}
    copy.body.rotation={{id='x',type='spell',action=1752,conditions=level}};copy.body.cooldowns={};copy.body.switch=level
    assert(a:RegisterDefaultRotation(copy))
    -- Shipped Retail premades use only readable conditions; one that reads health is incomplete.
    local hurt=a.RotationData.CopyData(copy);hurt.id='rm.test.incomplete'
    hurt.body.rotation={{id='x',type='spell',action=1752,conditions={type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5}}}
    f.env.UnitHealth=f.env.UnitHealth or function() end;f.env.UnitHealthMax=f.env.UnitHealthMax or function() end
    assert(a:RegisterDefaultRotation(hurt));assert(a:InitializeRotationLibrary());state.level=60
    local rows={};-- The Retail slot the shipped premade's SPECIALIZATION switch names.
    for _,row in ipairs(a:ListDefaultRotations(assert(shipped.body.specs[1]))) do rows[row.id]=row end
    assert(rows['rm.test.complete'] and rows['rm.test.complete'].eligible,'a complete Retail Built In is refused: '..tostring(rows['rm.test.complete'] and rows['rm.test.complete'].eligibilityReason))
    local incomplete=rows['rm.test.incomplete']
    assert(incomplete and not incomplete.eligible and incomplete.eligibilityReason=='invalid-or-unsupported',tostring(incomplete and incomplete.eligibilityReason))
    local message
    for _,d in ipairs(incomplete.validation.diagnostics) do message=a:DescribeUnsupportedCondition(d);if message then break end end
    assert(message and message:find('is not available on this client',1,true),tostring(message))
end)
finish()
