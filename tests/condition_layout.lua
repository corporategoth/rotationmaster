local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();local lookup=f.env.LibStub
    f.env.LibStub=function(name,...) assert(name~='AceGUI-3.0','native layout requested a GUI library');return lookup(name,...) end
    return f
end
test('five default factories acquire and recycle without Ace allocation or release',function()
    local f=fixture();local a=f.addon
    assert(a.ReleaseConditionWidget,'native lifecycle missing')
    for _,name in ipairs({'CreateConditionGroup','CreateConditionEditBox','CreateConditionSlider','CreateConditionCheckBox','CreateConditionDropdown'}) do
        local w=a[name](a);local calls=0;w:SetUserData('old',true);w.configure=function() error('old configure') end;w:SetCallback('Review',function() calls=calls+1 end);local stale=w.events.Review
        assert(w.frame.obj==w);assert(a:ReleaseConditionWidget(w));assert(not a:ReleaseConditionWidget(w))
        local nextWidget=a[name](a);assert(nextWidget==w and nextWidget:GetUserData('old')==nil and nextWidget.configure==nil)
        stale(w,'Review');assert(calls==0,'retired callback remained live on reuse')
        a:ReleaseConditionWidget(nextWidget)
    end
end)
test('native parents recycle child leases without accumulating frames or committing drafts',function()
    local f=fixture();local a=f.addon;local seen={};local calls=0
    for _=1,100 do
        local parent=a:CreateConditionGroup();local child=a:CreateConditionEditBox();seen[child]=true
        child:SetCallback('OnEnterPressed',function() calls=calls+1 end);parent:AddChild(child)
        child:SetText('Before');child.editbox:SetText('Pending');child.editbox.scripts.OnTextChanged(child.editbox,true)
        a:ReleaseConditionWidget(parent)
    end
    local count=0;for _ in pairs(seen) do count=count+1 end
    assert(count==1 and calls==0,'native discard stranded leases or saved pending text')
end)
test('release callbacks cannot reacquire queued leases and cleanup survives errors',function()
    local f=fixture();local a=f.addon;local root=a:CreateConditionGroup();local first=a:CreateConditionEditBox();local second=a:CreateConditionCheckBox()
    root:AddChild(first);root:AddChild(second);local acquired;local releases=0
    first:SetCallback('OnRelease',function() acquired=a:CreateConditionEditBox();assert(acquired~=first);error('release failure') end)
    second:SetCallback('OnRelease',function() releases=releases+1 end)
    local ok,why=pcall(a.ReleaseConditionWidget,a,root)
    assert(not ok and tostring(why):find('release failure',1,true));assert(releases==1 and #root.children==0)
    assert(root.rmQuarantined and first.rmQuarantined and not second.rmActive)
    local nextRoot=a:CreateConditionGroup();assert(nextRoot~=root);a:ReleaseConditionWidget(nextRoot);a:ReleaseConditionWidget(acquired)
end)
test('allocation observation covers captured factories and restores nested observers',function()
    local f=fixture();local a=f.addon;local captured=a.CreateConditionGroup;local outer,inner=0,0
    local stopOuter=a:ObserveConditionWidgets(function() outer=outer+1 end)
    local stopInner=a:ObserveConditionWidgets(function() inner=inner+1 end)
    local one=captured(a);stopInner();local two=captured(a);stopOuter();local three=captured(a)
    assert(outer==2 and inner==1);a:ReleaseConditionWidget(one);a:ReleaseConditionWidget(two);a:ReleaseConditionWidget(three)
end)
test('native Release methods retire leases and preserve callback error cleanup',function()
    local f=fixture();local a=f.addon;local child=a:CreateConditionCheckBox()
    child:Release();assert(not child.rmActive and not child.alive)
    local input=a:CreateConditionEditBox();input:SetCallback('OnRelease',function() error('release callback failed') end)
    local ok,why=pcall(input.Release,input);assert(not ok and tostring(why):find('release callback failed',1,true))
    assert(not input.isQueuedForRelease and not input.rmActive and not input.alive and input.rmQuarantined)
    local nextWidget=a:CreateConditionEditBox();assert(nextWidget~=input);a:ReleaseConditionWidget(nextWidget)
end)
test('ordinary item-set and shapeshift fields use native icons without Ace allocation',function()
    local f=fixture();local a=f.addon;f.env.UnitClass=function() return 'Warrior','WARRIOR',1 end;f.env.GetNumShapeshiftForms=function() return 0 end
    f.load('Conditions/common.lua');f.load('Conditions/combat.lua');a.db.profile.itemsets={};a.db.global.itemsets={}
    local items=a:Widget_ItemWidget(nil,'Item_EditBox',{},function() return true end,function() end)
    assert(items.children[1].type=='RM-ConditionIcon' and items.children[3].type=='RM-ConditionIcon');a:ReleaseConditionWidget(items)
    local root=a:CreateConditionGroup();local top=f.widget('Frame');top:SetUserData('funcs',{print=function() return '' end});top:SetUserData('root',{type='FORM',value=0});root:SetUserData('top',top)
    a.definitions.FORM.widget(root,0,{type='FORM',value=0});assert(root.children[1].type=='RM-ConditionIcon');a:ReleaseConditionWidget(root)
end)
test('condition item popup keeps its originating lease and resumes through the session proxy',function()
    local f=fixture();local a=f.addon;f.load('Conditions/common.lua');a.db.profile.itemsets={};a.db.global.itemsets={}
    a.UpdateItem_ID_Image=function() end;a.FindFirstItemOfItems=function() end;a.FindFirstItemInItems=function() end
    local changes,resumed,hidden=0,0,0;local top={SetCallback=function() end,Hide=function() hidden=hidden+1 end,rmResumeFromChild=function() resumed=resumed+1 end}
    local popup
    a.item_list_popup=function(_,name,kind,items,valid,changed,closed,options) popup={items=items,changed=changed,closed=closed,options=options};assert(kind=='Inventory_EditBox' and valid(10)) end
    local value={item={}};local group=a:Widget_ItemWidget(top,'Inventory_EditBox',value,function(id) return id==10 end,function() changes=changes+1 end)
    group.children[3]:Fire('OnClick');assert(hidden==1 and popup.items==value.item and popup.options.valid())
    popup.changed();assert(changes==1)
    a:ReleaseConditionWidget(group);assert(not popup.options.valid());popup.changed();assert(changes==1,'retired popup changed condition fields')
    local owned=a:CreateConditionGroup();popup.closed(owned);assert(not owned.rmActive and resumed==1,'closed child could not resume session after fields retired')
end)
test('named item popup rejects a replaced saved set even while its original field lease is active',function()
    local f=fixture();local a=f.addon;f.load('Conditions/common.lua')
    a.db.profile.itemsets={set={name='Selected set',items={10}}};a.db.global.itemsets={set={name='Other set',items={11}}}
    a.UpdateItem_ID_Image=function() end;a.FindFirstItemOfItemSet=function() end;a.FindFirstItemInItemSet=function() end
    local options;a.item_list_popup=function(_,_,_,_,_,_,_,guard) options=guard end
    local value={item='set'};local group=a:Widget_ItemWidget(nil,'Inventory_EditBox',value,function() return true end,function() end)
    group.children[3]:Fire('OnClick');assert(options.valid())
    local original=a.db.profile.itemsets.set;a.db.profile.itemsets.set={name='Replacement',items={10}};assert(not options.valid(),'replaced named set remained editable')
    a.db.profile.itemsets.set=original;assert(options.valid());original.items={10};assert(not options.valid(),'replaced target array remained editable')
    a:ReleaseConditionWidget(group)
end)
test('condition native list owns layout and propagates measured child heights',function()
    local f=fixture();local a=f.addon;local group=a:CreateConditionGroup();group:SetWidth(320);group:SetLayout('List')
    local first=a:CreateConditionEditBox();first:SetLabel('First');first:SetFullWidth(true)
    local second=a:CreateConditionCheckBox();second:SetLabel('Second');second:SetFullWidth(true)
    group:AddChild(first);group:AddChild(second);group:DoLayout()
    assert(first.frame:GetWidth()==320 and second.frame:GetWidth()==320,'list did not size full-width children')
    assert(second.frame.point[5]<first.frame.point[5] and group.frame:GetHeight()>=68,'list overlapped rows')
    assert(first.parent==group and second.parent==group,'legacy child ownership missing')
end)
test('native reference-card padding and relative widths stay inside measured bounds',function()
    local f=fixture();local a=f.addon;local group=a:CreateConditionGroup();group:SetWidth(320);group:SetUserData('padding',8)
    local child=a:CreateConditionCheckBox();child:SetRelativeWidth(.5);group:AddChild(child)
    assert(child.frame:GetWidth()==152 and child.frame.point[4]==8 and child.frame.point[5]==-8)
    assert(group.frame:GetHeight()==40);a:ReleaseConditionWidget(group)
    local reused=a:CreateConditionGroup();assert(reused==group and reused:GetUserData('padding')==nil);reused:SetWidth(320)
    child=a:CreateConditionCheckBox();child:SetFullWidth(true);reused:AddChild(child);assert(child.frame:GetWidth()==320 and child.frame.point[4]==0)
    a:ReleaseConditionWidget(reused)
end)
test('condition table sizes fixed and remaining columns',function()
    local f=fixture();local a=f.addon;local group=a:CreateConditionGroup();group:SetWidth(320);group:SetLayout('Table');group:SetUserData('table',{columns={44,1}})
    local first=a:CreateConditionCheckBox();first:SetHeight(44)
    local second=a:CreateConditionEditBox();second:SetLabel('Spell');second:SetFullWidth(true)
    group:AddChild(first);group:AddChild(second);group:DoLayout()
    assert(first.frame:GetWidth()==44 and second.frame:GetWidth()==272,'table lost fixed/remaining columns')
    assert(second.frame.point[5]==first.frame.point[5] and second.frame.point[4]>first.frame.point[4],'table columns overlap')
end)
test('releasing native layout children discards pending text without callbacks',function()
    local f=fixture();local a=f.addon;local group=a:CreateConditionGroup();local child=a:CreateConditionEditBox();local called=0
    child:SetText('Before');child:SetCallback('OnEnterPressed',function() called=called+1 end);group:AddChild(child)
    child.editbox:SetText('Pending');child.editbox.scripts.OnTextChanged(child.editbox,true)
    group:ReleaseChildren();assert(called==0 and #group.children==0 and not child:IsPending(),'release committed abandoned edits')
end)
test('pooled root hiding cannot commit child focus loss before recursive release',function()
    local f=fixture();local a=f.addon;local group=a:CreateConditionGroup();local child=a:CreateConditionEditBox();local called=0
    child:SetText('Before');child:SetCallback('OnEnterPressed',function() called=called+1 end);group:AddChild(child)
    child.editbox:SetText('Pending');child.editbox.scripts.OnTextChanged(child.editbox,true)
    group.frame:SetScript('OnHide',function() child.editbox.scripts.OnEditFocusLost(child.editbox) end)
    a:ReleaseConditionWidget(group)
    assert(called==0,'parent release committed child focus loss before its own release')
end)
test('zero-width table columns keep intrinsic content sizing beside numeric values',function()
    local f=fixture();local a=f.addon;local group=a:CreateConditionGroup();group:SetWidth(500);group:SetLayout('Table');group:SetUserData('table',{columns={0,75}})
    local first=a:CreateConditionDropdown();first:SetWidth(180);first:SetFullWidth(true)
    local second=a:CreateConditionEditBox();second:SetFullWidth(true);group:AddChild(first);group:AddChild(second);group:DoLayout()
    assert(first.frame:GetWidth()==180 and second.frame:GetWidth()==75,'zero column incorrectly consumed free space')
end)
test('pooled groups recover layout after a custom child throws during geometry',function()
    local f=fixture();local a=f.addon;local group=a:CreateConditionGroup()
    local child=a:CreateConditionEditBox();local width=child.SetWidth
    child.SetWidth=function() error('custom field geometry failed') end
    assert(not pcall(group.AddChild,group,child),'custom geometry did not fail')
    child.SetWidth=width;a:ReleaseConditionWidget(group)
    local reused=a:CreateConditionGroup();assert(reused==group,'regression did not reuse the failed group')
    reused:SetWidth(320);local replacement=a:CreateConditionCheckBox();replacement:SetFullWidth(true);reused:AddChild(replacement)
    assert(replacement.frame:GetWidth()==320 and reused.frame:GetHeight()==24,'pooled group retained the failed layout lock')
end)
test('one native layout pass visits a deep group chain linearly',function()
    local f=fixture();local a=f.addon;local root=a:CreateConditionGroup();local current=root;local groups={root}
    for _=2,10 do local child=a:CreateConditionGroup();child:SetFullWidth(true);current:AddChild(child);groups[#groups+1]=child;current=child end
    current:AddChild(a:CreateConditionCheckBox());local passes=0
    for _,group in ipairs(groups) do local finished=group.LayoutFinished;group.LayoutFinished=function(self,...) passes=passes+1;return finished(self,...) end end
    root:DoLayout();assert(passes<=20,'native layout repeated deep subtrees: '..passes)
end)
test('native child height changes propagate to the owning parent',function()
    local f=fixture();local a=f.addon;local parent=a:CreateConditionGroup();local child=a:CreateConditionGroup();local field=a:CreateConditionCheckBox()
    child:AddChild(field);parent:AddChild(child);assert(parent.frame:GetHeight()==24)
    field:SetHeight(80);child:DoLayout();assert(parent.frame:GetHeight()==80)
    a:ReleaseConditionWidget(parent)
end)
test('ordinary item-set table bottom alignment never requests the Ace layout',function()
    local f=fixture();local a=f.addon;f.load('Conditions/common.lua');a.db.profile.itemsets={};a.db.global.itemsets={}
    local group=a:Widget_ItemWidget(nil,'Inventory_EditBox',{item={}},function() return true end,function() end)
    local button=group.children[3];local bottom=0
    for _,child in ipairs(group.children) do bottom=math.max(bottom,child.frame:GetHeight()) end
    assert(button.frame.point[5]==-(bottom-button.frame:GetHeight()),'item list action was not aligned to the row bottom')
    a:ReleaseConditionWidget(group)
end)
test('native table vertical alignment uses the tallest current row including partial rows',function()
    local f=fixture();local a=f.addon
    local group=a:CreateConditionGroup();group:SetWidth(320);group:SetLayout('Table');group:SetUserData('table',{columns={44,1,44}});group:PauseLayout()
    local children={}
    for i,height in ipairs({24,60,40,20,36}) do
        local child=a:CreateConditionCheckBox();child:SetHeight(height);child:SetUserData('cell',{alignV=({'bottom','top','middle','end','start'})[i]});group:AddChild(child);children[i]=child
    end
    group:ResumeLayout();assert(children[1].frame.point[5]==-36 and children[2].frame.point[5]==0 and children[3].frame.point[5]==-10)
    assert(children[4].frame.point[5]==-80 and children[5].frame.point[5]==-64 and group.frame:GetHeight()==100)
    children[2]:SetHeight(80);group:DoLayout();assert(children[1].frame.point[5]==-56 and children[4].frame.point[5]==-100 and group.frame:GetHeight()==120)
    a:ReleaseConditionWidget(group)
end)
test('advanced native table alignment callbacks avoid the compatibility renderer',function()
    local f=fixture();local a=f.addon
    local group=a:CreateConditionGroup();group:SetLayout('Table');group:SetUserData('table',{columns={44,1}})
    local child=a:CreateConditionCheckBox();child:SetUserData('cell',{alignV=function() return 3 end});group:AddChild(child)
    assert(group.frame:GetHeight()==24 and child.frame.point[4]==-3);a:ReleaseConditionWidget(group)
end)

test('custom native table container alignment and spacing preserve geometry',function()
    local f=fixture();local a=f.addon
    local group=a:CreateConditionGroup();group:SetWidth(320);group:SetLayout('Table');group:PauseLayout();group:SetUserData('table',{columns={1,1},alignV='bottom',spaceV=12})
    local children={}
    for i,height in ipairs({60,24,40,20}) do local child=a:CreateConditionCheckBox();child:SetHeight(height);if i==1 then child:SetUserData('cell',{alignV='top'}) end;group:AddChild(child);children[i]=child end
    group:ResumeLayout()
    assert(children[2].frame.point[4]==-36 and children[4].frame.point[4]==-92 and group.frame:GetHeight()==112,'container options changed row placement')
    a:ReleaseConditionWidget(group)
end)

finish()
