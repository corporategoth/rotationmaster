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

## Mage: a spell taking shape

| Cell | Story |
| --- | --- |
| 1 | Moonlit tower library, floating tome, lectern and candles. |
| 2 | Observatory, armillary spheres and star charts. |
| 3 | Arcane circle kindling on a carved stone floor. |
| 4 | Portal archway overlooking a moonlit lake. |
| 5 | Fire, frost, arcane and nature sigils over the tower under stars. |

Generated using the built-in image generation tool. Exact prompts, in generation order:

> Use case: illustration-story. Create a single continuous richly detailed World of Warcraft inspired Mage class-hall loading-screen painting across a wide landscape. Its central horizontal strip will be cropped to a 5:1 panorama. Inside that strip tell five consecutive scenes left to right, each in one fifth of the width: moonlit tower library with a floating tome over lectern and candles; observatory with armillary spheres and star charts; arcane circle igniting on carved stone floor; portal archway over a moonlit lake; final payoff FOUR clearly distinct small fire, frost, arcane, and nature spell sigils hovering in a compact constellation over a tower under stars, entirely inside the rightmost fifth. Architectural pillars, walls, and stone features provide natural endings near each fifth, but scenery flows seamlessly. Put all important objects inside the central strip. Rich sharp edge-to-edge detail, deep indigo stone, arcane violet, silver filigree, faint embers. Dark muted low contrast, no bloom, no fog, no blur, no empty centers, no text, no familiar faces, no panels.

> Use case: illustration-story. Create a single continuous upright tall World of Warcraft inspired Mage class-hall loading-screen painting. The central narrow vertical strip will be cropped to a 1:5 panorama; keep ALL important objects inside the central 35% width. Tell five consecutive square chapters from top to bottom: moonlit tower library with floating tome over lectern and candles; observatory with armillary spheres and star charts; arcane circle igniting on carved stone floor; portal archway over a moonlit lake; final payoff FOUR distinct small fire, frost, arcane, and nature spell sigils hovering together in a compact constellation over a tower under stars, all entirely inside the bottom fifth and central 35% width. Architectural stone and pillars give natural endings at each chapter, continuous scenery, not panels. Rich sharp detail throughout, deep indigo stone, arcane violet and silver filigree, faint embers, moonlight. Dark muted low contrast, no bloom, no fog, no blur, no blank centers, no text, no familiar faces.

The row was edited once, using its original output as input:

> Edit this wide Mage painting. Preserve the existing five connected scenes, detailed painted style and dark indigo architecture. Recompose vertically for a very wide 5:1 crop: all five story subjects must be fully visible inside the CENTRAL 55% of image height, especially the entire group of FOUR distinct fire, frost, arcane, and nature sigils together above the tower in the rightmost fifth, the floating book and lectern, armillary sphere, floor circle and lake portal. Move the sigils and their tower lower as necessary so no part of the sigils is near the top edge of the central strip. Keep each scene continuous and detailed, quiet muted illumination, no bloom, no text, no panels.

Scripted edits: crop the 2172 × 724 edited row output to `(0, 143, 2170, 577)` and the 724 × 2172 column output to `(145, 0, 579, 2170)`, in exclusive-right/bottom coordinates; multiply RGB by 0.65 with rounding. These 2170 × 434 and 434 × 2170 crops are the saved native-pixel masters. Slice each into five 434 × 434 squares and downscale each with Lanczos to 256 × 256; export opaque RGBA PNGs and uncompressed 32-bit TGAs. Draw the indigo stone, silver rail, violet inlay, star corner and gem stud atlas with Pillow, using a constant rail profile and transparent unused atlas space. Assemble the QA windows at 64 pixels per slot with 6-pixel rails, reflected corners and studs at slot boundaries, using real condition PNGs; light each active slot's rail and a stud only when both neighboring slots are active. Enlarge the assembled windows 2× with Lanczos. The full sheet displays the two masters at native crop size. The original outputs, edited row output and masters are retained in `source/generated/`.

The architecture supports the sequence and the four sigils are distinct, but some prefix endings cut through architectural details instead of resolving at a complete wall, and the vertical version reads as stacked architectural levels more than a single perspective. The generated arcane effects retain visible painted halos even after the subdued exposure adjustment.

## Rogue: a night heist

| Cell | Story |
| --- | --- |
| 1 | Rain-soaked alley and a single lit window. |
| 2 | Rooftops, chimneys and grappling rope. |
| 3 | Ornate vault and lockpicks. |
| 4 | Moonlit balcony overlooking a guard and lantern. |
| 5 | Open empty chest, dagger, smoking lanterns and an escape across rooftops at first light. |

Created with the built-in image generation tool. Exact initial row prompt:

> Use case: illustration-story. Create one continuous wide World of Warcraft inspired Rogue class-hall loading-screen painting, rich sharp detail across the entire canvas. Compose the central horizontal band for a 5:1 crop: five consecutive square chapters left to right, smoothly connected by architecture: (1) rain-soaked alley with a single lit window; (2) rooftops, chimneys and grappling rope; (3) ornate vault door with lockpicks glinting; (4) moonlit balcony with a guard's lantern far below; (5) payoff: opened EMPTY chest, dagger stuck in a beam, escape route over rooftops at first light, four smoking lanterns left behind. Place each whole key object within its respective fifth and central band. Natural walls and pillars resolve chapter boundaries, yet continuous scene, no panels. Rogue heist, black leather, brass studs and chain, deep blue night, wet cobbles, dull poison green and warm window light. Dark subdued soft contrast, no bloom, no blurred patches or blank centers, no text, no recognizable faces.

Exact initial column prompt:

> Use case: illustration-story. Create one continuous upright tall World of Warcraft inspired Rogue class-hall loading-screen painting, rich sharp detail throughout. Compose all key subjects within the CENTRAL 20% of image width for a very narrow 1:5 crop. Five consecutive square chapters top to bottom smoothly connected by architecture: (1) rain-soaked alley with a single lit window; (2) rooftops, chimneys and grappling rope; (3) ornate vault door with lockpicks glinting; (4) moonlit balcony with guard's lantern far below; (5) payoff: opened EMPTY chest, dagger stuck in a beam, escape route over rooftops at first light, four smoking lanterns left behind. Keep each whole subject within its respective fifth and central narrow strip. Natural walls and pillars resolve transitions, no panels. Rogue night heist, black leather, brass studs and chain, deep blue night, wet cobbles, dull poison green and warm window light. Dark subdued soft contrast, no bloom, no blurred patches or blank centers, no text, no recognizable faces.

The row and column were each edited once using their respective original as input. Exact row edit prompt:

> Edit this wide Rogue heist painting. Keep its rich continuous scenes and storytelling. For an extremely wide central crop, fit the COMPLETE dagger in beam, whole opened empty chest, and four smoking lanterns within the central 55% of image height, entirely in the rightmost fifth. Move dagger lower and make it smaller as needed. Keep the entire lock and lockpicks visible centrally, the lit alley window, rooftop grappling rope and guard with lantern. Full sharp detail, no text, dark subdued lighting.

Exact column edit prompt:

> Edit this tall Rogue heist painting. The image will be cropped to its CENTRAL 40% WIDTH only. Recompose all five chapters so every important object is fully inside this central 40%: alley lit window; rooftop rope; vault and lockpicks; balcony and guard lantern; and at bottom a complete OPEN EMPTY CHEST with a DAGGER STUCK IN A BEAM beside it, a compact row of FOUR smoking lanterns and escape rooftops at first light. Make objects small enough to fit, especially entire chest, dagger and all four lanterns. Keep single continuous vertical setting, detailed dark muted fantasy painting, no text.

Scripted edits: crop the 2172 × 724 row output to `(0, 145, 2170, 579)` and the 724 × 2172 column output to `(145, 0, 579, 2170)`, in exclusive-right/bottom coordinates; multiply RGB by 0.65 with rounding. These native-pixel crops are the 2170 × 434 and 434 × 2170 masters. Slice each master into five 434 × 434 squares and downscale each with Lanczos to 256 × 256; export opaque RGBA PNG and uncompressed 32-bit TGA. Draw the stitched leather, brass, green inlay and bracket atlas with Pillow; rails repeat evenly at their endpoints and unused regions are transparent. A PIL assembler places 64-pixel painting cells inside the six-pixel border area, overlays real condition icon PNGs, lights rails for active slots and studs only when both adjacent slots are active, mirrors the four corners, and enlarges each window 2× with Lanczos. The full sheet presents both masters at native crop size. Original and edited outputs are retained in `source/generated/`.

The heist and Rogue equipment read clearly, with detailed architecture and a recognizable empty-chest payoff. Prefix endings are imperfect: some cut figures or architecture, particularly the three-cell column, and the column reads as stacked architectural levels. The narrow column crop clips part of the dagger and outer lanterns, while the lanterns appear lit despite their smoke. The count motifs are not consistent; details become small in the actual 64-pixel windows.
