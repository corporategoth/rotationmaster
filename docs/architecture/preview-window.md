# The preview window's background

The preview window (`UI/preview.lua`) shows one to five recommended icons in a row or a column. When there are fewer recommendations than
slots, the empty slots show the window's background. Three settings on the Preview tab shape it (all per profile):

| Setting | Key | Default | Effect |
| --- | --- | --- | --- |
| Preview window opacity | `preview_opacity` | 1 | Fades the background, never the icons. At 0 nothing is drawn and there is no padding. |
| Preview background | `preview_art` | `class` | `class` (the player's class, or the neutral painting for a class without one), a class token, `ROTATION_MASTER` for the neutral painting, or `solid` for a plain box. The old `preview_background` switch, when off, is a plain box whatever is chosen; the page sets it to match every choice, so a profile saved before the choice existed with the switch off shows `solid` until a painting is picked. |
| Preview window color | `preview_color` (`r g b a`) | slate (0.055, 0.065, 0.075, 1) | The plain box's color, used only for `solid` (and chosen on the page in place of the painting preview); its alpha multiplies the opacity. A painting sits on the default slate. |

## Choosing it (Preview tab)

The Appearance section of the Preview tab holds the look: the Preview background list ("My class (X)", the thirteen classes, Rotation
Master and Solid background), the chosen painting as a row of its five cells in the middle of the page (for Solid background the
color chooser takes its place), the opacity, the title, the target health bar, the lock, direction and position reset. The preview
options (spells, Masque skin, the preview's own readiness) and the forecast are in two columns under it
(`p:Column` starts the columns below the content above them).

## The painting

One painting per class (all thirteen), plus a neutral Rotation Master one that any class without its own gets (`ART_NEUTRAL`). The
class comes from `UnitClass('player')` when the window is configured. Each painting is a short story told across five chapters, one per slot: one continuous scene cut into
**five square cells of 256 x 256 texels**, each cell its own opaque 32-bit TGA in `Assets/Preview/`, so the scene flows through every
boundary and every cell is a different moment. A row uses `<theme>-w1` to `w5`, a column `<theme>-t1` to `t5` (the same story,
composed for a column). Each slot's cell is drawn over its slot, at the window opacity; the first and last cells run out under the padding at the ends of the window (a horizontal stretch of a tenth), so no bar of the box shows beside the painting; a window of `n` slots shows the first
`n` chapters, so the picture follows how many icons the window holds, and every prefix of one to five cells is a finished scene.

## The border

One sheet per theme, `<theme>-border.tga` (256 x 64, transparent outside the artwork, rows of 16 texels): a **dim rail** (row 1) and a
**lit rail** (row 2), a **corner** and a **dim and a lit stud** (row 3). The border is a tenth of the icon size, `clamp(round(size *
0.1), 5, 12)` pixels (6 at the default 64 px), and is the window's padding (a plain box keeps four). It shows how many slots hold an
icon (`window.count`, or the sample icons): every slot has a rail along both long sides, **lit for the slots that hold an icon and dim
for the rest**; the four corners are mirrored copies of one; and a stud sits at every joint between two slots on both long sides,
**lit when both its neighbors hold an icon**. The rail's outer side is the top of its row, which the second side flips and a column
turns a quarter. `ResumeLayout` redraws it after every poll's recommendations.

## Files and checks

Every texture is named in full in `ART_THEMES`, which is what keeps it in the release package (`Assets/Preview` is one of the folders
`tools/package_release.py` reads by bare file name). The paintings were made with Codex's image generator from the Rotation Master logo
and a written brief, then cut by script from full-resolution masters; the prompts, the story of each class and the script are recorded
in `Assets/Preview/README.md`, the lossless sources are in `Assets/Preview/source/`, and `Assets/Preview/qa/` holds contact sheets that
draw the window the way the game does. `tests/test_preview_art.py` checks the format, that nothing is brighter than the chrome should be,
that the cells of a story join without a seam and that no cell has a blurred patch in the middle; `tests/preview_art.lua` checks the
window: theme by class and direction, a cell over each slot, the border size, the lit and dim states, opacity and the plain box.

## Website

The profile fields `preview_art`, `preview_background` (legacy) and `preview_color` are part of the profile transfer format and the profile comparison
(`UI/collection_compare.lua`); the website's profile reader needs both.
