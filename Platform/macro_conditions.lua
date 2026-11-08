-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for macro conditionals ("[combat,harm]", "[stance:1]", "[@focus,exists]"): the game evaluates them
-- (SecureCmdOptionParse) and hands back a plain answer, in combat too, on every client. Only conditionals are accepted,
-- never a command or a second clause, so saved or imported text can do nothing but be tested. Loaded from the TOC after
-- Platform/unit_rank.lua; Conditions/macro_conditions.lua uses it.
local _, addon = ...
local platform = addon.Platform

-- Longest macro conditional text accepted.
local MAX_LENGTH = 255

-- Checks that text is only macro conditionals: one or more bracketed groups and nothing else.
-- @param text any  The saved text.
-- @return boolean  True when the text is a non-empty sequence of [..] groups no longer than MAX_LENGTH.
function platform:IsMacroConditionText(text)
    if type(text) ~= 'string' or #text > MAX_LENGTH or text:find('[;%c]') then
        return false
    end

    local groups = 0

    local rest = text:gsub('%b[]', function(group)
        groups = group:sub(2, -2):find('[%[%]]') and -math.huge or groups + 1
        return ''
    end)

    return groups > 0 and rest:match('^%s*$') ~= nil
end

-- Asks the game whether macro conditionals hold now.
-- @param text string  The conditionals, for example "[combat,harm]" or "[mod:shift][@focus,exists]" (groups are OR'd).
-- @return boolean|nil  Whether any group holds; nil when the game cannot answer.
-- @return string|nil  The reason code when the first return is nil.
function platform:GetMacroConditionObservation(text)
    if not self:IsMacroConditionText(text) then
        return nil, 'invalid-macro-condition'
    end
    if type(SecureCmdOptionParse) ~= 'function' then
        return nil, 'missing-api'
    end

    local ok, result = pcall(SecureCmdOptionParse, text .. ' 1')

    if not ok then
        return nil, 'api-error'
    end
    if not self:CanReadValue(result) then
        return nil, 'restricted-value'
    end

    return result == '1'
end
