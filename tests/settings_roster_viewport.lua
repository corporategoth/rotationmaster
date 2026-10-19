local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(n,ordered)
    local f=F.new();local a=f.addon;local frames=dofile('tests/fixtures/native_ui.lua')(f.env)
    for _,path in ipairs({'UI/settings_roster_order.lua','UI/settings_layout.lua','UI/settings_unsaved.lua','UI/settings_form.lua'}) do f.load(path) end
    local host=f.env.CreateFrame('Frame');host:SetSize(1000,600);local p=a:CreateSettingsForm(host);local entries,items={},{}
    for i=1,n do local id='id'..i;entries[i]={value=id,text=(i%5==0 and 'Keep ' or 'Entry ')..i};items[i]=id end
    local amount=1;local chosen
    local function draw(form)
        form:UseRoster(entries,chosen or 'id1',function(id) chosen=id end,ordered and {order=items} or {})
        form:Edit('amount','Amount',amount,tonumber,function(value) amount=value end)
    end
    p:Open(draw)
    return f,p,entries,items,frames,function() return chosen,amount end
end
local function rowFor(p,id)
    for _,row in ipairs(p.roster.rows) do if row.rosterLease and row.rosterEntry.value==id then return row end end
end
test('complete settings rosters reach4096 entries with bounded rows and zero warm-scroll allocations',function()
    local f,p,entries,items,frames,selected=fixture(4096,false);local r=p.roster
    local budget=math.ceil((r.scroll:GetHeight()+204)/34)+2
    assert(#r.matches==4096 and #r.rows<=budget,'roster allocated offscreen result controls')
    local stale=assert(rowFor(p,'id1')).scripts.OnClick
    local passes=0;local refresh=p.RefreshRoster;p.RefreshRoster=function(...) passes=passes+1;return refresh(...) end
    for i=0,10 do r.scroll.workbenchBar:SetValue(r.scroll.workbenchBar.scrollRange*i/10) end
    local objects,rows=#frames,#r.rows
    for pass=1,2 do for i=10,0,-1 do r.scroll.workbenchBar:SetValue(r.scroll.workbenchBar.scrollRange*i/10) end end
    assert(#r.rows==rows and #frames==objects and passes==0,'warm scroll rebuilt filtering or allocated controls')
    r.scroll.workbenchBar:SetValue(r.scroll.workbenchBar.scrollRange);local last=assert(rowFor(p,'id4096'));stale();assert(not selected(),'retired callback selected its old node')
    last:Click();assert(selected()=='id4096');local clicked=last.scripts.OnClick;p:Release();clicked();assert(selected()=='id4096')
end)
test('ordered roster indexing is linear and scroll performs zero full-order identity scans',function()
    local counts={}
    for _,n in ipairs({100,200,1000}) do
        local calls=0;debug.sethook(function(event) if event=='call' then local info=debug.getinfo(2,'S');if info.source=='@UI/settings_roster_order.lua' and info.linedefined==3 then calls=calls+1 end end end,'c')
        local f,p=fixture(n,true);debug.sethook();counts[#counts+1]=calls
        assert(calls<=n*4,'ordered roster still scans full order once per entry')
        local r=p.roster;local count=calls;debug.sethook(function(event) if event=='call' then local info=debug.getinfo(2,'S');if info.source=='@UI/settings_roster_order.lua' and info.linedefined==3 then calls=calls+1 end end end,'c')
        for i=0,10 do r.scroll.workbenchBar:SetValue(r.scroll.workbenchBar.scrollRange*i/10) end;debug.sethook()
        assert(calls==count and #r.rows<32 and #r.orderZones<32,'scroll scanned full ordering or leased all logical gaps');p:Release()
    end
    assert(counts[3]<=counts[1]*12)
end)
test('roster scroll preserves pending detail and search focus and recycled handlers cannot leave it',function()
    local f,p,entries,items,frames,selected=fixture(1000,true);local r=p.roster;local first=assert(rowFor(p,'id1'));local stale=first.down.scripts.OnClick
    local input=p.fields.amount;input:SetText('invalid');input.scripts.OnTextChanged(input,true);input:SetFocus();input:SetCursorPosition(2)
    r.scroll.workbenchBar:SetValue(r.scroll.workbenchBar.scrollRange);assert(input:GetText()=='invalid' and input:HasFocus() and input:GetCursorPosition()==2)
    rowFor(p,'id1000'):Click();assert(not selected() and input:GetText()=='invalid')
    stale();assert(items[1]=='id1');r.search:SetFocus();r.search:SetText('Keep');r.search.scripts.OnTextChanged(r.search,true)
    assert(r.search:HasFocus() and #r.matches==200 and input:GetText()=='invalid')
    p:Release();assert(not r.orderGhost:IsShown() and not r.search:HasFocus())
end)
test('offscreen roster dirty and moved markers follow bound IDs rather than pool positions',function()
    local f,p,entries,items=fixture(1000,true);local a=f.addon;local groups={}
    for i=1,1000 do groups[i]={id=items[i],name=entries[i].text,conditions={}} end
    p.settingsKey='Conditions';p.mode='categories';p.categorySelection='id1000';p.draftBaseline={profile={condition_groups=groups},global={}}
    p.draft={profile={condition_groups=a:CopySettingsData(groups)},global={}};p.draft.profile.condition_groups[1000].name='Changed'
    p:RefreshUnsaved();local r=p.roster;r.scroll.workbenchBar:SetValue(r.scroll.workbenchBar.scrollRange)
    assert(rowFor(p,'id1000').rmUnsaved,'newly leased offscreen dirty entry lacks its own marker')
    local other=rowFor(p,'id999');assert(not other.rmUnsaved,'pooled row inherited a different entry marker')
    local last=table.remove(p.draft.profile.condition_groups);table.insert(p.draft.profile.condition_groups,1,last);p:RefreshUnsaved()
    assert(other.rmUnsaved,'changed original ordering was not marked by ID')
    r.scroll.workbenchBar:SetValue(0);assert(rowFor(p,'id1').rmUnsaved,'newly leased moved row lacks its indexed marker');p:Release()
end)
test('large roster drag pins live sources and recycles gap leases before reaching the final destination',function()
    local f,p,entries,items=fixture(1000,true);local r=p.roster;local source=assert(rowFor(p,'id5'));local originalParent=source:GetParent();local view=r.orderView
    view:Begin('id5','Entry5',false);assert(source:GetParent()==view.ghost and view.ghost.liveEntries[1].frame==source)
    local stale=r.orderZones[1].scripts.OnReceiveDrag;r.scroll.workbenchBar:SetValue(r.scroll.workbenchBar.scrollRange)
    assert(source:GetParent()==view.ghost and source.rosterEntry.value=='id5' and rowFor(p,'id1000'),'drag scroll retired its source or omitted the destination')
    stale();assert(view.drag=='id5' and items[1]=='id1','recycled gap callback applied an old drop')
    local final;for _,zone in ipairs(r.orderZones) do if zone.gap==1001 and zone:IsShown() then final=zone end end
    assert(final and view:Drop(final.gap) and items[1000]=='id5' and #items==1000)
    assert(source:GetParent()==originalParent and not view.ghost:IsShown());p:Release()
end)
test('filtered Ctrl drag carries full logical suffixes and single arrows ignore Ctrl',function()
    local f,p,entries,items=fixture(1000,true);local r=p.roster;r.search:SetText('Keep');r.search.scripts.OnTextChanged(r.search,true);r.scroll.workbenchBar:SetValue(r.scroll.workbenchBar.scrollRange)
    f.env.IsControlKeyDown=function() return true end;local view=r.orderView;view:Begin('id995','Keep995')
    assert(view.tail and view.ghost.count:GetText()=='6 cards','filtered suffix ghost omitted hidden siblings')
    r.scroll.workbenchBar:SetValue(0);assert(view:Drop(1))
    for i=1,6 do assert(items[i]=='id'..(994+i),'hidden suffix order changed') end
    r.search:SetText('');r.search.scripts.OnTextChanged(r.search,true);local position=r.matchIndex.id996;r.scroll.workbenchBar:SetValue((position-1)*34)
    rowFor(p,'id996').up:Click();assert(items[1]=='id996' and items[2]=='id995' and items[3]=='id997','manual arrow carried the full Ctrl suffix')
    p:Release()
end)
test('filter revisions and profile replacement retire drag and row callbacks without losing another ghost',function()
    local f,p,entries,items,frames,selected=fixture(1000,true);local r=p.roster;local row=rowFor(p,'id5');local oldClick=row.scripts.OnClick;local oldDrag=row.scripts.OnDragStart
    local old=r.orderView;old:Begin('id5','Entry5',false);r.search:SetText('Keep');r.search.scripts.OnTextChanged(r.search,true);assert(not old.ghost:IsShown() and not old:Drop(1))
    local current=r.orderView;current:Begin('id10','Keep10',false);old:Cancel();assert(current.ghost:IsShown(),'retired view canceled a new ghost')
    oldClick();oldDrag();assert(not selected() and current.drag=='id10')
    f.addon.db.profile={};local click=rowFor(p,'id10').scripts.OnClick;click();assert(not selected() and not current:Drop(1) and items[1]=='id1')
    p:Release();assert(not current.ghost:IsShown());for _,control in ipairs(r.rows) do assert(not control.rosterLease) end
end)
test('a failed roster binding retires its partial lease and later viewport refresh recovers',function()
    local f,p,entries,items,frames,selected=fixture(1000,false);local r=p.roster;local stale=rowFor(p,'id1').scripts.OnClick
    local align=f.addon.AlignWorkbenchTextLeft;local failed=false;f.addon.AlignWorkbenchTextLeft=function(...) if not failed then failed=true;error('injected roster binding failure') end;return align(...) end
    local ok=pcall(r.scroll.workbenchBar.SetValue,r.scroll.workbenchBar,r.scroll.workbenchBar.scrollRange);assert(not ok and failed and not r.refreshing)
    for _,row in ipairs(r.rows) do assert(not row.rosterLease,'failed binding retained a partial row lease') end
    f.addon.AlignWorkbenchTextLeft=align;p:RefreshRosterViewport();assert(rowFor(p,'id1000'));stale();assert(not selected());p:Release()
end)
test('drag scrolling shows newly encountered logical suffix entries as bounded passive placeholders',function()
    local f,p,entries,items=fixture(1000,true);local r=p.roster;local view=r.orderView;local initial=#r.rows
    view:Begin('id5','Entry5',true)
    for i=1,10 do r.scroll.workbenchBar:SetValue(r.scroll.workbenchBar.scrollRange*i/10) end
    assert(not rowFor(p,'id1000'),'drag scrolling repopulated a moving suffix as ordinary controls')
    assert(#r.rows==initial and r.dragPlaceholders and #r.dragPlaceholders<32,'drag scrolling grew the carried control pool')
    local final;for _,placeholder in ipairs(r.dragPlaceholders) do if placeholder:IsShown() and placeholder.rosterPlaceholderIndex==1000 then final=placeholder end end
    assert(final and not final.mouseEnabled,'new suffix position has no passive placeholder')
    view:Cancel();assert(rowFor(p,'id1000') and not final:IsShown(),'cancel failed to replace passive placeholders with editable rows')
    for _,row in ipairs(r.rows) do assert(row:GetParent()==r.child) end;p:Release()
end)
test('retired outer drag scripts cannot mutate a recycled row flag or suppress its legitimate click',function()
    local f,p,entries,items,frames,selected=fixture(1000,true);local r=p.roster;local row=rowFor(p,'id1')
    local click,down,start,stop=row.scripts.OnClick,row.scripts.OnMouseDown,row.scripts.OnDragStart,row.scripts.OnDragStop
    r.scroll.workbenchBar:SetValue(r.scroll.workbenchBar.scrollRange);local id=row.rosterEntry.value;assert(id~='id1')
    row.rmDragged=false;start(row);assert(not row.rmDragged,'retired outer drag-start marked a new row as dragged')
    row.rmDragged=true;down(row,'LeftButton');assert(row.rmDragged,'retired mouse-down cleared the new row drag flag')
    click(row);assert(row.rmDragged,'retired click cleared the new row drag suppression')
    row.rmDragged=false;local other=r.matches[row.rosterIndex+1].value;local view=r.orderView;view:Begin(other,'Other',false);stop(row);assert(view.drag==other and view.ghost:IsShown(),'retired drag-stop canceled a new drag')
    view:Cancel();row:Click();assert(selected()==id,'retired drag callback suppressed the legitimate new row click');p:Release()
end)
test('retained roster labels remeasure on resize while invalid detail text keeps its focus and lease',function()
    local f,p=fixture(1000,true);local row=rowFor(p,'id1');local lease=row.rosterLease;local click=row.scripts.OnClick;local input=p.fields.amount
    input:SetText('bad');input.scripts.OnTextChanged(input,true);input:SetFocus();input:SetCursorPosition(2);local oldWidth=row:GetWidth();p:SetWidth(700)
    assert(row:GetWidth()<oldWidth and row:GetFontString():GetWidth()==row:GetWidth()-10,'retained roster label kept its old width after a narrower resize')
    assert(row.rosterLease==lease and row.scripts.OnClick==click and p.fields.amount==input,'resize rebound retained controls or callbacks')
    assert(input:GetText()=='bad' and input:HasFocus() and input:GetCursorPosition()==2,'resize lost invalid raw text or caret');p:Release()
end)
finish()
