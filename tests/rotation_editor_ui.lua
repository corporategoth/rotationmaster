local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function body() return {name='Mine',switch={},rotation={{id='branch',type='branch',conditions={},onTrue={{id='yes',type='none',conditions={}}},onFalse={{id='no',type='none',conditions={}}}}},cooldowns={{id='optional',type='spell',action=324,conditions={}}}} end
local function fixture()
    local f=F.new();local a=f.addon;local frames,create=dofile('tests/fixtures/native_ui.lua')(f.env);f.nativeFrames=frames
    local ace=f.libraries['AceGUI-3.0'];local original=ace.Create
    ace.Create=function(self,kind) local w=original(self,kind);w.frame=create('Frame');return w end
    ace.Release=function(_,w) w.frame:Hide() end
    dofile('tests/fixtures/spell_editbox.lua')(f,create)
    a.db.profile.rotations={[0]={mine=body()}};a.configPaneGeneration=1
    function a:GetEditableRotation(spec,id) return self.db.profile.rotations[spec] and self.db.profile.rotations[spec][id] end
    function a:GetDefaultIdForRuntime(_,id) if id=='builtin' then return 'pack' end end
    function a:ListDefaultRotations() return {{id='pack',runtimeKey='builtin',name='Mine',description='Preview',enabled=true,envelope={body=body()}}} end
    function a:GetImportValidationOptions() return {} end
    function a:validateCondition() return true end
    a.UpdateAutoSwitch=function() end;a.SwitchRotation=function() end;a.EvaluateNextAction=function() end
    for _,file in ipairs({'Platform/spells.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/rotation_draft.lua','Data/validation.lua','Core/rotation_editor.lua','Core/rotation_workspace.lua','Core/rotation_tags.lua','Core/rotation_canvas.lua','UI/window.lua'}) do f.load(file) end
    for _,file in ipairs({'UI/rotation_cards.lua','UI/rotation_canvas.lua','UI/color_picker.lua','UI/rotation_effect_fields.lua','UI/rotation_fields.lua','UI/rotation_navigation.lua','UI/rotation_metadata.lua','UI/rotation_view.lua','UI/rotation_editor.lua'}) do local h=io.open(file);if h then h:close();f.load(file) end end
    local parent=create('Frame');parent:SetSize(740,600)
    return f,parent
end
local function visibleCard(pane,id) for _,c in ipairs(pane.canvas.cards) do if c.model and c.model.id==id and c.frame:IsShown() then return c end end end
-- Existing field tests select the card's workspace through the public control.
-- Visibility tests use visibleCard so hidden content cannot pass accidentally.
local function card(pane,id)
    local snapshot=pane.workspace:Snapshot();local section='rotation'
    for _,step in ipairs(snapshot.cooldowns or {}) do if step.id==id then section='cooldowns';break end end
    if pane.view.section~=section then pane:SelectContent(section) end
    return visibleCard(pane,id)
end

test('defaults and custom rotations share native branch/action cards with readonly enforced',function()
    local f,parent=fixture();local a=f.addon
    local editable=assert(a:CreateRotationEditor(parent,0,'mine'))
    local other=f.env.CreateFrame('Frame');other:SetSize(740,600);local reference=assert(a:CreateRotationEditor(other,0,'builtin'))
    assert(#editable.canvas.scene.cards==#reference.canvas.scene.cards and card(editable,'branch').model.border=='white')
    assert(card(reference,'yes').controls.remove:IsEnabled()==false and card(editable,'yes').controls.remove:IsEnabled())
    card(reference,'branch').expand:Click();assert(card(reference,'branch').model.compact and card(reference,'yes'))
    card(reference,'branch').armToggle:Click();assert(card(reference,'yes')==nil)
    assert(reference.workspace:Snapshot().rotation[1].onTrue[1].id=='yes')
end)
test('deletion history and forced branch controls remain private until Apply',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    card(pane,'yes').controls.remove:Click();assert(card(pane,'yes')==nil and #f.addon:GetEditableRotation(0,'mine').rotation[1].onTrue==1)
    pane.undo:Click();assert(card(pane,'yes'));pane.redo:Click();assert(not card(pane,'yes'))
    pane.undo:Click();card(pane,'branch').controls.enable:Click()
    assert(card(pane,'branch').model.mode=='true' and card(pane,'no').model.inactive)
    pane.apply:Click();assert(f.addon:GetEditableRotation(0,'mine').rotation[1].mode=='true' and not pane.workspace:IsDirty())
end)
test('recycled card callbacks and released pane controls cannot mutate resumable drafts',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    local old=card(pane,'yes').controls.remove.scripts.OnClick
    pane:Render();old();assert(card(pane,'yes'))
    local released=card(pane,'yes').controls.remove.scripts.OnClick;pane:Release();released()
    assert(#pane.workspace:Snapshot().rotation[1].onTrue==1)
end)
test('nested condition buttons use detached guarded workspace targets for editable and readonly views',function()
    local f,parent=fixture();local a=f.addon;local captured
    function a:ShowConditionEditor(_,_,condition,callback,valid,options) captured={condition=condition,callback=callback,valid=valid,options=options} end
    local pane=assert(a:CreateRotationEditor(parent,0,'mine'));card(pane,'yes').condition:Click()
    captured.condition.disabled=true;captured.callback(true)
    assert(pane.workspace:Snapshot().rotation[1].onTrue[1].conditions.disabled and a:GetEditableRotation(0,'mine').rotation[1].onTrue[1].conditions.disabled==nil)
    pane:Release();pane=assert(a:CreateRotationEditor(parent,0,'builtin'));card(pane,'yes').condition:Click()
    assert(captured.options.readOnly and captured.options.persistentOwner)
end)
test('expanded native action fields keep edits undoable and reuse their controls across renders',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    card(pane,'yes').action:Click();local original=card(pane,'yes').fieldControls.suppress
    assert(original and card(pane,'yes').model.height>=72 and card(pane,'yes').model.height<120)
    original:Click();assert(pane.workspace:Snapshot().rotation[1].onTrue[1].suppress_attack)
    assert(card(pane,'yes').fieldControls.suppress==original,'every edit allocated a fresh native field frame')
    pane.undo:Click();assert(not pane.workspace:Snapshot().rotation[1].onTrue[1].suppress_attack)
    local stale=original.scripts.OnClick;pane:Release();stale()
    assert(not pane.workspace:Snapshot().rotation[1].onTrue[1].suppress_attack)
end)
test('closing retains a typed name and opening reuses frames while stale root callbacks stay inert',function()
    local f,parent=fixture();local a=f.addon;local pane=assert(a:CreateRotationEditor(parent,0,'mine'))
    local stale=pane.name.scripts.OnEnterPressed
    pane.name:SetText('Unsaved typed name');pane.name.scripts.OnTextChanged(pane.name,true);pane:Release()
    local reopened=assert(a:CreateRotationEditor(parent,0,'mine'))
    assert(reopened==pane and reopened.workspace:Snapshot().name=='Unsaved typed name' and a:GetEditableRotation(0,'mine').name=='Mine')
    local count=#f.nativeFrames;pane:Release();assert(a:CreateRotationEditor(parent,0,'builtin')==pane)
    assert(#f.nativeFrames==count,'reopening the same common layout allocated another native frame tree')
    stale(pane.name);assert(pane.workspace:Snapshot().name=='Mine' and pane.workspace.readOnly)
end)
test('palette inserts branches and action cards while no-op and cyclic drop zones stay unmarked',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    pane.palette.branch:Click();local snapshot=pane.workspace:Snapshot();assert(snapshot.rotation[2].type=='branch' and #snapshot.rotation[2].onTrue==0)
    pane.undo:Click();pane.canvas:BeginDrag('yes')
    local noOp,other
    for _,target in ipairs(pane.canvas.scene.dropTargets) do
        if target.destination.parentId=='branch' and target.destination.path[3]=='onTrue' and target.destination.index==2 then noOp=target end
        if target.destination.parentId=='branch' and target.destination.path[3]=='onFalse' and target.destination.index==2 then other=target end
    end
    assert(noOp and other and not pane.canvas:CanDrop(noOp) and pane.canvas:CanDrop(other))
    assert(pane.canvas:Drop(other));snapshot=pane.workspace:Snapshot();assert(#snapshot.rotation[1].onTrue==0 and snapshot.rotation[1].onFalse[2].id=='yes')
    pane.canvas:BeginDrag('branch');assert(not pane.canvas:CanDrop(other));pane.canvas:CancelDrag()
end)
test('dirty navigation offers Apply Discard Cancel and released prompts cannot navigate',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local navigated=0
    assert(pane:Command('UpdateStep','yes',{suppress_attack=true}))
    assert(not pane:RequestLeave(function() navigated=navigated+1 end));assert(pane.leavePrompt.frame:IsShown())
    pane.leavePrompt.cancel:Click();assert(navigated==0 and pane.workspace:IsDirty())
    pane:RequestLeave(function() navigated=navigated+1 end);pane.leavePrompt.apply:Click()
    assert(navigated==1 and f.addon:GetEditableRotation(0,'mine').rotation[1].onTrue[1].suppress_attack)
    pane:Command('UpdateStep','yes',{suppress_attack=false});pane:RequestLeave(function() navigated=navigated+1 end);pane.leavePrompt.discard:Click()
    assert(navigated==2 and pane.workspace:Snapshot().rotation[1].onTrue[1].suppress_attack)
    pane:Command('Remove','yes');pane:RequestLeave(function() navigated=navigated+1 end)
    local stale=pane.leavePrompt.discard.scripts.OnClick;pane:Release();stale();assert(navigated==2)
end)
test('live browser and main tabs preserve selection until dirty navigation is resolved',function()
    local f=fixture();local a=f.addon;f.env.NEW='New';a.currentSpec=0;a.currentRotation='mine'
    a.GetRotationEditorSpecs=function() return {{id=0,name='Primary'}} end
    a.BuildRotationEditor=function() error('legacy rotation view was still used') end
    a.SetupOptions=function() end;a.BuildConfigurationPane=function() end;a.pretty_name='Rotation Master';a.name='rotationmaster'
    f.load('UI/rotation_browser.lua');f.load('UI/config.lua')
    local shell=a:ShowConfig('Rotations',{spec=0,id='mine'});local browser=shell.pane;local editor=browser.pane
    assert(editor.workspace and not editor.workspace.readOnly)
    editor:Command('UpdateStep','yes',{suppress_attack=true});browser:SelectRotation(0,'builtin')
    assert(browser.selected=='mine' and editor.leavePrompt.frame:IsShown())
    editor.leavePrompt.cancel:Click();assert(browser.selected=='mine')
    browser.query='retain query';browser.filter='custom';local transfers=0;a.ShowRotationTransfer=function() transfers=transfers+1 end
    browser.newButton:Click();assert(browser.pendingId==nil and browser.query=='retain query' and browser.filter=='custom')
    editor.leavePrompt.cancel:Click();assert(browser.selected=='mine')
    browser.importButton:Click();assert(transfers==0 and editor.leavePrompt.frame:IsShown());editor.leavePrompt.cancel:Click()
    shell:SelectSection('General');assert(shell.section=='Rotations' and editor.leavePrompt.frame:IsShown())
    editor.leavePrompt.apply:Click();assert(shell.section=='General' and a:GetEditableRotation(0,'mine').rotation[1].onTrue[1].suppress_attack)
    shell:SelectSection('Rotations');browser=shell.pane;browser:SelectRotation(0,'mine');editor=browser.pane
    editor:Command('Remove','yes');browser:SelectRotation(0,'builtin');editor.leavePrompt.discard:Click()
    assert(browser.selected=='builtin' and browser.pane.workspace.readOnly)
end)
test('expanded optional spell search and effects commit detached data and release their pooled callbacks',function()
    local f,parent=fixture();local a=f.addon;a.db.global.effects={glow={name='Glow'}}
    local pane=assert(a:CreateRotationEditor(parent,0,'mine'));card(pane,'optional').action:Click()
    local controls=card(pane,'optional').fieldControls;assert(controls.spell and controls.effect and controls.sound)
    controls.spell:Fire('OnEnterPressed','403')
    assert(pane.workspace:Snapshot().cooldowns[1].action==403 and a:GetEditableRotation(0,'mine').cooldowns[1].action==324)
    local field=card(pane,'optional').fieldControls.magnification;field:SetValue(1.5);assert(pane:FlushFieldEdits())
    assert(pane.workspace:Snapshot().cooldowns[1].magnification==1.5)
    pane.undo:Click();assert(pane.workspace:Snapshot().cooldowns[1].magnification==nil)
end)
test('comparison waits for a dirty draft decision and the unchanged Apply button stays inactive',function()
    local f,parent=fixture();local a=f.addon;local exported=0;a.ShowRotationComparison=function() exported=exported+1 end
    local pane=assert(a:CreateRotationEditor(parent,0,'mine'));assert(not pane.apply:IsEnabled())
    pane:Command('UpdateStep','yes',{suppress_attack=true});assert(pane.apply:IsEnabled());pane.compare:Click()
    assert(exported==0 and pane.leavePrompt.frame:IsShown())
    pane.leavePrompt.cancel:Click();assert(exported==0)
    pane.compare:Click();pane.leavePrompt.apply:Click();assert(exported==1 and not pane.apply:IsEnabled())
end)
test('section controls sit with cooldown and rotation headings and switch text stays visible',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    assert(pane.switchText and pane.switchText:GetText()~='')
    assert(pane.sectionLabels.cooldowns:GetText()=='Cooldowns' and pane.sectionLabels.rotation:GetText()=='Rotation')
    assert(pane.palette.optional:GetParent()==pane.frame)
    assert(pane.palette.optional:GetText()=='Add cooldown' and pane.palette.branch:GetText()=='Add branch')
    local b=card(pane,'branch');assert(not b.preview:IsShown() and b.title:GetText()~='Conditional branch')
    assert(b.controls.enable.pillDecoration and pane.delete)
end)
test('Ctrl drag into an arm moves the following sequence as one undoable edit',function()
    local f,parent=fixture();local value=f.addon:GetEditableRotation(0,'mine')
    value.rotation[2]={id='second',type='none',conditions={}}
    value.rotation[3]={id='third',type='none',conditions={}}
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));f.env.IsControlKeyDown=function() return true end;pane.canvas:BeginDrag('second');f.env.IsControlKeyDown=function() return false end
    local destination
    for _,target in ipairs(pane.canvas.scene.dropTargets) do if target.destination.parentId=='branch' and target.destination.path[3]=='onTrue' and target.destination.index==2 then destination=target end end
    assert(pane.canvas:Drop(destination))
    local v=pane.workspace:Snapshot();assert(#v.rotation==1 and #v.rotation[1].onTrue==3)
    pane.undo:Click();assert(#pane.workspace:Snapshot().rotation==3)
end)
test('whole rotation deletion requires confirmation and stale confirmation cannot delete another owner',function()
    local f,parent=fixture();local a=f.addon;local calls=0
    a.DeleteCustomRotation=function(_,spec,id) calls=calls+1;a.db.profile.rotations[spec][id]=nil;return true end
    local pane=assert(a:CreateRotationEditor(parent,0,'mine'));pane.delete:Click()
    assert(calls==0 and pane.deletePrompt.frame:IsShown())
    local stale=pane.deletePrompt.confirm.scripts.OnClick
    pane.deletePrompt.cancel:Click();assert(calls==0)
    pane.delete:Click();pane.deletePrompt.confirm:Click();assert(calls==1)
    a.db.profile.rotations[0].mine=body();pane=assert(a:CreateRotationEditor(parent,0,'mine'));stale();assert(calls==1)
end)
test('native action identity supports spell hover and click with released callbacks inert',function()
    local f,parent=fixture();local shown,clicked
    f.env.C_Spell={GetSpellInfo=function(id) return {name='Lightning Bolt',spellID=id,iconID=1} end}
    f.env.GameTooltip={IsOwned=function() return false end,SetOwner=function() end,SetHyperlink=function(_,link) shown=link end,Hide=function() shown=nil end}
    f.env.SetItemRef=function(link) clicked=link end
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local action=card(pane,'optional').action
    action.scripts.OnEnter(action);assert(shown=='spell:324');f.env.IsShiftKeyDown=function() return true end;action:Click();assert(clicked=='spell:324')
    local stale=action.scripts.OnClick;pane:Release();clicked=nil;stale();assert(clicked==nil)
end)
test('editing a longer switch condition reflows the canvas without a resize',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    local before=pane.canvas.frame.point[3]
    f.addon.DescribeCondition=function(_,condition) return condition.long and string.rep('long switch condition ',12) or 'True' end
    pane:Command('SetCondition',{kind='switch'},{long=true})
    assert(pane.canvas.frame.point[3]<before and pane.switchText:GetHeight()<=72)
end)
test('pending native text and card names survive rerender closure and dirty navigation',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));card(pane,'optional').action:Click()
    local field=card(pane,'optional').fieldControls.xoffs;field:SetText('1.5');field.scripts.OnTextChanged(field,true)
    assert(pane:HasUnsavedChanges());card(pane,'yes').action:Click()
    assert(card(pane,'optional').fieldControls.xoffs:GetText()=='1.5')
    local moved=false;pane:RequestLeave(function() moved=true end);assert(not moved);pane.leavePrompt.cancel:Click()
    local named=card(pane,'yes');named.title:Click();named.name:SetText('Keep card name');named.name.scripts.OnTextChanged(named.name,true)
    pane:Release();pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    assert(pane:HasUnsavedChanges());pane.apply:Click()
    local saved=f.addon:GetEditableRotation(0,'mine');assert(saved.cooldowns[1].xoffs==1.5 and saved.rotation[1].onTrue[1].name=='Keep card name')
end)
test('invalid native field text remains visible and blocks Apply until corrected or discarded',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));card(pane,'optional').action:Click()
    local field=card(pane,'optional').fieldControls.xoffs;field:SetText('unfinished');field.scripts.OnTextChanged(field,true)
    pane:Render();field=card(pane,'optional').fieldControls.xoffs;assert(field:GetText()=='unfinished' and card(pane,'optional').model.invalid)
    assert(not pane:Apply() and pane:HasUnsavedChanges())
    pane.discard:Click();assert(not pane:HasUnsavedChanges() and card(pane,'optional').fieldControls.xoffs:GetText()=='')
end)
test('selecting the current action type keeps its action fields and history',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));card(pane,'optional').action:Click()
    local control=card(pane,'optional').fieldControls.type;control:Click();control.menu.rows[1]:Click()
    assert(pane.workspace:Snapshot().cooldowns[1].action==324 and not pane.workspace:IsDirty())
end)
test('pending new drafts remain discoverable across browser closure and confirmed dirty deletion navigates away',function()
    local f,parent=fixture();local a=f.addon;f.env.NEW='New';a.currentSpec=0
    a.GetRotationEditorSpecs=function() return {{id=0,name='Primary'}} end
    a.DeleteCustomRotation=function(_,spec,id) a.db.profile.rotations[spec][id]=nil;return true end
    f.load('UI/rotation_browser.lua');local browser=a:CreateRotationBrowser(parent,{spec=0,id='mine'})
    browser.newButton:Click();local pending=browser.selected
    browser.pane:Command('SetBodyField','name','Unfinished');browser.pane.palette.action:Click();browser:Release()
    browser=a:CreateRotationBrowser(parent,{spec=0,id=pending});assert(browser.selected==pending and browser.pane.workspace:Snapshot().name=='Unfinished')
    assert(not a:GetEditableRotation(0,pending));local found=false;for _,row in ipairs(browser.rows) do if row.key==pending then found=true end end;assert(found)
    browser:SelectRotation(0,'mine');browser.pane.leavePrompt.discard:Click()
    local editor=browser.pane;editor:Command('UpdateStep','yes',{suppress_attack=true});editor.delete:Click();editor.deletePrompt.confirm:Click()
    assert(not a:GetEditableRotation(0,'mine') and browser.selected==f.env.DEFAULT and not editor.leavePrompt.frame:IsShown())
end)
test('drag previews follow the pointer and geometric drop targeting works without mouse-focus hits',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local canvas=pane.canvas
    f.env.GetCursorPosition=function() return 200,510 end
    f.env.InputUtil={IsMouseOver=function() return false end}
    canvas.frame.GetLeft=function() return 0 end;canvas.frame.GetRight=function() return 740 end
    canvas.frame.GetBottom=function() return 0 end;canvas.frame.GetTop=function() return 1000 end
    local zone;for _,candidate in ipairs(canvas.zones) do if candidate.target.destination.path[1]=='rotation' and #candidate.target.destination.path==1 and candidate.target.destination.index==1 then zone=candidate;break end end
    zone.GetLeft=function() return 100 end;zone.GetRight=function() return 440 end;zone.GetBottom=function() return 500 end;zone.GetTop=function() return 524 end
    canvas:BeginDrag(nil,pane.palette.branch.node)
    assert(canvas.ghost and canvas.ghost:IsShown() and canvas.ghost.summary:GetText()~='')
    assert(canvas:HoverTarget()==zone and zone.marker:IsShown())
    canvas.frame.GetBottom=function() return 600 end;assert(not canvas:HoverTarget(),'off-viewport destination accepted')
    canvas.frame.GetBottom=function() return 0 end
    canvas:EndDrag();assert(not canvas.ghost:IsShown() and pane.workspace:Snapshot().rotation[1].type=='branch')
    assert(#pane.workspace:Snapshot().rotation[1].onTrue==1)
end)
test('drag release cannot also activate the source Add button or open a card editor',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    local button=pane.palette.branch;button.scripts.OnMouseDown(button,'LeftButton');button.scripts.OnDragStart()
    local target;for _,entry in ipairs(pane.canvas.scene.dropTargets) do if #entry.destination.path==1 and entry.destination.path[1]=='rotation' and entry.destination.index==1 then target=entry end end
    assert(pane.canvas:Drop(target));button:Click();assert(#pane.workspace:Snapshot().rotation==1)
    local title=card(pane,pane.workspace:Snapshot().rotation[1].id).title
    title.scripts.OnMouseDown(title,'LeftButton');title.scripts.OnDragStart();pane.canvas:CancelDrag();title:Click()
    assert(not card(pane,pane.workspace:Snapshot().rotation[1].id).name:IsShown())
end)
test('section and card controls distinguish collapsed summaries from action details',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    assert(pane.origin:GetText()=='' and pane.switch==pane.switchButton)
    local cooldown=card(pane,'optional');assert(not cooldown.controls.up:IsShown() and not cooldown.controls.down:IsShown())
    cooldown.action:Click();cooldown=card(pane,'optional');assert(cooldown.model.expanded and not cooldown.action:IsShown() and cooldown.condition:IsShown())
    cooldown.expand:Click();cooldown=card(pane,'optional');assert(not cooldown.model.expanded and not cooldown.model.compact)
    cooldown.expand:Click();assert(card(pane,'optional').model.compact and not card(pane,'optional').controls.enable:IsShown())
    pane.contentTabs.rotation:Click();assert(not visibleCard(pane,'optional'))
    pane.contentTabs.cooldowns:Click()
    pane.sectionTools.cooldowns.expand:Click();assert(not card(pane,'optional').model.expanded and not card(pane,'optional').model.compact)
    pane.sectionTools.cooldowns.collapse:Click();assert(card(pane,'optional').model.compact)
    assert(pane.hint:GetText():find('condition',1,true))
end)
test('readonly expanded branch condition inspection remains enabled after disabled field pool reuse',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'builtin'));local inspected=false
    f.addon.ShowConditionEditor=function(_,_,_,_,_,_,options) inspected=options.readOnly end
    card(pane,'optional').action:Click();assert(not card(pane,'optional').fieldPool.choices[1]:IsEnabled())
    pane.contentTabs.rotation:Click();pane.view.cardStates.branch='expanded';pane:Render()
    local guard=card(pane,'branch').fieldPool.choices[1];assert(guard:IsEnabled());guard:Click();assert(inspected)
end)
test('manual move callback failures are captured and forwarded once like other native controls',function()
    local f,parent=fixture();local forwarded=0
    f.env.geterrorhandler=function() return function() forwarded=forwarded+1 end end
    f.env.debugstack=function() return 'Interface/AddOns/rotationmaster/UI/rotation_canvas.lua:1: move' end
    f.addon:GetEditableRotation(0,'mine').rotation[1].onTrue[2]={id='second',type='none',conditions={}}
    f.load('Diagnostics/errors.lua');local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    pane.Command=function() error('manual-move-failed',0) end
    local control=card(pane,'yes').controls.down
    assert(pcall(function() control:Click() end));assert(#f.addon.Diagnostics:GetReports()==1 and forwarded==1)
    control:Click();assert(forwarded==1)
end)
test('rotation header separates description and metadata and docks controls without duplicate transfer',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    assert(pane.description and pane.info:GetText()=='Metadata' and pane.export==nil)
    assert(pane.enable.pillDecoration and pane.compare.icon and pane.clone.icon)
    assert(pane.delete.point[1]=='TOPRIGHT' and pane.hint.point[1]=='BOTTOMLEFT' and pane.hint.point[3]==12)
    pane.description:SetText('Shield upkeep while leveling');pane.description.scripts.OnTextChanged(pane.description,true)
    pane.apply:Click();assert(f.addon:GetEditableRotation(0,'mine').description=='Shield upkeep while leveling')
    assert(pane.status:GetText()=='')
end)
test('invalid cards have red borders and the rotation exposes unavailable diagnostics',function()
    local f,parent=fixture();local value=f.addon:GetEditableRotation(0,'mine');value.cooldowns[1].action=nil
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));assert(card(pane,'optional').model.invalid)
    assert(card(pane,'optional').decoration.border[1].color[1]>.7 and pane.validationButton:IsShown())
end)
test('chevron toggles summaries and names while action opens fields and preview does not change state',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    local c=card(pane,'optional');c.expand:Click();assert(card(pane,'optional').model.compact)
    card(pane,'optional').expand:Click();assert(not card(pane,'optional').model.expanded and not card(pane,'optional').model.compact)
    card(pane,'optional').action:Click();c=card(pane,'optional');assert(c.model.expanded and c.fieldControls.spell)
    assert(c.fieldSpellIcon:IsShown() and c.fieldSpellIcon.icon.texture)
    assert(c.effectDemo.target:GetWidth()==36 and not c.controls.effect)
    c.expand:Click();assert(not card(pane,'optional').model.compact and not card(pane,'optional').model.expanded)
end)
test('collapse all keeps branch paths visible and folding a branch is a separate view action',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    pane.sectionTools.rotation.collapse:Click();assert(card(pane,'branch').model.compact and card(pane,'yes') and card(pane,'no'))
    card(pane,'branch').armToggle:Click();assert(not card(pane,'yes') and not card(pane,'no'))
    card(pane,'branch').armToggle:Click();assert(card(pane,'yes') and card(pane,'yes').model.compact)
end)
test('content tabs select one workspace without whole section folding',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    assert(not pane.sectionTools.cooldowns.toggle and not pane.sectionLabels.cooldowns.icon)
    pane.sectionLabels.cooldowns:Click();assert(visibleCard(pane,'optional') and not visibleCard(pane,'yes'))
    pane.sectionLabels.rotation:Click();assert(visibleCard(pane,'yes') and not visibleCard(pane,'optional'))
end)
test('typed description participates in Undo and Redo before leaving the input',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    pane.description:SetText('New description');pane.description.scripts.OnTextChanged(pane.description,true)
    assert(pane.undo:IsEnabled());pane.undo:Click();assert(pane.description:GetText()=='')
    pane.redo:Click();assert(pane.description:GetText()=='New description')
end)
test('malformed metadata is inspectable without throwing and remains invalid',function()
    local f,parent=fixture();local value=f.addon:GetEditableRotation(0,'mine');value.metadata=42
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local report
    f.addon.ShowConditionText=function(_,message) report=message end
    pane.info:Click();assert(pane.metadataWindow.note:GetText():find('42',1,true) and pane.validationButton:IsShown())
    assert(value.metadata==42)
end)
test('switch heading and text both open the editor without folding',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local count=0
    f.addon.ShowConditionEditor=function() count=count+1 end
    pane.switchLabel:Click();assert(pane.switch:IsShown() and count==1)
    pane.switch:Click();assert(count==2)
end)
test('changing action type replaces a named item picker selection without stale fields',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    card(pane,'optional').action:Click();local typeField=card(pane,'optional').fieldControls.type;typeField:Click();typeField.menu.rows[4]:Click()
    local items=card(pane,'optional').fieldControls.item1;items:Fire('OnEnterPressed','123')
    typeField=card(pane,'optional').fieldControls.type;typeField:Click();typeField.menu.rows[1]:Click()
    local spell=card(pane,'optional').fieldControls.spell;spell:Fire('OnEnterPressed','324')
    assert(pane:Apply() and f.addon:GetEditableRotation(0,'mine').cooldowns[1].action==324)
end)
test('invalid typing immediately updates card and root markers without replacing focused fields',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));card(pane,'optional').action:Click()
    local field=card(pane,'optional').fieldControls.xoffs;field:SetText('unfinished');field.scripts.OnTextChanged(field,true)
    assert(card(pane,'optional').model.invalid and pane.validationButton:IsShown())
    assert(card(pane,'optional').fieldControls.xoffs==field and field:GetText()=='unfinished')
    local report;f.addon.ShowConditionText=function(_,message) report=message end;pane.validationButton:Click();assert(report:find('Horizontal offset',1,true))
    assert(not pane:Apply() and pane.validationButton:IsShown())
    field:SetText('1.5');field.scripts.OnTextChanged(field,true);assert(not card(pane,'optional').model.invalid and not pane.validationButton:IsShown())
end)
test('only active workspace tools occupy the fixed toolbar',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    assert(pane.separator==nil and not pane.sectionTools.cooldowns.expand:IsShown() and not pane.palette.optional:IsShown())
    pane.sectionLabels.cooldowns:Click();local tools=pane.sectionTools.cooldowns
    assert(tools.expand:IsShown() and tools.collapse:IsShown() and pane.palette.optional:IsShown())
    assert(not pane.palette.action:IsShown() and not pane.sectionTools.rotation.expand:IsShown() and not tools.hint)
end)
test('viewing pristine fallback and packaged defaults never opens an unsaved prompt',function()
    local f,parent=fixture();f.addon.db.profile.rotations[0][f.env.DEFAULT]={}
    local pane=assert(f.addon:CreateRotationEditor(parent,0,f.env.DEFAULT));local moved=false
    pane:RequestLeave(function() moved=true end);assert(moved and not pane:HasUnsavedChanges())
    pane=assert(f.addon:CreateRotationEditor(parent,0,'builtin'));pane.view.pendingFields={optional={name={text='old UI text'}}}
    moved=false;pane:RequestLeave(function() moved=true end);assert(moved)
end)
test('card name is plain text aligned with its input and blur hides editing without losing the draft',function()
    local f,parent=fixture();f.addon.SpellLabel=function() return '|cff00ffff|Hspell:324|h[Lightning Shield]|h|r' end
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local c=card(pane,'optional')
    assert(not c.title:GetText():find('|H',1,true));c.title:Click();assert(c.name:IsShown() and not c.title:IsShown())
    assert(c.name.point[2]==c.title and c.name:GetWidth()==c.title:GetWidth())
    c.name:SetText('My shield');c.name.scripts.OnTextChanged(c.name,true);c.name.scripts.OnEditFocusLost(c.name)
    assert(not c.name:IsShown() and c.title:IsShown() and pane:HasPendingFields())
    c.title:Click();c.name:SetText('');c.name.scripts.OnTextChanged(c.name,true);c.name.scripts.OnEditFocusLost(c.name);assert(c.title:GetText()=='Lightning Shield')
    c=card(pane,'branch');assert(c.armToggle.point[1]=='TOPLEFT' and c.armToggle.point[2]>=28 and c.armToggle.icon.texture:find('branch',1,true))
end)
test('fallback switch summary survives geometry and outside name clicks finish inline editing',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,f.env.DEFAULT))
    assert(pane.switchText:GetText()=='No other rotations match.')
    pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local c=card(pane,'optional');c.title:Click()
    f.env.IsMouseButtonDown=function() return true end;f.env.MouseIsOver=function() return false end
    f.env.GetCursorPosition=function() return 200,200 end
    c.name.GetLeft=function() return 0 end;c.name.GetRight=function() return 100 end
    c.name.GetBottom=function() return 0 end;c.name.GetTop=function() return 20 end
    c.name.scripts.OnUpdate(c.name);assert(not c.name:IsShown() and c.title:IsShown())
end)
test('card icons are backgroundless and cooldowns show a full size highlight preview without a Ping button',function()
    local f,parent=fixture();local a=f.addon;a.db.global.effects={ping={name='Ping',type='texture'}};a.db.profile.effect='ping'
    a.Glow=function() end;a.HideGlow=function() end
    local pane=assert(a:CreateRotationEditor(parent,0,'mine'));local c=card(pane,'optional')
    assert(not c.controls.remove.art:IsShown() and not c.expand.art:IsShown() and c.expand:GetHeight()<=18)
    assert(c.preview:GetWidth()==36 and not c.controls.effect);c.action:Click();c=card(pane,'optional')
    assert(c.effectDemo.target==c.fieldSpellIcon and c.fieldSpellIcon:GetWidth()==36)
end)
test('metadata form edits readable fields and description atomically in the private draft',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));pane.info:Click()
    local dialog=assert(pane.metadataWindow);assert(dialog.fields.description==pane.description and pane.description:GetParent()~=pane.frame)
    local author=dialog.fields.author;author:SetText('PreZ');author.scripts.OnTextChanged(author,true)
    pane.description:SetText('Leveling and upkeep');pane.description.scripts.OnTextChanged(pane.description,true)
    dialog.apply:Click();local snapshot=pane.workspace:Snapshot();assert(snapshot.metadata.author=='PreZ' and snapshot.description=='Leveling and upkeep')
    assert(f.addon:GetEditableRotation(0,'mine').metadata==nil)
    pane.undo:Click();snapshot=pane.workspace:Snapshot();assert(snapshot.metadata==nil and snapshot.description==nil)
    pane.redo:Click();assert(pane:Apply() and f.addon:GetEditableRotation(0,'mine').metadata.author=='PreZ')
    pane.info:Click();dialog.fields.author:SetText('Cancel me');dialog.fields.author.scripts.OnTextChanged(dialog.fields.author,true);dialog.cancel:Click()
    assert(not pane:HasUnsavedChanges() and pane.workspace:Snapshot().metadata.author=='PreZ')
end)
test('metadata form guards navigation and old callbacks and defaults share readonly fields',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));pane.info:Click();local dialog=pane.metadataWindow
    dialog.fields.author:SetText('Retain me');dialog.fields.author.scripts.OnTextChanged(dialog.fields.author,true)
    local left=false;pane:RequestLeave(function() left=true end);assert(not left);pane.leavePrompt.cancel:Click()
    local stale=dialog.apply.scripts.OnClick;pane:Release();pane=assert(f.addon:CreateRotationEditor(parent,0,'builtin'));pane.info:Click();stale()
    assert(pane.workspace.readOnly and not dialog.apply:IsEnabled() and not pane:HasUnsavedChanges())
    assert(pane.workspace:Snapshot().metadata==nil)
end)
test('Escape-style hiding cancels metadata inputs without leaving private dirty flags',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));pane.info:Click();local dialog=pane.metadataWindow
    local field=dialog.fields.author;field:SetText('Abandon');field.scripts.OnTextChanged(field,true)
    pane.description:SetText('Abandon too');pane.description.scripts.OnTextChanged(pane.description,true);dialog.frame:Hide()
    assert(not pane:HasUnsavedChanges() and pane.description:GetText()=='')
end)
test('repeated Metadata opening does not replace Cancel baseline and history refreshes description',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));pane.info:Click();local dialog=pane.metadataWindow
    dialog.fields.author:SetText('Cancel');dialog.fields.author.scripts.OnTextChanged(dialog.fields.author,true)
    pane.description:SetText('Cancel');pane.description.scripts.OnTextChanged(pane.description,true);pane.info:Click();dialog.cancel:Click();assert(not pane:HasUnsavedChanges())
    pane.info:Click();pane.description:SetText('One');pane.description.scripts.OnTextChanged(pane.description,true);dialog.apply:Click()
    pane.info:Click();pane.undo:Click();dialog.cancel:Click();pane.info:Click();assert(pane.description:GetText()=='' and pane.workspace:Snapshot().description==nil)
    assert(not pane.delete.art:IsShown())
end)
test('metadata source text grows the scroll content and retired callbacks cannot commit on reopening',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));pane.workspace.reserved={origins={manifest={sources={}}}}
    for i=1,12 do pane.workspace.reserved.origins.manifest.sources[i]={title='Guide '..i,url='https://example.test/'..i} end
    pane.info:Click();local dialog=pane.metadataWindow;assert(dialog.source:GetHeight()>=dialog.source:GetStringHeight())
    local stale=dialog.apply.scripts.OnClick;dialog.cancel:Click();pane.info:Click();local field=dialog.fields.author;field:SetText('Fresh');field.scripts.OnTextChanged(field,true);stale()
    assert(dialog.frame:IsShown() and pane.workspace:Snapshot().metadata==nil)
end)
test('effect fields use checkboxes side labels full preview direction controls and sound selection',function()
    local f,parent=fixture();local a=f.addon;local played
    f.libraries['LibSharedMedia-3.0']={HashTable=function() return {Bell='bell.ogg'} end,Fetch=function() return 'bell.ogg' end}
    f.env.PlaySoundFile=function(path) played=path;return true end
    local pane=assert(a:CreateRotationEditor(parent,0,'mine'));card(pane,'optional').action:Click();local c=card(pane,'optional');local fields=c.fieldControls
    assert(fields.ranked.check and c.effectDemo and c.effectDemo.target:GetWidth()>=36)
    assert(fields.magnification.point[2]>0 and fields.sound.menu and fields.soundPreview.icon)
    fields.positionRight:Click();assert(pane.workspace:Snapshot().cooldowns[1].xoffs==1)
    c=card(pane,'optional');c.fieldControls.positionCenter:Click();assert(pane.workspace:Snapshot().cooldowns[1].xoffs==0 and pane.workspace:Snapshot().cooldowns[1].setpoint=='CENTER')
    c=card(pane,'optional');c.fieldControls.sound:Click();c.fieldControls.sound.menu.rows[2]:Click()
    c=card(pane,'optional');c.fieldControls.soundPreview:Click();assert(played=='bell.ogg')
    c.fieldControls.colorSwatch:Click();assert(c.colorPicker.frame:IsShown())
    c.colorPicker:Choose(.5,1,1,.6);assert(pane:HasPendingFields() and c.effectDemo.color.a==.6)
end)
test('position controls consume pending offsets and color cancel preserves profile inheritance',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));card(pane,'optional').action:Click();local c=card(pane,'optional')
    local input=c.fieldControls.xoffs;input:SetText('10');input.scripts.OnTextChanged(input,true);c.fieldControls.positionRight:Click()
    assert(pane.workspace:Snapshot().cooldowns[1].xoffs==11 and not pane:HasPendingFields())
    c=card(pane,'optional');c.fieldControls.colorSwatch:Click();c.colorPicker:Choose(0,1,1,.5);c.colorPicker:Close(false)
    assert(not pane:HasPendingFields() and pane.workspace:Snapshot().cooldowns[1].color==nil)
end)
test('color picker Cancel retains an unfinished channel input and readonly preview cannot edit',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));card(pane,'optional').action:Click();local c=card(pane,'optional')
    local red=c.fieldControls.color_r;red:SetText('unfinished');red.scripts.OnTextChanged(red,true);c.fieldControls.colorSwatch:Click();c.colorPicker:Choose(.5,1,1,1);c.colorPicker:Close(false)
    assert(c.fieldControls.color_r:GetText()=='unfinished' and pane:HasInvalidPendingFields())
    pane:Release();pane=assert(f.addon:CreateRotationEditor(parent,0,'builtin'));card(pane,'optional').action:Click();c=card(pane,'optional')
    assert(not c.fieldControls.colorSwatch:IsEnabled() and not c.fieldControls.positionRight:IsEnabled() and not c.fieldControls.ranked:IsEnabled())
end)
test('workspace tabs expose their content and summaries explain editing',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    for _,key in ipairs({'cooldowns','rotation'}) do pane.sectionLabels[key]:Click();assert(pane.view.section==key and not pane.sectionTools[key].hint) end
    assert(not pane.switchCollapsedHint and pane.switch.tooltip and card(pane,'optional').condition.tooltip)
end)
test('compact card titles expand and named steps title the condition dialog',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local captured
    assert(pane:Command('UpdateStep','yes',{name='Keep safe'}))
    f.addon.ShowConditionEditor=function(_,_,_,_,_,_,options) captured=options end
    card(pane,'yes').condition:Click();assert(captured.title=='Keep safe')
    card(pane,'yes').expand:Click();card(pane,'yes').title:Click();assert(not card(pane,'yes').model.compact)
    card(pane,'branch').expand:Click();assert(card(pane,'branch').title:GetText()~='Click to add branch name')
end)
test('compact effect layout shares the leading spell icon and keeps controls inside the card',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));card(pane,'optional').action:Click();local c=card(pane,'optional');local fields=c.fieldControls
    assert(c.fieldSpellIcon.point[2]<fields.type.point[2] and c.effectDemo.target==c.fieldSpellIcon)
    assert(fields.magnification.kind=='Slider' and fields.colorReset:GetText()=='Default')
    assert(fields.color_r.point[3]==fields.color_g.point[3] and fields.color_b.point[3]==fields.color_a.point[3] and fields.color_r.point[3]>fields.color_b.point[3],'RGBA inputs should use two rows')
    assert(fields.xoffs.point[2]>fields.positionUp.point[2] and fields.yoffs.point[2]>fields.positionUp.point[2])
    assert(c.fields:GetHeight()>pane.view.detailsHeights.optional-8,'details cross card border')
end)
test('Apply clears previous active cooldown identities before evaluating changed effects',function()
    local f,parent=fixture();local a=f.addon;local cleared,evaluated={},false
    a.currentSpec=0;a.currentRotation='mine'
    a.GetSpellIds=function(_,step) return {step.action} end
    a.GlowCooldown=function(_,spell,show) assert(not show);cleared[#cleared+1]=spell end
    a.GlowClear=function() cleared.normal=true end
    a.EvaluateNextAction=function() evaluated=true;assert(cleared[1]==324 and cleared.normal) end
    local pane=assert(a:CreateRotationEditor(parent,0,'mine'));pane:Command('UpdateStep','optional',{action=403});assert(pane:Apply())
    assert(evaluated and a:GetEditableRotation(0,'mine').cooldowns[1].action==403)
end)
test('invalid RGBA text survives checkbox redraw and is correctable before Apply',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));card(pane,'optional').action:Click()
    local c=card(pane,'optional');local red=c.fieldControls.color_r;red:SetText('unfinished');red.scripts.OnTextChanged(red,true)
    c.fieldControls.ranked:Click();c=card(pane,'optional');red=c.fieldControls.color_r
    assert(red:GetText()=='unfinished' and pane:HasInvalidPendingFields(),'invalid pending text was hidden by redraw')
    red:SetText('0.2');red.scripts.OnTextChanged(red,true);assert(pane:Apply())
    assert(f.addon:GetEditableRotation(0,'mine').cooldowns[1].color.r==.2)
end)
test('fresh and recycled Item details preview effects on a visible leading icon',function()
    for _,recycled in ipairs({false,true}) do
        local f,parent=fixture();local a=f.addon;local last
        a.db.global.effects={preview={type='texture',name='Preview'}};a.db.profile.effect='preview'
        a.Glow=function(_,target,_,_,color,_,_,x,y) last={target=target,color=color,x=x,y=y} end
        if not recycled then local step=a.db.profile.rotations[0].mine.cooldowns[1];step.type='item';step.action={5512} end
        local pane=assert(a:CreateRotationEditor(parent,0,'mine'));card(pane,'optional').action:Click()
        if recycled then local typeField=card(pane,'optional').fieldControls.type;typeField:Click();typeField.menu.rows[4]:Click() end
        local c=card(pane,'optional');assert(c.effectDemo.target:IsShown(),'item preview uses a hidden pooled icon')
        local input=c.fieldControls.xoffs;input:SetText('12');input.scripts.OnTextChanged(input,true)
        local red=c.fieldControls.color_r;red:SetText('0.25');red.scripts.OnTextChanged(red,true)
        assert(last.target==c.effectDemo.target and last.x==12 and last.color.r==.25)
    end
end)
test('color swatch retains its selected decimal channels while hovered',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));card(pane,'optional').action:Click()
    local c=card(pane,'optional');local red=c.fieldControls.color_r;red:SetText('0.25');red.scripts.OnTextChanged(red,true)
    local swatch=c.fieldControls.colorSwatch;swatch.scripts.OnEnter(swatch);assert(swatch.art.color[1]==.25,'hover replaced the selected color')
    swatch.scripts.OnLeave(swatch);assert(swatch.art.color[1]==.25,'leaving the swatch replaced the selected color')
end)
test('condition text remains inspectable beneath both action and cooldown details',function()
    local f,parent=fixture();local a=f.addon;local opened=0
    a.ShowConditionEditor=function() opened=opened+1 end
    local pane=assert(a:CreateRotationEditor(parent,0,'mine'))
    for _,id in ipairs({'optional','yes'}) do
        card(pane,id).action:Click();local c=card(pane,id)
        assert(c.condition:IsShown(),'details hid the condition')
        assert(-c.condition.point[3]>=28+c.fields:GetHeight(),'condition overlaps fields')
        c.condition:Click()
    end
    assert(opened==2)
end)
test('condition hover guidance survives redraw and stale handlers cannot replace the current tooltip',function()
    local f,parent=fixture();local a=f.addon;local shown,owner
    f.env.GameTooltip={SetOwner=function(_,frame) owner=frame end,SetText=function(_,text) shown=text end,IsOwned=function(_,frame) return owner==frame end,Hide=function() shown=nil;owner=nil end}
    local pane=assert(a:CreateRotationEditor(parent,0,'mine'));local previous
    for _,id in ipairs({'optional','yes'}) do
        local c=card(pane,id);assert(type(c.condition.scripts.OnEnter)=='function','condition has no hover handler')
        c.condition.scripts.OnEnter(c.condition);assert(shown==pane.switch.tooltip)
        previous=c.condition.scripts.OnEnter;c.condition.scripts.OnLeave(c.condition);assert(shown==nil)
    end
    pane:Render();previous(card(pane,'yes').condition);assert(shown==nil,'retired hover callback displayed a tooltip')
    local c=card(pane,'optional');c.condition.scripts.OnEnter(c.condition);assert(shown==pane.switch.tooltip)
end)
test('condition edit buttons use plain spell names rather than noninteractive link labels',function()
    local f,parent=fixture();f.addon.DescribeCardCondition=function() return 'You have |cff00ffff|Hspell:324|h[Lightning Shield]|h|r' end
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    assert(card(pane,'optional').condition:GetText()=='You have Lightning Shield')
    assert(pane.switchText:GetText()=='You have Lightning Shield')
end)
test('Metadata opens on the config dialog layer and Escape cancels it without the special-frame registry',function()
    local f,parent=fixture();f.env.UISpecialFrames=nil
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));pane.frame:SetFrameStrata('FULLSCREEN_DIALOG');pane.info:Click()
    local dialog=pane.metadataWindow;assert(dialog.frame:IsShown() and dialog.frame:GetFrameStrata()=='FULLSCREEN_DIALOG','metadata opened behind the main config')
    local input=dialog.fields.author;input:SetText('Temporary');input.scripts.OnTextChanged(input,true)
    assert(type(dialog.frame.scripts.OnKeyDown)=='function','Metadata has no fallback Escape handler')
    dialog.frame.scripts.OnKeyDown(dialog.frame,'ESCAPE')
    assert(not dialog.frame:IsShown() and not pane.metadataDirty and pane.workspace:Snapshot().metadata==nil)
end)
test('condition editor titles use the visible default action name and an unfinished step rename',function()
    local f,parent=fixture();local a=f.addon;local heading
    a.Platform.GetSpellLink=function() return '|cff00ffff|Hspell:324|h[Lightning Shield]|h|r' end
    a.ShowConditionEditor=function(_,_,_,_,_,_,options) heading=options.title end
    local pane=assert(a:CreateRotationEditor(parent,0,'mine'));card(pane,'optional').condition:Click()
    assert(heading=='Lightning Shield','unnamed actions lost their visible title')
    local c=card(pane,'optional');c.title:Click();c.name:SetText('Keep shield active');c.name.scripts.OnTextChanged(c.name,true)
    pane:EditCondition('optional');assert(heading=='Keep shield active','pending step name was ignored')
end)
test('metadata description keeps its multiline viewport when native text height shrinks',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));pane.info:Click();local dialog=pane.metadataWindow
    assert(dialog.descriptionArea and dialog.descriptionScroll,'description has no fixed multiline viewport')
    assert(dialog.chrome.version:GetText()=='Metadata' and dialog.chrome.author:GetText()=='Mine' and dialog.title:GetText()=='Rotation Master: Mine')
    local areaHeight=dialog.descriptionArea:GetHeight();pane.description:SetHeight(24)
    assert(dialog.descriptionArea:GetHeight()==areaHeight and areaHeight>=96)
    pane.description:SetText('Opening buffs\nKeep the shield active.');pane.description.scripts.OnTextChanged(pane.description,true)
    dialog.apply:Click();assert(pane.workspace:Snapshot().description=='Opening buffs\nKeep the shield active.')
end)
test('metadata omits an absent source section and grows only when real sources exist',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));pane.info:Click();local dialog=pane.metadataWindow
    assert(not dialog.source:IsShown(),'empty source block is still visible');local compact=dialog.frame:GetHeight();dialog.cancel:Click()
    pane.workspace.reserved={origins={manifest={sources={}}}};for i=1,12 do pane.workspace.reserved.origins.manifest.sources[i]={title='Guide '..i,url='https://example.test/'..i} end
    pane.info:Click();assert(dialog.source:IsShown() and dialog.frame:GetHeight()>compact)
    dialog.cancel:Click();pane:Release();pane=assert(f.addon:CreateRotationEditor(parent,0,'builtin'));pane.info:Click()
    assert(not dialog.source:IsShown() and not dialog.apply:IsEnabled(),'readonly notice was mistaken for source information')
end)
test('condition editor context identifies the kind and the rotation owning the step',function()
    local f,parent=fixture();local captured;f.addon.ShowConditionEditor=function(_,_,_,_,_,_,options) captured=options end
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    for _,entry in ipairs({{'optional','Cooldown'},{'yes','Rotation'}}) do pane:EditCondition(entry[1]);assert(captured.contextLabel==entry[2] and captured.rotationName=='Mine') end
    pane:EditCondition({kind='switch'});assert(captured.contextLabel=='Switch condition' and captured.rotationName=='Mine')
end)
test('rotation move controls track sibling boundaries across moves undo and reflow',function()
    local f,parent=fixture();local source=f.addon:GetEditableRotation(0,'mine')
    source.rotation[2]={id='tail',type='none',conditions={}}
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    assert(not card(pane,'branch').controls.up:IsEnabled() and card(pane,'branch').controls.down:IsEnabled())
    assert(card(pane,'tail').controls.up:IsEnabled() and not card(pane,'tail').controls.down:IsEnabled())
    assert(not card(pane,'yes').controls.up:IsEnabled() and not card(pane,'yes').controls.down:IsEnabled())
    card(pane,'tail').controls.up:Click();pane.canvas:Reflow()
    assert(not card(pane,'tail').controls.up:IsEnabled() and card(pane,'tail').controls.down:IsEnabled())
    pane.undo:Click();assert(card(pane,'tail').controls.up:IsEnabled() and not card(pane,'tail').controls.down:IsEnabled())
end)
test('clearing a saved step name restores its generated title through reflow and Apply',function()
    local f,parent=fixture();local step=f.addon:GetEditableRotation(0,'mine').cooldowns[1];step.name='My shield'
    f.addon.Platform.GetSpellInfo=function(_,id) if id==324 then return {name='Lightning Shield',iconID=1} end end
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local c=card(pane,'optional')
    assert(c.title:GetText()=='My shield');c.title:Click();c.name:SetText('');c.name.scripts.OnTextChanged(c.name,true);c.name:ClearFocus()
    pane.canvas:Reflow();assert(card(pane,'optional').title:GetText()=='Lightning Shield')
    pane.apply:Click();assert(card(pane,'optional').title:GetText()=='Lightning Shield' and not f.addon:GetEditableRotation(0,'mine').cooldowns[1].name)
end)
test('RGBA display is compact without rounding untouched saved channels',function()
    local f,parent=fixture();local step=f.addon:GetEditableRotation(0,'mine').cooldowns[1]
    step.color={r=.12345678,g=.87654321,b=.33333333,a=1}
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));card(pane,'optional').action:Click()
    local fields=card(pane,'optional').fieldControls
    assert(fields.color_r:GetText()=='0.123' and fields.color_g:GetText()=='0.877')
    assert(not pane:HasPendingFields(),'formatting color dirtied rotation')
    fields.color_a:SetText('0.5');fields.color_a.scripts.OnTextChanged(fields.color_a,true);pane.apply:Click()
    local c=f.addon:GetEditableRotation(0,'mine').cooldowns[1].color
    assert(c.r==.12345678 and c.g==.87654321 and c.a==.5,'editing alpha rounded other channels')
end)
test('cooldown magnification supports raw numeric editing and invalid drafts',function()
    local f,parent=fixture();local pane=f.addon:CreateRotationEditor(parent,0,'mine');card(pane,'optional').action:Click()
    local c=card(pane,'optional');local raw=c.fieldControls.magnificationValue;assert(raw.kind=='EditBox','magnification value is not editable')
    raw:SetText('1.37');raw.scripts.OnTextChanged(raw,true);assert(pane:FlushFieldEdits());assert(pane.workspace:Snapshot().cooldowns[1].magnification==1.37)
    raw:SetText('bad');raw.scripts.OnTextChanged(raw,true);assert(not pane:FlushFieldEdits())
end)
test('color popup sliders accept raw numeric values and reject invalid ones',function()
    local f,parent=fixture();local a=f.addon;local d=a:CreateWorkbenchColorPicker(parent);local alpha
    d:Open({r=1,g=0,b=0,a=1},function(_,_,_,value) alpha=value end,function() return true end)
    local raw=assert(d.alphaValue,'alpha slider lacks editable value');raw:SetText('0.375');raw.scripts.OnEnterPressed(raw);assert(alpha==.375)
    raw:SetText('2');raw.scripts.OnEnterPressed(raw);assert(alpha==.375);raw.scripts.OnEscapePressed(raw);assert(raw:GetText()=='0.375')
end)
test('Use color validates pending raw channels and keeps invalid values open',function()
    local f,parent=fixture();local d=f.addon:CreateWorkbenchColorPicker(parent);local color
    d:Open({r=.123456789,g=.234567891,b=.345678912,a=1},function(r,g,b,a) color={r=r,g=g,b=b,a=a} end,function() return true end)
    local accept;for _,c in ipairs(f.nativeFrames) do if c.tooltip=='Use color' then accept=c end end;assert(accept)
    local alpha=d.alphaValue;alpha:SetText('0.25');if alpha.scripts.OnTextChanged then alpha.scripts.OnTextChanged(alpha,true) end;accept:Click()
    assert(color and color.a==.25 and math.abs(color.r-.123456789)<1e-12,'pending numeric alpha was discarded or untouched color rounded')
    d:Open({r=.1,g=.2,b=.3,a=1},function(r,g,b,a) color={r=r,g=g,b=b,a=a} end,function() return true end);alpha:SetText('bad');if alpha.scripts.OnTextChanged then alpha.scripts.OnTextChanged(alpha,true) end;accept:Click();assert(d.frame:IsShown(),'invalid numeric input closed the picker')
end)
test('metadata tags stage atomically with details and support undo cancel and readonly defaults',function()
    local f,parent=fixture();local a=f.addon;local pane=assert(a:CreateRotationEditor(parent,0,'mine'));local d=pane.metadataWindow;d:Open();assert(d.fields.tags,'tag field missing');d.fields.tags:SetText('AOE, MyLittlePony');d.fields.tags.scripts.OnTextChanged(d.fields.tags,true);d.apply:Click();assert(pane.workspace:Snapshot().tags[2]=='MyLittlePony' and a:GetEditableRotation(0,'mine').tags==nil);pane.undo:Click();assert(pane.workspace:Snapshot().tags==nil);pane.redo:Click();pane.apply:Click();assert(a:GetEditableRotation(0,'mine').tags[1]=='AOE');d:Open();d.fields.tags:SetText('PVP');d.fields.tags.scripts.OnTextChanged(d.fields.tags,true);d.cancel:Click();assert(not pane:HasUnsavedChanges() and pane.workspace:Snapshot().tags[1]=='AOE')
    pane:Release();pane=assert(a:CreateRotationEditor(parent,0,'builtin'));d=pane.metadataWindow;d:Open();assert(not d.apply:IsEnabled());local before=pane.workspace:Snapshot();d.fields.tags:SetText('Changed');d.fields.tags.scripts.OnTextChanged(d.fields.tags,true);assert(not pane.tagsDirty and a.RotationData.CopyData(before).tags==nil)
end)
test('unchanged inherited tags do not dirty a clone and malformed saved tags can be repaired',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.rotationLibrary={origins={[0]={mine={manifest={tags={'leveling'}}}}}};local pane=assert(a:CreateRotationEditor(parent,0,'mine'));local d=pane.metadataWindow;d:Open();assert(d.fields.tags:GetText()=='leveling');d.fields.tags.scripts.OnTextChanged(d.fields.tags,true);d.apply:Click();assert(not pane:HasUnsavedChanges() and pane.workspace:Snapshot().tags==nil)
    pane:Release();a.db.profile.rotations[0].mine.tags=false;pane=assert(a:CreateRotationEditor(parent,0,'mine'));d=pane.metadataWindow;d:Open();d.fields.tags:SetText('');d.fields.tags.scripts.OnTextChanged(d.fields.tags,true);d.apply:Click();assert(type(pane.workspace:Snapshot().tags)=='table' and #pane.workspace:Snapshot().tags==0)
end)
test('switch priority stages with metadata validation history cancellation and readonly defaults',function()
    local f,parent=fixture();local a=f.addon;local pane=assert(a:CreateRotationEditor(parent,0,'mine'));local d=pane.metadataWindow;d:Open()
    local field=d.fields.priority;assert(field,'priority field missing');assert(field:GetText()=='0')
    d.apply:Click();assert(not pane:HasUnsavedChanges() and pane.workspace:Snapshot().priority==nil,'unchanged zero materialized a priority')
    d:Open();field:SetText('2.5');field.scripts.OnTextChanged(field,true);assert(field:GetText()=='0');field:SetText('-');field.scripts.OnTextChanged(field,true);d.apply:Click();assert(d.frame:IsShown() and pane.workspace:Snapshot().priority==nil,'invalid priority changed the draft')
    field:SetText('25');field.scripts.OnTextChanged(field,true);d.apply:Click();assert(pane.workspace:Snapshot().priority==25 and a:GetEditableRotation(0,'mine').priority==nil)
    pane.undo:Click();assert(pane.workspace:Snapshot().priority==nil);pane.redo:Click();pane.apply:Click();assert(a:GetEditableRotation(0,'mine').priority==25)
    d:Open();field:SetText('-10');field.scripts.OnTextChanged(field,true);d.cancel:Click();assert(not pane:HasUnsavedChanges() and pane.workspace:Snapshot().priority==25)
    pane:Release();pane=assert(a:CreateRotationEditor(parent,0,'builtin'));d=pane.metadataWindow;d:Open();field=d.fields.priority;field:SetText('50');field.scripts.OnTextChanged(field,true);assert(not pane.priorityDirty and not d.apply:IsEnabled())
end)
test('diagram and compact list share one guarded draft and switching views preserves pending edits and history',function()
    local f,parent=fixture();local a=f.addon;local pane=assert(a:CreateRotationEditor(parent,0,'mine'))
    assert(pane.viewMode,'view toggle missing');assert(not pane:HasUnsavedChanges())
    pane.viewMode:Click();assert(pane.view.layout=='list' and pane.canvas.scene.layout=='list' and not pane:HasUnsavedChanges())
    assert(card(pane,'yes').model.compact);card(pane,'yes').title:Click();assert(not card(pane,'yes').model.compact)
    card(pane,'yes').action:Click();card(pane,'yes').fieldControls.suppress:Click()
    assert(pane.workspace:Snapshot().rotation[1].onTrue[1].suppress_attack)
    pane.viewMode:Click();assert(pane.view.layout=='diagram');pane.undo:Click();assert(not pane.workspace:Snapshot().rotation[1].onTrue[1].suppress_attack)
    local other=f.env.CreateFrame('Frame');other:SetSize(740,600);local readOnly=assert(a:CreateRotationEditor(other,0,'builtin'))
    readOnly.viewMode:Click();assert(readOnly.canvas.scene.layout=='list' and not card(readOnly,'yes').controls.remove:IsEnabled())
end)
test('content switching flushes valid fields and blocks invalid hidden edits',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    card(pane,'optional').action:Click();local input=card(pane,'optional').fieldControls.xoffs
    input:SetText('12');input.scripts.OnTextChanged(input,true);pane.contentTabs.rotation:Click()
    assert(pane.view.section=='rotation' and pane.workspace:Snapshot().cooldowns[1].xoffs==12)
    local red=card(pane,'optional').fieldControls.color_r;red:SetText('unfinished');red.scripts.OnTextChanged(red,true)
    pane.contentTabs.rotation:Click();assert(pane.view.section=='cooldowns' and pane:HasInvalidPendingFields())
    assert(card(pane,'optional').fieldControls.color_r:GetText()=='unfinished')
    local stale=pane.contentTabs.rotation.scripts.OnClick;pane:Release();stale();assert(pane.view.section=='cooldowns')
end)
test('canvas zoom uses separate scaled content extents and preserves center without resizing the window',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local c=pane.canvas
    assert(c.SetZoom and pane.zoomIn and pane.zoomOut and pane.zoomReset,'zoom controls missing')
    local width,height=pane.frame:GetWidth(),pane.frame:GetHeight();local sceneWidth,sceneHeight=c.scene.width,c.scene.height
    assert(c:SetZoom(2));assert(c.child:GetScale()==2 and c.surface==c.frame:GetScrollChild())
    assert(c.surface:GetWidth()==sceneWidth*2+c.frame:GetWidth() and c.surface:GetHeight()==sceneHeight*2+c.frame:GetHeight())
    assert(c.horizontal.scrollRange==sceneWidth*2)
    assert(c.frame.workbenchBar.scrollRange==sceneHeight*2)
    c.horizontal:SetValue(150);c.frame.workbenchBar:SetValue(100)
    local center=150/2;assert(c:SetZoom(1.8))
    assert(math.abs(c.scrollX-(center*1.8))<.0001)
    assert(pane.frame:GetWidth()==width and pane.frame:GetHeight()==height and pane.frame:GetScale()==1 and not pane:HasUnsavedChanges())
    pane.zoomReset:Click();assert(c:GetZoom()==1 and pane.zoomReset:GetText()=='100%')
    assert(not c:SetZoom(0/0) and not c:SetZoom('2'));c:SetZoom(20);assert(c:GetZoom()==2 and not pane.zoomIn:IsEnabled())
    c:SetZoom(.1);assert(c:GetZoom()==.25 and not pane.zoomOut:IsEnabled())
end)
test('blank canvas panning follows pointer deltas at window scale and clamps through both scrollbars',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local c=pane.canvas
    assert(c.BeginPan,'panning missing');assert(c:SetZoom(2))
    c.frame.GetEffectiveScale=function() return 2 end
    local x,y,down=300,300,true;f.env.GetCursorPosition=function() return x,y end;f.env.IsMouseButtonDown=function() return down end
    c.horizontal:SetValue(100);c.frame.workbenchBar:SetValue(100);c.child.scripts.OnDragStart(c.child)
    assert(c.pan and not c.drag);x=260;y=340;c.frame.scripts.OnUpdate(c.frame)
    assert(c.scrollX==120 and c.frame.workbenchBar:GetValue()==120)
    x=10000;y=-10000;c.frame.scripts.OnUpdate(c.frame);assert(c.scrollX==0 and c.frame.workbenchBar:GetValue()==0)
    down=false;c.frame.scripts.OnUpdate(c.frame);assert(not c.pan and not c.frame.scripts.OnUpdate)
    c:BeginDrag('yes');assert(not c:BeginPan() and c.drag,'blank pan stole a card drag');c:CancelDrag()
end)
test('zoom controls respect workspace mode read-only access and released guards',function()
    local f,parent=fixture();local a=f.addon;local pane=assert(a:CreateRotationEditor(parent,0,'mine'));local c=pane.canvas
    card(pane,'optional').action:Click();local raw=card(pane,'optional').fieldControls.xoffs
    raw:SetText('unfinished');raw.scripts.OnTextChanged(raw,true);pane.zoomIn:Click()
    assert(c:GetZoom()==1 and raw:GetText()=='unfinished' and pane:HasInvalidPendingFields())
    raw:SetText('12');raw.scripts.OnTextChanged(raw,true);pane.contentTabs.rotation:Click()
    pane.zoomIn:Click();assert(c:GetZoom()==1.1)
    f.env.GetCursorPosition=function() return 10,10 end;f.env.IsMouseButtonDown=function() return true end;c:BeginPan();local stale=c.frame.scripts.OnUpdate
    pane:Release();stale();assert(not c.pan and not c.drag)
    local other=f.env.CreateFrame('Frame');other:SetSize(740,600);local ro=assert(a:CreateRotationEditor(other,0,'builtin'))
    ro.zoomIn:Click();assert(ro.canvas:GetZoom()==1.1 and not ro:HasUnsavedChanges())
    ro.canvas:BeginPan();assert(ro.canvas.pan);ro.canvas:Render();assert(not ro.canvas.pan)
    ro.viewMode:Click();ro.zoomIn:Click();assert(ro.canvas:GetZoom()==1 and not ro.canvas:BeginPan())
end)
test('blank pan does not capture a card under the pointer and zoom keeps typed drop identities intact',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local c=pane.canvas
    f.env.GetCursorPosition=function() return 10,10 end
    local targetCard=card(pane,'yes').frame;f.env.MouseIsOver=function(frame) return frame==targetCard or frame==c.frame end
    assert(not c:BeginPan(),'panning started over an editing card')
    f.env.MouseIsOver=nil;c:SetZoom(.5);pane.viewMode:Click()
    local destination
    for _,target in ipairs(c.scene.dropTargets) do if target.destination.parentId=='branch' and target.destination.path[3]=='onFalse' and target.destination.index==2 then destination=target end end
    assert(destination);c:BeginDrag('yes');assert(c:Drop(destination))
    assert(pane.workspace:Snapshot().rotation[1].onFalse[2].id=='yes' and c:GetZoom()==1 and pane.view.zoom==.5)
end)
test('rotation and cooldown workspaces isolate cards layout and zoom without saving view choices',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    assert(pane.view.section=='rotation' and pane.contentTabs,'workspace selector missing')
    assert(visibleCard(pane,'yes') and not visibleCard(pane,'optional'))
    pane.canvas:SetZoom(1.5);pane.viewMode:Click();assert(pane.canvas:GetZoom()==1 and not pane.zoomBar:IsShown() and not pane.canvas:BeginPan())
    pane.contentTabs.cooldowns:Click();assert(pane.view.section=='cooldowns' and visibleCard(pane,'optional') and not visibleCard(pane,'yes'))
    assert(not visibleCard(pane,'optional').model.compact and not pane.viewMode:IsShown() and not pane.canvas:SetZoom(2))
    pane.contentTabs.rotation:Click();pane.viewMode:Click();assert(pane.canvas:GetZoom()==1.5 and pane.zoomBar:IsShown() and not pane:HasUnsavedChanges())
end)
test('diagram viewport wheel zoom middle reset and blank click pan cannot become scrollbar gestures',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local c=pane.canvas
    assert(pane.zoomBar and pane.zoomBar:GetParent()==c.frame and pane.zoomBar.point[1]=='BOTTOMRIGHT')
    assert(not c.frame.workbenchBar:IsShown() and not c.horizontal:IsShown())
    c.frame.scripts.OnMouseWheel(c.frame,1);assert(c:GetZoom()==1.1)
    local x,y,down=300,300,true;f.env.GetCursorPosition=function() return x,y end;f.env.IsMouseButtonDown=function() return down end
    local sx,sy=c.scrollX,c.frame.workbenchBar:GetValue()
    c.frame.scripts.OnMouseDown(c.frame,'LeftButton');assert(c.pan,'viewport did not accept blank press')
    x=260;y=340;c.frame.scripts.OnUpdate(c.frame);assert(c.scrollX==sx+40 and c.frame.workbenchBar:GetValue()==sy+40)
    c.frame.scripts.OnMouseUp(c.frame,'LeftButton');assert(not c.pan)
    c.frame.scripts.OnMouseUp(c.frame,'MiddleButton');assert(c:GetZoom()==1)
    pane.viewMode:Click();local stored=pane.view.zoom;c.frame.scripts.OnMouseWheel(c.frame,-1);c.frame.scripts.OnMouseUp(c.frame,'MiddleButton')
    assert(c:GetZoom()==1 and pane.view.zoom==stored and not c:BeginPan())
end)
test('content switching preserves staged fields and rejects hiding an invalid field',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    assert(pane.contentTabs,'workspace selector missing');pane.contentTabs.cooldowns:Click();visibleCard(pane,'optional').action:Click()
    local input=visibleCard(pane,'optional').fieldControls.xoffs;input:SetText('unfinished');input.scripts.OnTextChanged(input,true)
    pane.contentTabs.rotation:Click();assert(pane.view.section=='cooldowns' and input:GetText()=='unfinished' and pane:HasInvalidPendingFields())
    input:SetText('12');input.scripts.OnTextChanged(input,true);pane.contentTabs.rotation:Click()
    assert(pane.view.section=='rotation' and pane.workspace:Snapshot().cooldowns[1].xoffs==12 and f.addon:GetEditableRotation(0,'mine').cooldowns[1].xoffs==nil)
    pane.undo:Click();assert(pane.workspace:Snapshot().cooldowns[1].xoffs==nil)
    assert(not pane.switchCollapsedHint and not pane.sectionTools.cooldowns.hint,'whole section collapse remained')
end)
test('General preferred rotation view initializes new editors and changed preferences on reopen',function()
    local f,parent=fixture();local a=f.addon
    local pane=assert(a:CreateRotationEditor(parent,0,'mine'));assert(pane.view.layout=='diagram')
    pane.viewMode:Click();assert(pane.view.layout=='list' and a.db.profile.rotation_view==nil)
    pane:Open(0,'mine');assert(pane.view.layout=='list','temporary choice was lost within this workspace')
    a.db.profile.rotation_view='list';pane:Open(0,'mine');assert(pane.view.layout=='list')
    a.db.profile.rotation_view='diagram';pane:Open(0,'mine');assert(pane.view.layout=='diagram')
    a.db.profile.rotation_view='list';local other=f.env.CreateFrame('Frame');other:SetSize(740,600)
    local ro=assert(a:CreateRotationEditor(other,0,'builtin'));assert(ro.view.layout=='list' and ro.canvas:GetZoom()==1 and not ro:HasUnsavedChanges())
end)
test('normal lists scroll independently while diagram restores its camera across views and resize',function()
    local f,parent=fixture();local value=f.addon:GetEditableRotation(0,'mine')
    for i=1,40 do value.rotation[#value.rotation+1]={id='long'..i,type='none',conditions={}};value.cooldowns[#value.cooldowns+1]={id='cd'..i,type='spell',action=324,conditions={}} end
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local c=pane.canvas
    c.horizontal:SetValue(c.paddingX+80);c.frame.workbenchBar:SetValue(c.paddingY+120)
    pane.viewMode:Click();assert(c.frame.workbenchBar:IsShown() and not pane.zoomBar:IsShown())
    c.frame.scripts.OnMouseWheel(c.frame,-1);assert(c.frame.workbenchBar:GetValue()==40)
    pane.contentTabs.cooldowns:Click();assert(c.frame.workbenchBar:GetValue()==0 and c.frame.workbenchBar:IsShown() and c.child:GetScale()==1)
    c.frame.scripts.OnMouseWheel(c.frame,-1);c.frame.scripts.OnMouseWheel(c.frame,-1);assert(c.frame.workbenchBar:GetValue()==80)
    pane.contentTabs.rotation:Click();assert(c.frame.workbenchBar:GetValue()==40)
    assert(#c.groups>0 and c.groups[1]:IsShown())
    pane.viewMode:Click();assert(c.scrollX==c.paddingX+80 and c.frame.workbenchBar:GetValue()==c.paddingY+120)
    assert(not c.frame.workbenchBar:IsShown() and not c.groups[1]:IsShown())
    parent:SetSize(820,650);pane:SetWidth(820);pane:SetHeight(650);pane:Layout()
    assert(c.scrollX==c.paddingX+80 and c.frame.workbenchBar:GetValue()==c.paddingY+120)
    c.frame:UpdateWorkbenchScroll();assert(not c.frame.workbenchBar:IsShown(),'native extent callback exposed diagram scrollbar')
    pane:Open(0,'mine');assert(c.scrollX==c.paddingX+80 and c.frame.workbenchBar:GetValue()==c.paddingY+120)
    assert(not pane:HasUnsavedChanges())
end)
test('retired card wheel and middle callbacks cannot navigate a reopened workspace',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    local c=visibleCard(pane,'yes');local wheel,middle=c.title.scripts.OnMouseWheel,c.title.scripts.OnMouseUp
    pane:Open(0,'builtin');wheel(c.title,1);assert(pane.canvas:GetZoom()==1,'retired card zoomed another workspace')
    pane.canvas:SetZoom(1.5);middle(c.title,'MiddleButton');assert(pane.canvas:GetZoom()==1.5,'retired card reset another workspace')
end)
test('ordinary drag moves a leading card into a following branch without carrying its destination',function()
    local f,parent=fixture();local value=f.addon:GetEditableRotation(0,'mine')
    table.insert(value.rotation,1,{id='first',type='none',conditions={}})
    value.rotation[3]={id='last',type='none',conditions={}}
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local c=pane.canvas;local target
    for _,gap in ipairs(c.scene.dropTargets) do if gap.destination.parentId=='branch' and gap.destination.path[3]=='onTrue' and gap.destination.index==1 then target=gap end end
    c:BeginDrag('first');assert(c:CanDrop(target),'single drag accidentally carries destination branch');assert(c:Drop(target))
    local v=pane.workspace:Snapshot();assert(v.rotation[1].id=='branch' and v.rotation[2].id=='last' and v.rotation[1].onTrue[1].id=='first')
    pane.undo:Click();assert(pane.workspace:Snapshot().rotation[1].id=='first')
    f.env.IsControlKeyDown=function() return true end;c:BeginDrag('first');assert(not c:CanDrop(target),'Ctrl tail permits a cycle');c:CancelDrag()
end)
test('Ctrl rotation drag preview has a separate multiple-card count and stack',function()
    local f,parent=fixture();local value=f.addon:GetEditableRotation(0,'mine');value.rotation[2]={id='last',type='none',conditions={}}
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));f.env.IsControlKeyDown=function() return true end
    pane.canvas:BeginDrag('branch');local ghost=pane.canvas.ghost
    assert(ghost.count and ghost.count:IsShown() and ghost.count:GetText():find('4',1,true),'multiple card count missing')
    assert(ghost.liveEntries and #ghost.liveEntries>=4 and visibleCard(pane,'branch').frame:GetParent()==ghost,'multiple drag does not contain the actual cards')
    pane.canvas:CancelDrag();f.env.IsControlKeyDown=function() return false end;pane.canvas:BeginDrag('last')
    assert(not ghost.count:IsShown() and not ghost.stack[1]:IsShown(),'single drag retained multiple presentation')
end)
test('arm label buttons fold one side on readonly and editable rotations with stale guards',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'builtin'));local c=pane.canvas
    local button
    for _,control in ipairs(c.armButtons or {}) do if control.model.parentId=='branch' and control.model.arm=='false' then button=control end end
    assert(button,'arm fold control missing');local stale=button.scripts.OnClick;button:Click()
    assert(not visibleCard(pane,'no') and visibleCard(pane,'yes') and not pane:HasUnsavedChanges())
    stale();assert(not visibleCard(pane,'no'),'retired arm callback changed current fold')
    for _,control in ipairs(c.armButtons) do if control.model.parentId=='branch' and control.model.arm=='false' then assert(control:GetText():find('1',1,true));control:Click();break end end
    assert(visibleCard(pane,'no'));pane.viewMode:Click();assert(#c.armButtons>=2)
    pane:Release();stale();assert(not pane.active)
end)
test('rotation dragging lifts actual branch cards and connectors then restores placeholders on cancel',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local c=pane.canvas;local branch=visibleCard(pane,'branch');local yes=visibleCard(pane,'yes')
    c:BeginDrag('branch');assert(branch.frame:GetParent()==c.ghost and yes.frame:GetParent()==c.ghost,'source cards were not lifted')
    assert(c.ghost.placeholders[1]:IsShown() and #c.ghost.previewLines>0)
    c:CancelDrag();assert(branch.frame:GetParent()==c.child and yes.frame:GetParent()==c.child and not c.ghost.liveEntries)
    c:BeginDrag('branch');pane:Release();assert(branch.frame:GetParent()==c.child and not c.ghost:IsShown())
end)
test('unsaved rotation markers follow fields cards switch and Apply Undo or Discard baselines',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local c=visibleCard(pane,'yes')
    assert(not c.frame.rmUnsaved and not pane.name.rmUnsaved)
    pane:Command('UpdateStep','yes',{suppress_attack=true});assert(visibleCard(pane,'yes').frame.rmUnsaved and visibleCard(pane,'branch').frame.rmUnsaved)
    pane.undo:Click();assert(not visibleCard(pane,'yes').frame.rmUnsaved)
    pane.name:SetText('Changed name');pane.name.scripts.OnTextChanged(pane.name,true);assert(pane.name.rmUnsaved)
    pane:Command('SetCondition',{kind='switch'},{type='AND',value={}});assert(pane.switch.rmUnsaved)
    local ok,why=pane:Apply();assert(ok,why);assert(not pane.name.rmUnsaved and not pane.switch.rmUnsaved)
end)
test('metadata tag chips priority buttons and per-field markers preserve Cancel and defaults',function()
    local f,parent=fixture();local a=f.addon;local pane=assert(a:CreateRotationEditor(parent,0,'mine'));pane.info:Click();local d=pane.metadataWindow
    assert(d.tagPicker and d.priorityDown and not pane.info.rmUnsaved)
    d.tagPicker.input:SetText('MyLittlePony');d.tagPicker.input.scripts.OnEnterPressed(d.tagPicker.input)
    assert(pane.tagsDirty and d.tagPicker.frame.rmUnsaved and pane.info.rmUnsaved and pane.workspace:Snapshot().tags==nil)
    d.priorityDown:Click();assert(pane.priority:GetText()=='-1' and pane.priority.rmUnsaved)
    d.priorityUp:Click();assert(pane.priority:GetText()=='0' and not pane.priority.rmUnsaved)
    d.cancel:Click();assert(not pane.info.rmUnsaved and not pane.tagsDirty)
    d:Open();local author=d.fields.author;author:SetText('PreZ');author.scripts.OnTextChanged(author,true);assert(author.rmUnsaved and pane.info.rmUnsaved)
    author:SetText('');author.scripts.OnTextChanged(author,true);assert(not author.rmUnsaved and not pane.info.rmUnsaved)
    d.cancel:Click()
end)
test('metadata shows guide sources while retaining individual spell evidence in imported provenance',function()
    local f,parent=fixture();local a=f.addon;a.db.profile.rotationLibrary={imports={[0]={mine={manifest={sources={{url='https://www.icy-veins.com/tbc-classic/mage-leveling-guide',title='Mage guide'},{url='https://wowclassicdb.com/tbc/spell/133',title='Fireball record'}}}}}}}
    local pane=assert(a:CreateRotationEditor(parent,0,'mine'));pane.info:Click();local d=pane.metadataWindow
    assert(d.source:GetText():find('Mage guide',1,true) and not d.source:GetText():find('Fireball record',1,true))
    assert(#pane.workspace.reserved.imports.manifest.sources==2)
end)
test('pending child fields mark branch ancestors and priority buttons preserve invalid text',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    pane:StageField('yes','name','Unsaved child','', 'Name');assert(visibleCard(pane,'yes').frame.rmUnsaved and visibleCard(pane,'branch').frame.rmUnsaved)
    pane.info:Click();local d=pane.metadataWindow;pane.priority:SetText('-');pane.priority.scripts.OnTextChanged(pane.priority,true);d.priorityUp:Click();assert(pane.priority:GetText()=='-','unfinished minus became a valid priority')
end)
test('View Changes compares saved and raw draft values without applying or creating history',function()
    local f,parent=fixture();local a=f.addon;local pane=assert(a:CreateRotationEditor(parent,0,'mine'));assert(pane.viewChanges and not pane.viewChanges:IsEnabled())
    pane.name:SetText('Pending name');pane.name.scripts.OnTextChanged(pane.name,true);pane:StageField('optional','magnification','bad','','Magnification')
    assert(pane.viewChanges:IsEnabled());pane.viewChanges:Click();local d=pane.draftComparisonOwner.comparison
    assert(d.frame:IsShown() and d.leftHeading:GetText()=='Saved' and d.rightHeading:GetText()=='Unsaved')
    local foundName,foundBad=false,false;for _,row in ipairs(d.rows) do if row.label=='Name' and row.right=='Pending name' then foundName=true end;if row.right=='bad' then foundBad=true end end
    assert(foundName and foundBad and a:GetEditableRotation(0,'mine').name=='Mine' and not pane.workspace.session:HistoryState().canUndo)
    pane:Release();d.frame.scripts.OnUpdate();assert(not d.frame:IsShown())
end)
test('large list reaches its last row using a bounded reusable native card pool',function()
    local f,parent=fixture();local many={};for i=1,1000 do many[i]={id='large'..i,type='none',conditions={}} end
    f.addon.db.profile.rotations[0].mine={name='Large',rotation=many,cooldowns={}}
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));pane.view.layout='list';pane:Render()
    local c=pane.canvas
    assert(#c.scene.cards==1000 and c.scene.complete,'large scene was truncated')
    assert(visibleCard(pane,'large1') and not visibleCard(pane,'large1000'))
    assert(#c.cards<100,'allocated native controls for offscreen cards')
    local old=visibleCard(pane,'large1').controls.remove.scripts.OnClick
    c.frame.workbenchBar:SetValue(c.frame.workbenchBar.scrollRange)
    assert(visibleCard(pane,'large1000') and not visibleCard(pane,'large1'),'scroll did not populate last cards')
    old();assert(#pane.workspace:Snapshot().rotation==1000,'recycled callback acted on a stale card')
    c.frame.workbenchBar:SetValue(c.frame.workbenchBar.scrollRange/2);local peak=#c.cards
    for pass=1,2 do for i=1,10 do c.frame.workbenchBar:SetValue(c.frame.workbenchBar.scrollRange*i/10) end end
    assert(#c.cards<=peak+2 and #c.cards<100,'pool kept growing after scrolling: '..peak..' -> '..#c.cards)
    c.frame.workbenchBar:SetValue(0);assert(visibleCard(pane,'large1'))
end)
test('large scene scrolling preserves pending names and details without rebinding focused controls',function()
    local f,parent=fixture();local many={};for i=1,350 do many[i]={id='entry'..i,type='none',conditions={}} end
    f.addon.db.profile.rotations[0].mine={name='Large',rotation=many,cooldowns={}}
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));pane.view.layout='list';pane:Render()
    pane.view.cardStates.entry350='expanded';pane:Render()
    local c=pane.canvas;local first=visibleCard(pane,'entry1')
    first.title:Click();first=visibleCard(pane,'entry1');first.title:Click()
    first.name:SetText('Still typing');first.name.scripts.OnTextChanged(first.name,true)
    local input=first.name
    c.frame.workbenchBar:SetValue(c.frame.workbenchBar.scrollRange)
    assert(first.token and first.model.id=='entry1' and input:HasFocus() and input:IsShown(),'scroll or measured reflow hid focused name input')
    input:ClearFocus();c.frame.workbenchBar:SetValue(c.frame.workbenchBar.scrollRange-1)
    c.frame.workbenchBar:SetValue(0);first=visibleCard(pane,'entry1')
    assert(first.title:GetText()=='Still typing' and pane.workspace:Snapshot().rotation[1].name==nil)
    first.action:Click();local field=visibleCard(pane,'entry1').fieldControls
    assert(field and pane.view.cardStates.entry1=='expanded')
    c.frame.workbenchBar:SetValue(c.frame.workbenchBar.scrollRange);c.frame.workbenchBar:SetValue(0)
    assert(visibleCard(pane,'entry1').fieldControls and pane.view.cardStates.entry1=='expanded')
    assert(pane:HasUnsavedChanges(),'recycling discarded pending text')
end)
test('first materialization of an offscreen details card updates its measured geometry',function()
    local f,parent=fixture();local many={};for i=1,350 do many[i]={id='entry'..i,type='none',conditions={}} end
    f.addon.db.profile.rotations[0].mine={name='Large',rotation=many,cooldowns={}}
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));pane.view.layout='list'
    pane.view.cardStates.entry300='expanded';pane:Render();local c=pane.canvas
    local y;for _,m in ipairs(c.scene.cards) do if m.id=='entry300' then y=m.y end end
    c.frame.workbenchBar:SetValue(y)
    assert(visibleCard(pane,'entry300') and pane.view.detailsHeights.entry300<80)
    for _,m in ipairs(c.scene.cards) do if m.id=='entry300' then assert(m.height<120,'newly visible details retained estimated height') end end
end)
test('large diagram visibility follows zoom and pan coordinates without recycling a drag source',function()
    local f,parent=fixture();local many={};for i=1,350 do many[i]={id='entry'..i,type='none',conditions={}} end
    f.addon.db.profile.rotations[0].mine={name='Large',rotation=many,cooldowns={}}
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local c=pane.canvas
    local model=c.scene.cards[350]
    c.frame.workbenchBar:SetValue(c.paddingY+model.y);assert(visibleCard(pane,'entry350'))
    c:SetZoom(.5);c.frame.workbenchBar:SetValue(c.paddingY+model.y*.5)
    assert(visibleCard(pane,'entry350') and #c.cards<100,'zoom/padding hid the final card or materialized the whole tree')
    c:BeginDrag('entry350');local dragged=visibleCard(pane,'entry350');local token=dragged.token
    c.frame.workbenchBar:SetValue(0);assert(dragged.token==token,'scroll recycled a floating drag source')
    assert(visibleCard(pane,'entry1'),'drag-scrolling left destination cards blank')
    c:CancelDrag();assert(not visibleCard(pane,'entry350') and visibleCard(pane,'entry1'))
end)
test('failed viewport construction releases its reentry guard so a later refresh can recover',function()
    local f,parent=fixture();local many={};for i=1,350 do many[i]={id='entry'..i,type='none',conditions={}} end
    f.addon.db.profile.rotations[0].mine={name='Large',rotation=many,cooldowns={}}
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local c=pane.canvas
    pane.view.cardStates.entry350='expanded';pane:Render()
    local build=pane.BuildFields;pane.BuildFields=function() error('transient field construction failure') end
    local model=c.scene.cards[350];local ok=pcall(function() c.frame.workbenchBar:SetValue(c.paddingY+model.y) end)
    assert(not ok and not c.refreshing,'failed native construction retained the viewport lock')
    pane.BuildFields=build;c:RefreshVisibleCards();local recovered=visibleCard(pane,'entry350')
    assert(recovered and recovered.fieldControls,'partially bound card was retained after a failed construction')
end)
test('active diagram panning populates newly exposed cards before the gesture ends',function()
    local f,parent=fixture();local many={};for i=1,350 do many[i]={id='entry'..i,type='none',conditions={}} end
    f.addon.db.profile.rotations[0].mine={name='Large',rotation=many,cooldowns={}}
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local c=pane.canvas
    local x,y=200,200;f.env.GetCursorPosition=function() return x,y end
    f.env.IsMouseButtonDown=function() return true end
    assert(c:BeginPan());local last=c.scene.cards[350]
    y=y+last.y;c.frame.scripts.OnUpdate(c.frame)
    assert(c.pan and visibleCard(pane,'entry350'),'panning showed an empty viewport until mouse release')
    c:CancelDrag()
end)
finish()
