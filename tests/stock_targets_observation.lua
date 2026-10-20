-- Actual native stock observation/report controls, inventory adapter and AceTimer.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function row(id)return{itemID=id or 1710,minimum=5,target=12,enabled=true}end
local function fixture(plan,legacy)
 local f=F.new();local a,e=f.addon,f.env;local frames,create=dofile('tests/fixtures/native_ui.lua')(e)
 local rawCreate=e.CreateFrame
 e.CreateFrame=function(...)
  local c=rawCreate(...);c.events={}
  function c:RegisterEvent(event)self.events[event]=true end
  function c:UnregisterAllEvents()self.events={}end
  function c:IsVisible()local x=self;while x do if not x:IsShown()then return false end;x=x:GetParent()end;return true end
  return c
 end
 local queue,schedules,cancels={},0,0
 e.C_Timer={After=function(delay,callback)schedules=schedules+1;assert(delay==.01,'real AceTimer minimum not used');queue[#queue+1]=callback end}
 local libenv=setmetatable({LibStub={minor=0,libs={},minors={}}},{__index=e});libenv._G=libenv
 local function library(path)local fn=assert(loadfile(path));setfenv(fn,libenv);fn()end
 library('Libs/LibStub/LibStub.lua');library('Libs/AceTimer-3.0/AceTimer-3.0.lua');local timer=libenv.LibStub('AceTimer-3.0');timer:Embed(a)
 local cancel=a.CancelTimer;a.CancelTimer=function(self,handle)cancels=cancels+1;return cancel(self,handle)end
 local bags={count=4};local native={};local query=function(key)native[#native+1]=key end
 e.NUM_TOTAL_EQUIPPED_BAG_SLOTS=0
 local function slots(bag)query('slots:'..bag);return 1 end
 local function info(bag,slot)query('item:'..bag..':'..slot);if bags.fail then error('PRIVATE_PROVIDER_ERROR')end;if bags.empty then return end;if legacy then return 12,bags.count,false,1,false,false,'item:1710',false,false,1710 end;return{itemID=1710,stackCount=bags.count}end
 if legacy then e.GetContainerNumSlots=slots;e.GetContainerItemInfo=info else e.C_Container={GetContainerNumSlots=slots,GetContainerItemInfo=info}end
 f.load('Platform/inventory.lua');local original=a.Platform.GetBagItemCounts;local scans=0
 a.Platform.GetBagItemCounts=function(self,...)assert(self==a.Platform and select('#',...)==0);scans=scans+1;return original(self,...)end
 a.pretty_name='Rotation Master';a.name='rotationmaster';a.configPaneGeneration=1
 for _,path in ipairs({'Platform/spells.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/rotation_store.lua','Core/rotation_library.lua','Core/rotation_scope.lua','Core/rotation_migration.lua','Help/itemsets.lua','UI/window.lua','UI/help.lua','UI/icon_picker.lua','UI/color_picker.lua','UI/settings_roster_order.lua','UI/settings_layout.lua','UI/settings_ordered.lua','UI/settings_draft.lua','UI/settings_history.lua','UI/settings_unsaved.lua','UI/settings_form.lua','UI/settings_transfer.lua','UI/collection_compare.lua','UI/settings_collections.lua','UI/settings_stock.lua','UI/settings_items.lua','UI/settings_general.lua'})do
  f.load(path)
 end
 local parent=e.CreateFrame('Frame');parent:SetSize(1000,600);a.db.profile.itemsets={same={name='Set',items={1710}}};a.db.profile.stockTargets=plan;a.db.global.itemsets={};a.db.global.effects={};a.db.char={bindings={}}
 local p=a:OpenNativeSettings(parent,'ItemSets')
 local t={f=f,a=a,e=e,p=p,parent=parent,bags=bags,native=native}
 function t:frameCount()return #frames end
 function t:scans()return scans end
 function t:scheduled()return schedules end
 function t:registered()local n=0;for _,c in ipairs(frames)do for _ in pairs(c.events or{})do n=n+1 end end;return n end
 function t:flush()local q=queue;queue={};for _,cb in ipairs(q)do cb()end;return #q end
 function t:callbacks()local q={};for i,c in ipairs(queue)do q[i]=c end;return q end
 function t:eventFrames(name)local result={};for _,c in ipairs(frames)do if c.events and c.events[name]then result[#result+1]=c end end;return result end
 function t:eventCallbacks(name)local result={};for _,c in ipairs(frames)do if c.events and c.events[name]and c.scripts.OnEvent then local callback=c.scripts.OnEvent;result[#result+1]=function()callback(c,name,0)end end end;return result end
 function t:event(name)local callbacks={};for _,c in ipairs(frames)do if c.events and c.events[name]and c.scripts.OnEvent then callbacks[#callbacks+1]={c,c.scripts.OnEvent}end end;for _,v in ipairs(callbacks)do v[2](v[1],name,0)end end
 function t:stock()assert(p.roster.sourceButtons[2]);p.roster.sourceButtons[2]:Click()end
 function t:source()p.roster.sourceButtons[1]:Click()end
 function t:copy()local b=assert(p.fields.stock_copy,'copy absent');b.scripts.OnClick(b)end
 function t:refresh()local b=assert(p.fields.stock_refresh,'refresh absent');b.scripts.OnClick(b)end
 function t:reports()local result={};for _,c in ipairs(frames)do if c.kind=='EditBox'and c.text and c.text:find('Carried bags:',1,true)then result[#result+1]=c end end;return result end
 return t
end
local function input(t,key,text)local c=assert(t.p.fields[key]);c:SetText(text);c.scripts.OnTextChanged(c,true);return c end
local function carried(t,n)assert(t.p.fields.stock_carried and t.p.fields.stock_carried:GetText()=='Carried: '..n,'wrong carried '..tostring(t.p.fields.stock_carried and t.p.fields.stock_carried:GetText()))end
local function known(t)t:stock();assert(t:scans()==0);assert(t:flush()==1,'initial timer missing');assert(t:scans()==1);carried(t,4)end

test('closed ItemSets makes zero observer native queries timers subscriptions',function()local t=fixture({same=row()});assert(t:scans()==0 and #t.native==0 and t:scheduled()==0 and t:registered()==0);t.p:Release();assert(t:flush()==0)end)
test('Stock queues initial scan via actual AceTimer minimum and real native bag methods',function()for _,legacy in ipairs({true,false})do local t=fixture({same=row()},legacy);known(t);assert(table.concat(t.native,',')=='slots:0,item:0:1');assert(t:registered()==2 and t.p.fields.stock_shortage:GetText()=='Shortage: 8')end end)
test('event bursts coalesce and pending immediately refuses old complete Copy',function()local t=fixture({same=row()});known(t);assert(t.p.fields.stock_copy:IsEnabled());for i=1,3 do t:event('BAG_UPDATE')end;t:event('PLAYER_ENTERING_WORLD');assert(not t.p.fields.stock_copy:IsEnabled());t:copy();assert(#t:reports()==0);assert(t:flush()==1 and t:scans()==2)end)
test('Draw selection history Apply and same-pane fresh-builder Open preserve session',function()local t=fixture({same=row()});known(t);t.p:Draw();t.a:OpenNativeSettings(t.parent,'ItemSets',t.p);assert(t.p.itemSettingsSource=='stock');assert(t:scheduled()==1 and t:registered()==2 and t:flush()==0);carried(t,4);input(t,'target','15').scripts.OnEnterPressed(t.p.fields.target);t.p.fields.undo:Click();t.p.fields.redo:Click();t.p.fields.apply:Click();assert(t:flush()==0 and t:scans()==1 and t.a.db.profile.stockTargets.same.target==15,'after Open apply target='..tostring(t.a.db.profile.stockTargets.same.target)..' scans='..t:scans())end)
test('count refresh preserves invalid pending input focus cursor scroll draft and history',function()local t=fixture({same=row()});known(t);local p=t.p;local c=input(t,'minimum','999bad');c:SetFocus();c:SetCursorPosition(2);p.child:SetHeight(2000);p.scroll:UpdateWorkbenchScroll();p.scroll.workbenchBar:SetValue(17);local undo=#p.historyUndo;local generation=p.generation;local d,l,fl=0,0,0;local draw,layout,flush=p.Draw,p.Layout,p.FlushEdits;p.Draw=function(...)d=d+1;return draw(...)end;p.Layout=function(...)l=l+1;return layout(...)end;p.FlushEdits=function(...)fl=fl+1;return flush(...)end;t.bags.count=1;t:refresh();t:flush();carried(t,1);assert(c:GetText()=='999bad'and c:HasFocus()and c:GetCursorPosition()==2 and p.scroll.workbenchBar:GetValue()==17 and generation==p.generation and #p.historyUndo==undo and d==0 and l==0 and fl==0 and p.draft.profile.stockTargets.same.minimum==5,'refresh text='..tostring(c:GetText())..' focus='..tostring(c:HasFocus())..' cursor='..c:GetCursorPosition()..' scroll='..p.scroll.workbenchBar:GetValue()..' gen='..p.generation..'/'..generation..' writes='..d..'/'..l..'/'..fl);t:copy();assert(fl==0 and #t:reports()==0 and c:HasFocus())end)
test('physical hide and reopen retires old callback then queues fresh observation',function()local t=fixture({same=row()});t:stock();local old=t:callbacks()[1];t.p.frame:Hide();assert(t:registered()==0);old();assert(t:scans()==0);t.p:Open(t.p.builder);assert(t:registered()==2);t:flush();assert(t:scans()==1);carried(t,4)end)
test('release source switch and stale timer callbacks do zero scans',function()for _,how in ipairs({'release','source'})do local t=fixture({same=row()});t:stock();local old=t:callbacks()[1];if how=='release'then t.p:Release()else t:source()end;assert(t:registered()==0);old();t:flush();assert(t:scans()==0 and #t.native==0)end end)
test('profile global and char identity replacement retire old owner and reopen fresh',function()for _,scope in ipairs({'profile','global','char'})do local t=fixture({same=row()});t:stock();local old=t:callbacks()[1];local original=t.a.db[scope];t.a.db[scope]=t.a:CopySettingsData(original);old();assert(t:scans()==0 and t:registered()==0);t.a:OpenNativeSettings(t.parent,'ItemSets',t.p);t:stock();t:flush();assert(t:scans()==1)end end)
test('provider reentrant owner release cannot publish old success or retain work',function()local t=fixture({same=row()});local native=t.a.Platform.GetBagItemCounts;t.a.Platform.GetBagItemCounts=function(...)local counts=native(...);t.p:Release();return counts end;t:stock();t:flush();assert(t:scans()==1 and t:registered()==0 and t:flush()==0 and not t.p.active)end)
test('event during provider keeps new pending request and discards first success',function()local t=fixture({same=row()});local native=t.a.Platform.GetBagItemCounts;local once=true;t.a.Platform.GetBagItemCounts=function(...)local result=native(...);if once then once=false;t:event('BAG_UPDATE')end;return result end;t:stock();assert(t:flush()==1 and not t.p.fields.stock_copy:IsEnabled()and t.p.fields.stock_status:GetText()=='Stock counts pending.');assert(t:flush()==1 and t:scans()==2);carried(t,4);assert(t.p.fields.stock_copy:IsEnabled())end)
test('real adapter native throw clears completeness and later event recovers without self retry',function()local t=fixture({same=row()});known(t);t.bags.fail=true;t:event('BAG_UPDATE');t:flush();assert(not t.p.fields.stock_copy:IsEnabled());carried(t,'Unknown');assert(t:flush()==0);t.bags.fail=false;t.bags.empty=true;t:event('BAG_UPDATE');t:flush();carried(t,0);assert(t.p.fields.stock_shortage:GetText()=='Shortage: 12'and t.p.fields.stock_copy:IsEnabled())end)
test('unreadable consumed counts never arithmetic or raw reason echo',function()local t=fixture({same=row()});local secret={};t.e.canaccessvalue=function(v)return not rawequal(v,secret)end;t.a.Platform.GetBagItemCounts=function()return{[1710]=secret},'PRIVATE_REASON'end;t:stock();t:flush();carried(t,'Unknown');t:copy();assert(#t:reports()==0 and not t.p.message:GetText():find('PRIVATE',1,true))end)
test('disabled unknown does not block complete model and shortage zero',function()local x=row();x.enabled=false;local t=fixture({same=x});t.a.Platform.GetBagItemCounts=function()return nil,'unavailable'end;t:stock();t:flush();assert(t.p.fields.stock_copy:IsEnabled());assert(t.p.fields.stock_shortage:GetText()=='Shortage: 0');t:copy();assert(#t:reports()==1 and t:reports()[1]:GetText()=='Carried bags:\nNo shortages.')end)
test('dirty ItemSets pending Stock and creation all refuse Copy without implicit Apply',function()local t=fixture({same=row()});input(t,'name','Unsaved').scripts.OnEnterPressed(t.p.fields.name);known(t);t:copy();assert(#t:reports()==0 and t.a.db.profile.itemsets.same.name=='Set');t.p.fields.cancel:Click();input(t,'minimum','3');t:copy();assert(#t:reports()==0 and t.a.db.profile.stockTargets.same.minimum==5);t.p.fields.minimum.scripts.OnEscapePressed(t.p.fields.minimum);t.p.fields.new_collection:Click();t:copy();assert(#t:reports()==0 and t.a.db.profile.stockTargets.same.itemID==1710)end)
test('Copy refuses malformed saved replacement before any getter traversal',function()local t=fixture({same=row()});known(t);local reads=0;t.a.db.profile.stockTargets=setmetatable({},{__index=function()reads=reads+1;error('INVALID')end});t:copy();assert(reads==0 and #t:reports()==0 and t:scans()==1)end)
test('Copy catches in-place desired mutation during formatting',function()local t=fixture({same=row()});known(t);local format=t.a.StockTargets.FormatShortages;t.a.StockTargets.FormatShortages=function(report)t.a.db.profile.stockTargets.same.target=50;return format(report)end;t:copy();assert(#t:reports()==0 and t.a.db.profile.stockTargets.same.target==50)end)
test('detached copied list remains unchanged on bag and draft changes and hides on release',function()local t=fixture({same=row()});known(t);t:copy();local report=assert(t:reports()[1]);assert(report:GetText()=='Carried bags:\n1710 x 8');t.bags.count=7;t:event('BAG_UPDATE');t:flush();input(t,'target','15').scripts.OnEnterPressed(t.p.fields.target);assert(report:GetText()=='Carried bags:\n1710 x 8');t.p:Release();local owner=report;while owner and owner.kind~='Frame'do owner=owner:GetParent()end;assert(not report:HasFocus())end)
test('report constructor release never publishes retired list',function()local t=fixture({same=row()});known(t);local ctor=t.a.CreateWorkbenchTextReport;local made;t.a.CreateWorkbenchTextReport=function(...)made=ctor(...);t.p:Release();return made end;t:copy();assert(made and not made.frame:IsShown()and not made.input:HasFocus()and #t:reports()==0)end)
test('scheduler throw and nil handle fail closed without self retry',function()for _,how in ipairs({'throw','nil'})do local t=fixture({same=row()});t.a.ScheduleTimer=function()if how=='throw'then error('PRIVATE_SCHEDULE')end end;t:stock();assert(not t.p.fields.stock_copy:IsEnabled()and t:scans()==0 and t:flush()==0);t:copy();assert(#t:reports()==0)end end)
test('synchronous scheduler cannot overwrite newer reentrant pending timer',function()local t=fixture({same=row()});local schedule=t.a.ScheduleTimer;local first=true;local native=t.a.Platform.GetBagItemCounts;local once=true;t.a.Platform.GetBagItemCounts=function(...)local result=native(...);if once then once=false;t:event('BAG_UPDATE')end;return result end;t.a.ScheduleTimer=function(self,callback,delay)if first then first=false;callback();return{}end;return schedule(self,callback,delay)end;t:stock();assert(not t.p.fields.stock_copy:IsEnabled()and t:scans()==1);assert(t:flush()==1 and t:scans()==2 and t.p.fields.stock_copy:IsEnabled())end)
test('existing retained draft must retain stock key ownership after same-pane Open',function()
 local t=fixture({same=row()});t:stock();t.a:OpenNativeSettings(t.parent,'ItemSets',t.p)
 input(t,'target','15').scripts.OnEnterPressed(t.p.fields.target);t.p.fields.apply:Click()
 assert(t.a.db.profile.stockTargets.same.target==15,'retained draft lost stock transaction key on Open')
end)
test('retained stock draft key is restored from either source without authorizing invalid saved graphs',function()
 for _,startStock in ipairs({true,false})do
  local t=fixture({same=row()});if startStock then t:stock()end
  local baseline=t.p.draftBaseline;local draft=t.p.draft
  local reads=0;t.a.db.profile.stockTargets=setmetatable({},{__index=function()reads=reads+1;error('BAD_SAVED')end})
  t.a:OpenNativeSettings(t.parent,'ItemSets',t.p)
  assert(t.p.draft==draft and t.p.draftBaseline==baseline and reads==0)
  local n=0;for _,key in ipairs(t.p.transactionKeys.profile)do if key=='stockTargets'then n=n+1 end end
  assert(n==1,'retained safe ownership not restored exactly once')
  if startStock then t:source()end
  input(t,'name','Updated').scripts.OnEnterPressed(t.p.fields.name);t.p.fields.apply:Click()
  assert(t.a.db.profile.itemsets.same.name=='Updated'and reads==0 and getmetatable(t.a.db.profile.stockTargets))
 end
end)
test('invalid original stock never gains draft ownership through repeated Open',function()
 local bad=setmetatable({},{__index=function()error('INVALID_OLD')end});local t=fixture(bad)
 assert(t.p.stockEditable==false);t.a.db.profile.stockTargets={same=row()};t.a:OpenNativeSettings(t.parent,'ItemSets',t.p)
 for _,key in ipairs(t.p.transactionKeys.profile)do assert(key~='stockTargets')end
 assert(t.p.draft.profile.stockTargets==nil and t.p.stockEditable==false)
end)
test('owner and nonstock page Open retain existing draft policies',function()
 local t=fixture({same=row()});t:stock();t:flush();local old=t.p.draft
 t.a.db.profile={itemsets={same={name='New',items={1710}}},stockTargets={next=row(999)}}
 t.a:OpenNativeSettings(t.parent,'ItemSets',t.p);assert(t.p.draft~=old and t.p.draft.profile.stockTargets.next.itemID==999 and t:registered()==0)
 t.p:Release();t.a:OpenNativeSettings(t.parent,'General',t.p);for _,key in ipairs(t.p.transactionKeys.profile)do assert(key~='stockTargets')end
 assert(t:registered()==0)
end)
test('retained old event cannot retire or queue a newly opened session',function()
 local t=fixture({same=row()});known(t);local old=t:eventCallbacks('BAG_UPDATE')[1]
 t:source();t:stock();local scheduled=t:scheduled();assert(t:registered()==2);old()
 assert(t:registered()==2 and t:scheduled()==scheduled);t:flush();assert(t:scans()==2);carried(t,4)
end)
test('empty saved plan produces detached no-shortages text after one complete observation',function()
 local t=fixture();t:stock();assert(t:flush()==1 and t:scans()==1 and t.p.fields.stock_copy:IsEnabled());t:copy();assert(t:reports()[1]:GetText()=='Carried bags:\nNo shortages.'and t.a.db.profile.stockTargets==nil)
end)
test('new committed draft item IDs consume same complete snapshot without scans',function()
 local t=fixture({same=row()});known(t);input(t,'itemID','999999').scripts.OnEnterPressed(t.p.fields.itemID);carried(t,0);assert(t.p.fields.stock_shortage:GetText()=='Shortage: 12'and t:scans()==1 and t:flush()==0 and not t.p.fields.stock_copy:IsEnabled())
end)
test('readability callback release cannot write retired drawing labels',function()
 local t=fixture({same=row()});t:stock();local p=t.p;local text=p.fields.stock_status;local writes=0;local set=text.SetText
 text.SetText=function(self,...)if not p.active then writes=writes+1 end;return set(self,...)end
 local readable=t.a.Platform.CanReadValue;t.a.Platform.CanReadValue=function(self,value)
  if type(value)=='table'and rawget(value,1710)==4 then p:Release()end;return readable(self,value)
 end
 t:flush();assert(not p.active and writes==0 and t:registered()==0)
end)
test('formatting invalid saved replacement refuses without recursive getter comparison',function()
 local t=fixture({same=row()});known(t);local reads=0;local format=t.a.StockTargets.FormatShortages
 t.a.StockTargets.FormatShortages=function(report)t.a.db.profile.stockTargets=setmetatable({},{__index=function()reads=reads+1;error('INVALID_REPLACEMENT')end});return format(report)end
 t:copy();assert(reads==0 and #t:reports()==0)
end)
test('synchronous completed timer with nil handle retains completed observation',function()
 local t=fixture({same=row()});t.a.ScheduleTimer=function(self,callback)callback()end;t:stock();assert(t:scans()==1 and t.p.fields.stock_copy:IsEnabled());carried(t,4)
end)
test('disabled required-count policy survives provider throw and absent method',function()
 for _,how in ipairs({'throw','absent'})do
  local x=row();x.enabled=false;local t=fixture({same=x})
  if how=='throw'then t.a.Platform.GetBagItemCounts=function()error('PRIVATE_THROW')end else t.a.Platform.GetBagItemCounts=nil end
  t:stock();t:flush();assert(t.p.fields.stock_copy:IsEnabled(),'disabled unknown incorrectly blocked by '..how);t:copy();assert(t:reports()[1]:GetText()=='Carried bags:\nNo shortages.')
 end
end)
test('throwing inherited provider lookup clears old completeness without escaping actual timer',function()
 local t=fixture({same=row()});known(t);local platform=t.a.Platform;platform.GetBagItemCounts=nil
 setmetatable(platform,{__index=function(_,key)if key=='GetBagItemCounts'then error('PRIVATE_METHOD_GETTER')end end})
 t:refresh();local ok,err=pcall(function()t:flush()end);assert(ok,'method getter escaped timer: '..tostring(err));t:copy();assert(#t:reports()==0 and t:scans()==1);carried(t,'Unknown')
end)
test('provider getter release returning callable performs zero retired scans',function()
 local t=fixture({same=row()});local platform=t.a.Platform;local method=platform.GetBagItemCounts;platform.GetBagItemCounts=nil
 setmetatable(platform,{__index=function(_,key)if key=='GetBagItemCounts'then t.p:Release();return method end end})
 t:stock();t:flush();assert(t:scans()==0 and #t.native==0 and t:registered()==0 and not t.p.active)
end)
test('strict complete module inverses protect every unrelated byte',function()
 local previous=dofile('tests/fixtures/restore_stock_targets_observation.lua')
 local readiness=dofile('tests/fixtures/restore_stock_readiness.lua')
 local function inverse(text,path)if path=='UI/settings_stock.lua'then text=readiness(text)end;return previous(text,path)end
 for _,path in ipairs({'UI/settings_stock.lua','UI/settings_form.lua'})do
  local file=assert(io.open(path));local source=file:read('*a');file:close()
  local restored=inverse(source,path);assert(type(restored)=='string'and restored~=source)
  assert(not pcall(inverse,source..'\n-- unrelated',path))
  assert(not pcall(inverse,restored,path))
 end
end)
test('one pane reuses its native event frame across source and release leases',function()
 local t=fixture({same=row()});known(t);local events=assert(t:eventFrames('BAG_UPDATE')[1])
 for i=1,3 do t:source();t:stock();assert(t:eventFrames('BAG_UPDATE')[1]==events,'source reopen allocated another native event frame');t:flush()end
 t.p:Release();t.p:Open(t.p.builder);assert(t:eventFrames('BAG_UPDATE')[1]==events,'pane reacquire allocated another native event frame');t:flush()
end)
test('twelve reopened copy sessions reuse one report surface and bounded native frames',function()
 local t=fixture({same=row()});known(t);t:copy();local surface=t.p.stockObservationReport;assert(surface)
 t:source();assert(not surface.frame:IsShown()and surface.text==''and surface.input:GetText()==''and surface.measure:GetText()=='')
 t:stock();t:flush();t:copy();local count=t:frameCount()
 for i=1,12 do
  t:source();t:stock();t:flush();t:copy();assert(t.p.stockObservationReport==surface and t:frameCount()==count,'reopened report allocated native frames')
 end
 t.p:Release();t.p:Open(t.p.builder);t:flush();t:copy();assert(t.p.stockObservationReport==surface and t:frameCount()==count)
end)
test('old report callbacks cannot focus hide scroll or edit a later owner report',function()
 local t=fixture({same=row()});known(t);t:copy();local d=t.p.stockObservationReport;assert(d)
 local copy=d.copy.scripts.OnClick;local close=d.close.scripts.OnClick;local escape=d.input.scripts.OnEscapePressed;local wheel=d.input.scripts.OnMouseWheel;local hide=d.Hide
 local changed=d.input.scripts.OnTextChanged;local cursor=d.input.scripts.OnCursorChanged;local frameHide=d.frame.scripts.OnHide
 t.p:Release();t.a.db.char={bindings={}};t.a:OpenNativeSettings(t.parent,'ItemSets',t.p);t:stock();t:flush();t:copy()
 assert(t.p.stockObservationReport==d);d.input:ClearFocus();d.input:SetCursorPosition(3);local scroll=d.scroll.workbenchBar:GetValue();local text=d.text
 copy(d.copy);close(d.close);escape(d.input);wheel(d.input,-1);hide(d);changed(d.input,true);cursor(d.input,0,-400,1,12);frameHide(d.frame)
 assert(d.frame:IsShown()and not d.input:HasFocus()and d.input:GetCursorPosition()==3 and d.scroll.workbenchBar:GetValue()==scroll and d.text==text)
 d.copy:Click();assert(d.input:HasFocus());d.input.scripts.OnEscapePressed(d.input);assert(not d.frame:IsShown()and not d.input:HasFocus())
end)
test('report constructor reentry uses one construction sentinel and current owner surface',function()
 local t=fixture({same=row()});known(t);local ctor=t.a.CreateWorkbenchTextReport;local calls=0
 t.a.CreateWorkbenchTextReport=function(...)calls=calls+1;t:copy();return ctor(...)end
 t:copy();assert(calls==1 and t.p.stockObservationReport and #t:reports()==1)
end)
test('retired timer cancellation cannot unregister a synchronously reacquired session',function()
 local t=fixture({same=row()});t:stock();local cancel=t.a.CancelTimer;local once=true
 t.a.CancelTimer=function(self,handle)
  local result=cancel(self,handle)
  if once then once=false;t.p:Open(t.p.builder)end
  return result
 end
 t.p.frame:Hide();assert(t.p.frame:IsShown()and t:registered()==2,'retired cleanup unregistered current event frame');t:flush();assert(t:scans()==1);carried(t,4)
end)
test('stopped cached report callbacks do not retain an unavailable reason graph',function()
 local x=row();x.enabled=false;local t=fixture({same=x});local reason={privateGraph={}};local weak=setmetatable({reason},{__mode='v'})
 t.a.Platform.GetBagItemCounts=function()return nil,reason end;t:stock();t:flush();t:copy();assert(t.p.stockObservationReport)
 t:source();reason=nil;collectgarbage('collect');collectgarbage('collect');assert(weak[1]==nil,'retired report callback retained observation reason')
end)
test('cached report chrome and right-click callbacks belong to their original lease',function()
 local t=fixture({same=row()});known(t);t:copy();local d=t.p.stockObservationReport;local drag=d.chrome.drag
 local old={start=drag:GetScript('OnDragStart'),stop=drag:GetScript('OnDragStop'),up=drag:GetScript('OnMouseUp'),hide=drag:GetScript('OnHide'),show=d.frame:GetScript('OnShow'),watch=d.frame.rmRightClickWatcher:GetScript('OnUpdate')}
 t:source();t:stock();t:flush();t:copy();assert(t.p.stockObservationReport==d)
 local starts,stops,scales,mouse=0,0,0,0
 d.frame.StartMoving=function()starts=starts+1 end;d.frame.StopMovingOrSizing=function()stops=stops+1 end
 local scale=t.a.ApplyWorkbenchScale;t.a.ApplyWorkbenchScale=function(...)scales=scales+1;return scale(...)end
 local down=true;t.e.IsMouseButtonDown=function()mouse=mouse+1;return down end;t.e.GetMouseFocus=function()return d.input end
 old.start(drag,'LeftButton');assert(starts==0 and not drag.moving,'old header started current window movement')
 drag:GetScript('OnDragStart')(drag,'LeftButton');assert(starts==1 and drag.moving)
 old.stop(drag);old.up(drag,'LeftButton');old.hide(drag);old.show(d.frame);old.watch(d.frame.rmRightClickWatcher,.1)
 assert(stops==0 and drag.moving and scales==0 and mouse==0 and d.frame:IsShown(),'old chrome callback changed current lease')
 t:source();assert(stops==1 and not drag.moving and not d.input:HasFocus()and not d.frame:IsShown(),'retirement did not stop drag/focus')
 t:stock();t:flush();down=false;t:copy();assert(d.frame:IsShown());down=true;d.frame.rmRightClickWatcher:GetScript('OnUpdate')(d.frame.rmRightClickWatcher,.1);assert(not d.frame:IsShown(),'current right-click watcher stopped working')
end)
test('retired report cleanup cannot clear a synchronously rebound report surface',function()
 local t=fixture({same=row()});known(t);t:copy();local d=t.p.stockObservationReport;local once=true
 d.frame.StopMovingOrSizing=function()
  if once then once=false;t.p:Open(t.p.builder);t:flush();t:copy()end
 end
 t.p.frame:Hide();assert(t.p.frame:IsShown()and d.frame:IsShown()and d.text=='Carried bags:\n1710 x 8'and d.input:GetText()==d.text and t:registered()==2,'retired cleanup changed rebound report')
end)
finish()
