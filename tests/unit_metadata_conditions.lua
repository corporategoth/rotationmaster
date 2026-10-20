local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local kinds={CLASS='class',CREATURE='creature',CLASSIFICATION='classification'}
local apis={class='UnitClass',creature='UnitCreatureType',classification='UnitClassification'}
local values={CLASS='MAGE',CREATURE='HUMANOID',CLASSIFICATION='normal'}
local matches={class='MAGE',creature='Humanoid',classification='normal'}
local original={
    CLASS=[[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        local _, englishClass = Functions.cache.getCached(cache, UnitClass, value.unit)
        return englishClass == value.value
    end,]],
    CREATURE=[[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        return (Functions.cache.getCached(cache, UnitCreatureType, value.unit) == addon.creatures[value.value])
    end,]],
    CLASSIFICATION=[[    evaluate = function(value, cache)
        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end
        return (Functions.cache.getCached(cache, UnitClassification, value.unit) == value.value)
    end,]],
}
local repaired={}
for tag,kind in pairs(kinds) do
    repaired[tag]='    evaluate = function(value, cache)\n        local observed,reason=Functions.cache.getCached(cache, addon.Platform.GetUnitMetadataObservation, addon.Platform, value.unit, "'..kind..'")\n        if observed==nil then return nil,reason end\n        if observed==false then return false end\n        return observed == '..(tag=='CREATURE' and 'addon.creatures[value.value]' or 'value.value')..'\n    end,'
end
local function fixture(project)
    local f=F.new(project);local a,e=f.addon,f.env
    local s={exists=true,class='MAGE',creature='Humanoid',classification='normal',label='Mage',classID=8,creatureID=7,calls={}}
    local function call(key,...)
        assert(select('#',...)==1);s.calls[#s.calls+1]={key,...};if s.throw==key then error('native metadata failure') end
    end
    e.LOCALIZED_CLASS_NAMES_MALE={MAGE='Mage',WARRIOR='Warrior'}
    e.UnitExists=function(...) call('exists',...);return s.exists end
    e.UnitClass=function(...) call('class',...);if s.noReturns=='class' then return end;return s.label,s.class,s.classID end
    e.UnitCreatureType=function(...) call('creature',...);if s.noReturns=='creature' then return end;return s.creature,s.creatureID end
    e.UnitClassification=function(...) call('classification',...);if s.noReturns=='classification' then return end;return s.classification end
    local file=io.open('Platform/unit_metadata.lua');if file then file:close();f.load('Platform/unit_metadata.lua') end
    for _,path in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/character.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    s.calls={};return f,a,s
end
local function node(tag,unit) return {type=tag,unit=unit or 'target',value=values[tag:gsub('^COPY_',''):gsub('^SAVED_RAW_','')]} end
local function unknown(a,v)
    assert(a.conditionDefinitions[v.type].valid(0,v),'unknown fixture must pass unchanged field validator')
    for _,value in ipairs({v,{type='NOT',value=v},{type='AND',value={v}},{type='OR',value={{type='NOT',value=v}}}}) do
        local result=a:evaluateConditionResult(value);assert(result.status=='unavailable' and result.reason~='invalid-condition-fields','unknown metadata became actionable or fixture invalid')
    end
    local body={rotation={{id='metadata',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
    assert(a:EvaluateRotationSequence(body,function(value) return a:evaluateConditionResult(value) end,function() error('unknown metadata selected action') end).status=='unavailable')
end
local function clones(a)
    for tag in pairs(kinds) do local source=assert(a:GetBuiltinConditionSource(tag));assert(source.evaluate:find('addon.Platform.GetUnitMetadataObservation',1,true),'metadata source catalog stale')
        a:RegisterCondition('COPY_'..tag,assert(a:CompileCustomCondition('COPY_'..tag,source)))
    end
end
test('required observations remain unavailable under NOT groups and both branch arms',function()
    for tag,kind in pairs(kinds) do for _,key in ipairs({'exists',kind}) do for _,mode in ipairs({'missing','nil','no-return','throw','restricted','empty',false,0,1,{}}) do
        local f,a,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
        if mode=='missing' then f.env[key=='exists' and 'UnitExists' or apis[kind]]=nil
        elseif mode=='nil' then s[key]=nil
        elseif mode=='no-return' then if key=='exists' then f.env.UnitExists=function() return end else s.noReturns=kind end
        elseif mode=='throw' then s.throw=key
        elseif mode=='restricted' then s[key]=opaque
        elseif mode=='empty' then s[key]=''
        else s[key]=mode end
        if key=='exists' and mode==false then assert(a:evaluateConditionResult(node(tag)).status=='no-match') else unknown(a,node(tag)) end
    end end end
end)
test('known matches differences and readable absence preserve NOT and branch controls',function()
    for tag,kind in pairs(kinds) do for _,case in ipairs({{true,matches[kind],'match','yes'},{true,'Future native value','no-match','no'},{false,matches[kind],'no-match','no'}}) do
        local _,a,s=fixture();s.exists=case[1];s[kind]=case[2];local v=node(tag)
        assert(a:evaluateConditionResult(v).status==case[3] and a:evaluateConditionResult({type='NOT',value=v}).status==(case[3]=='match' and 'no-match' or 'match'))
        local selected;local body={rotation={{id='metadata',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
        a:EvaluateRotationSequence(body,function(value) return a:evaluateConditionResult(value) end,function(value) selected=value.id;return true end)
        assert(selected==case[4] and #s.calls==(case[1] and 6 or 3))
    end end
end)
test('complete tuple cache separates unit kind and self without longterm storage',function()
    local _,a,s=fixture();local cache={};local evaluate=a.conditionDefinitions.CLASS.evaluate;s.class=nil
    local value,reason=evaluate(node('CLASS'),cache);assert(value==nil and reason=='unit-metadata-unavailable' and #s.calls==2)
    s.class='MAGE';local again,why=evaluate(node('CLASS'),cache);assert(again==nil and why==reason and #s.calls==2)
    assert(evaluate(node('CLASS'),{})==true and #s.calls==4)
    s.calls={};cache={};s.exists=false;assert(evaluate(node('CLASS'),cache)==false);s.exists=true;assert(evaluate(node('CLASS'),cache)==false and #s.calls==1)
    assert(a.conditionDefinitions.CREATURE.evaluate(node('CREATURE'),cache)==true and #s.calls==3)
    assert(a.conditionDefinitions.CLASSIFICATION.evaluate(node('CLASSIFICATION'),cache)==true and #s.calls==5)
    assert(evaluate(node('CLASS','pet'),cache)==true and #s.calls==7)
    local other=setmetatable({},{__index=a.Platform})
    assert(a.Functions.cache.getCached(cache,a.Platform.GetUnitMetadataObservation,other,'target','class')=='MAGE' and #s.calls==9)
    assert(evaluate(node('CLASS'))==true and evaluate(node('CLASS'))==true and #s.calls==13)
    assert(next(a.longtermCache)==nil)
end)
test('unknown policy or transient errors never authorize actions and recover next pass',function()
    for _,project in ipairs({1,18,999}) do local _,a,s=fixture(project);for tag in pairs(kinds) do unknown(a,node(tag)) end;assert(#s.calls==0) end
    for tag,kind in pairs(kinds) do local _,a,s=fixture();s.throw=kind;unknown(a,node(tag));s.throw=nil;assert(a:evaluateConditionResult(node(tag)).status=='match') end
end)
test('current editable copies share normalized facts and preserve localized versus token comparisons',function()
    local f,a,s=fixture();clones(a);local cache={}
    for tag,kind in pairs(kinds) do s.calls={};assert(a.conditionDefinitions[tag].evaluate(node(tag),cache)==true and a.conditionDefinitions['COPY_'..tag].evaluate(node('COPY_'..tag),cache)==true and #s.calls==2)
        assert(s.calls[1][1]=='exists' and s.calls[1][2]=='target' and s.calls[2][1]==kind and s.calls[2][2]=='target')
        s[kind]=nil;unknown(a,node('COPY_'..tag));s[kind]=matches[kind];assert(a:evaluateConditionResult(node('COPY_'..tag)).status=='match')
    end
    local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;s.label=opaque;s.classID=opaque;s.creatureID=opaque
    for _,prefix in ipairs({'','COPY_'}) do assert(a:evaluateConditionResult(node(prefix..'CLASS')).status=='match' and a:evaluateConditionResult(node(prefix..'CREATURE')).status=='match') end
    s.creature='Humanoïde';a.creatures.HUMANOID='Humanoïde';a.classifications.normal='Local translated label'
    for _,prefix in ipairs({'','COPY_'}) do assert(a:evaluateConditionResult(node(prefix..'CREATURE')).status=='match' and a:evaluateConditionResult(node(prefix..'CLASSIFICATION')).status=='match') end
end)
test('saved raw callback bytes retain original nil mismatches without silent rewrite',function()
    local _,a,s=fixture()
    for tag,kind in pairs(kinds) do local source=assert(a:GetBuiltinConditionSource(tag));source.evaluate=assert(original[tag]:match('function%(value, cache%)\n(.*)\n    end,'));local before=a:CopySettingsData(source)
        local definition=assert(a:CompileCustomCondition('SAVED_RAW_'..tag,source));a:RegisterCondition('SAVED_RAW_'..tag,definition)
        s[kind]=nil;local value,reason=definition.evaluate(node(tag),{});assert(value==false and reason==nil and a:evaluateConditionResult({type='NOT',value=node('SAVED_RAW_'..tag)}).status=='match')
        s[kind]=matches[kind];s.exists=nil;assert(definition.evaluate(node(tag),{})==false and a:SettingsDataEqual(before,source));s.exists=true
    end
end)
test('public helper editable clone uses actual owner and live consumed-field readability',function()
    local f,a,s=fixture();local id='builtin:Platform/unit_metadata.lua:Platform_GetUnitMetadataObservation';local record=assert(a.builtinFunctions[id],'public metadata observer catalog missing')
    assert(a:ResolveFunctionBinding(id)==a.Platform.GetUnitMetadataObservation and a.builtinSourceModules['Platform/unit_metadata.lua']('Platform_GetUnitMetadataObservation')==a.Platform.GetUnitMetadataObservation)
    assert(record.source.args[1].type=='RMPlatform' and record.source.args[2].name=='unit' and record.source.args[3].name=='kind' and #record.source.description>0)
    assert(a:InstallCustomFunction('COPY_UNIT_METADATA',a:CopySettingsData(record.source)));local fn=a:ResolveFunctionBinding('COPY_UNIT_METADATA')
    for kind in pairs(apis) do assert(fn(a.Platform,'pet',kind)==matches[kind]) end
    s.exists=false;local value,why=fn(a.Platform,'target','class');assert(value==false and why==nil);s.exists=true
    local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;s.class=opaque
    value,why=fn(a.Platform,'target','class');assert(value==nil and why=='restricted-value')
    s.class='MAGE';s.label=opaque;assert(fn(a.Platform,'target','class')=='MAGE')
end)
test('exactly three evaluator bodies change with full module inverse and four private identities',function()
    local _,a=fixture();local file=assert(io.open('Conditions/character.lua'));local text=file:read('*a');file:close();text=dofile('tests/fixtures/restore_mobinfo2_repairs.lua')(text);text=dofile('tests/fixtures/restore_role_repairs.lua')(text);text=dofile('tests/fixtures/restore_class_group_repairs.lua')(text)
    for tag in pairs(kinds) do local first=assert(text:find(repaired[tag],1,true),'exact repaired '..tag..' missing');assert(not text:find(repaired[tag],first+1,true),'multiple repaired '..tag..' bodies')
        text=text:sub(1,first-1)..original[tag]..text:sub(first+#repaired[tag])
    end
    assert(a:FunctionSourceHash(text)=='d64994dc','character changed beyond three metadata evaluators from742794c')
    for name,hash in pairs({character_class='f9f4e4b5',color='3f9fe631',helpers='2e9a81e7',unit_class_num='33645816'}) do
        local id='builtin:Conditions/character.lua:'..name;assert(a:FunctionSourceHash(assert(a.builtinFunctions[id]).source)==hash and a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/character.lua'](name))
    end
end)
finish()
