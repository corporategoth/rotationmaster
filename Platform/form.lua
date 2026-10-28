-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for shapeshift forms and stances: GetShapeshiftForm, GetShapeshiftFormInfo and GetShapeshiftFormID.
-- Owns the `value or nil, reason` readers for the player's form index and form spell, plus the table of form spells
-- the editor offers per class and client family; it must not label forms (the condition and its Fields UI do).
-- GetPlayerFormObservation is a Built In helper whose body is recorded in the generated block at the end of the file
-- and must keep its exact text. Loaded from RotationMaster.toc after Platform/player_flags.lua.
local _, addon = ...
local platform = addon.Platform

-- Keep the native numeric observation unchanged; form labels and configured
-- class-dependent bounds belong to the authored condition and its Fields UI.
-- Returns the form index (0 means none), or nil and a reason code.
function platform:GetPlayerFormObservation()
    local policy=self:GetCombatDataPolicy()
    if policy~='probe' and policy~='restricted' then return nil,'unsupported-policy' end
    if type(GetShapeshiftForm)~='function' then return nil,'missing-api' end
    local ok,result=pcall(GetShapeshiftForm)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(result) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(result) then return nil,'restricted-value' end
    if result==nil then return nil,'form-unavailable' end
    if type(result)~='number' or result~=result or result==math.huge or result==-math.huge then return nil,'invalid-api-result' end
    return result
end

-- The active form's spell is its stable identity; the slot index above shifts
-- as forms are learned. 0 means no form (humanoid). Ghost Wolf is a form
-- without a stance-bar entry, so it is known by its constant form ID instead.
local GHOST_WOLF_FORM, GHOST_WOLF = 16, 2645

-- Validates a form's spell id: returns it, nil when absent, or nil and a reason code when secret or not a positive
-- integer.
local function spellID(self, id)
    if not self:CanReadValue(id) then
        return nil, 'restricted-value'
    end
    if canaccessvalue and not canaccessvalue(id) then
        return nil, 'restricted-value'
    end
    if id == nil then
        return nil
    end
    if type(id) ~= 'number' or id ~= id or id <= 0 or id == math.huge or id % 1 ~= 0 then
        return nil, 'invalid-api-result'
    end

    return id
end

-- Returns the spell id of the player's active form (0 when in no form), or nil and a reason code. Tries the stance
-- bar entry first, then the constant form id for forms that have no stance-bar entry (Ghost Wolf).
function platform:GetPlayerFormSpellObservation()
    local index, reason = self:GetPlayerFormObservation()

    if index == nil then
        return nil, reason
    end
    if index == 0 then
        return 0
    end
    if index < 0 or index % 1 ~= 0 then
        return nil, 'invalid-api-result'
    end

    if type(GetShapeshiftFormInfo) == 'function' then
        local ok, _, _, _, id = pcall(GetShapeshiftFormInfo, index)

        if not ok then
            return nil, 'api-error'
        end

        local form, why = spellID(self, id)

        if form then
            return form
        end
        if why then
            return nil, why
        end
    end

    if type(GetShapeshiftFormID) == 'function' then
        local ok, id = pcall(GetShapeshiftFormID)

        if not ok then
            return nil, 'api-error'
        end

        local form, why = spellID(self, id)

        if why then
            return nil, why
        end
        if form == GHOST_WOLF_FORM then
            return GHOST_WOLF
        end
    end

    return nil, 'form-identity-unavailable'
end

-- Form spells the editor offers besides those on the stance bar, so a form
-- can be picked before it is learned. Base ranks: any rank of a form matches.
-- Client families: e=Era, t=TBC, f=Forever, m=Mists. Only spells that are
-- forms (stance-bar entries) on that client are listed; the stance bar itself
-- is listed live by the editor and covers anything missing here.
local familyLetter = { era = 'e', tbc = 't', forever = 'f', progression = 'm' }

local classForms = {
    DRUID = {
        { 5487, 'etfm' },
        { 9634, 'etf' },
        { 1066, 'etfm' },
        { 768, 'etfm' },
        { 783, 'etfm' },
        { 24858, 'etfm' },
        { 33891, 'tm' },
        { 33943, 'tm' },
        { 40120, 'tm' },
        { 114282, 'm' },
    },
    WARRIOR = { { 2457, 'etfm' }, { 71, 'etfm' }, { 2458, 'etfm' } },
    PALADIN = {
        { 465, 'etf' },
        { 7294, 'etf' },
        { 19746, 'etf' },
        { 19876, 'etf' },
        { 19888, 'etf' },
        { 19891, 'etf' },
        { 20218, 'etf' },
        { 32223, 't' },
        { 20154, 'm' },
        { 31801, 'm' },
        { 20164, 'm' },
        { 20165, 'm' },
        { 105361, 'm' },
    },
    ROGUE = { { 1784, 'etfm' } },
    PRIEST = { { 15473, 'm' } },
    SHAMAN = { { GHOST_WOLF, 'etfm' } },
    DEATHKNIGHT = { { 48263, 'm' }, { 48266, 'm' }, { 48265, 'm' } },
    MONK = { { 115069, 'm' }, { 103985, 'm' }, { 115070, 'm' } },
    WARLOCK = { { 103958, 'm' } },
}

-- Returns the form spell ids the editor may offer for a class token on this client family, keeping only spells the
-- client knows. Returns an empty list when the family or class has none.
function platform:GetFormSpellCandidates(class)
    local result = {}
    local letter = familyLetter[self:GetClientFamily()]
    local list = letter and classForms[class]

    if not list then
        return result
    end

    -- A spell this client does not have is not offered.
    if type(self.GetSpellInfo) ~= 'function' then
        return result
    end

    for _, entry in ipairs(list) do
        if entry[2]:find(letter, 1, true) and self:GetSpellInfo(entry[1]) then
            result[#result + 1] = entry[1]
        end
    end

    return result
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetPlayerFormObservation" then return addon.Platform.GetPlayerFormObservation end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/form.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/form.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
