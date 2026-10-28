-- Whole-poll fixture: the real addon in TOC order with WoW API models and the
-- Shaman starter clone selected. Adapted from the Codex whole-poll harness.
local measurement, snapshotRoot, candidateEnabled, productRoot, direct = ...
assert(measurement == 'trace' or measurement == 'price')

-- Actual scoped main with TOC-order private handoffs and native raw globals.
local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local function once(text, old, new)
    local a, b = text:find(old, 1, true)
    assert(a, 'fixture anchor missing ' .. old)
    assert(not text:find(old, b + 1, true), 'fixture anchor repeated')
    return text:sub(1, a - 1) .. new .. text:sub(b + 1)
end

local startup = read(snapshotRoot .. '/tests/startup.lua')
local common = assert(startup:match('(local function fixture%(modern, absentThreat%).-)\ntest%('))

local persistent = assert(startup:match(
    '(local function persistentFixture%(saved,folder,scoped[,%a]*%).-)\n%-%- WoW SavedVariables'
))

-- Model TOC order: owned Data and sequence exist before main captures its reader.
-- Avoid rotation_data.lua's asserting __index global shim in the native model.
common = once(
    common,
    '    env._G = env',
    '    env._G = env\n    for _,key in ipairs({"type","pairs","ipairs","next","rawget","rawset","rawequal","getmetatable","getfenv","math","table","string","tonumber","tostring","unpack","select","pcall","error","assert"})do rawset(env,key,_G[key])end'
)

-- Simulated native security APIs exist before any addon source, as in WoW.
common = once(
    common,
    '    env._G = env',
    [[    env._G = env
    env.issecretvalue=function()return false end
    env.canaccessvalue=function()return true end
    env.C_Secrets={HasSecretRestrictions=function()local observe=env.__reviewSecretObservation;if observe then observe('HasSecretRestrictions')end;return false end}
]]
)

persistent = once(persistent, "    load('main.lua')\n", '')

persistent = once(
    persistent,
    '    local data,envelope=make();addon.RotationData=data',
    "    local _,envelope=make();addon.RotationData={}\n    load('Data/plain.lua');load('Data/rotation_revision.lua');load('Data/tags.lua');load('Data/rotation_tree.lua');load('Data/validation.lua')\n    local data=addon.RotationData"
)

persistent = once(
    persistent,
    '    addon.GetRotationContext=function()',
    "    load('Core/rotation_sequence.lua');load('main.lua')\n    addon.GetRotationContext=function()"
)

persistent = once(
    persistent,
    "load('Core/rotation_library.lua')",
    "load('Core/rotation_choice_preferences.lua');load('Core/rotation_library.lua')"
)

persistent = once(
    persistent,
    "load('Core/conditions.lua');",
    "load('Data/builtin_sources.lua');load('Diagnostics/errors.lua');load('Core/conditions.lua');if candidateEnabled then load('Core/condition_runtime.lua')end;load('Platform/unit_level.lua');load('Core/level_conditions.lua');"
)

persistent = once(
    persistent,
    "if scoped then load('Core/rotation_scope.lua');",
    "if scoped then load('Platform/rotation_owner.lua');load('Core/rotation_scope.lua');"
)

persistent = once(
    persistent,
    "load('Core/rotation_sequence.lua');load('main.lua')",
    "load('Core/rotation_sequence.lua');if candidateEnabled then load('Core/active_runtime_plan.lua');addon.preparedRuntimeTrial=true end;load('main.lua')"
)

-- Actual TOC registers every stock condition once before addon initialization.
persistent = once(persistent, "load('Conditions/known_spell.lua');", '')
persistent = once(persistent, "load('Conditions/unit_states.lua');", '')
persistent = once(persistent, "    addon:OnInitialize()\n", '')

persistent = once(
    persistent,
    "load('Functions/cache.lua');load('Functions/trends.lua')",
    "load('Functions/cache.lua');load('Diagnostics/cache_mode.lua');load('Functions/trends.lua')"
)

local makePersistent = assert(loadstring(
    'local candidateEnabled=...\n' .. common .. '\n' .. persistent .. '\nreturn persistentFixture',
    '@external-toc-ordered-runtime'
))(candidateEnabled)

local source = [====[local function make(options)
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
 local clock=100;local auraPresent=false;local enchanted=false;local eventFrames={};local playerLevel=11;local playerClass='SHAMAN';local vehicle=false;local spellReady=true
 local f=dofile('tests/fixtures/addon.lua').new(5,1,'SHAMAN');for k,v in pairs(f.env) do if rawget(e,k)==nil and k~='_G' and k~='LibStub' then e[k]=v end end
 local originalLib=e.LibStub;local originalCall=getmetatable(originalLib).__call;setmetatable(originalLib,{__call=function(self,name,silent) if self.libs and self.libs[name] then return self:GetLibrary(name,silent) end;if name=='LibRangeCheck-3.0' then return f.env.LibStub(name,silent) end;if name=='LibCustomGlow-1.0' then return {PixelGlow_Stop=function() end,AutoCastGlow_Stop=function() end,ButtonGlow_Stop=function() end} end;return originalCall(self,name,silent) end})
 e.UnitExists=function(unit) hit('UnitExists',unit);return unit=='player' or target and unit=='target' end
 e.UnitGUID=function(unit) hit('UnitGUID',unit);return unit=='player' and 'Player-1' or target and unit=='target' and 'Creature-1' or nil end
 e.UnitClass=function(unit) hit('UnitClass',unit);return 'Shaman',playerClass,7 end
 e.UnitLevel=function(unit) hit('UnitLevel',unit);return playerLevel end;e.UnitHasVehicleUI=function(unit) hit('UnitHasVehicleUI',unit);return vehicle end
 e.UnitName=function(unit) hit('UnitName',unit);return unit=='player' and 'Fixture' or 'Target' end
 e.UnitCanAttack=function(_,unit) hit('UnitCanAttack',unit);return target and unit=='target' end
 e.UnitIsEnemy=function(_,unit) hit('UnitIsEnemy',unit);return target and unit=='target' end;e.UnitThreatSituation=function(_,unit) hit('UnitThreatSituation',unit);return nil end;e.UnitIsDead=function() hit('UnitIsDead');return false end;e.UnitAffectingCombat=function(unit) hit('UnitAffectingCombat',unit);return combat end
 e.GetUnitSpeed=function() hit('GetUnitSpeed');return 0 end;e.GetWeaponEnchantInfo=function() hit('GetWeaponEnchantInfo');return enchanted,1000,1 end
 e.C_UnitAuras={GetAuraDataByIndex=function(unit,index,filter) hit('GetAuraDataByIndex',unit,index,filter);if auraPresent and index==1 then return{name='Spell 324',spellId=324,sourceUnit='player',applications=1,duration=0,expirationTime=0}end end}
 assert(type(e.issecretvalue)=='function'and type(e.canaccessvalue)=='function'and type(e.C_Secrets.HasSecretRestrictions)=='function');e.__reviewSecretObservation=hit
 e.IsSpellKnown=function() hit('IsSpellKnown');return true end
 e.C_Spell={GetSpellInfo=function(id) hit('GetSpellInfo');return {spellID=id,name='Spell '..id,iconID=1} end,GetSpellLink=function(id) return 'spell:'..id end,GetSpellCooldown=function(id) hit('GetSpellCooldown',id);local ready=spellReady or id==29515 or id==61304;return {startTime=ready and 0 or clock,duration=ready and 0 or 30,isEnabled=true,modRate=1} end,IsSpellUsable=function() hit('IsSpellUsable');return true,false end,SpellHasRange=function() hit('SpellHasRange');return true end,IsSpellInRange=function() hit('IsSpellInRange');return true end,IsCurrentSpell=function() return false end}
 e.GetTime=function() hit('GetTime');return clock end
 for _,name in ipairs({'GetLocale','GetBuildInfo','GetClassicExpansionLevel'}) do local fn=e[name];if type(fn)=='function' then e[name]=function(...) hit(name);return fn(...) end end end
 if options.preview or options.buttons then
  dofile('tests/fixtures/native_ui.lua')(e);a.SetUIScript=f.addon.SetUIScript;load('UI/controls.lua')
 end
 local nativeCreate=e.CreateFrame
 e.CreateFrame=function(...)
  local frame=nativeCreate(...);local events={};eventFrames[#eventFrames+1]=frame;frame.modelEvents=events
  function frame:RegisterEvent(event)events[event]=true end
  function frame:UnregisterEvent(event)events[event]=nil end
  function frame:IsEventRegistered(event)return events[event]==true end
  function frame:UnregisterAllEvents()for event in pairs(events)do events[event]=nil end end
  return frame
 end
 for _,path in ipairs({'Platform/spells.lua','Platform/actions.lua','Platform/range.lua','Platform/unit_flags.lua','Platform/unit_attackability.lua','Platform/player_movement.lua','Platform/auras.lua','Core/aura_conditions.lua','Core/spell_catalog.lua'}) do load(path) end
 -- Actual authored registry, no synthetic expansion of definition count.
 for path in io.lines(productRoot..'/RotationMaster.toc') do if path:match('^Conditions/') then load(path) end end
 -- The common startup fixture overrides context for unrelated tests. Restore
 -- the actual original function identity from the already-bound private reader.
 local nativeContext
 for i=1,20 do local name,value=debug.getupvalue(a.GetRotationOwnerContext,i);if not name then break end
  if name=='libraryReader' then for j=1,10 do local key,entry=debug.getupvalue(value.OwnsContext,j);if not key then break end;if key=='ownedRotationContext' then nativeContext=entry end end end
 end
 assert(type(nativeContext)=='function');a.GetRotationContext=nativeContext
 assert(a:OnInitialize(),'actual source initialization failed');a.currentSpec=0
 load('tests/fixtures/shaman_starter_pack.lua');assert(a:InitializeRotationLibrary())
 local id,why=a:CloneDefaultRotation(0,'rm.tbc.shaman.starter','Copy of Shaman: early leveling',{scope='class'});assert(id,why);a.currentSpec=0
 a.configWindow=nil;a.currentConditionEval=nil;a.nextWindow=nil;a.db.profile.preview_spells=0;a.db.profile.disable_buttons=false
 a.inCombat=combat;a.avail_announced={};a.announced={};a.skipAnnounce=true;a.lastCacheReport=100
 e.WeakAuras={ScanEvents=function(event,spell,item)hit('WeakAuras',event,spell,item)end};e.LibStub('AceEvent-3.0').SendMessage=function(_,event,spell,item) hit('SendMessage',event,spell,item) end
 local timed;a.ScheduleRepeatingTimer=function(_,method,delay,...) local args={n=select('#',...),...};local m=method;if type(m)=='function' then local f=m;m=function() return f(unpack(args,1,args.n)) end end;timed={method=m,delay=delay};return timed end;a.CancelTimer=function() timed=nil end
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
 e.LibStub('AceConsole-3.0').GetArgs=function(_,s)return s:match('^(%S+)'),(s:find(' ',1,true)or #s)+1 end
 a:HandleCommand('set Copy of Shaman: early leveling')
 a.db.profile.poll=options.poll or .15;a:EnableRotationTimer()
 local function tick()clock=clock+.15;if timed then if type(timed.method)=='function' then timed.method() else a[timed.method](a) end end end
 if options.inactive then a:DisableRotationTimer();a.currentRotation=nil end
 for i=1,5 do tick() end;assert(not a.adviceErrorReport,'real advice errored during warmup: '..a.Diagnostics:FormatReport(nil,true));assert(#a.Diagnostics:GetReports()==0,'warmup diagnostics')
 if options.exposed then assert(a:GetEditableRotation(0,id));for i=1,5 do tick() end end
]====]

source = once(
    source,
    "local e,a,_,_,_,_,load=fixture();load('Core/rotation_sequence.lua');",
    "local e,a,_,_,_,_,load=fixture();load('Libs/AceAddon-3.0/AceAddon-3.0.lua');assert(e.LibStub('AceAddon-3.0'):NewAddon(a,'rotationmaster')==a);assert(type(getmetatable(a).__tostring)=='function');"
)

local hitStart = assert(source:find(' local function hit(name,...', 1, true))
local hitEnd = assert(source:find(' local target,combat=', hitStart, true))

if measurement == 'price' then
    source = source:sub(1, hitStart - 1) .. ' local tracking=false;local observed={}\n' .. source:sub(hitEnd)
    source = source:gsub('hit%b()%s*;?%s*', '')
    source = source:gsub('e.__reviewSecretObservation=hit', 'e.__reviewSecretObservation=nil')
else
    source = source:sub(1, hitStart - 1)
        .. " local tracking=false;local observed={}\n local function hit(name,...)native[name]=(native[name]or 0)+1;if tracking then local row={name};for i=1,select('#',...)do row[#row+1]=type(select(i,...))..':'..tostring(select(i,...))end;observed[#observed+1]=table.concat(row,'|')end end\n"
        .. source:sub(hitEnd)
end

source = source
    .. " return {a=a,e=e,tick=tick,load=load,alignReset=function()a.lastCacheReport=clock end,setAura=function(v)auraPresent=v end,setCombat=function(v)combat=v;a.inCombat=v end,setTarget=function(v)target=v end,setEnchant=function(v)enchanted=v end,setLevel=function(v)playerLevel=v end,setClass=function(v)playerClass=v end,setVehicle=function(v)vehicle=v end,setSpellReady=function(v)spellReady=v end,fire=function(event,unit)for _,frame in ipairs(eventFrames)do local callback=frame.GetScript and frame:GetScript('OnEvent');if frame.modelEvents[event]and callback then callback(frame,event,unit)end end end,reset=function(track)native={};observed={};tracking=track end,snapshot=function()return native,observed end}\nend\nreturn make"

local holder = {}

local factory = assert(loadstring(
    'local persistent,productRoot,direct,holder=...\nlocal function fixture()local e,a,_,load=persistent({RotationMasterDB=holder.saved and holder.saved(direct) or {global={diagnosticCacheBypass=direct}}},nil,true);a.currentSpec=0;e.GetTime=function()return 100 end;a.lastCacheReport=100;return e,a,nil,nil,nil,nil,load end\n'
        .. source,
    '@external-normalized-shaman-factory'
))(makePersistent, productRoot, direct, holder)

return function(options)
    holder.saved = options and options.saved
    local ok, c = pcall(factory, options or {})
    assert(ok, c)
    assert(type(getmetatable(c.a).__tostring) == 'function' and tostring(c.a) == 'rotationmaster')
    assert(getfenv(c.a.EvaluateRotationSequence) == c.e, 'wrong sequence owner environment')
    return c
end
