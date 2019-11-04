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
    pettarget = L["your pet's target's"],
    targettarget = L["your target's target's"],
    mouseovertarget = L["your mouseover target's target's"],
}
if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
    addon.unitsPossessive["focus"] = L["your focus target's"]
    addon.unitsPossessive["focustarget"] = L["your focus target's target's"]
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

addon.creatures = {
    BEAST = L["Beast"],
    DRAGONKIN = L["Dragonkin"],
    DEMON = L["Demon"],
    ELEMENTAL = L["Elemental"],
    GIANT = L["Giant"],
    UNDEAD = L["Undead"],
    HUMANOID = L["Humanoid"],
    CRITTER = L["Critter"],
    MECHANICAL = L["Mechanical"],
    OTHER = L["Not specified"],
    TOTEM = L["Totem"],
    NONCOMBAT_PET = L["Non-combat Pet"],
    GAS_CLUUD = L["Gas Cloud"],
}

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

addon.actions = {
    HEAL = L["healed"],
    DODGE = L["dodged"],
    BLOCK = L["blocked"],
    WOUND = L["hit"],
    WOUND_CRITICAL = L["critically hit"],
    WOUND_CRUSHING = L["hit with a crushing blow"],
    WOUND_GLANCING = L["hit with a glancing blow"],
    MISS = L["missed"],
    PARRY = L["parried"],
    RESIST = L["resisted"]
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

addon.forms = {
    WARRIOR = {
        2457, -- Battle Stance
        71, -- Defensive Stance
        2458, -- Berserker Stance
    },
    ROGUE = {
        1784 -- Stealth
    },
    SHAMAN = {
        2645 -- Ghost Wolf
    },
    DRUID = {
        5487, -- Bear Form
        1066, -- Aquatic Form
        499, -- Cat Form
        783, -- Travel Form
        24858, -- Moonkin Form
        775, -- Tree Form
    },
}
