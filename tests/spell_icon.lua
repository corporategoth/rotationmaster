local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function fixture(allowFields)
    local f=F.new();local frames,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    local ace=f.libraries['AceGUI-3.0'];local original=ace.Create
    local pooled
    ace.Create=function(self,kind)
        assert(allowFields or kind=='Icon','spell icon still uses a vendor action widget')
        local w=pooled or original(self,kind);pooled=nil
        if not w.frame then w.frame=create('Button');w.frame:RegisterForClicks('LeftButtonUp') end
        function w:SetColor() end
        if kind:match('^ActionSlot') then w.text=create('FontString');w.SetText=function(self,value) self.actionData=value end end
        function w:Fire(event,...) if self.callbacks and self.callbacks[event] then return self.callbacks[event](self,event,...) end end
        return w
    end
    ace.Release=function(_,w) if w.OnRelease then w:OnRelease() end;w.callbacks={};pooled=w end
    f.env.C_Spell={GetSpellInfo=function(id)
        if id=='Lightning Bolt' then id=403 end
        if id==403 or id==529 then return {spellID=id,name='Lightning Bolt',iconID=135932} end
    end}
    f.env.ClearCursor=function() f.cleared=(f.cleared or 0)+1 end
    f.env.GameTooltip={IsVisible=function() return f.tooltip~=nil end,IsOwned=function(_,owner) return f.tooltipOwner==owner end,SetOwner=function(_,owner) f.tooltipOwner=owner end,
        SetHyperlink=function(_,link) f.tooltip=link end,Hide=function() f.tooltip=nil;f.tooltipOwner=nil end}
    f.load('Platform/client.lua');f.load('Platform/spells.lua');f.load('UI/spell_icon.lua')
    return f
end
test('modern spell metadata paints exact IDs without legacy globals or selection callbacks',function()
    local f=fixture();local w=f.addon:CreateSpellActionIcon('spell',403)
    local calls=0;w:SetCallback('OnEnterPressed',function() calls=calls+1 end)
    assert(w.image==135932 and w:GetUserData('spell')==403)
    w:SetText(529);assert(w:GetUserData('spell')==529 and calls==0)
    w.callbacks.OnEnter(w);assert(f.tooltip=='spell:529')
    w.callbacks.OnLeave(w);assert(f.tooltip==nil)
    w:SetText(nil);assert(w:GetUserData('spell')==nil)
end)
test('drops use exact native spell IDs and validate bank and selection before touching the cursor',function()
    local f=fixture();local w=f.addon:CreateSpellActionIcon('spell',403,function(id) return id==529 end)
    local id;w:SetCallback('OnEnterPressed',function(_,_,value) id=tonumber(value);w:SetText(id) end)
    f.env.GetCursorInfo=function() return 'spell',7,'spell',529 end
    w.frame.scripts.OnReceiveDrag(w.frame);assert(id==529 and f.cleared==1)
    f.env.GetCursorInfo=function() return 'spell',7,'spell',403 end
    w.frame.scripts.OnReceiveDrag(w.frame);assert(id==529 and f.cleared==1,'rejected spell replaced selection or consumed cursor')
    f.env.GetCursorInfo=function() return 'petaction',403 end
    w.frame.scripts.OnReceiveDrag(w.frame);assert(id==529 and f.cleared==1)
    local pet=f.addon:CreateSpellActionIcon('pet',403)
    pet:SetCallback('OnEnterPressed',function(_,_,value) id=tonumber(value) end)
    f.env.GetCursorInfo=function() return 'petaction',529 end
    pet.frame.scripts.OnReceiveDrag(pet.frame);assert(id==529 and f.cleared==2)
end)
test('unknown secret malformed or throwing cursor and metadata never invent a selection',function()
    local f=fixture();local w=f.addon:CreateSpellActionIcon('spell',403)
    w:SetCallback('OnEnterPressed',function() error('must not commit invalid observations') end)
    local opaque={};f.env.canaccessvalue=function(v) return v~=opaque end
    for _,cursor in ipairs({{'spell',7,'spell'}, {'spell',7,'spell',opaque}, {'spell',7,'spell',999}, {'spell',7,'spell',-1}, {'item',403}}) do
        f.env.GetCursorInfo=function() return unpack(cursor) end
        w.frame.scripts.OnReceiveDrag(w.frame)
    end
    f.env.GetCursorInfo=function() error('cursor unavailable') end;w.frame.scripts.OnReceiveDrag(w.frame)
    f.env.GetCursorInfo=function() return 'spell',7,'spell',529 end
    f.env.C_Spell.GetSpellInfo=function() error('metadata unavailable') end;w.frame.scripts.OnReceiveDrag(w.frame)
    assert(not f.cleared and w:GetUserData('spell')==403)
end)
test('explicit clearing disabled state and pooling preserve ordinary Icon ownership',function()
    local f=fixture();local a=f.addon;local ace=f.libraries['AceGUI-3.0']
    local w=a:CreateSpellActionIcon('spell',403);local saved=403
    w:SetCallback('OnEnterPressed',function(_,_,value) saved=tonumber(value);w:SetText(saved) end)
    w:SetDisabled(true);w.frame.scripts.OnClick(w.frame,'RightButton');assert(saved==403)
    f.env.GetCursorInfo=function() return 'spell',7,'spell',529 end
    w.frame.scripts.OnReceiveDrag(w.frame);assert(saved==403 and not f.cleared)
    w:SetDisabled(false);w.frame.scripts.OnClick(w.frame,'RightButton');assert(saved==nil and w:GetUserData('spell')==nil)
    local stale=w.frame.scripts.OnReceiveDrag;ace:Release(w)
    assert(w.frame.scripts.OnReceiveDrag==nil and #w.frame.clicks==1 and w.frame.clicks[1]=='LeftButtonUp')
    stale(w.frame);assert(not f.cleared)
    local reused=a:CreateSpellActionIcon('spell',403);assert(reused==w)
    reused:SetCallback('OnEnterPressed',function() ace:Release(reused) end)
    reused.frame.scripts.OnReceiveDrag(reused.frame)
    assert(not reused.rmSpellIconActive and reused.frame.scripts.OnReceiveDrag==nil,'release during commit touched the next owner')
end)
test('clearing an actual common condition icon clears saved spell identity and named spell identity',function()
    for _,case in ipairs({{false,false},{true,false},{false,true},{true,true}}) do
        local named,acceptNil=case[1],case[2]
        local f=fixture(true);local a=f.addon
        dofile('tests/fixtures/spell_editbox.lua')(f)
        f.env.BOOKTYPE_SPELL='spell';f.env.BOOKTYPE_PET='pet'
        f.load('UI/window.lua');f.load('Conditions/common.lua')
        local value={spell=named and 'Lightning Bolt' or 403};local updates=0
        local valid=function(id) return acceptNil or type(id)=='number' end
        local group
        if named then group=a:Widget_SpellNameWidget(0,'Spell_EditBox',value,valid,function() updates=updates+1 end)
        else group=a:Widget_SpellWidget(0,'Spell_EditBox',value,function() return 403 end,valid,function() updates=updates+1 end) end
        local icon=group.children[1]
        icon.callbacks.OnEnter(icon)
        assert(f.tooltip=='spell:403','named condition tooltip did not resolve a numeric spell link')
        f.env.GetCursorInfo=function() return 'spell',7,'spell',529 end
        icon.frame.scripts.OnReceiveDrag(icon.frame)
        assert(value.spell==(named and 'Lightning Bolt' or 529) and updates==1,'actual icon drop lost condition identity')
        icon.frame.scripts.OnClick(icon.frame,'RightButton')
        assert(value.spell==nil and updates==2,'clear only changed the picture; saved condition still refers to the spell')
    end
end)
test('diagnostic wrappers do not survive release of an owned spell icon',function()
    local f=fixture();f.load('Diagnostics/errors.lua')
    local w=f.addon:CreateSpellActionIcon('spell',403);f.libraries['AceGUI-3.0']:Release(w)
    assert(w.frame:GetScript('OnReceiveDrag')==nil and w.frame:GetScript('OnClick')==nil)
end)
test('releasing icons restores exact nonnil original scripts without stacking diagnostics',function()
    local f=fixture();f.load('Diagnostics/errors.lua');local ace=f.libraries['AceGUI-3.0'];local base=ace:Create('Icon');local original=function() end
    base.frame:SetScript('OnClick',original);ace:Release(base)
    for _=1,5 do local w=f.addon:CreateSpellActionIcon('spell',403);ace:Release(w);assert(w.frame:GetScript('OnClick')==original) end
end)
finish()
