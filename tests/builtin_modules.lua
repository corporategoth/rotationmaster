-- Built In packs ship as one load-on-demand addon per class (Modules/RotationMaster_<Class>)
-- with one client-flavour TOC per edition. Startup asks the client for exactly this
-- character's class module; the modeled client picks the TOC as WoW does (its game type's
-- suffix, then its family's, then the unsuffixed fallback, per Warcraft Wiki "TOC format")
-- and runs those files with the module's own name and a fresh namespace. Packs reach Rotation
-- Master through bind.lua. A module that cannot load leaves Rotation Master working with no
-- Built Ins and one message.
local corpus=dofile('tests/fixtures/default_corpus.lua')
local modules=dofile('tools/builtin_modules.lua')
local pass,fail=0,0
local function test(name,fn)local ok,err=pcall(fn);if ok then pass=pass+1;print('PASS '..name)else fail=fail+1;print('FAIL '..name..': '..tostring(err))end end

-- TOC suffixes each modeled client accepts, best first (fixture project IDs).
local SUFFIXES={[5]={'TBC','Classic'},[18]={'Camelot','Forever','Mainline'},[1]={'Standard','Mainline'},
    [2]={'Vanilla','Classic'},[19]={'Mists','Classic'}}
local function readable(path)local file=io.open(path,'r');if file then file:close();return true end;return false end
local function chooseTOC(name,project)
    local dir='Modules/'..name
    for _,suffix in ipairs(SUFFIXES[project] or {})do
        local toc=dir..'/'..name..'_'..suffix..'.toc';if readable(toc)then return toc end
    end
    local toc=dir..'/'..name..'.toc';if readable(toc)then return toc end
end
-- A client: C_AddOns.LoadAddOn(name) runs the TOC this client picks, each file with
-- (name, namespace) and one namespace per addon. outcome(name) may refuse instead.
local function client(f,project,options)
    options=options or {}
    local requests,loaded,ran={},{},{}
    local function load(name)
        requests[#requests+1]=name
        local refused=options.outcome and options.outcome(name)
        if refused then return false,refused end
        local toc=chooseTOC(name,project);if not toc then return false,'MISSING' end
        local namespace={};ran.toc=toc
        for _,path in ipairs(modules.entries(toc))do
            ran[#ran+1]=path
            local chunk=assert(loadfile(path));setfenv(chunk,f.env);chunk(name,namespace)
        end
        loaded[name]=true
        return true,nil
    end
    local api={LoadAddOn=load,IsAddOnLoaded=function(name)return loaded[name]==true end}
    if options.legacy then f.env.C_AddOns=nil;f.env.LoadAddOn=api.LoadAddOn;f.env.IsAddOnLoaded=api.IsAddOnLoaded
    else f.env.C_AddOns=api end
    return requests,ran
end
local function start(project,expansion,class,options)
    local f,packs=corpus.load(project,expansion,class,{characterScope=true,modules=false})
    assert(#packs==0,'no pack may register before the module loads')
    f.load('Core/builtin_modules.lua')
    local messages={};f.addon.info=function(_,message,...)messages[#messages+1]=message:format(...)end
    local requests,ran=client(f,project,options)
    return f,packs,requests,messages,ran
end
local function packFiles(family,class)
    local n=0;for _,path in ipairs(modules.paths({family=family,class=class}))do if not modules.isBlock(path)then n=n+1 end end;return n
end

for _,c in ipairs({{'TBC Shaman',5,1,'SHAMAN','tbc','RotationMaster_Shaman','_TBC.toc'},
    {'Forever Mage',18,12,'MAGE','forever','RotationMaster_Mage','_Camelot.toc'},
    {'Retail Warrior',1,12,'WARRIOR','retail','RotationMaster_Warrior','_Standard.toc'},
    {'Classic Era Shaman',2,0,'SHAMAN','era','RotationMaster_Shaman','_Vanilla.toc'},
    {'Era Mage',2,0,'MAGE','era','RotationMaster_Mage','_Vanilla.toc'}})do
    test(c[1]..' startup requests exactly its class module, which runs only its edition',function()
        local f,packs,requests,messages,ran=start(c[2],c[3],c[4])
        local a=f.addon
        assert(a:LoadBuiltInModule()==c[6])
        assert(#requests==1 and requests[1]==c[6],'requested: '..table.concat(requests,', '))
        assert(ran.toc:sub(-#c[7])==c[7],'client picked '..tostring(ran.toc))
        for _,path in ipairs(ran)do
            assert(path=='Modules/'..c[6]..'/bind.lua' or path:find('^Modules/'..c[6]..'/'..c[5]..'/'),path..' ran on a '..c[5]..' client')
        end
        assert(#packs==packFiles(c[5],c[4]) and #packs>0,('%d packs registered, %d in the edition'):format(#packs,packFiles(c[5],c[4])))
        for _,pack in ipairs(packs)do
            assert(pack.applicability.families[1]==c[5] and pack.applicability.class==c[4],pack.id..' is not this character\'s')
        end
        assert(a:InitializeRotationLibrary())
        for _,pack in ipairs(packs)do assert(a:GetDefaultRotation(pack.id),pack.id..' missing from the catalog')end
        assert(#messages==0,'a loaded module says nothing: '..tostring(messages[1]))
        -- Startup runs once per session; a later call neither reloads nor re-registers.
        assert(a:LoadBuiltInModule()==c[6] and #requests==1)
    end)
end

test('an edition with no Built Ins yet loads its class module, which runs nothing',function()
    local f,packs,requests,messages,ran=start(19,4,'DEMONHUNTER') -- Mists Classic: the unsuffixed fallback
    assert(f.addon:LoadBuiltInModule()=='RotationMaster_DemonHunter' and #requests==1)
    assert(ran.toc=='Modules/RotationMaster_DemonHunter/RotationMaster_DemonHunter.toc' and #ran==0 and #packs==0 and #messages==0)
    assert(f.addon:InitializeRotationLibrary())
end)

test('a class with no Built Ins in this edition runs nothing there',function()
    local f,packs,_,messages,ran=start(5,1,'MONK') -- Monks have Retail packs only
    assert(f.addon:LoadBuiltInModule()=='RotationMaster_Monk')
    assert(ran.toc=='Modules/RotationMaster_Monk/RotationMaster_Monk.toc' and #ran==0 and #packs==0 and #messages==0)
end)

for _,reason in ipairs({'MISSING','DISABLED','DEP_MISSING'})do
    test('a '..reason..' module leaves Rotation Master working with no Built Ins and one message',function()
        local f,packs,requests,messages=start(5,1,'SHAMAN',{outcome=function()return reason end})
        local a=f.addon
        local name,why=a:LoadBuiltInModule()
        assert(name==nil and why==reason and #requests==1 and requests[1]=='RotationMaster_Shaman')
        assert(a:InitializeRotationLibrary(),'library must still build')
        assert(#packs==0 and a:GetDefaultRotation('rm.tbc.shaman.restoration')==nil)
        assert(#messages==1 and messages[1]:find('RotationMaster_Shaman',1,true) and messages[1]:find(reason,1,true),tostring(messages[1]))
        a:LoadBuiltInModule();assert(#messages==1 and #requests==1,'the failure is reported once')
    end)
end

test('a module that raises while loading is reported, not propagated',function()
    local f,_,requests,messages=start(5,1,'SHAMAN')
    f.env.C_AddOns.LoadAddOn=function(name)requests[#requests+1]=name;error('broken module')end
    local name,why=f.addon:LoadBuiltInModule()
    assert(name==nil and why=='UNKNOWN_ERROR' and #messages==1)
    assert(f.addon:InitializeRotationLibrary())
end)

test('an unrecognised client requests nothing and says nothing',function()
    local f,_,requests,messages=start(5,1,'SHAMAN')
    f.addon.Platform.GetClientFamily=function()return 'unknown' end
    local name,why=f.addon:LoadBuiltInModule()
    assert(name==nil and why=='no-module' and #requests==0 and #messages==0)
end)

test('an unreadable class loads no module and says so once',function()
    local f,_,requests,messages=start(5,1,'SHAMAN')
    f.env.UnitClass=function()error('restricted')end
    local name,why=f.addon:LoadBuiltInModule()
    assert(name==nil and why=='unknown-class' and #requests==0 and #messages==1)
end)

test('clients without C_AddOns use the global LoadAddOn',function()
    local f,packs,requests=start(5,1,'SHAMAN',{legacy=true})
    assert(f.addon:LoadBuiltInModule()=='RotationMaster_Shaman' and #requests==1 and #packs==packFiles('tbc','SHAMAN'))
end)

test('outside a client (no loader) nothing is requested or reported',function()
    local f,_,_,messages=start(5,1,'SHAMAN');f.env.C_AddOns=nil;f.env.LoadAddOn=nil
    local name,why=f.addon:LoadBuiltInModule()
    assert(name==nil and why=='no-loader' and #messages==0)
end)

-- What a file registers, run in isolation through a recording namespace.
local function registrations(path)
    local rows={}
    local namespace={RegisterDefaultBlock=function(_,b)rows[#rows+1]={kind='block',families=b.families,class=b.class};return true end,
        RegisterDefaultRotation=function(_,p)rows[#rows+1]={kind='pack',families=p.applicability.families,class=p.applicability.class};return true end}
    local chunk=assert(loadfile(path));setfenv(chunk,setmetatable({},{__index=_G}));chunk('RotationMaster_Test',namespace)
    return rows
end
test('each flavour TOC lists exactly its edition\'s blocks and packs, every file in one edition of its class',function()
    local listed,count={},0
    for _,module in ipairs(modules.list())do
        assert(#modules.entries(module.toc)==0,module.toc..' (the fallback) must load nothing')
        for family,row in pairs(module.editions)do
            local first=assert(io.open(row.tocs[1])):read('*a')
            for i=2,#row.tocs do assert(assert(io.open(row.tocs[i])):read('*a')==first,row.tocs[i]..' differs from '..row.tocs[1])end
            assert(modules.entries(row.tocs[1])[1]==module.bind,row.tocs[1]..' must load bind.lua first')
            assert(modules.isBlock(row.files[1]),row.tocs[1]..' must load its blocks first')
            for _,path in ipairs(row.files)do
                assert(not listed[path],path..' listed twice');listed[path]=true;count=count+1
                assert(path:find('^'..module.dir..'/'..row.folder..'/'),path..' is outside '..row.folder..'/')
                local rows=registrations(path);assert(#rows>=1,path..' registers nothing')
                for _,r in ipairs(rows)do
                    assert(r.kind==(modules.isBlock(path)and 'block' or 'pack'),path)
                    assert(#r.families==1 and r.families[1]==family and r.class==module.class,path..' does not belong to '..family..' '..module.class)
                end
                if not modules.isBlock(path)then assert(#rows==1,path..' registers '..#rows..' packs')end
            end
        end
    end
    local p=assert(io.popen("find Modules -name '*.lua' ! -name bind.lua"));local onDisk=0
    for path in p:lines()do onDisk=onDisk+1;assert(listed[path],path..' is in no flavour TOC')end
    p:close()
    -- 278 with Era; +42 MoP Death Knight, Druid, Hunter, Mage, Monk, Paladin; +38 MoP Priest, Rogue, Shaman, Warlock, Warrior.
    assert(onDisk==count and count==278+42+38,onDisk..' files on disk, '..count..' listed')
end)

test('every module on disk is one the loader can name, and bind.lua reaches Rotation Master',function()
    local f=start(5,1,'SHAMAN');local a=f.addon
    local listed={};for _,module in ipairs(modules.list())do listed[module.name]=module end
    local p=assert(io.popen('ls -1 Modules'));local count=0
    for entry in p:lines()do
        if readable('Modules/'..entry..'/'..entry..'.toc')then count=count+1;assert(listed[entry],entry..' is not a name the loader produces')end
    end
    p:close()
    local n=0;for _ in pairs(listed)do n=n+1 end;assert(count==n and n==13,count..' module folders, '..n..' named')
    for name,module in pairs(listed)do assert(a:GetBuiltInModuleName(module.class)==name)end
    -- The bootstrap binds a module namespace, never Rotation Master's own.
    local host=f.env.RotationMasterBuiltIns;assert(type(host)=='table')
    assert(host.Bind(a)==false)
    local namespace={};assert(host.Bind(namespace)==true)
    local seen;local register=a.RegisterDefaultBlock
    a.RegisterDefaultBlock=function(self,block)seen=self==a and block;return true end
    assert(namespace:RegisterDefaultBlock('block')==true and seen=='block','forwarded with Rotation Master as self')
    a.RegisterDefaultBlock=register
end)

print(('%d passed, %d failed'):format(pass,fail));if fail>0 then os.exit(1)end
