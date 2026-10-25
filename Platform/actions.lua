local _,addon=...
local platform=addon.Platform
local function readClientPolicy(current)return current:GetClientInfo().combatDataPolicy end
---@type fun(...): any
local consumeClientPolicy=addon.ConsumeClientPolicyReader
if type(consumeClientPolicy)=='function' then readClientPolicy=consumeClientPolicy(addon) end

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
-- Shared, read-only range results.
local rangeNotApplicable,rangeIn,rangeOut={applicable=false},{applicable=true,inRange=true},{applicable=true,inRange=false}
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
    local hasRange,why,queriedShape
    if type(nativeShape)=="function" then
        queriedShape=true
        hasRange,why=call(nativeShape,id)
    elseif type(nativeRange)~="function" and type(SpellHasRange)=="function" then
        if not slot then slot,book,slotReason=findSlot(id,bank) end
        if not slot then return nil,slotReason end
        queriedShape=true
        hasRange,why=call(SpellHasRange,slot,book)
    end
    if why then return nil,why end
    if hasRange~=nil then
        if type(hasRange)~="boolean" then return nil,"invalid-api-result" end
        if not hasRange then return rangeNotApplicable end
    elseif queriedShape then return nil,"invalid-api-result" end
    local inRange
    if type(nativeRange)=="function" then
        inRange,why=call(nativeRange,id,unit)
        if why then return nil,why end
        if inRange~=nil and type(inRange)~="boolean" then return nil,"invalid-api-result" end
    else
        if type(IsSpellInRange)~="function" then return nil,"missing-api" end
        if not slot then slot,book,slotReason=findSlot(id,bank) end
        if not slot then return nil,slotReason end
        inRange,why=call(IsSpellInRange,slot,book,unit)
        if why then return nil,why end
        if inRange==0 then inRange=false elseif inRange==1 then inRange=true end
        if inRange~=nil and type(inRange)~="boolean" then return nil,"invalid-api-result" end
    end
    if inRange==nil then return nil,"invalid-range-check" end
    return inRange and rangeIn or rangeOut
end

-- A reader lives for one recommendation pass only. Native range identifies
-- spells by ID/unit, whereas legacy slot checks also depend on the book bank.
-- The second result starts a new pass on the same reader: observations carry
-- the pass stamp, so their tables are reused rather than rebuilt.
function platform:NewSpellRangeReader()
    local observations={}
    local stamp=0
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
        local record=units[target][id]
        if not record then record={};units[target][id]=record end
        if record.stamp~=stamp then
            record.value,record.reason=self:GetSpellRangeState(id,unit,bank)
            record.stamp=stamp
        end
        return record.value,record.reason
    end,function() stamp=stamp+1 end
end

-- This is only a suggestion to start ordinary weapon attacks. It cannot
-- operate a button or infer unavailable combat/target data.
-- A false answer for an attackable target in combat says why in its third
-- value, for the ranged auto-attack (Core/action_policy.lua): "attack-active"
-- (Attack is already on; range was not read) or "beyond-melee".
function platform:IsMeleeAttackNeeded(unit)
    if not self:CanReadValue(unit) or type(unit)~="string" or unit=="" then return nil,"invalid-unit" end
    if readClientPolicy(self)~="probe" then return nil,"unsupported-policy" end
    local function boolean(fn,...)
        local value,reason=call(fn,...)
        if reason then return nil,reason end
        if type(value)~="boolean" then return nil,"invalid-api-result" end
        return value
    end
    -- Snapshot all five providers before calling any, as the former query
    -- plan did, without building six temporary tables for each check.
    local combat,exists,attackable,dead,vehicle=UnitAffectingCombat,UnitExists,UnitCanAttack,
        UnitIsDeadOrGhost or UnitIsDead,UnitHasVehicleUI or UnitInVehicle
    local result,reason=boolean(combat,"player")
    if result==nil then return nil,reason end
    if not result then return false end
    result,reason=boolean(exists,unit)
    if result==nil then return nil,reason end
    if not result then return false end
    result,reason=boolean(attackable,"player",unit)
    if result==nil then return nil,reason end
    if not result then return false end
    result,reason=boolean(dead,unit)
    if result==nil then return nil,reason end
    if result then return false end
    result,reason=boolean(vehicle,"player")
    if result==nil then return nil,reason end
    if result then return false end
    local active
    active,reason=self:IsCurrentSpell(6603)
    if active==nil then return nil,reason end
    if active then return false,nil,"attack-active" end
    local beyond,why=self:IsBeyondMeleeRange(unit)
    if beyond==nil then return nil,why end
    if beyond then return false,nil,"beyond-melee" end
    return true
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetSpellRangeState" then return addon.Platform.GetSpellRangeState end
        if name=="call" then return call end
        if name=="findSlot" then return findSlot end
        if name=="platform" then return platform end
        if name=="rangeIn" then return rangeIn end
        if name=="rangeNotApplicable" then return rangeNotApplicable end
        if name=="rangeOut" then return rangeOut end
        if name=="spellID" then return spellID end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/actions.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/actions.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
