local _, addon = ...
local platform = addon.Platform

local function failure(reason)
    return { complete = false, reason = reason, entries = {} }
end

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

local function call(fn, ...)
    if type(fn) ~= "function" then return nil, "missing-api" end
    local ok, value = pcall(fn, ...)
    if not ok then return nil, "api-error" end
    if not platform:CanReadValue(value) then return nil, "restricted-value" end
    return value
end

-- Skill lines (Retail 11.0+: Enum.SpellBookSkillLineIndex General=1, Class=2,
-- MainSpec=3, OffSpecStart=4). A modern line names its specialization
-- (specID) or a non-active one (offSpecID); a line naming neither (General,
-- Class) is shared by every specialization. Legacy tabs carry no specID, so
-- their sharing is unknown (nil).
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

local function flag(value)
    if not platform:CanReadValue(value) then return nil, "restricted-value" end
    if value ~= nil and type(value) ~= "boolean" then return nil, "invalid-api-result" end
    return true
end

-- One slot: an entry, false (not a spell: future spell, flyout, pet action),
-- or nil plus the reason this one slot could not be read.
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

-- A single unreadable slot or line is skipped and counted, never allowed to
-- empty the whole book. Only a structural failure (no API, an unreadable line
-- count, unusable bank constants, or nothing at all readable) leaves the bank
-- incomplete.
local function skip(result, reason)
    result.skipped = result.skipped + 1
    result.skipReason = result.skipReason or reason
end

local function finishScan(result)
    if result.skipped > 0 and #result.entries == 0 and not result.hasOtherItems then
        return failure(result.skipReason)
    end

    return result
end

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

function platform:GetSpellBookSnapshot()
    return { player = scanPlayer(), pet = scanPet() }
end
