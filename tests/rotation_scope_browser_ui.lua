local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local make=dofile('tests/fixtures/rotation_data.lua')
local function body(name) return {name=name,switch={},rotation={{id='stop',type='stop',conditions={}}},cooldowns={}} end
local function ref(scope,id,owner,class) return {kind='custom',address={scope=scope,class=class or 'SHAMAN',owner=owner or (scope=='class' and 'SHAMAN' or 'A - Realm'),spec=0,id=id or 'shared'}} end
local function fixture()
    local f=F.new();local a=f.addon;local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    dofile('tests/fixtures/spell_editbox.lua')(f,create)
    for _,name in ipairs({'AceConfig-3.0','AceDBOptions-3.0','LibAboutPanel-2.0'}) do f.libraries[name]={} end
    local data,_,validation=make();a.RotationData=data;a.conditionDefinitions=validation.conditions;a.configPaneGeneration=1;f.env.NEW='New'
    a.db.keys={char='A - Realm'};a.db.global.effects={};a.db.profile={rotation_view='diagram',rotationFallbackID='Saved fallback',rotationLibrary={},
        rotationStore={version=1,classes={SHAMAN={[0]={shared={body=body('Twin')},['Saved fallback']={body=body('Class fallback')}}},MAGE={[0]={shared={body=body('Foreign')}}}},
        characters={['A - Realm']={class='SHAMAN',specs={[0]={shared={body=body('Twin')},['Saved fallback']={body=body('Character fallback')}}}},['Other - Realm']={class='SHAMAN',specs={[0]={secret={body=body('Other character')}}}}},legacy={rotations={[0]={old=body('Unassigned')}}}}}
    local n=0;a.uuid=function() n=n+1;return 'new-'..n end
    a.GetImportValidationOptions=function() return {} end;a.validateCondition=function() return true end
    a.printCondition=function() return 'Readable condition' end
    a.UpdateAutoSwitch=function() end;a.SwitchRotation=function() end;a.EvaluateNextAction=function() end
    for _,path in ipairs({'Platform/spells.lua','Data/catalog.lua','Data/diff.lua','Data/rotation_store.lua','Data/rotation_draft.lua','Core/rotation_library.lua','Core/rotation_editor.lua','Core/rotation_workspace.lua','Core/rotation_tags.lua','Core/rotation_scope.lua','Core/rotation_migration.lua','Core/rotation_canvas.lua',
        'UI/defaults.lua','UI/rotation_reference.lua','UI/settings_setup.lua','UI/rotation_cards.lua','UI/rotation_canvas.lua','UI/color_picker.lua','UI/rotation_effect_fields.lua','UI/rotation_fields.lua','UI/rotation_navigation.lua','UI/rotation_metadata.lua','UI/rotation_view.lua','UI/rotation_editor.lua','UI/rotation_browser.lua','UI/settings_layout.lua','UI/settings_roster_order.lua','UI/settings_history.lua','UI/settings_ordered.lua','UI/settings_form.lua','UI/settings_transfer.lua','UI/rotation_comparison.lua','UI/rotation_adoption.lua'}) do f.load(path) end
    a.GetRotationContext=function(_,spec) return {family='tbc',class='SHAMAN',level=11,spec=spec,actionContext='player',combatDataPolicy='probe'} end
    assert(a:InitializeRotationLibrary());assert(a:BindRotationProfile())
    a.GetEditableRotation=function() error('native UI requested a live body') end
    local parent=create('Frame');parent:SetSize(1100,760)
    return f,a,parent
end
test('native roster consumes owner-filtered headers and preserves equal IDs by full reference',function()
    local _,a,parent=fixture();local browser=a:CreateRotationBrowser(parent,{spec=0,id=ref('class')})
    assert(browser.pane.workspace.reference.address.scope=='class')
    assert(#browser.rows==4,'foreign or unassigned data leaked into the ordinary roster')
    local classKey,characterKey
    for _,row in ipairs(browser.rows) do
        assert(not row.name:find('Foreign',1,true) and not row.name:find('Other character',1,true) and not row.name:find('Unassigned',1,true))
        if row.canonicalId=='shared' then if row.scope=='class' then classKey=row.key else characterKey=row.key end end
    end
    assert(classKey and characterKey and classKey~=characterKey)
    browser:SelectRotation(0,characterKey);assert(browser.selected==characterKey and browser.pane.workspace.reference.address.scope=='character')
    browser:SetFilter('custom');assert(#browser.rows==4 and browser.selected==characterKey)
end)
test('new native draft defaults Class and saving retains its issued selection key',function()
    local _,a,parent=fixture();local browser=a:CreateRotationBrowser(parent,{spec=0,id=ref('class')})
    browser.newButton:Click();local key=browser.selected;local pane=browser.pane
    assert(pane.workspace.pending and pane.workspace.scope=='class' and key:sub(1,1)==string.char(1))
    pane.name:SetText('Fresh');pane.name.scripts.OnTextChanged(pane.name,true);pane.apply:Click()
    assert(not pane.workspace.pending and browser.selected==key and pane.workspace.reference.address.scope=='class')
    assert(a:GetRotationRecordSnapshot(0,pane.workspace.reference).body.name=='Fresh')
end)
test('both scoped fallback records protect name switch and delete controls',function()
    local _,a,parent=fixture()
    for _,scope in ipairs({'class','character'}) do
        local pane=assert(a:CreateRotationEditor(parent,0,ref(scope,'Saved fallback')))
        assert(pane.workspace.fallback and not pane.switch:IsEnabled() and not pane.delete:IsEnabled())
        assert(pane.name.mouseEnabled==false,'opaque key bypassed fallback name protection')
    end
end)
test('ownership is a staged metadata choice with Cancel shared Undo and visible changes',function()
    local _,a,parent=fixture();local browser=a:CreateRotationBrowser(parent,{spec=0,id=ref('class')});local pane=browser.pane
    pane.info:Click();local dialog=pane.metadataWindow
    assert(dialog.fields.scope and dialog.fields.scope:GetText()=='Class')
    dialog.fields.scope:Click();dialog.scopeMenu.rows[2]:Click()
    assert(pane.scopeDirty and pane.workspace.scope=='class' and not pane.workspace:IsDirty())
    dialog.cancel:Click();assert(not pane.scopeDirty and pane.workspace.scope=='class' and not pane:HasUnsavedChanges())
    pane.info:Click();dialog.fields.scope:Click();dialog.scopeMenu.rows[2]:Click();dialog.apply:Click()
    assert(pane.workspace.scope=='character' and pane.workspace:IsDirty() and pane.info.rmUnsaved)
    local _,pending=pane:ReviewSnapshot();assert(#pending==1 and pending[1].label=='Applies to' and pending[1].before=='Class' and pending[1].after=='This character')
    pane.undo:Click();assert(pane.workspace.scope=='class' and not pane:HasUnsavedChanges())
    pane.redo:Click();assert(pane.workspace.scope=='character' and pane:HasUnsavedChanges())
    local ok,why=pane:Apply();assert(not ok and why=='rotation-id-collision' and pane.workspace:IsDirty())
    assert(a:GetRotationRecordSnapshot(0,ref('class')).body.name=='Twin' and a:GetRotationRecordSnapshot(0,ref('character')).body.name=='Twin')
end)
test('successful scope move rebinds selection and retires old card and name callbacks',function()
    local _,a,parent=fixture();local _,token=a:GetRotationRecordSnapshot(0,ref('character'));assert(a:DeleteRotationRecord(ref('character'),token))
    local browser=a:CreateRotationBrowser(parent,{spec=0,id=ref('class')});local pane=browser.pane;local old=browser.selected
    local stale=pane.name.scripts.OnTextChanged
    assert(pane:Command('SetOwnership','character'));assert(pane:Apply())
    assert(browser.selected~=old and browser.selected==pane.workspace.id and pane.workspace.reference.address.scope=='character')
    stale(pane.name,true);assert(not pane.nameDirty and not pane:HasUnsavedChanges())
    assert(not a:ResolveRotationReference(0,old),'moved source key remained a selection authority')
end)
test('deletion warning captures complete record authority and rejects a changed target',function()
    local _,a,parent=fixture();local pane=assert(a:CreateRotationEditor(parent,0,ref('class')))
    pane:ConfirmDelete();local prompt=pane.deletePrompt
    local record,token=a:GetRotationRecordSnapshot(0,ref('class'));record.body.name='Replaced outside the editor'
    assert(a:CommitRotationDraft(ref('class'),token,record,'class'))
    prompt.confirm:Click()
    assert(a:GetRotationRecordSnapshot(0,ref('class')).body.name=='Replaced outside the editor')
    assert(not pane.deleted and prompt.frame:IsShown())
end)
test('deleting a draft ownership move targets the original saved record only',function()
    local _,a,parent=fixture();local pane=assert(a:CreateRotationEditor(parent,0,ref('class')))
    assert(pane:Command('SetOwnership','character'));pane:ConfirmDelete();pane.deletePrompt.confirm:Click()
    assert(not a:GetRotationRecordSnapshot(0,ref('class')) and a:GetRotationRecordSnapshot(0,ref('character')).body.name=='Twin')
end)
test('browser recovery adopts explicitly and selects the complete destination reference',function()
    local _,a,parent=fixture();local browser=a:CreateRotationBrowser(parent,{spec=0,id=ref('class')})
    assert(browser.recoveryButton:IsShown());browser.recoveryButton:Click();local window=a.rotationAdoptionWindow
    assert(window.frame:IsShown());window.form.fields.character:Click();window.form.fields.adopt:Click()
    assert(not window.frame:IsShown() and browser.pane.workspace.reference.address.scope=='character')
    assert(browser.pane.workspace.canonicalId=='old' and browser.pane.workspace:Snapshot().name=='Unassigned')
    assert(not browser.recoveryButton:IsShown())
end)
test('deleting the active exact owner resets manual selection without touching its equal-ID peer',function()
    local _,a,parent=fixture();local browser=a:CreateRotationBrowser(parent,{spec=0,id=ref('class')})
    a.currentRotation=browser.selected;a.manualRotation=true;local cleared=0;a.RemoveAllCurrentGlows=function() cleared=cleared+1 end
    browser.pane:ConfirmDelete();browser.pane.deletePrompt.confirm:Click()
    assert(not a.currentRotation and not a.manualRotation and cleared==1)
    assert(a:GetRotationRecordSnapshot(0,ref('character')).body.name=='Twin')
end)
test('moving the active manual rotation retargets its new exact owner key',function()
    local _,a,parent=fixture();local _,token=a:GetRotationRecordSnapshot(0,ref('character'));assert(a:DeleteRotationRecord(ref('character'),token))
    local browser=a:CreateRotationBrowser(parent,{spec=0,id=ref('class')});local pane=browser.pane
    a.currentRotation=browser.selected;a.manualRotation=true
    assert(pane:Command('SetOwnership','character'));assert(pane:Apply())
    assert(a.manualRotation and a.currentRotation==browser.selected and a:ResolveRotationReference(0,a.currentRotation).address.scope=='character')
end)
test('eligible Built In headers and native row status agree with runtime policy',function()
    local _,a,parent=fixture();local _,envelope=make();assert(a:RegisterDefaultRotation(envelope()));assert(a:InitializeRotationLibrary());assert(a:ListDefaultRotations(0)[1].eligible)
    local browser=a:CreateRotationBrowser(parent,{spec=0,id=ref('class')});local found
    for _,control in ipairs(browser.rowButtons) do if control.browserEntry and control.browserEntry.kind=='builtin' then
        found=true;assert(control.browserEntry.eligible and not control.statusLabel:GetText():find('Not available',1,true))
    end end
    assert(found,'eligible Built In row was hidden')
end)
test('header roster stamps remain private UI state rather than native label text',function()
    local _,a,parent=fixture();local browser=a:CreateRotationBrowser(parent,{spec=0,id=ref('class')})
    assert(type(browser.rosterStamp)=='table' and not browser.loadError)
    assert(type(browser.empty:GetText())=='string')
    browser.search:SetText('No such rotation');browser.search:GetScript('OnTextChanged')(browser.search,true)
    assert(#browser.rows==0 and browser.empty:GetText()=='No rotations match this search.')
end)
finish()
