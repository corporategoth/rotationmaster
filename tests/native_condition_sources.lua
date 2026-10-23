local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local inventory=dofile('tests/fixtures/catalog_inventory.lua')
local retired={
    'Conditions/common.lua','Conditions/combat.lua','Conditions/talent.lua',
    'UI/checkbox.lua','UI/selector.lua','UI/condition_inputs.lua','UI/condition_layout.lua',
}
local function fixture(branch)
    local f=F.new(unpack(branch or {5,1,'SHAMAN'}));local a,e=f.addon,f.env;local lookups={}
    local stub=e.LibStub;e.LibStub=function(name,...)
        if name:lower():find('acegui',1,true) then lookups[#lookups+1]=name;error('GUI library forbidden: '..name,0) end
        return stub(name,...)
    end
    local class=branch and branch[3] or 'SHAMAN';local classID=class=='DEATHKNIGHT' and 6 or 7
    e.UnitClass=function() return class,class,classID end
    e.LOCALIZED_CLASS_NAMES_MALE={SHAMAN='Shaman',DEATHKNIGHT='Death Knight',MAGE='Mage'};e.CLASS_SORT_ORDER={'SHAMAN','DEATHKNIGHT','MAGE'}
    e.LOSS_OF_CONTROL_DISPLAY_STUN='Stunned';e.SCHOOL_STRINGS={[1]='Physical'}
    for index=1,5 do e['SPELL_STAT'..index..'_NAME']='Stat '..index end;e.ARMOR='Armor'
    e.C_Spell={GetSpellInfo=function(id) return {spellID=tonumber(id) or 123,name='Fixture Spell',iconID=123,castTime=1000,minRange=0,maxRange=40} end,
        GetSpellLink=function(id) return '|Hspell:'..id..'|h[Fixture Spell]|h' end,
        GetSpellDescription=function() return 'Fixture spell description' end}
    e.GetSpellInfo=function(id) return 'Fixture Spell',nil,123,1000,0,40,tonumber(id) or 123 end
    e.GetSpellLink=function(id) return '|Hspell:'..id..'|h[Fixture Spell]|h' end
    local function itemInfo(id) return 'Fixture Item','|Hitem:'..id..'|h[Fixture Item]|h',1,1,1,'Glyph','Shaman',1,'',123 end
    local function itemInstant(id) return tonumber(id) or 101,'Glyph','Shaman','',123,16,classID end
    e.C_Item={GetItemInfo=itemInfo,GetItemInfoInstant=itemInstant,GetItemIconByID=function() return 123 end,GetItemCount=function() return 1 end}
    e.GetItemInfo=itemInfo;e.GetItemInfoInstant=itemInstant;e.GetItemIcon=function() return 123 end;e.GetItemCount=function() return 1 end
    e.GetNumShapeshiftForms=function() return 2 end;e.GetShapeshiftFormInfo=function() return 123,false,true,123 end
    e.GetZoneText=function() return 'Fixture Zone' end;e.GetSubZoneText=function() return 'Fixture Subzone' end
    e.GetNumTalentTabs=function() return 3 end;e.GetNumTalents=function() return 2 end
    e.C_SpecializationInfo={GetSpecializationInfo=function(tree) return tree,'Tree '..tree,'Description',123,nil,nil,2 end,
        GetTalentInfo=function() return {name='Fixture Talent',icon=123,rank=1,maxRank=5,talentID=101,spellID=123,tier=1,column=1,selected=true,available=true} end}
    e.ECSLoader={ImportModule=function() return {GetStatInfo=function(name) if name=='power' then return 42 elseif name=='percent' then return '25%' end end} end}
    e.ExtendedCharacterStats={profile={stats={refName='power',text='Power'},percent={refName='percent',text='Percent'}}}
    a.db.profile.itemsets={};a.db.global.itemsets={};a.db.char={bindings={}};a.db.profile.rotations={};a.delayed_condition={};a.unitsInRange={}
    f.load('constants.lua')
    for _,path in ipairs({'Platform/spells.lua','Platform/talents.lua','Platform/inventory.lua','Platform/range.lua','Core/conditions.lua','Core/item_sets.lua','Core/itemset_services.lua','UI/condition_entrypoints.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    if branch and branch[4] then e.MI2_GetMobData=function() end end
    for path in io.lines('RotationMaster.toc') do if path:match('^Conditions/') then f.load(path) end end
    for _,group in pairs(a.delayed_condition) do for tag,definition in pairs(group) do a:RegisterCondition(tag,definition) end end
    f.load('Data/builtin_sources.lua');f.load('Core/builtin_sources.lua')
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,lookups
end
local function first(t) local keys={};for key in pairs(t or {}) do keys[#keys+1]=key end;table.sort(keys,function(a,b) return tostring(a)<tostring(b) end);return keys[1] end
local function sample(a,tag,definition)
    local v={type=tag,unit='target',otherunit='player',operator='GREATERTHAN',value=1,spell=123,item={101},threat=2,
        action='WOUND',loc_type='STUN',school=1,stat=1,class='MAGE',debufftype=first(a.debufftypes),operation='average',
        distance=10,enemy=true,healthoperator='GREATERTHAN',health=.5,manaoperator='GREATERTHAN',mana=.5,tree=1,talent=1,rune=1}
    if tag=='CLASS' then v.value='MAGE' elseif tag=='CLASSIFICATION' then v.value='normal' elseif tag=='CREATURE' then v.value='HUMANOID'
    elseif tag=='PET_NAME' then v.value='Fixture Pet' elseif tag=='ZONE' then v.value='Fixture Zone'
    elseif tag=='ZONEPVP' then v.value='contested' elseif tag=='INSTANCE' then v.value='party'
    elseif tag=='FORM' then v.value=0 elseif tag=='LOC_BLOCKED' then v.school=1
    elseif tag=='IMMUNE' or tag=='RESIST' then v.school='ar'
    elseif tag=='TALENT' then v.layout='tree' elseif tag=='TOTEM' or tag=='TOTEM_REMAIN' then v.spell=1
    elseif tag=='GLYPH' then v.item=101 elseif tag=='ECS_STAT' then v.stat='power' elseif tag=='ECS_STAT_PCT' then v.stat='percent'
    elseif tag=='ROLE' then v.value='HEALER'
    elseif tag=='SET_PIECES' then v.set=500 elseif tag=='ACTION_CONTEXT' then v.context='vehicle'
    elseif tag=='WEAPON_IMBUE' then v.enchant=283 elseif tag=='RUNE_ENGRAVED' then v.rune=nil end
    return v
end
local function tree(a,definition,value,callback)
    local parent=a:CreateConditionGroup();parent:SetWidth(640)
    local owner={values={root=value,funcs={print=function() return 'Fixture summary' end}}}
    function owner:GetUserData(key) return self.values[key] end
    function owner:SetUserData(key,data) self.values[key]=data end
    function owner:SetStatusText(text) self.status=text end
    function owner:Hide() self.hidden=true end
    function owner:Show() self.hidden=false end
    owner.rmCompactRefresh=function() parent:DoLayout() end;parent:SetUserData('top',owner)
    if callback=='widget' then definition.widget(parent,0,value) else definition.help(parent) end
    a:configure_frame(parent);parent:DoLayout()
    local stale,count={},0
    local function visit(w)
        assert(a:IsConditionWidget(w) and w.rmWidget and w.rmActive and w.frame,'Fields UI/Help constructed a non-native widget')
        count=count+1;for event,fn in pairs(w.events or {}) do stale[#stale+1]={w,event,fn} end
        for _,child in ipairs(w.children or {}) do visit(child) end
    end
    visit(parent);a:ReleaseConditionWidget(parent)
    local baseline=a:CopySettingsData(value)
    for _,entry in ipairs(stale) do entry[3](entry[1],entry[2]) end
    assert(a:SettingsDataEqual(value,baseline),'retired Fields UI/Help callback mutated saved sample')
    return count
end

test('current catalog and getters omit all seven retired GUI value dependencies',function()
    local f,a,lookups=fixture();assert(not f.libraries['AceGUI-3.0'],'fixture still exposes the retired GUI library')
    for _,path in ipairs(retired) do
        local id='builtin:'..path..':AceGUI';assert(not a.builtinFunctions[id],'retired GUI value remains in catalog: '..id)
        local value=a:ResolveFunctionBinding(id);assert(value==nil,'retired GUI value still resolves')
        local getter=a.builtinSourceModules[path];assert(not getter or getter('AceGUI')==nil,'retired GUI getter remains')
    end
    for path,module in pairs(a.BuiltinSourceCatalog.modules) do for alias,entry in pairs(module.bindings) do
        assert(alias~='AceGUI','forced GUI catalog binding remains: '..path)
        for _,id in pairs(entry.bindings or {}) do assert(not id:match(':AceGUI$'),'current helper still requires GUI: '..path..':'..alias) end
    end end
    assert(#lookups==0,'absence checks queried a forbidden GUI library')
end)
test('every actual branch source compiles current duplicates without an Ace binding or context dependency',function()
    local seen={}
    for _,case in ipairs(inventory.branches) do local _,a,lookups=fixture({case[1][1],case[1][2],case[1][3],case[3]})
        for tag,definition in pairs(a.conditionDefinitions) do
            local source=assert(a:GetBuiltinConditionSource(tag),tag);seen[tag]=true
            for alias,id in pairs(source.bindings) do assert(alias~='AceGUI' and not id:match(':AceGUI$'),tag..' retains an Ace binding') end
            local copy,why=a:CompileCustomCondition('NATIVE_COPY_'..tag,source);assert(copy,tag..': '..tostring(why and why.reason))
            for _,name in ipairs({'valid','evaluate','print','widget','help'}) do assert(type(copy[name])=='function',tag..'.'..name..' missing') end
        end
        assert(#lookups==0,'current source clone queried forbidden GUI')
    end
    local count=0;for _ in pairs(seen) do count=count+1 end;assert(count==126,'current source inventory unexpectedly narrowed: '..count)
end)
test('all BuiltIn and compiled duplicate Fields UI and Help execute native trees using valid samples across branches',function()
    local failures,seen={},{};local rendered=0
    for _,case in ipairs(inventory.branches) do local f,a,lookups=fixture({case[1][1],case[1][2],case[1][3],case[3]})
        for tag,definition in pairs(a.conditionDefinitions) do
            local ok,why=pcall(function()
                local value=sample(a,tag,definition);assert(definition.valid(0,value),'sample fails actual validator')
                local copy=assert(a:CompileCustomCondition('NATIVE_FIELDS_'..tag,assert(a:GetBuiltinConditionSource(tag))))
                assert(copy.valid(0,value),'copy sample fails actual validator')
                for _,current in ipairs({definition,copy}) do
                    if definition.widget then rendered=rendered+tree(a,current,a:CopySettingsData(value),'widget') end
                    rendered=rendered+tree(a,current,a:CopySettingsData(value),'help')
                end
                seen[tag]=true
            end)
            if not ok then failures[#failures+1]=case[1][1]..'/'..case[1][2]..'/'..case[1][3]..' '..tag..': '..tostring(why) end
        end
        assert(#lookups==0,'Fields UI/Help attempted forbidden GUI lookup')
    end
    assert(#failures==0,table.concat(failures,'\n'));local count=0;for _ in pairs(seen) do count=count+1 end;assert(count==126 and rendered>1000,'native render inventory narrowed')
end)
test('saved source bound to retired GUI values stays unchanged and is controlled unavailable before execution',function()
    local _,a,lookups=fixture();a.db.global.custom_conditions={};a.marker=0
    for index,path in ipairs(retired) do
        local source={description='Old GUI source',icon=a.Artwork.condition.COMBAT,fields={},bindings={AceGUI='builtin:'..path..':AceGUI'},valid='return true',evaluate='addon.marker=addon.marker+1; return true',widget='AceGUI:Create("Label")',help='',print='return "Old source"',on_register='addon.marker=addon.marker+100',on_unregister=''}
        local key='SAVED_GUI_'..index;a.db.global.custom_conditions[key]=source;local snapshot=a:CopySettingsData(source)
        local ok,compiled,problem=pcall(a.CompileCustomCondition,a,key,source)
        assert(ok,'old GUI source raised an uncontrolled compile error')
        if compiled then
            assert(type(compiled.functionUnavailable)=='string','retired dependency remained available')
            a:RegisterCondition(key,compiled)
            assert(a:evaluateConditionResult({type=key}).status=='unavailable' and a:evaluateConditionResult({type='NOT',value={type=key}}).status=='unavailable','retired source reached evaluation')
        else
            assert(type(problem)=='table' and problem.field=='bindings' and type(problem.reason)=='string','fixture failed outside binding availability')
        end
        assert(a.marker==0 and a.db.global.custom_conditions[key]==source and a:SettingsDataEqual(source,snapshot),'retired dependency executed or rewrote stored source')
    end
    assert(#lookups==0,'retired source resolution queried a GUI library')
end)
test('public native factory copies and the current group constructor execute without GUI dependencies',function()
    local _,a,lookups=fixture()
    local factories={
        {'UI/condition_layout.lua','CreateConditionGroup'}, {'UI/checkbox.lua','CreateConditionCheckBox'},
        {'UI/selector.lua','CreateConditionDropdown'}, {'UI/condition_inputs.lua','CreateConditionEditBox'},
        {'UI/condition_inputs.lua','CreateConditionSlider'}, {'UI/condition_icon.lua','CreateConditionIcon'},
        {'UI/condition_display.lua','CreateConditionLabel'}, {'UI/condition_display.lua','CreateConditionButton'},
        {'UI/condition_display.lua','CreateConditionLink'}, {'UI/condition_position.lua','CreateConditionPositionPad'},
    }
    for index,pair in ipairs(factories) do
        local id='builtin:'..pair[1]..':'..pair[2];local source=a:CopySettingsData(assert(a.builtinFunctions[id]).source)
        assert(a:InstallCustomFunction('NATIVE_FACTORY_'..index,source))
        local ok,widget=pcall(assert(a:ResolveFunctionBinding('NATIVE_FACTORY_'..index)),a)
        assert(ok,pair[2]..': '..tostring(widget))
        assert(a:IsConditionWidget(widget) and widget.rmWidget and widget.rmActive and widget.frame);a:ReleaseConditionWidget(widget)
    end
    local id='builtin:UI/condition_layout.lua:constructor';local source=a:CopySettingsData(assert(a.builtinFunctions[id]).source)
    for _,dependency in pairs(source.bindings) do assert(not dependency:match(':AceGUI$'),'current constructor source still captures GUI') end
    assert(a:InstallCustomFunction('NATIVE_GROUP_CONSTRUCTOR',source));local group=assert(a:ResolveFunctionBinding('NATIVE_GROUP_CONSTRUCTOR'))()
    assert(group.rmWidget and group.frame);if not group.rmActive then group:OnAcquire() end;a:ReleaseConditionWidget(group)
    id='builtin:Conditions/common.lua:Widget_UnitWidget';source=a:CopySettingsData(assert(a.builtinFunctions[id]).source)
    assert(a:InstallCustomFunction('NATIVE_UNIT_FACTORY',source));local value={unit='target'};local calls=0
    local unit=assert(a:ResolveFunctionBinding('NATIVE_UNIT_FACTORY'))(a,value,a.units,function() calls=calls+1 end)
    unit.configure();assert(unit:GetValue()=='target' and calls==0);unit:Fire('OnValueChanged','player');assert(value.unit=='player' and calls==1);a:ReleaseConditionWidget(unit)
    assert(#lookups==0,'current native factory source queried forbidden GUI')
end)
test('condition source context exposes native typed helpers and no retired GUI field',function()
    local f,a,lookups=fixture();f.load('Core/lua_symbols.lua')
    assert(a.AceGUI==nil and rawget(f.env,'AceGUI')==nil,'GUI field was added to native code context')
    local source=assert(a:GetBuiltinConditionSource('COMBAT'));local symbols=a:LuaContextSymbols({kind='condition',callback='widget',source=source})
    assert(symbols.parent and symbols.parent.type=='RMConditionGroup' and symbols['addon:CreateConditionGroup'])
    for _,path in ipairs(retired) do
        local old={fields={},bindings={AceGUI='builtin:'..path..':AceGUI'}}
        symbols=a:LuaContextSymbols({kind='condition',callback='help',source=old})
        assert(not symbols.AceGUI and not symbols['functions.AceGUI'],'retired GUI value remains a usable code-context field')
    end
    local spell=assert(a.builtinFunctions['builtin:Conditions/common.lua:Widget_SpellWidget']).source
    assert(spell.returns[1].type=='RMConditionGroup','native spell group still has a GUI-library return type')
    assert(#lookups==0,'source context queried forbidden GUI')
end)
finish()
