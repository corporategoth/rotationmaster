-- Profile desired-stock editing only; inventory observations belong to a later view session.
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
