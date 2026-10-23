-- Right-click insertion into spell and item fields: the target's or focus's
-- current cast, recent casts and equipped trinkets, committed exactly like a
-- chosen suggestion, in the condition and card editors' reference inputs and
-- in settings-page reference fields.
local F=dofile('tests/fixtures/addon.lua')
local function read(path) local h=assert(io.open(path));local text=h:read('*a');h:close();return text end
local prefix=assert(read('tests/spell_search_ui.lua'):match('^(.-)\ntest%('))
local fixture=assert(loadstring(prefix..'\nreturn fixture','@reference-insert-fixture'))()
local test,finish=F.suite()

local function game(f,options)
    local env=f.env;options=options or {}
    env.UnitExists=function(unit) return options[unit]~=nil end
    env.UnitCastingInfo=function(unit) local o=options[unit];if o and o.cast then return 'Cast','',1,0,1,false,'guid',false,o.cast end end
    env.UnitChannelInfo=function(unit) local o=options[unit];if o and o.channel then return 'Channel','',1,0,1,false,false,o.channel end end
    env.GetInventoryItemID=function(_,slot) return (options.trinkets or {})[slot] end
    f.addon.spellHistory=options.history or {}
end
local function rows(popup) local list={};for _,row in ipairs(popup.rows) do if row:IsShown() then list[#list+1]=row end end;return list end

test('right-click lists the target and focus casts and recent casts newest first, once each',function()
    local f=fixture();local a=f.addon
    game(f,{target={cast=974},focus={channel=403},history={{spell=529,time=3},{spell=974,time=2},{spell=529,time=1}}})
    local w=a:CreateSpellEditBox('Spell_EditBox');local chosen;w:SetCallback('OnEnterPressed',function(_,_,id) chosen=id end)
    w.editbox.scripts.OnMouseDown(w.editbox,'RightButton');local popup=w.rmSpellPopup;local shown=rows(popup)
    assert(popup:IsShown() and #shown==3,'insert menu does not list three distinct spells')
    assert(shown[1].text:GetText()=='Target casting: Earth Shield' and shown[1].spellID==974)
    assert(shown[2].text:GetText():find('^Focus channeling: Lightning Bolt') and shown[2].spellID==403)
    assert(shown[3].text:GetText():find('^Recently cast: Lightning Bolt') and shown[3].spellID==529,'recent casts are not newest first')
    shown[1].scripts.OnMouseDown(shown[1],'LeftButton')
    assert(chosen=='974' and w:GetText()=='Earth Shield' and not popup:IsShown(),'choosing an entry did not commit it like a suggestion')
    w.editbox.scripts.OnMouseDown(w.editbox,'RightButton');assert(popup:IsShown());w.editbox.scripts.OnMouseDown(w.editbox,'RightButton');assert(not popup:IsShown(),'right-click again did not close the menu')
end)

test('values the client will not let addons read are left out, and an empty menu says why',function()
    local f=fixture();local a=f.addon;game(f,{target={cast=974},history={{spell=529,time=1}}})
    a.Platform.CanReadValue=function(_,value) return value~=974 end
    local w=a:CreateSpellEditBox('Spell_EditBox');w.editbox.scripts.OnMouseDown(w.editbox,'RightButton')
    local shown=rows(w.rmSpellPopup);assert(#shown==1 and shown[1].spellID==529,'an unreadable cast was offered')
    game(f,{});w.editbox.scripts.OnMouseDown(w.editbox,'RightButton');w.editbox.scripts.OnMouseDown(w.editbox,'RightButton')
    assert(#rows(w.rmSpellPopup)==0 and w.rmSpellPopup.footer:GetText():find('Nothing to insert',1,true),'an empty insert menu does not explain itself')
end)

test('scoped spell fields offer only spells they accept',function()
    local f=fixture();local a=f.addon;game(f,{history={{spell=974,time=2},{spell=403,time=1}}})
    local w=a:CreateSpellEditBox('Spec_EditBox');w:SetUserData('spec',0);w.editbox.scripts.OnMouseDown(w.editbox,'RightButton')
    local shown=rows(w.rmSpellPopup);assert(#shown==1 and shown[1].spellID==403,'a spell outside the field scope was offered')
end)

test('item fields offer equipped trinkets and a left click still takes a cursor drop',function()
    local f=fixture();local a=f.addon
    f.env.GetItemInfo=function(id) local n=tonumber(id)==1 and 'Water' or tonumber(id)==2 and 'Bread';return n,nil,nil,nil,nil,nil,nil,nil,nil,n and tonumber(id)+10 end
    assert(a:UpdateReferenceItem(1) and a:UpdateReferenceItem(2));game(f,{trinkets={[13]=2,[14]=1}})
    local w=a:CreateItemEditBox('Item_EditBox');local chosen;w:SetCallback('OnEnterPressed',function(_,_,id) chosen=id end)
    w.editbox.scripts.OnMouseDown(w.editbox,'RightButton');local shown=rows(w.rmSpellPopup)
    assert(#shown==2 and shown[1].text:GetText()=='Trinket 1: Bread' and shown[2].text:GetText()=='Trinket 2: Water','trinkets are not offered in slot order')
    shown[2].scripts.OnMouseDown(shown[2],'LeftButton');assert(chosen=='1' and w:GetText()=='Water')
    f.env.GetCursorInfo=function() return 'item',2 end;local cleared=false;f.env.ClearCursor=function() cleared=true end
    w.editbox.scripts.OnMouseDown(w.editbox,'LeftButton');assert(chosen=='2' and cleared,'a left click no longer takes the cursor item')
end)

test('settings reference fields offer the same entries and stage the choice',function()
    local f=fixture();local a=f.addon;f.load('UI/settings_form.lua');game(f,{target={cast=974}})
    local parent=f.env.CreateFrame('Frame');parent:SetSize(900,600);local p=a:CreateSettingsForm(parent);local value
    p:Open(function(form) form:Spell('spell','Spell',403,nil,function(id) value=id end) end)
    local input=p.fields.spell;input.scripts.OnMouseDown(input,'RightButton')
    assert(p.menu and p.menu.frame:IsShown(),'settings spell field has no insert menu')
    local row;for _,r in ipairs(p.menu.rows) do if r:IsShown() and (r:GetText() or ''):find('Target casting: Earth Shield',1,true) then row=r end end
    assert(row,'target cast missing from the settings insert menu');row:Click()
    assert(value==974 and p.fields.spell:GetText():find('Earth Shield',1,true),'settings insert did not stage the spell')
end)
finish()
