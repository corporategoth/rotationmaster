local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local restoreStat=dofile('tests/fixtures/restore_unit_stat_repairs.lua')
local baseline={
    buffs={["allcounts"]={["compareString"]=2,["deepcopy"]=1,["isin"]=6,["nullable"]=6,["playerize"]=2},["count"]=1,["counts"]={["deepcopy"]=1},["hashes"]={["BUFF"]=2290721974,["BUFF_REMAIN"]=385400309,["BUFF_STACKS"]=832467388,["STEALABLE"]=2149712789},["tags"]={["STEALABLE"]={["deepcopy"]=1}}},
    debuffs={["allcounts"]={["compareString"]=2,["isin"]=7,["keys"]=1,["nullable"]=7,["playerize"]=3},["count"]=1,["counts"]={["keys"]=1},["hashes"]={["DEBUFF"]=2337578661,["DEBUFF_REMAIN"]=172345129,["DEBUFF_STACKS"]=3832970224,["DISPELLABLE"]=2640440305},["tags"]={["DISPELLABLE"]={["keys"]=1}}},
    combat={["allcounts"]={["compare"]=6,["compareString"]=6,["deepcopy"]=5,["getCached"]=20,["isin"]=16,["keys"]=2,["nullable"]=20,["playerize"]=3},["count"]=7,["counts"]={["deepcopy"]=5,["keys"]=2},["hashes"]={["ATTACKABLE"]=1928276375,["COMBAT"]=1202331544,["COMBAT_HISTORY"]=3763389623,["COMBAT_HISTORY_TIME"]=912051754,["ENEMY"]=711004892,["FORM"]=1792978542,["INCONTROL"]=3736633212,["LOC_BLOCKED"]=2748025722,["LOC_TYPE"]=3529158107,["MOVING"]=1981052209,["PET"]=3286003977,["PET_NAME"]=3299158844,["STEALTHED"]=1067412973,["THREAT"]=82443761,["THREAT_COUNT"]=279254831,["TIME_IN_COMBAT"]=4185516284},["tags"]={["ATTACKABLE"]={["deepcopy"]=1},["COMBAT_HISTORY"]={["deepcopy"]=1,["keys"]=1},["COMBAT_HISTORY_TIME"]={["deepcopy"]=1,["keys"]=1},["ENEMY"]={["deepcopy"]=1},["THREAT"]={["deepcopy"]=1}}},
    talent={["allcounts"]={["compare"]=2,["compareString"]=2,["getCached"]=4,["isin"]=2,["nullable"]=2},["count"]=4,["counts"]={["getCached"]=4},["hashes"]={["PRIMARY_TALENT_TREE"]=2033236142,["TALENT"]=3510184698,["TALENT_TREE_POINTS"]=1725504698},["tags"]={["PRIMARY_TALENT_TREE"]={["getCached"]=1},["TALENT"]={["getCached"]=2},["TALENT_TREE_POINTS"]={["getCached"]=1}}},
    totem={["allcounts"]={["compare"]=1,["compareString"]=2,["keys"]=2,["nullable"]=6},["count"]=2,["counts"]={["keys"]=2},["hashes"]={["TOTEM"]=2948302599,["TOTEM_REMAIN"]=561548570,["TOTEM_SPELL"]=1619102701,["TOTEM_SPELL_REMAIN"]=4057426927},["tags"]={["TOTEM"]={["keys"]=1},["TOTEM_REMAIN"]={["keys"]=1}}},
    weapon={["allcounts"]={["compare"]=5,["compareString"]=4,["getCached"]=2,["isin"]=4,["nullable"]=4},["count"]=2,["counts"]={["getCached"]=2},["hashes"]={["SWING_TIME"]=2530301861,["SWING_TIME_REMAIN"]=2763838606,["WEAPON"]=1621917187,["WEAPON_REMAIN"]=3460887186,["WEAPON_STACKS"]=493277911},["tags"]={["SWING_TIME_REMAIN"]={["getCached"]=2}}},
    spatial={["allcounts"]={["compare"]=2,["compareString"]=2,["getCached"]=5,["isin"]=4,["nullable"]=8,["playerize"]=2},["count"]=9,["counts"]={["compare"]=1,["getCached"]=5,["isin"]=3},["hashes"]={["DISTANCE"]=2475258908,["DISTANCE_COUNT"]=2142936204,["PROXIMITY"]=145759557,["ZONE"]=1804004460},["tags"]={["DISTANCE"]={["getCached"]=1,["isin"]=1},["DISTANCE_COUNT"]={["getCached"]=2},["PROXIMITY"]={["compare"]=1,["isin"]=2},["ZONE"]={["getCached"]=2}}},
    ext_stats={["allcounts"]={["compare"]=3,["compareString"]=3,["deepcopy"]=1,["getCached"]=5,["isin"]=7,["keys"]=2,["nullable"]=4,["nullable_value"]=3},["count"]=28,["counts"]={["compare"]=3,["compareString"]=3,["deepcopy"]=1,["getCached"]=5,["isin"]=7,["keys"]=2,["nullable"]=4,["nullable_value"]=3},["hashes"]={["ECS_STAT"]=218257749,["ECS_STAT_PCT"]=3618672851,["STAT"]=400887984},["tags"]={["ECS_STAT"]={["compare"]=1,["compareString"]=1,["getCached"]=1,["isin"]=2,["keys"]=1,["nullable"]=1,["nullable_value"]=1},["ECS_STAT_PCT"]={["compare"]=1,["compareString"]=1,["getCached"]=1,["isin"]=2,["keys"]=1,["nullable"]=1,["nullable_value"]=1},["STAT"]={["compare"]=1,["compareString"]=1,["deepcopy"]=1,["getCached"]=3,["isin"]=3,["nullable"]=2,["nullable_value"]=1}}},
}
local privateHashes={
    ["builtin:Conditions/buffs.lua:color"]="89c33f24",
    ["builtin:Conditions/buffs.lua:helpers"]="e55d7b5a",
    ["builtin:Conditions/combat.lua:character_class"]="d17cf4c1",
    ["builtin:Conditions/combat.lua:color"]="dbda383d",
    ["builtin:Conditions/combat.lua:helpers"]="9e28e933",
    ["builtin:Conditions/debuffs.lua:color"]="cd0b6691",
    ["builtin:Conditions/debuffs.lua:helpers"]="785d08c7",
    ["builtin:Conditions/ext_stats.lua:color"]="bcd5d295",
    ["builtin:Conditions/ext_stats.lua:ecs_state"]="f87297b5",
    ["builtin:Conditions/ext_stats.lua:helpers"]="8c6f9acb",
    ["builtin:Conditions/spatial.lua:RangeCheck"]="272f05e0",
    ["builtin:Conditions/spatial.lua:booleanRead"]="3b3ceeb2",
    ["builtin:Conditions/spatial.lua:color"]="158ebd8f",
    ["builtin:Conditions/spatial.lua:finite"]="9e1e3ece",
    ["builtin:Conditions/spatial.lua:helpers"]="9485f785",
    ["builtin:Conditions/spatial.lua:protectedRead"]="cc49d134",
    ["builtin:Conditions/spatial.lua:rcf"]="a7ab75e4",
    ["builtin:Conditions/talent.lua:dropdown"]="fc359881",
    ["builtin:Conditions/talent.lua:gridWidget"]="d47802ad",
    ["builtin:Conditions/talent.lua:group"]="d6f4e415",
    ["builtin:Conditions/talent.lua:icon"]="957b6b1a",
    ["builtin:Conditions/talent.lua:info"]="c0972f2d",
    ["builtin:Conditions/talent.lua:integer"]="e1bd3b0e",
    ["builtin:Conditions/talent.lua:legacySlot"]="b8bfb514",
    ["builtin:Conditions/talent.lua:platform"]="7a51cfaa",
    ["builtin:Conditions/talent.lua:text"]="6cd18802",
    ["builtin:Conditions/talent.lua:treeExists"]="85703f5a",
    ["builtin:Conditions/talent.lua:treeName"]="19de3afd",
    ["builtin:Conditions/talent.lua:treePicker"]="8071735e",
    ["builtin:Conditions/talent.lua:treeShape"]="f0ba2bf9",
    ["builtin:Conditions/talent.lua:treeWidget"]="4d2ca794",
    ["builtin:Conditions/totem.lua:amount"]="3bd67a6b",
    ["builtin:Conditions/totem.lua:color"]="b1a3d66a",
    ["builtin:Conditions/totem.lua:element"]="5fbfedcc",
    ["builtin:Conditions/totem.lua:findSpecific"]="f753db9d",
    ["builtin:Conditions/totem.lua:helpers"]="f15cbb60",
    ["builtin:Conditions/totem.lua:observe"]="e59e23eb",
    ["builtin:Conditions/totem.lua:platform"]="c9ee8d33",
    ["builtin:Conditions/totem.lua:remaining"]="b96f5341",
    ["builtin:Conditions/totem.lua:specific"]="fdeca8ba",
    ["builtin:Conditions/weapon.lua:color"]="63742be5",
    ["builtin:Conditions/weapon.lua:enchantObservation"]="e5464f90",
    ["builtin:Conditions/weapon.lua:helpers"]="e831a1db",
    ["builtin:Conditions/weapon.lua:numericObservation"]="02dee6a9",
    ["builtin:Conditions/weapon.lua:swingSpeed"]="56aa868b",
}

local owners={isin='values',compare='values',nullable='presentation',nullable_value='presentation',compareString='presentation',playerize='presentation',getCached='cache',deepcopy='collections',keys='collections'}
local function path(name) return 'Functions.'..owners[name]..'.'..name end
local function identity(name) return 'builtin:'..(owners[name]=='collections' and 'Functions/collections.lua' or 'utils.lua')..':'..name end
local function fixture(case)
    local f=F.new(unpack(case and case[1] or {}));local a,e=f.addon,f.env
    local s={calls={},imports=0,stat=42,pct='12.5%',cast=nil,channel=nil}
    local function called(name) s.calls[name]=(s.calls[name] or 0)+1 end
    e.UnitExists=function() called('exists');return true end;e.UnitStat=function() called('stat');return 7,s.stat,nil,'tail' end;e.UnitArmor=function() called('armor');return 7,s.stat end
    e.GetZoneText=function() called('zone');return 'Fixture Zone' end;e.GetSubZoneText=function() called('subzone');return 'Fixture Subzone' end
    e.UnitAttackSpeed=function() called('speed');return 3,2 end;e.UnitCastingInfo=function() called('cast');return s.cast end;e.UnitChannelInfo=function() called('channel');return s.channel end
    e.GetNumTalentTabs=function() return 3 end;e.GetNumTalents=function() return 1 end
    e.C_SpecializationInfo={GetSpecializationInfo=function(tree) called('tree');return tree,'Tree '..tree,'',1,nil,nil,tree==2 and 20 or 5 end,
        GetTalentInfo=function() called('talent');return {name='Fixture Talent',icon=1,rank=2,maxRank=5,talentID=1,spellID=123,tier=1,column=1} end}
    local data={};data.GetStatInfo=function(...) assert(select('#',...)==1,'ECS GetStatInfo received a receiver');local key=...;assert(type(key)=='string','ECS refName must be a string');called('ecs');return key=='power' and s.stat or key=='chance' and s.pct end
    e.ECSLoader={ImportModule=function(_,name) assert(name=='Data');s.imports=s.imports+1;return data end}
    e.ExtendedCharacterStats={profile={refName='power',text='Power',child={refName='chance',text='Chance'}}}
    a.delayed_condition={};a.lastMainSwing=98;a.lastOffSwing=99
    for _,file in ipairs({'Platform/spells.lua','Platform/talents.lua','Platform/range.lua','Core/conditions.lua','Conditions/common.lua','Conditions/buffs.lua','Conditions/debuffs.lua','Conditions/combat.lua','Conditions/talent.lua','Conditions/totem.lua','Conditions/weapon.lua','Conditions/spatial.lua','Conditions/ext_stats.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(file) end
    for tag,definition in pairs(a.delayed_condition.ExtendedCharacterStats) do a:RegisterCondition(tag,definition) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,s
end
local function legacy(a,source,tag)
    local result=a:CopySettingsData(source)
    if tag=='STAT' then result.evaluate=restoreStat(result.evaluate,true) end
    for callback in pairs(a.CustomConditionCallbacks) do if result[callback] then for name in pairs(owners) do result[callback]=result[callback]:gsub(path(name):gsub('%.','%%.')..'([%(,])','addon.'..name..'%1') end end end
    for name in pairs(owners) do result.bindings[path(name)]=nil end
    return result
end
local function copies(a,tag)
    local source=assert(a:GetBuiltinConditionSource(tag));local canonical=assert(a:CompileCustomCondition('COPY_'..tag,source));local old=assert(a:CompileCustomCondition('OLD_'..tag,legacy(a,source,tag)));a:RegisterCondition('COPY_'..tag,canonical);a:RegisterCondition('OLD_'..tag,old);return canonical,old
end
local function count(code,pattern) local _,n=code:gsub(pattern,'');return n end
test('remaining fifty-four direct calls qualify actual owning leaves with no extra callback aliases',function()
    local f,a=fixture();local changed=0
    for module,record in pairs(baseline) do local declared=assert(a.builtinCallbackBindings and a.builtinCallbackBindings['Conditions/'..module..'.lua'],'missing canonical manifest '..module);changed=changed+record.count
        for name in pairs(record.allcounts) do assert(declared[path(name)]==identity(name) and a:ResolveFunctionBinding(identity(name))==a.Functions[owners[name]][name]) end
        local totals={};for tag in pairs(record.hashes) do local source=assert(a:GetBuiltinConditionSource(tag));assert(not source.bindings.Functions)
            if (module=='buffs'and tag~='STEALABLE')or(module=='debuffs'and tag~='DISPELLABLE')then source=dofile('tests/fixtures/restore_aura_name_summary_literals.lua')(source,tag,'export')end
            if tag=='ECS_STAT' or tag=='ECS_STAT_PCT' then source=dofile('tests/fixtures/restore_ecs_summary_literals.lua')(source,tag,'export')end
            if tag=='STAT' then source.evaluate=restoreStat(source.evaluate,true) end
            if tag=='ZONE' then source.evaluate=dofile('tests/fixtures/restore_zone_text_repairs.lua')(source.evaluate,true) end
            if tag=='COMBAT_HISTORY_TIME' then source.evaluate=dofile('tests/fixtures/restore_combat_history_time_repairs.lua')(source.evaluate,true) end
            for callback in pairs(a.CustomConditionCallbacks) do if source[callback] then for name in pairs(owners) do
                assert(not source[callback]:find('addon.'..name..'(',1,true),tag..' direct legacy '..name..' remains')
                totals[name]=(totals[name] or 0)+count(source[callback],path(name):gsub('%.','%%.')..'%(')
            end end end
        end
        for name in pairs(owners) do
            local expectedCount=record.allcounts[name] or 0
            -- ATTACKABLE and THREAT each save two raw queries; COMBAT/ENEMY each save one.
            if module=='combat' and name=='getCached' then expectedCount=expectedCount-6 end
            assert((totals[name] or 0)==expectedCount,module..' '..name..' count changed')
        end
    end
    assert(changed==54 and not f.env.Functions)
end)
test('every callback byte and parameter remains identical after reversing only namespace qualifiers',function()
    local _,a=fixture();local callbacks={};for name in pairs(a.CustomConditionCallbacks) do callbacks[#callbacks+1]=name end;table.sort(callbacks)
    for module,record in pairs(baseline) do for tag,hash in pairs(record.hashes) do local current=a:GetBuiltinConditionSource(tag)
        if (module=='buffs'and tag~='STEALABLE')or(module=='debuffs'and tag~='DISPELLABLE')then current=dofile('tests/fixtures/restore_aura_name_summary_literals.lua')(current,tag,'export')end
        if tag=='ECS_STAT' or tag=='ECS_STAT_PCT' then current=dofile('tests/fixtures/restore_ecs_summary_literals.lua')(current,tag,'export')end
        if tag=='THREAT_COUNT' then
            local restored,_,_,bindings,parameters=dofile('tests/fixtures/restore_threat_count_repairs.lua')(current.evaluate,true)
            current.evaluate=restored;current.bindings=a:CopySettingsData(bindings);current.parameters.evaluate=a:CopySettingsData(parameters)
        end
        if tag=='COMBAT_HISTORY_TIME' then current.evaluate=dofile('tests/fixtures/restore_combat_history_time_repairs.lua')(current.evaluate,true) end
        if tag=='TIME_IN_COMBAT' then current.evaluate=dofile('tests/fixtures/restore_combat_time_repairs.lua')(current.evaluate,true) end
        if tag=='FORM' then current.evaluate=dofile('tests/fixtures/restore_form_repairs.lua')(current.evaluate,tag) end
        if tag=='LOC_TYPE' or tag=='LOC_BLOCKED' then current.evaluate=dofile('tests/fixtures/restore_loss_of_control_repairs.lua')(current.evaluate,tag) end
        if tag=='TOTEM_REMAIN' then current.evaluate=dofile('tests/fixtures/restore_rounding_qualifiers.lua')(current.evaluate,tag,true) end
        if tag=='THREAT' then current.evaluate=dofile('tests/fixtures/restore_threat_repairs.lua')(current.evaluate,true) end
        if tag=='PET_NAME' then current=dofile('tests/fixtures/restore_pet_name_summary_literals.lua')(current,'export') end
        if tag=='PET' or tag=='PET_NAME' then current.evaluate=dofile('tests/fixtures/restore_pet_repairs.lua')(current.evaluate,tag) end
        if tag=='FORM' then for _,name in ipairs({'print','widget'}) do current[name]=dofile('tests/fixtures/restore_form_presentation_repairs.lua')(dofile('tests/fixtures/restore_form_localization.lua')(current[name],name),name) end end
        if tag=='ECS_STAT_PCT' then current.evaluate=dofile('tests/fixtures/restore_ecs_percentage_sign.lua')(current.evaluate,true) end
        if tag=='PROXIMITY' then current.print=dofile('tests/fixtures/restore_proximity_summary_repairs.lua')(current.print,true) end
        if tag=='ZONE' then current=dofile('tests/fixtures/restore_zone_cast_summary_literals.lua')(current,tag,'export') end
        if tag=='ZONE' then current.evaluate=dofile('tests/fixtures/restore_zone_text_repairs.lua')(current.evaluate,true) end
        if tag=='DISTANCE' then current.evaluate=dofile('tests/fixtures/restore_distance_presence.lua')(current.evaluate,true) end
        if tag=='SWING_TIME_REMAIN' then current.evaluate=dofile('tests/fixtures/restore_swing_countdown.lua')(current.evaluate,true) end
        local source=legacy(a,current,tag);local parts={}
        -- Separate ECS API regression tests require the corrected dot contract.
        -- Reverse only those explicit semantic fixes for this namespace-only byte proof.
        if tag=='ECS_STAT' or tag=='ECS_STAT_PCT' then
            source.on_register=source.on_register:gsub('ecs_state%.data%.GetStatInfo%(name%)','ecs_state.data:GetStatInfo(name)')
            source.evaluate=source.evaluate:gsub('ecs_state%.data%.GetStatInfo, value%.stat','ecs_state.data.GetStatInfo, ecs_state.data, value.stat')
        end
        if tag=='COMBAT' or tag=='ENEMY' then
            local kind=tag=='COMBAT' and 'combat' or 'enemy'
            assert(source.evaluate=='\n        return addon.getCached(cache, addon.Platform.GetUnitFlagObservation, addon.Platform, value.unit, "'..kind..'")\n    ','unexpected unit flag evaluator repair')
            local arguments=tag=='COMBAT' and 'UnitAffectingCombat, value.unit' or 'UnitIsEnemy, "player", value.unit'
            source.evaluate='\n        if not addon.getCached(cache, UnitExists, value.unit) then return false end\n        return addon.getCached(cache, '..arguments..')\n    '
        end
        if tag=='STEALTHED' or tag=='INCONTROL' then
            local kind=tag=='STEALTHED' and 'stealthed' or 'control'
            assert(source.evaluate=='\n        return addon.getCached(cache, addon.Platform.GetPlayerFlagObservation, addon.Platform, \"'..kind..'\")\n    ','unexpected player flag evaluator repair')
            source.evaluate='\n        return addon.getCached(cache, '..(tag=='STEALTHED' and 'IsStealthed' or 'HasFullControl')..')\n    '
        end
        -- The movement readiness suite separately pins this sole semantic body
        -- repair and reverses it against the entire original combat module.
        if tag=='MOVING' then
            assert(source.evaluate=='\n        local record,reason=addon.getCached(cache,addon.Platform.GetPlayerMovementObservation,addon.Platform)\n        if not record then return nil,reason end\n        return record.speed~=0\n    ','unexpected MOVING evaluator repair')
            source.evaluate='\n        return (addon.getCached(cache, GetUnitSpeed, "player") ~= 0)\n    '
        end
        if tag=='ATTACKABLE' then
            assert(source.evaluate=='\n        return addon.getCached(cache, addon.Platform.GetUnitAttackabilityObservation, addon.Platform, value.unit)\n    ','unexpected ATTACKABLE evaluator repair')
            source.evaluate='\n        if not addon.getCached(cache, UnitExists, value.unit) then return false end\n        return addon.getCached(cache, UnitCanAttack, "player", value.unit) and\n               not addon.getCached(cache, UnitIsDead, value.unit)\n    '
        end
        for _,callback in ipairs(callbacks) do if source.parameters[callback] then parts[#parts+1]=callback;parts[#parts+1]=table.concat(source.parameters[callback],',');parts[#parts+1]=source[callback] end end
        local code=table.concat(parts,'\0');local first,second=1,0;for i=1,#code do first=(first+code:byte(i))%65521;second=(second+first)%65521 end
        assert(second*65536+first==hash,module..' '..tag..' changed beyond namespaces')
    end end
end)
test('all forty-five remaining captured source identities and private helper bodies remain exact',function()
    local _,a=fixture()
    for id,hash in pairs(privateHashes) do local record=assert(a.builtinFunctions[id]);assert(a:FunctionSourceHash(record.source)==hash,'private source changed '..id)
        local module,name=id:match('^builtin:(.+):([^:]+)$');assert(a:ResolveFunctionBinding(id)==a.builtinSourceModules[module](name))
    end
    assert(a.builtinFunctions['builtin:Conditions/totem.lua:observe'].source.code:find('addon.getCached(',1,true))
    assert(a.builtinFunctions['builtin:Conditions/weapon.lua:enchantObservation'].source.code:find('pcall(addon.getCached',1,true))
    assert(a.builtinFunctions['builtin:Conditions/spatial.lua:protectedRead'].source.code:find('pcall(addon.getCached',1,true))
end)
test('all actual inventory branches retain compilable canonical and legacy-shaped registered copies',function()
    for _,case in ipairs(dofile('tests/fixtures/catalog_inventory.lua').branches) do local _,a=fixture(case)
        for _,record in pairs(baseline) do for tag in pairs(record.hashes) do if a.conditionDefinitions[tag] then local source=a:GetBuiltinConditionSource(tag);local canonical,old=copies(a,tag);assert(a:SettingsDataEqual(source.fields,canonical.fields) and a:SettingsDataEqual(source.fields,old.fields)) end end end
    end
end)
test('native stat and deferred ECS copies retain corrected dot API shared cache and summaries',function()
    local _,a,s=fixture();assert(s.imports==1)
    for _,tag in ipairs({'STAT','ECS_STAT','ECS_STAT_PCT'}) do local canonical,old=copies(a,tag);assert(s.imports==1,'cloned callback lost shared deferred initialization')
        local v={type=tag,unit='player',stat=tag=='STAT' and 1 or tag=='ECS_STAT' and 'power' or 'chance',operator='EQUALS',value=tag=='ECS_STAT_PCT' and 0.125 or 42};local cache={}
        assert(a.conditionDefinitions[tag].evaluate(v,cache)==true);local before=a:CopySettingsData(s.calls)
        -- Archived STAT keeps native-function cache keys; its distinct first
        -- observation is warmed before checking repeated-call cache stability.
        if tag=='STAT' then assert(old.evaluate(v,cache)==true);before=a:CopySettingsData(s.calls) end
        assert(canonical.evaluate(v,cache)==true and old.evaluate(v,cache)==true and a:SettingsDataEqual(before,s.calls))
        assert(a.conditionDefinitions[tag].valid(0,v)==canonical.valid(0,v) and canonical.valid(0,v)==old.valid(0,v))
        for _,negated in ipairs({false,true}) do local text=a.conditionDefinitions[tag].print(0,v,negated);assert(text==canonical.print(0,v,negated) and text==old.print(0,v,negated)) end
    end
    s.stat=57;assert(a.conditionDefinitions.COPY_ECS_STAT.evaluate({stat='power',operator='EQUALS',value=57},{})==true)
end)
test('collection widget callbacks preserve filtered units ordered lists and supplied native field values',function()
    local f,a=fixture();local before=a:CopySettingsData(a.units)
    local function render(definition,value)
        local parent=f.widget('Group');local top=f.widget('Top');top:SetUserData('root',value);top:SetUserData('funcs',{print=function() return 'summary' end});parent:SetUserData('top',top);definition.widget(parent,0,value)
        local function snapshot(widget)
            if widget.configure then widget.configure() end
            local result={kind=widget.kind or widget.type,value=widget.value,list=widget.list and a:CopySettingsData(widget.list),order=widget.order and a:CopySettingsData(widget.order),children={}}
            for _,child in ipairs(widget.children or {}) do result.children[#result.children+1]=snapshot(child) end;return result
        end
        local result=snapshot(parent);for _,child in ipairs(parent.children) do if child.rmWidget then a:ReleaseConditionWidget(child) end end;return result
    end
    for _,tag in ipairs({'STEALABLE','DISPELLABLE','ATTACKABLE','ENEMY','THREAT','COMBAT_HISTORY','COMBAT_HISTORY_TIME','TOTEM','TOTEM_REMAIN','STAT','ECS_STAT','ECS_STAT_PCT'}) do
        local canonical,old=copies(a,tag);local value={unit='target',value=3,operator='EQUALS',action='WOUND',spell=2,threat=3,stat=tag=='STAT' and 1 or tag=='ECS_STAT' and 'power' or 'chance',debufftype='Magic',distance=10}
        local original=render(a.conditionDefinitions[tag],value);assert(a:SettingsDataEqual(original,render(canonical,value)) and a:SettingsDataEqual(original,render(old,value)),tag..' field configuration changed')
        if tag=='STAT' then assert(original.children[1].list.player~=nil and original.children[1].list.pet~=nil and original.children[1].list.target==nil,'include-only deepcopy semantics changed') end
        if tag=='STEALABLE' then assert(original.children[1].list.player==nil and original.children[1].list.pet==nil,'exclude deepcopy semantics changed') end
    end
    assert(a:SettingsDataEqual(before,a.units),'callback mutated shared unit choices')
end)
test('swing cast nil tuples and zone branches preserve exact callback cache behavior',function()
    local _,a,s=fixture()
    for _,tag in ipairs({'SWING_TIME_REMAIN','ZONE'}) do local canonical,old=copies(a,tag);local v=tag=='ZONE' and {value='Fixture Zone'} or {operator='EQUALS',value=1};local cache={}
        local result=a.conditionDefinitions[tag].evaluate(v,cache,100);local before=a:CopySettingsData(s.calls);assert(canonical.evaluate(v,cache,100)==result and old.evaluate(v,cache,100)==result and a:SettingsDataEqual(before,s.calls))
    end
    assert(s.calls.cast==1 and s.calls.channel==1 and s.calls.zone==1);s.cast='Casting';assert(a.conditionDefinitions.COPY_SWING_TIME_REMAIN.evaluate({operator='EQUALS',value=3},{},100))
    assert(a.conditionDefinitions.COPY_ZONE.evaluate({value='Fixture Subzone',subzone=true},{})==true)
end)
finish()
