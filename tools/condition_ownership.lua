-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Offline, explicit ownership of unchanged historical helper implementations.
return {
    protectedRead = {
        module = 'Functions/cache.lua',
        member = 'Functions.cache.protectedRead',
        legacyModule = 'Conditions/spatial.lua',
        legacyAlias = 'protectedRead',
        bindingID = 'builtin:Conditions/spatial.lua:protectedRead',
        namespace = 'Conditions.spatial',
        description = 'Packaged helper from Conditions/spatial.lua.',
        captureBindings = {},
    },
}
