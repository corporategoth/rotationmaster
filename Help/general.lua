-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Help documents for the General settings: the ordered field help (enable, polling, history, preview window, highlight
-- effect, tooltips, specs, logging and the capture and report buttons) and the two page layouts, the primary options
-- help and the rotation options help. Paragraphs live in the locale tables under Help.General.*.
-- Loaded from RotationMaster.toc with the other Help/ files, after Help/common.lua (addon.help_funcs) and UI/. Entries
-- for features a client or build lacks (assisted highlight, talent groups, profiling captures) are added only when the
-- matching addon method exists, so help never documents a control that is not on screen.
local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color

local helpers = addon.help_funcs
local CreateText, Gap = helpers.CreateText, helpers.Gap

-- Returns the General page help entries in page order, with optional entries included only when their feature is
-- present on this client.
-- @return table[]  The entries, each {id=string, title=string, text=string}.
--
-- Field documentation is shared by the native workbench and legacy adapters.
function addon:GetGeneralOptionHelp()
    local ordered = {
        {
            id = "enable",
            title = L["Enable"],
            text = L["Enable Rotation Master recommendations, automatic rotation switching and bound item-set updates. Disabling clears active advice and highlights and hides the preview. Apply saves the change."],
        },
        {
            id = "disable_buttons",
            title = L["Disable Bar Highlighting"],
            text = L["Hide the main rotation recommendation on action bars. Independent cooldown highlights remain available. Enable Preview Spells if you want to see the main advice in a separate window; with both displays off, the main recommendation has no visible icon."],
        },
        {
            id = "minimap",
            title = L["Minimap Icon"],
            text = L["Show the Rotation Master minimap icon. Left-click toggles the configuration window. Right-click opens the quick menu for enabling recommendations and choosing a rotation or automatic switching."],
        },
        {
            id = "poll",
            title = L["Polling Interval (seconds)"],
            text = L["Set how often Rotation Master reevaluates the active rotation and independent cooldowns, in seconds. A shorter interval updates advice more often and uses more processing time. It does not cast spells, queue actions, or predict future combat."],
        },
        {
            id = "idle_poll",
            title = L["Idle Re-check Interval (seconds)"],
            text = L["Out of combat with no target and no focus, Rotation Master skips a polling tick unless something it watches has changed: auras, cooldowns, health or power of you, your pet or party, movement, casting, equipment, bags, form, pets or group. It still re-checks at least this often, for time-based conditions (aura or cooldown remaining), distance, and custom code. In combat, with any target or focus, or while configuration is open, every polling tick is evaluated. Zero evaluates every polling tick."],
        },
        {
            id = "autoswitch_poll",
            title = L["Auto-Switch Re-check Interval (seconds)"],
            text = L["With automatic switching, Rotation Master checks this often, in and out of combat, whether a different rotation's switch conditions now match, so conditions that change on their own (nearby enemy count, threat, movement, health) take effect. Target, focus and pet changes are checked straight away. Zero turns automatic switching off. Choosing a rotation manually still overrides automatic switching until you choose Auto again."],
        },
        {
            id = "live_config_update",
            title = L["Live Status Update Frequency (seconds)"],
            text = L["How often, in seconds, the rotation editor checks each card's condition for the colored bar on the left of its condition field: green when it currently matches for you, red when it does not, gray when it cannot be read at the moment (hover the condition for why and when it was checked). Conditions are checked only while the editor is open; zero turns the bars off. This is separate from the recommendation polling interval."],
        },
        {
            id = "rotation_view",
            title = L["Default rotation view"],
            text = L["Choose Diagram or List as the starting rotation view. This profile preference applies when opening a rotation; changing the view inside the editor does not change this setting. Cooldowns always use a scrolling grid."],
        },
        {
            id = "ignore_mana",
            title = L["Ignore Mana"],
            text = L["Advise a spell even when you do not have the mana or other resource for it right now. Without this, a spell you cannot afford is skipped like any other step that is not ready. The spell must still be learned, off cooldown and usable for another reason, and its conditions still apply."]
                .. (self.Platform:GetCombatDataPolicy() == "restricted"
                    and "\n\n"
                        .. L["Retail and Forever can hide whether a spell is usable from addons in some situations. The spell is then skipped whether or not this option is on."]
                    or ""),
        },
        {
            id = "ignore_range",
            title = L["Ignore Range"],
            text = L["Advise a spell or item even when your target is out of its range. Without this, a step whose range check fails is skipped. The spell or item must still be learned or owned, off cooldown and usable, and its conditions still apply."],
        },
        {
            id = "spell_history",
            title = L["Spell History Memory (seconds)"],
            text = L["Choose how many seconds of previous spell casts to retain for history-based conditions. Older casts are removed as recommendations update. A longer history retains more records."],
        },
        {
            id = "combat_history",
            title = L["Combat History Memory (seconds)"],
            text = L["Choose how many seconds of combat events to retain for conditions such as recent hits, parries and blocks. Older events are removed as recommendations update. Availability depends on the client combat-data policy."],
        },
        {
            id = "damage_history",
            title = L["Damage History Memory (seconds)"],
            text = L["Choose how many seconds of observed damage and healing to retain for burn-rate and time-to-die estimates. Recent observations receive more weight. A longer window uses more records and smooths short changes; it cannot supply events the client does not expose."],
        },
        {
            id = "preview_spells",
            title = L["Preview Spells"],
            text = L["Choose a whole number of upcoming recommendations, from zero (hidden) to five. This is the only switch for the preview window: it is shown whenever this is above zero and hidden at zero, and the window has no close button. The preview shows current priority results, not a simulation of future cooldowns or combat. Icons start at 64 pixels; resizing scales all icons while preserving their square shape and the window ratio."],
        },
        {
            id = "preview_opacity",
            title = L["Preview window opacity"],
            text = L["Adjust the preview background opacity without fading its icons. At zero only the icons remain, the hidden background does not intercept blank-space clicks and the resize grip is unavailable; an unlocked preview can still be dragged by its icons. Restore opacity in General to resize it."],
        },
        {
            id = "preview_locked",
            title = L["Lock position and size"],
            text = L["Unlocked, drag the preview by any icon or its background to move it, and resize it from the grip that appears at its lower-right corner on hover. Locked, it cannot be moved or resized and its background lets clicks through. Right-click an icon (or the background while unlocked) for a menu to lock, unlock or open these settings. Locking and unlocking take effect immediately and are saved without Apply. Other pending General edits remain unchanged."],
        },
        {
            id = "preview_vertical",
            title = L["Horizontal"],
            text = L["Arrange preview icons horizontally (default) or vertically. Lock, Direction and Reset share one row below the opacity slider. Changing direction keeps icons square and adjusts the window ratio."],
        },
        {
            id = "preview_reset",
            title = L["Reset preview position"],
            text = L["Immediately return the preview window to the screen center and restore 64-pixel icons without Apply. Other pending settings are preserved."],
        },
        {
            id = "preview_skin",
            title = L["Skin"],
            text = L["Enable Masque in Integrations to choose a skin. Skin changes update the open preview immediately and are saved by Masque, independently of Apply or Discard. Without enabled Masque support, the preview uses Blizzard Classic. Preview toggles sample icons whether Masque is enabled or not."],
        },
        {
            id = "preview_sample",
            title = L["Preview"],
            text = L["Click Preview to toggle temporary sample icons when no real recommendations are available. Real recommendations replace the samples. This does not change Preview Spells, cast spells, or save the sample state."],
        },
        {
            id = "preview",
            title = L["Highlight preview"],
            text = L["This icon previews the selected profile effect, color, size, anchor and offsets. Previewing an effect does not save the draft or change the spell being recommended."],
        },
        {
            id = "effect",
            title = L["Effect"],
            text = L["Choose the highlight used for the main recommendation and as the default for independent cooldowns. Manage available effects on the Effects page. A cooldown can override these profile settings in its action details."],
        },
        {
            id = "magnification",
            title = L["Magnification"],
            text = L["Scale the highlight relative to its action icon. A value of 1 uses the icon size. Drag the slider or type its numeric value; the preview updates as you edit."],
        },
        {
            id = "color",
            title = L["Highlight Color"],
            text = L["Choose the highlight color and opacity. Click the color swatch to open the picker, or enter R, G, B and A values between 0 and 1. Alpha controls opacity; individual cooldowns may override this profile color."],
        },
        {
            id = "setpoint",
            title = L["Anchor"],
            text = L["Choose the point on the action icon where a texture highlight is anchored by its center. Changing Anchor resets the offsets. The preview shows the resulting placement; non-texture glows may use offsets without a texture anchor."],
        },
        {
            id = "yoffs",
            title = L["V"],
            text = L["Vertical offset in pixels. Use Up or Down on the position control, or edit V directly. Hold Shift while using an arrow for ten pixels. Center resets both offsets and the anchor to Center."],
        },
        {
            id = "xoffs",
            title = L["H"],
            text = L["Horizontal offset in pixels. Use Left or Right on the position control, or edit H directly. Hold Shift while using an arrow for ten pixels. Non-texture glows interpret offsets according to their effect shape."],
        },
    }

    if self.GetAssistedHighlightSupport and self:GetAssistedHighlightSupport() then
        ordered[#ordered + 1] = {
            id = "assisted_highlight",
            title = L["Blizzard's suggestion highlight"],
            text = L["Who highlights the button while a \"Blizzard's suggestion\" step is the recommendation. Rotation Master's glow uses the effect below. Blizzard's Assisted Highlight turns on the game's own highlight (Options, Gameplay, Combat, Assisted Highlight) while a rotation with that step is active, and Rotation Master leaves that step's button to it; Both shows the two. Rotation Master turns Blizzard's highlight on only outside combat, never changes it if it was already on, and puts your setting back when the rotation ends, Rotation Master is disabled, or you log out or reload. If you change the setting yourself meanwhile, your choice is kept. Blizzard's highlight follows Blizzard's suggestion all the time, also while another step is recommended, and it shows on Blizzard's own action bars only, so choose Rotation Master's glow or Both with a bar addon. The choice is hidden on clients without Blizzard's highlight (Forever and the Classic clients)."],
        }
    end

    ordered[#ordered + 1] = {
        id = "tooltips",
        title = L["Show Rotation Master in tooltips"],
        text = L["Add Rotation Master lines to spell and item tooltips. This is the master switch: off, Rotation Master adds nothing to any tooltip, and the options below do nothing. Lines are only added, never read from the tooltip, so other tooltip addons are unaffected."],
    }

    ordered[#ordered + 1] = {
        id = "tooltip_disabled_rotations",
        title = L["Include disabled rotations"],
        text = L["Also list the rotations for your current specialization that are switched off, dimmed and marked disabled, after the ones that are on. Turn this off to list only rotations that are on; the \"(+N more)\" count then leaves the switched-off ones out too."],
    }

    ordered[#ordered + 1] = {
        id = "tooltip_conditions",
        title = L["Include rotation conditions"],
        text = L["Also count a spell or item that appears only inside a condition (for example \"spell is ready\" or \"item is carried\"), not just as a step. Off by default because it lists more rotations."],
    }

    ordered[#ordered + 1] = {
        id = "tooltip_exclude_disabled_conditions",
        title = L["Exclude disabled conditions"],
        text = L["With rotation conditions included, leave out any condition that is switched off in the rotation editor, together with everything under it, because a disabled condition no longer affects the rotation. Off by default: a spell or item that appears only in a disabled condition still counts."],
    }

    ordered[#ordered + 1] = {
        id = "tooltip_itemsets",
        title = L["List item sets in item tooltips"],
        text = L["In an item tooltip, list the Rotation Master item sets that contain the item: your profile's and the shared ones from the Item Sets page. Names beyond the limit below end the line with how many more there are."],
    }

    ordered[#ordered + 1] = {
        id = "tooltip_rotations",
        title = L["List rotations in spell and item tooltips"],
        text = L["In a spell or item tooltip, list the rotations for your current specialization that use it as a step in the rotation or cooldown list. A rotation that is switched off is shown dimmed and marked disabled. Built In rotations that are not for this version of the game or your specialization are left out. The list is refreshed out of combat after a rotation or item set changes."],
    }

    ordered[#ordered + 1] = {
        id = "tooltip_limit",
        title = L["Names listed per tooltip line"],
        text = L["How many names a tooltip line lists before it ends with \"(+N more)\". A lower number keeps tooltips short."],
    }

    if
        WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE
        and LE_EXPANSION_LEVEL_CURRENT >= 2
        and self.db
        and self.db.char
        and self.db.char.specs
    then
        ordered[#ordered + 1] = {
            id = "spec1",
            title = PRIMARY or L['Primary'],
            text = L["Choose the display name for your primary specialization. This changes its label in Rotation Master, not your character talents or specialization."],
        }

        ordered[#ordered + 1] = {
            id = "spec2",
            title = SECONDARY or L['Secondary'],
            text = L["Choose the display name for your secondary specialization. This changes its label in Rotation Master, not your character talents or specialization."],
        }
    end

    ordered[#ordered + 1] = {
        id = "loglevel",
        title = L['Log Level'],
        text = L["Choose the amount of Rotation Master chat output. Silent suppresses routine output. Default reports normal changes such as rotation switching. Debug adds runtime statistics and trigger information. Verbose includes detailed condition and highlight activity and can produce substantial output."],
    }

    ordered[#ordered + 1] = {
        id = "detailed_profiling",
        title = L['Detailed Profiling'],
        text = L["Include component timings in the periodic Debug or Verbose profiling report. Reports show measured runs, total, minimum, average and maximum in milliseconds. Timings include child work; nested scopes overlap and must not be added together. The overall scope starts after rotation preparation. This is elapsed timing, not the native addon CPU report."],
    }

    if self.GetCacheDiagnosticMode then
        ordered[#ordered + 1] = {
            id = 'cpu_cache_bypass',
            title = L['Enable observation cache'],
            text = L["Optional reuse of repeated getCached and getRetryCached lookups. Observation caching is off by default to reduce table allocations; enabling it can help conditions that repeat the same lookup. Compiled condition facts are independent of this option. The checkbox shows the saved choice for the next reload. Pending means it differs from the running mode. Use /reload to apply it; no full game restart is needed. This choice saves immediately without applying or discarding other pending settings."],
        }
    end

    -- Capture columns: CPU, Runtime, Memory, Casts. Each capture button also
    -- stops its running capture; the probe stays a /rm perf probe command.
    if self.RunCPUProfileAction then
        ordered[#ordered + 1] = {
            id = 'cpu_capture',
            title = L['Capture CPU (10s)'],
            text = L["Capture native cumulative function CPU costs and call counts for ten seconds. /rm perf cpu starts the same capture; /rm perf cpu 30 chooses 30 seconds (range 1–60). /rm perf cpu stop finalizes partial counters; /rm perf cpu report opens the copyable result. Capture uses live settings and does not apply pending changes. Close configuration after starting. WoW scriptProfile must already be enabled before a reload; RM never changes it or resets shared counters. Profiling itself adds overhead."],
        }

        ordered[#ordered + 1] = {
            id = 'cpu_report',
            title = L['CPU report'],
            text = L["Open a selectable, copyable report with total addon CPU, measured function costs and calls, sample boundaries, and unavailable or replaced functions. Inclusive costs overlap and must not be added together. Boundary state does not prove configuration or combat stayed unchanged throughout the capture. Untracked functions and native work may account for remaining costs."],
        }

        if type(self.StartCPURuntimeCapture) == 'function' then
            ordered[#ordered + 1] = {
                id = 'cpu_runtime_capture',
                title = L['Capture runtime (10s)'],
                text = L["Measure normal rotation evaluation calls for ten seconds with the native profiler. /rm perf runtime accepts 1–60 seconds (default 10), plus stop and report. The 512-dispatch safety limit can end a longer capture sooner. Polling stays unchanged. Stop finalizes partial measurements; the legacy Cancel capture action still cancels. Close configuration after starting. Instrumentation adds overhead; allocation is not retained memory or proof of a leak. Cumulative CPU captures cannot overlap this capture."],
            }

            ordered[#ordered + 1] = {
                id = 'cpu_runtime_report',
                title = L['Runtime report'],
                text = L["Open the copyable runtime report: measured evaluation calls, native elapsed time and gross allocation/deallocation counters. Missing metrics remain unavailable. Measurement covers evaluation calls only, not all addon events or rendering. Reading the report does not sample gameplay."],
            }
        end

        if self.StartMemoryCapture then
            ordered[#ordered + 1] = {
                id = 'memory_capture',
                title = L['Capture memory (10m)'],
                text = L["Observe memory for ten minutes without changing polling or forcing garbage collection. /rm perf memory accepts 1–1800 seconds (default 600), plus stop and report. Whole-Lua heap is sampled each second; bounded retained counts every thirty seconds. Addon attribution refreshes only at start and completion; intermediate values are cached with unknown age. Stop completes the final boundary before you open the report. Refreshes can hitch, and their cost is reported. Heap decreases do not prove collection or a leak."],
            }

            ordered[#ordered + 1] = {
                id = 'memory_report',
                title = L['Memory report'],
                text = L["Open the copyable lifetime report: whole-heap range and decreases, start/end addon attribution, explicitly cached intermediate values, retained key/row counts and capture overhead. Counts are not bytes; unavailable and capped observations stay explicit. Viewing the report never resamples memory."],
            }
        end
    end

    if self.RunCastCaptureAction then
        ordered[#ordered + 1] = {
            id = 'cast_capture',
            title = L['Capture casts (30s)'],
            text = L["Record spell cast receipts for thirty seconds without changing settings or gameplay polling. While it runs this button reads Stop cast capture and ends the capture early, keeping what was recorded."],
        }

        ordered[#ordered + 1] = {
            id = 'cast_report',
            title = L['Cast report'],
            text = L["Open the copyable cast receipt report. It stays disabled until a cast capture has produced a report and while a capture is running."],
        }
    end

    return ordered
end

-- Lays out the General page help: an introduction to automatic action requirements, then every field entry as a yellow
-- title followed by its paragraph.
-- @param frame table  The help frame the text widgets are added to.
function addon.layout_primary_options_help(frame)
    frame:AddChild(CreateText(
        L['Actions automatically require a learned spell or carried item, usable resources, cooldown readiness and valid range. Conditions can additionally test other actions.']
    ))

    for _, entry in ipairs(addon:GetGeneralOptionHelp()) do
        frame:AddChild(Gap())
        frame:AddChild(CreateText(color.BLIZ_YELLOW .. entry.title .. color.RESET .. ' - ' .. entry.text))
    end
end

-- Lays out the Rotations page help overview as a series of short paragraphs: cards, drafts and Apply/Discard, the
-- switch and fallback, cooldowns, branches, dragging, Stop, validation and the list/diagram controls.
-- @param frame table  The help frame the text widgets are added to.
function addon.layout_rotation_options_help(frame)
    frame:AddChild(CreateText(
        L["Built In and custom rotations use the same cards. Built In rotations are read-only; enable or disable them, inspect their conditions, or Duplicate to edit."]
    ))

    frame:AddChild(Gap())

    frame:AddChild(CreateText(
        L["Custom edits stay in a private draft. Apply saves; Discard restores the saved rotation. Undo and Redo include card deletion, movement, fields and conditions. Apply before reloading or logging out."]
    ))

    frame:AddChild(Gap())

    frame:AddChild(CreateText(
        L["Closing the window retains drafts for this session. Switching rotations or opening comparison or transfer asks whether to Apply, Discard or Cancel when changes are pending."]
    ))

    frame:AddChild(Gap())

    frame:AddChild(CreateText(
        L["The switch condition selects the rotation automatically; with none, it is selected whenever its specialization and level apply. Edit changes its condition tree. The fallback rotation is selected when no other rotation matches."]
    ))

    frame:AddChild(Gap())

    frame:AddChild(CreateText(
        L["Cooldown cards have their own scrolling workspace and highlight independently of the sequence. Add cooldown creates a reminder; clicking its action shows local highlight settings."]
    ))

    frame:AddChild(Gap())

    frame:AddChild(CreateText(
        L["Add action appends a priority action. Drag an Add control into a gap to insert there. Click a card name to rename it, expand for action fields, or click its condition text to edit the guard."]
    ))

    frame:AddChild(Gap())

    frame:AddChild(CreateText(
        L["Adding a branch moves following steps into its True arm. False is on the left in red; True is on the right in green. The mode pill cycles Evaluate condition, Always true and Always false. Unreachable cards are gray."]
    ))

    frame:AddChild(Gap())

    frame:AddChild(CreateText(
        L["Ordinary dragging moves one card and its own subtree. Hold Ctrl when starting a drag to carry that card and every following sibling, including their branch subtrees. Drop into a branch arm gap to move there. Up / Down always moves one card. A group cannot be dropped into itself or a carried descendant."]
    ))

    frame:AddChild(Gap())

    frame:AddChild(CreateText(
        L["An evaluated branch follows one arm, then rejoins later siblings. Stop ends the sequence. Independent cooldowns still apply; implicit auto-attack (Attack or Shoot) remains available unless the Stop suppresses it."]
    ))

    frame:AddChild(Gap())

    frame:AddChild(CreateText(
        L["Invalid or incomplete cards remain editable. Apply validates both branch arms without running custom condition code. Deleting a whole custom rotation requires confirmation and cannot be undone."]
    ))

    frame:AddChild(Gap())

    frame:AddChild(CreateText(
        L["List and Cooldowns use flat scrollbars or the mouse wheel. Diagram uses wheel zoom and dragging empty space to pan. Window scaling applies when the slider is released and also affects RM child windows."]
    ))

    frame:AddChild(Gap())
end
