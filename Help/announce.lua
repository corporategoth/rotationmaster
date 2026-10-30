-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Help document for the Announces settings page: the ordered list of sections (title plus one authored paragraph per
-- control), the renderer that lays them out in a help frame, and the subset shown from an announcement card's output
-- controls. Paragraph text lives in the locale tables under Help.Announces.*; this file only orders and selects it.
-- Loaded from RotationMaster.toc after Help/effects.lua, with the other Help/ files, once UI/ and Help/common.lua
-- (addon.help_funcs) exist. The document function is also read by UI/help.lua as the Announces help source.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs
local CreateText, Gap = helpers.CreateText, helpers.Gap

-- Returns the Announces help sections: overview, action type, macro use, channels and outputs, text and sounds, state
-- and Apply/Cancel, and the collection buttons.
-- @return table[]  The sections, each {id=string, title=string, text=string}, in page order.
--
-- Keep whole paragraphs in the locale table so translations control word order.
function addon:GetDocument_layout_announce_options_help()
    return {
        {
            id = "overview",
            title = L["Announces"],
            text = L["Announce selected spell casts or item uses independently of your active rotation, or invoke a configured Via Script/Macro entry directly. Select an entry in the sidebar, or use New to prepare one. The trigger applies to every ordered output card; each card has its own destination and conditions. These settings do not cast spells or use items. Cast-triggered announcements follow RM's combat-data policy and do not run on reference-only clients."],
        },
        {
            id = "name",
            title = L["Name"],
            text = L["An optional name identifies this announcement in the sidebar. Without one, the action name or Via Script/Macro identifier is used. Changing this display name does not change the watched action or callable identifier."],
        },
        {
            id = "type",
            title = L["Action Type"],
            text = L["Choose Spell, Pet Spell, Item or Via Script/Macro. Changing type clears the previous action and exact-rank choice. Via Script/Macro uses an Identifier instead of a cast event or stored action; switching back restores the event selector. Choosing the current type keeps its fields."],
        },
        {
            id = "type.spell",
            title = L["Spell"],
            text = L["Watch one of your spells. Choose the spell in the searchable field below Action Type."],
        },
        {
            id = "type.pet",
            title = L["Pet Spell"],
            text = L["Watch a spell from your pet spellbook. The spell selector uses the pet catalog for this action type."],
        },
        {
            id = "type.item",
            title = L["Item"],
            text = L["Watch item-use spells from a reusable item set or a custom list. This is an announcement trigger; it does not choose an item to use for you."],
        },
        {
            id = "type.macro",
            title = L["Via Script/Macro"],
            text = L["Via Script/Macro is invoked by its saved Identifier rather than a cast event. It does not require a stored spell or item. Current conditions must match before any output. This call attempts output synchronously; it does not establish that a spell was cast or succeeded."],
        },
        {
            id = "identifier",
            title = L["Identifier"],
            text = L["Use a unique, case-sensitive identifier of at most 64 ASCII characters. Start with a letter or underscore; subsequent characters may also include digits, dots or hyphens. Identifiers are scoped to the active profile, including disabled entries. Duplicate assigns a distinct identifier; ambiguous imports and Apply are rejected."],
        },
        {
            id = "macro.example",
            title = L["Macro invocation"],
            text = L["Use /run RM_Annouce('FOO','mouseover',nil). RM_Announce is the same function. The target unit and spell are optional: /run RM_Announce('FOO',nil,403) or /run RM_Announce('FOO','target','Lightning Bolt'). Spell names depend on client language. {{event}} becomes Via Script/Macro; {{target}} and {{spell}} use the supplied arguments. A required missing argument skips output. {{item}} is not supplied by this API. A resurrection message announces an attempt, not a completed resurrection. Examples are text only; RM does not create or execute macros."],
        },
        {
            id = "macro.target",
            title = L["Supplied macro unit"],
            text = L["Supply a readable unit token such as mouseover, target or focus. RM resolves that exact unit name and rechecks its identity during delivery. Announcement target conditions and Whisper use this same unit. Omitting the argument does not use your selected target, yourself, a prior cast or a prior macro call. Missing Announcement target data remains unavailable, including under NOT."],
        },
        {
            id = "macro.emote_target",
            title = L["Use supplied macro target ({{target}})"],
            text = L["Checked directs a named emote to the supplied macro unit. Missing or unreadable target data skips the targeted emote; unchecked is targetless."],
        },
        {
            id = "channel.say",
            title = L["Say"],
            text = L["Available only for Via Script/Macro. Attempt a Say message directly in the invoking call. Blizzard may reject macro-origin chat, including during instance encounters; RM does not attest hardware input, defer delivery, retry or guarantee visible output."],
        },
        {
            id = "channel.yell",
            title = L["Yell"],
            text = L["Available only for Via Script/Macro. Attempt a Yell message directly in the invoking call. Native macro and encounter restrictions still apply; a completed API call is not confirmation of delivery."],
        },
        {
            id = "channel.whisper",
            title = L["Whisper"],
            text = L["Available only for Via Script/Macro. Whisper uses the exact supplied unit name and requires a readable player identity. No target means no Whisper. Native macro and encounter restrictions still apply; RM never substitutes another recipient or retries."],
        },
        {
            id = "spell",
            title = L["Spell"],
            text = L["Search by spell name, select a result, or drag a spell from your spellbook or action bar into the field. The icon and name identify the selected spell. Spell and pet spell choices keep their respective catalog scope."],
        },
        {
            id = "ranked",
            title = L["Use this exact spell rank"],
            text = L["Unchecked (the default), any known rank of the spell matches. Checked limits matching to the rank you chose. This checkbox is shown only for Spell and Pet Spell, and only on clients with spell ranks."],
        },
        {
            id = "items",
            title = L["Item Set"],
            text = L["Choose a reusable set, or Custom to edit this announcement's own list. For a custom list, search for or drag items into the fields; Add item appends one and a red trash can removes an entry. Any matching item-use spell in the list can trigger the announcement; list order does not limit announcements to the first carried item. Changes to a shared set belong on the Item Sets page."],
        },
        {
            id = "event",
            title = L["Event"],
            text = L["For automatic action types, choose which observed cast event triggers this entry. A start, stop, interruption, failure or delay is different from a successful cast. Client support determines which events and observations are available. Via Script/Macro has no cast event."],
        },
        {
            id = "conditions",
            title = L["Announcement conditions"],
            text = L["Optional conditions use the Announcement condition list and All, Any and Not groups. For spell, pet and item announcements, they run when the configured action and event match. For Via Script/Macro, they run when you invoke the saved identifier. Each output card checks its own conditions. Only a matching result allows that output; unavailable data skips that card while later cards remain independent. In Group can check the Spell recipient recorded for this cast, including click casting, without using your selected target. Choose Announcement target to check the spell recipient for automatic entries, or the supplied unit for Via Script/Macro; Whisper uses that same supplied unit. Automatic entries pass the recorded recipient name to native unit queries. A missing or unresolvable recipient skips its required condition; an unrelated selected target is never substituted. Missing or ambiguous required recipients do not match. Apply in the condition editor updates the announcement draft; Apply on Announces saves it. Cancel or Discard abandons draft changes."],
        },
        {
            id = "event.START",
            title = L["Started"],
            text = L["The cast or channel started. This event does not mean it will finish successfully."],
        },
        {
            id = "event.STOP",
            title = L["Stopped"],
            text = L["The cast or channel stopped. A stop alone does not establish whether it succeeded."],
        },
        {
            id = "event.SUCCEEDED",
            title = L["Succeeded"],
            text = L["The client reported a successful spell cast or item-use spell. For a channel, this can occur as channeling begins rather than after its final tick."],
        },
        {
            id = "event.INTERRUPTED",
            title = L["Interrupted"],
            text = L["The client reported that the cast was interrupted. This can include canceling a cast yourself."],
        },
        {
            id = "event.FAILED",
            title = L["Failed"],
            text = L["The client reported that the cast failed. This is separate from the successful-cast event."],
        },
        {
            id = "event.DELAYED",
            title = L["Delayed"],
            text = L["The client reported a delay to the cast. This event is not a completion or success notification."],
        },
        {
            id = "outputs",
            title = L["Outputs"],
            text = L["One trigger can send an ordered series of outputs. Each expanded card has its own destination, text or sound, conditions and enabled state. Help describes that card. Duplicate makes an independent card; delete removes it. Use the arrows, or drag a card from anywhere on it, to change order. Add output, on the Outputs header row, appends a card; drag it into a gap to insert one there. A legacy announcement stays unchanged on display. Adding, duplicating or removing a card, choosing Channel, or changing to an action type that cannot use its saved destination converts only the draft to output cards. Up to 64 outputs are allowed; an empty series sends nothing. Apply saves the draft and Discard restores it."],
        },
        {
            id = "channel.channel",
            title = L["Channel"],
            text = L["Via Script/Macro outputs can send to a joined chat channel. Open Channel to refresh the joined names, then select the exact name. A saved name remains visible when unavailable; that output is skipped until the channel is joined under that name. Numeric channel IDs are not saved and channels are never joined automatically. Native delivery permissions still apply."],
        },
        {
            id = "announce",
            title = L["Announce"],
            text = L["Choose a chat destination, local output, a named Emote or Audible. Emote replaces Text with an emote selector and optional recipient. Audible replaces Text with Sound. Text is retained when switching modes. Say, Yell, Whisper and named joined channels are offered only for Via Script/Macro and remain subject to native restrictions."],
        },
        {
            id = "channel.audible",
            title = L["Audible"],
            text = L["Play the selected sound locally on the Master audio channel; no chat message is sent. Choose an available sound before applying the announcement."],
        },
        {
            id = "channel.partyraid",
            title = L["Raid or Party"],
            text = L["Use raid chat while in a raid, party chat while in a party, or your local chat frame while solo."],
        },
        {
            id = "channel.party",
            title = L["Party Only"],
            text = L["Use party chat when grouped, including your party within a raid. This destination produces no solo chat message."],
        },
        {
            id = "channel.raidwarn",
            title = L["Raid Warning"],
            text = L["Request group warning output. Depending on group membership and permissions, RM may use raid chat, party chat, or local output instead."],
        },
        {
            id = "channel.gesture",
            title = L["Emote"],
            text = L["Choose a named emote from this client's slash commands, such as /cheer. This does not send the Text field as a custom emote."],
        },
        {
            id = "channel.emote",
            title = L["Custom emote"],
            text = L["A saved free-text emote keeps its original message. Select Emote to use a named client emote instead."],
        },
        {
            id = "channel.local",
            title = L["Local Only"],
            text = L["Write to your own chat frame. Other players do not receive this message."],
        },
        {
            id = "emote",
            title = L["Emote"],
            text = L["Choose the emote to perform when the configured cast event is observed. The client may restrict an emote or require a hardware action; RM does not retry through another output path."],
        },
        {
            id = "emote_target",
            title = L["Use spell recipient ({{target}})"],
            text = L["For cast entries, checked directs the emote to the recipient recorded for this exact cast, including click casting. It does not use your current target or a previous cast's recipient. For Via Script/Macro, checked uses the supplied macro unit. A missing recipient skips targeted output. Unchecked performs the emote without a target."],
        },
        {
            id = "text",
            title = L["Text"],
            text = L["Enter the message for a chat destination. The substitutions below insert action and cast information when it is available. This text is not used for Audible or named Emote output."],
        },
        {
            id = "substitutions",
            title = L["Announcement substitutions"],
            text = L["For cast entries, {{spell}} is a spell link, {{item}} an item link and {{event}} the localized event name. {{target}} uses the recorded cast target, with the last recorded target for that spell as a fallback; it does not automatically use your selected target or your name. Unavailable cast substitutions can remain unchanged. Via Script/Macro instead uses its supplied target and spell, {{event}} becomes Via Script/Macro, and required missing inputs skip output; this API supplies no {{item}}."],
        },
        {
            id = "sound",
            title = L["Sound"],
            text = L["Choose a sound supplied by the shared-media catalog, then click Play to preview it. Preview is local and does not save the draft. An unavailable sound cannot be previewed; Audible announcements require a nonempty sound selection."],
        },
        {
            id = "state",
            title = L["Enabled / Disabled"],
            text = L["The pill turns this entry on or off while keeping its fields. Disabled entries do not announce matching casts or macro invocations. Apply saves the changed state."],
        },
        {
            id = "save",
            title = L["Apply / Cancel"],
            text = L["Edits stay in a draft until Apply. Complete the action or Via Script/Macro identifier and other required fields before saving. Discard abandons changes to saved announcements; Cancel closes a new creation draft. Leaving pending changes offers Apply, Discard or Cancel navigation."],
        },
        {
            id = "collections",
            title = L["New, Duplicate, Import/Export and Compare"],
            text = L["Use the sidebar buttons to create, duplicate, transfer or compare announcements. Apply saves the imported draft; Compare does not merge entries. Via Script/Macro Duplicate assigns a distinct identifier and every copied output gets a fresh identity. Series exports use version 2; version 1 remains available for legacy single-output entries. Imports and Apply reject ambiguous identifiers. The red trash permanently deletes the selected saved entry after confirmation. Resolve pending edits first; deletion does not carry into the next selected draft."],
        },
    }
end

-- Lays the Announces help document out in a frame as a yellow title followed by its paragraph, one gap between each.
-- @param frame table  The help frame (a container widget) the text widgets are added to.
function addon.layout_announce_options_help(frame)
    for _, entry in ipairs(addon:GetDocument_layout_announce_options_help()) do
        frame:AddChild(Gap())

        frame:AddChild(CreateText(
            (entry.title ~= '' and color.BLIZ_YELLOW .. entry.title .. color.RESET .. ' - ' or '') .. entry.text
        ))
    end
end

-- Returns the Announces help limited to an announcement card's output controls (card Help uses the same authored
-- document).
-- @param kind string  The announcement's action type ("macro" selects the macro wording of the emote target section).
-- @param mode string  The announcement's output channel (for example "audible" or "gesture").
-- @return table[]  Only the sections for that channel and the shared output controls, each {id=string, title=string,
--   text=string}.
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

    if mode == 'audible' then
        included.sound = true
    end

    for _, entry in ipairs(self:GetDocument_layout_announce_options_help()) do
        if included[entry.id] then
            sections[#sections + 1] = entry
        end
    end

    return sections
end
