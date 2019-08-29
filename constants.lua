local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

addon.setpoints = {
    CENTER = L["Center"],
    TOPLEFT = L["Top Left"],
    TOPRIGHT = L["Top Right"],
    BOTTOMLEFT = L["Bottom Left"],
    BOTTOMRIGHT = L["Bottom Right"],
    TOP = L["Top Center"],
    BOTTOM = L["Bottom Center"],
    LEFT = L["Left Center"],
    RIGHT = L["Right Center"],
}

addon.operators = {
    LESSTHAN = L["is less than"],
    LESSTHANOREQUALS = L["is less than or equal to"],
    GREATERTHAN = L["is greater than"],
    GREATERTHANOREQUALS = L["is greater than or equal to"],
    EQUALS = L["is equal to"],
    NOTEQUALS = L["is not equal to"],
    DIVISIBLE = L["is evenly divisible by"],
}

addon.units = {
    player = L["you"],
    pet = L["your pet"],
    target = L["your target"],
    mouseover = L["your mouseover target"],
    pettarget = L["your pet's target"],
    targettarget = L["your target's target"],
    mouseovertarget = L["your mouseover target's target"],
}

if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
    addon.units["focus"] = L["your focus target"]
    addon.units["focustarget"] = L["your focus target's target"]
end

addon.unitsPossessive = {
    player = L["your"],
    pet = L["your pet's"],
    target = L["your target's"],
    mouseover = L["your mouseover target's"],
    pettarget = L["your pet's target's target"],
    targettarget = L["your target's target's target"],
    mouseovertarget = L["your mouseover target's target's target"],
}
if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
    addon.unitsPossessive["focus"] = L["your focus target's"]
    addon.unitsPossessive["focustarget"] = L["your focus target's target's target"]
end

addon.classes = {
    WARRIOR = L["Warrior"],
    PALADIN = L["Paladin"],
    HUNTER = L["Hunter"],
    ROGUE = L["Rogue"],
    PRIEST = L["Priest"],
    SHAMAN = L["Shaman"],
    MAGE = L["Mage"],
    WARLOCK = L["Warlock"],
    DRUID = L["Druid"],
}
if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
    addon.classes["DEATHKNIGHT"] = L["Death Knight"]
    addon.classes["DEMONHUNTER"] = L["Demon Hunter"]
    addon.classes["MONK"] = L["Monk"]
end

addon.roles = {
    TANK = L["Tank"],
    DAMAGER = L["DPS"],
    HEALER = L["Healer"],
}

addon.debufftypes = {
    Magic = L["Magic"],
    Disease = L["Disease"],
    Poison = L["Poison"],
    Curse = L["Curse"],
    Enrage = L["Enrage"], -- Actually an empty string!
}

addon.zonepvp = {
    arena = L["Arena"],
    friendly = L["Controlled by your faction"],
    contested = L["Contested"],
    hostile = L["Controlled by opposing faction"],
    sanctuary = L["Sanctuary (no PVP)"],
    combat = L["Combat (auto-flagged)"],
}

addon.instances = {
    none = L["Outside"],
    pvp = L["Battleground"],
    arena = L["Arena"],
    party = L["Dungeon"],
    raid = L["Raid"],
    scenario = L["Scenario"],
}

addon.totems = {
    L["Fire"],
    L["Earth"],
    L["Water"],
    L["Air"],
}

addon.points = {
    DEATHKNIGHT = Enum.PowerType.Runes,
    WARLOCK = Enum.PowerType.SoulShards,
    MONK = Enum.PowerType.Chi,
    MAGE = Enum.PowerType.ArcaneCharges,
}

addon.threat = {
    L["no threat risk"],
    L["higher threat than tank"],
    L["tanking, at risk"],
    L["tanking, secure"],
}

addon.friendly_distance = {
    [5] = 37727,
    [8] = 34368,
    [10] = 32321,
    [15] = 34721,
    [20] = 21519,
    [25] = 31463,
    [30] = 34191,
    [35] = 18904,
    [40] = 34471,
    [45] = 32698,
    [60] = 32825,
    [80] = 35278,
}

addon.harmful_distance = {
    [5] = 37727,
    [8] = 34368,
    [10] = 32321,
    [15] = 33069,
    [20] = 10645,
    [25] = 31463,
    [30] = 34191,
    [35] = 18904,
    [40] = 28767,
    [45] = 32698,
    [60] = 32825,
    [80] = 35278,
}
