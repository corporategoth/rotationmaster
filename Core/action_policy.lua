local _,addon=...

-- Observations live for one evaluation only. Conditions can still inspect
-- other spells; a condition never overrides the action's own availability.
function addon:NewActionReadiness(now)
    local platform=self.Platform
    local spells,items,availability={},{},{}
    local range=platform:NewSpellRangeReader()
    local function validID(id)
        return platform:CanReadValue(id) and type(id)=="number" and id>0 and id<math.huge and id%1==0
    end
    return function(kind,id,itemID)
        if not validID(id) then return false end
        if kind=="item" then
            if not validID(itemID) then return false end
            if items[itemID]==nil then
                local ready=platform:IsItemReady(itemID,now)
                local observed=ready==true and platform:GetItemRangeState(itemID,"target")
                items[itemID]=type(observed)=="table" and (observed.applicable==false or observed.inRange==true)
            end
            return items[itemID]
        end
        if kind~="spell" and kind~="pet" and kind~="any" then return false end
        spells[kind]=spells[kind] or {}
        if spells[kind][id]==nil then
            local known=kind~="pet" and platform:IsSpellKnown(id,false)==true
            if not known and kind~="spell" then known=platform:IsSpellKnown(id,true)==true end
            if known and availability[id]==nil then
                local usable,power=platform:IsSpellUsable(id)
                availability[id]=usable==true and power==false and platform:IsSpellReady(id,now)==true
            end
            local ready=known and availability[id]
            local observed
            if ready and id==6603 and kind~="pet" then
                local beyond=platform:IsBeyondMeleeRange("target")
                if beyond~=nil then observed={applicable=true,inRange=beyond==false} end
            elseif ready then observed=range(id,"target",kind) end
            spells[kind][id]=type(observed)=="table" and (observed.applicable==false or observed.inRange==true)
        end
        return spells[kind][id]
    end
end
