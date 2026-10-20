-- Exact complete-module inverse for the reviewed Unit3 observation/report slice.
local sources={
 ['UI/settings_stock.lua']={old=[====[-- Profile desired-stock editing only; inventory observations belong to a later view session.
local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function integer(n)return type(n)=='number'and n==n and n~=math.huge and n~=-math.huge and n%1==0 end
local function quantity(text)local n=tonumber(text);if integer(n)and n>=0 and n<=1000000 then return n end end
function addon:ItemSettingsSourceOptions(p,options)
 if p.stockProfile~=self.db.profile or p.stockGlobal~=self.db.global or p.stockChar~=self.db.char then
  p.stockProfile,p.stockGlobal,p.stockChar=self.db.profile,self.db.global,self.db.char
  p.itemSettingsSource='itemsets';p.stockSelection=nil;p.newStockTarget=nil
 end
 options.sources={{value='itemsets',text=L['Item Sets']},{value='stock',text=L['Stock']}};options.source=p.itemSettingsSource
 local function choose(value)p.itemSettingsSource=value;p.creating=false;p.newStockTarget=nil;p.newItemSetName=nil;p:Draw()end
 options.chooseSource=choose
 options.requestSource=function(value)
  if value==p.itemSettingsSource then return end
  if p.creationUsedForNew then p:RequestLeave(function()choose(value)end)
  elseif p:FlushEdits()then choose(value)end
 end
 return options
end
function addon:BuildStockSettings(p)
 local store=p:SettingsData();local raw=rawget(self.db.profile,'stockTargets');local valid,reason=self.StockTargets.Validate(raw)
 local options=self:ItemSettingsSourceOptions(p,{})
 if not valid then
  p:UseRoster({},nil,function()end,options);p:Heading(L['Stock targets']);p:Text(L['Invalid stock targets; data preserved.']);p:Text(reason)
  p:Button('stock_reset',L['Reset targets'],function()
   local profile,global,char=self.db.profile,self.db.global,self.db.char;local expected=rawget(profile,'stockTargets')
   p:RequestLeave(function()
    if not p.active or self.db.profile~=profile or self.db.global~=global or self.db.char~=char then return end
    p:Confirm(L['Reset invalid stock targets? This cannot be undone.'],function()
     if InCombatLockdown and InCombatLockdown()then p:Message(L['Leave combat before applying these settings.']);return end
     if self.db.profile~=profile or self.db.global~=global or self.db.char~=char or not rawequal(rawget(profile,'stockTargets'),expected) then p:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return end
     profile.stockTargets=nil;p:DiscardSettingsDraft();p:Draw()
    end)
   end)
  end)
  return
 end
 local plan=store.profile.stockTargets or {};local entries={}
 for id,row in pairs(plan)do entries[#entries+1]={value=id,text=string.format('%.0f',row.itemID),icon='Interface\\Icons\\INV_Misc_QuestionMark'}end
 table.sort(entries,function(a,b)return plan[a.value].itemID<plan[b.value].itemID end)
 if not plan[p.stockSelection]and not p.creating then p.stockSelection=entries[1]and entries[1].value end
 local function create()p.previousStockSelection=p.stockSelection;p.stockSelection=nil;p.creating=true;p.newStockTarget={minimum=0,target=0,enabled=true};p:Draw()end
 options.new=create;options.newText=L['Add stock target']
 p:UseRoster(entries,p.stockSelection,function(id)p.stockSelection=id;p.creating=false;p.newStockTarget=nil;p:Draw()end,options)
 p:SetRosterActions({{key='new_collection',text=L['New'],icon='plus',enabled=#entries<128,action=create}})
 p:Heading(L['Stock targets']);p:HistoryActions()
 local row=p.creating and p.newStockTarget or plan[p.stockSelection]
 if not row then p:Text(L['No stock targets.']);return end
 local id=p.stockSelection
 local function accepted(value)
  if not integer(value)or value<=0 then return false end
  for key,other in pairs(plan)do if key~=id and other.itemID==value then return false end end
  return true
 end
 local itemLabel
 local function itemText()return row.itemID and string.format(L['Item ID: %s'],string.format('%.0f',row.itemID))or L['Choose an item first.']end
 p:Reference('itemID',L['Item'],row.itemID,'Item_EditBox',{accept=accepted},function(value)row.itemID=value;if itemLabel then itemLabel:SetText(itemText())end;if id then p:UpdateRosterEntry(id,{text=string.format('%.0f',value)})end end)
 itemLabel=p:Text(itemText());p.fields.stock_item_id=itemLabel
 p:Check('enabled',L['Enabled'],row.enabled,function(value)row.enabled=value end)
 local function parseMinimum(text)local n=quantity(text);local other=p.fields.target and quantity(p.fields.target:GetText())or row.target;if n and other and n<=other then return n end end
 local function parseTarget(text)local n=quantity(text);local other=p.fields.minimum and quantity(p.fields.minimum:GetText())or row.minimum;if n and other and other<=n then return n end end
 p:Edit('minimum',L['Minimum'],row.minimum,parseMinimum,function(value)row.minimum=value end)
 p:Edit('target',L['Target'],row.target,parseTarget,function(value)row.target=value end)
 if p.creating then
  p:CreationActions(function()
   if #entries>=128 or not accepted(row.itemID)or not self.StockTargets.Validate({candidate=row})then p:Message(L['Complete the highlighted input fields before applying.']);return end
   local new=self:uuid();if plan[new]then p:Message(L['This name is already in use.']);return end
   store.profile.stockTargets=plan;plan[new]=row;p.stockSelection=new;p.creating=false;p.newStockTarget=nil;p:Draw()
  end,function()p.creating=false;p.newStockTarget=nil;p.stockSelection=p.previousStockSelection;p:Draw()end)
 else
  self:SettingsTopDelete(p,function()if p:FlushEdits()then plan[id]=nil;p.stockSelection=nil;p:Draw()end end)
 end
end
]====],current=[====[-- Profile desired-stock editing and a private visible-only inventory observation session.
local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function integer(n)return type(n)=='number'and n==n and n~=math.huge and n~=-math.huge and n%1==0 end
local function quantity(text)local n=tonumber(text);if integer(n)and n>=0 and n<=1000000 then return n end end
-- Observations belong to one visible pane/owner lease and never enter desired data.
local sessions={}
local paint,request
local function stockClearReport(d,expected)
 if d.stockLease and d.stockLease~=expected then return end
 d.stockLease=nil
 if d.chrome and d.chrome.drag then d.chrome.drag.moving=nil;d.frame:StopMovingOrSizing()end
 if d.stockLease then return end
 d.text='';d.input:ClearFocus()
 if d.stockLease then return end
 d.setting=true;d.input:SetText('')
 if d.stockLease then return end
 d.setting=false;d.measure:SetText('')
 if d.stockOriginalHide then d.stockOriginalHide(d)else d:Hide()end
 if not d.stockLease and d.stockOriginalFrameHide then d.stockOriginalFrameHide(d.frame)end
end
local function stockStop(p,expected)
 local s=sessions[p];if not s or expected and s~=expected then return end
 sessions[p]=nil;s.retired=true;s.refs=nil;s.counts=nil;s.reason=nil;s.profile=nil;s.global=nil;s.char=nil
 local pending=s.pending;s.pending=nil
 s.events:UnregisterAllEvents();s.events:SetScript('OnEvent',nil)
 if s.report then stockClearReport(s.report,s);s.report=nil end
 if pending and pending.handle then pcall(addon.CancelTimer,addon,pending.handle)end
end
local function stockLive(s)
 local p=s.p
 return not s.retired and sessions[p]==s and p.active and p.settingsKey=='ItemSets'and p.itemSettingsSource=='stock'and p.frame:IsVisible()
 and rawequal(p.profile,addon.db.profile)and rawequal(p.global,addon.db.global)and rawequal(p.char,addon.db.char)
 and rawequal(s.profile,addon.db.profile)and rawequal(s.global,addon.db.global)and rawequal(s.char,addon.db.char)
end
local function stockSaved(s)
 if not stockLive(s)then return end
 local raw=rawget(s.profile,'stockTargets');if not addon.StockTargets.Validate(raw)then return end
 return true,raw
end
local function stockReport(s,plan)
 if s.pending then return end
 local platform=addon.Platform;local counts=s.counts
 local ok,report=pcall(function()
  if not platform:CanReadValue(counts)or type(counts)~='table'or getmetatable(counts)~=nil then return addon.StockTargets.BuildReport(plan,nil,'inventory-unavailable')end
  local selected={}
  for _,row in pairs(plan or{})do
   local count=rawget(counts,row.itemID)
   if not platform:CanReadValue(count)then return addon.StockTargets.BuildReport(plan,nil,'inventory-unavailable')end
   if count~=nil then selected[row.itemID]=count end
  end
  return addon.StockTargets.BuildReport(plan,selected,s.reason)
 end)
 if ok then return report end
end
local function copyReady(s)
 local ok,raw=stockSaved(s);if not ok or s.p.creating then return end
 local p=s.p
 if not p.draft or not p.draftBaseline or not addon.StockTargets.Validate(p.draft.profile.stockTargets)or not addon.StockTargets.Validate(p.draftBaseline.profile.stockTargets)then return end
 if p:IsSettingsDraftDirty()or not addon:SettingsDataEqual(raw,p.draftBaseline.profile.stockTargets)then return end
 local report=stockReport(s,raw)
 if report and report.complete then return report,raw end
end
paint=function(s)
 if not stockLive(s)then stockStop(s.p,s);return end
 local refs=s.refs;if not refs or not s.p:Valid(refs.generation)then return end
 local saved=stockSaved(s)
 if not saved then s.ready=false;s.counts=nil end
 local plan=s.p.draft and s.p.draft.profile.stockTargets
 local report=saved and addon.StockTargets.Validate(plan)and stockReport(s,plan)
 local selected=refs.row and addon.StockTargets.Validate({selected=refs.row})and stockReport(s,{selected=refs.row})
 local row=selected and selected.rows[1]
 local canCopy=copyReady(s)
 if not stockLive(s)or s.refs~=refs or not s.p:Valid(refs.generation)then return end
 refs.status:SetText(s.pending and L['Stock counts pending.']or report and report.complete and L['Stock counts ready.']or L['Stock counts unavailable.'])
 if refs.row then
  refs.carried:SetText(string.format(L['Carried: %s'],row and row.countKnown and string.format('%.0f',row.carried)or L['Unknown']))
  refs.shortage:SetText(string.format(L['Shortage: %s'],row and row.shortage~=nil and string.format('%.0f',row.shortage)or L['Unknown']))
 end
 if canCopy then refs.copy:Enable()else refs.copy:Disable()end
end
request=function(s)
 if not stockLive(s)then stockStop(s.p,s);return end
 if not stockSaved(s)then s.ready=false;s.counts=nil;paint(s);return end
 if s.pending then return end
 s.serial=s.serial+1;local pending={serial=s.serial};s.pending=pending;paint(s)
 local ok,handle=pcall(addon.ScheduleTimer,addon,function()
  if not stockLive(s)then stockStop(s.p,s);return end
  if s.pending~=pending then return end
  s.pending=nil
  if not stockSaved(s)then s.ready=false;s.counts=nil;paint(s);return end
  s.ready=false;s.counts=nil;s.reason='inventory-unavailable'
  local selected,platform,method=pcall(function()
   local owner=addon.Platform
   if type(owner)~='table'then return end
   local fn=owner.GetBagItemCounts
   if not owner:CanReadValue(fn)or type(fn)~='function'then return end
   return owner,fn
  end)
  if not stockLive(s)then stockStop(s.p,s);return end
  local success,counts,reason
  if selected and method then success,counts,reason=pcall(method,platform)end
  if not stockLive(s)then stockStop(s.p,s);return end
  if s.serial~=pending.serial then paint(s);return end
  s.ready=success==true
  if success then s.counts=counts;s.reason=reason else s.counts=nil;s.reason='inventory-unavailable'end
  paint(s)
 end,0)
 if s.pending==pending then
  if ok and handle then pending.handle=handle
  else s.pending=nil;s.ready=false;s.counts=nil;s.reason='inventory-unavailable';paint(s)end
 elseif ok and handle and not stockLive(s)then addon:CancelTimer(handle)
 end
end
local function stockObserve(p)
 local s=sessions[p]
 if s and not stockLive(s)then stockStop(p);s=nil end
 if not s then
  p.stockObservationEvents=p.stockObservationEvents or CreateFrame('Frame',nil,p.frame)
  s={p=p,profile=addon.db.profile,global=addon.db.global,char=addon.db.char,serial=0,events=p.stockObservationEvents};sessions[p]=s
  p.stopStockObservation=function()stockStop(p)end
  p.checkStockObservationOwner=function()local current=sessions[p];if current and not stockLive(current)then stockStop(p)end end
  p.updateStockObservationActions=function()local current=sessions[p];if current then paint(current)end end
  s.events:RegisterEvent('BAG_UPDATE');s.events:RegisterEvent('PLAYER_ENTERING_WORLD');s.events:SetScript('OnEvent',function()request(s)end)
  request(s)
 end
 return s
end
local function stockCopy(s,generation)
 if not stockLive(s)or not s.p:Valid(generation)then return end
 local report,raw=copyReady(s)
 if not report then s.p:Message(L['Apply or discard page changes and refresh stock counts before copying.']);return end
 local saved=addon:CopySettingsData(raw)
 local ok,text=pcall(addon.StockTargets.FormatShortages,report)
 if not ok or type(text)~='string'or not stockLive(s)or not copyReady(s)or not addon:SettingsDataEqual(rawget(s.profile,'stockTargets'),saved)then return end
 local p=s.p
 if p.stockReportConstructing then return end
 local d=p.stockObservationReport
 if not d then
  p.stockReportConstructing=true
  local made,result=pcall(addon.CreateWorkbenchTextReport,addon)
  p.stockReportConstructing=nil
  if not made or not result then return end
  d=result;p.stockObservationReport=d
 end
 if not stockLive(s)or not p:Valid(generation)or not copyReady(s)or not addon:SettingsDataEqual(rawget(s.profile,'stockTargets'),saved)then stockClearReport(d,s);return end
 if not d.stockOriginalHide then
  addon:RegisterWindowForEscape(d)
  d.stockOriginalHide=d.Hide;d.stockOriginalFrameHide=d.frame:GetScript('OnHide')
  d.stockScripts={}
  for _,record in ipairs({{d.copy,'OnClick'},{d.close,'OnClick'},{d.input,'OnEscapePressed'},{d.input,'OnMouseWheel'},{d.input,'OnTextChanged'},{d.input,'OnCursorChanged'},{d.frame,'OnHide'},{d.frame,'OnShow'},{d.chrome.drag,'OnDragStart'},{d.chrome.drag,'OnDragStop'},{d.chrome.drag,'OnMouseUp'},{d.chrome.drag,'OnHide'},{d.frame.rmRightClickWatcher,'OnUpdate'}})do
   record.callback=record[1]:GetScript(record[2]);d.stockScripts[#d.stockScripts+1]=record
  end
 end
 local function live()return stockLive(s)and p.stockObservationReport==d and d.stockLease==s end
 d.stockLease=s
 d.Hide=function(control,...)if live()then return d.stockOriginalHide(control,...)end end
 for _,record in ipairs(d.stockScripts)do
  local callback=record.callback
  addon:SetUIScript(record[1],record[2],function(...)if live()and callback then return callback(...)end end)
 end
 s.report=d;d:SetReport(L['Stock shortage list'],text)
 if not stockLive(s)then stockStop(s.p,s);stockClearReport(d,s)end
end
local function stockBind(p,row)
 local s=stockObserve(p);local generation=p.generation
 local status=p:Text('');p.fields.stock_status=status
 local refs={generation=generation,status=status,row=row,copy=p.fields.stock_copy}
 if row then refs.carried=p:Text('');refs.shortage=p:Text('');p.fields.stock_carried=refs.carried;p.fields.stock_shortage=refs.shortage end
 s.refs=refs
 addon:SetUIScript(p.fields.stock_refresh,'OnClick',function()if p:Valid(generation)and stockLive(s)then request(s)end end)
 addon:SetUIScript(p.fields.stock_copy,'OnClick',function()stockCopy(s,generation)end)
 p.cleanups[#p.cleanups+1]=function()if s.refs==refs then s.refs=nil end end
 paint(s)
end

function addon:ItemSettingsSourceOptions(p,options)
 if p.stockProfile~=self.db.profile or p.stockGlobal~=self.db.global or p.stockChar~=self.db.char then
  stockStop(p)
  p.stockProfile,p.stockGlobal,p.stockChar=self.db.profile,self.db.global,self.db.char
  p.itemSettingsSource='itemsets';p.stockSelection=nil;p.newStockTarget=nil
 end
 if p.settingsKey=='ItemSets'and p.stockEditable==true and p.draft and p.draftBaseline and p.draftBaseline.profile
 and addon.StockTargets.Validate(p.draft.profile.stockTargets)and addon.StockTargets.Validate(p.draftBaseline.profile.stockTargets)then
  local keys=p.transactionKeys and p.transactionKeys.profile
  if keys then local found=false;for _,key in ipairs(keys)do if key=='stockTargets'then found=true;break end end;if not found then keys[#keys+1]='stockTargets'end end
 end
 options.sources={{value='itemsets',text=L['Item Sets']},{value='stock',text=L['Stock']}};options.source=p.itemSettingsSource
 local function choose(value)if value~='stock'then stockStop(p)end;p.itemSettingsSource=value;p.creating=false;p.newStockTarget=nil;p.newItemSetName=nil;p:Draw()end
 options.chooseSource=choose
 options.requestSource=function(value)
  if value==p.itemSettingsSource then return end
  if p.creationUsedForNew then p:RequestLeave(function()choose(value)end)
  elseif p:FlushEdits()then choose(value)end
 end
 return options
end
function addon:BuildStockSettings(p)
 local store=p:SettingsData();local raw=rawget(self.db.profile,'stockTargets');local valid,reason=self.StockTargets.Validate(raw)
 local options=self:ItemSettingsSourceOptions(p,{})
 if not valid then
  stockStop(p)
  p:UseRoster({},nil,function()end,options);p:Heading(L['Stock targets']);p:Text(L['Invalid stock targets; data preserved.']);p:Text(reason)
  p:Button('stock_reset',L['Reset targets'],function()
   local profile,global,char=self.db.profile,self.db.global,self.db.char;local expected=rawget(profile,'stockTargets')
   p:RequestLeave(function()
    if not p.active or self.db.profile~=profile or self.db.global~=global or self.db.char~=char then return end
    p:Confirm(L['Reset invalid stock targets? This cannot be undone.'],function()
     if InCombatLockdown and InCombatLockdown()then p:Message(L['Leave combat before applying these settings.']);return end
     if self.db.profile~=profile or self.db.global~=global or self.db.char~=char or not rawequal(rawget(profile,'stockTargets'),expected) then p:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return end
     profile.stockTargets=nil;p:DiscardSettingsDraft();p:Draw()
    end)
   end)
  end)
  return
 end
 local plan=store.profile.stockTargets or {};local entries={}
 for id,row in pairs(plan)do entries[#entries+1]={value=id,text=string.format('%.0f',row.itemID),icon='Interface\\Icons\\INV_Misc_QuestionMark'}end
 table.sort(entries,function(a,b)return plan[a.value].itemID<plan[b.value].itemID end)
 if not plan[p.stockSelection]and not p.creating then p.stockSelection=entries[1]and entries[1].value end
 local function create()p.previousStockSelection=p.stockSelection;p.stockSelection=nil;p.creating=true;p.newStockTarget={minimum=0,target=0,enabled=true};p:Draw()end
 options.new=create;options.newText=L['Add stock target']
 p:UseRoster(entries,p.stockSelection,function(id)p.stockSelection=id;p.creating=false;p.newStockTarget=nil;p:Draw()end,options)
 p:SetRosterActions({{key='new_collection',text=L['New'],icon='plus',enabled=#entries<128,action=create},{key='stock_refresh',text=L['Refresh'],icon='refresh',action=function()end},{key='stock_copy',text=L['Copy shortage list'],icon='copy',action=function()end}})
 p:Heading(L['Stock targets']);p:HistoryActions()
 local row=p.creating and p.newStockTarget or plan[p.stockSelection]
 stockBind(p,row)
 if not row then p:Text(L['No stock targets.']);return end
 local id=p.stockSelection
 local function accepted(value)
  if not integer(value)or value<=0 then return false end
  for key,other in pairs(plan)do if key~=id and other.itemID==value then return false end end
  return true
 end
 local itemLabel
 local function itemText()return row.itemID and string.format(L['Item ID: %s'],string.format('%.0f',row.itemID))or L['Choose an item first.']end
 p:Reference('itemID',L['Item'],row.itemID,'Item_EditBox',{accept=accepted},function(value)row.itemID=value;if itemLabel then itemLabel:SetText(itemText())end;if id then p:UpdateRosterEntry(id,{text=string.format('%.0f',value)})end end)
 itemLabel=p:Text(itemText());p.fields.stock_item_id=itemLabel
 p:Check('enabled',L['Enabled'],row.enabled,function(value)row.enabled=value end)
 local function parseMinimum(text)local n=quantity(text);local other=p.fields.target and quantity(p.fields.target:GetText())or row.target;if n and other and n<=other then return n end end
 local function parseTarget(text)local n=quantity(text);local other=p.fields.minimum and quantity(p.fields.minimum:GetText())or row.minimum;if n and other and other<=n then return n end end
 p:Edit('minimum',L['Minimum'],row.minimum,parseMinimum,function(value)row.minimum=value end)
 p:Edit('target',L['Target'],row.target,parseTarget,function(value)row.target=value end)
 if p.creating then
  p:CreationActions(function()
   if #entries>=128 or not accepted(row.itemID)or not self.StockTargets.Validate({candidate=row})then p:Message(L['Complete the highlighted input fields before applying.']);return end
   local new=self:uuid();if plan[new]then p:Message(L['This name is already in use.']);return end
   store.profile.stockTargets=plan;plan[new]=row;p.stockSelection=new;p.creating=false;p.newStockTarget=nil;p:Draw()
  end,function()p.creating=false;p.newStockTarget=nil;p.stockSelection=p.previousStockSelection;p:Draw()end)
 else
  self:SettingsTopDelete(p,function()if p:FlushEdits()then plan[id]=nil;p.stockSelection=nil;p:Draw()end end)
 end
end
]====]},
 ['UI/settings_form.lua']={old=[====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function label(parent)
    local t=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');t:SetJustifyH('LEFT');t:SetJustifyV('MIDDLE');return t
end
local function identity(text) return text end

-- A private, pooled native form. Existing addon setting shapes stay outside
-- this view; every callback belongs to one drawing and one database identity.
function addon:CreateSettingsForm(parent)
    local p={frame=CreateFrame('Frame',nil,parent),pool={},counts={},fields={},edits={},cleanups={},active=false,generation=0,isSettingsForm=true}
    p.frame:SetAllPoints(parent)
    p.scroll=addon:CreateWorkbenchScrollFrame(p.frame);p.scroll:SetPoint('TOPLEFT',8,-8)
    p.child=CreateFrame('Frame',nil,p.scroll);p.scroll:SetScrollChild(p.child)
    p.message=label(p.frame);p.message:SetPoint('BOTTOMLEFT',8,4);p.message:SetTextColor(1,.5,.3);p.message:SetHeight(20)
    function p:Valid(token)
        return self.active and token==self.generation and self.profile==addon.db.profile and self.global==addon.db.global and self.char==addon.db.char
    end
    function p:Guard(callback)
        local token=self.generation
        return function(...) if self:Valid(token) then local result;if self.WithSettingsHistory then result=self:WithSettingsHistory(callback,...) else result=callback(...) end;if self.transactionKeys and self.fields.apply and not self.creationUsedForNew then if self:IsSettingsDraftDirty() then self.fields.apply:Enable() else self.fields.apply:Disable() end end;return result end end
    end
    function p:Acquire(kind,build)
        self.counts[kind]=(self.counts[kind] or 0)+1;local i=self.counts[kind];self.pool[kind]=self.pool[kind] or {}
        local c=self.pool[kind][i];if not c then c=build();self.pool[kind][i]=c end;if c.SetParent then c:SetParent(self.surface or self.child) end;c:Show();return c
    end
    function p:Message(text,success) self.message:SetText(text or '');self.message:SetTextColor(success and .35 or 1,success and .85 or .5,success and .45 or .3) end
    function p:Row(caption,height)
        local y=self.y;self.y=y+(height or 30)
        if caption and caption~='' then
            local t=self:Acquire('labels',function() return label(self.child) end);t:ClearAllPoints();t:SetPoint('TOPLEFT',0,-y);t:SetSize(212,(height or 30)-4);t:SetWordWrap(true);t:SetText(caption)
        end
        return y
    end
    function p:Text(text)
        local t=self:Acquire('text',function() return label(self.child) end);t:ClearAllPoints();t:SetPoint('TOPLEFT',0,-self.y);t:SetWidth(self.width);t:SetWordWrap(true);t:SetText(text or '');t:SetTextColor(.9,.92,.94);t:SetHeight(0);t:SetHeight(math.max(20,t:GetStringHeight()));self.y=self.y+t:GetHeight()+8;return t
    end
    function p:Heading(text)
        local t=self:Text(text);t:SetTextColor(1,.82,.2);self.y=self.y+4;return t
    end
    function p:Button(key,text,action,icon)
        local y=self:Row(nil,28);local c=self:Acquire(icon and 'iconButtons' or 'buttons',function() return icon and addon:CreateWorkbenchLabeledIconButton(self.child,icon,text,210) or addon:CreateWorkbenchButton(self.child,text,210) end)
        c:ClearAllPoints();c:SetPoint('TOPLEFT',0,-y);c:SetWidth(math.max(160,math.min(self.width,300)));c:SetText(text);if c.categoryIcon then c.categoryIcon:Hide() end;if icon then c.icon:SetTexture(addon:ControlTexture(icon)) end
        self.fields[key]=c;c:Enable();addon:SetUIScript(c,'OnClick',self:Guard(function() if self:FlushEdits() then action() end end));return c
    end
    function p:CreationActions(apply,cancel,pageDraft)
        self.creationUsed=true;self.creationUsedForNew=not pageDraft
        if not pageDraft then self.creationBaseline=self.creationBaseline or addon:CopySettingsData(self:CreationState());self.creationApply=apply end
        for _,entry in ipairs({{'apply',L['Apply'],apply},{'cancel',pageDraft and L['Discard'] or L['Cancel'],cancel}}) do
            local c=self:Acquire('creationButtons',function() return addon:CreateWorkbenchButton(self.frame,'',92) end);c:SetParent(self.frame);c:ClearAllPoints();c:SetPoint('BOTTOMRIGHT',entry[1]=='apply' and -108 or -8,2);c:SetWidth(92);c:SetText(entry[2]);c:Enable();self.fields[entry[1]]=c
            addon:SetUIScript(c,'OnClick',self:Guard(function()
                if entry[1]=='cancel' then cancel();if self.transactionKeys then self:DiscardSettingsDraft();self:Draw() end
                elseif pageDraft then if self:FlushEdits() then apply() end
                else self:ApplyCreation() end
            end))
        end
        self.fields.add=self.fields.apply;self:Layout()
    end
    function p:Actions(entries)
        local y=self:Row(nil,28);local x=0
        for _,entry in ipairs(entries) do
            local icon=entry.icon;local c=self:Acquire(icon and 'actionIcons' or 'actionButtons',function() return icon and addon:CreateWorkbenchIconButton(self.child,icon,entry.text) or addon:CreateWorkbenchButton(self.child,'',110) end)
            c:ClearAllPoints();c:SetPoint('TOPLEFT',x,-y);c.tooltip=entry.text;if icon then c.icon:SetTexture(addon:ControlTexture(icon));c:SetText('');c:SetWidth(20) else c:SetText(entry.text);c:SetWidth(110) end;x=x+c:GetWidth()+4
            if entry.enabled==false then c:Disable() else c:Enable() end;self.fields[entry.key]=c
            addon:SetUIScript(c,'OnClick',self:Guard(function() if self:FlushEdits() then entry.action() end end))
        end
    end
    function p:Section(key,title,build)
        self.closedSections=self.closedSections or {};local y=self:Row(nil,28)
        local c=self:Acquire('headings',function() return addon:CreateWorkbenchLabeledIconButton(self.child,'chevron-down','',300) end);c:ClearAllPoints();c:SetPoint('TOPLEFT',0,-y);c:SetWidth(self.width);c:SetText(title);c:GetFontString():SetTextColor(1,.82,.2);c.icon:SetTexture(addon:ControlTexture(self.closedSections[key] and 'chevron-right' or 'chevron-down'));c:Enable()
        self.fields['section_'..key]=c;addon:SetUIScript(c,'OnClick',self:Guard(function() if self:FlushEdits() then self.closedSections[key]=not self.closedSections[key];self:Draw() end end))
        if not self.closedSections[key] then build() end
    end
    function p:Check(key,caption,value,changed)
        local y=self:Row(nil);local c=self:Acquire('checks',function() return addon:CreateWorkbenchCheckBox(self.child,'',420) end)
        c:ClearAllPoints();c:SetPoint('TOPLEFT',0,-y);c:SetWidth(self.width);c:SetText(caption);c:GetFontString():SetWidth(self.width-22);c:SetChecked(value==true);c.rmCheck=true;c:Enable();self.fields[key]=c
        addon:SetUIScript(c,'OnClick',self:Guard(function() if self:FlushEdits() then c:SetChecked(not c:GetChecked());changed(c:GetChecked()) end end));return c
    end
    function p:InlineCheck(fieldKey,key,caption,value,changed,minimum)
        local rowY=self.y-30;local option=self:Check(key,caption,value,changed)
        local height=addon:LayoutWorkbenchFieldOption(self.fields[fieldKey],option,self.surface or self.child,220,rowY,self.width-220,minimum)
        self.y=rowY+height+6;return option
    end
    function p:Edit(key,caption,value,parse,changed)
        local y=self:Row(caption);local c=self:Acquire('edits',function() return addon:CreateWorkbenchEditBox(self.child) end)
        c:ClearAllPoints();c:SetPoint('TOPLEFT',220,-y);c:SetSize(math.max(1,self.width-220),24);c:SetMaxLetters(4096);c:EnableMouse(true);c:SetText(tostring(value or ''));c:SetTextColor(1,1,1);c:SetTextInsets(4,4,0,0);if c.referenceIcon then c.referenceIcon:Hide() end;if c.texturePreview then c.texturePreview:Hide() end;c:ClearFocus()
        addon:SetUIScript(c,'OnReceiveDrag',nil);addon:SetUIScript(c,'OnMouseDown',nil);if c.dropHint then c.dropHint:Hide() end;addon:SetUIScript(c,'OnEditFocusGained',nil);addon:SetUIScript(c,'OnEnter',nil);addon:SetUIScript(c,'OnLeave',nil)
        local record={control=c,parse=parse or identity,changed=changed,dirty=false,baseline=tostring(value or '')};self.edits[#self.edits+1]=record;self.fields[key]=c
        addon:SetUIScript(c,'OnTextChanged',self:Guard(function(_,user) if user then record.dirty=true;if self.transactionKeys and self.fields.apply then self.fields.apply:Enable() end;local v=record.parse(c:GetText());c:SetTextColor(1,v~=nil and 1 or .35,v~=nil and 1 or .35) end end))
        addon:SetUIScript(c,'OnEnterPressed',self:Guard(function() if self:FlushEdits() then c:ClearFocus() end end))
        addon:SetUIScript(c,'OnEscapePressed',self:Guard(function() record.dirty=false;c:SetText(record.baseline);c:SetTextColor(1,1,1);c:ClearFocus();self:Message('') end))
        addon:SetUIScript(c,'OnEditFocusLost',self:Guard(function() self:FlushEdits() end));return c
    end
    function p:Texture(key,caption,value,changed,options)
        options=options or {}
        local c;c=self:Edit(key,caption,value,nil,function(v) local texture=tonumber(v) or v;c.texturePreview:SetTexture(texture);changed(texture) end)
        local record=self.edits[#self.edits]
        c.texturePreview=c.texturePreview or c:CreateTexture(nil,'ARTWORK');c.texturePreview:ClearAllPoints();c.texturePreview:SetPoint('RIGHT',c,'LEFT',-6,0);c.texturePreview:SetSize(26,26);c.texturePreview:SetTexture(value)
        if options.preview==false then c.texturePreview:Hide() else c.texturePreview:Show() end
        local catalog=self:Acquire('textureCatalogs',function() return addon:CreateWorkbenchIconButton(self.child,'chevron-down',L['Choose overlay']) end)
        -- Anchor to the input rather than storing any engine-specific geometry.
        catalog:ClearAllPoints();catalog:SetPoint('TOPLEFT',c,'TOPRIGHT',4,0);catalog:SetSize(24,24)
        catalog:Enable()
        c:SetWidth(math.max(1,c:GetWidth()-28));self.fields[key..'_catalog']=catalog
        addon:SetUIScript(catalog,'OnClick',self:Guard(function()
            if self:FlushEdits() then self:ShowChoices(catalog,addon.Artwork.overlays,function(texture)
                c:SetText(texture);record.dirty=true;self:FlushEdits()
            end,true) end
        end));return c
    end
    function p:Slider(key,caption,value,lo,hi,step,changed)
        local y=self:Row(caption);local c=self:Acquire('sliders',function() return addon:CreateWorkbenchSlider(self.child,lo,hi,step,140) end)
        c:ClearAllPoints();c:SetPoint('TOPLEFT',220,-y-4);c:SetWidth(self.width-290);addon:SetUIScript(c,'OnValueChanged',nil);c:SetMinMaxValues(lo,hi);c:SetValueStep(step);c:SetValue(value or lo);c:EnableMouse(true)
        local number=self:Acquire('sliderNumbers',function() return addon:CreateWorkbenchEditBox(self.child) end);number:ClearAllPoints();number:SetPoint('TOPLEFT',self.width-64,-y);number:SetSize(62,24);number:SetText(string.format('%.4g',value or lo));number:SetTextColor(1,1,1);number:EnableMouse(true);number:ClearFocus()
        self.fields[key]=c;self.fields[key..'_value']=number
        local record={control=number,dirty=false,baseline=number:GetText(),parse=function(text) local n=tonumber(text);if n and n==n and n>=lo and n<=hi and (step<1 or n%1==0) then return n end end}
        record.changed=function(n) c.setting=true;c:SetValue(n);c.setting=false;changed(n) end;self.edits[#self.edits+1]=record
        addon:SetUIScript(number,'OnTextChanged',self:Guard(function(_,user) if user then record.dirty=true;if self.transactionKeys and self.fields.apply then self.fields.apply:Enable() end;local ok=record.parse(number:GetText())~=nil;number:SetTextColor(1,ok and 1 or .35,ok and 1 or .35) end end))
        addon:SetUIScript(number,'OnEnterPressed',self:Guard(function() if self:FlushEdits() then number:ClearFocus() end end));addon:SetUIScript(number,'OnEditFocusLost',self:Guard(function() self:FlushEdits() end))
        addon:SetUIScript(number,'OnEscapePressed',self:Guard(function() record.dirty=false;number:SetText(record.baseline);number:SetTextColor(1,1,1);number:ClearFocus();self:Message('') end))
        addon:SetUIScript(c,'OnValueChanged',self:Guard(function(_,n) if c.setting then return end;if step>=1 then local rounded=math.max(lo,math.min(hi,lo+math.floor((n-lo)/step+.5)*step));if rounded~=n then c.setting=true;c:SetValue(rounded);c.setting=false;n=rounded end end;if self:FlushEdits() then number:SetText(string.format('%.4g',n));record.baseline=number:GetText();changed(n) end end));return c
    end
    function p:Reference(key,caption,value,kind,settings,changed,allowEmpty)
        local provider=addon:GetReferenceProvider(kind);settings=settings or {};settings.limit=12;settings.inventory=provider.inventory
        local selected=value and (tonumber(value) or provider.resolve(value)) or nil
        local function accepted(id)
            if not settings.accept then return true end
            local ok,result=pcall(settings.accept,id);return ok and result and true or false
        end
        local function display(id) return id and (provider.name(id,settings.norank) or provider.missing) or '' end
        local c,record,paint
        c=self:Edit(key,caption,selected and display(selected) or value or '',function(text)
            if text=='' and allowEmpty then return '' end
            local id=selected and text==display(selected) and selected or provider.resolve(text,settings)
            if id~=nil and accepted(id) then return id end
        end,function(id) selected=id~='' and id or nil;c:SetText(display(selected));record.baseline=c:GetText();if paint then paint() end;changed(id) end)
        record=self.edits[#self.edits]
        c.referenceIcon=c.referenceIcon or c:CreateTexture(nil,'ARTWORK');c.referenceIcon:SetSize(20,20);c.referenceIcon:SetPoint('LEFT',2,0);c:SetTextInsets(26,4,0,0)
        paint=function()
            local info=selected and provider.info(selected);c.referenceIcon:SetTexture(info and info.icon or 'Interface\\Icons\\INV_Misc_QuestionMark');c.referenceIcon:Show()
        end
        paint();c.dropHint=c.dropHint or label(c);c.dropHint:ClearAllPoints();c.dropHint:SetPoint('LEFT',28,0);c.dropHint:SetPoint('RIGHT',-4,0);c.dropHint:SetText(provider.kind=='item' and L['Search or drag an item here'] or L['Search or drag a spell here']);c.dropHint:SetTextColor(.5,.5,.5);if c:GetText()=='' then c.dropHint:Show() else c.dropHint:Hide() end
        local textChanged=c:GetScript('OnTextChanged');local escape=c:GetScript('OnEscapePressed')
        local function query()
            local rows={};local input=c:GetText();if input==provider.missing then input='' end
            for _,entry in ipairs(provider.search(input,settings) or {}) do rows[#rows+1]={value=entry.id,text=entry.display or entry.name,icon=entry.icon} end
            if #rows==0 then if self.menu then self.menu.frame:Hide() end;return end
            self:ShowChoices(c,rows,function(id)
                if not self:Valid(self.generation) or not accepted(id) then return end
                c:SetText(display(id));selected=id;record.dirty=true;if self.transactionKeys and self.fields.apply then self.fields.apply:Enable() end;paint();if self:FlushEdits() then c:ClearFocus() end
            end,true)
        end
        addon:SetUIScript(c,'OnTextChanged',self:Guard(function(control,user) textChanged(control,user);if c:GetText()=='' then c.dropHint:Show() else c.dropHint:Hide() end;if user then query() end end))
        addon:SetUIScript(c,'OnEditFocusGained',self:Guard(function() if selected and not record.dirty then c:SetText(display(selected));record.baseline=c:GetText();paint() end;query() end))
        addon:SetUIScript(c,'OnEscapePressed',self:Guard(function() if self.menu then self.menu.frame:Hide() end;escape(c) end))
        addon:SetUIScript(c,'OnEnter',self:Guard(function() if selected and GameTooltip then GameTooltip:SetOwner(c,'ANCHOR_RIGHT');GameTooltip:SetHyperlink(provider.kind..':'..selected);GameTooltip:AddLine(provider.kind=='item' and L['Search or drag an item here'] or L['Search or drag a spell here']);GameTooltip:Show() elseif GameTooltip then GameTooltip:SetOwner(c,'ANCHOR_RIGHT');GameTooltip:SetText(c.dropHint:GetText()) end end))
        addon:SetUIScript(c,'OnLeave',function() if GameTooltip and GameTooltip:IsOwned(c) then GameTooltip:Hide() end end)
        local function drop()
            if type(GetCursorInfo)~='function' then return end
            local observed={pcall(GetCursorInfo)};local ok,cursor,first,third=observed[1],observed[2],observed[3],observed[5]
            if not ok or not addon.Platform:CanReadValue(cursor) then return end
            local id;if provider.kind=='item' and cursor=='item' then id=first elseif provider.kind=='spell' and cursor=='spell' then id=third elseif provider.kind=='spell' and cursor=='petaction' then id=first end
            if not addon.Platform:CanReadValue(id) or type(id)~='number' or not provider.resolve(tostring(id),settings) or not accepted(id) then return end
            selected=id;c:SetText(display(id));c.dropHint:Hide();record.dirty=true;if self.transactionKeys and self.fields.apply then self.fields.apply:Enable() end;paint()
            if self:FlushEdits() then if self.menu then self.menu.frame:Hide() end;if type(ClearCursor)=='function' then ClearCursor() end;c:ClearFocus() end
        end
        addon:SetUIScript(c,'OnReceiveDrag',self:Guard(drop));addon:SetUIScript(c,'OnMouseDown',self:Guard(drop))
        return c
    end
    function p:Spell(key,caption,id,spec,changed) return self:Reference(key,caption,id,'Spell_EditBox',{spec=spec,norank=false},changed) end
    function p:Item(key,caption,id,changed,allowEmpty) return self:Reference(key,caption,id,'Item_EditBox',{},changed,allowEmpty) end
    function p:ItemSequence(key,value,changed)
        local entries={{value='',text=L['Custom']}};local sets={}
        for _,source in ipairs({addon.db.global.itemsets or {},addon.db.profile.itemsets or {}}) do for id,set in pairs(source) do sets[id]=set end end
        local sorted={};for id,set in pairs(sets) do sorted[#sorted+1]={value=id,text=set.name or id} end;table.sort(sorted,function(a,b) return a.text<b.text end);for _,entry in ipairs(sorted) do entries[#entries+1]=entry end
        self:Choice(key..'_set',L['Item Set'],type(value)=='string' and value or '',entries,function(id) changed(id~='' and id or {});self:Draw() end)
        if type(value)=='string' then return end
        local items=type(value)=='table' and value or type(value)=='number' and {value} or {}
        local function replace(copy) items=copy;changed(copy) end
        for i,item in ipairs(items) do
            self:Item(key..i,string.format(L['Item %d'],i),item,function(id) local copy=addon.Functions.collections.deepcopy(items);copy[i]=id;replace(copy) end)
            self:Actions({{key=key..'_delete'..i,text=L['Delete'],icon='trash',action=function() local copy=addon.Functions.collections.deepcopy(items);table.remove(copy,i);replace(copy);self:Draw() end}})
        end
        self:Item(key..'_new',L['Add item'],'',function(id) if id~='' then local copy=addon.Functions.collections.deepcopy(items);copy[#copy+1]=id;replace(copy);self:Draw() end end,true)
    end
    function p:Sound(key,caption,value,changed)
        local ok,media=pcall(LibStub,'LibSharedMedia-3.0',true);local sounds={}
        if ok and media and media.HashTable then local success,found=pcall(media.HashTable,media,'sound');if success and type(found)=='table' then sounds=found end end
        local entries={{value='',text=L['None']}};local names={};for name in pairs(sounds) do if type(name)=='string' then names[#names+1]=name end end;table.sort(names);for _,name in ipairs(names) do entries[#entries+1]={value=name,text=name} end
        if value and sounds[value]==nil then entries[#entries+1]={value=value,text=value} end
        local selected=value;local c=self:Choice(key..'sound',caption,value or '',entries,function(v) selected=v~='' and v or nil;changed(selected) end);c:SetWidth(self.width-250)
        local play=self:Acquire('soundPlay',function() return addon:CreateWorkbenchIconButton(self.child,'play',L['Preview sound']) end);play:ClearAllPoints();play:SetPoint('LEFT',c,'RIGHT',4,0);self.fields[key..'play']=play
        addon:SetUIScript(play,'OnClick',self:Guard(function() local path=selected and sounds[selected];if (type(path)=='string' or type(path)=='number') and type(PlaySoundFile)=='function' then local played=PlaySoundFile(path,'Master');if not played then self:Message(L['Sound preview is unavailable.']) end else self:Message(L['Choose an available sound to preview.']) end end));return c
    end
    function p:Position(xvalue,yvalue,changed,anchor)
        local caption;if not anchor then caption=L['Position'] end;local y=self:Row(caption,56);local ox,oy=xvalue or 0,yvalue or 0
        if anchor then local title=self:Acquire('labels',function() return label(self.child) end);title:ClearAllPoints();title:SetPoint('TOPLEFT',0,-y);title:SetSize(154,20);title:SetText(L['Anchor']) end
        local padX=anchor and 170 or 220;local numberX=padX+78
        local pad=self:Acquire('positionPad',function() return addon:CreateWorkbenchPositionPad(self.child) end);pad:ClearAllPoints();pad:SetPoint('TOPLEFT',padX,-y)
        local token=self.generation
        pad:Bind(function(dx,dy,center,amount) if not self:FlushEdits() then return end;if center then ox,oy=0,0 else ox=ox+dx*amount;oy=oy+dy*amount end;changed(ox,oy,center);self:Draw() end,function() return self:Valid(token) end,false)
        self.fields.positionPad=pad
        local after=self.y
        local function numeric(text) local n=tonumber(text);if n and n==n and n>-math.huge and n<math.huge then return n end end
        for i,key in ipairs({'yoffs','xoffs'}) do
            local c=self:Edit(key,'',key=='yoffs' and oy or ox,numeric,function(n) if key=='yoffs' then oy=n else ox=n end;changed(ox,oy,false) end)
            c:ClearAllPoints();c:SetPoint('TOPLEFT',numberX,-y-5-(i-1)*22);c:SetSize(90,20)
            local t=self:Acquire('labels',function() return label(self.child) end);t:ClearAllPoints();t:SetPoint('TOPLEFT',numberX-18,-y-5-(i-1)*22);t:SetSize(16,20);t:SetText(key=='yoffs' and L['V'] or L['H'])
        end
        self.y=after
    end
    function p:Toggle(key,caption,value,falseLabel,trueLabel,changed)
        local y=self:Row(caption);local c=self:Acquire('togglePills',function() return addon:CreateWorkbenchPill(self.child,'',94) end)
        c:ClearAllPoints();c:SetPoint('TOPLEFT',220,-y);c:SetWidth(94);c:SetText(value and trueLabel or falseLabel);c:Enable();self.fields[key]=c
        addon:SetUIScript(c,'OnClick',self:Guard(function() if self:FlushEdits() then value=not value;c:SetText(value and trueLabel or falseLabel);changed(value) end end));return c
    end
    function p:Choice(key,caption,value,entries,changed)
        local y=self:Row(caption);local c=self:Acquire('choices',function() return addon:CreateWorkbenchLabeledIconButton(self.child,'chevron-down','',220) end)
        c:ClearAllPoints();c:SetPoint('TOPLEFT',220,-y);c:SetWidth(math.max(1,self.width-220));c:Enable();self.fields[key]=c
        local selected=L['Select'];local chosen;for _,entry in ipairs(entries) do if entry.value==value then selected=entry.text;chosen=entry;break end end;addon:PaintSelectorSelection(c,chosen,selected)
        addon:SetUIScript(c,'OnClick',self:Guard(function() if self:FlushEdits() then self:ShowChoices(c,entries,function(nextValue) if nextValue~=value then value=nextValue;changed(nextValue) end end) end end));return c
    end
    function p:ShowChoices(anchor,entries,changed,inline)
        self.menu=self.menu or addon:CreateWorkbenchSelector();local token=self.generation
        self.menu:Open(anchor,entries,nil,self:Guard(function(value,text) if not inline then anchor:SetText(text) end;changed(value) end),function() return self:Valid(token) end,inline)
    end
    function p:FlushEdits()
        if not self:Valid(self.generation) then return false end
        local changes={}
        for _,record in ipairs(self.edits) do if record.dirty then local v=record.parse(record.control:GetText());if v==nil then record.control:SetTextColor(1,.35,.35);self:Message(L['Complete the highlighted input fields before applying.']);return false end;changes[#changes+1]={record=record,value=v} end end
        for _,entry in ipairs(changes) do entry.record.dirty=false;entry.record.baseline=entry.record.control:GetText();entry.record.changed(entry.value) end
        self:Message('');if self.transactionKeys and self.fields.apply and not self.creationUsedForNew then if self:IsSettingsDraftDirty() then self.fields.apply:Enable() else self.fields.apply:Disable() end end;return true
    end
    function p:RequestLeave(callback)
        if not self:Valid(self.generation) then callback();return true end
        if self:IsCreationDirty() or self.transactionKeys and self:IsSettingsDraftDirty() then
            self:ConfirmPending(function()
                local ok;if self.creationUsedForNew then ok=self:ApplyCreation() else ok=self:FlushEdits() and self:SaveSettingsDraft() end
                if ok then callback() end
            end,function() self:DiscardSettingsDraft();callback() end);return false
        end
        if self:FlushEdits() then callback();return true end;return false
    end
    function p:Confirm(message,callback)
        local prompt=self.prompt
        if not prompt then
            prompt={frame=CreateFrame('Frame',nil,self.frame)};self.prompt=prompt;prompt.frame:SetSize(430,120);prompt.frame:SetPoint('CENTER');prompt.frame:EnableMouse(true);addon:MakeWindowOpaque(prompt.frame)
            prompt.text=label(prompt.frame);prompt.text:SetPoint('TOPLEFT',12,-12);prompt.text:SetSize(406,60);prompt.text:SetWordWrap(true)
            prompt.accept=addon:CreateWorkbenchButton(prompt.frame,L['Confirm'],100);prompt.accept:SetPoint('BOTTOMRIGHT',-120,12)
            prompt.cancel=addon:CreateWorkbenchButton(prompt.frame,L['Cancel'],100);prompt.cancel:SetPoint('BOTTOMRIGHT',-12,12)
            addon:SetUIScript(prompt.cancel,'OnClick',function() prompt.frame:Hide() end);prompt.frame:Hide()
        end
        if prompt.discard then prompt.discard:Hide() end;prompt.accept:SetText(L['Confirm']);prompt.accept:ClearAllPoints();prompt.accept:SetPoint('BOTTOMRIGHT',-120,12)
        prompt.text:SetText(message);addon:SetUIScript(prompt.accept,'OnClick',self:Guard(function() prompt.frame:Hide();callback() end));prompt.frame:SetFrameLevel(self.frame:GetFrameLevel()+250);prompt.frame:Show();addon:RegisterWindowForEscape(prompt)
    end
    function p:ConfirmPending(apply,discard)
        self:Confirm(L['Apply changes before leaving this page?'],apply)
        local d=self.prompt;d.accept:SetText(L['Apply']);d.accept:ClearAllPoints();d.accept:SetPoint('BOTTOMRIGHT',-228,12)
        d.discard=d.discard or addon:CreateWorkbenchButton(d.frame,L['Discard'],100);d.discard:ClearAllPoints();d.discard:SetPoint('BOTTOMRIGHT',-120,12);d.discard:Show()
        addon:SetUIScript(d.discard,'OnClick',self:Guard(function() d.frame:Hide();discard() end))
    end
    function p:Color(key,caption,color,changed)
        color=color or {r=1,g=1,b=1,a=1};local y=self:Row(caption,56)
        local swatch=self:Acquire('swatches',function() return addon:CreateWorkbenchButton(self.child,'',50) end);swatch:ClearAllPoints();swatch:SetPoint('TOPLEFT',220,-y);swatch:SetSize(50,50);swatch.art:SetColorTexture(color.r,color.g,color.b,color.a);swatch:Enable();self.fields[key]=swatch
        local values={r=color.r,g=color.g,b=color.b,a=color.a};local controls,records={},{}
        for i,channel in ipairs({'r','g','b','a'}) do
            local c=self:Acquire('colorInputs',function() return addon:CreateWorkbenchEditBox(self.child) end);c:ClearAllPoints();c:SetPoint('TOPLEFT',278+((i-1)%2)*84,-y-math.floor((i-1)/2)*26);c:SetSize(80,24);c:SetText(string.format('%.3f',values[channel]));c:SetTextColor(1,1,1);c:EnableMouse(true);c:ClearFocus();c:SetTextInsets(16,3,0,0)
            c.axis=c.axis or label(c);c.axis:ClearAllPoints();c.axis:SetPoint('LEFT',3,0);c.axis:SetText(channel:upper());controls[channel]=c;self.fields[key..'_'..channel]=c
            local record={control=c,dirty=false,baseline=c:GetText(),parse=function(text) local n=tonumber(text);if n and n==n and n>=0 and n<=1 then return n end end,changed=function(n) values[channel]=n;changed({r=values.r,g=values.g,b=values.b,a=values.a});swatch.art:SetColorTexture(values.r,values.g,values.b,values.a) end};self.edits[#self.edits+1]=record;records[channel]=record
            addon:SetUIScript(c,'OnTextChanged',self:Guard(function(_,user) if user then record.dirty=true;if self.transactionKeys and self.fields.apply then self.fields.apply:Enable() end;local valid=record.parse(c:GetText())~=nil;c:SetTextColor(1,valid and 1 or .35,valid and 1 or .35) end end));addon:SetUIScript(c,'OnEnterPressed',self:Guard(function() if self:FlushEdits() then c:ClearFocus() end end));addon:SetUIScript(c,'OnEditFocusLost',self:Guard(function() self:FlushEdits() end))
            addon:SetUIScript(c,'OnEscapePressed',self:Guard(function() record.dirty=false;c:SetText(record.baseline);c:SetTextColor(1,1,1);c:ClearFocus();self:Message('') end))
        end
        swatch.picker=swatch.picker or addon:CreateWorkbenchColorPicker(self.frame)
        local token=self.generation
        addon:SetUIScript(swatch,'OnEnter',self:Guard(function() swatch.art:SetColorTexture(values.r,values.g,values.b,values.a) end));addon:SetUIScript(swatch,'OnLeave',self:Guard(function() swatch.art:SetColorTexture(values.r,values.g,values.b,values.a) end))
        addon:SetUIScript(swatch,'OnClick',self:Guard(function() if self:FlushEdits() then swatch.picker:Open(values,self:Guard(function(r,g,b,a) values={r=r,g=g,b=b,a=a};for channel,c in pairs(controls) do c:SetText(string.format('%.3f',values[channel]));records[channel].baseline=c:GetText();records[channel].dirty=false end;swatch.art:SetColorTexture(r,g,b,a);changed({r=r,g=g,b=b,a=a}) end),function() return self:Valid(token) end,swatch) end end))
        self.cleanups[#self.cleanups+1]=function() if swatch.picker.frame:IsShown() then swatch.picker:Close(true) end end
        return swatch
    end
    function p:Draw()
        if not self.active then return end
        self.generation=self.generation+1
        if self.menu then self.menu.frame:Hide() end
        if self.prompt then self.prompt.frame:Hide() end
        if self.textDialog then self.textDialog.frame:Hide() end
        for _,cleanup in ipairs(self.cleanups) do cleanup() end;self.cleanups={}
        for _,list in pairs(self.pool) do for _,control in ipairs(list) do control:Hide() end end
        self.creationUsed=false;self.creationUsedForNew=false;self.counts={};self.fields={};self.edits={};if self.ResetLayout then self:ResetLayout() end;self.y=4;self.width=math.max(340,math.min(760,self.frame:GetWidth()-40));self.child:SetWidth(self.width)
        self.builder(self);if self.DraftActions then self:DraftActions() end;if not self.creationUsedForNew then self.creationBaseline=nil;self.creationApply=nil end;self.child:SetHeight(self.y+12);self.scroll:UpdateWorkbenchScroll()
    end
    function p:Open(builder)
        if self.profile~=addon.db.profile or self.global~=addon.db.global or self.char~=addon.db.char then self.selection=nil;self.creating=false;self.rosterQuery=nil;self.condition=nil;self.category=nil;self.conditionSource=nil;self.newAnnounce=nil;self.newEffectName=nil;self.newItem=nil;self.newItemSetName=nil;self.newGroupName=nil end
        if self.profile~=addon.db.profile or self.global~=addon.db.global then self.draft=nil end
        self.active=true;self.profile=addon.db.profile;self.global=addon.db.global;self.char=addon.db.char;self.builder=builder;self.frame:Show();self:Layout();self:Draw()
    end
    function p:Layout()
        if self.fixedViewport then
            self.scroll:Hide();self.child:SetParent(self.frame);self.child:ClearAllPoints();self.child:SetPoint('TOPLEFT',0,0);self.child:SetWidth(self.frame:GetWidth());return
        end
        self.scroll:SetSize(math.max(1,self.frame:GetWidth()-34),math.max(1,self.frame:GetHeight()-(self.creationUsed and 66 or 38)));self.message:SetWidth(math.max(1,self.frame:GetWidth()-(self.creationUsed and 340 or 20)))
    end
    function p:SetWidth(n) local changed=n~=self.frame:GetWidth();self.frame:SetWidth(n);self:Layout();if changed and self.active and self:FlushEdits() then self:Draw() end end
    function p:SetHeight(n) self.frame:SetHeight(n);self:Layout() end
    function p:Release()
        if self.ClearSettingsHistory then self:ClearSettingsHistory() end
        self.draft=nil;self.draftBaseline=nil;self.draftEffects=nil;self.active=false;self.generation=self.generation+1;if self.menu then self.menu.frame:Hide() end
        if self.prompt then self.prompt.frame:Hide() end
        if self.textDialog then self.textDialog.frame:Hide() end
        for _,cleanup in ipairs(self.cleanups) do cleanup() end;self.cleanups={}
        for _,list in pairs(self.pool) do for _,control in ipairs(list) do if control.ClearFocus then control:ClearFocus() end end end
        self.frame:Hide()
    end
    if addon.InstallSettingsHistory then addon:InstallSettingsHistory(p) end
    if addon.InstallSettingsDraft then addon:InstallSettingsDraft(p) end
    if addon.InstallSettingsOrdered then addon:InstallSettingsOrdered(p) end
    if addon.InstallSettingsRosterOrder then addon:InstallSettingsRosterOrder(p) end
    if addon.InstallSettingsLayout then addon:InstallSettingsLayout(p) end
    if addon.InstallSettingsUnsaved then addon:InstallSettingsUnsaved(p) end
    if addon.InstallSettingsChangeReview then addon:InstallSettingsChangeReview(p) end
    p.frame:SetSize(parent:GetWidth(),parent:GetHeight());p:Layout();return p
end
]====],current=[====[local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function label(parent)
    local t=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');t:SetJustifyH('LEFT');t:SetJustifyV('MIDDLE');return t
end
local function identity(text) return text end

-- A private, pooled native form. Existing addon setting shapes stay outside
-- this view; every callback belongs to one drawing and one database identity.
function addon:CreateSettingsForm(parent)
    local p={frame=CreateFrame('Frame',nil,parent),pool={},counts={},fields={},edits={},cleanups={},active=false,generation=0,isSettingsForm=true}
    p.frame:SetAllPoints(parent)
    addon:SetUIScript(p.frame,"OnHide",function()if p.stopStockObservation then p.stopStockObservation()end end)
    p.scroll=addon:CreateWorkbenchScrollFrame(p.frame);p.scroll:SetPoint('TOPLEFT',8,-8)
    p.child=CreateFrame('Frame',nil,p.scroll);p.scroll:SetScrollChild(p.child)
    p.message=label(p.frame);p.message:SetPoint('BOTTOMLEFT',8,4);p.message:SetTextColor(1,.5,.3);p.message:SetHeight(20)
    function p:Valid(token)
        return self.active and token==self.generation and self.profile==addon.db.profile and self.global==addon.db.global and self.char==addon.db.char
    end
    function p:Guard(callback)
        local token=self.generation
        return function(...) if self:Valid(token) then local result;if self.WithSettingsHistory then result=self:WithSettingsHistory(callback,...) else result=callback(...) end;if self.transactionKeys and self.fields.apply and not self.creationUsedForNew then if self:IsSettingsDraftDirty() then self.fields.apply:Enable() else self.fields.apply:Disable() end end;if self.updateStockObservationActions then self.updateStockObservationActions()end;return result end end
    end
    function p:Acquire(kind,build)
        self.counts[kind]=(self.counts[kind] or 0)+1;local i=self.counts[kind];self.pool[kind]=self.pool[kind] or {}
        local c=self.pool[kind][i];if not c then c=build();self.pool[kind][i]=c end;if c.SetParent then c:SetParent(self.surface or self.child) end;c:Show();return c
    end
    function p:Message(text,success) self.message:SetText(text or '');self.message:SetTextColor(success and .35 or 1,success and .85 or .5,success and .45 or .3) end
    function p:Row(caption,height)
        local y=self.y;self.y=y+(height or 30)
        if caption and caption~='' then
            local t=self:Acquire('labels',function() return label(self.child) end);t:ClearAllPoints();t:SetPoint('TOPLEFT',0,-y);t:SetSize(212,(height or 30)-4);t:SetWordWrap(true);t:SetText(caption)
        end
        return y
    end
    function p:Text(text)
        local t=self:Acquire('text',function() return label(self.child) end);t:ClearAllPoints();t:SetPoint('TOPLEFT',0,-self.y);t:SetWidth(self.width);t:SetWordWrap(true);t:SetText(text or '');t:SetTextColor(.9,.92,.94);t:SetHeight(0);t:SetHeight(math.max(20,t:GetStringHeight()));self.y=self.y+t:GetHeight()+8;return t
    end
    function p:Heading(text)
        local t=self:Text(text);t:SetTextColor(1,.82,.2);self.y=self.y+4;return t
    end
    function p:Button(key,text,action,icon)
        local y=self:Row(nil,28);local c=self:Acquire(icon and 'iconButtons' or 'buttons',function() return icon and addon:CreateWorkbenchLabeledIconButton(self.child,icon,text,210) or addon:CreateWorkbenchButton(self.child,text,210) end)
        c:ClearAllPoints();c:SetPoint('TOPLEFT',0,-y);c:SetWidth(math.max(160,math.min(self.width,300)));c:SetText(text);if c.categoryIcon then c.categoryIcon:Hide() end;if icon then c.icon:SetTexture(addon:ControlTexture(icon)) end
        self.fields[key]=c;c:Enable();addon:SetUIScript(c,'OnClick',self:Guard(function() if self:FlushEdits() then action() end end));return c
    end
    function p:CreationActions(apply,cancel,pageDraft)
        self.creationUsed=true;self.creationUsedForNew=not pageDraft
        if not pageDraft then self.creationBaseline=self.creationBaseline or addon:CopySettingsData(self:CreationState());self.creationApply=apply end
        for _,entry in ipairs({{'apply',L['Apply'],apply},{'cancel',pageDraft and L['Discard'] or L['Cancel'],cancel}}) do
            local c=self:Acquire('creationButtons',function() return addon:CreateWorkbenchButton(self.frame,'',92) end);c:SetParent(self.frame);c:ClearAllPoints();c:SetPoint('BOTTOMRIGHT',entry[1]=='apply' and -108 or -8,2);c:SetWidth(92);c:SetText(entry[2]);c:Enable();self.fields[entry[1]]=c
            addon:SetUIScript(c,'OnClick',self:Guard(function()
                if entry[1]=='cancel' then cancel();if self.transactionKeys then self:DiscardSettingsDraft();self:Draw() end
                elseif pageDraft then if self:FlushEdits() then apply() end
                else self:ApplyCreation() end
            end))
        end
        self.fields.add=self.fields.apply;self:Layout()
    end
    function p:Actions(entries)
        local y=self:Row(nil,28);local x=0
        for _,entry in ipairs(entries) do
            local icon=entry.icon;local c=self:Acquire(icon and 'actionIcons' or 'actionButtons',function() return icon and addon:CreateWorkbenchIconButton(self.child,icon,entry.text) or addon:CreateWorkbenchButton(self.child,'',110) end)
            c:ClearAllPoints();c:SetPoint('TOPLEFT',x,-y);c.tooltip=entry.text;if icon then c.icon:SetTexture(addon:ControlTexture(icon));c:SetText('');c:SetWidth(20) else c:SetText(entry.text);c:SetWidth(110) end;x=x+c:GetWidth()+4
            if entry.enabled==false then c:Disable() else c:Enable() end;self.fields[entry.key]=c
            addon:SetUIScript(c,'OnClick',self:Guard(function() if self:FlushEdits() then entry.action() end end))
        end
    end
    function p:Section(key,title,build)
        self.closedSections=self.closedSections or {};local y=self:Row(nil,28)
        local c=self:Acquire('headings',function() return addon:CreateWorkbenchLabeledIconButton(self.child,'chevron-down','',300) end);c:ClearAllPoints();c:SetPoint('TOPLEFT',0,-y);c:SetWidth(self.width);c:SetText(title);c:GetFontString():SetTextColor(1,.82,.2);c.icon:SetTexture(addon:ControlTexture(self.closedSections[key] and 'chevron-right' or 'chevron-down'));c:Enable()
        self.fields['section_'..key]=c;addon:SetUIScript(c,'OnClick',self:Guard(function() if self:FlushEdits() then self.closedSections[key]=not self.closedSections[key];self:Draw() end end))
        if not self.closedSections[key] then build() end
    end
    function p:Check(key,caption,value,changed)
        local y=self:Row(nil);local c=self:Acquire('checks',function() return addon:CreateWorkbenchCheckBox(self.child,'',420) end)
        c:ClearAllPoints();c:SetPoint('TOPLEFT',0,-y);c:SetWidth(self.width);c:SetText(caption);c:GetFontString():SetWidth(self.width-22);c:SetChecked(value==true);c.rmCheck=true;c:Enable();self.fields[key]=c
        addon:SetUIScript(c,'OnClick',self:Guard(function() if self:FlushEdits() then c:SetChecked(not c:GetChecked());changed(c:GetChecked()) end end));return c
    end
    function p:InlineCheck(fieldKey,key,caption,value,changed,minimum)
        local rowY=self.y-30;local option=self:Check(key,caption,value,changed)
        local height=addon:LayoutWorkbenchFieldOption(self.fields[fieldKey],option,self.surface or self.child,220,rowY,self.width-220,minimum)
        self.y=rowY+height+6;return option
    end
    function p:Edit(key,caption,value,parse,changed)
        local y=self:Row(caption);local c=self:Acquire('edits',function() return addon:CreateWorkbenchEditBox(self.child) end)
        c:ClearAllPoints();c:SetPoint('TOPLEFT',220,-y);c:SetSize(math.max(1,self.width-220),24);c:SetMaxLetters(4096);c:EnableMouse(true);c:SetText(tostring(value or ''));c:SetTextColor(1,1,1);c:SetTextInsets(4,4,0,0);if c.referenceIcon then c.referenceIcon:Hide() end;if c.texturePreview then c.texturePreview:Hide() end;c:ClearFocus()
        addon:SetUIScript(c,'OnReceiveDrag',nil);addon:SetUIScript(c,'OnMouseDown',nil);if c.dropHint then c.dropHint:Hide() end;addon:SetUIScript(c,'OnEditFocusGained',nil);addon:SetUIScript(c,'OnEnter',nil);addon:SetUIScript(c,'OnLeave',nil)
        local record={control=c,parse=parse or identity,changed=changed,dirty=false,baseline=tostring(value or '')};self.edits[#self.edits+1]=record;self.fields[key]=c
        addon:SetUIScript(c,'OnTextChanged',self:Guard(function(_,user) if user then record.dirty=true;if self.transactionKeys and self.fields.apply then self.fields.apply:Enable() end;local v=record.parse(c:GetText());c:SetTextColor(1,v~=nil and 1 or .35,v~=nil and 1 or .35) end end))
        addon:SetUIScript(c,'OnEnterPressed',self:Guard(function() if self:FlushEdits() then c:ClearFocus() end end))
        addon:SetUIScript(c,'OnEscapePressed',self:Guard(function() record.dirty=false;c:SetText(record.baseline);c:SetTextColor(1,1,1);c:ClearFocus();self:Message('') end))
        addon:SetUIScript(c,'OnEditFocusLost',self:Guard(function() self:FlushEdits() end));return c
    end
    function p:Texture(key,caption,value,changed,options)
        options=options or {}
        local c;c=self:Edit(key,caption,value,nil,function(v) local texture=tonumber(v) or v;c.texturePreview:SetTexture(texture);changed(texture) end)
        local record=self.edits[#self.edits]
        c.texturePreview=c.texturePreview or c:CreateTexture(nil,'ARTWORK');c.texturePreview:ClearAllPoints();c.texturePreview:SetPoint('RIGHT',c,'LEFT',-6,0);c.texturePreview:SetSize(26,26);c.texturePreview:SetTexture(value)
        if options.preview==false then c.texturePreview:Hide() else c.texturePreview:Show() end
        local catalog=self:Acquire('textureCatalogs',function() return addon:CreateWorkbenchIconButton(self.child,'chevron-down',L['Choose overlay']) end)
        -- Anchor to the input rather than storing any engine-specific geometry.
        catalog:ClearAllPoints();catalog:SetPoint('TOPLEFT',c,'TOPRIGHT',4,0);catalog:SetSize(24,24)
        catalog:Enable()
        c:SetWidth(math.max(1,c:GetWidth()-28));self.fields[key..'_catalog']=catalog
        addon:SetUIScript(catalog,'OnClick',self:Guard(function()
            if self:FlushEdits() then self:ShowChoices(catalog,addon.Artwork.overlays,function(texture)
                c:SetText(texture);record.dirty=true;self:FlushEdits()
            end,true) end
        end));return c
    end
    function p:Slider(key,caption,value,lo,hi,step,changed)
        local y=self:Row(caption);local c=self:Acquire('sliders',function() return addon:CreateWorkbenchSlider(self.child,lo,hi,step,140) end)
        c:ClearAllPoints();c:SetPoint('TOPLEFT',220,-y-4);c:SetWidth(self.width-290);addon:SetUIScript(c,'OnValueChanged',nil);c:SetMinMaxValues(lo,hi);c:SetValueStep(step);c:SetValue(value or lo);c:EnableMouse(true)
        local number=self:Acquire('sliderNumbers',function() return addon:CreateWorkbenchEditBox(self.child) end);number:ClearAllPoints();number:SetPoint('TOPLEFT',self.width-64,-y);number:SetSize(62,24);number:SetText(string.format('%.4g',value or lo));number:SetTextColor(1,1,1);number:EnableMouse(true);number:ClearFocus()
        self.fields[key]=c;self.fields[key..'_value']=number
        local record={control=number,dirty=false,baseline=number:GetText(),parse=function(text) local n=tonumber(text);if n and n==n and n>=lo and n<=hi and (step<1 or n%1==0) then return n end end}
        record.changed=function(n) c.setting=true;c:SetValue(n);c.setting=false;changed(n) end;self.edits[#self.edits+1]=record
        addon:SetUIScript(number,'OnTextChanged',self:Guard(function(_,user) if user then record.dirty=true;if self.transactionKeys and self.fields.apply then self.fields.apply:Enable() end;local ok=record.parse(number:GetText())~=nil;number:SetTextColor(1,ok and 1 or .35,ok and 1 or .35) end end))
        addon:SetUIScript(number,'OnEnterPressed',self:Guard(function() if self:FlushEdits() then number:ClearFocus() end end));addon:SetUIScript(number,'OnEditFocusLost',self:Guard(function() self:FlushEdits() end))
        addon:SetUIScript(number,'OnEscapePressed',self:Guard(function() record.dirty=false;number:SetText(record.baseline);number:SetTextColor(1,1,1);number:ClearFocus();self:Message('') end))
        addon:SetUIScript(c,'OnValueChanged',self:Guard(function(_,n) if c.setting then return end;if step>=1 then local rounded=math.max(lo,math.min(hi,lo+math.floor((n-lo)/step+.5)*step));if rounded~=n then c.setting=true;c:SetValue(rounded);c.setting=false;n=rounded end end;if self:FlushEdits() then number:SetText(string.format('%.4g',n));record.baseline=number:GetText();changed(n) end end));return c
    end
    function p:Reference(key,caption,value,kind,settings,changed,allowEmpty)
        local provider=addon:GetReferenceProvider(kind);settings=settings or {};settings.limit=12;settings.inventory=provider.inventory
        local selected=value and (tonumber(value) or provider.resolve(value)) or nil
        local function accepted(id)
            if not settings.accept then return true end
            local ok,result=pcall(settings.accept,id);return ok and result and true or false
        end
        local function display(id) return id and (provider.name(id,settings.norank) or provider.missing) or '' end
        local c,record,paint
        c=self:Edit(key,caption,selected and display(selected) or value or '',function(text)
            if text=='' and allowEmpty then return '' end
            local id=selected and text==display(selected) and selected or provider.resolve(text,settings)
            if id~=nil and accepted(id) then return id end
        end,function(id) selected=id~='' and id or nil;c:SetText(display(selected));record.baseline=c:GetText();if paint then paint() end;changed(id) end)
        record=self.edits[#self.edits]
        c.referenceIcon=c.referenceIcon or c:CreateTexture(nil,'ARTWORK');c.referenceIcon:SetSize(20,20);c.referenceIcon:SetPoint('LEFT',2,0);c:SetTextInsets(26,4,0,0)
        paint=function()
            local info=selected and provider.info(selected);c.referenceIcon:SetTexture(info and info.icon or 'Interface\\Icons\\INV_Misc_QuestionMark');c.referenceIcon:Show()
        end
        paint();c.dropHint=c.dropHint or label(c);c.dropHint:ClearAllPoints();c.dropHint:SetPoint('LEFT',28,0);c.dropHint:SetPoint('RIGHT',-4,0);c.dropHint:SetText(provider.kind=='item' and L['Search or drag an item here'] or L['Search or drag a spell here']);c.dropHint:SetTextColor(.5,.5,.5);if c:GetText()=='' then c.dropHint:Show() else c.dropHint:Hide() end
        local textChanged=c:GetScript('OnTextChanged');local escape=c:GetScript('OnEscapePressed')
        local function query()
            local rows={};local input=c:GetText();if input==provider.missing then input='' end
            for _,entry in ipairs(provider.search(input,settings) or {}) do rows[#rows+1]={value=entry.id,text=entry.display or entry.name,icon=entry.icon} end
            if #rows==0 then if self.menu then self.menu.frame:Hide() end;return end
            self:ShowChoices(c,rows,function(id)
                if not self:Valid(self.generation) or not accepted(id) then return end
                c:SetText(display(id));selected=id;record.dirty=true;if self.transactionKeys and self.fields.apply then self.fields.apply:Enable() end;paint();if self:FlushEdits() then c:ClearFocus() end
            end,true)
        end
        addon:SetUIScript(c,'OnTextChanged',self:Guard(function(control,user) textChanged(control,user);if c:GetText()=='' then c.dropHint:Show() else c.dropHint:Hide() end;if user then query() end end))
        addon:SetUIScript(c,'OnEditFocusGained',self:Guard(function() if selected and not record.dirty then c:SetText(display(selected));record.baseline=c:GetText();paint() end;query() end))
        addon:SetUIScript(c,'OnEscapePressed',self:Guard(function() if self.menu then self.menu.frame:Hide() end;escape(c) end))
        addon:SetUIScript(c,'OnEnter',self:Guard(function() if selected and GameTooltip then GameTooltip:SetOwner(c,'ANCHOR_RIGHT');GameTooltip:SetHyperlink(provider.kind..':'..selected);GameTooltip:AddLine(provider.kind=='item' and L['Search or drag an item here'] or L['Search or drag a spell here']);GameTooltip:Show() elseif GameTooltip then GameTooltip:SetOwner(c,'ANCHOR_RIGHT');GameTooltip:SetText(c.dropHint:GetText()) end end))
        addon:SetUIScript(c,'OnLeave',function() if GameTooltip and GameTooltip:IsOwned(c) then GameTooltip:Hide() end end)
        local function drop()
            if type(GetCursorInfo)~='function' then return end
            local observed={pcall(GetCursorInfo)};local ok,cursor,first,third=observed[1],observed[2],observed[3],observed[5]
            if not ok or not addon.Platform:CanReadValue(cursor) then return end
            local id;if provider.kind=='item' and cursor=='item' then id=first elseif provider.kind=='spell' and cursor=='spell' then id=third elseif provider.kind=='spell' and cursor=='petaction' then id=first end
            if not addon.Platform:CanReadValue(id) or type(id)~='number' or not provider.resolve(tostring(id),settings) or not accepted(id) then return end
            selected=id;c:SetText(display(id));c.dropHint:Hide();record.dirty=true;if self.transactionKeys and self.fields.apply then self.fields.apply:Enable() end;paint()
            if self:FlushEdits() then if self.menu then self.menu.frame:Hide() end;if type(ClearCursor)=='function' then ClearCursor() end;c:ClearFocus() end
        end
        addon:SetUIScript(c,'OnReceiveDrag',self:Guard(drop));addon:SetUIScript(c,'OnMouseDown',self:Guard(drop))
        return c
    end
    function p:Spell(key,caption,id,spec,changed) return self:Reference(key,caption,id,'Spell_EditBox',{spec=spec,norank=false},changed) end
    function p:Item(key,caption,id,changed,allowEmpty) return self:Reference(key,caption,id,'Item_EditBox',{},changed,allowEmpty) end
    function p:ItemSequence(key,value,changed)
        local entries={{value='',text=L['Custom']}};local sets={}
        for _,source in ipairs({addon.db.global.itemsets or {},addon.db.profile.itemsets or {}}) do for id,set in pairs(source) do sets[id]=set end end
        local sorted={};for id,set in pairs(sets) do sorted[#sorted+1]={value=id,text=set.name or id} end;table.sort(sorted,function(a,b) return a.text<b.text end);for _,entry in ipairs(sorted) do entries[#entries+1]=entry end
        self:Choice(key..'_set',L['Item Set'],type(value)=='string' and value or '',entries,function(id) changed(id~='' and id or {});self:Draw() end)
        if type(value)=='string' then return end
        local items=type(value)=='table' and value or type(value)=='number' and {value} or {}
        local function replace(copy) items=copy;changed(copy) end
        for i,item in ipairs(items) do
            self:Item(key..i,string.format(L['Item %d'],i),item,function(id) local copy=addon.Functions.collections.deepcopy(items);copy[i]=id;replace(copy) end)
            self:Actions({{key=key..'_delete'..i,text=L['Delete'],icon='trash',action=function() local copy=addon.Functions.collections.deepcopy(items);table.remove(copy,i);replace(copy);self:Draw() end}})
        end
        self:Item(key..'_new',L['Add item'],'',function(id) if id~='' then local copy=addon.Functions.collections.deepcopy(items);copy[#copy+1]=id;replace(copy);self:Draw() end end,true)
    end
    function p:Sound(key,caption,value,changed)
        local ok,media=pcall(LibStub,'LibSharedMedia-3.0',true);local sounds={}
        if ok and media and media.HashTable then local success,found=pcall(media.HashTable,media,'sound');if success and type(found)=='table' then sounds=found end end
        local entries={{value='',text=L['None']}};local names={};for name in pairs(sounds) do if type(name)=='string' then names[#names+1]=name end end;table.sort(names);for _,name in ipairs(names) do entries[#entries+1]={value=name,text=name} end
        if value and sounds[value]==nil then entries[#entries+1]={value=value,text=value} end
        local selected=value;local c=self:Choice(key..'sound',caption,value or '',entries,function(v) selected=v~='' and v or nil;changed(selected) end);c:SetWidth(self.width-250)
        local play=self:Acquire('soundPlay',function() return addon:CreateWorkbenchIconButton(self.child,'play',L['Preview sound']) end);play:ClearAllPoints();play:SetPoint('LEFT',c,'RIGHT',4,0);self.fields[key..'play']=play
        addon:SetUIScript(play,'OnClick',self:Guard(function() local path=selected and sounds[selected];if (type(path)=='string' or type(path)=='number') and type(PlaySoundFile)=='function' then local played=PlaySoundFile(path,'Master');if not played then self:Message(L['Sound preview is unavailable.']) end else self:Message(L['Choose an available sound to preview.']) end end));return c
    end
    function p:Position(xvalue,yvalue,changed,anchor)
        local caption;if not anchor then caption=L['Position'] end;local y=self:Row(caption,56);local ox,oy=xvalue or 0,yvalue or 0
        if anchor then local title=self:Acquire('labels',function() return label(self.child) end);title:ClearAllPoints();title:SetPoint('TOPLEFT',0,-y);title:SetSize(154,20);title:SetText(L['Anchor']) end
        local padX=anchor and 170 or 220;local numberX=padX+78
        local pad=self:Acquire('positionPad',function() return addon:CreateWorkbenchPositionPad(self.child) end);pad:ClearAllPoints();pad:SetPoint('TOPLEFT',padX,-y)
        local token=self.generation
        pad:Bind(function(dx,dy,center,amount) if not self:FlushEdits() then return end;if center then ox,oy=0,0 else ox=ox+dx*amount;oy=oy+dy*amount end;changed(ox,oy,center);self:Draw() end,function() return self:Valid(token) end,false)
        self.fields.positionPad=pad
        local after=self.y
        local function numeric(text) local n=tonumber(text);if n and n==n and n>-math.huge and n<math.huge then return n end end
        for i,key in ipairs({'yoffs','xoffs'}) do
            local c=self:Edit(key,'',key=='yoffs' and oy or ox,numeric,function(n) if key=='yoffs' then oy=n else ox=n end;changed(ox,oy,false) end)
            c:ClearAllPoints();c:SetPoint('TOPLEFT',numberX,-y-5-(i-1)*22);c:SetSize(90,20)
            local t=self:Acquire('labels',function() return label(self.child) end);t:ClearAllPoints();t:SetPoint('TOPLEFT',numberX-18,-y-5-(i-1)*22);t:SetSize(16,20);t:SetText(key=='yoffs' and L['V'] or L['H'])
        end
        self.y=after
    end
    function p:Toggle(key,caption,value,falseLabel,trueLabel,changed)
        local y=self:Row(caption);local c=self:Acquire('togglePills',function() return addon:CreateWorkbenchPill(self.child,'',94) end)
        c:ClearAllPoints();c:SetPoint('TOPLEFT',220,-y);c:SetWidth(94);c:SetText(value and trueLabel or falseLabel);c:Enable();self.fields[key]=c
        addon:SetUIScript(c,'OnClick',self:Guard(function() if self:FlushEdits() then value=not value;c:SetText(value and trueLabel or falseLabel);changed(value) end end));return c
    end
    function p:Choice(key,caption,value,entries,changed)
        local y=self:Row(caption);local c=self:Acquire('choices',function() return addon:CreateWorkbenchLabeledIconButton(self.child,'chevron-down','',220) end)
        c:ClearAllPoints();c:SetPoint('TOPLEFT',220,-y);c:SetWidth(math.max(1,self.width-220));c:Enable();self.fields[key]=c
        local selected=L['Select'];local chosen;for _,entry in ipairs(entries) do if entry.value==value then selected=entry.text;chosen=entry;break end end;addon:PaintSelectorSelection(c,chosen,selected)
        addon:SetUIScript(c,'OnClick',self:Guard(function() if self:FlushEdits() then self:ShowChoices(c,entries,function(nextValue) if nextValue~=value then value=nextValue;changed(nextValue) end end) end end));return c
    end
    function p:ShowChoices(anchor,entries,changed,inline)
        self.menu=self.menu or addon:CreateWorkbenchSelector();local token=self.generation
        self.menu:Open(anchor,entries,nil,self:Guard(function(value,text) if not inline then anchor:SetText(text) end;changed(value) end),function() return self:Valid(token) end,inline)
    end
    function p:FlushEdits()
        if not self:Valid(self.generation) then return false end
        local changes={}
        for _,record in ipairs(self.edits) do if record.dirty then local v=record.parse(record.control:GetText());if v==nil then record.control:SetTextColor(1,.35,.35);self:Message(L['Complete the highlighted input fields before applying.']);return false end;changes[#changes+1]={record=record,value=v} end end
        for _,entry in ipairs(changes) do entry.record.dirty=false;entry.record.baseline=entry.record.control:GetText();entry.record.changed(entry.value) end
        self:Message('');if self.transactionKeys and self.fields.apply and not self.creationUsedForNew then if self:IsSettingsDraftDirty() then self.fields.apply:Enable() else self.fields.apply:Disable() end end;return true
    end
    function p:RequestLeave(callback)
        if not self:Valid(self.generation) then callback();return true end
        if self:IsCreationDirty() or self.transactionKeys and self:IsSettingsDraftDirty() then
            self:ConfirmPending(function()
                local ok;if self.creationUsedForNew then ok=self:ApplyCreation() else ok=self:FlushEdits() and self:SaveSettingsDraft() end
                if ok then callback() end
            end,function() self:DiscardSettingsDraft();callback() end);return false
        end
        if self:FlushEdits() then callback();return true end;return false
    end
    function p:Confirm(message,callback)
        local prompt=self.prompt
        if not prompt then
            prompt={frame=CreateFrame('Frame',nil,self.frame)};self.prompt=prompt;prompt.frame:SetSize(430,120);prompt.frame:SetPoint('CENTER');prompt.frame:EnableMouse(true);addon:MakeWindowOpaque(prompt.frame)
            prompt.text=label(prompt.frame);prompt.text:SetPoint('TOPLEFT',12,-12);prompt.text:SetSize(406,60);prompt.text:SetWordWrap(true)
            prompt.accept=addon:CreateWorkbenchButton(prompt.frame,L['Confirm'],100);prompt.accept:SetPoint('BOTTOMRIGHT',-120,12)
            prompt.cancel=addon:CreateWorkbenchButton(prompt.frame,L['Cancel'],100);prompt.cancel:SetPoint('BOTTOMRIGHT',-12,12)
            addon:SetUIScript(prompt.cancel,'OnClick',function() prompt.frame:Hide() end);prompt.frame:Hide()
        end
        if prompt.discard then prompt.discard:Hide() end;prompt.accept:SetText(L['Confirm']);prompt.accept:ClearAllPoints();prompt.accept:SetPoint('BOTTOMRIGHT',-120,12)
        prompt.text:SetText(message);addon:SetUIScript(prompt.accept,'OnClick',self:Guard(function() prompt.frame:Hide();callback() end));prompt.frame:SetFrameLevel(self.frame:GetFrameLevel()+250);prompt.frame:Show();addon:RegisterWindowForEscape(prompt)
    end
    function p:ConfirmPending(apply,discard)
        self:Confirm(L['Apply changes before leaving this page?'],apply)
        local d=self.prompt;d.accept:SetText(L['Apply']);d.accept:ClearAllPoints();d.accept:SetPoint('BOTTOMRIGHT',-228,12)
        d.discard=d.discard or addon:CreateWorkbenchButton(d.frame,L['Discard'],100);d.discard:ClearAllPoints();d.discard:SetPoint('BOTTOMRIGHT',-120,12);d.discard:Show()
        addon:SetUIScript(d.discard,'OnClick',self:Guard(function() d.frame:Hide();discard() end))
    end
    function p:Color(key,caption,color,changed)
        color=color or {r=1,g=1,b=1,a=1};local y=self:Row(caption,56)
        local swatch=self:Acquire('swatches',function() return addon:CreateWorkbenchButton(self.child,'',50) end);swatch:ClearAllPoints();swatch:SetPoint('TOPLEFT',220,-y);swatch:SetSize(50,50);swatch.art:SetColorTexture(color.r,color.g,color.b,color.a);swatch:Enable();self.fields[key]=swatch
        local values={r=color.r,g=color.g,b=color.b,a=color.a};local controls,records={},{}
        for i,channel in ipairs({'r','g','b','a'}) do
            local c=self:Acquire('colorInputs',function() return addon:CreateWorkbenchEditBox(self.child) end);c:ClearAllPoints();c:SetPoint('TOPLEFT',278+((i-1)%2)*84,-y-math.floor((i-1)/2)*26);c:SetSize(80,24);c:SetText(string.format('%.3f',values[channel]));c:SetTextColor(1,1,1);c:EnableMouse(true);c:ClearFocus();c:SetTextInsets(16,3,0,0)
            c.axis=c.axis or label(c);c.axis:ClearAllPoints();c.axis:SetPoint('LEFT',3,0);c.axis:SetText(channel:upper());controls[channel]=c;self.fields[key..'_'..channel]=c
            local record={control=c,dirty=false,baseline=c:GetText(),parse=function(text) local n=tonumber(text);if n and n==n and n>=0 and n<=1 then return n end end,changed=function(n) values[channel]=n;changed({r=values.r,g=values.g,b=values.b,a=values.a});swatch.art:SetColorTexture(values.r,values.g,values.b,values.a) end};self.edits[#self.edits+1]=record;records[channel]=record
            addon:SetUIScript(c,'OnTextChanged',self:Guard(function(_,user) if user then record.dirty=true;if self.transactionKeys and self.fields.apply then self.fields.apply:Enable() end;local valid=record.parse(c:GetText())~=nil;c:SetTextColor(1,valid and 1 or .35,valid and 1 or .35) end end));addon:SetUIScript(c,'OnEnterPressed',self:Guard(function() if self:FlushEdits() then c:ClearFocus() end end));addon:SetUIScript(c,'OnEditFocusLost',self:Guard(function() self:FlushEdits() end))
            addon:SetUIScript(c,'OnEscapePressed',self:Guard(function() record.dirty=false;c:SetText(record.baseline);c:SetTextColor(1,1,1);c:ClearFocus();self:Message('') end))
        end
        swatch.picker=swatch.picker or addon:CreateWorkbenchColorPicker(self.frame)
        local token=self.generation
        addon:SetUIScript(swatch,'OnEnter',self:Guard(function() swatch.art:SetColorTexture(values.r,values.g,values.b,values.a) end));addon:SetUIScript(swatch,'OnLeave',self:Guard(function() swatch.art:SetColorTexture(values.r,values.g,values.b,values.a) end))
        addon:SetUIScript(swatch,'OnClick',self:Guard(function() if self:FlushEdits() then swatch.picker:Open(values,self:Guard(function(r,g,b,a) values={r=r,g=g,b=b,a=a};for channel,c in pairs(controls) do c:SetText(string.format('%.3f',values[channel]));records[channel].baseline=c:GetText();records[channel].dirty=false end;swatch.art:SetColorTexture(r,g,b,a);changed({r=r,g=g,b=b,a=a}) end),function() return self:Valid(token) end,swatch) end end))
        self.cleanups[#self.cleanups+1]=function() if swatch.picker.frame:IsShown() then swatch.picker:Close(true) end end
        return swatch
    end
    function p:Draw()
        if not self.active then return end
        self.generation=self.generation+1
        if self.menu then self.menu.frame:Hide() end
        if self.prompt then self.prompt.frame:Hide() end
        if self.textDialog then self.textDialog.frame:Hide() end
        for _,cleanup in ipairs(self.cleanups) do cleanup() end;self.cleanups={}
        for _,list in pairs(self.pool) do for _,control in ipairs(list) do control:Hide() end end
        self.creationUsed=false;self.creationUsedForNew=false;self.counts={};self.fields={};self.edits={};if self.ResetLayout then self:ResetLayout() end;self.y=4;self.width=math.max(340,math.min(760,self.frame:GetWidth()-40));self.child:SetWidth(self.width)
        self.builder(self);if self.DraftActions then self:DraftActions() end;if not self.creationUsedForNew then self.creationBaseline=nil;self.creationApply=nil end;self.child:SetHeight(self.y+12);self.scroll:UpdateWorkbenchScroll()
    end
    function p:Open(builder)
        if self.checkStockObservationOwner then self.checkStockObservationOwner()end
        if self.profile~=addon.db.profile or self.global~=addon.db.global or self.char~=addon.db.char then self.selection=nil;self.creating=false;self.rosterQuery=nil;self.condition=nil;self.category=nil;self.conditionSource=nil;self.newAnnounce=nil;self.newEffectName=nil;self.newItem=nil;self.newItemSetName=nil;self.newGroupName=nil end
        if self.profile~=addon.db.profile or self.global~=addon.db.global then self.draft=nil end
        self.active=true;self.profile=addon.db.profile;self.global=addon.db.global;self.char=addon.db.char;self.builder=builder;self.frame:Show();self:Layout();self:Draw()
    end
    function p:Layout()
        if self.fixedViewport then
            self.scroll:Hide();self.child:SetParent(self.frame);self.child:ClearAllPoints();self.child:SetPoint('TOPLEFT',0,0);self.child:SetWidth(self.frame:GetWidth());return
        end
        self.scroll:SetSize(math.max(1,self.frame:GetWidth()-34),math.max(1,self.frame:GetHeight()-(self.creationUsed and 66 or 38)));self.message:SetWidth(math.max(1,self.frame:GetWidth()-(self.creationUsed and 340 or 20)))
    end
    function p:SetWidth(n) local changed=n~=self.frame:GetWidth();self.frame:SetWidth(n);self:Layout();if changed and self.active and self:FlushEdits() then self:Draw() end end
    function p:SetHeight(n) self.frame:SetHeight(n);self:Layout() end
    function p:Release()
        if self.stopStockObservation then self.stopStockObservation()end
        if self.ClearSettingsHistory then self:ClearSettingsHistory() end
        self.draft=nil;self.draftBaseline=nil;self.draftEffects=nil;self.active=false;self.generation=self.generation+1;if self.menu then self.menu.frame:Hide() end
        if self.prompt then self.prompt.frame:Hide() end
        if self.textDialog then self.textDialog.frame:Hide() end
        for _,cleanup in ipairs(self.cleanups) do cleanup() end;self.cleanups={}
        for _,list in pairs(self.pool) do for _,control in ipairs(list) do if control.ClearFocus then control:ClearFocus() end end end
        self.frame:Hide()
    end
    if addon.InstallSettingsHistory then addon:InstallSettingsHistory(p) end
    if addon.InstallSettingsDraft then addon:InstallSettingsDraft(p) end
    if addon.InstallSettingsOrdered then addon:InstallSettingsOrdered(p) end
    if addon.InstallSettingsRosterOrder then addon:InstallSettingsRosterOrder(p) end
    if addon.InstallSettingsLayout then addon:InstallSettingsLayout(p) end
    if addon.InstallSettingsUnsaved then addon:InstallSettingsUnsaved(p) end
    if addon.InstallSettingsChangeReview then addon:InstallSettingsChangeReview(p) end
    p.frame:SetSize(parent:GetWidth(),parent:GetHeight());p:Layout();return p
end
]====]},
}
return function(text,path)
 local source=assert(sources[path],'unexpected stock observation module')
 assert(type(text)=='string'and text==source.current,'unrelated stock observation module delta')
 return source.old
end
