local _, addon = ...
local platform = addon.Platform or {}
addon.Platform = platform

local function readable(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return false end
    if type(canaccessvalue) == "function" and not canaccessvalue(value) then return false end
    return true
end

local function primitive(value)
    if not readable(value) then return nil end
    local kind = type(value)
    if kind == "string" or kind == "number" or kind == "boolean" then return value end
end

local function probe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return primitive(value) end
end

function platform:GetClientInfo()
    local project = primitive(WOW_PROJECT_ID)
    local function isProject(constant)
        return type(project) == "number" and type(constant) == "number" and project == constant
    end
    local family = "unknown"
    if isProject(WOW_PROJECT_CAMELOT) then family = "forever"
    elseif isProject(WOW_PROJECT_MAINLINE) then family = "retail"
    elseif isProject(WOW_PROJECT_CLASSIC) then family = "era"
    elseif isProject(WOW_PROJECT_BURNING_CRUSADE_CLASSIC) then family = "tbc"
    elseif isProject(WOW_PROJECT_MISTS_CLASSIC) or isProject(WOW_PROJECT_CATACLYSM_CLASSIC)
        or isProject(WOW_PROJECT_WRATH_CLASSIC) then family = "progression" end

    local info = {family=family, projectId=project, expansion=primitive(LE_EXPANSION_LEVEL_CURRENT),
                  classicExpansionLevel=probe(GetClassicExpansionLevel), locale=probe(GetLocale),
                  runtimeVerified=false}
    if type(GetBuildInfo) == "function" then
        local ok, version, build, _, interface = pcall(GetBuildInfo)
        if ok then info.version, info.build, info.interface = primitive(version), primitive(build), primitive(interface) end
    end
    if C_Seasons then info.seasonId = probe(C_Seasons.GetActiveSeason) end
    if C_GameRules then
        info.gameModeId = probe(C_GameRules.GetCurrentGameModeRecordID)
        info.hardcore = probe(C_GameRules.IsHardcoreActive)
        info.selfFoundAllowed = probe(C_GameRules.IsSelfFoundAllowed)
    end
    if family == "retail" or family == "forever" then info.combatDataPolicy = "restricted"
    elseif family == "unknown" then info.combatDataPolicy = "unsupported"
    else info.combatDataPolicy = "probe" end
    return info
end

local ownedClientInfo=platform.GetClientInfo
-- One-time private handoff. Public client metadata keeps its complete shape.
function addon:BindRotationClientReader(bind)
    if type(bind)~='function' then return nil,'invalid-client-reader-binder' end
    bind(function(current)
        local method=current.GetClientInfo
        if method~=ownedClientInfo then return method(current) end
        local project=primitive(WOW_PROJECT_ID)
        local function isProject(constant)
            return type(project)=='number' and type(constant)=='number' and project==constant
        end
        local family='unknown'
        if isProject(WOW_PROJECT_CAMELOT) then family='forever'
        elseif isProject(WOW_PROJECT_MAINLINE) then family='retail'
        elseif isProject(WOW_PROJECT_CLASSIC) then family='era'
        elseif isProject(WOW_PROJECT_BURNING_CRUSADE_CLASSIC) then family='tbc'
        elseif isProject(WOW_PROJECT_MISTS_CLASSIC) or isProject(WOW_PROJECT_CATACLYSM_CLASSIC)
            or isProject(WOW_PROJECT_WRATH_CLASSIC) then family='progression' end
        local context={family=family}
        if type(GetBuildInfo)=='function' then
            local ok,_,build=pcall(GetBuildInfo)
            if ok then context.build=primitive(build) end
        end
        if family=='retail' or family=='forever' then context.combatDataPolicy='restricted'
        elseif family=='unknown' then context.combatDataPolicy='unsupported'
        else context.combatDataPolicy='probe' end
        return context
    end)
    return true
end

function platform:CanReadValue(value)
    if not readable(value) then return false, "restricted-value" end
    return true
end

local function declaration(namespace, method, label, legacy)
    if type(namespace) == "table" and type(namespace[method]) == "function" then
        return {status="present", source=label.."."..method, readability="unverified"}
    end
    if legacy and type(_G[legacy]) == "function" then
        return {status="present", source=legacy, readability="unverified"}
    end
    return {status="missing", readability="unverified"}
end

function platform:GetAPISurface()
    return {
        spellMetadata=declaration(C_Spell, "GetSpellInfo", "C_Spell", "GetSpellInfo"),
        spellbook=declaration(C_SpellBook, "GetSpellBookItemInfo", "C_SpellBook", "GetSpellBookItemInfo"),
        knownSpell=declaration(C_SpellBook, "IsSpellKnown", "C_SpellBook", "IsSpellKnown"),
        aura=declaration(C_UnitAuras, "GetAuraDataByIndex", "C_UnitAuras", "UnitAura"),
        cooldown=declaration(C_Spell, "GetSpellCooldown", "C_Spell", "GetSpellCooldown"),
        assisted=declaration(C_AssistedCombat, "GetNextCastSpell", "C_AssistedCombat"),
        eventValidation=declaration(C_EventUtils, "IsEventValid", "C_EventUtils"),
    }
end

function platform:GetAssistedAvailability()
    if type(C_AssistedCombat) ~= "table" or type(C_AssistedCombat.IsAvailable) ~= "function" then
        return {available=false, reason="missing-api"}
    end
    local ok, available, reason = pcall(C_AssistedCombat.IsAvailable)
    if not ok then return {available=false, reason="availability-probe-error"} end
    if not readable(available) or not readable(reason) then
        return {available=false, reason="restricted-availability"}
    end
    if type(available) ~= "boolean" then return {available=false, reason="invalid-availability-result"} end
    return {available=available, reason=type(reason) == "string" and reason or nil}
end
