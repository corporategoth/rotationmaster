local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local inventory=dofile('tests/fixtures/catalog_inventory.lua')
local validateDeclarations=dofile('tests/fixtures/declarations.lua')
for _,case in ipairs(inventory.branches) do
    local branch=case[1]
    test('registered catalog/help/category branch '..table.concat(branch,'/')..(case[3] and '/MobInfo' or ''),function()
        local f=F.new(unpack(branch))
        if case[3] then f.env.MI2_GetMobData=function() error('catalog must not query MobInfo runtime data') end end
        f.addon.delayed_condition={}
        f.load('init.lua')
        local defaults={char={},global={},profile={}}
        f.addon:augmentDefaults(defaults)
        -- Creation additions are deliberately outside recursive AceDB defaults.
        f.addon:InitializeTalentTreeConditions(nil,{profile=defaults.profile})
        f.load('Core/unit_state_conditions.lua')
        f.addon:InitializeUnitStateConditions(nil,{profile=defaults.profile})
        local categories={}
        for _,group in ipairs(defaults.profile.condition_groups) do
            for _,tag in ipairs(group.conditions) do categories[tag]=true end
        end
        for _,tag in ipairs(defaults.profile.switch_conditions) do categories[tag]=true end
        for _,tag in ipairs(defaults.profile.other_conditions_order) do categories[tag]=true end
        for line in io.lines('RotationMaster.toc') do
            if line:match('^Conditions/') then f.load(line) end
        end
        local expected={}
        for tag in (inventory.common..' '..case[2]):gmatch('%S+') do expected[tag]=true end
        for tag,definition in pairs(f.addon.definitions) do
            assert(expected[tag],tag..' unexpectedly registered; review branch inventory')
            expected[tag]=nil
            assert(type(definition.description)=='string' and #definition.description>0,tag..' description')
            assert(type(definition.fields)=='table',tag..' fields')
            local ok,reason,path=validateDeclarations(definition.fields)
            assert(ok,tag..' '..tostring(path)..' '..tostring(reason))
            for _,method in ipairs({'valid','evaluate','print','help'}) do
                assert(type(definition[method])=='function',tag..' missing '..method)
            end
            assert(categories[tag],tag..' uncategorized')
            local frame=f.widget('Frame')
            definition.help(frame)
            assert(#frame.children>0,tag..' empty help')
        end
        for tag in pairs(expected) do error(tag..' missing from registered branch') end
        local delayedExpected={ECS_STAT=true,ECS_STAT_PCT=true}
        for provider,definitions in pairs(f.addon.delayed_condition) do
            assert(provider=='ExtendedCharacterStats','unexpected deferred provider')
            for tag,definition in pairs(definitions) do
                assert(delayedExpected[tag],tag..' unexpected deferred condition')
                delayedExpected[tag]=nil
                assert(categories[tag],tag..' uncategorized deferred condition')
                local ok,reason,path=validateDeclarations(definition.fields)
                assert(ok,tag..' '..tostring(path)..' '..tostring(reason))
                local frame=f.widget('Frame');definition.help(frame)
                assert(#F.text(frame)>30,tag..' empty deferred help')
            end
        end
        for tag in pairs(delayedExpected) do error(tag..' missing deferred definition') end
    end)
end
finish()
