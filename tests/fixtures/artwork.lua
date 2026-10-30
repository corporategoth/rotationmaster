-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Preserve historical whole-source checks while permitting reviewed icon-only
-- declarations. Callback sources and all other metadata remain hash checked.
return function(source, family, expected)
    assert(family == 'spatial', 'unexpected historical icon family')

    local declaration = [=[icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Conditions\\]=]
        .. family
        .. [=[",]=]

    local text, count = source:gsub('icon = addon%.Artwork%.condition%["[A-Z_0-9]+"%],', function()
        return declaration
    end)

    assert(count == expected, 'artwork declaration inventory changed')
    return text
end
