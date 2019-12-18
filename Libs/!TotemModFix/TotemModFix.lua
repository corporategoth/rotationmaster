local MAJOR_VERSION = "TotemModFix"
local MINOR_VERSION = 6

-- Don't load this if it's already been laded.
if _G.TotemModFix_MINOR_VERSION and MINOR_VERSION <= _G.TotemModFix_MINOR_VERSION then return end
_G.TotemModFix_MINOR_VERSION = MINOR_VERSION

-- Everything below this line is a workaround for CLASSIC ONLY.
if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then return end
-- if select(2, UnitClass("player")) ~= "SHAMAN" then return end

local TotemItems = {
    [EARTH_TOTEM_SLOT] = 5175,
    [FIRE_TOTEM_SLOT] = 5176,
    [WATER_TOTEM_SLOT] = 5177,
    [AIR_TOTEM_SLOT] = 5178,
}

local ranks = {
    [string.format(TRADESKILL_RANK_HEADER, 1)] = "I",
    [string.format(TRADESKILL_RANK_HEADER, 2)] = "II",
    [string.format(TRADESKILL_RANK_HEADER, 3)] = "III",
    [string.format(TRADESKILL_RANK_HEADER, 4)] = "IV",
    [string.format(TRADESKILL_RANK_HEADER, 5)] = "V",
    [string.format(TRADESKILL_RANK_HEADER, 6)] = "VI",
}

local TotemSpells = {
    Tremor = {
        element = EARTH_TOTEM_SLOT,
        spellids = { 8143, },
        duration = 120,
    },
    Stoneskin = {
        element = EARTH_TOTEM_SLOT,
        spellids = { 8071, 8154, 8155, 10406, 10407, 10408, },
        duration = 120,
    },
    Stoneclaw = {
        element = EARTH_TOTEM_SLOT,
        spellids = { 5730, 6390, 6391, 6392, 10427, 10428 },
        duration = 15,
    },
    StrengthOfEarth = {
        element = EARTH_TOTEM_SLOT,
        spellids = { 8075, 8160, 8161, 10442, },
        duration = 120,
    },
    EarthBind = {
        element = EARTH_TOTEM_SLOT,
        spellids = { 2484, },
        duration = 45,
    },

    Searing = {
        element = FIRE_TOTEM_SLOT,
        spellids = { 3599, 6363, 6364, 6365, 10437, 10438, },
        duration = { 30, 35, 40, 45, 50, 55, },
    },
    FireNova = {
        element = FIRE_TOTEM_SLOT,
        spellids = { 1535, 8498, 8499, 11314, 11315 },
        duration = 4,
    },
    Magma = {
        element = FIRE_TOTEM_SLOT,
        spellids = { 8190, 10585, 10586, 10587 },
        duration = 20,
    },
    FrostResistance = {
        element = FIRE_TOTEM_SLOT,
        spellids = { 8181, 10478, 10479, },
        duration = 120,
    },
    Flametongue = {
        element = FIRE_TOTEM_SLOT,
        spellids = { 8227, 8249, 10526, 16387, },
        duration = 120,
    },

    HealingStream = {
        element = WATER_TOTEM_SLOT,
        spellids = { 5394, 6375, 6377, 10462, 10463, },
        duration = 60,
    },
    ManaTide = {
        element = WATER_TOTEM_SLOT,
        spellids = { 16190, 17354, 17359, },
        duration = 12,
    },
    PoisonCleansing = {
        element = WATER_TOTEM_SLOT,
        spellids = { 8166, },
        duration = 120,
    },
    DiseaseCleansing = {
        element = WATER_TOTEM_SLOT,
        spellids = { 8170, },
        duration = 120,
    },
    ManaSpring = {
        element = WATER_TOTEM_SLOT,
        spellids = { 5675, 10495, 10496, 10497, },
        duration = 60,
    },
    FireResistance = {
        element = WATER_TOTEM_SLOT,
        spellids = { 8184, 10537, 10538, },
        duration = 120,
    },

    Grounding = {
        element = AIR_TOTEM_SLOT,
        spellids = { 8177, },
        duration = 45,
    },
    NatureResistance = {
        element = AIR_TOTEM_SLOT,
        spellids = { 10595, 10600, 10601, },
        duration = 120,
    },
    Windfury = {
        element = AIR_TOTEM_SLOT,
        spellids = { 8512, 10613, 10614, },
        duration = 120,
    },
    Sentry = {
        element = AIR_TOTEM_SLOT,
        spellids = { 6495, },
        duration = 600,
    },
    Windwall = {
        element = AIR_TOTEM_SLOT,
        spellids = { 15107, 15111, 15112, },
        duration = 120,
    },
    GraceOfAir = {
        element = AIR_TOTEM_SLOT,
        spellids = { 8835, 10627, },
        duration = 120,
    },
    TranquilAir = {
        element = AIR_TOTEM_SLOT,
        spellids = { 25908, },
        duration = 120,
    },
}

local SpellIDToTotem = {}
local ActiveTotems = {}
local EventFrame

for name,val in pairs(TotemSpells) do
    for _, x in pairs(val.spellids) do
        SpellIDToTotem[x] = name
    end
end

local UNIT_SPELLCAST_SUCCEEDED = function(event, unit, castguid, id)
    local totem = SpellIDToTotem[id]
    if totem then
        ActiveTotems[TotemSpells[totem].element] = {
            spellid = id,
            duration = 0,
            cast = GetTime(),
            acknowledged = false,
        }
        if type(TotemSpells[totem].duration) == "table" then
            for idx,spellid in ipairs(TotemSpells[totem].spellids) do
                if spellid == id then
                    ActiveTotems[TotemSpells[totem].element].duration = TotemSpells[totem].duration[idx]
                    break
                end
            end
        else
            ActiveTotems[TotemSpells[totem].element].duration = TotemSpells[totem].duration
        end
    end
end

local PLAYER_TOTEM_UPDATE = function(event, elem)
    if ActiveTotems[elem] then
        if not ActiveTotems[elem].acknowledged then
            ActiveTotems[elem].acknowledged = true
        else
            ActiveTotems[elem] = nil
        end
    end
end

function FakeGetTotemInfo(elem)
    local name
    if ActiveTotems[elem] then
        local spell, rank = GetSpellBookItemName(FindSpellBookSlotBySpellID(ActiveTotems[elem].spellid, false), BOOKTYPE_SPELL)
        name = spell
        if rank and rank ~= "" then
            name = name .. " " .. ranks[rank]
        end
    end

    return (GetItemCount(TotemItems[elem]) > 0),
           (ActiveTotems[elem] and name or ""),
           (ActiveTotems[elem] and ActiveTotems[elem].cast or 0),
           (ActiveTotems[elem] and ActiveTotems[elem].duration or 0),
           (ActiveTotems[elem] and GetSpellTexture(ActiveTotems[elem].spellid) or nil)
end

if type(GetTotemInfo) ~= "function" then
    GetTotemInfo = FakeGetTotemInfo
    if not EventFrame then
        EventFrame = CreateFrame("frame")
    end
end

function FakeGetTotemTimeLeft(elem)
    return (ActiveTotems[elem] and max((ActiveTotems[elem].duration - (GetTime() - ActiveTotems[elem].cast)), 0) or 0)
end

if type(GetTotemTimeLeft) ~= "function" then
    GetTotemTimeLeft = FakeGetTotemTimeLeft
    if not EventFrame then
        EventFrame = CreateFrame("frame")
    end
end

if EventFrame then
    EventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    EventFrame:RegisterEvent("PLAYER_TOTEM_UPDATE")
    EventFrame:SetScript("OnEvent", function(self, event, ...)
            if event == "UNIT_SPELLCAST_SUCCEEDED" then
                    UNIT_SPELLCAST_SUCCEEDED(event, ...)
            elseif event == "PLAYER_TOTEM_UPDATE" then
                    PLAYER_TOTEM_UPDATE(event, ...)
            end
    end)
end

