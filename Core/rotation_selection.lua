local _,addon=...
local data=addon.RotationData

-- Build the candidate order without evaluating switch conditions. Missing
-- priorities retain the historical alphabetical order; IDs break equal names.
function addon:GetOrderedAutoSwitchRotations(spec,rotations)
    local candidates={}
    for id,body in pairs(rotations) do
        local priority=type(body)=='table' and data.GetRotationPriority(body.priority)
        if type(id)=='string' and id~=DEFAULT and priority and not body.disabled
            and type(body.switch)=='table' and self:usefulCondition(body.switch)
            and self:validateCondition(body.switch,spec) and self:rotationValidConditions(body,spec) then
            candidates[#candidates+1]={id=id,priority=priority,name=type(body.name)=='string' and body.name or id,
                builtin=self:IsDefaultRuntimeRotation(spec,id)==true}
        end
    end
    table.sort(candidates,function(left,right)
        if left.builtin~=right.builtin then return not left.builtin end
        if left.priority~=right.priority then return left.priority>right.priority end
        if left.name~=right.name then return left.name<right.name end
        return left.id<right.id
    end)
    local ordered={};for _,entry in ipairs(candidates) do ordered[#ordered+1]=entry.id end
    return ordered
end
