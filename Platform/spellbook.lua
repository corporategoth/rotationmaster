-- Platform adapter that scans the player's and pet's spellbook (C_SpellBook skill lines and items on modern clients;
-- GetSpellTabInfo, GetSpellBookItemInfo and IsPassiveSpell on legacy ones). The only public entry is
-- platform:GetSpellBookSnapshot, which returns the raw entries for Core/spell_catalog.lua to attribute to
-- specializations. A single unreadable slot or line is skipped and counted; only a structural failure marks a bank
-- incomplete with a reason. Every game value passes platform:CanReadValue first. Loaded from RotationMaster.toc
-- after Platform/totems.lua and Platform/actions.lua; it must not cache, because the book changes on learning.
local _, addon = ...
local platform = addon.Platform

-- ============================================================================
-- Reading helpers
-- ============================================================================

-- Builds the result for a bank that could not be scanned at all: incomplete, with the reason and no entries.
local function failure(reason)
    return { complete = false, reason = reason, entries = {} }
end

-- Returns value when it is a readable finite integer of at least minimum (and at most maximum when given); otherwise
-- nil and a reason. A nil value is "spellbook-data-unavailable"; a value above maximum is "spellbook-limit", which
-- bounds the work a hostile or broken client can cause.
local function number(value, minimum, maximum)
    if not platform:CanReadValue(value) then return nil, "restricted-value" end

    if
        type(value) ~= "number"
        or value ~= value
        or value == math.huge
        or value == -math.huge
        or value % 1 ~= 0
        or value < minimum
    then
        return nil, value == nil and "spellbook-data-unavailable" or "invalid-api-result"
    end

    if maximum and value > maximum then return nil, "spellbook-limit" end
    return value
end

-- Calls fn(...) under pcall and returns its first result, or nil and a reason when fn is missing, throws or returns a
-- restricted value. A readable nil result is returned as nil with no reason.
local function call(fn, ...)
    if type(fn) ~= "function" then return nil, "missing-api" end
    local ok, value = pcall(fn, ...)
    if not ok then return nil, "api-error" end
    if not platform:CanReadValue(value) then return nil, "restricted-value" end
    return value
end

-- ============================================================================
-- Skill lines and items
-- ============================================================================

-- Skill lines (Retail 11.0+: Enum.SpellBookSkillLineIndex General=1, Class=2,
-- MainSpec=3, OffSpecStart=4). A modern line names its specialization
-- (specID) or a non-active one (offSpecID); a line naming neither (General,
-- Class) is shared by every specialization. Legacy tabs carry no specID, so
-- their sharing is unknown (nil).
-- Returns { offset, count, offSpecID, specID, shared } for skill line or tab `index`, or nil and a reason. modern
-- selects C_SpellBook over GetSpellTabInfo.
local function readLine(index, modern)
    local record, why

    if modern then
        record, why = call(C_SpellBook.GetSpellBookSkillLineInfo, index)
    else
        if type(GetSpellTabInfo) ~= "function" then return nil, "missing-api" end
        local ok, name, icon, offset, count, guild, offSpecID = pcall(GetSpellTabInfo, index)
        if not ok then return nil, "api-error" end
        record = { itemIndexOffset = offset, numSpellBookItems = count, offSpecID = offSpecID }
    end

    if why then return nil, why end
    if type(record) ~= "table" then return nil, "spellbook-data-unavailable" end
    local offset, errorCode = number(record.itemIndexOffset, 0, 4096)
    if not offset then return nil, errorCode end
    local count, reason = number(record.numSpellBookItems, 0, 4096)
    if not count then return nil, reason end
    local offSpecID, specID = record.offSpecID, modern and record.specID or nil
    if not platform:CanReadValue(offSpecID) or not platform:CanReadValue(specID) then return nil, "restricted-value" end

    if offSpecID ~= nil then
        local checked, problem = number(offSpecID, 0)
        if not checked then return nil, problem end
        if offSpecID == 0 then offSpecID = nil end
    end

    if specID ~= nil then
        local checked, problem = number(specID, 0)
        if not checked then return nil, problem end
        if specID == 0 then specID = nil end
    end

    if offset + count > 4096 then return nil, "spellbook-limit" end
    local shared
    if modern then shared = specID == nil and offSpecID == nil end
    return { offset = offset, count = count, offSpecID = offSpecID, specID = specID, shared = shared }
end

-- The bank and item-type constants are the same for every slot, so they are
-- resolved once per scan; a problem here is structural (fails the bank).
-- Returns { modern, native, bank, spellType } for the player or pet bank, or nil and a reason. It falls back to the
-- legacy GetSpellBookItemInfo reader when the Enum constants are missing and that global exists.
local function bankReader(pet)
    local native = C_SpellBook and C_SpellBook.GetSpellBookItemInfo
    local modern = type(native) == "function"
    local banks = Enum and Enum.SpellBookSpellBank
    local types = Enum and Enum.SpellBookItemType

    if modern and (not platform:CanReadValue(banks) or not platform:CanReadValue(types)) then
        return nil, "restricted-value"
    end

    local bank, spellType

    if type(banks) == "table" then
        if pet then
            bank = banks.Pet
        else
            bank = banks.Player
        end
    end

    if type(types) == "table" then spellType = types.Spell end

    if modern and (not platform:CanReadValue(bank) or not platform:CanReadValue(spellType)) then
        return nil, "restricted-value"
    end

    if modern and (type(bank) ~= "number" or type(spellType) ~= "number") then
        if type(GetSpellBookItemInfo) == "function" then
            modern = false
        elseif type(bank) ~= "number" then
            return nil, "missing-spell-bank"
        else
            return nil, "missing-spell-type"
        end
    end

    if not modern and type(GetSpellBookItemInfo) ~= "function" then return nil, "missing-api" end
    return { modern = modern, native = native, bank = bank, spellType = spellType }
end

-- Returns true when value is a readable Boolean or nil, otherwise nil and a reason. Used for optional native flags.
local function flag(value)
    if not platform:CanReadValue(value) then return nil, "restricted-value" end
    if value ~= nil and type(value) ~= "boolean" then return nil, "invalid-api-result" end
    return true
end

-- One slot: an entry, false (not a spell: future spell, flyout, pet action),
-- or nil plus the reason this one slot could not be read.
-- A returned entry carries spellID, baseSpellID (the un-overridden spell), slot, bank ("player" or "pet"), isPassive,
-- isOffSpec and, from the skill line, offSpecID, lineSpecID and shared.
local function readItem(reader, slot, pet, line)
    local id, baseID, passive, offspec

    if reader.modern then
        local record, why = call(reader.native, slot, reader.bank)
        if why then return nil, why end
        if type(record) ~= "table" then return nil, "spellbook-data-unavailable" end
        if not platform:CanReadValue(record.itemType) then return nil, "restricted-value" end
        if type(record.itemType) ~= "number" then return nil, "invalid-api-result" end
        if record.itemType ~= reader.spellType then return false end
        id, baseID, passive, offspec = record.spellID, record.actionID, record.isPassive, record.isOffSpec
        local ok, problem = flag(passive)
        if not ok then return nil, problem end
        ok, problem = flag(offspec)
        if not ok then return nil, problem end
        -- isOffSpec is documented non-nil; if a build omits it, the line says.
        if offspec == nil then offspec = line ~= nil and line.offSpecID ~= nil end
    else
        local kind, ok
        ok, kind, id = pcall(GetSpellBookItemInfo, slot, pet and (BOOKTYPE_PET or "pet") or (BOOKTYPE_SPELL or "spell"))
        if not ok then return nil, "api-error" end
        if not platform:CanReadValue(kind) then return nil, "restricted-value" end
        if type(kind) ~= "string" then return nil, "spellbook-data-unavailable" end
        if kind ~= "SPELL" then return false end

        if type(IsPassiveSpell) == "function" then
            local why
            passive, why = call(IsPassiveSpell, slot, pet and (BOOKTYPE_PET or "pet") or (BOOKTYPE_SPELL or "spell"))
            if why then return nil, why end
            if type(passive) ~= "boolean" then return nil, "invalid-api-result" end
        end

        baseID = id
        offspec = line and line.offSpecID ~= nil or false
    end

    local spellID, why = number(id, 1)
    if not spellID then return nil, why end
    -- actionID is the base spell (spellID is its override when one is active).
    -- An unreadable base is left out rather than failing the spell itself.
    local base = number(baseID, 1)

    return {
        spellID = spellID,
        baseSpellID = base,
        slot = slot,
        bank = pet and "pet" or "player",
        isPassive = passive,
        isOffSpec = offspec,
        offSpecID = line and line.offSpecID or nil,
        lineSpecID = line and line.specID or nil,
        shared = line and line.shared or nil,
    }
end

-- ============================================================================
-- Scans
-- ============================================================================

-- A single unreadable slot or line is skipped and counted, never allowed to
-- empty the whole book. Only a structural failure (no API, an unreadable line
-- count, unusable bank constants, or nothing at all readable) leaves the bank
-- incomplete.
-- Counts one skipped slot or line in result and remembers the first reason.
local function skip(result, reason)
    result.skipped = result.skipped + 1
    result.skipReason = result.skipReason or reason
end

-- Returns result, unless something was skipped and nothing at all was readable (no spells and no other items), in
-- which case the bank is reported as failed with the first skip reason.
local function finishScan(result)
    if result.skipped > 0 and #result.entries == 0 and not result.hasOtherItems then
        return failure(result.skipReason)
    end

    return result
end

-- Scans every player skill line or spell tab and returns { complete, entries, coverage, skipped, skipReason? }. The
-- 4096-slot total and the seen-slot set guard against overlapping or runaway lines.
local function scanPlayer()
    local modern = C_SpellBook and type(C_SpellBook.GetNumSpellBookSkillLines) == "function"
    local count, why = call(modern and C_SpellBook.GetNumSpellBookSkillLines or GetNumSpellTabs)
    if why then return failure(why) end
    local lines, reason = number(count, 0, 128)
    if not lines then return failure(reason) end
    local result = { complete = true, entries = {}, coverage = "direct-spells", skipped = 0 }
    local reader, problem
    local total, seen = 0, {}

    for index = 1, lines do
        local line, errorCode = readLine(index, modern)

        if not line then
            skip(result, errorCode)
        elseif total + line.count > 4096 then
            skip(result, "spellbook-limit")
        else
            total = total + line.count

            if line.count > 0 and not reader then
                reader, problem = bankReader(false)
                if not reader then return failure(problem) end
            end

            for slot = line.offset + 1, line.offset + line.count do
                if seen[slot] then
                    skip(result, "overlapping-spellbook-lines")
                else
                    seen[slot] = true
                    local entry, failed = readItem(reader, slot, false, line)

                    if entry == nil then
                        skip(result, failed)
                    elseif entry then
                        result.entries[#result.entries + 1] = entry
                    else
                        result.hasOtherItems = true
                    end
                end
            end
        end
    end

    return finishScan(result)
end

-- Scans the pet spellbook (slots 1 to the pet spell count) and returns the same shape as scanPlayer. A player with no
-- pet spells yields a complete, empty result.
local function scanPet()
    local fn = C_SpellBook and C_SpellBook.HasPetSpells or HasPetSpells
    local count, why = call(fn)
    if why then return failure(why) end
    if count == nil then return { complete = true, entries = {}, coverage = "direct-spells", skipped = 0 } end
    local maximum, reason = number(count, 0, 4096)
    if not maximum then return failure(reason) end
    local result = { complete = true, entries = {}, coverage = "direct-spells", skipped = 0 }
    if maximum == 0 then return result end
    local reader, problem = bankReader(true)
    if not reader then return failure(problem) end

    for slot = 1, maximum do
        local entry, failed = readItem(reader, slot, true)

        if entry == nil then
            skip(result, failed)
        elseif entry then
            result.entries[#result.entries + 1] = entry
        else
            result.hasOtherItems = true
        end
    end

    return finishScan(result)
end

-- ============================================================================
-- Public API
-- ============================================================================

-- Returns { player = scan, pet = scan } where each scan is { complete, entries, ... } (or { complete = false,
-- reason, entries = {} } when that bank could not be read). Reads the whole book on every call and allocates, so it
-- is for the catalog refresh (addon:RefreshSpellCatalog in Core/spell_catalog.lua), not for the poll path.
function platform:GetSpellBookSnapshot()
    return { player = scanPlayer(), pet = scanPet() }
end
