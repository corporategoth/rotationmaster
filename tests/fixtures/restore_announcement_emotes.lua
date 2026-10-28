-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Exact named-emote event changes before historical main-module proofs.
local changes = {
    {
        at = 80943,
        current = [====[            if (value.value or value.announce == "audible" or value.announce == "gesture") and (not value.disabled) and (value.type == BOOKTYPE_PET and unit == "pet" or unit == "player") and
]====],
        previous = [====[            if (value.value or value.announce == "audible") and (not value.disabled) and (value.type == BOOKTYPE_PET and unit == "pet" or unit == "player") and
]====],
    },
    {
        at = 82155,
        current = [====[                            if ent.announce~='audible' and ent.announce~='gesture' then
]====],
        previous = [====[                            if ent.announce~='audible' then
]====],
    },
    {
        at = 83179,
        current = [====[                            if ent.announce=='gesture' then self:DispatchAnnouncement(ent,nil,currentSpells[castguid])
                            else self:DispatchAnnouncement(ent, text) end
]====],
        previous = [====[                            self:DispatchAnnouncement(ent, text)
]====],
    },
}

local function hash(s)
    local n = 0

    for i = 1, #s do
        n = (n * 33 + s:byte(i)) % 4294967296
    end

    return string.format('%08x', n)
end

return function(text, path)
    if path == 'main.lua' and text:find('local prepareChoiceSelection', 1, true) then
        text = dofile('tests/fixtures/restore_rotation_choice_preferences.lua')(text, path)
    end
    if path == 'main.lua' and text:find('-- BEGIN EQUIPMENT EVENT LIFETIME', 1, true) then
        text = dofile('tests/fixtures/restore_equipment_event_refresh.lua')(text, path)
    end

    if path ~= 'main.lua' then
        return text
    end

    assert(#text == 88071 and hash(text) == '15dc9e89', 'unrelated named-emote main source')

    for i = #changes, 1, -1 do
        local c = changes[i]
        assert(text:sub(c.at, c.at + #c.current - 1) == c.current, 'named-emote source mismatch')
        text = text:sub(1, c.at - 1) .. c.previous .. text:sub(c.at + #c.current)
    end

    assert(#text == 87884 and hash(text) == '28b84d73', 'named-emote predecessor mismatch')
    return text
end
