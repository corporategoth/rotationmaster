-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Static lookup tables the condition definitions and the UI share: translated labels for operators, units, creature
-- types and so on, plus class/spell id lists (forms, glyphs) and power types, all hung on the addon table.
-- Loaded from RotationMaster.toc after the locales and the Platform adapters (it asks Platform/focus_unit.lua and the
-- group unit adapter what this client supports), before utils.lua and every condition. It must stay data only: no
-- game-value reads, no events, no saved variables. Every user-facing label goes through L[] so it is translated.
-- Several tables are keyed by values saved in profiles (operators, units, tags), so keys must not be renamed.
local addon_name, addon = ...

-- ============================================================================
-- Labels, operators and history phrases
-- ============================================================================

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
addon.logoTexture = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Branding\\rotation-master-small.tga"
addon.logoArtworkTexture = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Branding\\rotation-master.tga"

addon.loglevels = {
    L["Quiet"],
    DEFAULT,
    L["Debug"],
    L["Verbose"],
}

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

-- Full translated negative predicates keep comparison grammar out of the UI.
addon.negatedOperators = {
    LESSTHAN = L["is not less than"],
    LESSTHANOREQUALS = L["is not less than or equal to"],
    GREATERTHAN = L["is not greater than"],
    GREATERTHANOREQUALS = L["is not greater than or equal to"],
    EQUALS = L["is not equal to"],
    NOTEQUALS = L["is equal to"],
    DIVISIBLE = L["is not evenly divisible by"],
}

-- History conditions say when something happened ("was cast fewer than 3 casts
-- ago"), so each operator has a whole phrase per unit of measure; NOT negates
-- the history template's own verb ("was not cast").
addon.historyCastsAgo = {
    LESSTHAN = L["fewer than %s casts ago"],
    LESSTHANOREQUALS = L["at most %s casts ago"],
    GREATERTHAN = L["more than %s casts ago"],
    GREATERTHANOREQUALS = L["at least %s casts ago"],
    EQUALS = L["exactly %s casts ago"],
    NOTEQUALS = L["other than %s casts ago"],
    DIVISIBLE = L["a multiple of %s casts ago"],
}

addon.historyActionsAgo = {
    LESSTHAN = L["fewer than %s actions ago"],
    LESSTHANOREQUALS = L["at most %s actions ago"],
    GREATERTHAN = L["more than %s actions ago"],
    GREATERTHANOREQUALS = L["at least %s actions ago"],
    EQUALS = L["exactly %s actions ago"],
    NOTEQUALS = L["other than %s actions ago"],
    DIVISIBLE = L["a multiple of %s actions ago"],
}

addon.historySecondsAgo = {
    LESSTHAN = L["less than %s seconds ago"],
    LESSTHANOREQUALS = L["at most %s seconds ago"],
    GREATERTHAN = L["more than %s seconds ago"],
    GREATERTHANOREQUALS = L["at least %s seconds ago"],
    EQUALS = L["exactly %s seconds ago"],
    NOTEQUALS = L["other than %s seconds ago"],
    DIVISIBLE = L["a multiple of %s seconds ago"],
}

-- ============================================================================
-- Units
-- ============================================================================

addon.units = {
    player = L["you"],
    pet = L["your pet"],
    target = L["your target"],
    mouseover = L["your mouseover target"],
    pettarget = L["your pet's target"],
    targettarget = L["your target's target"],
    mouseovertarget = L["your mouseover target's target"],
}

-- Focus and its target exist where the client has a focus system
-- (Platform/focus_unit.lua asks the client). Without a platform (a bare
-- fixture) the old per-project answer stands: everything but Classic Era.
local platform = addon.Platform
local hasFocus

if platform and platform.IsFocusUnitSupported then
    hasFocus = platform:IsFocusUnitSupported()
end
if hasFocus == nil then
    hasFocus = (WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC)
end

if hasFocus then
    addon.units["focus"] = L["your focus target"]
    addon.units["focustarget"] = L["your focus target's target"]
end

-- Group unit types have no token of their own: Core/group_unit_resolution.lua
-- swaps in the real token of whoever holds the assignment when a condition is
-- evaluated. Every kind is recognized (a saved one stays recognized on a client
-- that cannot resolve it); the picker offers the ones this client can.
addon.groupUnitKinds = {
    maintank = true,
    mainassist = true,
    assignedtank = true,
    assignedhealer = true,
    groupleader = true,
}

local groupUnitNames = {
    maintank = { L["your group's main tank"], L["your group's main tank's"] },
    mainassist = { L["your group's main assist"], L["your group's main assist's"] },
    assignedtank = { L["your group's assigned tank"], L["your group's assigned tank's"] },
    assignedhealer = { L["your group's assigned healer"], L["your group's assigned healer's"] },
    groupleader = { L["your group's leader"], L["your group's leader's"] },
}

local groupUnitOffered = {}

if platform and platform.GetGroupUnitSupport then
    for kind in pairs(groupUnitNames) do
        local ok, reason = pcall(platform.GetGroupUnitSupport, platform, kind)

        if ok and reason == nil then
            groupUnitOffered[kind] = true
            addon.units[kind] = groupUnitNames[kind][1]
        end
    end
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

if hasFocus then
    addon.unitsPossessive["focus"] = L["your focus target's"]
    addon.unitsPossessive["focustarget"] = L["your focus target's target's"]
end

for kind in pairs(groupUnitOffered) do
    addon.unitsPossessive[kind] = groupUnitNames[kind][2]
end

-- ============================================================================
-- Creatures, events, roles and other enumerations
-- ============================================================================

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
    -- The misspelling is a saved-data key: CREATURE conditions store it and Core/creature_conditions.lua maps it to
    -- creature type 13, so renaming it would orphan every saved Gas Cloud condition. Keep it as it is.
    GAS_CLUUD = L["Gas Cloud"],
}

addon.classifications = {
    worldboss = L["World Boss"],
    rareelite = L["Rare Elite"],
    elite = L["Elite"],
    rare = L["Rare"],
    normal = L["Normal"],
    trivial = L["Trivial"],
    minus = L["Minus"],
}

addon.events = {
    START = L["Started"],
    STOP = L["Stopped"],
    SUCCEEDED = L["Succeeded"],
    INTERRUPTED = L["Interrupted"],
    FAILED = L["Failed"],
    DELAYED = L["Delayed"],
}

addon.profession_levels = {
    APPRENTICE, JOURNEYMAN, EXPERT, ARTISAN, MASTER, GRAND_MASTER, ILLUSTRIOUS, ZEN_MASTER, DRAENOR_MASTER,
    LEGION_MASTER
}

addon.loc_types = {
    BANISH = LOSS_OF_CONTROL_DISPLAY_BANISH,
    CHARM = LOSS_OF_CONTROL_DISPLAY_CHARM,
    CONFUSE = LOSS_OF_CONTROL_DISPLAY_CONFUSE,
    CYCLONE = LOSS_OF_CONTROL_DISPLAY_CYCLONE,
    DAZE = LOSS_OF_CONTROL_DISPLAY_DAZE,
    DISARM = LOSS_OF_CONTROL_DISPLAY_DISARM,
    DISORIENT = LOSS_OF_CONTROL_DISPLAY_DISORIENT,
    DISTRACT = LOSS_OF_CONTROL_DISPLAY_DISTRACT,
    FEAR = LOSS_OF_CONTROL_DISPLAY_FEAR,
    FREEZE = LOSS_OF_CONTROL_DISPLAY_FREEZE,
    HORROR = LOSS_OF_CONTROL_DISPLAY_HORROR,
    INCAPACITATE = LOSS_OF_CONTROL_DISPLAY_INCAPACITATE,
    INTERRUPT = LOSS_OF_CONTROL_DISPLAY_INTERRUPT,
    INVULNERABILITY = LOSS_OF_CONTROL_DISPLAY_INVULNERABILITY,
    PACIFY = LOSS_OF_CONTROL_DISPLAY_PACIFY,
    PACIFYSILENCE = LOSS_OF_CONTROL_DISPLAY_PACIFYSILENCE,
    POLYMORPH = LOSS_OF_CONTROL_DISPLAY_POLYMORPH,
    POSSESS = LOSS_OF_CONTROL_DISPLAY_POSSESS,
    ROOT = LOSS_OF_CONTROL_DISPLAY_ROOT,
    SAP = LOSS_OF_CONTROL_DISPLAY_SAP,
    SCHOOL_INTERRUPT = LOSS_OF_CONTROL_DISPLAY_SCHOOL_INTERRUPT,
    SHACKLE_UNDEAD = LOSS_OF_CONTROL_DISPLAY_SHACKLE_UNDEAD,
    SILENCE = LOSS_OF_CONTROL_DISPLAY_SILENCE,
    SLEEP = LOSS_OF_CONTROL_DISPLAY_SLEEP,
    SNARE = LOSS_OF_CONTROL_DISPLAY_SNARE,
    STUN = LOSS_OF_CONTROL_DISPLAY_STUN,
    TAUNT = LOSS_OF_CONTROL_DISPLAY_TAUNT,
}

addon.loc_equivalent = {
    TURN_UNDEAD = "FEAR",
    STUN_MECHANIC = "STUN",
    FEAR_MECHANIC = "FEAR",
    MAGICAL_IMMUNITY = "PACIFY",
    INTERRUPT_SCHOOL = "INTERRUPT",
}

addon.roles = {
    TANK = L["Tank"],
    DAMAGER = L["DPS"],
    HEALER = L["Healer"],
}

addon.trendmode = {
    fields = { unit = "string", operator = "string", value = "number" },
    both = L["Damage and Heals"],
    noheals = L["Damage Only"],
    nodmg = L["Heals Only"],
}

addon.debufftypes = {
    Magic = L["Magic"],
    Disease = L["Disease"],
    Poison = L["Poison"],
    Curse = L["Curse"],
    Enrage = L["Enrage"],  -- Actually an empty string!
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

addon.spell_schools = {
    ar = L["Arcane"],
    fi = L["Fire"],
    fr = L["Frost"],
    ho = L["Holy"],
    na = L["Nature"],
    sh = L["Shadow"],
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
    RESIST = L["resisted"],
}

-- ============================================================================
-- Class resources, runes, threat and stats
-- ============================================================================

addon.points = {
    DEATHKNIGHT = Enum.PowerType.Runes,
    WARLOCK = Enum.PowerType.SoulShards,
    MONK = Enum.PowerType.Chi,
    MAGE = Enum.PowerType.ArcaneCharges,
}

-- Retail's other class resources (Rogue and Druid keep the Combo Points
-- fallback). Classic-family clients keep the map above unchanged; it serves
-- TBC, Forever and the archived V1 POINT API. Era and progression POINT select
-- per expansion and specialization instead (Core/point_conditions.lua).
if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
    addon.points.PALADIN = Enum.PowerType.HolyPower
    addon.points.EVOKER = Enum.PowerType.Essence
end

addon.runes = {
    L["Blood"],  -- 1
    L["Frost"],  -- 2
    L["Unholy"],  -- 3
    L["Death"],  -- 4
}

addon.threat = {
    L["no threat risk"],
    L["higher threat than tank"],
    L["tanking, at risk"],
    L["tanking, secure"],
}

-- What THREAT and THREAT_COUNT test at each level: the native threat status
-- (0 lower than the tank, 1 higher than the tank, 2 tanking insecurely, 3
-- tanking securely) is at least the level's own status, so level 1 is "on the
-- threat table at all". %s is the unit (possessive for level 1).
addon.threatPredicates = {
    L["you {{!are|are not}} on %s threat table"],
    L["you {{!have|do not have}} at least as much threat on %s as its tank"],
    L["you {{!are|are not}} tanking %s"],
    L["you {{!are|are not}} securely tanking %s"],
}

addon.threatCounts = {
    L["the number of enemies whose threat table you are on"],
    L["the number of enemies on which you have at least as much threat as their tank"],
    L["the number of enemies you are tanking"],
    L["the number of enemies you are securely tanking"],
}

addon.stats = {
    SPELL_STAT1_NAME,  -- 1
    SPELL_STAT2_NAME,  -- 2
    SPELL_STAT3_NAME,  -- 3
    SPELL_STAT4_NAME,  -- 4
    SPELL_STAT5_NAME,  -- 5
    ARMOR,  -- 6
}

-- ============================================================================
-- Shapeshift forms and math operations
-- ============================================================================

addon.forms = {
    WARRIOR = {
        2457,  -- Battle Stance
        71,  -- Defensive Stance
        2458,  -- Berserker Stance
    },
    ROGUE = {
        1784,  -- Stealth
    },
    SHAMAN = {
        2645,  -- Ghost Wolf
    },
    DRUID = {
        5487,  -- Bear Form
        1066,  -- Aquatic Form
        499,  -- Cat Form
        783,  -- Travel Form
        24858,  -- Moonkin Form
        775,  -- Tree Form
    },
}

addon.math_operations = {
    minimum = L["Minimum"],
    average = L["Average"],
    maximum = L["Maximum"],
}

-- The same operations inside a sentence ("the lowest health of ...").
addon.math_operations_prose = {
    minimum = L["lowest"],
    average = L["average"],
    maximum = L["highest"],
}

-- ============================================================================
-- Glyph item ids per class
-- ============================================================================

-- Retail has its own, shorter glyph list; every other client uses the Classic-family list in the else branch.
if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
    addon.glyphs = {
        WARRIOR = {104138, 141898, 43398, 80588, 43400, 85221, 80587, 49084, 137188},
        PALADIN = { 143588, 41100, 43366, 137293, 43369, 104108 },
        HUNTER = {43350, 170173, 137267, 137269, 139288, 137250, 137238, 137239, 137249},
        ROGUE = { 139358, 129020, 139442, 45768 },
        PRIEST = {153036, 77101, 87392, 153033, 129017, 153031, 149755, 104120, 43373, 104122, 79538, 87277},
        DEATHKNIGHT = {
            43535, 104099, 43551, 139271, 137274, 146979, 146981, 139270, 153659, 153649, 153651, 153652, 153653,
            153654, 153655, 153656, 153657, 153658, 153660
        },
        SHAMAN = {190378, 190380, 43386, 104127, 137287, 104126, 137289, 137288, 139289},
        MAGE = {139348, 170164, 166583, 170168, 170165, 166664, 104104, 172449, 167539, 139352, 129019, 104105, 42751},
        WARLOCK = {
            139311, 151542, 147119, 151540, 139315, 151538, 129018, 139310, 139312, 43394, 139314, 42459, 139313,
            137191, 189721, 45789
        },
        MONK = { 87885, 129022, 139339, 87881, 87888, 139338, 87883 },
        DRUID = {44922, 43334, 136825, 143750, 184100, 118061, 184096, 136826, 188164, 139278, 184097},
        DEMONHUNTER = {},
    }
else
    addon.glyphs = {
        WARRIOR = {
            43414, 43397, 43416, 43395, 43424, 43396, 43432, 43418, 43425, 43423, 43427, 45790, 43421, 45797, 43426,
            43399, 43429, 45793, 43428, 43420, 45792, 43422, 43400, 43417, 43419, 49084, 43415, 45794, 45795, 43412,
            43398, 43431, 43430, 43413
        },
        PALADIN = {
            43869, 41092, 41105, 41099, 41100, 41096, 41108, 43367, 41094, 41103, 43365, 43369, 43368, 45745, 45741,
            41109, 41098, 45742, 45743, 43340, 41104, 41095, 43867, 41107, 45747, 43366, 41110, 41097, 43868, 41101,
            45744, 45746, 41102
        },
        HUNTER = {
            45732, 42912, 43351, 43350, 42914, 45625, 43338, 42909, 42902, 45731, 45733, 43355, 42907, 42897, 42906,
            42911, 42913, 42915, 42916, 42917, 45734, 45735, 42899, 42460, 42903, 42904, 42905, 42910, 42908, 42901,
            43354, 43356, 42898, 42900
        },
        ROGUE = {
            42973, 45767, 45768, 42972, 42974, 42962, 43379, 45762, 43378, 43380, 42961, 45761, 45764, 45766, 43376,
            42959, 42970, 42956, 45769, 42969, 42971, 45908, 42957, 42967, 42968, 42958, 42965, 42955, 42963, 42964,
            43377, 42960, 42966, 43343
        },
        PRIEST = {
            43373, 42415, 43371, 42407, 43374, 45753, 43370, 42400, 42406, 42408, 42411, 45756, 43342, 42397, 42409,
            42401, 42396, 42402, 43372, 42398, 45755, 45760, 42399, 42404, 42414, 42403, 45757, 45758, 42405, 42417,
            42412, 42410, 42416
        },
        DEATHKNIGHT = {
            45805, 45804, 43542, 43549, 43546, 43673, 43535, 43672, 43533, 43825, 43827, 43547, 43554, 43544, 45803,
            43538, 45806, 43671, 43543, 45799, 43539, 43553, 43534, 43536, 43537, 43541, 43545, 43548, 43550, 43551,
            43552, 43826, 44432, 45800
        },
        SHAMAN = {
            41541, 45775, 41533, 41527, 41517, 41542, 41535, 41539, 45776, 41536, 45771, 43386, 41538, 41534, 43388,
            41530, 43385, 44923, 43725, 45772, 41524, 43384, 41532, 45778, 41540, 43383, 41531, 43344, 41529, 41552,
            45770, 45777, 41518, 43381, 41547, 41537, 41526
        },
        MAGE = {
            45737, 44955, 42751, 43339, 42735, 43364, 42737, 50045, 44684, 42739, 42734, 42738, 42736, 42744, 43361,
            43360, 42749, 42740, 42746, 43357, 43359, 42750, 42747, 45738, 42743, 42748, 42745, 44920, 42754, 45736,
            45739, 45740, 42753, 42741, 42752
        },
        WARLOCK = {
            50077, 42459, 42455, 42453, 42467, 45785, 43390, 43389, 42454, 42465, 45779, 43393, 42468, 42462, 42470,
            45781, 42464, 45780, 42458, 43394, 43391, 42471, 42469, 42472, 42473, 42457, 45782, 45783, 45789, 42463,
            42460, 42466, 42461, 42456
        },
        MONK = {},
        DRUID = {
            40901, 40908, 40484, 44928, 43337, 43336, 40921, 40923, 40922, 43335, 40919, 40897, 40913, 40902, 43331,
            50125, 43674, 45622, 40948, 43332, 40914, 40909, 45604, 44922, 40896, 40903, 45602, 43334, 40900, 48720,
            45601, 45603, 46372, 40899, 40920, 40906, 40915, 45623, 43316, 40912, 39584, 40924
        },
        DEMONHUNTER = {},
    }
end
