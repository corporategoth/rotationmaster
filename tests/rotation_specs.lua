-- A rotation's specializations are its own property, body.specs (the user,
-- 2026-10-24): the minimap list, /rm set and the Rotations list read it, the
-- switch condition never decides whether a rotation is listed or can be chosen
-- by hand (it could be anything, "in PvP" included), and automatic switching
-- tries the specialization first, then the switch, then priority.
--
-- What a value means is a static fact of the client (Platform/specializations.lua
-- GetRotationSpecKind): specialization IDs where they are the same on every
-- account (Retail with its "No specialization" IDs, Mists of Pandaria Classic),
-- talent groups everywhere dual specialization exists or will (Era, TBC,
-- Wrath, Cataclysm, Forever), whatever the character's level. Talent groups
-- never leave the character: exports drop them, imports fill them in.
local T=dofile('tests/fixtures/toc_addon.lua')
local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()

local function same(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function show(v)
    if type(v)~='table' then return tostring(v) end
    local keys={};for k in pairs(v) do keys[#keys+1]=k end
    table.sort(keys,function(x,y) return tostring(x)<tostring(y) end)
    local out={};for _,k in ipairs(keys) do out[#out+1]=tostring(k)..'='..show(v[k]) end
    return '{'..table.concat(out,',')..'}'
end
local function platform(project,expansion)
    local f=F.new(project,expansion);f.load('Platform/specializations.lua');return f
end
local function key(a,id) return a:GetScopedRotationCoordinator():Key({kind='builtin',id=id}) end
local function custom(f,spec,name,body)
    local a=f.addon;local ref=assert(a:NewRotationDraftTarget(spec,'class'))
    body=body or {};body.name=name;body.rotation=body.rotation or {{id='a1',type='assisted',conditions={}}};body.cooldowns=body.cooldowns or {}
    assert(a:CommitRotationDraft(ref,nil,{body=body},'class'))
    return a:GetScopedRotationCoordinator():Key(ref),ref
end
local function spec(n) return {type='SPECIALIZATION',spec=n} end
local function level(n) return {type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=n} end
local COMBAT={type='COMBAT',unit='player'}

-- Platform/specializations.lua's table, client by client.
test('classification: specialization IDs on Retail and Mists Classic, talent groups on every dual-specialization client',function()
    local rows={
        {1,12,'portable',true,'Retail'},
        {19,4,'portable',false,'Mists of Pandaria Classic'},
        {2,0,'slot',false,'Classic Era and Season of Discovery'},
        {5,1,'slot',false,'TBC Anniversary'},
        {11,2,'slot',true,'Wrath Classic'},
        {14,3,'slot',true,'Cataclysm Classic'},
        {18,12,'slot',false,'Forever'},
    }
    for _,row in ipairs(rows) do
        local p=platform(row[1],row[2]).addon.Platform
        assert(p:GetRotationSpecKind()==row[3],row[5]..': '..tostring(p:GetRotationSpecKind()))
        assert(p:RotationKeyIsSpecValue()==row[4],row[5]..' namespace')
        if row[3]=='slot' then local choices=assert(p:GetRotationSpecChoices(10));assert(#choices==2 and choices[1].id==1 and choices[2].id==2 and choices[1].slot,row[5]..': both talent groups') end
    end
    local unknown=platform(999,12).addon.Platform
    assert(unknown:GetRotationSpecKind()==nil and unknown:GetRotationSpecValue()==nil,'an unknown client has no specializations')
end)

test('the current value: the active talent group on slot clients (a low-level Forever character is in group 1), the specialization ID elsewhere',function()
    -- Forever before dual specialization: the client still answers group 1.
    local forever=platform(18,12);forever.env.C_SpecializationInfo={GetActiveSpecGroup=function() return 1 end}
    assert(forever.addon.Platform:GetRotationSpecValue()==1)
    forever.env.C_SpecializationInfo={GetActiveSpecGroup=function() return 2 end};assert(forever.addon.Platform:GetRotationSpecValue()==2)
    -- No talent-group API at all: the only group there is.
    local era=platform(2,0);era.env.C_SpecializationInfo=nil;era.env.GetActiveTalentGroup=nil
    assert(era.addon.Platform:GetRotationSpecValue()==1)
    local tbc=platform(5,1);tbc.env.C_SpecializationInfo=nil;tbc.env.GetActiveTalentGroup=function() return 2 end
    assert(tbc.addon.Platform:GetRotationSpecValue()==2)
    local mists=platform(19,4)
    mists.env.C_SpecializationInfo={GetSpecialization=function() return 1 end,GetSpecializationInfo=function() return 268,'Brewmaster' end,GetActiveSpecGroup=function() return 2 end}
    assert(mists.addon.Platform:GetRotationSpecValue()==268,'Mists names the specialization, not its talent group')
    mists.env.C_SpecializationInfo.GetSpecialization=function() return nil end
    assert(mists.addon.Platform:GetRotationSpecValue()==nil,'no specialization chosen yet is unknown')
    local retail=platform(1,12)
    retail.env.C_SpecializationInfo={GetSpecialization=function() return 5 end,GetSpecializationInfo=function() return 1450,'Initial' end}
    assert(retail.addon.Platform:GetRotationSpecValue()==1450,'"No specialization" is a value of its own')
end)

-- The minimap list and /rm set: the specialization, never the switch.
test('a switch condition never hides a rotation from the minimap list or manual selection; another specialization does',function()
    local f=T.new{level=10,specIndex=1};local a=f.addon
    local pvp=custom(f,268,'Only in PvP',{priority=5,switch={type='PVP',unit='player'}})
    local ww=custom(f,268,'Windwalker only',{priority=5,specs={269},switch=COMBAT})
    local pass=a:AcquireRotationRuntimePass(268);local listed=pass:Candidates(false)
    assert(listed[pvp],'a rotation whose switch does not match left the minimap list')
    assert(listed[ww]==nil,'another specialization reached the minimap list')
    assert(a:ExplainRotationRefusal(268,pvp)==nil,'manual selection refused over a switch')
    local why,code=a:ExplainRotationRefusal(268,ww)
    assert(code=='specialization-mismatch' and why=='it is for another specialization',tostring(why))
    -- A Built In of another specialization says the same, from its body.specs.
    local _,builtinCode=a:ExplainRotationRefusal(268,key(a,'rm.retail.monk.windwalker'))
    assert(builtinCode=='specialization-mismatch',tostring(builtinCode))
    -- /rm set by identifier selects the PvP one by hand.
    a:HandleCommand('set only-in-pvp');assert(a.currentRotation==pvp and a.manualRotation,'manual selection failed')
    -- Respec to Windwalker: now the Windwalker rotation is listed (it lives where it was saved).
    f.state.specIndex=3;f.fire('PLAYER_SPECIALIZATION_CHANGED','player')
    assert(a.currentSpec==269)
    listed=a:AcquireRotationRuntimePass(269):Candidates(false)
    assert(listed[ww] and listed[pvp],'respec did not bring the Windwalker rotation')
    local report=table.concat(a:GetRotationIdentifierReport(),'\n')
    assert(report:find('Rotations for Windwalker',1,true),report)
end)

test('automatic switching: the specialization first, then the switch, then priority; no switch is still manual only',function()
    local f=T.new{level=10,specIndex=1};local a=f.addon
    for _,id in ipairs({'rm.retail.monk.brewmaster','rm.retail.monk.windwalker'}) do assert(a:SetDefaultRotationEnabled(id,false)) end
    local mine=custom(f,268,'Brewmaster mine',{priority=50,specs={268},switch=level(1)})
    local theirs=custom(f,268,'Windwalker mine',{priority=60,specs={269},switch=level(1)})
    local hand=custom(f,268,'By hand',{priority=70,specs={268}})
    a.db.profile.disable_autoswitch=false;a:DisableRotation();a.manualRotation=false;a:UpdateAutoSwitch();a:SwitchRotation()
    assert(a.currentRotation==mine,'expected the Brewmaster rotation, got '..tostring(a:GetRotationName(a.currentRotation)))
    assert(not a:IsManualOnlyRotation(268,mine) and a:IsManualOnlyRotation(268,hand),'manual only means no switch condition')
    local report=table.concat(a:GetRotationEligibilityReport(),'\n')
    assert(report:find('By hand [by-hand]: ready, manual only',1,true),report)
    assert(report:find('Windwalker mine [windwalker-mine]: cannot be selected, it is for Windwalker.',1,true),report)
    assert(a:AcquireRotationRuntimePass(268):Get(theirs)==nil)
    -- Its overlap with another Brewmaster rotation is judged with its specializations: none with Windwalker's.
    local overlaps=a:GetSwitchOverlaps(268)
    for _,entry in ipairs(overlaps[mine] or {}) do assert(entry.key~=theirs,'overlaps another specialization') end
    f.state.specIndex=3;f.fire('PLAYER_SPECIALIZATION_CHANGED','player');a.manualRotation=false;a:SwitchRotation()
    assert(a.currentRotation==theirs,'Windwalker did not switch: '..tostring(a:GetRotationName(a.currentRotation)))
end)

test('on a talent-group client body.specs holds the group, and switching groups changes what is listed',function()
    local f=T.new{project=5,expansion=1,class='MAGE',level=60};local a=f.addon;local group=1
    f.env.C_SpecializationInfo.GetActiveSpecGroup=function() return group end
    a:InvalidateBuildContext('talents')
    assert(a:GetRotationSpecKind()=='slot' and a:GetCurrentRotationSpecValue()==1)
    local second=custom(f,0,'Second talents',{priority=5,specs={2},switch=COMBAT})
    local either=custom(f,0,'Either',{priority=5,switch=COMBAT})
    local listed=a:AcquireRotationRuntimePass(0):Candidates(false)
    assert(listed[either] and listed[second]==nil,'the secondary talents rotation is listed in the primary group')
    group=2;f.fire('ACTIVE_TALENT_GROUP_CHANGED');a:InvalidateBuildContext('talents')
    listed=a:AcquireRotationRuntimePass(0):Candidates(false)
    assert(listed[either] and listed[second],'switching to the secondary group did not list it')
    local entries=a:GetRotationSpecEntries()
    assert(#entries==2 and entries[1].name:find('Primary',1,true) and entries[2].name:find('Secondary',1,true),show(entries))
    assert(not a:DescribeRotationSpecs({2}):find('2',1,true) or a:DescribeRotationSpecs({2}):find('Secondary',1,true),'a group is named, never "spec 2"')
end)

-- The one-time profile migration.
local function store(records,key,class)
    class=class or 'MONK'
    local rows={};for id,switch in pairs(records) do rows[id]={body={name=id,switch=switch,rotation={},cooldowns={}}} end
    return {rotationFallbackID='Default-id',rotationStore={version=1,classes={[class]={[key]=rows}},characters={},legacy={}}}
end
local function body(profile,id,key,class) return profile.rotationStore.classes[class or 'MONK'][key][id].body end
test('migration on Retail: the namespace becomes body.specs, and exactly the shapes that filed a Built In move out of the switch',function()
    local a=T.new{level=10,specIndex=1}.addon
    local profile=store({
        only=spec(268),
        withLevel={type='AND',value={level(10),spec(268)}},
        withTwo={type='AND',value={level(10),spec(268),COMBAT}},
        either={type='OR',value={spec(268),spec(269)}},
        other=spec(269),
        negated={type='NOT',value=spec(268)},
        mixed={type='OR',value={spec(268),COMBAT}},
        conflict={type='AND',value={spec(268),spec(269)}},
        disabled={type='SPECIALIZATION',spec=268,disabled=true},
        plain=COMBAT,
        ['Default-id']=spec(268),
    },268)
    profile.rotationStore.classes.MONK[268].preset={body={name='preset',specs={},switch=spec(268),rotation={},cooldowns={}}}
    assert(a:MoveRotationSpecsToProperty(profile) and profile.rotationSpecsMigrated)
    local function check(id,specs,switch) local b=body(profile,id,268)
        assert(same(b.specs,specs) and same(b.switch,switch),id..': '..show(b.specs)..' '..show(b.switch)) end
    check('only',{268},level(1))       -- it chose itself automatically, and still does
    check('withLevel',{268},level(10))
    check('withTwo',{268},{type='AND',value={level(10),COMBAT}})
    check('either',{268},level(1))
    check('other',{268},spec(269))        -- never matched where it was saved; left as it was
    check('negated',{268},{type='NOT',value=spec(268)})
    check('mixed',{268},{type='OR',value={spec(268),COMBAT}})
    check('conflict',{268},{type='AND',value={spec(268),spec(269)}})
    check('disabled',{268},{type='SPECIALIZATION',spec=268,disabled=true})
    check('plain',{268},COMBAT)
    check('Default-id',nil,spec(268))     -- the fallback belongs to its namespace
    check('preset',{},spec(268))          -- already has the property: untouched
    -- Once only: a rotation later set to Any stays Any.
    body(profile,'only',268).specs=nil
    assert(not a:MoveRotationSpecsToProperty(profile) and body(profile,'only',268).specs==nil)
    assert(a:ValidateProfileTransfer({rotationSpecsMigrated=true}) and not a:ValidateProfileTransfer({rotationSpecsMigrated='yes'}))
end)

test('migration elsewhere: Mists moves the switch only; Wrath files talent groups; Era, TBC and Forever move nothing',function()
    -- Mists: rotations are saved per talent group, but SPECIALIZATION reads the specialization ID.
    local mists=platform(19,4);mists.load('Data/plain.lua');mists.load('Data/validation.lua');mists.load('Core/rotation_migration.lua')
    local profile=store({brew={type='AND',value={level(10),spec(268)}},plain=COMBAT},2)
    assert(mists.addon:MoveRotationSpecsToProperty(profile))
    assert(same(body(profile,'brew',2).specs,{268}) and same(body(profile,'brew',2).switch,level(10)),show(body(profile,'brew',2)))
    assert(body(profile,'plain',2).specs==nil,'a talent-group namespace became a specialization')
    -- Wrath: the namespace is the talent group; SPECIALIZATION there tests talent trees.
    local wrath=platform(11,2);wrath.load('Data/plain.lua');wrath.load('Data/validation.lua');wrath.load('Core/rotation_migration.lua')
    profile=store({tree=spec(62),plain=COMBAT},2,'MAGE')
    assert(wrath.addon:MoveRotationSpecsToProperty(profile))
    assert(same(body(profile,'tree',2,'MAGE').specs,{2}) and same(body(profile,'tree',2,'MAGE').switch,spec(62)),show(body(profile,'tree',2,'MAGE')))
    assert(same(body(profile,'plain',2,'MAGE').specs,{2}))
    for _,client in ipairs({{2,0},{5,1},{18,12}}) do
        local f=platform(client[1],client[2]);f.load('Data/plain.lua');f.load('Data/validation.lua');f.load('Core/rotation_migration.lua')
        profile=store({tree=spec(62),both={type='AND',value={spec(62),COMBAT}}},0,'MAGE')
        assert(f.addon:MoveRotationSpecsToProperty(profile))
        for _,id in ipairs({'tree','both'}) do local b=body(profile,id,0,'MAGE');assert(b.specs==nil and b.switch.type~=nil,id..' moved on '..client[1]) end
    end
end)

-- The premades were converted once, by tokenizer (tests/fixtures/premade_spec_switches.lua holds
-- every pre-conversion switch that named a specialization).
test('every converted premade: the old switch-derived specializations are its body.specs, and its switch is the old one minus them',function()
    local corpus=dofile('tests/fixtures/default_corpus.lua')
    local f,packs=corpus.load(5,1,'ROGUE');f.load('Data/plain.lua');f.load('Data/validation.lua');f.load('Core/rotation_migration.lua')
    local old=dofile('tests/fixtures/premade_spec_switches.lua');local byId={}
    for _,p in ipairs(packs) do byId[p.id]=p end
    local count=0
    for id,switch in pairs(old) do
        local p=assert(byId[id],id..' is gone')
        local specs,rest=f.addon:SplitSwitchSpecializations(switch)
        assert(specs,id..': the old switch was not a recognized shape')
        assert(same(p.body.specs,specs),id..': specs '..show(p.body.specs)..' expected '..show(specs))
        assert(same(p.body.switch,rest),id..': switch '..show(p.body.switch)..' expected '..show(rest))
        count=count+1
    end
    assert(count==155,count..' converted premades')
    -- Nothing else gained specializations, and slot editions never do.
    for _,p in ipairs(packs) do
        if p.body.specs then assert(old[p.id],p.id..' gained specs it never had') end
        local family=p.applicability.families[1]
        if family~='retail' and family~='progression' then assert(p.body.specs==nil,p.id..' has talent-group specs') end
    end
end)

-- Talent groups stay on the character.
local function exporter(project,expansion,body)
    local f=platform(project,expansion);f.load('Data/plain.lua');f.load('Data/validation.lua');f.load('Core/rotation_selection.lua');f.load('Core/imports.lua')
    local a=f.addon
    a.GetScopedRotationCoordinator=function() return {Snapshot=function() return {body=a.RotationData.CopyData(body)} end} end
    return a
end
test('exports drop talent groups on every dual-specialization client (a low-level Forever character too) and keep specialization IDs',function()
    local body={name='Mine',specs={2},rotation={},cooldowns={}}
    for _,client in ipairs({{2,0},{5,1},{11,2},{14,3},{18,12}}) do
        local a=exporter(client[1],client[2],body)
        if client[1]==18 then a.Platform.GetRotationSpecValue=function() return 1 end end
        local exported=assert(a:GetRotationExportData(0,'x'));assert(exported.specs==nil,'project '..client[1]..' exported a talent group')
    end
    for _,client in ipairs({{1,12},{19,4}}) do
        local a=exporter(client[1],client[2],{name='Mine',specs={268},rotation={},cooldowns={}})
        assert(same(a:GetRotationExportData(268,'x').specs,{268}),'project '..client[1]..' dropped specialization IDs')
    end
end)

test('imports fill in a talent group (the list\'s, else yours), keep specialization IDs, and refuse another class\'s',function()
    for _,client in ipairs({{2,0},{5,1},{11,2},{14,3},{18,12}}) do
        local a=exporter(client[1],client[2],{})
        a.GetRotationSpecValue=function() return 2 end
        assert(same(a:PrepareImportedRotationSpecs(nil),{2}),'project '..client[1]..': not the current group')
        assert(same(a:PrepareImportedRotationSpecs({1}),{2}),'an imported group number was trusted')
        assert(same(a:PrepareImportedRotationSpecs(nil,1),{1}),'not the list\'s group')
        assert(a:PrepareImportedRotationSpecs(nil,nil,{reference={}})==nil,'a replacement does not keep its own')
    end
    -- On a whole Retail client, through the real import.
    local f=T.new{level=10,specIndex=1};local a=f.addon
    local id=assert(a:CreateImportedRotation({body={name='x',specs={269,268},rotation={{id='s',type='assisted',conditions={}}},cooldowns={}}},268,'Imported'))
    local found;for _,row in ipairs(a:ListRotationHeaders(268)) do if row.canonicalId==id then found=row end end
    assert(found and same(found.specs,{268,269}),show(found and found.specs))
    local _,why=a:CreateImportedRotation({body={name='y',specs={71},rotation={{id='s',type='assisted',conditions={}}},cooldowns={}}},268,'Warrior')
    assert(why=='class-mismatch',tostring(why))
    -- A whole TBC client: the export carries none, the import is for the group you are in.
    local g=T.new{project=5,expansion=1,class='MAGE',level=60};local b=g.addon
    g.env.C_SpecializationInfo.GetActiveSpecGroup=function() return 2 end;b:InvalidateBuildContext('talents')
    local imported=assert(b:CreateImportedRotation({body={name='z',specs={1},rotation={{id='s',type='spell',action=133,conditions={}}},cooldowns={}}},0,'From a friend'))
    local key2;for _,row in ipairs(b:ListRotationHeaders(0)) do if row.canonicalId==imported then key2=row.key;assert(same(row.specs,{2}),show(row.specs)) end end
    assert(b:GetRotationExportData(0,key2).specs==nil)
end)

-- The list: a dropdown above the search box, filtering like the class does.
test('the Rotations list: a specialization dropdown above the search box, the current one by default, a warning for another, All',function()
    local f=T.new{level=10,specIndex=1};local a=f.addon
    local brew=custom(f,268,'Brew rot',{priority=3,specs={268}});local wind=custom(f,268,'Wind rot',{priority=3,specs={269}})
    local any=custom(f,268,'Any rot',{priority=3})
    local host=f.env.CreateFrame('Frame');host:SetSize(1000,3000)
    local browser=a:CreateRotationBrowser(host,{spec=268})
    local function shown() local set={};for _,row in ipairs(browser.rows) do set[row.key]=true end;return set end
    assert(browser.specFilter:IsShown() and browser.specFilter:GetParent()==browser.left,'the dropdown is not inside the list column')
    local _,_,_,_,searchY=browser.search:GetPoint(1);assert(searchY<0,'the search box is not below the dropdown')
    assert(browser.specValue==268 and a.rotationListSpec==268 and not browser.specWarning:IsShown())
    local rows=shown();assert(rows[brew] and rows[any] and not rows[wind] and not rows[key(a,'rm.retail.monk.windwalker')],'the list is not filtered by specialization')
    browser:SetSpecValue(269)
    rows=shown();assert(rows[wind] and rows[any] and not rows[brew] and rows[key(a,'rm.retail.monk.windwalker')])
    assert(browser.specWarning:IsShown() and browser.specWarning:GetText()=='This is not your current specialization.','no warning for another specialization')
    assert(browser.spec==269,'the namespace (its fallback) did not follow')
    -- A new rotation is for the specialization the list shows.
    browser.newButton:Click()
    assert(same(browser.pane.workspace:Snapshot().specs,{269}),'new rotation: '..show(browser.pane.workspace:Snapshot().specs))
    browser:SetSpecValue('all')
    rows=shown();assert(rows[wind] and rows[any] and rows[brew] and not browser.specWarning:IsShown())
    browser:Release();assert(a.rotationListSpec==nil)
    -- Session only: reopening starts at the current specialization again.
    browser=a:CreateRotationBrowser(host,{spec=268});assert(browser.specValue==268);browser:Release()
end)

test('the editor header: a specialization picker on the ID/Priority/Enabled line, several or Any, read-only on a Built In',function()
    local f=T.new{level=10,specIndex=1};local a=f.addon
    local parent=f.env.CreateFrame('Frame');parent:SetSize(900,700)
    local pane=assert(a:CreateRotationEditor(parent,268,key(a,'rm.retail.monk.brewmaster')));pane:Layout()
    assert(pane.specButton:IsShown() and not pane.specButton:IsEnabled() and pane.specButton:GetText()=='Brewmaster','Built In picker')
    local _,anchor=pane.specButton:GetPoint(1);assert(anchor==pane.identifierLabel,'the picker is not on the header line')
    local _,_,_,_,y=pane.specButton:GetPoint(1);local _,_,_,_,idY=pane.identifier:GetPoint(1);assert(y==idY,'the picker is on another row')
    local mineKey=custom(f,268,'Mine',{specs={268},switch=COMBAT})
    pane=assert(a:CreateRotationEditor(parent,268,mineKey));pane:Layout()
    assert(pane.specButton:IsEnabled() and pane.specButton:GetText()=='Brewmaster')
    pane.specButton:Click();pane.specMenu.changed(269)
    assert(same(pane.workspace:Snapshot().specs,{268,269}) and pane.specButton:GetText()=='Brewmaster, Windwalker',show(pane.workspace:Snapshot().specs))
    pane.specMenu.changed('any')
    assert(pane.workspace:Snapshot().specs==nil and pane.specButton:GetText()=='Any specialization')
    pane.apply:Click()
    local saved;for _,row in ipairs(a:ListRotationHeaders(268)) do if row.key==mineKey then saved=row end end
    assert(saved and saved.specs==nil,'Any was not saved')
    -- The fallback belongs to its namespace and has no picker.
    local fallback=assert(a:CreateRotationEditor(parent,268,DEFAULT or f.env.DEFAULT));fallback:Layout()
    assert(not fallback.specButton:IsShown())
end)
finish()
