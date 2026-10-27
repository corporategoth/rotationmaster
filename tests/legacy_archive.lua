-- Upgrading from a release before 2.0: a synthetic 1.4.3e SavedVariables table
-- (tests/fixtures/legacy_143e_profile.lua) goes through the real AceDB,
-- main.lua, init.lua and the scoped rotation store. The rotations land in the
-- unassigned archive and do not run until adopted; the player is told once;
-- the old data formats are upgraded in the archive too; adopting many at once
-- uses the same ownership code as adopting one.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local build=dofile('tests/fixtures/legacy_143e_profile.lua')
local function uuid(n) return string.format('00000000-0000-4000-8000-%012d',n) end

-- The real startup fixture of tests/startup.lua, as several suites load it.
local source=assert(io.open('tests/startup.lua')):read('*a')
local prefix=assert(source:match('^(.-)\nlocal function initialize'))
local persistent=assert(source:match('(local function persistentFixture%(saved,folder,scoped%).-)\n%-%- WoW SavedVariables'))
local make=assert(loadstring(prefix..'\n'..persistent..'\nreturn persistentFixture','@legacy-archive-startup'))()
-- What the host writes at logout: AceDB strips defaults, then plain data only.
local function serialized(value)
    if type(value)~='table' then return value end
    local copy={};for k,v in pairs(value) do copy[serialized(k)]=serialized(v) end;return copy
end
local function start(saved,after)
    local env,a,scripts,load=make({RotationMasterDB=saved or build()},nil,true)
    assert(not a.initializationErrorReport,'initialization failed');load('Core/legacy_archive.lua')
    local messages={};a.print=function(_,text,...) messages[#messages+1]=string.format(text,...) end
    return a,env,scripts,messages
end
local function restart(env,scripts)
    scripts.OnEvent(nil,'PLAYER_LOGOUT')
    local saved=serialized(env.RotationMasterDB)
    return start(saved)
end
local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function archive(a,profile) return a.db.sv.profiles[profile or 'SHAMAN'].rotationStore.legacy.rotations[0] end
local function contains(tree,field,value)
    if type(tree)~='table' then return false end
    if tree[field]==value then return true end
    for _,child in pairs(tree) do if contains(child,field,value) then return true end end
    return false
end

test('a 1.4.3e profile starts, keeps every setting, and archives all its rotations unassigned',function()
    local a=start()
    local p=a.db.profile
    assert(p.ignore_mana==true and p.ignore_range==true and p.poll==0.2 and p.spell_history==30 and p.preview_spells==3,'a setting was lost')
    assert(p.effect==uuid(702) and p.announces[1].name=='Bolt cast' and p.itemsets[uuid(902)].name=='ProfileSet','profile data was lost')
    local rows=assert(a:ListUnassignedRotations());assert(#rows==3,'expected the three saved rotations, got '..#rows)
    local names={};for _,row in ipairs(rows) do names[row.name]=row.hasBody end
    assert(names.Default and names.Everything and names.Solo,'a rotation is missing from the archive')
    local listed={};for _,row in ipairs(a:ListRotationHeaders(0)) do listed[row.canonicalId]=row end
    -- The editor shows an empty, virtual Default; the archived one is not it.
    assert(not listed[uuid(11)] and not listed[uuid(12)] and (not listed.Default or listed.Default.virtual==true),'an unassigned rotation was listed as running')
    assert(not next(a.db.profile.rotationStore.classes) and not next(a.db.profile.rotationStore.characters),'ownership was inferred')
    assert(a.db.global.itemsets[uuid(901)].items[2]=='Healthstone' and a.db.char.bindings[uuid(902)][1]==12 and a.db.char.bindings[uuid(901)][1]==34,'global or character data changed')
end)

test('the old data formats are upgraded inside the archive, for every profile and character',function()
    local a=start()
    local default=archive(a).Default
    assert(default.cooldowns[2].effect==uuid(702),'a cooldown effect stored by name was not resolved')
    assert(default.cooldowns[3].effect=='NoSuchEffect','an effect that cannot be resolved was erased')
    assert(default.cooldowns[6].type=='any' and default.rotation[6].type=='any','a pet step was not converted')
    assert(default.cooldowns[1].effect==uuid(702) and default.cooldowns[1].announce==uuid(801),'a current field changed')
    local first=default.rotation[1].conditions.value[3].value
    assert(first[1].type=='ANYSPELL_AVAIL' and not contains(default,'type','PETSPELL_AVAIL'),'a pet spell condition was not converted')
    assert(first[2].rune==1,'a rune name was not converted')
    assert(type(default.rotation[3].action)=='table' and default.rotation[3].action[1]==5512,'a bare item id was not wrapped')
    assert(type(default.rotation[4].action)=='table' and default.rotation[4].action[2]=='Healthstone','an item list changed')
    assert(default.rotation[5].action==uuid(901),'an item set reference changed')
    assert(type(default.rotation[7].conditions.item)=='table' and default.rotation[7].conditions.item[1]==5512,'an item condition was not wrapped')
    -- A profile this character never uses, and a character root, are upgraded as well.
    local other=archive(a,'LEGACY').Default
    assert(other.cooldowns[1].type=='any' and other.cooldowns[1].effect==uuid(702),'the other profile\'s pet step or effect name was not converted')
    assert(other.cooldowns[1].conditions.type=='ANYSPELL_RANGE' and other.rotation[1].conditions.rune==2,'the other profile\'s conditions were not converted')
    local char=a.db.sv.char['Alt - Fixture Realm'].rotations[0].charold
    assert(char.rotation[1].type=='any' and char.rotation[1].conditions.type=='ANYSPELL_COOLDOWN','a character root was not converted')
end)

test('the upgrade of archived bodies changes nothing the second time',function()
    local a,env,scripts=start()
    local before=serialized(a.db.sv.profiles.SHAMAN.rotationStore.legacy)
    local b=restart(env,scripts)
    assert(same(before,serialized(b.db.sv.profiles.SHAMAN.rotationStore.legacy)),'a second start changed the archive')
end)

test('the player is told once, per profile, and only while something waits',function()
    local a,env,scripts,messages=start()
    assert(a:ShowLegacyArchiveNotice()==true and #messages==1 and messages[1]:find('3',1,true),'no notice about the three rotations')
    assert(a.db.profile.legacyArchiveNoticed==true and a:ShowLegacyArchiveNotice()==false and #messages==1,'the notice repeated')
    local b,_,_,again=restart(env,scripts)
    assert(b:ShowLegacyArchiveNotice()==false and #again==0,'the notice came back after a restart')
    local empty,_,_,quiet=start({})
    assert(empty:ShowLegacyArchiveNotice()==false and #quiet==0 and empty.db.profile.legacyArchiveNoticed==nil,'a profile with nothing waiting was told, or marked as told')
end)

test('the first world entry shows the notice through the event frame',function()
    local a,_,scripts,messages=start()
    scripts.OnEvent(nil,'PLAYER_ENTERING_WORLD');assert(#messages==1,'the world-entry event did not show the notice')
    scripts.OnEvent(nil,'PLAYER_ENTERING_WORLD');assert(#messages==1,'a second world entry repeated it')
    assert(a.legacyArchiveNoticeFrame~=nil)
end)

test('the settings banner stays until dismissed, and dismissing keeps the archive',function()
    local a,env,scripts=start()
    assert(a:GetLegacyArchiveBanner()==3)
    a:ShowLegacyArchiveNotice();assert(a:GetLegacyArchiveBanner()==3,'saying it in chat hid the banner')
    a:DismissLegacyArchiveBanner();assert(a:GetLegacyArchiveBanner()==nil and #a:ListUnassignedRotations()==3)
    local b=restart(env,scripts);assert(b:GetLegacyArchiveBanner()==nil,'a dismissed banner came back')
    local c=start();c:AdoptAllUnassignedRotations('class');assert(c:GetLegacyArchiveBanner()==nil,'the banner outlived the archive')
end)

test('adopting all uses the explicit scope and the existing ownership rules',function()
    local a=start()
    local refused,why=a:AdoptAllUnassignedRotations('universal');assert(refused==nil and why=='invalid-owner-scope')
    local none=assert(a:AdoptAllUnassignedRotations('class',{spec=99}));assert(none.adopted==0 and #a:ListUnassignedRotations()==3,'a filter for another specialization adopted something')
    local result=assert(a:AdoptAllUnassignedRotations('class'))
    assert(result.adopted==3 and #result.failed==0 and result.skipped==0 and #result.references==3,'not all three were adopted')
    assert(#a:ListUnassignedRotations()==0,'rotations are still unassigned')
    local owned=a.db.profile.rotationStore.classes.SHAMAN[0]
    assert(owned and owned.Default and owned[uuid(11)] and owned[uuid(12)] and not next(a.db.profile.rotationStore.characters),'the class owner did not receive them')
    assert(owned[uuid(11)].body.name=='Everything' and owned.Default.body.cooldowns[2].effect==uuid(702),'an adopted body differs from the archive')
    local listed={};for _,row in ipairs(a:ListRotationHeaders(0)) do listed[row.canonicalId]=row.name end
    assert(listed[uuid(11)]=='Everything' and listed[uuid(12)]=='Solo' and listed.Default=='Default','adopted rotations are not listed')
    for _,row in ipairs(a:ListRotationHeaders(0)) do if row.canonicalId=='Default' then assert(row.virtual==false,'the archived fallback is still a virtual draft') end end
    for _,reference in ipairs(result.references) do assert(reference.kind=='custom' and reference.address.scope=='class' and reference.address.class=='SHAMAN') end
end)

test('adopting for this character puts them under the character, not the class',function()
    local a=start()
    local result=assert(a:AdoptAllUnassignedRotations('character'));assert(result.adopted==3)
    local store=a.db.profile.rotationStore
    assert(not next(store.classes) and store.characters and next(store.characters),'the character owner did not receive them')
end)

test('adopting one specialization adopts only that key and reports a refused record without stopping',function()
    local saved=build()
    -- The character root holds a second Default: the same address as the profile's.
    saved.char['Fixture Character - Fixture Realm'].rotations={[0]={Default={name='Character default',switch={},cooldowns={},rotation={}}}}
    saved.profiles.SHAMAN.rotations[1]={[uuid(13)]={name='Other key',switch={},cooldowns={},rotation={}}}
    local a=start(saved)
    local rows=assert(a:ListUnassignedRotations());assert(#rows==5,'expected five archived rotations, got '..#rows)
    local one=assert(a:AdoptAllUnassignedRotations('class',{spec=1}));assert(one.adopted==1 and #a:ListUnassignedRotations()==4,'one specialization key did not adopt exactly its rotation')
    local all=assert(a:AdoptAllUnassignedRotations('class'))
    assert(all.adopted==3 and #all.failed==1 and all.failed[1].id=='Default' and type(all.failed[1].reason)=='string','the refused record was not reported: '..all.adopted..'/'..#all.failed)
    assert(#a:ListUnassignedRotations()==1,'the refused record was lost or forced')
end)

test('end to end: nothing runs until adopted, then the 1.4.3e rotation is chosen and advises its spell',function()
    local root=assert(io.popen('pwd'):read('*l'))
    local c=assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('price',root,true,root,true)({target=true,combat=false,buttons=true,poll=.15,
        saved=function(direct) local saved=build();saved.global.diagnosticCacheBypass=direct;saved.profiles.SHAMAN.effect=nil;return saved end})
    local a=c.a;c.load('Core/legacy_archive.lua')
    assert(#a:ListUnassignedRotations()==3 and a.currentSpell==403,'the premade should be running before adoption')
    for _,row in ipairs(a:ListRotationHeaders(0)) do assert(row.name~='Solo','an unassigned rotation was listed') end
    a:HandleCommand('set Solo');for _=1,3 do c.tick() end
    assert(a:GetRuntimeRotation(0,a.currentRotation).name~='Solo','an unassigned rotation was selectable')
    local result=assert(a:AdoptAllUnassignedRotations('class'));assert(result.adopted==3 and #result.failed==0)
    a:HandleCommand('set Solo');for _=1,5 do c.tick() end
    assert(a:GetRuntimeRotation(0,a.currentRotation).name=='Solo','the adopted rotation was not selected')
    assert(a.currentSpell==8042,'the adopted rotation did not advise its spell, got '..tostring(a.currentSpell))
end)

finish()
