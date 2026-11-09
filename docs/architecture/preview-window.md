# The preview window's background

The preview window (`UI/preview.lua`) shows one to five recommended icons in a row or a column. When there are fewer recommendations than
slots, the empty slots show the window's background. Three settings in General shape it (all per profile):

| Setting | Key | Default | Effect |
| --- | --- | --- | --- |
| Preview window opacity | `preview_opacity` | 1 | Fades the background, never the icons. At 0 nothing is drawn and there is no padding. |
| Draw the preview background art | `preview_background` | on | The class painting below. Off: a plain box. |
| Preview window color | `preview_color` (`r g b a`) | slate (0.055, 0.065, 0.075, 1) | The plain box's color, used only when the art is off; its alpha multiplies the opacity. The painting sits on the default slate. |

## The painting

One painting per class plus a neutral one (`rotation-master`, used for a class the code does not list). The class comes from
`UnitClass('player')` when the window is configured. Each is a short story told across five chapters, one per slot: a continuous
scene that flows through the cell boundaries, every cell a different moment, never one tile repeated. A theme is two uncompressed,
opaque 32-bit TGA files in `Assets/Preview/`:

* `<theme>-wide.tga`, 512 x 128, for a row: **five square cells of 96 x 96 texels side by side** (x 0 to 479; the last 32 texels are
  spare).
* `<theme>-tall.tga`, 128 x 512, for a column: the same story with the five cells stacked (y 0 to 479), composed for a column rather
  than turned.

The painting fills the whole window (it is a background, not a frame), behind the icons, at the window opacity. A window of `n` slots
shows the first `n` cells and stretches them over the window (texture coordinates `0..n*96/512` along the window's long direction),
so the picture follows how many icons the window holds, and every prefix of one to five cells is a finished scene. The window keeps
its four pixel padding with the art on or off, so switching it never moves an icon. Every texture is named in full in `ART_THEMES`,
which is what keeps it in the release package (`Assets/Preview` is one of the folders `tools/package_release.py` reads by bare file
name).

The paintings were made with Codex's image generator from the Rotation Master logo and a written brief, then fixed up by script; the
prompts, the story of each class and the script are recorded in `Assets/Preview/README.md`, the lossless sources are in
`Assets/Preview/source/`, and `Assets/Preview/qa/` holds contact sheets that draw the window the way the game does.
`tests/test_preview_art.py` checks the format, that the classes are different pictures, that nothing is brighter than the chrome
should be and that the cells join without a seam; `tests/preview_art.lua` checks the window: theme by class and direction, the crop
by slot count, unchanged geometry, opacity and the plain box.

## Website

The profile fields `preview_background` and `preview_color` are part of the profile transfer format and the profile comparison
(`UI/collection_compare.lua`); the website's profile reader needs both.
