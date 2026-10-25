local F=dofile('tests/fixtures/addon.lua')
local make=dofile('tests/fixtures/rotation_data.lua')
local test,finish=F.suite()
local function fixture(product,expansion,realCustom)
    local f=F.new(product,expansion);local a=f.addon;f.env.NEW='New'
    a.loadAllDefaults=true -- registers a foreign-class pack on purpose
    local frames,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    local data,envelope,validation=make();a.RotationData=data;a.conditionDefinitions=validation.conditions
    f.load('Data/catalog.lua');f.load('Data/diff.lua');f.load('Core/rotation_library.lua');local tags=io.open('Core/rotation_tags.lua');if tags then tags:close();f.load('Core/rotation_tags.lua') end
    a.GetRotationContext=function(_,spec) return {family='tbc',class='SHAMAN',level=11,spec=spec,actionContext='player',combatDataPolicy='probe'} end
    local counter=0;a.uuid=function() counter=counter+1;return 'new-'..counter end
    local pack=envelope();pack.nameKey='Twin';pack.descriptionKey='Contains % [ brackets';pack.applicability.maxLevel=19
    assert(a:RegisterDefaultRotation(pack))
    local other=envelope();other.id='other-pack';other.nameKey='Other default';other.applicability.class='MAGE'
    assert(a:RegisterDefaultRotation(other))
    a.db.profile.rotations={[0]={one={name='Twin',rotation={}},two={name='Twin',rotation={}}},[1]={third={name='Secondary custom',rotation={}}}}
    a.db.profile.enable=false;a.db.char={specs={[1]='Primary',[2]='Secondary'}};a.db.profile.itemsets={};a.db.global.effects={}
    assert(a:InitializeRotationLibrary());assert(a:SetDefaultRotationEnabled(other.id,false))
    a.Platform.GetSpellInfo=function(_,id) return {spellID=id,name='Lightning Bolt'} end
    a.Platform.GetSpellLink=function() return '|Hspell:403|h[Lightning Bolt]|h' end
    a.printCondition=function() return 'Readable condition' end
    f.load('UI/defaults.lua');f.load('UI/rotation_reference.lua');f.load('UI/settings_setup.lua')
    local nativeEditor
    if realCustom then
        a.validateCondition=function() return true end
        a.GetImportValidationOptions=function() return {conditions=a.conditionDefinitions} end
        a.UpdateAutoSwitch=function() end;a.SwitchRotation=function() end;a.EvaluateNextAction=function() end
        for _,path in ipairs({'Platform/spells.lua','Data/rotation_draft.lua','Core/rotation_editor.lua','Core/rotation_workspace.lua','Core/rotation_canvas.lua','UI/window.lua','UI/rotation_cards.lua','UI/rotation_canvas.lua','UI/color_picker.lua','UI/rotation_effect_fields.lua','UI/rotation_fields.lua','UI/rotation_navigation.lua','UI/rotation_metadata.lua','UI/rotation_view.lua','UI/rotation_editor.lua'}) do f.load(path) end
        nativeEditor=a.CreateRotationEditor
    end
    local editors={}
    -- Native pane fixture isolates the roster; the name/apply case below uses
    -- the actual native editor and the reference case uses native reference controls.
    a.CreateRotationEditor=function(self,parent,spec,id,onSelect)
        if nativeEditor then
            local pane,why=nativeEditor(self,parent,spec,id,onSelect)
            if pane then editors[#editors+1]={pane=pane,spec=spec,id=id,select=onSelect} end
            return pane,why
        end
        local pane=self:CreateConditionGroup();pane.frame:SetParent(parent);pane:SetWidth(parent:GetWidth());pane:SetHeight(parent:GetHeight())
        pane.workspace={pending=false};pane.clone={action=function()
            local builtin=self:GetDefaultIdForRuntime(spec,id);local source=self:GetEditableRotation(spec,id)
            local title=source and source.name or id;local name='Copy of '..title
            local generated=builtin and self:CloneDefaultRotation(spec,builtin,name) or self:DuplicateCustomRotation(spec,id,name)
            if generated then onSelect(spec,generated) end
        end}
        local release=pane.Release
        function pane:Release() self.released=true;self.Release=nil;return release(self) end
        editors[#editors+1]={pane=pane,spec=spec,id=id,select=onSelect}
        local builtin=self:GetDefaultIdForRuntime(spec,id)
        if builtin then self:CreateDefaultRotationOptions(pane,spec,builtin,function(generated) onSelect(spec,generated) end)
        else local label=self:CreateConditionLabel();label:SetText('custom editor');pane:AddChild(label) end
        return pane
    end
    dofile('tests/fixtures/rotation_header_backend.lua')(a,f.env.DEFAULT,f.env.NEW)
    f.load('UI/rotation_browser.lua')
    return f,pack,editors,create,frames
end
local function row(browser,key)
    for _,r in ipairs(browser.rows) do if r.key==key then return r end end
end
local function findWidget(widget,text)
    if widget.text==text then return widget end
    for _,child in ipairs(widget.children or {}) do local found=findWidget(child,text);if found then return found end end
end
test('roster preserves duplicate identities and searches literally without altering the selected editor or saved data',function()
    local f,_,editors,create=fixture();local a=f.addon
    local browser=a:CreateRotationBrowser(create('Frame'),{spec=0,id='one'})
    assert(browser.selected=='one' and row(browser,'one') and row(browser,'two'))
    local saved=a.db.profile.rotations[0].one;local pane=browser.pane;local count=#editors
    browser.search:SetText('% [');browser.search.scripts.OnTextChanged(browser.search,true)
    assert(#browser.rows==1 and browser.rows[1].kind=='builtin','search treated literal punctuation as a pattern')
    assert(browser.pane==pane and #editors==count,'filtering destroyed the unsaved selected editor')
    browser:SetFilter('custom');assert(#browser.rows==0 and browser.selected=='one')
    browser.search:SetText('');browser.search.scripts.OnTextChanged(browser.search,true)
    assert(row(browser,'one') and row(browser,'two') and not row(browser,'RM-BUILTIN:pack'))
    browser:SelectRotation(0,'two');assert(editors[#editors].id=='two' and pane.released)
    assert(a.db.profile.rotations[0].one==saved and saved.color==nil and saved.use_name==nil)
end)
test('foreign defaults are hidden while disabled current-class defaults remain inspectable and cloneable',function()
    local f,pack,editors,create=fixture();local a=f.addon
    local browser=a:CreateRotationBrowser(create('Frame'),{spec=0,id='one'})
    browser:SetFilter('builtin')
    assert(not row(browser,'RM-BUILTIN:other-pack'),'foreign class leaked into the browser')
    assert(a:SetDefaultRotationEnabled(pack.id,false));browser:RefreshRows()
    local other=assert(row(browser,'RM-BUILTIN:'..pack.id))
    assert(not other.eligible and not other.enabled and other.readOnly)
    browser:SelectRotation(0,other.key)
    assert(F.text(browser.pane):find('Disabled',1,true))
    assert(not a:GetEditableRotation(0,other.key),'reference became a custom body')
    browser:SelectRotation(0,'RM-BUILTIN:'..pack.id)
    assert(F.text(browser.pane):find('Sequential priority',1,true),'full default was not integrated')
    local clone=assert(findWidget(browser.pane,'Clone to edit'));local source=a:GetDefaultRotation(pack.id)
    clone:Fire('OnClick')
    assert(browser.selected~='RM-BUILTIN:'..pack.id and a:GetEditableRotation(0,browser.selected),'clone callback did not select the new editor')
    assert(editors[#editors].id==browser.selected)
    assert(a:GetDefaultRotation(pack.id).envelope.body.rotation[1].action==source.envelope.body.rotation[1].action)
end)
test('specializations preserve their distinct identities and missing selections fall back safely',function()
    -- The specialization menu heads the list column: Retail's specializations (with "No
    -- specialization"), Mists' specializations, a talent-group client's two talent groups.
    for _,client in ipairs({{1,12},{19,5},{5,1}}) do
        local f,_,editors,create=fixture(client[1],client[2]);local a=f.addon;f.load('Core/rotation_selection.lua')
        f.env.UnitClass=function() return 'Shaman','SHAMAN',7 end
        f.env.C_SpecializationInfo={GetNumSpecializationsForClassID=function() return 2 end}
        f.env.GetNumSpecializationsForClassID=nil
        f.env.GetSpecializationInfoForClassID=function(_,index) return index==1 and 262 or 264,index==1 and 'Elemental' or 'Restoration' end
        f.env.GetNumTalentGroups=function() return 2 end
        a.currentSpec=client[1]==1 and 262 or client[2]>=2 and 1 or 0
        local browser=a:CreateRotationBrowser(create('Frame'),{spec=999,id='missing'})
        assert(browser.spec==a.currentSpec and browser.selected=='Default')
        assert(#browser.specEntries==(client[1]==1 and 3 or 2) and browser.specFilter:IsShown() and browser.specFilter:GetParent()==browser.left)
        if client[1]==1 then assert(browser.specEntries[3].id==1444 and browser.specEntries[3].name=='No specialization') end
        if client[1]==5 then for _,entry in ipairs(browser.specEntries) do assert(entry.name:find('Primary') or entry.name:find('Secondary'),'a talent group is named like the game (or by you), never "spec '..entry.id..'"') end end
        -- Another value: where namespaces are specializations (Retail) the list reads that one.
        local other=client[1]==5 and 2 or 264
        browser:SetSpecValue(other);assert(browser.specValue==other and browser.spec==(client[1]==1 and 264 or a.currentSpec),tostring(browser.spec))
        assert(editors[#editors].spec==browser.spec)
    end
end)
test('new placeholder and selection refreshes do not recreate abandoned or released panes',function()
    local f,_,editors,create=fixture();local a=f.addon
    local browser=a:CreateRotationBrowser(create('Frame'),{spec=0,id='one'})
    local callback=editors[#editors].select
    browser.newButton:Click();local pending=browser.selected
    assert(pending~='one' and a:GetEditableRotation(0,pending)==nil,'New persisted before explicit name acceptance')
    a.db.profile.rotations[0][pending]={name='Named new',rotation={}}
    editors[#editors].select(0,pending)
    assert(row(browser,pending) and browser.selected==pending and not browser.pendingId)
    local current=browser.pane
    callback(0,'one');assert(browser.pane==current,'abandoned editor callback replaced current details')
    browser:SetWidth(768);browser:SetHeight(420)
    assert(browser.detail:GetWidth()>400 and browser.list:GetHeight()>100)
    local count=#editors;local latest=editors[count].select
    browser:Release();latest(0,'one')
    assert(browser.pane==nil and not browser.frame:IsShown() and #editors==count)
    assert(current.released,'closing browser retained pooled fields')
end)
test('native configuration reuses browser frames and releases fields across tabs and close',function()
    local f,_,_,create=fixture();local a=f.addon
    a.pretty_name='Rotation Master';a.name='rotationmaster';a.SetupOptions=function() end
    a.BuildConfigurationPane=function() error('native shell revived legacy fields') end
    f.load('UI/window.lua');f.load('UI/config.lua')
    local shell=a:ShowConfig('Rotations',{spec=0,id='one'});local browser=shell.pane
    assert(shell.nativePane and browser.selected=='one','native config still embeds the rotation dropdown')
    browser:SelectRotation(0,'two');local pane=browser.pane
    shell:SelectSection('General');assert(pane.released and not browser.active)
    shell:SelectSection('Rotations')
    assert(shell.pane==browser and browser.active and browser.selected=='two','navigation lost selection or allocated a duplicate browser')
    local current=browser.pane;local old=browser.rowButtons[1]
    shell.close:Click();assert(current.released and not browser.active and not old.scripts.OnClick)
    a:ShowConfig('Rotations',{spec=0,id='one'})
    assert(shell.pane==browser and browser.rowButtons[1]==old and browser.active and browser.selected=='one')
end)
test('the actual native name editor stages and applies a new row through the browser selection boundary',function()
    local f,_,_,create=fixture(nil,nil,true);local a=f.addon
    a.configure_frame=function() end;a.usefulCondition=function() return false end
    a.rotationValidConditions=function() return false end;a.db.profile.disable_autoswitch=true
    local browser=a:CreateRotationBrowser(create('Frame'),{spec=0,id='one'})
    browser.newButton:Click();local id=browser.selected
    assert(a:GetEditableRotation(0,id)==nil)
    local pane=browser.pane;local field=pane.name
    assert(field and pane.apply,'new rotation has no native name/apply controls')
    field:SetText('My new rotation');field.scripts.OnTextChanged(field,true)
    assert(a:GetEditableRotation(0,id)==nil,'typing persisted before Apply')
    pane.apply:Click()
    assert(a:GetEditableRotation(0,id).name=='My new rotation' and browser.selected==id)
    assert(row(browser,id).name=='My new rotation' and browser.pendingId==nil)
end)
test('missing or failing specialization metadata still permits the reference browser to open',function()
    local f,_,_,create=fixture(1,12);local a=f.addon
    f.env.GetNumSpecializationsForClassID=function() error('not ready') end
    f.env.GetSpecializationInfoForClassID=function() error('must not query invalid count') end
    local browser=a:CreateRotationBrowser(create('Frame'),{spec=262,id='missing'})
    assert(browser.spec==0 and browser.selected=='Default' and #browser.rows>=3)
    f.env.GetNumSpecializationsForClassID=function() return 2 end
    f.env.GetSpecializationInfoForClassID=nil
    browser:Release();assert(a:CreateRotationBrowser(browser.frame.parent).spec==0)
    local classic=fixture(19,5);classic.env.GetNumTalentGroups=function() return math.huge end
    local entries=classic.addon:GetRotationEditorSpecs();assert(#entries==1 and entries[1].id==0)
end)
test('a sole rotation scope has no redundant selector or reserved row',function()
    local f,_,_,create=fixture(5,1);f.addon.currentSpec=0
    local browser=f.addon:CreateRotationBrowser(create('Frame'),{spec=0,id='one'})
    -- No row between the tabs and the panes: any specialization menu sits inside the list column.
    assert(browser.specs==nil and browser.specButtons==nil and browser.left.point[5]==0 and browser.detail.point[5]==0)
    assert(browser.specFilter:GetParent()==browser.left)
end)
test('roster Duplicate clones the selection and keeps the original unchanged',function()
    local f,_,_,create=fixture();local a=f.addon;local browser=a:CreateRotationBrowser(create('Frame'),{spec=0,id='one'})
    assert(browser.duplicateButton and browser.duplicateButton.icon and browser.newButton.icon)
    browser.duplicateButton:Click();assert(browser.selected~='one' and a:GetEditableRotation(0,browser.selected).name=='Copy of Twin')
    assert(a:GetEditableRotation(0,'one').name=='Twin')
end)
test('roster Compare uses the selected rotation and is inert after release',function()
    local f,_,_,create=fixture();local a=f.addon;local compared={}
    a.ShowRotationComparison=function(_,spec,id) compared[#compared+1]={spec,id} end
    local browser=a:CreateRotationBrowser(create('Frame'),{spec=0,id='one'})
    assert(browser.compareButton,'roster has no Compare action');browser.compareButton:Click()
    assert(#compared==1 and compared[1][1]==0 and compared[1][2]=='one')
    local old=browser.compareButton.scripts.OnClick;browser:Release();old();assert(#compared==1)
end)
test('rotation sidebar uses the shared page width and compact footer captions',function()
    local f,_,_,create=fixture();local a=f.addon;local host=create('Frame');host:SetSize(1000,600);local browser=a:CreateRotationBrowser(host,{spec=0,id='one'});browser:Layout();assert(browser.left:GetWidth()==a:GetWorkbenchSidebarWidth(browser.frame:GetWidth()));assert(browser.newButton:GetText()=='New' and browser.compareButton:GetText()=='Compare')
end)
test('tag filtering and unified metadata search preserve the selected editor and saved data',function()
    local f,_,editors,create=fixture();local a=f.addon;local source=a.db.profile.rotations[0].one;source.description='Healing upkeep';source.metadata={author='PreZ',realm='Realm'};source.tags={'PVP','MyLittlePony'};local browser=a:CreateRotationBrowser(create('Frame'),{spec=0,id='one'});assert(browser.tagButton,'tag filter missing');local pane=browser.pane;local count=#editors;browser:SetTag('PVP');assert(#browser.rows==1 and browser.rows[1].key=='one');browser.search:SetText('prez');browser.search.scripts.OnTextChanged(browser.search,true);assert(#browser.rows==1 and browser.pane==pane and #editors==count);browser.search:SetText('healing');browser.search.scripts.OnTextChanged(browser.search,true);assert(#browser.rows==1);browser:SetFilter('builtin');assert(#browser.rows==0);browser:SetTag(nil);browser:SetFilter('all');browser.search:SetText('MyLittlePony');browser.search.scripts.OnTextChanged(browser.search,true);assert(#browser.rows==1 and source.tags[2]=='MyLittlePony')
end)
test('tag selector dismisses on release and stale profile callbacks cannot change filtering',function()
    local f,_,_,create=fixture();local a=f.addon;a.db.profile.rotations[0].one.tags={'PVP'};local browser=a:CreateRotationBrowser(create('Frame'),{spec=0,id='one'});browser.tagPicker:Suggest();assert(browser.tagMenu.frame:IsShown());local stale=browser.tagMenu.rows[1].scripts.OnClick;a.db.profile={rotations={[0]={}}};stale();assert(browser.tag==nil);browser:Release();assert(not browser.tagMenu.frame:IsShown())
end)
test('New clears the tag filter so its pending rotation is visible',function()
    local f,_,_,create=fixture();local a=f.addon;a.db.profile.rotations[0].one.tags={'PVP'};local browser=a:CreateRotationBrowser(create('Frame'),{spec=0,id='one'});browser:SetTag('PVP');browser.newButton:Click();assert(browser.tag==nil and row(browser,browser.selected),'new pending rotation hidden by old tag filter')
end)
test('prepackaged rotation filter is labeled Built In while default settings retain their meaning',function()
    local f,_,_,create=fixture();local browser=f.addon:CreateRotationBrowser(create('Frame'),{spec=0,id='one'})
    assert(browser.filters.builtin:GetText()=='Built In')
end)
test('shared roster tags combine Any and All without creating filter labels',function()
    local f,_,_,create=fixture();local a=f.addon;a.db.profile.rotations[0].one.tags={'PVP','Frost'};a.db.profile.rotations[0].two.tags={'PVP'}
    local b=a:CreateRotationBrowser(create('Frame'),{spec=0,id='one'});b:SetTags({'PVP','Frost'});assert(#b.rows==2)
    b.tagModeButton:Click();assert(#b.rows==1 and b.rows[1].key=='one' and b.tagMode=='all')
    b.tagPicker.input:SetText('New label');b.tagPicker.input.scripts.OnEnterPressed(b.tagPicker.input);assert(#b.selectedTags==2)
    assert(a:SetRotationTagColor('PVP',{r=.2,g=.5,b=.8,a=1}) and a:GetRotationTagColor('pvp').g==.5)
    assert(a:GetRotationTagColor('Unknown').r==1)
end)
test('tag filter text input remains visible after closing and reopening the browser',function()
    local f,_,_,create=fixture();local a=f.addon;local b=a:CreateRotationBrowser(create('Frame'),{spec=0,id='one'})
    b:Release();b:Open({spec=0,id='one'})
    assert(b.rowButtons[1].art,'rotation list bypasses shared row styling')
    assert(b.tagPicker.frame:IsShown() and b.tagPicker.input:IsShown(),'tag search remains hidden after reopening')
    assert(b.tagPicker.frame.point[3]==-56 and b.tagPicker.input.point[2]==92 and b.tagPicker.input:GetWidth()==b.left:GetWidth()-92,'tag search is not beside Any/All')
end)
test('missing native editor shows feedback without allocating a legacy rotation pane',function()
    local f,_,_,create=fixture();local a=f.addon;a.CreateRotationEditor=nil
    a.BuildRotationEditor=function() error('missing native editor revived the legacy renderer') end
    a.GetConditionWidgetCompatibilityLibrary=function() error('missing native editor requested retired GUI') end
    local browser=a:CreateRotationBrowser(create('Frame'),{spec=0,id='one'})
    assert(not browser.pane and browser.detail.rmEditorError and browser.detail.rmEditorError:IsShown())
    assert(browser.detail.rmEditorError:GetText()=='The native rotation editor is unavailable.')
    browser:Release()
end)
local function largeBrowser(n)
    local f,pack,editors,create,frames=fixture();local a=f.addon;a.db.profile.rotations[0]={}
    for i=1,n do local body={name=string.format('Entry %04d',i),switch={},rotation={},cooldowns={}};assert(a.RotationData.ValidateBody(body,{conditions=a.conditionDefinitions}).valid);a.db.profile.rotations[0]['entry-'..i]=body end
    local host=create('Frame');host:SetSize(1000,700);local browser=a:CreateRotationBrowser(host,{spec=0,id='entry-1'})
    return f,browser,editors,frames,create
end
local function visibleBrowserRow(browser,id)
    for _,control in ipairs(browser.rowButtons) do if control.browserLease and control.browserEntry.key==id then return control end end
end
test('rotation browser complete1000-row data uses bounded warm native viewport controls',function()
    local f,b,editors,frames=largeBrowser(1000);local a=f.addon;assert(#b.rows==1002 and #b.rowButtons<25,'rotation browser allocated every result')
    local pane=b.pane;local count=#editors;local observations=0;local tags=a.GetRotationTagView;a.GetRotationTagView=function(...) observations=observations+1;return tags(...) end
    for i=0,10 do b.list.workbenchBar:SetValue(b.list.workbenchBar.scrollRange*i/10) end
    local warm=#frames;for pass=1,2 do for i=10,0,-1 do b.list.workbenchBar:SetValue(b.list.workbenchBar.scrollRange*i/10) end end
    assert(#frames==warm and observations==0 and b.pane==pane and #editors==count,'scroll rebuilt library metadata, controls or the editor')
    b.list.workbenchBar:SetValue(b.list.workbenchBar.scrollRange);assert(visibleBrowserRow(b,'entry-1000'));visibleBrowserRow(b,'entry-1000'):Click();assert(b.selected=='entry-1000');b:Release()
end)
test('browser filter and recycled callbacks cannot select old rows or approve retired navigation',function()
    local f,b,editors=largeBrowser(1000);local old=visibleBrowserRow(b,'entry-2').scripts.OnClick;local pending;b.pane.RequestLeave=function(_,callback) pending=callback;return false end
    visibleBrowserRow(b,'entry-2'):Click();assert(pending);b.search:SetText('Entry 1000');b.search.scripts.OnTextChanged(b.search,true);local count=#editors
    old();pending();assert(b.selected=='entry-1' and #editors==count,'retired row or navigation reopened an old target')
    b.pane.RequestLeave=nil;visibleBrowserRow(b,'entry-1000'):Click();assert(b.selected=='entry-1000');b:Release()
end)
test('browser resize keeps invalid pending detail focus and remeasures retained labels without metadata scans',function()
    local f,b,editors,frames,create=largeBrowser(1000);local input=create('EditBox',nil,b.pane.frame);input:SetFontObject('GameFontHighlightSmall');input:SetText('bad pending input');input:SetFocus();input:SetCursorPosition(4)
    local first=visibleBrowserRow(b,'entry-1');local lease=first.browserLease;local pane=b.pane;local count=#editors;local observations=0;local tags=f.addon.GetRotationTagView;f.addon.GetRotationTagView=function(...) observations=observations+1;return tags(...) end
    b:SetWidth(700);assert(b.pane==pane and #editors==count and first.browserLease==lease and observations==0,'resize rebound the editor or rebuilt library data')
    assert(first.nameLabel:GetWidth()==first:GetWidth()-12 and first.statusLabel:GetWidth()==first:GetWidth()-12)
    assert(input:GetText()=='bad pending input' and input:HasFocus() and input:GetCursorPosition()==4)
    b:Release();local stale=first.scripts.OnClick;if stale then stale() end;assert(not b.active)
end)
test('browser approved navigation survives data refresh but not profile replacement or reopen',function()
    local f,b,editors=largeBrowser(1000);local pending;b.pane.RequestLeave=function(_,callback) pending=callback;return false end
    visibleBrowserRow(b,'entry-2'):Click();b:RefreshRows();pending();assert(b.selected=='entry-2','metadata refresh lost an approved target with unchanged filters')
    local old=visibleBrowserRow(b,'entry-3').scripts.OnClick;local profile=f.addon.db.profile;local count=#editors;f.addon.db.profile={};old();assert(b.selected=='entry-2' and #editors==count,'retired profile callback opened another editor')
    f.addon.db.profile=profile;b:Release();b:Open({spec=0,id='entry-1'});count=#editors;old();assert(b.selected=='entry-1' and #editors==count,'old browser opening selected a stale target');b:Release()
end)
test('browser binding error retires its partial row and recovers without replacing detail state',function()
    local f,b,editors=largeBrowser(1000);local stale=visibleBrowserRow(b,'entry-2').scripts.OnClick;local pane=b.pane;local select=f.addon.SetWorkbenchListSelection;local failed=false
    f.addon.SetWorkbenchListSelection=function(...) if not failed then failed=true;error('injected browser binding failure') end;return select(...) end
    local ok=pcall(b.list.workbenchBar.SetValue,b.list.workbenchBar,b.list.workbenchBar.scrollRange);assert(not ok and failed and not b.refreshing)
    f.addon.SetWorkbenchListSelection=select;b:RefreshViewport();stale();assert(visibleBrowserRow(b,'entry-1000') and b.pane==pane and b.selected=='entry-1');b:Release()
end)
-- A Retail character without a specialization runs the class's initial spec
-- (GetSpecialization() answers index 5, its own spec ID). The browser offers it
-- as "No specialization" and opens on it, so what is saved there is what RM runs.
test('Retail below level 10: the browser offers the initial spec RM runs and opens on it',function()
    local f,_,_,create=fixture(1,12);local a=f.addon
    local specs={{262,'Elemental'},{263,'Enhancement'},{264,'Restoration'},[5]={1444,'Initial'}}
    f.env.C_SpecializationInfo={GetSpecialization=function() return 5 end,GetSpecializationInfo=function(i) return specs[i][1],specs[i][2] end,
        GetNumSpecializationsForClassID=function() return 3 end}
    f.env.GetSpecializationInfoForClassID=function(_,i) local entry=specs[i];if entry then return entry[1],entry[2] end end
    f.env.UnitClass=function() return 'Shaman','SHAMAN',7 end
    a.currentSpec=assert(a.Platform:GetRotationSpecialization()).key;assert(a.currentSpec==1444)
    f.load('Core/rotation_selection.lua')
    local browser=a:CreateRotationBrowser(create('Frame'))
    assert(browser.spec==1444,'browser spec '..tostring(browser.spec))
    local labels={};for _,entry in ipairs(browser.specEntries) do labels[#labels+1]=entry.name end
    assert(table.concat(labels,',')=='Elemental,Enhancement,Restoration,No specialization',table.concat(labels,','))
    assert(browser.specValue==1444 and not browser.specWarning:IsShown(),'the menu does not start at the current specialization')
    browser:Release()
end)
test('a rotation that cannot be selected wears a red row naming its first blocking issue',function()
    local f,_,_,create=fixture();local a=f.addon;f.load('Core/rotation_selection.lua')
    local list=a.ListRotationHeaders
    a.ListRotationHeaders=function(self,spec)
        local rows,stamp=list(self,spec)
        for _,row in ipairs(rows) do if row.key=='one' then row.validationState='unresolved';row.problem={code='missing-effect',path='$.body.rotation[1].onFalse[2].effect'} end end
        return rows,stamp
    end
    local browser=a:CreateRotationBrowser(create('Frame'),{spec=0,id='one'})
    local one,two
    for _,control in ipairs(browser.rowButtons) do if control:IsShown() and control.browserEntry then
        if control.browserEntry.key=='one' then one=control elseif control.browserEntry.key=='two' then two=control end
    end end
    assert(one and one.problemText and one.problemText:find('Rotation step 1 › No 2: uses a highlight effect that no longer exists',1,true),tostring(one and one.problemText))
    -- The tooltip leads with the blocking issue, then the selection order note.
    assert(one.tooltip:sub(1,#one.problemText)==one.problemText and one.problemEdges[1]:IsShown())
    assert(two and two.problemText==nil and (two.problemEdges==nil or not two.problemEdges[1]:IsShown()))
    browser:Release()
end)
finish()
