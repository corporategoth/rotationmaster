local F=dofile('tests/fixtures/addon.lua')
local make=dofile('tests/fixtures/rotation_data.lua')
local test,finish=F.suite()
local function fixture(product,expansion,realCustom)
    local f=F.new(product,expansion);local a=f.addon;f.env.NEW='New'
    local frames,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    local ace=f.libraries['AceGUI-3.0'];local original=ace.Create
    ace.Create=function(self,kind)
        local w=original(self,kind);w.frame=create('Frame');w.frame:Hide()
        function w:ReleaseChildren() self.children={} end
        for _,method in ipairs({'PauseLayout','ResumeLayout','DoLayout','SetTree','SetStatusTable','SetPoint'}) do w[method]=function() end end
        return w
    end
    ace.Release=function(_,w) w.released=true;w.frame:Hide();w.children={} end
    f.env.LibStub=setmetatable({GetLibrary=function() return {} end},{__call=function(_,name) return f.libraries[name] or {} end})
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
    f.load('UI/defaults.lua');f.load('UI/rotation_reference.lua');f.load('Options/general.lua')
    local real=a.BuildRotationEditor
    local editors={}
    a.BuildRotationEditor=function(self,pane,spec,id,onSelect)
        editors[#editors+1]={pane=pane,spec=spec,id=id,select=onSelect}
        if realCustom or self:GetDefaultIdForRuntime(spec,id) then return real(self,pane,spec,id,onSelect) end
        pane:AddChild(f.widget('custom editor'))
    end
    f.load('UI/rotation_browser.lua')
    return f,pack,editors,create
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
test('disabled and inapplicable defaults remain inspectable and clone into the same browser',function()
    local f,pack,editors,create=fixture();local a=f.addon
    local browser=a:CreateRotationBrowser(create('Frame'),{spec=0,id='one'})
    browser:SetFilter('builtin')
    local other=assert(row(browser,'RM-BUILTIN:other-pack'))
    assert(not other.eligible and not other.enabled and other.readOnly)
    browser:SelectRotation(0,other.key)
    assert(F.text(browser.pane):find('Different class',1,true) or F.text(browser.pane):find('Disabled',1,true))
    assert(not a:GetEditableRotation(0,other.key),'reference became a custom body')
    browser:SelectRotation(0,'RM-BUILTIN:'..pack.id)
    assert(F.text(browser.pane):find('Sequential priority',1,true),'full default was not integrated')
    local clone=assert(findWidget(browser.pane,'Clone to edit'));local source=a:GetDefaultRotation(pack.id)
    clone.callbacks.OnClick()
    assert(browser.selected~='RM-BUILTIN:'..pack.id and a:GetEditableRotation(0,browser.selected),'clone callback did not select the new editor')
    assert(editors[#editors].id==browser.selected)
    assert(a:GetDefaultRotation(pack.id).envelope.body.rotation[1].action==source.envelope.body.rotation[1].action)
end)
test('specializations preserve their distinct identities and missing selections fall back safely',function()
    for _,client in ipairs({{1,12},{19,5},{5,1}}) do
        local f,_,editors,create=fixture(client[1],client[2]);local a=f.addon
        f.env.UnitClass=function() return 'Shaman','SHAMAN',7 end
        f.env.C_SpecializationInfo={GetNumSpecializationsForClassID=function() return 2 end}
        f.env.GetNumSpecializationsForClassID=nil
        f.env.GetSpecializationInfoForClassID=function(_,index) return index==1 and 262 or 264,index==1 and 'Elemental' or 'Restoration' end
        f.env.GetNumTalentGroups=function() return 2 end
        a.currentSpec=client[1]==1 and 262 or client[2]>=2 and 1 or 0
        local browser=a:CreateRotationBrowser(create('Frame'),{spec=999,id='missing'})
        assert(browser.spec==a.currentSpec and browser.selected=='Default')
        assert(#browser.specButtons==(client[2]>=2 and 2 or 1))
        if #browser.specButtons>1 then browser.specButtons[2]:Click();assert(browser.spec==(client[1]==1 and 264 or 2)) end
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
    a.BuildConfigurationPane=function(_,pane) pane:AddChild(f.widget('general controls')) end
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
test('the actual legacy name editor commits a new row through the browser selection boundary',function()
    local f,_,_,create=fixture(nil,nil,true);local a=f.addon
    a.configure_frame=function() end;a.usefulCondition=function() return false end
    a.rotationValidConditions=function() return false end;a.db.profile.disable_autoswitch=true
    local browser=a:CreateRotationBrowser(create('Frame'),{spec=0,id='one'})
    browser.newButton:Click();local id=browser.selected
    assert(a:GetEditableRotation(0,id)==nil)
    local field
    local function scan(w)
        if w.kind=='EditBox' and w.label=='Name' then field=w end
        for _,child in ipairs(w.children) do scan(child) end
    end
    scan(browser.pane);assert(field,'new rotation has no name editor')
    field.callbacks.OnEnterPressed(field,nil,'My new rotation')
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
    assert(not browser.specButtons[1]:IsShown() and browser.left.point[5]==0 and browser.detail.point[5]==0)
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
finish()
