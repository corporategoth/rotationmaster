local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color

local helpers = addon.help_funcs
local CreateText, Gap = helpers.CreateText, helpers.Gap

-- Field documentation is shared by the native workbench and legacy adapters.
function addon:GetGeneralOptionHelp()
    local ordered={
        {id="enable",title=L["Enable"],text=L["Help.General.enable"]},
        {id="disable_buttons",title=L["Disable Bar Highlighting"],text=L["Help.General.disable_buttons"]},
        {id="minimap",title=L["Minimap Icon"],text=L["Help.General.minimap"]},
        {id="poll",title=L["Polling Interval (seconds)"],text=L["Help.General.poll"]},
        {id="idle_poll",title=L["Idle Re-check Interval (seconds)"],text=L["Help.General.idle_poll"]},
        {id="autoswitch_poll",title=L["Auto-Switch Re-check Interval (seconds)"],text=L["Help.General.autoswitch_poll"]},
        {id="live_config_update",title=L["Live Status Update Frequency (seconds)"],text=L["Help.General.live_config_update"]},
        {id="rotation_view",title=L["Default rotation view"],text=L["Help.General.rotation_view"]},
        {id="spell_history",title=L["Spell History Memory (seconds)"],text=L["Help.General.spell_history"]},
        {id="combat_history",title=L["Combat History Memory (seconds)"],text=L["Help.General.combat_history"]},
        {id="damage_history",title=L["Damage History Memory (seconds)"],text=L["Help.General.damage_history"]},
        {id="preview_spells",title=L["Preview Spells"],text=L["Help.General.preview_spells"]},
        {id="preview_opacity",title=L["Preview window opacity"],text=L["Help.General.preview_opacity"]},
        {id="preview_locked",title=L["Lock position and size"],text=L["Help.General.preview_locked"]},
        {id="preview_vertical",title=L["Horizontal"],text=L["Help.General.preview_vertical"]},
        {id="preview_reset",title=L["Reset preview position"],text=L["Help.General.preview_reset"]},
        {id="preview_skin",title=L["Skin"],text=L["Help.General.preview_skin"]},
        {id="preview_sample",title=L["Preview"],text=L["Help.General.preview_sample"]},
        {id="preview",title=L["Highlight preview"],text=L["Help.General.preview"]},
        {id="effect",title=L["Effect"],text=L["Help.General.effect"]},
        {id="magnification",title=L["Magnification"],text=L["Help.General.magnification"]},
        {id="color",title=L["Highlight Color"],text=L["Help.General.color"]},
        {id="setpoint",title=L["Anchor"],text=L["Help.General.setpoint"]},
        {id="yoffs",title=L["V"],text=L["Help.General.yoffs"]},
        {id="xoffs",title=L["H"],text=L["Help.General.xoffs"]},
    }
    if self.GetAssistedHighlightSupport and self:GetAssistedHighlightSupport() then
        ordered[#ordered+1]={id="assisted_highlight",title=L["Blizzard's suggestion highlight"],text=L["Help.General.assisted_highlight"]}
    end
    if WOW_PROJECT_ID~=WOW_PROJECT_MAINLINE and LE_EXPANSION_LEVEL_CURRENT>=2 and self.db and self.db.char and self.db.char.specs then
        ordered[#ordered+1]={id="spec1",title=PRIMARY or L['Primary'],text=L['Help.General.spec1']}
        ordered[#ordered+1]={id="spec2",title=SECONDARY or L['Secondary'],text=L['Help.General.spec2']}
    end
    ordered[#ordered+1]={id="loglevel",title=L['Log Level'],text=L['Help.General.loglevel']}
    ordered[#ordered+1]={id="detailed_profiling",title=L['Detailed Profiling'],text=L['Help.General.detailed_profiling']}
    if self.GetCacheDiagnosticMode then ordered[#ordered+1]={id='cpu_cache_bypass',title=L['Enable observation cache'],text=L['Help.General.cpu_cache_bypass']} end
    -- Capture columns: CPU, Runtime, Memory, Casts. Each capture button also
    -- stops its running capture; the probe stays a /rm perf probe command.
    if self.RunCPUProfileAction then
        ordered[#ordered+1]={id='cpu_capture',title=L['Capture CPU (10s)'],text=L['Help.General.cpu_capture']}
        ordered[#ordered+1]={id='cpu_report',title=L['CPU report'],text=L['Help.General.cpu_report']}
        if type(self.StartCPURuntimeCapture)=='function' then
            ordered[#ordered+1]={id='cpu_runtime_capture',title=L['Capture runtime (10s)'],text=L['Help.General.cpu_runtime_capture']}
            ordered[#ordered+1]={id='cpu_runtime_report',title=L['Runtime report'],text=L['Help.General.cpu_runtime_report']}
        end
        if self.StartMemoryCapture then
            ordered[#ordered+1]={id='memory_capture',title=L['Capture memory (10m)'],text=L['Help.General.memory_capture']}
            ordered[#ordered+1]={id='memory_report',title=L['Memory report'],text=L['Help.General.memory_report']}
        end
    end
    if self.RunCastCaptureAction then
        ordered[#ordered+1]={id='cast_capture',title=L['Capture casts (30s)'],text=L['Help.General.cast_capture']}
        ordered[#ordered+1]={id='cast_report',title=L['Cast report'],text=L['Help.General.cast_report']}
    end
    return ordered
end

function addon.layout_primary_options_help(frame)
    frame:AddChild(CreateText(L['Actions automatically require a learned spell or carried item, usable resources, cooldown readiness and valid range. Conditions can additionally test other actions.']))
    for _,entry in ipairs(addon:GetGeneralOptionHelp()) do frame:AddChild(Gap());frame:AddChild(CreateText(color.BLIZ_YELLOW..entry.title..color.RESET..' - '..entry.text)) end
end

function addon.layout_rotation_options_help(frame)
    frame:AddChild(CreateText(L["Built In and custom rotations use the same cards. Built In rotations are read-only; enable or disable them, inspect their conditions, or Duplicate to edit."]))
    frame:AddChild(Gap())
    frame:AddChild(CreateText(L["Custom edits stay in a private draft. Apply saves; Discard restores the saved rotation. Undo and Redo include card deletion, movement, fields and conditions. Apply before reloading or logging out."]))
    frame:AddChild(Gap())
    frame:AddChild(CreateText(L["Closing the window retains drafts for this session. Switching rotations or opening comparison or transfer asks whether to Apply, Discard or Cancel when changes are pending."]))
    frame:AddChild(Gap())
    frame:AddChild(CreateText(L["The switch condition selects the rotation automatically; with none, it is selected whenever its specialization and level apply. Edit changes its condition tree. The fallback rotation is selected when no other rotation matches."]))
    frame:AddChild(Gap())
    frame:AddChild(CreateText(L["Cooldown cards have their own scrolling workspace and highlight independently of the sequence. Add cooldown creates a reminder; clicking its action shows local highlight settings."]))
    frame:AddChild(Gap())
    frame:AddChild(CreateText(L["Add action appends a priority action. Drag an Add control into a gap to insert there. Click a card name to rename it, expand for action fields, or click its condition text to edit the guard."]))
    frame:AddChild(Gap())
    frame:AddChild(CreateText(L["Adding a branch moves following steps into its True arm. False is on the left in red; True is on the right in green. The mode pill cycles Evaluate condition, Always true and Always false. Unreachable cards are gray."]))
    frame:AddChild(Gap())
    frame:AddChild(CreateText(L["Ordinary dragging moves one card and its own subtree. Hold Ctrl when starting a drag to carry that card and every following sibling, including their branch subtrees. Drop into a branch arm gap to move there. Up / Down always moves one card. A group cannot be dropped into itself or a carried descendant."]))
    frame:AddChild(Gap())
    frame:AddChild(CreateText(L["An evaluated branch follows one arm, then rejoins later siblings. Stop ends the sequence. Independent cooldowns still apply; implicit auto-attack (Attack or Shoot) remains available unless the Stop suppresses it."]))
    frame:AddChild(Gap())
    frame:AddChild(CreateText(L["Invalid or incomplete cards remain editable. Apply validates both branch arms without running custom condition code. Deleting a whole custom rotation requires confirmation and cannot be undone."]))
    frame:AddChild(Gap())
    frame:AddChild(CreateText(L["List and Cooldowns use flat scrollbars or the mouse wheel. Diagram uses wheel zoom and dragging empty space to pan. Window scaling applies when the slider is released and also affects RM child windows."]))
    frame:AddChild(Gap())
end
