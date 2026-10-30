-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Exact optional-event registration stage inverse; original full-source proofs remain.
local changes = {
    {
        current = ([====[!-- These additional notifications vary by client; leave existing subscriptions
-- alone and require the native event catalogue to confirm each optional name.
local function registerOptionalEvent(owner,change,event)
    if not activeChangeCurrent(owner,change) then return false end
    local utils=C_EventUtils
    local validEvent=type(utils)=='table' and utils.IsEventValid
    if not activeChangeCurrent(owner,change) then return false end
    if type(validEvent)~='function' then return activeChangeCurrent(owner,change) end
    local ok,valid=pcall(validEvent,event)
    if not activeChangeCurrent(owner,change) then return false end
    if ok and valid==true then return activeCall(owner,change,'RegisterEvent',event) end
    return true
end

]====]):sub(2),
        previous = ([====[!]====]):sub(2),
    },
    {
        current = ([====[!
    if not registerOptionalEvent(self,change,'UNIT_EXITED_VEHICLE') then return end
    if family=='tbc' then
        if not registerOptionalEvent(self,change,'PLAYER_TALENT_UPDATE') then return end
        if not registerOptionalEvent(self,change,'ACTIVE_TALENT_GROUP_CHANGED') then return end
    end
]====]):sub(2),
        previous = ([====[!]====]):sub(2),
    },
}

local function hash(s)
    local n = 5381

    for i = 1, #s do
        n = (n * 33 + s:byte(i)) % 4294967296
    end

    return string.format('%08x', n)
end

return function(text, path)
    if path ~= 'main.lua' then
        return text
    end

    assert(#text == 86599 and hash(text) == 'c0b43855', 'unrelated optional-event source')

    for _, c in ipairs(changes) do
        local a, b = text:find(c.current, 1, true)
        assert(a and not text:find(c.current, b + 1, true), 'optional-event inverse anchor')
        text = text:sub(1, a - 1) .. c.previous .. text:sub(b + 1)
    end

    assert(#text == 85546 and hash(text) == 'd64c4f0b', 'optional-event predecessor differs')
    return text
end
