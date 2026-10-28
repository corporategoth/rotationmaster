-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The client the rotation library and scope suites model: a TBC Anniversary Shaman. They load the real
-- Platform/client.lua (Core/rotation_library.lua reads addon.Platform while it loads, as in the TOC, where all of
-- Platform/ comes first), and a Built In whose families do not include the client's is not registered
-- ("other-character"), so the globals Platform reads to name the client have to be there.
return function(env)
    env.WOW_PROJECT_MAINLINE, env.WOW_PROJECT_CLASSIC = 1, 2
    env.WOW_PROJECT_BURNING_CRUSADE_CLASSIC, env.WOW_PROJECT_MISTS_CLASSIC = 5, 19
    env.WOW_PROJECT_WRATH_CLASSIC, env.WOW_PROJECT_CATACLYSM_CLASSIC, env.WOW_PROJECT_CAMELOT = 11, 14, 18
    env.WOW_PROJECT_ID, env.LE_EXPANSION_LEVEL_CURRENT = 5, 1
    env.UnitClass = function() return 'Shaman', 'SHAMAN' end
    return env
end
