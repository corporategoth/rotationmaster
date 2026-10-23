-- Joined fixture using existing explicit startup/service and native-frame hosts.
-- Real AceDB, owned Platform/context/library, declarations and Shaman pack.
-- This is neither a complete TOC/vendor boot nor native acceptance.
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function once(source,old,new)
 local a,b=source:find(old,1,true);assert(a,'baseline fixture anchor missing: '..old)
 assert(not source:find(old,b+1,true),'baseline fixture anchor repeated: '..old)
 return source:sub(1,a-1)..new..source:sub(b+1)
end
local startup=read('tests/startup.lua')
local common=assert(startup:match('(local function fixture%(modern, absentThreat%).-)\ntest%('),'startup common boundary missing')
local persistent=assert(startup:match('(local function persistentFixture%(saved,folder,scoped%).-)\n%-%- WoW SavedVariables'),'startup persistent boundary missing')
local addonFixture=read('tests/fixtures/addon.lua')
local support=assert(addonFixture:match("(    load%('UI/controls.lua'%).-)\n    return {env=env"),'native support boundary missing')
-- Identity is assigned before the common fixture's first production load.
common=once(common,'    env.LE_EXPANSION_LEVEL_CURRENT = 1',[[    env.LE_EXPANSION_LEVEL_CURRENT = baseline[3]
    env.WOW_PROJECT_ID = baseline[2]
    env.WOW_PROJECT_BURNING_CRUSADE_CLASSIC,env.WOW_PROJECT_WRATH_CLASSIC=5,11
    env.WOW_PROJECT_CATACLYSM_CLASSIC,env.WOW_PROJECT_MISTS_CLASSIC,env.WOW_PROJECT_CAMELOT=14,19,18
    env.UnitLevel=function() return 11 end
    env.UnitHasVehicleUI=function() return false end
    env.GetNumShapeshiftForms=function() return 0 end
    env.GetBuildInfo=function() return 'Fixture','70006','Fixture',20506 end]])
common=once(common,'    local function load(path)\n        local chunk',[[    local function load(path)
        if firstProject==nil then firstProject=env.WOW_PROJECT_ID end
        local chunk]])
-- These are the same explicit bundled-library stubs used by existing fixtures,
-- not optional-addon installations. Do not invent functions for unknown APIs.
common=once(common,"        ['LibCompress'] = {},",[[        ['LibCompress'] = {},
        ['LibRangeCheck-3.0'] = {},
        ['LibClassicDurations'] = {Register=function() end},]])
persistent=once(persistent,"    addon.GetRotationContext=function() return {family='tbc',class='SHAMAN',level=11,spec=0,actionContext='player',combatDataPolicy='probe'} end\n",'')
persistent=once(persistent,'    assert(addon:RegisterDefaultRotation(envelope()))',[[    -- Reuse the native support loader without changing any shared fixture.
    addon.db={profile={},global={}}
    dofile('tests/fixtures/native_ui.lua')(env)
    local helpers=assert(loadstring('local addon,load=...\n'..support,'@client-baseline-native-support'))
    setfenv(helpers,env);helpers(addon,load)
    for _,path in ipairs({'Platform/spells.lua','Platform/auras.lua','Platform/range.lua',
        'Platform/unit_flags.lua','Platform/unit_attackability.lua','Platform/player_movement.lua',
        'Core/level_conditions.lua','Core/aura_conditions.lua'}) do load(path) end
    for line in io.lines('RotationMaster.toc') do if line:match('^Conditions/') then load(line) end end
    -- The cross-client checks browse a TBC pack on every client family.
    addon.loadAllDefaults=true
    load('tests/fixtures/shaman_starter_pack.lua')]])
persistent=once(persistent,'    addon:OnInitialize()',[[    initialProject=env.WOW_PROJECT_ID
    addon:OnInitialize()]])
-- Native UI installation replaces CreateFrame; keep AceDB's already registered
-- logout host separate. Both hosts are the existing finite explicit fixtures.
local factorySource='local baseline,support=...\nlocal firstProject,initialProject\n'..common..'\n'..persistent..[[
local env,addon,scripts,load=persistentFixture(nil,nil,true)
return env,addon,scripts,load,firstProject,initialProject
]]
return function(case)
 assert(type(case)=='table' and type(case[2])=='number' and type(case[3])=='number','explicit client case required')
 local outerSaved=_G.RotationMasterDB
 local factory=assert(loadstring(factorySource,'@client-baseline-startup'))
 local e,a,scripts,load,firstProject,initialProject=factory(case,support)
 for _,path in ipairs({'UI/rotation_reference.lua','UI/defaults.lua','Data/codec.lua','Data/import_session.lua','Core/imports.lua'}) do load(path) end
 local function optionalAbsent()
  for _,name in ipairs({'WeakAuras','Details','MobInfo2','ExtendedCharacterStats','LuaWorkbench','TitanPanel'}) do
   if e[name]~=nil then return false end
  end
  return true
 end
 assert(optionalAbsent(),'optional addon leaked into fixture')
 local function codec()
  -- The real bundled dependencies already have a JIT-only fixture because
  -- stock system Lua 5.1 has no bit module. No fake compressor or silent skip.
  assert(type(jit)=='table','wire controls require LuaJIT with bit')
  local _,deps=dofile('tests/fixtures/codec.lua')()
  return assert(a.RotationData.NewCodec(deps))
 end
 return {e=e,a=a,scripts=scripts,load=load,firstProject=firstProject,initialProject=initialProject,
  outerSaved=outerSaved,optionalAbsent=optionalAbsent,codec=codec}
end
