-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform side of the Set Mark step: the fixed whitelist of units a mark can be placed on, the pseudo spell id a Set
-- Mark step stands for (so the bar index, the glow and the preview can treat it like a spell), the one macro line each
-- (unit, mark) pair runs ("/tm [@unit] N"), how a macro on an action bar is recognized as that pair, whether placing the
-- mark is advisable now, and the macro calls the Bind button needs. Rotation Master only RECOMMENDS: nothing here sets
-- a mark; the player presses the button (Core/raid_mark_buttons.lua builds it). Every piece of text that can reach a
-- secure button is produced by looking a saved value up in the whitelists below and never by copying it, so no saved or
-- imported value can add to the macro. Loaded from RotationMaster.toc after Platform/raid_marks.lua.
local _, addon = ...
local platform = addon.Platform

-- Game names are read through this table, not as globals: they are probes, and a client that lacks one must read as
-- "no" (see Platform/raid_marks.lua).
local env = getfenv and getfenv(1) or _G

-- ============================================================================
-- The whitelists
-- ============================================================================

-- The units a mark can be placed on, in the order the editor lists them. Each is a token the macro conditional
-- "[@unit]" accepts. The value is the only text that ever reaches a macro; a saved unit is looked up here, never used.
local ACTION_UNITS = { 'player', 'target', 'focus', 'mouseover', 'pet', 'targettarget', 'focustarget' }
local UNIT_ORDINAL = {}

for ordinal, token in ipairs(ACTION_UNITS) do
    UNIT_ORDINAL[token] = ordinal
end

-- Short ASCII codes of the units, for macro names (a macro name holds sixteen characters).
local UNIT_CODE = {
    player = 'me',
    target = 'tgt',
    focus = 'foc',
    mouseover = 'mo',
    pet = 'pet',
    targettarget = 'tt',
    focustarget = 'ft',
}

-- The units that exist only where the client has a focus target.
local FOCUS_UNITS = { focus = true, focustarget = true }

-- What a step's action can say: a mark's name, or none to clear the mark.
local NONE = 'none'
local MARK_NUMBER = { [NONE] = 0 }

for key, index in pairs(platform.RaidMarks.index) do
    MARK_NUMBER[key] = index
end

-- The key of each mark number 0 to 8, none first.
local MARK_KEY = { [0] = NONE }

for index, key in ipairs(platform.RaidMarks.keys) do
    MARK_KEY[index] = key
end

-- The one macro line a button runs: place mark N on unit U, N = 0 clears it. The unit and the number are the only
-- parts that vary, both taken from the whitelists above.
local MACRO_TEMPLATE = '/tm [@%s] %d'

-- The pseudo spell id of a (unit, mark) pair: far above every real spell id, so no spell is ever mistaken for one.
local ACTION_BASE = 1073741824
local ACTION_SPAN = 16

-- The button name of each (unit, mark) pair, and the pair behind each name; both built once from the whitelists.
local BUTTON_NAME, NAME_ID = {}, {}

for ordinal, token in ipairs(ACTION_UNITS) do
    for mark = 0, 8 do
        local id = ACTION_BASE + ordinal * ACTION_SPAN + mark
        local name = 'RM_Mark_' .. token .. '_' .. MARK_KEY[mark]
        BUTTON_NAME[id] = name
        NAME_ID[name] = id
    end
end

-- Static data for the files that build the editor and the buttons. units lists the whitelisted tokens, marks maps a
-- step's action word to its number (none is 0). Read only.
platform.RaidMarkActions = { units = ACTION_UNITS, marks = MARK_NUMBER, none = NONE }

-- ============================================================================
-- Identity
-- ============================================================================

-- Builds the pseudo spell id of a (unit, mark) pair.
-- Arguments:
--   unit (string): one of the whitelisted unit tokens.
--   mark (number): 0 to clear the mark, 1 (star) to 8 (skull).
-- Returns:
--   id (number|nil): the pseudo spell id; nil when either argument is not on the whitelist.
function platform:GetMarkActionId(unit, mark)
    local ordinal = type(unit) == 'string' and UNIT_ORDINAL[unit]

    if not ordinal or type(mark) ~= 'number' or mark < 0 or mark > 8 or mark % 1 ~= 0 then
        return nil
    end

    return ACTION_BASE + ordinal * ACTION_SPAN + mark
end

-- Splits a pseudo spell id back into its unit and mark.
-- Arguments:
--   id (number): any number; a real spell id answers nil.
-- Returns:
--   unit (string|nil): the whitelisted unit token.
--   mark (number|nil): 0 to 8.
function platform:DecodeMarkActionId(id)
    if type(id) ~= 'number' or id < ACTION_BASE or id % 1 ~= 0 then
        return nil
    end

    local offset = id - ACTION_BASE
    local unit = ACTION_UNITS[(offset - offset % ACTION_SPAN) / ACTION_SPAN]
    local mark = offset % ACTION_SPAN

    if not unit or mark > 8 then
        return nil
    end

    return unit, mark
end

-- Tells whether a number is the pseudo spell id of a Set Mark step.
-- Arguments:
--   id (any): a value from the bar index or a step.
-- Returns:
--   isMark (boolean): true when id decodes to a (unit, mark) pair.
function platform:IsMarkActionId(id)
    return self:DecodeMarkActionId(id) ~= nil
end

-- Tells whether a unit can be offered for a Set Mark step on this client.
-- Arguments:
--   unit (any): a saved unit field.
-- Returns:
--   offered (boolean): true when unit is on the whitelist and the client has it (focus needs a focus target).
function platform:IsMarkActionUnit(unit)
    if type(unit) ~= 'string' or not UNIT_ORDINAL[unit] then
        return false
    end
    if FOCUS_UNITS[unit] and self.IsFocusUnitSupported and self:IsFocusUnitSupported() == false then
        return false
    end

    return true
end

-- Lists the units the editor offers for a Set Mark step on this client. Allocates; not for the poll.
-- Returns:
--   units (table): whitelisted unit tokens in editor order.
function platform:GetMarkActionUnits()
    local units = {}

    for _, token in ipairs(ACTION_UNITS) do
        if self:IsMarkActionUnit(token) then
            units[#units + 1] = token
        end
    end

    return units
end

-- Turns a saved Set Mark step into its pseudo spell id.
-- Arguments:
--   step (table): a rotation step; step.unit is a unit token and step.action a mark name or none.
-- Returns:
--   id (number|nil): the pseudo spell id.
--   reason (string|nil): 'invalid-mark-step' when either field is not on the whitelist, 'unsupported-unit' when the
--     unit is not available on this client.
function platform:GetMarkStepActionId(step)
    if type(step) ~= 'table' then
        return nil, 'invalid-mark-step'
    end

    local unit, action = step.unit, step.action
    local mark = type(action) == 'string' and MARK_NUMBER[action]
    local ordinal = type(unit) == 'string' and UNIT_ORDINAL[unit]

    if mark == false or mark == nil or not ordinal then
        return nil, 'invalid-mark-step'
    end
    if not self:IsMarkActionUnit(unit) then
        return nil, 'unsupported-unit'
    end

    return ACTION_BASE + ordinal * ACTION_SPAN + mark
end

-- Gives the localized name of a mark.
-- Arguments:
--   mark (number): 0 for none, 1 (star) to 8 (skull).
-- Returns:
--   name (string|nil): the game's own name (RAID_TARGET_N), else the English name; nil outside 0 to 8.
function platform:GetRaidMarkName(mark)
    if type(mark) ~= 'number' or mark < 0 or mark > 8 or mark % 1 ~= 0 then
        return nil
    end

    if mark == 0 then
        local label = env.NONE
        return type(label) == 'string' and label or 'None'
    end

    local label = env['RAID_TARGET_' .. mark]

    if type(label) == 'string' and label ~= '' then
        return label
    end

    local key = MARK_KEY[mark]
    return key:sub(1, 1):upper() .. key:sub(2)
end

-- Gives the texture of a mark.
-- Arguments:
--   mark (number): 0 for none, 1 (star) to 8 (skull).
-- Returns:
--   texture (string): the game's raid target icon, or the generic question mark for none and out-of-range numbers.
function platform:GetRaidMarkTexture(mark)
    if type(mark) == 'number' and mark >= 1 and mark <= 8 and mark % 1 == 0 then
        return 'Interface\\TargetingFrame\\UI-RaidTargetingIcon_' .. mark
    end

    return 'Interface\\Icons\\INV_Misc_QuestionMark'
end

-- Describes a pseudo spell id the way GetSpellInfo describes a spell, so the preview window and reports can name it.
-- Arguments:
--   id (any): a number; a real spell id answers nil.
-- Returns:
--   info (table|nil): { name, iconID, mark, unit } for a Set Mark id (name is the mark's name), nil otherwise.
function platform:GetMarkActionInfo(id)
    local unit, mark = self:DecodeMarkActionId(id)

    if not unit then
        return nil
    end

    return { name = self:GetRaidMarkName(mark), iconID = self:GetRaidMarkTexture(mark), mark = mark, unit = unit }
end

-- ============================================================================
-- The macro
-- ============================================================================

-- Gives the macro line that places a mark; the only text a Set Mark button ever runs.
-- Arguments:
--   unit (string): one of the whitelisted unit tokens.
--   mark (number): 0 to clear the mark, 1 to 8.
-- Returns:
--   text (string|nil): "/tm [@unit] N"; nil when either argument is not on the whitelist.
function platform:GetMarkMacroText(unit, mark)
    local ordinal = type(unit) == 'string' and UNIT_ORDINAL[unit]

    if not ordinal or type(mark) ~= 'number' or mark < 0 or mark > 8 or mark % 1 ~= 0 then
        return nil
    end

    return string.format(MACRO_TEMPLATE, ACTION_UNITS[ordinal], mark)
end

-- Gives the global name of the hidden secure button for a pair.
-- Arguments:
--   unit (string): one of the whitelisted unit tokens.
--   mark (number): 0 to 8.
-- Returns:
--   name (string|nil): "RM_Mark_<unit>_<mark name>", for example RM_Mark_target_skull; nil when not on the whitelist.
function platform:GetMarkButtonName(unit, mark)
    local id = self:GetMarkActionId(unit, mark)
    return id and BUTTON_NAME[id] or nil
end

-- Gives the macro a player puts on an action bar to press the button.
-- Arguments:
--   unit (string): one of the whitelisted unit tokens.
--   mark (number): 0 to 8.
-- Returns:
--   name (string|nil): the macro name, at most sixteen ASCII characters, such as "RM skull/tgt".
--   body (string|nil): "/click RM_Mark_<unit>_<mark name>".
function platform:GetMarkBarMacro(unit, mark)
    local id = self:GetMarkActionId(unit, mark)

    if not id then
        return nil
    end

    return 'RM ' .. MARK_KEY[mark] .. '/' .. UNIT_CODE[unit], '/click ' .. BUTTON_NAME[id]
end

-- ============================================================================
-- Recognizing a macro on a bar
-- ============================================================================

-- Whether macros on the bars are looked at for Set Mark buttons. Off until a Set Mark step has been evaluated or bound,
-- so a player who never uses the step pays nothing for the macro reads.
local tracking = false

-- Turns the recognition of Set Mark macros on the bars on or off.
-- Arguments:
--   on (boolean): true once a Set Mark step is in use.
function platform:SetMarkActionTracking(on)
    tracking = on == true
end

-- Tells whether Set Mark macros on the bars are being recognized.
-- Returns:
--   on (boolean): the state last set.
function platform:IsMarkActionTracking()
    return tracking
end

-- Recognizes a macro whose body presses a Set Mark button.
-- Arguments:
--   macro (number|string): a macro index or name, as the bar reports it.
-- Returns:
--   id (number|nil): the pseudo spell id of the first "/click RM_Mark_..." line; nil when tracking is off, the macro
--     cannot be read or holds no such line.
--
-- The body is only compared with the whitelisted button names; it is never parsed further or run.
function platform:GetMarkMacroActionId(macro)
    if not tracking then
        return nil
    end

    local read = env.GetMacroBody

    if type(read) ~= 'function' then
        return nil
    end
    if not self:CanReadValue(macro) or (type(macro) ~= 'number' and type(macro) ~= 'string') then
        return nil
    end

    local ok, body = pcall(read, macro)

    if not ok or not self:CanReadValue(body) or type(body) ~= 'string' or #body > 4096 then
        return nil
    end

    -- Almost every macro is not one of ours: a plain find rejects it without building anything.
    if not body:find('RM_Mark_', 1, true) then
        return nil
    end

    for word in body:gmatch('/[Cc][Ll][Ii][Cc][Kk]%s+([%w_]+)') do
        local id = NAME_ID[word]

        if id then
            return id
        end
    end
end

-- ============================================================================
-- Support and readiness
-- ============================================================================

-- Tells why a Set Mark step cannot work on this client.
-- Returns:
--   reason (string|nil): nil when the client has the target marker command or SetRaidTarget; 'unsupported-policy' on
--     a client with no known data policy; 'missing-api' otherwise.
function platform:GetMarkActionSupport()
    local policy = self:GetCombatDataPolicy()

    if policy ~= 'probe' and policy ~= 'restricted' then
        return 'unsupported-policy'
    end
    if type(env.SetRaidTarget) == 'function' then
        return nil
    end

    local commands, slash = env.SecureCmdList, env.SlashCmdList

    if type(commands) == 'table' and commands.TARGET_MARKER ~= nil then
        return nil
    end
    if type(slash) == 'table' and slash.TARGET_MARKER ~= nil then
        return nil
    end

    return 'missing-api'
end

-- Calls a game function that answers a boolean; true, false, or nil when it is missing or unreadable.
local function ask(fn, ...)
    if type(fn) ~= 'function' then
        return nil
    end

    local ok, value = pcall(fn, ...)

    if not ok or not platform:CanReadValue(value) then
        return nil
    end
    if value == true or value == 1 then
        return true
    end
    if value == false or value == 0 or value == nil then
        return false
    end
end

-- Tells whether you may place raid marks now: anyone in a party or alone, only the leader and assistants in a raid.
-- Returns:
--   allowed (boolean|nil): true or false as the group rule says; nil when the client cannot say.
--   reason (string|nil): 'missing-api' or 'restricted-value' when allowed is nil.
function platform:CanSetRaidMark()
    local raid = ask(env.IsInRaid)

    if raid == nil then
        return nil, 'missing-api'
    end
    if not raid then
        return true
    end

    local leader = ask(env.UnitIsGroupLeader, 'player')

    if leader == true then
        return true
    end

    local assistant = ask(env.UnitIsGroupAssistant, 'player')

    if assistant == true then
        return true
    end
    if leader == nil or assistant == nil then
        return nil, 'missing-api'
    end

    return false
end

-- Tells whether a Set Mark step has something to do now: the unit exists, does not already carry the mark, and you may
-- place marks.
-- Arguments:
--   id (number): the pseudo spell id of the step.
-- Returns:
--   ready (boolean): true when the step may be recommended; false otherwise, and when the answer cannot be read.
--   reason (string|nil): why ready is false: 'invalid-mark-step', a support reason, 'no-unit', 'already-marked',
--     'no-mark-permission', or the reason a read failed.
--
-- The group rule is applied only when the client can answer it; a client that cannot is given the benefit of the doubt.
function platform:IsMarkActionReady(id)
    local unit, mark = self:DecodeMarkActionId(id)

    if not unit then
        return false, 'invalid-mark-step'
    end

    local unsupported = self:GetMarkActionSupport()

    if unsupported then
        return false, unsupported
    end
    if not self:IsMarkActionUnit(unit) then
        return false, 'unsupported-unit'
    end

    local exists, why = self:GetUnitPresenceObservation(unit)

    if exists == nil then
        return false, why
    end
    if not exists then
        return false, 'no-unit'
    end

    local current, reason = self:GetUnitRaidMark(unit)

    if current == nil then
        return false, reason
    end
    if current == mark then
        return false, 'already-marked'
    end

    local allowed = self:CanSetRaidMark()

    if allowed == false then
        return false, 'no-mark-permission'
    end

    return true
end

-- ============================================================================
-- Macros for the Bind button
-- ============================================================================

-- Finds the macro for a pair among the player's macros.
-- Arguments:
--   unit (string): one of the whitelisted unit tokens.
--   mark (number): 0 to 8.
-- Returns:
--   index (number|nil): the macro index; nil when there is none or the client cannot say.
--   reason (string|nil): 'invalid-mark-step' or 'missing-api' when index is nil for a reason other than absence.
function platform:FindMarkBarMacro(unit, mark)
    local name = self:GetMarkBarMacro(unit, mark)

    if not name then
        return nil, 'invalid-mark-step'
    end

    local find = env.GetMacroIndexByName

    if type(find) ~= 'function' then
        return nil, 'missing-api'
    end

    local ok, index = pcall(find, name)

    if ok and self:CanReadValue(index) and type(index) == 'number' and index > 0 then
        return index
    end
end

-- Makes the macro for a pair (a character macro) if it does not exist yet.
-- Arguments:
--   unit (string): one of the whitelisted unit tokens.
--   mark (number): 0 to 8.
-- Returns:
--   index (number|nil): the macro index.
--   reason (string|nil): 'invalid-mark-step', 'missing-api', 'api-error' or 'macros-full' when index is nil.
--
-- Out of combat only; the caller checks. The body is the click line built from the whitelist.
function platform:CreateMarkBarMacro(unit, mark)
    local name, body = self:GetMarkBarMacro(unit, mark)

    if not name then
        return nil, 'invalid-mark-step'
    end

    local existing, why = self:FindMarkBarMacro(unit, mark)

    if existing then
        return existing
    end

    -- A client that cannot look macros up by name cannot say whether this one exists: never make a second copy blind.
    if why then
        return nil, why
    end

    local create = env.CreateMacro

    if type(create) ~= 'function' then
        return nil, 'missing-api'
    end

    local ok, index = pcall(create, name, 'INV_Misc_QuestionMark', body, true)

    if not ok then
        return nil, 'api-error'
    end
    if type(index) ~= 'number' or index <= 0 then
        return nil, 'macros-full'
    end

    return index
end

-- Puts a macro on the cursor so the player can drop it on an action bar slot.
-- Arguments:
--   index (number): a macro index from FindMarkBarMacro or CreateMarkBarMacro.
-- Returns:
--   ok (boolean): whether the client accepted the call.
function platform:PickupMarkBarMacro(index)
    local pickup = env.PickupMacro

    if type(pickup) ~= 'function' or type(index) ~= 'number' then
        return false
    end

    return (pcall(pickup, index))
end
