local _, addon = ...

-- This index belongs to RM. Metadata is useful for reference/search even when
-- a spell is not learned; only a fresh spellbook snapshot populates specSpells.
local catalog = {}
addon.SpellCatalog = catalog
local entries, byName = {}, {}
-- At most one private ordering per indexed name group. Metadata refresh still
-- observes the provider; only ordering/membership changes retire this view.
local ordered, groupVersion, memberNames = {}, {}, {}

local function invalidateGroup(key)
    ordered[key] = nil
    groupVersion[key] = (groupVersion[key] or 0) + 1
end

local function copyIDs(ids)
    local result = {}

    for i = 1, #ids do
        result[i] = ids[i]
    end

    return result
end

local function rankNumber(entry)
    return tonumber((entry.rank or ""):match("%d+")) or 0
end

local function preferred(left, right)
    local a, b = rankNumber(entries[left]), rankNumber(entries[right])
    if a ~= b then return a > b end
    return left > right
end

function catalog:UpdateSpell(id)
    if type(id) ~= "number" or id < 1 or id == math.huge or id % 1 ~= 0 then return nil end
    local info, reason = addon.Platform:GetSpellInfo(id)
    if not info then return nil, reason end
    local old = entries[id]

    if old and old.name ~= info.name then
        local oldKey = string.lower(old.name)
        invalidateGroup(oldKey)
        byName[oldKey][id] = nil
        memberNames[id][oldKey] = nil
    end

    local entry = { name = info.name, rank = info.subtext, icon = info.iconID, link = addon.Platform:GetSpellLink(id) }
    -- A link provider can reenter and update this ID before outer publication.
    local previous = entries[id]

    if previous and (previous.name ~= entry.name or previous.rank ~= entry.rank) then
        -- Reentrant publication can leave an ID in more than its current name
        -- group. Every surviving membership sorts against this same entry.
        for member in pairs(memberNames[id]) do
            invalidateGroup(member)
        end
    end

    entries[id] = entry
    local key = string.lower(entry.name)
    byName[key] = byName[key] or {}
    if not byName[key][id] then invalidateGroup(key) end
    byName[key][id] = true
    memberNames[id] = memberNames[id] or {}
    memberNames[id][key] = true
    return true
end

function catalog:GetAllSpellIds(spell)
    local name

    if type(spell) == "number" then
        if not entries[spell] then self:UpdateSpell(spell) end
        name = entries[spell] and entries[spell].name
    elseif type(spell) == "string" then
        name = spell
    end

    if not name then return nil end
    local key = string.lower(name)
    local group = byName[key]
    if not group then return nil end
    if ordered[key] then return copyIDs(ordered[key]) end
    local version = groupVersion[key]
    local result = {}

    for id in pairs(group) do
        result[#result + 1] = id
    end

    table.sort(result, preferred)
    -- Never publish a stale sort, or expose its private storage to the caller
    -- (or a source-owned sorting hook used during this cold construction).
    if groupVersion[key] == version then ordered[key] = copyIDs(result) end
    return result
end

function catalog:GetSpellId(spell, rank)
    local ids = self:GetAllSpellIds(spell)

    if not ids and type(spell) == "string" then
        local info, why = addon.Platform:GetSpellInfo(spell)

        if info and type(info.spellID) == "number" then
            self:UpdateSpell(info.spellID)
            ids = self:GetAllSpellIds(info.spellID)
        elseif why == "restricted-value" or why == "api-error" then
            return nil, why
        end
    end

    -- Preserve the native name resolver's canonical/override choice rather
    -- than assuming the highest indexed metadata rank is currently learned.
    if ids and rank == nil then
        local info, why = addon.Platform:GetSpellInfo(entries[ids[1]].name)

        if info and type(info.spellID) == "number" then
            local indexed, problem = self:UpdateSpell(info.spellID)
            if indexed then return info.spellID end
            return nil, problem or "spell-data-unavailable"
        elseif why == "restricted-value" or why == "api-error" then
            return nil, why
        end
    end

    if ids then
        for _, id in ipairs(ids) do
            if rank == nil or entries[id].rank == rank then return id end
        end
    end
end

function catalog:SpellName(id, norank)
    if not entries[id] then self:UpdateSpell(id) end
    local entry = entries[id]

    if entry then
        if not norank and entry.rank and entry.rank ~= "" then
            return entry.name .. "|cFF888888 (" .. entry.rank .. ")|r"
        end

        return entry.name
    end
end

function catalog:SpellLink(id)
    if not entries[id] then self:UpdateSpell(id) end
    return entries[id] and entries[id].link or addon.Platform:GetSpellLink(id)
end

function catalog:SpellRank(id)
    if not entries[id] then self:UpdateSpell(id) end
    return entries[id] and entries[id].rank
end

function catalog:SpellRankNum(id)
    if not entries[id] then self:UpdateSpell(id) end
    return entries[id] and rankNumber(entries[id]) or 0
end

-- Rotation keys a spec-agnostic spellbook entry also belongs to. On clients
-- whose rotations are keyed by specialization ID (Retail, Forever), the General
-- and Class skill lines are shared by every specialization of the class, and
-- so is a line for a specialization that is not one of them: below level 10
-- the active "initial" specialization (index > GetNumSpecializations(),
-- Blizzard_SharedXML/UnitUtil.lua IsInitialSpec) has its own ID that no
-- rotation is ever keyed by. Other clients key rotations by talent group or a
-- single key and keep the current-spec attribution only.
local function sharedSpecs(self)
    local platform = self.Platform

    if type(platform.GetClientFamily) ~= "function" or type(platform.GetRotationSpecializations) ~= "function" then
        return nil
    end

    local family = platform:GetClientFamily()
    if family ~= "retail" and family ~= "forever" then return nil end
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, _, classID = pcall(UnitClass, "player")
    if not ok or not platform:CanReadValue(classID) then return nil end
    local choices = platform:GetRotationSpecializations(classID)
    if type(choices) ~= "table" then return nil end
    local list, set = {}, {}

    for _, choice in ipairs(choices) do
        local id = type(choice) == "table" and choice.id

        if type(id) == "number" and not set[id] then
            set[id] = true
            list[#list + 1] = id
        end
    end

    if #list == 0 then return nil end
    return { list = list, set = set }
end

function addon:RefreshSpellCatalog()
    local snapshot = self.Platform:GetSpellBookSnapshot()
    local petKey = BOOKTYPE_PET or "pet"
    local spells, reverse = { [petKey] = {} }, { [petKey] = {} }

    if self.currentSpec ~= nil then
        spells[self.currentSpec] = {}
        reverse[self.currentSpec] = {}
    end

    local shared = sharedSpecs(self)

    local function add(spec, id)
        spells[spec] = spells[spec] or {}
        reverse[spec] = reverse[spec] or {}
        spells[spec][id] = true
        local name = catalog:SpellName(id, true)

        if name then
            local previous = reverse[spec][name]
            if not previous or preferred(id, previous) then reverse[spec][name] = id end
        end
    end

    local function attribute(spec, entry)
        add(spec, entry.spellID)

        -- The base of an active override is the same book entry: a rotation
        -- saved against either identity stays valid in the spellbook view.
        if entry.baseSpellID and entry.baseSpellID ~= entry.spellID and catalog:UpdateSpell(entry.baseSpellID) then
            add(spec, entry.baseSpellID)
        end
    end

    for _, bank in ipairs({ "player", "pet" }) do
        local state = snapshot[bank]

        if state.complete then
            for _, entry in ipairs(state.entries) do
                catalog:UpdateSpell(entry.spellID)

                -- Unknown passivity/offspec identity is not evidence that an
                -- entry can be used as an action for the selected spec.
                if entry.isPassive == false then
                    if bank == "pet" then
                        attribute(petKey, entry)
                    elseif entry.offSpecID then
                        attribute(entry.offSpecID, entry)
                    elseif not entry.isOffSpec then
                        if self.currentSpec ~= nil then attribute(self.currentSpec, entry) end

                        if
                            shared and (entry.shared or entry.lineSpecID ~= nil and not shared.set[entry.lineSpecID])
                        then
                            for _, spec in ipairs(shared.list) do
                                if spec ~= self.currentSpec then attribute(spec, entry) end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Replace rather than merge: old pets, lost spells and former offspecs
    -- must not survive a new snapshot, including a failed bank observation.
    self.specSpells, self.specSpellsReverse = spells, reverse

    self.spellBookStatus = {
        player = {
            complete = snapshot.player.complete,
            reason = snapshot.player.reason,
            coverage = snapshot.player.coverage,
            hasOtherItems = snapshot.player.hasOtherItems,
            skipped = snapshot.player.skipped,
            skipReason = snapshot.player.skipReason,
        },
        pet = {
            complete = snapshot.pet.complete,
            reason = snapshot.pet.reason,
            coverage = snapshot.pet.coverage,
            hasOtherItems = snapshot.pet.hasOtherItems,
            skipped = snapshot.pet.skipped,
            skipReason = snapshot.pet.skipReason,
        },
    }

    return self.spellBookStatus
end

-- Detached metadata snapshots support owned search without exposing the index.
function catalog:GetIndexedSpells()
    local result = {}

    for id, entry in pairs(entries) do
        result[#result + 1] = { id = id, name = entry.name, rank = entry.rank, icon = entry.icon, link = entry.link }
    end

    return result
end

-- BEGIN CPU ACTIVITY HANDOFF
-- Private capture-only cardinality; no metadata query or per-event bookkeeping.
do
    local raw, nextKey, kind, equal = rawget, next, type, rawequal
    local ownedUpdate = catalog.UpdateSpell

    local function count(map)
        local n, key = 0, nil

        repeat
            key = nextKey(map, key)
            if key ~= nil then n = n + 1 end
        until key == nil or n > 4096

        return { n = n > 4096 and 4096 or n, capped = n > 4096 }
    end

    local bind = raw(addon, 'BindCPUActivityDiagnostic')

    if kind(bind) == 'function' then
        bind(addon, 'spell', function()
            if
                not equal(raw(addon, 'SpellCatalog'), catalog) or not equal(raw(catalog, 'UpdateSpell'), ownedUpdate)
            then
                return
            end

            return { spellIDs = count(entries), spellNames = count(byName) }
        end)
    end
end
-- END CPU ACTIVITY HANDOFF
