-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- QA-only exact inverse of the responsive workbench layout change (list/detail
-- divider, list rows that fill their column, shared row widths and window
-- size bounds). Exactly the current bytes of each touched file map back to
-- their predecessor, so the closed historical proofs that pin those files
-- keep running against the source they were written for. Any other text,
-- including every older stage, passes through unchanged.
local function digest(s)
    local n = 5381

    for i = 1, #s do
        n = (n * 33 + s:byte(i)) % 4294967296
    end

    return n
end

local records = {}

records["Core/profile_data.lua"] = {
    bytes = 13895,
    hash = 3810377379,
    oldBytes = 13787,
    oldHash = 2953815205,
    changes = {
        {
            at = 3696,
            current = "-- The desired-stock feature is retired. An existing saved stockTargets map\n-- is inert data: copies, transfers and validation carry it unread as long as\n-- it is plain table data.\nlocal function validStockTargets(_,profile)\n",
            previous = "-- Reject malformed optional stock before generic recursive profile copying.\nlocal function validStockTargets(addon,profile)\n",
        },
        {
            at = 4018,
            current = "    return plan==nil or type(plan)=='table' and getmetatable(plan)==nil\n",
            previous = "    return plan==nil or addon.StockTargets.Validate(plan)==true\n",
        },
        {
            at = 7302,
            current = "            -- Retired desired-stock data: plain tables only, carried unread.\n",
            previous = "            -- Closed optional schema was checked before copying the profile.\n",
        },
    },
}

records["Help/announce.lua"] = {
    bytes = 5047,
    hash = 619562948,
    oldBytes = 5134,
    oldHash = 3312792342,
    changes = {
        {
            at = 795,
            current = "        {id=\"type.macro\",title=L[\"Via Script/Macro\"],text=L[\"Help.Announces.type.macro\"]},\n",
            previous = "        {id=\"type.macro\",title=L[\"Via Macro\"],text=L[\"Help.Announces.type.macro\"]},\n",
        },
        {
            at = 3572,
            current = "",
            previous = "        {id=\"diagnostics\",title=L[\"Emote diagnostics\"],text=L[\"Help.Announces.diagnostics\"]},\n",
        },
    },
}

records["Help/general.lua"] = {
    bytes = 8060,
    hash = 2843726051,
    oldBytes = 7840,
    oldHash = 1835073424,
    changes = {
        {
            at = 407,
            current = "        {id=\"disable_buttons\",title=L[\"Disable Bar Highlighting\"],text=L[\"Help.General.disable_buttons\"]},\n        {id=\"minimap\",title=L[\"Minimap Icon\"],text=L[\"Help.General.minimap\"]},\n",
            previous = "",
        },
        {
            at = 680,
            current = "        {id=\"idle_poll\",title=L[\"Idle Re-check Interval (seconds)\"],text=L[\"Help.General.idle_poll\"]},\n        {id=\"autoswitch_poll\",title=L[\"Auto-Switch Re-check Interval (seconds)\"],text=L[\"Help.General.autoswitch_poll\"]},\n",
            previous = "        {id=\"disable_autoswitch\",title=L[\"Disable Auto-Switching\"],text=L[\"Help.General.disable_autoswitch\"]},\n        {id=\"disable_buttons\",title=L[\"Disable Bar Highlighting\"],text=L[\"Help.General.disable_buttons\"]},\n",
        },
        {
            at = 1032,
            current = "",
            previous = "        {id=\"minimap\",title=L[\"Minimap Icon\"],text=L[\"Help.General.minimap\"]},\n",
        },
        {
            at = 3393,
            current = "    -- Capture columns: CPU, Runtime, Memory, Casts. Each capture button also\n    -- stops its running capture; the probe stays a /rm perf probe command.\n",
            previous = "    if self.StartMemoryCapture then\n        ordered[#ordered+1]={id='memory_capture',title=L['Capture memory (10m)'],text=L['Help.General.memory_capture']}\n        ordered[#ordered+1]={id='memory_report',title=L['Memory report'],text=L['Help.General.memory_report']}\n        ordered[#ordered+1]={id='memory_stop',title=L['Stop memory capture'],text=L['Help.General.memory_stop']}\n    end\n",
        },
        {
            at = 3797,
            current = "",
            previous = "        ordered[#ordered+1]={id='cpu_cancel',title=L['Cancel capture'],text=L['Help.General.cpu_cancel']}\n        ordered[#ordered+1]={id='cpu_probe',title=L['Native profiler probe'],text=L['Help.General.cpu_probe']}\n",
        },
        {
            at = 4132,
            current = "        if self.StartMemoryCapture then\n            ordered[#ordered+1]={id='memory_capture',title=L['Capture memory (10m)'],text=L['Help.General.memory_capture']}\n            ordered[#ordered+1]={id='memory_report',title=L['Memory report'],text=L['Help.General.memory_report']}\n        end\n    end\n    if self.RunCastCaptureAction then\n        ordered[#ordered+1]={id='cast_capture',title=L['Capture casts (30s)'],text=L['Help.General.cast_capture']}\n        ordered[#ordered+1]={id='cast_report',title=L['Cast report'],text=L['Help.General.cast_report']}\n",
            previous = "",
        },
    },
}

records["Locales/enUS.lua"] = {
    bytes = 263239,
    hash = 890027340,
    oldBytes = 260311,
    oldHash = 227334449,
    changes = {
        {
            at = 907,
            current = "L['/rm perf engine [lean|standard] - Show or choose the rotation evaluation engine.'] = '/rm perf engine [lean||standard] - Show or choose the rotation evaluation engine.'\nL['Usage: /rm perf engine [lean|standard]'] = 'Usage: /rm perf engine [lean||standard]'\nL['Evaluation engine: %s'] = true\n",
            previous = "",
        },
        {
            at = 8356,
            current = "",
            previous = "L[\"Invalid stock targets in profile %s (%s); data preserved.\"] = true\nL[\"Invalid stock targets; data preserved.\"] = true\n",
        },
        {
            at = 19739,
            current = "L[\"Idle Re-check Interval (seconds)\"] = true\nL[\"Auto-Switch Re-check Interval (seconds)\"] = true\n",
            previous = "",
        },
        {
            at = 50299,
            current = "L[\"Drag to resize the list. Double-click to reset.\"] = true\nL[\"Drag onto any action bar slot (it swaps with what is there), or click Bind and then click an empty slot.\"] = true\n",
            previous = "",
        },
        {
            at = 71100,
            current = "L['Move %d selected cards'] = true\nL['Duplicate selected cards'] = true\nL['Enable selected cards'] = true\nL['Disable selected cards'] = true\nL['Delete selected cards'] = true\nL['Clear selection'] = true\nL['Select several cards'] = true\nL['Ctrl-click cards to add or remove them from the selection; Shift-click selects the siblings between it and the last clicked card. Shift-drag on empty canvas draws a box that selects every card it touches (Ctrl+Shift-drag adds). With several cards selected, the strip above the canvas groups them as All or Any, and Duplicate, Enable, Disable and Delete act on every selected card; one Undo reverses each. Drag any selected card to move the selection.'] = true\nL['Ctrl-click cards to add or remove them from the selection; Shift-click a title or condition to select the siblings between it and the last clicked card. Shift-drag on empty canvas draws a box that selects every card it touches (Ctrl+Shift-drag adds). Drag any selected card to move the whole selection to one gap. Beside Apply, Duplicate, Enable, Disable and Delete act on every selected card, and one Undo reverses each. Branches keep their Evaluate / Always mode. Click empty canvas to clear the selection.'] = true\nL['Target casting: %s'] = true\nL['Focus casting: %s'] = true\nL['Target channeling: %s'] = true\nL['Focus channeling: %s'] = true\nL['Recently cast: %s'] = true\nL['Trinket 1: %s'] = true\nL['Trinket 2: %s'] = true\nL['No equipped trinket to insert.'] = true\nL['Nothing to insert: no target or focus cast and no recent casts.'] = true\nL['Click to insert. Right-click the field again to close.'] = true\nL['Right-click to insert an equipped trinket.'] = true\nL[\"Right-click to insert your target's cast or a recent cast.\"] = true\n",
            previous = "",
        },
        {
            at = 82304,
            current = "L[\"Help.Announces.overview\"] = \"Announce selected spell casts or item uses independently of your active rotation, or invoke a configured Via Script/Macro entry directly. Select an entry in the sidebar, or use New to prepare one. The trigger applies to every ordered output card; each card has its own destination and conditions. These settings do not cast spells or use items. Cast-triggered announcements follow RM's combat-data policy and do not run on reference-only clients.\"\nL[\"Help.Announces.name\"] = \"An optional name identifies this announcement in the sidebar. Without one, the action name or Via Script/Macro identifier is used. Changing this display name does not change the watched action or callable identifier.\"\nL[\"Help.Announces.type\"] = \"Choose Spell, Pet Spell, Item or Via Script/Macro. Changing type clears the previous action and exact-rank choice. Via Script/Macro uses an Identifier instead of a cast event or stored action; switching back restores the event selector. Choosing the current type keeps its fields.\"\n",
            previous = "L[\"Help.Announces.overview\"] = \"Announce selected spell casts or item uses independently of your active rotation, or invoke a configured Via Macro entry directly. Select an entry in the sidebar, or use New to prepare one. The trigger applies to every ordered output card; each card has its own destination and conditions. These settings do not cast spells or use items. Cast-triggered announcements follow RM's combat-data policy and do not run on reference-only clients.\"\nL[\"Help.Announces.name\"] = \"An optional name identifies this announcement in the sidebar. Without one, the action name or Via Macro identifier is used. Changing this display name does not change the watched action or callable identifier.\"\nL[\"Help.Announces.type\"] = \"Choose Spell, Pet Spell, Item or Via Macro. Changing type clears the previous action and exact-rank choice. Via Macro uses an Identifier instead of a cast event or stored action; switching back restores the event selector. Choosing the current type keeps its fields.\"\n",
        },
        {
            at = 84616,
            current = "L[\"Help.Announces.event\"] = \"For automatic action types, choose which observed cast event triggers this entry. A start, stop, interruption, failure or delay is different from a successful cast. Client support determines which events and observations are available. Via Script/Macro has no cast event.\"\n",
            previous = "L[\"Help.Announces.event\"] = \"For automatic action types, choose which observed cast event triggers this entry. A start, stop, interruption, failure or delay is different from a successful cast. Client support determines which events and observations are available. Via Macro has no cast event.\"\n",
        },
        {
            at = 85744,
            current = "L[\"Help.Announces.announce\"] = \"Choose a chat destination, local output, a named Emote or Audible. Emote replaces Text with an emote selector and optional recipient. Audible replaces Text with Sound. Text is retained when switching modes. Say, Yell, Whisper and named joined channels are offered only for Via Script/Macro and remain subject to native restrictions.\"\n",
            previous = "L[\"Help.Announces.announce\"] = \"Choose a chat destination, local output, a named Emote or Audible. Emote replaces Text with an emote selector and optional recipient. Audible replaces Text with Sound. Text is retained when switching modes. Say, Yell, Whisper and named joined channels are offered only for Via Macro and remain subject to native restrictions.\"\n",
        },
        {
            at = 87066,
            current = "",
            previous = "L[\"Test /cheer\"] = true\nL[\"Emote report\"] = true\nL[\"Emote diagnostics\"] = true\nL[\"Help.Announces.diagnostics\"] = \"Test /cheer sends one targetless cheer when clicked and opens a copyable report. It does not apply pending settings or retry a spell announcement. Emote report opens the latest automatic-emote and click-test observations without sending anything. Call completion is not proof of visible output. Automatic Say and Yell are unavailable; saved entries retain their text and can be changed to another destination.\"\n",
        },
        {
            at = 87443,
            current = "L[\"Help.Announces.emote_target\"] = \"For cast entries, checked directs the emote to the recipient recorded for this exact cast, including click casting. It does not use your current target or a previous cast's recipient. For Via Script/Macro, checked uses the supplied macro unit. A missing recipient skips targeted output. Unchecked performs the emote without a target.\"\n",
            previous = "L[\"Help.Announces.emote_target\"] = \"For cast entries, checked directs the emote to the recipient recorded for this exact cast, including click casting. It does not use your current target or a previous cast's recipient. For Via Macro, checked uses the supplied macro unit. A missing recipient skips targeted output. Unchecked performs the emote without a target.\"\n",
        },
        {
            at = 88134,
            current = "L[\"Help.Announces.substitutions\"] = \"For cast entries, {{spell}} is a spell link, {{item}} an item link and {{event}} the localized event name. {{target}} uses the recorded cast target, with the last recorded target for that spell as a fallback; it does not automatically use your selected target or your name. Unavailable cast substitutions can remain unchanged. Via Script/Macro instead uses its supplied target and spell, {{event}} becomes Via Script/Macro, and required missing inputs skip output; this API supplies no {{item}}.\"\n",
            previous = "L[\"Help.Announces.substitutions\"] = \"For cast entries, {{spell}} is a spell link, {{item}} an item link and {{event}} the localized event name. {{target}} uses the recorded cast target, with the last recorded target for that spell as a fallback; it does not automatically use your selected target or your name. Unavailable cast substitutions can remain unchanged. Via Macro instead uses its supplied target and spell, {{event}} becomes Via Macro, and required missing inputs skip output; this API supplies no {{item}}.\"\n",
        },
        {
            at = 89121,
            current = "L[\"Help.Announces.save\"] = \"Edits stay in a draft until Apply. Complete the action or Via Script/Macro identifier and other required fields before saving. Discard abandons changes to saved announcements; Cancel closes a new creation draft. Leaving pending changes offers Apply, Discard or Cancel navigation.\"\nL[\"Help.Announces.collections\"] = \"Use the sidebar buttons to create, duplicate, transfer or compare announcements. Apply saves the imported draft; Compare does not merge entries. Via Script/Macro Duplicate assigns a distinct identifier and every copied output gets a fresh identity. Series exports use version 2; version 1 remains available for legacy single-output entries. Imports and Apply reject ambiguous identifiers. The red trash permanently deletes the selected saved entry after confirmation. Resolve pending edits first; deletion does not carry into the next selected draft.\"\n",
            previous = "L[\"Help.Announces.save\"] = \"Edits stay in a draft until Apply. Complete the action or Via Macro identifier and other required fields before saving. Discard abandons changes to saved announcements; Cancel closes a new creation draft. Leaving pending changes offers Apply, Discard or Cancel navigation.\"\nL[\"Help.Announces.collections\"] = \"Use the sidebar buttons to create, duplicate, transfer or compare announcements. Apply saves the imported draft; Compare does not merge entries. Via Macro Duplicate assigns a distinct identifier and every copied output gets a fresh identity. Series exports use version 2; version 1 remains available for legacy single-output entries. Imports and Apply reject ambiguous identifiers. The red trash permanently deletes the selected saved entry after confirmation. Resolve pending edits first; deletion does not carry into the next selected draft.\"\n",
        },
        {
            at = 91472,
            current = "L[\"Help.ItemSets.items\"] = \"The list of item cards is the priority order. Put preferred items first. RM can leave a selection unavailable when required inventory or identity observations are missing; it does not treat unknown data as proof that a lower-priority item should be used. The sidebar icon represents the first defined item and need not be the currently carried or highlighted one.\"\n",
            previous = "L[\"Help.ItemSets.items\"] = \"Click the heading to hide or show the list. Put preferred items first. RM can leave a selection unavailable when required inventory or identity observations are missing; it does not treat unknown data as proof that a lower-priority item should be used. The sidebar icon represents the first defined item and need not be the currently carried or highlighted one.\"\n",
        },
        {
            at = 92170,
            current = "L[\"Help.ItemSets.add\"] = \"Choose or drag an item into the empty item field above the list, then click Add item to append it to the priority list, or drag Add item into a gap between cards to insert it there. Entering an item in this field alone does not add a row.\"\n",
            previous = "L[\"Help.ItemSets.add\"] = \"Choose or drag an item into the empty Item field, then click Add item to append it to the priority list. Entering an item in this field alone does not add a row.\"\n",
        },
        {
            at = 92832,
            current = "L[\"Help.ItemSets.binding\"] = \"Outside combat, apply pending item-set edits before binding. Drag the set (its row in the list, or the Bind pill) onto any action bar slot; an occupied slot swaps, leaving its previous action on the cursor. Or click Bind and then click an empty slot. Both pick up the first available item of the set. RM records the slot and updates it as item availability changes. The pill shows bound slot numbers; click it to unbind and remove still-matching bar items. Replaced bar actions are preserved. Binding changes are immediate action-bar operations, independent of the draft and its history.\"\n",
            previous = "L[\"Help.ItemSets.binding\"] = \"Outside combat, apply pending item-set edits before binding. Bind picks up an available item for you to place on an action bar. RM records the slot and updates it as item availability changes. The pill shows bound slot numbers; click it to unbind and remove still-matching bar items. Replaced bar actions are preserved. Binding changes are immediate action-bar operations, independent of the draft and its history.\"\n",
        },
        {
            at = 126915,
            current = "L[\"Help.General.idle_poll\"] = \"Out of combat with no target and no focus, Rotation Master skips a polling tick unless something it watches has changed: auras, cooldowns, health or power of you, your pet or party, movement, casting, equipment, bags, form, pets or group. It still re-checks at least this often, for time-based conditions (aura or cooldown remaining), distance, and custom code. In combat, with any target or focus, or while configuration is open, every polling tick is evaluated. Zero evaluates every polling tick.\"\nL[\"Help.General.autoswitch_poll\"] = \"With automatic switching, Rotation Master checks this often, in and out of combat, whether a different rotation's switch conditions now match, so conditions that change on their own (nearby enemy count, threat, movement, health) take effect. Target, focus and pet changes are checked straight away. Zero turns automatic switching off. Choosing a rotation manually still overrides automatic switching until you choose Auto again.\"\n",
            previous = "",
        },
        {
            at = 139456,
            current = "L[\"Help.Effects.sequence\"] = \"Sequence cards play in order and repeat. Add step, on the Sequence header row, appends a card; drag Add step into a gap to insert one there. Drag a card into an insertion gap to reorder it; hold Ctrl when starting to carry it and all following cards. Up and Down move one card and are disabled at their respective ends. The red trash removes a card from the draft. Canceling a drag restores its original position.\"\n",
            previous = "L[\"Help.Effects.sequence\"] = \"Sequence cards play in order and repeat. Add step appends a card. Drag a card into an insertion gap to reorder it; hold Ctrl when starting to carry it and all following cards. Up and Down move one card and are disabled at their respective ends. The red trash removes a card from the draft. Canceling a drag restores its original position.\"\n",
        },
        { at = 156905, current = "", previous = "L[\"Stock targets\"] = true\n" },
        { at = 156906, current = "", previous = "L[\"Reset targets\"] = true\n" },
        { at = 156907, current = "", previous = "L[\"Reset invalid stock targets? This cannot be undone.\"] = true\n" },
        { at = 156908, current = "", previous = "L[\"Add stock target\"] = true\n" },
        { at = 156909, current = "", previous = "L[\"No stock targets.\"] = true\n" },
        { at = 156930, current = "", previous = "L[\"Complete the stock target settings before applying.\"] = true\n" },
        {
            at = 157164,
            current = "",
            previous = "L[\"All saved minimums met.\"] = true\nL[\"No enabled saved targets.\"] = true\nL[\"%d saved targets below minimum.\"] = true\nL[\"%d below minimum; %d unknown.\"] = true\nL[\"Saved stock counts pending.\"] = true\nL[\"Apply or discard page changes to assess saved targets.\"] = true\nL[\"Saved stock readiness unavailable.\"] = true\n",
        },
        { at = 157165, current = "", previous = "L[\"Stock counts pending.\"] = true\n" },
        { at = 157166, current = "", previous = "L[\"Stock counts ready.\"] = true\n" },
        { at = 157167, current = "", previous = "L[\"Stock counts unavailable.\"] = true\n" },
        { at = 157168, current = "", previous = "L[\"Carried: %s\"] = true\n" },
        { at = 157169, current = "", previous = "L[\"Shortage: %s\"] = true\n" },
        { at = 157170, current = "", previous = "L[\"Copy shortage list\"] = true\n" },
        {
            at = 157171,
            current = "",
            previous = "L[\"Apply or discard page changes and refresh stock counts before copying.\"] = true\n",
        },
        { at = 157172, current = "", previous = "L[\"Stock shortage list\"] = true\n" },
        {
            at = 164764,
            current = "L[\"Stop CPU capture\"] = true\nL[\"Stop runtime capture\"] = true\nL[\"Stop cast capture\"] = true\nL[\"Help.General.cast_capture\"] = \"Record spell cast receipts for thirty seconds without changing settings or gameplay polling. While it runs this button reads Stop cast capture and ends the capture early, keeping what was recorded.\"\nL[\"Help.General.cast_report\"] = \"Open the copyable cast receipt report. It stays disabled until a cast capture has produced a report and while a capture is running.\"\n",
            previous = "",
        },
        {
            at = 186466,
            current = "L[\"Help.Announces.conditions\"] = \"Optional conditions use the Announcement condition list and All, Any and Not groups. For spell, pet and item announcements, they run when the configured action and event match. For Via Script/Macro, they run when you invoke the saved identifier. Each output card checks its own conditions. Only a matching result allows that output; unavailable data skips that card while later cards remain independent. In Group can check the Spell recipient recorded for this cast, including click casting, without using your selected target. Choose Announcement target to check the spell recipient for automatic entries, or the supplied unit for Via Script/Macro; Whisper uses that same supplied unit. Automatic entries pass the recorded recipient name to native unit queries. A missing or unresolvable recipient skips its required condition; an unrelated selected target is never substituted. Missing or ambiguous required recipients do not match. Apply in the condition editor updates the announcement draft; Apply on Announces saves it. Cancel or Discard abandons draft changes.\"\n",
            previous = "L[\"Help.Announces.conditions\"] = \"Optional conditions use the Announcement condition list and All, Any and Not groups. For spell, pet and item announcements, they run when the configured action and event match. For Via Macro, they run when you invoke the saved identifier. Each output card checks its own conditions. Only a matching result allows that output; unavailable data skips that card while later cards remain independent. In Group can check the Spell recipient recorded for this cast, including click casting, without using your selected target. Choose Announcement target to check the spell recipient for automatic entries, or the supplied unit for Via Macro; Whisper uses that same supplied unit. Automatic entries pass the recorded recipient name to native unit queries. A missing or unresolvable recipient skips its required condition; an unrelated selected target is never substituted. Missing or ambiguous required recipients do not match. Apply in the condition editor updates the announcement draft; Apply on Announces saves it. Cancel or Discard abandons draft changes.\"\n",
        },
        {
            at = 196044,
            current = "L[\"Via Script/Macro\"] = true\nL[\"Use a unique Via Script/Macro identifier.\"] = true\n",
            previous = "",
        },
        { at = 196259, current = "", previous = "L[\"Use a unique Via Macro identifier.\"] = true\n" },
        {
            at = 196477,
            current = "L[\"Help.Announces.type.macro\"] = \"Via Script/Macro is invoked by its saved Identifier rather than a cast event. It does not require a stored spell or item. Current conditions must match before any output. This call attempts output synchronously; it does not establish that a spell was cast or succeeded.\"\n",
            previous = "L[\"Help.Announces.type.macro\"] = \"Via Macro is invoked by its saved Identifier rather than a cast event. It does not require a stored spell or item. Current conditions must match before any output. This call attempts output synchronously; it does not establish that a spell was cast or succeeded.\"\n",
        },
        {
            at = 197145,
            current = "L[\"Help.Announces.macro.example\"] = \"Use /run RM_Annouce('FOO','mouseover',nil). RM_Announce is the same function. The target unit and spell are optional: /run RM_Announce('FOO',nil,403) or /run RM_Announce('FOO','target','Lightning Bolt'). Spell names depend on client language. {{event}} becomes Via Script/Macro; {{target}} and {{spell}} use the supplied arguments. A required missing argument skips output. {{item}} is not supplied by this API. A resurrection message announces an attempt, not a completed resurrection. Examples are text only; RM does not create or execute macros.\"\n",
            previous = "L[\"Help.Announces.macro.example\"] = \"Use /run RM_Annouce('FOO','mouseover',nil). RM_Announce is the same function. The target unit and spell are optional: /run RM_Announce('FOO',nil,403) or /run RM_Announce('FOO','target','Lightning Bolt'). Spell names depend on client language. {{event}} becomes Via Macro; {{target}} and {{spell}} use the supplied arguments. A required missing argument skips output. {{item}} is not supplied by this API. A resurrection message announces an attempt, not a completed resurrection. Examples are text only; RM does not create or execute macros.\"\n",
        },
        {
            at = 198337,
            current = "L[\"Help.Announces.channel.say\"] = \"Available only for Via Script/Macro. Attempt a Say message directly in the invoking call. Blizzard may reject macro-origin chat, including during instance encounters; RM does not attest hardware input, defer delivery, retry or guarantee visible output.\"\nL[\"Help.Announces.channel.yell\"] = \"Available only for Via Script/Macro. Attempt a Yell message directly in the invoking call. Native macro and encounter restrictions still apply; a completed API call is not confirmation of delivery.\"\nL[\"Help.Announces.channel.whisper\"] = \"Available only for Via Script/Macro. Whisper uses the exact supplied unit name and requires a readable player identity. No target means no Whisper. Native macro and encounter restrictions still apply; RM never substitutes another recipient or retries.\"\n",
            previous = "L[\"Help.Announces.channel.say\"] = \"Available only for Via Macro. Attempt a Say message directly in the invoking call. Blizzard may reject macro-origin chat, including during instance encounters; RM does not attest hardware input, defer delivery, retry or guarantee visible output.\"\nL[\"Help.Announces.channel.yell\"] = \"Available only for Via Macro. Attempt a Yell message directly in the invoking call. Native macro and encounter restrictions still apply; a completed API call is not confirmation of delivery.\"\nL[\"Help.Announces.channel.whisper\"] = \"Available only for Via Macro. Whisper uses the exact supplied unit name and requires a readable player identity. No target means no Whisper. Native macro and encounter restrictions still apply; RM never substitutes another recipient or retries.\"\n",
        },
        {
            at = 199832,
            current = "L['Help.Announces.outputs']='One trigger can send an ordered series of outputs. Each expanded card has its own destination, text or sound, conditions and enabled state. Help describes that card. Duplicate makes an independent card; delete removes it. Use the arrows, or drag a card from anywhere on it, to change order. Add output, on the Outputs header row, appends a card; drag it into a gap to insert one there. A legacy announcement stays unchanged on display. Adding, duplicating or removing a card, choosing Channel, or changing to an action type that cannot use its saved destination converts only the draft to output cards. Up to 64 outputs are allowed; an empty series sends nothing. Apply saves the draft and Discard restores it.'\nL['Help.Announces.channel.channel']='Via Script/Macro outputs can send to a joined chat channel. Open Channel to refresh the joined names, then select the exact name. A saved name remains visible when unavailable; that output is skipped until the channel is joined under that name. Numeric channel IDs are not saved and channels are never joined automatically. Native delivery permissions still apply.'\n",
            previous = "L['Help.Announces.outputs']='One trigger can send an ordered series of outputs. Each expanded card has its own destination, text or sound, conditions and enabled state. Help describes that card. Duplicate makes an independent card; delete removes it. Use the arrows or drag a card to change order. A legacy announcement stays unchanged on display. Adding, duplicating or removing a card, choosing Channel, or changing to an action type that cannot use its saved destination converts only the draft to output cards. Up to 64 outputs are allowed; an empty series sends nothing. Apply saves the draft and Discard restores it.'\nL['Help.Announces.channel.channel']='Via Macro outputs can send to a joined chat channel. Open Channel to refresh the joined names, then select the exact name. A saved name remains visible when unavailable; that output is skipped until the channel is joined under that name. Numeric channel IDs are not saved and channels are never joined automatically. Native delivery permissions still apply.'\n",
        },
        {
            at = 200977,
            current = "L['Choose an announcement trigger, then edit its always expanded output cards. Each card has a destination, conditions, enabled state and Help. Add, duplicate, delete, move or drag outputs within the announcement. Joined channel names are available for Via Script/Macro. New opens a draft; Apply saves it and Discard restores it. Imports are validated and never execute code.']='Choose an announcement trigger, then edit its always expanded output cards. Each card has a destination, conditions, enabled state and Help. Add, duplicate, delete, move or drag outputs within the announcement. Joined channel names are available for Via Script/Macro. New opens a draft; Apply saves it and Discard restores it. Imports are validated and never execute code.'\n",
            previous = "L['Choose an announcement trigger, then edit its always expanded output cards. Each card has a destination, conditions, enabled state and Help. Add, duplicate, delete, move or drag outputs within the announcement. Joined channel names are available for Via Macro. New opens a draft; Apply saves it and Discard restores it. Imports are validated and never execute code.']='Choose an announcement trigger, then edit its always expanded output cards. Each card has a destination, conditions, enabled state and Help. Add, duplicate, delete, move or drag outputs within the announcement. Joined channel names are available for Via Macro. New opens a draft; Apply saves it and Discard restores it. Imports are validated and never execute code.'\n",
        },
    },
}

records["RotationMaster.toc"] = {
    bytes = 8284,
    hash = 3602199701,
    oldBytes = 8333,
    oldHash = 3667809674,
    changes = {
        { at = 3007, current = "", previous = "Core/stock_targets.lua\n" },
        { at = 4798, current = "", previous = "UI/stock_profile_safety.lua\n" },
        { at = 5202, current = "", previous = "UI/settings_stock.lua\n" },
        { at = 5224, current = "UI/item_set_binding.lua\n", previous = "" },
    },
}

records["tests/fixtures/addon.lua"] = {
    bytes = 7144,
    hash = 3632122966,
    oldBytes = 7241,
    oldHash = 186603638,
    changes = {
        {
            at = 5312,
            current = "    load('UI/controls.lua');load('UI/condition_widgets.lua');load('UI/condition_observation.lua');load('UI/condition_icon.lua');load('UI/condition_position.lua');load('UI/condition_display.lua');load('UI/drag_presentation.lua');load('Core/unsaved_changes.lua');load('UI/unsaved.lua');load('UI/settings_draft.lua');load('UI/collection_compare.lua');load('UI/draft_changes.lua');load('UI/draft_change_controls.lua');load('UI/window.lua');load('UI/selector.lua');load('UI/tag_picker.lua');load('UI/checkbox.lua');load('UI/condition_inputs.lua');load('UI/condition_layout.lua');load('UI/condition_table.lua');load('UI/condition_unit.lua');load('Core/item_conditions.lua');load('Core/rotation_references.lua');load('Help/common.lua'); load('Help/conditional.lua'); load('Core/presentation.lua');load('Core/condition_description.lua'); load('Core/spell_catalog.lua');load('Core/spell_search.lua');load('Core/reference_catalog.lua');load('Core/category_data.lua');load('Core/announcement_data.lua');load('Core/profile_data.lua');load('Core/collection_data.lua');load('Core/custom_condition_data.lua');load('Core/functions.lua');load('UI/spell_search.lua');load('UI/spell_icon.lua')\n",
            previous = "    load('UI/controls.lua');load('UI/condition_widgets.lua');load('UI/condition_observation.lua');load('UI/condition_icon.lua');load('UI/condition_position.lua');load('UI/condition_display.lua');load('UI/drag_presentation.lua');load('Core/unsaved_changes.lua');load('UI/unsaved.lua');load('Core/stock_targets.lua');load('UI/stock_profile_safety.lua');load('UI/settings_stock.lua');load('UI/settings_draft.lua');load('UI/collection_compare.lua');load('UI/draft_changes.lua');load('UI/draft_change_controls.lua');load('UI/window.lua');load('UI/selector.lua');load('UI/tag_picker.lua');load('UI/checkbox.lua');load('UI/condition_inputs.lua');load('UI/condition_layout.lua');load('UI/condition_table.lua');load('UI/condition_unit.lua');load('Core/item_conditions.lua');load('Core/rotation_references.lua');load('Help/common.lua'); load('Help/conditional.lua'); load('Core/presentation.lua');load('Core/condition_description.lua'); load('Core/spell_catalog.lua');load('Core/spell_search.lua');load('Core/reference_catalog.lua');load('Core/category_data.lua');load('Core/announcement_data.lua');load('Core/profile_data.lua');load('Core/collection_data.lua');load('Core/custom_condition_data.lua');load('Core/functions.lua');load('UI/spell_search.lua');load('UI/spell_icon.lua')\n",
        },
    },
}

records["tools/check"] = {
    bytes = 46587,
    hash = 3984742385,
    oldBytes = 46207,
    oldHash = 3900218271,
    changes = {
        {
            at = 23807,
            current = "            ['lua5.1', 'tests/idle_gate.lua'],\n            ['luajit', 'tests/idle_gate.lua'],\n            ['lua5.1', 'tests/lean_parity.lua'],\n            ['luajit', 'tests/lean_parity.lua'],\n            ['lua5.1', 'tests/native_overlay_animation.lua'],\n            ['luajit', 'tests/native_overlay_animation.lua'],\n            ['lua5.1', 'tests/item_set_unbind.lua'],\n            ['luajit', 'tests/item_set_unbind.lua'],\n            ['lua5.1', 'tests/auto_switch_recheck.lua'],\n            ['luajit', 'tests/auto_switch_recheck.lua'],\n",
            previous = "",
        },
        {
            at = 39461,
            current = "",
            previous = "            ['lua5.1', 'tests/stock_targets.lua'],\n            ['luajit', 'tests/stock_targets.lua'],\n            ['lua5.1', 'tests/stock_targets_profiles.lua'],\n            ['luajit', 'tests/stock_targets_profiles.lua'],\n",
        },
        {
            at = 40231,
            current = "",
            previous = "            ['lua5.1', 'tests/stock_targets_observation.lua'],\n            ['luajit', 'tests/stock_targets_observation.lua'],\n            ['lua5.1', 'tests/stock_readiness.lua'],\n            ['luajit', 'tests/stock_readiness.lua'],\n            ['lua5.1', 'tests/stock_targets_ui.lua'],\n            ['luajit', 'tests/stock_targets_ui.lua'],\n",
        },
        {
            at = 40355,
            current = "",
            previous = "            ['lua5.1', 'tests/stock_targets_safety_ui.lua'],\n            ['luajit', 'tests/stock_targets_safety_ui.lua'],\n",
        },
        {
            at = 41252,
            current = "            ['lua5.1', 'tests/workbench_resize.lua'],\n            ['luajit', 'tests/workbench_resize.lua'],\n            ['lua5.1', 'tests/workbench_reflow.lua'],\n            ['luajit', 'tests/workbench_reflow.lua'],\n            ['lua5.1', 'tests/stock_retired.lua'],\n            ['luajit', 'tests/stock_retired.lua'],\n            ['lua5.1', 'tests/ordered_cards.lua'],\n            ['luajit', 'tests/ordered_cards.lua'],\n            ['lua5.1', 'tests/item_set_binding.lua'],\n            ['luajit', 'tests/item_set_binding.lua'],\n",
            previous = "",
        },
    },
}

records["UI/analytics_capture.lua"] = {
    bytes = 10861,
    hash = 2499424663,
    oldBytes = 10418,
    oldHash = 3077508178,
    changes = {
        {
            at = 1361,
            current = "end\n-- Running state is cheap. The report check copies the last snapshot, so\n-- callers ask for it only when the running state changes.\nfunction addon:GetCastCaptureState(withReport)\n if not rawequal(self,addon)then return nil end\n local p=phase();local running=p=='running'or p=='starting'\n if not withReport then return running end\n if running or not owned()then return running,false end\n return running,type(invoke('GetSnapshot'))=='table'\n",
            previous = "",
        },
    },
}

records["UI/collection_compare.lua"] = {
    bytes = 14017,
    hash = 1295190649,
    oldBytes = 13908,
    oldHash = 1548309674,
    changes = {
        {
            at = 1312,
            current = "        local labels={lua_editor=L['Lua editor'],identifier=L['Identifier'],definition=L['Definition'],enable=L['Enable'],poll=L['Polling Interval (seconds)'],idle_poll=L['Idle Re-check Interval (seconds)'],autoswitch_poll=L['Auto-Switch Re-check Interval (seconds)'],ignore_mana=L['Ignore mana'],ignore_range=L['Ignore range'],effect=L['Effect'],color=L['Highlight Color'],magnification=L['Magnification'],setpoint=L['Anchor'],xoffs=L['H'],yoffs=L['V'],loglevel=L['Log Level'],detailed_profiling=L['Detailed Profiling'],disable_autoswitch=L['Disable Auto-Switching'],live_config_update=L['Live Status Update Frequency (seconds)'],spell_history=L['Spell History Memory (seconds)'],combat_history=L['Combat History Memory (seconds)'],damage_history=L['Damage History Memory (seconds)'],disable_buttons=L['Disable Bar Highlighting'],rotation_view=L['Default rotation view'],preview_spells=L['Preview Spells'],preview_window=L['Preview position'],minimap=L['Minimap Icon'],rotations=L['Rotations'],rotationLibrary=L['Rotation library'],itemsets=L['Item Sets'],announces=L['Announces'],outputs=L['Outputs'],channel_name=L['Channel'],condition_groups=L['Categories'],switch_conditions=L['Switch conditions'],other_conditions_order=L['Other'],disabled_conditions=L['Hidden'],name=L['Name'],description=L['Description'],conditions=L['Conditions'],rotation=L['Rotation'],cooldowns=L['Cooldowns'],type=L['Type'],action=L['Action'],unit=L['Unit'],value=L['Value'],spell=L['Spell'],item=L['Item'],items=L['Items'],disabled=L['Disabled'],announce=L['Announce'],event=L['Event'],announce_sound=L['Sound'],emote=L['Emote'],emote_target=L['Use spell recipient ({{target}})'],ranked=L['Use this exact spell rank'],use_name=L['Use step name'],suppress_attack=L['Also suppress implicit Attack'],preview_vertical=L['Vertical'],preview_locked=L['Lock position and size'],preview_opacity=L['Preview window opacity'],preview_icon_size=L['Preview icon size'],preview_masque=L['Skin preview buttons with Masque'],evaluate=L['Evaluate'],valid=L['Validate'],print=L['Summary'],widget=L['Fields UI'],help=L['Help'],on_register=L['On register'],on_unregister=L['On unregister'],preferences=L['Built In preferences'],origins=L['Clone sources'],comparisons=L['Comparison history'],imports=L['Imports']}\n",
            previous = "        local labels={lua_editor=L['Lua editor'],identifier=L['Identifier'],definition=L['Definition'],enable=L['Enable'],poll=L['Polling Interval (seconds)'],ignore_mana=L['Ignore mana'],ignore_range=L['Ignore range'],effect=L['Effect'],color=L['Highlight Color'],magnification=L['Magnification'],setpoint=L['Anchor'],xoffs=L['H'],yoffs=L['V'],loglevel=L['Log Level'],detailed_profiling=L['Detailed Profiling'],disable_autoswitch=L['Disable Auto-Switching'],live_config_update=L['Live Status Update Frequency (seconds)'],spell_history=L['Spell History Memory (seconds)'],combat_history=L['Combat History Memory (seconds)'],damage_history=L['Damage History Memory (seconds)'],disable_buttons=L['Disable Bar Highlighting'],rotation_view=L['Default rotation view'],preview_spells=L['Preview Spells'],preview_window=L['Preview position'],minimap=L['Minimap Icon'],rotations=L['Rotations'],rotationLibrary=L['Rotation library'],itemsets=L['Item Sets'],announces=L['Announces'],outputs=L['Outputs'],channel_name=L['Channel'],condition_groups=L['Categories'],switch_conditions=L['Switch conditions'],other_conditions_order=L['Other'],disabled_conditions=L['Hidden'],name=L['Name'],description=L['Description'],conditions=L['Conditions'],rotation=L['Rotation'],cooldowns=L['Cooldowns'],type=L['Type'],action=L['Action'],unit=L['Unit'],value=L['Value'],spell=L['Spell'],item=L['Item'],items=L['Items'],disabled=L['Disabled'],announce=L['Announce'],event=L['Event'],announce_sound=L['Sound'],emote=L['Emote'],emote_target=L['Use spell recipient ({{target}})'],ranked=L['Use this exact spell rank'],use_name=L['Use step name'],suppress_attack=L['Also suppress implicit Attack'],preview_vertical=L['Vertical'],preview_locked=L['Lock position and size'],preview_opacity=L['Preview window opacity'],preview_icon_size=L['Preview icon size'],preview_masque=L['Skin preview buttons with Masque'],evaluate=L['Evaluate'],valid=L['Validate'],print=L['Summary'],widget=L['Fields UI'],help=L['Help'],on_register=L['On register'],on_unregister=L['On unregister'],preferences=L['Built In preferences'],origins=L['Clone sources'],comparisons=L['Comparison history'],imports=L['Imports']}\n",
        },
    },
}

records["UI/condition_canvas.lua"] = {
    bytes = 29386,
    hash = 2876960082,
    oldBytes = 26134,
    oldHash = 3503934404,
    changes = {
        {
            at = 3272,
            current = "        self.drag=nil;self.box=nil;if self.boxFrame then self.boxFrame:Hide() end;ghost:Hide();addon:SetUIScript(self.frame,\"OnUpdate\",nil)\n",
            previous = "        self.drag=nil;ghost:Hide();addon:SetUIScript(self.frame,\"OnUpdate\",nil)\n",
        },
        {
            at = 9617,
            current = "    -- Shift-drag on empty canvas draws a box selecting the cards it touches\n    -- (Ctrl+Shift adds to the selection); a card inside another touched card\n    -- travels with it, as with Ctrl-click.\n    function canvas:SelectBox(left,top,right,bottom,additive)\n        if not owner.active or not self.scene or not owner:SyncWorking() then return end\n        local touched={}\n        for _,model in ipairs(self.scene.cards) do\n            -- A group's frame encloses its children; only its own header counts.\n            local height=model.group and model.ownHeight or model.height\n            if model.path and model.x<=right and model.x+model.width>=left and model.y<=bottom and model.y+height>=top then touched[#touched+1]=model end\n        end\n        local selection=additive and owner.view.selection or {}\n        local rows=owner.active.session:Rows(4096)\n        for _,model in ipairs(touched) do\n            local inside=false\n            for _,other in ipairs(touched) do if other~=model and #other.path<#model.path and prefix(other.path,model.path) then inside=true;break end end\n            if not inside then\n                for _,row in ipairs(rows) do if prefix(row.path,model.path) or prefix(model.path,row.path) then selection[addon.ConditionPathKey(row.path)]=nil end end\n                selection[addon.ConditionPathKey(model.path)]=true\n            end\n        end\n        owner.view.selection=selection\n        if (#self:Selection()>1)~=owner.selectionStrip then owner:Layout() else self:Reflow() end\n    end\n    function canvas:BeginBoxSelect()\n        if not owner.active or self.drag then return false end\n        local x,y=addon:WorkbenchPointerIn(self.child);if not x then return false end\n        self:CancelDrag()\n        local box={x=x,y=y,additive=IsControlKeyDown and IsControlKeyDown() or false,generation=self.generation};self.box=box\n        self.boxFrame=self.boxFrame or addon:CreateWorkbenchSelectionBox(self.child);self.boxFrame:Place(x,y,x,y)\n        addon:SetUIScript(self.frame,\"OnUpdate\",function()\n            if self.box~=box then return end\n            if not owner.active or box.generation~=self.generation then self:CancelDrag();return end\n            local cx,cy=addon:WorkbenchPointerIn(self.child);if cx then box.cx,box.cy=cx,cy;self.boxFrame:Place(box.x,box.y,cx,cy) end\n            if IsMouseButtonDown and not IsMouseButtonDown(\"LeftButton\") then self:EndBoxSelect() end\n        end)\n        return true\n    end\n    function canvas:EndBoxSelect()\n        local box=self.box;if not box then return end\n        local cx,cy=box.cx or box.x,box.cy or box.y;self:CancelDrag()\n        self:SelectBox(math.min(box.x,cx),math.min(box.y,cy),math.max(box.x,cx),math.max(box.y,cy),box.additive)\n    end\n    for _,surface in ipairs({canvas.frame,canvas.child}) do\n        surface:EnableMouse(true)\n        addon:SetUIScript(surface,\"OnMouseDown\",function(_,button) if button==\"LeftButton\" and IsShiftKeyDown and IsShiftKeyDown() then canvas:BeginBoxSelect() end end)\n        addon:SetUIScript(surface,\"OnMouseUp\",function(_,button) if button==\"LeftButton\" and canvas.box then canvas:EndBoxSelect() end end)\n    end\n    local horizontal=addon:CreateWorkbenchScrollBar(parent,'HORIZONTAL');addon:TrackWorkbenchSize(horizontal);canvas.horizontal=horizontal\n",
            previous = "    local horizontal=addon:CreateWorkbenchScrollBar(parent,'HORIZONTAL');canvas.horizontal=horizontal\n",
        },
    },
}

records["UI/condition_editor.lua"] = {
    bytes = 42802,
    hash = 1178542009,
    oldBytes = 41404,
    oldHash = 2820911158,
    changes = {
        {
            at = 3187,
            current = "    local window=addon:TrackWorkbenchSize(CreateFrame(\"Frame\",nil,UIParent))\n",
            previous = "    local window=CreateFrame(\"Frame\",nil,UIParent)\n",
        },
        {
            at = 35384,
            current = "    -- The same selection-wide actions as the rotation editor, one undo step each.\n    shell.selectionActions={}\n    for _,entry in ipairs({{\"duplicate\",\"copy\",L[\"Duplicate selected cards\"],function() shell:SelectedCommand(\"DuplicateSelection\") end},\n        {\"enable\",\"check\",L[\"Enable selected cards\"],function() shell:SelectedCommand(\"SetSelectionDisabled\",false) end},\n        {\"disable\",\"minus\",L[\"Disable selected cards\"],function() shell:SelectedCommand(\"SetSelectionDisabled\",true) end},\n        {\"remove\",\"trash\",L[\"Delete selected cards\"],function() shell:SelectedCommand(\"RemoveSelection\") end}}) do\n        local control=addon:CreateWorkbenchIconButton(window,entry[2],entry[3]);control:SetSize(20,20);control:Hide()\n        if entry[1]==\"remove\" then control.icon:SetVertexColor(1,.3,.3,1) end\n        addon:SetUIScript(control,\"OnClick\",function() if shell.active then entry[4]() end end)\n        shell.selectionActions[#shell.selectionActions+1]=control;shell[\"selection_\"..entry[1]]=control\n    end\n",
            previous = "",
        },
        {
            at = 39291,
            current = "            for i,control in ipairs(self.selectionActions) do\n                control:ClearAllPoints();control:SetPoint(\"TOPLEFT\",352+(i-1)*22,-top+32);control:Show()\n                if self.active and self.active.readOnly then control:Disable() else control:Enable() end\n            end\n        else self.selectionLabel:Hide();self.groupAll:Hide();self.groupAny:Hide();for _,control in ipairs(self.selectionActions) do control:Hide() end end\n",
            previous = "        else self.selectionLabel:Hide();self.groupAll:Hide();self.groupAny:Hide() end\n",
        },
    },
}

records["UI/condition_source_pane.lua"] = {
    bytes = 13507,
    hash = 2474746448,
    oldBytes = 13481,
    oldHash = 887567564,
    changes = {
        {
            at = 3843,
            current = "    local options={readOnly=readOnly,parent=p.frame,x=geometry.detailX,footer=p.frame,width=geometry.detailWidth-self:GetWorkbenchHelpReserve(p.frame),height=math.max(160,p.frame:GetHeight()-34),editor=p.inlineEditorCache,resume=p.inlineResume};p.inlineResume=nil\n",
            previous = "    local options={readOnly=readOnly,parent=p.frame,x=geometry.detailX,footer=p.frame,width=geometry.detailWidth,height=math.max(160,p.frame:GetHeight()-34),editor=p.inlineEditorCache,resume=p.inlineResume};p.inlineResume=nil\n",
        },
        {
            at = 4886,
            current = "        local hidden=form:Check('hidden',L['Hidden'],context.hidden,function(value) d.model:Change(function(model) model.context.hidden=value end);d:UpdateActions() end)\n        local switch=form:Check('switch',L['Switch Condition'],context.switch,function(value) d.model:Change(function(model) model.context.switch=value end);d:UpdateActions() end)\n",
            previous = "        local checkWidth=(form.width-148)/2\n        local hidden=form:Check('hidden',L['Hidden'],context.hidden,function(value) d.model:Change(function(model) model.context.hidden=value end);d:UpdateActions() end);hidden:SetWidth(checkWidth);hidden:GetFontString():SetWidth(checkWidth-22)\n        local switch=form:Check('switch',L['Switch Condition'],context.switch,function(value) d.model:Change(function(model) model.context.switch=value end);d:UpdateActions() end);switch:ClearAllPoints();switch:SetPoint('TOPLEFT',checkWidth+8,-y);switch:SetWidth(checkWidth);switch:GetFontString():SetWidth(checkWidth-22);form.y=form.y-28\n",
        },
        {
            at = 5602,
            current = "        -- The three flags share their row in thirds (the Enabled pill and\n        -- Delete keep the right end) and wrap rather than clip when narrow.\n        self:LayoutConditionFlags(hidden,switch,announcement,y,form.width-148);form.y=y+hidden.rmFlagRowsHeight+2\n",
            previous = "",
        },
    },
}

records["UI/config.lua"] = {
    bytes = 25809,
    hash = 2946254545,
    oldBytes = 23345,
    oldHash = 38627145,
    changes = {
        {
            at = 3272,
            current = "    local window=addon:TrackWorkbenchSize(CreateFrame(\"Frame\",nil,UIParent))\n",
            previous = "    local window=CreateFrame(\"Frame\",nil,UIParent)\n",
        },
        {
            at = 3587,
            current = "    local layout=addon.WorkbenchLayout;local minimumWidth,minimumHeight=layout.windowMinWidth,layout.windowMinHeight\n",
            previous = "    if window.SetResizeBounds then window:SetResizeBounds(800,500) end\n",
        },
        {
            at = 3771,
            current = "    -- Sizing stays within the supported minimum and the visible screen. Older\n    -- clients only provide SetMinResize, and a size restored or set by another\n    -- addon is corrected on the next layout as well.\n    function shell:ApplySizeBounds()\n        local scale=window:GetScale() or 1;if scale<=0 then scale=1 end\n        local screenWidth=UIParent and UIParent.GetWidth and UIParent:GetWidth();local screenHeight=UIParent and UIParent.GetHeight and UIParent:GetHeight()\n        -- A screen smaller than the minimum cannot bound the window usefully.\n        local maximumWidth=type(screenWidth)=='number' and screenWidth/scale>=minimumWidth and math.floor(screenWidth/scale) or nil\n        local maximumHeight=type(screenHeight)=='number' and screenHeight/scale>=minimumHeight and math.floor(screenHeight/scale) or nil\n        self.maximumWidth,self.maximumHeight=maximumWidth,maximumHeight\n        if window.SetResizeBounds then\n            window:SetResizeBounds(minimumWidth,minimumHeight,maximumWidth or 100000,maximumHeight or 100000)\n        else\n            if window.SetMinResize then window:SetMinResize(minimumWidth,minimumHeight) end\n            if window.SetMaxResize then window:SetMaxResize(maximumWidth or 100000,maximumHeight or 100000) end\n        end\n        return self:ClampSize()\n    end\n    -- Returns true when the size had to be corrected.\n    function shell:ClampSize()\n        local width,height=window:GetWidth(),window:GetHeight()\n        local wantedWidth=math.max(minimumWidth,self.maximumWidth and math.min(width,self.maximumWidth) or width)\n        local wantedHeight=math.max(minimumHeight,self.maximumHeight and math.min(height,self.maximumHeight) or height)\n        if wantedWidth==width and wantedHeight==height then return false end\n        window:SetSize(wantedWidth,wantedHeight);return true\n    end\n",
            previous = "",
        },
        {
            at = 8690,
            current = "    local content=addon:TrackWorkbenchSize(CreateFrame(\"Frame\",nil,window));shell.content=content;content:EnableMouse(true)\n    -- The page \"?\" sits in the top-right corner of the content, on the page's\n    -- first row; panes leave that corner free (content.rmHelpReserve).\n    content.rmHelpReserve=addon.WorkbenchLayout.helpReserve\n    local paneHeader=addon:TrackWorkbenchSize(CreateFrame('Frame',nil,window));shell.paneHeader=paneHeader\n    shell.pageHelp=addon:CreateWorkbenchHelpButton(paneHeader,L['Help']);shell.pageHelp:SetPoint('TOPRIGHT',0,0);shell.pageHelp:SetSize(20,20);shell.pageHelp.icon:SetSize(18,18)\n",
            previous = "    local paneHeader=CreateFrame('Frame',nil,window);shell.paneHeader=paneHeader\n    shell.pageHelp=addon:CreateWorkbenchHelpButton(paneHeader,L['Help']);shell.pageHelp:SetPoint('TOPRIGHT',-2,-2);shell.pageHelp:SetSize(20,20);shell.pageHelp.icon:SetSize(18,18)\n    local content=CreateFrame(\"Frame\",nil,window);shell.content=content;content:EnableMouse(true)\n",
        },
        {
            at = 10887,
            current = "        local selected=scale(value);window:SetScale(selected);self:ApplySizeBounds()\n",
            previous = "        local selected=scale(value);window:SetScale(selected)\n",
        },
        {
            at = 15182,
            current = "            local link=flatButton(footer,entry.label,90);link:SetSize(link:GetFontString():GetStringWidth()+12,18);link.tooltip=entry.url\n",
            previous = "            local link=flatButton(footer,entry.key==\"website\" and entry.url or entry.label,90);link:SetSize(link:GetFontString():GetStringWidth()+12,18);link.tooltip=entry.url\n",
        },
        {
            at = 15470,
            current = "    local linksWidth=0;for _,link in ipairs(links) do linksWidth=linksWidth+link:GetWidth()+6 end;shell.footerLinksWidth=linksWidth\n",
            previous = "    local linksWidth=0;for _,link in ipairs(links) do linksWidth=linksWidth+link:GetWidth()+6 end\n",
        },
        {
            at = 18201,
            current = "        -- The page \"?\" shares the first row; it never adds header height.\n        self.paneHeaderHeight=0\n        if existing and existing:IsShown()then self.pageHelp:Hide();self.paneHeader:Hide()\n        else self.pageHelp:Show();self.paneHeader:Show() end\n",
            previous = "        if existing and existing:IsShown()then self.pageHelp:Hide();self.paneHeader:Hide();self.paneHeaderHeight=0\n        else self.pageHelp:Show();self.paneHeader:Show();self.paneHeaderHeight=24 end\n",
        },
        {
            at = 19373,
            current = "        content:ClearAllPoints();content:SetPoint(\"TOPLEFT\",window,\"TOPLEFT\",12,-top)\n        local contentWidth,contentHeight=math.max(1,width-24),math.max(1,height-top-28)\n        paneHeader:ClearAllPoints();paneHeader:SetPoint('TOPRIGHT',content,'TOPRIGHT',0,0);paneHeader:SetSize(20,20)\n        paneHeader:SetFrameLevel(content:GetFrameLevel()+50)\n        content:SetSize(contentWidth,contentHeight)\n        -- Status text ends before the centred footer links.\n        self.status:SetWidth(math.max(1,width/2-(self.footerLinksWidth or 0)/2-174-8))\n",
            previous = "        paneHeader:ClearAllPoints();paneHeader:SetPoint('TOPLEFT',window,'TOPLEFT',12,-top);paneHeader:SetSize(math.max(1,width-24),math.max(1,self.paneHeaderHeight or 24))\n        content:ClearAllPoints();content:SetPoint(\"TOPLEFT\",window,\"TOPLEFT\",12,-top-(self.paneHeaderHeight or 24))\n        content:SetSize(math.max(1,width-24),math.max(1,height-top-28-(self.paneHeaderHeight or 24)))\n        self.status:SetWidth(math.max(1,width/2-270))\n",
        },
        {
            at = 20169,
            current = "            self.pane:SetWidth(contentWidth);self.pane:SetHeight(contentHeight)\n",
            previous = "            self.pane:SetWidth(content:GetWidth());self.pane:SetHeight(content:GetHeight())\n",
        },
        {
            at = 24006,
            current = "    -- The client reports a sizing drag here; lay out with the reported size.\n    addon:SetUIScript(window,\"OnSizeChanged\",function() if not shell:ClampSize() then shell:Layout() end end)\n",
            previous = "    addon:SetUIScript(window,\"OnSizeChanged\",function() shell:Layout() end)\n",
        },
    },
}

records["UI/controls.lua"] = {
    bytes = 52930,
    hash = 3017017041,
    oldBytes = 33171,
    oldHash = 3919520019,
    changes = {
        {
            at = 330,
            current = "-- The client resolves a region's rect on its next layout pass: right after\n-- SetWidth/SetSize, or for a frame sized by its anchors, GetWidth/GetHeight\n-- still return the previous size, and OnSizeChanged arrives a frame later.\n-- Layout code reads sizes it has just assigned, so RM frames answer with the\n-- size RM last assigned (or the client last reported) instead of the stale\n-- rect. A size the client reports (window sizing, anchors) is noted before\n-- the frame's own OnSizeChanged handler runs, so that handler reads it too.\nfunction addon:TrackWorkbenchSize(frame)\n    if not frame or frame.rmTracksSize then return frame end\n    frame.rmTracksSize=true\n    local setWidth,setHeight,setSize,getWidth,getHeight=frame.SetWidth,frame.SetHeight,frame.SetSize,frame.GetWidth,frame.GetHeight\n    function frame:SetWidth(value,...) if type(value)=='number' then self.rmWidth=value end;return setWidth(self,value,...) end\n    function frame:SetHeight(value,...) if type(value)=='number' then self.rmHeight=value end;return setHeight(self,value,...) end\n    if setSize then function frame:SetSize(width,height,...) if type(width)=='number' then self.rmWidth=width end;if type(height)=='number' then self.rmHeight=height end;return setSize(self,width,height,...) end end\n    function frame:GetWidth(...) local value=self.rmWidth;if value then return value end;return getWidth(self,...) end\n    function frame:GetHeight(...) local value=self.rmHeight;if value then return value end;return getHeight(self,...) end\n    if frame.SetScript and frame.HookScript and frame.HasScript and frame:HasScript('OnSizeChanged') then\n        local setScript=frame.SetScript\n        function frame:SetScript(event,handler,...)\n            if event=='OnSizeChanged' and handler then\n                local inner=handler\n                handler=function(region,width,height,...) addon:NoteWorkbenchSize(region,width,height);return inner(region,width,height,...) end\n            end\n            return setScript(self,event,handler,...)\n        end\n        local current=frame:GetScript('OnSizeChanged');if current then frame:SetScript('OnSizeChanged',current) end\n        frame:HookScript('OnSizeChanged',function(region,width,height) addon:NoteWorkbenchSize(region,width,height) end)\n    end\n    return frame\nend\n-- Pooled builders may return any region or a plain table; only regions\n-- with their own geometry are tracked.\nfunction addon:TrackWorkbenchRegion(value)\n    if type(value)=='table' and type(value.SetWidth)=='function' and type(value.GetWidth)=='function' and type(value.SetPoint)=='function' then return self:TrackWorkbenchSize(value) end\n    return value\nend\nfunction addon:NoteWorkbenchSize(frame,width,height)\n    if not frame.rmTracksSize then return end\n    if type(width)=='number' and width>0 then frame.rmWidth=width end\n    if type(height)=='number' and height>0 then frame.rmHeight=height end\nend\n",
            previous = "",
        },
        {
            at = 3291,
            current = "    local button=CreateFrame(\"Button\",nil,parent);self:TrackWorkbenchSize(button);button:SetSize(width or 28,20);button:EnableMouse(true)\n",
            previous = "    local button=CreateFrame(\"Button\",nil,parent);button:SetSize(width or 28,20);button:EnableMouse(true)\n",
        },
        {
            at = 5774,
            current = "    -- The caption is bounded by the button so a long label cannot spill out.\n    local caption=button:GetFontString();caption:ClearAllPoints();caption:SetPoint('LEFT',24,0);caption:SetPoint('RIGHT',-4,0);caption:SetJustifyH('LEFT');caption:SetWordWrap(false);return button\n",
            previous = "    local caption=button:GetFontString();caption:ClearAllPoints();caption:SetPoint('LEFT',24,0);return button\n",
        },
        {
            at = 6792,
            current = "-- An aligned caption keeps following its button when the button is resized\n-- later, rather than keeping the width it had when aligned. A caller that\n-- narrows the caption itself afterwards keeps that width until realigned.\nlocal function refitAlignedText(button)\n    local label=button:GetFontString();local inset=button.rmAlignInset\n    if not label or not inset then return end\n    addon:TrackWorkbenchSize(label)\n    if math.abs((label:GetWidth() or 0)-(button.rmAlignWidth or -1))>.5 then button.rmAlignInset=nil;return end\n    local width=math.max(1,button:GetWidth()-inset-4);label:SetWidth(width);button.rmAlignWidth=width\nend\n",
            previous = "",
        },
        {
            at = 7481,
            current = "    local label=button:GetFontString();self:TrackWorkbenchSize(label);label:ClearAllPoints();label:SetPoint('LEFT',inset or 4,0);label:SetJustifyH('LEFT')\n    local width=math.max(1,button:GetWidth()-(inset or 4)-4);label:SetWidth(width);button.rmAlignInset=inset or 4;button.rmAlignWidth=width\n    if not button.rmAlignFollows then\n        button.rmAlignFollows=true;local setWidth,setSize=button.SetWidth,button.SetSize\n        function button:SetWidth(...) setWidth(self,...);refitAlignedText(self) end\n        function button:SetSize(...) setSize(self,...);refitAlignedText(self) end\n    end\n",
            previous = "    local label=button:GetFontString();label:ClearAllPoints();label:SetPoint('LEFT',inset or 4,0);label:SetJustifyH('LEFT');label:SetWidth(math.max(1,button:GetWidth()-(inset or 4)-4))\n",
        },
        {
            at = 12222,
            current = "    -- Repainting the same colors (every redraw does) costs eighteen texture\n    -- calls; skip it.\n",
            previous = "",
        },
        {
            at = 12379,
            current = "        local last=self.painted\n        if last and last[1]==r and last[2]==g and last[3]==b and last[4]==alpha and last[5]==fillAlpha then return end\n        self.painted={r,g,b,alpha,fillAlpha}\n",
            previous = "",
        },
        {
            at = 15168,
            current = "    local input=CreateFrame(\"EditBox\",nil,parent);self:TrackWorkbenchSize(input);input:SetFontObject(\"GameFontHighlightSmall\");input:SetAutoFocus(false)\n",
            previous = "    local input=CreateFrame(\"EditBox\",nil,parent);input:SetFontObject(\"GameFontHighlightSmall\");input:SetAutoFocus(false)\n",
        },
        {
            at = 16721,
            current = "    local slider=CreateFrame(\"Slider\",nil,parent);self:TrackWorkbenchSize(slider);slider:SetOrientation(\"HORIZONTAL\");slider:SetSize(width or 112,12)\n",
            previous = "    local slider=CreateFrame(\"Slider\",nil,parent);slider:SetOrientation(\"HORIZONTAL\");slider:SetSize(width or 112,12)\n",
        },
        {
            at = 23048,
            current = "    local scroll=CreateFrame('ScrollFrame',nil,parent);self:TrackWorkbenchSize(scroll)\n    local bar=self:CreateWorkbenchScrollBar(scroll,'VERTICAL');self:TrackWorkbenchSize(bar);scroll.workbenchBar=bar\n    local setScrollChild=scroll.SetScrollChild\n    function scroll:SetScrollChild(child,...) addon:TrackWorkbenchSize(child);return setScrollChild(self,child,...) end\n",
            previous = "    local scroll=CreateFrame('ScrollFrame',nil,parent)\n    local bar=self:CreateWorkbenchScrollBar(scroll,'VERTICAL');scroll.workbenchBar=bar\n",
        },
        {
            at = 24003,
            current = "        self:FitWorkbenchColumn()\n    end\n    -- A list column keeps its rows flush with the column's right edge: the\n    -- bar takes its reserve only while the list actually scrolls. The owner's\n    -- OnWorkbenchColumnResized refreshes row widths after a change.\n    function scroll:SetWorkbenchColumnWidth(width)\n        self.workbenchColumnWidth=math.max(1,width);self:FitWorkbenchColumn()\n    end\n    function scroll:FitWorkbenchColumn()\n        local column=self.workbenchColumnWidth;if not column or self.fittingColumn then return end\n        local wanted=math.max(1,column-(bar:IsShown() and addon.WorkbenchLayout.scrollReserve or 0))\n        local child=self:GetScrollChild()\n        if math.abs(self:GetWidth()-wanted)<.01 and (not child or math.abs(child:GetWidth()-wanted)<.01) then return end\n        self.fittingColumn=true;self:SetWidth(wanted);if child then child:SetWidth(wanted) end;self.fittingColumn=nil\n        if self.OnWorkbenchColumnResized then self:OnWorkbenchColumnResized(wanted) end\n",
            previous = "",
        },
        {
            at = 33192,
            current = "-- Live reflow, coalesced. A window grip or divider drag reports a new size\n-- every rendered frame, often through several nested frames. Owners do the\n-- cheap geometry at once and request their expensive relayout here: one\n-- shared driver runs each pending owner at most once per rendered frame,\n-- the latest request winning, and then stops itself so idle frames cost\n-- nothing. An owner that is not visible is dropped (it draws when opened\n-- again). Each run is timed, and the owner's next run waits twice that long,\n-- so a relayout that is slow on this machine takes at most a third of the\n-- frames of a drag; the last request always runs once the waiting is over.\n-- A settle request runs once its owner has had no reflow request for a few\n-- rendered frames: the full drawing after a drag that reflowed cheaply.\nlocal reflowQueue,settleQueue,reflowDriver={},{},nil\nlocal function reflowClock()\n    if type(debugprofilestop)=='function' then return debugprofilestop()/1000 end\n    if type(GetTime)=='function' then return GetTime() end\n    return 0\nend\nlocal function reflowVisible(frame)\n    if not frame then return true end\n    if frame.IsVisible then return frame:IsVisible() and true or false end\n    for _=1,64 do\n        if not frame then return true end\n        if frame.IsShown and not frame:IsShown() then return false end\n        frame=frame.GetParent and frame:GetParent() or nil\n    end\n    return true\nend\nlocal function driveReflow(driver)\n    local batch=reflowQueue;reflowQueue={}\n    for owner,request in pairs(batch) do\n        if reflowQueue[owner] then\n            -- Requested again by a relayout that already ran this frame.\n        elseif not reflowVisible(request.frame) then\n            owner.rmReflowAfter=nil\n        elseif (owner.rmReflowAfter or 0)>reflowClock() then\n            reflowQueue[owner]=request\n        else\n            local start=reflowClock()\n            local ok,why=pcall(request.run)\n            local finish=reflowClock();owner.rmReflowAfter=finish+math.min(.25,math.max(0,finish-start)*2)\n            if not ok then local handler=geterrorhandler and geterrorhandler();if handler then pcall(handler,why) end end\n        end\n    end\n    local due={}\n    for owner,request in pairs(settleQueue) do\n        if not reflowQueue[owner] then\n            request.wait=request.wait-1\n            if request.wait<=0 then settleQueue[owner]=nil;if reflowVisible(request.frame) then due[#due+1]=request end end\n        end\n    end\n    for _,request in ipairs(due) do\n        local ok,why=pcall(request.run)\n        if not ok then local handler=geterrorhandler and geterrorhandler();if handler then pcall(handler,why) end end\n    end\n    if next(reflowQueue)==nil and next(settleQueue)==nil then driver:SetScript('OnUpdate',nil) end\nend\nfunction addon:RequestWorkbenchReflow(owner,frame,run)\n    if type(owner)~='table' or type(run)~='function' then return end\n    reflowQueue[owner]={frame=frame,run=run}\n    reflowDriver=reflowDriver or CreateFrame('Frame')\n    if not reflowDriver:GetScript('OnUpdate') then reflowDriver:SetScript('OnUpdate',driveReflow) end\nend\nfunction addon:RequestWorkbenchSettle(owner,frame,run,frames)\n    if type(owner)~='table' or type(run)~='function' then return end\n    settleQueue[owner]={frame=frame,run=run,wait=frames or 6}\n    reflowDriver=reflowDriver or CreateFrame('Frame')\n    if not reflowDriver:GetScript('OnUpdate') then reflowDriver:SetScript('OnUpdate',driveReflow) end\nend\n-- Runs every pending relayout and settle now, without waiting for a frame\n-- or a cost window (for code and tests that need the final layout at once).\nfunction addon:FlushWorkbenchReflow()\n    for _=1,8 do\n        if next(reflowQueue)==nil and next(settleQueue)==nil then break end\n        for owner in pairs(reflowQueue) do if type(owner)=='table' then owner.rmReflowAfter=nil end end\n        for _,request in pairs(settleQueue) do request.wait=1 end\n        driveReflow(reflowDriver)\n    end\nend\n-- A released owner leaves both queues.\nfunction addon:CancelWorkbenchReflow(owner) reflowQueue[owner]=nil;settleQueue[owner]=nil;if type(owner)=='table' then owner.rmReflowAfter=nil end end\nfunction addon:IsWorkbenchReflowPending(owner) return reflowQueue[owner]~=nil or settleQueue[owner]~=nil end\n\n-- Box selection on a card canvas. The pointer in a canvas child's own\n-- coordinates (x right, y down from its top-left, zoom included), or nil when\n-- the client cannot tell.\nfunction addon:WorkbenchPointerIn(child)\n    if type(GetCursorPosition)~='function' or not child or not child.GetLeft or not child.GetTop or not child.GetEffectiveScale then return end\n    local ok,x,y=pcall(GetCursorPosition);local scale=child:GetEffectiveScale();local left,top=child:GetLeft(),child:GetTop()\n    local function finite(value) return type(value)=='number' and value==value and value>-math.huge and value<math.huge end\n    if not ok or not finite(x) or not finite(y) or not finite(scale) or scale<=0 or not finite(left) or not finite(top) then return end\n    return x/scale-left,top-y/scale\nend\n-- The drawn box: a faint gold fill with a 1px outline, placed in child\n-- coordinates with :Place(x1,y1,x2,y2).\nfunction addon:CreateWorkbenchSelectionBox(child)\n    local frame=CreateFrame('Frame',nil,child);frame:EnableMouse(false);frame:Hide()\n    frame.fill=frame:CreateTexture(nil,'OVERLAY');frame.fill:SetAllPoints(frame);frame.fill:SetColorTexture(.9,.75,.3,.12)\n    for _,side in ipairs({{'TOPLEFT','TOPRIGHT','h'},{'BOTTOMLEFT','BOTTOMRIGHT','h'},{'TOPLEFT','BOTTOMLEFT','v'},{'TOPRIGHT','BOTTOMRIGHT','v'}}) do\n        local edge=frame:CreateTexture(nil,'OVERLAY');edge:SetColorTexture(.9,.75,.3,.9);edge:SetPoint(side[1]);edge:SetPoint(side[2])\n        if side[3]=='h' then edge:SetHeight(1) else edge:SetWidth(1) end\n    end\n    function frame:Place(x1,y1,x2,y2)\n        self:ClearAllPoints();self:SetPoint('TOPLEFT',child,'TOPLEFT',math.min(x1,x2),-math.min(y1,y2))\n        self:SetSize(math.max(1,math.abs(x2-x1)),math.max(1,math.abs(y2-y1)));self:SetFrameLevel(child:GetFrameLevel()+200);self:Show()\n    end\n    return frame\nend\n\n",
            previous = "",
        },
        {
            at = 40692,
            current = "-- Shared workbench sizing. The window minimum is the smallest width at which\n-- every page keeps its controls inside the pane; list/detail pages share one\n-- divider position, which each page clamps to its own width.\naddon.WorkbenchLayout={windowMinWidth=800,windowMinHeight=500,sidebarMin=200,detailMin=440,splitGap=18,scrollReserve=14,helpReserve=22}\n-- A workbench page's gold \"?\" sits in the top-right corner of the page\n-- content, on the page's first row. The content frame carries the reserve;\n-- panes reaching that corner leave it free on their first row.\n-- One section-header style for every page, the one the Rotations editor\n-- uses for its \"Switch condition\" header: GameFontNormal in its gold.\naddon.WorkbenchHeaderFont='GameFontNormal';addon.WorkbenchHeaderColor={1,.82,0}\nfunction addon:StyleWorkbenchHeader(label)\n    if not label then return label end\n    local color=self.WorkbenchHeaderColor\n    if label.SetFontObject then label:SetFontObject(self.WorkbenchHeaderFont) end\n    if label.SetTextColor then label:SetTextColor(color[1],color[2],color[3]) end\n    label.rmHeaderFont=self.WorkbenchHeaderFont;return label\nend\nfunction addon:GetWorkbenchHelpReserve(frame)\n    local parent=frame and frame.GetParent and frame:GetParent()\n    return parent and parent.rmHelpReserve or 0\nend\n-- A detail scroll bar in that corner (with its 10 px arrow above the\n-- track) starts below the \"?\".\nfunction addon:ReserveWorkbenchHelpCorner(owner,scroll,scrollTop)\n    local reserve=self:GetWorkbenchHelpReserve(owner);local bar=scroll and scroll.workbenchBar\n    if not bar then return end\n    bar:ClearAllPoints();bar:SetPoint('TOPLEFT',scroll,'TOPRIGHT',4,-math.max(10,reserve>0 and reserve+12-(scrollTop or 0) or 10));bar:SetPoint('BOTTOMLEFT',scroll,'BOTTOMRIGHT',4,10)\nend\nfunction addon:GetWorkbenchSidebarBounds(width)\n    local layout=self.WorkbenchLayout\n    local maximum=math.min(math.floor(width*.5),width-layout.splitGap-layout.detailMin)\n    return layout.sidebarMin,math.max(layout.sidebarMin,maximum)\nend\nfunction addon:GetWorkbenchSidebarPreference()\n    local global=self.db and self.db.global;local value=global and global.workbenchSidebarWidth\n    if type(value)=='number' and value==value and value>0 and value<100000 then return value end\nend\n-- nil returns the divider to its automatic position.\nfunction addon:SetWorkbenchSidebarPreference(value)\n    local global=self.db and self.db.global;if not global then return end\n    if value==nil then global.workbenchSidebarWidth=nil\n    elseif type(value)=='number' and value==value and value>0 and value<100000 then global.workbenchSidebarWidth=math.floor(value+.5) end\nend\n",
            previous = "",
        },
        {
            at = 43392,
            current = "    local minimum,maximum=self:GetWorkbenchSidebarBounds(width)\n    local value=self:GetWorkbenchSidebarPreference() or math.max(210,math.min(270,width*.26))\n    return math.max(minimum,math.min(maximum,value))\n",
            previous = "    return math.max(210,math.min(270,width*.26))\n",
        },
        {
            at = 43766,
            current = "    local side=self:GetWorkbenchSidebarWidth(width);local gap=self.WorkbenchLayout.splitGap\n    return {width=width,top=top or 0,sidebarWidth=side,sidebarHeight=self:GetWorkbenchSidebarHeight(height,top),detailX=side+gap,detailWidth=math.max(1,width-side-gap)}\nend\n\n-- The draggable divider between a list column and its detail pane. It lives in\n-- the gap between them; dragging stores the shared preference and asks the\n-- owner to lay out again, passing the previous preference so an owner that\n-- cannot follow may restore it. Double-click restores the automatic position.\nfunction addon:CreateWorkbenchSplitter(parent,changed)\n    local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)\n    local splitter=CreateFrame('Button',nil,parent);splitter:SetSize(10,1);splitter:EnableMouse(true)\n    local line=splitter:CreateTexture(nil,'ARTWORK');line:SetPoint('TOP',splitter,'TOP',0,0);line:SetPoint('BOTTOM',splitter,'BOTTOM',0,0);splitter.line=line\n    local function paint()\n        if splitter.drag then line:SetColorTexture(.9,.75,.3,1);line:SetWidth(2)\n        elseif splitter.hover then line:SetColorTexture(.62,.66,.69,1);line:SetWidth(2)\n        else line:SetColorTexture(.33,.35,.37,.8);line:SetWidth(1) end\n    end\n    function splitter:Place(geometry)\n        self.geometry=geometry;self:ClearAllPoints()\n        self:SetPoint('TOPLEFT',parent,'TOPLEFT',geometry.sidebarWidth+(addon.WorkbenchLayout.splitGap-10)/2,-(geometry.top or 0))\n        self:SetSize(10,math.max(1,geometry.sidebarHeight));self:Show()\n    end\n    -- Returns true when the divider moved.\n    function splitter:Resize(value)\n        local geometry=self.geometry;if not geometry or type(value)~='number' or value~=value then return false end\n        local minimum,maximum=addon:GetWorkbenchSidebarBounds(geometry.width)\n        value=math.floor(math.max(minimum,math.min(maximum,value))+.5)\n        if value==addon:GetWorkbenchSidebarWidth(geometry.width) then return false end\n        local previous=addon:GetWorkbenchSidebarPreference()\n        addon:SetWorkbenchSidebarPreference(value);changed(previous);return true\n    end\n    function splitter:Reset() local previous=addon:GetWorkbenchSidebarPreference();addon:SetWorkbenchSidebarPreference(nil);changed(previous) end\n    local function stop()\n        if not splitter.drag then return end\n        splitter.drag=nil;addon:SetUIScript(splitter,'OnUpdate',nil);paint()\n    end\n    splitter.Stop=stop\n    addon:SetUIScript(splitter,'OnMouseDown',function(_,button)\n        if button~='LeftButton' or not splitter.geometry or not GetCursorPosition then return end\n        local x=GetCursorPosition();splitter.drag={x=x,width=splitter.geometry.sidebarWidth};paint()\n        addon:SetUIScript(splitter,'OnUpdate',function()\n            local drag=splitter.drag;if not drag then return end\n            if IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then stop();return end\n            local current=GetCursorPosition();local scale=splitter:GetEffectiveScale() or 1\n            splitter:Resize(drag.width+(current-drag.x)/(scale>0 and scale or 1))\n        end)\n    end)\n    addon:SetUIScript(splitter,'OnMouseUp',stop);addon:SetUIScript(splitter,'OnHide',stop)\n    addon:SetUIScript(splitter,'OnDoubleClick',function() stop();splitter:Reset() end)\n    addon:SetUIScript(splitter,'OnEnter',function()\n        splitter.hover=true;paint()\n        if GameTooltip then GameTooltip:SetOwner(splitter,'ANCHOR_RIGHT');GameTooltip:SetText(L['Drag to resize the list. Double-click to reset.'],1,1,1,1,true) end\n    end)\n    addon:SetUIScript(splitter,'OnLeave',function() splitter.hover=nil;paint();if GameTooltip and GameTooltip:IsOwned(splitter) then GameTooltip:Hide() end end)\n    paint();return splitter\nend\n\n-- Places same-row controls left to right within their parent, sharing the\n-- row width evenly. A control never shrinks below `minimum`; when the row\n-- cannot hold them all, it wraps onto further lines. Returns the height used.\nfunction addon:LayoutWorkbenchRow(controls,x,y,width,options)\n    options=options or {};local gap=options.gap or 4;local pitch=options.pitch or 28\n    local count=#controls;if count==0 then return 0 end\n    local minimum=options.minimum or 1\n    local columns=math.max(1,math.min(count,math.floor((width+gap)/(minimum+gap))))\n    if options.columns then columns=math.max(1,math.min(columns,options.columns)) end\n    local each=math.max(1,(width-(columns-1)*gap)/columns)\n    for index,control in ipairs(controls) do\n        local column=(index-1)%columns;local line=math.floor((index-1)/columns)\n        control:ClearAllPoints();control:SetPoint('TOPLEFT',x+column*(each+gap),-(y+line*pitch));control:SetWidth(each)\n        if options.text then local label=control.GetFontString and control:GetFontString();if label then label:SetWidth(math.max(1,each-options.text)) end end\n    end\n    return math.ceil(count/columns)*pitch,each,columns\nend\n\n-- In-pane confirmation prompts keep their designed width but never exceed\n-- the pane they cover. Returns the width used.\nfunction addon:FitWorkbenchPrompt(frame,owner,preferred)\n    local available=owner and owner.GetWidth and owner:GetWidth() or preferred\n    local width=math.max(1,math.min(preferred,(available or preferred)-16))\n    frame:SetWidth(width);return width\n",
            previous = "    local side=self:GetWorkbenchSidebarWidth(width)\n    return {sidebarWidth=side,sidebarHeight=self:GetWorkbenchSidebarHeight(height,top),detailX=side+18,detailWidth=math.max(200,width-side-18)}\n",
        },
    },
}

records["UI/custom_condition_editor.lua"] = {
    bytes = 37116,
    hash = 3956714193,
    oldBytes = 36998,
    oldHash = 3952024730,
    changes = {
        {
            at = 883,
            current = "    d=d or {frame=self:TrackWorkbenchSize(CreateFrame('Frame',nil,embedded and embedded.parent or UIParent)),nativeCustomEditor=true}\n",
            previous = "    d=d or {frame=CreateFrame('Frame',nil,embedded and embedded.parent or UIParent),nativeCustomEditor=true}\n",
        },
        {
            at = 2277,
            current = "    d.body=d.body or self:TrackWorkbenchSize(CreateFrame('Frame',nil,frame));d.body:ClearAllPoints();d.body:SetPoint('TOPLEFT',embedded and 0 or 12,embedded and 0 or -34);d.body:SetSize(frame:GetWidth()-(embedded and 0 or 24),frame:GetHeight()-(embedded and 0 or 70))\n",
            previous = "    d.body=d.body or CreateFrame('Frame',nil,frame);d.body:ClearAllPoints();d.body:SetPoint('TOPLEFT',embedded and 0 or 12,embedded and 0 or -34);d.body:SetSize(frame:GetWidth()-(embedded and 0 or 24),frame:GetHeight()-(embedded and 0 or 70))\n",
        },
        {
            at = 28282,
            current = "            local caption=button:GetFontString();caption:SetFontObject('GameFontHighlightSmall');caption:SetWidth(math.max(1,tabWidth-6));caption:SetWordWrap(false)\n",
            previous = "            local caption=button:GetFontString();caption:SetFontObject('GameFontHighlightSmall')\n",
        },
    },
}

records["UI/custom_source_fields.lua"] = {
    bytes = 7150,
    hash = 4204464940,
    oldBytes = 7098,
    oldHash = 310130279,
    changes = {
        {
            at = 1599,
            current = "    local height=owner.advancedSchema and (short and 44 or 80) or math.max(24,math.min(short and 1 or 3,#nodes)*20)\n",
            previous = "    local height=owner.advancedSchema and (short and 56 or 80) or math.max(24,math.min(short and 1 or 3,#nodes)*20)\n",
        },
        {
            at = 2975,
            current = "    scroll.schemaContent=scroll.schemaContent or addon:TrackWorkbenchSize(CreateFrame('Frame',nil,scroll));local content=scroll.schemaContent\n",
            previous = "    scroll.schemaContent=scroll.schemaContent or CreateFrame('Frame',nil,scroll);local content=scroll.schemaContent\n",
        },
        {
            at = 4595,
            current = "    owner.schemaRows=owner.schemaRows or {};scroll.preview=scroll.preview or addon:TrackWorkbenchSize(CreateFrame('Frame',nil,scroll));local preview=scroll.preview;preview:SetWidth(width-18);preview:SetHeight(math.max(20,#nodes*20))\n",
            previous = "    owner.schemaRows=owner.schemaRows or {};scroll.preview=scroll.preview or CreateFrame('Frame',nil,scroll);local preview=scroll.preview;preview:SetWidth(width-18);preview:SetHeight(math.max(20,#nodes*20))\n",
        },
    },
}

records["UI/defaults.lua"] = {
    bytes = 8558,
    hash = 3794403372,
    oldBytes = 8524,
    oldHash = 873595521,
    changes = {
        {
            at = 879,
            current = "    if kind=='Heading' then widget:SetFontObject(addon.WorkbenchHeaderFont);widget:SetColor(unpack(addon.WorkbenchHeaderColor)) end\n",
            previous = "    if kind=='Heading' then widget:SetFontObject('GameFontNormal');widget:SetColor(1,.82,.25) end\n",
        },
    },
}

records["UI/function_source_pane.lua"] = {
    bytes = 31091,
    hash = 2324044601,
    oldBytes = 31836,
    oldHash = 3297718040,
    changes = {
        {
            at = 3353,
            current = "    local d=p.functionEditorCache or {frame=self:TrackWorkbenchSize(CreateFrame('Frame',nil,p.frame))};p.functionEditorCache=d;p.inlineFunction=d\n",
            previous = "    local d=p.functionEditorCache or {frame=CreateFrame('Frame',nil,p.frame)};p.functionEditorCache=d;p.inlineFunction=d\n",
        },
        {
            at = 4436,
            current = "    d.frame:SetParent(p.frame);d.frame:ClearAllPoints();d.frame:SetPoint('TOPLEFT',geometry.detailX,0);d.frame:SetSize(geometry.detailWidth-self:GetWorkbenchHelpReserve(p.frame),math.max(160,p.frame:GetHeight()-36))\n",
            previous = "    d.frame:SetParent(p.frame);d.frame:ClearAllPoints();d.frame:SetPoint('TOPLEFT',geometry.detailX,0);d.frame:SetSize(geometry.detailWidth,math.max(160,p.frame:GetHeight()-36))\n",
        },
        {
            at = 13501,
            current = "",
            previous = "        local headerY=form.y\n        local heading=form:Acquire('functionMetadataHeadings',function() return addon:CreateWorkbenchButton(form.child,'',240) end)\n        heading:ClearAllPoints();heading:SetPoint('TOPLEFT',0,-headerY);heading:SetSize(math.max(60,form.width-118),22);heading:SetText(caption);heading.art:Hide();heading:GetFontString():SetTextColor(1,.82,.2);addon:AlignWorkbenchTextLeft(heading,0);form.fields['section_'..field]=heading\n        addon:SetUIScript(heading,'OnClick',form:Guard(function() if d:Flush() then d.metadataCollapsed[field]=not d.metadataCollapsed[field];refresh() end end))\n",
        },
        {
            at = 14243,
            current = "        local function append()\n",
            previous = "        local add=form:Button('add_'..field,field=='args' and L['Argument'] or L['Return'],function()\n",
        },
        {
            at = 14691,
            current = "        end\n",
            previous = "        end,'plus')\n        add:ClearAllPoints();add:SetPoint('TOPRIGHT',0,-headerY);add:SetWidth(112);enable(add,not d.readOnly);form.y=headerY+28\n",
        },
        {
            at = 15134,
            current = "        -- The collapsible section title and Add share the list's header row.\n        local header={heading={text=caption,key='section_'..field,collapsed=d.metadataCollapsed[field],toggle=function() if d:Flush() then d.metadataCollapsed[field]=not d.metadataCollapsed[field];refresh() end end},\n            add={key='add_'..field,text=field=='args' and L['Argument'] or L['Return'],enabled=not d.readOnly,click=append,beginDrag=beginInsert}}\n",
            previous = "        addon:BindWorkbenchDragSource(add,beginInsert,function() local view=form.ordered and form.ordered[viewKey];if view then view:EndDrag() end end)\n        if d.metadataCollapsed[field] then return end\n",
        },
        {
            at = 16340,
            current = "            -- Nullable is only as wide as its box and caption, right-aligned so\n            -- it sits against the card's help icon.\n            local nullableY=wide and top or top+(isArgument and 56 or 28)\n            form.y=nullableY\n            local check=form:Check(prefix..'nullable',L['Nullable'],nullable,function(value) setType(base,value) end)\n            local caption=check:GetFontString();caption:SetWidth(200)\n            local captionWidth=math.min(120,math.max(30,math.ceil(caption:GetStringWidth() or 0)+2));local checkWidth=22+captionWidth\n            caption:SetWidth(captionWidth);check:SetWidth(checkWidth);check:ClearAllPoints();check:SetPoint('TOPLEFT',math.max(0,width-checkWidth),-nullableY)\n            local inlineRight=wide and width-checkWidth-6 or width\n",
            previous = "",
        },
        {
            at = 17296,
            current = "            local typeWidth=wide and (isArgument and math.min(140,math.floor(width*.25)) or inlineRight-34) or width-34\n",
            previous = "            local typeWidth=wide and (isArgument and math.min(140,math.floor(width*.25)) or width-144) or width-34\n",
        },
        {
            at = 18305,
            current = "                input:SetMultiLine(false);input:SetHeight(24);input:SetTextInsets(4,4,0,0);input:SetCursorPosition(0);input:ClearAllPoints();input:SetPoint('TOPLEFT',nameX,-nameY);input:SetWidth(math.max(40,inlineRight-nameX));input.tooltip=L['Argument name'];enable(input,not d.readOnly)\n",
            previous = "                input:SetMultiLine(false);input:SetHeight(24);input:SetTextInsets(4,4,0,0);input:SetCursorPosition(0);input:ClearAllPoints();input:SetPoint('TOPLEFT',nameX,-nameY);input:SetWidth(math.max(40,(wide and width-110 or width)-nameX));input.tooltip=L['Argument name'];enable(input,not d.readOnly)\n",
        },
        {
            at = 18788,
            current = "            enable(check,not d.readOnly and base~='nil');form.y=nullableY+28\n",
            previous = "            local nullableY=wide and top or top+(isArgument and 56 or 28)\n            form.y=nullableY\n            local check=form:Check(prefix..'nullable',L['Nullable'],nullable,function(value) setType(base,value) end)\n            check:ClearAllPoints();check:SetPoint('TOPLEFT',wide and width-104 or 34,-nullableY);check:SetWidth(102);check:GetFontString():SetWidth(80);enable(check,not d.readOnly and base~='nil');form.y=nullableY+28\n",
        },
        {
            at = 19535,
            current = "            form.fields[prefix..'help']=row.help\n            addon:SetUIScript(row.help,'OnClick',form:Guard(function()\n",
            previous = "            row.functionHelp=row.functionHelp or addon:CreateWorkbenchHelpButton(row,L['Help']);row.functionHelp:ClearAllPoints();row.functionHelp:SetPoint('TOPRIGHT',-4,-3);row.functionHelp:SetSize(20,20);row.functionHelp.icon:SetSize(18,18);row.functionHelp:Enable();row.functionHelp:Show();form.fields[prefix..'help']=row.functionHelp\n            addon:SetUIScript(row.functionHelp,'OnClick',form:Guard(function()\n",
        },
        {
            at = 21069,
            current = "            form.fields[prefix..'duplicate']=row.duplicate\n            addon:SetUIScript(row.duplicate,'OnClick',form:Guard(function()\n",
            previous = "            row.functionDuplicate=row.functionDuplicate or addon:CreateWorkbenchIconButton(row,'copy',L['Duplicate']);row.functionDuplicate:ClearAllPoints();row.functionDuplicate:SetPoint('TOPRIGHT',-4,-25);row.functionDuplicate:SetSize(20,20);enable(row.functionDuplicate,not d.readOnly);row.functionDuplicate:Show();form.fields[prefix..'duplicate']=row.functionDuplicate\n            addon:SetUIScript(row.functionDuplicate,'OnClick',form:Guard(function()\n",
        },
        {
            at = 21856,
            current = "            form.fields[prefix..'remove']=row.remove\n        end,function() if not d.readOnly then if d.code then d.value.code=d.code:GetText() end;d:UpdateActions() end end,{heading=header.heading,add=header.add,help=true,duplicate=true,prefix=field=='args' and 'arg_' or 'return_',readOnly=d.readOnly,confirmReorder=confirmOrderChange,confirmInsert=function(apply,gap)\n",
            previous = "            row.remove:ClearAllPoints();row.remove:SetPoint('TOPRIGHT',-4,-47);form.fields[prefix..'remove']=row.remove\n        end,function() if not d.readOnly then if d.code then d.value.code=d.code:GetText() end;d:UpdateActions() end end,{header=false,prefix=field=='args' and 'arg_' or 'return_',readOnly=d.readOnly,confirmReorder=confirmOrderChange,confirmInsert=function(apply,gap)\n",
        },
    },
}

records["UI/help.lua"] = {
    bytes = 28738,
    hash = 3181601776,
    oldBytes = 27318,
    oldHash = 1142123770,
    changes = {
        {
            at = 2790,
            current = "-- Some bound controls are Lua wrappers (editor objects), not frames; the\n-- tooltip's owner APIs reject those with \"Wrong object type\".\nlocal function tooltipOwned(control)\n    if not GameTooltip then return false end\n    local ok,owned=pcall(GameTooltip.IsOwned,GameTooltip,control)\n    return ok and owned\nend\n\n",
            previous = "",
        },
        {
            at = 3767,
            current = "        if tooltipOwned(control) then if descriptor.brief~=control.tooltip then GameTooltip:AddLine(descriptor.brief,1,1,1,true) end\n        else\n            if not pcall(GameTooltip.SetOwner,GameTooltip,control,'ANCHOR_RIGHT') then return end\n            GameTooltip:SetText(descriptor.brief,1,1,1,1,true)\n        end\n",
            previous = "        if GameTooltip:IsOwned(control) then if descriptor.brief~=control.tooltip then GameTooltip:AddLine(descriptor.brief,1,1,1,true) end\n        else GameTooltip:SetOwner(control,'ANCHOR_RIGHT');GameTooltip:SetText(descriptor.brief,1,1,1,1,true) end\n",
        },
        {
            at = 4231,
            current = "        if current() and tooltipOwned(control) then GameTooltip:Hide() end\n",
            previous = "        if current() and GameTooltip and GameTooltip:IsOwned(control) then GameTooltip:Hide() end\n",
        },
        {
            at = 4833,
            current = "        if tooltipOwned(control) then GameTooltip:Hide() end\n",
            previous = "        if GameTooltip and GameTooltip:IsOwned(control) then GameTooltip:Hide() end\n",
        },
        {
            at = 7183,
            current = "            section(L['Select several cards'],L['Ctrl-click cards to add or remove them from the selection; Shift-click selects the siblings between it and the last clicked card. Shift-drag on empty canvas draws a box that selects every card it touches (Ctrl+Shift-drag adds). With several cards selected, the strip above the canvas groups them as All or Any, and Duplicate, Enable, Disable and Delete act on every selected card; one Undo reverses each. Drag any selected card to move the selection.']),\n",
            previous = "",
        },
        {
            at = 8627,
            current = "        result[#result+1]=section(L['Select several cards'],L['Ctrl-click cards to add or remove them from the selection; Shift-click a title or condition to select the siblings between it and the last clicked card. Shift-drag on empty canvas draws a box that selects every card it touches (Ctrl+Shift-drag adds). Drag any selected card to move the whole selection to one gap. Beside Apply, Duplicate, Enable, Disable and Delete act on every selected card, and one Undo reverses each. Branches keep their Evaluate / Always mode. Click empty canvas to clear the selection.'])\n",
            previous = "",
        },
        {
            at = 14588,
            current = "        Announces=L['Choose an announcement trigger, then edit its always expanded output cards. Each card has a destination, conditions, enabled state and Help. Add, duplicate, delete, move or drag outputs within the announcement. Joined channel names are available for Via Script/Macro. New opens a draft; Apply saves it and Discard restores it. Imports are validated and never execute code.'],\n",
            previous = "        Announces=L['Choose an announcement trigger, then edit its always expanded output cards. Each card has a destination, conditions, enabled state and Help. Add, duplicate, delete, move or drag outputs within the announcement. Joined channel names are available for Via Macro. New opens a draft; Apply saves it and Discard restores it. Imports are validated and never execute code.'],\n",
        },
    },
}

records["UI/item_list_popup.lua"] = {
    bytes = 8967,
    hash = 3188644752,
    oldBytes = 8897,
    oldHash = 2519681235,
    changes = {
        {
            at = 7570,
            current = "        -- The new-item field and Add share the row above the item cards.\n        local function insertItem(gap)\n            if p.newItem=='' or not w:Accept(p.newItem) then p:Message(L['Choose an item first.']);return end\n            table.insert(w.draft,math.max(1,math.min(gap,#w.draft+1)),p.newItem);p.newItem='';p:Draw()\n        end\n",
            previous = "",
        },
        {
            at = 8428,
            current = "        end,function() end,{prefix='item',compact=true,readOnly=type(w.target)~='table',add={key='add_item',text=L['Add item'],insert=insertItem,\n            leading=function(form,y,width) return self:LayoutNewItemField(form,form:Reference('new_item',nil,p.newItem,w.editbox,{accept=function(value) return w:Accept(value) end},function(value) p.newItem=value end,true),y,width) end}})\n",
            previous = "        end,function() end,{prefix='item',compact=true,readOnly=type(w.target)~='table'})\n        local y=p.y;local newItem=p:Reference('new_item',L['Item'],p.newItem,w.editbox,{accept=function(value) return w:Accept(value) end},function(value) p.newItem=value end,true);newItem:SetWidth(math.max(60,p.width-334))\n        local add=p:Button('add_item',L['Add item'],function()\n            if p.newItem=='' or not w:Accept(p.newItem) then p:Message(L['Choose an item first.']);return end\n            table.insert(w.draft,p.newItem);p.newItem='';p:Draw()\n        end,'plus');add:ClearAllPoints();add:SetPoint('TOPRIGHT',0,-y);add:SetWidth(104);p.y=p.y-28\n",
        },
    },
}

records["UI/lua_editor.lua"] = {
    bytes = 26624,
    hash = 1928857555,
    oldBytes = 26599,
    oldHash = 1791765547,
    changes = {
        {
            at = 11339,
            current = "    local c={frame=self:TrackWorkbenchSize(CreateFrame('Frame',nil,parent)),provider='native',valid=valid,changed=changed}\n",
            previous = "    local c={frame=CreateFrame('Frame',nil,parent),provider='native',valid=valid,changed=changed}\n",
        },
    },
}

records["UI/preview.lua"] = {
    bytes = 18280,
    hash = 3728756344,
    oldBytes = 18254,
    oldHash = 36259924,
    changes = {
        {
            at = 1612,
            current = "        local frame=addon:TrackWorkbenchSize(CreateFrame('Frame',nil,UIParent));frame:SetFrameStrata('MEDIUM');frame:SetMovable(true);frame:SetResizable(true);frame:SetClampedToScreen(true);frame:EnableMouse(false)\n",
            previous = "        local frame=CreateFrame('Frame',nil,UIParent);frame:SetFrameStrata('MEDIUM');frame:SetMovable(true);frame:SetResizable(true);frame:SetClampedToScreen(true);frame:EnableMouse(false)\n",
        },
    },
}

records["UI/rotation_browser.lua"] = {
    bytes = 26107,
    hash = 734944635,
    oldBytes = 25536,
    oldHash = 2453721151,
    changes = {
        {
            at = 808,
            current = "    local frame=addon:TrackWorkbenchSize(CreateFrame(\"Frame\",nil,parent));frame:SetPoint(\"TOPLEFT\",parent,\"TOPLEFT\",0,0)\n",
            previous = "    local frame=CreateFrame(\"Frame\",nil,parent);frame:SetPoint(\"TOPLEFT\",parent,\"TOPLEFT\",0,0)\n",
        },
        {
            at = 1044,
            current = "    local specs=addon:TrackWorkbenchSize(CreateFrame(\"Frame\",nil,frame));browser.specs=specs\n    local left=addon:TrackWorkbenchSize(CreateFrame(\"Frame\",nil,frame));browser.left=left\n    local detail=addon:TrackWorkbenchSize(CreateFrame(\"Frame\",nil,frame));browser.detail=detail\n    -- The editor touches the page \"?\" corner; it inherits the reserve.\n    detail.rmHelpReserve=addon:GetWorkbenchHelpReserve(frame)\n",
            previous = "    local specs=CreateFrame(\"Frame\",nil,frame);browser.specs=specs\n    local left=CreateFrame(\"Frame\",nil,frame);browser.left=left\n    local detail=CreateFrame(\"Frame\",nil,frame);browser.detail=detail\n",
        },
        {
            at = 4283,
            current = "    -- Rows follow the list column; the scroll bar reserves space only when shown.\n    function list:OnWorkbenchColumnResized(width) empty:SetWidth(math.max(40,width-8));browser:RefreshViewport() end\n    browser.splitter=addon:CreateWorkbenchSplitter(frame,function() if browser.active then browser:Layout() end end)\n",
            previous = "",
        },
        {
            at = 21984,
            current = "        self.splitter:Place(geometry)\n        addon:LayoutWorkbenchRow({self.filters.all,self.filters.builtin,self.filters.custom},0,28,leftWidth)\n",
            previous = "        for index,key in ipairs({'all','builtin','custom'}) do local filter=self.filters[key];filter:ClearAllPoints();filter:SetPoint('TOPLEFT',left,'TOPLEFT',(index-1)*(leftWidth+4)/3,-28);filter:SetWidth((leftWidth-8)/3) end\n",
        },
        {
            at = 22355,
            current = "        list:SetPoint(\"TOPLEFT\",left,\"TOPLEFT\",0,-listTop);list:SetHeight(math.max(64,left:GetHeight()-listTop-36-footerHeight))\n        list:SetWorkbenchColumnWidth(leftWidth);child:SetWidth(list:GetWidth())\n        count:ClearAllPoints();count:SetPoint(\"BOTTOMLEFT\",left,\"BOTTOMLEFT\",0,footerHeight+8);count:SetWidth(leftWidth)\n",
            previous = "        list:SetPoint(\"TOPLEFT\",left,\"TOPLEFT\",0,-listTop);list:SetSize(leftWidth-24,math.max(64,left:GetHeight()-listTop-36-footerHeight))\n        child:SetWidth(list:GetWidth())\n        count:ClearAllPoints();count:SetPoint(\"BOTTOMLEFT\",left,\"BOTTOMLEFT\",0,footerHeight+8)\n",
        },
        {
            at = 22727,
            current = "        for _,control in ipairs({new,duplicate,import,compare}) do control:ClearAllPoints();control:SetWidth(buttonWidth);addon:AlignWorkbenchTextLeft(control,24) end\n",
            previous = "        for _,control in ipairs({new,duplicate,import,compare}) do control:ClearAllPoints();control:SetWidth(buttonWidth) end\n",
        },
    },
}

records["UI/rotation_canvas.lua"] = {
    bytes = 39515,
    hash = 3316515723,
    oldBytes = 27894,
    oldHash = 3639761049,
    changes = {
        {
            at = 468,
            current = "-- The scene builder lays cards out at their 340 px design width. A diagram\n-- keeps that (it pans and zooms in two dimensions), but the vertical list and\n-- the cooldown grid fill the viewport: list cards reach the right edge less\n-- 8 px per nested branch, and grid columns share the row. Nothing narrows.\nlocal listIndent,gridGap,gridCardMaximum=24,24,600\nfunction addon:FitRotationSceneWidth(scene,viewport)\n    if type(scene)~='table' or not finite(viewport) then return scene end\n    local right=math.max(0,viewport-4);local widest=0\n    local function stretch(item,inset,base)\n        local depth=math.max(0,math.floor((item.x-base)/listIndent+.5))\n        item.width=math.max(item.width,right-depth*8-inset-item.x)\n    end\n    if scene.layout=='list' then\n        for _,card in ipairs(scene.cards) do stretch(card,0,0) end\n        for _,group in ipairs(scene.groups or {}) do if group.kind=='arm' then stretch(group,4,20) else stretch(group,0,0) end end\n        for _,target in ipairs(scene.dropTargets or {}) do stretch(target,0,0) end\n    elseif scene.layout=='grid' and #(scene.groups or {})==0 then\n        local design=340;local pitch=design+gridGap;local columns=0\n        for _,card in ipairs(scene.cards) do columns=math.max(columns,math.floor(card.x/pitch+.5)+1) end\n        if columns==0 then return scene end\n        local each=math.max(design,math.min(gridCardMaximum,(right-(columns-1)*gridGap)/columns))\n        local function place(item) local column=math.floor(item.x/pitch+.5);item.x=column*(each+gridGap);item.width=each end\n        for _,card in ipairs(scene.cards) do if card.width==design then place(card) end end\n        for _,target in ipairs(scene.dropTargets or {}) do\n            if target.width==design then place(target) elseif target.width>design then target.x=0;target.width=columns*each+(columns-1)*gridGap end\n        end\n    else return scene end\n    for _,card in ipairs(scene.cards) do widest=math.max(widest,card.x+card.width) end\n    for _,group in ipairs(scene.groups or {}) do widest=math.max(widest,group.x+group.width) end\n    scene.width=math.max(scene.width or 0,widest)\n    return scene\nend\n",
            previous = "",
        },
        {
            at = 2902,
            current = "    canvas.cameraHost=self:TrackWorkbenchSize(CreateFrame('Frame',nil,canvas.surface))\n    canvas.child=self:TrackWorkbenchSize(CreateFrame('Frame',nil,canvas.cameraHost));canvas.child:SetPoint('TOPLEFT')\n    canvas.horizontal=addon:CreateWorkbenchScrollBar(parent,'HORIZONTAL');addon:TrackWorkbenchSize(canvas.horizontal)\n",
            previous = "    canvas.cameraHost=CreateFrame('Frame',nil,canvas.surface)\n    canvas.child=CreateFrame('Frame',nil,canvas.cameraHost);canvas.child:SetPoint('TOPLEFT')\n    canvas.horizontal=addon:CreateWorkbenchScrollBar(parent,'HORIZONTAL')\n",
        },
        {
            at = 3491,
            current = "        self.drag=nil;self.pan=nil;self.box=nil;if self.boxFrame then self.boxFrame:Hide() end;self.ghost:Hide();addon:SetUIScript(self.frame,'OnUpdate',nil)\n",
            previous = "        self.drag=nil;self.pan=nil;self.ghost:Hide();addon:SetUIScript(self.frame,'OnUpdate',nil)\n",
        },
        {
            at = 5532,
            current = "    -- Several cards can be selected: Ctrl-click toggles a card, Shift-click\n    -- selects the sibling range from the last clicked card, a plain click on\n    -- a card's body selects only it, and a plain click on empty canvas clears\n    -- the selection. Shift-drag on empty canvas draws a box that selects the\n    -- cards it touches (Ctrl+Shift adds to the selection). The selection is\n    -- view state: it survives renders and drops cards that no longer exist.\n    function canvas:SelectionSet() owner.view.selection=owner.view.selection or {};return owner.view.selection end\n    -- Selected ids in document order; with topLevel, a card inside another\n    -- selected card is left out (it travels with its parent).\n    function canvas:SelectedIds(topLevel)\n        local selection=self:SelectionSet();local result={}\n        if next(selection)==nil then return result end\n        local index=addon.RotationData.IndexRotationSteps(owner.workspace:Snapshot())\n        if not index then return result end\n        local chosen={}\n        for _,row in ipairs(index.rows) do if selection[row.step.id] then chosen[#chosen+1]=row end end\n        for _,row in ipairs(chosen) do\n            local nested=false\n            if topLevel then for _,other in ipairs(chosen) do if other~=row and #other.path<#row.path then\n                local inside=true;for i=1,#other.path do if other.path[i]~=row.path[i] then inside=false;break end end\n                if inside then nested=true;break end\n            end end end\n            if not nested then result[#result+1]=row.step.id end\n        end\n        return result\n    end\n    function canvas:PaintSelection()\n        local selection=self:SelectionSet()\n        for _,card in ipairs(self.cards) do if card.token and card.model and card.SetSelected then card:SetSelected(selection[card.model.id]==true) end end\n        if owner.SelectionChanged then owner:SelectionChanged() end\n    end\n    function canvas:ClearSelection()\n        if next(self:SelectionSet())==nil then return end\n        owner.view.selection={};self.anchor=nil;self:PaintSelection()\n    end\n    function canvas:Select(id,toggle,range)\n        if not owner.active or not self.scene then return end\n        local selection=self:SelectionSet();local byId={};for _,model in ipairs(self.scene.cards) do byId[model.id]=model end\n        local model=byId[id];if not model then return end\n        local anchor=self.anchor and byId[self.anchor]\n        if range and anchor and anchor.parentId==model.parentId and #anchor.path==#model.path and anchor.path[1]==model.path[1] then\n            if not toggle then selection={} end\n            local depth=#model.path;local low,high=math.min(anchor.path[depth],model.path[depth]),math.max(anchor.path[depth],model.path[depth])\n            for _,other in ipairs(self.scene.cards) do\n                if other.parentId==model.parentId and #other.path==depth and other.path[1]==model.path[1] and other.path[depth]>=low and other.path[depth]<=high then selection[other.id]=true end\n            end\n        elseif toggle then selection[id]=not selection[id] or nil\n        else selection={[id]=true} end\n        owner.view.selection=selection;if not range then self.anchor=id end\n        self:PaintSelection()\n    end\n    -- Selects the cards touching a box given in canvas (child) coordinates.\n    function canvas:SelectBox(left,top,right,bottom,additive)\n        if not owner.active or not self.scene then return end\n        local selection=additive and self:SelectionSet() or {}\n        for _,model in ipairs(self.scene.cards) do\n            if model.x<=right and model.x+model.width>=left and model.y<=bottom and model.y+model.height>=top then selection[model.id]=true end\n        end\n        owner.view.selection=selection;self:PaintSelection()\n    end\n    function canvas:BeginBoxSelect()\n        if not owner.active or self.drag then return false end\n        local x,y=addon:WorkbenchPointerIn(self.child);if not x then return false end\n        self:CancelDrag()\n        local box={x=x,y=y,additive=IsControlKeyDown and IsControlKeyDown() or false,generation=self.generation};self.box=box\n        self.boxFrame=self.boxFrame or addon:CreateWorkbenchSelectionBox(self.child);self.boxFrame:Place(x,y,x,y)\n        addon:SetUIScript(self.frame,'OnUpdate',function()\n            if self.box~=box then return end\n            if not owner.active or box.generation~=self.generation then self:CancelDrag();return end\n            local cx,cy=addon:WorkbenchPointerIn(self.child);if cx then box.cx,box.cy=cx,cy;self.boxFrame:Place(box.x,box.y,cx,cy) end\n            if IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then self:EndBoxSelect() end\n        end)\n        return true\n    end\n    function canvas:EndBoxSelect()\n        local box=self.box;if not box then return end\n        local cx,cy=box.cx or box.x,box.cy or box.y;self:CancelDrag()\n        self:SelectBox(math.min(box.x,cx),math.min(box.y,cy),math.max(box.x,cx),math.max(box.y,cy),box.additive)\n    end\n",
            previous = "",
        },
        {
            at = 11834,
            current = "            if math.abs(cx-request.x)+math.abs(cy-request.y)>3 then request.moved=true end\n",
            previous = "",
        },
        {
            at = 12140,
            current = "    function canvas:BindViewportInput(control,pan,alive,click)\n",
            previous = "    function canvas:BindViewportInput(control,pan,alive)\n",
        },
        {
            at = 12815,
            current = "            elseif button=='LeftButton' and self.box then self:EndBoxSelect()\n            elseif button=='LeftButton' then\n                -- A click (not a pan or drag) on a card selects; on empty\n                -- canvas it clears the selection.\n                local request=self.pan;local moved=request and request.moved;if request then self:CancelDrag() end\n                if click then if not control.rmDragged then click() end\n                elseif pan and not moved then self:ClearSelection() end\n            end\n",
            previous = "            elseif button=='LeftButton' and self.pan then self:CancelDrag() end\n",
        },
        {
            at = 13422,
            current = "            local function begin() if IsShiftKeyDown and IsShiftKeyDown() then self:BeginBoxSelect() else self:BeginPan() end end\n            addon:SetUIScript(control,'OnMouseDown',function(_,button) if button=='LeftButton' then begin() end end)\n            addon:SetUIScript(control,'OnDragStart',function() if not self.box and not self.pan then begin() end end)\n            addon:SetUIScript(control,'OnDragStop',function() if self.box then self:EndBoxSelect() elseif self.pan then self:CancelDrag() end end)\n",
            previous = "            addon:SetUIScript(control,'OnMouseDown',function(_,button) if button=='LeftButton' then self:BeginPan() end end)\n            addon:SetUIScript(control,'OnDragStart',function() self:BeginPan() end)\n            addon:SetUIScript(control,'OnDragStop',function() if self.pan then self:CancelDrag() end end)\n",
        },
        {
            at = 14181,
            current = "    local function dragCommand(drag) return drag.insert and 'Insert' or drag.ids and 'MoveMany' or (drag.tail and 'MoveTail' or 'Move') end\n",
            previous = "",
        },
        {
            at = 14772,
            current = "        local command=dragCommand(drag)\n        local ok=draft and draft:Command(command,drag.insert and d or drag.ids or drag.id,drag.insert or d)\n        if ok and drag.ids then\n            -- A gap that leaves every carried card where it was is no move.\n            local before=addon.RotationData.IndexRotationSteps(owner.workspace:Snapshot()).byId\n            local after=addon.RotationData.IndexRotationSteps(draft:Snapshot()).byId\n            local moved=false\n            for _,id in ipairs(drag.ids) do if not before[id] or not after[id] or location(before[id].path)~=location(after[id].path) then moved=true;break end end\n            ok=moved\n        elseif ok and not drag.insert then\n",
            previous = "        local command=drag.insert and 'Insert' or (drag.tail and 'MoveTail' or 'Move')\n        local ok=draft and draft:Command(command,drag.insert and d or drag.id,drag.insert or d)\n        if ok and not drag.insert then\n",
        },
        {
            at = 16423,
            current = "        return owner:Command(dragCommand(drag),drag.insert and target.destination or drag.ids or drag.id,drag.insert or target.destination)\n",
            previous = "        local command=drag.insert and 'Insert' or (drag.tail and 'MoveTail' or 'Move')\n        return owner:Command(command,drag.insert and target.destination or drag.id,drag.insert or target.destination)\n",
        },
        {
            at = 17422,
            current = "        -- Dragging a selected card carries the whole selection.\n        local carriedIds=id and not self.drag.tail and self:SelectionSet()[id] and self:SelectedIds(true)\n        if carriedIds and #carriedIds>1 then\n            self.drag.ids=carriedIds;title=string.format(L['Move %d selected cards'],#carriedIds)\n            count=0;local index=addon.RotationData.IndexRotationSteps(owner.workspace:Snapshot())\n            for _,carried in ipairs(carriedIds) do\n                local source=index.byId[carried]\n                for _,row in ipairs(index.rows) do\n                    local inside=#row.path>=#source.path\n                    for i=1,#source.path do if row.path[i]~=source.path[i] then inside=false;break end end\n                    if inside and not selected[row.step.id] then selected[row.step.id]=true;count=count+1 end\n                end\n            end\n        elseif id then\n",
            previous = "        if id then\n",
        },
        {
            at = 21289,
            current = "        -- The viewport this layout was made for (see the editor's resize).\n        self.reflowedWidth,self.reflowedHeight=self.frame:GetWidth(),self.frame:GetHeight()\n",
            previous = "",
        },
        {
            at = 23803,
            current = "        -- Cards that left the scene (removed, or under a folded branch) leave\n        -- the selection.\n        local selection=self:SelectionSet();for selected in pairs(selection) do if not byId[selected] then selection[selected]=nil end end\n        if owner.SelectionChanged then owner:SelectionChanged() end\n",
            previous = "",
        },
        {
            at = 33777,
            current = "        local function modifiers() return IsControlKeyDown and IsControlKeyDown() or false,IsShiftKeyDown and IsShiftKeyDown() or false end\n        local function clickBody() if not alive() then return end;local ctrl,shift=modifiers();self:Select(model.id,ctrl,shift) end\n",
            previous = "",
        },
        {
            at = 34135,
            current = "            self:BindViewportInput(source,false,alive,source==card.frame and clickBody or nil)\n",
            previous = "            self:BindViewportInput(source,false,alive)\n",
        },
        {
            at = 34405,
            current = "        -- Ctrl-click anywhere on a card toggles it; Shift-click on its title\n        -- or condition extends the range (Shift-click on the action still\n        -- links the spell). Other clicks keep their own meaning.\n        for _,source in ipairs({card.title,card.action,card.condition}) do\n            local original=source:GetScript('OnClick')\n            addon:SetUIScript(source,'OnClick',function(...)\n                local ctrl,shift=modifiers()\n                if alive() and (ctrl or shift and source~=card.action) then if not source.rmDragged then self:Select(model.id,ctrl,shift) end;source.rmDragged=false;return end\n                if original then return original(...) end\n            end)\n        end\n        if card.SetSelected then card:SetSelected(self:SelectionSet()[model.id]==true) end\n",
            previous = "",
        },
        {
            at = 35759,
            current = "    end\n    -- Expanded cards lay their fields out for the card width when bound. A\n    -- width change releases them (unless one holds focus) so the next reflow\n    -- binds them at the new width; every other card is only re-placed.\n    function canvas:ReleaseExpandedCards()\n        for _,card in ipairs(self.cards) do\n            if card.token and card.model and card.model.expanded and not focused(card) and card.frame:GetParent()~=self.ghost then card:Release();card.model=nil end\n        end\n",
            previous = "",
        },
        { at = 38798, current = "        self.renderedWidth=self.frame:GetWidth()\n", previous = "" },
    },
}

records["UI/rotation_cards.lua"] = {
    bytes = 10822,
    hash = 182416016,
    oldBytes = 9936,
    oldHash = 729923698,
    changes = {
        {
            at = 4465,
            current = "        self.action:SetText(action);self.action:SetWidth(math.max(256,model.width-84));addon:AlignWorkbenchTextLeft(self.action,3)\n",
            previous = "        self.action:SetText(action);self.action:SetWidth(256);addon:AlignWorkbenchTextLeft(self.action,3)\n",
        },
        {
            at = 7841,
            current = "            self.condition:SetWidth(math.max(280,model.width-60));self.condition:GetFontString():SetWidth(math.max(274,model.width-66))\n",
            previous = "            self.condition:SetWidth(280);self.condition:GetFontString():SetWidth(274)\n",
        },
        {
            at = 8697,
            current = "    -- A selected card wears a gold outline over its border.\n    function card:SetSelected(selected)\n        if selected and not self.selection then\n            self.selection={}\n            for _,side in ipairs({{'TOPLEFT','TOPRIGHT','h'},{'BOTTOMLEFT','BOTTOMRIGHT','h'},{'TOPLEFT','BOTTOMLEFT','v'},{'TOPRIGHT','BOTTOMRIGHT','v'}}) do\n                local edge=frame:CreateTexture(nil,'OVERLAY');edge:SetColorTexture(1,.82,.2,.95);edge:SetPoint(side[1]);edge:SetPoint(side[2])\n                if side[3]=='h' then edge:SetHeight(2) else edge:SetWidth(2) end;self.selection[#self.selection+1]=edge\n            end\n        end\n        self.selected=selected==true\n        for _,edge in ipairs(self.selection or {}) do if self.selected then edge:Show() else edge:Hide() end end\n    end\n",
            previous = "",
        },
        {
            at = 9747,
            current = "        self.token=nil;self.frame:Hide();self.name:ClearFocus();self:SetSelected(false)\n",
            previous = "        self.token=nil;self.frame:Hide();self.name:ClearFocus()\n",
        },
    },
}

records["UI/rotation_comparison.lua"] = {
    bytes = 16062,
    hash = 176053984,
    oldBytes = 16028,
    oldHash = 4087480245,
    changes = {
        {
            at = 4153,
            current = "    local widget=addon:CreateConditionLabel();if kind=='Heading' then widget:SetFontObject(addon.WorkbenchHeaderFont);widget:SetColor(unpack(addon.WorkbenchHeaderColor)) end;widget:SetFullWidth(true);widget:SetText(text);parent:AddChild(widget)\n",
            previous = "    local widget=addon:CreateConditionLabel();if kind=='Heading' then widget:SetFontObject('GameFontNormal');widget:SetColor(1,.82,.25) end;widget:SetFullWidth(true);widget:SetText(text);parent:AddChild(widget)\n",
        },
    },
}

records["UI/rotation_editor.lua"] = {
    bytes = 33992,
    hash = 2249545573,
    oldBytes = 29363,
    oldHash = 974058566,
    changes = {
        {
            at = 675,
            current = "    local pane={frame=self:TrackWorkbenchSize(CreateFrame('Frame',nil,parent)),workspace=workspace,view={collapsed={},expanded={},detailsHeights={}},active=false,tools={}}\n",
            previous = "    local pane={frame=CreateFrame('Frame',nil,parent),workspace=workspace,view={collapsed={},expanded={},detailsHeights={}},active=false,tools={}}\n",
        },
        { at = 3439, current = "        addon:FitRotationSceneWidth(scene,self.view.viewportWidth)\n", previous = "" },
        {
            at = 11189,
            current = "    pane.switchLabel=addon:CreateWorkbenchButton(pane.frame,L['Switch condition'],180);addon:StyleWorkbenchHeader(pane.switchLabel:GetFontString());pane.switchLabel.art:SetAlpha(.1);addon:AlignWorkbenchTextLeft(pane.switchLabel,0)\n",
            previous = "    pane.switchLabel=addon:CreateWorkbenchButton(pane.frame,L['Switch condition'],180);pane.switchLabel:GetFontString():SetFontObject('GameFontNormal');pane.switchLabel.art:SetAlpha(.1);addon:AlignWorkbenchTextLeft(pane.switchLabel,0)\n",
        },
        {
            at = 14110,
            current = "    -- Bulk actions on the selected cards, left of Apply. Each is one command,\n    -- so one Undo reverses it.\n    local bar=CreateFrame('Frame',nil,pane.frame);pane.selectionBar=bar;bar:SetSize(196,22);bar:SetPoint('BOTTOMRIGHT',-194,8);bar:Hide()\n    bar.label=text(bar);bar.label:SetPoint('LEFT',0,0);bar.label:SetWidth(84);bar.label:SetJustifyH('RIGHT')\n    bar.buttons={}\n    for i,entry in ipairs({{'duplicate','copy',L['Duplicate selected cards']},{'enable','check',L['Enable selected cards']},{'disable','minus',L['Disable selected cards']},{'remove','trash',L['Delete selected cards']},{'clear','close',L['Clear selection']}}) do\n        local button=self:CreateWorkbenchIconButton(bar,entry[2],entry[3]);button:SetSize(20,20);button:SetPoint('LEFT',88+(i-1)*22,0);bar.buttons[entry[1]]=button\n        if entry[1]=='remove' then button.icon:SetVertexColor(1,.3,.3,1) end\n        addon:SetUIScript(button,'OnClick',function() if pane.active then pane:BulkCommand(entry[1]) end end)\n    end\n    function pane:SelectionChanged()\n        local count=#self.canvas:SelectedIds(false);local width=self.frame:GetWidth()\n        if count==0 or not self.active then bar:Hide() else\n            bar.label:SetText(string.format(L['%d selected'],count));bar:Show()\n            local editable=not self.workspace.readOnly\n            for key,button in pairs(bar.buttons) do if key=='clear' or editable then button:Enable() else button:Disable() end end\n        end\n        local reserve=bar:IsShown() and 200 or 0\n        self.status:SetWidth(math.max(1,width-330-reserve));self.hint:SetWidth(math.max(1,width-330-reserve))\n    end\n    function pane:BulkCommand(kind)\n        if not self.active then return end\n        if kind=='clear' then self.canvas:ClearSelection();return end\n        if self.workspace.readOnly then return end\n        local index=addon.RotationData.IndexRotationSteps(self.workspace:Snapshot());if not index then return end\n        local operations={}\n        if kind=='duplicate' or kind=='remove' then\n            for _,id in ipairs(self.canvas:SelectedIds(true)) do operations[#operations+1]={kind=='duplicate' and 'Duplicate' or 'Remove',id} end\n        else\n            -- Branches keep their Evaluate / Always mode; only steps toggle.\n            local disabled=kind=='disable'\n            for _,id in ipairs(self.canvas:SelectedIds(false)) do\n                local row=index.byId[id];if row and row.step.type~='branch' and (row.step.disabled==true)~=disabled then operations[#operations+1]={'UpdateStep',id,{disabled=disabled}} end\n            end\n        end\n        if #operations==0 then return end\n        local ok=self:Command('Batch',operations)\n        if ok and kind=='remove' then self.canvas:ClearSelection() end\n        return ok\n    end\n",
            previous = "",
        },
        {
            at = 24104,
            current = "        local reserve=addon:GetWorkbenchHelpReserve(self.frame)\n        self.name:ClearAllPoints();self.name:SetPoint('TOPLEFT',86,-4);self.name:SetWidth(math.max(100,width-94-self.info:GetWidth()-8-reserve))\n        self.info:ClearAllPoints();self.info:SetPoint('TOPRIGHT',self.frame,'TOPRIGHT',-8-reserve,-4)\n",
            previous = "        self.name:ClearAllPoints();self.name:SetPoint('TOPLEFT',86,-4);self.name:SetWidth(math.max(100,width-94-self.info:GetWidth()-8))\n        self.info:ClearAllPoints();self.info:SetPoint('TOPRIGHT',self.frame,'TOPRIGHT',-8,-4)\n",
        },
        {
            at = 26157,
            current = "        self.canvas.frame:SetSize(math.max(1,width-40),math.max(1,height-top-48));self.canvas:LayoutScrollBar();local barReserve=self.selectionBar and self.selectionBar:IsShown() and 200 or 0;self.status:SetWidth(math.max(1,width-330-barReserve));self.hint:SetWidth(math.max(1,width-330-barReserve));if (self.status:GetText() or '')=='' then self.hint:Show() else self.hint:Hide() end\n",
            previous = "        self.canvas.frame:SetSize(math.max(1,width-40),math.max(1,height-top-48));self.canvas:LayoutScrollBar();self.status:SetWidth(math.max(1,width-330));self.hint:SetWidth(math.max(1,width-330));if (self.status:GetText() or '')=='' then self.hint:Show() else self.hint:Hide() end\n",
        },
        {
            at = 27034,
            current = "        if addon.CancelWorkbenchReflow then addon:CancelWorkbenchReflow(self) end\n",
            previous = "",
        },
        {
            at = 32112,
            current = "    -- A resize lays out the header and viewport at once. Cards follow through\n    -- the shared reflow driver, once per rendered frame at most, by geometry\n    -- alone: bound cards are re-placed, never released and bound again. The\n    -- diagram keeps its card widths, so that is all it needs. List and\n    -- cooldown cards take the viewport width, which rewraps their text, so\n    -- once the size has settled they are bound again (measured) in one render.\n    function pane:Resized()\n        if not self.active then return end\n        self:LayoutGeometry()\n        local canvas=self.canvas\n        local function stale() return canvas.frame:GetWidth()~=canvas.reflowedWidth or canvas.frame:GetHeight()~=canvas.reflowedHeight end\n        if not stale() then return end\n        if not addon.RequestWorkbenchReflow then return self:Render() end\n        local token=self.generation\n        local function current() return self.active and self.generation==token end\n        addon:RequestWorkbenchReflow(self,self.frame,function()\n            if not current() or not stale() then return end\n            if not canvas:IsDiagram() and canvas.frame:GetWidth()~=canvas.reflowedWidth then canvas:ReleaseExpandedCards() end\n            canvas:Reflow()\n        end)\n        if not canvas:IsDiagram() then\n            addon:RequestWorkbenchSettle(self,self.frame,function() if current() and not canvas:IsDiagram() and canvas.frame:GetWidth()~=canvas.renderedWidth then self:Render() end end)\n        end\n    end\n    addon:SetUIScript(pane.frame,'OnSizeChanged',function() pane:Resized() end)\n",
            previous = "    addon:SetUIScript(pane.frame,'OnSizeChanged',function() pane:Layout() end)\n",
        },
    },
}

records["UI/rotation_navigation.lua"] = {
    bytes = 5971,
    hash = 2100337607,
    oldBytes = 5490,
    oldHash = 2894771127,
    changes = {
        {
            at = 1097,
            current = "            self.deletePrompt={frame=frame,label=label,confirm=confirm,cancel=cancel};frame:Hide()\n",
            previous = "            self.deletePrompt={frame=frame,confirm=confirm,cancel=cancel};frame:Hide()\n",
        },
        {
            at = 1208,
            current = "        local deleteWidth=addon:FitWorkbenchPrompt(self.deletePrompt.frame,self.frame,390);self.deletePrompt.label:SetWidth(math.max(1,deleteWidth-24))\n",
            previous = "",
        },
        {
            at = 4172,
            current = "        -- The prompt covers the editor pane, so it shares the pane's width.\n        local promptWidth=addon:FitWorkbenchPrompt(prompt.frame,self.frame,420);prompt.message:SetWidth(math.max(1,promptWidth-28))\n        addon:LayoutWorkbenchRow({prompt.apply,prompt.discard,prompt.cancel},14,96,promptWidth-28,{gap=10})\n",
            previous = "",
        },
    },
}

records["UI/rotation_reference.lua"] = {
    bytes = 6634,
    hash = 1838102895,
    oldBytes = 6600,
    oldHash = 854366692,
    changes = {
        {
            at = 122,
            current = "    local widget=addon:CreateConditionLabel();if kind=='Heading' then widget:SetFontObject(addon.WorkbenchHeaderFont);widget:SetColor(unpack(addon.WorkbenchHeaderColor)) end\n",
            previous = "    local widget=addon:CreateConditionLabel();if kind=='Heading' then widget:SetFontObject('GameFontNormal');widget:SetColor(1,.82,.25) end\n",
        },
    },
}

records["UI/schema_editor.lua"] = {
    bytes = 5779,
    hash = 2755607869,
    oldBytes = 5753,
    oldHash = 3987567257,
    changes = {
        {
            at = 962,
            current = "    d.host=d.host or addon:TrackWorkbenchSize(CreateFrame('Frame',nil,frame));d.host:SetPoint('TOPLEFT',8,-64);d.host:SetSize(744,420)\n",
            previous = "    d.host=d.host or CreateFrame('Frame',nil,frame);d.host:SetPoint('TOPLEFT',8,-64);d.host:SetSize(744,420)\n",
        },
    },
}

records["UI/settings_announces.lua"] = {
    bytes = 24951,
    hash = 1485521963,
    oldBytes = 27489,
    oldHash = 2283616000,
    changes = {
        {
            at = 330,
            current = "local types={{value='spell',text=L['Spell']},{value='pet',text=L['Pet Spell']},{value='item',text=L['Item']},{value='macro',text=L['Via Script/Macro']}}\n",
            previous = "local types={{value='spell',text=L['Spell']},{value='pet',text=L['Pet Spell']},{value='item',text=L['Item']},{value='macro',text=L['Via Macro']}}\n",
        },
        {
            at = 5192,
            current = "        -- Add sits on the Outputs header row; a click appends and a drag drops\n        -- into a gap, both through this one insert.\n        local function insertOutput(gap)\n            if not collectionCurrent()or #items>=64 then return end\n            local output={id=self:uuid(),announce='partyraid',value=''};if not collectionCurrent()then return end\n            local outputs=materialize();if not outputs then return end\n            table.insert(outputs,math.max(1,math.min(gap,#outputs+1)),output);p:Draw()\n        end\n",
            previous = "        p:Heading(L['Outputs'])\n",
        },
        {
            at = 7429,
            current = "            -- The card has no title row: Announce is its first row, beside the\n            -- Enabled pill and Help at the card's top right.\n            choice:SetWidth(math.max(60,p.width-(p.labelX or 220)-row.firstRowReserve))\n",
            previous = "",
        },
        {
            at = 11966,
            current = "            -- The shared card owns the rail (Help, Duplicate, Delete) and the\n            -- Enabled pill; this card wires their actions.\n            local duplicate=row.duplicate\n",
            previous = "            row.header:SetWidth(math.max(1,row:GetWidth()-128))\n            row.remove:ClearAllPoints();row.remove:SetPoint('TOPRIGHT',-4,-44);row.remove:SetSize(20,20)\n            local duplicate=p:Acquire('outputDuplicate',function()return self:CreateWorkbenchIconButton(row,'copy',L['Duplicate'])end)\n            duplicate:SetParent(row);duplicate:ClearAllPoints();duplicate:SetPoint('TOPRIGHT',-5,-24);duplicate:SetSize(20,20);if #items>=64 then duplicate:Disable()else duplicate:Enable()end\n",
        },
        {
            at = 12797,
            current = "            local help=row.help;p.fields[prefix..'output'..index..'help']=help\n",
            previous = "            local help=p:Acquire('outputHelp',function()return self:CreateWorkbenchHelpButton(row,L['Help'])end)\n            help:SetParent(row);help:ClearAllPoints();help:SetPoint('TOPRIGHT',-5,-3);help:SetSize(20,20);help.icon:SetSize(18,18);p.fields[prefix..'output'..index..'help']=help\n",
        },
        {
            at = 13144,
            current = "            local enabled=row.enabled\n",
            previous = "            local enabled=p:Acquire('outputEnabled',function()return self:CreateWorkbenchPill(row,'',70)end)\n            enabled:SetParent(row);enabled:ClearAllPoints();enabled:SetPoint('TOPRIGHT',-28,-4);enabled:SetSize(70,18)\n",
        },
        {
            at = 14082,
            current = "        end,structuralChange,{prefix=prefix..'output',unsavedKey='outputs',current=collectionCurrent,help=true,duplicate=true,canDuplicate=function() return #items<64 end,enabled=true,heading=L['Outputs'],\n            add={key=prefix..'add_output',text=L['Add output'],enabled=#items<64,insert=insertOutput}})\n",
            previous = "        end,structuralChange,{prefix=prefix..'output',unsavedKey='outputs',current=collectionCurrent})\n",
        },
        {
            at = 14444,
            current = "",
            previous = "        local add=p:Button(prefix..'add_output',L['Add output'],function()\n            if not collectionCurrent()or #items>=64 or not p:FlushEdits()or not collectionCurrent()then return end\n            local output={id=self:uuid(),announce='partyraid',value=''};if not collectionCurrent()then return end\n            local outputs=materialize();if not outputs then return end\n            outputs[#outputs+1]=output;p:Draw()\n        end)\n        if #items>=64 then add:Disable()end\n",
        },
        {
            at = 15077,
            current = "        if entry.type=='macro' then return {name=entry.identifier or L['Via Script/Macro']} end\n",
            previous = "        if entry.type=='macro' then return {name=entry.identifier or L['Via Macro']} end\n",
        },
        {
            at = 21147,
            current = "                if entry.type=='macro' and not identifierFree(entry.identifier,settings.mode=='replace' and selected or nil) then return false,L['Use a unique Via Script/Macro identifier.'] end\n",
            previous = "                if entry.type=='macro' and not identifierFree(entry.identifier,settings.mode=='replace' and selected or nil) then return false,L['Use a unique Via Macro identifier.'] end\n",
        },
        {
            at = 22793,
            current = "    -- The page name is in the tab and title bar; the page \"?\" is the shell's.\n",
            previous = "    p:Heading(L['Announces'])\n    local help=p:Acquire('announceHelp',function() return self:CreateWorkbenchHelpButton(p.child,L['Help']) end)\n    help:ClearAllPoints();help:SetPoint('TOPRIGHT',-4,-3);help:SetSize(20,20);help.icon:SetSize(18,18);p.fields.announce_help=help\n    self:SetUIScript(help,'OnClick',p:Guard(function() self:ShowWorkbenchHelp(L['Announces'],self:WorkbenchPageHelp('Announces'),self.pretty_name) end))\n    if self.TestAnnouncementEmote and self.GetAnnouncementEmoteReport then\n        local token=p.generation\n        local function report()\n            if not p:Valid(token) then return end\n            local request={};p.emoteDiagnosticRequest=request\n            local text=self:GetAnnouncementEmoteReport()\n            if not p:Valid(token) or p.emoteDiagnosticRequest~=request then return end\n            local dialog=p.emoteDiagnosticReport\n            if not dialog then\n                dialog=self:CreateWorkbenchTextReport()\n                if not p:Valid(token) or p.emoteDiagnosticRequest~=request then dialog:Hide();return end\n                p.emoteDiagnosticReport=dialog\n            end\n            dialog:SetReport(L['Emote diagnostics'],text,self.pretty_name)\n            if not p:Valid(token) or p.emoteDiagnosticRequest~=request then\n                if p.emoteDiagnosticReport~=dialog or p.emoteDiagnosticRequest==request then dialog:Hide() end\n            end\n        end\n        local y=p.y\n        local test=p:Button('emote_test',L['Test /cheer'],function() end)\n        local inspect=p:Button('emote_report',L['Emote report'],function() end)\n        local width=(p.width-4)/2\n        test:ClearAllPoints();test:SetPoint('TOPLEFT',0,-y);test:SetWidth(width)\n        inspect:ClearAllPoints();inspect:SetPoint('TOPLEFT',width+4,-y);inspect:SetWidth(width);p.y=y+28\n        -- Explicit diagnostics do not flush or apply the current draft.\n        self:SetUIScript(test,'OnClick',function()\n            if not p:Valid(token) then return end\n            self:TestAnnouncementEmote()\n            if p:Valid(token) then report() end\n        end)\n        self:SetUIScript(inspect,'OnClick',report)\n        p.cleanups[#p.cleanups+1]=function() if p.emoteDiagnosticReport then p.emoteDiagnosticReport:Hide() end end\n    end\n",
        },
        {
            at = 22951,
            current = "        -- No title repeating the name: Name is the first row, narrowed to\n        -- leave the Enabled pill and the trash beside it.\n        local name=p:Edit('entry'..i..'name',L['Name'],entry.name or '',nil,function(value) update(entry,'name',value) end);name:SetWidth(math.max(60,p.width-220-122))\n        if not drawAction('entry'..i,entry)then return end\n        local enabled=p:Acquire('announceEnabled',function() return self:CreateWorkbenchPill(p.child,'',88) end);enabled:ClearAllPoints();enabled:SetPoint('TOPRIGHT',-28,-4);enabled:SetSize(88,18);enabled:SetText(entry.disabled and L['Disabled'] or L['Enabled']);enabled:SetSelected(not entry.disabled);p.fields['enabled'..i]=enabled;self:SetUIScript(enabled,'OnClick',p:Guard(function() if p:FlushEdits() then entry.disabled=not entry.disabled;p:Draw() end end))\n",
            previous = "        local title=self:SettingsNonempty(entry.name) or entry.type=='item' and (itemInfo(entry.item) and itemInfo(entry.item).name or L['Item data loading']) or entry.type=='macro' and (entry.identifier or L['Via Macro']) or self:PlainWorkbenchName(self:SpellLabel(entry.spell))\n        p:Heading(title)\n        p:Edit('entry'..i..'name',L['Name'],entry.name or '',nil,function(value) update(entry,'name',value) end);if not drawAction('entry'..i,entry)then return end\n        local enabled=p:Acquire('announceEnabled',function() return self:CreateWorkbenchPill(p.child,'',88) end);enabled:ClearAllPoints();enabled:SetPoint('TOPRIGHT',-52,-4);enabled:SetSize(88,18);enabled:SetText(entry.disabled and L['Disabled'] or L['Enabled']);enabled:SetSelected(not entry.disabled);p.fields['enabled'..i]=enabled;self:SetUIScript(enabled,'OnClick',p:Guard(function() if p:FlushEdits() then entry.disabled=not entry.disabled;p:Draw() end end))\n",
        },
        {
            at = 24294,
            current = "        local trash=p.fields['delete'..i];trash:ClearAllPoints();trash:SetPoint('TOPRIGHT',0,-4)\n",
            previous = "        local trash=p.fields['delete'..i];trash:ClearAllPoints();trash:SetPoint('TOPRIGHT',-28,-4)\n",
        },
    },
}

records["UI/settings_collections.lua"] = {
    bytes = 7531,
    hash = 2924349653,
    oldBytes = 7727,
    oldHash = 1428831952,
    changes = {
        {
            at = 2456,
            current = "    local scopes={Integrations={profile={'lua_editor','lua_editor_disabled','lua_native_highlighting','lua_line_numbers','questie_enabled','preview_masque'}},Effects={global={'effects'}},ItemSets={profile={'itemsets'},global={'itemsets'}},Announces={profile={'announces'}},Conditions={profile={'condition_groups','switch_conditions','announcement_conditions','other_conditions_order','disabled_conditions'},global={'custom_conditions'}},General={profile={'enable','poll','idle_poll','autoswitch_poll','ignore_mana','ignore_range','effect','color','magnification','setpoint','xoffs','yoffs','loglevel','detailed_profiling','disable_autoswitch','live_config_update','spell_history','combat_history','damage_history','disable_buttons','rotation_view','preview_spells','preview_vertical','preview_locked','preview_opacity','preview_icon_size','preview_window','minimap'},char={'specs'}}}\n",
            previous = "    local scopes={Integrations={profile={'lua_editor','lua_editor_disabled','lua_native_highlighting','lua_line_numbers','questie_enabled','preview_masque'}},Effects={global={'effects'}},ItemSets={profile={'itemsets'},global={'itemsets'}},Announces={profile={'announces'}},Conditions={profile={'condition_groups','switch_conditions','announcement_conditions','other_conditions_order','disabled_conditions'},global={'custom_conditions'}},General={profile={'enable','poll','ignore_mana','ignore_range','effect','color','magnification','setpoint','xoffs','yoffs','loglevel','detailed_profiling','disable_autoswitch','live_config_update','spell_history','combat_history','damage_history','disable_buttons','rotation_view','preview_spells','preview_vertical','preview_locked','preview_opacity','preview_icon_size','preview_window','minimap'},char={'specs'}}}\n",
        },
        {
            at = 5195,
            current = "        local expected={};for scope,keys in pairs(p.transactionKeys or {}) do expected[scope]={};for _,key in ipairs(keys) do expected[scope][key]=self:CopySettingsData(self.db[scope] and self.db[scope][key]) end end\n",
            previous = "        local stockUnrelated=p.settingsKey=='ItemSets'\n        local function ownsKey(scope,key)return not (stockUnrelated and scope=='profile' and key=='stockTargets')end\n        local expected={};for scope,keys in pairs(p.transactionKeys or {}) do expected[scope]={};for _,key in ipairs(keys) do if ownsKey(scope,key) then expected[scope][key]=self:CopySettingsData(self.db[scope] and self.db[scope][key]) end end end\n",
        },
        {
            at = 5816,
            current = "                if not self:SettingsDataEqual(self.db[scope] and self.db[scope][key],expected[scope][key]) then p:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return end\n",
            previous = "                if ownsKey(scope,key) and not self:SettingsDataEqual(self.db[scope] and self.db[scope][key],expected[scope][key]) then p:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return end\n",
        },
    },
}

records["UI/settings_conditions.lua"] = {
    bytes = 21472,
    hash = 166717864,
    oldBytes = 20771,
    oldHash = 2993379710,
    changes = {
        {
            at = 141,
            current = "-- Hidden, Switch Condition and Announcement Condition share one row in\n-- thirds; a row too narrow for their captions wraps instead of clipping.\nfunction addon:LayoutConditionFlags(hidden,switch,announcement,y,width)\n    local widest=0;for _,check in ipairs({hidden,switch,announcement}) do widest=math.max(widest,check:GetFontString():GetStringWidth()) end\n    local height=self:LayoutWorkbenchRow({hidden,switch,announcement},0,y,width,{minimum=widest+30,text=22})\n    hidden.rmFlagRowsHeight=height;return height\nend\n",
            previous = "",
        },
        { at = 7602, current = "", previous = "    p:Heading(L['Conditions'])\n" },
        {
            at = 8074,
            current = "        local special=(self.conditionSpecials or {})[tag]~=nil;local flagsY=p.y\n",
            previous = "        local special=(self.conditionSpecials or {})[tag]~=nil\n",
        },
        {
            at = 9202,
            current = "        -- The three flags share their row in thirds and wrap rather than clip.\n        self:LayoutConditionFlags(hidden,switch,announcement,flagsY,p.width);p.y=flagsY+hidden.rmFlagRowsHeight+2\n",
            previous = "",
        },
    },
}

records["UI/settings_draft.lua"] = {
    bytes = 6948,
    hash = 1937219198,
    oldBytes = 8179,
    oldHash = 455296557,
    changes = {
        {
            at = 1126,
            current = "        return {effect=self.newEffect,announcement=self.newAnnounce,profileName=self.newProfileName,profileSource=self.profileSource,importProfile=self.importProfile,itemSetName=self.newItemSetName,categoryName=self.newGroupName}\n",
            previous = "        return {effect=self.newEffect,announcement=self.newAnnounce,profileName=self.newProfileName,profileSource=self.profileSource,importProfile=self.importProfile,stockTarget=self.newStockTarget,itemSetName=self.newItemSetName,categoryName=self.newGroupName}\n",
        },
        {
            at = 1740,
            current = "        self.draft=nil;self.draftBaseline=nil;self.draftEffects=nil;self.newEffect=nil;self.newAnnounce=nil;self.newProfileName=nil;self.importProfile=nil;self.profileSource=nil;self.newItemSetName=nil;self.newGroupName=nil;self.creating=false;self.creatingCategory=false;self.creationBaseline=nil;self.creationApply=nil;self.emptyDismissed=true\n",
            previous = "        self.draft=nil;self.draftBaseline=nil;self.draftEffects=nil;self.newEffect=nil;self.newAnnounce=nil;self.newProfileName=nil;self.importProfile=nil;self.profileSource=nil;self.newStockTarget=nil;self.newItemSetName=nil;self.newGroupName=nil;self.creating=false;self.creatingCategory=false;self.creationBaseline=nil;self.creationApply=nil;self.emptyDismissed=true\n",
        },
        {
            at = 2585,
            current = "            self.draft={profile=addon:CopySettingsData(addon.db.profile),global=addon:CopySettingsData(addon.db.global),char=addon:CopySettingsData(addon.db.char or {})};self.draftBaseline={};self.draftEffects={}\n",
            previous = "            if self.settingsKey=='ItemSets' then\n                local keys={};for _,key in ipairs(self.transactionKeys.profile or {}) do if key~='stockTargets' then keys[#keys+1]=key end end\n                self.stockEditable=addon.StockSettings.CheckProfile(addon.db.profile)==true\n                if self.stockEditable then keys[#keys+1]='stockTargets' end;self.transactionKeys.profile=keys\n            end\n            self.draft={profile=addon:CopySettingsData(addon.StockSettings.DraftProfile(addon.db.profile)),global=addon:CopySettingsData(addon.db.global),char=addon:CopySettingsData(addon.db.char or {})};self.draftBaseline={};self.draftEffects={}\n",
        },
        {
            at = 3735,
            current = "",
            previous = "        local stockUnchanged=false\n        for _,key in ipairs(self.transactionKeys.profile or {}) do if key=='stockTargets' then\n            if not addon.StockTargets.Validate(self.draft.profile.stockTargets) then self:Message(L['Complete the stock target settings before applying.']);return false end\n            stockUnchanged=equal(self.draft.profile.stockTargets,self.draftBaseline.profile.stockTargets)\n            if not stockUnchanged and not addon.StockSettings.CheckProfile(addon.db.profile) then self:Message(L['Invalid stock targets; data preserved.']);return false end\n        end end\n",
        },
        {
            at = 3821,
            current = "            if not equal(addon.db[scope] and addon.db[scope][key],self.draftBaseline[scope][key]) then self:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return false end\n",
            previous = "            if not (scope=='profile' and key=='stockTargets' and stockUnchanged) and not equal(addon.db[scope] and addon.db[scope][key],self.draftBaseline[scope][key]) then self:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return false end\n",
        },
        {
            at = 4922,
            current = "            if not addon:AreMacroAnnouncementIdentifiersUnique(self.draft.profile.announces or {}) then self:Message(L['Use a unique Via Script/Macro identifier.']);return false end\n",
            previous = "            if not addon:AreMacroAnnouncementIdentifiersUnique(self.draft.profile.announces or {}) then self:Message(L['Use a unique Via Macro identifier.']);return false end\n",
        },
        {
            at = 5646,
            current = "            if not equal(self.draft[scope][key],self.draftBaseline[scope][key]) then\n",
            previous = "            if not (scope=='profile' and key=='stockTargets' and stockUnchanged) and not equal(self.draft[scope][key],self.draftBaseline[scope][key]) then\n",
        },
    },
}

records["UI/settings_effects.lua"] = {
    bytes = 14619,
    hash = 2599452075,
    oldBytes = 14245,
    oldHash = 2815105956,
    changes = {
        {
            at = 4038,
            current = "    p:UseRoster(entries,p.selection,function(id) p.selection=id;p.creating=false;p:Draw() end,{newText=L['Add effect'],new=function() p.previousSelection=p.selection;p.selection=nil;p.creating=true;p.newEffect=nil;p.emptyDismissed=false;p:Draw() end})\n",
            previous = "    p:UseRoster(entries,p.selection,function(id) p.selection=id;p.creating=false;p:Draw() end,{newText=L['Add effect'],new=function() p.previousSelection=p.selection;p.selection=nil;p.creating=true;p.newEffect=nil;p.emptyDismissed=false;p:Draw() end});p:Heading(L['Effects'])\n",
        },
        {
            at = 4902,
            current = "        -- The live preview sits in the caption column beside Name and Type,\n        -- so this page keeps the full-width caption column.\n        if p.labelScope then p.labelScope.custom=true end\n",
            previous = "",
        },
        { at = 7362, current = "", previous = "            p:Heading(L['Sequence'])\n" },
        {
            at = 7430,
            current = "                -- Add step sits on the Sequence header row; a click appends and\n                -- a drag drops into a gap, both through this one insert.\n                local function insertStep(gap)\n                    effect.sequence=effect.sequence or {};local value=effect.type=='pulse' and 1 or effect.type=='animate' and '' or effect.type=='dazzle' and {r=1,g=1,b=1,a=1} or {texture='',angle=0,color={r=1,g=1,b=1,a=1},magnification=1}\n                    table.insert(effect.sequence,math.max(1,math.min(gap,#effect.sequence+1)),value);refresh();p:Draw()\n                end\n",
            previous = "",
        },
        {
            at = 9232,
            current = "                end,refresh,{prefix='seq',heading=L['Sequence'],add={key='sequence_add',text=L['Add step'],insert=insertStep},dragIcon=function(i) return effect.type=='animate' and sequence[i] or effect.type=='custom' and sequence[i].texture or effect.texture end,endPreview=function(ghost) if ghost.effectPreview and self.HideGlow then self:HideGlow(ghost.effectPreview,'settings-drag') end end,dragPreview=function(ghost,i)\n",
            previous = "                end,refresh,{prefix='seq',header=false,dragIcon=function(i) return effect.type=='animate' and sequence[i] or effect.type=='custom' and sequence[i].texture or effect.texture end,endPreview=function(ghost) if ghost.effectPreview and self.HideGlow then self:HideGlow(ghost.effectPreview,'settings-drag') end end,dragPreview=function(ghost,i)\n",
        },
        {
            at = 10569,
            current = "",
            previous = "                p:Button('sequence_add',L['Add step'],function()\n                    effect.sequence=effect.sequence or {};local value=effect.type=='pulse' and 1 or effect.type=='animate' and '' or effect.type=='dazzle' and {r=1,g=1,b=1,a=1} or {texture='',angle=0,color={r=1,g=1,b=1,a=1},magnification=1}\n                    effect.sequence[#effect.sequence+1]=value;refresh();p:Draw()\n                end,'plus')\n",
        },
    },
}

records["UI/settings_form.lua"] = {
    bytes = 44278,
    hash = 391568194,
    oldBytes = 35570,
    oldHash = 1062779351,
    changes = {
        {
            at = 492,
            current = "    local p={frame=addon:TrackWorkbenchSize(CreateFrame('Frame',nil,parent)),pool={},counts={},fields={},edits={},cleanups={},active=false,generation=0,isSettingsForm=true}\n",
            previous = "    local p={frame=CreateFrame('Frame',nil,parent),pool={},counts={},fields={},edits={},cleanups={},active=false,generation=0,isSettingsForm=true}\n",
        },
        {
            at = 698,
            current = "",
            previous = "    addon:SetUIScript(p.frame,\"OnHide\",function()if p.stopStockObservation then p.stopStockObservation()end end)\n",
        },
        {
            at = 2611,
            current = "        return function(...) if self:Valid(token) then local result;if self.WithSettingsHistory then result=self:WithSettingsHistory(callback,...) else result=callback(...) end;if self.transactionKeys and self.fields.apply and not self.creationUsedForNew then if self:IsSettingsDraftDirty() then self.fields.apply:Enable() else self.fields.apply:Disable() end end;return result end end\n",
            previous = "        return function(...) if self:Valid(token) then local result;if self.WithSettingsHistory then result=self:WithSettingsHistory(callback,...) else result=callback(...) end;if self.transactionKeys and self.fields.apply and not self.creationUsedForNew then if self:IsSettingsDraftDirty() then self.fields.apply:Enable() else self.fields.apply:Disable() end end;if self.updateStockObservationActions then self.updateStockObservationActions()end;return result end end\n",
        },
        {
            at = 3157,
            current = "        local c=self.pool[kind][i];if not c then c=build();addon:TrackWorkbenchRegion(c);self.pool[kind][i]=c end;if c.SetParent then c:SetParent(self.surface or self.child) end;c:Show();return c\n",
            previous = "        local c=self.pool[kind][i];if not c then c=build();self.pool[kind][i]=c end;if c.SetParent then c:SetParent(self.surface or self.child) end;c:Show();return c\n",
        },
        {
            at = 3849,
            current = "            local scope=self.labelScope;if scope then local row={label=t,controls=0};scope.rows[#scope.rows+1]=row;self.labelRow=row end\n",
            previous = "",
        },
        {
            at = 4015,
            current = "    end\n    -- Label column. Builders place values at x=220 as before and register\n    -- them; when a scope (the page, a column or a card) ends, its column is\n    -- narrowed to its longest caption and the registered values move left and\n    -- grow by the same amount. A scope with a caption row whose control the\n    -- page placed itself, or with a value the page re-anchored, keeps 220 so\n    -- its rows stay aligned.\n    local function anchorOf(control)\n        if not control.GetPoint or (control.GetNumPoints and control:GetNumPoints()<1) then return end\n        local point,a,b,c,d=control:GetPoint(1)\n        if type(a)=='number' then return point,a,b end\n        return point,c,d\n    end\n    function p:BeginLabelScope() self.labelScopes=self.labelScopes or {};self.labelScopes[#self.labelScopes+1]=self.labelScope;self.labelScope={rows={},controls={}};self.labelRow=nil end\n    function p:LabelControl(control,dx,dw)\n        local scope,row=self.labelScope,self.labelRow;if not scope or not control then return control end\n        local point,x,y=anchorOf(control);if point~='TOPLEFT' or not x then scope.custom=true;return control end\n        -- A value laid out again (InlineCheck re-places its field) keeps one entry.\n        for _,entry in ipairs(scope.controls) do if entry.control==control then entry.x,entry.y,entry.dx,entry.dw=x,y,dx or 1,dw or 0;return control end end\n        scope.controls[#scope.controls+1]={control=control,x=x,y=y,dx=dx or 1,dw=dw or 0};if row then row.controls=row.controls+1 end\n        return control\n    end\n    function p:EndLabelScope()\n        local scope=self.labelScope;self.labelScope=self.labelScopes and table.remove(self.labelScopes) or nil;self.labelRow=nil\n        if not scope or scope.custom or #scope.rows==0 then return end\n        local widest=0\n        for _,row in ipairs(scope.rows) do if row.controls==0 then return end;widest=math.max(widest,row.label:GetStringWidth()) end\n        for _,entry in ipairs(scope.controls) do local point,x,y=anchorOf(entry.control);if point~='TOPLEFT' or x~=entry.x or y~=entry.y then return end end\n        local column=math.max(60,math.min(220,math.ceil(widest)+12));local delta=220-column;if delta<=0 then return end\n        for _,row in ipairs(scope.rows) do row.label:SetWidth(column-8) end\n        for _,entry in ipairs(scope.controls) do\n            local control=entry.control;control:ClearAllPoints();control:SetPoint('TOPLEFT',entry.x-delta*entry.dx,entry.y)\n            if entry.dw>0 then control:SetWidth(control:GetWidth()+delta*entry.dw) end\n        end\n        scope.column=column;return column\n",
            previous = "",
        },
        {
            at = 7016,
            current = "        local y=self.y;local t=self:Text(text);addon:StyleWorkbenchHeader(t);t:SetHeight(0);t:SetHeight(math.max(20,t:GetStringHeight()));self.y=y+t:GetHeight()+12;return t\n",
            previous = "        local t=self:Text(text);t:SetTextColor(1,.82,.2);self.y=self.y+4;return t\n",
        },
        {
            at = 9318,
            current = "            c.tooltip=entry.text;if icon then c.icon:SetTexture(addon:ControlTexture(icon));c:SetText('');c:SetWidth(20) else c:SetText(entry.text);c:SetWidth(math.min(110,self.width)) end\n            -- A row that no longer fits wraps instead of running past the pane.\n            if x>0 and x+c:GetWidth()>self.width then x=0;y=y+28;self.y=self.y+28 end\n            c:ClearAllPoints();c:SetPoint('TOPLEFT',x,-y);x=x+c:GetWidth()+4\n",
            previous = "            c:ClearAllPoints();c:SetPoint('TOPLEFT',x,-y);c.tooltip=entry.text;if icon then c.icon:SetTexture(addon:ControlTexture(icon));c:SetText('');c:SetWidth(20) else c:SetText(entry.text);c:SetWidth(110) end;x=x+c:GetWidth()+4\n",
        },
        {
            at = 10103,
            current = "        local c=self:Acquire('headings',function() return addon:CreateWorkbenchLabeledIconButton(self.child,'chevron-down','',300) end);c:ClearAllPoints();c:SetPoint('TOPLEFT',0,-y);c:SetWidth(self.width);c:SetText(title);addon:StyleWorkbenchHeader(c:GetFontString());c.icon:SetTexture(addon:ControlTexture(self.closedSections[key] and 'chevron-right' or 'chevron-down'));c:Enable()\n",
            previous = "        local c=self:Acquire('headings',function() return addon:CreateWorkbenchLabeledIconButton(self.child,'chevron-down','',300) end);c:ClearAllPoints();c:SetPoint('TOPLEFT',0,-y);c:SetWidth(self.width);c:SetText(title);c:GetFontString():SetTextColor(1,.82,.2);c.icon:SetTexture(addon:ControlTexture(self.closedSections[key] and 'chevron-right' or 'chevron-down'));c:Enable()\n",
        },
        {
            at = 11454,
            current = "        local height,_,inline=addon:LayoutWorkbenchFieldOption(self.fields[fieldKey],option,self.surface or self.child,220,rowY,self.width-220,minimum)\n        self:LabelControl(self.fields[fieldKey],1,1);self:LabelControl(option,inline and 0 or 1,0)\n",
            previous = "        local height=addon:LayoutWorkbenchFieldOption(self.fields[fieldKey],option,self.surface or self.child,220,rowY,self.width-220,minimum)\n",
        },
        {
            at = 11936,
            current = "        c:ClearAllPoints();c:SetPoint('TOPLEFT',220,-y);c:SetSize(math.max(1,self.width-220),24);self:LabelControl(c,1,1);c:SetMaxLetters(4096);c:EnableMouse(true);c:SetText(tostring(value or ''));c:SetTextColor(1,1,1);c:SetTextInsets(4,4,0,0);if c.referenceIcon then c.referenceIcon:Hide() end;if c.texturePreview then c.texturePreview:Hide() end;c:ClearFocus()\n",
            previous = "        c:ClearAllPoints();c:SetPoint('TOPLEFT',220,-y);c:SetSize(math.max(1,self.width-220),24);c:SetMaxLetters(4096);c:EnableMouse(true);c:SetText(tostring(value or ''));c:SetTextColor(1,1,1);c:SetTextInsets(4,4,0,0);if c.referenceIcon then c.referenceIcon:Hide() end;if c.texturePreview then c.texturePreview:Hide() end;c:ClearFocus()\n",
        },
        {
            at = 14954,
            current = "        c:ClearAllPoints();c:SetPoint('TOPLEFT',220,-y-4);c:SetWidth(self.width-290);self:LabelControl(c,1,1);addon:SetUIScript(c,'OnValueChanged',nil);c:SetMinMaxValues(lo,hi);c:SetValueStep(step);c:SetValue(value or lo);c:EnableMouse(true)\n",
            previous = "        c:ClearAllPoints();c:SetPoint('TOPLEFT',220,-y-4);c:SetWidth(self.width-290);addon:SetUIScript(c,'OnValueChanged',nil);c:SetMinMaxValues(lo,hi);c:SetValueStep(step);c:SetValue(value or lo);c:EnableMouse(true)\n",
        },
        {
            at = 19027,
            current = "        local function choose(id)\n            if not self:Valid(self.generation) or not accepted(id) then return end\n            c:SetText(display(id));c.dropHint:Hide();selected=id;record.dirty=true;if self.transactionKeys and self.fields.apply then self.fields.apply:Enable() end;paint();if self:FlushEdits() then c:ClearFocus() end\n        end\n",
            previous = "",
        },
        {
            at = 19745,
            current = "            self:ShowChoices(c,rows,choose,true)\n        end\n        -- Right-click: what the game offers right now (target or focus cast,\n        -- recent casts, equipped trinkets), chosen like a suggestion.\n        local function insertMenu()\n            local rows={}\n            for _,entry in ipairs(addon:GetReferenceContextEntries(provider.kind)) do\n                local id=provider.resolve(tostring(entry.id),settings)\n                if id and accepted(id) then local info=provider.info(id);rows[#rows+1]={value=id,text=string.format(entry.context,provider.name(id,settings.norank) or tostring(id)),icon=info and info.icon} end\n            end\n            if #rows==0 then self:Message(provider.kind=='item' and L['No equipped trinket to insert.'] or L['Nothing to insert: no target or focus cast and no recent casts.']);return end\n            self:ShowChoices(c,rows,choose,true)\n",
            previous = "            self:ShowChoices(c,rows,function(id)\n                if not self:Valid(self.generation) or not accepted(id) then return end\n                c:SetText(display(id));selected=id;record.dirty=true;if self.transactionKeys and self.fields.apply then self.fields.apply:Enable() end;paint();if self:FlushEdits() then c:ClearFocus() end\n            end,true)\n",
        },
        {
            at = 21173,
            current = "        addon:SetUIScript(c,'OnEnter',self:HelpGuard(function() if selected and GameTooltip then GameTooltip:SetOwner(c,'ANCHOR_RIGHT');GameTooltip:SetHyperlink(provider.kind..':'..selected);GameTooltip:AddLine(provider.kind=='item' and L['Search or drag an item here'] or L['Search or drag a spell here']);GameTooltip:AddLine(provider.kind=='item' and L['Right-click to insert an equipped trinket.'] or L[\"Right-click to insert your target's cast or a recent cast.\"]);GameTooltip:Show() elseif GameTooltip then GameTooltip:SetOwner(c,'ANCHOR_RIGHT');GameTooltip:SetText(c.dropHint:GetText());GameTooltip:AddLine(provider.kind=='item' and L['Right-click to insert an equipped trinket.'] or L[\"Right-click to insert your target's cast or a recent cast.\"]);GameTooltip:Show() end end))\n",
            previous = "        addon:SetUIScript(c,'OnEnter',self:HelpGuard(function() if selected and GameTooltip then GameTooltip:SetOwner(c,'ANCHOR_RIGHT');GameTooltip:SetHyperlink(provider.kind..':'..selected);GameTooltip:AddLine(provider.kind=='item' and L['Search or drag an item here'] or L['Search or drag a spell here']);GameTooltip:Show() elseif GameTooltip then GameTooltip:SetOwner(c,'ANCHOR_RIGHT');GameTooltip:SetText(c.dropHint:GetText()) end end))\n",
        },
        {
            at = 23095,
            current = "        addon:SetUIScript(c,'OnReceiveDrag',self:Guard(drop));addon:SetUIScript(c,'OnMouseDown',self:Guard(function(_,button) if button=='RightButton' then insertMenu() else drop() end end))\n",
            previous = "        addon:SetUIScript(c,'OnReceiveDrag',self:Guard(drop));addon:SetUIScript(c,'OnMouseDown',self:Guard(drop))\n",
        },
        {
            at = 26884,
            current = "        -- The pad lines up with the swatches and values above it.\n        local padX=220;local numberX=padX+78\n        -- The anchored variant lays out its own caption column.\n        local scope=self.labelScope;if anchor and scope then scope.custom=true end;self.labelScope=nil\n",
            previous = "        local padX=anchor and 170 or 220;local numberX=padX+78\n",
        },
        {
            at = 28299,
            current = "            if not anchor then self.labelScope=scope;self:LabelControl(c,1,0);self:LabelControl(t,1,0);self.labelScope=nil end\n",
            previous = "",
        },
        {
            at = 28438,
            current = "        self.labelScope=scope;if not anchor then self:LabelControl(pad,1,0) end\n",
            previous = "",
        },
        {
            at = 28753,
            current = "        c:ClearAllPoints();c:SetPoint('TOPLEFT',220,-y);c:SetWidth(94);self:LabelControl(c,1,0);c:SetText(value and trueLabel or falseLabel);c:Enable();self.fields[key]=c\n",
            previous = "        c:ClearAllPoints();c:SetPoint('TOPLEFT',220,-y);c:SetWidth(94);c:SetText(value and trueLabel or falseLabel);c:Enable();self.fields[key]=c\n",
        },
        {
            at = 29331,
            current = "        c:ClearAllPoints();c:SetPoint('TOPLEFT',220,-y);c:SetWidth(math.max(1,self.width-220));self:LabelControl(c,1,1);c:Enable();self.fields[key]=c\n",
            previous = "        c:ClearAllPoints();c:SetPoint('TOPLEFT',220,-y);c:SetWidth(math.max(1,self.width-220));c:Enable();self.fields[key]=c\n",
        },
        {
            at = 32523,
            current = "        local promptWidth=addon:FitWorkbenchPrompt(prompt.frame,self.frame,430);prompt.text:SetWidth(math.max(1,promptWidth-24))\n",
            previous = "",
        },
        {
            at = 33723,
            current = "        local swatch=self:Acquire('swatches',function() return addon:CreateWorkbenchButton(self.child,'',50) end);swatch:ClearAllPoints();swatch:SetPoint('TOPLEFT',220,-y);swatch:SetSize(50,50);self:LabelControl(swatch,1,0);swatch.art:SetColorTexture(color.r,color.g,color.b,color.a);swatch:Enable();self.fields[key]=swatch\n",
            previous = "        local swatch=self:Acquire('swatches',function() return addon:CreateWorkbenchButton(self.child,'',50) end);swatch:ClearAllPoints();swatch:SetPoint('TOPLEFT',220,-y);swatch:SetSize(50,50);swatch.art:SetColorTexture(color.r,color.g,color.b,color.a);swatch:Enable();self.fields[key]=swatch\n",
        },
        {
            at = 34139,
            current = "        -- The four channels share the row beside the swatch in two columns.\n        local channelWidth=math.max(40,(self.width-278-4)/2)\n",
            previous = "",
        },
        {
            at = 34331,
            current = "            local c=self:Acquire('colorInputs',function() return addon:CreateWorkbenchEditBox(self.child) end);c:ClearAllPoints();c:SetPoint('TOPLEFT',278+((i-1)%2)*(channelWidth+4),-y-math.floor((i-1)/2)*26);c:SetSize(channelWidth,24);self:LabelControl(c,(i-1)%2==0 and 1 or .5,.5);c:SetText(string.format('%.3f',values[channel]));c:SetTextColor(1,1,1);c:EnableMouse(true);c:ClearFocus();c:SetTextInsets(16,3,0,0)\n",
            previous = "            local c=self:Acquire('colorInputs',function() return addon:CreateWorkbenchEditBox(self.child) end);c:ClearAllPoints();c:SetPoint('TOPLEFT',278+((i-1)%2)*84,-y-math.floor((i-1)/2)*26);c:SetSize(80,24);c:SetText(string.format('%.3f',values[channel]));c:SetTextColor(1,1,1);c:EnableMouse(true);c:ClearFocus();c:SetTextInsets(16,3,0,0)\n",
        },
        {
            at = 36985,
            current = "    -- Every cleanup runs even if one fails; a failure part-way used to leave\n    -- the old page's controls on screen and the page unusable.\n    function p:RunCleanups()\n        local cleanups=self.cleanups;self.cleanups={}\n        for _,cleanup in ipairs(cleanups) do\n            local ok,why=pcall(cleanup)\n            if not ok then local handler=geterrorhandler and geterrorhandler();if handler then pcall(handler,why) end end\n        end\n    end\n",
            previous = "",
        },
        {
            at = 37719,
            current = "        self:RunCleanups()\n",
            previous = "        for _,cleanup in ipairs(self.cleanups) do cleanup() end;self.cleanups={}\n",
        },
        {
            at = 37844,
            current = "        self.creationUsed=false;self.creationUsedForNew=false;self.counts={};self.fields={};self.edits={};if self.ResetLayout then self:ResetLayout() end;self.y=4;self.width=math.max(340,self.frame:GetWidth()-40);self.child:SetWidth(self.width)\n        self.labelScopes={};self.labelScope=nil;self:BeginLabelScope()\n        self.builder(self);if self.DraftActions then self:DraftActions() end;while self.labelScope do self:EndLabelScope() end;self:BindHelpBriefs();if not self.creationUsedForNew then self.creationBaseline=nil;self.creationApply=nil end;self.child:SetHeight(self.y+12);self.scroll:UpdateWorkbenchScroll()\n        self.drawnReflowKey=self:ReflowKey();self.drawnColumnSingle=self.usedColumns and self.columnSingle or nil\n",
            previous = "        self.creationUsed=false;self.creationUsedForNew=false;self.counts={};self.fields={};self.edits={};if self.ResetLayout then self:ResetLayout() end;self.y=4;self.width=math.max(340,math.min(760,self.frame:GetWidth()-40));self.child:SetWidth(self.width)\n        self.builder(self);if self.DraftActions then self:DraftActions() end;self:BindHelpBriefs();if not self.creationUsedForNew then self.creationBaseline=nil;self.creationApply=nil end;self.child:SetHeight(self.y+12);self.scroll:UpdateWorkbenchScroll()\n",
        },
        {
            at = 38617,
            current = "",
            previous = "        if self.checkStockObservationOwner then self.checkStockObservationOwner()end\n",
        },
        { at = 39483, current = "        addon:ReserveWorkbenchHelpCorner(self.frame,self.scroll,8)\n", previous = "" },
        {
            at = 39783,
            current = "    -- Geometry alone changed: draw again at the new width, carrying every\n    -- pending input across as typed (invalid text included) without\n    -- committing it, so a resize never loses or silently applies an edit.\n    function p:Relayout()\n        if not self.active then return end\n        for _,record in ipairs(self.edits) do\n            if record.control.HasFocus and record.control:HasFocus() then\n                -- Typing keeps its control, text and caret; draw again once\n                -- the input lets go. A newer drawing supersedes this wait.\n                self.relayoutWaiter=self.relayoutWaiter or CreateFrame('Frame',nil,self.frame)\n                local token=self.generation\n                addon:SetUIScript(self.relayoutWaiter,'OnUpdate',function(waiter)\n                    if not self.active or self.generation~=token then addon:SetUIScript(waiter,'OnUpdate',nil);return end\n                    for _,current in ipairs(self.edits) do if current.control.HasFocus and current.control:HasFocus() then return end end\n                    addon:SetUIScript(waiter,'OnUpdate',nil);self:Relayout()\n                end)\n                return\n            end\n        end\n        local pending={}\n        for _,record in ipairs(self.edits) do if record.dirty then for key,control in pairs(self.fields) do if control==record.control then pending[key]=control:GetText() end end end end\n        self:Draw()\n        for key,text in pairs(pending) do\n            local control=self.fields[key]\n            for _,record in ipairs(self.edits) do if control and record.control==control then\n                control:SetText(text);record.dirty=true\n                local valid=record.parse(text)~=nil;control:SetTextColor(1,valid and 1 or .35,valid and 1 or .35)\n                if self.transactionKeys and self.fields.apply then self.fields.apply:Enable() end\n            end end\n        end\n    end\n    -- The widths a drawing depends on: the page and its detail viewport.\n    function p:ReflowKey() return tostring(self.frame:GetWidth())..'/'..tostring(self.scroll:GetWidth()) end\n    -- Geometry is laid out at once; drawing again waits for the shared\n    -- reflow driver (once per rendered frame at most, never while hidden)\n    -- and is skipped when the widths are those last drawn.\n    function p:RequestRelayout()\n        if not self.active then return end\n        if self:ReflowKey()==self.drawnReflowKey then if addon.CancelWorkbenchReflow then addon:CancelWorkbenchReflow(self) end;return end\n        if not addon.RequestWorkbenchReflow then return self:Relayout() end\n        -- Crossing the one- or two-column breakpoint changes structure: draw\n        -- on the next frame, whatever the previous drawing cost.\n        if self.drawnColumnSingle~=nil and (math.max(340,self.frame:GetWidth()-40)<960)~=self.drawnColumnSingle then self.rmReflowAfter=nil end\n        addon:RequestWorkbenchReflow(self,self.frame,function() if self.active and self:ReflowKey()~=self.drawnReflowKey then self:Relayout() end end)\n    end\n    function p:SetWidth(n) self.frame:SetWidth(n);self:Layout();self:RequestRelayout() end\n",
            previous = "    function p:SetWidth(n) local changed=n~=self.frame:GetWidth();self.frame:SetWidth(n);self:Layout();if changed and self.active and self:FlushEdits() then self:Draw() end end\n",
        },
        {
            at = 43007,
            current = "        if addon.CancelWorkbenchReflow then addon:CancelWorkbenchReflow(self) end\n",
            previous = "        if self.stopStockObservation then self.stopStockObservation()end\n",
        },
        {
            at = 43450,
            current = "        self:RunCleanups()\n",
            previous = "        for _,cleanup in ipairs(self.cleanups) do cleanup() end;self.cleanups={}\n",
        },
    },
}

records["UI/settings_functions.lua"] = {
    bytes = 7579,
    hash = 2352650897,
    oldBytes = 7605,
    oldHash = 4149430786,
    changes = {
        {
            at = 7493,
            current = "    p:Text(L['Add a function or duplicate a packaged helper to edit its source.'])\n",
            previous = "    p:Heading(L['Functions']);p:Text(L['Add a function or duplicate a packaged helper to edit its source.'])\n",
        },
    },
}

records["UI/settings_general.lua"] = {
    bytes = 21221,
    hash = 178921903,
    oldBytes = 17307,
    oldHash = 680690495,
    changes = {
        { at = 473, current = "    local enableY=p.y\n", previous = "" },
        {
            at = 670,
            current = "    p:Check('disable_buttons',L['Disable Bar Highlighting'],profile.disable_buttons,function(v) profile.disable_buttons=v;p:RunSettingsEffect('buttons',function() if v then self:GlowClear() end end) end)\n    p:Check('minimap',L['Minimap Icon'],not (profile.minimap or {}).hide,function(v)\n        profile.minimap=profile.minimap or {};profile.minimap.hide=not v;p:RunSettingsEffect('minimap',function() local lib=LibStub('LibDBIcon-1.0');if v then lib:Show(self.name) else lib:Hide(self.name) end end)\n    end)\n    -- Enable, Disable Bar Highlighting and Minimap Icon share one row in thirds.\n    self:LayoutWorkbenchRow({p.fields.enable,p.fields.disable_buttons,p.fields.minimap},0,enableY,p.width,{text=22});p.y=enableY+30\n",
            previous = "",
        },
        {
            at = 1631,
            current = "    p:Slider('idle_poll',L['Idle Re-check Interval (seconds)'],profile.idle_poll or 1,0,5,.25,function(v) profile.idle_poll=v end)\n    p:Slider('autoswitch_poll',L['Auto-Switch Re-check Interval (seconds)'],profile.autoswitch_poll or 1,0,10,.25,function(v) profile.autoswitch_poll=v;profile.disable_autoswitch=nil;p:RunSettingsEffect('autoswitch_poll',function() self:StartAutoSwitchTimer() end) end)\n",
            previous = "    p:Check('disable_autoswitch',L['Disable Auto-Switching'],profile.disable_autoswitch,function(v) profile.disable_autoswitch=v end)\n    local checkY=p.y-30\n    local bar=p:Check('disable_buttons',L['Disable Bar Highlighting'],profile.disable_buttons,function(v) profile.disable_buttons=v;p:RunSettingsEffect('buttons',function() if v then self:GlowClear() end end) end)\n    local half=(p.width-8)/2;p.fields.disable_autoswitch:SetWidth(half);p.fields.disable_autoswitch:GetFontString():SetWidth(half-22);bar:ClearAllPoints();bar:SetPoint('TOPLEFT',half+8,-checkY);bar:SetWidth(half);bar:GetFontString():SetWidth(half-22);p.y=p.y-30\n",
        },
        {
            at = 2529,
            current = "",
            previous = "    end)\n    p:Check('minimap',L['Minimap Icon'],not (profile.minimap or {}).hide,function(v)\n        profile.minimap=profile.minimap or {};profile.minimap.hide=not v;p:RunSettingsEffect('minimap',function() local lib=LibStub('LibDBIcon-1.0');if v then lib:Show(self.name) else lib:Hide(self.name) end end)\n",
        },
        {
            at = 9181,
            current = "    -- The preview icon has no caption: it sits left of Effect and\n    -- Magnification and spans both rows, their captions beside it.\n    local y=p.y\n",
            previous = "    local y=p:Row(L['Highlight preview'],48)\n",
        },
        {
            at = 9521,
            current = "    preview:ClearAllPoints();preview:SetPoint('TOPLEFT',4,-y-4);preview:SetSize(48,48);preview.icon:SetTexture('Interface\\\\Icons\\\\Spell_Nature_Lightning');p.fields.preview=preview\n    local function besidePreview(build)\n        local count=p.counts.labels or 0;local rowY=p.y;local control=build();local caption=p.pool.labels[count+1]\n        if caption then caption:ClearAllPoints();caption:SetPoint('TOPLEFT',64,-rowY);caption:SetWidth(148) end\n        return control\n    end\n",
            previous = "    preview:ClearAllPoints();preview:SetPoint('TOPLEFT',224,-y);preview:SetSize(36,36);preview.icon:SetTexture('Interface\\\\Icons\\\\Spell_Nature_Lightning')\n",
        },
        {
            at = 10729,
            current = "    besidePreview(function() return p:Choice('effect',L['Effect'],profile.effect,effectEntries,function(v) profile.effect=v;refresh() end) end)\n    besidePreview(function() return p:Slider('magnification',L['Magnification'],profile.magnification or 1,.1,2,.1,function(v) profile.magnification=v;refresh() end) end)\n    p.y=math.max(p.y,y+60)\n",
            previous = "    p:Choice('effect',L['Effect'],profile.effect,effectEntries,function(v) profile.effect=v;refresh() end)\n    p:Slider('magnification',L['Magnification'],profile.magnification or 1,.1,2,.1,function(v) profile.magnification=v;refresh() end)\n",
        },
        {
            at = 11374,
            current = "    anchor:ClearAllPoints();anchor:SetPoint('TOPLEFT',0,-positionY-22);anchor:SetWidth(204);p.y=positionY\n",
            previous = "    anchor:ClearAllPoints();anchor:SetPoint('TOPLEFT',0,-positionY-22);anchor:SetWidth(154);p.y=positionY\n",
        },
        {
            at = 12149,
            current = "    local logY=p.y\n    local logLevel=p:Choice('loglevel',L['Log Level'],profile.loglevel or 2,logEntries,function(v) profile.loglevel=v;p:RunSettingsEffect('loglevel',function() if self.RefreshEvaluationProfilerPolicy then self:RefreshEvaluationProfilerPolicy()end end);p:Draw() end)\n",
            previous = "    p:Choice('loglevel',L['Log Level'],profile.loglevel or 2,logEntries,function(v) profile.loglevel=v;p:RunSettingsEffect('loglevel',function() if self.RefreshEvaluationProfilerPolicy then self:RefreshEvaluationProfilerPolicy()end end);p:Draw() end)\n",
        },
        {
            at = 12632,
            current = "    -- Detailed Profiling follows Log Level on its row, only as wide as its\n    -- box and caption.\n    local detailText=detail:GetFontString();detailText:SetWidth(300)\n    local detailWidth=22+math.min(180,math.max(40,math.ceil(detailText:GetStringWidth() or 0)+2))\n    detailText:SetWidth(detailWidth-22);detail:SetWidth(detailWidth);detail:ClearAllPoints();detail:SetPoint('TOPLEFT',math.max(0,p.width-detailWidth),-logY-3)\n    logLevel:SetWidth(math.max(60,p.width-220-detailWidth-8));p.y=logY+30\n",
            previous = "",
        },
        {
            at = 14305,
            current = "    -- Diagnostics: one column per capture kind, its capture button above its\n    -- report button. While a capture runs its button stops it (the report is\n    -- kept); a report button stays disabled until that kind has a report.\n    -- Labels follow live state, whoever started or ended the capture, but only\n    -- while this page is shown. Each action uses live settings, never a draft.\n    local captures={}\n    local function call(method,...) local fn=self[method];if type(fn)~='function' then return false end;local ok,value=pcall(fn,self,...);return ok and value end\n    local function stopper(kind,method) return function()\n        if type(self.HandlePerformanceCommand)=='function' then return self:HandlePerformanceCommand(kind..' stop') end\n        local ok=call(method);return ok,''\n    end end\n    local function stored(method) return function() local fn=self[method];if type(fn)~='function' then return false end;local ok,value=pcall(fn,self);return ok and type(value)=='string' end end\n",
            previous = "",
        },
        {
            at = 15344,
            current = "        captures[#captures+1]={key='cpu_capture',reportKey='cpu_report',start=L['Capture CPU (10s)'],stop=L['Stop CPU capture'],report=L['CPU report'],\n            running=function() return call('IsCPUProfileRunning')==true end,hasReport=stored('GetCPUProfileReport'),\n            begin=function() return self:RunCPUProfileAction('start') end,finish=stopper('cpu','StopCPUProfile'),open=function() return self:RunCPUProfileAction('report') end}\n",
            previous = "        local controls={\n            {key='cpu_capture',text=L['Capture CPU (10s)'],action='start'},\n            {key='cpu_report',text=L['CPU report'],action='report'},\n            {key='cpu_cancel',text=L['Cancel capture'],action='cancel'},\n            {key='cpu_probe',text=L['Native profiler probe'],action='probe'},\n        }\n",
        },
        {
            at = 15851,
            current = "            captures[#captures+1]={key='cpu_runtime_capture',reportKey='cpu_runtime_report',start=L['Capture runtime (10s)'],stop=L['Stop runtime capture'],report=L['Runtime report'],\n                running=function() return call('IsCPURuntimeCaptureRunning')==true end,hasReport=stored('GetCPURuntimeCaptureReport'),\n                begin=function() return self:RunCPUProfileAction('runtime') end,finish=stopper('runtime','StopCPURuntimeCapture'),open=function() return self:RunCPUProfileAction('runtimereport') end}\n",
            previous = "            controls[#controls+1]={key='cpu_runtime_capture',text=L['Capture runtime (10s)'],action='runtime'}\n            controls[#controls+1]={key='cpu_runtime_report',text=L['Runtime report'],action='runtimereport'}\n",
        },
        {
            at = 16440,
            current = "            captures[#captures+1]={key='memory_capture',reportKey='memory_report',start=L['Capture memory (10m)'],stop=L['Stop memory capture'],report=L['Memory report'],\n                running=function() return call('IsMemoryCaptureRunning')==true end,hasReport=stored('GetMemoryCaptureReport'),\n                begin=function() return self:RunCPUProfileAction('memory') end,finish=stopper('memory','CompleteMemoryCapture'),open=function() return self:RunCPUProfileAction('memoryreport') end}\n",
            previous = "            controls[#controls+1]={key='memory_capture',text=L['Capture memory (10m)'],action='memory'}\n            controls[#controls+1]={key='memory_report',text=L['Memory report'],action='memoryreport'}\n            controls[#controls+1]={key='memory_stop',text=L['Stop memory capture'],action='memorystop'}\n",
        },
        {
            at = 16947,
            current = "    end\n    if self.RunCastCaptureAction then\n        -- The cast report copies its snapshot, so it is checked only when the\n        -- running state changes (and now and then as a safety net).\n        captures[#captures+1]={key='cast_capture',reportKey='cast_report',start=L['Capture casts (30s)'],stop=L['Stop cast capture'],report=L['Cast report'],costly=true,\n            running=function() return type(self.GetCastCaptureState)=='function' and self:GetCastCaptureState()==true end,\n            hasReport=function() if type(self.GetCastCaptureState)~='function' then return true end;local _,available=self:GetCastCaptureState(true);return available==true end,\n            begin=function() return self:RunCastCaptureAction('start') end,finish=function() return self:RunCastCaptureAction('stop') end,open=function() return self:RunCastCaptureAction('report') end}\n    end\n    if #captures>0 then\n        local token=p.generation;local minimumWidth=120;local diagnosticY=p.y\n        local function paint(entry,force)\n            local running=entry.running()\n            local has=entry.has\n            if not running and (force or not entry.costly or running~=entry.wasRunning or (entry.age or 0)>=2) then has=entry.hasReport()==true;entry.age=0 end\n            if running then has=false end\n            entry.wasRunning=running;entry.has=has\n            entry.button:SetText(running and entry.stop or entry.start)\n            if has then entry.reportButton:Enable() else entry.reportButton:Disable() end\n        end\n        local function repaint(force) if p:Valid(token) then for _,entry in ipairs(captures) do paint(entry,force) end end end\n        for _,entry in ipairs(captures) do\n            local button=p:Button(entry.key,entry.start,function() end);local reportButton=p:Button(entry.reportKey,entry.report,function() end)\n            entry.button,entry.reportButton=button,reportButton\n            for _,text in ipairs({entry.start,entry.stop}) do button:SetText(text);minimumWidth=math.max(minimumWidth,button:GetFontString():GetStringWidth()+20) end\n            self:SetUIScript(button,'OnClick',p:Guard(function()\n                local action=entry.running() and entry.finish or entry.begin\n                local ok,message,current=action()\n                if current==false or not p:Valid(token) then return end\n                if message and message~='' then p:Message(message,ok) end;repaint(true)\n            end))\n            self:SetUIScript(reportButton,'OnClick',p:Guard(function()\n                local ok,message,current=entry.open()\n                if current==false or not p:Valid(token) then return end\n                p:Message(message or '',ok);repaint(true)\n",
            previous = "        local diagnosticY=p.y;local buttons={};local minimumWidth=120\n        local diagnosticToken=p.generation\n        for i,entry in ipairs(controls) do\n            local control=p:Button(entry.key,entry.text,function() end)\n            buttons[i]=control\n            minimumWidth=math.max(minimumWidth,control:GetFontString():GetStringWidth()+20)\n            -- Diagnostics use live runtime settings, without applying/flushing a draft.\n            self:SetUIScript(control,'OnClick',p:Guard(function()\n                local ok,message=self:RunCPUProfileAction(entry.action)\n                if not p:Valid(diagnosticToken) then return end\n                p:Message(message,ok)\n",
        },
        {
            at = 19666,
            current = "        local gap=4\n        local columns=math.max(1,math.min(#captures,math.floor((p.width+gap)/(minimumWidth+gap))))\n        local each=(p.width-(columns-1)*gap)/columns\n        for i,entry in ipairs(captures) do\n            local x=((i-1)%columns)*(each+gap);local top=diagnosticY+math.floor((i-1)/columns)*58\n            entry.button:ClearAllPoints();entry.button:SetPoint('TOPLEFT',x,-top);entry.button:SetWidth(each)\n            entry.reportButton:ClearAllPoints();entry.reportButton:SetPoint('TOPLEFT',x,-top-28);entry.reportButton:SetWidth(each)\n",
            previous = "        local columns=p.width>=minimumWidth*4+12 and 4 or p.width>=minimumWidth*2+4 and 2 or 1\n        local controlWidth=(p.width-(columns-1)*4)/columns\n        for i,control in ipairs(buttons) do\n            control:ClearAllPoints();control:SetPoint('TOPLEFT',((i-1)%columns)*(controlWidth+4),-diagnosticY-math.floor((i-1)/columns)*28);control:SetWidth(controlWidth)\n",
        },
        {
            at = 20232,
            current = "        p.y=diagnosticY+math.ceil(#captures/columns)*58\n        repaint(true)\n        local watcher=p:Acquire('captureWatcher',function() return CreateFrame('Frame',nil,p.child) end);local elapsed=0\n        self:SetUIScript(watcher,'OnUpdate',function(frame,delta)\n            if not p:Valid(token) then self:SetUIScript(frame,'OnUpdate',nil);return end\n            elapsed=elapsed+(delta or 0);if elapsed<.25 then return end\n            for _,entry in ipairs(captures) do entry.age=(entry.age or 0)+elapsed end;elapsed=0;repaint(false)\n        end)\n",
            previous = "        p.y=diagnosticY+math.ceil(#buttons/columns)*28\n    end\n    if self.RunCastCaptureAction then\n        local controls={\n            {key='cast_capture',text=L['Capture casts (30s)'],action='start'},\n            {key='cast_stop',text=L['Stop'],action='stop'},\n            {key='cast_report',text=L['Cast report'],action='report'},\n            {key='cast_clear',text=L['Clear'],action='clear'},\n        }\n        local diagnosticY=p.y;local buttons={};local minimumWidth=120\n        local statusText;local diagnosticToken=p.generation\n        for i,entry in ipairs(controls) do\n            local control=p:Button(entry.key,entry.text,function() end)\n            buttons[i]=control\n            minimumWidth=math.max(minimumWidth,control:GetFontString():GetStringWidth()+20)\n            self:SetUIScript(control,'OnClick',p:Guard(function()\n                local ok,message,current=self:RunCastCaptureAction(entry.action)\n                if current==false or not p:Valid(diagnosticToken) then return end\n                p:Message(message,ok)\n                if statusText then statusText:SetText(self:GetCastCaptureStatusText()) end\n            end))\n        end\n        local columns=p.width>=minimumWidth*4+12 and 4 or p.width>=minimumWidth*2+4 and 2 or 1\n        local controlWidth=(p.width-(columns-1)*4)/columns\n        for i,control in ipairs(buttons) do\n            control:ClearAllPoints();control:SetPoint('TOPLEFT',((i-1)%columns)*(controlWidth+4),-diagnosticY-math.floor((i-1)/columns)*28);control:SetWidth(controlWidth)\n        end\n        p.y=diagnosticY+math.ceil(#buttons/columns)*28\n        if self.GetCastCaptureStatusText then statusText=p:Text(self:GetCastCaptureStatusText()) end\n",
        },
    },
}

records["UI/settings_history.lua"] = {
    bytes = 3524,
    hash = 209929092,
    oldBytes = 3823,
    oldHash = 625625862,
    changes = {
        {
            at = 868,
            current = "        return addon:CopySettingsData({profile=self.draft.profile.itemsets,global=self.draft.global.itemsets,effects=self.draftEffects,selection=self.selection})\n",
            previous = "        local stock=self.stockEditable and self.draft.profile.stockTargets or nil;if not addon.StockTargets.Validate(stock) then stock=nil end\n        return addon:CopySettingsData({profile=self.draft.profile.itemsets,global=self.draft.global.itemsets,effects=self.draftEffects,selection=self.selection,stock=stock,stockSelection=self.stockSelection})\n",
        },
        {
            at = 2503,
            current = "        to[#to+1]=self:HistorySnapshot();local value=table.remove(from);self.draft.profile.itemsets=addon:CopySettingsData(value.profile);self.draft.global.itemsets=addon:CopySettingsData(value.global);self.draftEffects=addon:CopySettingsData(value.effects);self.selection=value.selection;self.historyEpoch=(self.historyEpoch or 0)+1;self:Draw()\n",
            previous = "        to[#to+1]=self:HistorySnapshot();local value=table.remove(from);self.draft.profile.itemsets=addon:CopySettingsData(value.profile);self.draft.global.itemsets=addon:CopySettingsData(value.global);self.draftEffects=addon:CopySettingsData(value.effects);self.selection=value.selection;self.stockSelection=value.stockSelection;self.draft.profile.stockTargets=addon:CopySettingsData(value.stock);self.historyEpoch=(self.historyEpoch or 0)+1;self:Draw()\n",
        },
    },
}

records["UI/settings_items.lua"] = {
    bytes = 12353,
    hash = 2383659033,
    oldBytes = 11410,
    oldHash = 3241360293,
    changes = {
        {
            at = 499,
            current = "",
            previous = "    self:ItemSettingsSourceOptions(p,{})\n    if p.itemSettingsSource=='stock' then return self:BuildStockSettings(p) end\n",
        },
        {
            at = 1188,
            current = "    -- Binding: drag a set (its roster row or the Bind pill) onto any action\n    -- bar slot, which swaps with what is there, or click Bind and then click\n    -- an empty slot. Both start the same pending bind.\n    local function beginBind(setId)\n        if not p:FlushEdits() then return false end\n        if InCombatLockdown and InCombatLockdown() then p:Message(L['Leave combat before changing action bar bindings.']);return false end\n        if p.transactionKeys and p:IsSettingsDraftDirty() then p:Message(L['Apply item-set changes before binding it to an action bar.']);return false end\n        local first;if self.FindFirstItemOfItemSet then first=self:FindFirstItemOfItemSet({},setId,true) elseif self.FindFirstItemInItems then first=self:FindFirstItemInItems((merged[setId] or {}).items or {}) end\n        local ok,why\n        if self.BeginItemSetBind then ok,why=self:BeginItemSetBind(setId,first)\n        elseif first and type(PickupItem)=='function' then self.bindingItemSet=setId;PickupItem(first);ok=true else why='unavailable' end\n        if not ok then p:Message(why=='combat' and L['Leave combat before changing action bar bindings.'] or L['An item from this set must be available before binding.']) end\n        return ok\n    end\n    p:UseRoster(entries,p.selection,function(id) p.selection=id;p.creating=false;p:Draw() end,{dragOut=function(setId) beginBind(setId) end,newText=L['Add item set'],new=function() p.previousSelection=p.selection;p.selection=nil;p.creating=true;p.emptyDismissed=false;p:Draw() end});if p.historyEnabled then p:HistoryActions() end\n",
            previous = "    p:UseRoster(entries,p.selection,function(id) p.selection=id;p.creating=false;p:Draw() end,self:ItemSettingsSourceOptions(p,{newText=L['Add item set'],new=function() p.previousSelection=p.selection;p.selection=nil;p.creating=true;p.emptyDismissed=false;p:Draw() end}));p:Heading(L['Item Sets']);if p.historyEnabled then p:HistoryActions() end\n",
        },
        {
            at = 3929,
            current = "        -- The priority list has no title: the new-item field and Add share\n        -- the row directly above the item cards. A click appends; dragging Add\n        -- drops the chosen item into a gap through the same insert.\n        p.newItem=p.newItem or ''\n        local function insertItem(gap)\n            local value=itemValue(tostring(p.newItem));if not value then p:Message(L['Choose an item first.']);return end\n            set.items=set.items or {};table.insert(set.items,math.max(1,math.min(gap,#set.items+1)),value);p.newItem='';update();p:Draw()\n        end\n        p:OrderedCollection('items_'..id,items,function(i) return self:GetReferenceProvider('item').name(tonumber(items[i]) or self:GetReferenceProvider('item').resolve(items[i])) or L['Item data loading'] end,function(form,i,item,row)\n            local field=form:Item('item'..i,nil,item,function(value) items[i]=value;update() end);field:ClearAllPoints();field:SetPoint('TOPLEFT',18,-2);field:SetSize(form.width-20,24);form.y=22\n        end,update,{prefix='item',compact=true,add={key='add_item',text=L['Add item'],insert=insertItem,\n            leading=function(form,y,width) return self:LayoutNewItemField(form,form:Item('new_item',nil,p.newItem,function(value) p.newItem=value end,true),y,width) end}})\n",
            previous = "        p:Section('items_'..id,L['Items in priority order'],function()\n            p:OrderedCollection('items_'..id,items,function(i) return self:GetReferenceProvider('item').name(tonumber(items[i]) or self:GetReferenceProvider('item').resolve(items[i])) or L['Item data loading'] end,function(form,i,item,row)\n                local field=form:Item('item'..i,nil,item,function(value) items[i]=value;update() end);field:ClearAllPoints();field:SetPoint('TOPLEFT',18,-2);field:SetSize(form.width-20,24);form.y=22\n            end,update,{prefix='item',compact=true})\n            p.newItem=p.newItem or '';local y=p.y;local newItem=p:Item('new_item',L['Item'],p.newItem,function(value) p.newItem=value end,true);newItem:SetWidth(math.max(60,p.width-334))\n            local add=p:Button('add_item',L['Add item'],function() local value=itemValue(tostring(p.newItem));if not value then p:Message(L['Choose an item first.']);return end;set.items=set.items or {};set.items[#set.items+1]=value;p.newItem='';update();p:Draw() end,'plus');add:ClearAllPoints();add:SetPoint('TOPRIGHT',0,-y);add:SetWidth(104);p.y=p.y-28\n        end)\n",
        },
        {
            at = 6512,
            current = "            beginBind(id)\n",
            previous = "            if p.transactionKeys and p:IsSettingsDraftDirty() then p:Message(L['Apply item-set changes before binding it to an action bar.']);return end\n            local first;if self.FindFirstItemOfItemSet then first=self:FindFirstItemOfItemSet({},id,true) elseif self.FindFirstItemInItems then first=self:FindFirstItemInItems(items) end\n            if not first or type(PickupItem)~='function' then p:Message(L['An item from this set must be available before binding.']);return end\n            self.bindingItemSet=id;PickupItem(first)\n",
        },
        {
            at = 6552,
            current = "        binding.tooltip=L['Drag onto any action bar slot (it swaps with what is there), or click Bind and then click an empty slot.']\n        self:BindWorkbenchDragSource(binding,p:Guard(function() beginBind(id) end),function() end)\n",
            previous = "",
        },
        {
            at = 6986,
            current = "        p.cleanups[#p.cleanups+1]=function() if self.itemSetCallback==callback then self.itemSetCallback=nil end;if self.bindingItemSet==id then self.bindingItemSet=nil;if self.ClearItemSetBindCursor then self:ClearItemSetBindCursor(id) end end;if self.EndHighlightSlot then self:EndHighlightSlot() end end\n",
            previous = "        p.cleanups[#p.cleanups+1]=function() if self.itemSetCallback==callback then self.itemSetCallback=nil end;if self.bindingItemSet==id then self.bindingItemSet=nil;if type(GetCursorInfo)=='function' and GetCursorInfo()=='item' and type(ClearCursor)=='function' then ClearCursor() end end;if self.EndHighlightSlot then self:EndHighlightSlot() end end\n",
        },
    },
}

records["UI/settings_layout.lua"] = {
    bytes = 16587,
    hash = 1856577001,
    oldBytes = 15213,
    oldHash = 1223137639,
    changes = {
        {
            at = 184,
            current = "        self.surface=nil;self.rosterUsed=false;self.columnMode=false;self.columnSingle=false;self.usedColumns=false\n        -- A divider drag redraws the page; keep its splitter alive meanwhile.\n        if self.roster then self.roster.frame:Hide();if self.roster.splitter and not self.roster.splitter.drag then self.roster.splitter:Hide() end end\n",
            previous = "        self.surface=nil;self.rosterUsed=false;self.columnMode=false;self.columnSingle=false\n        if self.roster then self.roster.frame:Hide() end\n",
        },
        {
            at = 775,
            current = "            self.fullWidth=math.max(340,self.frame:GetWidth()-40);self.columnSingle=self.fullWidth<960;self.columnMode=true;self.usedColumns=true\n",
            previous = "            self.fullWidth=math.max(340,self.frame:GetWidth()-40);self.columnSingle=self.fullWidth<960;self.columnMode=true\n",
        },
        {
            at = 969,
            current = "            if self.columnSingle then self.width=self.fullWidth;return end\n",
            previous = "            if self.columnSingle then self.width=math.min(760,self.fullWidth);return end\n",
        },
        {
            at = 1127,
            current = "            for i=1,2 do local f=self.columns[i] or addon:TrackWorkbenchSize(CreateFrame('Frame',nil,self.child));self.columns[i]=f;f:ClearAllPoints();f:SetPoint('TOPLEFT',(i-1)*(self.columnWidth+24),0);f:SetSize(self.columnWidth,1);f:Show() end\n",
            previous = "            for i=1,2 do local f=self.columns[i] or CreateFrame('Frame',nil,self.child);self.columns[i]=f;f:ClearAllPoints();f:SetPoint('TOPLEFT',(i-1)*(self.columnWidth+24),0);f:SetSize(self.columnWidth,1);f:Show() end\n",
        },
        {
            at = 1430,
            current = "        -- Each column sizes its own caption column.\n        if self.EndLabelScope and self.labelScope then self:EndLabelScope();self:BeginLabelScope() end\n",
            previous = "",
        },
        {
            at = 1894,
            current = "        if self.EndLabelScope and self.labelScope then self:EndLabelScope();self:BeginLabelScope() end\n",
            previous = "",
        },
        {
            at = 3469,
            current = "        r.rebuilding=nil;r.search:ClearFocus();r.frame:Hide();if r.splitter and not r.splitter.drag then r.splitter:Hide() end\n",
            previous = "        r.rebuilding=nil;r.search:ClearFocus();r.frame:Hide()\n",
        },
        {
            at = 10146,
            current = "            r={frame=addon:TrackWorkbenchSize(CreateFrame('Frame',nil,self.frame)),rows={}};self.roster=r;r.frame:SetPoint('TOPLEFT',0,0)\n",
            previous = "            r={frame=CreateFrame('Frame',nil,self.frame),rows={}};self.roster=r;r.frame:SetPoint('TOPLEFT',0,0)\n",
        },
        {
            at = 10786,
            current = "            -- Rows follow the list column; the scroll bar reserves space only when shown.\n            function r.scroll.OnWorkbenchColumnResized() self:RefreshRosterViewport() end\n            r.splitter=addon:CreateWorkbenchSplitter(self.frame,function() self:ResizeSplit() end)\n",
            previous = "",
        },
        {
            at = 14732,
            current = "            local shown={};for i=1,#r.options.sources do shown[i]=r.sourceButtons[i] end\n            addon:LayoutWorkbenchRow(shown,0,filterTop,side)\n",
            previous = "            local width=(side-8)/#r.options.sources\n            for i,control in ipairs(r.sourceButtons) do control:ClearAllPoints();control:SetPoint('TOPLEFT',(i-1)*(width+4),-filterTop);control:SetWidth(width) end\n",
        },
        {
            at = 15509,
            current = "        local top=filterTop+(r.options.categories and 32 or 4);r.scroll:ClearAllPoints();r.scroll:SetPoint('TOPLEFT',0,-top);r.scroll:SetHeight(math.max(1,sidebarHeight-top-footerHeight))\n        r.scroll:SetWorkbenchColumnWidth(side);r.child:SetWidth(r.scroll:GetWidth());r.empty:SetWidth(math.max(1,r.child:GetWidth()-12));r.splitter:Place(geometry)\n        self.scroll:ClearAllPoints();self.scroll:SetPoint('TOPLEFT',geometry.detailX,0);self.scroll:SetSize(geometry.detailWidth-math.max(18,addon:GetWorkbenchHelpReserve(self.frame)),height);addon:ReserveWorkbenchHelpCorner(self.frame,self.scroll,0);self.message:SetWidth(math.max(1,self.frame:GetWidth()-(self.creationUsed and 340 or 20)))\n",
            previous = "        local top=filterTop+(r.options.categories and 32 or 4);r.scroll:ClearAllPoints();r.scroll:SetPoint('TOPLEFT',0,-top);r.scroll:SetSize(side-24,math.max(1,sidebarHeight-top-footerHeight));r.child:SetWidth(side-24)\n        self.scroll:ClearAllPoints();self.scroll:SetPoint('TOPLEFT',geometry.detailX,0);self.scroll:SetSize(geometry.detailWidth-18,height);self.message:SetWidth(math.max(1,self.frame:GetWidth()-(self.creationUsed and 340 or 20)))\n",
        },
        {
            at = 16248,
            current = "    -- A divider drag changes the detail width without resizing the page, so\n    -- the page is drawn again exactly as after a window resize, pending\n    -- (even invalid) input included.\n    function p:ResizeSplit()\n        if not self.rosterUsed or not self.roster then return end\n        self:Layout();self:RequestRelayout()\n    end\n",
            previous = "",
        },
    },
}

records["UI/settings_ordered.lua"] = {
    bytes = 18182,
    hash = 4254286256,
    oldBytes = 11245,
    oldHash = 4073992159,
    changes = {
        {
            at = 83,
            current = "-- A new-item field placed at the left of a list's header row (its Add sits\n-- at the right). Returns the width it used.\nfunction addon:LayoutNewItemField(form,field,y,width)\n    form.y=y;field:ClearAllPoints();field:SetPoint('TOPLEFT',0,-y);field:SetSize(math.max(60,width),22);return 0\nend\n",
            previous = "",
        },
        {
            at = 1226,
            current = "            self.drag=nil;self.tail=nil;self.insertFactory=nil;self.insertAction=nil\n",
            previous = "            self.drag=nil;self.tail=nil;self.insertFactory=nil\n",
        },
        {
            at = 1808,
            current = "            if self.insertFactory or self.insertAction then return type(gap)=='number' and gap%1==0 and gap>=1 and gap<=#items+1 end\n",
            previous = "            if self.insertFactory then return type(gap)=='number' and gap%1==0 and gap>=1 and gap<=#items+1 end\n",
        },
        {
            at = 2066,
            current = "            local from,tail,factory,action=self.drag,self.tail,self.insertFactory,self.insertAction;local allowed=self:CanDrop(gap);self:CancelDrag()\n",
            previous = "            local from,tail,factory=self.drag,self.tail,self.insertFactory;local allowed=self:CanDrop(gap);self:CancelDrag()\n",
        },
        {
            at = 2302,
            current = "            -- A dropped add action inserts through the page's own add path, so\n            -- a drop at the end leaves exactly what a click on Add leaves.\n            if action then\n                local function insert() action(gap) end\n                if p.WithSettingsHistory then p:WithSettingsHistory(insert) else insert() end;return true\n            end\n",
            previous = "",
        },
        {
            at = 5329,
            current = "            -- Gaps right before and after the carried card would not move it.\n            for gap,zone in ipairs(self.zones) do if self:CanDrop(gap) then zone:Show() else zone:Hide() end end\n",
            previous = "            for _,zone in ipairs(self.zones) do zone:Show() end\n",
        },
        {
            at = 5819,
            current = "        function view:BeginInsert(factory,label,action)\n            self:CancelDrag();if not valid() or options.readOnly or type(factory)~='function' and type(action)~='function' or not p:FlushEdits() or not valid() then return false end\n            if type(action)=='function' then self.insertAction=action else self.insertFactory=factory end;self.ghost.rmCollectionDragOwner=self\n",
            previous = "        function view:BeginInsert(factory,label)\n            self:CancelDrag();if not valid() or options.readOnly or type(factory)~='function' or not p:FlushEdits() or not valid() then return false end\n            self.insertFactory=factory;self.ghost.rmCollectionDragOwner=self\n",
        },
        {
            at = 6915,
            current = "        -- The list's header row: an optional section title at the left and the\n        -- add action right-aligned to the cards' right edge, on one row. With\n        -- neither there is no row. options.heading is a string or {text,key,\n        -- collapsed,toggle}; options.add is {key,text,icon,insert(gap),click,\n        -- beginDrag,appendGap,leading(form,y,width),enabled}. A click appends\n        -- through insert(appendGap); dragging Add drops into a gap through the\n        -- same insert, so both leave identical data.\n        local heading=type(options.heading)=='string' and {text=options.heading} or options.heading\n        local add=options.add\n        if heading or add then\n            local y=self.y;local addWidth=0\n            if add then\n                local button=self:Acquire('orderedAdd',function() return addon:CreateWorkbenchLabeledIconButton(parent,'plus','',110) end)\n                button:SetText(add.text or L['Add']);button.icon:SetTexture(addon:ControlTexture(add.icon or 'plus'))\n                addWidth=math.min(math.max(110,button:GetFontString():GetStringWidth()+40),math.max(60,math.floor(width*.5)))\n                button:ClearAllPoints();button:SetPoint('TOPLEFT',width-addWidth,-y);button:SetSize(addWidth,22);addon:AlignWorkbenchTextLeft(button,24)\n                if add.key then self.fields[add.key]=button end;view.add=button\n                local blocked=options.readOnly or add.enabled==false\n                if blocked then button:Disable() else button:Enable() end\n                addon:SetUIScript(button,'OnClick',self:Guard(function()\n                    if blocked then return end\n                    if add.click then return add.click() end\n                    if self:FlushEdits() and valid() then add.insert(add.appendGap and add.appendGap() or #items+1) end\n                end))\n                addon:BindWorkbenchDragSource(button,function()\n                    if blocked or not valid() then return end\n                    if add.beginDrag then return add.beginDrag(view) end\n                    view:BeginInsert(add.factory,add.label or add.text,add.insert)\n                end,function() if valid() then view:EndDrag() end end)\n            end\n            local left=0\n            if add and add.leading then left=add.leading(self,y,math.max(1,width-addWidth-8)) or 0 end\n            if heading then\n                local titleWidth=math.max(1,width-addWidth-(addWidth>0 and 8 or 0)-left)\n                if heading.toggle then\n                    local c=self:Acquire('orderedToggles',function() return addon:CreateWorkbenchLabeledIconButton(parent,'chevron-down','',200) end)\n                    c:ClearAllPoints();c:SetPoint('TOPLEFT',left,-y);c:SetSize(titleWidth,22);c:SetText(heading.text);c.art:Hide();addon:AlignWorkbenchTextLeft(c,20)\n                    addon:StyleWorkbenchHeader(c:GetFontString());c.icon:SetTexture(addon:ControlTexture(heading.collapsed and 'chevron-right' or 'chevron-down'));c:Enable()\n                    addon:SetUIScript(c,'OnClick',self:Guard(function() if valid() then heading.toggle() end end));if heading.key then self.fields[heading.key]=c end;view.heading=c\n                else\n                    local t=self:Acquire('orderedHeadings',function() local text=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');text:SetJustifyH('LEFT');text:SetJustifyV('MIDDLE');text:SetWordWrap(false);return text end)\n                    t:ClearAllPoints();t:SetPoint('TOPLEFT',left,-y);t:SetSize(titleWidth,22);t:SetText(heading.text);addon:StyleWorkbenchHeader(t)\n                    if heading.key then self.fields[heading.key]=t end;view.heading=t\n                end\n            end\n            self.y=y+28\n            if heading and heading.collapsed then view.collapsed=true;self.cleanups[#self.cleanups+1]=function() view:CancelDrag() end;return view end\n        end\n",
            previous = "",
        },
        {
            at = 11047,
            current = "                local frame=CreateFrame('Frame',nil,parent);frame.header=addon:CreateWorkbenchButton(frame,'',width-56);frame.header.art:Hide();frame.body=addon:TrackWorkbenchSize(CreateFrame('Frame',nil,frame));frame.body:SetPoint('TOPLEFT',26,0)\n",
            previous = "                local frame=CreateFrame('Frame',nil,parent);frame.header=addon:CreateWorkbenchButton(frame,'',width-56);frame.header.art:Hide();frame.body=CreateFrame('Frame',nil,frame);frame.body:SetPoint('TOPLEFT',26,0)\n",
        },
        {
            at = 11795,
            current = "            -- One card for every list: no title row and no grip. The whole card\n            -- picks up for a drag; arrows on the left; on the right a rail of\n            -- optional Help and Duplicate above Delete, and an optional\n            -- Enabled pill on the first row left of the rail.\n            row:ClearAllPoints();row:SetPoint('TOPLEFT',0,-y);row:SetWidth(width);row.header:Hide()\n            if row.header.grip then row.header.grip:Hide() end\n",
            previous = "            row:ClearAllPoints();row:SetPoint('TOPLEFT',0,-y);row:SetWidth(width)\n            row.header:ClearAllPoints();row.header:SetPoint('TOPLEFT',26,-3);row.header:SetWidth(width-54);row.header:SetText((options.compact or options.header==false) and '' or title(i));addon:AlignWorkbenchTextLeft(row.header,3)\n            row.header.grip=row.header.grip or row.header:CreateTexture(nil,'ARTWORK');row.header.grip:SetTexture(addon:ControlTexture('grip'));row.header.grip:SetSize(12,18);row.header.grip:SetPoint('LEFT',2,0)\n            if options.header==false then row.header:SetPoint('TOPRIGHT',-4,-25);row.header:SetWidth(20);row.header:SetHeight(20);row.header.grip:Hide() elseif options.compact then row.header:SetPoint('TOPLEFT',20,-2);row.header:SetWidth(18);row.header:SetHeight(26);row.header.grip:Show() else row.header:SetHeight(20);row.header.grip:Hide() end\n            row.header.tooltip=L['Drag one entry; Ctrl-drag moves it and all following siblings.'];row.body:SetWidth(width-62)\n",
        },
        {
            at = 12344,
            current = "            row.up:SetPoint('TOPLEFT',3,options.compact and -1 or -4);row.down:SetPoint('TOPLEFT',3,options.compact and -14 or -22)\n            row.up:SetSize(18,options.compact and 13 or 18);row.down:SetSize(18,options.compact and 13 or 18)\n",
            previous = "            row.up:SetPoint('TOPLEFT',3,options.compact and -1 or options.header==false and -4 or -26);row.down:SetPoint('TOPLEFT',3,options.compact and -14 or options.header==false and -22 or -44)\n            row.up:SetSize(18,options.compact and 13 or 18);row.down:SetSize(18,options.compact and 13 or 18);row.remove:SetPoint('TOPRIGHT',-4,-3)\n",
        },
        {
            at = 12983,
            current = "            local rail=0\n            local function railSlot(control) control:ClearAllPoints();control:SetPoint('TOPRIGHT',-4,-3-rail*22);control:SetSize(20,20);rail=rail+1;control:Show() end\n            if options.help and not options.compact then\n                row.help=row.help or addon:CreateWorkbenchHelpButton(row,L['Help']);row.help.icon:SetSize(18,18);row.help:Enable();railSlot(row.help)\n                if type(options.help)=='function' then addon:SetUIScript(row.help,'OnClick',self:Guard(function() if valid() then options.help(i,items[i],row) end end)) end\n            elseif row.help then row.help:Hide() end\n            if options.duplicate and not options.compact then\n                row.duplicate=row.duplicate or addon:CreateWorkbenchIconButton(row,'copy',L['Duplicate']);railSlot(row.duplicate)\n                local allowed=not options.readOnly and (not options.canDuplicate or options.canDuplicate(i,items[i]))\n                if allowed then row.duplicate:Enable() else row.duplicate:Disable() end\n                if type(options.duplicate)=='function' then addon:SetUIScript(row.duplicate,'OnClick',self:Guard(function() if allowed and valid() then options.duplicate(i,items[i],row) end end)) end\n            elseif row.duplicate then row.duplicate:Hide() end\n            railSlot(row.remove)\n",
            previous = "",
        },
        {
            at = 14389,
            current = "            addon:SetUIScript(row.remove,'OnClick',self:Guard(function() if not options.readOnly and self:FlushEdits() and valid() then if options.removeItem then options.removeItem(i,items[i]) else table.remove(items,i);changed();self:Draw() end end end))\n            row.firstRowReserve=0\n            if options.enabled and not options.compact then\n                -- options.enabled is {get,toggle,width,tooltip}, or true when the\n                -- page sets the pill's state and action while building the card.\n                local spec=type(options.enabled)=='table' and options.enabled or {}\n                local pillWidth=spec.width or 70\n                row.enabled=row.enabled or addon:CreateWorkbenchPill(row,'',pillWidth)\n                row.enabled:ClearAllPoints();row.enabled:SetPoint('TOPRIGHT',-28,-4);row.enabled:SetSize(pillWidth,18);row.enabled:Show()\n                if spec.get then\n                    local on=spec.get(i,items[i])==true\n                    row.enabled:SetText(on and L['Enabled'] or L['Disabled']);row.enabled:SetSelected(on);row.enabled.tooltip=spec.tooltip\n                    if options.readOnly then row.enabled:Disable() else row.enabled:Enable() end\n                    addon:SetUIScript(row.enabled,'OnClick',self:Guard(function() if not options.readOnly and valid() then spec.toggle(i,items[i],row) end end))\n                end\n                -- Body coordinates kept free on the first row for the pill.\n                row.firstRowReserve=pillWidth+6\n            elseif row.enabled then row.enabled:Hide() end\n            local bodyX=options.compact and 4 or 26\n            row.body:SetWidth(options.compact and width-bodyX-28 or width-62)\n",
            previous = "            addon:SetUIScript(row.remove,'OnClick',self:Guard(function() if not options.readOnly and self:FlushEdits() and valid() then table.remove(items,i);changed();self:Draw() end end))\n",
        },
        {
            at = 16654,
            current = "",
            previous = "            addon:BindWorkbenchDragSource(row.header,function() view:BeginDrag(i) end,function() if valid() then view:EndDrag() end end)\n",
        },
        {
            at = 16837,
            current = "            self.surface=row.body;self.width=row.body:GetWidth();self.y=options.compact and 2 or 4\n            if self.BeginLabelScope then self:BeginLabelScope() end\n",
            previous = "            self.surface=row.body;self.width=width-62;self.y=options.compact and 2 or options.header==false and 4 or 28\n",
        },
        { at = 17043, current = "            if self.EndLabelScope then self:EndLabelScope() end\n", previous = "" },
        {
            at = 17174,
            current = "            local height=math.max(options.compact and 30 or math.max(44,3+rail*22+2),self.y+8);row:SetHeight(height);row.body:SetHeight(height);row.body:ClearAllPoints();row.body:SetPoint('TOPLEFT',bodyX,0)\n",
            previous = "            local height=math.max(options.compact and 30 or options.header==false and 44 or 68,self.y+8);row:SetHeight(height);row.body:SetHeight(height);row.body:ClearAllPoints();row.body:SetPoint('TOPLEFT',26,options.header==false and -math.max(0,(height-(self.y-4))/2-4) or 0)\n",
        },
    },
}

records["UI/settings_profiles.lua"] = {
    bytes = 10869,
    hash = 2839211645,
    oldBytes = 11740,
    oldHash = 2703702999,
    changes = {
        {
            at = 1208,
            current = "",
            previous = "    local function stockOK(profile)\n        if self.StockSettings.CheckProfile(profile) then return true end\n        p:Message(L['Invalid stock targets; data preserved.']);return false\n    end\n",
        },
        {
            at = 1256,
            current = "",
            previous = "        if operation=='CopyProfile' and not stockOK(saved(name)) then return false end\n",
        },
        {
            at = 1417,
            current = "        local ok,why=pcall(function() db[operation](db,name);if after then after() end end)\n",
            previous = "        local ok,why=pcall(function() if operation=='CopyProfile' and not stockOK(saved(name)) then error(L['Invalid stock targets; data preserved.'],0) end;db[operation](db,name);if after then after() end end)\n",
        },
        {
            at = 2594,
            current = "        {key='duplicate',text=L['Duplicate'],icon='copy',enabled=selected~=nil,action=function() p.previousSelection=p.selection;p.profileSource=selectedName;p.newProfileName=string.format(L['Copy of %s'],selectedName);p.creating=true;p:Draw() end},\n",
            previous = "        {key='duplicate',text=L['Duplicate'],icon='copy',enabled=selected~=nil,action=function() if not stockOK(saved(selectedName)) then return end;p.previousSelection=p.selection;p.profileSource=selectedName;p.newProfileName=string.format(L['Copy of %s'],selectedName);p.creating=true;p:Draw() end},\n",
        },
        { at = 3319, current = "", previous = "            if selected and not stockOK(selected) then return end\n" },
        {
            at = 4431,
            current = "",
            previous = "                    if not stockOK(target) then return false,L['Invalid stock targets; data preserved.'] end\n",
        },
        {
            at = 6368,
            current = "            self:ShowCollectionComparison(p,'profile',{name=left.name,profile=first},{name=right.name,profile=second})\n",
            previous = "            if stockOK(first) and stockOK(second) then self:ShowCollectionComparison(p,'profile',{name=left.name,profile=first},{name=right.name,profile=second}) end\n",
        },
        {
            at = 6500,
            current = "    p:Text(L['Profile changes apply immediately. Rotations and settings belong to the active profile.'])\n",
            previous = "    p:Heading(L['Profiles']);p:Text(L['Profile changes apply immediately. Rotations and settings belong to the active profile.'])\n",
        },
        {
            at = 7161,
            current = "            p.selectAfterProfileChange=name\n            local ok=change('SetProfile',name,function() if source then db:CopyProfile(source) elseif imported then overlay(db.profile,imported) end;db:SetProfile(previous);p.creating=false;p.importProfile=nil;p.profileSource=nil end)\n",
            previous = "            if source and not stockOK(saved(source)) then return end;p.selectAfterProfileChange=name\n            local ok=change('SetProfile',name,function() if source then if not stockOK(saved(source)) then db:SetProfile(previous);error(L['Invalid stock targets; data preserved.'],0) end;db:CopyProfile(source) elseif imported then overlay(db.profile,imported) end;db:SetProfile(previous);p.creating=false;p.importProfile=nil;p.profileSource=nil end)\n",
        },
    },
}

records["UI/settings_unsaved.lua"] = {
    bytes = 12425,
    hash = 2693147360,
    oldBytes = 12702,
    oldHash = 198233167,
    changes = {
        { at = 297, current = "", previous = "    local stockID=id or p.stockSelection\n" },
        {
            at = 497,
            current = "    -- General reads single keys: a view over the profile, not a deep copy of\n    -- it (every rotation included) for each bound control on every draw.\n    if p.settingsKey=='General' then local result={minimap=not (profile.minimap or {}).hide};for i,v in ipairs((store.char or {}).specs or {}) do result['spec'..i]=v end;return setmetatable(result,{__index=profile}) end\n",
            previous = "    if p.settingsKey=='ItemSets' and p.itemSettingsSource=='stock' then return (profile.stockTargets or {})[stockID] end\n    if p.settingsKey=='General' then local result=addon:CopySettingsData(profile);result.minimap=not (profile.minimap or {}).hide;for i,v in ipairs((store.char or {}).specs or {}) do result['spec'..i]=v end;return result end\n",
        },
        {
            at = 5068,
            current = "    function p:UnsavedIdentity() return table.concat({self.settingsKey or '',self.mode or '',tostring(self.mode=='categories' and self.categorySelection or self.settingsKey=='Conditions' and self.condition or self.selection or 'general'),self.creating and 'new' or ''},':') end\n",
            previous = "    function p:UnsavedIdentity() return table.concat({self.settingsKey or '',self.mode or '',self.settingsKey=='ItemSets' and self.itemSettingsSource or '',self.settingsKey=='ItemSets' and self.itemSettingsSource=='stock' and tostring(self.stockSelection) or '',tostring(self.mode=='categories' and self.categorySelection or self.settingsKey=='Conditions' and self.condition or self.selection or 'general'),self.creating and 'new' or ''},':') end\n",
        },
        {
            at = 10549,
            current = "                    selected=self.mode=='categories' and self.categorySelection or self.settingsKey=='Conditions' and self.condition or self.selection,\n",
            previous = "                    selected=self.settingsKey=='ItemSets' and self.itemSettingsSource=='stock' and self.stockSelection or self.mode=='categories' and self.categorySelection or self.settingsKey=='Conditions' and self.condition or self.selection,\n",
        },
    },
}

records["validate.lua"] = {
    bytes = 34967,
    hash = 1826936062,
    oldBytes = 35105,
    oldHash = 1093992229,
    changes = {
        {
            at = 30217,
            current = "        -- stockTargets belongs to the retired desired-stock feature: an\n        -- existing saved map stays exactly as it is (kept above), unread.\n",
            previous = "        local stockTargets=rawget(data,'stockTargets')\n        if stockTargets~=nil then\n            local ok,why=addon.StockTargets.Validate(stockTargets)\n            if not ok then addon:warn(L['Invalid stock targets in profile %s (%s); data preserved.'],profile,why) end\n        end\n",
        },
    },
}

records["UI/spell_search.lua"] = {
    bytes = 15597,
    hash = 3269671316,
    oldBytes = 11631,
    oldHash = 2563953169,
    changes = {
        {
            at = 1458,
            current = "end\n\n-- What the game can offer a spell or item field right now, for its\n-- right-click menu: the target's and focus's current cast, the player's\n-- recent casts (newest first) and equipped trinkets. Each entry is\n-- {id=number, context=format string taking the name}. Values the client\n-- marks unreadable, and repeats, are left out.\nfunction addon:GetReferenceContextEntries(kind)\n    local entries,seen={},{}\n    local platform=self.Platform\n    local function readable(value) return value~=nil and (not platform or not platform.CanReadValue or platform:CanReadValue(value)) end\n    local function add(id,context)\n        if not readable(id) or type(id)~='number' or id<=0 or seen[id] or #entries>=10 then return end\n        seen[id]=true;entries[#entries+1]={id=id,context=context}\n    end\n    local function returned(ok,...) if ok then return ... end end\n    local function call(fn,...) if type(fn)=='function' then return returned(pcall(fn,...)) end end\n    if kind=='spell' then\n        for _,unit in ipairs({'target','focus'}) do\n            local exists=call(UnitExists,unit)\n            if readable(exists) and exists then\n                local casting=select(9,call(UnitCastingInfo,unit));local channel=select(8,call(UnitChannelInfo,unit))\n                add(casting,unit=='target' and L['Target casting: %s'] or L['Focus casting: %s'])\n                add(channel,unit=='target' and L['Target channeling: %s'] or L['Focus channeling: %s'])\n            end\n        end\n        for _,entry in ipairs(type(self.spellHistory)=='table' and self.spellHistory or {}) do\n            if type(entry)=='table' then add(entry.spell,L['Recently cast: %s']) end\n        end\n    elseif kind=='item' then\n        for slot,context in pairs({[13]=L['Trinket 1: %s'],[14]=L['Trinket 2: %s']}) do add(call(GetInventoryItemID,'player',slot),context) end\n        table.sort(entries,function(a,b) return a.context<b.context end)\n    end\n    return entries\n",
            previous = "",
        },
        {
            at = 8741,
            current = "        popup.footer:SetText(footer..'\\n'..(provider.kind=='item' and L['Search or drag an item here'] or L['Search or drag a spell here'])..'\\n'..(provider.kind=='item' and L['Right-click to insert an equipped trinket.'] or L[\"Right-click to insert your target's cast or a recent cast.\"]))\n",
            previous = "        popup.footer:SetText(footer..'\\n'..(provider.kind=='item' and L['Search or drag an item here'] or L['Search or drag a spell here']))\n",
        },
        {
            at = 9086,
            current = "        popup:SetSize(width,math.max(1,#matches)*26+74);popup.footer:SetWidth(width-20)\n",
            previous = "        popup:SetSize(width,math.max(1,#matches)*26+60);popup.footer:SetWidth(width-20)\n",
        },
        {
            at = 9256,
            current = "        highlight();popup.rmContextMenu=nil;popup:Show()\n",
            previous = "        highlight();popup:Show()\n",
        },
        {
            at = 11925,
            current = "    -- Right-click lists what the game offers right now (see\n    -- GetReferenceContextEntries) in the suggestion rows; a click commits it\n    -- exactly like a suggestion.\n    local function insertMenu()\n        if not alive or widget.disabled then return end\n        if popup:IsShown() and popup.rmContextMenu then hide();return end\n        local opts=settings();matches={}\n        for _,entry in ipairs(addon:GetReferenceContextEntries(provider.kind)) do\n            local id=provider.resolve(tostring(entry.id),opts)\n            if id then local info=provider.info and provider.info(id);matches[#matches+1]={id=id,display=string.format(entry.context,provider.name(id,widget:GetUserData('norank')) or tostring(id)),icon=info and info.icon} end\n        end\n        selected=1;navigated=false\n        for index,row in ipairs(popup.rows) do\n            local entry=matches[index];row.referenceID=entry and entry.id;row.spellID=provider.kind=='spell' and row.referenceID or nil;row.itemID=provider.kind=='item' and row.referenceID or nil\n            if entry then row.text:SetText(entry.display);if entry.icon then row.icon:SetTexture(entry.icon);row.icon:Show() else row.icon:Hide() end;row:Show() else row:Hide() end\n        end\n        popup.footer:SetText(#matches==0 and (provider.kind=='item' and L['No equipped trinket to insert.'] or L['Nothing to insert: no target or focus cast and no recent casts.']) or L['Click to insert. Right-click the field again to close.'])\n        local width=math.max(360,field:GetWidth()+16)\n        popup:SetSize(width,math.max(1,#matches)*26+46);popup.footer:SetWidth(width-20)\n        popup:ClearAllPoints();popup:SetPoint(\"TOPLEFT\",field,\"BOTTOMLEFT\",-6,-4)\n        highlight();popup.rmContextMenu=true;popup:Show()\n    end\n    install(field,\"OnReceiveDrag\",drag)\n    install(field,\"OnMouseDown\",function(_,button) if button==\"RightButton\" then insertMenu() else drag() end end)\n",
            previous = "    install(field,\"OnReceiveDrag\",drag);install(field,\"OnMouseDown\",drag)\n",
        },
    },
}

return function(value, path)
    assert(path ~= 'tests/fixtures/restore_workbench_resize.lua', 'workbench resize inverse cannot normalize itself')
    value = dofile('tests/fixtures/restore_bossmod_integration.lua')(value, path)
    local row = type(value) == 'string' and records[path]

    if not row or #value ~= row.bytes or digest(value) ~= row.hash then
        return value
    end

    for i = #row.changes, 1, -1 do
        local c = row.changes[i]
        assert(value:sub(c.at, c.at + #c.current - 1) == c.current, 'workbench resize inverse literal drift: ' .. path)
        value = value:sub(1, c.at - 1) .. c.previous .. value:sub(c.at + #c.current)
    end

    assert(#value == row.oldBytes and digest(value) == row.oldHash, 'workbench resize predecessor differs: ' .. path)
    return value
end
