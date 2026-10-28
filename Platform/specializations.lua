-- Platform adapter for specializations and talent groups (C_SpecializationInfo with legacy globals as fallback:
-- GetSpecialization, GetSpecializationInfo, GetActiveTalentGroup, GetNumTalentGroups, GetSpecializationInfoForClassID,
-- GetSpecializationInfoByID). Owns the rotation storage key (GetRotationSpecialization) and what that key means on each
-- client family. Readers return `value, nil` or `nil, reason`; game values pass platform:CanReadValue first. Must not
-- guess a specialization the client has not reported. Loaded from RotationMaster.toc after
-- Platform/loss_of_control.lua and before Platform/talents.lua; Core/build_context.lua, Core/imports.lua and the
-- editors consume it.

local _, addon = ...
local platform = addon.Platform

-- ============================================================================
-- Query helpers
-- ============================================================================

-- Whether a value is readable and is an integer within a range.
-- @param value any  The value to test.
-- @param minimum number  The smallest accepted value.
-- @param maximum number  The largest accepted value.
-- @return boolean  True for a readable integer in [minimum, maximum].
local function integer(value, minimum, maximum)
    return platform:CanReadValue(value)
        and type(value) == "number"
        and value >= minimum
        and value < math.huge
        and value <= maximum
        and value % 1 == 0
end

-- Tells how this client addresses specializations.
-- @return string|nil  "specialization" (Retail, Forever), "single" (Era, TBC: one namespace) or "group" (progression
--   clients from expansion 2, which key by talent group); nil when the family is unknown.
-- @return string|nil  "unsupported-client" when the first return is nil; nil otherwise.
local function mode()
    local client = platform:GetClientInfo()

    if client.family == "retail" or client.family == "forever" then
        return "specialization"
    end
    if client.family == "era" or client.family == "tbc" then
        return "single"
    end
    if client.family == "progression" and integer(client.expansion, 2, 100) then
        return "group"
    end

    return nil, "unsupported-client"
end

-- Looks up a specialization function, preferring C_SpecializationInfo.
-- @param name string  The C_SpecializationInfo function name.
-- @param legacy function|nil  The legacy global to fall back to.
-- @return function|nil  C_SpecializationInfo[name] when the client has that function, otherwise legacy (which may be
--   nil).
--
-- Feature detection, not a client-version branch.
local function method(name, legacy)
    if C_SpecializationInfo and type(C_SpecializationInfo[name]) == "function" then
        return C_SpecializationInfo[name]
    end

    return legacy
end

-- Calls fn(...) under pcall and returns the result when it is a readable integer from 1 to maximum.
-- @param fn function|nil  The native function.
-- @param maximum number  The largest accepted result.
-- @param ... any  The arguments passed to fn.
-- @return number|nil  The integer result; nil on failure.
-- @return string|nil  The reason code when the first return is nil ("missing-api", "api-error", "restricted-value",
--   "specialization-unavailable" or "invalid-api-result"); nil otherwise.
local function queryInteger(fn, maximum, ...)
    if type(fn) ~= "function" then
        return nil, "missing-api"
    end

    local ok, value = pcall(fn, ...)

    if not ok then
        return nil, "api-error"
    end
    if not platform:CanReadValue(value) then
        return nil, "restricted-value"
    end
    if value == nil then
        return nil, "specialization-unavailable"
    end
    if not integer(value, 1, maximum) then
        return nil, "invalid-api-result"
    end

    return value
end

-- ============================================================================
-- Active specialization and the rotation storage key
-- ============================================================================

-- Retail: a character who has not chosen a specialization (new characters
-- start without one) has none.
-- GetSpecialization() then answers the class's initial spec, an index past
-- the class's count (Blizzard's UnitUtil IsInitialSpec), with its own spec ID
-- (SpecializationID "Initial" rows, Gethe/wow-ui-source and wago.tools
-- ChrSpecialization), keyed here by class ID. Rotations for that stage are
-- saved under this ID like any other specialization.
local INITIAL_SPECS = {
    [1] = 1446,
    [2] = 1451,
    [3] = 1448,
    [4] = 1453,
    [5] = 1452,
    [6] = 1455,
    [7] = 1444,
    [8] = 1449,
    [9] = 1454,
    [10] = 1450,
    [11] = 1447,
    [12] = 1456,
    [13] = 1465,
}

-- Reads the player's current selection and the rotation storage key it maps to.
-- @return table|nil  { kind = "single"|"group"|"specialization", index = n, key = n }; "single" clients always
--   answer index 0 and key 0. nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- key is the saved rotation namespace; index is the native API selector.
function platform:GetRotationSpecialization()
    local kind, reason = mode()

    if not kind then
        return nil, reason
    end
    if kind == "single" then
        return { kind = kind, index = 0, key = 0 }
    end

    if kind == "group" then
        local group, why = queryInteger(method("GetActiveSpecGroup", GetActiveTalentGroup), 4, false, false)

        if not group then
            return nil, why
        end

        return { kind = kind, index = group, key = group }
    end

    local index, why = queryInteger(method("GetSpecialization", GetSpecialization), 16)

    if not index then
        return nil, why
    end

    local id, unavailable = queryInteger(method("GetSpecializationInfo", GetSpecializationInfo), math.huge, index)

    if not id then
        return nil, unavailable
    end

    return { kind = kind, index = index, key = id }
end

-- Reads the player's active specialization index (1..4).
-- @return number|nil  The integer index; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- For an observation that depends on it: POINT's per-specialization resource on Mists of Pandaria Classic. It is not
-- the rotation storage key above (progression stores per talent group). Blizzard's 5.5.4 resource bars compare
-- C_SpecializationInfo.GetSpecialization() with the SPEC_* indices (Gethe/wow-ui-source classic 45eb466ddb,
-- Blizzard_FrameXMLBase/Classic/Constants.lua; Blizzard_UnitFrame/Mists/ShardBar.lua, PriestBar.lua). No
-- specialization yet (below level 10) is unavailable, never index 1.
function platform:GetPlayerSpecializationIndex()
    return queryInteger(method("GetSpecialization", GetSpecialization), 16)
end

-- Lists the storage choices for a class.
-- @param classID number|nil  The class id; required on "specialization" clients, ignored elsewhere.
-- @return table[]|nil  A fresh list of { id, name?, initial? }: one entry on "single" clients, one per talent group
--   on "group" clients, and the class's specializations on "specialization" clients (plus Retail's initial "no
--   specialization" entry). nil when the client cannot answer.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
function platform:GetRotationSpecializations(classID)
    local kind, reason = mode()

    if not kind then
        return nil, reason
    end
    if kind == "single" then
        return { { id = 0 } }
    end

    if kind == "group" then
        local count, why = queryInteger(GetNumTalentGroups, 4, false, false)

        if not count then
            return nil, why
        end

        local choices = {}

        for index = 1, count do
            choices[index] = { id = index }
        end

        return choices
    end

    if not integer(classID, 1, math.huge) then
        return nil, "invalid-class"
    end

    local count, why = queryInteger(
        method("GetNumSpecializationsForClassID", GetNumSpecializationsForClassID),
        16,
        classID
    )

    if not count then
        return nil, why
    end
    if type(GetSpecializationInfoForClassID) ~= "function" then
        return nil, "missing-api"
    end

    local choices, seen = {}, {}

    for index = 1, count do
        local ok, id, name = pcall(GetSpecializationInfoForClassID, classID, index)

        if not ok then
            return nil, "api-error"
        end
        if not self:CanReadValue(id) or not self:CanReadValue(name) then
            return nil, "restricted-value"
        end
        if not integer(id, 1, math.huge) or type(name) ~= "string" or name == "" or seen[id] then
            return nil, "invalid-api-result"
        end

        seen[id] = true
        choices[index] = { id = id, name = name }
    end

    -- Retail offers the class's initial spec too ("No specialization"). The live
    -- selection names it when the player is in it; otherwise the known ID.
    if self:GetClientFamily() == "retail" then
        local initial = INITIAL_SPECS[classID]
        local current = self:GetRotationSpecialization()

        if current and current.kind == "specialization" and current.index > count and type(UnitClass) == "function" then
            local ok, _, _, playerClass = pcall(UnitClass, "player")

            if ok and self:CanReadValue(playerClass) and playerClass == classID then
                initial = current.key
            end
        end

        if initial and not seen[initial] then
            choices[#choices + 1] = { id = initial, initial = true }
        end
    end

    return choices
end

-- ============================================================================
-- Specialization kinds and editor choices
-- ============================================================================

-- A rotation's specializations (body.specs) hold one kind of value per
-- client, a static fact of the client family (and Classic Progression's
-- expansion), never of the character's level or whether a second
-- specialization is unlocked yet:
--   portable  the game's specialization IDs, the same on every account:
--             Retail (with each class's "no specialization" ID) and Mists of
--             Pandaria Classic (progression, expansion 4 and later).
--   slot      a talent group number (1 or 2, primary or secondary talents),
--             which means something only on this character: every client
--             that has (or will get) dual specialization: Classic Era and
--             Season of Discovery, TBC Anniversary, Wrath and Cataclysm
--             Classic (progression, expansions 2-3) and Forever.
-- Exports drop slot values; imports fill them in (Core/imports.lua).
local SPEC_KINDS = { retail = 'portable', era = 'slot', tbc = 'slot', forever = 'slot' }

-- Whether the client is Mists of Pandaria or later, whose progression clients name real specializations.
-- @return boolean  True when LE_EXPANSION_LEVEL_CURRENT is a readable integer of 4 or more.
local function mistsOrLater()
    local expansion = LE_EXPANSION_LEVEL_CURRENT
    return integer(expansion, 4, 100)
end

-- Tells which kind of specialization value a rotation's specs hold on this client.
-- @return string|nil  "portable" (the game's specialization ids) or "slot" (a talent group number), see SPEC_KINDS;
--   nil when the client is unsupported.
-- @return string|nil  "unsupported-client" when the first return is nil; nil otherwise.
function platform:GetRotationSpecKind()
    local family = self:GetClientFamily()
    local kind = SPEC_KINDS[family]

    if kind then
        return kind
    end
    if family == 'progression' then
        return mistsOrLater() and 'portable' or 'slot'
    end

    return nil, 'unsupported-client'
end

-- Tells whether the saved-rotation namespace (GetRotationSpecialization().key) is itself a specialization value.
-- @return boolean  True on Retail (keyed by specialization id) and Wrath or Cataclysm Classic (keyed by talent group);
--   false for Mists Classic, Era, TBC, Forever and an unidentified client family.
--
-- Mists Classic keys by talent group but its values are specialization ids, and Era, TBC and Forever keep one
-- namespace per class.
function platform:RotationKeyIsSpecValue()
    local family = self:GetClientFamily()

    if family == 'retail' then
        return true
    end

    return family == 'progression' and not mistsOrLater()
end

-- Reads the character's current specialization value (see GetRotationSpecKind).
-- @return number|nil  The value as an integer; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Slot clients answer the active talent group, 1 when the client has a single one; Mists Classic without a
-- specialization yet is unavailable.
function platform:GetRotationSpecValue()
    local kind, reason = self:GetRotationSpecKind()

    if not kind then
        return nil, reason
    end

    if kind == 'slot' then
        local native = method("GetActiveSpecGroup", GetActiveTalentGroup)

        if type(native) ~= 'function' then
            return 1
        end

        return queryInteger(native, 4, false, false)
    end

    if self:GetClientFamily() == 'retail' then
        local selection, why = self:GetRotationSpecialization()

        if not selection then
            return nil, why
        end

        return selection.key
    end

    return self:GetPlayerSpecializationID()
end

-- Lists the specialization values a rotation can be restricted to on this client.
-- @param classID number|nil  The class id whose specializations are offered; ignored on slot clients.
-- @return table[]|nil  A fresh list of { id, name, initial, slot }; slot clients always offer both talent groups. nil
--   when the client cannot answer.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
function platform:GetRotationSpecChoices(classID)
    local kind, reason = self:GetRotationSpecKind()

    if not kind then
        return nil, reason
    end
    if kind == 'slot' then
        return { { id = 1, slot = true }, { id = 2, slot = true } }
    end
    if self:GetClientFamily() == 'retail' then
        return self:GetRotationSpecializations(classID)
    end

    return self:GetClassSpecializationChoices(classID)
end

-- Whether a Retail spec id is a class's initial spec ("No specialization").
-- @param specID number  The specialization id.
-- @return boolean  True for an initial spec; false on every other client family.
function platform:IsInitialSpecialization(specID)
    if self:GetClientFamily() ~= "retail" or type(specID) ~= "number" then
        return false
    end

    for _, id in pairs(INITIAL_SPECS) do
        if id == specID then
            return true
        end
    end

    return false
end

-- ============================================================================
-- Specialization identity and display data
-- ============================================================================

-- Reads the player's specialization id (Retail, Mists of Pandaria Classic), for the SPECIALIZATION condition.
-- @return number|nil  The specialization id; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Forever's specialization API reports one id per class (its three trees are trait groups), so it cannot name a spec
-- there. Talent-tree clients have no specialization API; the condition reads their primary talent tree instead
-- (Core/build_context.lua). No specialization yet is unavailable, never a guessed index.
function platform:GetPlayerSpecializationID()
    local family = self:GetClientFamily()

    if family == "forever" then
        return nil, "specialization-unsupported"
    end
    if family ~= "retail" and family ~= "progression" then
        return nil, "unsupported-client"
    end

    local index, why = queryInteger(method("GetSpecialization", GetSpecialization), 16)

    if not index then
        return nil, why
    end

    return queryInteger(method("GetSpecializationInfo", GetSpecializationInfo), math.huge, index)
end

-- Lists one class's specializations as the client names them, for editors.
-- @param classID number  The class id, an integer from 1 to 64.
-- @return table[]|nil  A fresh list of { id, name, icon }; nil when the client cannot answer.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Only clients whose specialization API names real specs answer (not Forever).
function platform:GetClassSpecializationChoices(classID)
    local family = self:GetClientFamily()

    if family ~= "retail" and family ~= "progression" then
        return nil, "unsupported-client"
    end
    if not integer(classID, 1, 64) then
        return nil, "invalid-class"
    end

    local count, why = queryInteger(
        method("GetNumSpecializationsForClassID", GetNumSpecializationsForClassID),
        16,
        classID
    )

    if not count then
        return nil, why
    end
    if type(GetSpecializationInfoForClassID) ~= "function" then
        return nil, "missing-api"
    end

    local choices = {}

    for index = 1, count do
        local ok, id, name, _, icon = pcall(GetSpecializationInfoForClassID, classID, index)

        if not ok then
            return nil, "api-error"
        end
        if not self:CanReadValue(id) or not self:CanReadValue(name) or not self:CanReadValue(icon) then
            return nil, "restricted-value"
        end
        if not integer(id, 1, math.huge) or type(name) ~= "string" or name == "" then
            return nil, "invalid-api-result"
        end

        if type(icon) ~= "number" and type(icon) ~= "string" then
            icon = nil
        end

        choices[#choices + 1] = { id = id, name = name, icon = icon }
    end

    return choices
end

-- Reads the display name, icon and class token of a specialization id, where the client can name it.
-- @param specID number  The specialization id.
-- @return table|nil  { id, name, icon?, class? }; icon and class are nil when the client reports another type. nil
--   when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Retail order of GetSpecializationInfoByID: id, name, description, icon, role, class.
function platform:GetSpecializationDisplay(specID)
    local family = self:GetClientFamily()

    if family ~= "retail" and family ~= "progression" then
        return nil, "unsupported-client"
    end
    if not integer(specID, 1, math.huge) or type(GetSpecializationInfoByID) ~= "function" then
        return nil, "missing-api"
    end

    local ok, id, name, _, icon, _, classFile = pcall(GetSpecializationInfoByID, specID)

    if not ok then
        return nil, "api-error"
    end
    if
        not self:CanReadValue(id)
        or not self:CanReadValue(name)
        or not self:CanReadValue(icon)
        or not self:CanReadValue(classFile)
    then
        return nil, "restricted-value"
    end
    if id ~= specID or type(name) ~= "string" or name == "" then
        return nil, "specialization-unavailable"
    end

    if type(icon) ~= "number" and type(icon) ~= "string" then
        icon = nil
    end

    return { id = id, name = name, icon = icon, class = type(classFile) == "string" and classFile or nil }
end
