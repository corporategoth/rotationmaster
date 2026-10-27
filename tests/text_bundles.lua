-- Load-on-demand text (Locales/bundles.json, Core/text_bundles.lua, Data/text_bundle_index.lua).
--
-- A bundle is an add-on under Modules/ holding the English and the ten translations of text that nothing reads while
-- the game is loading. `L["English text"]` must read the same wherever the text lives, so this proves:
--   * a normal start loads no bundle (the saving is real), on every client family;
--   * a main-table key never loads one, and a bundle key loads exactly its own bundle, once;
--   * the index finds the owner of every bundle key and of no main key (the Lua hash agrees with tools/locales.py);
--   * in every language every bundle key reads as the translation its file holds, English where the file has none;
--   * a bundle that cannot load answers with the key (the English), is asked once, and breaks nothing;
--   * a key in no catalog is still reported as missing.
local passed,failed=0,0
local function test(name,fn)
    local ok,why=pcall(fn)
    if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(why)) end
end
local function read(path) local h=assert(io.open(path));local s=h:read('*a');h:close();return s end

local LOCALES={'deDE','esES','esMX','frFR','itIT','koKR','ptBR','ruRU','zhCN','zhTW'}
local bundles={}
for id,module in read('Locales/bundles.json'):gmatch('"id"%s*:%s*"([^"]+)"%s*,%s*"module"%s*:%s*"([^"]+)"') do bundles[#bundles+1]={id=id,module=module} end
assert(#bundles>=4,'Locales/bundles.json names fewer bundles than expected: '..#bundles)

-- The entries of one locale file, read without AceLocale's selection: key -> displayed text.
local function entries(path)
    local into={}
    local target=setmetatable({},{__newindex=function(_,k,v) into[k]=v==true and k or v end})
    local env=setmetatable({LibStub=function() return {NewLocale=function() return target end} end,NORMAL_FONT_COLOR_CODE='|cffffd200'},{__index=_G})
    local fn=assert(loadfile(path));setfenv(fn,env);fn('RotationMaster',{})
    return into
end
local function mainEnglish() return entries('Locales/enUS.lua') end
for _,bundle in ipairs(bundles) do bundle.english=entries('Modules/'..bundle.module..'/enUS.lua') end

-- The addon as the client loads the locale: libraries, locales.xml, then the index and loader the TOC lists after it.
-- `loads` records every add-on the game would be asked to load.
local function boot(client,options)
    options=options or {}
    local loads={}
    local env=setmetatable({GetLocale=function() return client end,NORMAL_FONT_COLOR_CODE='|cffffd200',
        geterrorhandler=function() return function(message) error(message,0) end end},{__index=_G})
    env._G=env
    local function load(path,...) local fn=assert(loadfile(path));setfenv(fn,env);return fn(...) end
    env.C_AddOns={LoadAddOn=options.loader or function(name)
        loads[#loads+1]=name
        local dir='Modules/'..name
        for line in io.lines(dir..'/'..name..'.toc') do
            local file=line:gsub('\r','')
            -- Only the text: a converter add-on also lists code that needs the whole client.
            if file:match('^%a%a%a%a%.lua$') then load(dir..'/'..file,name,{}) end
        end
        return true
    end}
    load('Libs/LibStub/LibStub.lua');load('Libs/AceLocale-3.0/AceLocale-3.0.lua');load('globals.lua')
    for file in read('locales.xml'):gmatch('<Script file="([^"]+)"') do load((file:gsub('\\','/')),'RotationMaster',{}) end
    local addon={}
    load('Data/text_bundle_index.lua','RotationMaster',addon);load('Core/text_bundles.lua','RotationMaster',addon)
    return env.LibStub('AceLocale-3.0'):GetLocale('RotationMaster'),addon,loads,env
end

local function idle(addon)
    for id,state in pairs(addon:GetTextBundleStates()) do if state~='idle' then return false,id..' is '..state end end
    return true
end

test('the index knows every bundle and owns exactly the keys the bundles hold',function()
    local L,addon=boot('enUS')
    local main=mainEnglish()
    local states=addon:GetTextBundleStates()
    for _,bundle in ipairs(bundles) do
        assert(states[bundle.id]=='idle',bundle.id..' is missing from Data/text_bundle_index.lua')
        local count=0
        for key in pairs(bundle.english) do
            count=count+1
            local owner=addon:GetTextBundleOf(key)
            assert(owner==bundle.id,('%q is owned by %s, not %s (rebuild with tools/locales.py index)'):format(key,tostring(owner),bundle.id))
            assert(main[key]==nil,('%q is in both the main catalog and %s'):format(key,bundle.id))
        end
        assert(count>0,bundle.id..' holds no text')
    end
    for key in pairs(main) do assert(addon:GetTextBundleOf(key)==nil,('main key %q is claimed by a bundle'):format(key)) end
    assert(idle(addon))
end)

test('a normal start asks for no bundle, and a main-table key never loads one',function()
    local L,addon,loads=boot('enUS')
    local main=mainEnglish()
    local checked=0
    for key,value in pairs(main) do
        assert(L[key]==value,('%q reads %q'):format(key,tostring(L[key])))
        checked=checked+1
        if checked>=400 then break end
    end
    assert(#loads==0,'reading main text loaded '..table.concat(loads,', '))
    assert(idle(addon))
end)

test('a bundle key loads exactly its own bundle, once, and reads as the English',function()
    for _,bundle in ipairs(bundles) do
        local L,addon,loads=boot('enUS')
        local key,value=next(bundle.english)
        assert(L[key]==value,('%q reads %q'):format(key,tostring(L[key])))
        assert(#loads==1 and loads[1]==bundle.module,bundle.id..' loaded '..table.concat(loads,', '))
        local states=addon:GetTextBundleStates()
        for id,state in pairs(states) do assert(state==(id==bundle.id and 'loaded' or 'idle'),id..' is '..state) end
        local again=next(bundle.english,key) or key
        assert(L[again]==bundle.english[again])
        assert(#loads==1,'the second read loaded '..table.concat(loads,', '))
        assert(addon:LoadTextBundle(bundle.id)==true)
        assert(#loads==1,'LoadTextBundle asked the client again')
    end
end)

test('every bundle key reads as its translation in every language, English where the file has none',function()
    for _,client in ipairs(LOCALES) do
        local L,addon,loads=boot(client)
        for _,bundle in ipairs(bundles) do
            local translated=entries('Modules/'..bundle.module..'/'..client..'.lua')
            for key,english in pairs(bundle.english) do
                local want=translated[key]
                if want==nil then want=english end
                local got=L[key]
                assert(got==want,('%s %q reads %q, the file holds %q'):format(client,key:sub(1,60),tostring(got):sub(1,60),tostring(want):sub(1,60)))
            end
        end
        assert(#loads==#bundles,client..' loaded '..#loads..' bundles for '..#bundles)
    end
end)

test('a bundle that cannot load answers with the key and is asked only once',function()
    local calls=0
    local L,addon=boot('deDE',{loader=function() calls=calls+1;return false,'DISABLED' end})
    local first,second
    for _,bundle in ipairs(bundles) do if bundle.id=='help' then
        first=next(bundle.english);second=next(bundle.english,first)
    end end
    assert(first and second,'the help bundle needs two keys')
    assert(L[first]==first and L[second]==second,'a bundle that cannot load must answer with the English key')
    assert(calls==1,'the client was asked '..calls..' times')
    assert(addon:GetTextBundleStates().help=='failed')
    assert(addon:LoadTextBundle('help')==false)
    assert(select(2,addon:LoadTextBundle('nope'))=='unknown-bundle')
    assert(L['Enabled']~=nil,'main text still reads')
end)

test('a bundle loader that throws is contained: the read answers with the key and the bundle is not asked again',function()
    local calls=0
    local L,addon=boot('deDE',{loader=function() calls=calls+1;error('loader exploded') end})
    local first
    for _,bundle in ipairs(bundles) do if bundle.id=='help' then first=next(bundle.english) end end
    assert(first,'the help bundle needs a key')
    local ok,value=pcall(function() return L[first] end)
    assert(ok,'a throwing loader escaped an L read: '..tostring(value))
    assert(value==first,'a bundle that threw must answer with the English key')
    assert(L[first]==first and calls==1,'the loader was asked '..calls..' times')
    assert(addon:GetTextBundleStates().help=='failed' and addon:LoadTextBundle('help')==false)
    assert(L['Enabled']~=nil,'main text still reads')
end)

test('a key in no catalog is still reported as missing and loads nothing',function()
    local L,addon,loads=boot('enUS')
    local ok,message=pcall(function() return L['No such text anywhere in Rotation Master'] end)
    assert(not ok and tostring(message):find('Missing entry',1,true),'a missing key went unreported: '..tostring(message))
    assert(#loads==0 and idle(addon))
end)

test('a normal start loads no bundle on any client family',function()
    local T=dofile('tests/fixtures/toc_addon.lua')
    local configs={
        {name='Retail',project=1,class='MONK'},
        {name='Burning Crusade',project=5,expansion=1,class='SHAMAN',level=70},
    }
    for _,config in ipairs(configs) do
        local f=T.new(config)
        for _,e in ipairs(f.loadErrors) do assert(e:match('^Libs/'),config.name..': addon file failed to load: '..e) end
        local addon=f.addon
        assert(type(addon.GetTextBundleStates)=='function',config.name..': Core/text_bundles.lua did not load')
        for _,bundle in ipairs(bundles) do
            assert(not f.env.C_AddOns.IsAddOnLoaded(bundle.module),config.name..' loaded '..bundle.module..' while starting')
        end
        assert(idle(addon))
        -- Reading one of its keys now loads the add-on through the client's own loader.
        local L=f.env.LibStub('AceLocale-3.0'):GetLocale('rotationmaster')
        local bundle=bundles[1]
        local key,value=next(bundle.english)
        assert(L[key]==value)
        assert(f.env.C_AddOns.IsAddOnLoaded(bundle.module),config.name..': '..bundle.module..' did not load on first read')
        assert(addon:GetTextBundleStates()[bundle.id]=='loaded')
    end
end)

print(passed..' passed, '..failed..' failed')
if failed>0 then os.exit(1) end
