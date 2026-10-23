local _,addon=...

-- Cold, one-time profile migration: keep indexed AceDB defaults and custom
-- ordering stable. Once seeded, removing either Switch choice remains saved.
-- Action and build context conditions join their categories once per
-- profile, under their own flag, so existing profiles receive them too and a
-- later removal stays saved.
local contextSeeds={
    {category='b8136123-2bda-4230-a77a-89ea2aed3a1a',tags={'ACTION_CONTEXT'}},
    {category='fca4ff75-4085-458a-b5bf-27a6b52f2092',tags={'SET_PIECES'}},
    {category='e618608c-92ec-4ae9-9dde-40a397d7beb9',tags={'WEAPON_IMBUE'}},
}
local function seedContextConditions(profile)
    if profile.contextConditionsSeeded then return end
    local function append(list,tags)
        if type(list)~='table' then return end
        for _,tag in ipairs(tags) do
            local found=false
            for _,existing in ipairs(list) do if existing==tag then found=true;break end end
            if not found then list[#list+1]=tag end
        end
    end
    for _,category in ipairs(type(profile.condition_groups)=='table' and profile.condition_groups or {}) do
        for _,seed in ipairs(contextSeeds) do
            if category.id==seed.category then append(category.conditions,seed.tags) end
        end
    end
    profile.contextConditionsSeeded=true
end
function addon:InitializeUnitStateConditions(_,db)
    local profile=db.profile
    seedContextConditions(profile)
    if profile.unitStateSwitchSeeded then return end
    local function append(list)
        for _,tag in ipairs({'DEAD','FRIENDLY'}) do
            local found=false
            for _,existing in ipairs(list) do if existing==tag then found=true;break end end
            if not found then list[#list+1]=tag end
        end
    end
    append(profile.switch_conditions)
    for _,category in ipairs(profile.condition_groups) do
        if category.id=='b8136123-2bda-4230-a77a-89ea2aed3a1a' then append(category.conditions) end
    end
    profile.unitStateSwitchSeeded=true
end

-- CallbackHandler keeps one callback per owner/event. Use a private owner so
-- these seeds coexist with existing profile lifecycle handlers on the addon.
local callbackOwner={}
function addon:InstallUnitStateConditions(db)
    for _,event in ipairs({'OnNewProfile','OnProfileReset','OnProfileChanged','OnProfileCopied'}) do
        db.RegisterCallback(callbackOwner,event,function(event,currentDB)
            addon:InitializeUnitStateConditions(event,currentDB)
        end)
    end
    self:InitializeUnitStateConditions(nil,db)
end
