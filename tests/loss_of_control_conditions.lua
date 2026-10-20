local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local tags={'LOC_TYPE','LOC_BLOCKED'}
local function fixture(project)
    local f=F.new(project);local a,e=f.addon,f.env
    local s={count=1,rows={{locType='STUN_MECHANIC',lockoutSchool=4,timeRemaining=5}},calls={}}
    local function call(key) s.calls[#s.calls+1]=key;if s.throw==key then error('LOC native failure') end end
    e.C_LossOfControl={GetActiveLossOfControlDataCount=function(...) assert(select('#',...)==0);call('count');return s.count end,
        GetActiveLossOfControlData=function(...) assert(select('#',...)==1);local index=...;call(index);return s.rows[index] end}
    local ok,library=pcall(require,'bit')
    e.bit=ok and library or {lshift=function(value,n) return value*2^n end,band=function(left,right)
        local value,power=0,1
        while left>0 or right>0 do if left%2==1 and right%2==1 then value=value+power end;left=math.floor(left/2);right=math.floor(right/2);power=power*2 end
        return value
    end}
    e.SCHOOL_STRINGS={[1]='Physical',[2]='Holy',[3]='Fire',[4]='Nature',[5]='Frost',[6]='Shadow',[7]='Arcane'}
    a.loc_types={STUN='Stun',FEAR='Fear',INTERRUPT='Interrupt'}
    local file=io.open('Platform/loss_of_control.lua');if file then file:close();f.load('Platform/loss_of_control.lua') end
    for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Core/rotation_sequence.lua','Conditions/common.lua','Conditions/combat.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,s
end
local function node(tag,operator,value) return {type=tag,loc_type=tag=='LOC_TYPE' and 'STUN' or nil,school=tag=='LOC_BLOCKED' and 3 or nil,operator=operator or 'GREATERTHAN',value=value or 2} end
local function unknown(a,v)
    assert(a.conditionDefinitions[v.type].valid(0,v),'unknown test must pass current field validator')
    for _,value in ipairs({v,{type='NOT',value=v},{type='AND',value={v}},{type='OR',value={{type='NOT',value=v}}}}) do
        local result=a:evaluateConditionResult(value);assert(result.status=='unavailable' and result.reason~='invalid-condition-fields' and result.reason~='condition-callback-error','unknown LOC fact became actionable or quarantined')
    end
    local body={rotation={{id='loc',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
    assert(a:EvaluateRotationSequence(body,function(value) return a:evaluateConditionResult(value) end,function() error('unknown LOC selected branch') end).status=='unavailable')
end
local function legacy(f,s)
    f.env.C_LossOfControl.GetNumEvents=function() s.calls[#s.calls+1]='legacy-count';return s.count end
    f.env.C_LossOfControl.GetEventInfo=function(index)
        s.calls[#s.calls+1]='legacy-row';local row=s.rows[index];if not row then return end
        return row.locType,100,'Control',123,98,row.timeRemaining,5,row.lockoutSchool,1,2
    end
end
local function copies(a)
    for _,tag in ipairs(tags) do local source=assert(a:GetBuiltinConditionSource(tag));assert(source.evaluate:find('addon.Platform.GetLossOfControl',1,true),'LOC catalog stale')
        a:RegisterCondition('COPY_'..tag,assert(a:CompileCustomCondition('COPY_'..tag,source)))
    end
end
test('modern-only known events empty scans and NOT retain exact selected-row outcomes',function()
    for _,tag in ipairs(tags) do for _,case in ipairs({{1,5,'match','yes'},{1,1,'no-match','no'},{0,5,'no-match','no'}}) do
        local f,a,s=fixture();s.count=case[1];s.rows[1].timeRemaining=case[2]
        if s.count==0 then f.env.C_LossOfControl.GetActiveLossOfControlData=nil;f.env.bit=nil end
        local v=node(tag);assert(a:evaluateConditionResult(v).status==case[3] and a:evaluateConditionResult({type='NOT',value=v}).status==(case[3]=='match' and 'no-match' or 'match'))
        local selected;local body={rotation={{id='loc',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
        a:EvaluateRotationSequence(body,function(value) return a:evaluateConditionResult(value) end,function(value) selected=value.id;return true end)
        assert(selected==case[4] and #s.calls==(s.count==0 and 3 or 6))
    end end
end)
test('zero and unrelated school masks are false while combined masks select the requested school',function()
    for _,mask in ipairs({0,2,4,6}) do local f,a,s=fixture();legacy(f,s);s.rows[1].lockoutSchool=mask
        local want=mask==4 or mask==6;assert(a:evaluateConditionResult(node('LOC_BLOCKED')).status==(want and 'match' or 'no-match'),'zero bit result was truthy')
        for _,call in ipairs(s.calls) do assert(call~='legacy-count' and call~='legacy-row','current BuiltIn used legacy APIs') end
    end
end)
test('only the first selected row matters including false and later unknown rows',function()
    for _,tag in ipairs(tags) do local _,a,s=fixture();s.count=3;s.rows={{locType='STUN_MECHANIC',lockoutSchool=4,timeRemaining=1},{locType='STUN',lockoutSchool=4,timeRemaining=10}}
        assert(a:evaluateConditionResult(node(tag)).status=='no-match' and #s.calls==2,'later match overrode first comparison')
        s.rows[1].timeRemaining=5;s.calls={};assert(a:evaluateConditionResult(node(tag)).status=='match' and #s.calls==2,'later missing row poisoned completed selection')
    end
    local _,a,s=fixture();s.count=2;s.rows={{locType='FEAR',lockoutSchool=2,timeRemaining=10},{locType='STUN',lockoutSchool=4,timeRemaining=1}}
    assert(a:evaluateConditionResult(node('LOC_BLOCKED')).status=='no-match' and #s.calls==3,'unrelated first school selected')
end)
test('unrelated subjects ignore missing failed or opaque time and unneeded subject fields',function()
    for _,tag in ipairs(tags) do local f,a,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
        local subject=tag=='LOC_TYPE' and {locType='FEAR'} or {lockoutSchool=2}
        s.rows={setmetatable(subject,{__index=function(_,key) if key=='timeRemaining' then error('unavailable timing') end;return opaque end})}
        assert(a:evaluateConditionResult(node(tag)).status=='no-match')
        s.count=2;s.rows[2]={locType='STUN_MECHANIC',lockoutSchool=4,timeRemaining=5};assert(a:evaluateConditionResult(node(tag)).status=='match')
    end
end)
test('required count row subjects and selected timing remain unavailable under NOT groups and branches',function()
    for _,tag in ipairs(tags) do for _,mode in ipairs({'namespace','count-api','row-api','nil-count','nan-count','negative-count','fractional-count','budget','count-error','row-error','missing-row','subject-nil','subject-restricted','time-nil','time-restricted','time-nan','time-infinite'}) do
        local f,a,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
        if mode=='namespace' then f.env.C_LossOfControl=nil elseif mode=='count-api' then f.env.C_LossOfControl.GetActiveLossOfControlDataCount=nil
        elseif mode=='row-api' then f.env.C_LossOfControl.GetActiveLossOfControlData=nil elseif mode=='nil-count' then s.count=nil
        elseif mode=='nan-count' then s.count=0/0 elseif mode=='negative-count' then s.count=-1 elseif mode=='fractional-count' then s.count=.5
        elseif mode=='budget' then s.count=257 elseif mode=='count-error' then s.throw='count' elseif mode=='row-error' then s.throw=1
        elseif mode=='missing-row' then s.rows={}
        elseif mode=='subject-nil' then s.rows[1][tag=='LOC_TYPE' and 'locType' or 'lockoutSchool']=nil
        elseif mode=='subject-restricted' then s.rows[1][tag=='LOC_TYPE' and 'locType' or 'lockoutSchool']=opaque
        elseif mode=='time-nil' then s.rows[1].timeRemaining=nil elseif mode=='time-restricted' then s.rows[1].timeRemaining=opaque
        elseif mode=='time-nan' then s.rows[1].timeRemaining=0/0 elseif mode=='time-infinite' then s.rows[1].timeRemaining=math.huge end
        unknown(a,node(tag,'NOTEQUALS'))
    end end
end)
test('finite signed fractional timers type equivalence and empty future unrelated types preserve comparison meaning',function()
    for _,tag in ipairs(tags) do local _,a,s=fixture();s.rows[1].timeRemaining=-.25;assert(a:evaluateConditionResult(node(tag,'LESSTHAN',0)).status=='match')
        s.rows[1].timeRemaining=2.75;assert(a:evaluateConditionResult(node(tag,'GREATERTHAN',2.5)).status=='match')
    end
    for _,kind in ipairs({'','Future type'}) do local _,a,s=fixture();s.rows[1].locType=kind;s.rows[1].timeRemaining=nil;assert(a:evaluateConditionResult(node('LOC_TYPE')).status=='no-match') end
end)
test('bit failures stay transient unknown and count zero never requires bit operations',function()
    for _,mode in ipairs({'missing','throw','nil-result','opaque-result'}) do local f,a,s=fixture();local originalBit=f.env.bit;local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
        if mode=='missing' then
            f.env.bit=nil;local fallback=getmetatable(f.env).__index
            setmetatable(f.env,{__index=function(_,key) if key=='bit' then return nil end;return fallback[key] end})
        elseif mode=='throw' then f.env.bit={lshift=function() error('shift failure') end}
        elseif mode=='nil-result' then f.env.bit={lshift=function() return 4 end,band=function() return nil end}
        else f.env.bit={lshift=function() return opaque end,band=function() error('opaque shift entered band') end} end
        unknown(a,node('LOC_BLOCKED'));f.env.bit=originalBit;assert(a:evaluateConditionResult(node('LOC_BLOCKED')).status=='match')
        s.count=0;f.env.bit=nil;assert(a:evaluateConditionResult(node('LOC_BLOCKED')).status=='no-match')
    end
end)
test('count and requested row snapshots cache exact tuples by self kind index and pass',function()
    local _,a,s=fixture();local cache={};local evaluate=a.conditionDefinitions.LOC_TYPE.evaluate;s.rows[1].timeRemaining=nil
    local value,why=evaluate(node('LOC_TYPE'),cache);assert(value==nil and why=='loss-of-control-time-unavailable' and #s.calls==2)
    s.rows[1].timeRemaining=5;local again,reason=evaluate(node('LOC_TYPE'),cache);assert(again==nil and reason==why and #s.calls==2)
    assert(a.conditionDefinitions.LOC_BLOCKED.evaluate(node('LOC_BLOCKED'),cache)==true and #s.calls==3)
    assert(evaluate(node('LOC_TYPE'),{})==true and #s.calls==5)
    local other=setmetatable({},{__index=a.Platform});assert(a.Functions.cache.getCached(cache,a.Platform.GetLossOfControlCount,other)==1 and #s.calls==6)
    assert(evaluate(node('LOC_TYPE'))==true and #s.calls==8 and next(a.longtermCache)==nil)
    for _,project in ipairs({1,18,999}) do local _,b,state=fixture(project);unknown(b,node('LOC_TYPE'));assert(#state.calls==0) end
end)
test('numeric school emitted by actual native widget validates for storage and strings are rejected',function()
    local _,a=fixture();local definition=a.conditionDefinitions.LOC_BLOCKED;local value=node('LOC_BLOCKED');value.school=nil
    local parent=a:CreateConditionGroup();local top=a:CreateConditionGroup();function top:SetStatusText(text) self.status=text end
    top:SetUserData('root',value);top:SetUserData('funcs',{print=function() return 'LOC' end});parent:SetUserData('top',top)
    definition.widget(parent,0,value);local school=parent.children[1];school.configure();school:Fire('OnValueChanged',3)
    assert(value.school==3 and definition.valid(0,value))
    local function validate(v) return a.RotationData.ValidateBody({rotation={{id='loc',type='spell',action=1,conditions=v}},cooldowns={}},{conditions=a.conditionDefinitions}) end
    assert(validate(value).valid,'native numeric school rejected by declared storage schema')
    local wrong=a:CopySettingsData(value);wrong.school='3';local result=validate(wrong);assert(not result.valid,'string school accepted by numeric storage schema')
    local schoolError=false;for _,diagnostic in ipairs(result.diagnostics) do if diagnostic.code=='invalid-field-type' and diagnostic.path:match('%.school$') then schoolError=true end end
    assert(schoolError,'string rejection did not exercise the declared school field')
    a:ReleaseConditionWidget(parent);a:ReleaseConditionWidget(top)
    copies(a);local copy=node('LOC_BLOCKED');copy.type='COPY_LOC_BLOCKED';assert(a.conditionDefinitions.COPY_LOC_BLOCKED.fields.school=='number' and validate(copy).valid)
end)
test('current condition and public helper copies resolve actual normalized owners',function()
    local f,a,s=fixture();copies(a);local cache={}
    for _,tag in ipairs(tags) do local v=node(tag);local copy=a:CopySettingsData(v);copy.type='COPY_'..tag
        assert(a.conditionDefinitions[tag].evaluate(v,cache)==true and a.conditionDefinitions[copy.type].evaluate(copy,cache)==true)
        s.rows[1].timeRemaining=nil;unknown(a,copy);s.rows[1].timeRemaining=5
    end
    for _,name in ipairs({'GetLossOfControlCount','GetLossOfControlEvent'}) do local id='builtin:Platform/loss_of_control.lua:Platform_'..name;local record=assert(a.builtinFunctions[id],'LOC helper catalog missing')
        assert(a:ResolveFunctionBinding(id)==a.Platform[name] and a.builtinSourceModules['Platform/loss_of_control.lua']('Platform_'..name)==a.Platform[name])
        assert(a:InstallCustomFunction('COPY_'..name,a:CopySettingsData(record.source)));local fn=a:ResolveFunctionBinding('COPY_'..name)
        if name=='GetLossOfControlCount' then assert(fn(a.Platform)==1) else assert(fn(a.Platform,1,'school').lockoutSchool==4) end
    end
end)
test('raw saved tuple callbacks and schema remain unchanged while exact inverse protects every other byte',function()
    local f,a,s=fixture();legacy(f,s);local inverse,original=dofile('tests/fixtures/restore_loss_of_control_repairs.lua')
    for _,tag in ipairs(tags) do local source=assert(a:GetBuiltinConditionSource(tag));source.evaluate=original[tag];if tag=='LOC_BLOCKED' then source.fields.school='string' end
        local before=a:CopySettingsData(source);local raw=assert(a:CompileCustomCondition('RAW_'..tag,source));assert(raw.evaluate(node(tag),{})==true)
        if tag=='LOC_BLOCKED' then s.rows[1].lockoutSchool=0;assert(raw.evaluate(node(tag),{})==true,'legacy zero-mask truthiness changed');s.rows[1].lockoutSchool=4 end
        assert(a:SettingsDataEqual(source,before))
    end
    local file=assert(io.open('Conditions/combat.lua'));local text=file:read('*a');file:close();text=dofile('tests/fixtures/restore_combat_history_time_repairs.lua')(dofile('tests/fixtures/restore_form_presentation_repairs.lua')(dofile('tests/fixtures/restore_form_localization.lua')(text)));text=dofile('tests/fixtures/restore_threat_count_repairs.lua')(text);text=dofile('tests/fixtures/restore_combat_time_repairs.lua')(text);assert(a:FunctionSourceHash(inverse(dofile('tests/fixtures/restore_form_repairs.lua')(text)))=='e0d8eae5','combat changed beyond2LOC evaluators and school schema fromf537fe1')
    for name,hash in pairs({color='dbda383d',character_class='d17cf4c1',helpers='9e28e933'}) do local id='builtin:Conditions/combat.lua:'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/combat.lua'](name)) end
end)
finish()
