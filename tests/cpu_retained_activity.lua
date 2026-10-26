local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local priorInverse=dofile('tests/fixtures/restore_cpu_retained_activity.lua')
local function inverse(text,path)return priorInverse(dofile('tests/fixtures/parser_string_history.lua')(text,path),path)end
local function once(s,a,b)local i,j=assert(s:find(a,1,true));assert(not s:find(a,j+1,true));return s:sub(1,i-1)..b..s:sub(j+1)end
local text=read('tests/cpu.lua');text=text:sub(1,assert(text:find("test('module is idle",1,true))-1)
text=once(text,'local function fixture(historical,prePrivate)','local function fixture(configure,old)')
text=once(text," if prePrivate then loadPrePrivateCPU(f)elseif historical then loadHistoricalCPU(f)else local file=io.open('Diagnostics/cpu.lua');if file then file:close();f.load('Diagnostics/cpu.lua')end end",[[ if configure then configure(f,a,s)end
 if old then local chunk=assert(loadstring(INVERSE(READ('Diagnostics/cpu.lua'),'Diagnostics/cpu.lua'),'@Diagnostics/cpu.lua'));setfenv(chunk,e);chunk('rotationmaster',a)else f.load('Diagnostics/cpu.lua')end]])
local make=assert(loadstring('local READ,INVERSE=...\n'..text..'return fixture','@activity-cpu-fixture'))(read,inverse)
local function has(s,x)assert(type(s)=='string'and s:find(x,1,true),'missing '..x..': '..tostring(s))end
local function absent(s,x)assert(not s:find(x,1,true),'unexpected '..x)end
local function count(s,fn)local n=0;for _,q in ipairs(s.queries)do if q[1]==fn then n=n+1 end end;return n end
local function native(f,a,s)
 s.frames=dofile('tests/fixtures/native_ui.lua')(f.env);local create=f.env.CreateFrame
 f.env.CreateFrame=function(...)local w=create(...);w.events={}
  function w:RegisterEvent(event)self.events[event]=true end
  function w:UnregisterAllEvents()self.events={}end
  function w:IsVisible()local x=self;while x do if not x:IsShown()then return false end;x=x:GetParent()end;return true end
  return w
 end
 s.fire=function(event,...)for _,w in ipairs(s.frames)do if w.events and w.events[event] and w.scripts.OnEvent then w.scripts.OnEvent(w,event,...)end end end
 s.listeners=function()local n=0;for _,w in ipairs(s.frames)do if w.events and next(w.events)then n=n+1 end end;return n end
end
local function fixture(configure,old)
 local f,a,s=make(function(f,a,s)native(f,a,s);if configure then configure(f,a,s)end end,old)
 f.env.C_Spell={GetSpellInfo=function(id)return {name='SECRET_SOURCE_TEXT spell '..id,spellID=id,iconID=1}end,GetSpellLink=function(id)return '|Hspell:'..id..'|h[Spell]|h'end}
 f.env.C_Item={GetItemInfo=function(id)return 'SECRET_SOURCE_TEXT item '..id,'|Hitem:'..id..'|h[Item]|h',nil,nil,nil,nil,nil,nil,nil,1 end}
 f.load('Platform/spells.lua');f.load('Core/spell_catalog.lua');f.load('Core/reference_catalog.lua');a.bagContents={}
 return f,a,s
end
local function capture(f,a,s)assert(a:StartCPUProfile());s:complete();return a:GetCPUProfileReport()end
local heading='Retained catalogs and animation activity (capture only):'
local function split(s)local at=s:find('\n'..heading,1,true);return at and s:sub(1,at-1)or s,at and s:sub(at+1)end

test('actual retained maps and temporary global result listener report counts without source values',function()
 local f,a,s=fixture()
 f.libraries['AceAddon-3.0']={NewAddon=function(_,object)return object end};f.libraries['AceEvent-3.0']={};f.libraries['LibDBIcon-1.0']={};f.libraries['LibDataBroker-1.1']={NewDataObject=function()return {}end};f.libraries['ThreatClassic-1.0']={Disable=function()end}
 f.env.UnitGUID=function()return 'Player-PRIVATE'end;f.env.C_AddOns={GetAddOnMetadata=function(_,key)return key=='Title' and 'Rotation Master' or 'test'end};f.load('main.lua');a.debug=function()end
 assert(s.listeners()==0);assert(a:StartCPUProfile());assert(s.listeners()==1,'capture event observer absent')
 for id=1,1000 do a:SPELL_DATA_LOAD_RESULT('SPELL_DATA_LOAD_RESULT',id,true);a:ITEM_DATA_LOAD_RESULT('ITEM_DATA_LOAD_RESULT',id,true);s.fire('SPELL_DATA_LOAD_RESULT',id,true);s.fire('ITEM_DATA_LOAD_RESULT',id,true)end
 for id=1,1000 do a.SpellCatalog:UpdateSpell(id);a:UpdateReferenceItem(id)end
 s.fire('ITEM_DATA_LOAD_RESULT',9,false);s:complete();assert(s.listeners()==0)
 local report=a:GetCPUProfileReport();has(report,heading);has(report,'spell IDs: start=0; end=1000; change=1000');has(report,'item index: start=0; end=1000; change=1000');has(report,'metadata successes: spell=1000; item=1000');absent(report,'SECRET_SOURCE_TEXT');absent(report,'|Hitem:')
end)
test('retained counts cap map iteration and never fabricate a capped growth difference',function()
 local _,a,s=fixture();for id=1,4097 do a.SpellCatalog:UpdateSpell(id);a:UpdateReferenceItem(id)end
 local report=capture(nil,a,s);has(report,'spell IDs: start=>=4096; end=>=4096; change=unavailable');has(report,'item index: start=>=4096; end=>=4096; change=unavailable')
end)
test('event observer retires on cancel scheduling error disable and stale callbacks',function()
 local _,a,s=fixture();assert(a:StartCPUProfile());local old=s.timers[1];assert(s.listeners()==1);a:CancelCPUProfile();assert(s.listeners()==0);assert(a:StartCPUProfile());old.callback();assert(s.listeners()==1);a:OnDisable();assert(s.listeners()==0)
 local _,a,s=fixture();s.scheduleError=true;assert(not a:StartCPUProfile());assert(s.listeners()==0)
end)
test('missing owners and changed anchors remain separate unavailable views',function()
 local _,a,s=fixture();assert(a:StartCPUProfile());a.SpellCatalog={UpdateSpell=function()error('replacement invoked')end};s:complete();has(a:GetCPUProfileReport(),'spell IDs: start=0; end=unavailable; change=unavailable');has(a:GetCPUProfileReport(),'item index: start=0; end=0; change=0')
end)
test('old report prefix and every prior native query remain exact',function()
 local f,a,s=fixture(nil,true);local old=capture(f,a,s);local oldQueries=#s.queries
 local f,a,s=fixture();local current=capture(f,a,s);local prefix,appendix=split(current);assert(appendix,'activity appendix absent');assert(prefix==old,'old CPU report changed');assert(#s.queries==oldQueries,'unavailable visuals created native samples')
end)

local function visuals(countButtons)
 local f,a,s=fixture(function(f,a,s)
  local e=f.env;local original=e.LibStub
  e.LibStub=setmetatable({GetLibrary=function(_,name)return f.libraries[name]end},{__call=function(_,...)return original(...)end})
  s.callbacks={pixel=function()error('animation callback executed')end,autocast=function()error('animation callback executed')end,blizzard=function()error('animation callback executed')end}
  local glow={};s.glow=glow
  local function start(name,key)
   return function(button,_,_,_,_,_,_,_,_,id)
    local slot=key..tostring(id or '');local frame=e.CreateFrame('Frame',nil,button);frame:SetScript('OnUpdate',s.callbacks[name]);button[slot]=frame
   end
  end
  glow.PixelGlow_Start=start('pixel','_PixelGlow');glow.AutoCastGlow_Start=function(button,_,_,_,_,_,_,id)local frame=e.CreateFrame('Frame',nil,button);frame:SetScript('OnUpdate',s.callbacks.autocast);button['_AutoCastGlow'..tostring(id or '')]=frame end
  glow.ButtonGlow_Start=function(button)local frame=e.CreateFrame('Frame',nil,button);frame:SetScript('OnUpdate',s.callbacks.blizzard);button._ButtonGlow=frame end
  glow.PixelGlow_Stop=function(button,id)local x=button['_PixelGlow'..tostring(id or '')];if x then x:Hide()end end
  glow.AutoCastGlow_Stop=function(button,id)local x=button['_AutoCastGlow'..tostring(id or '')];if x then x:Hide()end end
  glow.ButtonGlow_Stop=function(button)if button._ButtonGlow then button._ButtonGlow:Hide()end end
  f.libraries['LibCustomGlow-1.0']=glow
  e.C_AddOns={IsAddOnLoaded=function()return false end,GetAddOnMetadata=function(_,field)return field=='Title' and 'Rotation Master' or 'test'end}
  e.tinsert=table.insert;e.tremove=table.remove;e.HasAction=function()return true end;e.GetActionInfo=function(slot)return 'spell',1000+slot end
  local create=e.CreateFrame;e.CreateFrame=function(...)local w=create(...);local texture=w.CreateTexture;w.CreateTexture=function(...)local t=texture(...);t.SetBlendMode=function()end;t.SetRotation=function()end;return t end;return w end
  s.buttons={};for i=1,countButtons or 4 do local w=e.CreateFrame('Button',nil,e.UIParent);local slot=i;function w:GetAttribute(key)if key=='type'then return 'action'elseif key=='action'then return slot end end;s.buttons[i]=w;if i<=12 then e['ActionButton'..i]=w else s.extra=s.extra or {};s.extra[#s.extra+1]=w end end
  a.debug=function()end;a.verbose=function()end
  a.ScheduleRepeatingTimer=function(_,fn,delay,...)local token={fn=fn,delay=delay,args={...}};s.repeating=s.repeating or {};s.repeating[#s.repeating+1]=token;return token end
 end)
 f.load('buttons.lua');if s.extra then a:RegisterButtonProvider('test-bars',function(add)for _,w in ipairs(s.extra)do add(w)end end)end;a.db.profile.effect='pulse';a.db.global.effects={pulse={type='pulse',texture='Texture',sequence={.8,1},frequency=.1},pixel={type='pixel'},autocast={type='autocast'},blizzard={type='blizzard'}}
 a:Fetch()
 return f,a,s
end
local function cooldown(a,id,effect)a:GlowCooldown(id,true,{id='PRIVATE_SOURCE_KEY',effect=effect})end

test('actual button pipeline selects exact overlay and associated shared callbacks without executing them',function()
 local f,a,s=visuals();a:GlowSpell(1001);cooldown(a,1002,'pixel');cooldown(a,1003,'autocast');cooldown(a,1004,'blizzard')
 assert(a:StartCPUProfile());for _,name in ipairs({'pixel','autocast','blizzard'})do assert(count(s,s.callbacks[name])==2,'shared callback missing '..name);s.rows[s.callbacks[name]]={{0,0,0},{1,2,4}}end
 s:complete();local report=a:GetCPUProfileReport();has(report,'RM.UpdateOverlay | exclusive=');has(report,'sequence=1');has(report,'pixel=1 autocast=1 blizzard=1');has(report,'SharedGlow.Pixel.OnUpdate | exclusive=1.000 ms | inclusive=2.000 ms | calls=4');has(report,'shared callback counters include all callers');has(report,'aliases=4; available=4; unavailable=0');absent(report,'PRIVATE_SOURCE_KEY')
 for _,name in ipairs({'pixel','autocast','blizzard'})do assert(count(s,s.callbacks[name])==4,'duplicate callback query')end
end)
test('animation views alias old rows and one another without changing ranking reference validity',function()
 local f,a,s=visuals();s.callbacks.autocast=s.callbacks.pixel;a.EvaluateNextAction=s.callbacks.pixel;a.EvaluateNextActionInternal=s.callbacks.pixel;cooldown(a,1001,'pixel');cooldown(a,1002,'autocast')
 assert(a:StartCPUProfile());assert(count(s,s.callbacks.pixel)==2);s:complete();assert(count(s,s.callbacks.pixel)==4);has(a:GetCPUProfileReport(),'aliases=4; available=3; unavailable=1')
end)
test('foreign inactive frames and hidden parents are excluded while stopped start callbacks stay measurable',function()
 local f,a,s=visuals();local foreign=f.env.CreateFrame('Frame',nil,s.buttons[2]);foreign:SetScript('OnUpdate',s.callbacks.pixel);s.buttons[2]._PixelGlownext=foreign
 cooldown(a,1001,'pixel');assert(a:StartCPUProfile());assert(count(s,s.callbacks.pixel)==2);a:GlowCooldown(1001,false);s.buttons[1]:Hide();s:complete();assert(count(s,s.callbacks.pixel)==4);local report=a:GetCPUProfileReport();has(report,'end visuals:');has(report,'pixel=0');has(report,'SharedGlow.Pixel.OnUpdate | exclusive=')
 local f,a,s=visuals();local report=capture(f,a,s);assert(count(s,s.callbacks.pixel)==0);has(report,'SharedGlow.Pixel.OnUpdate | unavailable: no-start-callback')
end)
test('end-only callback has no retroactive baseline and ordinary report reads do no collection',function()
 local f,a,s=visuals();assert(a:StartCPUProfile());cooldown(a,1001,'pixel');s:complete();assert(count(s,s.callbacks.pixel)==0);has(a:GetCPUProfileReport(),'no-start-callback');local n=#s.queries;local frames=#s.frames
 for _=1,20 do a:GetCPUProfileReport();a:IsCPUProfileRunning()end;assert(#s.queries==n and #s.frames==frames and s.listeners()==0)
end)
test('sample cap and source-owner changes affect only optional animation views',function()
 local f,a,s=visuals();for i=1,512 do a.conditionDefinitions['COND_'..i]={evaluate=function()end,valid=function()end}end;cooldown(a,1001,'pixel');local report=capture(f,a,s);has(report,'selected=384;');has(report,'RM.UpdateOverlay | unavailable: selection-limit');assert(#s.queries<=1536)
 local f,a,s=visuals();cooldown(a,1001,'pixel');assert(a:StartCPUProfile());s.glow.PixelGlow_Start=function()error('replacement invoked')end;s:complete();has(a:GetCPUProfileReport(),'SharedGlow.Pixel.OnUpdate | unavailable: source-reader-changed');has(a:GetCPUProfileReport(),'Private helper views: aliases=2; available=2; unavailable=0')
end)
test('synchronous completion and reentrant later capture cannot retain an event subscription',function()
 local f,a,s=fixture();a.ScheduleTimer=function(_,callback)callback();return {}end;s.now=110;s.total={10,50}
 -- Advance clock only once the scheduler runs, preserving a positive interval.
 a.ScheduleTimer=function(_,callback)s.now=120;s.phase='finish';callback();return {}end
 assert(a:StartCPUProfile());assert(not a:IsCPUProfileRunning() and s.listeners()==0);assert(a:GetCPUProfileReport()==nil,'existing synchronous report lifecycle changed')
end)

test('ambiguous shared callback variants never guess and cannot poison an existing row',function()
 local f,a,s=visuals();local first=s.callbacks.pixel;a.EvaluateNextAction=first;cooldown(a,1001,'pixel');s.callbacks.pixel=function()error('second variant invoked')end;cooldown(a,1002,'pixel')
 local report=capture(f,a,s);has(report,'SharedGlow.Pixel.OnUpdate | unavailable: ambiguous-callback');assert(count(s,first)==4 and count(s,s.callbacks.pixel)==0,'ambiguous view sampled or poisoned old row')
end)
test('hidden pulse handles remain counted independently from visible overlays',function()
 local f,a,s=visuals();a:GlowSpell(1001);s.buttons[1]:Hide();local report=capture(f,a,s);has(report,'overlays=0 sequence=1');has(report,'sequence counts timer handles regardless of visibility, not measured executions')
end)
test('Proc native animation association has no fabricated Lua callback row',function()
 local f,a,s=visuals();a.db.global.effects.proc={type='proc'};a.db.profile.effect='proc';a.GetProcGlowSupport=function()return true end
 s.glow.ProcGlow_Start=function(button,options)button['_ProcGlow'..options.key]=f.env.CreateFrame('Frame',nil,button)end
 s.glow.ProcGlow_Stop=function()end;a:GlowSpell(1001);local report=capture(f,a,s);has(report,'proc=1');has(report,'Proc uses native animations');absent(report,'SharedGlow.Proc.OnUpdate')
end)
test('visual scan stops at its slot budget without traversing global frame pools',function()
 local f,a,s=visuals(100);for i=1,100 do a:GlowSpell(1000+i);cooldown(a,1000+i,'pixel')end
 local report=capture(f,a,s);has(report,'slots=512');has(report,'capped=true');assert(#s.queries<=1536)
end)
test('exact4096 remains exact and trusted map iteration is bounded without result snapshots',function()
 local calls=0;local f,a,s=fixture(function(f)f.env.next=function(...)calls=calls+1;return next(...)end end)
 for i=1,4096 do a.SpellCatalog:UpdateSpell(i);a:UpdateReferenceItem(i)end
 local report=capture(f,a,s);has(report,'spell IDs: start=4096; end=4096; change=0');assert(calls<=4097*5*2,'reader walked beyond fixed map budgets')
end)
test('unknown success and absent event capability remain honest without source details',function()
 local f,a,s=fixture();local opaque={};f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end
 assert(a:StartCPUProfile());s.fire('SPELL_DATA_LOAD_RESULT',999,opaque);s.fire('ITEM_DATA_LOAD_RESULT',999,nil);s:complete();has(a:GetCPUProfileReport(),'metadata successes: spell=0; item=0; unknown=2')
 local f,a,s=fixture(function(f)f.env.CreateFrame=nil end);local report=capture(f,a,s);has(report,'metadata successes: unavailable');has(report,'item index: start=0; end=0; change=0')
end)
test('current producer handoffs are one shot and foreign or replacement installers do not execute',function()
 local _,a,s=fixture();assert(type(a.BindCPUActivityDiagnostic)=='function');local called=0
 assert(not a:BindCPUActivityDiagnostic('spell',function()called=called+1 end));assert(not a.BindCPUActivityDiagnostic({},'visual',function()called=called+1 end));assert(a:StartCPUProfile());assert(a.BindCPUActivityDiagnostic==nil);s:complete();assert(called==0)
end)
test('complete report budget preserves prior oversized text and never partially appends activity',function()
 for _,power in ipairs({180,220,308})do
  local function configure(_,a,s)for i=1,30 do local key=string.format('HOT_%02d',i);local fn=function()end;a.conditionDefinitions[key]={evaluate=fn,valid=fn};s.rows[fn]={{0,0,0},{10^power,10^power,3}}end end
  local f,a,s=fixture(configure,true);local old=capture(f,a,s)
  local f,a,s=fixture(configure);local report=capture(f,a,s);local prefix,appendix=split(report)
  if power==308 then assert(#old>=16000 and report==old,'oversized report changed')
  elseif appendix then assert(prefix==old and #report<16000)else local footer='\nRetained activity omitted to keep report bounded.';if report:sub(-#footer)==footer then assert(report:sub(1,-#footer-1)==old and #report<16000)else assert(report==old)end end
 end
end)
test('replaced observer callback is not overwritten on cleanup or subsequent capture',function()
 local _,a,s=fixture();assert(a:StartCPUProfile());local observer
 for _,frame in ipairs(s.frames)do if frame.events and frame.events.SPELL_DATA_LOAD_RESULT then observer=frame end end
 local original=observer.scripts.OnEvent;local foreign=function()end;observer:SetScript('OnEvent',foreign)
 a:CancelCPUProfile();assert(observer:GetScript('OnEvent')==foreign);assert(a:StartCPUProfile());assert(observer:GetScript('OnEvent')==foreign);original(observer,'SPELL_DATA_LOAD_RESULT',1,true);s:complete();has(a:GetCPUProfileReport(),'metadata successes: spell=0; item=0')
end)


test('exact four new callback samples add at most sixteen queries while old report remains byte exact',function()
 local function run(old)
  local f,a,s=visuals();if old then f.load=function(path)local chunk=assert(loadstring(inverse(read(path),path),'@'..path));setfenv(chunk,f.env);return chunk('rotationmaster',a)end;f.load('Diagnostics/cpu.lua')end
  a:GlowSpell(1001);cooldown(a,1002,'pixel');cooldown(a,1003,'autocast');cooldown(a,1004,'blizzard');local overlay=s.repeating[1].fn;s.rows[overlay]={{0,0,0},{3,5,7}}
  local report=capture(f,a,s);return report,s,overlay
 end
 local old,os=run(true);local report,s,overlay=run(false);local prefix,appendix=split(report);assert(prefix==old and appendix);assert(#s.queries==#os.queries+16,'four optional pointers exceeded sixteen extra queries');assert(count(s,overlay)==4)
 has(report,'RM.UpdateOverlay | exclusive=3.000 ms | inclusive=5.000 ms | calls=7')
end)
test('retained item records can shrink while prior index and blocked observations remain distinct',function()
 local f,a,s=fixture();a:UpdateReferenceItem(1);assert(a:StartCPUProfile());f.env.C_Item.GetItemInfo=function()error('SECRET_SOURCE_TEXT')end;a:UpdateReferenceItem(1);s:complete();local report=a:GetCPUProfileReport()
 has(report,'item records: start=1; end=0; change=-1');has(report,'item index: start=1; end=1; change=0');has(report,'blocked items: start=0; end=1; change=1');absent(report,'SECRET_SOURCE_TEXT')
end)
test('completion callback can start a fresh run without stale event callbacks touching its counters',function()
 local _,a,s=fixture();assert(a:StartCPUProfile());local callback
 for _,frame in ipairs(s.frames)do if frame.events and frame.events.SPELL_DATA_LOAD_RESULT then callback=frame.scripts.OnEvent end end
 a.OnCPUProfileFinished=function()a.OnCPUProfileFinished=nil;assert(a:StartCPUProfile())end
 s:complete();assert(a:IsCPUProfileRunning()and s.listeners()==1);callback(nil,'SPELL_DATA_LOAD_RESULT',99,true);s.fire('ITEM_DATA_LOAD_RESULT',1,true);s:complete();assert(s.listeners()==0);has(a:GetCPUProfileReport(),'metadata successes: spell=0; item=1')
end)
finish()
