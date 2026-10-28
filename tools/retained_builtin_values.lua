-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Offline-only retention of one actual historical lexical value. This is not
-- a public helper declaration, executable replacement, or hash compatibility map.
return {
    character_class = {
        module = 'Conditions/character.lua',
        alias = 'character_class',
        bindingID = 'builtin:Conditions/character.lua:character_class',
        declaration = 'local character_class = select(2, UnitClass("player"))',
        namespace = 'Conditions.character',
        description = 'Packaged helper from Conditions/character.lua.',
        sourceHash = 'f9f4e4b5',
    },
}
