local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local AceGUI = LibStub("AceGUI-3.0")
local color = color

local helpers = addon.help_funcs
local CreateText, CreatePictureText, Indent, Gap =
    helpers.CreateText, helpers.CreatePictureText, helpers.Indent, helpers.Gap

-- Field documentation is shared by the native workbench and legacy adapters.
function addon:GetGeneralOptionHelp()
    local values={
color.BLIZ_YELLOW .. L['Enable'] .. color.RESET .. " - " ..
            "Allow Rotation Master to perform it's function.  Unckecking this will remove all highlighting, " ..
            "prevent rotation switching and no longer update bound item sets.",
color.BLIZ_YELLOW .. L["Polling Interval (seconds)"] .. color.RESET .. " - " ..
        "How often should Rotation Master check all cooldowns and rotation steps in the currently active " ..
        "rotation to adjust which cooldowns should be highlighted and which rotation step should be active.  " ..
        "The lower this value, the more frequent updates will be made, but also the higher the performance " ..
        "impact will be.  As human response time is generally not much better than 0.25 seconds, setting this " ..
        "too low has no practical impact.",
color.BLIZ_YELLOW .. L["Disable Auto-Switching"] .. color.RESET .. " - " ..
            "Prevent Rotation Master from automatically switching to a different rotation based on it's switch " ..
            "conditions.  This can also be achieved by manually switching to a rotation with the " .. color.MAGENTA ..
            "/rm set <rotation>" .. color.RESET .. " command, however this option is persistent through UI reloads.",
color.BLIZ_YELLOW .. L["Live Status Update Frequency (seconds)"] .. color.RESET .. " - " ..
            "How often should we check cooldown or rotation step conditions (while the configuration menu is " ..
            "open) to update the " .. color.GREEN .. L["Currently satisfied"] .. color.RESET .. " or " .. color.RED ..
            L["Not currently satisfied"] .. color.RESET .. " message to allow for easier condition editing.  If " ..
            "this is set to 0, updaing this condition status will be disabled.",
color.BLIZ_YELLOW .. L["Minimap Icon"] .. color.RESET .. " - " ..
        "Should a Rotation Master icon be added to the border of the minimap.  Left-clicking the minimap icon " ..
        "will open the Rotation Master settings.  Right-clicking will give a mini-menu that allows both enabling " ..
        "and disabling Rotation Master, and switching rotations",
color.BLIZ_YELLOW .. L["Spell History Memory (seconds)"] .. color.RESET .. " - " ..
        "Some conditions use spell cast history as part of their evaluation.  This adjusts how long to remember " ..
        "all previous spell casts for.",
color.BLIZ_YELLOW .. L["Combat History Memory (seconds)"] .. color.RESET .. " - " ..
            "Some conditions use combat history as part of their evaluation (eg. if you were parried, hit, etc).  " ..
            "This adjusts how long to remember your combat history for.",
color.BLIZ_YELLOW .. L["Damage History Memory (seconds)"] .. color.RESET .. " - " ..
        "How long to remember the heals and damage for units in your vacinity.  This is used in the burn rate " ..
        "calculation (ie. dps or hps) on a unit, which is in turn used for Time to Die style calculations.  " ..
        "Newer DPS or heals are given more weight than older DPS or heals in a burn rate calculation.",
color.BLIZ_YELLOW .. L["Disable Bar Highlighting"] .. color.RESET .. " - " ..
            "Do not highlight the active rotation on your action bars.  If you wish to use the preview window " ..
            "exclusively check this, however if this is checked and the preview spells is 0, you will not be " ..
            "able to see rotation steps at all!  This does not effect cooldown highlighting (at the moment).",
color.BLIZ_YELLOW .. L["Preview Spells"] .. color.RESET .. " - " ..
            "The number of spells to preview in a separate window.  If this is 0 (the default) the preview " ..
            "window is not displayed.  The preview window attempts to predict a number of spells in advance, " ..
            "however this is not accurate and will change as current combat circumstances change.",
color.BLIZ_YELLOW .. L["Effect"] .. color.RESET .. " - " ..
        "How a rotation step should be highlighted (and the default for cooldowns).  This selection can be " ..
        "updated in the " .. color.BLUE .. L["Effects"] .. color.RESET .. " configuration screen.",
color.BLIZ_YELLOW .. L["Magnification"] .. color.RESET .. " - " ..
        "How much bigger or smaller than the spell action icon should the cooldown or rotation step highlight " ..
        "be.  This value is simply multiplied by the size of the action icon.  So a 1.0 value would be the " ..
        "same size as the action icon.",
color.BLIZ_YELLOW .. L["Highlight Color"] .. color.RESET .. " - " ..
        "The color and alpha value (ie. opacity) to apply to the rotation step highlight.",
color.BLIZ_YELLOW .. L["Position"] .. color.RESET .. " - " ..
        "The anchor position on the spell action icon for the highlight.  This is only valid if the highlight " ..
        "is a texture (see the " .. color.BLUE .. L["Effects"] .. color.RESET .. " configuration screen to see " ..
        "what type of highlight the effect is.)  The highlight is always anchored at it's center",
color.BLIZ_YELLOW .. "Offset" .. color.RESET .. " - " ..
        "For texture glows, this will offset the anchor point of the highlight.  Left and Right arrows will " ..
        "offset the X axis, and Up and Down arrows will offset the Y axis.  The center button will reset the " ..
        "offset back to the anchor point.  For non-texture highlights, which don't have an anchor point, this " ..
        "functions somewhat like magnification, controlling how much wider (X axis) or taller (Y axis) the " ..
        "highlight will appear compared to the action icon.",
color.BLIZ_YELLOW .. "X" .. color.RESET .. " / " ..
        color.BLIZ_YELLOW .. "Y" .. color.RESET .. " - " ..
        "A display for the X and Y axis offsets controlled by the " .. color.BLUE .. "Offset" .. color.RESET ..
        " control.",
color.BLIZ_YELLOW .. (PRIMARY or L['Primary']) .. color.RESET .. " - " ..
            "The name we use for your primary specialization (as shown in the tabs for in the " ..
            "rotation editing screen).",
color.BLIZ_YELLOW .. (SECONDARY or L['Secondary']) .. color.RESET .. " - " ..
                "The name we use for your secondary specialization (as shown in the tabs for in the " ..
                "rotation editing screen).",
color.BLIZ_YELLOW .. L["Log Level"] .. color.RESET .. " - " ..
        "The of information that Rotation Master will put into your chat text box.",
color.GREEN .. L["Quiet"] .. color.RESET .. " - " ..
        "No output from Rotation Master at all.",
color.GREEN .. L['Default'] .. color.RESET .. " - " ..
            "Normal output about when Rotation Master switches rotation profiles.",
color.GREEN .. L["Debug"] .. color.RESET .. " - " ..
            "Some information about runtime statistics and when certain trigger events happen.",
color.GREEN .. L["Verbose"] .. color.RESET .. " - " ..
            "Detailed information about evaluation of conditions for highlighting buttons.",
color.BLIZ_YELLOW .. L["Detailed Profiling"] .. color.RESET .. " - " ..
            "Should the profiling statistics (visible in debug mode) contain extra information about " ..
            "components of evaluating rotation settings (as opposed to just the overall statistics)."
    }
    local result={}
    for _,value in ipairs(values) do
        local plain=value:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')
        local title,text=plain:match('^(.-) %- (.*)$')
        if title then result[#result+1]={title=title,text=text} end
    end
    local byTitle={};for _,entry in ipairs(result) do byTitle[entry.title]=entry end
    local function extra(title,text) byTitle[title]={title=title,text=text} end
    extra(L['Default rotation view'],L['Choose Diagram or List as the starting rotation view. This profile preference applies when opening a rotation; changing the view inside the editor does not change this setting. Cooldowns always use a scrolling grid.'])
    extra(L['Preview Spells'],L['Choose a whole number of upcoming recommendations, from zero (hidden) to five. The preview shows the current priority results, not a full simulation of future cooldowns or combat. Icons start at 64 pixels; resizing scales all icons while preserving their square shape and the window ratio.'])
    extra(L['Horizontal'],L['Arrange preview icons horizontally (default) or vertically. Below the opacity slider, Lock, Direction and Reset share one row.'])
    extra(L['Vertical'],byTitle[L['Horizontal']].text)
    extra(L['Lock position and size'],L['Prevent moving the preview by its title bar or resizing it by its lower-right corner. Unlock this option in General to adjust it again.'])
    extra(L['Preview window opacity'],L['Adjust the preview background and title bar opacity without fading its icons. At zero only the icons remain, and the hidden frame does not intercept blank-space clicks. Restore opacity in General to access the title bar and resize handle.'])
    extra(L['Reset preview position'],L['Immediately return the preview window to the screen center and restore 64-pixel icons without Apply. Other pending settings are preserved.'])
    extra(L['Highlight preview'],L['The icon shows your selected profile effect, color, size, anchor and offsets.'])
    extra(L['Anchor'],byTitle[L['Position']].text)
    extra(L['V'],L['Vertical offset in pixels. Up and Down change it; hold Shift for ten pixels. Center resets both offsets.'])
    extra(L['H'],L['Horizontal offset in pixels. Left and Right change it; hold Shift for ten pixels. Center resets both offsets.'])
    local log=byTitle[L['Log Level']];for _,title in ipairs({L['Quiet'],L['Default'],L['Debug'],L['Verbose']}) do local row=byTitle[title];if row then log.text=log.text..'\n'..row.title..': '..row.text end end
    local ordered={}
    for _,title in ipairs({L['Enable'],L['Polling Interval (seconds)'],L['Disable Auto-Switching'],L['Disable Bar Highlighting'],L['Live Status Update Frequency (seconds)'],L['Minimap Icon'],L['Default rotation view'],L['Spell History Memory (seconds)'],L['Combat History Memory (seconds)'],L['Damage History Memory (seconds)'],L['Preview Spells'],L['Preview window opacity'],L['Lock position and size'],L['Horizontal'],L['Reset preview position'],L['Highlight preview'],L['Effect'],L['Magnification'],L['Highlight Color'],L['Anchor'],L['V'],L['H']}) do ordered[#ordered+1]=byTitle[title] end
    if WOW_PROJECT_ID~=WOW_PROJECT_MAINLINE and LE_EXPANSION_LEVEL_CURRENT>=2 then ordered[#ordered+1]=byTitle[PRIMARY or L['Primary']];ordered[#ordered+1]=byTitle[SECONDARY or L['Secondary']] end
    ordered[#ordered+1]=log;ordered[#ordered+1]=byTitle[L['Detailed Profiling']]
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
    frame:AddChild(CreateText(L["The switch condition selects the rotation automatically. Edit changes its condition tree. The fallback rotation is selected when no other rotation matches."]))
    frame:AddChild(Gap())
    frame:AddChild(CreateText(L["Cooldown cards have their own scrolling workspace and highlight independently of the sequence. Add cooldown creates a reminder; clicking its action shows local highlight settings."]))
    frame:AddChild(Gap())
    frame:AddChild(CreateText(L["Add action appends a priority action. Drag an Add control into a gap to insert there. Click a card name to rename it, expand for action fields, or click its condition text to edit the guard."]))
    frame:AddChild(Gap())
    frame:AddChild(CreateText(L["Adding a branch moves following steps into its True arm. False is on the left in red; True is on the right in green. The mode pill cycles Evaluate condition, Always true and Always false. Unreachable cards are gray."]))
    frame:AddChild(Gap())
    frame:AddChild(CreateText(L["Ordinary dragging moves one card and its own subtree. Hold Ctrl when starting a drag to carry that card and every following sibling, including their branch subtrees. Drop into a branch arm gap to move there. Up / Down always moves one card. A group cannot be dropped into itself or a carried descendant."]))
    frame:AddChild(Gap())
    frame:AddChild(CreateText(L["An evaluated branch follows one arm, then rejoins later siblings. Stop ends the sequence. Independent cooldowns still apply; implicit Attack remains available unless the Stop suppresses it."]))
    frame:AddChild(Gap())
    frame:AddChild(CreateText(L["Invalid or incomplete cards remain editable. Apply validates both branch arms without running custom condition code. Deleting a whole custom rotation requires confirmation and cannot be undone."]))
    frame:AddChild(Gap())
    frame:AddChild(CreateText(L["List and Cooldowns use flat scrollbars or the mouse wheel. Diagram uses wheel zoom and dragging empty space to pan. Window scaling applies when the slider is released and also affects RM child windows."]))
    frame:AddChild(Gap())
end
