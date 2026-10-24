-- Rotation Master's display language: Automatic (the game's) or one chosen in
-- the configuration header, saved account-wide as RotationMasterDB.global.language.
--
-- Only the language in use is ever kept. Locales/enUS.lua is the AceLocale
-- default; each generated Locales/<xx>.lua hands its strings to
-- RegisterTranslation as a function, and only the selected one is run (written
-- over the English). The others are dropped unrun, so their strings can be
-- collected, as AceLocale did for languages other than the game's.
--
-- Many strings are read into tables while the files load (condition names,
-- option lists), so the language must be known before then. The TOC sets
-- LoadSavedVariablesFirst (11.1.5 and the Classic clients built after it), so
-- the saved choice is readable here. A client that ignores the directive loads
-- SavedVariables after the files: the game's language is applied while loading,
-- the others are held until FinishLanguageSelection (OnInitialize) reads the
-- choice, and a different choice is applied then. Text read while loading keeps
-- the game's language on such a client (languageSwitchedLate).
--
-- Setting GAME_LOCALE would change every Ace addon's language, so it is only read.
local addon_name,addon=...
local type,rawget,rawset,pairs,setmetatable=type,rawget,rawset,pairs,setmetatable

-- Languages are named in their own language and script, as game clients do.
local NAMES={enUS="English",deDE="Deutsch",esES="Español (España)",esMX="Español (Latinoamérica)",frFR="Français",itIT="Italiano",
    koKR="한국어",ptBR="Português (Brasil)",ruRU="Русский",zhCN="简体中文",zhTW="繁體中文"}
local ORDER={"enUS","deDE","esES","esMX","frFR","itIT","koKR","ptBR","ruRU","zhCN","zhTW"}
addon.languageNames,addon.languageOrder=NAMES,ORDER

-- The game's language, as AceLocale resolves it (GAME_LOCALE is an optional
-- override some players define; it is not a client global).
local client=rawget(_G,"GAME_LOCALE") or type(GetLocale)=="function" and GetLocale() or nil
if client=="enGB" then client="enUS" end

local function validChoice(value)
    if value=="auto" or NAMES[value] then return value end
    return "auto"
end
-- The locale whose strings a choice shows: Automatic shows the game's
-- language when Rotation Master has it, otherwise English.
local function resolve(choice)
    if choice=="auto" then return NAMES[client] and client or "enUS" end
    return choice
end
local function savedChoice()
    local saved=rawget(_G,"RotationMasterDB")
    local global=type(saved)=="table" and rawget(saved,"global")
    return validChoice(type(global)=="table" and rawget(global,"language") or nil)
end

-- SavedVariables already present means the client honoured LoadSavedVariablesFirst.
-- Absent means a client that loads them later, or no settings saved yet.
local decided=type(rawget(_G,"RotationMasterDB"))=="table"
local target=decided and resolve(savedChoice()) or resolve("auto")
local applied          -- the locale whose translation has been written, if any
local pending={}       -- undecided only: translations not applied, until the choice is read
local english          -- undecided only: the English each applied entry replaced
local switchedLate=false
local finished=false

local function apply(locale,translate,record)
    local L=LibStub("AceLocale-3.0"):GetLocale(addon_name,true)
    if not L then return end
    translate(setmetatable({},{__newindex=function(_,key,value)
        if record and record[key]==nil then record[key]=rawget(L,key) or false end
        rawset(L,key,value==true and key or value)
    end}))
    applied=locale
end

-- Called by each generated Locales/<xx>.lua with a function that writes its strings.
function addon.RegisterTranslation(locale,translate)
    if finished or type(translate)~="function" then return end
    if locale==target then
        if not decided then english={} end
        apply(locale,translate,english)
    elseif not decided then
        pending[locale]=translate
    end
end

-- Runs first in OnInitialize, when SavedVariables are certainly loaded.
function addon:FinishLanguageSelection()
    if finished then return end
    finished=true
    if not decided then
        local wanted=resolve(savedChoice())
        if wanted~=target then
            local L=LibStub("AceLocale-3.0"):GetLocale(addon_name,true)
            if L and english then for key,value in pairs(english) do rawset(L,key,value or nil) end end
            applied=nil;target=wanted;switchedLate=true
            if pending[wanted] then apply(wanted,pending[wanted]) end
        end
    end
    -- Nothing else will be applied: release every translation not in use.
    pending,english=nil,nil
    addon.RegisterTranslation=nil
end

-- choice: the saved preference ("auto" or a locale); shown: the locale that
-- choice shows; active: the locale whose strings are in use now (shown differs
-- until a reload); client: the game's language; automatic: what Automatic
-- shows; switchedLate: text read while loading kept the game's language.
function addon:GetLanguageState()
    local global=self.db and self.db.global
    local choice=validChoice(type(global)=="table" and global.language or nil)
    return {choice=choice,shown=resolve(choice),active=applied or "enUS",client=client,automatic=resolve("auto"),switchedLate=switchedLate}
end

-- Saves a choice. Returns true when a reload is needed to show it, false when
-- that language is already in use, or nil for an unknown choice.
function addon:SetLanguageChoice(choice)
    if choice~="auto" and not NAMES[choice] then return nil end
    local global=self.db and self.db.global
    if type(global)~="table" then return nil end
    global.language=choice
    return resolve(choice)~=(applied or "enUS")
end
