-- Which selection of the Rotations list can an import replace, and what the import window does for each: a custom
-- rotation can be replaced (checkable and uncheckable at will); a Built In, the Default that was never saved, and a
-- new unsaved rotation cannot (Replace unticked and disabled, Preview works). Looked at in the fixtures exactly as
-- UI/rotation_browser.lua opens it: ShowRotationTransfer(spec, the selected key).
local F=dofile('tests/fixtures/addon.lua');local make=dofile('tests/fixtures/rotation_data.lua');local test,finish=F.suite()

local function fixture(product)
    local f=F.new(product);local a=f.addon;local frames,create=dofile('tests/fixtures/native_ui.lua')(f.env);f.nativeFrames=frames
    dofile('tests/fixtures/spell_editbox.lua')(f,create)
    local data,envelope,options=make();a.RotationData=data
    a.conditionDefinitions=options.conditions;a.db.keys={char='A - Realm'};local n=0;a.uuid=function() n=n+1;return 'preview-'..n end
    function a:GetImportValidationOptions() return {} end
    function a:validateCondition() return true end
    a.UpdateAutoSwitch=function() end;a.SwitchRotation=function() end;a.EvaluateNextAction=function() end
    for _,path in ipairs({'Platform/spells.lua','Data/catalog.lua','Data/diff.lua','Data/visual_comparison.lua','Data/import_session.lua','Data/rotation_store.lua','Data/rotation_draft.lua','Core/rotation_library.lua','Core/rotation_scope.lua','Core/imports.lua','Core/transfer_formats.lua','Core/rotation_editor.lua','Core/rotation_workspace.lua','Core/rotation_tags.lua','Core/rotation_canvas.lua','UI/window.lua','UI/settings_layout.lua','UI/settings_roster_order.lua','UI/settings_draft.lua','UI/settings_history.lua','UI/settings_ordered.lua','UI/settings_form.lua','UI/settings_transfer.lua','UI/rotation_reference.lua','UI/rotation_comparison.lua','UI/transfer.lua','UI/transfer_format.lua'}) do f.load(path) end
    for _,file in ipairs({'UI/rotation_cards.lua','UI/rotation_canvas.lua','UI/color_picker.lua','UI/rotation_effect_fields.lua','UI/rotation_fields.lua','UI/rotation_navigation.lua','UI/rotation_metadata.lua','UI/rotation_view.lua','UI/rotation_editor.lua','UI/unsaved.lua','UI/draft_change_controls.lua','UI/help.lua'}) do local h=io.open(file);if h then h:close();f.load(file) end end
    local body=envelope().body;body.rotation={{id='branch',type='branch',conditions={},onTrue={{id='yes',type='spell',action=403,conditions={type='SPELL_KNOWN',spell=403}}},onFalse={{id='no',type='stop',conditions={}}}}}
    body.cooldowns={{id='optional',type='spell',action=324,conditions={}}}
    a.db.profile={rotationFallbackID='Default',rotationStore={version=1,classes={SHAMAN={[0]={mine={body=body}}}},characters={},legacy={}}}
    a.GetRotationContext=function(_,spec) return {class='SHAMAN',family='tbc',spec=spec,actionContext='player',combatDataPolicy='probe'} end;assert(a:BindRotationProfile())
    a.GetEditableRotation=function() error('ordinary transfer used mutable getter') end
    local incoming=data.CopyData(body);incoming.name='Incoming';incoming.priority=7;incoming.description='What it does'
    incoming.rotation[1].onTrue[1].action=974;incoming.rotation[1].onTrue[1].conditions={type='SPELL_KNOWN',spell=974}
    local wire={incoming=incoming}
    a.NewRotationCodec=function() return {Encode=function() return 'export-text' end,Decode=function(_,text)
        if text=='bad' then return nil,'invalid-base64' end
        if text=='future' then local value=envelope();value.futureMetadata={coefficient=42};return {kind='envelope',original=text,value=value} end
        if text=='envelope' then local value=envelope();value.body.name='Packaged';return {kind='envelope',original=text,value=value} end
        if text=='scalar' then return {kind='legacy',original=text,value=7} end
        return {kind='legacy',original=text,value=data.CopyData(wire[text])}
    end} end
    a.ShowComparisonReport=function(_,text) return text end
    a.printCondition=function() return 'Readable conditions' end
    a.ShowConfig=function() end
    return f,a,data,body,wire
end
local function reference(a) return 'mine' end
local function paste(d,text) d.input:SetText(text);d.input.scripts.OnTextChanged(d.input,true) end
local function counts(a)
    local compared=0;local native=a.ShowNativeImportPreview
    a.ShowNativeImportPreview=function(...) compared=compared+1;return native(...) end
    return function() return compared end
end
local function same(x,y,seen)
    if type(x)~=type(y) then return false end
    if type(x)=='function' or type(x)=='userdata' then return true end
    if type(x)~='table' then return x==y end
    seen=seen or {};if seen[x] then return true end;seen[x]=true
    for k,v in pairs(x) do if not same(v,y[k],seen) then return false end end
    for k in pairs(y) do if x[k]==nil then return false end end
    return true
end
local function diff(x,y,path,out,seen)
    path=path or '';out=out or {};seen=seen or {}
    if type(x)~=type(y) then out[#out+1]=path..': '..type(x)..' vs '..type(y);return out end
    if type(x)=='function' or type(x)=='userdata' then return out end
    if type(x)~='table' then if x~=y then out[#out+1]=path..': '..tostring(x)..' vs '..tostring(y) end;return out end
    if seen[x] then return out end;seen[x]=true
    for k,v in pairs(x) do diff(v,y[k],path..'.'..tostring(k),out,seen) end
    for k in pairs(y) do if x[k]==nil then out[#out+1]=path..'.'..tostring(k)..' added' end end
    return out
end
local function clone(x,seen)
    if type(x)~='table' then return x end
    seen=seen or {};if seen[x] then return seen[x] end
    local result={};seen[x]=result;for k,v in pairs(x) do result[k]=clone(v,seen) end;return result
end
local function cardIds(pane) local ids={};for _,card in ipairs(pane.canvas.scene.cards) do ids[card.id]=card end;return ids end

-- A Built In, registered the way the library does it; its key is what the Rotations list passes.
local function builtin(a)
    local pack={format='RotationMaster',schemaVersion=1,id='rm.test.pack',revision=1,nameKey='Test Pack',descriptionKey='Test pack description',
        applicability={families={'tbc'},actionContext='player',class='SHAMAN'},sources={{url='https://example.invalid/fixture',reviewedAt='2026-10-23'}},
        body={switch={},rotation={{id='s1',type='stop',conditions={}}},cooldowns={}}}
    assert(a:RegisterDefaultRotation(pack));assert(a:InitializeRotationLibrary());assert(a:BindRotationProfile())
    for _,row in ipairs(a:ListDefaultRotations(0)) do if row.id=='rm.test.pack' then return row.runtimeKey end end
end
local function pending(a) local reference,key=assert(a:NewRotationDraftTarget(0));return key,reference end

local f_default
local SELECTIONS={
    {name='a Built In',replaceable=false,open=function(a) return builtin(a) end},
    {name='a new unsaved rotation',replaceable=false,open=function(a) return (pending(a)) end},
    {name='the Default that was never saved',replaceable=false,open=function(a) return f_default end},
    {name='a custom rotation',replaceable=true,open=function(a) return 'mine' end},
    {name='the Default once it is saved',replaceable=true,open=function(a)
        local reference=assert(a:NewRotationDraftTarget(0,'class',true));local body=a.RotationData.CopyData(a.db.profile.rotationStore.classes.SHAMAN[0].mine.body);body.name='Default'
        assert(a:CommitRotationDraft(reference,nil,{body=body},'class'));return f_default end},
}
local function windows(a) local p=a.rotationTransferForm;return p.importPreview and p.importPreview.frame:IsShown(),p.importContent and p.importContent.frame:IsShown() end

for _,case in ipairs(SELECTIONS) do
    test('selection: '..case.name..' -- label, checkbox, preview and import follow one mode',function()
        local f,a=fixture();f_default=f.env.DEFAULT
        local id=case.open(a);assert(id~=nil,'no key for '..case.name)
        local d=a:ShowRotationTransfer(0,id)
        if case.replaceable then
            assert(d.mode=='replace' and d.destination:GetChecked() and d.destination:IsEnabled() and d.preview:GetText()=='Compare import','mode '..tostring(d.mode))
        else
            assert(d.mode=='new' and not d.destination:GetChecked() and not d.destination:IsEnabled() and d.preview:GetText()=='Preview import','mode '..tostring(d.mode)..' checked '..tostring(d.destination:GetChecked())..' enabled '..tostring(d.destination:IsEnabled())..' label '..tostring(d.preview:GetText()))
        end
        -- Preview/Compare in the initial mode.
        paste(d,'incoming');d.preview:Click()
        local compared,previewed=windows(a)
        if case.replaceable then assert(compared and not previewed,'replace mode must compare') else assert(previewed and not compared,'a selection that cannot be replaced must open the single preview, never the comparison; status: '..tostring(d.status:GetText())) end
        assert(d.apply:IsEnabled(),'a ready import enables Import: '..tostring(d.status:GetText()))
        -- Toggle at will, twice, and preview in the other mode.
        d.destination:Click()
        if case.replaceable then
            assert(d.mode=='new' and not d.destination:GetChecked() and d.preview:GetText()=='Preview import');d.preview:Click();compared,previewed=windows(a);assert(previewed and not compared)
            d.destination:Click();assert(d.mode=='replace' and d.destination:GetChecked() and d.preview:GetText()=='Compare import');d.preview:Click();compared,previewed=windows(a);assert(compared and not previewed)
            d.destination:Click();assert(d.mode=='new' and d.preview:GetText()=='Preview import','third toggle')
        else
            assert(d.mode=='new' and not d.destination:GetChecked() and d.preview:GetText()=='Preview import','a disabled checkbox must not flip the mode');d.preview:Click();compared,previewed=windows(a);assert(previewed and not compared)
        end
    end)
end

test('Import after a new-copy preview creates a new copy and leaves the selected rotation alone, for every selection',function()
    for _,case in ipairs(SELECTIONS) do
        local f,a=fixture();f_default=f.env.DEFAULT;local id=case.open(a);local d=a:ShowRotationTransfer(0,id)
        if case.replaceable then d.destination:Click() end
        local before={};for key,record in pairs(a.db.profile.rotationStore.classes.SHAMAN[0]) do before[key]=record.body.name end
        paste(d,'incoming');d.preview:Click();assert(d.apply:IsEnabled(),case.name)
        d.name:SetText('Saved copy');d.name.scripts.OnTextChanged(d.name,true);d.apply:Click()
        local copies,others=0,0
        for key,record in pairs(a.db.profile.rotationStore.classes.SHAMAN[0]) do if record.body.name=='Saved copy' then copies=copies+1 elseif before[key]~=record.body.name then others=others+1 end end
        assert(copies==1 and others==0,case.name..': copies '..copies..' changed '..others)
    end
end)
test('Import after a compare replaces the saved Default in place, not a copy',function()
    local f,a=fixture();local store=a.db.profile.rotationStore.classes.SHAMAN[0]
    local reference=assert(a:NewRotationDraftTarget(0,'class',true));local body=a.RotationData.CopyData(store.mine.body);body.name='Default';assert(a:CommitRotationDraft(reference,nil,{body=body},'class'))
    local d=a:ShowRotationTransfer(0,f.env.DEFAULT);assert(d.mode=='replace' and d.destination:IsEnabled() and d.preview:GetText()=='Compare import')
    paste(d,'incoming');d.preview:Click();assert(d.apply:IsEnabled());d.apply:Click()
    local n=0;for _ in pairs(store) do n=n+1 end;assert(n==2 and store.Default.body.priority==7,'the Default was not replaced in place')
end)
test('a stale transfer window says so instead of doing nothing, and an error in Preview reaches the status line',function()
    local f,a=fixture();local d=a:ShowRotationTransfer(0,'mine');paste(d,'incoming')
    a.NewRotationPreviewWorkspace=function() error('injected failure') end;d.destination:Click();d.preview:Click()
    assert(d.status:GetText():find('injected failure',1,true) or d.status:GetText():find('cannot be shown',1,true),tostring(d.status:GetText()))
    a.db.profile={};d.status:SetText('');d.destination:Click();assert(d.status:GetText():find('out of date',1,true),tostring(d.status:GetText()))
    d.status:SetText('');d.preview:Click();assert(d.status:GetText():find('out of date',1,true),tostring(d.status:GetText()))
end)
test('Import after a compare replaces exactly the selected custom rotation',function()
    local f,a=fixture();local d=a:ShowRotationTransfer(0,'mine');paste(d,'incoming');d.preview:Click();assert(d.mode=='replace' and d.apply:IsEnabled())
    d.apply:Click();local record=a.db.profile.rotationStore.classes.SHAMAN[0].mine;assert(record and record.body.priority==7 and record.body.description=='What it does','the selected rotation was not replaced')
    local n=0;for _ in pairs(a.db.profile.rotationStore.classes.SHAMAN[0]) do n=n+1 end;assert(n==1,'replacing created a second rotation')
end)
finish()
