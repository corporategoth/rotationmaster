local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local inverse,old,repaired=dofile('tests/fixtures/restore_environment_selector_repairs.lua')
local function fixture()
    local f=F.new();local a=f.addon
    for _,p in ipairs({'Core/conditions.lua','Conditions/misc.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(p) end
    f.env.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,f.env) end;return fn,why end
    return f,a
end
local function mount(a,tag,value,definition)
    definition=definition or a.conditionDefinitions[tag]
    local root={type=tag,condition=value};local parent=a:CreateConditionGroup();local state={prints=0,statuses=0};local funcs={};local top={}
    function top:GetUserData(key) if key=='root' then return root elseif key=='funcs' then return funcs end end
    function funcs:print(actualRoot,spec)
        assert(self==funcs and actualRoot==root and spec==7,'summary receiver/root/spec changed')
        state.prints=state.prints+1;state.observed={value=value.value};return definition.print(spec,value)
    end
    function top:SetStatusText(text) state.statuses=state.statuses+1;assert(state.statuses==state.prints,'status updated before printing');state.status=text end
    parent:SetUserData('top',top);definition.widget(parent,7,value)
    assert(#parent.children==1 and a:IsConditionWidget(parent.children[1]),'widget did not build one native dropdown')
    local dropdown=parent.children[1];dropdown.configure();return dropdown,state,parent
end
local function rowFor(dropdown,value)
    dropdown.button:Click();assert(dropdown.selector.frame:IsShown(),'native popup did not open')
    for _,row in ipairs(dropdown.selector.rows) do if row.menuEntry and row.menuEntry.value==value then return row end end
    error('native popup has no requested row: '..tostring(value))
end
local function choose(dropdown,value) rowFor(dropdown,value):Click() end
local function unchanged(value,nested)
    assert(value.sentinel==nested and nested.child=='same' and value.other==false,'selection changed unrelated/shallow data')
    assert(value.vlaue==nil,'selection introduced misspelled data')
end
local function clearZone(a,definition)
    local nested={child='same'};local value={value='hostile',sentinel=nested,other=false};local zone,state,parent=mount(a,'ZONEPVP',value,definition)
    assert(zone.list~=a.zonepvp and zone.list['']=='no PVP' and a.zonepvp['']==nil,'no-PVP choice leaked into canonical data')
    for key,label in pairs(a.zonepvp) do assert(zone.list[key]==label,'zone list lost a named option') end
    choose(zone,'');assert(value.value==nil,'empty zone selection retained the previous stored mode')
    assert(state.prints==1 and state.statuses==1 and state.observed.value==nil,'summary did not observe nil before refresh');unchanged(value,nested)
    zone.configure();assert(zone:GetValue()=='','reconfigure restored a stale zone selection');local blank=rowFor(zone,'');assert(blank.menuEntry.value=='' and zone.selector.selected=='','reopened popup lost empty selection');zone.selector:Hide()
    choose(zone,'friendly');assert(value.value=='friendly' and state.observed.value=='friendly' and state.prints==2 and state.statuses==2,'named zone selection changed');unchanged(value,nested)
    parent:Release()
end
local function clearInstance(a,definition)
    local nested={child='same'};local value={value='party',sentinel=nested,other=false};local instance,state,parent=mount(a,'INSTANCE',value,definition)
    assert(instance.list==a.instances and instance.list['']==nil,'INSTANCE added an empty menu option or copied its canonical list')
    instance:Fire('OnValueChanged','');assert(value.value==nil,'defensive empty instance callback retained the previous stored mode')
    assert(state.prints==1 and state.statuses==1 and state.observed.value==nil,'instance summary did not observe cleared selection');unchanged(value,nested)
    instance.configure();assert(instance:GetValue()=='','nil instance did not configure blank')
    local count=0;for _ in pairs(instance.list) do count=count+1 end;assert(count==6,'INSTANCE normal option set changed')
    for _,selected in ipairs({'none','pvp','arena','party','raid','scenario'}) do choose(instance,selected);assert(value.value==selected and state.observed.value==selected,'normal INSTANCE selection changed');unchanged(value,nested) end
    assert(state.prints==7 and state.statuses==7,'INSTANCE selection refreshed status unexpectedly');parent:Release()
end
test('native zone empty row clears stored mode before summary and survives reopening',function() local _,a=fixture();clearZone(a) end)
test('native instance defensive empty event clears mode and keeps all six ordinary choices',function() local _,a=fixture();clearInstance(a) end)
test('released zone popup rows cannot clear the retired owner or a recycled selector',function()
    local _,a=fixture();local value={value='hostile'};local zone,state,parent=mount(a,'ZONEPVP',value);local row=rowFor(zone,'');local stale=row.scripts.OnClick
    parent:Release();local nextValue={value='friendly'};local reused,nextState,nextParent=mount(a,'ZONEPVP',nextValue);assert(reused==zone,'test did not exercise recycled selector')
    stale(row);assert(value.value=='hostile' and nextValue.value=='friendly' and state.prints==0 and nextState.prints==0,'stale popup changed an owner');nextParent:Release()
end)
test('exact widget inverses preserve complete module and reject unrelated or duplicate bodies',function()
    local _,a=fixture();local file=assert(io.open('Conditions/misc.lua'));local text=file:read('*a');file:close()
    assert(a:FunctionSourceHash(inverse(text))=='5b75d6d9','misc changed beyond the two exact widget repairs from75f8297')
    for _,tag in ipairs({'ZONEPVP','INSTANCE'}) do
        assert(inverse(repaired[tag],tag)==old[tag]);assert(not pcall(inverse,old[tag],tag));assert(not pcall(inverse,repaired[tag]..' ',tag))
        assert(not pcall(inverse,text..repaired[tag]),'inverse accepted duplicate widget body')
    end
    assert(not pcall(inverse,repaired.ZONEPVP,'UNKNOWN'))
    for name,hash in pairs({color='89a5436e',helpers='3ab28a24'}) do local id='builtin:Conditions/misc.lua:'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/misc.lua'](name),'private identity changed') end
end)
if arg[1]~='--runtime-only' then
    test('actual exported widget clones clear selectors through current source bindings',function()
        local _,a=fixture()
        for _,tag in ipairs({'ZONEPVP','INSTANCE'}) do
            local source=assert(a:GetBuiltinConditionSource(tag));assert(source.widget==repaired[tag],'actual '..tag..' widget catalog is stale')
            assert(table.concat(source.parameters.widget,',')=='parent,spec,value','widget parameter identity changed')
            local copy=assert(a:CompileCustomCondition('CLONE_'..tag,source));if tag=='ZONEPVP' then clearZone(a,copy) else clearInstance(a,copy) end
        end
    end)
end
test('raw historical saved widgets keep original typo behavior and source data exactly',function()
    local _,a=fixture();a.db.global.custom_conditions={}
    for _,tag in ipairs({'ZONEPVP','INSTANCE'}) do
        local source=assert(a:GetBuiltinConditionSource(tag));source.widget=old[tag];local before=a:CopySettingsData(source);a.db.global.custom_conditions['RAW_'..tag]=source
        local copy=assert(a:CompileCustomCondition('RAW_'..tag,source));local value={value=tag=='ZONEPVP' and 'hostile' or 'party'};local previous=value.value
        local widget,state,parent=mount(a,tag,value,copy)
        if tag=='ZONEPVP' then choose(widget,'') else widget:Fire('OnValueChanged','') end
        assert(value.value==previous and state.observed.value==previous and state.statuses==1,'raw historical callback behavior was rewritten')
        assert(a:SettingsDataEqual(before,source) and a.db.global.custom_conditions['RAW_'..tag]==source,'saved raw source changed');parent:Release()
    end
end)
finish()
