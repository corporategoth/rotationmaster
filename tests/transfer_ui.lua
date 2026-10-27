local F=dofile('tests/fixtures/addon.lua');local make=dofile('tests/fixtures/rotation_data.lua');local test,finish=F.suite()
test('shared native rotation transfer invalidates previews and applies copy or selected replacement explicitly',function()
    local f=F.new();local a=f.addon;dofile('tests/fixtures/native_ui.lua')(f.env);local data,envelope,options=make();a.RotationData=data
    a.conditionDefinitions=options.conditions;a.db.keys={char='A - Realm'};local n=0;a.uuid=function() n=n+1;return 'transfer-'..n end
    for _,path in ipairs({'Data/catalog.lua','Data/diff.lua','Data/import_session.lua','Data/rotation_store.lua','Data/rotation_draft.lua','Core/rotation_library.lua','Core/rotation_scope.lua','Core/imports.lua','Core/rotation_editor.lua','Core/rotation_workspace.lua','UI/settings_layout.lua','UI/settings_roster_order.lua','UI/settings_draft.lua','UI/settings_history.lua','UI/settings_ordered.lua','UI/settings_form.lua','UI/settings_transfer.lua','UI/rotation_comparison.lua','UI/transfer.lua'}) do f.load(path) end
    local body=envelope().body;a.db.profile={rotationFallbackID='Default',rotationStore={version=1,classes={SHAMAN={[0]={mine={body=body}}}},characters={},legacy={}}}
    a.GetRotationContext=function(_,spec) return {class='SHAMAN',family='tbc',spec=spec,actionContext='player',combatDataPolicy='probe'} end;assert(a:BindRotationProfile())
    a.GetEditableRotation=function() error('ordinary transfer used mutable getter') end
    a.NewRotationCodec=function() return {Encode=function() return 'export-text' end,Decode=function(_,text)
        if text=='bad' then return nil,'invalid-base64' end
        if text=='future' then local incoming=envelope();incoming.futureMetadata={coefficient=42};return {kind='envelope',original=text,value=incoming} end
        local incoming=data.CopyData(body);incoming.rotation[1].action=974;return {kind='legacy',original=text,value=incoming}
    end} end
    local renders,applied,target=0,0,nil;a.ShowComparisonReport=function(_,text) return text end;a.ShowNativeImportPreview=function(_,_,view) renders=renders+1;assert(view.right.body.rotation[1].action==974 or view.right.body.rotation[1].action==403) end
    local apply=a.ApplyRotationImport
    a.ApplyRotationImport=function(self,session,token,spec,name,selected,expected,settings) assert(session:GetReady(token) and spec==0 and name~='');local id,why,reference=apply(self,session,token,spec,name,selected,expected,settings);if id then applied=applied+1;target=selected end;return id,why,reference end;a.ShowConfig=function(_,section) assert(section=='Rotations') end
    local d=a:ShowRotationTransfer(0,'mine');assert(d.destination:GetChecked() and d.original and d.name and not d.apply:IsEnabled());d.copy:Click();assert(d.input.focused and d.input.selection[2]==-1)
    d.input:SetText('incoming');d.input.scripts.OnTextChanged(d.input,true);assert(renders==0);d.preview:Click();assert(renders==1 and d.apply:IsEnabled())
    d.clear:Click();assert(d.input:GetText()=='' and not d.apply:IsEnabled());d.apply:Click();assert(applied==0)
    d.input:SetText('bad');d.input.scripts.OnTextChanged(d.input,true);assert(not d.apply:IsEnabled());d.apply:Click();assert(applied==0);d.preview:Click();assert(not d.apply:IsEnabled())
    d.input:SetText('future');d.input.scripts.OnTextChanged(d.input,true);d.preview:Click();assert(not d.apply:IsEnabled());local details=d.inspect.scripts.OnClick();assert(details:find('futureMetadata',1,true))
    d.input:SetText('incoming');d.input.scripts.OnTextChanged(d.input,true);d.preview:Click();d.destination:Click();d.name:SetText('Copy');d.name.scripts.OnTextChanged(d.name,true);d.apply:Click();assert(applied==1 and not target and not d.frame:IsShown() and body.rotation[1].action==403)
    d=a:ShowRotationTransfer(0,'mine');d.preview:Click();d.apply:Click();assert(applied==2 and target.kind=='custom' and target.address.scope=='class' and target.address.id=='mine' and a:GetRotationRecordSnapshot(0,target).body.rotation[1].action==974)
end)
test('shared transfer shell keeps moved coordinates while its text and themed context refresh',function()
    local f=F.new();local a=f.addon;dofile('tests/fixtures/native_ui.lua')(f.env);f.load('UI/settings_transfer.lua')
    local d=a:CreateWorkbenchTransferShell(570,430);local started,stopped=0,0
    function d.frame:StartMoving() started=started+1 end;function d.frame:StopMovingOrSizing() stopped=stopped+1 end
    local drag=assert(d.chrome.drag,'transfer/output shell omitted common title dragging')
    drag:GetScript('OnDragStart')(drag,'LeftButton');d.frame:SetPoint('BOTTOMLEFT',f.env.UIParent,'BOTTOMLEFT',210,175);drag:GetScript('OnDragStop')(drag)
    d.input:SetText('Copyable output');d.chrome:SetContext('Output','Output','');d.scroll:UpdateWorkbenchScroll()
    assert(started==1 and stopped==1 and d.frame.point[4]==210 and d.frame.point[5]==175)
    assert(d.close:GetParent()==d.frame and d.input:GetParent()==d.scroll and not d.input.drags,'dragging changed close or editable text ownership')
end)
local function previewFixture()
    local f=F.new();local a=f.addon;a.RotationData=make()
    for _,path in ipairs({'Data/diff.lua','Data/visual_comparison.lua','UI/rotation_reference.lua','UI/rotation_comparison.lua','UI/transfer.lua'}) do f.load(path) end
    a.Platform={GetSpellInfo=function(_,id) return {name='Spell '..id,spellID=id,iconID=id} end,
        GetSpellLink=function(_,id) return '|Hspell:'..id..'|h[Named spell]|h' end}
    a.printCondition=function() return 'Readable conditions' end
    local left={body={rotation={{id='step',type='spell',action=403,conditions={}}}}}
    local right={body={rotation={{id='step',type='spell',action=8042,conditions={}}}}}
    local view={key='import',left=left,right=right,diff=a.RotationData.DiffRotations(left,right)}
    return f,a,{cleanups={},generation=1},view
end
test('actual import preview renders native comparison content and releases it on close',function()
    local f,a,p,view=previewFixture();local old=f.env.LibStub
    f.env.LibStub=function(name,...) assert(name~='AceGUI-3.0','import preview requested retired GUI');return old(name,...) end
    local d=a:ShowNativeImportPreview(p,view,0)
    assert(d.frame:GetFrameStrata()=='FULLSCREEN_DIALOG','preview can hide beneath main configuration')
    assert(d.graph.type=='RM-ConditionGroup' and d.scroll.contentWidget==d.graph,'preview omitted native group viewport')
    assert(d.graph.frame:GetParent()==d.scroll and d.scroll:GetScrollChild()==d.graph.frame)
    assert(F.text(d.graph):find('Always',1,true) and F.text(d.graph):find('Incoming rotation',1,true),'real comparison content missing')
    local root=d.graph;d.close:Click();assert(not d.frame:IsShown() and not root.rmActive and not d.graph and not d.scroll.contentWidget)
end)
test('cached import preview reopens with a fresh root lease and old cleanup cannot hide it',function()
    local _,a,p,view=previewFixture();view.left={body={rotation={}}};view.right={body={rotation={}}};view.diff=a.RotationData.DiffRotations(view.left,view.right)
    local d=a:ShowNativeImportPreview(p,view,0);local root=d.graph;local lease=root.rmLease;local old=p.cleanups[1]
    d.frame:SetPoint('BOTTOMLEFT',210,175);d.close:Click()
    local reopened=a:ShowNativeImportPreview(p,view,0)
    assert(reopened==d and d.graph==root and root.rmLease~=lease,'dialog or native root did not recycle')
    assert(d.frame.point[1]=='BOTTOMLEFT' and d.frame.point[2]==210,'reopen discarded moved coordinates')
    old();assert(d.frame:IsShown() and root.rmActive,'retired import cleanup closed the newer preview')
    p.generation=p.generation+1;p.cleanups[#p.cleanups]();assert(not d.frame:IsShown() and not root.rmActive,'generation advance prevented current cleanup')
end)
test('import cleanup cannot release a preview root that another native owner has borrowed',function()
    local _,a,p,view=previewFixture();view.left={body={rotation={}}};view.right={body={rotation={}}};view.diff=a.RotationData.DiffRotations(view.left,view.right)
    local d=a:ShowNativeImportPreview(p,view,0);local root=d.graph
    a:ReleaseConditionWidget(root);local borrowed=a:CreateConditionGroup();assert(borrowed==root);borrowed:SetWidth(222)
    local finished=function() end;borrowed.LayoutFinished=finished
    d.frame:Hide();assert(borrowed.rmActive and borrowed.LayoutFinished==finished and borrowed.frame:GetWidth()==222,'preview cleanup corrupted a new root lease')
    a:ReleaseConditionWidget(borrowed)
end)
test('failed native import rendering releases its partially populated root',function()
    local _,a,p,view=previewFixture();local root
    a.RenderRotationComparison=function(_,graph)
        root=graph;local label=a:CreateConditionLabel();label:SetText('Partial preview');graph:AddChild(label)
        error('injected import rendering failure')
    end
    local ok,why=pcall(a.ShowNativeImportPreview,a,p,view,0)
    assert(not ok and why:find('injected import rendering failure',1,true))
    assert(root and not root.rmActive and not p.importPreview.graph and not p.importPreview.scroll.contentWidget,'failed preview stranded an active root')
end)
finish()
