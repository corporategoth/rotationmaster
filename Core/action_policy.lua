local _,addon=...

-- Observations live for one evaluation only. Conditions can still inspect
-- other spells; a condition never overrides the action's own availability.
-- One memo per evaluation: each observation is made at most once per poll.
-- Entries carry the stamp of the poll that made them, so reset() starts a new
-- poll without discarding (and reallocating) the tables.
local function buildReadiness(platform)
    local spells,spellStamps,items,itemStamps,availability,availableStamps={},{},{},{},{},{}
    local range,resetRange=platform:NewSpellRangeReader()
    local stamp,now=0,nil
    local function validID(id)
        return platform:CanReadValue(id) and type(id)=="number" and id>0 and id<math.huge and id%1==0
    end
    local function ready(kind,id,itemID)
        if not validID(id) then return false end
        if kind=="item" then
            if not validID(itemID) then return false end
            if itemStamps[itemID]~=stamp then
                local ready=platform:IsItemReady(itemID,now)
                local observed=ready==true and platform:GetItemRangeState(itemID,"target")
                items[itemID]=type(observed)=="table" and (observed.applicable==false or observed.inRange==true)
                itemStamps[itemID]=stamp
            end
            return items[itemID]
        end
        if kind~="spell" and kind~="pet" and kind~="any" then
            -- An assisted step resolves to Blizzard's suggested player spell
            -- and is held to exactly the readiness of a spell step.
            if kind~="assisted" then return false end
            kind="spell"
        end
        local results,stamps=spells[kind],spellStamps[kind]
        if not results then results,stamps={},{};spells[kind],spellStamps[kind]=results,stamps end
        if stamps[id]~=stamp then
            local known=kind~="pet" and platform:IsSpellKnown(id,false)==true
            if not known and kind~="spell" then known=platform:IsSpellKnown(id,true)==true end
            -- Vehicle, override and possession abilities are in neither
            -- spellbook; while such a bar is up, the bound button decides.
            if not known and addon.GetActionContext and addon:GetActionContext()~="player" and addon.IsBoundActionReady then
                results[id]=addon:IsBoundActionReady(id,now)==true;stamps[id]=stamp
                return results[id]
            end
            if known and availableStamps[id]~=stamp then
                local usable,power=platform:IsSpellUsable(id)
                availability[id]=usable==true and power==false and platform:IsSpellReady(id,now)==true
                availableStamps[id]=stamp
            end
            local result=false
            if known and availability[id] then
                if id==6603 and kind~="pet" then
                    local beyond=platform:IsBeyondMeleeRange("target")
                    result=beyond~=nil and beyond==false
                else
                    local observed=range(id,"target",kind)
                    result=type(observed)=="table" and (observed.applicable==false or observed.inRange==true)
                end
            end
            results[id]=result;stamps[id]=stamp
        end
        return results[id]
    end
    local function reset(at)
        stamp,now=stamp+1,at
        if resetRange then resetRange() end
    end
    return ready,reset
end

function addon:NewActionReadiness(now)
    local ready,reset=buildReadiness(self.Platform)
    reset(now)
    return ready
end

-- Steady-state polling keeps one memo and starts a new poll on it.
local shared
function addon:ResetActionReadiness(now)
    if not shared or shared.platform~=self.Platform then
        shared={platform=self.Platform}
        shared.ready,shared.reset=buildReadiness(self.Platform)
    end
    shared.reset(now)
    return shared.ready
end
