local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local uuid='61b36ed1-fa31-4656-ad71-f3d50f193a85'
local function fixture()
    local f=F.new();local a,e=f.addon,f.env
    for _,path in ipairs({'Core/custom_authoring.lua','Core/custom_condition_services.lua','Core/schema_authoring.lua','validate.lua'}) do f.load(path) end
    local warnings={};a.warn=function(_,format,...) warnings[#warnings+1]=string.format(format,...) end
    a.savedVariableName='SchemaRepairFixtureDB';e.SchemaRepairFixtureDB={global={custom_conditions={},function_import_origins={}},char={},profiles={Fixture={announces={}}}}
    local template={global={custom_conditions={},custom_functions={},function_import_origins={}},char={},profile={announces={},minimap={hide=false}}}
    return f,a,e.SchemaRepairFixtureDB,template,warnings
end
local function source(a)
    local v=a:CopySettingsData(a.empty_condition);v.description='Imported requirement';v.fields={unit='string',value='number',items='{ string, { string, number } }'}
    v.bindings={['Functions.values.compare']='builtin:utils.lua:compare',dependency='UNAVAILABLE_CUSTOM_HELPER'}
    v.parameters={evaluate={'input','memo','beginning'},widget={'container','specification','input'},on_register={'identifier'}}
    v.requiredFields={'unit','value'};v.fieldOrder={{'value'},{'unit'},{'items'}};v.disabled=false
    return v
end
local function announce(item) return {id=uuid,name='Item notice',type='item',item=item,event='SUCCEEDED',announce='party',value='Used item'} end
test('repair preserves valid custom bindings original parameters root requirements order and detached import origins',function()
    local _,a,db,template=fixture();local v=source(a);db.global.custom_conditions.CUSTOM=v
    db.global.function_import_origins['condition:CUSTOM']={originalID='FOREIGN',hash='01234567',importedHash='89abcdef',provenance={source='manual-import'}}
    local expected=a:CopySettingsData(db);local bindings,parameters,required,order=v.bindings,v.parameters,v.requiredFields,v.fieldOrder
    a:validate(template,true);assert(a:SettingsDataEqual(db,expected),'repair discarded a valid persisted schema field')
    assert(v.bindings==bindings and v.parameters==parameters and v.requiredFields==required and v.fieldOrder==order,'repair replaced valid source metadata')
end)
test('numeric custom icons and explicitly supported legacy union source text stay byte-exact',function()
    local _,a=fixture();local v=source(a);v.icon=12345;local before=a:CopySettingsData(v);a:validate_custom_condition('fixture','CUSTOM',v,true)
    assert(a:SettingsDataEqual(v,before) and v.fields.items=='{ string, { string, number } }')
end)
test('read-only validation never writes even when semantic metadata is malformed',function()
    local _,a,db,template,warnings=fixture();local v=source(a);v.bindings={addon='BAD'};v.parameters={unknown={'value'}};v.requiredFields={'missing'};db.global.custom_conditions.CUSTOM=v
    local before=a:CopySettingsData(db);a:validate(template,false);assert(a:SettingsDataEqual(db,before) and #warnings>0)
end)
test('malformed custom metadata is preserved and disabled without compiling or executing source',function()
    for _,mutation in ipairs({function(v) v.bindings='bad' end,function(v) v.bindings={addon='BAD'} end,function(v) v.bindings={input='BAD'} end,
        function(v) v.parameters={evaluate={[2]='input'}} end,function(v) v.parameters={unknown={'input'}} end,
        function(v) v.requiredFields={'missing'} end,function(v) v.requiredFields={'unit','unit'} end,function(v) v.fieldOrder={{'missing'}} end,
        function(v) v.fields={x='userdata'} end,function(v) v.icon={} end}) do
        local f,a,_,_,warnings=fixture();local v=source(a);mutation(v);local before=a:CopySettingsData(v);before.disabled=true
        f.env.loadstring=function() error('repair must not invoke executable compiler') end
        a:validate_custom_condition('fixture','CUSTOM',v,true);assert(a:SettingsDataEqual(v,before),'repair erased semantic metadata or enabled an invalid condition');assert(#warnings>0 and table.concat(warnings,'\n'):find('disabled',1,true),'quarantine warning missing')
        local compiled=assert(a:CompileCustomCondition('CUSTOM',v));assert(compiled.disabled and not compiled.evaluate,'malformed disabled source reached executable compilation')
    end
end)
test('valid empty or absent metadata stays distinct while ordinary extra fields retain repair behavior',function()
    local _,a=fixture();for _,empty in ipairs({false,true}) do local v=source(a);v.fields={};v.parameters=empty and {} or nil;v.bindings=empty and {} or nil;v.requiredFields=empty and {} or nil;v.fieldOrder=empty and {} or nil;v.extra='remove';a:validate_custom_condition('fixture','CUSTOM',v,true)
        assert(v.extra==nil and v.disabled==false);for _,field in ipairs({'bindings','parameters','requiredFields','fieldOrder'}) do assert(empty and type(v[field])=='table' or not empty and v[field]==nil) end
    end
end)
test('item announcement named lists and dense custom item arrays retain exact contents and identity',function()
    local _,a,db,template=fixture();local items={5512,'Healthstone',6948};db.profiles.Fixture.announces={announce(uuid),announce(items)}
    local before=a:CopySettingsData(db);a:validate(template,true);assert(a:SettingsDataEqual(db,before),'repair removed announcement items');assert(db.profiles.Fixture.announces[2].item==items)
end)
test('malformed item references cannot become enabled repaired announcement records',function()
    for _,item in ipairs({17,false,{},'',{5512,{}},{0},{-1},{1.5},{math.huge},{''},{[2]=5512}}) do
        local _,a,_,_,warnings=fixture();local v=announce(item);local before=a:CopySettingsData(v);before.disabled=true;a:validate_announce('fixture',1,v,true)
        assert(a:SettingsDataEqual(v,before),'repair silently rewrote invalid announcement membership');assert(#warnings>0)
    end
end)
test('normal announcement validation and legacy repair use the same item-reference acceptance service',function()
    local cases={{value=uuid,valid=true},{value={5512,'Healthstone'},valid=true},{value='',valid=false},{value={},valid=false},{value=17,valid=false},{value={0},valid=false},{value={math.huge},valid=false},{value={[2]=5512},valid=false},{value={5512,unexpected=6948},valid=false},{value=string.rep('x',129),valid=false},{value={string.rep('x',1025)},valid=false}}
    for _,case in ipairs(cases) do local _,a=fixture();local shared=assert(a.IsValidAnnouncementItemReference);local calls=0
        a.IsValidAnnouncementItemReference=function(self,item) calls=calls+1;assert(item==case.value);return shared(self,item) end
        local v=announce(case.value);assert(a:IsValidAnnouncement(v,true)==case.valid);a:validate_announce('fixture',1,v,true)
        assert(calls==2 and v.item==case.value and (v.disabled==true)==not case.valid,'validators disagreed or rewrote item membership')
    end
    local _,a=fixture();local legacy=announce(nil);legacy.type='petspell';legacy.spell=123;legacy.ranked=true;local before=a:CopySettingsData(legacy);a:validate_announce('fixture',1,legacy,true);assert(a:SettingsDataEqual(legacy,before),'legacy petspell repair changed')
end)
test('optional library minimap state is preserved without manufacturing persisted defaults',function()
    local _,a,db,template=fixture();local options={hide=false,minimapPos=231.5,lock=true,radius=9,showInCompartment=true};db.profiles.Fixture.minimap=options
    local before=a:CopySettingsData(db);local oldTemplate=a:CopySettingsData(template);a:validate(template,true);assert(a:SettingsDataEqual(before,db) and db.profiles.Fixture.minimap==options and a:SettingsDataEqual(template,oldTemplate))
    db.profiles.Fixture.minimap={hide=false};a:validate(template,true);assert(a:SettingsDataEqual(db.profiles.Fixture.minimap,{hide=false}),'repair invented optional library defaults')
    db.profiles.Fixture.minimap=nil;a:validate(template,true);assert(db.profiles.Fixture.minimap==nil)
end)
test('minimap type and finite-value checks still reject malformed optional or unknown keys',function()
    local _,a,db,template=fixture();local options={hide=false,minimapPos='bad',lock='true',radius=math.huge,showInCompartment=1,unknown='remove'};db.profiles.Fixture.minimap=options
    local before=a:CopySettingsData(db);a:validate(template,false);assert(a:SettingsDataEqual(before,db));a:validate(template,true);assert(a:SettingsDataEqual(options,{hide=false}))
end)
test('repair quarantines only the current compiled custom definition without hooks before reload',function()
    local f,a,db=fixture();f.load('Core/conditions.lua');a.db.global=db.global;local v=source(a);v.requiredFields={'missing'};db.global.custom_conditions.CUSTOM=v
    local calls=0;local definition={customCode=true,fields={},valid=function() calls=calls+1;return true end,evaluate=function() calls=calls+1;return true end,on_register=function() error('repair executed register hook') end,on_unregister=function() error('repair executed unregister hook') end};a.conditionDefinitions.CUSTOM=definition
    assert(a:evaluateConditionResult({type='CUSTOM'}).status=='match');calls=0;a.conditionRegistryVersion=9
    a:validate_custom_condition('fixture','CUSTOM',v,false);assert(not definition.disabled and a.conditionRegistryVersion==9 and not v.disabled)
    local foreign=a:CopySettingsData(v);a:validate_custom_condition('fixture','CUSTOM',foreign,true);assert(foreign.disabled and not definition.disabled and a.conditionRegistryVersion==9)
    a:validate_custom_condition('fixture','CUSTOM',v,true);assert(v.disabled and definition.disabled and a.conditionRegistryVersion==10 and calls==0)
    assert(a:evaluateConditionResult({type='CUSTOM'}).status=='unavailable' and a:evaluateConditionResult({type='NOT',value={type='CUSTOM'}}).status=='unavailable' and calls==0)
    a:validate_custom_condition('fixture','CUSTOM',v,true);assert(a.conditionRegistryVersion==10,'repeated repair invalidated registry repeatedly')
end)
test('repair preserves recognized offline character legacy roots without performing login migration',function()
    for _,version in ipairs({false,1}) do local _,a,db,template=fixture();template.char={bindings={}};local old={rotations={[0]={[uuid]={name='Old rotation',rotation={}}}},itemsets={[uuid]={name='Old items',items={5512}}},announces={announce({5512})}}
        if version then old.version=version;template.char.version=2 end;db.char['Offline - Realm']=old;db.char['Current - Realm']={bindings={}};local before=a:CopySettingsData(db);local roots={old.rotations,old.itemsets,old.announces}
        a:validate(template,true);assert(a:SettingsDataEqual(db,before),'repair dropped offline legacy owner data');assert(old.rotations==roots[1] and old.itemsets==roots[2] and old.announces==roots[3] and (not version or old.version==1))
    end
end)
test('native effect schemas preserve numeric textures at every supported stored position',function()
    for _,kind in ipairs({'texture','dazzle','pulse','rotate','custom','animate'}) do local f,a=fixture();f.load('UI/settings_effects.lua')
        local value={name='Effect',type=kind,texture=136048};if kind~='texture' then value.frequency=.25 end
        if kind=='dazzle' then value.sequence={{r=1,g=1,b=1,a=1}}
        elseif kind=='pulse' then value.sequence={.5,1.5}
        elseif kind=='rotate' then value.steps=4
        elseif kind=='custom' then value.texture=nil;value.sequence={{texture=136048,angle=0,magnification=1,color={r=1,g=1,b=1,a=1}}}
        elseif kind=='animate' then value.texture=nil;value.sequence={136048,'Interface\\Icons\\Spell_Nature_Lightning'} end
        assert(a:IsValidEffectDefinition(value));local before=a:CopySettingsData(value);a:validate_effect('global',uuid,value,true);assert(a:SettingsDataEqual(value,before),kind..' valid numeric texture changed')
    end
end)
test('effect type validation still removes malformed textures sequence values and unknown fields',function()
    local _,a=fixture();local top={name='Effect',type='texture',texture=false,unexpected=42};a:validate_effect('global',uuid,top,true);assert(top.texture==nil and top.unexpected==nil)
    local custom={name='Custom',type='custom',sequence={{texture={},angle=0,magnification=1,color={r=1,g=1,b=1,a=1},unexpected=42}}};a:validate_effect('global',uuid,custom,true);assert(custom.sequence[1].texture==nil and custom.sequence[1].unexpected==nil)
    local animate={name='Animate',type='animate',sequence={136048,false,'Texture',{},17}};local before=a:CopySettingsData(animate);a:validate_effect('global',uuid,animate,false);assert(a:SettingsDataEqual(animate,before));a:validate_effect('global',uuid,animate,true);assert(a:SettingsDataEqual(animate.sequence,{136048,'Texture',17}))
end)
test('pure action schema pet any spell rank and common appearance fields survive flat repair in both lists',function()
    local data=dofile('tests/fixtures/rotation_data.lua')()
    for _,scope in ipairs({'rotation','cooldowns'}) do for _,kind in ipairs({'pet','any','spell'}) do local _,a=fixture();a.RotationData=data
        local step={id=uuid,type=kind,action=529,ranked=true,conditions={},effect=uuid,color={r=.1,g=.2,b=.3,a=.4},magnification=1.25,setpoint='CENTER',xoffs=2,yoffs=-3,announce='local',announce_sound='Bell'}
        local body={name='Action',rotation={},cooldowns={}};body[scope][1]=step;assert(data.ValidateBody(body,{effects={[uuid]={}}}).valid);local before=a:CopySettingsData(body)
        a:validate_rotation('fixture',uuid,body,true);assert(step.action==529,kind..' action removed');assert(step.ranked==true,kind..' exact rank removed');assert(a:SettingsDataEqual(body,before),scope..' common appearance changed')
    end end
end)
test('flat step repair keeps type rejection and reports malformed UUID fields without formatting exceptions',function()
    local data=dofile('tests/fixtures/rotation_data.lua')()
    for _,fix in ipairs({false,true}) do for _,scope in ipairs({'rotation','cooldowns'}) do for _,mode in ipairs({'id','effect','item-type','item-id','field-types'}) do local _,a,_,_,warnings=fixture();a.RotationData=data
        local step={id=uuid,type='spell',action=403,ranked=true};if mode=='id' then step.id='bad' elseif mode=='effect' then step.effect='bad' elseif mode=='item-type' then step.type='item';step.action=false elseif mode=='item-id' then step.type='item';step.action='bad' else step.action='bad';step.ranked='bad';step.color='bad';step.effect={};step.unexpected=true end
        local body={name='Action',rotation={},cooldowns={}};body[scope][1]=step;local before=a:CopySettingsData(body);a:validate_rotation('fixture',uuid,body,fix);assert(#warnings>0)
        if not fix then assert(a:SettingsDataEqual(body,before)) elseif mode=='id' then assert(#body[scope]==0) elseif mode=='field-types' then assert(step.action==nil and step.ranked==nil and step.color==nil and step.effect==nil and step.unexpected==nil) end
    end end end
end)
test('unknown effect kinds are reported without throwing or deleting future records',function()
    for _,fix in ipairs({false,true}) do local _,a,_,_,warnings=fixture();local v={name='Future effect',type='future-kind',texture=123,sequence={{future=true}}};local before=a:CopySettingsData(v);a:validate_effect('global',uuid,v,fix);assert(a:SettingsDataEqual(v,before) and #warnings>0) end
end)
test('repair retains scoped ownership roots including incomplete and invalid archives without adopting them',function()
    local f,a,db,template,warnings=fixture();a.RotationData=dofile('tests/fixtures/rotation_data.lua')();f.load('Data/catalog.lua');f.load('Data/rotation_store.lua')
    local root={version=1,classes={SHAMAN={[0]={same={body={name='Incomplete',rotation=false,cooldowns={}}}}}},characters={},legacy={origins={[0]={orphan={source='unknown'}}}}}
    db.profiles.Fixture.rotationStore=root;local before=a:CopySettingsData(db);local oldTemplate=a:CopySettingsData(template)
    a:validate(template,false);a:validate(template,true);assert(a:SettingsDataEqual(before,db) and db.profiles.Fixture.rotationStore==root,'repair erased or rewrote owned records')
    assert(#warnings==0 and a:SettingsDataEqual(template,oldTemplate),'repair invented defaults or reported valid ownership as extra')
    root.version=999;before=a:CopySettingsData(db);a:validate(template,false);a:validate(template,true)
    assert(a:SettingsDataEqual(before,db) and db.profiles.Fixture.rotationStore==root,'repair dropped unknown ownership state')
    assert(#warnings==2 and warnings[1]:find('preserved',1,true),'invalid ownership should be reported without destructive repair')
    db.profiles.Empty={};a:validate(template,true);assert(db.profiles.Empty.rotationStore==nil,'repair manufactured ownership')
end)
finish()
