-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Help document for the Effects settings page: the effect types (texture, pixel, auto cast, glow, proc glow, dazzle,
-- animate, pulse, rotate, custom), each type's tuning fields, the sequence settings, Apply/Cancel, Delete and the
-- collection buttons, plus the renderer that lays them out in a help frame. Paragraphs live in the locale tables under
-- Help.Effects.*; this file only orders them.
-- Loaded from RotationMaster.toc with the other Help/ files, after Help/common.lua (addon.help_funcs) and UI/.
local addon_name, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs
local CreateText, Gap = helpers.CreateText, helpers.Gap

-- Returns the Effects page help sections.
-- @return table[]  The sections, each {id=string, title=string, text=string}.
--
-- Whole paragraphs preserve translation word order and retain distinct units for library glow rates versus RM
-- texture/sequence timer intervals.
function addon:GetDocument_layout_effects_options_help()
    return {
        {
            id = "overview",
            title = L["Effects"],
            text = L["Effects define how action-bar icons are highlighted. They are shared across characters. General settings select the main recommendation effect and cooldown default; individual cooldowns can choose another effect. Select an effect in the sidebar to inspect or edit it."],
        },
        {
            id = "name",
            title = L["Name"],
            text = L["Give the effect a name used by selectors in General and cooldown action details. New drafts can change type and fields before being named, but Apply requires a nonempty, unique name."],
        },
        {
            id = "type",
            title = L["Type"],
            text = L["Choose the highlight implementation. Changing type stages the new fields and resets its sequence because different sequence types store different values. Choosing the current type preserves existing values. Apply saves the change; Discard restores the saved effect."],
        },
        {
            id = "type.texture",
            title = L["Texture"],
            text = L["Texture: overlay a single image from game data or an installed addon. Its color, magnification and position come from the profile or the individual cooldown."],
        },
        {
            id = "type.pixel",
            title = L["Pixel"],
            text = L["Pixel: animate short lines around the action icon border. Lines, Frequency, Length and Thickness control this library glow."],
        },
        {
            id = "type.autocast",
            title = L["Auto Cast"],
            text = L["Auto Cast: animate groups of glowing particles around the action icon. Particles, Frequency and Scale control this library glow."],
        },
        {
            id = "type.blizzard",
            title = L["Glow"],
            text = L["Glow: use the familiar Blizzard-style button glow. Frequency controls its animation rate."],
        },
        {
            id = "type.proc",
            title = L["Proc Glow"],
            text = L["Proc Glow: use the animated actionbar proc border from LibCustomGlow. Rotation Master checks the required game artwork and animation support before using it. Unsupported clients use Pixel glow instead; the definition remains portable. Color and offsets come from the profile or the cooldown."],
        },
        {
            id = "type.dazzle",
            title = L["Dazzle"],
            text = L["Dazzle: keep one texture and cycle through the sequence of colors. Each sequence card contains one RGBA color."],
        },
        {
            id = "type.animate",
            title = L["Animate"],
            text = L["Animate: cycle through the sequence of texture images. Each card selects one image and previews that selection."],
        },
        {
            id = "type.pulse",
            title = L["Pulse"],
            text = L["Pulse: keep one texture and cycle through the sequence of magnifications. Each card selects one scale relative to the action icon."],
        },
        {
            id = "type.rotate",
            title = L["Rotate"],
            text = L["Rotate: animate one texture through evenly spaced angles around a full circle. Steps chooses the number of angles and Reverse changes their order."],
        },
        {
            id = "type.custom",
            title = L["Custom"],
            text = L["Custom: cycle through cards containing a texture, angle, magnification and color. Each card supplies its own settings instead of relying on one shared texture."],
        },
        {
            id = "preview",
            title = L["Preview"],
            text = L["The image beside Name and Type previews the current draft with a white color and standard size. Texture and sequence changes update the preview without saving. Actual recommendations use their profile or cooldown color, size and offsets."],
        },
        {
            id = "texture",
            title = L["Texture"],
            text = L["For Texture, Dazzle, Pulse and Rotate, choose the image used throughout the effect. The arrow beside an image field opens the bundled overlay catalog with previews. Enter an available texture path or numeric file ID to use another image. Animate and Custom choose images in their sequence cards using the same controls. Selections update the draft and preview; Apply saves them."],
        },
        {
            id = "pixel.lines",
            title = L["Lines"],
            text = L["Pixel effects: choose the number of animated lines around the button, from 1 to 20."],
        },
        {
            id = "pixel.frequency",
            title = L["Frequency"],
            text = L["Pixel effects: signed cycles per second. A larger magnitude moves faster; a negative value reverses direction. Zero uses the glow library default of one cycle every four seconds."],
        },
        {
            id = "pixel.length",
            title = L["Length"],
            text = L["Pixel effects: choose line length in pixels. The glow library limits it to the smaller button dimension."],
        },
        {
            id = "pixel.thickness",
            title = L["Thickness"],
            text = L["Pixel effects: choose line thickness in pixels, from 1 to 5."],
        },
        {
            id = "autocast.particles",
            title = L["Particles"],
            text = L["Auto Cast effects: choose 1 to 4 particles in each of the glow library particle groups."],
        },
        {
            id = "autocast.frequency",
            title = L["Frequency"],
            text = L["Auto Cast effects: signed cycles per second. A larger magnitude moves faster; a negative value reverses direction. Zero uses the glow library default of one cycle every eight seconds."],
        },
        {
            id = "autocast.scale",
            title = L["Scale"],
            text = L["Auto Cast effects: scale the particles relative to the glow library default. A value of 1 uses their normal size."],
        },
        {
            id = "blizzard.frequency",
            title = L["Frequency"],
            text = L["Glow effects: adjust the library animation rate. Larger positive values animate faster. Zero uses the library default rather than stopping the glow."],
        },
        {
            id = "proc.duration",
            title = L["Loop duration"],
            text = L["Time in seconds for one repeating proc-border animation, from 0.1 to 5. Use the slider or enter an exact value in its number field. Changing the value updates the preview."],
        },
        {
            id = "proc.startAnim",
            title = L["Start burst"],
            text = L["Play the opening burst when this highlight first appears, then repeat its border animation. Off by default. Refreshing an already visible Proc Glow does not restart the burst."],
        },
        {
            id = "dazzle.frequency",
            title = L["Frequency"],
            text = L["Dazzle effects: seconds between color cards. A smaller positive interval changes colors more often; the sequence repeats after the last color."],
        },
        {
            id = "animate.frequency",
            title = L["Frequency"],
            text = L["Animate effects: seconds between texture cards. A smaller positive interval changes images more often; the sequence repeats after the last image."],
        },
        {
            id = "pulse.frequency",
            title = L["Frequency"],
            text = L["Pulse effects: seconds between magnification cards. A smaller positive interval changes size more often; the sequence repeats after the last size."],
        },
        {
            id = "rotate.frequency",
            title = L["Frequency"],
            text = L["Rotate effects: seconds between angle steps. A smaller positive interval rotates faster. One full cycle uses this interval multiplied by Steps."],
        },
        {
            id = "rotate.steps",
            title = L["Steps"],
            text = L["Rotate effects: choose 2 to 36 evenly spaced angles for a full turn. More steps at the same Frequency interval make a longer complete cycle."],
        },
        {
            id = "rotate.reverse",
            title = L["Reverse"],
            text = L["Rotate effects: reverse the order of angle steps. Changing this checkbox does not alter the texture or number of steps."],
        },
        {
            id = "custom.frequency",
            title = L["Frequency"],
            text = L["Custom effects: seconds between sequence cards. A smaller positive interval changes settings more often; the sequence repeats after the last card."],
        },
        {
            id = "sequence",
            title = L["Sequence"],
            text = L["Sequence cards play in order and repeat. Add step, on the Sequence header row, appends a card; drag Add step into a gap to insert one there. Drag a card into an insertion gap to reorder it; hold Ctrl when starting to carry it and all following cards. Up and Down move one card and are disabled at their respective ends. The red trash removes a card from the draft. Canceling a drag restores its original position."],
        },
        {
            id = "sequence.texture",
            title = L["Texture"],
            text = L["Animate and Custom cards: choose a texture path or numeric file ID. The card preview shows the selected image. Custom also keeps an independent angle, magnification and color on that card."],
        },
        {
            id = "sequence.angle",
            title = L["Angle"],
            text = L["Custom cards: set the texture angle in degrees from 0 to 359. This is the angle for this card, rather than a continuous rotation speed."],
        },
        {
            id = "sequence.magnification",
            title = L["Magnification"],
            text = L["Pulse and Custom cards: scale the texture relative to the action icon. A value of 1 uses the icon size. Use the slider or edit its numeric value."],
        },
        {
            id = "sequence.color",
            title = L["Color"],
            text = L["Dazzle and Custom cards: choose an RGBA color. Click the swatch to open the picker, or edit channels between 0 and 1. Alpha controls opacity."],
        },
        {
            id = "save",
            title = L["Apply / Cancel"],
            text = L["Edits and sequence changes remain in a draft. Apply saves; Discard restores the saved effect. Cancel closes a new creation draft. View Changes compares saved and unsaved values. New drafts require a unique name and valid fields before Apply. Leaving with edits offers Apply, Discard or Cancel."],
        },
        {
            id = "delete",
            title = L["Delete"],
            text = L["The red trash at the upper right deletes the selected effect after a permanent-deletion warning. Resolve pending edits first. Choose a replacement for any profile or cooldown using that effect; deletion does not silently rewrite those references."],
        },
        {
            id = "collections",
            title = L["New, Duplicate, Import/Export and Compare"],
            text = L["New, Duplicate, Import/Export and Compare are below the sidebar. Duplicate copies the selected effect into a draft. Transfers show the original name and let you create a renamed copy or replace the selection when allowed. Compare inspects differences without saving them."],
        },
    }
end

-- Lays the Effects help document out in a frame as a yellow title followed by its paragraph, one gap between each.
-- @param frame table  The help frame the text widgets are added to.
function addon.layout_effects_options_help(frame)
    for _, entry in ipairs(addon:GetDocument_layout_effects_options_help()) do
        frame:AddChild(Gap())

        frame:AddChild(CreateText(
            (entry.title ~= '' and color.BLIZ_YELLOW .. entry.title .. color.RESET .. ' - ' or '') .. entry.text
        ))
    end
end
