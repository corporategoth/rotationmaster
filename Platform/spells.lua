local _, addon = ...
local platform = addon.Platform

local function identifier(value, idOnly)
    if not platform:CanReadValue(value) then return false, "restricted-value" end
    if type(value) == "number" and value > 0 and value < math.huge and value % 1 == 0 then return true end
    if not idOnly and type(value) == "string" and #value > 0 then return true end
    return false, "invalid-spell"
end

local function copy(record, fields)
    if not platform:CanReadValue(record) then return nil, "restricted-value" end
    if type(record) ~= "table" then return nil, "invalid-api-result" end
    local result = {}
    for key, kind in pairs(fields) do
        local value = record[key]
        if not platform:CanReadValue(value) then return nil, "restricted-value" end
        if value ~= nil then
            if type(value) ~= kind and not (kind == "icon" and (type(value) == "number" or type(value) == "string")) then
                return nil, "invalid-api-result"
            end
            if type(value) == "number" and (value ~= value or value == math.huge or value == -math.huge) then
                return nil, "invalid-api-result"
            end
            result[key] = value
        end
    end
    return result
end

-- A record built here from a legacy multi-return API is ours, so normalize it
-- in place: same checks and listed fields, one table fewer per call. Records
-- returned by C_Spell are copied, never modified.
local function own(record, fields, built)
    if not built then return copy(record, fields) end
    if not platform:CanReadValue(record) then return nil, "restricted-value" end
    if type(record) ~= "table" or getmetatable(record) ~= nil then return copy(record, fields) end
    for key, kind in pairs(fields) do
        local value = record[key]
        if not platform:CanReadValue(value) then return nil, "restricted-value" end
        if value ~= nil then
            if type(value) ~= kind and not (kind == "icon" and (type(value) == "number" or type(value) == "string")) then
                return nil, "invalid-api-result"
            end
            if type(value) == "number" and (value ~= value or value == math.huge or value == -math.huge) then
                return nil, "invalid-api-result"
            end
        end
    end
    local key = next(record)
    while key ~= nil do
        local following = next(record, key)
        if fields[key] == nil then record[key] = nil end
        key = following
    end
    return record
end

local infoFields = {
    name = "string",
    subtext = "string",
    iconID = "icon",
    castTime = "number",
    minRange = "number",
    maxRange = "number",
    spellID = "number",
    originalIconID = "icon",
}

local chargeFields = {
    currentCharges = "number",
    maxCharges = "number",
    cooldownStartTime = "number",
    cooldownDuration = "number",
    chargeModRate = "number",
    isActive = "boolean",
}

function platform:GetSpellInfo(spell)
    local valid, reason = identifier(spell)
    if not valid then return nil, reason end
    local ok, record, built

    if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
        ok, record = pcall(C_Spell.GetSpellInfo, spell)
    elseif type(GetSpellInfo) == "function" then
        local name, subtext, icon, cast, min, max, id, original
        ok, name, subtext, icon, cast, min, max, id, original = pcall(GetSpellInfo, spell)
        if not ok then return nil, "api-error" end
        if not self:CanReadValue(name) then return nil, "restricted-value" end

        if name ~= nil then
            record = {
                name = name,
                subtext = subtext,
                iconID = icon,
                castTime = cast,
                minRange = min,
                maxRange = max,
                spellID = id,
                originalIconID = original,
            }

            built = true
        end
    else
        return nil, "missing-api"
    end

    if not ok then return nil, "api-error" end
    if not self:CanReadValue(record) then return nil, "restricted-value" end
    if record == nil then return nil, "spell-data-unavailable" end
    local info, why = own(record, infoFields, built)
    if not info then return nil, why end
    if not info.name or info.name == "" then return nil, "invalid-api-result" end

    -- Modern metadata omits rank text; keep this optional public decoration
    -- separate from the required spell identity fields.
    if info.subtext == nil and C_Spell and type(C_Spell.GetSpellSubtext) == "function" then
        local textOk, text = pcall(C_Spell.GetSpellSubtext, spell)
        if textOk and self:CanReadValue(text) and type(text) == "string" then info.subtext = text end
    end

    return info
end

-- Identity of a live spell observation (a cast, a channel, the active form)
-- against a configured spell ID. An equal ID matches. Otherwise, unless the
-- exact ID was asked for, any rank of the spell matches: ranks share the
-- client's own localized name, so this holds on every locale. Names are fixed
-- for a session, so a resolved name is kept; failures are never kept.
local familyNames = {}

function platform:GetSpellFamilyName(spellID)
    local name = familyNames[spellID]
    if name then return name end
    local info, reason = self:GetSpellInfo(spellID)
    if not info then return nil, reason or "spell-data-unavailable" end
    name = info.name
    if type(name) ~= "string" or name == "" then return nil, "invalid-api-result" end
    familyNames[spellID] = name
    return name
end

function platform:MatchSpellIdentity(observedID, observedReason, observedName, wanted, exact)
    if observedID ~= nil and observedID == wanted then return true end

    if exact then
        if observedID == nil then return nil, observedReason or "spell-identity-unavailable" end
        return false
    end

    local name = observedName

    if name == nil then
        if observedID == nil then return nil, observedReason or "spell-identity-unavailable" end
        local reason
        name, reason = self:GetSpellFamilyName(observedID)
        if not name then return nil, reason end
    end

    local wantedName, why = self:GetSpellFamilyName(wanted)
    if not wantedName then return nil, why end
    return name == wantedName
end

function platform:IsSpellKnown(spellID, pet)
    local valid, reason = identifier(spellID, true)
    if not valid then return nil, reason end
    if pet ~= nil and type(pet) ~= "boolean" then return nil, "invalid-spell-bank" end
    local fn, bank

    if C_SpellBook and type(C_SpellBook.IsSpellKnown) == "function" then
        local banks = Enum and Enum.SpellBookSpellBank

        if banks then
            if pet then
                bank = banks.Pet
            else
                bank = banks.Player
            end
        end

        if self:CanReadValue(bank) and type(bank) == "number" then fn = C_SpellBook.IsSpellKnown end
    end

    if not fn then
        if type(IsSpellKnown) == "function" then
            fn, bank = IsSpellKnown, pet == true
        elseif C_SpellBook and type(C_SpellBook.IsSpellKnown) == "function" then
            return nil, "missing-spell-bank"
        else
            return nil, "missing-api"
        end
    end

    local ok, known = pcall(fn, spellID, bank)
    if not ok then return nil, "api-error" end
    if not self:CanReadValue(known) then return nil, "restricted-value" end
    if type(known) ~= "boolean" then return nil, "invalid-api-result" end
    return known
end

local cooldownFields = { startTime = "number", duration = "number", isEnabled = "boolean", modRate = "number" }

-- Retail and Forever hide a cooldown's times while addon restrictions are in
-- effect (combat, encounters, challenge modes, PvP matches), but never its
-- state flags. Blizzard's generated API documentation (Gethe/wow-ui-source,
-- Interface/AddOns/Blizzard_APIDocumentationGenerated):
--   live e7aa82019dc298e0351c7159d60c2a9b916b9b67 (12.1.5.70529) and
--   forever ca8368f2f2380cbe696854f7f2646387c278a61b (1.60.1.70532), with
--   SpellDocumentation.lua and SpellSharedDocumentation.lua identical for these:
--   C_Spell.GetSpellCooldown / GetSpellCharges: SecretWhenCooldownsRestricted
--     ("Individual spells may be flagged as never or always secret, which
--     takes priority over restrictions", SecretPredicatesDocumentation.lua).
--   SpellCooldownInfo NeverSecret: isEnabled, isActive ("False if cooldown is
--     not active (ex: not enabled, or startTime or duration are 0)") and
--     isOnGCD (nilable; "do not trust this field unless responding to a
--     SPELL_UPDATE_COOLDOWN event"). startTime, duration, modRate,
--     activeCategory and timeUntilEndOfStartRecovery may be secret.
--   SpellChargeInfo NeverSecret: maxCharges and isActive only.
--   C_Spell.IsSpellUsable, IsSpellInRange and SpellHasRange carry no secret
--   annotation at all.
-- So when only the times are secret, GetSpellCooldown stays unavailable (nil,
-- "restricted-value") and reports the flags after the reason. Readiness can be
-- decided from them; a remaining time never can. Classic-family builds never
-- reach this: their values are never secret.
local function cooldownFlags(self, record)
    if type(record) ~= "table" then return end
    local enabled, active, onGCD = record.isEnabled, record.isActive, record.isOnGCD
    if not self:CanReadValue(enabled) or not self:CanReadValue(active) or not self:CanReadValue(onGCD) then return end
    if type(enabled) ~= "boolean" or type(active) ~= "boolean" or (onGCD ~= nil and type(onGCD) ~= "boolean") then return end
    return enabled, active, onGCD
end

function platform:GetSpellCooldown(spell)
    local valid, reason = identifier(spell)
    if not valid then return nil, reason end
    local ok, record, built
    if C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
        ok, record = pcall(C_Spell.GetSpellCooldown, spell)
    elseif type(GetSpellCooldown) == "function" then
        local start, duration, enabled, rate
        ok, start, duration, enabled, rate = pcall(GetSpellCooldown, spell)
        if not ok then return nil, "api-error" end
        if not self:CanReadValue(start) or not self:CanReadValue(duration) or not self:CanReadValue(enabled)
            or not self:CanReadValue(rate) then return nil, "restricted-value" end
        if start ~= nil then
            if enabled ~= 0 and enabled ~= 1 then return nil, "invalid-api-result" end
            record = {startTime=start, duration=duration, isEnabled=enabled == 1, modRate=rate or 1};built = true
        end
    else return nil, "missing-api" end
    if not ok then return nil, "api-error" end
    if not self:CanReadValue(record) then return nil, "restricted-value" end
    if record == nil then return nil, "spell-data-unavailable" end
    local cooldown, why = own(record, cooldownFields, built)
    if not cooldown then
        if why == "restricted-value" and not built then return nil, why, cooldownFlags(self, record) end
        return nil, why
    end
    if cooldown.startTime == nil or cooldown.duration == nil or cooldown.isEnabled == nil
        or cooldown.startTime < 0 or cooldown.duration < 0 or (cooldown.modRate and cooldown.modRate <= 0) then
        return nil, "invalid-api-result"
    end
    cooldown.modRate = cooldown.modRate or 1
    return cooldown
end

function platform:GetSpellLink(spell)
    local valid, reason = identifier(spell)
    if not valid then return nil, reason end
    local fn = C_Spell and C_Spell.GetSpellLink or GetSpellLink
    if type(fn) ~= "function" then return nil, "missing-api" end
    local ok, link = pcall(fn, spell)
    if not ok then return nil, "api-error" end
    if not self:CanReadValue(link) then return nil, "restricted-value" end
    if link == nil then return nil, "spell-data-unavailable" end
    if type(link) ~= "string" or link == "" then return nil, "invalid-api-result" end
    return link
end

-- Recommendation readiness permits a next action during the global cooldown,
-- but not an ability whose own cooldown will still be active afterward.
local gcdSpell

function platform:GetGlobalCooldown()
    if not gcdSpell then
        local client = self:GetClientInfo()

        -- Classic public probe; later clients expose the dedicated GCD spell.
        gcdSpell = (client.family == 'era'
            or client.family == 'tbc'
            or (client.family == 'progression' and client.expansion == 2))
            and 29515
            or 61304
    end

    return self:GetSpellCooldown(gcdSpell)
end

-- Readiness runs for every reached action each poll. On classic builds
-- without secrets the multi-value cooldown API is read directly: the same
-- values GetSpellCooldown validates, without a result table per call.
-- Results: start, duration, enabled, reason. When only the times are secret
-- (Retail/Forever), start is nil and enabled, then active and onGCD after the
-- reason, carry the never-secret flags.
local function finiteNonNegative(value)
    return type(value)=="number" and value==value and value>=0 and value~=math.huge
end

local function cooldownValues(self, spell)
    local legacy=self.secretsUnrestricted and GetSpellCooldown
    if type(legacy)~="function" then
        local cooldown,reason,enabled,active,onGCD=self:GetSpellCooldown(spell)
        if not cooldown then return nil,nil,enabled,reason,active,onGCD end
        return cooldown.startTime,cooldown.duration,cooldown.isEnabled
    end
    local valid,reason=identifier(spell)
    if not valid then return nil,nil,nil,reason end
    local ok,start,duration,enabled=pcall(legacy,spell)
    if not ok then return nil,nil,nil,"api-error" end
    if not self:CanReadValue(start) or not self:CanReadValue(duration) or not self:CanReadValue(enabled) then
        return nil,nil,nil,"restricted-value"
    end
    if start==nil then return nil,nil,nil,"spell-data-unavailable" end
    if enabled~=0 and enabled~=1 and enabled~=true and enabled~=false then return nil,nil,nil,"invalid-api-result" end
    if not finiteNonNegative(start) or not finiteNonNegative(duration) then return nil,nil,nil,"invalid-api-result" end
    return start,duration,enabled==1 or enabled==true
end

-- Whether the global cooldown is running: true, false, or nil and a reason.
-- From its times when they are readable, otherwise from its flags.
local function gcdRunning(self, now)
    if not gcdSpell then self:GetGlobalCooldown() end
    local start,duration,enabled,why,active=cooldownValues(self,gcdSpell)
    if start~=nil then return enabled and duration>0 and start+duration>now end
    if active==nil then return nil,why end
    return enabled and active
end

-- Readiness from the never-secret flags alone, with the meaning the times
-- give it: a held cooldown is not ready; an inactive one is; an active one is
-- ready only while it is the global cooldown. Blizzard says isOnGCD is only
-- trustworthy at SPELL_UPDATE_COOLDOWN, so a polled "on the GCD" counts only
-- while a global cooldown is actually running. The one case the times decide
-- and the flags cannot is an own cooldown that ends inside the GCD: if the
-- client reports it as the spell's own (isOnGCD false), it reads not ready
-- until the client reports the GCD instead.
local function flagReadiness(self, enabled, active, onGCD, now)
    if not enabled then return false end
    if not active then return true end
    if onGCD==false then return false end
    local running,why=gcdRunning(self,now)
    if running==false then return false end
    if onGCD==true then return true end
    return nil,why or "restricted-value"
end

function platform:IsSpellReady(spell, now)
    if not self:CanReadValue(now) then return nil, "restricted-value" end
    if type(now)~="number" or now~=now or now==math.huge or now==-math.huge then
        return nil, "invalid-time"
    end
    local start,duration,enabled,reason,active,onGCD=cooldownValues(self,spell)
    if start==nil then
        if active==nil then return nil,reason end
        return flagReadiness(self,enabled,active,onGCD,now)
    end
    if not enabled then return false end
    local expires=start+duration
    if duration==0 or expires<=now then return true end

    if not gcdSpell then self:GetGlobalCooldown() end
    local gcdStart,gcdDuration,gcdEnabled,why,gcdActive=cooldownValues(self,gcdSpell)
    if gcdStart==nil then
        -- The GCD's times are hidden: one known not to be running cannot
        -- cover this spell's own, still running, cooldown.
        if gcdActive~=nil and (not gcdEnabled or not gcdActive) then return false end
        return nil,why
    end
    if not gcdEnabled or gcdDuration==0 then return false end
    -- modRate controls cooldown animation; API timestamps/duration already
    -- describe expiration in GetTime seconds, so do not divide them by it.
    local gcdExpires=gcdStart+gcdDuration
    return gcdExpires>now and expires<=gcdExpires+0.001
end

function platform:GetSpellCharges(spell)
    local valid,reason=identifier(spell)
    if not valid then return nil,reason end
    local ok,record,built
    if C_Spell and type(C_Spell.GetSpellCharges)=="function" then
        ok,record=pcall(C_Spell.GetSpellCharges,spell)
    elseif type(GetSpellCharges)=="function" then
        local current,maximum,start,duration,rate
        ok,current,maximum,start,duration,rate=pcall(GetSpellCharges,spell)
        if not ok then return nil,"api-error" end
        record={currentCharges=current,maxCharges=maximum,cooldownStartTime=start,cooldownDuration=duration,chargeModRate=rate};built=true
    else return nil,"missing-api" end
    if not ok then return nil,"api-error" end
    if not self:CanReadValue(record) then return nil,"restricted-value" end
    if record==nil then return nil,"spell-charges-unavailable" end
    local charges,why=own(record,chargeFields,built)
    if not charges then return nil,why end
    if next(charges)==nil then return nil,"spell-charges-unavailable" end
    local current,maximum,start,duration=charges.currentCharges,charges.maxCharges,charges.cooldownStartTime,charges.cooldownDuration
    if current==nil or maximum==nil or start==nil or duration==nil or current<0 or current%1~=0
        or maximum<1 or maximum%1~=0 or current>maximum or start<0 or duration<0
        or charges.chargeModRate and charges.chargeModRate<=0 then return nil,"invalid-api-result" end
    local active=current<maximum and start>0 and duration>0
    if charges.isActive==nil then charges.isActive=active
    elseif charges.isActive and not active then return nil,"invalid-api-result" end
    charges.chargeModRate=charges.chargeModRate or 1
    return charges
end

function platform:IsCurrentSpell(spell)
    local valid, reason = identifier(spell)
    if not valid then return nil, reason end
    local native = C_Spell and C_Spell.IsCurrentSpell
    local fn = native or IsCurrentSpell
    if type(fn) ~= "function" then return nil, "missing-api" end
    local ok, active = pcall(fn, spell)
    if not ok then return nil, "api-error" end
    if not self:CanReadValue(active) then return nil, "restricted-value" end

    if not native then
        if active == 0 then
            active = false
        elseif active == 1 then
            active = true
        end
    end

    if type(active) ~= "boolean" then return nil, "invalid-api-result" end
    return active
end

-- This is the client's auto-repeat state, distinct from a current/queued
-- spell. Legacy numeric arguments are book slots, so resolve the player book
-- explicitly instead of passing a spell ID into that overload.
function platform:IsAutoRepeatActive(spellID)
    local policy=self:GetCombatDataPolicy()
    if policy~='probe' and policy~='restricted' then return nil,'unsupported-policy' end
    local valid,reason=identifier(spellID,true)
    if not valid then return nil,reason end
    local native=C_Spell and C_Spell.IsAutoRepeatSpell
    local ok,active
    if type(native)=='function' then
        ok,active=pcall(native,spellID)
    else
        if type(IsAutoRepeatSpell)~='function' or type(FindSpellBookSlotBySpellID)~='function' then return nil,'missing-api' end
        local found,slot=pcall(FindSpellBookSlotBySpellID,spellID,false)
        if not found then return nil,'api-error' end
        if not self:CanReadValue(slot) then return nil,'restricted-value' end
        if slot==nil then return nil,'spell-not-in-book' end
        if type(slot)~='number' or slot<1 or slot==math.huge or slot%1~=0 then return nil,'invalid-api-result' end
        ok,active=pcall(IsAutoRepeatSpell,slot,BOOKTYPE_SPELL or 'spell')
    end
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(active) then return nil,'restricted-value' end
    if type(native)~='function' then
        if active==0 then active=false elseif active==1 then active=true end
    end
    if type(active)~='boolean' then return nil,'invalid-api-result' end
    return active
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetSpellCharges" then return addon.Platform.GetSpellCharges end
        if name=="Platform_GetSpellCooldown" then return addon.Platform.GetSpellCooldown end
        if name=="Platform_IsAutoRepeatActive" then return addon.Platform.IsAutoRepeatActive end
        if name=="Platform_IsSpellReady" then return addon.Platform.IsSpellReady end
        if name=="chargeFields" then return chargeFields end
        if name=="cooldownFields" then return cooldownFields end
        if name=="cooldownFlags" then return cooldownFlags end
        if name=="cooldownValues" then return cooldownValues end
        if name=="copy" then return copy end
        if name=="finiteNonNegative" then return finiteNonNegative end
        if name=="flagReadiness" then return flagReadiness end
        if name=="gcdRunning" then return gcdRunning end
        if name=="gcdSpell" then return gcdSpell end
        if name=="identifier" then return identifier end
        if name=="own" then return own end
        if name=="platform" then return platform end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/spells.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/spells.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
