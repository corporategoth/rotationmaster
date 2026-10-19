local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local expected={CreateConditionLink='addon:CreateConditionLink',CreateConditionPositionPad='addon:CreateConditionPositionPad',CreateConditionIcon='addon:CreateConditionIcon',CreateConditionLabel='addon:CreateConditionLabel',CreateConditionButton='addon:CreateConditionButton',getCached='Functions.cache.getCached',getRetryCached='Functions.cache.getRetryCached',compare='Functions.values.compare',isin='Functions.values.isin',nullable='Functions.presentation.nullable',nullable_value='Functions.presentation.nullable_value',playerize='Functions.presentation.playerize',compareString='Functions.presentation.compareString',split='Functions.text.split',wrap='Functions.text.wrap',trim='Functions.text.trim',CreateConditionGroup='addon:CreateConditionGroup',CreateConditionEditBox='addon:CreateConditionEditBox',CreateConditionSlider='addon:CreateConditionSlider',CreateConditionDropdown='addon:CreateConditionDropdown',CreateConditionCheckBox='addon:CreateConditionCheckBox',Widget_UnitWidget='addon:Widget_UnitWidget',Widget_SpellWidget='addon:Widget_SpellWidget',Widget_GetSpellId='addon:Widget_GetSpellId',Platform_IsSpellReady='addon.Platform:IsSpellReady',Platform_GetSpellCooldown='addon.Platform:GetSpellCooldown',Platform_GetSpellCharges='addon.Platform:GetSpellCharges',Platform_GetSpellRangeState='addon.Platform:GetSpellRangeState'}
local function fixture(...)
    local f=F.new(...);f.load('Data/builtin_sources.lua');f.load('Core/builtin_sources.lua');f.load('Core/custom_authoring.lua');f.load('Conditions/common.lua');f.load('Platform/spells.lua');f.load('Platform/actions.lua')
    f.env.loadstring=function(text,name) local fn,why=loadstring(text,name);if fn then setfenv(fn,f.env) end;return fn,why end
    return f,f.addon
end
local function public(a,name)
    for id,record in pairs(a.builtinFunctions or {}) do if record.callName==expected[name] then return record,id end end
    error('public helper missing: '..name)
end
local function clone(a,name)
    local record=public(a,name);assert(a:InstallCustomFunction('COPY_'..name,a:CopySettingsData(record.source)));return assert(a:ResolveFunctionBinding('COPY_'..name)),record
end
test('curated addon helpers register from modules loaded before and after the catalog with typed public call docs',function()
    local before=F.new();assert(not before.addon.RegisterBuiltinSourceModule and before.addon.builtinSourceModules['utils.lua'])
    assert(before.addon.builtinSourceModules['utils.lua']('getCached')==before.addon.getCached)
    local _,a=fixture()
    for name,callName in pairs(expected) do
        local record,id=public(a,name);assert(record.public and not record.valueBinding and record.callName==callName and record.source.description:find('%S'))
        assert(record.source.code:find('%S') and #record.source.returns>0 and record.source.returns[1].description:find('%S'))
        for _,arg in ipairs(record.source.args) do assert(arg.type~='any' or arg.name=='...' or name=='nullable' or name=='nullable_value' or name=='playerize' or name=='isin' or name=='compare');assert(arg.description:find('%S')) end
        assert(not a:InstallCustomFunction(id,a:CopySettingsData(record.source)))
    end
    assert(public(a,'getCached').source.args[1].name=='cache')
    assert(public(a,'CreateConditionEditBox').source.args[1].name=='self')
    local _,trimID=public(a,'trim');a.Functions.text.trim=function() return 'live namespace getter' end;assert(a:ResolveFunctionBinding(trimID)()=='live namespace getter')
end)
test('platform public helpers retain real source getters typed receivers and multiple results',function()
    local _,a=fixture();local record,id=public(a,'Platform_IsSpellReady')
    assert(record.source.args[1].name=='self' and record.source.args[1].type=='RMPlatform' and #record.source.returns==2)
    assert(a:ResolveFunctionBinding(id)==a.Platform.IsSpellReady,'dotted getter did not reference the real platform method')
    local ready=clone(a,'Platform_IsSpellReady');a.Platform.GetSpellCooldown=function() return {isEnabled=true,startTime=0,duration=0} end
    assert(ready(a.Platform,403,100)==true)
    local spell=public(a,'Widget_GetSpellId');assert(#spell.source.returns==2 and spell.source.args[2].name=='spellid')
end)
test('cloned cache helpers preserve nil tuples retry misses and cache identity',function()
    local _,a=fixture();local cached=clone(a,'getCached');local retry=clone(a,'getRetryCached');local calls=0
    local fn=function(value) calls=calls+1;return value,nil,'tail' end;local cache={}
    local x,y,z=cached(cache,fn,3);assert(x==3 and y==nil and z=='tail');cached(cache,fn,3);assert(calls==1)
    local misses=0;local absent=function() misses=misses+1;return nil,nil end;cached(cache,absent);cached(cache,absent);assert(misses==1)
    local retryCache={};retry(retryCache,absent);retry(retryCache,absent);assert(misses==3)
end)
test('cloned utility bodies preserve the real addon helper results',function()
    local _,a=fixture();local compare=clone(a,'compare');assert(compare('GREATERTHAN',5,3)==a.compare('GREATERTHAN',5,3))
    local isin=clone(a,'isin');assert(isin({flag=false},'flag') and not isin({},'flag'))
    local nullable=clone(a,'nullable');local nullableValue=clone(a,'nullable_value');assert(nullable(nil,'missing')==a.nullable(nil,'missing'));assert(nullableValue('key',{key=false},'missing')==false)
    local split=clone(a,'split');assert(table.concat(split('one,two',','),'|')==table.concat(a.split('one,two',','),'|'))
    local wrap=clone(a,'wrap');assert(wrap('one two three four',7)==a.wrap('one two three four',7));local trim=clone(a,'trim');assert(trim('  text\t')=='text')
end)
test('native field helper clones create the same widget contracts and unit controls',function()
    local f,a=fixture();dofile('tests/fixtures/native_ui.lua')(f.env)
    for name,kind in pairs({CreateConditionLink='RM-ConditionLink',CreateConditionPositionPad='RM-ConditionPositionPad',CreateConditionIcon='RM-ConditionIcon',CreateConditionLabel='RM-ConditionLabel',CreateConditionButton='RM-ConditionButton',CreateConditionGroup='RM-ConditionGroup',CreateConditionEditBox='RM-ConditionEditBox',CreateConditionSlider='RM-ConditionSlider',CreateConditionDropdown='RM-Selector',CreateConditionCheckBox='RM-CheckBox'}) do
        local fn=clone(a,name);local widget=fn(a);assert(widget.type==kind and widget.SetCallback and (widget.SetDisabled or widget.AddChild or widget.SetFontObject))
    end
    local unit=clone(a,'Widget_UnitWidget');local value={unit='player'};local updates=0;local widget=unit(a,value,{player='Player',target='Target'},function() updates=updates+1 end);widget.configure();assert(widget:GetValue()=='player');widget:Fire('OnValueChanged','target');assert(value.unit=='target' and updates==1)
end)
test('saved Ace factory bodies retain captured library bindings after native migration',function()
    local f,a=fixture()
    f.load('Conditions/combat.lua');f.load('Conditions/talent.lua')
    for _,module in ipairs({'Conditions/common.lua','Conditions/combat.lua','Conditions/talent.lua'}) do assert(a:ResolveFunctionBinding('builtin:'..module..':AceGUI')==f.libraries['AceGUI-3.0']) end
    f.libraries['AceGUI-3.0'].Release=function(_,widget) widget.isQueuedForRelease=true;widget:OnRelease();widget.isQueuedForRelease=nil end
    for index,entry in ipairs({{'UI/checkbox.lua','RM-CheckBox'},{'UI/selector.lua','RM-Selector'},{'UI/condition_inputs.lua','RM-ConditionEditBox'},{'UI/condition_inputs.lua','RM-ConditionSlider'}}) do
        local id='builtin:'..entry[1]..':AceGUI';assert(a:ResolveFunctionBinding(id)==f.libraries['AceGUI-3.0'])
        local source={description='Historical cloned factory',args={{name='self',type='table'}},returns={{type='table'}},bindings={AceGUI=id},code='return AceGUI:Create("'..entry[2]..'")'}
        assert(a:InstallCustomFunction('OLD_FACTORY_'..index,source))
        local factory=assert(a:ResolveFunctionBinding('OLD_FACTORY_'..index));local widget=factory(a)
        assert(widget.type==entry[2] and widget.rmActive and widget.Release);assert(a:ReleaseConditionWidget(widget));assert(not a:ReleaseConditionWidget(widget))
    end
end)
test('public helper catalog is available across the reviewed client inventory',function()
    for _,case in ipairs(dofile('tests/fixtures/catalog_inventory.lua').branches) do
        local _,a=fixture(unpack(case[1]));for name in pairs(expected) do local record=public(a,name);assert(a:ValidateCustomFunctionSource('CHECK_'..name,record.source)) end
    end
end)
test('public descriptions argument help and return help use runtime locale keys',function()
    local f=F.new();local docs=dofile('tools/public_helpers.lua').getCached
    f.translations[docs.description]='Localized helper';f.translations[docs.args.cache.description]='Localized argument';f.translations[docs.returns.description]='Localized return'
    f.load('Data/builtin_sources.lua');f.load('Core/builtin_sources.lua');local record=public(f.addon,'getCached')
    assert(record.source.description=='Localized helper' and record.source.args[1].description=='Localized argument' and record.source.returns[1].description=='Localized return')
end)
test('spell field clones retain original group callbacks and update the same record fields',function()
    local f,a=fixture(1,10);dofile('tests/fixtures/native_ui.lua')(f.env);local fn=clone(a,'Widget_SpellWidget')
    local function input() local widget=f.widget('EditBox');widget.type='TestEditBox';widget.frame=f.env.CreateFrame('Frame');return widget end
    a.CreateSpellEditBox=function() return input() end;a.CreateSpellActionIcon=function() return input() end
    a.SpellCatalog.SpellName=function(_,id) return 'Spell '..tostring(id) end;a.SpellCatalog.GetSpellId=function() return 123 end
    for _,helper in ipairs({a.Widget_SpellWidget,fn}) do
        local value={spell=123};local changed=0;local group=helper(a,0,'Spec_EditBox',value,function() return 456 end,function(id) return type(id)=='number' end,function() changed=changed+1 end)
        assert(group.layout=='RM-SpellField' and #group.children==2)
        local spell=group.children[2];spell.callbacks.OnEnterPressed(spell,'OnEnterPressed','New name');assert(value.spell==456 and changed==1)
    end
end)
finish()
