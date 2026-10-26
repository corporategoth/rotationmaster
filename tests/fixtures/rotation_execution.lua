-- Actual scoped main with TOC-order private handoffs and native raw globals.
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function once(text,old,new)local a,b=text:find(old,1,true);assert(a,'fixture anchor missing '..old);assert(not text:find(old,b+1,true),'fixture anchor repeated');return text:sub(1,a-1)..new..text:sub(b+1)end
local startup=read('tests/startup.lua')
local common=assert(startup:match('(local function fixture%(modern, absentThreat%).-)\ntest%('))
local persistent=assert(startup:match('(local function persistentFixture%(saved,folder,scoped%).-)\n%-%- WoW SavedVariables'))
-- Model TOC order: owned Data and sequence exist before main captures its reader.
-- Avoid rotation_data.lua's asserting __index global shim in the native model.
common=once(common,'    env._G = env','    env._G = env\n    for _,key in ipairs({"type","pairs","ipairs","next","rawget","rawset","rawequal","getmetatable","getfenv","math","table","string","tonumber","tostring","unpack","select","pcall","error","assert"})do rawset(env,key,_G[key])end')
persistent=once(persistent,"    load('main.lua')\n",'')
persistent=once(persistent,'    local data,envelope=make();addon.RotationData=data',"    local _,envelope=make();addon.RotationData={}\n    load('Data/plain.lua');load('Data/rotation_revision.lua');load('Data/tags.lua');load('Data/rotation_tree.lua');load('Data/validation.lua')\n    local data=addon.RotationData")
persistent=once(persistent,'    addon.GetRotationContext=function()',"    load('Core/rotation_sequence.lua');load('main.lua')\n    addon.GetRotationContext=function()")
persistent=once(persistent,"load('Core/rotation_library.lua')","load('Core/rotation_choice_preferences.lua');load('Core/rotation_library.lua')")
local makePersistent=assert(loadstring(common..'\n'..persistent..'\nreturn persistentFixture','@external-toc-ordered-runtime'))()
local source=[====[local function make(options)
 local e,a,_,_,_,_,load=fixture();load('Core/rotation_sequence.lua');local native={};local phase;local trace={};local cacheIDs=setmetatable({},{__mode='k'});local cacheCount=0
 local function hit(name,...)
  native[name]=(native[name] or 0)+1
  if not phase then return end
  local cacheID='direct';local cacheFunction='';local origin=''
  for level=2,18 do
   local info=debug.getinfo(level,'Slnf');if not info then break end
   if info.source=='@Functions/cache.lua' then
    local cached,fn
    for index=1,12 do local key,value=debug.getlocal(level,index);if not key then break end;if key=='cache' then cached=value elseif key=='func' then fn=value end end
    if type(cached)=='table' and type(fn)=='function' then
     if not cacheIDs[cached] then cacheCount=cacheCount+1;cacheIDs[cached]=cacheCount end
     cacheID='cache'..cacheIDs[cached];local descriptor=debug.getinfo(fn,'S');cacheFunction=(descriptor.source or '?')..':'..descriptor.linedefined;break
    end
   end
  end
  local caller=debug.getinfo(3,'Sl');origin=(caller and caller.source or '?')..':'..(caller and caller.currentline or 0)
  local key=phase..' '..name..'('..tostring((...))..') '..cacheID..' via '..cacheFunction..' immediate '..origin;trace[key]=(trace[key] or 0)+1
 end
 local target,combat=options.target==true,options.combat==true
 local f=dofile('tests/fixtures/addon.lua').new(5,1,'SHAMAN');for k,v in pairs(f.env) do if rawget(e,k)==nil and k~='_G' and k~='LibStub' then e[k]=v end end
 local originalLib=e.LibStub;local originalCall=getmetatable(originalLib).__call;setmetatable(originalLib,{__call=function(self,name,silent) if self.libs and self.libs[name] then return self:GetLibrary(name,silent) end;if name=='LibRangeCheck-3.0' then return f.env.LibStub(name,silent) end;if name=='LibCustomGlow-1.0' then return {PixelGlow_Stop=function() end,AutoCastGlow_Stop=function() end,ButtonGlow_Stop=function() end} end;return originalCall(self,name,silent) end})
 e.UnitExists=function(unit) hit('UnitExists',unit);return unit=='player' or target and unit=='target' end
 e.UnitGUID=function(unit) hit('UnitGUID',unit);return unit=='player' and 'Player-1' or target and unit=='target' and 'Creature-1' or nil end
 e.UnitClass=function() hit('UnitClass');return 'Shaman','SHAMAN',7 end
 e.UnitLevel=function() hit('UnitLevel');return 11 end;e.UnitHasVehicleUI=function() hit('UnitHasVehicleUI');return false end
 e.UnitName=function(unit) hit('UnitName',unit);return unit=='player' and 'Fixture' or 'Target' end
 e.UnitCanAttack=function(_,unit) hit('UnitCanAttack',unit);return target and unit=='target' end
 e.UnitIsEnemy=e.UnitCanAttack;e.UnitIsDead=function() hit('UnitIsDead');return false end;e.UnitAffectingCombat=function(unit) hit('UnitAffectingCombat',unit);return combat end
 e.GetUnitSpeed=function() hit('GetUnitSpeed');return 0 end;e.GetWeaponEnchantInfo=function() hit('GetWeaponEnchantInfo');return true,1000,1 end
 e.C_UnitAuras={GetAuraDataByIndex=function() hit('GetAuraDataByIndex');return nil end}
 e.IsSpellKnown=function() hit('IsSpellKnown');return true end
 e.C_Spell={GetSpellInfo=function(id) hit('GetSpellInfo');return {spellID=id,name='Spell '..id,iconID=1} end,GetSpellLink=function(id) return 'spell:'..id end,GetSpellCooldown=function() hit('GetSpellCooldown');return {startTime=0,duration=0,isEnabled=true,modRate=1} end,IsSpellUsable=function() hit('IsSpellUsable');return true,false end,SpellHasRange=function() hit('SpellHasRange');return true end,IsSpellInRange=function() hit('IsSpellInRange');return true end,IsCurrentSpell=function() return false end}
 e.GetTime=function() hit('GetTime');return 100 end
 for _,name in ipairs({'GetLocale','GetBuildInfo','GetClassicExpansionLevel'}) do local fn=e[name];if type(fn)=='function' then e[name]=function(...) hit(name);return fn(...) end end end
 for _,path in ipairs({'Platform/rotation_owner.lua','Platform/spells.lua','Platform/actions.lua','Platform/range.lua','Platform/unit_flags.lua','Platform/unit_attackability.lua','Platform/player_movement.lua','Platform/auras.lua','Core/aura_conditions.lua','Core/spell_catalog.lua','Diagnostics/errors.lua'}) do load(path) end
 -- Actual authored registry, no synthetic expansion of definition count.
 for path in io.lines('RotationMaster.toc') do if path:match('^Conditions/') then load(path) end end
 -- The common startup fixture overrides context for unrelated tests. Restore
 -- the actual original function identity from the already-bound private reader.
 local nativeContext
 for i=1,20 do local name,value=debug.getupvalue(a.GetRotationOwnerContext,i);if not name then break end
  if name=='libraryReader' then for j=1,10 do local key,entry=debug.getupvalue(value.OwnsContext,j);if not key then break end;if key=='ownedRotationContext' then nativeContext=entry end end end
 end
 assert(type(nativeContext)=='function');a.GetRotationContext=nativeContext
 load('tests/fixtures/shaman_starter_pack.lua');assert(a:InitializeRotationLibrary())
 local id,why=a:CloneDefaultRotation(0,'rm.tbc.shaman.starter','Copy of Shaman: early leveling',{scope='class'});assert(id,why);a.currentRotation=id;a.currentSpec=0
 a.configWindow=nil;a.currentConditionEval=nil;a.nextWindow=nil;a.db.profile.preview_spells=0;a.db.profile.disable_buttons=false
 a.units={player='Player',pet='Pet',target='Target',mouseover='Mouseover',pettarget='Pet target',targettarget='Target target',mouseovertarget='Mouseover target',focus='Focus',focustarget='Focus target'}
 a.inCombat=combat;a.avail_announced={};a.announced={};a.skipAnnounce=true;a.lastCacheReport=100
 e.WeakAuras=nil;e.LibStub('AceEvent-3.0').SendMessage=function() hit('SendMessage') end
 a.IsGlowing=function() return true end;a.GlowNextSpell=function() hit('GlowNextSpell') end;a.GlowClear=function() hit('GlowClear') end;a.GlowCooldown=function() hit('GlowCooldown') end;a.DispatchAnnouncement=function() hit('Announcement') end
 a.FindSpell=function(_,ids) return ids[1] end -- external action-bar mapping, stable populated bar
 -- tick() is the evaluation poll. The auto-switch interval timer (234d62c6) is a second repeating timer and must not replace it.
 local timed;a.ScheduleRepeatingTimer=function(_,method,delay) local timer={method=method,delay=delay};if method~='AutoSwitchTimer' then timed=timer end;return timer end;a.CancelTimer=function(_,timer) if timer==nil or timer==timed then timed=nil end end
 if options.preview or options.buttons then
  dofile('tests/fixtures/native_ui.lua')(e);a.SetUIScript=f.addon.SetUIScript;load('UI/controls.lua')
 end
 if options.preview then
  load('UI/preview.lua');a.db.profile.preview_spells=options.preview;local window=a:CreateNativePreviewWindow()
  for _,name in ipairs({'ReleaseChildren','DoLayout','AddRecommendation'}) do local fn=window[name];window[name]=function(...) hit('Preview.'..name);return fn(...) end end
  local set=window.frame.SetSize;window.frame.SetSize=function(...) hit('Preview.frame.SetSize');return set(...) end
 end
 if options.buttons then
  local create=e.CreateFrame;e.CreateFrame=function(...) local frame=create(...);local texture=frame.CreateTexture;frame.CreateTexture=function(...) local t=texture(...);t.SetBlendMode=t.SetBlendMode or function() hit('Texture.SetBlendMode') end;t.SetRotation=t.SetRotation or function() hit('Texture.SetRotation') end;return t end;return frame end
  e.tinsert=table.insert;e.tremove=table.remove;e.HasAction=function(slot) return slot>=1 and slot<=4 end
  local ids={403,8042,324,8017};e.GetActionInfo=function(slot) hit('GetActionInfo');if options.macro and slot==1 then return 'macro',1 end;return 'spell',ids[slot] end
  e.GetMacroItem=function() hit('GetMacroItem');return nil,nil end;e.GetMacroSpell=function() hit('GetMacroSpell');return 403 end
  for i=1,4 do local slot=i;local button=e.CreateFrame('Button',nil,e.UIParent);button.action=i;button:SetSize(36,36);button.GetAttribute=function(_,key) if key=='type' then return 'action' elseif key=='action' then return slot end end;e['ActionButton'..i]=button end
  load('Platform/macros.lua');load('Core/presentation.lua');load('buttons.lua');a:Fetch()
 end
 a.db.profile.poll=options.poll or .15;a.db.profile.idle_poll=0;a:EnableRotationTimer()
 local function tick() if timed then a[timed.method](a) end end
 if options.inactive then a:DisableRotationTimer();a.currentRotation=nil end
 for i=1,5 do tick() end;assert(not a.adviceErrorReport,'real advice errored during warmup: '..a.Diagnostics:FormatReport(nil,true));assert(#a.Diagnostics:GetReports()==0,'warmup diagnostics')
 if options.exposed then assert(a:GetEditableRotation(0,id));for i=1,5 do tick() end end
]====]
source=once(source,"local e,a,_,_,_,_,load=fixture();load('Core/rotation_sequence.lua');","local e,a,_,_,_,_,load=fixture();load('Libs/AceAddon-3.0/AceAddon-3.0.lua');assert(e.LibStub('AceAddon-3.0'):NewAddon(a,'rotationmaster')==a);assert(type(getmetatable(a).__tostring)=='function');")
local hitStart=assert(source:find(' local function hit(name,...',1,true));local hitEnd=assert(source:find(' local target,combat=',hitStart,true))
source=source:sub(1,hitStart-1).." local tracking=false;local observed={}\n local function hit(name,...)native[name]=(native[name]or 0)+1;if tracking then local row={name};for i=1,select('#',...)do row[#row+1]=type(select(i,...))..':'..tostring(select(i,...))end;observed[#observed+1]=table.concat(row,'|')end end\n"..source:sub(hitEnd)
source=source.." return {a=a,e=e,tick=tick,load=load,reset=function(track)native={};observed={};tracking=track end,snapshot=function()return native,observed end}\nend\nreturn make"
local factory=assert(loadstring('local persistent=...\nlocal function fixture()local e,a,_,load=persistent(nil,nil,true);a.currentSpec=0;e.GetTime=function()return 100 end;a.lastCacheReport=100;return e,a,nil,nil,nil,nil,load end\n'..source,'@external-normalized-shaman-factory'))(makePersistent)
local restore=dofile('tests/fixtures/restore_rotation_execution_index.lua')
-- The predecessor sources are rebuilt only for a caller that asks for the old engine (the second argument below): a suite that
-- runs the current code must not depend on the byte-exact text of the files it never compares against a predecessor.
local frozen;local function predecessors()
if frozen then return frozen end
frozen={};for _,path in ipairs({'Core/rotation_sequence.lua','main.lua','Data/plain.lua','Data/rotation_tree.lua'})do local text=dofile('tests/fixtures/parser_string_history.lua')(read(path),path);if path=='Data/rotation_tree.lua'then text=dofile('tests/fixtures/restore_index_unsupported_binding.lua')(text)end;if path=='main.lua'then text=dofile('tests/fixtures/restore_cache_mode_initialization.lua')(text)end;frozen[path]=restore(dofile('tests/fixtures/restore_rotation_execution_diagnostics.lua')(text,path),path)end
return frozen
end
return function(options,old)
 local original=loadfile
 if old then local frozen=predecessors();_G.loadfile=function(path)if frozen[path]then return assert(loadstring(frozen[path],'@'..path))end;return original(path)end end
 local ok,c=pcall(factory,options or {});_G.loadfile=original;assert(ok,c)
 -- These suites state the contract of the standard engine (a live graph checked at every invocation, exact native query
 -- counts). The default lean engine reuses a compiled plan under its own contract: options.engine='lean' keeps it.
 if (options or {}).engine~='lean' then assert(c.a:SetEvaluationEngine('standard'),'standard engine unavailable') end
 assert(type(getmetatable(c.a).__tostring)=='function'and tostring(c.a)=='rotationmaster')
 assert(getfenv(c.a.EvaluateRotationSequence)==c.e,'wrong sequence owner environment')
 for _,key in ipairs({'type','pairs','ipairs','next','rawget','rawequal','getmetatable','getfenv','math','table','string'})do assert(rawget(c.e,key)==_G[key],'non-native raw model '..key)end
 return c
end
