local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local id='builtin:Conditions/common.lua:Widget_UnitWidget'
local function fixture()
    local f=F.new();local file=io.open('UI/condition_unit.lua');if file then file:close();f.load('UI/condition_unit.lua') end
    for _,path in ipairs({'Core/conditions.lua','Conditions/common.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    f.env.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,f.env) end;return fn,why end
    return f,f.addon
end
local function choices() return {player='You',focus='Focus',target='Target'} end
test('native unit factory has one actual UI owner and preserves its original source identity',function()
    local _,a=fixture();assert(debug.getinfo(a.Widget_UnitWidget,'S').source=='@UI/condition_unit.lua','factory still belongs to condition declarations')
    assert(a.builtinSourceModules['UI/condition_unit.lua']('Widget_UnitWidget')==a.Widget_UnitWidget)
    assert(a.builtinSourceModules['Conditions/common.lua']('Widget_UnitWidget')==a.Widget_UnitWidget and a:ResolveFunctionBinding(id)==a.Widget_UnitWidget)
    assert(not a.builtinFunctions['builtin:UI/condition_unit.lua:Widget_UnitWidget'],'historical factory gained a second source ID')
    assert(a:FunctionSourceHash(a.builtinFunctions[id].source)=='40eccf8e')
end)
test('native owner loads without frame allocation Ace lookup or registration',function()
    local f=F.new();local stub=f.env.LibStub;local create=f.env.CreateFrame;local frames=0
    f.env.LibStub=function(name,...) assert(name~='AceGUI-3.0','unit owner queried Ace');return stub(name,...) end
    f.env.CreateFrame=function(...) frames=frames+1;return create(...) end
    assert(not f.libraries['AceGUI-3.0'])
    f.load('UI/condition_unit.lua');assert(frames==0 and type(f.addon.Widget_UnitWidget)=='function')
    local widget=f.addon:Widget_UnitWidget({unit='player'},choices(),function() end);assert(widget.rmWidget and widget.rmActive and frames>0);f.addon:ReleaseConditionWidget(widget)
end)
test('public typed contract original parameter order and documentation remain unchanged',function()
    local _,a=fixture();local source=assert(a.builtinFunctions[id]).source
    assert(source.name=='Widget_UnitWidget' and source.namespace=='Conditions.common' and source.description=='Create a configured unit selector bound to a condition value record. Returns the widget for the caller to add to the condition callback parent.')
    local expected={{'self','RMAddon','Rotation Master addon instance (implicit with colon calls).'},
        {'value','table','Condition value record updated when a unit is chosen.'},
        {'units','table','Unit key-to-display-name map shown in the selector.'},
        {'update','function','Callback invoked after changing the selected unit.'},
        {'field','string | nil','Value record field to edit; defaults to unit.'}}
    assert(#source.args==5 and #source.returns==1)
    for index,arg in ipairs(expected) do local actual=source.args[index];assert(actual.name==arg[1] and actual.type==arg[2] and actual.description==arg[3]) end
    assert(source.returns[1].type=='RMConditionSelector' and source.returns[1].description=='Configured unit selector; add it with parent:AddChild(widget).')
    assert(source.code:find('addon.keys(units)',1,true),'live compatibility dispatch changed')
end)
test('default unit field disabled state sorted dropdown and explicit selection are native',function()
    local f,a=fixture();assert(not f.libraries['AceGUI-3.0'])
    local value={unit='target',disabled=true};local updates=0;local units=choices();local widget=a:Widget_UnitWidget(value,units,function() updates=updates+1 end)
    assert(widget.rmWidget and widget.rmActive and not widget.rmLegacyOwned and widget.disabled and widget.caption:GetText()=='Unit')
    widget.configure();assert(widget.list==units and widget.order[1]=='focus' and widget.order[2]=='target' and widget.order[3]=='player' and widget.value=='target' and updates==0)
    value.unit='player';widget.configure();assert(widget.value=='player' and updates==0)
    widget:SetDisabled(false);widget:Fire('OnValueChanged','focus');assert(value.unit=='focus' and updates==1)
    a:ReleaseConditionWidget(widget)
end)
test('explicit field changes only the supplied key and preserves caller table and update contract',function()
    local _,a=fixture();local value={unit='player',otherunit='target'};local updates=0;local widget=a:Widget_UnitWidget(value,choices(),function(...) assert(select('#',...)==0);updates=updates+1 end,'otherunit')
    widget.configure();assert(widget.value=='target');widget:Fire('OnValueChanged','focus');assert(value.otherunit=='focus' and value.unit=='player' and updates==1)
    a:ReleaseConditionWidget(widget)
end)
test('configure resolves the current legacy key function on every call with exact supplied choices',function()
    local _,a=fixture();local units=choices();local value={unit='player'};local widget=a:Widget_UnitWidget(value,units,function() error('configure must not commit') end);local calls=0
    a.keys=function(input) assert(input==units);calls=calls+1;return {'player','target','focus'} end
    widget.configure();assert(calls==1 and widget.order[1]=='player' and widget.order[3]=='focus')
    a.keys=function(input) assert(input==units);calls=calls+1;return {'focus'} end
    value.unit='focus';widget.configure();assert(calls==2 and #widget.order==1 and widget.order[1]=='focus' and widget.value=='focus')
    a:ReleaseConditionWidget(widget)
end)
test('retired and ancestor-releasing callbacks cannot mutate either original or recycled draft',function()
    local _,a=fixture();local first={unit='player'};local count=0;local widget=a:Widget_UnitWidget(first,choices(),function() count=count+1 end);local retired=widget.events.OnValueChanged
    a:ReleaseConditionWidget(widget);retired(widget,'OnValueChanged','target');assert(first.unit=='player' and count==0)
    local second={unit='focus'};local reused=a:Widget_UnitWidget(second,choices(),function() count=count+1 end);assert(reused==widget);retired(widget,'OnValueChanged','target');assert(second.unit=='focus' and first.unit=='player' and count==0)
    reused.parent={isQueuedForRelease=true};reused:Fire('OnValueChanged','target');assert(second.unit=='focus' and count==0);reused.parent=nil
    reused:Fire('OnValueChanged','target');assert(second.unit=='target' and count==1);a:ReleaseConditionWidget(reused)
end)
test('actual old requirement bundle imports and executes through the exact historical factory ID',function()
    local _,a=fixture();local source={description='Saved unit field',args={{name='value',type='table'},{name='units',type='table'},{name='update',type='function'},{name='field',type='string | nil'}},returns={{type='RMConditionSelector'}},bindings={unitFactory=id},code='return unitFactory(addon,value,units,update,field)'}
    local bundle=assert(a:BuildFunctionBundle('function','SAVED_UNIT_FACTORY',source));assert(#bundle.requirements==1 and bundle.requirements[1].id==id and bundle.requirements[1].hash=='40eccf8e')
    local plan=assert(a:PlanFunctionBundleImport(bundle));assert(plan.valid and plan.requirements[1].status=='available');assert(a:ApplyFunctionBundleImport(plan))
    local value={otherunit='focus'};local changed=0;local widget=a:ResolveFunctionBinding('SAVED_UNIT_FACTORY')(value,choices(),function() changed=changed+1 end,'otherunit');widget.configure();assert(widget.value=='focus')
    widget:Fire('OnValueChanged','target');assert(value.otherunit=='target' and changed==1);a:ReleaseConditionWidget(widget)
end)
test('compiled packaged factory copy uses native fields live ordering and guarded leases',function()
    local f,a=fixture();assert(a:InstallCustomFunction('COPY_UNIT_FACTORY',a:CopySettingsData(a.builtinFunctions[id].source)));local copied=assert(a:ResolveFunctionBinding('COPY_UNIT_FACTORY'))
    assert(not f.libraries['AceGUI-3.0'])
    local units=choices();local value={unit='target'};local calls=0;a.keys=function(input) assert(input==units);return {'target','focus'} end
    local widget=copied(a,value,units,function() calls=calls+1 end);widget.configure();assert(widget.rmActive and not widget.rmLegacyOwned and widget.value=='target' and widget.order[1]=='target')
    local retired=widget.events.OnValueChanged;widget:Fire('OnValueChanged','focus');assert(value.unit=='focus' and calls==1);a:ReleaseConditionWidget(widget);retired(widget,'OnValueChanged','player');assert(value.unit=='focus' and calls==1)
end)
finish()
