-- Exact complete UI module inverse frozen from d5a970f.
local repairs={
 {old=[=[local function copyReady(s)
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
]=],new=[=[-- Assessment uses the already-built committed report, never a second observation.
local function stockReadinessText(report,reason,pending)
 if pending then return L['Saved stock counts pending.'] end
 if reason=='page-changes' then return L['Apply or discard page changes to assess saved targets.'] end
 if not report then return L['Saved stock readiness unavailable.'] end
 local enabled,below,unknown=0,0,0
 for _,row in ipairs(report.rows)do
  if row.enabled then
   enabled=enabled+1
   if not row.countKnown then unknown=unknown+1 elseif row.carried<row.minimum then below=below+1 end
  end
 end
 if enabled==0 then return L['No enabled saved targets.'] end
 if unknown>0 then return string.format(L['%d below minimum; %d unknown.'],below,unknown) end
 if below>0 then return string.format(L['%d saved targets below minimum.'],below) end
 return L['All saved minimums met.']
end
local function stockReadinessLabel(p)
 local control=p:Text('');local previous=control:GetHeight();local height=previous
 -- Reserve every localized state at Draw; later count updates only change text.
 control:SetText('0');local lineHeight=control:GetStringHeight();control:SetHeight(0)
 for _,text in ipairs({L['All saved minimums met.'],L['No enabled saved targets.'],string.format(L['%d saved targets below minimum.'],128),
  string.format(L['%d below minimum; %d unknown.'],128,128),L['Saved stock counts pending.'],
  L['Apply or discard page changes to assess saved targets.'],L['Saved stock readiness unavailable.']})do
  control:SetText(text);height=math.max(height,control:GetStringHeight())
 end
 -- One extra native line allows digit-width variation in the bounded counts.
 control:SetHeight(height+lineHeight);control:SetText('');p.y=p.y+control:GetHeight()-previous
 return control
end
local function copyReady(s)
 local ok,raw=stockSaved(s);if not ok then return end
 if s.p.creating then return nil,nil,nil,'page-changes' end
 local p=s.p
 if not p.draft or not p.draftBaseline or not addon.StockTargets.Validate(p.draft.profile.stockTargets)or not addon.StockTargets.Validate(p.draftBaseline.profile.stockTargets)then return end
 if p:IsSettingsDraftDirty()or not addon:SettingsDataEqual(raw,p.draftBaseline.profile.stockTargets)then return nil,nil,nil,'page-changes' end
 local report=stockReport(s,raw)
 if report and report.complete then return report,raw,report end
 return nil,nil,report
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
 local canCopy,_,assessmentReport,assessmentReason=copyReady(s)
 if not stockLive(s)or s.refs~=refs or not s.p:Valid(refs.generation)then return end
 refs.status:SetText(s.pending and L['Stock counts pending.']or report and report.complete and L['Stock counts ready.']or L['Stock counts unavailable.'])
 refs.readiness:SetText(stockReadinessText(assessmentReport,assessmentReason,s.pending))
 if refs.row then
  refs.carried:SetText(string.format(L['Carried: %s'],row and row.countKnown and string.format('%.0f',row.carried)or L['Unknown']))
  refs.shortage:SetText(string.format(L['Shortage: %s'],row and row.shortage~=nil and string.format('%.0f',row.shortage)or L['Unknown']))
 end
 if canCopy then refs.copy:Enable()else refs.copy:Disable()end
end
]=]},
 {old=[=[local function stockBind(p,row)
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

]=],new=[=[local function stockBind(p,row)
 local s=stockObserve(p);local generation=p.generation
 local status=p:Text('');p.fields.stock_status=status
 local readiness=stockReadinessLabel(p);p.fields.stock_readiness=readiness
 local refs={generation=generation,status=status,readiness=readiness,row=row,copy=p.fields.stock_copy}
 if row then refs.carried=p:Text('');refs.shortage=p:Text('');p.fields.stock_carried=refs.carried;p.fields.stock_shortage=refs.shortage end
 s.refs=refs
 addon:SetUIScript(p.fields.stock_refresh,'OnClick',function()if p:Valid(generation)and stockLive(s)then request(s)end end)
 addon:SetUIScript(p.fields.stock_copy,'OnClick',function()stockCopy(s,generation)end)
 p.cleanups[#p.cleanups+1]=function()if s.refs==refs then s.refs=nil end end
 paint(s)
end

]=]},
}
local function restore(text)
 assert(type(text)=='string','expected complete stock UI source')
 for _,repair in ipairs(repairs)do
  local first,last=text:find(repair.new,1,true);assert(first and not text:find(repair.new,last+1,true),'unexpected stock readiness source')
  text=text:sub(1,first-1)..repair.old..text:sub(last+1)
 end
 local hash=5381;for i=1,#text do hash=(hash*33+text:byte(i))%4294967296 end
 assert(#text==15535 and string.format('%08x',hash)=='1cac623d','unrelated stock UI source changes')
 return text
end
return restore
