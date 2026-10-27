local _, addon = ...
local platform = addon.Platform or {}
addon.Platform = platform

-- Whether this client has a focus target, so that `focus` and `focustarget` are
-- offered as units. A 2021 check of WOW_PROJECT_ID hid them on Classic Era; the
-- client itself is asked instead. Three independent signs say yes: the event
-- catalog knows PLAYER_FOCUS_CHANGED (the catalog main.lua uses to confirm
-- optional events), the FocusUnit function exists, or the FocusFrame does. Names
-- are read through the environment table, not as globals: they are probes, and
-- a client without them must read as "no", not as a missing API.
-- Returns true or false; nil when the client cannot be probed at all (no event
-- catalog and no sign) and its family is unknown to the caller.
local env = getfenv and getfenv(1) or _G

function platform:IsFocusUnitSupported()
    local utils = env.C_EventUtils
    local asked

    if type(utils) == 'table' and type(utils.IsEventValid) == 'function' then
        local ok, valid = pcall(utils.IsEventValid, 'PLAYER_FOCUS_CHANGED')

        if ok and type(valid) == 'boolean' then
            asked = true
            if valid then return true end
        end
    end

    if type(env.FocusUnit) == 'function' or type(env.FocusFrame) == 'table' then return true end
    -- No sign of a focus system. A client that could answer the event question
    -- and said no has none; one that could not is judged by its family.
    if asked then return false end
    local family = type(self.GetClientFamily) == 'function' and self:GetClientFamily()
    if family == 'era' then return false end
    if family == 'retail' or family == 'forever' or family == 'tbc' or family == 'progression' then return true end
    return nil
end
