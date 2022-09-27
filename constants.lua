local _, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

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

addon.units = {
    player = L["you"],
    pet = L["your pet"],
    target = L["your target"],
    mouseover = L["your mouseover target"],
    pettarget = L["your pet's target"],
    targettarget = L["your target's target"],
    mouseovertarget = L["your mouseover target's target"],
}

if (WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC) then
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
-- Everything except classic has FOCUS
if (WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC) then
    addon.unitsPossessive["focus"] = L["your focus target's"]
    addon.unitsPossessive["focustarget"] = L["your focus target's target's"]
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
    APPRENTICE,
    JOURNEYMAN,
    EXPERT,
    ARTISAN,
    MASTER,
    GRAND_MASTER,
    ILLUSTRIOUS,
    ZEN_MASTER,
    DRAENOR_MASTER,
    LEGION_MASTER,
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
    both = L["Damage and Heals"],
    noheals = L["Damage Only"],
    nodmg = L["Heals Only"],
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
    RESIST = L["resisted"]
}

addon.points = {
    DEATHKNIGHT = Enum.PowerType.Runes,
    WARLOCK = Enum.PowerType.SoulShards,
    MONK = Enum.PowerType.Chi,
    MAGE = Enum.PowerType.ArcaneCharges,
}

addon.runes = {
    L["Blood"],  -- 1
    L["Frost"],  -- 2
    L["Unholy"], -- 3
    L["Death"]   -- 4
}

addon.threat = {
    L["no threat risk"],
    L["higher threat than tank"],
    L["tanking, at risk"],
    L["tanking, secure"],
}

addon.stats = {
    SPELL_STAT1_NAME, -- 1
    SPELL_STAT2_NAME, -- 2
    SPELL_STAT3_NAME, -- 3
    SPELL_STAT4_NAME, -- 4
    SPELL_STAT5_NAME, -- 5
    ARMOR             -- 6
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

addon.math_operations = {
    minimum = L["Minimum"],
    average = L["Average"],
    maximum = L["Maximum"],
}

if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
    addon.glyphs = {
        WARRIOR = { 104138, 141898, 43398, 80588, 43400, 85221, 80587, 49084, 137188 },
        PALADIN = { 143588, 41100, 43366, 137293, 43369, 104108 },
        HUNTER = { 43350, 170173, 137267, 137269, 139288, 137250, 137238, 137239, 137249 },
        ROGUE = { 139358, 129020, 139442, 45768 },
        PRIEST = { 153036, 77101, 87392, 153033, 129017, 153031, 149755, 104120, 43373, 104122, 79538, 87277 },
        DEATHKNIGHT = { 43535, 104099, 43551, 139271, 137274, 146979, 146981, 139270, 153659, 153649, 153651, 153652, 153653, 153654, 153655, 153656, 153657, 153658, 153660 },
        SHAMAN = { 190378, 190380, 43386, 104127, 137287, 104126, 137289, 137288, 139289 },
        MAGE = { 139348, 170164, 166583, 170168, 170165, 166664, 104104, 172449, 167539, 139352, 129019, 104105, 42751 },
        WARLOCK = { 139311, 151542, 147119, 151540, 139315, 151538, 129018, 139310, 139312, 43394, 139314, 42459, 139313, 137191, 189721, 45789 },
        MONK = { 87885, 129022, 139339, 87881, 87888, 139338, 87883 },
        DRUID = { 44922, 43334, 136825, 143750, 184100, 118061, 184096, 136826, 188164, 139278, 184097 },
        DEMONHUNTRER = {  },
    }
else
    addon.glyphs = {
        WARRIOR = { 43414, 43397, 43416, 43395, 43424, 43396, 43432, 43418, 43425, 43423, 43427, 45790, 43421, 45797, 43426, 43399, 43429, 45793, 43428, 43420, 45792, 43422, 43400, 43417, 43419, 49084, 43415, 45794, 45795, 43412, 43398, 43431, 43430, 43413 },
        PALADIN = { 43869, 41092, 41105, 41099, 41100, 41096, 41108, 43367, 41094, 41103, 43365, 43369, 43368, 45745, 45741, 41109, 41098, 45742, 45743, 43340, 41104, 41095, 43867, 41107, 45747, 43366, 41110, 41097, 43868, 41101, 45744, 45746, 41102 },
        HUNTER = { 45732, 42912, 43351, 43350, 42914, 45625, 43338, 42909, 42902, 45731, 45733, 43355, 42907, 42897, 42906, 42911, 42913, 42915, 42916, 42917, 45734, 45735, 42899, 42460, 42903, 42904, 42905, 42910, 42908, 42901, 43354, 43356, 42898, 42900 },
        ROGUE = { 42973, 45767, 45768, 42972, 42974, 42962, 43379, 45762, 43378, 43380, 42961, 45761, 45764, 45766, 43376, 42959, 42970, 42956, 45769, 42969, 42971, 45908, 42957, 42967, 42968, 42958, 42965, 42955, 42963, 42964, 43377, 42960, 42966, 43343 },
        PRIEST = { 43373, 42415, 43371, 42407, 43374, 45753, 43370, 42400, 42406, 42408, 42411, 45756, 43342, 42397, 42409, 42401, 42396, 42402, 43372, 42398, 45755, 45760, 42399, 42404, 42414, 42403, 45757, 45758, 42405, 42417, 42412, 42410, 42416 },
        DEATHKNIGHT = { 45805, 45804, 43542, 43549, 43546, 43673, 43535, 43672, 43533, 43825, 43827, 43547, 43554, 43544, 45803, 43538, 45806, 43671, 43543, 45799, 43539, 43553, 43534, 43536, 43537, 43541, 43545, 43548, 43550, 43551, 43552, 43826, 44432, 45800 },
        SHAMAN = { 41541, 45775, 41533, 41527, 41517, 41542, 41535, 41539, 45776, 41536, 45771, 43386, 41538, 41534, 43388, 41530, 43385, 44923, 43725, 45772, 41524, 43384, 41532, 45778, 41540, 43383, 41531, 43344, 41529, 41552, 45770, 45777, 41518, 43381, 41547, 41537, 41526 },
        MAGE = { 45737, 44955, 42751, 43339, 42735, 43364, 42737, 50045, 44684, 42739, 42734, 42738, 42736, 42744, 43361, 43360, 42749, 42740, 42746, 43357, 43359, 42750, 42747, 45738, 42743, 42748, 42745, 44920, 42754, 45736, 45739, 45740, 42753, 42741, 42752 },
        WARLOCK = { 50077, 42459, 42455, 42453, 42467, 45785, 43390, 43389, 42454, 42465, 45779, 43393, 42468, 42462, 42470, 45781, 42464, 45780, 42458, 43394, 43391, 42471, 42469, 42472, 42473, 42457, 45782, 45783, 45789, 42463, 42460, 42466, 42461, 42456 },
        MONK = {  },
        DRUID = { 40901, 40908, 40484, 44928, 43337, 43336, 40921, 40923, 40922, 43335, 40919, 40897, 40913, 40902, 43331, 50125, 43674, 45622, 40948, 43332, 40914, 40909, 45604, 44922, 40896, 40903, 45602, 43334, 40900, 48720, 45601, 45603, 46372, 40899, 40920, 40906, 40915, 45623, 43316, 40912, 39584, 40924 },
        DEMONHUNTRER = {  },
    }
end

