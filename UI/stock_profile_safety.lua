local _,addon=...
-- Keep malformed optional stock outside generic recursive settings services.
local safety={};addon.StockSettings=safety
function safety.CheckProfile(profile)
    if type(profile)~='table' then return true end
    local plan=rawget(profile,'stockTargets')
    if plan==nil then return true end
    return addon.StockTargets.Validate(plan)
end
function safety.DraftProfile(profile)
    if safety.CheckProfile(profile) then return profile end
    local projection={}
    for key,value in pairs(profile) do if key~='stockTargets' then projection[key]=value end end
    return projection
end
