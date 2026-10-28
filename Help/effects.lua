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

-- Whole paragraphs preserve translation word order and retain distinct units
-- for library glow rates versus RM texture/sequence timer intervals.
-- Returns the Effects page help sections { id, title, text }.
function addon:GetDocument_layout_effects_options_help()
    return {
        { id = "overview", title = L["Effects"], text = L["Help.Effects.overview"] },
        { id = "name", title = L["Name"], text = L["Help.Effects.name"] },
        { id = "type", title = L["Type"], text = L["Help.Effects.type"] },
        { id = "type.texture", title = L["Texture"], text = L["Help.Effects.type.texture"] },
        { id = "type.pixel", title = L["Pixel"], text = L["Help.Effects.type.pixel"] },
        { id = "type.autocast", title = L["Auto Cast"], text = L["Help.Effects.type.autocast"] },
        { id = "type.blizzard", title = L["Glow"], text = L["Help.Effects.type.blizzard"] },
        { id = "type.proc", title = L["Proc Glow"], text = L["Help.Effects.type.proc"] },
        { id = "type.dazzle", title = L["Dazzle"], text = L["Help.Effects.type.dazzle"] },
        { id = "type.animate", title = L["Animate"], text = L["Help.Effects.type.animate"] },
        { id = "type.pulse", title = L["Pulse"], text = L["Help.Effects.type.pulse"] },
        { id = "type.rotate", title = L["Rotate"], text = L["Help.Effects.type.rotate"] },
        { id = "type.custom", title = L["Custom"], text = L["Help.Effects.type.custom"] },
        { id = "preview", title = L["Preview"], text = L["Help.Effects.preview"] },
        { id = "texture", title = L["Texture"], text = L["Help.Effects.texture"] },
        { id = "pixel.lines", title = L["Lines"], text = L["Help.Effects.pixel.lines"] },
        { id = "pixel.frequency", title = L["Frequency"], text = L["Help.Effects.pixel.frequency"] },
        { id = "pixel.length", title = L["Length"], text = L["Help.Effects.pixel.length"] },
        { id = "pixel.thickness", title = L["Thickness"], text = L["Help.Effects.pixel.thickness"] },
        { id = "autocast.particles", title = L["Particles"], text = L["Help.Effects.autocast.particles"] },
        { id = "autocast.frequency", title = L["Frequency"], text = L["Help.Effects.autocast.frequency"] },
        { id = "autocast.scale", title = L["Scale"], text = L["Help.Effects.autocast.scale"] },
        { id = "blizzard.frequency", title = L["Frequency"], text = L["Help.Effects.blizzard.frequency"] },
        { id = "proc.duration", title = L["Loop duration"], text = L["Help.Effects.proc.duration"] },
        { id = "proc.startAnim", title = L["Start burst"], text = L["Help.Effects.proc.startAnim"] },
        { id = "dazzle.frequency", title = L["Frequency"], text = L["Help.Effects.dazzle.frequency"] },
        { id = "animate.frequency", title = L["Frequency"], text = L["Help.Effects.animate.frequency"] },
        { id = "pulse.frequency", title = L["Frequency"], text = L["Help.Effects.pulse.frequency"] },
        { id = "rotate.frequency", title = L["Frequency"], text = L["Help.Effects.rotate.frequency"] },
        { id = "rotate.steps", title = L["Steps"], text = L["Help.Effects.rotate.steps"] },
        { id = "rotate.reverse", title = L["Reverse"], text = L["Help.Effects.rotate.reverse"] },
        { id = "custom.frequency", title = L["Frequency"], text = L["Help.Effects.custom.frequency"] },
        { id = "sequence", title = L["Sequence"], text = L["Help.Effects.sequence"] },
        { id = "sequence.texture", title = L["Texture"], text = L["Help.Effects.sequence.texture"] },
        { id = "sequence.angle", title = L["Angle"], text = L["Help.Effects.sequence.angle"] },
        { id = "sequence.magnification", title = L["Magnification"], text = L["Help.Effects.sequence.magnification"] },
        { id = "sequence.color", title = L["Color"], text = L["Help.Effects.sequence.color"] },
        { id = "save", title = L["Apply / Cancel"], text = L["Help.Effects.save"] },
        { id = "delete", title = L["Delete"], text = L["Help.Effects.delete"] },
        {
            id = "collections",
            title = L["New, Duplicate, Import/Export and Compare"],
            text = L["Help.Effects.collections"],
        },
    }
end

-- Lays the Effects help document out in a frame as a yellow title followed by its paragraph, one gap between each.
function addon.layout_effects_options_help(frame)
    for _, entry in ipairs(addon:GetDocument_layout_effects_options_help()) do
        frame:AddChild(Gap())

        frame:AddChild(CreateText(
            (entry.title ~= '' and color.BLIZ_YELLOW .. entry.title .. color.RESET .. ' - ' or '') .. entry.text
        ))
    end
end
