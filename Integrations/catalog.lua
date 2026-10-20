local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
-- Addon identities are explicit supported consumers, not every loaded addon or
-- a list of bundled libraries. Listing never discovers/registers providers.
local providers={
 {'ExtendedCharacterStats','ExtendedCharacterStats','Optional character statistics conditions.','ecs'},
 {'MobInfo2','MobInfo2','Recorded creature history conditions; no current history is queried.'},
 {'!!!LuaWorkbench','LuaWorkbench','Lua editor integration. Choose an editor in Lua editor options.','editor'},
 {'WowLua','WowLua','Optional editor addon; no built-in connection is registered.'},
 {'WeakAuras','WeakAuras','Recommendation event bridge; no WeakAuras display is required.'},
 {'Questie','Questie','Quest update receipts only; native quest progress is not verified.','questie'},
 {'ElvUI','ElvUI','Optional action-bar glow support.'},
 {'Bartender4','Bartender4','Optional action-bar mapping and glow support.'},
 {'ButtonForge','ButtonForge','Optional action-bar mapping and glow support.'},
 {'G15Buttons','G15Buttons','Optional action-bar mapping and glow support.'},
 {'SyncUI','SyncUI','Optional action-bar mapping and glow support.'},
 {'LUI','LUI','Optional action-bar mapping and glow support.'},
 {'Dominos','Dominos','Optional action-bar mapping and glow support.'},
 {'DiabolicUI','DiabolicUI','Optional action-bar mapping and glow support.'},
 {'AzeriteUI','AzeriteUI','Optional action-bar mapping and glow support.'},
 {'Neuron','Neuron','Optional action-bar mapping and glow support.'},
 {'FarmingBar','FarmingBar','Optional action-bar mapping and glow support.'},
 {'TotemTimers','TotemTimers','Optional action-bar mapping and glow support.'},
 {'SamyTotemTimers','SamyTotemTimers','Optional action-bar mapping and glow support.'},
}
local questieStates={available='connected',disabled='disabled',missing='missing',waiting='loaded',
 incompatible='incompatible',['client-restricted']='incompatible',error='unknown',unavailable='unknown'}
local function readable(value)
 local ok,accepted=pcall(function()
  local platform=addon.Platform
  return platform and type(platform.CanReadValue)=='function' and platform:CanReadValue(value)==true
 end)
 return ok and accepted==true
end
---@param value any
---@param limit number
local function text(value,limit)
 if not readable(value) or type(value)~='string' then return nil end
 local result,bytes,index={},0,1
 -- Bound output/work, retaining complete UTF-8 codepoints and doubled pipes.
 -- Malformed UTF-8 is replaced per invalid byte; no raw malformed byte escapes.
 while index<=#value and bytes<limit do
  local first=value:byte(index);local width=1;local valid=true
  if first>=194 and first<=223 then width=2
  elseif first>=224 and first<=239 then width=3
  elseif first>=240 and first<=244 then width=4
  elseif first>=128 then valid=false end
  if width>1 then
   for offset=1,width-1 do
    local nextByte=value:byte(index+offset)
    if not nextByte or nextByte<128 or nextByte>191 then valid=false;break end
   end
   if valid then
    local second=value:byte(index+1)
    if (first==224 and second<160) or (first==237 and second>159)
     or (first==240 and second<144) or (first==244 and second>143) then valid=false end
   end
  end
  local char
  if not valid then char='?';width=1
  elseif first<32 or first==127 then char='?'
  elseif first==124 then char='||'
  else char=value:sub(index,index+width-1) end
  if bytes+#char>limit then break end
  result[#result+1]=char;bytes=bytes+#char;index=index+width
 end
 return table.concat(result)
end
local function display(key,limit)
 local ok,value=pcall(function()return L[key]end)
 return (ok and text(value,limit)) or text(key,limit) or key
end
local function native(name,...)
 local args={...}
 local ok,value=pcall(function()
  local namespace=rawget(_G,'C_AddOns')
  local fn=type(namespace)=='table' and rawget(namespace,name) or nil
  if type(fn)~='function' then fn=rawget(_G,name) end
  if type(fn)~='function' then return nil end
  return fn(unpack(args))
 end)
 if not ok or not readable(value) then return nil end
 return value
end
local function connection(kind)
 if kind=='ecs' then
  local definitions=rawget(addon,'conditionDefinitions')
  if readable(definitions) and type(definitions)=='table' then
   local stat,percent=rawget(definitions,'ECS_STAT'),rawget(definitions,'ECS_STAT_PCT')
   if readable(stat) and readable(percent) and type(stat)=='table' and type(percent)=='table' then return 'connected' end
  end
 elseif kind=='editor' then
  local create,provider=rawget(addon,'CreateLuaWorkbenchControl'),rawget(_G,'LuaWorkbench')
  if readable(create) and readable(provider) and type(create)=='function' and type(provider)=='table' then return 'connected' end
 elseif kind=='questie' then
  -- This is RM's cached, detached singleton status, never provider discovery.
  local ok,value=pcall(function()
   local get=addon.GetQuestieIntegrationStatus
   if type(get)=='function' then return get(addon) end
  end)
  if not ok or not readable(value) or type(value)~='table' then return 'unknown' end
  local state=rawget(value,'state')
  if not readable(state) or type(state)~='string' then return 'unknown' end
  return questieStates[state] or 'unknown'
 end
 return 'loaded'
end
function addon:ListIntegrationStatus()
 if not rawequal(self,addon) then return {} end
 local rows={}
 for _,provider in ipairs(providers)do
  local loaded=native('IsAddOnLoaded',provider[1])
  local state=loaded==true and 'loaded' or loaded==false and 'missing' or 'unknown'
  -- Metadata may exist for an installed but not loaded addon. A false loaded
  -- flag alone never establishes that the addon is not installed.
  local version=text(native('GetAddOnMetadata',provider[1],'Version'),96)
  if loaded==true then state=connection(provider[4]) end
  rows[#rows+1]={id=provider[1],name=display(provider[2],96),version=version,state=state,detail=display(provider[3],320)}
 end
 return rows
end
