local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

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
    focus = L["your focus target"],
    mouseover = L["your mouseover target"],
    pettarget = L["your pet's target"],
    targettarget = L["your target's target"],
    focustarget = L["your focus target's target"],
    mouseovertarget = L["your mouseover target's target"],
}

addon.unitsPossessive = {
    player = L["your"],
    pet = L["your pet's"],
    target = L["your target's"],
    focus = L["your focus target's"],
    mouseover = L["your mouseover target's"],
    pettarget = L["your pet's target's target"],
    targettarget = L["your target's target's target"],
    focustarget = L["your focus target's target's target"],
    mouseovertarget = L["your mouseover target's target's target"],
}

addon.classes = {
    WARRIOR = L["Warrior"],
    PALADIN = L["Paladin"],
    HUNDER = L["Hunter"],
    ROGUE = L["Rogue"],
    PRIEST = L["Priest"],
    DEATHKNIGHT = L["Death Knight"],
    SHAMAN = L["Shaman"],
    MAGE = L["Mage"],
    WARLOCK = L["Warlock"],
    MONK = L["Monk"],
    DRUID = L["Druid"],
    DEMONHUNTER = L["Demon Hunter"],
}

addon.roles = {
    TANK = L["Tank"],
    DAMAGER = L["DPS"],
    HEALER = L["Healer"],
}

addon.debufftypes = {
    MAGIC = L["Magic"],
    DISEASE = L["Disease"],
    POISON = L["Poison"],
    CURSE = L["Curse"],
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