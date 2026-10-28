-- A Built In names itself by a locale key (nameKey, "Default.<Edition>.<Class>.<Variant>.Name"). The key is
-- never a name: an export carries the display name in the exporting client's language, an import of an older
-- export that holds only the key shows the display name (or, with no translation, a readable form), and no
-- shipped Built In shows a dotted key anywhere in the transfer window.
local F=dofile('tests/fixtures/addon.lua');local make=dofile('tests/fixtures/rotation_data.lua');local test,finish=F.suite()
local KEY='Default.Retail.Monk.Brewmaster.Name'
-- The real AceLocale keeps its entries raw in the locale table; the fixture keeps them aside. Mirror them.
local function localize(f,entries)
    local L=f.libraries['AceLocale-3.0'].GetLocale()
    for key,value in pairs(f.translations) do rawset(L,key,value) end
    for key,value in pairs(entries or {}) do rawset(L,key,value) end
    return L
end
local function pack(id,nameKey)
    return {format='RotationMaster',schemaVersion=1,id=id,revision=1,nameKey=nameKey,descriptionKey='Default.Test.Description',
        applicability={families={'tbc'},actionContext='player',class='SHAMAN'},sources={{url='https://example.invalid/fixture',reviewedAt='2026-10-23'}},
        body={switch={},rotation={},cooldowns={}}}
end

test('RotationDisplayName resolves registered Built In keys and leaves everything else alone',function()
    local f=F.new();local a=f.addon;f.load('Core/rotation_library.lua')
    localize(f,{[KEY]='Blizzard Assisted with brews',['Class']='Klasse'})
    assert(a:RotationDisplayName(KEY)=='Blizzard Assisted with brews')
    assert(a:RotationDisplayName({nameKey=KEY,body={}})=='Blizzard Assisted with brews','an envelope names itself by its key')
    assert(a:RotationDisplayName({nameKey=KEY,body={name='Mine'}})=='Mine','a body name wins over the key')
    assert(a:RotationDisplayName({name=KEY})=='Blizzard Assisted with brews','a legacy body whose name is the key')
    -- A user's name is never looked up: it is not a Built In key, even when it is another locale key.
    assert(a:RotationDisplayName('Class')=='Class' and a:RotationDisplayName({body={name='Class'}})=='Class')
    assert(a:RotationDisplayName('Default.Mine.Name')=='Default.Mine.Name','a name that only looks like a key is the user\'s')
    assert(a:RotationDisplayName({nameKey='My clone',body={}})=='My clone','a clone\'s manifest carries its own name as the key')
    assert(a:RotationDisplayName(nil)==nil and a:RotationDisplayName({})==nil and a:RotationDisplayName({body={name=''}})==nil)
end)

test('a key with no translation reads as its variant, never as a dotted key',function()
    local f=F.new();local a=f.addon;f.load('Core/rotation_library.lua');localize(f)
    assert(a:RotationDisplayName({nameKey='Default.Retail.Monk.NoSuchGuide.Name',body={}})=='No Such Guide')
    assert(a:RotationDisplayName({nameKey='Default.Era.Druid.Feral.NoSuchTavernCasual.Name',body={}})=='Feral No Such Tavern Casual')
    assert(a:RotationDisplayName({nameKey='Default.MoP.Druid.Gone.Name',body={}})=='Gone')
    assert(a:RotationDisplayName({nameKey='Default.Foo.Name',body={}})=='Foo')
    -- Only an envelope's key gets this: a body name that is not registered is the user's own text.
    assert(a:RotationDisplayName({body={name='Default.Retail.Monk.Gone.Name'}})=='Default.Retail.Monk.Gone.Name')
end)

local function fixture(entries)
    local f=F.new();local a=f.addon;dofile('tests/fixtures/native_ui.lua')(f.env);local data,envelope,options=make();a.RotationData=data
    a.conditionDefinitions=options.conditions;a.db.keys={char='A - Realm'};local n=0;a.uuid=function() n=n+1;return 'transfer-'..n end
    for _,path in ipairs({'Data/catalog.lua','Data/diff.lua','Data/import_session.lua','Data/rotation_store.lua','Data/rotation_draft.lua','Core/rotation_library.lua','Core/rotation_scope.lua','Core/rotation_tags.lua','Core/imports.lua','Core/rotation_editor.lua','Core/rotation_workspace.lua','UI/settings_layout.lua','UI/settings_roster_order.lua','UI/settings_draft.lua','UI/settings_history.lua','UI/settings_ordered.lua','UI/settings_text.lua','UI/settings_form.lua','UI/settings_transfer.lua','UI/transfer.lua'}) do
        local ok=loadfile(path);if ok then f.load(path) end
    end
    localize(f,entries)
    return f,a,data,envelope
end

-- The transfer window, driven the way tests/transfer_ui.lua drives it, with a Built In registered and a codec that
-- keeps what it encoded so Decode can hand it back.
local function transfer(entries)
    local f,a,data,envelope=fixture(entries)
    local body=envelope().body;a.db.profile={rotationFallbackID='Default',rotationStore={version=1,classes={SHAMAN={[0]={mine={body=body}}}},characters={},legacy={}}}
    a.GetRotationContext=function(_,spec) return {class='SHAMAN',family='tbc',spec=spec,actionContext='player',combatDataPolicy='probe'} end
    assert(a:RegisterDefaultRotation(pack('rm.test.brewmaster',KEY)));assert(a:InitializeRotationLibrary());assert(a:BindRotationProfile())
    local runtime;for _,row in ipairs(a:ListDefaultRotations(0)) do if row.id=='rm.test.brewmaster' then runtime=row.runtimeKey end end
    local encoded={}
    a.NewRotationCodec=function() return {Encode=function(_,value) encoded[#encoded+1]=value;return 'export-'..#encoded end,
        Decode=function(_,text) local value=encoded[tonumber(text:match('^export%-(%d+)$'))] or (a.pasted and a.pasted[text]);if not value then return nil,'invalid-base64' end
            return {kind=value.nameKey and 'envelope' or 'legacy',original=text,value=data.CopyData(value)} end} end
    a.ShowComparisonReport=function() end;a.ShowNativeImportPreview=function() end
    return f,a,runtime,encoded
end

test('exporting a Built In carries its display name in the exporting client\'s language, and keeps its key',function()
    for _,case in ipairs({{'enUS','Blizzard Assisted with brews'},{'deDE','Blizzard-unterstuetzt mit Branntweinen'}}) do
        local f,a,runtime,encoded=transfer({[KEY]=case[2]});assert(runtime,'Built In not registered')
        local exported=assert(a:GetRotationExportData(0,runtime))
        assert(exported.nameKey==KEY and exported.id=='rm.test.brewmaster','the premade stays identified by its envelope')
        assert(exported.body.name==case[2],case[1]..': exported name '..tostring(exported.body.name))
        assert(a.RotationData.ValidateEnvelope(exported).valid,'the export is a valid envelope')
        assert(a:GetDefaultRotation('rm.test.brewmaster').envelope.body.name==nil,'the registered Built In was edited by exporting it')
        local d=a:ShowRotationTransfer(0,runtime)
        assert(#encoded==1 and encoded[1].body.name==case[2])
        assert(d.original:GetText()=='Original name: '..case[2],case[1]..': '..tostring(d.original:GetText()))
        assert(d.name:GetText()==case[2],case[1]..': the default new name is '..tostring(d.name:GetText()))
        assert(not tostring(d.original:GetText()):find('Default.',1,true) and not tostring(d.name:GetText()):find('Default.',1,true))
    end
end)

test('importing an older export that holds only the key shows the display name',function()
    local f,a,runtime=transfer({[KEY]='Blizzard Assisted with brews'})
    a.pasted={legacy=a.RotationData.CopyData(a:GetDefaultRotation('rm.test.brewmaster').envelope)}
    local d=a:ShowRotationTransfer(0,runtime)
    d.input:SetText('legacy');d.input.scripts.OnTextChanged(d.input,true)
    assert(d.original:GetText()=='Original name: Blizzard Assisted with brews',tostring(d.original:GetText()))
    assert(d.name:GetText()=='Blizzard Assisted with brews',tostring(d.name:GetText()))
    local saved;local apply=a.ApplyRotationImport
    a.ApplyRotationImport=function(self,session,token,spec,name,...) saved=name;return apply(self,session,token,spec,name,...) end;a.ShowConfig=function() end
    d.preview:Click();assert(d.apply:IsEnabled(),'the older export cannot be imported')
    d.destination:Click();d.apply:Click();assert(saved=='Blizzard Assisted with brews','the stored name is '..tostring(saved))
    -- A key this client has no text for is a readable name, not the key.
    a.pasted={future={format='RotationMaster',schemaVersion=1,id='rm.future',revision=1,nameKey='Default.Retail.Monk.NewVariant.Name',descriptionKey='Default.Retail.Monk.NewVariant.Description',
        applicability={families={'retail'},actionContext='player',class='MONK'},body={rotation={},cooldowns={}}}}
    d=a:ShowRotationTransfer(0,runtime);d.input:SetText('future');d.input.scripts.OnTextChanged(d.input,true)
    assert(d.original:GetText()=='Original name: New Variant',tostring(d.original:GetText()))
    assert(d.name:GetText()=='New Variant')
    assert(not tostring(d.name:GetText()):find('Default.',1,true))
end)

-- Every shipped Built In, on the real English and German locale files: the name shown is the locale's text, an
-- export of it names it by that text, and with no translation at all it still reads as words.
test('no shipped Built In shows a dotted key as its name, in English, in German, or untranslated',function()
    local corpus=dofile('tests/fixtures/default_corpus.lua');local modules=dofile('tools/builtin_modules.lua')
    local f=corpus.load(5,1,'ROGUE',{modules=false});local a=f.addon;local ids={}
    local register=a.RegisterDefaultRotation
    a.RegisterDefaultRotation=function(self,p) ids[#ids+1]=p.id;return register(self,p) end
    for _,path in ipairs(modules.paths()) do f.load(path) end
    f.load('Core/rotation_tags.lua');f.load('Core/imports.lua')
    assert(#ids>=300,#ids..' Built Ins')
    local L=f.libraries['AceLocale-3.0'].GetLocale()
    local function names(read) local out={};for _,id in ipairs(ids) do local key=a:GetDefaultRotation(id).envelope.nameKey;out[id]=read(key) end;return out end
    -- Untranslated first: the keys are not registered, so every name is the readable form.
    for _,id in ipairs(ids) do
        local shown=a:RotationDisplayName(a:GetDefaultRotation(id).envelope)
        assert(type(shown)=='string' and shown~='' and not shown:find('Default',1,true) and not shown:find('.',1,true),id..' shows '..tostring(shown))
    end
    local entries=dofile('tests/fixtures/locale_entries.lua');local english=entries.entries('enUS')
    localize(f)
    local rows=a:ListDefaultRotations(0);assert(#rows>0)
    local function check(label,text)
        for _,id in ipairs(ids) do
            local envelope=a:GetDefaultRotation(id).envelope
            local shown=a:RotationDisplayName(envelope)
            assert(shown==text[envelope.nameKey] and shown~='' and not shown:find('Default.',1,true),label..' '..id..' shows '..tostring(shown))
        end
        for _,row in ipairs(rows) do
            local exported=assert(a:GetRotationExportData(0,row.runtimeKey));local text_=text[exported.nameKey]
            assert(exported.body.name==text_ and exported.nameKey:find('^Default%.'),label..' export of '..row.id..' names it '..tostring(exported.body.name))
            assert(a.RotationData.ValidateEnvelope(exported).valid,label..' export of '..row.id..' is not a valid envelope')
        end
    end
    check('enUS',english)
    -- The German file as the client reads it: its own entries over English.
    local german=entries.entries('deDE')
    localize(f,german)
    check('deDE',german)
    local differs=0;for _,id in ipairs(ids) do local key=a:GetDefaultRotation(id).envelope.nameKey;if german[key]~=english[key] then differs=differs+1 end end
    assert(differs>0,'the German file translates no Built In name, so this proves nothing about German')
end)

finish()
