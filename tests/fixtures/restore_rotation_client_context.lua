-- Strict inverse: private reader additions and exactly five context expressions.
local changes={
 ["Platform/client.lua"]={
  {[==[local ownedClientInfo=platform.GetClientInfo
-- One-time private handoff. Public client metadata keeps its complete shape.
function addon:BindRotationClientReader(bind)
    if type(bind)~='function' then return nil,'invalid-client-reader-binder' end
    bind(function(current)
        local method=current.GetClientInfo
        if method~=ownedClientInfo then return method(current) end
        local project=primitive(WOW_PROJECT_ID)
        local function isProject(constant)
            return type(project)=='number' and type(constant)=='number' and project==constant
        end
        local family='unknown'
        if isProject(WOW_PROJECT_CAMELOT) then family='forever'
        elseif isProject(WOW_PROJECT_MAINLINE) then family='retail'
        elseif isProject(WOW_PROJECT_CLASSIC) then family='era'
        elseif isProject(WOW_PROJECT_BURNING_CRUSADE_CLASSIC) then family='tbc'
        elseif isProject(WOW_PROJECT_MISTS_CLASSIC) or isProject(WOW_PROJECT_CATACLYSM_CLASSIC)
            or isProject(WOW_PROJECT_WRATH_CLASSIC) then family='progression' end
        local context={family=family}
        if type(GetBuildInfo)=='function' then
            local ok,_,build=pcall(GetBuildInfo)
            if ok then context.build=primitive(build) end
        end
        if family=='retail' or family=='forever' then context.combatDataPolicy='restricted'
        elseif family=='unknown' then context.combatDataPolicy='unsupported'
        else context.combatDataPolicy='probe' end
        return context
    end)
    return true
end

]==],[==[]==]},
 },
 ["Core/rotation_library.lua"]={
  {[==[local clientContextReader
local bindClient=addon.BindRotationClientReader
if type(bindClient)=='function' then
    bindClient(addon,function(reader) clientContextReader=reader end)
    addon.BindRotationClientReader=nil
end
-- Only the exact owned methods use the narrow projection. Overrides retain
-- their actual receiver, first result, shared table and error behavior.
local function rotationContext(owner,spec)
    local method=owner.GetRotationContext
    if method~=ownedRotationContext or not clientContextReader then return method(owner,spec) end
    local context=clientContextReader(owner.Platform)
    local function read(fn,...)
        if type(fn)~="function" then return nil end
        local ok,value=pcall(fn,...)
        if ok and owner.Platform:CanReadValue(value) then return value end
    end
    local function class() local _,token=UnitClass("player");return token end
    context.class=read(class)
    context.level=read(UnitLevel,"player")
    context.build=tonumber(context.build)
    context.spec=spec
    context.actionContext="player"
    local vehicle=read(UnitHasVehicleUI,"player")
    if vehicle==nil then vehicle=read(UnitInVehicle,"player") end
    if vehicle then context.actionContext="vehicle" end
    if C_PetBattles and read(C_PetBattles.IsInBattle) then context.actionContext="petbattle" end
    return context
end
]==],[==[]==]},
  {[==[    function reader:Context(spec) return rotationContext(owner,spec) end
]==],[==[]==]},
  {[==[        local context=rotationContext(owner,spec);context.spec=spec
]==],[==[        local context=owner:GetRotationContext(spec);context.spec=spec
]==]},
  {[==[        local context=rotationContext(owner,spec);context.spec=spec;local rows={}
]==],[==[        local context=owner:GetRotationContext(spec);context.spec=spec;local rows={}
]==]},
  {[==[    function reader:Eligible(view,spec,candidates) local context=rotationContext(owner,spec);context.spec=spec;return eligible(view,context,candidates) end
]==],[==[    function reader:Eligible(view,spec,candidates) local context=owner:GetRotationContext(spec);context.spec=spec;return eligible(view,context,candidates) end
]==]},
 },
 ["Core/rotation_scope.lua"]={
  {[==[local function rotationContext(owner,spec)
    local method=libraryReader and libraryReader.Context
    if type(method)=='function' then return method(libraryReader,spec) end
    local fallback=owner.GetRotationContext
    return fallback(owner,spec)
end
]==],[==[]==]},
  {[==[            local value=rotationContext(owner,number);local result={}
]==],[==[            local value=owner:GetRotationContext(number);local result={}
]==]},
  {[==[            elseif rotationContext(owner,number).combatDataPolicy~='probe' then return nil,'restricted-or-unsupported-client' end
]==],[==[            elseif owner:GetRotationContext(number).combatDataPolicy~='probe' then return nil,'restricted-or-unsupported-client' end
]==]},
 },
}
local hashes={["Platform/client.lua"]="6cb90db0",["Core/rotation_library.lua"]="a636cfd7",["Core/rotation_scope.lua"]="5daa21f1"}
return function(text,path,hash)
 if path=='Platform/client.lua' then text=dofile('tests/fixtures/restore_runtime_context_projection.lua')(text,path) end
 assert(type(text)=='string' and type(hash)=='function' and changes[path],'unknown context inverse input')
 for _,entry in ipairs(changes[path]) do
  local first,last=text:find(entry[1],1,true)
  assert(first and not text:find(entry[1],last+1,true),'unexpected context addition/expression count or body')
  text=text:sub(1,first-1)..entry[2]..text:sub(last+1)
 end
 assert(hash(text)==hashes[path],'context module differs beyond approved additions and five expressions')
 return text
end
