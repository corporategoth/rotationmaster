local function fixture(values, modules)
    local addon={}
    local env=setmetatable(values or {}, {__index=_G})
    env._G=env
    for _,path in ipairs(modules or {'Platform/client.lua','Platform/spells.lua'}) do
        local load=assert(loadfile(path));setfenv(load,env);load('rotationmaster',addon)
    end
    return addon.Platform,env,addon
end
return fixture
