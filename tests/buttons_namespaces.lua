-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
 local f=F.new(5,1,'SHAMAN');local a,e=f.addon,f.env;local calls={pixel={},stops={},timers={}}
 local library={PixelGlow_Stop=function(frame,key) calls.stops[#calls.stops+1]={frame=frame,key=key} end,AutoCastGlow_Stop=function() end,ButtonGlow_Stop=function() end,PixelGlow_Start=function(...) calls.pixel[#calls.pixel+1]={...} end}
 local stub=e.LibStub;e.LibStub=setmetatable({GetLibrary=function(_,name,silent) assert(silent and name:match('^LibActionButton'));return nil end},{__call=function(_,name,...) if name=='LibCustomGlow-1.0' then return library end;return stub(name,...) end})
 e.C_AddOns={IsAddOnLoaded=function() return false end};e.tinsert,e.tremove=table.insert,table.remove
 local create=e.CreateFrame;e.CreateFrame=function(...)
  local frame=create(...);local texture=frame.CreateTexture
  function frame:CreateTexture(...) local region=texture(self,...);function region:SetBlendMode(value) self.blend=value end;return region end
  return frame
 end
 e.HasAction=function(slot) return slot==73 or slot==74 end;e.GetActionInfo=function(slot) assert(slot==73 or slot==74);return 'spell',133 end
 e.GetSpellInfo=function(id) assert(id==133);return 'Fireball',nil,1,0,0,30,133 end
 a.db.profile.color={r=.2,g=.3,b=.4,a=.5}
 function a:ScheduleRepeatingTimer(callback,frequency,...) local token={callback=callback,frequency=frequency,args={...}};calls.timers[token]=true;return token end
 function a:CancelTimer(token) assert(calls.timers[token],'unknown overlay timer');calls.timers[token]=nil end
 for _,path in ipairs({'Platform/spells.lua','Platform/macros.lua','buttons.lua','Core/function_data.lua'}) do f.load(path) end
 local function button(slot,kind)
  local value=e.CreateFrame('Button',nil,e.UIParent);value:SetSize(42,30);value:SetFrameStrata('FULLSCREEN_DIALOG');value:SetFrameLevel(20)
  local attributes={type=kind or 'action',action=slot,spell=133};function value:GetAttribute(key) return attributes[key] end
  return value,attributes
 end
 return f,a,calls,button
end
local function poison(a) a.index=function() error('LEGACY_INDEX_ALIAS_MUST_NOT_RUN') end end
local function inverse(text)
 for _,args in ipairs({'addon.textured_types, type','slots, bslot'}) do
  local repaired='addon.Functions.collections.index('..args..')';local original='addon.index('..args..')'
  local first,last=text:find(repaired,1,true);assert(first and not text:find(repaired,last+1,true),'unexpected canonical button index expression count')
  text=text:sub(1,first-1)..original..text:sub(last+1)
 end
 return text
end
local function pack(...) return {n=select('#',...),...} end

test('actual textured Glow resolves live canonical index with exact arguments and overlay identity',function()
 local _,a,_,button=fixture();local target=button(73);local effect={type='texture',texture='fixture-texture'};local color={r=0};local index=a.Functions.collections.index;local calls=0
 assert(a.index==index,'fixture must start with the real direct alias');poison(a)
 a.Functions.collections.index=function(...) assert(select('#',...)==2 and select(1,...)==a.textured_types and select(2,...)=='texture','Glow index receiver or table changed');calls=calls+1;return index(...) end
 local r=pack(a:Glow(target,'preview',effect,color,1.5,'TOP',2,-3,.25));local overlay=assert(target.rmOverlays and target.rmOverlays.preview,'textured Glow did not create actual overlay')
 assert(r.n==0 and calls==1 and overlay:IsShown() and overlay:GetParent()==target and overlay:GetWidth()==63 and overlay:GetHeight()==45,'Glow return/parent/scale changed')
 assert(overlay.point[1]=='CENTER' and overlay.point[2]==target and overlay.point[3]=='TOP' and overlay.point[4]==2 and overlay.point[5]==-3 and overlay:GetFrameStrata()=='FULLSCREEN_DIALOG' and overlay:GetFrameLevel()==21)
 assert(overlay.texture.texture=='fixture-texture' and overlay.texture.rotation==.25 and table.concat(overlay.texture.color,',')=='0,0.3,0.4,0.5','actual appearance changed')
 assert(effect.type=='texture' and effect.texture=='fixture-texture' and color.r==0 and color.g==nil,'Glow materialized inherited color in caller data')
 a.Functions.collections.index=function(...) assert(select('#',...)==2 and select(1,...)==a.textured_types);return nil end
 a:Glow(target,'preview',effect,color,1.5,'TOP',2,-3,.25);assert(target.rmOverlays.preview==overlay and not overlay:IsShown() and calls==1,'Glow cached canonical index or replaced overlay identity')
end)
test('Glow preserves the first pairs match including false keys rather than a membership rewrite',function()
 local f,a,calls,button=fixture();local target=button(73);local types={[false]='texture',named='texture'};a.textured_types=types
 local order={false,'named'};local ordinary=pairs
 f.env.pairs=function(array)
  if array~=types then return ordinary(array) end
  local at=0;return function() at=at+1;local key=order[at];if key~=nil then return key,array[key] end end
 end
 f.load('Functions/collections.lua');poison(a)
 a:Glow(target,'first',{type='texture',texture='fixture'},nil,1,'CENTER',0,0);assert(not target.rmOverlays and #calls.pixel==0,'false first match became a truthy membership result')
 order={'named',false};a:Glow(target,'first',{type='texture',texture='fixture'},nil,1,'CENTER',0,0);assert(target.rmOverlays.first:IsShown(),'first truthy match did not select texture route')
end)
test('actual discovery and HighlightSlots preserve false and zero keys selected identities and clearing',function()
 local f,a,calls,button=fixture();local first=button(73);local second=button(74);local nonAction=button(nil,'spell');f.env.ActionButton1,f.env.ActionButton2,f.env.ActionButton3=first,second,nonAction
 a:Fetch();assert(a:FindSpell({133})==133,'actual discovery failed');local nested={};local slots={[false]=73,[0]=74,nested=nested};local index=a.Functions.collections.index;local results={};poison(a)
 a.Functions.collections.index=function(...)
  assert(select('#',...)==2,'Highlight/Glow added a helper receiver');local array,value=...
  assert(array==slots or array==a.textured_types,'selection copied caller table')
  local key=index(array,value);if array==slots then results[value]=key end;return key
 end
 assert(pack(a:HighlightSlots(slots)).n==0 and results[73]==false and results[74]==0,'slot selection used truthiness instead of ~=nil')
 for _,selected in ipairs({first,second}) do local overlay=assert(selected.rmOverlays and selected.rmOverlays.highlight,'selected action has no actual overlay');assert(overlay:IsShown() and overlay:GetParent()==selected and overlay.texture.texture=='Interface\\Cooldown\\star4' and table.concat(overlay.texture.color,',')=='1,0,0,1','selected identity or highlight appearance changed');assert(overlay.sequenceTimer and calls.timers[overlay.sequenceTimer],'highlight timer was not owned') end
 assert(not nonAction.rmOverlays and slots[false]==73 and slots[0]==74 and slots.nested==nested,'non-action was highlighted or caller data changed')
 a.Functions.collections.index=index;a:HighlightSlots({});for _,selected in ipairs({first,second}) do assert(not selected.rmOverlays.highlight:IsShown() and not selected.rmOverlays.highlight.sequenceTimer,'outgoing highlight was not cleared') end;assert(next(calls.timers)==nil)
 a:HighlightSlots(nil);assert(not first.rmOverlays.highlight:IsShown(),'nil slot list selected a prior action')
end)
test('button consumers preserve canonical errors and live lookup for slot selection',function()
 local f,a,_,button=fixture();local target=button(73);f.env.ActionButton1=target;a:Fetch();poison(a)
 local slots={73};a.Functions.collections.index=function(array,value) if array==slots then return nil end;error('unexpected type lookup') end
 a:HighlightSlots(slots);assert(not target.rmOverlays,'HighlightSlots captured old canonical index')
 a.Functions.collections.index=function() error('CANONICAL_INDEX_ERROR') end
 for _,fn in ipairs({function() a:Glow(target,'error',{type='texture'},nil,1,'CENTER',0,0) end,function() a:HighlightSlots(slots) end}) do local ok,why=pcall(fn);assert(not ok and tostring(why):find('CANONICAL_INDEX_ERROR',1,true),'canonical error changed') end
 assert(pack(a:Glow(target,'none',nil)).n==0,'nil effect stopped returning without a lookup')
end)
finish()
