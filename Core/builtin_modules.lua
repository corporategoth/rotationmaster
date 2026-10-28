-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Names the load-on-demand Built In rotation modules and loads the current character's class module.
-- It owns the edition/class tables (also read by tools/builtin_modules.lua), the RotationMasterBuiltIns.Bind global the
-- modules' bind.lua calls, and the one-shot module load; it never reads rotation data itself. Class and client family
-- come through addon.Platform and are checked with CanReadValue. Loaded from RotationMaster.toc right after
-- Core/rotation_library.lua; main.lua calls LoadBuiltInModule at startup, just before the rotation library builds its
-- catalog.

local addon_name, addon = ...

-- Packaged Built In rotations ship as load-on-demand addons, one per class
-- (Modules/RotationMaster_<Class>, see Modules/README.md). Each module holds
-- one folder per edition and one client-flavour TOC per edition that lists
-- only that folder, so the client itself runs only its own edition's files;
-- the unsuffixed fallback TOC loads nothing. Startup loads only this
-- character's class module. The release zip carries every module as its own
-- top-level AddOns folder (.pkgmeta move-folders).
-- Offline tools read this table (tools/builtin_modules.lua): the classes name
-- the module folders; each edition names its folder and the TOC flavour
-- suffixes that load it (Warcraft Wiki "TOC format": the client prefers its
-- game type's suffix, then its family's, then the unsuffixed TOC).
addon.BuiltInModules = {
    editions = {
        -- Classic Era 1.15: also Season of Discovery, Hardcore and Self-Found realms.
        { family = "era", folder = "era", flavors = { "Vanilla" } },
        { family = "tbc", folder = "tbc", flavors = { "TBC" } },
        -- Forever's game type is "camelot", with "forever" listed as its alias.
        { family = "forever", folder = "forever", flavors = { "Camelot", "Forever" } },
        -- Not _Mainline: that family suffix also matches Forever.
        { family = "retail", folder = "retail", flavors = { "Standard" } },
        -- Mists of Pandaria Classic; its packs also declare minExpansion/maxExpansion 4.
        { family = "progression", folder = "mop", flavors = { "Mists" } },
    },
    classes = {
        DEATHKNIGHT = "DeathKnight",
        DEMONHUNTER = "DemonHunter",
        DRUID = "Druid",
        EVOKER = "Evoker",
        HUNTER = "Hunter",
        MAGE = "Mage",
        MONK = "Monk",
        PALADIN = "Paladin",
        PRIEST = "Priest",
        ROGUE = "Rogue",
        SHAMAN = "Shaman",
        WARLOCK = "Warlock",
        WARRIOR = "Warrior",
    },
}

-- Returns the load-on-demand module addon name for a class token (for example "RotationMaster_Mage"), or nil for an
-- unknown class or a non-string.
function addon:GetBuiltInModuleName(class)
    local className = type(class) == "string" and addon.BuiltInModules.classes[class]
    return className and "RotationMaster_" .. className or nil
end

-- A load-on-demand addon's files receive its own name and a fresh private
-- namespace, not this addon's. Each module's first file (bind.lua) passes that
-- namespace here; it gains exactly the two registration methods packs call,
-- forwarded to this addon, so pack sources stay `local _,addon=...` unchanged.
-- The global has a fixed name because the main addon's own global follows
-- its folder name, which an install may spell in any case.
-- Gives a module's private namespace the two registration methods packs call. Returns true when the namespace was
-- bound, false for a non-table or for this addon's own namespace (which already has them).
local function bind(namespace)
    if type(namespace) ~= "table" or namespace == addon then
        return false
    end

    namespace.RegisterDefaultBlock = function(_, block) return addon:RegisterDefaultBlock(block) end
    namespace.RegisterDefaultRotation = function(_, envelope) return addon:RegisterDefaultRotation(envelope) end
    return true
end

_G.RotationMasterBuiltIns = { Bind = bind }

-- True when a value from the client may be inspected: platform:CanReadValue allows it and, where the client has
-- canaccessvalue, that agrees. Guards the class token read from UnitClass.
local function readable(platform, value)
    return platform and platform:CanReadValue(value) and (not canaccessvalue or canaccessvalue(value))
end

-- Memo of the one load attempt: whether it ran, the module name that loaded, and the reason nothing loaded.
local attempted, outcome, outcomeReason

-- Loads this character's module once, before the rotation library builds its
-- catalog. Returns the module name (or nil) and why nothing loaded:
-- "no-module" (an unrecognised client), "no-loader" (not a game
-- client), "unknown-class", or the client's LoadAddOn reason (MISSING,
-- DISABLED, ...). A module that cannot load leaves Rotation Master working
-- with no Built Ins and says so once.
function addon:LoadBuiltInModule()
    if attempted then
        return outcome, outcomeReason
    end

    attempted = true
    local platform = self.Platform
    local family = platform and type(platform.GetClientFamily) == "function" and platform:GetClientFamily()

    -- Every known client loads its class module; the flavour TOC decides what
    -- (if anything) that edition runs. An unrecognised client loads nothing.
    if type(family) ~= "string" or family == "unknown" then
        outcomeReason = "no-module"
        return nil, outcomeReason
    end

    local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn

    if type(load) ~= "function" then
        outcomeReason = "no-loader"
        return nil, outcomeReason
    end

    local token

    if type(UnitClass) == "function" then
        local ok, _, value = pcall(UnitClass, "player")

        if ok and readable(platform, value) and type(value) == "string" then
            token = value
        end
    end

    local name = self:GetBuiltInModuleName(token)
    local loaded, reason

    if name then
        local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
        loaded = type(isLoaded) == "function" and isLoaded(name) or false

        if not loaded then
            local ok, result, why = pcall(load, name)
            loaded, reason = ok and result and true or false, ok and why or "UNKNOWN_ERROR"
        end
    else
        reason = "unknown-class"
    end

    if loaded then
        outcome = name
        return name
    end

    outcomeReason = tostring(reason or "UNKNOWN_ERROR")
    -- Awaiting a Locales entry; rawget keeps AceLocale from reporting the key.
    local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
    local message = "Built In rotations are unavailable: the add-on %s did not load (%s)."
    self:info(rawget(L, message) or message, name or "RotationMaster_<Class>", outcomeReason)
    return nil, outcomeReason
end
