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
        {family = "tbc", folder = "tbc", flavors = {"TBC"}},
        -- Forever's game type is "camelot", with "forever" listed as its alias.
        {family = "forever", folder = "forever", flavors = {"Camelot", "Forever"}},
        -- Not _Mainline: that family suffix also matches Forever.
        {family = "retail", folder = "retail", flavors = {"Standard"}},
        -- Mists of Pandaria Classic; its packs also declare minExpansion/maxExpansion 4.
        {family = "progression", folder = "mop", flavors = {"Mists"}},
    },
    classes = {
        DEATHKNIGHT = "DeathKnight", DEMONHUNTER = "DemonHunter", DRUID = "Druid",
        EVOKER = "Evoker", HUNTER = "Hunter", MAGE = "Mage", MONK = "Monk",
        PALADIN = "Paladin", PRIEST = "Priest", ROGUE = "Rogue", SHAMAN = "Shaman",
        WARLOCK = "Warlock", WARRIOR = "Warrior",
    },
}

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
local function bind(namespace)
    if type(namespace) ~= "table" or namespace == addon then return false end
    namespace.RegisterDefaultBlock = function(_, block) return addon:RegisterDefaultBlock(block) end
    namespace.RegisterDefaultRotation = function(_, envelope) return addon:RegisterDefaultRotation(envelope) end
    return true
end
_G.RotationMasterBuiltIns = {Bind = bind}

local function readable(platform, value)
    return platform and platform:CanReadValue(value) and (not canaccessvalue or canaccessvalue(value))
end

local attempted, outcome, outcomeReason
-- Loads this character's module once, before the rotation library builds its
-- catalog. Returns the module name (or nil) and why nothing loaded:
-- "no-module" (an unrecognised client), "no-loader" (not a game
-- client), "unknown-class", or the client's LoadAddOn reason (MISSING,
-- DISABLED, ...). A module that cannot load leaves Rotation Master working
-- with no Built Ins and says so once.
function addon:LoadBuiltInModule()
    if attempted then return outcome, outcomeReason end
    attempted = true
    local platform = self.Platform
    local family = platform and type(platform.GetClientFamily) == "function" and platform:GetClientFamily()
    -- Every known client loads its class module; the flavour TOC decides what
    -- (if anything) that edition runs. An unrecognised client loads nothing.
    if type(family) ~= "string" or family == "unknown" then outcomeReason = "no-module"; return nil, outcomeReason end
    local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
    if type(load) ~= "function" then outcomeReason = "no-loader"; return nil, outcomeReason end
    local token
    if type(UnitClass) == "function" then
        local ok, _, value = pcall(UnitClass, "player")
        if ok and readable(platform, value) and type(value) == "string" then token = value end
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
    if loaded then outcome = name; return name end
    outcomeReason = tostring(reason or "UNKNOWN_ERROR")
    -- Awaiting a Locales entry; rawget keeps AceLocale from reporting the key.
    local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
    local message = "Built In rotations are unavailable: the add-on %s did not load (%s)."
    self:info(rawget(L, message) or message, name or "RotationMaster_<Class>", outcomeReason)
    return nil, outcomeReason
end
