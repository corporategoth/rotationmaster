local _,addon=...
local platform=addon.Platform

local function spellID(id)
    if not platform:CanReadValue(id) then return nil,"restricted-value" end
    if type(id)~="number" or id<1 or id==math.huge or id%1~=0 then return nil,"invalid-spell" end
    return true
end
local function call(fn,...)
    if type(fn)~="function" then return nil,"missing-api" end
    local ok,value=pcall(fn,...)
    if not ok then return nil,"api-error" end
    if not platform:CanReadValue(value) then return nil,"restricted-value" end
    return value
end
function platform:IsSpellUsable(id)
    local valid,reason=spellID(id)
    if not valid then return nil,nil,reason end
    local fn=C_Spell and C_Spell.IsSpellUsable or IsUsableSpell
    if type(fn)~="function" then return nil,nil,"missing-api" end
    local ok,usable,power=pcall(fn,id)
    if not ok then return nil,nil,"api-error" end
    if not self:CanReadValue(usable) or not self:CanReadValue(power) then return nil,nil,"restricted-value" end
    if type(usable)~="boolean" or type(power)~="boolean" then return nil,nil,"invalid-api-result" end
    return usable,power
end

local function findSlot(id,bank)
    local pet=bank=="pet"
    local slot,reason=call(FindSpellBookSlotBySpellID,id,pet)
    if reason then return nil,nil,reason end
    if slot==nil and bank=="any" then
        pet=true;slot,reason=call(FindSpellBookSlotBySpellID,id,true)
        if reason then return nil,nil,reason end
    end
    if slot==nil then return nil,nil,"spell-not-in-book" end
    if type(slot)~="number" or slot<1 or slot==math.huge or slot%1~=0 then return nil,nil,"invalid-api-result" end
    return slot,pet and (BOOKTYPE_PET or "pet") or (BOOKTYPE_SPELL or "spell")
end
function platform:GetSpellRangeState(id,unit,bank)
    local valid,reason=spellID(id)
    if not valid then return nil,reason end
    if not self:CanReadValue(unit) or not self:CanReadValue(bank) then return nil,"restricted-value" end
    if unit~=nil and (type(unit)~="string" or unit=="") then return nil,"invalid-unit" end
    if bank~="spell" and bank~="pet" and bank~="any" then return nil,"invalid-spell-bank" end
    unit=unit or "target"
    local nativeRange=C_Spell and C_Spell.IsSpellInRange
    local nativeShape=C_Spell and C_Spell.SpellHasRange
    local slot,book,slotReason
    local function legacySlot()
        if not slot then slot,book,slotReason=findSlot(id,bank) end
        return slot,slotReason
    end
    local hasRange,why,queriedShape
    if type(nativeShape)=="function" then
        queriedShape=true
        hasRange,why=call(nativeShape,id)
    elseif type(nativeRange)~="function" and type(SpellHasRange)=="function" then
        if not legacySlot() then return nil,slotReason end
        queriedShape=true
        hasRange,why=call(SpellHasRange,slot,book)
    end
    if why then return nil,why end
    if hasRange~=nil then
        if type(hasRange)~="boolean" then return nil,"invalid-api-result" end
        if not hasRange then return {applicable=false} end
    elseif queriedShape then return nil,"invalid-api-result" end
    local inRange
    if type(nativeRange)=="function" then
        inRange,why=call(nativeRange,id,unit)
        if why then return nil,why end
        if inRange~=nil and type(inRange)~="boolean" then return nil,"invalid-api-result" end
    else
        if type(IsSpellInRange)~="function" then return nil,"missing-api" end
        if not legacySlot() then return nil,slotReason end
        inRange,why=call(IsSpellInRange,slot,book,unit)
        if why then return nil,why end
        if inRange==0 then inRange=false elseif inRange==1 then inRange=true end
        if inRange~=nil and type(inRange)~="boolean" then return nil,"invalid-api-result" end
    end
    if inRange==nil then return nil,"invalid-range-check" end
    return {applicable=true,inRange=inRange}
end

-- A reader lives for one recommendation pass only. Native range identifies
-- spells by ID/unit, whereas legacy slot checks also depend on the book bank.
function platform:NewSpellRangeReader()
    local observations={}
    local native=C_Spell and type(C_Spell.IsSpellInRange)=="function"
    return function(id,unit,bank)
        local valid,reason=spellID(id)
        if not valid then return nil,reason end
        if not self:CanReadValue(unit) or not self:CanReadValue(bank) then return nil,"restricted-value" end
        if unit~=nil and (type(unit)~="string" or unit=="") then return nil,"invalid-unit" end
        if bank~="spell" and bank~="pet" and bank~="any" then return nil,"invalid-spell-bank" end
        local key=native and "native" or bank
        observations[key]=observations[key] or {}
        local units=observations[key]
        local target=unit or "target"
        units[target]=units[target] or {}
        if not units[target][id] then
            local value,why=self:GetSpellRangeState(id,unit,bank)
            units[target][id]={value=value,reason=why}
        end
        return units[target][id].value,units[target][id].reason
    end
end

-- This is only a suggestion to start ordinary weapon attacks. It cannot
-- operate a button or infer unavailable combat/target data.
function platform:IsMeleeAttackNeeded(unit)
    if not self:CanReadValue(unit) or type(unit)~="string" or unit=="" then return nil,"invalid-unit" end
    if self:GetClientInfo().combatDataPolicy~="probe" then return nil,"unsupported-policy" end
    local function boolean(fn,...)
        local value,reason=call(fn,...)
        if reason then return nil,reason end
        if type(value)~="boolean" then return nil,"invalid-api-result" end
        return value
    end
    local checks={
        {UnitAffectingCombat,true,"player"},{UnitExists,true,unit},
        {UnitCanAttack,true,"player",unit},{UnitIsDeadOrGhost or UnitIsDead,false,unit},
        {UnitHasVehicleUI or UnitInVehicle,false,"player"},
    }
    for _,check in ipairs(checks) do
        local result,reason=boolean(check[1],unpack(check,3))
        if result==nil then return nil,reason end
        if result~=check[2] then return false end
    end
    local active,reason=self:IsCurrentSpell(6603)
    if active==nil then return nil,reason end
    if active then return false end
    local beyond,why=self:IsBeyondMeleeRange(unit)
    if beyond==nil then return nil,why end
    return not beyond
end
