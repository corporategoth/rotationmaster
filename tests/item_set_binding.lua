-- Item-set binding: drag or click Bind puts the set's first item on the
-- cursor; placing it binds the slot. Placing an item onto a slot that already
-- holds that item is a client no-op with no slot-change event, so button post
-- hooks also complete the bind. A swap leaves the user's previous action on
-- the cursor, which nothing may clear or overwrite.
local function read(path) local h=assert(io.open(path));local text=h:read('*a');h:close();return text end
local prefix=assert(read('tests/startup.lua'):match('^(.-)\ntest%('))
local fixture,initialize=assert(loadstring(prefix..'\nreturn fixture,initialize','@item-set-binding-startup-fixture'))()
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()

-- A client model: action slots, a cursor, PlaceAction swapping like the
-- client (an identical item is a no-op that consumes the cursor item), and
-- action buttons whose post hooks the binding observes.
local function world()
    local env,a,load=fixture();load('main.lua');initialize(a);load('UI/item_set_binding.lua')
    a.debug=function() end;a.ButtonFetch=function() end;a.db.char.bindings={}
    local w={actions={},cursor=nil,events={},timers={},buttons={}}
    env.GetActionInfo=function(slot) local v=w.actions[slot];if v then return v.kind,v.id end end
    env.GetCursorInfo=function() if w.cursor then return w.cursor.kind,w.cursor.id end end
    env.PickupItem=function(id) w.cursor={kind='item',id=id} end
    env.ClearCursor=function() w.cursor=nil end
    env.C_Timer={After=function(delay,fn) w.timers[#w.timers+1]=fn end}
    env.PlaceAction=function(slot)
        local held,old=w.cursor,w.actions[slot]
        if held and old and held.kind==old.kind and held.id==old.id then w.cursor=nil;return end
        w.actions[slot]=held;w.cursor=old
        w.events[#w.events+1]=slot;a:ACTIONBAR_SLOT_CHANGED('ACTIONBAR_SLOT_CHANGED',slot)
    end
    env.InCombatLockdown=function() return false end
    a.FindItemInItemSet=function(_,id,item) return id=='mana' and (item==11 or item==12) and 1 or nil end
    a.FindFirstItemOfItemSet=function(_,_,id) return id=='mana' and 11 or nil end
    -- Indexed action buttons: hooks run after the bar's own handler.
    local function button(slot)
        local b={slot=slot,hooks={}}
        function b:HasScript() return true end
        function b:HookScript(event,fn) self.hooks[event]=self.hooks[event] or {};table.insert(self.hooks[event],fn) end
        function b:Drop() env.PlaceAction(self.slot);for _,fn in ipairs(self.hooks.OnReceiveDrag or {}) do fn(self) end end
        function b:ClickWithCursor() if not w.actions[self.slot] then env.PlaceAction(self.slot) elseif w.cursor and w.cursor.kind==w.actions[self.slot].kind and w.cursor.id==w.actions[self.slot].id then w.cursor=nil end;for _,fn in ipairs(self.hooks.PostClick or {}) do fn(self) end end
        w.buttons[slot]=b;return b
    end
    for slot=1,4 do button(slot) end
    a.ForEachActionButton=function(_,fn) for slot,b in pairs(w.buttons) do fn(b,slot) end end
    a.ResolveActionButtonSlot=function(_,b) return b.slot end
    return env,a,w
end
local function count(list,value) local n=0;for _,v in ipairs(list or {}) do if v==value then n=n+1 end end;return n end

test('starting a bind picks up the first item and remembers the set',function()
    local _,a,w=world()
    assert(a:BeginItemSetBind('mana',11) and a.bindingItemSet=='mana' and w.cursor.id==11,'bind did not pick up the first item')
    local ok,why=a:BeginItemSetBind('mana',nil);assert(not ok and why=='unavailable')
end)

test('a drop on an occupied slot binds it and leaves the old action on the cursor',function()
    local _,a,w=world();w.actions[2]={kind='spell',id=403}
    a:BeginItemSetBind('mana',11);w.buttons[2]:Drop()
    assert(count(a.db.char.bindings.mana,2)==1,'occupied slot was not bound')
    assert(w.cursor and w.cursor.kind=='spell' and w.cursor.id==403,'the replaced action is not on the cursor')
    assert(a.bindingItemSet==nil,'pending bind outlived the drop')
end)

test('a drop or click on a slot already holding the same item binds without a slot event',function()
    for _,how in ipairs({'Drop','ClickWithCursor'}) do
        local _,a,w=world();w.actions[3]={kind='item',id=11}
        a:BeginItemSetBind('mana',11);w.buttons[3][how](w.buttons[3])
        assert(#w.events==0,'the model fired a slot event for a no-op placement')
        assert(count(a.db.char.bindings.mana,3)==1 and a.bindingItemSet==nil,how..' onto the same item did not bind')
    end
end)

test('a drop onto a different member of the set binds once with no duplicate entry',function()
    local _,a,w=world();w.actions[1]={kind='item',id=12}
    a:BeginItemSetBind('mana',11);w.buttons[1]:Drop()
    assert(count(a.db.char.bindings.mana,1)==1,'slot recorded twice or not at all')
    a:ACTIONBAR_SLOT_CHANGED('ACTIONBAR_SLOT_CHANGED',1);assert(count(a.db.char.bindings.mana,1)==1,'a later slot event duplicated the binding')
end)

test('a drop of an unrelated item takes the normal swap path and binds nothing',function()
    local _,a,w=world();w.actions[4]={kind='item',id=99}
    a.bindingItemSet=nil;w.cursor={kind='item',id=55};w.buttons[4]:Drop()
    assert(a.db.char.bindings.mana==nil and w.actions[4].id==55 and w.cursor.id==99,'unrelated swap was disturbed')
end)

test('a stale pending bind is cleared once its item leaves the cursor',function()
    local env,a,w=world();local frames={}
    local create=env.CreateFrame;env.CreateFrame=function(...) local f={scripts={}};function f:SetScript(e,fn) self.scripts[e]=fn end;frames[#frames+1]=f;return f end
    a:BeginItemSetBind('mana',11);local watcher=frames[#frames];assert(watcher and watcher.scripts.OnUpdate,'no cursor watcher')
    watcher.scripts.OnUpdate(watcher);assert(a.bindingItemSet=='mana','pending cleared while its item is on the cursor')
    w.cursor=nil;watcher.scripts.OnUpdate(watcher);assert(a.bindingItemSet=='mana','pending cleared before the grace frame')
    watcher.scripts.OnUpdate(watcher);assert(a.bindingItemSet==nil,'stale pending survived an empty cursor')
    w.actions[2]={kind='item',id=11};a:ACTIONBAR_SLOT_CHANGED('ACTIONBAR_SLOT_CHANGED',2);assert(a.db.char.bindings.mana==nil,'an unrelated later slot change bound the set')
    env.CreateFrame=create
end)

test('refreshing a bound slot never overwrites or clears what the cursor holds',function()
    local _,a,w=world();a.db.char.bindings.mana={1};w.actions[1]={kind='item',id=12}
    w.cursor={kind='spell',id=403};assert(a:UpdateBoundButton('mana')==false,'refresh ran with a held cursor')
    assert(w.cursor.kind=='spell' and w.cursor.id==403 and w.actions[1].id==12,'held cursor was destroyed')
    w.cursor=nil;for _,fn in ipairs(w.timers) do fn() end;assert(w.actions[1].id==11 and w.cursor==nil,'deferred refresh did not run once the cursor emptied')
end)

test('clearing a binding cursor leaves a swapped-out action alone',function()
    local _,a,w=world()
    w.cursor={kind='spell',id=403};assert(not a:ClearItemSetBindCursor('mana') and w.cursor.id==403,'a non-binding cursor was cleared')
    w.cursor={kind='item',id=11};assert(a:ClearItemSetBindCursor('mana') and w.cursor==nil)
end)

local make=dofile('tests/fixtures/rotation_data.lua')
local function settingsFixture()
    local f=F.new();local a=f.addon;local frames,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    a.pretty_name='Rotation Master';a.name='rotationmaster';a.configPaneGeneration=1;a.RotationData=make()
    for _,path in ipairs({'Platform/spells.lua','Data/catalog.lua','Data/rotation_store.lua','Core/rotation_library.lua','Core/rotation_scope.lua','Core/rotation_migration.lua','Help/general.lua','Help/conditions.lua','Help/effects.lua','Help/itemsets.lua','Help/announce.lua','UI/window.lua','UI/help.lua','UI/icon_picker.lua','UI/color_picker.lua','UI/settings_roster_order.lua','UI/settings_layout.lua','UI/settings_ordered.lua','UI/settings_draft.lua','UI/settings_history.lua','UI/settings_unsaved.lua','UI/settings_form.lua','UI/settings_transfer.lua','UI/cpu_profile.lua','UI/settings_general.lua','UI/settings_profiles.lua','UI/collection_compare.lua','UI/settings_collections.lua','UI/settings_announces.lua','UI/settings_effects.lua','UI/settings_items.lua','UI/settings_conditions.lua'}) do local h=io.open(path);if h then h:close();f.load(path) end end
    return f,frames,create
end
test('Item Sets: dragging a set row or the Bind pill starts a bind; page cleanup keeps a swapped-out cursor',function()
    local f,frames,create=settingsFixture();local a=f.addon;f.load('UI/item_set_binding.lua');local env=f.env
    local cursor;env.GetCursorInfo=function() if cursor then return cursor.kind,cursor.id end end;env.PickupItem=function(id) cursor={kind='item',id=id} end;env.ClearCursor=function() cursor=nil end
    env.InCombatLockdown=function() return false end
    a.db.char={bindings={}};a.db.global.itemsets={mana={name='Mana',items={11,12}},heal={name='Heal',items={21}}};a.db.profile.itemsets={}
    a.FindFirstItemOfItemSet=function(_,_,id) return ({mana=11,heal=21})[id] end;a.FindItemInItemSet=function(_,id,item) return (id=='mana' and (item==11 or item==12) or id=='heal' and item==21) and 1 or nil end
    local parent=create('Frame');parent:SetSize(1000,600);local p=a:OpenNativeSettings(parent,'ItemSets')
    local pill=p.fields.bind;assert(pill.tooltip and pill.tooltip:find('Drag onto any action bar slot',1,true),'Bind does not explain dragging')
    pill.scripts.OnDragStart(pill);assert(a.bindingItemSet==p.selection and cursor and cursor.kind=='item','dragging Bind did not start a bind')
    cursor=nil;a.bindingItemSet=nil
    local row;for _,r in ipairs(p.roster.rows) do if r.rosterLease and r.rosterEntry.value=='heal' then row=r end end
    assert(row and row.scripts.OnDragStart,'set rows cannot be dragged');row.scripts.OnDragStart(row);assert(a.bindingItemSet=='heal' and cursor.id==21,'dragging a set row did not start its bind')
    -- After a swap the cursor holds the user's previous action: cleanup keeps it.
    cursor={kind='spell',id=403};p:Release();assert(cursor and cursor.id==403,'page cleanup cleared a swapped-out action')
end)
test('Item Sets: a set row drag binds through the client event order and never reorders',function()
    -- OnMouseDown, OnDragStart (the set's item on the cursor), release over an
    -- action button: the bar places it, then OnReceiveDrag runs our hook.
    local f,frames,create=settingsFixture();local a=f.addon;f.load('UI/item_set_binding.lua');local env=f.env
    local cursor,actions=nil,{};env.GetCursorInfo=function() if cursor then return cursor.kind,cursor.id end end;env.PickupItem=function(id) cursor={kind='item',id=id} end;env.ClearCursor=function() cursor=nil end
    env.InCombatLockdown=function() return false end;env.GetActionInfo=function(slot) local v=actions[slot];if v then return v.kind,v.id end end
    local button={slot=3,hooks={}};function button:HasScript() return true end;function button:HookScript(event,fn) self.hooks[event]=self.hooks[event] or {};table.insert(self.hooks[event],fn) end
    function button:Drop() local held,old=cursor,actions[self.slot];actions[self.slot]=held;cursor=old;for _,fn in ipairs(self.hooks.OnReceiveDrag or {}) do fn(self) end end
    a.ForEachActionButton=function(_,fn) fn(button,button.slot) end;a.ResolveActionButtonSlot=function(_,b) return b.slot end
    a.db.char={bindings={}};a.db.global.itemsets={mana={name='Mana',items={11,12}},heal={name='Heal',items={21}}};a.db.profile.itemsets={}
    a.FindFirstItemOfItemSet=function(_,_,id) return ({mana=11,heal=21})[id] end;a.FindItemInItemSet=function(_,id,item) return (id=='mana' and (item==11 or item==12) or id=='heal' and item==21) and 1 or nil end
    local parent=create('Frame');parent:SetSize(1000,600);local p=a:OpenNativeSettings(parent,'ItemSets')
    local row;for _,r in ipairs(p.roster.rows) do if r.rosterLease and r.rosterEntry.value=='heal' then row=r end end
    local before={};for i,v in ipairs(p.roster.options.order or {}) do before[i]=v end
    if row.scripts.OnMouseDown then row.scripts.OnMouseDown(row,'LeftButton') end
    assert(a.bindingItemSet==nil and cursor==nil,'pressing a set row started a bind before the drag')
    row.scripts.OnDragStart(row);assert(a.bindingItemSet=='heal' and cursor and cursor.id==21,'the drag did not put the set item on the cursor')
    assert(not (p.roster.orderView and p.roster.orderView.drag),'a set row drag started a list reorder')
    button:Drop();assert(actions[3] and actions[3].id==21 and cursor==nil,'the bar did not take the item')
    assert(count(a.db.char.bindings.heal,3)==1 and a.bindingItemSet==nil,'OnReceiveDrag did not complete the bind')
    if row.scripts.OnDragStop then row.scripts.OnDragStop(row) end
    for i,v in ipairs(p.roster.options.order or {}) do assert(before[i]==v,'the set list was reordered') end
end)
finish()
