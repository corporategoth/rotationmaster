-- Actual Stock UI, inventory observation session and bundled AceTimer.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local file=assert(io.open('tests/stock_targets_observation.lua'));local source=file:read('*a');file:close()
local first=assert(source:find("test('closed ItemSets",1,true),'stock observation fixture boundary changed')
local actual=assert(loadstring(source:sub(1,first-1)..'return fixture','@tests/stock_targets_observation.lua'))()
local function row(id,minimum,target,enabled)return{itemID=id or 1710,minimum=minimum or 5,target=target or 12,enabled=enabled~=false}end
local function fixture(plan,historical)
 local original=loadfile
 if historical then loadfile=function(path)
  if path=='UI/settings_stock.lua'then local h=assert(io.open(path));local text=h:read('*a');h:close();return assert(loadstring(dofile('tests/fixtures/restore_stock_readiness.lua')(text),'@'..path))end
  return original(path)
 end end
 local ok,t=pcall(actual,plan);loadfile=original;assert(ok,t);return t
end
local function readiness(t,expected)local label=assert(t.p.fields.stock_readiness,'overall saved readiness label absent');assert(label:GetText()==expected,'readiness '..label:GetText()..' expected '..expected);assert(label:GetHeight()>=label:GetStringHeight(),'readiness text clipped');return label end
local function show(t)t:stock();assert(t:scans()==0);assert(t:flush()==1 and t:scans()==1)end
local function input(t,key,value)local c=t.p.fields[key];c:SetText(value);c.scripts.OnTextChanged(c,true);return c end

test('saved minimum readiness distinguishes availability shortage and threshold from target',function()
 for _,case in ipairs({{4,'1 saved targets below minimum.'},{5,'All saved minimums met.'},{8,'All saved minimums met.'},{12,'All saved minimums met.'}})do
  local t=fixture({a=row()});t.bags.count=case[1];show(t);readiness(t,case[2]);assert(t.p.fields.stock_status:GetText()=='Stock counts ready.'and t.p.fields.stock_copy:IsEnabled())
 end
end)
test('pending empty disabled and minimum-zero states do not manufacture requirements',function()
 for _,plan in ipairs({{}, {a=row(1710,5,12,false)}})do local t=fixture(plan);t:stock();readiness(t,'Saved stock counts pending.');t:flush();readiness(t,'No enabled saved targets.')end
 local t=fixture({a=row(1710,0,12)});t.bags.empty=true;show(t);readiness(t,'All saved minimums met.')
end)
test('required unknown and mixed known shortages remain incomplete and uncopyable',function()
 local t=fixture({a=row(),b=row(9)});local calls=0;t.a.Platform.GetBagItemCounts=function()calls=calls+1;return{[1710]=4,[9]=-1}end;t:stock();t:flush();readiness(t,'1 below minimum; 1 unknown.');assert(calls==1 and not t.p.fields.stock_copy:IsEnabled());t:copy();assert(#t:reports()==0)
 local t=fixture({a=row()});t.bags.fail=true;show(t);readiness(t,'0 below minimum; 1 unknown.');t.bags.fail=false;t:event('BAG_UPDATE');t:flush();readiness(t,'1 saved targets below minimum.')
end)
test('invalid and accepted page edits require Apply or Discard without consuming pending fields',function()
 local t=fixture({a=row()});t.bags.count=5;show(t);local p=t.p;local c=input(t,'minimum','999bad');c:SetFocus();c:SetCursorPosition(2);p.child:SetHeight(2000);p.scroll:UpdateWorkbenchScroll();p.scroll.workbenchBar:SetValue(17)
 readiness(t,'Apply or discard page changes to assess saved targets.');local history=#p.historyUndo;local generation=p.generation;local draw,layout,flush=p.Draw,p.Layout,p.FlushEdits;local d,l,fl=0,0,0
 p.Draw=function(...)d=d+1;return draw(...)end;p.Layout=function(...)l=l+1;return layout(...)end;p.FlushEdits=function(...)fl=fl+1;return flush(...)end
 t:refresh();readiness(t,'Saved stock counts pending.');t:flush();readiness(t,'Apply or discard page changes to assess saved targets.')
 assert(c:GetText()=='999bad'and c:HasFocus()and c:GetCursorPosition()==2 and p.scroll.workbenchBar:GetValue()==17 and #p.historyUndo==history and p.generation==generation and d==0 and l==0 and fl==0 and p.draft.profile.stockTargets.a.minimum==5)
 p.Draw,p.Layout,p.FlushEdits=draw,layout,flush;c.scripts.OnEscapePressed(c);readiness(t,'All saved minimums met.')
 input(t,'minimum','4').scripts.OnEnterPressed(p.fields.minimum);readiness(t,'Apply or discard page changes to assess saved targets.');p.fields.cancel:Click();readiness(t,'All saved minimums met.')
end)
test('Apply Undo Redo and creation retain saved-plan authority and no new observations',function()
 local t=fixture({a=row()});t.bags.count=5;show(t);local p=t.p;input(t,'minimum','6').scripts.OnEnterPressed(p.fields.minimum);readiness(t,'Apply or discard page changes to assess saved targets.')
 p.fields.undo:Click();readiness(t,'All saved minimums met.');p.fields.redo:Click();readiness(t,'Apply or discard page changes to assess saved targets.');p.fields.apply:Click();readiness(t,'1 saved targets below minimum.');assert(t.a.db.profile.stockTargets.a.minimum==6 and t:scans()==1 and t:flush()==0)
 p.fields.new_collection:Click();readiness(t,'Apply or discard page changes to assess saved targets.');assert(not p.fields.stock_copy:IsEnabled())
end)
test('count events preserve detached copied text while current readiness changes',function()
 local t=fixture({a=row()});show(t);t:copy();local copied=assert(t:reports()[1]);assert(copied:GetText()=='Carried bags:\n1710 x 8');t.bags.count=5;t:event('BAG_UPDATE');readiness(t,'Saved stock counts pending.');t:flush();readiness(t,'All saved minimums met.');assert(copied:GetText()=='Carried bags:\n1710 x 8')
end)
test('closed source physical hide and released callbacks create no extra observations',function()
 local t=fixture({a=row()});assert(t:scans()==0 and t:registered()==0 and t:scheduled()==0);show(t);local label=readiness(t,'1 saved targets below minimum.');local writes=0;local set=label.SetText;label.SetText=function(self,...)if not t.p.active then writes=writes+1 end;return set(self,...)end
 local old=t:eventCallbacks('BAG_UPDATE')[1];local scans=t:scans();t.p:Release();old();assert(t:registered()==0 and t:flush()==0 and t:scans()==scans and writes==0)
 local t=fixture({a=row()});show(t);t.p.frame:Hide();assert(t:registered()==0);t.p:Open(t.p.builder);t:flush();readiness(t,'1 saved targets below minimum.');assert(t:scans()==2)
end)
test('profile global and character identity changes retire the old assessment lease',function()
 for _,key in ipairs({'profile','global','char'})do local t=fixture({a=row()});show(t);local old=t:eventCallbacks('BAG_UPDATE')[1];t.a.db[key]=t.a:CopySettingsData(t.a.db[key]);old();assert(t:registered()==0 and t:flush()==0 and t:scans()==1);t.a:OpenNativeSettings(t.parent,'ItemSets',t.p);t:stock();t:flush();readiness(t,'1 saved targets below minimum.');assert(t:scans()==2)end
end)
test('translated readiness has reserved wrapped space across narrow resize and all bounded messages',function()
 local t=fixture({a=row()});local keys={'All saved minimums met.','No enabled saved targets.','%d saved targets below minimum.','%d below minimum; %d unknown.','Saved stock counts pending.','Apply or discard page changes to assess saved targets.','Saved stock readiness unavailable.'}
 for _,key in ipairs(keys)do t.f.translations[key]='Translated expanded minimum assessment: '..key..' translated ending.'end
 show(t)
 for _,width in ipairs({420,900,420})do
  t.p:SetWidth(width);local label=assert(t.p.fields.stock_readiness);local point=label.point;local bottom=-point[#point]+label:GetHeight();local carried=t.p.fields.stock_carried;assert(-carried.point[#carried.point]>=bottom+8,'readiness overlaps selected counts')
  for _,key in ipairs(keys)do label:SetText(string.format(t.f.translations[key],128,128));assert(label:GetHeight()>=label:GetStringHeight(),'translated label lacks reserved height')end
  t.p.updateStockObservationActions();assert(t:scans()==1 and t:flush()==0)
 end
end)
test('readiness reuses the exact old report builds native queries and copy first-two-result authority',function()
 local function run(historical)
  local t=fixture({a=row()},historical);local n=0;local build=t.a.StockTargets.BuildReport;t.a.StockTargets.BuildReport=function(...)n=n+1;return build(...)end
  show(t);t:copy();t.bags.count=5;t:event('BAG_UPDATE');t:flush();t:copy();return n,table.concat(t.native,','),t:scans(),t:scheduled(),t:reports()[1]:GetText(),t.a.db.profile.stockTargets.a.minimum
 end
 local a,b,c,d,e,f=run(false);local aa,bb,cc,dd,ee,ff=run(true);assert(a==aa and b==bb and c==cc and d==dd and e==ee and f==ff,'readiness adds report builds/observations or changes Copy')
end)
test('all128 targets and malformed saved replacement retain bounded truthful assessment',function()
 local plan={};for i=1,128 do plan['row'..i]=row(i)end
 local t=fixture(plan);show(t);readiness(t,'128 saved targets below minimum.')
 local reads=0;t.a.db.profile.stockTargets=setmetatable({},{__index=function()reads=reads+1;error('PRIVATE')end});t.p.updateStockObservationActions();readiness(t,'Saved stock readiness unavailable.');assert(reads==0 and not t.p.fields.stock_copy:IsEnabled()and t:scans()==1)
end)
test('reentrant provider release never publishes new readiness into a retired label',function()
 local t=fixture({a=row()});t:stock();local label=assert(t.p.fields.stock_readiness);local writes=0;local set=label.SetText;label.SetText=function(self,...)if not t.p.active then writes=writes+1 end;return set(self,...)end
 local method=t.a.Platform.GetBagItemCounts;t.a.Platform.GetBagItemCounts=function(...)local result=method(...);t.p:Release();return result end
 t:flush();assert(not t.p.active and writes==0 and t:registered()==0 and t:flush()==0)
end)
test('strict full-module inverse restores actual frozen d5 baseline and rejects unrelated bytes',function()
 local h=assert(io.open('UI/settings_stock.lua'));local text=h:read('*a');h:close();local inverse=dofile('tests/fixtures/restore_stock_readiness.lua');local old=inverse(text);local n=5381;for i=1,#old do n=(n*33+old:byte(i))%4294967296 end
 assert(#old==15535 and string.format('%08x',n)=='1cac623d','frozen whole stock UI changed');assert(not pcall(inverse,text..'\n-- unrelated'))
end)
finish()
