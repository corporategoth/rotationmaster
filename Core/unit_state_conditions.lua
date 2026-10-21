local _,addon=...

-- Cold, one-time profile migration: keep indexed AceDB defaults and custom
-- ordering stable. Once seeded, removing either Switch choice remains saved.
function addon:InitializeUnitStateConditions(_,db)
    local profile=db.profile
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
