-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter that answers one question: does this client have a focus target at all.
-- Owns platform:IsFocusUnitSupported only; the focus unit's own state is read by the unit readers, and this file must
-- not read it. It asks the client (event catalog, FocusUnit, FocusFrame) rather than branching on the client version.
-- Loaded early in RotationMaster.toc, after Platform/groups.lua; it uses platform:GetClientFamily from
-- Platform/client.lua only as a last resort when the client cannot answer.
local _, addon = ...
local platform = addon.Platform or {}
addon.Platform = platform

-- Names are read through the environment table, not as globals: they are probes, and a client without them must read
-- as "no", not as a missing API.
local env = getfenv and getfenv(1) or _G

-- Whether this client has a focus target, so that `focus` and `focustarget` are offered as units.
-- @return boolean|nil  True or false when the client could be probed; nil when it cannot be probed at all (no event
--   catalog and no sign of a focus system) and its family is unknown to the caller.
--
-- A 2021 check of WOW_PROJECT_ID hid the focus units on Classic Era; the client itself is asked instead. Three
-- independent signs say yes: the event catalog knows PLAYER_FOCUS_CHANGED (the catalog main.lua uses to confirm
-- optional events), the FocusUnit function exists, or the FocusFrame does. Safe to call at any time.
function platform:IsFocusUnitSupported()
    local utils = env.C_EventUtils
    local asked

    if type(utils) == 'table' and type(utils.IsEventValid) == 'function' then
        local ok, valid = pcall(utils.IsEventValid, 'PLAYER_FOCUS_CHANGED')

        if ok and type(valid) == 'boolean' then
            asked = true

            if valid then
                return true
            end
        end
    end

    if type(env.FocusUnit) == 'function' or type(env.FocusFrame) == 'table' then
        return true
    end

    -- No sign of a focus system. A client that could answer the event question
    -- and said no has none; one that could not is judged by its family.
    if asked then
        return false
    end

    local family = type(self.GetClientFamily) == 'function' and self:GetClientFamily()

    if family == 'era' then
        return false
    end
    if family == 'retail' or family == 'forever' or family == 'tbc' or family == 'progression' then
        return true
    end

    return nil
end
