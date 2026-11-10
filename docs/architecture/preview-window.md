# The preview window's background

The preview window (`UI/preview.lua`) shows one to five recommended icons in a row or a column. When there are fewer recommendations than
slots, the empty slots show the window's background. Three settings in General shape it (all per profile):

| Setting | Key | Default | Effect |
| --- | --- | --- | --- |
| Preview window opacity | `preview_opacity` | 1 | Fades the background, never the icons. At 0 nothing is drawn and there is no padding. |
| Draw the preview background art | `preview_background` | on | The class painting and border below. Off: a plain box. |
| Preview window color | `preview_color` (`r g b a`) | slate (0.055, 0.065, 0.075, 1) | The plain box's color, used only when the art is off; its alpha multiplies the opacity. The art sits on the default slate. |

## The painting

One painting per class (all thirteen), plus a neutral Rotation Master one that any class without its own gets (`ART_NEUTRAL`). The
class comes from `UnitClass('player')` when the window is configured. Each painting is a short story told across five chapters, one per slot: one continuous scene cut into
**five square cells of 256 x 256 texels**, each cell its own opaque 32-bit TGA in `Assets/Preview/`, so the scene flows through every
boundary and every cell is a different moment. A row uses `<theme>-w1` to `w5`, a column `<theme>-t1` to `t5` (the same story,
composed for a column). Each slot's cell is drawn over exactly that slot, at the window opacity; a window of `n` slots shows the first
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

The profile fields `preview_background` and `preview_color` are part of the profile transfer format and the profile comparison
(`UI/collection_compare.lua`); the website's profile reader needs both.
