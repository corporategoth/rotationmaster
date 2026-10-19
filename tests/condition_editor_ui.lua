local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function fixture()
    local f=F.new();local a=f.addon
    local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    local ace=f.libraries['AceGUI-3.0'];local original=ace.Create;local widgets={}
    ace.Create=function(self,kind)
        assert(kind~='Window' and kind~='Frame' and kind~='DisablableInlineGroup','old recursive editor was used')
        local w=original(self,kind);w.frame=w.frame or create('Frame');widgets[#widgets+1]=w
        function w:ReleaseChildren() self.children={} end
        function w:PauseLayout() end
        function w:ResumeLayout() end
        function w:DoLayout() end
        function w:DisableButton() end
        function w:SetList(list,order) self.list,self.order=list,order end
        return w
    end
    dofile('tests/fixtures/spell_editbox.lua')(f,create)
    ace.Release=function(_,w) if w.frame then w.frame:Hide() end;w.released=true end
    for _,file in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/condition_draft.lua','Data/validation.lua','Data/diff.lua','Core/conditions.lua','Core/condition_catalog.lua','Core/condition_editor.lua','Core/condition_canvas.lua','UI/window.lua','UI/help.lua','UI/condition_picker.lua','UI/condition_cards.lua','UI/condition_canvas.lua','UI/condition_editor.lua','UI/condition_entrypoints.lua','Options/conditional.lua'}) do f.load(file) end
    local h=io.open('UI/condition_text.lua');if h then h:close();f.load('UI/condition_text.lua') end
    a:RegisterCondition('NUMBER',{description='Number check',fields={number='number'},requiredFields={'number'},
        valid=function(_,value) return type(value.number)=='number' end,
        evaluate=function() error('editor must not evaluate combat') end,
        print=function() error('compact tree must not execute a printer') end,
        widget=function(parent,_,value)
            local slider=ace:Create('Slider');slider:SetLabel('Number');slider:SetValue(value.number)
            slider:SetCallback('OnValueChanged',function(_,_,amount)
                value.number=amount
                local top=parent:GetUserData('top')
                top:SetStatusText(top:GetUserData('funcs'):print(top:GetUserData('root'),0))
            end)
            parent:AddChild(slider)
        end,help=function(parent) local label=ace:Create('Label');label:SetText('Number help');parent:AddChild(label) end})
    a.listConditions=function() return {'AND','OR','NOT','DELETE','NUMBER'} end
    function a:GetImportValidationOptions() return {conditions=self.conditionDefinitions} end
    a.UpdateAutoSwitch=function() end;a.SwitchRotation=function() end;a.configPaneGeneration=1
    return f,widgets
end
test('native pending numeric fields apply without Enter and invalid text cannot be applied',function()
    local f=fixture();local a=f.addon
    a:RegisterCondition('NATIVE_NUMBER',{description='Native number',fields={number='number'},valid=function(_,v) return type(v.number)=='number' end,
        print=function() return 'Native number' end,widget=function(parent,_,value)
            local w=a:CreateConditionSlider();w:SetValue(value.number);w:SetSliderValues(0,1,.01);w:SetIsPercent(true)
            w:SetCallback('OnValueChanged',function(_,_,amount) value.number=amount;parent:GetUserData('top'):SetStatusText() end);parent:AddChild(w)
        end})
    local root={type='NATIVE_NUMBER',number=.5};local shell=a:EditCondition(1,0,root);shell.canvas.cards[1].header:Click()
    local w=shell.canvas.cards[1].pane.children[1];assert(w.type=='RM-ConditionSlider')
    w.editbox:SetText('25');w.editbox.scripts.OnTextChanged(w.editbox,true);assert(shell.apply:IsEnabled(),'typing did not enable Apply')
    shell.apply:Click();assert(root.number==.25 and not shell.active,'Apply lost unfinished numeric input')
    shell=a:EditCondition(1,0,root);shell.canvas.cards[1].header:Click();w=shell.canvas.cards[1].pane.children[1]
    w.editbox:SetText('bad');w.editbox.scripts.OnTextChanged(w.editbox,true);shell.apply:Click()
    assert(shell.active and root.number==.25,'invalid raw input silently applied the old value')
    w.editbox.scripts.OnEscapePressed(w.editbox);shell.cancel:Click()
end)
test('opening a sibling field pane does not discard pending native numeric input',function()
    local f=fixture();local a=f.addon
    a:RegisterCondition('TEXT',{description='Text field',fields={text='string'},valid=function() return true end,print=function() return 'Text' end,
        widget=function(parent,_,value) local w=a:CreateConditionEditBox();w:SetText(value.text);w:SetCallback('OnEnterPressed',function(_,_,text) value.text=text;parent:GetUserData('top'):SetStatusText() end);parent:AddChild(w) end})
    local root={type='AND',value={{type='TEXT',text='First'},{type='TEXT',text='Second'}}}
    local shell=a:EditCondition(1,0,root);shell.canvas.cards[2].header:Click()
    local w=shell.canvas.cards[2].pane.children[1];w.editbox:SetText('Pending edit');w.editbox.scripts.OnTextChanged(w.editbox,true)
    shell.canvas.cards[3].header:Click();shell.apply:Click()
    assert(root.value[1].text=='Pending edit','a sibling render lost pending input')
end)
test('Undo consumes the first pending native edit and Redo restores its confirmed value',function()
    local f=fixture();local a=f.addon
    a:RegisterCondition('TEXT',{description='Text field',fields={text='string'},valid=function() return true end,print=function() return 'Text' end,
        widget=function(parent,_,value) local w=a:CreateConditionEditBox();w:SetText(value.text);w:SetCallback('OnEnterPressed',function(_,_,text) value.text=text;parent:GetUserData('top'):SetStatusText() end);parent:AddChild(w) end})
    local root={type='TEXT',text='Before'};local shell=a:EditCondition(1,0,root);shell.canvas.cards[1].header:Click()
    local w=shell.canvas.cards[1].pane.children[1];w.editbox:SetText('After');w.editbox.scripts.OnTextChanged(w.editbox,true)
    assert(shell.undo:IsEnabled(),'Undo ignored the first pending edit');shell.undo:Click();assert(shell.active.working.text=='Before' and root.text=='Before')
    shell.redo:Click();assert(shell.active.working.text=='After' and root.text=='Before');shell.apply:Click();assert(root.text=='After')
end)
test('compact native tree edits one selected leaf in a detached draft and applies explicitly',function()
    local f,widgets=fixture();local a=f.addon;local closed=0
    local root={type='AND',value={{type='NUMBER',number=1},{type='NUMBER',number=2}}}
    local shell=a:EditCondition(1,0,root,function() closed=closed+1 end)
    assert(shell.frame.visible and #shell.rows==3 and shell.canvas.cards[1].label.text:find('AND',1,true))
    shell.canvas.cards[2].header:Click()
    local slider;for _,w in ipairs(widgets) do if w.kind=='Slider' and not w.released then slider=w end end
    assert(slider and slider.value==1)
    slider.callbacks.OnValueChanged(slider,nil,9)
    assert(root.value[1].number==1,'field controls changed the running rotation before Apply')
    shell.apply:Click();assert(root.value[1].number==9 and closed==1 and not shell.frame.visible)
    local reused=a:EditCondition(1,0,root,function() closed=closed+1 end);assert(reused==shell)
    shell:Command('Remove',{})
    shell.cancel:Click();assert(root.value[1].number==9 and closed==2)
end)
test('group commands stay compact and callbacks never update a released source pane',function()
    local f=fixture();local a=f.addon;local callback=0
    local root={type='NUMBER',number=1}
    local shell=a:EditCondition(1,0,root,function() callback=callback+1 end)
    shell:Command('Wrap',{},'NOT');assert(#shell.rows==2 and root.type=='NUMBER')
    shell:Command('Unwrap',{});assert(#shell.rows==1)
    a.configPaneGeneration=2
    shell.apply:Click();assert(callback==0,'callback touched a source pane released by navigation')
end)
test('concurrent saved edits block Apply and keep the draft open for inspection',function()
    local f=fixture();local a=f.addon;local root={type='NUMBER',number=1}
    local shell=a:EditCondition(1,0,root,function() end)
    shell:Command('Replace',{}, {type='NUMBER',number=2});root.number=5;shell.apply:Click()
    assert(shell.frame.visible and root.number==5 and shell.status.text:find('another editor',1,true))
    shell.cancel:Click()
end)
test('custom field configure errors are isolated and keep the draft cancellable',function()
    local f=fixture();local a=f.addon;local root={type='NUMBER',number=1}
    local original=a.widgetCondition
    function a:widgetCondition(parent,spec,value)
        original(self,parent,spec,value)
        local extra=f.widget('Label');extra.configure=function() error('configure rejected') end;parent:AddChild(extra)
    end
    local ok,shell=pcall(a.EditCondition,a,1,0,root,function() end)
    assert(ok,'configure callback escaped the editor boundary');shell.canvas.cards[1].header:Click()
    assert(shell.frame.visible and shell.status.text:find('/rm errors',1,true))
    shell.cancel:Click();assert(not shell.frame.visible and root.number==1)
end)
test('legacy child popups hide and restore the compact draft without committing it',function()
    local f=fixture();local a=f.addon;local root={type='NUMBER',number=1};local closed=0
    local shell=a:EditCondition(1,0,root,function() closed=closed+1 end)
    shell:SetCallback('OnClose',function() end);shell:Hide()
    assert(shell.active and not shell.frame.visible)
    shell:GetUserData('root').number=8
    a.LayoutConditionFrame(shell);shell:Show()
    assert(shell.active and shell.frame.visible and root.number==1)
    shell.apply:Click();assert(root.number==8 and closed==1)
end)
test('opening a second condition preserves the first unsaved draft',function()
    local f=fixture();local a=f.addon;local first={type='NUMBER',number=1};local second={type='NUMBER',number=2}
    local shell=a:EditCondition(1,0,first,function() end)
    shell:Command('SetDisabled',{},true)
    assert(a:EditCondition(2,0,second,function() error('wrong callback') end)==shell)
    assert(shell.active.session:Snapshot().disabled==true and first.disabled==nil and second.disabled==nil)
    shell.cancel:Click()
end)
test('actual known-spell field controls edit the draft and keep named spell identity',function()
    local f,widgets=fixture();local a=f.addon
    a.Platform={GetSpellInfo=function(_,id)
        id=tonumber(id);return {spellID=id,name=id==403 and 'Lightning Bolt' or 'Earth Shock',subtext='Rank 1'}
    end,GetSpellLink=function(_,id) return '|Hspell:'..tostring(id)..'|h[spell]|h' end}
    f.load('Conditions/known_spell.lua')
    local root={type='SPELL_KNOWN',spell=403};local shell=a:EditCondition(1,0,root,function() end)
    shell.canvas.cards[1].header:Click()
    local picker
    for _,w in ipairs(shell.canvas.cards[1].pane.children) do if w.type=='RM-ConditionEditBox' and w.label=='Spell' then picker=w end end
    assert(picker and picker.text:find('Lightning Bolt',1,true))
    picker:Fire('OnEnterPressed','8042')
    assert(root.spell==403 and shell.canvas.cards[1].label.text:find('Earth Shock',1,true))
    shell.apply:Click();assert(root.spell==8042)
end)
test('empty conditions are presented as always matching rather than an unexplained placeholder',function()
    local f=fixture();local a=f.addon
    local shell=a:EditCondition(1,0,{},function() end)
    assert(shell.canvas.cards[1].label.text=='Always (no condition)')
    shell.cancel:Click()
end)
test('cancel does not invoke the callback of a removed source within the same configuration section',function()
    local f=fixture();local a=f.addon;local root={type='NUMBER',number=1};local exists=true;local calls=0
    local shell=a:EditCondition(1,0,root,function() calls=calls+1 end,function() return exists end)
    shell:Command('SetDisabled',{},true);exists=false;shell.apply:Click()
    assert(shell.frame.visible and shell.status.text:find('removed or replaced',1,true))
    shell.cancel:Click();assert(calls==0 and root.number==1)
end)
test('Undo and Redo restore deleted conditions and inline field edits until Apply',function()
    local f,widgets=fixture();local a=f.addon;local root={type='NUMBER',number=1}
    local shell=a:EditCondition(1,0,root,function() end)
    shell.canvas.cards[1].header:Click()
    local slider;for _,w in ipairs(widgets) do if w.kind=='Slider' then slider=w end end
    slider.callbacks.OnValueChanged(slider,nil,9)
    shell.undo:Click();assert(shell.active.working.number==1 and root.number==1)
    shell.redo:Click();assert(shell.active.working.number==9 and root.number==1)
    shell:Command('Remove',{});assert(next(shell.active.working)==nil)
    shell.undo:Click();assert(shell.active.working.number==9)
    shell.apply:Click();assert(root.number==9)
end)
test('condition cards edit several leaves inline and group selected siblings',function()
    local f=fixture();local a=f.addon;local root={type='AND',value={{type='NUMBER',number=1},{type='NUMBER',number=2}}}
    local shell=a:EditCondition(1,0,root,function() end)
    assert(shell.right==nil,'permanent inspector still consumes the right side')
    local canvas=shell.canvas
    canvas.cards[2].header:Click();canvas.cards[3].header:Click()
    assert(canvas.cards[2].pane and canvas.cards[3].pane and canvas.cards[2].pane~=canvas.cards[3].pane)
    canvas:Select({'value',1},false,false);canvas:Select({'value',2},true,false)
    shell:SelectedCommand('GroupSelection','OR')
    assert(shell.active.working.value[1].type=='OR' and #shell.active.working.value[1].value==2 and #root.value==2)
    shell.undo:Click();assert(#shell.active.working.value==2)
    canvas.cards[1].name:SetText('Opening');canvas.cards[1].name.scripts.OnEnterPressed(canvas.cards[1].name)
    assert(shell.active.working.name=='Opening')
    canvas.cards[1].header:Click();assert(canvas.cards[1].model.expanded)
    canvas.cards[1].fold:Click();assert(#canvas.scene.cards==1)
    shell.cancel:Click();assert(root.name==nil)
end)
test('native drag moves cards atomically and stale drag callbacks cannot edit reused cards',function()
    local f=fixture();local root={type='AND',value={{type='NUMBER',number=1},{type='NUMBER',number=2}}}
    local shell=f.addon:EditCondition(1,0,root,function() end);local canvas=shell.canvas
    local oldStart=canvas.cards[2].header.scripts.OnDragStart
    oldStart();assert(canvas.drag)
    local target
    for _,zone in ipairs(canvas.zones) do if zone.target.kind=='after' and zone.target.destination.index==3 then target=zone end end
    f.env.MouseIsOver=function(frame) return frame==target or frame==canvas.frame end
    canvas:EndDrag();assert(shell.active.working.value[1].number==2 and root.value[1].number==1)
    oldStart();assert(not canvas.drag,'old pooled header started a new drag')
    canvas.cards[2].header.scripts.OnDragStart();assert(canvas.drag)
    shell.cancel:Click();canvas:EndDrag();assert(not canvas.drag and root.value[1].number==1)
end)
test('incomplete fields are marked without running validators and the type combobox filters immediately by category',function()
    local f,widgets=fixture();local a=f.addon
    a.db.profile.condition_groups={{id='numbers',name='Numbers',conditions={'NUMBER'}},{id='combat',name='Combat',conditions={'COMBAT'}}}
    a:RegisterCondition('COMBAT',{description='In Combat',fields={unit='string'},requiredFields={'unit'},
        valid=function() error('do not execute validators while drawing') end,
        widget=function() error('no widget should appear until chosen') end})
    a.listConditions=function() return {'NUMBER','COMBAT'} end
    local root={type='AND',value={{type='COMBAT'},{}}};local shell=a:EditCondition(1,0,root,function() end)
    assert(shell.canvas.cards[2].model.invalid and shell.canvas.cards[2].summary.text:find('unit',1,true))
    shell.canvas.cards[3].header:Click();shell.canvas.cards[3].typeButton:Click()
    local picker=shell.canvas.cards[3].picker
    assert(picker and #picker.categories==3)
    for _,w in ipairs(widgets) do assert(w.kind~='Slider','an empty condition displayed type-specific fields') end
    picker.frame.scripts.OnMouseDown();assert(picker.popup.visible and #picker.matches==2)
    picker.categories[2]:Click();assert(#picker.matches==1 and picker.matches[1]=='NUMBER')
    picker.categories[1]:Click();picker.frame:SetText('combat');picker.frame.scripts.OnTextChanged(picker.frame,true)
    assert(picker.popup.visible and #picker.matches==1 and picker.matches[1]=='COMBAT')
    shell.cancel:Click();assert(root.value[2].type==nil)
end)
test('stale type selection cannot replace a node after Undo and modified range selection remains an antichain',function()
    local f=fixture();local root={type='AND',value={{type='NUMBER',number=1},{type='NUMBER',number=2},{type='NUMBER',number=3}}}
    local shell=f.addon:EditCondition(1,0,root,function() end);local canvas=shell.canvas
    canvas.cards[2].header:Click();canvas.cards[2].typeButton:Click();local picker=canvas.cards[2].picker
    local stale=picker.rows[1].scripts.OnClick
    shell:Command('Remove',{'value',1});shell.undo:Click();stale()
    assert(shell.active.working.value[1].number==1)
    shell:Command('Wrap',{'value',1},'OR')
    canvas:Select({'value',1,'value',1},false,false);canvas:Select({'value',3},true,false)
    canvas:Select({'value',1},true,true)
    local selected=canvas:Selection()
    assert(#selected==3 and #selected[1]==2,'range selection retained an overlapping parent')
    shell.cancel:Click()
end)
test('inline layout reflows following cards and resize invalidates old panes and drags',function()
    local f=fixture();local root={type='AND',value={{type='NUMBER',number=1},{type='NUMBER',number=2}}}
    local shell=f.addon:EditCondition(1,0,root,function() end);local canvas=shell.canvas
    canvas.cards[2].header:Click();canvas.cards[3].header:Click()
    local pane=canvas.cards[2].pane;local lease=pane.rmLease;local proxy=canvas.cards[2].proxy
    local originalY=canvas.cards[3].model.y
    pane.children[1].frame:SetHeight(350);pane:DoLayout()
    assert(canvas.cards[3].model.y>originalY and canvas.child:GetHeight()>=canvas.cards[3].model.y+canvas.cards[3].model.height)
    canvas.cards[2].header.scripts.OnDragStart();assert(canvas.drag)
    shell.frame:SetSize(840,520)
    assert(not canvas.drag and canvas.cards[2].pane.rmLease~=lease)
    proxy:SetStatusText();assert(shell.active.working.value[1].number==1 and root.value[1].number==1)
    for _,model in ipairs(canvas.scene.cards) do assert(model.x+model.width<=canvas.frame:GetWidth()) end
    shell.cancel:Click()
end)
test('group Help opens inline without creating a recursive group editor',function()
    local f=fixture();local root={type='AND',value={{type='NUMBER',number=1}}}
    local shell=f.addon:EditCondition(1,0,root,function() end)
    shell.canvas.cards[1].controls.help:Click();assert(not shell.canvas.cards[1].model.expanded and f.addon.helpWindow.frame:IsShown())
    assert(not shell.canvas.cards[1].picker and not shell.canvas.cards[1].pane)
    shell.cancel:Click()
end)
test('released field callbacks cannot change the draft through captured mutable values',function()
    local f,widgets=fixture();local root={type='NUMBER',number=1}
    local shell=f.addon:EditCondition(1,0,root,function() end)
    shell.canvas.cards[1].header:Click()
    local slider;for _,widget in ipairs(widgets) do if widget.kind=='Slider' then slider=widget end end
    local stale=slider.callbacks.OnValueChanged
    shell.canvas.cards[1].expand:Click();stale(slider,nil,999)
    assert(shell.active.working.number==1)
    shell.apply:Click();assert(root.number==1)
end)
test('rebuilding cards hides the old native type input and its popup',function()
    local f=fixture();local shell=f.addon:EditCondition(1,0,{type='NUMBER',number=1},function() end)
    shell.canvas.cards[1].header:Click()
    shell.canvas.cards[1].typeButton:Click();local picker=shell.canvas.cards[1].picker;assert(picker.popup:IsShown())
    shell.canvas.cards[1].expand:Click();assert(not picker.frame:IsShown() and not picker.popup:IsShown())
    assert(not picker.host:IsShown());shell.canvas.cards[1].typeButton:Click();assert(shell.canvas.cards[1].picker==picker and picker.frame:IsShown())
    shell.cancel:Click()
end)
test('legacy popup returns through its actual card proxy after the refresh replaces that card',function()
    local f=fixture();local root={type='NUMBER',number=1}
    local shell=f.addon:EditCondition(1,0,root,function() end);shell.canvas.cards[1].header:Click();local top=shell.canvas.cards[1].proxy
    top:SetCallback('OnClose',function() end);top:Hide();assert(not shell.frame.visible and shell.active)
    top:GetUserData('root').number=8
    f.addon.LayoutConditionFrame(top);top:Show()
    assert(shell.frame.visible and shell.active.working.number==8 and root.number==1)
    shell.apply:Click();assert(root.number==8)
end)
test('child editors resume their original session after fields retire without reviving a different session',function()
    local f=fixture();local a=f.addon;local root={type='NUMBER',number=1}
    local shell=a:EditCondition(1,0,root,function() end);shell.canvas.cards[1].header:Click();local top=shell.canvas.cards[1].proxy
    assert(top.rmResumeFromChild,'child resume must be tied to session rather than field lease')
    top:SetCallback('OnClose',function() end);top:Hide();top:GetUserData('root').number=8;top:SetStatusText()
    shell:Render();assert(top.rmResumeFromChild() and shell.frame:IsShown() and shell.active.working.number==8 and root.number==1)
    shell.cancel:Click();assert(not top.rmResumeFromChild() and not shell.frame:IsShown())
    local other={type='NUMBER',number=2};a:EditCondition(1,0,other,function() end);assert(not top.rmResumeFromChild() and shell.active.working.number==2)
    shell.cancel:Click()
end)
test('native item-list Apply returns to the condition draft and preserves its separate Apply boundary',function()
    local f=fixture();local a=f.addon
    for _,path in ipairs({'UI/settings_ordered.lua','UI/settings_history.lua','UI/settings_unsaved.lua','UI/settings_form.lua','UI/item_list_popup.lua','Core/itemset_services.lua','Options/itemset.lua','Conditions/common.lua'}) do f.load(path) end
    a.db.profile.itemsets={};a.db.global.itemsets={};f.env.GetItemInfo=function(id) id=tonumber(id);return 'Item '..id,'item:'..id,nil,nil,nil,nil,nil,nil,nil,id end
    a.FindFirstItemOfItems=function() end;a.FindFirstItemInItems=function() end;a.UpdateItem_ID_Image=function() end
    a:RegisterCondition('ITEMLIST',{description='Item list',fields={item={'string',{'number'}}},valid=function(_,value) return type(value.item)=='table' end,
        widget=function(parent,_,value) local top=parent:GetUserData('top');parent:AddChild(a:Widget_ItemWidget(top,'Item_EditBox',value,function(id) return id>0 end,function() top:SetStatusText() end)) end})
    local popup;local open=a.OpenItemListPopup;a.OpenItemListPopup=function(self,...) popup=open(self,...);return popup end
    local root={type='ITEMLIST',item={1}};local shell=a:EditCondition(1,0,root,function() end);shell.canvas.cards[1].header:Click()
    shell.canvas.cards[1].pane.children[1].children[3]:Fire('OnClick');assert(popup and popup.rmActive and not shell.frame:IsShown())
    local field=popup.form.fields.item1;field:SetText('2');field.scripts.OnTextChanged(field,true);field.scripts.OnEnterPressed(field)
    assert(root.item[1]==1 and shell.active.working.item[1]==1)
    popup.form.fields.apply:Click();assert(not popup.rmActive and shell.frame:IsShown() and shell.active.working.item[1]==2 and root.item[1]==1)
    shell.apply:Click();assert(root.item[1]==2,'condition Apply failed: '..tostring(shell.status:GetText()))
end)
test('inline parent fields preserve newer edits in independently expanded custom child fields',function()
    local f=fixture();local a=f.addon;local definition=a.conditionDefinitions.NUMBER
    a:RegisterCondition('CUSTOM',{description='Custom gate',fields={number='number',gate='condition'},requiredFields={'number'},
        widget=definition.widget,valid=function() return true end})
    local root={type='CUSTOM',number=1,gate={type='NUMBER',number=2}}
    local shell=a:EditCondition(1,0,root,function() end)
    shell.canvas.cards[1].header:Click()
    shell.canvas.cards[2].header:Click()
    local function slider(card)
        for _,child in ipairs(card.pane.children) do if child.kind=='Slider' then return child end end
    end
    local parent,child=slider(shell.canvas.cards[1]),slider(shell.canvas.cards[2])
    child.callbacks.OnValueChanged(child,nil,9);parent.callbacks.OnValueChanged(parent,nil,7)
    assert(shell.active.working.number==7 and shell.active.working.gate.number==9)
    shell.apply:Click();assert(root.number==7 and root.gate.number==9)
end)
test('intrinsic picker widths stay usable when only the viewport shrinks',function()
    local f=fixture();local root={type='NUMBER',number=1}
    for _=1,12 do root={type='AND',value={root}} end
    local shell=f.addon:EditCondition(1,0,root,function() end)
    shell.canvas.cards[13].header:Click();shell.canvas.cards[13].typeButton:Click();local picker=shell.canvas.cards[13].picker
    picker.frame.scripts.OnMouseDown();local old=picker.rows[1]:GetWidth()
    shell.frame:SetSize(840,520);shell.canvas.cards[13].typeButton:Click();picker=shell.canvas.cards[13].picker
    assert(picker.rows[1]:GetWidth()==old and picker.rows[1]:GetWidth()<=picker.popup:GetWidth()-190)
    assert(shell.canvas.scene.width>=shell.canvas.cards[13].model.x+shell.canvas.cards[13].model.width)
    shell.cancel:Click()
end)
test('custom field punctuation cannot alias a different selected condition path',function()
    local f=fixture();local a=f.addon
    a:RegisterCondition('CUSTOM',{description='Custom paths',fields={a='condition[]',['a/number:1']='condition'},valid=function() return true end})
    local root={type='CUSTOM',a={{type='NUMBER',number=1}},['a/number:1']={type='NUMBER',number=2}}
    local shell=a:EditCondition(1,0,root,function() end)
    shell.canvas:Select({'a',1},false,false)
    assert(#shell.canvas:Selection()==1)
    shell:SelectedCommand('RemoveSelection')
    assert(#shell.active.working.a==0 and shell.active.working['a/number:1'].number==2)
    shell.cancel:Click()
end)
test('compact tree owns local controls clickable group names and view expansion controls',function()
    local f=fixture();local root={type='AND',value={{type='NUMBER',number=1},{type='NUMBER',number=2}}}
    local shell=f.addon:EditCondition(1,0,root,function() end);local canvas=shell.canvas
    assert(shell.frame:GetWidth()<1000 and canvas.cards[2].model.width==340)
    assert(not canvas.cards[1].name:IsShown() and canvas.cards[1].nameButton:GetText()=='Click to add group name')
    canvas.cards[1].nameButton:Click();assert(canvas.cards[1].name:IsShown())
    canvas.cards[1].name:SetText('Combat checks');canvas.cards[1].name.scripts.OnEnterPressed(canvas.cards[1].name)
    assert(canvas.cards[1].nameButton:GetText()=='Combat checks' and not canvas.cards[1].name:IsShown())
    canvas.cards[2].controls.negate:Click();assert(#canvas.scene.cards==3 and canvas.cards[2].model.negated)
    canvas.cards[2].controls.disable:Click();assert(canvas.cards[2].model.disabled)
    shell.collapseAll:Click();assert(#canvas.scene.cards==3 and canvas.cards[1].model.compact)
    shell.expandAll:Click();assert(#canvas.scene.cards==3 and not canvas.cards[2].model.compact and not canvas.cards[2].model.expanded)
    canvas.cards[2].controls.remove:Click();assert(#canvas.scene.cards==2)
    shell.undo:Click();assert(#canvas.scene.cards==3 and #root.value==2)
    shell.cancel:Click()
end)
test('palette drops insert once on native mouse release without OnDragStop and only one target is marked',function()
    local f=fixture();local root={type='AND',value={{type='NUMBER',number=1}}}
    local shell=f.addon:EditCondition(1,0,root,function() end);local canvas=shell.canvas;local down=true
    f.env.IsMouseButtonDown=function(button) assert(button=='LeftButton' or button=='RightButton');return button=='LeftButton' and down end
    shell.palette.condition.scripts.OnDragStart();assert(canvas.drag and canvas.drag.insert)
    local target
    for _,zone in ipairs(canvas.zones) do if zone.target.kind=='after' and zone.target.destination.index==2 then target=zone end end
    f.env.MouseIsOver=function(frame) return frame==target or frame==canvas.frame end
    canvas.frame.scripts.OnUpdate(canvas.frame)
    local marked=0;for _,zone in ipairs(canvas.zones) do if zone.marker:IsShown() then marked=marked+1 end end
    assert(marked==1)
    down=false;canvas.frame.scripts.OnUpdate(canvas.frame)
    assert(not canvas.drag and #shell.active.working.value==2 and next(shell.active.working.value[2])==nil and #root.value==1)
    shell.undo:Click();assert(#shell.active.working.value==1)
    shell.cancel:Click()
end)
test('negated fields edit the actual operand and disabling preserves its negation',function()
    local f,widgets=fixture();local root={type='NOT',value={type='NUMBER',number=1}}
    local shell=f.addon:EditCondition(1,0,root,function() end)
    shell.canvas.cards[1].header:Click()
    assert(#shell.canvas.scene.cards==1 and shell.canvas.cards[1].model.negated)
    local slider;for _,w in ipairs(widgets) do if w.kind=='Slider' then slider=w end end
    assert(slider);slider.callbacks.OnValueChanged(slider,nil,8)
    shell.canvas.cards[1].controls.disable:Click();shell.apply:Click()
    assert(root.type=='NOT' and root.value.number==8 and root.disabled==true)
end)
test('card duplication is undoable and never aliases source values',function()
    local f,widgets=fixture();local root={type='AND',value={{type='NUMBER',number=1}}}
    local shell=f.addon:EditCondition(1,0,root,function() end)
    shell.canvas.cards[2].controls.duplicate:Click();assert(#shell.active.working.value==2 and #root.value==1)
    shell.canvas.cards[3].header:Click()
    local pane=shell.canvas.cards[3].pane;local slider
    for _,widget in ipairs(pane.children) do if widget.kind=='Slider' then slider=widget end end
    slider.callbacks.OnValueChanged(slider,nil,7)
    assert(shell.active.working.value[1].number==1 and shell.active.working.value[2].number==7)
    shell.undo:Click();assert(shell.active.working.value[2].number==1)
    shell.undo:Click();assert(#shell.active.working.value==1)
    shell.cancel:Click()
end)
test('missing NOT operands remain incomplete until a type is explicitly chosen',function()
    local f=fixture();local root={type='NOT'};local shell=f.addon:EditCondition(1,0,root,function() end)
    assert(#shell.canvas.scene.cards==1 and shell.canvas.cards[1].model.negated and shell.canvas.cards[1].model.invalid)
    assert(shell.active.working.value==nil and not shell.active.session:HistoryState().canUndo)
    shell.canvas.cards[1].typeButton:Click();local picker=shell.canvas.cards[1].picker;picker.rows[1]:Click()
    assert(shell.active.working.type=='NOT' and shell.active.working.value.type=='NUMBER' and root.value==nil)
    shell.cancel:Click()
end)
test('two-axis scroll bounds include intrinsic deep nodes and collapse resets excess horizontal offset',function()
    local f=fixture();local root={type='NUMBER',number=1}
    for _=1,20 do root={type='AND',value={root}} end
    local shell=f.addon:EditCondition(1,0,root,function() end);shell.frame:SetSize(660,460)
    local canvas=shell.canvas;assert(canvas.horizontal:IsShown() and canvas.horizontal.maximum>0)
    canvas.horizontal:SetValue(canvas.horizontal.maximum)
    assert(canvas.frame.horizontalScroll>0)
    canvas.cards[1].fold:Click();assert(not canvas.horizontal:IsShown() and canvas.frame.horizontalScroll==0)
    shell.cancel:Click()
end)
test('dragging never marks a destination inside the selected source subtree',function()
    local f=fixture();local root={type='AND',value={{type='AND',value={{type='NUMBER',number=1}}},{type='NUMBER',number=2}}}
    local shell=f.addon:EditCondition(1,0,root,function() end);local canvas=shell.canvas
    canvas.cards[2].header.scripts.OnDragStart()
    local target
    for _,zone in ipairs(canvas.zones) do if #zone.target.destination.path==2 and zone.target.destination.path[1]=='value' and zone.target.destination.path[2]==1 then target=zone end end
    f.env.MouseIsOver=function(frame) return frame==target or frame==canvas.frame end
    canvas.frame.scripts.OnUpdate(canvas.frame)
    assert(not target.marker:IsShown())
    canvas:EndDrag();assert(not canvas.drag and #shell.active.working.value==2)
    shell.cancel:Click()
end)
test('negating a disabled card preserves actual engine behavior and enabling clears hidden disabled flags',function()
    local f=fixture();local a=f.addon;local root={type='NUMBER',number=1}
    local shell=a:EditCondition(1,0,root,function() end)
    shell.canvas.cards[1].controls.disable:Click();shell.canvas.cards[1].controls.negate:Click()
    assert(shell.active.working.type=='NOT' and shell.active.working.disabled==true and shell.active.working.value.disabled==nil)
    assert(a:evaluateConditionResult(shell.active.working).status=='match')
    shell.canvas.cards[1].controls.negate:Click();assert(shell.active.working.disabled==true)
    shell.cancel:Click()
    root={type='NOT',disabled=true,value={type='NUMBER',number=1,disabled=true}}
    shell=a:EditCondition(1,0,root,function() end);shell.canvas.cards[1].controls.disable:Click()
    assert(not shell.canvas.cards[1].model.disabled and shell.active.working.disabled==nil and shell.active.working.value.disabled==nil)
    shell.cancel:Click()
end)
test('group bounds select the group and modifier-clicking its name selects instead of renaming',function()
    local f=fixture();local root={type='AND',value={{type='OR',value={{type='NUMBER',number=1}}},{type='NUMBER',number=2}}}
    local shell=f.addon:EditCondition(1,0,root,function() end);local canvas=shell.canvas
    canvas.cards[1].frame.scripts.OnMouseDown(canvas.cards[1].frame,'LeftButton')
    assert(#canvas:Selection()==1 and #canvas:Selection()[1]==0)
    f.env.IsControlKeyDown=function() return true end
    canvas.cards[2].nameButton:Click()
    assert(not canvas.cards[2].name:IsShown() and #canvas:Selection()==1 and canvas:Selection()[1][2]==1)
    shell.cancel:Click()
end)
test('choosing the current condition or dismissing the picker keeps every existing field and history',function()
    local f=fixture();local root={type='NUMBER',number=7};local shell=f.addon:EditCondition(1,0,root,function() end)
    shell.canvas.cards[1].typeButton:Click();local picker=shell.canvas.cards[1].picker
    picker.rows[1]:Click()
    assert(shell.active.working.type=='NUMBER' and shell.active.working.number==7,'selecting current type reset its fields')
    assert(not shell.active.session:HistoryState().canUndo,'same selection created a destructive history entry')
    picker=shell.canvas.cards[1].picker;picker.frame.scripts.OnMouseDown();picker.frame:SetText('another search')
    picker.frame.scripts.OnEscapePressed()
    assert(shell.active.working.number==7 and root.number==7 and not picker.popup:IsShown())
end)
test('condition category selection visibly highlights only the active filter',function()
    local f=fixture();f.addon.db.profile.condition_groups={{name='Numbers',conditions={'NUMBER'}}}
    local shell=f.addon:EditCondition(1,0,{type='NUMBER',number=1},function() end);shell.canvas.cards[1].typeButton:Click();local picker=shell.canvas.cards[1].picker
    picker.frame.scripts.OnMouseDown();assert(picker.categories[1].selected and not picker.categories[2].selected)
    picker.categories[2]:Click();assert(picker.categories[2].selected and not picker.categories[1].selected and #picker.matches==1)
    assert(picker.categories[2].art.color[2]>picker.categories[1].art.color[2],'active category has no visible selection')
end)
test('local card controls use texture icons and deliberate edge positions while history is visibly disabled',function()
    local f=fixture();local shell=f.addon:EditCondition(1,0,{type='AND',value={{type='NUMBER',number=1}}},function() end)
    local card=shell.canvas.cards[1]
    assert(card.controls.up.icon and card.controls.down.icon and card.controls.remove.icon and card.controls.duplicate.icon,'missing native texture control icons')
    assert(card.controls.up:GetWidth()==18 and card.controls.remove:GetWidth()==20 and card.controls.duplicate:GetWidth()==20)
    assert(card.controls.help.point[1]=='TOPRIGHT' and card.controls.remove.point[1]=='TOPRIGHT')
    assert(card.controls.down.point[2]==card.controls.up and card.controls.down.point[3]=='BOTTOMLEFT' and card.controls.down.point[5]==0)
    assert(not shell.undo.enabled and not shell.redo.enabled and shell.undo:GetAlpha()<1 and shell.redo:GetAlpha()<1)
    card.controls.duplicate:Click();assert(shell.undo.enabled and shell.undo:GetAlpha()==1)
end)
test('clicking a collapsed condition title opens its chooser without expanding or erasing its fields',function()
    local f=fixture();local shell=f.addon:EditCondition(1,0,{type='AND',value={{type='NUMBER',number=7}}},function() end)
    local card=shell.canvas.cards[2];assert(not card.model.expanded)
    card.typeButton:Click();local picker=card.picker
    assert(picker and picker.host:IsShown() and picker.popup:IsShown() and not card.model.expanded)
    picker.rows[1]:Click();assert(shell.active.working.value[1].number==7 and not picker.host:IsShown())
    card.typeButton:Click();picker.frame.scripts.OnEscapePressed();assert(shell.active.working.value[1].number==7)
end)
test('collapsed descriptions and persistent full-expression footer update independently of transient status',function()
    local f=fixture();local shell=f.addon:EditCondition(1,0,{type='AND',value={{type='NUMBER',number=7},{type='NUMBER',number=9}}},function() end)
    assert(not shell.canvas.cards[2].summary.text:find('Expand to edit',1,true))
    local text=shell.description:GetText();assert(text:find('7',1,true) and text:find('9',1,true))
    shell:Message('invalid-condition-fields');assert(shell.description:GetText()==text)
    shell:Command('Replace',{'value',1},{type='NUMBER',number=13})
    assert(shell.description:GetText():find('13',1,true) and shell.description:GetText():find('9',1,true))
    assert(shell.palette.group and not shell.palette.any and shell.palette.condition.point[1]=='TOPRIGHT')
end)
test('drag hover and direct drops suppress adjacent destinations that would not move the card',function()
    local f=fixture();local shell=f.addon:EditCondition(1,0,{type='AND',value={{type='NUMBER',number=1},{type='NUMBER',number=2}}},function() end)
    local canvas=shell.canvas;canvas.cards[2].header.scripts.OnDragStart()
    local noop,valid
    for _,zone in ipairs(canvas.zones) do
        if #zone.target.destination.path==0 and zone.target.destination.index==2 then noop=zone end
        if #zone.target.destination.path==0 and zone.target.destination.index==3 then valid=zone end
    end
    assert(noop and valid)
    f.env.MouseIsOver=function(frame) return frame==noop or frame==canvas.frame end
    assert(not canvas:HoverTarget() and not noop.marker:IsShown(),'unchanged move was offered')
    f.env.MouseIsOver=function(frame) return frame==valid or frame==canvas.frame end
    assert(canvas:HoverTarget()==valid and valid.marker:IsShown())
    canvas:Drop(noop.target);assert(shell.active.working.value[1].number==1 and not shell.active.session:HistoryState().canUndo)
end)
test('outside picker click dismisses without changing data while category clicks remain inside',function()
    local f=fixture();local shell=f.addon:EditCondition(1,0,{type='NUMBER',number=4},function() end)
    shell.canvas.cards[1].typeButton:Click();local picker=shell.canvas.cards[1].picker
    local down=false;f.env.IsMouseButtonDown=function() return down end
    f.env.MouseIsOver=function(frame) return frame==picker.host end
    picker.host.scripts.OnUpdate();down=true;picker.host.scripts.OnUpdate();assert(picker.host:IsShown())
    down=false;picker.host.scripts.OnUpdate();f.env.MouseIsOver=function() return false end;down=true;picker.host.scripts.OnUpdate()
    assert(not picker.host:IsShown() and shell.active.working.number==4 and not shell.active.session:HistoryState().canUndo)
end)
test('named negated leaves keep the collapsed field summary as well as the editable wrapper label',function()
    local f=fixture();local root={type='AND',value={{type='NOT',name='Emergency',value={type='NUMBER',number=37}}}}
    local shell=f.addon:EditCondition(1,0,root,function() end);local card=shell.canvas.cards[2]
    assert(card.model.negated and card.nameButton:GetText()=='Emergency' and card.typeButton:IsShown())
    assert(card.summary:GetText():find('37',1,true),'named NOT replaced field details with another copy of its title')
end)
test('readonly condition view keeps common cards expandable while mutating controls stay inert',function()
    local f,widgets=fixture();local a=f.addon;local root={type='AND',value={{type='NUMBER',number=7}}}
    local shell=a:ShowConditionEditor(1,0,root,nil,nil,{readOnly=true})
    assert(shell.active.readOnly and not shell.apply:IsEnabled())
    shell.canvas.cards[2].header:Click();assert(shell.canvas.cards[2].model.expanded)
    shell:Command('Remove',{});shell.apply:Click()
    assert(root.type=='AND' and root.value[1].number==7 and not shell.active.session:HistoryState().canUndo)
    for _,w in ipairs(widgets) do if w.kind=='Slider' and not w.released then
        assert(w.disabled,'readonly fields still permit editing');w.callbacks.OnValueChanged(w,nil,99)
    end end
    assert(shell.active.working.value[1].number==7)
    shell.cancel:Click();local editable=a:ShowConditionEditor(1,0,root,nil)
    assert(not editable.apply:IsEnabled() and editable.canvas.cards[1].controls.negate:IsEnabled(),'readonly disabled state leaked into editable reuse')
end)
test('workspace-owned nested editor commits after its original pane generation changes',function()
    local f=fixture();local a=f.addon;local root={type='NUMBER',number=7};local called=0
    local shell=a:ShowConditionEditor(1,0,root,function(applied) assert(applied);called=called+1 end,function() return true end,{persistentOwner=true})
    assert(shell:Command('Replace',{}, {type='NUMBER',number=8}))
    a.configPaneGeneration=a.configPaneGeneration+1;shell.apply:Click()
    assert(root.number==8 and called==1,'resumable workspace lost its nested condition commit')
end)
test('dense cards replace collapsed text with controls and help returns to the prior collapsed view',function()
    local f=fixture();local a=f.addon;local shell=a:ShowConditionEditor(1,0,{type='NUMBER',number=7})
    assert(not shell.apply:IsEnabled() and shell.undo:GetText()=='Undo' and shell.redo:GetText()=='Redo')
    assert(shell.descriptionScroll==nil and shell.description:GetText():find('7',1,true) and shell.status:GetText()=='')
    local card=shell.canvas.cards[1]
    assert(card.model.width>=340 and card.controls.disable:GetWidth()<80 and card.controls.disable.pillDecoration)
    assert(card.controls.duplicate.point[1]=='TOPRIGHT' and shell.palette.condition.point[1]=='TOPRIGHT')
    if card.model.expanded then card.expand:Click();card=shell.canvas.cards[1] end
    if card.model.compact then card.expand:Click();card=shell.canvas.cards[1] end
    card.controls.help:Click();assert(not shell.canvas.cards[1].model.expanded and a.helpWindow.frame:IsShown())
    a.helpWindow.close:Click();assert(not shell.canvas.cards[1].model.expanded)
    card=shell.canvas.cards[1];card.header:Click();card=shell.canvas.cards[1]
    assert(not card.header:IsShown() and card.fields:IsShown(),'expanded fields were appended beneath the collapsed description')
    shell:Command('Replace',{}, {type='NUMBER',number=8});assert(shell.apply:IsEnabled())
    shell.undo:Click();assert(not shell.apply:IsEnabled(),'Apply remains active after returning to the saved condition')
end)
test('long full expressions preserve a usable tree and offer the entire copyable text without a footer scrollbar',function()
    local f=fixture();local root={type='AND',value={}}
    for i=1,60 do root.value[i]={type='NUMBER',number=i} end
    local shell=f.addon:ShowConditionEditor(1,0,root)
    assert(shell.copyExpression:IsShown() and shell.canvas.frame:GetHeight()>=40 and shell.descriptionScroll==nil)
    shell.copyExpression:Click();local dialog=f.addon.conditionTextWindow
    assert(dialog and dialog.edit:GetText()==shell.fullDescription and dialog.edit.focused and dialog.edit.selection[2]==-1)
    dialog.close:Click();assert(not dialog.frame:IsShown())
end)
test('condition chevrons collapse summaries and leave details without hiding group paths',function()
    local f=fixture();local shell=f.addon:EditCondition(1,0,{type='NUMBER',number=1},function() end)
    shell.canvas.cards[1].header:Click()
    local card=shell.canvas.cards[1];assert(card.model.expanded);card.expand:Click();card=shell.canvas.cards[1]
    assert(not card.model.compact and not card.model.expanded and card.controls.disable:IsShown())
    card.expand:Click();card=shell.canvas.cards[1];assert(card.model.compact and not card.controls.disable:IsShown() and not card.icon:IsShown())
    card.expand:Click();card=shell.canvas.cards[1];assert(not card.model.compact and not card.model.expanded)
    card.header:Click();assert(shell.canvas.cards[1].model.expanded and not shell.canvas.cards[1].header:IsShown())
end)
test('typed group names remain in the condition draft and Apply works without Enter',function()
    local f=fixture();local root={type='AND',value={{type='NUMBER',number=1}}};local shell=f.addon:EditCondition(1,0,root,function() end)
    local card=shell.canvas.cards[1];card.nameButton:Click();card.name:SetText('Opening buffs');card.name.scripts.OnTextChanged(card.name,true)
    assert(root.name==nil and shell.apply:IsEnabled());shell:Render();assert(shell.canvas.cards[1].model.name=='Opening buffs')
    shell.apply:Click();assert(root.name=='Opening buffs')
end)
test('group Help measures its text after compact native controls and clears that height on close',function()
    local f=fixture();local shell=f.addon:EditCondition(1,0,{type='AND',value={{type='NUMBER',number=1}}},function() end)
    shell.canvas.cards[1].header:Click();local before=shell.canvas.cards[1].model.ownHeight
    shell.canvas.cards[1].controls.help:Click();local card=shell.canvas.cards[1]
    assert(card.fields:GetHeight()>=card.helpText:GetStringHeight()+16)
    assert(shell.canvas.cards[2].model.y>=card.model.y+card.model.ownHeight)
    card.controls.help:Click();assert(shell.canvas.cards[1].model.ownHeight==before)
end)
test('condition summaries open fields while chevron toggles names and summary without hiding group paths',function()
    local f=fixture();local shell=f.addon:EditCondition(1,0,{type='AND',value={{type='NUMBER',number=1}}},function() end)
    shell.collapseAll:Click();assert(#shell.canvas.scene.cards==2 and shell.canvas.cards[1].model.compact)
    shell.canvas.cards[1].fold:Click();assert(#shell.canvas.scene.cards==1);shell.canvas.cards[1].fold:Click();assert(#shell.canvas.scene.cards==2)
    local c=shell.canvas.cards[2];c.expand:Click();c=shell.canvas.cards[2];assert(not c.model.expanded and not c.model.compact)
    c.header:Click();c=shell.canvas.cards[2];assert(c.model.expanded and not c.header:IsShown())
    c.expand:Click();assert(not shell.canvas.cards[2].model.expanded and not shell.canvas.cards[2].model.compact)
end)
test('long condition type labels grow their card instead of truncating and new controls dock right with icons',function()
    local f=fixture();local shell=f.addon:EditCondition(1,0,{type='NUMBER',number=1},function() end)
    f.addon.conditionDefinitions.NUMBER.description=string.rep('Long condition type ',3);shell:Render()
    local c=shell.canvas.cards[1];assert(c.label:GetWidth()>=c.label:GetStringWidth())
    assert(shell.palette.condition.icon and shell.palette.group.icon and shell.palette.group.point[1]=='TOPRIGHT')
end)
test('explicit summary navigation exits Help while Help toggle alone restores its prior view',function()
    local f=fixture();local shell=f.addon:EditCondition(1,0,{type='AND',value={{type='NUMBER',number=1}}},function() end)
    local c=shell.canvas.cards[1];c.header:Click();c=shell.canvas.cards[1];c.controls.help:Click();assert(shell.canvas.cards[1].model.expanded)
    shell.expandAll:Click();assert(not shell.canvas.cards[1].model.expanded and not shell.view.help[''])
    shell.canvas.cards[1].header:Click();shell.canvas.cards[1].controls.help:Click();shell.canvas.cards[1].expand:Click()
    assert(not shell.canvas.cards[1].model.compact and not shell.canvas.cards[1].model.expanded and not shell.view.help[''])
    shell.canvas.cards[1].controls.help:Click();shell.collapseAll:Click();assert(shell.canvas.cards[1].model.compact and not shell.view.help[''])
end)
test('invalid disabled conditions retain red validation borders and group names avoid fold controls',function()
    local f=fixture();local shell=f.addon:EditCondition(1,0,{type='AND',value={{type='NUMBER',disabled=true}}},function() end)
    local c=shell.canvas.cards[2];assert(c.model.invalid and c.borders[1].color[1]>.7)
    shell.collapseAll:Click();c=shell.canvas.cards[1]
    assert(c.fold.point[1]=='TOPLEFT' and c.nameButton.point[2]>=c.fold.point[2]+c.fold:GetWidth()+4)
end)
test('group names hide their label and align inline editing until focus leaves',function()
    local f=fixture();local shell=f.addon:EditCondition(1,0,{type='AND',name='Group',value={}},function() end)
    local c=shell.canvas.cards[1];c.nameButton:Click();assert(not c.nameButton:IsShown() and c.name:IsShown())
    assert(c.name.point[2]==c.nameButton and c.name:GetWidth()==c.nameButton:GetWidth())
    c.name:SetText('');c.name.scripts.OnTextChanged(c.name,true)
    c.name.scripts.OnEditFocusLost(c.name);assert(c.nameButton:IsShown() and not c.name:IsShown() and c.nameButton:GetText()=='Click to add group name')
end)
test('condition additions append to the complete expression and retain disabled summaries',function()
    local f=fixture();local shell=f.addon:EditCondition(1,0,{type='AND',value={{type='NUMBER',number=1,disabled=true},{type='NUMBER',number=2}}},function() end)
    assert(shell.canvas.cards[2].summary:GetText()~='Disabled')
    shell.canvas:Select({'value',1},false,false);shell.palette.condition:Click();assert(#shell.active.working.value==3 and next(shell.active.working.value[3])==nil)
    shell.palette.group:Click();assert(#shell.active.working.value==4 and shell.active.working.value[4].type=='AND')
    assert(shell.palette.condition:GetText()=='Add condition' and not shell.dragHint:IsShown())
    local c=shell.canvas.cards[1];assert(not c.controls.help.art:IsShown() and not c.expand.art:IsShown() and c.controls.operator.pillDecoration.border[1].color[1]>.7)
end)
test('disabling keeps the same readable summary while the card is grayed',function()
    local f=fixture();f.addon.printCondition=function(_,condition) return 'Number is '..condition.number end
    local shell=f.addon:EditCondition(1,0,{type='NUMBER',number=37},function() end);shell.canvas.cards[1].expand:Click()
    local before=shell.canvas.cards[1].summary:GetText();shell.canvas.cards[1].controls.disable:Click()
    assert(shell.canvas.cards[1].summary:GetText()==before)
end)
test('condition chrome mirrors the main window and compact unnamed summaries expand by title',function()
    local f=fixture();f.addon.printCondition=function(_,node) return 'Number is '..node.number end
    local shell=f.addon:EditCondition(1,0,{type='NUMBER',number=7},function() end)
    assert(shell.chrome and shell.chrome.header and shell.chrome.footer and shell.chrome.version)
    shell.collapseAll:Click();local c=shell.canvas.cards[1];assert(c.nameButton:GetText()=='Number is 7')
    c.nameButton:Click();assert(not shell.canvas.cards[1].model.compact)
end)
test('condition title and opaque header art belong to the same frame layer',function()
    local f=fixture();local shell=f.addon:EditCondition(1,0,{type='NUMBER',number=7},function() end)
    assert(shell.chrome.header.kind=='Texture' and shell.chrome.header:GetParent()==shell.title:GetParent(),'opaque child frame covers title regions')
end)
test('leaf and group condition editors both open with summaries before showing fields',function()
    local f=fixture();local a=f.addon
    for _,root in ipairs({{type='NUMBER',number=7},{type='AND',value={{type='NUMBER',number=7}}}}) do
        local shell=a:EditCondition(1,0,root,function() end)
        assert(not shell.canvas.cards[1].model.expanded and shell.canvas.cards[1].header:IsShown(),'root leaf opened differently from group')
        shell.cancel:Click()
    end
end)
test('condition dialog keeps the supplied step heading as visible plain text',function()
    local f=fixture();local shell=f.addon:ShowConditionEditor(1,0,{type='NUMBER',number=1},function() end,nil,{title='Keep Lightning Shield active',contextLabel='Cooldown',rotationName='Mine'})
    assert(shell.title:GetText()=='Rotation Master: Keep Lightning Shield active' and shell.title:GetHeight()>0 and shell.title:IsShown(),'step heading has no visible text region')
    assert(shell.chrome.version:GetText()=='Cooldown' and shell.chrome.author:GetText()=='Mine')
    shell.cancel:Click()
end)
test('move controls reflect actual sibling boundaries including negated groups',function()
    local f=fixture();local shell=f.addon:EditCondition(1,0,{type='AND',value={{type='NOT',value={type='OR',value={}}},{type='NUMBER',number=2}}},function() end)
    local cards=shell.canvas.cards
    assert(not cards[1].controls.up:IsEnabled() and not cards[1].controls.down:IsEnabled())
    assert(not cards[2].controls.up:IsEnabled() and cards[2].controls.down:IsEnabled())
    assert(cards[3].controls.up:IsEnabled() and not cards[3].controls.down:IsEnabled())
    cards[2].controls.down:Click();cards=shell.canvas.cards
    assert(cards[2].model.type=='NUMBER' and not cards[2].controls.up:IsEnabled() and cards[2].controls.down:IsEnabled())
    assert(cards[3].model.type=='OR' and cards[3].controls.up:IsEnabled() and not cards[3].controls.down:IsEnabled())
end)
test('compact unnamed groups show their operator while named groups keep their name',function()
    local f=fixture();local shell=f.addon:EditCondition(1,0,{type='AND',value={{type='OR',value={}},{type='AND',name='Opening',value={}}}},function() end)
    shell.collapseAll:Click();local cards=shell.canvas.cards
    assert(cards[1].nameButton:GetText()=='All of' and cards[2].nameButton:GetText()=='Any of' and cards[3].nameButton:GetText()=='Opening')
end)
test('expanded condition help appends below live fields instead of replacing them',function()
    local f,widgets=fixture();local shell=f.addon:EditCondition(1,0,{type='NUMBER',number=7},function() end)
    shell.canvas.cards[1].header:Click();shell.canvas.cards[1].controls.help:Click();local pane=shell.canvas.cards[1].pane
    assert(pane.children[1].kind=='Slider' and pane.children[2].text=='Number help','help replaced the editable field')
    pane.children[1].callbacks.OnValueChanged(pane.children[1],nil,8);shell.apply:Click()
end)
test('Ctrl drag selects only the source sibling suffix including each group subtree',function()
    local f=fixture();local a=f.addon;local root={type='AND',value={{type='OR',value={}},{type='NUMBER',number=2},{type='AND',value={{type='NUMBER',number=3}}}}}
    local shell=a:EditCondition(1,0,root,function() end);local c=shell.canvas
    f.env.IsControlKeyDown=function() return true end;c:StartDrag({'value',2},c.generation)
    assert(c.drag and #c.drag.paths==2 and c.drag.paths[1][2]==2 and c.drag.paths[2][2]==3)
    assert(c.ghost.label:GetText():find('Move this and following entries',1,true),'tail ghost is indistinguishable from explicit selection')
    f.env.IsControlKeyDown=function() return false end
    assert(c:Drop({destination={path={'value',1},field='value',index=1}}))
    local v=shell.active.session:Snapshot();assert(#v.value==1 and v.value[1].value[1].number==2 and v.value[1].value[2].value[1].number==3)
    shell.undo:Click();assert(#shell.active.session:Snapshot().value==3);shell.cancel:Click()
end)
test('condition unsaved rails track changed leaves and ancestors through Undo without changing saved data',function()
    local f=fixture();local root={type='AND',value={{type='NUMBER',number=1},{type='NUMBER',number=2}}}
    local shell=f.addon:EditCondition(1,0,root,function() end)
    assert(not shell.canvas.cards[1].frame.rmUnsaved)
    shell:Command('Replace',{'value',1},{type='NUMBER',number=9})
    assert(shell.canvas.cards[1].frame.rmUnsaved and shell.canvas.cards[2].frame.rmUnsaved and not shell.canvas.cards[3].frame.rmUnsaved)
    assert(root.value[1].number==1)
    shell.undo:Click();assert(not shell.canvas.cards[1].frame.rmUnsaved and not shell.canvas.cards[2].frame.rmUnsaved)
    shell.cancel:Click()
end)
test('condition View Changes shows saved versus unsaved expressions without committing',function()
    local f=fixture();local root={type='NUMBER',number=1};local shell=f.addon:EditCondition(1,0,root,function() end);assert(shell.viewChanges and not shell.viewChanges:IsEnabled())
    shell:Command('Replace',{}, {type='NUMBER',number=2});shell.viewChanges:Click();local d=shell.draftComparisonOwner.comparison
    assert(d.frame:IsShown() and #d.rows>0 and root.number==1);shell.cancel:Click();d.frame.scripts.OnUpdate();assert(not d.frame:IsShown())
end)
local function viewportCard(shell,path)
    for _,card in ipairs(shell.canvas.cards) do
        if card.token and card.model and #card.model.path==#path then
            local same=true;for i,part in ipairs(path) do if card.model.path[i]~=part then same=false end end
            if same then return card end
        end
    end
end
test('large condition scenes reach the last node with a bounded reusable card and marker pool',function()
    local f=fixture();local a=f.addon;local root={type='AND',value={}};for i=1,1000 do root.value[i]={type='NUMBER',number=i} end
    local shell=a:EditCondition(1,0,root,function() end);local c=shell.canvas
    assert(c.scene.complete and #c.scene.cards==1001,'large condition scene was truncated')
    if shell.copyExpression:IsShown() then assert(shell.copyExpression:GetWidth()>=shell.copyExpression:GetFontString():GetStringWidth()+12,'copy description caption is clipped') end
    c.frame.workbenchBar:SetValue(c.scene.cards[2].y)
    local first=assert(viewportCard(shell,{'value',1}));local stale=first.controls.remove.scripts.OnClick
    assert(not viewportCard(shell,{'value',1000}) and #c.cards<80,'offscreen condition controls were allocated')
    c.frame.workbenchBar:SetValue(c.frame.workbenchBar.scrollRange)
    assert(viewportCard(shell,{'value',1000}) and not viewportCard(shell,{'value',1}),'scroll did not materialize final condition')
    stale();assert(#shell.active.working.value==1000,'recycled callback changed its old condition')
    local peak=#c.cards;for pass=1,2 do for i=0,10 do c.frame.workbenchBar:SetValue(c.frame.workbenchBar.scrollRange*i/10) end end
    assert(#c.cards<80 and #c.cards<=peak+3 and #c.zones<100 and #c.lines<100,'viewport pools grew with total conditions')
    shell:Command('Replace',{'value',1000},{type='NUMBER',number=9000});shell.apply:Click();assert(root.value[1000].number==9000 and #root.value==1000)
end)
test('offscreen pending native fields remain leased and invalid fields still block Apply',function()
    local f=fixture();local a=f.addon
    a:RegisterCondition('NATIVE',{description='Native',fields={number='number'},valid=function(_,v) return type(v.number)=='number' end,print=function() return 'Native' end,
        widget=function(parent,_,value) local w=a:CreateConditionSlider();w:SetSliderValues(0,100,1);w:SetValue(value.number);w:SetCallback('OnValueChanged',function(_,_,v) value.number=v;parent:GetUserData('top'):SetStatusText() end);parent:AddChild(w) end})
    local root={type='AND',value={}};for i=1,350 do root.value[i]={type='NATIVE',number=1} end
    local shell=a:EditCondition(1,0,root,function() end);local c=shell.canvas;c.frame.workbenchBar:SetValue(c.scene.cards[2].y);local first=assert(viewportCard(shell,{'value',1}));first.header:Click();first=assert(viewportCard(shell,{'value',1}))
    local input=first.pane.children[1];input.editbox:SetText('invalid');input.editbox.scripts.OnTextChanged(input.editbox,true)
    c.frame.workbenchBar:SetValue(c.frame.workbenchBar.scrollRange)
    assert(first.token and first.pane and input:GetText()=='invalid' and input:IsPending(),'scroll released invalid pending field')
    shell.apply:Click();assert(shell.active and root.value[1].number==1)
    input.editbox:SetText('8');input.editbox.scripts.OnTextChanged(input.editbox,true);shell.apply:Click();assert(root.value[1].number==8 and not shell.active)
end)
test('large condition drag keeps complete final destinations and carries offscreen suffixes atomically',function()
    local f=fixture();local a=f.addon;local root={type='AND',value={}};for i=1,350 do root.value[i]={type='NUMBER',number=i} end
    local shell=a:EditCondition(1,0,root,function() end);local c=shell.canvas
    f.env.IsControlKeyDown=function() return true end;c:StartDrag({'value',349},c.generation);assert(c.drag and #c.drag.paths==2)
    c.frame.workbenchBar:SetValue(0);assert(c:Drop({destination={path={},field='value',index=1}}));assert(shell.active.working.value[1].number==349 and shell.active.working.value[2].number==350 and #root.value==350)
    shell.undo:Click();assert(shell.active.working.value[1].number==1)
    c:StartInsert({type='NUMBER',number=777});c.frame.workbenchBar:SetValue(c.frame.workbenchBar.scrollRange)
    local target;for _,zone in ipairs(c.zones) do if zone.target and zone.target.destination.index==351 and zone:IsShown() then target=zone.target end end
    assert(target and c:Drop(target),'last complete drop target was not reachable');assert(shell.active.working.value[351].number==777 and #root.value==350)
    shell.cancel:Click();assert(not c.drag and not c.ghost:IsShown())
end)
test('scrolled group drag hides its leased connector textures and restores them on cancel',function()
    local f=fixture();local a=f.addon;local root={type='AND',value={}};for i=1,350 do root.value[i]={type='NUMBER',number=i} end
    root.value[300]={type='AND',value={{type='NUMBER',number=1}}}
    local shell=a:EditCondition(1,0,root,function() end);local c=shell.canvas;local group=c.scene.cardsByKey[a.ConditionPathKey({'value',300})]
    c.frame.workbenchBar:SetValue(group.y);local groupCard=assert(viewportCard(shell,{'value',300}));assert(viewportCard(shell,{'value',300,'value',1}))
    local edge=c.scene.connectorsByTo[a.ConditionPathKey({'value',300,'value',1})][2];local source
    for _,line in ipairs(c.lines) do if line:IsShown() and line.point[4]==edge.x and line.point[5]==-edge.y then source=line end end
    assert(source,'expected visible child connector');c:StartDrag(group.path,c.generation)
    assert(c.drag and groupCard.frame:GetParent()==c.ghost and not source:IsShown(),'drag did not hide the leased original connector')
    c.frame.workbenchBar:SetValue(group.y+16)
    local function visibleOriginal() for _,line in ipairs(c.lines) do if line:IsShown() and line.point[4]==edge.x and line.point[5]==-edge.y then return true end end end
    assert(not visibleOriginal(),'scroll refresh redrew a carried connector in its original position')
    c:CancelDrag();assert(visibleOriginal() and groupCard.frame:GetParent()==c.child and not c.ghost:IsShown(),'cancel did not restore connector and card ownership');shell.cancel:Click()
end)
test('large condition range selection stays an antichain across offscreen siblings',function()
    local f=fixture();local root={type='AND',value={}};for i=1,600 do root.value[i]={type='NUMBER',number=i} end
    root.value[301]={type='AND',value={{type='NUMBER',number=1}}}
    local shell=f.addon:EditCondition(1,0,root,function() end);local c=shell.canvas
    c:Select({'value',301,'value',1},false,false);c.anchor={'value',1};c:Select({'value',600},true,true)
    local selected=c:Selection();assert(#selected==600 and #selected[301]==2,'range kept a hidden descendant or lost an offscreen sibling')
    assert(#c.cards<80 and #root.value==600)
end)
test('viewport reflow pins a focused offscreen name and retired Escape cannot affect its recycled control',function()
    local f=fixture();local a=f.addon
    local root={type='AND',value={}};for i=1,350 do root.value[i]={type='AND',value={},name='Entry '..i} end
    local shell=a:EditCondition(1,0,root,function() end);local c=shell.canvas;c.frame.workbenchBar:SetValue(c.scene.cards[2].y)
    local first=assert(viewportCard(shell,{'value',1}));first.nameButton:Click();first.name:SetText('Still typing');first.name.scripts.OnTextChanged(first.name,true)
    local escape=first.name.scripts.OnEscapePressed;c.frame.workbenchBar:SetValue(c.frame.workbenchBar.scrollRange)
    assert(first.token and first.name:HasFocus() and first.name:IsShown() and first.name:GetText()=='Still typing','scroll reflow hid a focused name')
    first.name:ClearFocus();c.frame.workbenchBar:SetValue(c.frame.workbenchBar.scrollRange/2)
    assert(first.token and first.model.path[2]~=1,'released name slot was not recycled')
    first.nameButton:Click();assert(first.name:HasFocus());escape();assert(first.name:HasFocus(),'retired Escape cleared the newly leased name input')
    assert(root.value[1].name=='Entry 1' and shell.active.working.value[1].name=='Still typing');shell.cancel:Click()
end)
test('offscreen child popup ownership pins its source fields until the original draft resumes',function()
    local f=fixture();local a=f.addon;local root={type='AND',value={}};for i=1,350 do root.value[i]={type='NUMBER',number=i} end
    local shell=a:EditCondition(1,0,root,function() end);local c=shell.canvas;c.frame.workbenchBar:SetValue(c.scene.cards[2].y)
    local first=assert(viewportCard(shell,{'value',1}));first.header:Click();first=assert(viewportCard(shell,{'value',1}));local top=first.proxy;local pane=first.pane
    top:SetCallback('OnClose',function() end);top:Hide();assert(not shell.frame:IsShown() and shell.closeOverride)
    c.frame.workbenchBar:SetValue(c.frame.workbenchBar.scrollRange);assert(first.token and first.proxy==top and first.pane==pane,'scroll retired a child-owned field pane')
    top:GetUserData('root').value[1].number=8;a.LayoutConditionFrame(top);top:Show()
    assert(shell.frame:IsShown() and shell.active.working.value[1].number==8 and root.value[1].number==1)
    shell.apply:Click();assert(root.value[1].number==8 and not shell.active)
end)
test('large viewport height changes retain a visible scroll anchor and invalid pending input',function()
    local f=fixture();local a=f.addon
    a:RegisterCondition('NATIVE',{description='Native',fields={number='number'},valid=function() return true end,print=function() return 'Native' end,
        widget=function(parent,_,value) local w=a:CreateConditionSlider();w:SetValue(value.number);parent:AddChild(w) end})
    local root={type='AND',value={}};for i=1,350 do root.value[i]={type='NATIVE',number=1} end
    local shell=a:EditCondition(1,0,root,function() end);local c=shell.canvas;c.frame.workbenchBar:SetValue(c.scene.cards[2].y)
    local first=assert(viewportCard(shell,{'value',1}));first.header:Click();first=assert(viewportCard(shell,{'value',1}))
    c.frame.workbenchBar:SetValue(first.model.y+7);local before=c.frame.workbenchBar:GetValue()-first.model.y
    local input=first.pane.children[1];input.editbox:SetText('invalid');input.editbox.scripts.OnTextChanged(input.editbox,true);input:SetFocus()
    first.pane:LayoutFinished(nil,220)
    assert(c.frame.workbenchBar:GetValue()-first.model.y==before,'height reflow jumped away from the visible condition')
    assert(input:IsPending() and input:GetText()=='invalid' and input.editbox:HasFocus(),'height reflow rebound the pending field')
    shell.cancel:Click();assert(not first.token and not input.rmActive and not c.drag and not c.scene)
end)
test('incomplete condition presentation rows show an explicit failure without an editable partial scene',function()
    local f=fixture();local root={type='NUMBER',number=1};local shell=f.addon:EditCondition(1,0,root,function() end);local c=shell.canvas;local stale=c.cards[1].controls.remove.scripts.OnClick
    local session=shell.active.session;local rows=session.Rows;session.Rows=function(self,limit) local value=rows(self,limit);return value,false end
    shell:Render();assert(not c.scene and not c.cards[1].token and shell.status:GetText()=='This condition exceeds the supported editor limits.')
    stale();assert(root.number==1 and shell.active.working.number==1);shell.cancel:Click()
end)
test('largest accepted condition tree remains reachable and applies its final node without allocating all controls',function()
    local f=fixture();local a=f.addon;a:RegisterCondition('EMPTY',{description='Empty',fields={},valid=function() return true end,print=function() return 'Empty' end})
    local root={type='AND',value={}};for i=1,4095 do root.value[i]={type='EMPTY'} end
    local shell=a:EditCondition(1,0,root,function() end);local c=shell.canvas;assert(#c.scene.cards==4096 and c.scene.complete)
    c.frame.workbenchBar:SetValue(c.frame.workbenchBar.scrollRange);local last=assert(viewportCard(shell,{'value',4095}));assert(last.controls.disable:IsEnabled() and #c.cards<80)
    last.controls.disable:Click();assert(root.value[4095].disabled==nil and shell.active.working.value[4095].disabled)
    shell.apply:Click();assert(not shell.active and root.value[4095].disabled and #root.value==4095)
end)
finish()
