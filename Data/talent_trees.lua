local addon_name,addon=...
local L=LibStub("AceLocale-3.0"):GetLocale(addon_name)
local platform=addon.Platform

-- Talent tree names, per client family and class, for the clients whose
-- talents are three trees per class (Classic Era and Season of Discovery, TBC
-- Anniversary, Wrath and Cataclysm Classic, Forever).
--
-- PRIMARY_TALENT_TREE, TALENT_TREE_POINTS and the Classic TALENT condition
-- save a tree as its number, its position in the talent window (1, 2 or 3).
-- That is what the game's talent calls take and what a rotation carries between
-- characters, so it stays the stored value. People never read it: every place
-- that shows a tree shows its name. In game the player's own class is named by
-- the game itself (platform:GetTalentTreeInfo, already in the client's
-- language). This table answers where the game cannot:
--   * a class the player is not playing (a rotation opened for another class);
--   * the player's own class while the talent data has not loaded yet, or when
--     the client withholds it.
-- The names below are English; each is read through the locale files as
-- L["TalentTree.<name>"], so the fallback speaks the client's language.
--
-- Each list is in the talent window's order, which is the stored number: the
-- first name is tree 1. tests/talent_trees.lua fails when a shipped Built In's
-- tree number names a different tree than the Built In itself says it is for.
-- tools/export_talent_trees.py writes Data/talent_trees.json from this table
-- for the website; the two must stay in step (tests/test_talent_trees.py).
local DATA={
    version=1,
    order="Position in the talent window, 1-based; this is the value the tree conditions save.",
    -- Listing order of the families (an array, so the export is stable).
    familyOrder={"era","tbc","wrath","cata","forever"},
    families={
        era={
            label="Classic Era and Season of Discovery",
            basis="Classic talent window order, the same on every Classic client; confirmed by the Built In Era and Season of Discovery premades.",
            classes={
                DRUID={"Balance","Feral Combat","Restoration"},
                HUNTER={"Beast Mastery","Marksmanship","Survival"},
                MAGE={"Arcane","Fire","Frost"},
                PALADIN={"Holy","Protection","Retribution"},
                PRIEST={"Discipline","Holy","Shadow"},
                ROGUE={"Assassination","Combat","Subtlety"},
                SHAMAN={"Elemental","Enhancement","Restoration"},
                WARLOCK={"Affliction","Demonology","Destruction"},
                WARRIOR={"Arms","Fury","Protection"},
            },
        },
        tbc={
            label="Burning Crusade Classic (TBC Anniversary)",
            basis="Classic talent window order, unchanged in The Burning Crusade; confirmed by the Built In TBC premades.",
            classes={
                DRUID={"Balance","Feral Combat","Restoration"},
                HUNTER={"Beast Mastery","Marksmanship","Survival"},
                MAGE={"Arcane","Fire","Frost"},
                PALADIN={"Holy","Protection","Retribution"},
                PRIEST={"Discipline","Holy","Shadow"},
                ROGUE={"Assassination","Combat","Subtlety"},
                SHAMAN={"Elemental","Enhancement","Restoration"},
                WARLOCK={"Affliction","Demonology","Destruction"},
                WARRIOR={"Arms","Fury","Protection"},
            },
        },
        wrath={
            label="Wrath of the Lich King Classic",
            basis="Classic talent window order, unchanged in Wrath of the Lich King, which adds the Death Knight. No Built In premades yet, so the order is the game's, not the premades'.",
            classes={
                DEATHKNIGHT={"Blood","Frost","Unholy"},
                DRUID={"Balance","Feral Combat","Restoration"},
                HUNTER={"Beast Mastery","Marksmanship","Survival"},
                MAGE={"Arcane","Fire","Frost"},
                PALADIN={"Holy","Protection","Retribution"},
                PRIEST={"Discipline","Holy","Shadow"},
                ROGUE={"Assassination","Combat","Subtlety"},
                SHAMAN={"Elemental","Enhancement","Restoration"},
                WARLOCK={"Affliction","Demonology","Destruction"},
                WARRIOR={"Arms","Fury","Protection"},
            },
        },
        cata={
            label="Cataclysm Classic",
            basis="Cataclysm keeps three trees per class in the Wrath order. No Built In premades yet, so the order is the game's, not the premades'.",
            classes={
                DEATHKNIGHT={"Blood","Frost","Unholy"},
                DRUID={"Balance","Feral Combat","Restoration"},
                HUNTER={"Beast Mastery","Marksmanship","Survival"},
                MAGE={"Arcane","Fire","Frost"},
                PALADIN={"Holy","Protection","Retribution"},
                PRIEST={"Discipline","Holy","Shadow"},
                ROGUE={"Assassination","Combat","Subtlety"},
                SHAMAN={"Elemental","Enhancement","Restoration"},
                WARLOCK={"Affliction","Demonology","Destruction"},
                WARRIOR={"Arms","Fury","Protection"},
            },
        },
        forever={
            label="WoW Forever",
            basis="Assumed to follow the classic talent window order (three trait node groups per class); the Built In Forever premades use it, but it has not been read from a Forever client. Verify in game. The classes are those the Built In Forever premades cover.",
            classes={
                DRUID={"Balance","Feral Combat","Restoration"},
                HUNTER={"Beast Mastery","Marksmanship","Survival"},
                MAGE={"Arcane","Fire","Frost"},
                PALADIN={"Holy","Protection","Retribution"},
                PRIEST={"Discipline","Holy","Shadow"},
                ROGUE={"Assassination","Combat","Subtlety"},
                SHAMAN={"Elemental","Enhancement","Restoration"},
                WARLOCK={"Affliction","Demonology","Destruction"},
                WARRIOR={"Arms","Fury","Protection"},
            },
        },
    },
}

local Trees={data=DATA}
addon.TalentTrees=Trees

local function readable(value)
    return platform and platform:CanReadValue(value) and (not canaccessvalue or canaccessvalue(value))
end

-- The family key this client's trees are named under, or nil on a client
-- whose talents are not three trees per class (Retail, Mists of Pandaria).
function Trees.Family()
    if not platform or type(platform.GetClientFamily)~="function" then return nil end
    local family=platform:GetClientFamily()
    if family=="era" or family=="tbc" or family=="forever" then return family end
    if family=="progression" then
        local expansion=LE_EXPANSION_LEVEL_CURRENT
        if not readable(expansion) then return nil end
        if expansion==2 then return "wrath" end
        if expansion==3 then return "cata" end
    end
    return nil
end

-- The player's class token, nil when it cannot be read.
function Trees.PlayerClass()
    if type(UnitClass)~="function" then return nil end
    local ok,_,class=pcall(UnitClass,"player")
    if not ok or not readable(class) or type(class)~="string" then return nil end
    if canaccessvalue and not canaccessvalue(class) then return nil end
    if class~="" then return class end
end

-- Whether `class` is the player's class (false when either cannot be read).
function Trees.IsPlayerClass(class)
    local player=Trees.PlayerClass()
    if type(class)~="string" or player==nil then return false end
    if canaccessvalue and not canaccessvalue(class) then return false end
    return class==player
end

-- The English tree names of one class in the talent window's order, in this
-- client's family (or the family named); nil where the table has none.
function Trees.Names(class,family)
    family=family or Trees.Family()
    local row=family and DATA.families[family]
    local names=row and type(class)=="string" and row.classes[class]
    return names or nil
end

-- A saved tree number as a name, nil when the table cannot name it.
function Trees.StaticName(tree,class,family)
    local names=Trees.Names(class,family)
    local key=names and type(tree)=="number" and names[tree]
    if key then return L["TalentTree."..key] end
end

-- The class whose trees an editor lists and a summary names: the class of the
-- rotation open in the Rotations editor (it may be one the player is not
-- playing: a Built In or saved rotation for another class), else the player's.
function Trees.ContextClass()
    local pane=addon.activeRotationEditor
    local workspace=type(pane)=="table" and pane.workspace
    local class=type(workspace)=="table" and type(workspace.RotationClass)=="function" and workspace:RotationClass()
    if type(class)=="string" and class~="" then return class end
    return Trees.PlayerClass()
end

-- The trees of `class` for a picker: {choices={[number]=name},order={number...},live=bool}.
-- A class that is the player's takes the game's own names while the game
-- answers (each missing one from the table); any other class, and a client
-- that does not answer yet, take the table. nil when neither can name a tree,
-- which is a client without three-tree talents.
function Trees.Choices(class,group)
    local family=Trees.Family()
    class=class or Trees.PlayerClass()
    local mine=Trees.IsPlayerClass(class)
    local names=family and Trees.Names(class,family)
    local live,count={},nil
    if mine and platform and type(platform.GetTalentTreeCount)=="function" then
        count=platform:GetTalentTreeCount()
        if type(count)~="number" then count=nil end
        for index=1,count or 0 do
            local info=platform:GetTalentTreeInfo(index,group)
            if info and type(info.name)=="string" and info.name~="" then live[index]=info.name end
        end
    end
    local total=math.max(count or 0,names and #names or 0)
    if total==0 then return nil end
    local choices,order,anyLive={},{},false
    for index=1,total do
        local name=live[index]
        if name then anyLive=true else name=Trees.StaticName(index,class,family) end
        if name then choices[index]=name;order[#order+1]=index end
    end
    if #order==0 then return nil end
    return {choices=choices,order=order,live=anyLive}
end

-- One tree's name for text: the game's for the player's class, else the table's.
-- nil when neither knows it (the caller words the gap, never a bare number).
function Trees.Name(tree,class,group)
    if type(tree)~="number" or tree%1~=0 or tree<1 or tree>16 then return nil end
    class=class or Trees.PlayerClass()
    if Trees.IsPlayerClass(class) and platform and type(platform.GetTalentTreeInfo)=="function" then
        local info=platform:GetTalentTreeInfo(tree,group)
        if info and type(info.name)=="string" and info.name~="" then return info.name end
    end
    return Trees.StaticName(tree,class)
end
