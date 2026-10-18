local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function fixture()
    local f=F.new();local a=f.addon
    dofile('tests/fixtures/spell_editbox.lua')(f)
    local info={[403]={name='Lightning Bolt',subtext='Rank 1',spellID=403,iconID=1},
        [529]={name='Lightning Bolt',subtext='Rank 2',spellID=529,iconID=1},
        [974]={name='Earth Shield',spellID=974,iconID=2}}
    a.Platform.GetSpellInfo=function(_,id) if id=='Lightning Bolt' then id=529 end;return info[id] end
    a.Platform.GetSpellLink=function(_,id) return 'spell:'..id end
    for id in pairs(info) do a.SpellCatalog:UpdateSpell(id) end
    a.specSpells={[0]={[403]=true},pet={[529]=true}}
    a.spellBookStatus={player={complete=true},pet={complete=true}}
    f.load('UI/window.lua');f.load('UI/spell_search.lua')
    return f
end
test('owned spell suggestions show named ranks and commit exact ID without shared loader',function()
    local f=fixture();local w=f.addon:CreateSpellEditBox('Spell_EditBox')
    w:SetUserData('norank',false);w:SetText('Lightning Bolt (Rank 1)')
    local chosen;w:SetCallback('OnEnterPressed',function(_,_,id) chosen=id end)
    w:SetFocus();local popup=assert(w.rmSpellPopup)
    assert(popup:IsShown() and popup.rows[1].spellID==529 and popup.rows[2].spellID==403)
    popup.rows[2].scripts.OnMouseDown(popup.rows[2],'LeftButton')
    assert(chosen=='403' and w:GetText()=='Lightning Bolt (Rank 1)' and not popup:IsShown())
    assert(f.libraries['AceGUI-3.0-SpellLoader'].spellList==nil)
end)
test('scoped suggestions filter current bank and cancellation leaves the saved selection alone',function()
    local f=fixture();local w=f.addon:CreateSpellEditBox('Spec_EditBox')
    w:SetUserData('spec',0);w:SetText('Lightning Bolt');local calls=0
    w:SetCallback('OnEnterPressed',function() calls=calls+1 end)
    w:SetFocus();local popup=w.rmSpellPopup
    assert(popup.rows[1].spellID==403 and not popup.rows[2]:IsShown())
    w.editbox:SetText('Earth Shield');w.editbox.scripts.OnEscapePressed(w.editbox)
    assert(calls==0 and w:GetText()=='Lightning Bolt' and not popup:IsShown())
end)
test('release closes suggestions and restores all native scripts and pooled methods',function()
    local f=fixture();local w=f.addon:CreateSpellEditBox('Spell_EditBox');local popup=w.rmSpellPopup
    w:SetText('Lightning');w:SetFocus();assert(popup:IsShown())
    w:OnRelease();assert(w.baseReleased and not popup:IsShown())
    assert(w.editbox:GetScript('OnEnterPressed')==nil and w.editbox:GetScript('OnEscapePressed')==nil)
    assert(w.rmSpellSearchActive==nil)
    local called=false;w:SetCallback('OnEnterPressed',function() called=true end);w:Fire('OnEnterPressed','unrelated')
    assert(called,'pooled callback retained spell processing')
end)
test('Enter reconfirms an exact displayed rank and Tab chooses a different suggestion',function()
    local f=fixture();local w=f.addon:CreateSpellEditBox('Spell_EditBox');local chosen={}
    w:SetUserData('norank',false);w:SetText('Lightning Bolt (Rank 1)')
    w:SetCallback('OnEnterPressed',function(_,_,id) chosen[#chosen+1]=id end)
    w:SetFocus();w.editbox.scripts.OnEnterPressed(w.editbox)
    assert(chosen[1]=='403','reconfirming selected rank upgraded it')
    w:SetFocus();w.editbox:SetText('Light')
    w.editbox.scripts.OnTabPressed(w.editbox,false)
    w.editbox.scripts.OnEnterPressed(w.editbox)
    assert(chosen[2]=='403','Tab did not move from rank2 to rank1')
    w:SetFocus();w.editbox:SetText('not a spell');w.editbox.scripts.OnEnterPressed(w.editbox)
    assert(#chosen==2,'invalid input committed an invented selection')
    w:ClearFocus();assert(w:GetText()=='Lightning Bolt (Rank 1)')
end)
test('spell and pet cursor drops preserve the supplied spell ID without guessing book slots',function()
    local f=fixture();local w=f.addon:CreateSpellEditBox('Spell_EditBox');local chosen,clears
    clears=0;f.env.ClearCursor=function() clears=clears+1 end
    w:SetCallback('OnEnterPressed',function(_,_,id) chosen=id end)
    f.env.GetCursorInfo=function() return 'spell',7,'spell',403 end
    w.editbox.scripts.OnReceiveDrag(w.editbox);assert(chosen=='403' and clears==1)
    f.env.GetCursorInfo=function() return 'petaction',529 end
    w.editbox.scripts.OnReceiveDrag(w.editbox);assert(chosen=='529' and clears==2)
    f.env.GetCursorInfo=function() return 'spell',7,'spell' end
    w.editbox.scripts.OnReceiveDrag(w.editbox);assert(chosen=='529' and clears==2,'slot was treated as a spell ID')
end)
test('selection callbacks may release and reuse the field without stale focus or text writes',function()
    local f=fixture();local w=f.addon:CreateSpellEditBox('Spell_EditBox')
    w:SetText('Lightning');w:SetCallback('OnEnterPressed',function()
        w:OnRelease();w:SetText('next owner')
        w.ClearFocus=function() error('stale callback touched next owner focus') end
    end)
    w:SetFocus();local row=w.rmSpellPopup.rows[1];row.scripts.OnMouseDown(row,'LeftButton')
    assert(w:GetText()=='next owner' and not w.rmSpellSearchActive and not w.rmSpellPopup:IsShown())
end)
test('hover tooltips use exact spell IDs and close with the owned suggestions',function()
    local f=fixture();local owner,link
    f.env.GameTooltip={SetOwner=function(_,value) owner=value end,SetHyperlink=function(_,value) link=value end,
        IsOwned=function(_,value) return owner==value end,Hide=function() owner=nil end}
    local w=f.addon:CreateSpellEditBox('Spell_EditBox');w:SetText('Lightning');w:SetFocus()
    local row=w.rmSpellPopup.rows[2];row.scripts.OnEnter(row)
    assert(owner==row and link=='spell:403')
    w.editbox.scripts.OnEscapePressed(w.editbox);assert(owner==nil)
end)
test('totem fields preserve selected-book and localized-name filtering on suggestions and manual entry',function()
    local f=fixture();local a=f.addon;local original=a.Platform.GetSpellInfo
    a.Platform.GetSpellInfo=function(self,id)
        if id==8071 then return {name='Stoneskin Totem',spellID=id,iconID=1} end
        return original(self,id)
    end
    a.SpellCatalog:UpdateSpell(8071);a.specSpells[0][8071]=true
    local w=a:CreateSpellEditBox('Totem_EditBox');w:SetUserData('spec',0)
    local chosen;w:SetCallback('OnEnterPressed',function(_,_,id) chosen=id end)
    w:SetFocus();local popup=w.rmSpellPopup
    assert(popup.rows[1].spellID==8071 and not popup.rows[2]:IsShown(),'totem scope first='..tostring(popup.rows[1].spellID)..' second='..tostring(popup.rows[2].spellID)..' footer='..tostring(popup.footer.text))
    popup.rows[1].scripts.OnMouseDown(popup.rows[1],'LeftButton');assert(chosen=='8071')
    w:SetFocus();w.editbox:SetText('403');w.editbox.scripts.OnEnterPressed(w.editbox)
    assert(chosen=='8071','manual non-totem input reached the consumer')
end)
test('diagnostic wrappers are restored when a pooled spell field is released',function()
    local f=fixture();f.load('Diagnostics/errors.lua')
    local w=f.addon:CreateSpellEditBox('Spell_EditBox');w:OnRelease()
    assert(w.editbox:GetScript('OnEnterPressed')==nil and w.editbox:GetScript('OnEscapePressed')==nil)
end)
test('releasing diagnostic-wrapped fields restores exact nonnil original scripts across reuse',function()
    local f=fixture();f.load('Diagnostics/errors.lua');local ace=f.libraries['AceGUI-3.0'];local create=ace.Create;local original
    ace.Create=function(self,kind) local w=create(self,kind);original=w.editbox:GetScript('OnTextChanged');return w end
    local w=f.addon:CreateSpellEditBox('Spell_EditBox');w:OnRelease();assert(w.editbox:GetScript('OnTextChanged')==original)
    ace.Create=function() return w end
    for _=1,5 do w=f.addon:CreateSpellEditBox('Spell_EditBox');w:OnRelease();assert(w.editbox:GetScript('OnTextChanged')==original) end
end)
test('every programmatic numeric spell value displays its name rather than its saved identifier',function()
    local f=fixture();local a=f.addon
    for _,kind in ipairs({'Spell_EditBox','Spec_EditBox','Totem_EditBox'}) do
        local w=a:CreateSpellEditBox(kind,403);w:SetText(403)
        assert(w:GetText():find('Lightning Bolt',1,true) and w:GetText()~='403')
        w:OnRelease()
    end
end)
test('item suggestions show icons and commit exact item IDs with inventory filtering',function()
    local f=fixture();local a=f.addon
    f.env.GetItemInfo=function(id) local n=tonumber(id)==1 and 'Water' or tonumber(id)==2 and 'Bread';return n,nil,nil,nil,nil,nil,nil,nil,nil,n and tonumber(id)+10 end
    f.libraries['AceGUI-3.0-ItemLoader'].itemList={[1]={name='Water',icon=11},[2]={name='Bread',icon=12}};a.bagContents={[1]={count=2,slots={{bag=0,slot=1}}}}
    local w=a:CreateItemEditBox('Inventory_EditBox',1);w:SetText(1);assert(w:GetText()=='Water');local id
    w:SetCallback('OnEnterPressed',function(_,_,value) id=value end);w:SetFocus();local row=w.rmSpellPopup.rows[1]
    assert(row.itemID==1 and row.icon.texture==11 and not w.rmSpellPopup.rows[2]:IsShown())
    row.scripts.OnMouseDown(row,'LeftButton');assert(id=='1' and w:GetText()=='Water')
end)
test('inventory references accept typed and cursor bag items without losing exact identity or cancel state',function()
    local f=fixture();local a=f.addon
    f.env.GetItemInfo=function(id) if id==1 then return 'Water',nil,nil,nil,nil,nil,nil,nil,nil,11 end end
    a.bagContents={[1]={count=2,slots={{bag=0,slot=1}}}}
    local w=a:CreateItemEditBox('Inventory_EditBox');local values={};w:SetText('')
    w:SetCallback('OnEnterPressed',function(_,_,value) values[#values+1]=value end)
    w:SetFocus();w.editbox:SetText('1');w.editbox.scripts.OnEnterPressed(w.editbox)
    assert(values[1]=='1' and w:GetText()=='Water','typed owned item was rejected')
    local clears=0;f.env.ClearCursor=function() clears=clears+1 end
    f.env.GetCursorInfo=function() return 'item',1,'item:1' end
    w:SetFocus();w.editbox.scripts.OnReceiveDrag(w.editbox);assert(values[2]=='1' and clears==1)
    f.env.GetCursorInfo=function() return 'item',2,'item:2' end
    w.editbox.scripts.OnReceiveDrag(w.editbox);assert(#values==2 and clears==1,'unowned item consumed the cursor')
    w:SetFocus();w.editbox:SetText('unfinished');w:ClearFocus();assert(w:GetText()=='Water' and #values==2)
end)
test('uncached item selection refreshes its label without committing a placeholder',function()
    local f=fixture();local ready=false;f.env.GetItemInfo=function(id) if ready then return 'Water' end end
    local w=f.addon:CreateItemEditBox('Item_EditBox',1);w:SetText(1);local calls=0;w:SetCallback('OnEnterPressed',function() calls=calls+1 end)
    assert(w:GetText()=='Item data loading');w:SetFocus();w:ClearFocus();ready=true;w:SetFocus();assert(w:GetText()=='Water' and calls==0)
end)
test('legacy display updates retain exact picker identity even for duplicate item names',function()
    local f=fixture();local a=f.addon
    f.env.C_Item={GetItemInfo=function(id) return 'Same name','item:'..id end,GetItemInfoInstant=function() return 2 end}
    local w=a:CreateItemEditBox('Item_EditBox',1);local chosen
    w:SetCallback('OnEnterPressed',function(_,_,value) chosen=value end)
    a:UpdateItem_Name_ID(1,w,nil);assert(w:GetText()=='Same name')
    w:SetFocus();w.editbox.scripts.OnEnterPressed(w.editbox)
    assert(chosen=='1','name presentation changed the selected identity to '..tostring(chosen))
end)
test('delayed legacy display cannot write into released or directly edited reference fields',function()
    for _,released in ipairs({true,false}) do
        local f=fixture();local a=f.addon;local ready=false;local queued
        f.env.C_Item={GetItemInfo=function() if ready then return 'Water' end end}
        a.ScheduleTimer=function(_,method,_,...) queued={method=method,args={...}} end
        local w=a:CreateItemEditBox('Item_EditBox',1)
        a:UpdateItem_Name_ID(1,w,nil);assert(queued)
        if released then w:OnRelease() end
        w:SetText('New owner');ready=true;a[queued.method](a,unpack(queued.args))
        assert(w:GetText()=='New owner','late metadata overwrote a released or edited field')
    end
end)
test('automatic picker metadata refresh does not cancel the matching icon retry',function()
    local f=fixture();local a=f.addon;local ready=false;local queued
    f.env.C_Item={GetItemInfo=function() if ready then return 'Water' end end}
    a.ScheduleTimer=function(_,method,_,...) queued={method=method,args={...}} end
    local w=a:CreateItemEditBox('Item_EditBox',1);local icon={SetText=function(self,value) self.value=value end}
    a:UpdateItem_Name_ID(1,w,icon);assert(queued and not icon.value)
    ready=true;w:SetFocus();assert(w:GetText()=='Water')
    a[queued.method](a,unpack(queued.args));assert(icon.value==1,'same-identity label refresh stranded the icon')
end)
test('choosing another duplicate-name item cancels the former identity retry',function()
    local f=fixture();local a=f.addon;local ready=false;local queued
    f.env.C_Item={GetItemInfo=function(id) return 'Same name',nil,nil,nil,nil,nil,nil,nil,nil,(ready or id==2) and 10+id or nil end}
    a.ScheduleTimer=function(_,method,_,...) queued={method=method,args={...}} end
    local w=a:CreateItemEditBox('Item_EditBox',1)
    local icon={SetImage=function(self,value) self.image=value end}
    a:UpdateItem_Name_Image(1,w,icon);assert(queued);ready=true;w:SetText(2)
    -- Both names are now loaded; the old request must not steal item2's ID.
    a[queued.method](a,unpack(queued.args));assert(w:GetReferenceID()==2,'retry restored a former same-name identity')
end)
finish()
