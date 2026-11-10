# Shaman preview artwork

Run `python Assets/Preview/build.py` with Pillow installed. The build reads the saved generator outputs, crops without stretching, applies a uniform 0.65 exposure multiplier, resamples each complete master with Lanczos, slices it, draws the atlas, and assembles both QA sheets. It does not call the generator.

## Files and geometry

- `shaman-w1.tga` through `shaman-w5.tga`: row cells, left to right.
- `shaman-t1.tga` through `shaman-t5.tga`: column cells, top to bottom.
- Corresponding lossless PNGs are in `source/`. Every cell is 256 × 256, opaque RGBA; TGAs are uncompressed 32-bit.
- `source/generated/shaman-w-master.png` is the 2110 × 422 native-pixel row crop, and `shaman-t-master.png` is the 360 × 1800 native-pixel column crop. Both contain the exposure adjustment. Original generated images and intermediate attempts are retained alongside them. The final row crop is (0, 70, 2110, 492); the column crop is (215, 0, 575, 1800), in Pillow's exclusive-right/bottom coordinates. Both are exact 5:1 or 1:5 without stretching. The whole master is resampled before slicing to preserve continuous joins.
- `shaman-border.tga` and `source/shaman-border.png`: 256 × 64 RGBA atlas, transparent outside artwork. y=0–15 dim rail; y=16–31 lit rail; y=32–47: corner x=0–15, dim stud x=16–31, lit stud x=32–47; y=48–63 transparent. Rail ends match. The border is drawn by the build script as carved wood, dark outline, and turquoise/ember inlay.
- `qa/shaman.png`: 64-pixel cells with 6-pixel border, at 3× nearest-neighbour zoom. It shows all empty row prefixes, two and five active icons, and three- and five-cell columns. The icons are actual PNGs from `Assets/Conditions/source/`. Rails are lit per active slot; joint studs light only when both adjoining slots are active. Corners are mirrored.
- `qa/shaman-full.png`: both masters at native crop resolution and a 2× nearest-neighbour enlargement of the fifth row cell.

| Cell | Chapter |
| --- | --- |
| 1 | Dusk totem circle and first fire |
| 2 | Wind and feathers over the red mesa |
| 3 | Lightning storm over the mesa |
| 4 | Teal river canyon and water spirits |
| 5 | Four lit earth, fire, water and wind totems beneath stars |

Each orientation is one generated image, cropped as a whole and sliced. Cell boundaries retain the original continuous scene. Some prefix endings cut through landscape rather than resolving into a discrete foreground object; the column's transitions are more like stacked vistas than a single uninterrupted terrain. The count motifs are not consistently legible, and the outer wind figure in the row is close to the edge.

## Provenance

Built-in imagegen was used with the earlier `qa/shaman-full.png` as a mood reference. Initial row prompt:

> Use case: illustration-story. Create a richly detailed, dark muted fantasy game background painting as one continuous panoramic landscape, composed for cropping the central horizontal 5:1 strip. Across that strip, left to right in five equal chapters: dusk carved wood and feather totem circle with first fire; wind and feathers over red mesa; lightning storm over mesa; teal river canyon with water spirits; finally FOUR clearly separated large lit totems representing earth, fire, water and wind together under stars. Keep the four totems entirely within the rightmost fifth of the strip. Natural rock, tree or cliff transitions at each fifth, continuous across boundaries. Full sharp painted detail throughout, no fog boxes, blur, blank centers, frames, lettering or UI. Shaman spirit walk, carved wood and stone, turquoise inlay, muted ember, storm grey, dusk to night. Dark subdued lighting. High detail. Reference the supplied shaman painting for mood, not its blurry centers.

Initial column prompt:

> Use case: illustration-story. Create a richly detailed dark muted fantasy game background painting, a single continuous vertical landscape composed for cropping the central vertical 1:5 strip. Across that strip, top to bottom in five equal chapters: dusk carved wood and feather totem circle with first fire; wind and feathers over red mesa; lightning storm over mesa; teal river canyon with water spirits; finally FOUR clearly separated large lit totems representing earth, fire, water and wind together under stars. Keep all four totems entirely within the bottom fifth of the strip. Natural rock, tree or cliff transitions at each fifth, continuous across boundaries. Full sharp painted detail throughout, no fog boxes, blur, blank centers, frames, lettering or UI. Shaman spirit walk, carved wood and stone, turquoise inlay, muted ember, storm grey, dusk to night. Dark subdued lighting. High detail. Reference the supplied shaman painting for mood, not its blurry centers.

Column retry prompt:

> Create a single continuous vertical fantasy game painting. CRITICAL COMPOSITION: the finished image will be cropped to only the CENTRAL 40% OF THE IMAGE WIDTH, full height. Put ALL important subjects in that central narrow strip and use the sides only as expendable landscape. Within the central strip arrange five equal stacked chapters, top to bottom: carved wood and feather totem circle at dusk with fire; wind and feathers over red mesa; mesa lightning storm; turquoise water spirits in a canyon; then FOUR distinct large, clearly separated slender elemental totems standing SIDE BY SIDE together in the narrow central strip, earth, fire, water and wind, under starry sky. All four totems must be fully visible inside the central 40% width. Continuous scenery flowing across chapter boundaries. No panel dividers, no fog boxes, no blurred centers, no text. Rich, sharp detailed painted wood and stone, teal, muted orange, storm grey. Dark, subdued, shaman spirit walk.

Column final edit, using the retry as input:

> Edit this vertical painting. Preserve the continuous landscape and mood. At the bottom, arrange FOUR distinct slender elemental totems (earth fire water wind) in a very tight group, all four complete totems, heads and bases, fitting inside the CENTER 35% of the image width and BOTTOM 20% of image height, with visible margin on both sides. All four in one row and clearly separated. Maintain stars behind them. Other chapters remain continuous and full detail. No text or panel lines.

Row edits, each using the previous result as input:

> Edit this panorama. Preserve the existing landscape and mood. Place the entire group of FOUR elemental totems closer together and shift it right, so all four complete totems fit inside the RIGHTMOST 18% of the image, with visible space at both sides of the group. Four clear separate figures, earth fire water wind, under stars, their heads and bases inside the central horizontal 60% of image height. Keep the rest of the landscape continuous and detailed. No text, no panel lines.

> Edit this wide panorama. On its far right, make the group of four elemental totems significantly smaller and much more tightly clustered; shift the entire group to the RIGHT. The complete group including the earth figure must fit within the rightmost 15 percent of the whole image, with room at the right edge. Four separate totems earth fire water wind. Preserve the rest of the image and its landscape. No text.

> Edit only the four tiny totems at the far right: make each of the four elemental totems twice as tall and the group twice as wide, while keeping all four complete figures entirely inside the rightmost fifth of the image, with margins. They are the focal point of that fifth. Earth fire water wind, clearly separated. Preserve rest of continuous landscape and stars.

## Warrior: a soldier's march

| Cell | Story |
| --- | --- |
| 1 | Night forge and armory: black plate, weapons and an anvil. |
| 2 | Training yard: straw dummies, weapon racks and red banners. |
| 3 | Mountain gate: stone and rising portcullis. |
| 4 | Battlefield: a marching army, siege towers, banners and smoke. |
| 5 | Dawn: four war standards, crossed axes and a planted sword. |

Generated with the built-in image generation tool. The selected native outputs are `warrior-row-final.png` and `warrior-column-final.png`; earlier attempts are retained alongside them. Exact prompts, in generation order:

> Use case: illustration-story. Asset: continuous horizontal game background painting, extremely wide narrative composition, intended to crop central horizontal fifth of image into a 5:1 strip. Fill that central strip edge to edge with five adjacent detailed square chapters left to right, no panels: (1) night forge, black plate and weapons, sword on anvil; (2) training yard, straw dummies, weapon racks, red battle banners; (3) mountain gate, rising portcullis, torch-lit stone; (4) dusk battlefield, banners, siege towers, smoke; (5) dawn payoff, four distinct great war standards in a row, crossed axes and sword planted at their base. Natural architectural or rock endings at each chapter boundary, seamless continuous scene. Rich detailed WoW-inspired class-hall loading screen painting, blackened riveted steel, worn red leather, ember orange, stone. Dark muted low contrast, no bloom, full sharp detail even in centers, no text or famous faces. Put all important content within central horizontal 20% of image, no borders.

> Use case: illustration-story. Asset: continuous vertical game background painting, extremely tall narrative composition, intended to crop central vertical fifth of image into a 1:5 strip. Fill that central strip edge to edge with five adjacent upright detailed square chapters top to bottom, no panels: (1) night forge, black plate and weapons, sword on anvil; (2) training yard, straw dummies, weapon racks, red battle banners; (3) mountain gate, rising portcullis, torch-lit stone; (4) dusk battlefield, banners, siege towers, smoke; (5) dawn payoff, four distinct great war standards in a row, crossed axes and sword planted at their base. Natural architectural or rock endings at each chapter boundary, seamless continuous scene. Rich detailed WoW-inspired class-hall loading screen painting, blackened riveted steel, worn red leather, ember orange, stone. Dark muted low contrast, no bloom, full sharp detail even in centers, no text or famous faces. Put all important content within central vertical 20% of image, no borders.

> Use case: illustration-story. Paint a single seamless, wide cinematic World of Warcraft inspired warrior class-hall loading-screen landscape, filling the entire image without bands, panels, borders or separate strips. Across the width tell a soldier's march in five successive, distinct spatial locations smoothly blending into each other: far left a night forge and armory with blackened plate racks and a sword on an anvil; left-center a training yard with straw dummies, weapon racks and red battle banners; center a mountain gate with rising portcullis and torchlit masonry; right-center a dusk battlefield with siege towers, banners and smoke; far right the dawn payoff of four great war standards raised in a row, crossed axes and a sword planted at their bases. Fit all significant story elements in the middle half of the image vertically so an extremely wide crop retains them. Natural pillars and rocks resolve each scene, dense sharp painted detail throughout, no blurred or empty centers. Black iron, stone, worn red leather, muted ember light. Quiet dark low contrast, no glow or bloom, no text or recognizable faces.

> Use case: illustration-story. Paint a seamless, tall upright World of Warcraft inspired warrior class-hall loading-screen landscape, filling the entire canvas. The central vertical 40% must contain the COMPLETE important elements, because both sides will be cropped away. Tell a soldier's march top to bottom in five square-height chapters, each flows into the next: (1) night forge and armory with black plate racks and sword on anvil; (2) training yard with straw dummies and red battle banners; (3) mountain gate with a rising portcullis and torchlit stone; (4) dusk battlefield with banners, siege towers and smoke; (5) dawn payoff: FOUR closely grouped, fully visible great war standards in a row, crossed axes and a sword planted at their bases, ALL FOUR fitting in the central 40% width. Concentrate story within central 40%, with no important objects clipped there. Natural rocks and masonry at chapter boundaries. Detailed painting throughout with no blank areas, blackened riveted iron, worn red leather, stone, subdued ember light. Dark muted low contrast, no glow or bloom, no text, no familiar faces.

> Create one continuous upright vertical game painting for a VERY NARROW crop: compose all key objects strictly within the central 20% of the canvas width, leave both sides as expendable environment. It tells a warrior's march top to bottom: forge and armor with sword on anvil; training yard with dummies and red banners; stone gate with raised portcullis; battlefield with siege towers; final dawn scene: four SMALL closely spaced COMPLETE war standards in a single compact row occupying only the middle 20% width, with crossed axes and sword beneath them. Paint this as detailed Warcraft-inspired loading screen art, rich black iron, dark red leather, stone, muted ember light. Full detail across every region, each part joined by natural masonry and rock, dark low contrast, no text, no glow or bloom.

Scripted edits: crop the 2172×724 row output to `(1, 80, 2171, 514)` and the 724×2172 column output to `(145, 0, 579, 2170)`; multiply RGB by 0.70 with rounding for subdued exposure. Save the resulting 2170×434 and 434×2170 native-pixel masters. Split each into five 434×434 squares and downscale each with Lanczos to 256×256 RGBA; export matching opaque PNG and uncompressed 32-bit TGA. Draw the iron, enamel, bracket and gem atlas with Pillow, with constant rail profiles across their length, and export matching PNG and TGA. The QA assembler places cells and real condition icons in 64-pixel slots, overlays 6-pixel rails and mirrored corners, and places studs at slot boundaries; it shows lit rails for active slots and lit studs only when both adjoining slots are active. It scales each assembled window 2× with Lanczos. The full sheet shows both cropped masters at native size.
