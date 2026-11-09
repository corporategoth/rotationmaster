# Shaman preview background

These are paintings behind the recommendation icons, not frames. Only the Shaman example is included.

## Files

- `shaman-wide.tga`, `shaman-tall.tga`: uncompressed, opaque 32-bit RGBA game textures.
- `source/shaman-wide.png`, `source/shaman-tall.png`: lossless pixel-identical sources.
- `source/generated/shaman-wide.png`, `source/generated/shaman-tall.png`: large selected imagegen originals. `source/generated/shaman-tall-first.png` records the rejected initial vertical composition.
- `qa/shaman.png`: 3× game-style prefix crops, icon overlay, and column previews.
- `qa/shaman-full.png`: the five-cell horizontal and vertical crops at 3×.
- `build.py`: rebuilds textures and sheets with Pillow; run `python Assets/Preview/build.py` from the repository root.

## Geometry

The wide texture is 512 × 128: five 96 × 96 cells occupy x=0–479 and the remaining 32 texels continue the picture. For n slots crop x=0 to 96n, with the entire 128-texel height, then stretch to the window. The tall texture is 128 × 512: five 96 × 96 cells occupy y=0–479, with 32 spare texels below; crop y=0 to 96n with the entire 128-texel width. The QA renderer stretches each crop to n × 64 pixels plus a total 4-pixel margin on each window dimension; icons occupy 64 × 64 pixels starting at (2,2). Both textures are opaque.

## Story

1. Carved wood, feathers and a small fire mark the dusk totem circle.
2. Feathers travel in the wind across the red mesa.
3. Storm clouds and lightning gather over the canyon.
4. Teal water spirits move through the river canyon.
5. Elemental totems answer beneath the stars.

The source images are composed independently for their orientations. The optional count marks are not consistently represented, and the small-size vertical crop compresses detail and the final group of totems.

## Provenance

Generated with the built-in imagegen tool. Exact horizontal prompt:

> Use case: illustration-story. Create a horizontal, very wide continuous painted fantasy game background, a Shaman spirit-walk across five successive distinct chapters from left to right. One coherent panoramic landscape: (1) carved wooden totem circle and feathers, first small fire at dusk; (2) wind carries feathers across a red mesa; (3) storm clouds and restrained lightning over mesa; (4) water spirits in a river canyon with muted teal; (5) earth, fire, water and wind totems under night stars. Same landscape flows across every transition, each chapter resolves naturally at its right edge. Calm open area at the center of each of five equal sections for overlaying spell icons. Bold readable forms and fine carved wood, stone and feather detail. Rich atmospheric World of Warcraft class-hall/loading screen painting. Dark, muted candlelit tapestry: storm grey, teal, weathered wood, faint ember orange. No bright light, no bloom, no text, no faces, no frames, no borders, no panels, no repeating motifs. Edge-to-edge illustration.

Exact selected vertical prompt:

> Use case: illustration-story. An upright vertical fantasy Shaman spirit-walk painting for a game UI, continuous flowing landscape, absolutely no panels or horizontal dividers. Follow one winding river and path descending through ONE continuous canyon, with consistent atmospheric perspective and overlapping cliffs linking all heights of the image. Five successive moments flowing smoothly down the image: near the top a dusk totem circle and small fire with carved wood and feathers; then wind blowing feathers over red mesas; then storm clouds and distant lightning; then water spirits in a teal river; finally four elemental totems below under a starry night. Each region distinct but the same land and river connect all of them without seams or abrupt changes. Natural soft mist at transition points. Quiet center areas for spell icon overlay. Atmospheric detailed World of Warcraft class-hall painting, dark muted candlelit tapestry, storm grey, weathered wood, teal and subdued ember orange. No bright light, bloom, text, faces, borders, frames, repeated emblems or grid.

Exact rejected initial vertical prompt:

> Use case: illustration-story. Create a vertical portrait continuous painted fantasy game background, upright composition flowing DOWN through five successive distinct chapters. A Shaman spirit-walk: (1) carved wooden totem circle and feathers, first small fire at dusk; (2) wind carries feathers across a red mesa; (3) storm clouds and restrained lightning over mesa; (4) water spirits in a river canyon with muted teal; (5) earth, fire, water and wind totems under night stars. Same continuous landscape and atmosphere through transitions; each chapter resolves naturally at its lower edge. Calm open area at the center of each of five equal sections for overlaying spell icons. Bold readable forms and fine carved wood, stone and feather detail. Rich atmospheric World of Warcraft class-hall/loading screen painting. Dark muted candlelit tapestry: storm grey, teal, weathered wood, faint ember orange. No bright light, no bloom, no text, no faces, no frames, no borders, no panels, no repeating motifs. Edge-to-edge illustration.

Scripted edits: convert selected originals to RGB, resize to the required full texture dimensions using Lanczos, multiply each color channel by 0.58, add opaque alpha, and save PNG and uncompressed TGA. The QA sheet crops and stretches those exact pixels, with `Assets/Conditions/source/spell.png` and `totem.png` as icon stand-ins.
