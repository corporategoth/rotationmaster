local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function fixture()
    local f=F.new();f.load('Data/plain.lua');f.load('Data/tags.lua');f.load('Data/rotation_tree.lua')
    local row={id='pack',runtimeKey='pack-key',name='Shaman: early leveling',description='Leveling guidance',enabled=true,eligible=false,
        eligibilityReason='class-mismatch',revision=1,readOnly=true,
        applicability={families={'tbc'},class='SHAMAN',minLevel=1,maxLevel=19},
        envelope={body={rotation={{id='step',type='spell',action=403,conditions={type='SPELL_KNOWN',spell=403}}},cooldowns={}},
            sources={{url='https://example.invalid/guide',reviewedAt='2026-10-17'}}}}
    f.addon.ListDefaultRotations=function() return {row} end
    f.addon.Platform={CanReadValue=function() return true end,GetSpellInfo=function() return {name='Lightning Bolt',spellID=403,iconID=123} end,GetSpellLink=function() return '|Hspell:403|h[Lightning Bolt]|h' end}
    f.addon.printCondition=function() return 'You know Lightning Bolt' end
    f.addon.db.profile.enable=false
    f.load('UI/rotation_reference.lua');f.load('UI/defaults.lua')
    return f,row
end
test('default view exposes reference, enable and clone controls without edit/delete widgets',function()
    local f=fixture();local frame=f.addon:CreateConditionGroup()
    local selected
    f.addon.CloneDefaultRotation=function(_,spec,id,name)
        assert(spec==0 and id=='pack' and name~='');return 'new-custom'
    end
    f.addon:CreateDefaultRotationOptions(frame,0,'pack',function(id) selected=id end)
    local text=F.text(frame)
    assert(not text:find('View full rotation',1,true),'redundant default reference popup is still offered')
    assert(text:find('read%-only') and text:find('Leveling guidance',1,true))
    assert(text:find('Lightning Bolt',1,true) and text:find('https://example.invalid/guide',1,true))
    local clone,enable
    local function scan(widget)
        assert(widget.kind~='EditBox' and widget.kind~='Spell_EditBox','editable default field')
        if widget.type=='RM-ConditionButton' and widget.text=='Clone to edit' then clone=widget end
        if widget.type=='RM-CheckBox' then enable=widget end
        for _,child in ipairs(widget.children or {}) do scan(child) end
    end
    scan(frame);assert(clone and enable)
    clone:Fire('OnClick');assert(selected=='new-custom')
    local toggled=false
    f.addon.SetDefaultRotationEnabled=function(_,id,value) assert(id=='pack' and value==false);toggled=true;return true end
    enable:Fire('OnValueChanged',false);assert(toggled)
end)
test('full default reference shows switching, priority and independent optional steps without cloning',function()
    local f,row=fixture();local a=f.addon
    row.envelope.body.cooldowns={{id='shield',type='spell',action=324,conditions={type='BUFF',spell=324}}}
    row.envelope.body.switch={type='LEVEL',level=20}
    a.CloneDefaultRotation=function() error('viewing must not clone') end
    local frame=a:ShowDefaultRotation(0,'pack',function() end)
    local text=F.text(frame.root)
    assert(text:find('Switch conditions',1,true) and text:find('Sequential priority',1,true))
    assert(text:find('Optional highlights',1,true) and text:find('independently',1,true))
    local links={}
    local function scan(w)
        assert(w.kind~='EditBox' and w.kind~='Spell_EditBox','default reference became editable')
        if w.type=='RM-ConditionLink' and w.text:find('|Hspell:',1,true) then links[w:GetUserData('spell')]=w.image end
        for _,child in ipairs(w.children or {}) do scan(child) end
    end
    scan(frame.root);assert(links[403] and links[324] and links[6603],'authored steps and implicit fallback need native spell links and icons')
end)
test('item lists render each item instead of throwing or hiding their contents',function()
    local f=fixture();local parent=f.widget('parent')
    f.env.GetItemInfo=function(id) return id==5512 and 'Healthstone' or 'Healing Potion' end
    f.addon:CreateRotationStepCard(parent,{type='item',action={5512,118},conditions={}},0,1,'cooldowns')
    local text=F.text(parent)
    assert(text:find('Healthstone',1,true) and text:find('Healing Potion',1,true))
end)
test('spell player and pet execution contexts are visible on reference cards',function()
    local f=fixture();local parent=f.widget('parent')
    f.addon:CreateRotationStepCard(parent,{type='pet',action=403,conditions={}},0,1,'rotation')
    assert(F.text(parent):find('Pet spell',1,true),'pet and player actions look identical')
end)
test('read-only references never run custom Lua printers even inside nested fields',function()
    local f=F.new();local a=f.addon
    f.load('Core/conditions.lua');f.load('UI/rotation_reference.lua')
    local calls=0
    a:RegisterCondition('CUSTOM_PREVIEW',{description='My custom check',fields={},customCode=true,
        print=function() calls=calls+1;a.db.profile.sideEffect=true;return 'executed custom printer' end})
    a:RegisterCondition('WRAPPER',{description='Wrapper',fields={gate='condition'},
        print=function(spec,value) return a:printCondition(value.gate,spec) end})
    local parent=f.widget('parent')
    a:CreateConditionReference(parent,{type='NOT',value={type='WRAPPER',gate={type='CUSTOM_PREVIEW'}}},0)
    assert(calls==0 and not a.db.profile.sideEffect,'reference display executed custom Lua')
    -- The data-only summary (6494a9a3) names the wrapper and lists its saved settings, the nested condition by its tag.
    assert(F.text(parent):find('Wrapper',1,true) and F.text(parent):find('CUSTOM_PREVIEW',1,true),'data-only condition summary is missing')
end)
test('cloning from a separate reference opens a fresh editor without touching a released source pane',function()
    local f=fixture();local a=f.addon
    a.CloneDefaultRotation=function() return 'new-clone' end
    local opened=false
    a.ShowConfig=function(_,section,selection) assert(section=='Rotations' and selection.spec==0 and selection.id=='new-clone');opened=true end
    local window=a:ShowDefaultRotation(0,'pack',function() error('source editor has been released') end)
    for _,child in ipairs(window.root.children) do if child.type=='RM-ConditionButton' and child.text=='Clone to edit' then child:Fire('OnClick') end end
    assert(opened and not window.frame:IsShown() and not window.root)
end)
test('default exports route through the immutable runtime reference',function()
    local f=fixture();local parent=f.addon:CreateConditionGroup()
    local exported=false
    f.addon.ShowRotationTransfer=function(_,spec,key) assert(spec==0 and key=='pack-key');exported=true end
    f.addon:CreateDefaultRotationOptions(parent,0,'pack',function() error('export cloned a default') end)
    for _,child in ipairs(parent.children) do if child.type=='RM-ConditionButton' and child.text=='Export Built In' then child:Fire('OnClick') end end
    assert(exported)
end)
test('native default window owns pooled content and ignores callbacks after close or profile replacement',function()
    local f,row=fixture();local a=f.addon;local before=a.RotationData.CopyData(row.envelope);local changed=0
    a.SetDefaultRotationEnabled=function() changed=changed+1;return true end
    a.CloneDefaultRotation=function() changed=changed+1;return 'clone' end
    a.ShowRotationTransfer=function() changed=changed+1 end
    local d=a:ShowDefaultRotation(0,'pack');local root=d.root;local old={}
    for _,child in ipairs(root.children) do if child.type=='RM-ConditionButton' or child.type=='RM-CheckBox' then old[#old+1]=child.events.OnClick or child.events.OnValueChanged end end
    assert(d.chrome and d.viewport.contentWidget==root and d.frame:IsShown())
    d:Hide();assert(not root.rmActive and not d.root)
    local reopened=a:ShowDefaultRotation(0,'pack');assert(reopened==d and reopened.root.rmActive);root=reopened.root
    for _,callback in ipairs(old) do callback(nil,nil,false) end;assert(changed==0,'closed view retained live actions')
    local enable;for _,child in ipairs(root.children) do if child.type=='RM-CheckBox' then enable=child end end
    a.db.profile={};enable:Fire('OnValueChanged',false);assert(changed==0,'stale profile callback changed preferences')
    d.frame.scripts.OnUpdate();assert(not d.frame:IsShown() and not root.rmActive)
    assert(a:SettingsDataEqual(row.envelope,before),'reference view changed source data')
end)
test('embedded native viewport releases content and restores group methods under a native parent',function()
    local f=fixture();local a=f.addon
    local parent=a:CreateConditionGroup();parent:SetWidth(700);parent:SetHeight(620);parent:SetLayout('List')
    local seen={}
    for _=1,5 do
        a:CreateDefaultRotationOptions(parent,0,'pack',function() end)
        local holder=parent.children[#parent.children];local viewport=holder.rmDefaultViewport;local content=viewport.contentWidget
        assert(holder.rmWidget and viewport:IsShown() and content and content.rmActive and holder.frame:GetHeight()>=120)
        seen[#seen+1]={holder=holder,content=content,viewport=viewport}
    end
    a:ReleaseConditionWidget(parent)
    for _,entry in ipairs(seen) do assert(not entry.holder.rmActive and not entry.content.rmActive and not entry.viewport.contentWidget and not entry.viewport:IsShown(),'embedded content retained its owner') end
    local group=a:CreateConditionGroup();group:SetWidth(200);local child=a:CreateConditionCheckBox();group:AddChild(child)
    assert(group.frame:GetHeight()==24 and child.frame:GetParent()==group.frame,'reference viewport methods escaped into an ordinary group lease')
    a:ReleaseConditionWidget(group)
end)
test('failed default reference rendering releases unattached and attached native groups',function()
    local f=fixture();local a=f.addon;local allocated={};local stop=a:ObserveConditionWidgets(function(widget) allocated[#allocated+1]=widget end)
    a.CreateRotationReference=function(_,parent) local text=a:CreateConditionLabel();parent:AddChild(text);error('injected reference failure') end
    local ok,why=pcall(a.ShowDefaultRotation,a,0,'pack');stop();assert(not ok and why:find('injected reference failure',1,true))
    for _,widget in ipairs(allocated) do assert(not widget.rmActive,'failed default reference orphaned '..widget.type) end
end)
test('unavailable references stay native and failed enable or clone actions show their reason',function()
    local f=fixture();local a=f.addon;local root=a:CreateConditionGroup();root:SetUserData('defaultWholeScroll',true)
    a.SetDefaultRotationEnabled=function() return nil,'blocked' end;a.CloneDefaultRotation=function() return nil,'blocked clone' end
    a:CreateDefaultRotationOptions(root,0,'pack',function() error('failed clone navigated') end)
    for _,child in ipairs(root.children) do if child.type=='RM-CheckBox' then child:Fire('OnValueChanged',false) end end
    assert(F.text(root):find('blocked',1,true))
    for _,child in ipairs(root.children) do if child.type=='RM-ConditionButton' and child.text=='Clone to edit' then child:Fire('OnClick') end end
    assert(F.text(root):find('blocked clone',1,true));a.ListDefaultRotations=function() return {} end
    a:CreateDefaultRotationOptions(root,0,'missing',function() end);assert(#root.children==1 and F.text(root):find('unavailable',1,true))
    a:ReleaseConditionWidget(root)
end)
finish()
