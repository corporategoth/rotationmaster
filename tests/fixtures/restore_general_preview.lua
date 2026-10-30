-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Undo only the two General/inventory additions before the existing complete
-- Masque successor proof. Its original full-file equality remains the authority.
local changes = {
    ['UI/settings_collections.lua'] = {
        "'preview_spells','preview_masque','preview_vertical'",
        "'preview_spells','preview_vertical'",
    },
    ['UI/settings_integrations.lua'] = {
        "key='integrations_themes',title=L['Button skins']",
        "key='integrations_preview',title=L['Preview appearance']",
    },
}

return function(path, source)
    local change = changes[path]

    if not change then
        return source
    end

    local start, last = source:find(change[1], 1, true)

    if not start then
        return source
    end

    assert(not source:find(change[1], last + 1, true), 'General preview inverse has an ambiguous addition: ' .. path)
    return source:sub(1, start - 1) .. change[2] .. source:sub(last + 1)
end
