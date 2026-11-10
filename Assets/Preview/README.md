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

## Paladin: a vigil

| Cell | Story |
| --- | --- |
| 1 | A night marble chapel with a candle. |
| 2 | A ceremonial hammer on an altar in shafts of light. |
| 3 | A great stained-glass sunburst window. |
| 4 | Banners along white stone stairs at dawn. |
| 5 | A sunburst shield before a dawn city and four pillars of light. |

Generated with the built-in image generation tool. Exact row prompt:

> Use case: illustration-story. Create a single continuous extremely wide horizontal World of Warcraft paladin class-hall loading-screen painting, composed as five adjacent square chapters across the central horizontal band, no panels or seams. Left to right: 1 night marble chapel and one candle; 2 a ceremonial war hammer resting on a marble altar in shafts of light; 3 enormous detailed stained-glass golden sunburst window; 4 banners-only procession on white stone steps at dawn; 5 a prominent radiant gold sunburst shield overlooking a dawn city with four golden pillars of light rising behind it. Each chapter has detailed architecture at its right edge that resolves naturally while continuing seamlessly. Full detail edge to edge, no text, no faces, no blank areas, no fog patches. Dark quiet muted low contrast, white and grey marble, old gold, warm candlelight, deep blue shadows; no bloom. Highly detailed painterly fantasy art. Important: fit all five story beats within the middle narrow horizontal fifth of the image, because that band will be cropped to a 5:1 panorama.

Exact column prompt:

> Use case: illustration-story. Create a single continuous extremely tall upright vertical World of Warcraft paladin class-hall loading-screen painting, composed as five adjacent square chapters down the central vertical band, no panels or seams. Top to bottom: 1 night marble chapel and one candle; 2 a ceremonial war hammer resting on a marble altar in shafts of light; 3 enormous detailed stained-glass golden sunburst window; 4 banners-only procession on white stone steps at dawn; 5 a prominent radiant gold sunburst shield overlooking a dawn city with four golden pillars of light rising behind it. All objects upright, architecture and atmosphere flow continuously downwards, each chapter's bottom edge resolves naturally. Full detail edge to edge, no text, no faces, no blank areas, no fog patches. Dark quiet muted low contrast, white and grey marble, old gold, warm candlelight, deep blue shadows; no bloom. Highly detailed painterly fantasy art. Important: fit all five story beats within the middle narrow vertical fifth of the image, because that band will be cropped to a 1:5 panorama.

Column edit prompt, using the original column as input:

> Edit this vertical paladin painting for a narrow central crop. Preserve the five story moments and detailed marble and gold style, but make them flow continuously together with architectural transitions instead of abrupt horizontal seams. CRITICAL: keep the complete candle, hammer, sunburst window, stair banners, and entire final sunburst shield with the dawn city and four light pillars strictly inside the central 40% of the image width, all upright and legible. Make the shield small enough to fit entirely inside the bottom fifth and central 40%, with city and four pillars behind it. Full sharp detail, dark muted lighting, no text, no faces, no bloom.

Scripted edits: crop the 2172 × 724 row original to `(1, 145, 2171, 579)` and the 793 × 1983 edited column to `(198, 0, 594, 1980)`, exclusive right and bottom. Multiply RGB by 0.62, rounding, to subdue the light. Save these 2170 × 434 and 396 × 1980 crops as native-pixel masters. Slice each into five native square cells, Lanczos downscale each to 256 × 256, and save matching opaque RGBA PNG and uncompressed 32-bit TGA. Draw the marble, gold inlay, sunburst corner and stud atlas with Pillow; the rail has constant cross-section and transparent unused atlas space. The QA assembler places cells and real Conditions icons in 64-pixel slots, overlays 6-pixel rails and reflected corners, and places studs at boundaries, lighting rails for active slots and studs only when both neighboring slots are active. Scale each assembled window 2× with Lanczos. The full sheet shows both masters at their native crop size.

The hammer, stained glass, heraldry and shield make the Paladin theme legible, and both stories retain rich architectural detail. The vertical composition remains noticeably stacked. The narrow column crop clips part of the candle holder, while the row crop clips the bottom of the shield and top of the stained-glass sunburst; several prefix cuts end on continuing architecture rather than a naturally complete edge. The banners imply a procession but no people are shown, and the four pillars are clearer in the column than in the row.

## Priest — a prayer

| Cell | Story |
| --- | --- |
| 1 | A candlelit nave and open book on a lectern. |
| 2 | A cloister fountain of soft light. |
| 3 | Wings of light unfold over an altar. |
| 4 | Doves pass a bell tower at twilight. |
| 5 | Dawn over rooftops, a great halo and rays above the spires. |

Built-in imagegen prompts, exactly as submitted:

> Use case: illustration-story. Create a detailed World of Warcraft inspired priest class-hall loading-screen painting for a game UI. One continuous extra-wide horizontal narrative, designed to be cropped to the central horizontal 5:1 strip: place ALL essential subjects inside the central 20% of the image height, spanning the entire width. Five successive connected scenes left to right: candlelit nave with open book on lectern; cloister fountain of soft light; wings of light unfolding over altar; bell tower at twilight with doves; dawn rooftops with a great halo and four rays rising from four spires. Each fifth has complete detailed architecture, natural pillar or wall at its right edge, and flows into the next. Last fifth is a complete payoff. Ivory stone, pale gold, violet cloth, twilight blue, gentle candlelight. Dark muted low contrast, finely textured materials, no bloom, no fog or blank areas, no text, no recognizable faces. Render as a single cohesive detailed painting, not panels.

> Use case: illustration-story. Create a detailed World of Warcraft inspired priest class-hall loading-screen painting for a game UI. One continuous upright vertical narrative, designed to be cropped to the central vertical 1:5 strip: place ALL essential subjects inside the central 20% of image width, spanning the entire height. Five successive connected scenes top to bottom: candlelit nave with open book on lectern; cloister fountain of soft light; wings of light unfolding over altar; bell tower at twilight with doves; dawn rooftops with a great halo and four rays rising from four spires. All buildings and objects upright. Each fifth has complete detailed architecture, a natural ledge or architectural boundary at its bottom edge, and flows into the next. Last fifth is a complete payoff. Ivory stone, pale gold, violet cloth, twilight blue, gentle candlelight. Dark muted low contrast, finely textured materials, no bloom, no fog or blank areas, no text, no recognizable faces. Render as a single cohesive detailed painting, not panels.

> Use case: illustration-story. Paint a single seamless wide cinematic World of Warcraft inspired Priest class-hall loading-screen painting. Fill the ENTIRE canvas edge to edge with detailed scenery; absolutely no black bars, no bands, no letterboxing, no frames. Across the width tell a prayer in five successive locations smoothly blending: far left candlelit nave with open book on lectern; left-center cloister fountain of soft light; center wings of light unfolding over an altar; right-center bell tower at twilight with doves; far right dawn rooftops with a great halo and four rays rising from four spires. Place all story elements in the middle half of image height so a wide crop retains them, but paint architecture and scenery across the entire canvas above and below. Pillars and walls resolve each scene, dense sharp detail throughout, no empty or blurred centers. Ivory stone, pale gold, violet cloth, twilight blue, soft candles. Dark subdued soft contrast, no bloom, no text, no recognizable faces.

> Use case: illustration-story. Paint a single seamless upright tall cinematic World of Warcraft inspired Priest class-hall loading-screen painting. Fill the ENTIRE canvas edge to edge with detailed scenery; absolutely no black bars, no bands, no letterboxing, no frames. Top to bottom tell a prayer in five successive connected locations: candlelit nave with open book on lectern; cloister fountain of soft light; wings of light unfolding over an altar; bell tower at twilight with doves; dawn rooftops with a great halo and four rays rising from four spires. All objects upright. Place story elements in the middle half of image width so a tall crop retains them, but paint architecture and scenery across the entire canvas left and right. Natural ledges resolve transitions, dense sharp detail throughout, no empty or blurred centers. Ivory stone, pale gold, violet cloth, twilight blue, soft candles. Dark subdued soft contrast, no bloom, no text, no recognizable faces.

Scripted edits: retain all four generator outputs; the second column output reversed the story and the first row had insufficient painted height, so use the second row and first column. Crop the 2172 × 724 row to `(1, 100, 2171, 534)` and the 793 × 1983 column to `(198, 0, 594, 1980)` (exclusive right/bottom), and multiply RGB by 0.56 with rounding. Save the resulting 2170 × 434 and 396 × 1980 native-pixel masters, slice each into five square crops, Lanczos downscale to 256 × 256, and export opaque RGBA PNGs and uncompressed 32-bit TGAs. Draw the ivory, gold and violet border atlas with Pillow, using constant rail cross-sections, winged corner and halo studs. The QA assembler positions 64-pixel cells with six-pixel external rails, reflected corners and joint studs as in `UI/preview.lua`, overlays real condition icons, lights rails for active slots and studs when both neighbours are active, and enlarges each assembled window 2× with Lanczos. The full sheet presents both masters at native crop size. The vertical chapters read as stacked scenes and some prefix cuts intersect architecture; the row payoff includes more than four spires and the column includes a central fifth ray.

## Hunter preview painting

| Cell | Story |
| --- | --- |
| 1 | Dawn forest edge and a bow on a stump. |
| 2 | Paw prints crossing fresh snow. |
| 3 | A wolf companion on a ridge. |
| 4 | An eagle over a mountain pass. |
| 5 | Dusk campfire and a spear bearing trophy feathers. |

Generated with the built-in image generation tool. Exact row prompt:

> Use case: illustration-story. Create a continuous panoramic World of Warcraft inspired Hunter class loading-screen painting, composed as five consecutive square chapters left to right within the central horizontal strip of the image. 1 forest edge at dawn, bow resting on stump; 2 tracks and paw prints in fresh snow; 3 wolf companion silhouetted on ridge; 4 mountain pass with eagle in sky; 5 dusk camp under stars, campfire and spear bearing exactly four trophy feathers. One flowing landscape, rich sharp details edge to edge, natural stopping points at each fifth. Hunter materials green leather, horn, bone, fur, forest green, snow blue, restrained amber. Dark muted soft contrast, no bloom, text, faces, panels, borders, blurred patches or vignette. Ensure all five chapters appear within the middle 20% of image height, because that strip will be cropped to a 5:1 panorama. Reference the attached Shaman painting for painterly detail and quiet game-background treatment, not its subject.

Exact first column prompt:

> Use case: illustration-story. Create a continuous upright vertical World of Warcraft inspired Hunter class loading-screen painting, composed as five consecutive square chapters top to bottom within the central vertical strip of the image. 1 forest edge at dawn, bow resting on stump; 2 tracks and paw prints in fresh snow; 3 wolf companion silhouetted on ridge; 4 mountain pass with eagle in sky; 5 dusk camp under stars, campfire and spear bearing exactly four trophy feathers. One flowing landscape, rich sharp details edge to edge, natural stopping points at each fifth. Hunter materials green leather, horn, bone, fur, forest green, snow blue, restrained amber. Dark muted soft contrast, no bloom, text, faces, panels, borders, blurred patches or vignette. Ensure all five chapters appear within the middle 20% of image width, because that strip will be cropped to a 1:5 panorama. Reference the attached Shaman painting for painterly detail and quiet game-background treatment, not its subject.

Exact replacement column prompt:

> Create a single very tall upright continuous Hunter landscape painting for cropping to the central 1:5 strip. Within the central 40% of the image width place ALL essential subjects, fully visible and relatively small: top to bottom a bow resting on a forest stump at dawn, snow with animal pawprints, a wolf on a ridge, mountain pass and an eagle, finally a dusk campfire and a spear with four feathers. Do not put key subjects outside this central strip. Landscape transitions seamlessly between the five scenes. Rich fine detail throughout, World of Warcraft class-hall loading-screen painting, green leather, horn, bone, fur, forest green, snow blue, subdued amber, dark muted and low contrast, no text, borders, empty fog or bright bloom.

Scripted processing: kept both column attempts and the row output in `source/generated/`; cropped native pixels `(0,150,2170,584)` from the row and `(270,0,666,1980)` from the replacement column, multiplied RGB by 0.64, and saved these 2170×434 and 396×1980 masters. Sliced each master into five native square cells, resized each with Lanczos to 256×256, and exported matching opaque PNG and uncompressed RGBA32 TGA. No aspect-ratio scaling was applied. A PIL drawing built the transparent 256×64 atlas: stitched green leather rails with dim/lit green inlay, bone-toned horn corner and feather/peg studs; matching rail endpoints permit butt joins. A PIL assembler placed 64px cells and real condition icons inside an external 6px border, with per-slot rails, mirrored corners and joint studs matching `UI/preview.lua`; the game-scale sheet is enlarged 2× with Lanczos. The full sheet places the two masters at 100%.

Review limitations: prefix edges sometimes cut through open landscape; the column is composed as vertically stacked vistas and its crop trims the feathered spear, while the row crop also clips its tip. The generator did not reliably render exactly four distinct feathers. The border's material details are subtle at game scale.

## Druid: a turn of the seasons

| Cell | Story |
| --- | --- |
| 1 | Moonlit grove and antlered stone circle. |
| 2 | Waking roots and spring blossom. |
| 3 | A bear beside a misty stream. |
| 4 | The great tree in summer gold. |
| 5 | Four seasonal trees beneath a crescent moon. |

Generated with the built-in image generation tool. Exact prompts:

**Row:**

> Use case: illustration-story. Create a wide horizontal continuous World of Warcraft inspired druid class-hall loading screen painting, rich finely detailed dark tapestry, no text. Compose five equal consecutive square chapters across the central horizontal band, designed to crop to 5:1: 1 moonlit grove and antlered stone circle, 2 waking roots and spring blossom, 3 misty stream and unmistakable bear silhouette, 4 a magnificent summer-gold great tree, 5 four distinct trees side by side for spring summer autumn winter under crescent moon. Continuous landscape and natural tree or rock boundaries at each fifth; last fifth complete. Dark bark, living green, moon gold, mist blue; quiet low contrast, no bloom, no empty or blurred patches, edge-to-edge detail, no faces.

**First column:**

> Use case: illustration-story. Create a tall vertical continuous World of Warcraft inspired druid class-hall loading screen painting, upright top-to-bottom journey, rich finely detailed dark tapestry, no text. Compose five equal consecutive square chapters across the central vertical band, designed to crop to 1:5: 1 moonlit grove and antlered stone circle, 2 waking roots and spring blossom, 3 misty stream and unmistakable bear silhouette, 4 a magnificent summer-gold great tree, 5 four distinct trees side by side for spring summer autumn winter under crescent moon. Continuous landscape and natural tree or rock boundaries at each fifth; last fifth complete. Dark bark, living green, moon gold, mist blue; quiet low contrast, no bloom, no empty or blurred patches, edge-to-edge detail, no faces.

**Second column attempt:**

> Use case: illustration-story. Tall upright druid fantasy game painting, a continuous journey from top to bottom in five equal chapters. CRITICAL composition: all important subjects must fit INSIDE THE CENTRAL 40 PERCENT of image width, because both left and right sides will be cropped away; extend only background out to the sides. First chapter antlered standing stone circle in moonlit grove; second waking roots and spring blossoms; third a bear beside a misty stream; fourth great summer-gold tree; fifth all FOUR small distinctly different spring, summer, autumn, and winter trees tightly grouped side by side under a crescent moon, all four inside the central 40 percent. Flowing natural forest scenery, detailed dark bark, living green, moon gold and mist blue, muted, soft contrast, no bright glow, no text, no blank areas, intricate WoW class-hall painting.

**Final column:**

> A tall continuous fantasy druid painting for a very narrow vertical crop. All story elements MUST fit in the CENTRAL 25% of the picture width; the rest is expendable background. At the top a moonlit antlered stone circle, then spring roots and pink blossoms, then a bear at a stream, then a golden great tree. At the bottom, exactly FOUR MINIATURE TREES packed together extremely close inside the central 25% of the image: one pink spring tree, one green summer tree, one orange autumn tree, one white winter tree, all four fully visible next to each other and crescent moon above. The tiny trees together should occupy less than one quarter of the total image width. Rich intricate dark World of Warcraft druid class hall painting, flowing forest, muted bark, green, gold and mist blue, no words, no bloom, no empty spots.

**Processing:** Pillow cropped the row original at (0, 92, 2170, 526) and the final column at (145, 0, 579, 2170), in native pixels. Each exact-ratio master was uniformly darkened to 68% per channel, sliced into 434-pixel squares, and each slice resized to 256 pixels with Lanczos; no aspect-ratio deformation. Original generations and cropped masters are retained in `source/generated/`. The border atlas was drawn procedurally as repeatable bark and green-vine rails, mirrored antler joints, and dim/lit leaf-and-moon studs; unused pixels are transparent. The QA assembler applies the same per-slot rails, mirrored corners and neighbour-dependent studs as the Shaman reference; it renders at 64 pixels per slot with 6-pixel border and scales the composite 2x using Lanczos. QA uses actual Conditions icons.

**Review:** The row reads continuously and retains all four seasonal trees. The column has all four trees and a recognizable Druid journey, though the scenes stack vertically and the gold tree has a residual illuminated center; some prefix cuts pass through foliage or water rather than resolving completely. The corner's antler detail is subtle at game size.

## Warlock — the bargain

| Cell | Story |
| --- | --- |
| 1 | A ritual circle in a bone-filled crypt. |
| 2 | An imp whispers beside chained soulstones. |
| 3 | Fel fire rises from an altar. |
| 4 | A horned shadow looms over a ruined arch. |
| 5 | Four soulstones rest on an altar under a green moon. |

Built-in image generation prompts (exact):

**Row, used:**

> Use case: illustration-story. Create a richly detailed World of Warcraft inspired dark fantasy loading-screen painting, an exceptionally wide horizontal continuous panorama designed to crop a central 5:1 strip. Within that central strip tell a warlock's bargain sequentially left to right: bone-lit ritual circle in crypt; imp whispering beside chained soulstones; fel fire rising from an altar; horned shadow looming over a ruined arch; payoff four distinct soulstones aglow on an altar under a green moon. Each fifth contains its event, and transition at each fifth naturally resolves with stone or pillars. Full intricate detail everywhere, coherent continuous landscape and architecture, no separate panels, no lettering or UI. Charcoal bone, thorn and chain, fel green and purple, dark crypt stone. Muted dark soft contrast, no bloom, no blank or blurred areas. Match rich detailed painterly fantasy reference.

**Column, first attempt:**

> Use case: illustration-story. Create a richly detailed World of Warcraft inspired dark fantasy loading-screen painting, exceptionally tall vertical continuous composition designed to crop a central 1:5 strip, all subjects upright. Within that central strip tell a warlock's bargain sequentially top to bottom: bone-lit ritual circle in crypt; imp whispering beside chained soulstones; fel fire rising from an altar; horned shadow looming over a ruined arch; payoff four distinct soulstones aglow on an altar under a green moon. Each fifth contains its event, transition naturally resolves with masonry. Full intricate detail everywhere, coherent continuous scene, no panel borders, no lettering or UI. Charcoal bone, thorns and chains, fel green and purple, dark crypt stone. Muted dark soft contrast, no bloom, no blank or blurred areas. Rich detailed painterly fantasy.

**Column, used:**

> Use case: illustration-story. A vertical continuous dark fantasy Warlock loading-screen painting, no text. CRITICAL COMPOSITION: everything essential must fit within the central 20 percent of image width, as it will be cropped to a very narrow 1:5 strip; place all story subjects and all four final stones entirely inside this narrow central column, not across full image. Top to bottom: bone-lit ritual circle in crypt, a small imp whispering beside chained soulstones, fel fire rising from an altar, a horned shadow over a ruined arch, and four tiny soulstones together on an altar beneath a green moon. Each fifth of the central strip depicts its event, connected by detailed crypt masonry, no panel borders. Upright scene, sharp detailed painting, charcoal bone, chains, thorn, dark stone, muted green and purple. Dark, no bloom, no empty or blurred areas.

**Row, second attempt (not used):**

> Use case: illustration-story. A horizontal continuous dark fantasy Warlock loading-screen painting, no text. CRITICAL COMPOSITION: everything essential must fit within the central 20 percent of image height, as it will be cropped to a very narrow 5:1 strip; place all story subjects, entire ritual circle, moon, and all four final stones inside this narrow central horizontal strip. Left to right: bone-lit ritual circle in a crypt, an imp whispering beside chained soulstones, fel fire rising from an altar, a horned shadow over a ruined arch, and four small soulstones together on an altar beneath a green moon. Each fifth of the strip depicts its event, connected by detailed crypt masonry, no panel borders. Sharp detailed WoW-inspired painting, charcoal bone, chains, thorn, dark stone, muted green and purple. Dark, no bloom, no empty or blurred areas.

Scripted edits: the row original is 2172×724, cropped at (1, 0, 2171, 434); the column original is 887×1774, cropped at (266, 0, 620, 1770). Each exact-ratio native-pixel master was uniformly darkened by multiplying RGB by 0.65, sliced into native square fifths, and each slice resized to 256×256 with Lanczos and saved as opaque RGBA PNG and uncompressed RGBA32 TGA. A PIL-drawn charcoal bone-and-thorn border atlas uses matching rail endpoints, dim and lit green inlays, mirrored corner and two symmetric studs. The QA assembler positions cells inside a 6 px external border, applies rails and studs according to active slots, uses real Conditions icons and renders at 2× Lanczos. The second row attempt confined the story to an excessively thin strip surrounded by black, so it was retained as an attempt rather than used.

Review: the five beats and four-stone payoff are legible, with rich crypt detail and seamless source joins. The row crop cuts off much of the ritual circle, some prefix endings cut through objects, and the column reads as vertically stacked episodes; its final stones are small at game size. The border is quiet and its lit state is visibly greener, but its tiny horn details are subtle at game size.
