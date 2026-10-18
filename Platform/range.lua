local _, addon = ...
local platform=addon.Platform

-- Native Attack range, when the client supports that query, includes the game's
-- melee geometry. An invalid nil result may use a conservative public estimate.
function platform:IsBeyondMeleeRange(unit)
    if type(unit)~="string" or unit=="" then return nil,"invalid-unit" end
    local fn,spell
    if C_Spell and type(C_Spell.IsSpellInRange)=="function" then fn,spell=C_Spell.IsSpellInRange,6603
    elseif type(IsSpellInRange)=="function" then
        local info,why=self:GetSpellInfo(6603)
        if info then fn,spell=IsSpellInRange,info.name
        elseif why=="restricted-value" or why=="api-error" then return nil,why end
    end
    if fn then
        local ok,inRange=pcall(fn,spell,unit)
        if not ok then return nil,"api-error" end
        if not self:CanReadValue(inRange) then return nil,"restricted-value" end
        if inRange==true or inRange==1 then return false,nil,"native-attack-range" end
        if inRange==false or inRange==0 then return true,nil,"native-attack-range" end
        if inRange~=nil then return nil,"invalid-api-result" end
    end
    if not LibStub then return nil,"missing-range-provider" end
    local loaded,provider=pcall(function() return LibStub("LibRangeCheck-3.0",true) end)
    if not loaded or not provider or type(provider.GetRange)~="function" then return nil,"missing-range-provider" end
    local ok,minimum,maximum=pcall(provider.GetRange,provider,unit,true)
    if not ok then return nil,"range-provider-error" end
    for _,value in pairs({min=minimum,max=maximum}) do
        if not self:CanReadValue(value) then return nil,"restricted-value" end
        if type(value)~="number" or value~=value or value<0 or value==math.huge then return nil,"invalid-range-result" end
    end
    if minimum==nil and maximum==nil then return nil,"range-unavailable" end
    if minimum and maximum and minimum>maximum then return nil,"invalid-range-result" end
    -- These are intervals rather than exact distances. A failed five-yard check
    -- yields a lower bound of five; an interval spanning it stays unavailable.
    if maximum and maximum<=5 then return false,nil,"estimated-five-yard-range" end
    if minimum and minimum>=5 then return true,nil,"estimated-five-yard-range" end
    return nil,"range-uncertain"
end
