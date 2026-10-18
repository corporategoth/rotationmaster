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
    local f=fixture();local frame=f.widget('parent')
    function frame:ReleaseChildren() self.children={} end
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
        if widget.kind=='Button' and widget.text=='Clone to edit' then clone=widget end
        if widget.kind=='CheckBox' then enable=widget end
        for _,child in ipairs(widget.children) do scan(child) end
    end
    scan(frame);assert(clone and enable)
    clone.callbacks.OnClick();assert(selected=='new-custom')
    local toggled=false
    f.addon.SetDefaultRotationEnabled=function(_,id,value) assert(id=='pack' and value==false);toggled=true;return true end
    enable.callbacks.OnValueChanged(nil,nil,false);assert(toggled)
end)
test('full default reference shows switching, priority and independent optional steps without cloning',function()
    local f,row=fixture();local a=f.addon
    row.envelope.body.cooldowns={{id='shield',type='spell',action=324,conditions={type='BUFF',spell=324}}}
    row.envelope.body.switch={type='LEVEL',level=20}
    local original=f.libraries['AceGUI-3.0'].Create
    f.libraries['AceGUI-3.0'].Create=function(self,kind)
        local w=original(self,kind)
        function w:SetTitle(text) self.title=text end
        function w:ReleaseChildren() self.children={} end
        return w
    end
    a.HideOnEscape=function() end
    a.CloneDefaultRotation=function() error('viewing must not clone') end
    local frame=a:ShowDefaultRotation(0,'pack',function() end)
    local text=F.text(frame)
    assert(text:find('Switch conditions',1,true) and text:find('Sequential priority',1,true))
    assert(text:find('Optional highlights',1,true) and text:find('independently',1,true))
    local links={}
    local function scan(w)
        assert(w.kind~='EditBox' and w.kind~='Spell_EditBox','default reference became editable')
        if w.kind=='InteractiveLabel' and w.text:find('|Hspell:',1,true) then links[w:GetUserData('spell')]=w.image end
        for _,child in ipairs(w.children) do scan(child) end
    end
    scan(frame);assert(links[403] and links[324] and links[6603],'authored steps and implicit fallback need native spell links and icons')
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
    assert(F.text(parent):find('My custom check',1,true),'data-only custom condition description is missing')
end)
test('cloning from a separate reference opens a fresh editor without touching a released source pane',function()
    local f=fixture();local a=f.addon;local original=f.libraries['AceGUI-3.0'].Create
    f.libraries['AceGUI-3.0'].Create=function(self,kind)
        local w=original(self,kind);function w:ReleaseChildren() self.children={} end
        function w:Hide() self.hidden=true end
        return w
    end
    a.HideOnEscape=function() end
    a.CloneDefaultRotation=function() return 'new-clone' end
    local opened=false
    a.ShowConfig=function(_,section,selection) assert(section=='Rotations' and selection.spec==0 and selection.id=='new-clone');opened=true end
    local window=a:ShowDefaultRotation(0,'pack',function() error('source editor has been released') end)
    for _,child in ipairs(window.children) do if child.kind=='Button' and child.text=='Clone to edit' then child.callbacks.OnClick() end end
    assert(opened and window.hidden)
end)
test('default exports route through the immutable runtime reference',function()
    local f=fixture();local parent=f.widget('parent');function parent:ReleaseChildren() self.children={} end
    local exported=false
    f.addon.ShowRotationTransfer=function(_,spec,key) assert(spec==0 and key=='pack-key');exported=true end
    f.addon:CreateDefaultRotationOptions(parent,0,'pack',function() error('export cloned a default') end)
    for _,child in ipairs(parent.children) do if child.kind=='Button' and child.text=='Export Built In' then child.callbacks.OnClick() end end
    assert(exported)
end)
finish()
