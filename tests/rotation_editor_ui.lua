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
    for _,file in ipairs({'UI/rotation_cards.lua','UI/rotation_canvas.lua','UI/color_picker.lua','UI/rotation_effect_fields.lua','UI/rotation_fields.lua','UI/rotation_navigation.lua','UI/rotation_metadata.lua','UI/rotation_editor.lua'}) do local h=io.open(file);if h then h:close();f.load(file) end end
    local parent=create('Frame');parent:SetSize(740,600)
    return f,parent
end
local function card(pane,id) for _,c in ipairs(pane.canvas.cards) do if c.model and c.model.id==id and c.frame:IsShown() then return c end end end
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
    controls.spell.callbacks.OnEnterPressed(controls.spell,nil,'403')
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
    assert(pane.palette.optional:GetParent()==pane.canvas.child)
    assert(pane.palette.optional:GetText()=='Add cooldown' and pane.palette.branch:GetText()=='Add branch')
    local b=card(pane,'branch');assert(not b.preview:IsShown() and b.title:GetText()~='Conditional branch')
    assert(b.controls.enable.pillDecoration and pane.delete)
end)
test('drag into an arm moves the following sequence as one undoable edit',function()
    local f,parent=fixture();local value=f.addon:GetEditableRotation(0,'mine')
    value.rotation[2]={id='second',type='none',conditions={}}
    value.rotation[3]={id='third',type='none',conditions={}}
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));pane.canvas:BeginDrag('second')
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
    pane.sectionTools.cooldowns.toggle:Click();assert(not card(pane,'optional'))
    pane.sectionTools.cooldowns.expand:Click();assert(not card(pane,'optional').model.expanded and not card(pane,'optional').model.compact)
    pane.sectionTools.cooldowns.collapse:Click();assert(card(pane,'optional').model.compact)
    assert(pane.hint:GetText():find('condition',1,true))
end)
test('readonly expanded branch condition inspection remains enabled after disabled field pool reuse',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'builtin'));local inspected=false
    f.addon.ShowConditionEditor=function(_,_,_,_,_,_,options) inspected=options.readOnly end
    card(pane,'optional').action:Click();assert(not card(pane,'optional').fieldPool.choices[1]:IsEnabled())
    pane.sectionTools.cooldowns.toggle:Click();pane.view.cardStates.branch='expanded';pane:Render()
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
test('section headings collapse their contents without separate arrow controls',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    assert(pane.sectionTools.cooldowns.toggle==pane.sectionLabels.cooldowns and not pane.sectionLabels.cooldowns.icon)
    pane.sectionLabels.cooldowns:Click();assert(not card(pane,'optional'))
    pane.sectionLabels.cooldowns:Click();assert(card(pane,'optional'))
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
test('switch heading folds the condition summary while condition text opens its editor',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'));local inspected=false
    f.addon.ShowConditionEditor=function() inspected=true end
    pane.switchLabel:Click();assert(not pane.switch:IsShown());pane.switchLabel:Click();assert(pane.switch:IsShown())
    pane.switch:Click();assert(inspected)
end)
test('changing action type replaces a named item picker selection without stale fields',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    card(pane,'optional').action:Click();local typeField=card(pane,'optional').fieldControls.type;typeField:Click();typeField.menu.rows[4]:Click()
    local items=card(pane,'optional').fieldControls.item1;items.callbacks.OnEnterPressed(items,nil,'123')
    typeField=card(pane,'optional').fieldControls.type;typeField:Click();typeField.menu.rows[1]:Click()
    local spell=card(pane,'optional').fieldControls.spell;spell.callbacks.OnEnterPressed(spell,nil,'324')
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
test('collapsed section replaces tools with a hint and has no separator line or empty card space',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    pane.sectionLabels.cooldowns:Click();local tools=pane.sectionTools.cooldowns
    assert(pane.separator==nil and not tools.expand:IsShown() and not tools.collapse:IsShown() and not pane.palette.optional:IsShown())
    assert(tools.hint:IsShown() and pane.canvas.scene.sections.rotation.y-pane.canvas.scene.sections.cooldowns.y<=36)
    pane.sectionLabels.cooldowns:Click();assert(tools.expand:IsShown() and pane.palette.optional:IsShown() and not tools.hint:IsShown())
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
test('collapsed section hints open all three sections and condition summaries explain editing',function()
    local f,parent=fixture();local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    for _,key in ipairs({'cooldowns','rotation'}) do
        pane.sectionLabels[key]:Click();local hint=pane.sectionTools[key].hint
        assert(hint.kind=='Button' or hint.Click,'expand hint is not interactive');hint:Click();assert(not pane.view.sectionsCollapsed[key])
    end
    pane.switchLabel:Click();assert(pane.switchCollapsedHint:IsShown());pane.switchCollapsedHint:Click();assert(not pane.view.switchCollapsed)
    assert(pane.switch.tooltip and card(pane,'optional').condition.tooltip)
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
finish()
