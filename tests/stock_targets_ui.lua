-- Actual native stock settings controls; inventory observations are outside this unit.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function row(item)return{itemID=item or 1710,minimum=5,target=12,enabled=true}end
local function deep()local v={};local n=v;for i=1,20000 do local c={};n.child=c;n=c end;return v end
local function fixture(plan)
 local f=F.new();local a,e=f.addon,f.env;local _,create=dofile('tests/fixtures/native_ui.lua')(e)
 local load=f.load;local inverse=dofile('tests/fixtures/restore_stock_targets_observation.lua')
 f.load=function(path)if path=='UI/settings_stock.lua' or path=='UI/settings_form.lua'then local h=assert(io.open(path));local text=h:read('*a');h:close();if path=='UI/settings_stock.lua'then text=dofile('tests/fixtures/restore_stock_readiness.lua')(text)end;local chunk=assert(loadstring(inverse(text,path),'@'..path));setfenv(chunk,e);return chunk('rotationmaster',a)end;return load(path)end
 a.pretty_name='Rotation Master';a.name='rotationmaster';a.configPaneGeneration=1
 for _,path in ipairs({'Platform/spells.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/rotation_store.lua','Core/rotation_library.lua','Core/rotation_scope.lua','Core/rotation_migration.lua','Help/itemsets.lua','Help/general.lua','UI/window.lua','UI/help.lua','UI/icon_picker.lua','UI/color_picker.lua','UI/settings_roster_order.lua','UI/settings_layout.lua','UI/settings_ordered.lua','UI/settings_draft.lua','UI/settings_history.lua','UI/settings_unsaved.lua','UI/settings_form.lua','UI/settings_transfer.lua','UI/collection_compare.lua','UI/settings_collections.lua','UI/settings_stock.lua','UI/settings_items.lua','UI/settings_general.lua'})do
  f.load(path)
 end

 local parent=create('Frame');parent:SetSize(1000,600);a.db.profile.itemsets={same={name='Set',items={1710}}};a.db.profile.stockTargets=plan;a.db.global.itemsets={};a.db.global.effects={};a.db.char={bindings={}}
 local scans=0;a.Platform.GetBagItemCounts=function()scans=scans+1;error('Unit2b must not scan')end
 local p=a:OpenNativeSettings(parent,'ItemSets');return f,a,p,parent,function()return scans end
end
local function source(p,i)local c=p.roster and p.roster.sourceButtons and p.roster.sourceButtons[i];assert(c and c:IsShown(),'stock source button absent');c:Click()end
local function input(p,key,text,flush)local c=assert(p.fields[key],key..' field absent');c:SetText(text);c.scripts.OnTextChanged(c,true);if flush then c.scripts.OnEnterPressed(c)end end
local function stock(p)source(p,2)end
test('existing itemset native controls remain unchanged before choosing stock',function()local _,a,p=fixture();assert(p.fields.name and p.fields.global and p.fields.binding and a.db.profile.stockTargets==nil)end)
test('stock opens empty without defaults scans or automatic creation',function()local _,a,p,_,scans=fixture();stock(p);assert(p.itemSettingsSource=='stock'and not p.creating and a.db.profile.stockTargets==nil and not p.fields.itemID and p.fields.new_collection and scans()==0)end)
test('stock keeps independent same-ID selection and shared unsaved itemset draft across source switches',function()
 local _,a,p=fixture({same=row()});input(p,'name','Changed',true);assert(p.draft.profile.itemsets.same.name=='Changed'and a.db.profile.itemsets.same.name=='Set');stock(p)
 assert(p.stockSelection=='same'and p.selection=='same'and p.fields.itemID and not p.fields.global and not p.fields.binding);source(p,1);assert(p.fields.name:GetText()=='Changed'and p.selection=='same');p.fields.cancel:Click();assert(a.db.profile.itemsets.same.name=='Set')
end)
test('stock existing row edits are detached with Undo Redo ViewChanges and Apply',function()
 local _,a,p=fixture({same=row()});stock(p);input(p,'target','15',true);assert(p.draft.profile.stockTargets.same.target==15 and a.db.profile.stockTargets.same.target==12);assert(p.fields.undo:IsEnabled());p.fields.undo:Click();assert(p.draft.profile.stockTargets.same.target==12);p.fields.redo:Click();assert(p.draft.profile.stockTargets.same.target==15)
 assert(p:UnsavedIdentity():find('stock',1,true));assert(p.fields.viewChanges and p.fields.viewChanges:IsEnabled());p.fields.viewChanges:Click();assert(p.draftComparisonOwner.comparison.frame:IsShown());p.fields.apply:Click();assert(a.db.profile.stockTargets.same.target==15)
end)
test('stock pair parsers reject invalid ranges and accept both pending fields atomically',function()
 local _,a,p=fixture({same=row()});stock(p);input(p,'minimum','20');assert(not p:FlushEdits()and p.draft.profile.stockTargets.same.minimum==5);input(p,'target','30');assert(p:FlushEdits());assert(p.draft.profile.stockTargets.same.minimum==20 and p.draft.profile.stockTargets.same.target==30 and a.db.profile.stockTargets.same.minimum==5)
 for _,text in ipairs({'-1','1000001','0.5','nan','inf'})do input(p,'target',text);assert(not p:FlushEdits()and p.draft.profile.stockTargets.same.target==30);p.fields.target.scripts.OnEscapePressed(p.fields.target)end
end)
test('invalid creation can reach source-switch Discard and Cancel rather than preflush trapping',function()
 local _,a,p=fixture();stock(p);p.fields.new_collection:Click();input(p,'itemID','bad');source(p,1);assert(p.prompt and p.prompt.frame:IsShown()and p.prompt.discard and p.prompt.discard:IsShown());p.prompt.cancel:Click();assert(p.itemSettingsSource=='stock'and p.fields.itemID:GetText()=='bad');source(p,1);p.prompt.discard:Click();assert(p.itemSettingsSource=='itemsets'and a.db.profile.stockTargets==nil)
end)
test('out-of-bag exact numeric item creation uses first Apply and duplicate IDs refuse',function()
 local _,a,p=fixture();a.uuid=function()return'new-stock'end;stock(p);p.fields.new_collection:Click();input(p,'itemID','999999',true);assert(p.newStockTarget.itemID==999999 and a.db.profile.stockTargets==nil);p.fields.apply:Click();assert(a.db.profile.stockTargets['new-stock'].itemID==999999 and not p.creating)
 p.fields.new_collection:Click();input(p,'itemID','999999');assert(not p:FlushEdits());assert(a.db.profile.stockTargets['new-stock'].itemID==999999)
end)
test('valid delete is draft-reversible instead of immediate saved deletion',function()
 local _,a,p=fixture({same=row()});stock(p);p.fields.delete:Click();assert(a.db.profile.stockTargets.same and not p.draft.profile.stockTargets.same);p.fields.undo:Click();assert(p.draft.profile.stockTargets.same.itemID==1710)
end)
test('invalid stock recovery cancels safely and confirms only same raw root without history recursion',function()
 local bad=deep();local _,a,p=fixture(bad);stock(p);assert(p.fields.stock_reset and not p.fields.itemID and a.db.profile.stockTargets==bad);p.fields.stock_reset:Click();p.prompt.cancel:Click();assert(a.db.profile.stockTargets==bad)
 p.fields.stock_reset:Click();local replacement=deep();a.db.profile.stockTargets=replacement;p.prompt.accept:Click();assert(a.db.profile.stockTargets==replacement);p:Draw();p.fields.stock_reset:Click();p.prompt.accept:Click();assert(a.db.profile.stockTargets==nil and p.stockEditable and not p.fields.stock_reset)
end)
test('valid-to-invalid external stock does not block unrelated ItemSet Apply or traverse malformed getters',function()
 local _,a,p=fixture({same=row()});local getters=0;local bad=setmetatable({},{__index=function()getters=getters+1;error('malformed saved stock getter')end});a.db.profile.stockTargets=bad;input(p,'name','Updated',true);p.fields.apply:Click()
 assert(a.db.profile.itemsets.same.name=='Updated'and a.db.profile.stockTargets==bad and getters==0,'untouched stock blocked unrelated Apply or ran getter')
end)
test('edited stock refuses invalid external replacement before saved comparison',function()
 local _,a,p=fixture({same=row()});stock(p);input(p,'target','15',true);local getters=0;local bad=setmetatable({},{__index=function()getters=getters+1;error('saved stock getter')end});a.db.profile.stockTargets=bad;p.fields.apply:Click();assert(a.db.profile.stockTargets==bad and getters==0 and p.draft.profile.stockTargets.same.target==15)
end)
test('Discard starts fresh scope before selected-key baseline copy after deep invalid replacement',function()
 local _,a,p=fixture({same=row()});input(p,'name','Changed',true);local bad=deep();a.db.profile.stockTargets=bad;p.fields.cancel:Click();assert(a.db.profile.stockTargets==bad and p.draft.profile.stockTargets==nil and not p.stockEditable and a.db.profile.itemsets.same.name=='Set')
end)
test('live item replacement keeps exact-ID fallback label and roster current without saving metadata',function()
 local _,a,p=fixture({same=row()});stock(p);input(p,'itemID','999999',true)
 assert(p.draft.profile.stockTargets.same.itemID==999999 and a.db.profile.stockTargets.same.itemID==1710)
 assert(p.fields.stock_item_id and p.fields.stock_item_id:GetText()=='Item ID: 999999'and p.roster.entries[1].text=='999999')
end)
test('disabled targets still reserve exact IDs and row limit blocks New at128',function()
 local disabled=row();disabled.enabled=false;local _,a,p=fixture({a=disabled});stock(p);p.fields.new_collection:Click();input(p,'itemID','1710');assert(not p:FlushEdits()and a.db.profile.stockTargets.a.enabled==false)
 local rows={};for i=1,128 do rows['r'..i]=row(1000+i)end;local _,a,p=fixture(rows);stock(p);assert(not p.fields.new_collection:IsEnabled());p.fields.new_collection:Click();assert(not p.creating and #p.roster.entries==128)
end)
test('pending invalid existing row blocks ordinary source departure without silently saving',function()
 local _,a,p=fixture({same=row()});stock(p);input(p,'minimum','20');source(p,1);assert(p.itemSettingsSource=='stock'and p.fields.minimum:GetText()=='20'and a.db.profile.stockTargets.same.minimum==5)
end)
test('dirty itemset can switch through invalid-stock recovery ViewChanges and Apply without owning external stock',function()
 local _,a,p=fixture({same=row()});input(p,'name','Changed',true);local bad=deep();a.db.profile.stockTargets=bad;stock(p);assert(p.fields.stock_reset and p.fields.viewChanges:IsEnabled());p.fields.viewChanges:Click();assert(p.draftComparisonOwner.comparison.frame:IsShown());p.fields.apply:Click();assert(a.db.profile.itemsets.same.name=='Changed'and a.db.profile.stockTargets==bad)
end)
test('invalid recovery resolves existing itemset draft explicitly before clearing only stock',function()
 local bad=deep();local _,a,p=fixture(bad);input(p,'name','Changed',true);stock(p);p.fields.stock_reset:Click();assert(p.prompt.discard and p.prompt.discard:IsShown());p.prompt.accept:Click();assert(p.prompt.frame:IsShown());p.prompt.accept:Click();assert(a.db.profile.stockTargets==nil and a.db.profile.itemsets.same.name=='Changed')
end)
test('stale pooled stock callbacks and profile replacement cannot edit a new owner',function()
 local _,a,p,parent=fixture({same=row()});stock(p);local stale=p.fields.enabled.scripts.OnClick;local old=a.db.profile;p:Release();stale();assert(old.stockTargets.same.enabled)
 a.db.profile={itemsets={new={name='New',items={}}},stockTargets={other=row(999999)}};a:OpenNativeSettings(parent,'ItemSets',p);stale();assert(p.itemSettingsSource=='itemsets'and p.stockSelection==nil and a.db.profile.stockTargets.other.enabled and old.stockTargets.same.enabled)
end)
test('native Item_EditBox drag accepts exact unavailable IDs and rejects disabled duplicate IDs',function()
 local disabled=row();disabled.enabled=false;local f,a,p=fixture({same=disabled,other=row(7654)});stock(p);p.stockSelection='other';p:Draw();local clears=0;f.env.ClearCursor=function()clears=clears+1 end
 f.env.GetCursorInfo=function()return'item',1710 end;p.fields.itemID.scripts.OnReceiveDrag(p.fields.itemID);assert(p.draft.profile.stockTargets.other.itemID==7654 and clears==0)
 f.env.GetCursorInfo=function()return'item',999999 end;p.fields.itemID.scripts.OnReceiveDrag(p.fields.itemID);assert(p.draft.profile.stockTargets.other.itemID==999999 and clears==1 and a.db.profile.stockTargets.other.itemID==7654)
end)
test('itemset Delete confirmation omits unrelated stock keys even when live stock is replaced',function()
 for _,kind in ipairs({'getter','valid'})do
  local _,a,p=fixture({same=row()});p.fields.delete:Click();assert(p.prompt.frame:IsShown());local reads=0
  local replacement=kind=='getter'and setmetatable({},{__index=function()reads=reads+1;error('external stock getter reached Delete equality')end})or {external=row(999999)}
  a.db.profile.stockTargets=replacement;p.prompt.accept:Click()
  assert(not a.db.profile.itemsets.same and rawequal(a.db.profile.stockTargets,replacement)and reads==0,'unrelated stock replacement blocked itemset Delete')
 end
end)
test('confirmed itemset Delete still rejects original itemset map conflicts',function()
 local _,a,p=fixture({same=row()});p.fields.delete:Click();a.db.global.itemsets.external={name='External',items={7654}};p.prompt.accept:Click();assert(a.db.profile.itemsets.same and a.db.global.itemsets.external)
end)
test('invalid-stock recovery uses raw root identity rather than shared __eq authority',function()
 local equalCalls=0;local mt={__eq=function()equalCalls=equalCalls+1;return true end};local original=setmetatable({},mt)
 local _,a,p=fixture(original);stock(p);p.fields.stock_reset:Click();local replacement=setmetatable({},mt);a.db.profile.stockTargets=replacement;p.prompt.accept:Click()
 assert(rawequal(a.db.profile.stockTargets,replacement)and equalCalls==0,'stock root swap spoofed unchanged identity through __eq')
 p:Draw();p.fields.stock_reset:Click();p.prompt.accept:Click();assert(a.db.profile.stockTargets==nil and equalCalls==0)
end)
test('strict complete-module editor inverse rejects unrelated changes and composes before stock safety inverse',function()
 local inverse=dofile('tests/fixtures/restore_stock_targets_ui.lua');local safety=dofile('tests/fixtures/restore_stock_targets_safety_ui.lua')
 for _,path in ipairs({'UI/settings_items.lua','UI/settings_layout.lua','UI/settings_draft.lua','UI/settings_history.lua','UI/settings_unsaved.lua','UI/settings_collections.lua'})do
  local f=assert(io.open(path));local source=f:read('*a');f:close();if path=='UI/settings_items.lua' or path=='UI/settings_draft.lua' or path=='UI/settings_collections.lua' then source=dofile('tests/fixtures/restore_revision_changes.lua')(source,path) end;local restored=inverse(source,path);assert(restored~=source)
  assert(not pcall(inverse,source..'\n-- unrelated',path))
  if path=='UI/settings_draft.lua'or path=='UI/settings_collections.lua'then assert(safety(restored,path))end
 end
end)
test('stock navigation state cannot alter an unrelated native General page field identity',function()
 local _,a,_,parent=fixture({same=row()});local q=a:OpenNativeSettings(parent,'General');assert(q.fields.poll)
 q.itemSettingsSource='stock';q.stockSelection='first';local identity=q:UnsavedIdentity();q.stockSelection='second';assert(q:UnsavedIdentity()==identity,'stock selection leaked into General field identity')
end)
finish()
