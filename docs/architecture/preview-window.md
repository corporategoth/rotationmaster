# The preview window's background

The preview window (`UI/preview.lua`) shows one to five recommended icons in a row or a column. The icons cover everything inside the
window, so the only background anyone sees is the border round them. Three settings in General shape it (all per profile):

| Setting | Key | Default | Effect |
| --- | --- | --- | --- |
| Preview window opacity | `preview_opacity` | 1 | Fades the background, never the icons. At 0 nothing is drawn and there is no border. |
| Draw the preview background art | `preview_background` | on | The themed border below. Off: a plain box. |
| Preview window color | `preview_color` (`r g b a`) | slate (0.055, 0.065, 0.075, 1) | The plain box's color, used only when the art is off; its alpha multiplies the opacity. The art sits on the default slate. |

## The art

One theme per class plus a neutral one (`rotation-master`, used for a class the code does not list). The class comes from
`UnitClass('player')` when the window is configured. A theme is two textures in `Assets/Preview/`, both uncompressed 32-bit TGA:

* `<theme>-edge.tga`, 32 x 32: a seamless tile whose **top** is its outer side. It is repeated along each side, one repeat per
  border width, with `REPEAT` wrapping; the bottom side flips it and the left and right sides turn it a quarter, so it holds a
  pattern that runs along its length (no text, no one-sided light) and is opaque.
* `<theme>-ornament.tga`, 64 x 32: the **left cell is a corner** (mirrored across and down for the other three) and the **right cell
  is a stud**, drawn on the border at every joint between two icons, on both long sides. The number of icons therefore shows in the
  border: a single icon has no stud, five have eight. The stud has a transparent background.

The border is a share of the icon size, `clamp(round(size * 0.125), 6, 16)` pixels (8 at the default 64 px, 16 at 128 px and up),
so the art scales with the window; a plain box keeps a four pixel border. The window's size, the icons' anchors and the resize
maths all use the same border (`borderFor` in `UI/preview.lua`). Every theme is named in full in `ART_THEMES`, which is what keeps its
textures in the release package (`Assets/Preview` is one of the folders `tools/package_release.py` reads by bare file name).

The files were made with Codex's image generator from the Rotation Master logo and a written brief, then fixed up by script; the
prompts and the script are recorded in `Assets/Preview/README.md`, the lossless sources are in `Assets/Preview/source/`, and
`Assets/Preview/qa/` holds contact sheets that draw the border the way the window does. To change a theme, replace its two sources and
re-export; `tests/test_preview_art.py` checks the format, that every edge tile repeats without a seam, and that nothing is brighter
than the chrome should be. `tests/preview_art.lua` checks the window: theme by class, border by icon size, tiling and rotation,
studs by icon count in a row and a column, opacity, and the plain box.

## Website

The profile fields `preview_background` and `preview_color` are part of the profile transfer format and the profile comparison
(`UI/collection_compare.lua`); the website's profile reader needs both.
