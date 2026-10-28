-- Exact outer announcement composition before unchanged historical proofs.
local records = {
    ["main.lua"] = {
        bytes = 93447,
        hash = "5f988159",
        oldBytes = 92461,
        oldHash = "cb9c5af2",
        changes = {
            {
                at = 85272,
                current = ([========[!        -- BEGIN ANNOUNCEMENT CONDITION OWNER
        local profile=self.db.profile
        local announcements=profile.announces
        for index, value in ipairs(announcements) do
        -- END ANNOUNCEMENT CONDITION OWNER
]========]):sub(2),
                previous = ([========[!        for _, value in ipairs(self.db.profile.announces) do
]========]):sub(2),
            },
            {
                at = 86156,
                current = ([========[!                    -- BEGIN ANNOUNCEMENT CONDITION LEASE
                    local registry=self.conditionRegistryVersion
                    local ent,current=self:PrepareAnnouncementDelivery(value,function()
                        return self.db.profile==profile and profile.announces==announcements
                            and announcements[index]==value and not value.disabled
                            and self.conditionRegistryVersion==registry
                    end)
                    if ent and current() then
                    -- END ANNOUNCEMENT CONDITION LEASE
]========]):sub(2),
                previous = ([========[!                    local ent = self.Functions.collections.deepcopy(value)
                    if ent.type == BOOKTYPE_SPELL or ent.type == BOOKTYPE_PET then
                        ent.action = ent.spell
                    elseif ent.type == "item" then
                        ent.action = ent.item
                    end

]========]):sub(2),
            },
            {
                at = 86913,
                current = ([========[!                            -- BEGIN ANNOUNCEMENT CONDITION MATCH
                            if self:AnnouncementConditionMatches(ent,currentSpells[castguid],current) then
                            -- END ANNOUNCEMENT CONDITION MATCH
]========]):sub(2),
                previous = ([========[!]========]):sub(2),
            },
            {
                at = 88231,
                current = ([========[!                            if not current() then return end -- ANNOUNCEMENT CONDITION BEFORE OUTPUT
                            -- Reserve before any output callback can reenter this cast.
                            if self.announced[ent.id] == nil then
                                self.announced[ent.id] = { castguid }
]========]):sub(2),
                previous = ([========[!                            if ent.announce=='gesture' then self:DispatchAnnouncement(ent,nil,currentSpells[castguid])
                            else self:DispatchAnnouncement(ent, text) end
                            if self.announced[value.id] == nil then
                                self.announced[value.id] = { castguid }
]========]):sub(2),
            },
            {
                at = 88590,
                current = ([========[!                                table.insert(self.announced[ent.id], castguid)
]========]):sub(2),
                previous = ([========[!                                table.insert(self.announced[value.id], castguid)
]========]):sub(2),
            },
            {
                at = 88701,
                current = ([========[!                            if ent.announce=='gesture' then self:DispatchAnnouncement(ent,nil,currentSpells[castguid],current)
                            else self:DispatchAnnouncement(ent,text,nil,current) end
                            end -- ANNOUNCEMENT CONDITION OUTPUT
]========]):sub(2),
                previous = ([========[!]========]):sub(2),
            },
            {
                at = 89064,
                current = ([========[!                    end -- ANNOUNCEMENT CONDITION LEASE
]========]):sub(2),
                previous = ([========[!]========]):sub(2),
            },
        },
    },
    ["Locales/enUS.lua"] = {
        bytes = 239014,
        hash = "0b109ae5",
        oldBytes = 236594,
        oldHash = "f0996095",
        changes = {
            {
                at = 179162,
                current = ([========[!L["Edit announcement conditions"] = "Edit announcement conditions"
L["Announcement conditions"] = "Announcement conditions"
L["Help.Announces.conditions"] = "Optional conditions use the Switch condition list and All, Any and Not groups. They run only when this announcement's spell and event match. Only a matching result allows its message or sound; unavailable data skips the announcement. In Group can check the Spell recipient recorded for this cast, including click casting, without using your selected target. Missing or ambiguous recipients skip that check. Apply in the condition editor updates the announcement draft; Apply on Announces saves it. Cancel or Discard abandons draft changes."

L["Spell recipient"] = "Spell recipient"
L["{unit} {{!is|is not}} in a raid"] = "{unit} {{!is|is not}} in a raid"
L["{unit} {{!is|is not}} in a group"] = "{unit} {{!is|is not}} in a group"
L["Help.GROUP.unit"] = "Choose the unit whose membership in your party or raid is checked. Player keeps the original player group-status behavior. Spell recipient uses only the current announcement event context; without that readable context the result is unavailable. It never substitutes your selected target or a previous cast."
L["Help.GROUP.raid"] = "Checked tests raid membership only. Unchecked tests party membership or raid membership. A known nonmember is false; unavailable native data stays unavailable, including under NOT."
]========]):sub(2),
                previous = ([========[!]========]):sub(2),
            },
            {
                at = 194921,
                current = ([========[!L["Exact readable recipient name recorded for this cast."] = true
]========]):sub(2),
                previous = ([========[!]========]):sub(2),
            },
            {
                at = 219363,
                current = ([========[!L["Read a specified unit membership in the player party or raid. True raidOnly queries only UnitInRaid; otherwise a true UnitInParty result short-circuits, false proceeds to UnitInRaid, and unknown remains unavailable. Readable nil raid index means false; integer raid index1..40 means true. Names are passed unchanged to native APIs; native name-query acceptance requires client qualification."] = true
]========]):sub(2),
                previous = ([========[!]========]):sub(2),
            },
            {
                at = 226499,
                current = ([========[!L["Readable nonempty unit token or native-recognized name, passed unchanged."] = true
]========]):sub(2),
                previous = ([========[!]========]):sub(2),
            },
            {
                at = 228352,
                current = ([========[!L["Resolve an exact cast-recipient name against the current bounded party or raid roster, then observe membership through a unit token. Missing, ambiguous or changing roster data remains unavailable; never reads the selected target or retains state across casts."] = true
]========]):sub(2),
                previous = ([========[!]========]):sub(2),
            },
            {
                at = 235043,
                current = ([========[!L["True checks raid membership only; false or nil checks party or raid."] = true
L["True checks raid membership only; false or nil checks party then raid."] = true
]========]):sub(2),
                previous = ([========[!]========]):sub(2),
            },
        },
    },
    ["RotationMaster.toc"] = {
        bytes = 8035,
        hash = "ac9c3e2f",
        oldBytes = 7999,
        oldHash = "45c8fbf4",
        changes = {
            {
                at = 1069,
                current = ([========[!Platform/announcement_recipient.lua
]========]):sub(2),
                previous = ([========[!]========]):sub(2),
            },
        },
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
    text = dofile('tests/fixtures/restore_announcement_unit_context.lua')(text, path)
    local row = records[path]

    if not row then
        return text
    end
    if #text == row.oldBytes and hash(text) == row.oldHash then
        return text
    end

    assert(#text == row.bytes and hash(text) == row.hash, 'unrelated complete announcement-condition source: ' .. path)

    for i = #row.changes, 1, -1 do
        local c = row.changes[i]
        assert(text:sub(c.at, c.at + #c.current - 1) == c.current, 'announcement-condition source mismatch')
        text = text:sub(1, c.at - 1) .. c.previous .. text:sub(c.at + #c.current)
    end

    assert(#text == row.oldBytes and hash(text) == row.oldHash, 'announcement-condition predecessor mismatch: ' .. path)
    return text
end
