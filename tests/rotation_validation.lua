local F=dofile('tests/fixtures/addon.lua')
local make=dofile('tests/fixtures/rotation_data.lua')
local test,finish=F.suite()
local data,envelope,options=make()
local function has(result,code,path)
    for _,d in ipairs(result.diagnostics) do if d.code==code and (not path or d.path==path) then return true end end
    return false
end
test('a portable envelope validates without gameplay APIs or input mutation',function()
    local v=envelope()
    local result=data.ValidateEnvelope(v,options)
    assert(result.valid and result.supported and result.resolved)
    assert(result.executionStatus=='unchecked' and result.qualityStatus=='unreviewed')
    assert(v.body.rotation[1].conditions.spell==403 and v.body.rotation[1].id=='step-1')
end)
test('shared event and vehicle envelopes do not require a class or specialization',function()
    local v=envelope();v.applicability.class=nil;v.applicability.actionContext='vehicle';v.tags={'event','vehicle'}
    assert(data.ValidateEnvelope(v,options).valid)
    v.applicability.families=nil
    local result=data.ValidateEnvelope(v,options)
    assert(not result.valid and has(result,'missing-field','$.applicability.families'))
end)
test('future formats and unknown condition data are preserved but inert',function()
    local v=envelope();v.schemaVersion=9
    local result=data.ValidateEnvelope(v,options)
    assert(not result.supported and result.executionStatus=='unavailable' and v.schemaVersion==9)
    v=envelope();v.body.rotation[1].conditions={type='FUTURE_CONDITION',futureField={power=42}}
    result=data.ValidateEnvelope(v,options)
    assert(result.valid and not result.resolved and has(result,'unknown-condition'))
    assert(v.body.rotation[1].conditions.futureField.power==42 and result.executionStatus=='unavailable')
end)
test('dense ordered priorities and stable unique step identifiers are required',function()
    local v=envelope();v.body.rotation[3]={id='step-3',type='spell',action=974}
    local result=data.ValidateEnvelope(v,options)
    assert(not result.valid and has(result,'sparse-list','$.body.rotation'))
    v=envelope();v.body.cooldowns={{id='step-1',type='spell',action=974}}
    result=data.ValidateEnvelope(v,options)
    assert(not result.valid and has(result,'duplicate-step-id','$.body.cooldowns[1].id'))
    v=envelope();v.body.rotation[1].action='403'
    assert(not data.ValidateEnvelope(v,options).valid)
end)
test('nested condition structures, declared field types and required fields are checked',function()
    local v=envelope();v.body.rotation[1].conditions={type='AND',value={{type='SPELL_KNOWN',spell=403},
        {type='NOT',value={type='BUFF',unit='player',spell=324}}}}
    assert(data.ValidateEnvelope(v,options).valid)
    v.body.rotation[1].conditions.value[1].spell='403'
    local result=data.ValidateEnvelope(v,options)
    assert(not result.valid and has(result,'invalid-field-type'))
    v.body.rotation[1].conditions={type='SPELL_KNOWN'}
    result=data.ValidateEnvelope(v,options)
    assert(not result.valid and has(result,'missing-field','$.body.rotation[1].conditions.spell'))
    v.body.rotation[1].conditions={type='NOT'}
    assert(not data.ValidateEnvelope(v,options).valid)
    v.body.rotation[1].conditions={type='OR',value={[1]={},[3]={}}}
    assert(not data.ValidateEnvelope(v,options).valid)
end)
test('unknown fields and references remain present and do not silently acquire execution support',function()
    local v=envelope();v.body.rotation[1].conditions.extraGate=true
    local result=data.ValidateEnvelope(v,options)
    assert(result.valid and not result.supported and has(result,'unknown-field'))
    assert(v.body.rotation[1].conditions.extraGate==true)
    v=envelope();v.body.rotation[1].type='item';v.body.rotation[1].action='missing-itemset'
    result=data.ValidateEnvelope(v,options)
    assert(result.valid and not result.resolved and has(result,'missing-itemset'))
    v=envelope();v.body.rotation[1].type='future-action'
    result=data.ValidateEnvelope(v,options)
    assert(result.valid and not result.supported and has(result,'unknown-action-type'))
end)
test('invalid scope, empty required labels, bad revisions and nonportable values are rejected',function()
    for _,modify in ipairs({
        function(v) v.revision=0 end,
        function(v) v.nameKey='' end,
        function(v) v.applicability.minLevel=20;v.applicability.maxLevel=10 end,
        function(v) v.applicability.families={} end,
        function(v) v.applicability.actionContext=42 end,
        function(v) v.body.rotation[1].conditions.disabled='false' end,
        function(v) v.body.rotation[1].conditions.run=function() end end,
    }) do
        local v=envelope();modify(v);assert(not data.ValidateEnvelope(v,options).valid)
    end
end)
test('diagnostics are deterministic and bounded for a large invalid body',function()
    local v=envelope();v.body.rotation={}
    for i=1,200 do v.body.rotation[i]={id='same-id',type='spell',action=-1} end
    local a,b=data.ValidateEnvelope(v,options),data.ValidateEnvelope(v,options)
    assert(not a.valid and #a.diagnostics<=100 and #a.diagnostics==#b.diagnostics)
    for i,d in ipairs(a.diagnostics) do
        assert(d.code==b.diagnostics[i].code and d.path==b.diagnostics[i].path)
    end
end)
test('documented nested list and record declarations validate without calling predicates',function()
    local settings={conditions={CUSTOM={fields={items={'string',{'string','number'}},
        record={'string',{name='string',count='number'}}},requiredFields={'items','record'},
        valid=function() error('pure validation called runtime predicate') end}}}
    local v=envelope()
    v.body.rotation[1].conditions={type='CUSTOM',items={123,'Potion'},record={name='fixture',count=2}}
    assert(data.ValidateEnvelope(v,settings).valid)
    v.body.rotation[1].conditions.items[2]=false
    assert(not data.ValidateEnvelope(v,settings).valid)
    v.body.rotation[1].conditions.items={123};v.body.rotation[1].conditions.record.extra=true
    assert(not data.ValidateEnvelope(v,settings).valid)
end)
test('itemset and effect dependencies resolve only against an explicit supplied catalog',function()
    local v=envelope()
    v.body.rotation[1].type='item';v.body.rotation[1].action='itemset-1';v.body.rotation[1].effect='effect-1'
    local missing=data.ValidateEnvelope(v,options)
    assert(not missing.resolved and has(missing,'missing-itemset') and has(missing,'missing-effect'))
    local supplied={conditions=options.conditions,itemsets={['itemset-1']={}},effects={['effect-1']={}}}
    assert(data.ValidateEnvelope(v,supplied).resolved)
end)
test('an explicit empty selector is invalid rather than silently matching every spec or role',function()
    for _,field in ipairs({'specs','roles','rulesets'}) do
        local v=envelope();v.applicability[field]={}
        local result=data.ValidateEnvelope(v,options)
        assert(not result.valid and has(result,'empty-selector','$.applicability.'..field))
    end
end)
test('declared nested conditions are validated inside fields, lists, unions and records',function()
    local settings={conditions={CUSTOM={fields={gate='condition',gates='condition[]',
        alternate={'string',{gate='condition'}},sequence={'string',{'condition'}}}},
        SPELL_KNOWN=options.conditions.SPELL_KNOWN}}
    local v=envelope()
    v.body.rotation[1].conditions={type='CUSTOM',gate={type='FUTURE_CONDITION'},
        gates={{type='SPELL_KNOWN',spell='bad'}},
        alternate={gate={type='NOT'}},sequence={{type='SPELL_KNOWN'}}}
    local result=data.ValidateEnvelope(v,settings)
    local prefix='$.body.rotation[1].conditions'
    assert(not result.valid and not result.resolved and result.executionStatus=='unavailable')
    assert(has(result,'unknown-condition',prefix..'.gate.type'))
    assert(has(result,'invalid-field-type',prefix..'.gates[1].spell'))
    assert(has(result,'missing-field',prefix..'.alternate.gate.value'))
    assert(has(result,'missing-field',prefix..'.sequence[1].spell'))
    v.body.rotation[1].conditions={type='CUSTOM',gate={type='AND',value={{type='SPELL_KNOWN',spell=403},
        {type='NOT',value={type='OR',value={}}}}}}
    result=data.ValidateEnvelope(v,settings)
    assert(result.valid and result.supported and result.resolved)
end)
test('legacy bodies validate independently without inventing edition or source metadata',function()
    local body=envelope().body
    local result=data.ValidateBody(body,options)
    assert(result.valid and result.supported and result.resolved)
    assert(body.applicability==nil and body.schemaVersion==nil,'body validation fabricated scope')
    body.rotation[1].action='403'
    assert(not data.ValidateBody(body,options).valid)
    body.rotation[1].action=403;body.futureSetting={foo=42}
    result=data.ValidateBody(body,options)
    assert(result.valid and not result.supported and body.futureSetting.foo==42)
end)
test('Stop fallback suppression is an optional portable boolean belonging only to Stop steps',function()
    local v=envelope();local step=v.body.rotation[1]
    step.type='none';step.action=nil;step.suppress_attack=true
    local result=data.ValidateEnvelope(v,options)
    assert(result.valid and result.supported and result.resolved)
    step.suppress_attack=false;assert(data.ValidateEnvelope(v,options).supported)
    step.suppress_attack='false';assert(not data.ValidateEnvelope(v,options).valid)
    step.suppress_attack=true;step.type='spell';step.action=403
    assert(not data.ValidateEnvelope(v,options).supported,'a Stop-only option was ignored on a spell')
end)
test('Boolean group labels validate without reserving custom leaf name fields',function()
    local v=envelope();v.body.switch={type='AND',name='Opening checks',value={{type='NOT',name='Safe target',value={}}}}
    local result=data.ValidateEnvelope(v,options);assert(result.valid and result.supported)
    for _,name in ipairs({false,string.rep('x',513),'bad\nlabel'}) do
        v.body.switch.name=name;assert(not data.ValidateEnvelope(v,options).valid)
    end
    v.body.switch={type='NAMED',name='leaf name'}
    local opts=data.CopyData(options);opts.conditions.NAMED={fields={name='string'}}
    result=data.ValidateEnvelope(v,opts);assert(result.valid and result.supported and result.resolved)
end)
test('branches validate both dense arms recursively with globally unique IDs and strict control fields',function()
    local v=envelope();v.body.rotation={{id='b',type='branch',mode='true',name='Combat',conditions={},
        onTrue={{id='yes',type='spell',action=403}},onFalse={{id='no',type='none'}}}}
    local result=data.ValidateEnvelope(v,options);assert(result.valid and result.supported and result.resolved)
    v.body.rotation[1].onFalse[1].id='yes';result=data.ValidateEnvelope(v,options)
    assert(not result.valid and has(result,'duplicate-step-id','$.body.rotation[1].onFalse[1].id'))
    v.body.rotation[1].onFalse[1].id='no';v.body.rotation[1].onTrue[1].action='403'
    result=data.ValidateEnvelope(v,options);assert(not result.valid and has(result,'invalid-field-value','$.body.rotation[1].onTrue[1].action'))
    v.body.rotation[1].onTrue[1].action=403
    for _,field in ipairs({'action','disabled','effect'}) do
        v.body.rotation[1][field]=false;assert(not data.ValidateEnvelope(v,options).valid);v.body.rotation[1][field]=nil
    end
    v.body.cooldowns={v.body.rotation[1]};v.body.rotation={};assert(not data.ValidateEnvelope(v,options).valid)
end)
test('unknown branch metadata remains preserved and unsupported while invalid modes and arms fail',function()
    local v=envelope();v.body.rotation={{id='b',type='branch',conditions={},onTrue={},onFalse={},future={coefficient=42}}}
    local result=data.ValidateEnvelope(v,options)
    assert(result.valid and not result.supported and v.body.rotation[1].future.coefficient==42)
    v.body.rotation[1].future=nil;v.body.rotation[1].mode=false;assert(not data.ValidateEnvelope(v,options).valid)
    v.body.rotation[1].mode='evaluate';v.body.rotation[1].onFalse={[2]={id='x',type='none'}}
    assert(not data.ValidateEnvelope(v,options).valid)
end)
test('rotation descriptions and supplied metadata validate without executing code and reject malformed values',function()
    local v=envelope();v.body.description='A leveling rotation';v.body.metadata={author='PreZ',realm='Example',email='opt-in@example.invalid',website='https://example.invalid',version='1'}
    local r=data.ValidateEnvelope(v,options);assert(r.valid and r.supported and r.resolved)
    v.body.metadata.author={};r=data.ValidateEnvelope(v,options);assert(not r.valid and has(r,'invalid-field-type','$.body.metadata.author'))
    v.body.metadata={future='retained'};r=data.ValidateEnvelope(v,options);assert(r.valid and not r.supported and v.body.metadata.future=='retained')
end)
test('disabled condition definitions keep saved bodies valid but make direct and negated consumers unavailable',function()
    for _,guard in ipairs({{type='OFF'},{type='NOT',value={type='OFF'}}}) do
        local v=envelope();v.body.switch=guard
        local result=data.ValidateEnvelope(v,{conditions={OFF={fields={},disabled=true},SPELL_KNOWN=options.conditions.SPELL_KNOWN}})
        assert(result.valid and not result.resolved and result.executionStatus=='unavailable' and has(result,'disabled-condition'))
    end
end)
finish()
