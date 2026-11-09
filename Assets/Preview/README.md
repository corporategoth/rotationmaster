# Preview borders

Fourteen matching themes provide two textures each. `Assets/Preview/<theme>-edge.tga` and `<theme>-ornament.tga` are uncompressed 32-bit RGBA TGAs; corresponding lossless PNGs live in `source/`. `source/material-reference.png` is the darkened generated source material, and `build.py` reproduces the textures and the two QA sheets. `qa/contact.png` assembles each theme over dark and light backgrounds; `qa/detail.png` contains four-times nearest-neighbor crops.

The prefixes are `rotation-master`, `warrior`, `paladin`, `hunter`, `rogue`, `priest`, `deathknight`, `shaman`, `mage`, `warlock`, `monk`, `druid`, `demonhunter`, and `evoker`.

## Geometry

The opaque edge texture is 32 × 32, with outer side at top and identical left and right columns. The 64 × 32 transparent ornament sheet holds the top-left corner in its left cell and a centered joint stud in its right cell. For icon size `s`, the border thickness is `e = clamp(round(s * 0.125), 6, 16)` pixels. Draw edge cells at `e × e`, repeating along each side; flip the top edge vertically for the bottom and rotate it 90 degrees for the side bands. Mirror the top-left corner horizontally and/or vertically for the other corners. Center a stud on each boundary between icons, on both long sides; flip for the bottom and rotate for the column sides. The QA assembler applies these operations at native display size.

## Themes

| Theme | Material and accent |
| --- | --- |
| rotation-master | Gunmetal and slate; aged gold and blue, violet, orange gems |
| warrior | Blackened steel and worn red leather; crimson |
| paladin | White-gray marble and brass; warm white-gold |
| hunter | Dark-green leather and horn; hunter green |
| rogue | Black leather and brass; dull poison green |
| priest | Ivory and pale gold; violet |
| deathknight | Runed iron; frost blue |
| shaman | Weathered wood and stone; teal and blue |
| mage | Indigo stone and silver; violet blue |
| warlock | Charcoal bone and thorn; fel green and purple |
| monk | Jade and lacquered wood; soft jade |
| druid | Dark bark and vines; moon gold and living green |
| demonhunter | Black spiked iron; fel green and magenta-purple |
| evoker | Bronze, teal scales and obsidian; ember gold |

## Provenance

The built-in image generator was given the attached Rotation Master logo as a reference and the following exact prompt:

> Use case: stylized-concept. Asset type: fantasy game UI border material source. Create one straight horizontal repeatable strip of dark gunmetal with aged gold bevel, slate inset, fine carved intertwined metal filigree and restrained rivets, viewed directly from above, occupying entire canvas. Reference the attached Rotation Master emblem for material character and restrained blue, violet, and orange hints. It should be quiet and dark, no glow, no text, no faces, consistent neutral lighting, handcrafted WoW-inspired detail. Straight parallel edges, horizontally repeating motif.

The generated source was darkened to 60% brightness and saved as `source/material-reference.png`. `build.py` crops a section of the material, converts it to luminance, mirrors it horizontally and maps it into each theme's dark palette. It draws shared bevels and interlaced bands, theme-colored inlays and distinct stud glyphs at 4× resolution, then downsamples; it enforces identical first and last tile columns. Corners and studs are drawn on transparent sheets. Pillow writes PNG and uncompressed TGA from identical RGBA pixels. The script also constructs the QA layouts and magnified crops from those same textures.
