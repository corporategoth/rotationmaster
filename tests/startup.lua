-- Run from the repository root: lua5.1 tests/startup.lua
-- WoW is external to this harness; only its API surface is substituted.
local failures, passed = 0, 0
local function test(name, body)
    local ok, err = pcall(body)
    if ok then passed = passed + 1; print('PASS ' .. name)
    else failures = failures + 1; print('FAIL ' .. name .. ': ' .. tostring(err)) end
end
local function fixture(modern, absentThreat)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.WOW_PROJECT_ID, env.WOW_PROJECT_MAINLINE, env.WOW_PROJECT_CLASSIC = 5, 1, 2
    env.LE_EXPANSION_LEVEL_CURRENT = 1
    env.NUM_BAG_SLOTS=4
    env.color = setmetatable({CYAN = '', RESET = '', RED = ''},{__index=function() return '' end})
    env.OFF = 'Off'
    env.GetTime = function() return 0 end
    env.PRIMARY, env.SECONDARY = 'Primary', 'Secondary'
    env.DEFAULT='Default'
    env.BOOKTYPE_SPELL,env.BOOKTYPE_PET='spell','pet'
    env.UnitGUID = function() return 'Player-1' end
    env.IsSpellKnown=function() return true end
    local metadata = function(name, field)
        assert(name == 'rotationmaster')
        return ({Title = 'Rotation Master', Version = 'test-version'})[field]
    end
    env.GetAddOnMetadata = metadata
    if modern then env.GetAddOnMetadata = nil end
    env.IsAddOnLoaded = function() return false end
    if modern then env.IsAddOnLoaded = nil end
    env.C_AddOns = modern and {GetAddOnMetadata = metadata, IsAddOnLoaded = function() return false end} or nil
    env.C_EventUtils = {IsEventValid = function(event) return event ~= 'LEARNED_SPELL_IN_TAB' end}
    local addon = {help_funcs = {}, registered = {}}
    -- Isolated startup tests keep the selection facade at the legacy boundary.
    function addon:GetRuntimeRotations(spec) return self.db.profile.rotations[spec] or {} end
    function addon:GetRuntimeRotation(spec,id) return self:GetRuntimeRotations(spec)[id] end
    function addon:IsDefaultRuntimeRotation() return false end
    function addon:GetRotationCandidates(spec) return self:GetRuntimeRotations(spec) end
    function addon:GetRotationForCleanup(spec,id) return self:GetRuntimeRotation(spec,id) end
    local L = setmetatable({}, {__index = function(_, key) return key end})
    local libs = {
        ['AceAddon-3.0'] = {NewAddon = function(_, object) return object end},
        ['AceGUI-3.0'] = {}, ['AceConsole-3.0'] = {RegisterChatCommand = function() end,Printf=function() end},
        ['LibCompress'] = {},
        ['AceEvent-3.0'] = {SendMessage = function() end},
        ['AceDB-3.0'] = {New = function(_, _, defaults) return defaults end},
        ['AceGUI-3.0-SpellLoader'] = {}, ['AceGUI-3.0-ItemLoader'] = {},
        ['AceLocale-3.0'] = {GetLocale = function() return L end},
        ['LibDBIcon-1.0'] = {Register = function() end}, ['LibSharedMedia-3.0'] = {},
        ['LibDataBroker-1.1'] = {NewDataObject = function(_, _, data) env.broker=data;return data end},
        ['ThreatClassic-1.0'] = not absentThreat and {Disable = function() end} or nil,
    }
    env.LibStub = function(name, silent)
        if not libs[name] and not silent then error('Missing library ' .. name) end
        return libs[name]
    end
    local function load(path)
        local chunk = assert(loadfile(path)); setfenv(chunk, env)
        chunk('rotationmaster', addon)
    end
    env.WOW_PROJECT_BURNING_CRUSADE_CLASSIC=5
    load('Data/artwork.lua')
    load('Platform/client.lua');load('Platform/items.lua');load('Platform/inventory.lua');load('Platform/specializations.lua');load('Platform/communication.lua');load('Core/announcements.lua');load('Core/action_policy.lua');load('Core/inventory.lua');load('Core/rotation_references.lua')
    load('Data/plain.lua');load('Data/tags.lua');load('Data/rotation_tree.lua');load('Data/validation.lua');load('Core/rotation_sequence.lua');load('Core/rotation_selection.lua')
    return env, addon, load
end

local function initialize(addon)
    function addon:augmentDefaults() end
    function addon:init() end
    function addon:validate() end
    function addon:ProfiledCode() return {} end
    addon.getCached = function(_, fn, ...) return fn(...) end
    addon.getRetryCached = addon.getCached
    addon:OnInitialize()
end

test('level-up retires normalized and saved raw player levels before dispatch and delayed selection',function()
    local env,a,load=fixture(true,true);load('main.lua');initialize(a);load('Functions/cache.lua');a.debug=function() end
    local native=20;env.UnitLevel=function(unit) return unit=='target' and 23 or native end
    env.UnitExists=function() return true end
    load('Platform/unit_level.lua');load('Core/level_conditions.lua')
    local getCached=a.Functions.cache.getCached
    local retained={fact=true};a.longtermCache.retained=retained
    assert(a:GetConditionUnitLevel('player',{})==20)
    assert(getCached(a.longtermCache,env.UnitLevel,'player')==20)
    assert(getCached(a.longtermCache,env.UnitLevel,'target')==23)
    local targetObservation=a.longtermCache[env.UnitLevel].target
    local pending,stages
    a.ScheduleTimer=function(_,callback,delay) assert(delay==0.01);pending=callback end
    a.UpdateAutoSwitch=function(self)
        stages=1
        assert(self.longtermCache.conditionPlayerLevel==nil,'normalized level survived delayed boundary')
        assert(self:GetConditionUnitLevel('player',{})==21,'normalized player observation did not recover')
        assert(getCached(self.longtermCache,env.UnitLevel,'player')==21,'saved raw callback retained previous level')
    end
    a.SwitchRotation=function() assert(stages==1);stages=2 end
    a.currentRotation='selected'
    a.EvaluateNextAction=function() assert(stages==2);stages=3 end
    a:PLAYER_LEVEL_UP('PLAYER_LEVEL_UP',21)
    assert(type(pending)=='function' and stages==nil,'level selection must remain deferred')
    local levelCache=a.longtermCache[env.UnitLevel]
    assert(a.longtermCache.conditionPlayerLevel==nil and not (levelCache and levelCache.player),'level event retained prior cache')
    assert(levelCache and levelCache.target==targetObservation,'player event retired another unit level')
    -- Other event consumers can observe the old native value before it settles.
    assert(a:GetConditionUnitLevel('player',{})==20);assert(getCached(a.longtermCache,env.UnitLevel,'player')==20)
    native=21;pending()
    assert(stages==3 and a.longtermCache.retained==retained and a.longtermCache[env.UnitLevel].target==targetObservation,'level refresh lost unrelated longterm facts')
end)

test('level-up remains safe before level APIs and longterm storage are available',function()
    local env,a,load=fixture(true,true);load('main.lua');initialize(a)
    env.UnitLevel=nil;a.longtermCache=nil;a.debug=function() end
    local pending,selected
    a.ScheduleTimer=function(_,callback) pending=callback end
    a.UpdateAutoSwitch=function() end;a.SwitchRotation=function() selected=true end
    a:PLAYER_LEVEL_UP('PLAYER_LEVEL_UP',21);assert(pending);pending();assert(selected)
end)

test('deferred level refresh invalidates the currently active profile cache',function()
    local env,a,load=fixture(true,true);load('main.lua');initialize(a);load('Functions/cache.lua');a.debug=function() end
    env.UnitLevel=function() return 21 end
    a.longtermCache.conditionPlayerLevel=20
    local previous=a.longtermCache;local pending
    a.ScheduleTimer=function(_,callback) pending=callback end
    a.UpdateAutoSwitch=function(self)
        assert(self.longtermCache.conditionPlayerLevel==nil and not self.longtermCache[env.UnitLevel].player)
    end
    a.SwitchRotation=function() end
    a:PLAYER_LEVEL_UP('PLAYER_LEVEL_UP',21)
    a.longtermCache={conditionPlayerLevel=19,other='new profile fact'}
    local current=a.longtermCache
    a.Functions.cache.getCached(current,env.UnitLevel,'player')
    pending()
    assert(a.longtermCache==current and current.other=='new profile fact' and previous~=current)
end)

test('manual selection refuses ambiguous names instead of choosing an arbitrary owner',function()
    local env,a,load=fixture(true,true);load('main.lua');initialize(a);a.currentSpec=0
    env.LibStub('AceConsole-3.0').GetArgs=function() return 'set',5 end
    a.db.profile.rotations[0]={first={name='Twin'},second={name='Twin'}}
    local message;a.warn=function(_,text) message=text end
    a:HandleCommand('set Twin');assert(not a.currentRotation and message:find('More than one',1,true))
end)

test('namespaced metadata allows main and delayed conditions to load', function()
    local env, addon, load = fixture(true, false)
    load('main.lua')
    assert(addon.pretty_name == 'Rotation Master')
    function addon:RegisterCondition(name, value) self.registered[name] = value end
    for _,path in ipairs({'Functions/values.lua','Functions/presentation.lua','Functions/collections.lua','Functions/cache.lua'}) do load(path) end
    load('Conditions/ext_stats.lua')
    assert(addon.registered.STAT, 'base stat condition was not registered')
    assert(addon.delayed_condition.ExtendedCharacterStats.ECS_STAT, 'extended stats were not queued')
end)

test('legacy metadata remains usable', function()
    local _, addon, load = fixture(false, false)
    load('main.lua')
    assert(addon.pretty_name == 'Rotation Master')
end)

test('main registration does not request the legacy preview widget library',function()
    for _,modern in ipairs({false,true}) do
        local env,addon,load=fixture(modern);local lib=env.LibStub
        env.LibStub=function(name,...) assert(name~='AceGUI-3.0','main eagerly requested legacy widgets');return lib(name,...) end
        load('main.lua');assert(addon.pretty_name=='Rotation Master')
    end
end)

test('namespaced addon lookup registers installed extension conditions', function()
    local env, addon, load = fixture(true, true)
    env.C_AddOns.IsAddOnLoaded = function(name) return name == 'ExampleExtension' end
    load('main.lua')
    addon.delayed_condition.ExampleExtension = {EXAMPLE = {description = 'Example'}}
    function addon:RegisterCondition(name, condition) self.registered[name] = condition end
    initialize(addon)
    assert(addon.registered.EXAMPLE.description == 'Example')
end)

test('entering world scans modern bag records, ignores empty slots and counts stacks', function()
    local env, addon, load = fixture(true, true)
    env.C_Container = {
        GetContainerNumSlots = function(bag) return bag == 0 and 3 or 0 end,
        GetContainerItemInfo = function(bag, slot)
            assert(bag == 0)
            if slot == 1 then return {itemID = 5512, stackCount = 2} end
            if slot == 3 then return {itemID = 5512, stackCount = 4} end
        end,
    }
    env.GetItemSpell = function(id) assert(id == 5512); return 'Healthstone',234 end
    load('main.lua')
    initialize(addon)
    function addon:verbose() end
    function addon:debug() end
    function addon:SetupOptions() end
    function addon:UpdateButtonGlow() end
    function addon:UpdateSkill() end
    addon.db.char.bindings = {}
    addon:PLAYER_ENTERING_WORLD('PLAYER_ENTERING_WORLD')
    assert(addon.bagContents[5512].count == 6)
    assert(addon.bagContents[5512].spell == 'Healthstone')
    assert(#addon.bagContents[5512].slots == 2)
end)

test('TBC loads when the Classic-only threat library does not initialize', function()
    local _, addon, load = fixture(false, true)
    load('main.lua')
    assert(addon.pretty_name == 'Rotation Master')
end)

test('enabling registers valid events and spell changes still refresh skills', function()
    local _, addon, load = fixture(false, false)
    load('main.lua')
    addon.db = {profile = {preview_spells = 0}}
    local seen, refreshed, enabled = {}, 0, false
    function addon:RegisterEvent(event)
        assert(event ~= 'LEARNED_SPELL_IN_TAB', 'unknown event ' .. event)
        seen[event] = true
    end
    -- wrapEvent captures the real method at load; its downstream work is stubbed.
    function addon:debug() end
    function addon:verbose() end
    function addon:UpdateSpecSpells() refreshed = refreshed + 1 end
    function addon:UpdateAutoSwitch() end
    function addon:SwitchRotation() end
    function addon:ButtonFetch() end
    function addon:EnableRotation() enabled = true end
    addon:enable()
    assert(enabled and refreshed == 1)
    assert(seen.SPELLS_CHANGED)
    addon:SPELLS_CHANGED('SPELLS_CHANGED')
    assert(refreshed == 2, 'spell updates no longer refresh skills')
end)

test('event failure reaches collector once and stops advice safely', function()
    local env,addon,load=fixture(true,true)
    local errors={}
    env.geterrorhandler=function() return function(err) errors[#errors+1]=err end end
    load('Diagnostics/errors.lua');load('main.lua')
    function addon:debug() end
    function addon:verbose() error('event failure') end
    function addon:RemoveAllCurrentGlows() end
    function addon:DestroyAllGlows() end
    addon.currentRotation='active'
    addon:UNIT_ENTERED_VEHICLE('UNIT_ENTERED_VEHICLE','player')
    addon:UNIT_ENTERED_VEHICLE('UNIT_ENTERED_VEHICLE','player')
    assert(#errors==1)
    assert(addon.currentRotation==nil and addon.adviceErrorReport)
    assert(addon.Diagnostics:FormatReport():find('UNIT_ENTERED_VEHICLE',1,true))
end)
test('recommendation timer failure is recorded and cancels its repeating timer',function()
    local env,addon,load=fixture(true,true)
    local errors={}
    env.geterrorhandler=function() return function(err) errors[#errors+1]=err end end
    load('Diagnostics/errors.lua');load('main.lua')
    function addon:EvaluateNextActionInternal() error('tick failure') end
    function addon:RemoveAllCurrentGlows() end
    function addon:DestroyAllGlows() end
    local cancelled
    function addon:CancelTimer(id) cancelled=id end
    addon.currentRotation='active';addon.rotationTimer='timer-1'
    addon:EvaluateNextAction()
    assert(#errors==1 and cancelled=='timer-1' and addon.rotationTimer==nil)
    assert(addon.currentRotation==nil)
end)

test('error-paused advice cannot silently start another repeating timer',function()
    local _,addon,load=fixture(true,true)
    load('main.lua')
    addon.currentRotation='active';addon.adviceErrorReport=1
    function addon:ScheduleRepeatingTimer() error('paused advice scheduled') end
    addon:EnableRotationTimer()
    assert(addon.rotationTimer==nil)
end)

test('errors command routes to the independent report window',function()
    local env,addon,load=fixture(true,true)
    env.LibStub('AceConsole-3.0').GetArgs=function(_,text) return text end
    load('main.lua')
    local opened=false
    function addon:ShowErrors() opened=true end
    addon:HandleCommand('errors')
    assert(opened)
end)

test('config command and broker open the standalone rotation workbench',function()
    local env,addon,load=fixture(true,true)
    env.LibStub('AceConsole-3.0').GetArgs=function(_,text) return text end
    local broker
    env.LibStub('LibDataBroker-1.1').NewDataObject=function(_,_,object) broker=object;return object end
    env.CreateFrame=function() return {} end
    load('main.lua')
    local opened=0
    function addon:ShowConfig(section) assert(section=='Rotations');opened=opened+1 end
    addon:HandleCommand('config');broker.OnClick(nil,'LeftButton')
    assert(opened==2)
end)

test('error cleanup clears stale previews and notifies consumers despite one failed cleanup',function()
    local env,addon,load=fixture(true,true)
    local messages,wa={},{ }
    env.geterrorhandler=function() return function() end end
    env.LibStub('AceEvent-3.0').SendMessage=function(_,event,...) messages[event]={...} end
    env.WeakAuras={ScanEvents=function(event,...) wa[event]={...} end}
    load('Diagnostics/errors.lua');load('main.lua')
    addon.currentRotation='active';addon.currentSpell=123
    addon.avail_announced={step=123}
    local destroyed,hidden=false,false
    addon.nextWindow={Hide=function() hidden=true end}
    function addon:RemoveAllCurrentGlows() error('glow cleanup failed') end
    function addon:DestroyAllGlows() destroyed=true end
    addon:StopAdviceForError(1)
    assert(addon.currentSpell==nil and addon.currentRotation==nil)
    assert(hidden and destroyed)
    assert(next(addon.avail_announced)==nil)
    assert(messages.ROTATIONMASTER_ROTATION and messages.ROTATIONMASTER_SPELL_UPDATE)
    assert(wa.ROTATIONMASTER_SPELL_UPDATE)
end)

test('a manually selected rotation becoming unavailable clears advice before evaluation',function()
    local env,addon,load=fixture(true,true)
    local messages={}
    env.LibStub('AceEvent-3.0').SendMessage=function(_,event) messages[event]=true end
    load('main.lua')
    addon.db={profile={rotations={}}};addon.currentSpec=0
    addon.currentRotation='gone';addon.currentSpell=403;addon.avail_announced={step=403}
    addon.manualRotation=true
    local destroyed=false
    function addon:debug() end
    function addon:info() end
    function addon:DestroyAllGlows() destroyed=true end
    function addon:GlowClear() end
    addon:EvaluateNextActionInternal()
    assert(addon.currentRotation==nil and addon.currentSpell==nil and destroyed)
    assert(next(addon.avail_announced)==nil and messages.ROTATIONMASTER_SPELL_UPDATE)
end)

test('live autoswitch reads packaged rotations through the facade and prefers existing custom choices',function()
    local env,addon,load=fixture(true,true)
    load('Data/plain.lua');load('Data/tags.lua');load('Data/rotation_tree.lua');load('Data/validation.lua');load('Data/catalog.lua');load('Data/diff.lua')
    load('Core/rotation_library.lua');load('main.lua')
    local _,envelope=dofile('tests/fixtures/rotation_data.lua')()
    local pack=envelope();pack.body.switch={type='READY'}
    assert(addon:RegisterDefaultRotation(pack))
    initialize(addon)
    addon.GetRotationContext=function() return {family='tbc',class='SHAMAN',level=11,actionContext='player',combatDataPolicy='probe'} end
    addon.conditionDefinitions={READY={fields={}},SPELL_KNOWN={fields={spell='number'}}}
    assert(addon:InitializeRotationLibrary())
    addon.currentSpec=0
    function addon:debug() end
    function addon:info() end
    function addon:warn() end
    function addon:usefulCondition() return true end
    function addon:validateCondition() return true end
    function addon:rotationValidConditions() return true end
    function addon:evaluateCondition() return true end
    function addon:RemoveAllCurrentGlows() end
    function addon:EnableRotationTimer() end
    function addon:DestroyAllGlows() end
    function addon:GlowClear() end
    addon.db.profile.rotations[0]={user={name='Z custom',switch={type='READY'},rotation={}}}
    addon:UpdateAutoSwitch();addon:SwitchRotation()
    assert(addon.currentRotation=='user','default displaced an existing matching custom rotation')
    addon.db.profile.rotations[0].user=nil
    addon.db.profile.rotations[0][env.DEFAULT or 'Default']={name='Saved fallback',rotation={{type='spell',action=324}}}
    addon:UpdateAutoSwitch();addon:SwitchRotation()
    assert(addon.currentRotation==(env.DEFAULT or 'Default'),'pack displaced the saved fallback')
    addon.db.profile.rotations[0][env.DEFAULT or 'Default']=nil
    addon:UpdateAutoSwitch();addon:SwitchRotation()
    local selected=addon.currentRotation
    assert(selected and addon:IsDefaultRuntimeRotation(0,selected))
    assert(addon:GetRotationName(selected)=='Shaman Leveling')
    assert(addon.db.profile.rotations[0][selected]==nil,'packaged body was persisted into custom data')
    assert(addon:SetDefaultRotationEnabled(pack.id,false))
    addon:UpdateAutoSwitch();addon:SwitchRotation()
    assert(addon.currentRotation==nil)
end)

test('switching revisits previously inapplicable packs and clears outgoing cooldowns',function()
    local env,addon,load=fixture(true,true)
    load('Data/plain.lua');load('Data/tags.lua');load('Data/rotation_tree.lua');load('Data/validation.lua');load('Data/catalog.lua');load('Data/diff.lua')
    load('Core/rotation_library.lua');load('main.lua')
    local _,envelope=dofile('tests/fixtures/rotation_data.lua')()
    local first,second=envelope(),envelope()
    first.applicability.maxLevel=19
    first.body.switch={type='READY'}
    first.body.cooldowns={{id='cooldown-a',type='spell',action=324,conditions={}}}
    second.id='rm.tbc.shaman.next';second.applicability.minLevel=20;second.body.switch={type='READY'}
    assert(addon:RegisterDefaultRotation(first));assert(addon:RegisterDefaultRotation(second))
    initialize(addon)
    local level=19
    addon.GetRotationContext=function() return {family='tbc',class='SHAMAN',level=level,actionContext='player',combatDataPolicy='probe'} end
    addon.conditionDefinitions={READY={fields={}},SPELL_KNOWN={fields={spell='number'}}}
    assert(addon:InitializeRotationLibrary());addon.currentSpec=0
    function addon:debug() end
    function addon:info() end
    function addon:warn() end
    function addon:usefulCondition() return true end
    function addon:validateCondition() return true end
    function addon:rotationValidConditions() return true end
    function addon:evaluateCondition() return true end
    function addon:EnableRotationTimer() end
    function addon:DestroyAllGlows() end
    function addon:GetSpellIds(step) return {step.action} end
    local glowing,cleared=true,false
    function addon:GlowCooldown(id,value) assert(id==324);glowing=value end
    function addon:GlowClear() cleared=true end
    addon:UpdateAutoSwitch();addon:SwitchRotation()
    local previous=addon.currentRotation;glowing=true;cleared=false
    level=20
    addon:SwitchRotation()
    assert(addon.currentRotation and addon.currentRotation~=previous,'new level pack was not revisited')
    assert(glowing==false and cleared,'outgoing ineligible pack retained highlights')
end)

test('live autoswitch uses explicit priority and keeps fallback precedence without extra evaluation',function()
    local env,a,load=fixture(true,true);load('main.lua');initialize(a)
    a.currentSpec=0
    local function body(name,priority) return {name=name,priority=priority,switch={type='COMBAT'},rotation={{type='spell',action=403}}} end
    local rows={low=body('A low',0),high=body('Z high',20),pack=body('Pack',10000),bad=body('Invalid',.5)}
    a.db.profile.rotations[0]=rows
    a.IsDefaultRuntimeRotation=function(_,_,id) return id=='pack' end
    a.usefulCondition=function() return true end;a.validateCondition=function() return true end;a.rotationValidConditions=function() return true end
    a.debug=function() end;a.info=function() end;a.RemoveAllCurrentGlows=function() end;a.EnableRotationTimer=function() end
    local calls=0;a.evaluateCondition=function() calls=calls+1;return true end
    a:UpdateAutoSwitch();a:SwitchRotation();assert(a.currentRotation=='high' and calls==1,'priority selection executed extra candidates or chose alphabetically')
    rows.high.priority=-5;a:UpdateAutoSwitch();a:SwitchRotation();assert(a.currentRotation=='low')
    rows.low.disabled=true;rows.high.disabled=true;rows[env.DEFAULT]=body('My fallback',-100000)
    a:UpdateAutoSwitch();calls=0;a:SwitchRotation();assert(a.currentRotation==env.DEFAULT and calls==0,'packaged priority displaced the user fallback')
end)

test('invalid switch priority makes even a fallback body unavailable to auto-selection',function()
    local _,a,load=fixture(true,true);load('main.lua');initialize(a);a.validateCondition=function() return true end
    local body={priority='2',rotation={{type='spell',action=403,conditions={}}}}
    assert(not a:rotationValidConditions(body,0),'malformed priority passed the live validity gate')
    body.priority=0;assert(a:rotationValidConditions(body,0))
end)

test('numeric zero range results cannot highlight an out-of-range spell',function()
    local env,addon,load=fixture(true,true)
    env.GetSpellCooldown=function() return 0,0,1 end
    load('Platform/client.lua');load('Platform/spells.lua');load('Platform/actions.lua')
    load('main.lua');initialize(addon)
    addon.currentSpec=0;addon.currentRotation='range-test';addon.units={}
    addon.db.profile.rotations[0]={['range-test']={name='Range fixture',rotation={{id='step',type='spell',action=403,conditions={}}},cooldowns={}}}
    local profile={}
    function profile:start() end
    function profile:stop() end
    function profile:child() return self end
    addon.evaluationProfile=profile
    function addon:GetSpellIds() return {403} end
    function addon:FindSpell() return 403,1 end
    function addon:evaluateCondition() return true end
    function addon:IsGlowing() return false end
    function addon:verbose() end
    local glowing=false
    function addon:GlowNextSpell() glowing=true end
    function addon:GlowClear() glowing=false end
    env.IsUsableSpell=function() return true,false end
    env.FindSpellBookSlotBySpellID=function() return 1 end
    local range=0
    env.IsSpellInRange=function() return range end
    addon:EvaluateNextActionInternal()
    assert(not glowing,'out-of-range numeric zero is truthy in Lua')
    range=1;addon:EvaluateNextActionInternal();assert(glowing)
    range=0;addon:EvaluateNextActionInternal();assert(not glowing and addon.currentSpell==nil,'stale recommendation survived')
    range=nil;addon:EvaluateNextActionInternal();assert(not glowing,'invalid range was treated as rangeless')
    env.SpellHasRange=function() return false end
    addon:EvaluateNextActionInternal();assert(glowing,'observed rangeless spell was suppressed')
    env.IsUsableSpell=nil;env.FindSpellBookSlotBySpellID=nil;env.IsSpellInRange=nil;env.SpellHasRange=nil
    local usableCalls,rangeCalls=0,0
    env.C_Spell={IsSpellUsable=function(id) usableCalls=usableCalls+1;assert(id==403);return true,false end,
        SpellHasRange=function() return true end,IsSpellInRange=function(id,unit) rangeCalls=rangeCalls+1;assert(id==403 and unit=='target');return true end}
    addon.db.profile.rotations[0]['range-test'].cooldowns={{id='optional',type='any',action=403,conditions={}}}
    env.Enum={SpellBookSpellBank={Player=0,Pet=1}}
    env.C_SpellBook={IsSpellKnown=function() return true end}
    addon.skipAnnounce=true
    local optionalGlow
    function addon:GlowCooldown(_,on) optionalGlow=on end
    addon:EvaluateNextActionInternal();assert(glowing,'modern-only spell recommendation failed')
    assert(usableCalls==1 and rangeCalls==1,'same spell was observed twice for optional and sequential advice')
    env.C_Spell.IsSpellInRange=function() return nil end
    addon:EvaluateNextActionInternal();assert(not glowing and addon.currentSpell==nil,'modern invalid range retained glow')
    env.C_Spell.IsSpellInRange=function() return true end
    addon.db.profile.rotations[0]['range-test'].rotation[1].type='any'
    env.Enum={SpellBookSpellBank={Player=0,Pet=1}}
    env.C_SpellBook={IsSpellKnown=function(id,bank) assert(id==403);return bank==1 end}
    addon:EvaluateNextActionInternal();assert(glowing,'modern pet learned-state was ignored for any action')
    env.C_SpellBook.IsSpellKnown=function() return nil end
    addon:EvaluateNextActionInternal();assert(not glowing,'unknown learned state enabled any action')
    assert(optionalGlow==false,'optional any glow survived unknown learned state')
end)

test('recommendations skip Earth Shock cooldowns in existing rotations and optional highlights',function()
    local env,addon,load=fixture(true,true)
    env.WOW_PROJECT_BURNING_CRUSADE_CLASSIC=5
    env.GetTime=function() return 100 end
    load('Platform/client.lua');load('Platform/spells.lua');load('Platform/actions.lua')
    load('main.lua');initialize(addon)
    addon.currentSpec=0;addon.currentRotation='existing-clone';addon.units={}
    addon.db.profile.ignore_range=true
    addon.db.profile.rotations[0]={['existing-clone']={name='Existing clone',rotation={
        {id='shock',type='spell',action=8042,conditions={}},
        {id='bolt',type='spell',action=403,conditions={}},
    },cooldowns={{id='optional-shock',type='spell',action=8042,conditions={}}}}}
    local profile={}
    function profile:start() end
    function profile:stop() end
    function profile:child() return self end
    addon.evaluationProfile=profile
    function addon:GetSpellIds(step) return {step.action} end
    function addon:FindSpell(ids) return ids[1],1 end
    function addon:evaluateCondition() return true end
    function addon:IsGlowing() return false end
    function addon:verbose() end
    local glowing,optional
    function addon:GlowNextSpell(id) glowing=id end
    function addon:GlowClear() glowing=nil end
    function addon:GlowCooldown(id,on) assert(id==8042);optional=on end
    env.IsUsableSpell=function() return true,false end
    env.C_SpellBook={IsSpellKnown=function() return true end}
    local shock={startTime=98,duration=6,isEnabled=true,modRate=1}
    local gcd={startTime=99.5,duration=1.5,isEnabled=true,modRate=1}
    env.C_Spell={SpellHasRange=function() return false end,GetSpellCooldown=function(id)
        if id==8042 then return shock end
        if id==29515 then return gcd end
        return {startTime=0,duration=0,isEnabled=true,modRate=1}
    end}
    addon:EvaluateNextActionInternal()
    assert(glowing==403 and addon.currentSpell==403,'Earth Shock on cooldown blocked the ready filler')
    assert(optional==false,'optional Earth Shock highlighted while on cooldown')
    -- Only the GCD remains; keep a useful next-spell suggestion.
    addon.skipAnnounce=true;shock=gcd
    addon:EvaluateNextActionInternal()
    assert(glowing==8042 and optional==true,'GCD-only spells must remain eligible as the next action')
    shock={startTime=94,duration=6,isEnabled=true,modRate=1}
    addon:EvaluateNextActionInternal();assert(glowing==8042,'expired cooldown was not ready')
    shock={startTime=100,duration=0,isEnabled=false,modRate=1}
    addon:EvaluateNextActionInternal();assert(glowing==403 and optional==false,'held cooldown was treated as ready')
    env.C_Spell.GetSpellCooldown=function() return nil end
    addon:EvaluateNextActionInternal();assert(glowing==nil and addon.currentSpell==nil,'unknown cooldown retained a recommendation')
    -- The optional preview uses the same modern metadata as bar discovery.
    local widget=dofile('tests/fixtures/addon.lua').new().widget
    env.LibStub('AceGUI-3.0').Create=function(_,kind) assert(kind=='Icon');return widget(kind) end
    addon.nextWindow=widget('preview')
    function addon.nextWindow:ReleaseChildren() self.children={} end
    function addon.nextWindow:PauseLayout() end
    function addon.nextWindow:ResumeLayout() end
    function addon.nextWindow:DoLayout() end
    addon.db.profile.preview_spells=1
    env.GetSpellInfo=nil
    env.C_Spell.GetSpellCooldown=function() return {startTime=0,duration=0,isEnabled=true,modRate=1} end
    env.C_Spell.GetSpellInfo=function(id) return {name='Earth Shock',spellID=id,iconID=136026} end
    addon:EvaluateNextActionInternal()
    local preview=addon.nextWindow.children[1]
    assert(preview and preview.label=='Earth Shock' and preview.image==136026,'modern recommendation preview lost its metadata')
end)

test('real main refresh uses owned catalog and discards removed pet spells',function()
    local env,addon,load=fixture(true,false)
    env.GetSpellInfo=function(id) return id==403 and 'Lightning Bolt' or 'Earth Shock','Rank '..(id==8042 and 1 or 2),1,0,0,20,id end
    env.GetSpellLink=function(id) return 'spell:'..id end
    env.GetNumSpellTabs=function() return 1 end
    env.GetSpellTabInfo=function() return 'Shaman',1,0,2,false,0 end
    env.GetSpellBookItemInfo=function(slot,bank) return 'SPELL',bank=='pet' and 403 or (slot==1 and 8042 or 8044) end
    env.IsPassiveSpell=function() return false end
    env.HasPetSpells=function() return 1 end
    load('Platform/client.lua');load('Platform/spells.lua');load('Platform/spellbook.lua')
    load('Core/spell_catalog.lua');load('main.lua')
    addon.currentSpec=0
    addon:UpdateSpecSpells()
    assert(addon.specSpells[0][8042] and addon.specSpells.pet[403])
    assert(addon.specSpellsReverse[0]['Earth Shock']==8044)
    local ranks=addon:GetSpellIds({type='spell',action=8042})
    assert(ranks[1]==8044 and ranks[2]==8042)
    assert(addon:GetSpellIds({type='spell',action=8042,ranked=true})[1]==8042)
    env.HasPetSpells=function() return nil end
    addon.debug=function() end;addon.verbose=function() end
    local switches,evaluations=0,0
    addon.SwitchRotation=function() switches=switches+1 end
    addon.EvaluateNextAction=function() evaluations=evaluations+1 end
    addon:UNIT_PET('UNIT_PET','party1');assert(addon.specSpells.pet[403] and switches==0)
    addon:UNIT_PET('UNIT_PET','player');assert(next(addon.specSpells.pet)==nil and switches==1 and evaluations==1)
end)

test('startup failures remain copyable and cannot enable partial state or cascade through gameplay events',function()
    for _,stage in ipairs({'database','upgrade'}) do
        local env,a,load=fixture(true,true)
        local forwarded,commands={},{}
        env.geterrorhandler=function() return function(err) forwarded[#forwarded+1]=err end end
        env.debugstack=function() return 'Interface/AddOns/rotationmaster/init.lua:476: upgradeBindingSlots' end
        local fallback=env.LibStub
        local console={RegisterChatCommand=function(_,name,callback) commands[name]=callback end,
            GetArgs=function(_,text) return text,1 end}
        env.LibStub=function(name,silent)
            if name=='AceConsole-3.0' then return console end
            if name=='AceDB-3.0' and stage=='database' then return {New=function() error('database initialization failed') end} end
            return fallback(name,silent)
        end
        local broker
        env.LibStub('LibDataBroker-1.1').NewDataObject=function(_,_,object) broker=object;return object end
        env.CreateFrame=function() error('failed startup constructed a DB-dependent broker window') end
        load('Diagnostics/errors.lua');load('main.lua')
        a.augmentDefaults=function() end
        a.init=function() error('binding upgrade failed') end
        a.validate=function() error('must not continue after failed upgrade') end
        a.RegisterEvent=function() error('incomplete startup registered a gameplay event') end
        a.ScheduleRepeatingTimer=function() error('incomplete startup scheduled a timer') end
        a.verbose=function() error('partial state reached event body') end
        a.info=function() error('partial state reached normal OnEnable') end
        local copied
        a.ShowErrors=function(self) copied=self.Diagnostics:FormatReport() end
        local ok=pcall(a.OnInitialize,a)
        assert(ok,'startup failure escaped the RM-owned diagnostic boundary')
        assert(#forwarded==1 and #a.Diagnostics:GetReports()==1,'startup error was lost or forwarded more than once')
        assert(commands.rm and commands.rotationmaster,'diagnostic commands were not registered before startup failed')
        commands.rm('errors');assert(copied and copied:find('initialization',1,true))
        a:OnEnable();a:enable();a:disable();a:EvaluateNextAction();a:EnableRotationTimer()
        a:NAME_PLATE_UNIT_ADDED('NAME_PLATE_UNIT_ADDED','nameplate1')
        a:PLAYER_ENTERING_WORLD('PLAYER_ENTERING_WORLD')
        assert(#forwarded==1 and #a.Diagnostics:GetReports()==1,'partial runtime caused additional errors')
        copied=nil;commands.rm('enable');assert(copied,'unsafe command did not direct the user to the startup report')
        for _,button in ipairs({'LeftButton','RightButton'}) do
            copied=nil;broker.OnClick(nil,button)
            assert(copied,'broker click bypassed the startup failure report')
        end
    end
end)

local function persistentFixture(saved,folder,scoped)
    local env,addon=fixture(true,true)
    env.securecallfunction=function(fn,...) return fn(...) end
    env.UnitFactionGroup=function() return 'Horde' end
    env.GetLocale=function() return 'enUS' end
    env.UnitClass=function() return 'Shaman','SHAMAN' end
    env.UnitRace=function() return 'Orc','Orc' end
    env.GetRealmName=function() return 'Fixture Realm' end
    env.UnitNameUnmodified=function() return 'Fixture Character' end
    env.GetCurrentRegionName=function() return 'US' end
    env.GetCurrentRegion=function() return 1 end
    env.strlenutf8=function(text) return #text end
    local scripts={}
    env.CreateFrame=function() return {RegisterEvent=function() end,SetScript=function(_,event,handler) scripts[event]=handler end} end
    env.C_AddOns.GetAddOnMetadata=function(_,field) return ({Title='Rotation Master',Version='test'})[field] end
    local function load(path)
        local chunk=assert(loadfile(path));setfenv(chunk,env);chunk(folder or 'rotationmaster',addon)
    end
    local fallback=env.LibStub;env.LibStub=false
    load('Libs/LibStub/LibStub.lua');load('Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua');load('Libs/AceDB-3.0/AceDB-3.0.lua')
    local real=env.LibStub
    setmetatable(real,{__call=function(self,name,silent)
        if self.libs[name] then return self:GetLibrary(name,silent) end
        return fallback(name,silent)
    end})
    for key,value in pairs(saved or {}) do env[key]=value end
    env.Enum={PowerType={Runes=5,SoulShards=7,Chi=12,ArcaneCharges=16}}
    env.GetItemInfo=function() end
    load('globals.lua');load('constants.lua');load('Functions/values.lua');load('Functions/presentation.lua');load('Functions/text.lua');load('Functions/collections.lua');load('Functions/cache.lua');load('utils.lua');load('profiler.lua')
    load('Core/itemset_services.lua');load('Core/conditions.lua');load('Core/condition_catalog.lua');load('Conditions/known_spell.lua');load('UI/condition_entrypoints.lua');load('Options/conditional.lua')
    load('main.lua')
    local make=dofile('tests/fixtures/rotation_data.lua')
    local data,envelope=make();addon.RotationData=data
    load('Data/catalog.lua');load('Data/diff.lua');load('Data/rotation_store.lua');load('Core/rotation_library.lua')
    if scoped then load('Core/rotation_scope.lua');load('Core/rotation_migration.lua');load('Core/rotation_lifecycle.lua') end
    addon.GetRotationContext=function() return {family='tbc',class='SHAMAN',level=11,spec=0,actionContext='player',combatDataPolicy='probe'} end
    local n=0;addon.uuid=function() n=n+1;return '00000000-0000-0000-0000-'..string.format('%012d',n) end
    assert(addon:RegisterDefaultRotation(envelope()))
    load('init.lua');load('validate.lua')
    addon:OnInitialize()
    return env,addon,scripts,load
end

-- WoW SavedVariables accepts numeric zero keys (Classic spec 0), unlike
-- portable rotation arrays. Model the host serializer, not the import schema.
local function savedVariablesCopy(value)
    if type(value)~='table' then
        assert(type(value)=='string' or type(value)=='number' or type(value)=='boolean' or value==nil)
        return value
    end
    assert(getmetatable(value)==nil,'AceDB did not remove defaults before saving')
    local result={}
    for key,entry in pairs(value) do result[savedVariablesCopy(key)]=savedVariablesCopy(entry) end
    return result
end

test('production scoped startup archives exact legacy roots before init and preserves unknown character owners',function()
    local empty={};local saved={profiles={Default={version=1,rotations={[0]={old=empty}},rotationLibrary={imports={[0]={old={originalID='evidence'}}}}}},char={['Fixture Character - Fixture Realm']={version=1,rotations={[0]={character={}}}}}}
    local env,a,scripts=persistentFixture({RotationMasterDB=saved},nil,true)
    assert(not a.initializationErrorReport,'scoped initialization failed')
    assert(a.db:GetCurrentProfile()=='Default' and a.db.profile.rotationStore and a.db.profile.rotationFallbackID=='Default')
    assert(next(a.db.profile.rotationStore.legacy.rotations[0].old)==nil and a.db.profile.rotationStore.legacy.imports[0].old.originalID=='evidence')
    assert(a.db.char.rotations[0].character and #a:ListUnassignedRotations()==2)
    for _,row in ipairs(a:ListRotationHeaders(0)) do assert(row.canonicalId~='old' and row.canonicalId~='character') end
    scripts.OnEvent(nil,'PLAYER_LOGOUT')
    local _,b=persistentFixture({RotationMasterDB=savedVariablesCopy(env.RotationMasterDB)},nil,true)
    assert(not b.initializationErrorReport and #b:ListUnassignedRotations()==2)
end)
test('production scoped startup and repair retain malformed roots without AceDB default substitution',function()
    local _,a=persistentFixture({RotationMasterDB={profiles={Default={version=1,rotations=false}},char={['Fixture Character - Fixture Realm']={rotations={[0]={old={}}}}}}},nil,true)
    assert(not a.initializationErrorReport and a.rotationStorageError and a.db.profile.rotations==false)
    assert(a.db.char.rotations[0].old and not a:ListRotationHeaders(0))
    a:validate({global={},char={},profile={}},true)
    assert(a.db.profile.rotations==false and a.db.char.rotations[0].old)
end)

test('real AceDB defaults to diagram and preserves the chosen rotation view on reload',function()
    local env,a,scripts=persistentFixture();assert(a.db.profile.rotation_view=='diagram')
    a.db.profile.rotation_view='list';scripts.OnEvent(nil,'PLAYER_LOGOUT')
    local _,b=persistentFixture({RotationMasterDB=savedVariablesCopy(env.RotationMasterDB)})
    assert(b.db.profile.rotation_view=='list')
end)

test('scoped production profile reset preserves the real condition seed callback',function()
    local _,a=persistentFixture(nil,nil,true)
    assert(a.rotationProfileLifecycleInstalled and not a.initializationErrorReport)
    a.DisableRotation=function() end;a.EnableRotation=function() end;a.RefreshConfiguration=function() end
    a.db:ResetProfile()
    local function contains(list,tag) for _,entry in ipairs(list) do if entry==tag then return true end end end
    assert(contains(a.db.profile.switch_conditions,'TALENT_TREE_POINTS') and contains(a.db.profile.switch_conditions,'PRIMARY_TALENT_TREE'),'scoped reset lost real switch-condition seeds')
    local character,spell
    for _,group in ipairs(a.db.profile.condition_groups) do
        if group.id=='b8136123-2bda-4230-a77a-89ea2aed3a1a' then character=group.conditions end
        if group.id=='8034819e-26f5-4f4e-9153-d8cab5e65f31' then spell=group.conditions end
    end
    assert(character and contains(character,'TALENT_TREE_POINTS') and contains(character,'PRIMARY_TALENT_TREE'),'scoped reset lost real character condition seeds')
    assert(spell and contains(spell,'SPELL_AUTOREPEAT'),'scoped reset lost real spell condition seed')
end)

test('real AceDB preserves customized condition lists across reload and seeds only new or reset profiles',function()
    local env,a,scripts=persistentFixture()
    local function contains(list,tag) for _,value in ipairs(list) do if value==tag then return true end end end
    local function character(profile) for _,group in ipairs(profile.condition_groups) do if group.id=='b8136123-2bda-4230-a77a-89ea2aed3a1a' then return group end end end
    assert(contains(a.db.profile.switch_conditions,'PRIMARY_TALENT_TREE') and contains(character(a.db.profile).conditions,'TALENT_TREE_POINTS'),'new profile lacks tree conditions')
    -- Model a pre-feature profile with complete, deliberately reordered lists.
    local profile=a.db.profile
    for _,list in ipairs({profile.switch_conditions,character(profile).conditions}) do
        for i=#list,1,-1 do if list[i]=='PRIMARY_TALENT_TREE' or list[i]=='TALENT_TREE_POINTS' then table.remove(list,i) end end
        list[1],list[2]=list[2],list[1]
    end
    profile.condition_groups[1],profile.condition_groups[2]=profile.condition_groups[2],profile.condition_groups[1]
    local expectedSwitch=table.concat(profile.switch_conditions,',');local expectedCharacter=table.concat(character(profile).conditions,',')
    scripts.OnEvent(nil,'PLAYER_LOGOUT')
    local saved={RotationMasterDB=savedVariablesCopy(env.RotationMasterDB)}
    local nextEnv,b,nextScripts=persistentFixture(saved)
    assert(table.concat(b.db.profile.switch_conditions,',')==expectedSwitch,'reload appended tree conditions to customized switch list')
    assert(table.concat(character(b.db.profile).conditions,',')==expectedCharacter,'reload modified reordered Character list')
    assert(not contains(b.db.profile.condition_groups[2].conditions,'PRIMARY_TALENT_TREE'),'tree tags were merged into the category at the old numeric position')
    b.db:SetProfile('New tree profile');assert(contains(b.db.profile.switch_conditions,'PRIMARY_TALENT_TREE'))
    b.db:CopyProfile('Default');assert(not contains(b.db.profile.switch_conditions,'PRIMARY_TALENT_TREE'),'copying an existing profile added new conditions')
    b.db:ResetProfile();assert(contains(b.db.profile.switch_conditions,'PRIMARY_TALENT_TREE') and contains(character(b.db.profile).conditions,'TALENT_TREE_POINTS'))
    nextScripts.OnEvent(nil,'PLAYER_LOGOUT')
    local _,c=persistentFixture({RotationMasterDB=savedVariablesCopy(nextEnv.RotationMasterDB)})
    assert(contains(c.db.profile.switch_conditions,'PRIMARY_TALENT_TREE'),'new-profile conditions were pruned or lost on reload')
end)

test('real AceDB keeps customized spell arrays unchanged and seeds auto-repeat only for new or reset profiles',function()
    local env,a,scripts=persistentFixture()
    local function spells(profile) for _,group in ipairs(profile.condition_groups) do if group.id=='8034819e-26f5-4f4e-9153-d8cab5e65f31' then return group end end end
    local function contains(list,tag) for _,entry in ipairs(list) do if entry==tag then return true end end end
    assert(contains(spells(a.db.profile).conditions,'SPELL_AUTOREPEAT'),'new profile lacks auto-repeat')
    local group=spells(a.db.profile);local reordered={}
    for i=#group.conditions,1,-1 do if group.conditions[i]~='SPELL_AUTOREPEAT' then reordered[#reordered+1]=group.conditions[i] end end
    group.conditions=reordered;local expected=table.concat(reordered,',')
    scripts.OnEvent(nil,'PLAYER_LOGOUT')
    local nextEnv,b,nextScripts=persistentFixture({RotationMasterDB=savedVariablesCopy(env.RotationMasterDB)})
    assert(table.concat(spells(b.db.profile).conditions,',')==expected,'reload filled the customized spell array from a newly extended numeric default')
    b.db:SetProfile('Fresh auto-repeat profile');assert(contains(spells(b.db.profile).conditions,'SPELL_AUTOREPEAT'),'new profile callback did not seed auto-repeat')
    b.db:CopyProfile('Default');assert(table.concat(spells(b.db.profile).conditions,',')==expected,'copying a customized profile seeded or changed its spell array')
    b.db:ResetProfile();assert(contains(spells(b.db.profile).conditions,'SPELL_AUTOREPEAT'),'profile reset did not seed auto-repeat')
    nextScripts.OnEvent(nil,'PLAYER_LOGOUT')
    local _,c=persistentFixture({RotationMasterDB=savedVariablesCopy(nextEnv.RotationMasterDB)})
    assert(contains(spells(c.db.profile).conditions,'SPELL_AUTOREPEAT'),'seeded auto-repeat was pruned on reload')
end)

test('real AceDB clones edits and lineage survive saving only TOC-declared globals across folder casing',function()
    local env,a,scripts=persistentFixture()
    local source='rm.tbc.shaman.leveling'
    local id=assert(a:CloneDefaultRotation(0,source,'Persisted clone'))
    a:GetEditableRotation(0,id).rotation[1].action=974
    a:GetEditableRotation(0,id).tags={'AOE','MyLittlePony'}
    a:GetEditableRotation(0,id).priority=42
    a:GetEditableRotation(0,id).description='Keep these tags across reload'
    a.db.profile.ignore_range=true
    assert(a:SetDefaultRotationEnabled(source,false))
    scripts.OnEvent(nil,'PLAYER_LOGOUT')
    local toc=assert(io.open('RotationMaster.toc')):read('*a')
    local names=assert(toc:match('## SavedVariables:%s*([^\n]+)'))
    local saved={}
    for name in names:gmatch('[%w_]+') do if env[name]~=nil then
        saved[name]=savedVariablesCopy(env[name])
    end end
    local _,b=persistentFixture(saved,'RotationMaster')
    local body=b:GetEditableRotation(0,id)
    assert(body and body.name=='Persisted clone' and body.rotation[1].action==974,'clone was not persisted in a declared SavedVariables global')
    assert(body.tags[2]=='MyLittlePony' and body.description=='Keep these tags across reload','tags and description were lost on reload')
    assert(body.priority==42,'switch priority was lost on reload')
    assert(b.db.profile.ignore_range and not b:GetDefaultRotation(source).enabled,'profile preferences were lost')
    local view=assert(b:GetSourcedRotationView(0,id))
    assert(view.lineage.baseline.body.rotation[1].action==403 and view.envelope.body.rotation[1].action==974,'source baseline was lost')
    assert(b.db.sv==saved.RotationMasterDB,'existing canonical data was replaced')
end)

test('complete real initialization prepares cache helpers and nameplate state before runtime events',function()
    local env,a= persistentFixture()
    assert(env.rotationmasterDB==nil and a.db.sv==env.RotationMasterDB)
    assert(type(a.unitsInRange)=='table' and type(a.longtermCache)=='table')
    env.C_Container={GetContainerNumSlots=function(bag) return bag==0 and 1 or 0 end,
        GetContainerItemInfo=function() return nil end}
    a:UpdateBagContents(nil)
    assert(next(a.bagContents)==nil,'empty modern bag scan did not complete after initialization')
    a.unitsInRange['Player-1']={unit='old'}
    a:NAME_PLATE_UNIT_ADDED('NAME_PLATE_UNIT_ADDED','nameplate1')
    assert(a.unitsInRange['Player-1'].unit=='nameplate1','nameplate event failed after startup')
end)

test('real initialization upgrades existing bindings in the canonical store without replacing other characters',function()
    local item='00000000-0000-0000-0000-000000000001'
    local other={bindings={[item]=73,existing={4,5}},version=1}
    local canonical={char={['Other Character - Other Realm']=other}}
    local env,a=persistentFixture({RotationMasterDB=canonical})
    assert(a.db.sv==canonical and env.rotationmasterDB==nil)
    assert(canonical.char['Other Character - Other Realm']==other)
    assert(type(other.bindings[item])=='table' and other.bindings[item][1]==73)
    assert(other.bindings.existing[1]==4 and other.bindings.existing[2]==5,'migration rewrote an existing binding list')
end)

test('initialization upgrades item actions and conditions inside both branch arms and the branch guard',function()
    local _,a=persistentFixture()
    local b={name='Nested old data',rotation={{id='branch',type='branch',conditions={type='RUNE',rune='BLOOD'},
        onTrue={{id='yes',type='item',action=5512,conditions={type='RUNE',rune='FROST'}}},
        onFalse={{id='no',type='item',action=5513,conditions={type='RUNE',rune='UNHOLY'}}}}},cooldowns={}}
    a.db.profile.rotations[0]={tree=b};a:init()
    assert(type(b.rotation[1].onTrue[1].action)=='table' and b.rotation[1].onTrue[1].action[1]==5512)
    assert(b.rotation[1].onFalse[1].action[1]==5513 and b.rotation[1].conditions.rune==1
        and b.rotation[1].onTrue[1].conditions.rune==2 and b.rotation[1].onFalse[1].conditions.rune==3)
end)

test('real main item actions and bag metadata use native item spell records and retry unavailable data',function()
    local env,a=persistentFixture()
    local ready=false
    env.GetItemSpell=nil
    env.C_Item={GetItemSpell=function(id) assert(id==5512 or id=='Healthstone');if ready then return 'Healthstone',234 end end}
    local step={type='item',action={5512}}
    local spells=a:GetSpellIds(step);assert(#spells==0)
    ready=true
    spells=a:GetSpellIds(step);assert(spells[1]==234,'native item spell was missing or a nil lookup was cached indefinitely')
    local idReady=false;env.GetItemInfoInstant=nil
    env.C_Item.GetItemInfoInstant=function(name) assert(name=='Healthstone');if idReady then return 5512 end end
    local named={type='item',action={'Healthstone'}}
    spells=a:GetSpellIds(named);assert(#spells==0,'unresolved named item returned an unpaired use spell')
    idReady=true
    local ids;spells,ids=a:GetSpellIds(named)
    assert(spells[1]==234 and ids[1]==5512,'native named item ID was missing or failed to recover after loading')
    env.C_Container={GetContainerNumSlots=function(bag) return bag==0 and 1 or 0 end,
        GetContainerItemInfo=function() return {itemID=5512,stackCount=2} end}
    a:UpdateBagContents(nil)
    assert(a.bagContents[5512].spell=='Healthstone' and a.bagContents[5512].count==2,'native bag item use metadata was discarded')
end)

test('legacy validation reads the declared database rather than the addon folder name',function()
    local env,a,_,load=persistentFixture()
    env.RotationMasterDB={global={},char={},profiles={}};env.rotationmasterDB=nil
    a.deepcopy=function(value) return value end
    a.cleanArray=function(value) for key in pairs(value) do value[key]=nil end end
    load('validate.lua')
    a:validate({global={},char={},profile={}},false)
end)

test('real skill refresh selects native namespaces clears previous advice and pauses on unavailable selection',function()
    local env,a=persistentFixture()
    env.WOW_PROJECT_ID=1;env.LE_EXPANSION_LEVEL_CURRENT=12
    env.C_SpecializationInfo={GetSpecialization=function() return 2 end,
        GetSpecializationInfo=function(index) assert(index==2);return 264,'Restoration' end}
    env.GetSpecializationInfo=nil;env.GetSpecialization=nil
    env.GetTalentInfo=function() error('raw obsolete talent cache was queried') end
    local cleanupSpec,cleared,refreshed
    a.RemoveAllCurrentGlows=function(self) cleanupSpec=self.currentSpec end
    a.DestroyAllGlows=function() cleared=true end
    a.UpdateSpecSpells=function() refreshed=true end
    a.UpdateAutoSwitch=function() end;a.SwitchRotation=function() end;a.ButtonFetch=function() end
    a.currentSpec=262;a.currentRotation='old-manual';a.currentSpell=403;a.manualRotation=true
    a:UpdateSkill()
    assert(a.currentSpec==264 and cleanupSpec==262 and cleared and refreshed,'previous spec advice was retained or cleanup ran in new namespace')
    assert(a.currentRotation==nil and a.currentSpell==nil and not a.manualRotation)
    local selected
    a.specTab={SelectTab=function(_,value) selected=value end}
    env.WOW_PROJECT_ID=19;env.WOW_PROJECT_MISTS_CLASSIC=19;env.LE_EXPANSION_LEVEL_CURRENT=4
    env.C_SpecializationInfo={GetActiveSpecGroup=function() return 2 end}
    env.GetNumTalentTabs=nil;env.GetNumTalents=nil
    a:UpdateSkill();assert(a.currentSpec==2 and selected==2,'progression tabs must use numeric saved group keys')
    a.currentRotation='group-advice';a.currentSpell=8042;refreshed=false;cleared=false
    a.autoswitchRotation={'stale'};a.longtermCache={old=true}
    env.C_SpecializationInfo.GetActiveSpecGroup=function() return nil end
    a:UpdateSkill()
    assert(a.currentSpec==nil and a.currentRotation==nil and a.currentSpell==nil and cleared)
    assert(not refreshed and next(a.autoswitchRotation)==nil and next(a.longtermCache)==nil,'unknown spec reused old observations')
    a.Fetch=function() error('must not fetch without a readable namespace') end
    a:EnableRotation();assert(a.currentRotation==nil)
end)

local function recommendationFixture()
    local env,a,_,load=persistentFixture()
    for _,path in ipairs({'Platform/spells.lua','Platform/actions.lua','Platform/range.lua'}) do load(path) end
    local state={combat=true,active=false,known={[403]=true,[8042]=true,[324]=true,[6603]=true},
        range={},cooldowns={},gate=false,optional={},main=nil,stock={},itemCooldowns={}}
    env.GetTime=function() return 100 end;a.lastCacheReport=100
    env.IsSpellKnown=function(id) return state.known[id]==true end
    env.C_Spell={GetSpellInfo=function(id) return {spellID=id,name='Spell '..id,iconID=1} end,
        GetSpellCooldown=function(id) return {startTime=99,duration=state.cooldowns[id] or 0,isEnabled=true,modRate=1} end,
        IsSpellUsable=function() return true,false end,SpellHasRange=function(id) return id~=324 end,
        IsSpellInRange=function(id) if state.range[id]~=nil then return state.range[id] end;return true end,
        IsCurrentSpell=function() return state.active end}
    env.UnitExists=function() return true end;env.UnitCanAttack=function() return true end
    env.UnitIsDeadOrGhost=function() return false end;env.UnitHasVehicleUI=function() return false end
    env.UnitAffectingCombat=function() return state.combat end
    env.C_Item={GetItemCount=function(id) return state.stock[id] or 0 end,IsUsableItem=function() return true,false end,
        GetItemSpell=function(id) return 'Item use',id==5512 and 234 or 235 end,
        ItemHasRange=function() return false end}
    env.C_Container={GetItemCooldown=function(id) return 99,state.itemCooldowns[id] or 0,1 end}
    a.currentSpec=0;a.currentRotation='test-priority';a.units={}
    a.db.profile.rotations[0]={['test-priority']={name='Runtime priority',rotation={},cooldowns={}}}
    a.db.profile.ignore_range=true
    a:RegisterCondition('TEST_GATE',{description='Fixture gate',icon=1,fields={},valid=function() return true end,
        evaluate=function() if state.gate=='unknown' then return nil,'unavailable-fixture' end;return state.gate end,
        print=function() return 'Fixture gate' end,widget=function() end,help=function() end})
    a.FindSpell=function(_,ids) return ids and ids[1],1 end
    a.IsGlowing=function() return false end
    a.GlowNextSpell=function(_,id) state.main=id end;a.GlowClear=function() state.main=nil end
    a.GlowCooldown=function(_,id,on) state.optional[id]=on end
    return env,a,state,a.db.profile.rotations[0]['test-priority'],load
end

test('real recommendations choose branch arms, skip forced guards and stop safely on unavailable data',function()
    local _,a,state,b=recommendationFixture()
    b.rotation={{id='branch',type='branch',mode='evaluate',conditions={type='TEST_GATE'},
        onTrue={{id='shock',type='spell',ranked=true,action=8042,conditions={}}},
        onFalse={{id='bolt',type='spell',ranked=true,action=403,conditions={}}}},
        {id='tail',type='spell',ranked=true,action=324,conditions={}}}
    b.cooldowns={{id='upkeep',type='spell',ranked=true,action=324,conditions={}}}
    state.gate=true;a:EvaluateNextActionInternal();assert(state.main==8042)
    state.gate=false;a:EvaluateNextActionInternal();assert(state.main==403)
    state.gate='unknown';a:EvaluateNextActionInternal();assert(state.main==nil and state.optional[324],'unknown guard selected False/tail/Attack or blocked optional upkeep')
    b.rotation[1].mode='true';a:EvaluateNextActionInternal();assert(state.main==8042,'forced mode evaluated unavailable guard')
    state.cooldowns[8042]=6;a:EvaluateNextActionInternal();assert(state.main==324,'unready chosen arm failed to rejoin parent sequence')
    b.rotation[1].onTrue={{id='stop',type='none',conditions={}}}
    a:EvaluateNextActionInternal();assert(state.main==6603,'nested Stop fell through or suppressed permitted implicit Attack')
    b.rotation[1].onTrue[1].suppress_attack=true;a:EvaluateNextActionInternal();assert(state.main==nil and state.optional[324])
end)

test('semantic validity follows reachable branches and checks evaluated guards instead of requiring a branch action',function()
    local _,a,_,b=recommendationFixture()
    b.rotation={{id='branch',type='branch',mode='true',conditions={type='TEST_GATE'},onTrue={{id='x',type='spell',action=403,conditions={}}},onFalse={}}}
    assert(a:rotationValidConditions(b,0),'actionless branch was rejected')
    b.rotation[1].onTrue[1].action=nil;assert(not a:rotationValidConditions(b,0),'invalid reachable action was ignored')
end)

test('real recommendation exhaustion uses implicit Attack as normal priority without optional glow or saved steps',function()
    local _,a,s,body=recommendationFixture()
    body.rotation={{id='shock',type='spell',action=8042,ranked=true,conditions={}}}
    body.cooldowns={{id='shield',type='spell',action=324,ranked=true,conditions={}}}
    a:EvaluateNextActionInternal();assert(s.main==8042 and s.optional[324])
    s.cooldowns[8042]=6
    a:EvaluateNextActionInternal()
    assert(s.main==6603 and a.currentSpell==6603,'implicit Attack was not the final main recommendation')
    assert(s.optional[6603]==nil and #body.rotation==1 and #body.cooldowns==1,'implicit Attack was saved or treated as optional')
    s.active=true;a:EvaluateNextActionInternal();assert(s.main==nil and a.currentSpell==nil,'active autoattack was repeatedly prompted')
    s.active=false;s.combat=false;a:EvaluateNextActionInternal();assert(s.main==nil,'fallback proposed a new pull')
    s.combat=true;s.range[6603]=false;a:EvaluateNextActionInternal();assert(s.main==nil,'fallback recommended an out-of-melee attack')
end)

test('conditional Stop ends priorities and optionally suppresses Attack while preserving previews and independent upkeep',function()
    local env,a,s,body=recommendationFixture()
    local stop={id='stop',type='none',conditions={type='TEST_GATE'}}
    body.rotation={stop,{id='bolt',type='spell',action=403,ranked=true,conditions={}}}
    body.cooldowns={{id='shield',type='spell',action=324,ranked=true,conditions={}}}
    s.gate=true;a:EvaluateNextActionInternal();assert(s.main==6603 and s.optional[324],'Stop suppressed the default Attack fallback')
    stop.suppress_attack=true;a:EvaluateNextActionInternal();assert(s.main==nil and s.optional[324])
    stop.suppress_attack=false;a:EvaluateNextActionInternal();assert(s.main==6603)
    stop.suppress_attack=nil
    s.gate=false;a:EvaluateNextActionInternal();assert(s.main==403)
    s.gate='unknown';a:EvaluateNextActionInternal();assert(s.main==nil,'unknown Stop guard fell through')
    stop.disabled=true;a:EvaluateNextActionInternal();assert(s.main==403)
    stop.disabled=false;s.gate=true
    body.rotation={{id='first',type='spell',action=403,ranked=true,conditions={}},stop}
    local widget=dofile('tests/fixtures/addon.lua').new().widget
    env.LibStub('AceGUI-3.0').Create=function(_,kind) return widget(kind) end
    a.nextWindow=widget('preview')
    function a.nextWindow:ReleaseChildren() self.children={} end
    function a.nextWindow:PauseLayout() end;function a.nextWindow:ResumeLayout() end;function a.nextWindow:DoLayout() end
    a.db.profile.preview_spells=5
    a:EvaluateNextActionInternal();assert(s.main==403 and a.currentSpell==403 and #a.nextWindow.children==1)
    body.rotation[2]={id='unready',type='spell',action=8042,ranked=true,conditions={}}
    s.cooldowns[8042]=6
    a:EvaluateNextActionInternal();assert(s.main==403 and a.currentSpell==403,'later unready preview cleared the first recommendation')
end)

test('real main action checks apply to every bank and paired item alternative despite no explicit readiness conditions',function()
    local env,a,s,body=recommendationFixture();s.combat=false
    for _,kind in ipairs({'spell','pet','any'}) do
        body.rotation={{id='plain',type=kind,action=403,ranked=true,conditions={}}}
        body.cooldowns={{id='optional',type=kind,action=403,ranked=true,conditions={}}}
        s.known[403]=true;a:EvaluateNextActionInternal();assert(s.main==403 and s.optional[403],kind)
        s.known[403]=false;a:EvaluateNextActionInternal();assert(s.main==nil and s.optional[403]==false,'unlearned '..kind..' remained highlighted')
        s.known[403]=true;s.range[403]=false;a:EvaluateNextActionInternal();assert(s.main==nil and not s.optional[403],'range bypassed '..kind)
        s.range[403]=true
    end
    env.C_SpellBook=nil
    body.rotation={{id='items',type='item',action={5512,5513},conditions={}}};body.cooldowns={}
    s.stock[5512]=0;s.stock[5513]=1
    a:EvaluateNextActionInternal();assert(s.main==235,'first unavailable item blocked a usable alternative')
    s.stock[5512]=1;s.itemCooldowns[5512]=120
    a:EvaluateNextActionInternal();assert(s.main==235,'first cooling-down item blocked the second')
    s.itemCooldowns[5513]=120;a:EvaluateNextActionInternal();assert(s.main==nil,'cooling-down item was recommended')
end)

test('real recommendation and real button registry cannot borrow an unavailable item sharing the same use spell',function()
    local env,a,s,body,load=recommendationFixture();s.combat=false
    env.LibStub:NewLibrary('LibCustomGlow-1.0',1)
    env.tinsert=table.insert
    local first={GetAttribute=function(_,key) if key=='type' then return 'item' elseif key=='item' then return 5512 end end}
    env.ActionButton1=first
    env.C_Item.GetItemSpell=function() return 'Shared use',234 end
    load('buttons.lua')
    a.db.profile.effect='test';a.db.global.effects.test={type='pixel'}
    local lit={}
    a.Glow=function(_,button,key) lit[button]=lit[button] or {};lit[button][key]=true end
    a.HideGlow=function(_,button,key) if lit[button] then lit[button][key]=nil end end
    local function fetch()
        local rotation=a.currentRotation;a.currentRotation=nil;a:Fetch();a.currentRotation=rotation
    end
    fetch();body.rotation={{id='shared-item',type='item',action={5512,5513},conditions={}}}
    body.cooldowns={{id='shared-optional',type='item',action={5512,5513},conditions={}}}
    s.stock[5513]=1;a:EvaluateNextActionInternal()
    assert(a.currentSpell==nil and not lit[first],'unmapped ready item authorized the unavailable item button')
    local second={GetAttribute=function(_,key) if key=='type' then return 'item' elseif key=='item' then return 5513 end end}
    env.ActionButton2=second;fetch();a:EvaluateNextActionInternal()
    assert(a.currentSpell==234 and lit[second].next and lit[second][234])
    assert(not(lit[first] and (lit[first].next or lit[first][234])),'wrong item highlighted in a main or optional channel')
end)

test('real recommendation passes follow a changed macro without a full bar fetch or edit event',function()
    local env,a,s,body,load=recommendationFixture();s.combat=false
    env.LibStub:NewLibrary('LibCustomGlow-1.0',1);env.tinsert=table.insert
    local exposed=403
    env.GetMacroItem=function() return nil,nil end
    env.GetMacroSpell=function() return exposed end
    local button={GetAttribute=function(_,key) if key=='type' then return 'macro' elseif key=='macro' then return 1 end end}
    env.ActionButton1=button;load('Platform/macros.lua');load('buttons.lua')
    a.db.profile.effect='test';a.db.global.effects.test={type='pixel'}
    local lit={}
    a.Glow=function(_,frame,key) assert(frame==button);lit[key]=true end
    a.HideGlow=function(_,frame,key) assert(frame==button);lit[key]=nil end
    local rotation=a.currentRotation;a.currentRotation=nil;a:Fetch();a.currentRotation=rotation
    a.Fetch=function() error('ordinary recommendation rescanned all bars') end
    body.rotation={{id='bolt',type='spell',ranked=true,action=403,conditions={}},
        {id='shock',type='spell',ranked=true,action=8042,conditions={}}}
    body.cooldowns={{id='optional-bolt',type='spell',ranked=true,action=403,conditions={}},
        {id='optional-shock',type='spell',ranked=true,action=8042,conditions={}}}
    a:EvaluateNextActionInternal();assert(a.currentSpell==403 and lit.next and lit[403])
    exposed=8042;a:EvaluateNextActionInternal()
    assert(a.currentSpell==8042 and lit.next and lit[8042] and not lit[403],'changed macro kept stale priority or cooldown')
    exposed=nil;a:EvaluateNextActionInternal()
    assert(a.currentSpell==nil and not next(lit),'unavailable macro retained a recommendation')
    exposed=403;a:EvaluateNextActionInternal();assert(a.currentSpell==403 and lit.next and lit[403])
end)

test('workbench scale has a canonical default and survives real SavedVariables reload',function()
    local env,a,scripts=persistentFixture()
    assert(a.db.global.uiScale==1)
    a.db.global.uiScale=.85;scripts.OnEvent(nil,'PLAYER_LOGOUT')
    local saved={RotationMasterDB=savedVariablesCopy(env.RotationMasterDB)}
    local _,b=persistentFixture(saved)
    assert(b.db.global.uiScale==.85)
end)

test('item announcements resolve their item action and deduplicate successful casts',function()
    local env,a,load=fixture();load('main.lua');initialize(a)
    a.debug=function() end;a.deepcopy=function(value) local result={};for k,v in pairs(value) do result[k]=v end;return result end
    env.GetItemInfo=function() return 'Water','item:1' end
    a.db.profile.announces={{id='item',type='item',item={1},event='SUCCEEDED',announce='local',value='Used item'}};a.announced={};a.spellHistory={}
    a.events={SUCCEEDED='Succeeded'};local calls=0;a.announce=function() calls=calls+1 end
    a.GetSpellIds=function(_,entry) if entry.action and entry.action[1]==1 then return {123},{1} end;return {} end
    a:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED','player','cast-one',123)
    a:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED','player','cast-one',123)
    assert(calls==1,'item announcement was not dispatched exactly once')
end)

test('item announcement links use protected native metadata and preserve literal percent characters',function()
    local env,a,load=fixture();load('main.lua');initialize(a)
    a.debug=function() end;a.deepcopy=function(value) local result={};for k,v in pairs(value) do result[k]=v end;return result end
    env.GetItemInfo=nil;env.C_Item={GetItemInfo=function() return 'Water 100%','|Hitem:1|h[Water 100%]|h' end}
    a.db.profile.announces={{id='item',type='item',item={1},event='SUCCEEDED',announce='local',value='Used {{item}}'}}
    a.announced={};a.spellHistory={};a.events={SUCCEEDED='Succeeded'};local text
    a.announce=function(_,value) text=value end
    a.GetSpellIds=function() return {123},{1} end
    a:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED','player','native-item',123)
    assert(text=='Used |Hitem:1|h[Water 100%]|h',tostring(text))
    env.C_Item.GetItemInfo=function() error('unavailable') end
    a:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED','player','unavailable-item',123)
    assert(text=='Used {{item}}','failed data revived a previous item link')
end)

test('audible announcements play once without chat even without announcement text',function()
    local env,a,load=fixture();local lib=env.LibStub;env.LibStub=function(name,...) if name=='LibSharedMedia-3.0' then return {Fetch=function(_,kind,key) assert(kind=='sound' and key=='Chime');return 'chime.ogg' end} end;return lib(name,...) end
    local played,chat=0,0;env.PlaySoundFile=function(path,channel) assert(path=='chime.ogg' and channel=='Master');played=played+1 end;env.SendChatMessage=function() chat=chat+1 end
    load('main.lua');initialize(a);a.debug=function() end;a.deepcopy=function(value) local result={};for k,v in pairs(value) do result[k]=v end;return result end;a.announce=function() chat=chat+1 end;a.announced={};a.spellHistory={};a.events={SUCCEEDED='Succeeded'}
    a.db.profile.announces={{id='sound',type='spell',spell=403,event='SUCCEEDED',announce='audible',announce_sound='Chime'}};a.GetSpellIds=function() return {403},{} end
    a:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED','player','cast-sound',403);a:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED','player','cast-sound',403);assert(played==1 and chat==0)
end)
test('item binding reconciliation follows moves and clears removed or replaced actions',function()
    local env,a,load=fixture();load('main.lua');initialize(a);a.debug=function() end;a.ButtonFetch=function() end;a.tablelength=function(t) return #t end;a.db.char.bindings={s={1,2}};local actions={[1]=11,[2]=11};local cursor
    env.GetActionInfo=function(slot) if actions[slot] then return 'item',actions[slot] end end;env.GetCursorInfo=function() if cursor then return 'item',cursor end end
    a.FindItemInItemSet=function(_,id,item) return id=='s' and item==11 and 1 or nil end;local refreshed=0;a.itemSetCallback=function() refreshed=refreshed+1 end
    actions[1]=nil;cursor=11;a:ACTIONBAR_SLOT_CHANGED('ACTIONBAR_SLOT_CHANGED',1);assert(#a.db.char.bindings.s==1 and a.bindingItemSet=='s')
    actions[3]=11;cursor=nil;a:ACTIONBAR_SLOT_CHANGED('ACTIONBAR_SLOT_CHANGED',3);assert(#a.db.char.bindings.s==2 and a.bindingItemSet==nil)
    actions[2]=99;a:ACTIONBAR_SLOT_CHANGED('ACTIONBAR_SLOT_CHANGED',2);assert(#a.db.char.bindings.s==1 and a.db.char.bindings.s[1]==3)
    actions[3]=nil;a:ACTIONBAR_SLOT_CHANGED('ACTIONBAR_SLOT_CHANGED',3);assert(a.db.char.bindings.s==nil and refreshed>=4)
end)
test('Unbind removes all still-matching bar actions and preserves replaced slots and combat state',function()
    local env,a,load=fixture();load('main.lua');initialize(a);a.db.char.bindings={s={1,2,3}};a.ButtonFetch=function() end;a.EndHighlightSlot=function() end;a.FindItemInItemSet=function(_,id,item) return item==11 and 1 or nil end
    local actions={[1]=11,[2]=11,[3]=99};env.GetActionInfo=function(slot) return 'item',actions[slot] end;env.PickupAction=function(slot) actions[slot]=nil end;env.ClearCursor=function() end;env.InCombatLockdown=function() return true end
    assert(a:UnbindItemSet('s')==false and actions[1]==11 and a.db.char.bindings.s);env.InCombatLockdown=function() return false end;a:UnbindItemSet('s');assert(actions[1]==nil and actions[2]==nil and actions[3]==99 and a.db.char.bindings.s==nil)
end)
test('audible announcement safely tolerates a missing sound playback API',function()
    local env,a,load=fixture();env.PlaySoundFile=nil;load('main.lua');initialize(a);a.debug=function() end;a.deepcopy=function(value) local copy={};for key,v in pairs(value) do copy[key]=v end;return copy end;a.announced={};a.spellHistory={};a.events={SUCCEEDED='Success'};a.GetSpellIds=function() return {403},{} end;a.db.profile.announces={{id='sound',type='spell',spell=403,event='SUCCEEDED',announce='audible',announce_sound='Sound'}}
    local ok,why=pcall(a.UNIT_SPELLCAST_SUCCEEDED,a,'UNIT_SPELLCAST_SUCCEEDED','player','missing-sound-api',403);assert(ok,why)
end)
test('real cast announcement supports a native-only chat sender and modern raid roles',function()
    local env,a,load=fixture();load('main.lua');initialize(a);a.debug=function() end
    a.deepcopy=function(value) local result={};for k,v in pairs(value) do result[k]=v end;return result end
    a.Platform.GetSpellLink=function() return 'Lightning Bolt' end;a.GetSpellIds=function() return {403},{} end
    a.announced={};a.spellHistory={};a.events={SUCCEEDED='Succeeded'}
    a.db.profile.announces={{id='native',type='spell',spell=403,event='SUCCEEDED',announce='raidwarn',value='Cast {{spell}}'}}
    env.IsInRaid=function() return true end;env.IsInGroup=function() return true end
    env.UnitIsGroupLeader=function() return false end;env.UnitIsGroupAssistant=function() return true end
    env.IsRaidLeader=nil;env.SendChatMessage=nil;local sent=0
    env.C_ChatInfo={SendChatMessage=function(text,destination) assert(text=='Cast Lightning Bolt' and destination=='RAID_WARNING');sent=sent+1 end}
    a:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED','player','native',403)
    a:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED','player','native',403)
    assert(sent==1 and a.announced.native[1]=='native')
end)
test('failed chat or sound output does not abort real cast bookkeeping',function()
    local env,a,load=fixture();local lib=env.LibStub
    env.LibStub=function(name,...) if name=='LibSharedMedia-3.0' then return {Fetch=function() return 'chime.ogg' end} end;return lib(name,...) end
    load('main.lua');initialize(a);a.debug=function() end
    a.deepcopy=function(value) local result={};for k,v in pairs(value) do result[k]=v end;return result end
    a.Platform.GetSpellLink=function() return 'Lightning Bolt' end;a.GetSpellIds=function() return {403},{} end
    a.announced={};a.spellHistory={};a.events={SUCCEEDED='Succeeded'}
    a.db.profile.announces={{id='failed-output',type='spell',spell=403,event='SUCCEEDED',announce='emote',announce_sound='Chime',value='Cast'}}
    env.SendChatMessage=function() error('chat blocked') end;env.PlaySoundFile=function() error('sound blocked') end
    a:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED','player','blocked-output',403)
    assert(a.announced['failed-output'][1]=='blocked-output' and #a.spellHistory==1)
end)
test('reference-only clients retain metadata registration without combat observations',function()
    local observation={'NAME_PLATE_UNIT_ADDED','NAME_PLATE_UNIT_REMOVED','UNIT_COMBAT','UNIT_SPELLCAST_SENT','UNIT_SPELLCAST_START','UNIT_SPELLCAST_STOP','UNIT_SPELLCAST_SUCCEEDED','UNIT_SPELLCAST_INTERRUPTED','UNIT_SPELLCAST_FAILED','UNIT_SPELLCAST_DELAYED','UNIT_SPELLCAST_CHANNEL_START','UNIT_SPELLCAST_CHANNEL_STOP','COMBAT_LOG_EVENT_UNFILTERED'}
    for _,project in ipairs({1,18,98765}) do
        local env,a,load=fixture();env.WOW_PROJECT_ID=project;env.WOW_PROJECT_CAMELOT=18;load('main.lua');initialize(a)
        local registered={};a.RegisterEvent=function(_,event) registered[event]=true end;a.UpdateSkill=function() end;a.EnableRotation=function() end
        a:enable()
        for _,event in ipairs(observation) do assert(not registered[event],'reference-only mode registered '..event) end
        for _,event in ipairs({'SPELLS_CHANGED','SPELL_DATA_LOAD_RESULT','ITEM_DATA_LOAD_RESULT','PLAYER_ENTERING_WORLD','BAG_UPDATE'}) do assert(registered[event],'reference event missing: '..event) end
    end
    for _,project in ipairs({2,5,19}) do
        local env,a,load=fixture();env.WOW_PROJECT_ID=project;env.WOW_PROJECT_MISTS_CLASSIC=19
        local lib=env.LibStub;env.LibStub=function(name,...) if name=='LibClassicDurations' then return {Register=function() end} end;return lib(name,...) end
        load('main.lua');initialize(a)
        local registered={};a.RegisterEvent=function(_,event) registered[event]=true end;a.UpdateSkill=function() end;a.EnableRotation=function() end
        a:enable();for _,event in ipairs(observation) do assert(registered[event],'probe client lost '..event) end
    end
end)
test('reference-only combat callbacks ignore payloads before logging querying or mutation',function()
    local events={'NAME_PLATE_UNIT_ADDED','NAME_PLATE_UNIT_REMOVED','UNIT_COMBAT','UNIT_SPELLCAST_SENT','UNIT_SPELLCAST_START','UNIT_SPELLCAST_STOP','UNIT_SPELLCAST_SUCCEEDED','UNIT_SPELLCAST_INTERRUPTED','UNIT_SPELLCAST_FAILED','UNIT_SPELLCAST_DELAYED','UNIT_SPELLCAST_CHANNEL_START','UNIT_SPELLCAST_CHANNEL_STOP','COMBAT_LOG_EVENT_UNFILTERED'}
    for _,project in ipairs({1,18,98765}) do
        local env,a,load=fixture();env.WOW_PROJECT_ID=project;env.WOW_PROJECT_CAMELOT=18;load('main.lua');initialize(a)
        local secret={};env.issecretvalue=function(value) return value==secret end
        local function forbidden() error('reference-only payload consumed') end
        a.debug=forbidden;env.UnitGUID=forbidden;env.CombatLogGetCurrentEventInfo=forbidden;env.GetTime=forbidden;a.GetSpellIds=forbidden;a.DispatchAnnouncement=forbidden
        local combat,spells,damage,units=a.combatHistory,a.spellHistory,a.damageHistory,a.unitsInRange
        for _,event in ipairs(events) do
            local ok,why=pcall(a[event],a,event,'player',secret,secret,secret,secret)
            assert(ok,event..': '..tostring(why))
        end
        assert(a.combatHistory==combat and next(combat)==nil and a.spellHistory==spells and #spells==0 and a.damageHistory==damage and next(damage)==nil and a.unitsInRange==units and next(units)==nil)
        local learned,items
        a.debug=function() end;a.SpellCatalog={UpdateSpell=function(_,id) learned=id end}
        env.LibStub('AceGUI-3.0-ItemLoader').UpdateItem=function(_,id) items=id end
        a:SPELL_DATA_LOAD_RESULT('SPELL_DATA_LOAD_RESULT',403,true);a:ITEM_DATA_LOAD_RESULT('ITEM_DATA_LOAD_RESULT',1,true)
        assert(learned==403 and items==1,'reference metadata callbacks were suppressed')
    end
end)
test('new item-set binding normalizes every slot immediately to the first available item',function()
    local env,a,load=fixture();load('main.lua');initialize(a);a.debug=function() end;a.ButtonFetch=function() end;a.db.char.bindings={s={2}};a.bindingItemSet='s';local actions={[1]=11,[2]=11};local held
    env.GetActionInfo=function(slot) return 'item',actions[slot] end;env.GetCursorInfo=function() end;a.FindItemInItemSet=function(_,_,item) return item==11 or item==22 end;a.FindFirstItemOfItemSet=function() return 22 end
    env.PickupItem=function(id) held=id end;env.PlaceAction=function(slot) actions[slot]=held end;env.ClearCursor=function() held=nil end
    a:ACTIONBAR_SLOT_CHANGED('ACTIONBAR_SLOT_CHANGED',1);assert(actions[1]==22 and actions[2]==22 and #a.db.char.bindings.s==2)
end)
test('real item-set helpers update and unbind bars through native-only item APIs without editor loading',function()
    local env,a,load=fixture();load('Platform/inventory.lua');load('Core/item_conditions.lua');load('Core/item_sets.lua');load('main.lua');initialize(a)
    a.debug=function() end;a.ButtonFetch=function() end;a.EndHighlightSlot=function() end
    a.db.profile.itemsets={s={items={11,22}}};a.db.global.itemsets={};a.db.char.bindings={s={1,2}}
    env.GetItemInfoInstant=nil;env.IsEquippedItem=nil;env.NUM_BAG_SLOTS=4
    env.C_Item={IsEquippedItem=function() return false end}
    env.C_Container={GetContainerNumSlots=function(bag) return bag==0 and 1 or 0 end,
        GetContainerItemInfo=function() return {itemID=22,stackCount=1} end}
    local actions={[1]=11,[2]=11,[3]=99};local held
    env.GetActionInfo=function(slot) return 'item',actions[slot] end
    env.PickupItem=function(id) held=id end;env.PlaceAction=function(slot) actions[slot]=held end;env.ClearCursor=function() held=nil end
    env.PickupAction=function(slot) actions[slot]=nil end
    assert(a:UpdateBoundButton('s') and actions[1]==22 and actions[2]==22,'real native resolver did not normalize bound slots')
    actions[2]=99;a:UnbindItemSet('s')
    assert(actions[1]==nil and actions[2]==99 and actions[3]==99 and a.db.char.bindings.s==nil)
end)
test('runtime bag snapshots include declared equipped bags and retain legacy slots plus accurate locations',function()
    local env,a,load=fixture();env.NUM_TOTAL_EQUIPPED_BAG_SLOTS=5;env.NUM_BAG_SLOTS=4
    env.C_Container={GetContainerNumSlots=function(bag) return (bag==0 or bag==5) and 1 or 0 end,
        GetContainerItemInfo=function(bag) return {itemID=5512,stackCount=bag==0 and 2 or 4} end}
    env.C_Item={GetItemSpell=function() return 'Healthstone',234 end}
    load('main.lua');initialize(a);a:UpdateBagContents(nil)
    local item=a.bagContents[5512];assert(item.count==6,'declared fifth carried bag was omitted')
    assert(item.spell=='Healthstone' and #item.slots==2 and item.slots[1]==1 and item.slots[2]==1)
    assert(#item.locations==2 and item.locations[1].bag==0 and item.locations[2].bag==5 and item.locations[2].slot==1)
    assert(a.bagContentsUnavailable==nil)
end)
test('runtime bag snapshots discard incomplete observations without publishing partial or stale counts and recover',function()
    local env,a,load=fixture();env.NUM_BAG_SLOTS=4;local secret={}
    env.canaccessvalue=function(value) return not rawequal(value,secret) end
    local bad;env.C_Container={GetContainerNumSlots=function(bag) return bag==0 and 2 or 0 end,
        GetContainerItemInfo=function(_,slot) if slot==1 then return {itemID=5512,stackCount=2} end;if bad=='error' then error('slot not readable') end;return bad end}
    load('main.lua');initialize(a)
    for _,record in ipairs({secret,{}, {itemID=5512,stackCount=secret},'error'}) do
        a.bagContents={[99]={count=8}};bad=record
        local ok,ready,reason=pcall(a.UpdateBagContents,a,nil)
        assert(ok and ready==false and reason and a.bagContentsUnavailable==reason,'failed snapshot escaped or lost its unavailable reason')
        assert(next(a.bagContents)==nil,'failed scan published partial or stale inventory')
    end
    bad=nil;assert(a:UpdateBagContents(nil)==true and a.bagContents[5512].count==2 and a.bagContentsUnavailable==nil)
end)
test('real AceDB global item references refresh packaged validation without copying into profile data',function()
    local _,a=persistentFixture();local id='fixture.global-items'
    local pack={format='RotationMaster',schemaVersion=1,id=id,revision=1,nameKey='Global reference fixture',descriptionKey='Fixture',
        applicability={families={'tbc'},actionContext='player',class='SHAMAN'},body={rotation={{id='global-item',type='item',action='shared'}},cooldowns={}}}
    a.db.global.itemsets.shared={name='Shared',items={5512}}
    assert(a:RegisterDefaultRotation(pack));assert(a:InitializeRotationLibrary())
    local function row() for _,value in ipairs(a:ListDefaultRotations(0)) do if value.id==id then return value end end end
    assert(row().eligible and a.db.profile.itemsets.shared==nil)
    a.db.global.itemsets.shared=nil;assert(not row().eligible)
    a.db.global.itemsets.shared={name='Restored',items={5512}};assert(row().eligible)
    assert(a.db.profile.itemsets.shared==nil,'reference normalization wrote global sets into the profile')
end)
test('real recommendation engine fills the native preview with spell and item icons without AceGUI icons',function()
    local env,a,state,body,load=recommendationFixture();dofile('tests/fixtures/native_ui.lua')(env);load('UI/controls.lua');load('UI/preview.lua')
    env.C_Item.GetItemInfo=function(id) return 'Item '..id,nil,nil,nil,nil,nil,nil,nil,nil,id+10 end
    env.LibStub('AceGUI-3.0').Create=function() error('native preview allocated AceGUI') end
    local lib=env.LibStub;env.LibStub=function(name,...) assert(name~='AceGUI-3.0','native preview requested legacy widget library');return lib(name,...) end
    a.db.profile.preview_spells=2;state.stock[5512]=1;state.combat=false
    body.rotation={{id='bolt',type='spell',action=403,ranked=true,conditions={}},{id='stone',type='item',action={5512},conditions={}}}
    local w=a:CreateNativePreviewWindow();a:EvaluateNextActionInternal()
    assert(w.count==2 and w.icons[1].spellId==403 and w.icons[2].itemId==5512 and w.icons[2].texture:GetTexture()==5522)
    local first,second=w.icons[1],w.icons[2];state.stock[5512]=0;a:EvaluateNextActionInternal();assert(w.icons[1]==first and not second:IsShown())
end)
test('broker launcher toggles the workbench through its guarded Hide without creating dropdowns',function()
    local env,a,load=fixture(true);load('main.lua');local opened,closed=0,0;local shown=false
    env.CreateFrame=function() error('left click created a dropdown') end
    a.ShowConfig=function(_,section) assert(section=='Rotations');opened=opened+1;shown=true end
    a.configWindow={frame={IsShown=function() return shown end},Hide=function() closed=closed+1 end}
    env.broker.OnClick(nil,'LeftButton');assert(opened==1 and shown)
    env.broker.OnClick(nil,'LeftButton');assert(opened==1 and closed==1 and shown,'launcher bypassed pending-change close guard')
    shown=false;env.broker.OnClick(nil,'LeftButton');assert(opened==2)
end)
test('main metadata events update the actual ItemLoader consumed by native reference search',function()
    for _,modern in ipairs({false,true}) do
        local env,a,load=fixture(modern);local previous=env.LibStub;env.LibStub=nil;load('Libs/LibStub/LibStub.lua')
        local lib=env.LibStub;local call=getmetatable(lib).__call
        getmetatable(lib).__call=function(self,name,silent) if self.libs[name] then return call(self,name,silent) end;return previous(name,silent) end
        load('Libs/AceGUI-3.0-Item-EditBox/ItemLoader.lua');local item=lib('AceGUI-3.0-ItemLoader');local available=false
        env.GetItemInfoInstant=function(value) if value==10 or value=='Event potion' then return 10,nil,nil,nil,110 end end
        env.GetItemInfo=function(id) if available and id==10 then return 'Event potion','item:10',nil,nil,nil,nil,nil,nil,nil,110 end end
        load('main.lua');initialize(a);a.debug=function() end
        a:ITEM_DATA_LOAD_RESULT('ITEM_DATA_LOAD_RESULT',10,false);assert(not item.itemList[10])
        available=true;a:ITEM_DATA_LOAD_RESULT('ITEM_DATA_LOAD_RESULT',10,true)
        assert(item.itemList[10].name=='Event potion' and item.itemList[10].link=='item:10' and item.itemListReverse['event potion']==10 and not item.loader)
        load('Core/reference_catalog.lua');local rows=a:GetReferenceProvider('Item_EditBox').search('',{limit=20});assert(#rows==1 and rows[1].id==10 and rows[1].name=='Event potion')
    end
end)
test('source import provenance has a global default and survives real AceDB reload',function()
    local env,a,scripts=persistentFixture()
    assert(type(a.db.global.function_import_origins)=='table','source provenance is missing from global defaults')
    a.db.global.function_import_origins['function:example']={sourceId='original',name='Example'}
    scripts.OnEvent(nil,'PLAYER_LOGOUT')
    local _,b=persistentFixture({RotationMasterDB=savedVariablesCopy(env.RotationMasterDB)})
    assert(b.db.global.function_import_origins['function:example'].sourceId=='original')
end)
print(string.format('%d passed, %d failed', passed, failures))
os.exit(failures == 0 and 0 or 1)
