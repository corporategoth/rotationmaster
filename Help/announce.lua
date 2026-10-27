local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs
local CreateText, Gap = helpers.CreateText, helpers.Gap

-- Keep whole paragraphs in the locale table so translations control word order.
function addon:GetDocument_layout_announce_options_help()
    return {
        { id = "overview", title = L["Announces"], text = L["Help.Announces.overview"] },
        { id = "name", title = L["Name"], text = L["Help.Announces.name"] },
        { id = "type", title = L["Action Type"], text = L["Help.Announces.type"] },
        { id = "type.spell", title = L["Spell"], text = L["Help.Announces.type.spell"] },
        { id = "type.pet", title = L["Pet Spell"], text = L["Help.Announces.type.pet"] },
        { id = "type.item", title = L["Item"], text = L["Help.Announces.type.item"] },
        { id = "type.macro", title = L["Via Script/Macro"], text = L["Help.Announces.type.macro"] },
        { id = "identifier", title = L["Identifier"], text = L["Help.Announces.identifier"] },
        { id = "macro.example", title = L["Macro invocation"], text = L["Help.Announces.macro.example"] },
        { id = "macro.target", title = L["Supplied macro unit"], text = L["Help.Announces.macro.target"] },
        {
            id = "macro.emote_target",
            title = L["Use supplied macro target ({{target}})"],
            text = L["Help.Announces.macro.emote_target"],
        },
        { id = "channel.say", title = L["Say"], text = L["Help.Announces.channel.say"] },
        { id = "channel.yell", title = L["Yell"], text = L["Help.Announces.channel.yell"] },
        { id = "channel.whisper", title = L["Whisper"], text = L["Help.Announces.channel.whisper"] },
        { id = "spell", title = L["Spell"], text = L["Help.Announces.spell"] },
        { id = "ranked", title = L["Use this exact spell rank"], text = L["Help.Announces.ranked"] },
        { id = "items", title = L["Item Set"], text = L["Help.Announces.items"] },
        { id = "event", title = L["Event"], text = L["Help.Announces.event"] },
        { id = "conditions", title = L["Announcement conditions"], text = L["Help.Announces.conditions"] },
        { id = "event.START", title = L["Started"], text = L["Help.Announces.event.START"] },
        { id = "event.STOP", title = L["Stopped"], text = L["Help.Announces.event.STOP"] },
        { id = "event.SUCCEEDED", title = L["Succeeded"], text = L["Help.Announces.event.SUCCEEDED"] },
        { id = "event.INTERRUPTED", title = L["Interrupted"], text = L["Help.Announces.event.INTERRUPTED"] },
        { id = "event.FAILED", title = L["Failed"], text = L["Help.Announces.event.FAILED"] },
        { id = "event.DELAYED", title = L["Delayed"], text = L["Help.Announces.event.DELAYED"] },
        { id = "outputs", title = L["Outputs"], text = L["Help.Announces.outputs"] },
        { id = "channel.channel", title = L["Channel"], text = L["Help.Announces.channel.channel"] },
        { id = "announce", title = L["Announce"], text = L["Help.Announces.announce"] },
        { id = "channel.audible", title = L["Audible"], text = L["Help.Announces.channel.audible"] },
        { id = "channel.partyraid", title = L["Raid or Party"], text = L["Help.Announces.channel.partyraid"] },
        { id = "channel.party", title = L["Party Only"], text = L["Help.Announces.channel.party"] },
        { id = "channel.raidwarn", title = L["Raid Warning"], text = L["Help.Announces.channel.raidwarn"] },
        { id = "channel.gesture", title = L["Emote"], text = L["Help.Announces.channel.gesture"] },
        { id = "channel.emote", title = L["Custom emote"], text = L["Help.Announces.channel.emote"] },
        { id = "channel.local", title = L["Local Only"], text = L["Help.Announces.channel.local"] },
        { id = "emote", title = L["Emote"], text = L["Help.Announces.emote"] },
        { id = "emote_target", title = L["Use spell recipient ({{target}})"], text = L["Help.Announces.emote_target"] },
        { id = "text", title = L["Text"], text = L["Help.Announces.text"] },
        { id = "substitutions", title = L["Announcement substitutions"], text = L["Help.Announces.substitutions"] },
        { id = "sound", title = L["Sound"], text = L["Help.Announces.sound"] },
        { id = "state", title = L["Enabled / Disabled"], text = L["Help.Announces.state"] },
        { id = "save", title = L["Apply / Cancel"], text = L["Help.Announces.save"] },
        {
            id = "collections",
            title = L["New, Duplicate, Import/Export and Compare"],
            text = L["Help.Announces.collections"],
        },
    }
end

function addon.layout_announce_options_help(frame)
    for _, entry in ipairs(addon:GetDocument_layout_announce_options_help()) do
        frame:AddChild(Gap())

        frame:AddChild(
            CreateText(
                (entry.title ~= '' and color.BLIZ_YELLOW .. entry.title .. color.RESET .. ' - ' or '') .. entry.text
            )
        )
    end
end

-- Card Help uses the same authored document, limited to its output controls.
function addon:GetAnnouncementOutputHelp(kind, mode)
    local sections = {}

    local included = {
        outputs = true,
        conditions = true,
        announce = true,
        text = true,
        substitutions = true,
        state = true,
        save = true,
    }

    included['channel.' .. tostring(mode)] = true

    if mode == 'gesture' then
        included.emote = true
        included[kind == 'macro' and 'macro.emote_target' or 'emote_target'] = true
    end

    if mode == 'audible' then included.sound = true end

    for _, entry in ipairs(self:GetDocument_layout_announce_options_help()) do
        if included[entry.id] then sections[#sections + 1] = entry end
    end

    return sections
end
