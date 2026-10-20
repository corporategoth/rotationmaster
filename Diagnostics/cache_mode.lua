local _,addon=...
-- Diagnostic dispatch is selected once, before utils and built-in callbacks
-- capture their helper references. Changing the request requires a reload.
local type,rawget,rawset,pcall=type,rawget,rawset,pcall
local globals=_G
local function savedGlobal()
 local saved=rawget(globals,'RotationMasterDB')
 return type(saved)=='table' and rawget(saved,'global') or nil
end
local function readyGlobal()
 local db=rawget(addon,'db')
 return type(db)=='table' and rawget(db,'global') or nil
end
local function directRequested(global)
 return type(global)=='table' and rawget(global,'diagnosticCacheBypass')==true
end
local loaded='cached'
if directRequested(savedGlobal()) then
 local functions=rawget(addon,'Functions')
 local owner=type(functions)=='table' and rawget(functions,'cache')
 local modules=rawget(addon,'builtinSourceModules')
 local getter=type(modules)=='table' and rawget(modules,'Functions/cache.lua')
 local ok,internal
 if type(getter)=='function' then ok,internal=pcall(getter,'getCachedInternal') end
 if type(owner)=='table' and ok and type(internal)=='function' then
  -- Reuse the original nil-cache path, preserving global-name resolution,
  -- exact arguments, return arity and errors without touching caller tables.
  owner.getCached=function(_,func,...)return internal(nil,true,func,...)end
  owner.getRetryCached=function(_,func,...)return internal(nil,false,func,...)end
  loaded='direct'
 end
end
function addon:GetCacheDiagnosticMode()
 if self~=addon then return nil,'invalid-owner' end
 local global=readyGlobal();if type(global)~='table' then global=savedGlobal() end
 local requested=directRequested(global) and 'direct' or 'cached'
 return loaded,requested,loaded~=requested
end
function addon:SetCacheDiagnosticMode(mode)
 if self~=addon then return false,'invalid-owner' end
 if mode~='cached' and mode~='direct' then return false,'invalid-cache-mode' end
 local global=readyGlobal()
 if type(global)~='table' then return false,'cache-mode-unavailable' end
 rawset(global,'diagnosticCacheBypass',mode=='direct')
 return true
end
